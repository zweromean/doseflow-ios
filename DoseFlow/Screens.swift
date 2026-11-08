import SwiftUI
import UserNotifications
import UIKit

struct NoteEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var date: Date
    @State private var text = ""
    var body: some View { NavigationStack { TextEditor(text: $text).padding().navigationTitle("메모 남기기").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("저장") { var note = store.notes[store.key(date)] ?? DayNote(); note.text = text; store.notes[store.key(date)] = note; store.save(); dismiss() } }; ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }.onAppear { text = store.notes[store.key(date)]?.text ?? "" } }
}
}
struct IntervalEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var body: some View { NavigationStack { Form {
        Section("복용 후 예상 구간") {
            Stepper("최대농도 시작: \(Int(store.peakStart))시간", value: $store.peakStart, in: 2...store.peakEnd-1)
            Stepper("최대농도 종료: \(Int(store.peakEnd))시간", value: $store.peakEnd, in: store.peakStart+1...store.duration-1)
            Stepper("감소 종료: \(Int(store.duration))시간", value: $store.duration, in: store.peakEnd+1...16)
        }
        Text("개인별로 다를 수 있는 참고용 구간입니다. 복용량 변경을 안내하는 기능이 아닙니다.").font(.caption).foregroundStyle(.secondary)
    }.navigationTitle("구간 조정").toolbar { Button("완료") { store.save(); dismiss() } } } }
}
struct CalendarScreen: View {
    @EnvironmentObject var store: Store
    @State private var month = Date()
    @State private var selected = Date()
    @State private var tab = 0
    @State private var edit = false
    var calendar: Calendar { Calendar.current }
    var days: [Date] { let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!; let offset = calendar.component(.weekday, from: first)-1; return (0..<42).map { calendar.date(byAdding: .day, value: $0-offset, to: first)! } }
    var body: some View { NavigationStack { ScrollView { VStack(spacing: 12) {
        Card {
            HStack { Button { shift(-1) } label: { Image(systemName: "chevron.left") }; Spacer(); Text(month.formatted(.dateTime.year().month().locale(Locale(identifier: "ko_KR")))).bold(); Spacer(); Button { shift(1) } label: { Image(systemName: "chevron.right") } }.foregroundStyle(.black).padding(12)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 18) {
                ForEach(Array(["일","월","화","수","목","금","토"].enumerated()), id: \.offset) { _, day in Text(day).font(.caption).foregroundStyle(.gray) }
                ForEach(days, id: \.self) { day in Button { selected = day } label: { VStack(spacing: 3) { Text("\(calendar.component(.day, from: day))").font(.system(size: 15)).frame(width: 31, height: 31).background(calendar.isDate(day, inSameDayAs: selected) ? Color.orange : .clear, in: Circle()).overlay(Circle().stroke(calendar.isDate(day, inSameDayAs: selected) ? accent : .clear, lineWidth: 2)); Circle().fill(store.doses(day).isEmpty ? .clear : accent).frame(width: 4, height: 4) }.foregroundStyle(calendar.isDate(day, equalTo: month, toGranularity: .month) ? .primary : .secondary) } }
            }
            Text("이번 달 복용 \(Set(store.records.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }.map { store.key($0.date) }).count)일").font(.caption).foregroundStyle(.gray).padding(.top, 10)
        }
        Card {
            Picker("기록", selection: $tab) { Text("• 복약").tag(0); Text("• 목표").tag(1); Text("• 할 일").tag(2) }.pickerStyle(.segmented)
            if tab == 0 { if store.doses(selected).isEmpty { Text("복용 기록이 없어요").foregroundStyle(.gray) }; ForEach(store.doses(selected)) { item in HStack { Text(clock(item.date)).font(.caption).foregroundStyle(.gray); if item.medication == "콘서타" { Pill(dose: item.dose) } else { Image(systemName: "pills") }; Text("\(item.medication) \(item.dose)mg").bold() } } }
            else { Text("현재 \(tab == 1 ? "목표" : "할 일")").font(.caption).foregroundStyle(.secondary); ForEach(store.tasks.filter { $0.goal == (tab == 1) }) { item in Label(item.title, systemImage: item.done ? "checkmark.circle.fill" : "circle") } }
        }
        Card { HStack { Text(selected.formatted(date: .abbreviated, time: .omitted)).bold(); Spacer(); Button("메모 보기") { edit = true }.font(.caption.bold()) }; if let note = store.notes[store.key(selected)] { if let mood = note.mood { MoodFace(index: mood, selected: true) }; Text(note.text) } else { Text("남긴 기록이 없어요").foregroundStyle(.gray) } }
    }.padding(8) }.navigationTitle("캘린더").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $edit) { NoteEditor(date: selected) } } }
    func shift(_ value: Int) { month = calendar.date(byAdding: .month, value: value, to: month)! }
}
struct NotesView: View {
    @EnvironmentObject var store: Store
    var body: some View { NavigationStack { List { if store.notes.isEmpty { ContentUnavailableView("기록이 없어요", systemImage: "square.and.pencil", description: Text("홈에서 기분과 메모를 남겨 보세요.")) }; ForEach(store.notes.keys.sorted().reversed(), id: \.self) { key in VStack(alignment: .leading, spacing: 10) { Text(key).font(.headline); if let note = store.notes[key] { if let mood = note.mood { HStack { MoodFace(index: mood); Text(moodNames[mood]) } }; if !note.text.isEmpty { Text(note.text) } } }.padding(.vertical, 8) } }.navigationTitle("기록") } }
}
struct TasksView: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var goal = false
    var body: some View { NavigationStack { List {
        Section { TextField("새 목표 또는 할 일", text: $text); Toggle("목표로 등록", isOn: $goal); Button("추가") { store.tasks.append(TaskItem(title: text.trimmingCharacters(in: .whitespaces), goal: goal)); text = ""; store.save() }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty) }
        ForEach($store.tasks) { $item in Button { item.done.toggle(); store.save() } label: { HStack { Image(systemName: item.done ? "checkmark.circle.fill" : "circle"); Text(item.title).strikethrough(item.done); Spacer(); if item.goal { Text("목표").font(.caption).foregroundStyle(.green) } } } }.onDelete { store.tasks.remove(atOffsets: $0); store.save() }
    }.navigationTitle("목표 · 할 일") } }
}
struct ReminderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var time = Date()
    @State private var message: String?
    var body: some View { NavigationStack { Form { DatePicker("매일 알림 시간", selection: $time, displayedComponents: .hourAndMinute); Button("매일 복용 알림 설정") { Task { do { let center = UNUserNotificationCenter.current(); guard try await center.requestAuthorization(options: [.alert, .sound]) else { message = "설정 앱에서 알림을 허용해 주세요."; return }; let content = UNMutableNotificationContent(); content.title = "복약 기록"; content.body = "처방받은 복용 일정을 확인하고 기록해 주세요."; content.sound = .default; let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.hour, .minute], from: time), repeats: true); try await center.add(UNNotificationRequest(identifier: "daily-dose", content: content, trigger: trigger)); message = "매일 \(clock(time)) 알림을 설정했어요." } catch { message = error.localizedDescription } } }; Button("알림 해제", role: .destructive) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-dose"]); message = "알림을 해제했어요." }; if let message { Text(message) } }.navigationTitle("복용 루틴").toolbar { Button("닫기") { dismiss() } } } }
}
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var intro = false
    @State private var routine = false
    @State private var message: String?
    var body: some View { NavigationStack { Form {
        Section("앱 기능") { Button("기능 둘러보기") { intro = true }; Button("복용 알림") { routine = true }; Button("잠금화면 Live Activity 시작") { do { try store.liveActivity(); message = "진행 중인 복용 기록이 있으면 잠금화면에 표시됩니다." } catch { message = error.localizedDescription } }; if let message { Text(message).font(.caption) } }
        Section("데이터") { Text("기록은 이 iPhone에 저장됩니다."); HealthConnectionView() }
    }.navigationTitle("설정").sheet(isPresented: $intro) { IntroView() }.sheet(isPresented: $routine) { ReminderView() } } }
}
struct ReportView: View {
    @EnvironmentObject var health: HealthStore
    @Environment(\.scenePhase) private var phase
    @State private var healthSummary = HealthSummary()
    @State private var healthLoading = false
    @State private var healthError: String?
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var from = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
    @State private var to = Date()
    @State private var url: URL?
    @State private var errorText: String?
    var records: [DoseRecord] { store.records.filter { $0.date >= Calendar.current.startOfDay(for: from) && $0.date < Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: to))! }.sorted { $0.date < $1.date } }
    var body: some View { NavigationStack { Form { DatePicker("시작", selection: $from, in: ...to, displayedComponents: .date); DatePicker("종료", selection: $to, in: from..., displayedComponents: .date); Section("복용 · 컨디션 리포트") { Text("복용 \(records.count)회"); Text(healthSummary.heartText); Text(healthSummary.sleepText); if healthLoading { ProgressView("건강 데이터 읽는 중") }; if let healthError { Text(healthError).font(.caption) }; if !health.requested { Text("설정에서 건강 앱을 연결하면 심박·수면을 포함할 수 있어요.").font(.caption) }; Button("PDF 만들기") { makePDF() }.disabled(healthLoading); if let url { ShareLink("PDF 저장 및 공유", item: url) }; if let errorText { Text(errorText) } } }.navigationTitle("리포트").toolbar { Button("닫기") { dismiss() } }.onChange(of: from) { url = nil }.onChange(of: to) { url = nil }.task(id: "\(from)-\(to)-\(health.revision)-\(phase == .active)") {
        guard phase == .active else { return }
        url = nil; healthSummary = HealthSummary(); healthError = nil; healthLoading = true
        defer { healthLoading = false }
        do { let result = try await health.summary(from: from, to: to); guard !Task.isCancelled else { return }; healthSummary = result }
        catch { if !Task.isCancelled { healthError = "건강 데이터 조회 오류: \(error.localizedDescription)" } }
    } } }
    func makePDF() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("복용-컨디션-리포트.pdf")
        do { try renderer.writePDF(to: path) { ctx in
            var y: CGFloat = 45
            func line(_ text: String, bold: Bool = false) { if y > 775 { ctx.beginPage(); y = 45 }; (text as NSString).draw(in: CGRect(x: 40, y: y, width: 515, height: 44), withAttributes: [.font: bold ? UIFont.boldSystemFont(ofSize: 18) : UIFont.systemFont(ofSize: 12)]); y += 38 }
            ctx.beginPage(); line("복용 · 컨디션 리포트", bold: true); line("\(store.key(from)) – \(store.key(to))"); line("복용 \(records.count)회"); line(healthSummary.heartText); line(healthSummary.sleepText); line("수면: 전날 정오~당일 정오, 기록이 있는 날의 평균"); if healthError != nil { line("건강 데이터 조회 실패: 이 리포트에 건강 데이터가 포함되지 않았습니다.") }
            for record in records { line("\(store.key(record.date))  \(clock(record.date))  \(record.medication) \(record.dose)mg") }
            line("기분 · 메모", bold: true)
            for key in store.notes.keys.sorted() where key >= store.key(from) && key <= store.key(to) { if let note = store.notes[key] { line("\(key)  \(note.mood.map { moodNames[$0] } ?? "")"); for chunk in note.text.split(separator: "\n", omittingEmptySubsequences: false) { let chars = Array(chunk); if chars.isEmpty { line("") }; for start in stride(from: 0, to: chars.count, by: 40) { line(String(chars[start..<min(start+40, chars.count)])) } } } }
        }; url = path } catch { errorText = error.localizedDescription }
    }
}
