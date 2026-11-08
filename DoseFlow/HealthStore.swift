import SwiftUI
import HealthKit
import Charts

struct HeartReading: Identifiable {
    let id: UUID
    let date: Date
    let bpm: Double
}
struct HealthSummary {
    var heart: [HeartReading] = []
    var sleepHours: Double?
    var sleepNights = 0
    var meanHeart: Double? { heart.isEmpty ? nil : heart.map(\.bpm).reduce(0, +) / Double(heart.count) }
    var heartText: String { meanHeart.map { String(format: "평균 심박 %.0f bpm", $0) } ?? "심박 데이터 없음" }
    var sleepText: String { sleepHours.map { String(format: "평균 수면 %.1f시간 (%d일)", $0, sleepNights) } ?? "수면 데이터 없음" }
}

@MainActor final class HealthStore: ObservableObject {
    private let health = HKHealthStore()
    @Published var requested = UserDefaults.standard.bool(forKey: "healthRequested")
    @Published var requesting = false
    @Published var message: String?
    @Published var revision = 0
    @Published var showConnectionResult = false
    var available: Bool { HKHealthStore.isHealthDataAvailable() }
    func connect() async {
        guard !requesting else { return }
        guard available else {
            message = "이 기기에서 건강 데이터를 사용할 수 없습니다."
            showConnectionResult = true
            return
        }
        requesting = true
        defer { requesting = false; showConnectionResult = true }
        do {
            let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKCategoryType(.sleepAnalysis)]
            let status = try await health.getRequestStatusForAuthorization(toShare: [], read: read)
            try await health.requestAuthorization(toShare: [], read: read)
            requested = true
            UserDefaults.standard.set(true, forKey: "healthRequested")
            if status == .unnecessary {
                message = "추가 권한 요청이 필요하지 않아 권한 화면이 다시 표시되지 않을 수 있습니다. 읽기 허용 여부는 앱에서 알 수 없습니다. 건강 앱 → 프로필 → 개인정보 보호 → 앱에서 복약의 심박·수면 읽기 설정을 확인해 주세요. 앱이 목록에 없다면 아래 오류 여부와 설치에 사용한 서명 방식을 확인해 주세요."
            } else {
                message = "건강 데이터 권한 요청을 완료했습니다. 완료 자체가 읽기 허용을 의미하지는 않습니다. 허용한 항목에 실제 기록이 있으면 표시됩니다."
            }
            revision += 1
        } catch {
            requested = false
            UserDefaults.standard.set(false, forKey: "healthRequested")
            let native = error as NSError
            var detail = "\(native.domain) (\(native.code)): \(native.localizedDescription)"
            if let reason = native.localizedFailureReason { detail += "\n\(reason)" }
            if let underlying = native.userInfo[NSUnderlyingErrorKey] as? NSError {
                detail += "\n\(underlying.domain) (\(underlying.code)): \(underlying.localizedDescription)"
            }
            let lower = detail.lowercased()
            let guidance: String
            if lower.contains("entitlement") || lower.contains("provision") {
                guidance = "설치된 앱의 서명에서 HealthKit 권한을 사용할 수 없습니다. 서명과 프로비저닝 프로파일에 com.apple.developer.healthkit 권한이 허용되어야 합니다. IPA를 다시 빌드하는 것만으로 설치 도구의 서명 권한이 추가되지는 않습니다."
            } else {
                guidance = "건강 데이터 권한 요청에 실패했습니다. 아래 오류 내용을 확인해 주세요."
            }
            message = guidance + "\n\n오류 상세\n" + detail
        }
    }
    private func samples(type: HKSampleType, start: Date, end: Date) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            health.execute(query)
        }
    }
    func heart(start: Date, end: Date) async throws -> [HeartReading] {
        guard requested, available else { return [] }
        let samples = try await samples(type: HKQuantityType(.heartRate), start: start, end: end)
        return samples.compactMap { sample in
            guard let sample = sample as? HKQuantitySample, sample.startDate >= start, sample.startDate < end else { return nil }
            return HeartReading(id: sample.uuid, date: sample.startDate, bpm: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        }
    }
    // Merge overlapping asleep samples so different devices and sleep stages never double-count time.
    static func asleepHours(_ samples: [HKCategorySample], start: Date, end: Date) -> Double? {
        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        let intervals = samples.filter { asleep.contains($0.value) }.map { (max($0.startDate, start), min($0.endDate, end)) }.filter { $0.0 < $0.1 }.sorted { $0.0 < $1.0 }
        guard var current = intervals.first else { return nil }
        var seconds: TimeInterval = 0
        for interval in intervals.dropFirst() {
            if interval.0 <= current.1 { current.1 = max(current.1, interval.1) }
            else { seconds += current.1.timeIntervalSince(current.0); current = interval }
        }
        seconds += current.1.timeIntervalSince(current.0)
        return seconds / 3600
    }
    // Each date's sleep is the prior noon through that date's noon, including sleep across midnight.
    func summary(from: Date, to: Date) async throws -> HealthSummary {
        guard requested, available else { return HealthSummary() }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to))!
        async let heartValues = heart(start: start, end: end)
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: start)!
        let sleepEnd = calendar.date(byAdding: .hour, value: -12, to: end)!
        let sleepSamples = try await samples(type: HKCategoryType(.sleepAnalysis), start: sleepStart, end: sleepEnd).compactMap { $0 as? HKCategorySample }
        var totals: [Double] = []
        var day = start
        while day < end {
            let windowStart = calendar.date(byAdding: .hour, value: -12, to: day)!
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let windowEnd = calendar.date(byAdding: .hour, value: -12, to: nextDay)!
            if let hours = Self.asleepHours(sleepSamples, start: windowStart, end: windowEnd) { totals.append(hours) }
            day = nextDay
        }
        return HealthSummary(heart: try await heartValues, sleepHours: totals.isEmpty ? nil : totals.reduce(0, +)/Double(totals.count), sleepNights: totals.count)
    }
}

