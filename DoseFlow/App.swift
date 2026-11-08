import SwiftUI

@main struct DoseFlowApp: App {
    @StateObject private var store = Store()
    @StateObject private var health = HealthStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(store).environmentObject(health).tint(accent).preferredColorScheme(.light) } }
}
struct RootView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("복약", systemImage: "pills.fill") }
            NotesView().tabItem { Label("기록", systemImage: "list.clipboard") }
            TasksView().tabItem { Label("할 일", systemImage: "checklist") }
            CalendarScreen().tabItem { Label("달력", systemImage: "calendar") }
            SettingsView().tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}
struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var date = Date()
    @State private var dose = 18
    @State private var medication = "콘서타"
    @State private var customName = ""
    @State private var medicationSheet = false
    var selectedName: String { medication == "기타" ? customName.trimmingCharacters(in: .whitespacesAndNewlines) : medication }
    @State private var doseSheet = false
    @State private var dateSheet = false
    @State private var report = false
    @State private var intervals = false
    @State private var noteSheet = false
    @State private var routine = false
    @State private var confirm = false
    var latest: DoseRecord? { store.records.filter { $0.date <= date }.max { $0.date < $1.date } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let record = latest, record.medication == "콘서타" {
                        Card {
                            Text(status(record)).font(.system(size: 29, weight: .bold)).foregroundStyle(.gray)
                            Text("콘서타 \(record.dose)mg · \(clock(record.date)) 복용 · \(Int(max(0, date.timeIntervalSince(record.date)/3600)))시간 지남").font(.system(size: 14))
                            HStack { Text("콘서타").font(.title3.bold()); Image(systemName: "info.circle").font(.caption).foregroundStyle(.gray); Spacer(); Button("구간 조정") { intervals = true }.font(.caption.bold()).foregroundStyle(.gray).padding(8).background(.gray.opacity(0.08), in: Capsule()) }.padding(.top, 8)
                            HStack { legend("1차", .cyan, "0:30~1:30", record.date); Spacer(); legend("최대농도", .red, "\(Int(store.peakStart))~\(Int(store.peakEnd))시간", record.date); Spacer(); legend("감소", .purple, "\(Int(store.peakEnd))~\(Int(store.duration))시간", record.date) }
                            EffectChart(start: record.date, peakStart: store.peakStart, peakEnd: store.peakEnd, duration: store.duration, mood: store.notes[store.key(date)]?.mood)
                            HStack(spacing: 16) { Image(systemName: "chart.bar.fill").foregroundStyle(accent); VStack(alignment: .leading, spacing: 6) { HStack { Text("개인 반응 예상").bold(); Text("기록 수집 중").foregroundStyle(accent).bold() }.font(.system(size: 12)); Text("심박 반응 예상을 검증할 기록을 모으고 있어요.").font(.system(size: 11)).foregroundStyle(.gray) }; Spacer(); Image(systemName: "info.circle").foregroundStyle(.gray) }.padding(16).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
                            Text("그래프는 설정한 구간에 따른 참고용 예상이며 실제 혈중농도 측정값이 아닙니다.").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    HealthCard(date: date, record: latest)
                    Card {
                        Text("오늘 어땠나요?").font(.headline)
                        HStack { ForEach(0..<5) { index in Button { var note = store.notes[store.key(date)] ?? DayNote(); note.mood = index; store.notes[store.key(date)] = note; store.save() } label: { VStack(spacing: 8) { MoodFace(index: index, selected: store.notes[store.key(date)]?.mood == index); Text(moodNames[index]).font(.system(size: 10)).foregroundStyle(.gray) }.frame(maxWidth: .infinity) } } }
                        Divider(); Button { noteSheet = true } label: { Label("메모 남기기", systemImage: "square.and.pencil").foregroundStyle(.gray) }
                    }
                    Card {
                        Text("오늘 복용 기록").font(.headline)
                        if store.doses(date).isEmpty { VStack(spacing: 12) { Image(systemName: "pills").foregroundStyle(.gray); Text("오늘 기록이 없어요").font(.headline); Text("복용한 약을 기록하면, 아래 목록에 쌓이고\n위쪽에서 약효 그래프가 바로 보여요").font(.caption).foregroundStyle(.gray).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 22) }
                        ForEach(store.doses(date)) { record in HStack { Text(clock(record.date)).font(.caption).foregroundStyle(.gray); if record.medication == "콘서타" { Pill(dose: record.dose) } else { Image(systemName: "pills") }; Text("\(record.medication) \(record.dose)mg").bold(); Spacer(); Button(role: .destructive) { store.records.removeAll { $0.id == record.id }; store.save() } label: { Image(systemName: "trash").font(.caption) } } }
                    }
                    Card {
                        Text("복용").font(.headline)
                        HStack { Button { medicationSheet = true } label: { HStack { Label(medication, systemImage: "pills"); Spacer(); Image(systemName: "chevron.down").font(.caption) }.foregroundStyle(.primary).padding().background(.white, in: RoundedRectangle(cornerRadius: 20)) }; Text("\(store.doses(date).count+1)회차").font(.caption).foregroundStyle(.gray); Button { doseSheet = true } label: { HStack { Text("\(dose)mg"); Image(systemName: "chevron.down").font(.caption2) }.foregroundStyle(.black).padding().background(.white, in: RoundedRectangle(cornerRadius: 20)) } }
                        if medication == "기타" { TextField("약 이름", text: $customName).padding().background(.white, in: RoundedRectangle(cornerRadius: 16)) }
                        Button("지금 복용") { confirm = true }.buttonStyle(PrimaryButton()).disabled(dose <= 0 || selectedName.isEmpty)
                        ForEach(store.routines.filter { !$0.items.isEmpty }) { saved in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(saved.title).font(.headline)
                                ForEach(saved.items) { item in Text("\(item.name) \(item.dose)mg").font(.subheadline).foregroundStyle(.secondary) }
                            }
                        }
                        Button("복용 루틴 만들기") { routine = true }.buttonStyle(PrimaryButton(white: true))
                    }
                }.padding(.horizontal, 8).padding(.bottom, 20)
            }.navigationTitle(date.formatted(.dateTime.month(.defaultDigits).day().weekday(.wide).locale(Locale(identifier: "ko_KR")))).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button { dateSheet = true } label: { Image(systemName: "calendar") } }; ToolbarItem(placement: .topBarTrailing) { Button { report = true } label: { Label("리포트", systemImage: "doc.text") } } }
                .sheet(isPresented: $doseSheet) { DosePicker(dose: $dose, medication: medication) }
                .sheet(isPresented: $medicationSheet) { MedicationPicker(medication: $medication) }
                .onChange(of: medication) { dose = medication == "콘서타" ? 18 : 0 }
                .sheet(isPresented: $dateSheet) { DatePicker("기록 날짜", selection: $date, displayedComponents: [.date]).datePickerStyle(.graphical).padding().presentationDetents([.medium]) }
                .sheet(isPresented: $noteSheet) { NoteEditor(date: date) }
                .sheet(isPresented: $intervals) { IntervalEditor() }
                .sheet(isPresented: $report) { ReportView() }
                .sheet(isPresented: $routine) { RoutineView() }
                .confirmationDialog("\(selectedName) \(dose)mg 복용을 기록할까요?", isPresented: $confirm, titleVisibility: .visible) { Button("복용 기록 저장") { store.take(dose, at: Date(), medication: selectedName); date = Date() } }
        }
    }
    func status(_ record: DoseRecord) -> String { let h = date.timeIntervalSince(record.date)/3600; return h < store.peakStart ? "상승" : h < store.peakEnd ? "최대농도" : h < store.duration ? "감소" : "잔효" }
    func legend(_ title: String, _ color: Color, _ time: String, _ date: Date) -> some View { VStack(alignment: .leading, spacing: 6) { HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8); Text(title).bold() }; Text(time).foregroundStyle(.gray) }.font(.system(size: 10)) }
}
struct PrimaryButton: ButtonStyle {
    var white = false
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 18).foregroundStyle(white ? .black : .white).background(white ? .white : accent, in: RoundedRectangle(cornerRadius: 18)).opacity(configuration.isPressed ? 0.7 : 1) }
}
