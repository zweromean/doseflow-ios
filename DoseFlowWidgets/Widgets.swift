import SwiftUI
import WidgetKit
import ActivityKit

struct DoseEntry: TimelineEntry { var date: Date; var record: DoseRecord? }
struct DoseProvider: TimelineProvider {
    func placeholder(in context: Context) -> DoseEntry { DoseEntry(date: Date(), record: DoseRecord(date: Date(), dose: 18)) }
    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> Void) { completion(DoseEntry(date: Date(), record: SharedData.records.max { $0.date < $1.date })) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) { completion(Timeline(entries: [DoseEntry(date: Date(), record: SharedData.records.max { $0.date < $1.date })], policy: .after(Date().addingTimeInterval(900)))) }
}
struct DoseWidget: Widget {
    let kind = "DoseWidget"
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: DoseProvider()) { entry in
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "pills.fill").foregroundStyle(.blue)
            if let record = entry.record {
                Text("\(record.medication) \(record.dose)mg").foregroundStyle(.secondary)
                let hours = SharedData.defaults.double(forKey: "duration")
                let end = record.date.addingTimeInterval((hours > 0 ? hours : 12)*3600)
                if record.medication == "콘서타", end > Date() { Text(timerInterval: Date()...end, countsDown: true).font(.largeTitle.bold()); Text("예상 종료까지").font(.caption).foregroundStyle(.secondary) } else { Text("복용 기록").font(.headline); Text(record.date, style: .time) }
            } else { Text("오늘 기록이 없어요").font(.headline); Text("앱에서 복용을 기록해요").font(.caption) }
        }.frame(maxWidth: .infinity, alignment: .leading).containerBackground(.white, for: .widget)
    }.configurationDisplayName("복약 기록").description("최근 복용 기록과 예상 시간을 확인하세요.").supportedFamilies([.systemSmall, .systemMedium]) }
}
struct MedicationLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MedicationActivity.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack { Image(systemName: "pills.fill"); Text("\(context.attributes.medication) \(context.state.dose)mg"); Spacer(); Text(timerInterval: context.state.start...context.state.end, countsDown: true).font(.title.bold()).monospacedDigit().frame(width: 125) }
                ProgressView(timerInterval: context.state.start...context.state.end, countsDown: false).tint(.cyan)
                Text("복용 후 예상 흐름 · 개인차가 있어요").font(.caption).foregroundStyle(.secondary)
            }.padding(22).activityBackgroundTint(Color(white: 0.14)).activitySystemActionForegroundColor(.white).foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("\(context.state.dose)mg", systemImage: "pills.fill") }
                DynamicIslandExpandedRegion(.trailing) { Text(timerInterval: context.state.start...context.state.end, countsDown: true).monospacedDigit().frame(width: 95) }
                DynamicIslandExpandedRegion(.bottom) { Text("\(context.attributes.medication) · 예상 종료까지").font(.caption) }
            } compactLeading: { Image(systemName: "pills.fill").foregroundStyle(.cyan) } compactTrailing: { Text(timerInterval: context.state.start...context.state.end, countsDown: true).monospacedDigit().frame(width: 65) } minimal: { Image(systemName: "pills.fill") }
        }
    }
}
@main struct DoseWidgetBundle: WidgetBundle { var body: some Widget { DoseWidget(); MedicationLiveWidget() } }
