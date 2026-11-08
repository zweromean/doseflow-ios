import XCTest
import HealthKit
@testable import DoseFlow

@MainActor final class HealthStoreTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    func sample(_ offset: Double, _ hours: Double, _ value: HKCategoryValueSleepAnalysis = .asleepCore) -> HKCategorySample {
        HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: value.rawValue, start: start.addingTimeInterval(offset * 3600), end: start.addingTimeInterval((offset + hours) * 3600))
    }
    func testOverlappingDevicesAndStagesDoNotDoubleCount() {
        let samples = [sample(0, 4), sample(2, 4, .asleepREM), sample(0, 6, .asleepUnspecified)]
        XCTAssertEqual(HealthStore.asleepHours(samples, start: start, end: start.addingTimeInterval(24*3600))!, 6, accuracy: 0.001)
    }
    func testAwakeAndInBedExcludedAndGapsPreserved() {
        let samples = [sample(0, 10, .inBed), sample(0, 3), sample(3, 1, .awake), sample(4, 2, .asleepDeep)]
        XCTAssertEqual(HealthStore.asleepHours(samples, start: start, end: start.addingTimeInterval(24*3600))!, 5, accuracy: 0.001)
    }
    func testSamplesClippedAtWindowEdges() {
        XCTAssertEqual(HealthStore.asleepHours([sample(-2, 6)], start: start, end: start.addingTimeInterval(2*3600))!, 2, accuracy: 0.001)
    }
    func testMissingSleepDoesNotBecomeZeroHours() {
        XCTAssertNil(HealthStore.asleepHours([], start: start, end: start.addingTimeInterval(24*3600)))
        XCTAssertNil(HealthStore.asleepHours([sample(0, 8, .inBed)], start: start, end: start.addingTimeInterval(24*3600)))
    }
    func testLegacyDoseKeepsConcertaName() throws {
        let data = Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"date\":0,\"dose\":18}".utf8)
        let record = try JSONDecoder().decode(DoseRecord.self, from: data)
        XCTAssertEqual(record.medication, "콘서타")
    }
    func testMedicationNameSurvivesRoundTrip() throws {
        let record = DoseRecord(date: Date(), dose: 10, medicationName: "메디키넷")
        let decoded = try JSONDecoder().decode(DoseRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.medication, "메디키넷")
        XCTAssertEqual(decoded.dose, 10)
    }
    func testRoutineRoundTripPreservesEdits() throws {
        let routines = [MedicationRoutine(title: "아침", items: [MedicationItem(name: "콘서타", dose: 18)])]
        let decoded = try JSONDecoder().decode([MedicationRoutine].self, from: JSONEncoder().encode(routines))
        XCTAssertEqual(decoded.first?.items.first?.dose, 18)
        XCTAssertEqual(decoded.first?.title, "아침")
    }
}
