import SwiftUI
import WidgetKit
import ActivityKit

struct DayNote: Codable { var mood: Int?; var text = "" }
struct TaskItem: Identifiable, Codable { var id = UUID(); var title: String; var done = false; var goal = false }

@MainActor final class Store: ObservableObject {
    @Published var records = SharedData.records
    @Published var notes: [String: DayNote] = [:]
    @Published var tasks: [TaskItem] = []
    @Published var peakStart = 6.0
    @Published var peakEnd = 10.0
    @Published var duration = 12.0
    @Published var routines: [MedicationRoutine] = [MedicationRoutine(title: "아침"), MedicationRoutine(title: "점심"), MedicationRoutine(title: "저녁")]
    init() {
        if let data = UserDefaults.standard.data(forKey: "routines"), let value = try? JSONDecoder().decode([MedicationRoutine].self, from: data) { routines = value }
        if let data = UserDefaults.standard.data(forKey: "notes"), let value = try? JSONDecoder().decode([String: DayNote].self, from: data) { notes = value }
        if let data = UserDefaults.standard.data(forKey: "tasks"), let value = try? JSONDecoder().decode([TaskItem].self, from: data) { tasks = value }
        if let values = UserDefaults.standard.array(forKey: "intervals") as? [Double], values.count == 3 { peakStart = values[0]; peakEnd = values[1]; duration = values[2] }
    }
    func key(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    func doses(_ date: Date) -> [DoseRecord] { records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date } }
    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(routines), forKey: "routines")
        SharedData.records = records
        UserDefaults.standard.set(try? JSONEncoder().encode(notes), forKey: "notes")
        UserDefaults.standard.set(try? JSONEncoder().encode(tasks), forKey: "tasks")
        UserDefaults.standard.set([peakStart, peakEnd, duration], forKey: "intervals")
        SharedData.defaults.set(duration, forKey: "duration")
        WidgetCenter.shared.reloadAllTimelines()
    }
    func take(_ dose: Int, at date: Date, medication: String = "콘서타") { records.append(DoseRecord(date: date, dose: dose, medicationName: medication)); save() }
    func liveActivity() throws {
        guard let record = records.max(by: { $0.date < $1.date }), record.medication == "콘서타", record.date.addingTimeInterval(duration * 3600) > Date() else { return }
        guard Activity<MedicationActivity>.activities.isEmpty else { return }
        let state = MedicationActivity.ContentState(start: record.date, end: record.date.addingTimeInterval(duration * 3600), dose: record.dose)
        _ = try Activity.request(attributes: MedicationActivity(medication: "콘서타"), content: ActivityContent(state: state, staleDate: state.end), pushType: nil)
    }
}

let cardColor = Color(red: 0.953, green: 0.949, blue: 0.973)
let accent = Color(red: 0.10, green: 0.25, blue: 0.91)
let muted = Color.gray
let moodNames = ["아주 좋음", "좋음", "보통", "나쁨", "아주 나쁨"]
let moodColors: [Color] = [.mint, .green, .yellow, .orange, .pink]
func clock(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "a h:mm"; return f.string(from: date) }
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 18) { content }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(cardColor, in: RoundedRectangle(cornerRadius: 17)) }
}
struct Pill: View {
    let dose: Int
    var body: some View {
        if dose == 45 { VStack(spacing: 1) { pill(18); pill(27) }.frame(width: 52, height: 38) }
        else { pill(dose) }
    }
    func pill(_ value: Int) -> some View {
        Text("alza \(value)").font(.system(size: 9, weight: .medium)).foregroundStyle(.black.opacity(0.75)).frame(width: 49, height: 23).background(LinearGradient(colors: [color.opacity(0.6), color, color.opacity(0.8)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).stroke(.black.opacity(0.08)))
    }

    var color: Color { dose == 18 ? Color(red: 0.85, green: 0.72, blue: 0.36) : dose == 54 ? .brown : Color(white: dose == 27 ? 0.64 : 0.77) }
}
struct MoodFace: View {
    var index: Int
    var selected = false
    var body: some View {
        ZStack {
            Circle().fill(moodColors[index].opacity(selected ? 0.85 : 0.25)).overlay(Circle().stroke(selected ? accent : .gray, lineWidth: 2.5))
            Canvas { context, size in
                let w = size.width
                for x in [0.35, 0.65] { context.fill(Path(ellipseIn: CGRect(x: w*x-1.6, y: w*0.34, width: 3.2, height: 3.2)), with: .color(.gray)) }
                var p = Path(); p.move(to: CGPoint(x: w*0.33, y: w*0.63))
                p.addQuadCurve(to: CGPoint(x: w*0.67, y: w*0.63), control: CGPoint(x: w*0.5, y: w*(index < 2 ? 0.88 : index == 2 ? 0.63 : 0.40)))
                context.stroke(p, with: .color(.gray), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }.frame(width: 34, height: 34)
    }
}