struct HealthConnectionView: View {
    @EnvironmentObject var health: HealthStore
    var body: some View {
        Button(health.requesting ? "권한 요청 중…" : health.requested ? "건강 접근 권한 다시 요청" : "건강 앱 연결") { Task { await health.connect() } }.disabled(health.requesting)
            .alert("건강 연결 결과", isPresented: $health.showConnectionResult) { Button("확인", role: .cancel) {} } message: { Text(health.message ?? "") }
        if let message = health.message { Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
        Text("심박·수면을 읽기만 합니다. 데이터가 없거나 읽기 권한이 없으면 값이 표시되지 않습니다. 권한은 설정 앱의 건강 접근 항목에서 변경할 수 있습니다.").font(.caption).foregroundStyle(.secondary)
    }
}

struct HealthCard: View {
    @EnvironmentObject var health: HealthStore
    @Environment(\.scenePhase) private var phase
    var date: Date
    var record: DoseRecord?
    @State private var summary = HealthSummary()
    @State private var readings: [HeartReading] = []
    @State private var errorText: String?
    @State private var loading = false
    private var requestID: String { "\(date.timeIntervalSince1970)-\(record?.id.uuidString ?? "none")-\(health.revision)-\(phase == .active)" }
    var body: some View {
        Card {
            Text("심박 · 수면").font(.headline)
            if !health.requested { HealthConnectionView() }
            else {
                if loading { ProgressView("건강 데이터 읽는 중") }
                Text(summary.heartText).bold()
                Text(summary.sleepText).foregroundStyle(.secondary)
                if !readings.isEmpty {
                    Text(record == nil ? "선택한 날짜의 심박" : "복용 후 16시간 심박").font(.caption).foregroundStyle(.secondary)
                    Chart(readings) { item in LineMark(x: .value("시간", item.date), y: .value("심박", item.bpm)).foregroundStyle(.pink) }.chartYAxisLabel("bpm").frame(height: 110)
                }
                if let errorText { Text(errorText).font(.caption).foregroundStyle(.secondary) }
                Text("심박은 건강 앱에 저장된 측정값입니다. 수면은 전날 정오부터 당일 정오까지의 실제 수면 시간을 합산합니다.").font(.caption2).foregroundStyle(.secondary)
                Button("새로고침") { health.revision += 1 }.font(.caption)
            }
        }.task(id: requestID) {
            guard health.requested, phase == .active else { return }
            loading = true; errorText = nil; summary = HealthSummary(); readings = []
            defer { loading = false }
            do {
                let result = try await health.summary(from: date, to: date)
                var points = result.heart
                if let record { points = try await health.heart(start: record.date, end: record.date.addingTimeInterval(16*3600)) }
                guard !Task.isCancelled else { return }
                summary = result; readings = points
            } catch { if !Task.isCancelled { errorText = error.localizedDescription } }
        }
    }
}
