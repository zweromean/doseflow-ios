import ActivityKit
import Foundation

struct MedicationActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
        var end: Date
        var dose: Int
    }
    var medication: String
}

struct DoseRecord: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var dose: Int
    var medicationName: String? = nil
    var medication: String { medicationName ?? "콘서타" }
}

enum SharedData {
    static let suite = "group.com.example.DoseFlow"
    static var defaults: UserDefaults { UserDefaults(suiteName: suite) ?? .standard }
    static var records: [DoseRecord] {
        get { (try? JSONDecoder().decode([DoseRecord].self, from: defaults.data(forKey: "doses") ?? Data())) ?? [] }
        set { if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: "doses") } }
    }
}
