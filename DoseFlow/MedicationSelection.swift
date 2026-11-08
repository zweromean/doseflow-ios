import SwiftUI

let medicationNames = ["콘서타", "메디키넷", "아토목세틴", "페니드", "기타"]
struct MedicationItem: Identifiable, Codable {
    var id = UUID()
    var name = "콘서타"
    var dose = 18
}
struct MedicationRoutine: Identifiable, Codable {
    var id = UUID()
    var title: String
    var items: [MedicationItem] = []
}

struct SheetHeader: View {
    var title: String
    var close: () -> Void
    var save: (() -> Void)? = nil
    var body: some View {
        ZStack {
            Text(title).font(.headline)
            HStack {
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 17)).foregroundStyle(.gray).frame(width: 44, height: 44).background(.white.opacity(0.7), in: Circle()).overlay(Circle().stroke(.gray.opacity(0.15))) }.accessibilityLabel("닫기")
                Spacer()
                if let save { Button("저장", action: save).foregroundStyle(accent).frame(width: 44, height: 44).overlay(Circle().stroke(.gray.opacity(0.15))) }
            }
        }.padding(14).background(.white)
    }
}
struct MedicationPicker: View {
    @Binding var medication: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "약 종류 선택", close: { dismiss() })
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(medicationNames, id: \.self) { name in
                        Button { medication = name; dismiss() } label: {
                            HStack { Text(name); Spacer(); if medication == name { Image(systemName: "checkmark").foregroundStyle(accent) } }.foregroundStyle(.primary).frame(minHeight: 72).contentShape(Rectangle())
                        }
                        Divider()
                    }
                }.padding(.horizontal, 16)
            }.background(Color(white: 0.94))
        }.presentationDetents([.height(460), .large]).presentationCornerRadius(36).presentationDragIndicator(.hidden)
    }
}
struct DosePicker: View {
    @Binding var dose: Int
    var medication = "콘서타"
    @Environment(\.dismiss) private var dismiss
    @State private var custom = ""
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "용량 선택", close: { dismiss() })
            ScrollView {
                if medication == "콘서타" {
                    VStack(spacing: 0) {
                        ForEach([18,27,36,45,54], id: \.self) { value in
                            Button { dose = value; dismiss() } label: {
                                HStack(spacing: 18) {
                                    Pill(dose: value).frame(width: 58)
                                    VStack(alignment: .leading, spacing: 8) { Text("\(value)mg"); if value == 45 { Text("18mg + 27mg").font(.caption).foregroundStyle(.gray) } }
                                    Spacer()
                                    if dose == value { Image(systemName: "checkmark").foregroundStyle(accent) }
                                }.foregroundStyle(.primary).frame(minHeight: 72).contentShape(Rectangle())
                            }
                            Divider().padding(.leading, 76)
                        }
                    }.padding(.horizontal, 16)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("처방받은 용량을 입력해 주세요.").font(.subheadline).foregroundStyle(.secondary)
                        HStack { TextField("용량", text: $custom).keyboardType(.numberPad); Text("mg") }.padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
                        Button("선택") { if let value = Int(custom), value > 0 { dose = value; dismiss() } }.buttonStyle(PrimaryButton()).disabled((Int(custom) ?? 0) <= 0)
                    }.padding(20)
                }
            }.background(Color(white: 0.94))
        }.onAppear { custom = String(dose) }.presentationDetents([.height(460), .large]).presentationCornerRadius(36).presentationDragIndicator(.hidden)
    }
}
struct RoutineView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [MedicationRoutine] = []
    @State private var addTo: UUID?
    @State private var editingItem: MedicationItem?
    @State private var editor = false
    @State private var renameID: UUID?
    @State private var name = ""
    @State private var rename = false
    @State private var adding = false
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "루틴 만들기", close: { dismiss() }, save: { store.routines = draft; store.save(); dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Button { name = ""; adding = true; rename = true } label: { HStack { Image(systemName: "plus"); Text("새 루틴 추가").bold(); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.gray) }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 26)) }
                    ForEach(draft) { routine in
                        VStack(spacing: 18) {
                            HStack {
                                Text(routine.title).font(.headline).foregroundStyle(.gray)
                                Spacer()
                                Button { renameID = routine.id; name = routine.title; adding = false; rename = true } label: { Image(systemName: "pencil").foregroundStyle(.gray) }.accessibilityLabel("\(routine.title) 이름 편집")
                            }.padding(.horizontal, 16)
                            VStack(alignment: .leading, spacing: 16) {
                                if routine.items.isEmpty { Text("\(routine.title)에 추가된 약이 아직 없어요.").foregroundStyle(.gray).font(.subheadline) }
                                ForEach(routine.items) { item in
                                    HStack {
                                        Button { addTo = routine.id; editingItem = item; editor = true } label: { Text("\(item.name) \(item.dose)mg").foregroundStyle(.primary) }
                                        Spacer()
                                        Button(role: .destructive) { if let i = draft.firstIndex(where: { $0.id == routine.id }) { draft[i].items.removeAll { $0.id == item.id } } } label: { Image(systemName: "minus.circle") }.accessibilityLabel("약 삭제")
                                    }
                                }
                                Divider()
                                Button { addTo = routine.id; editingItem = nil; editor = true } label: { Label("\(routine.title)에 약 추가", systemImage: "plus").foregroundStyle(.gray) }
                            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 26))
                            if !["아침", "점심", "저녁"].contains(routine.title) { Button("루틴 삭제", role: .destructive) { draft.removeAll { $0.id == routine.id } }.font(.caption) }
                        }.padding(.top, 14)
                    }
                }.padding(16).padding(.vertical, 18)
            }.background(cardColor)
        }.onAppear { draft = store.routines }
            .alert(adding ? "새 루틴 추가" : "루틴 이름", isPresented: $rename) {
                TextField("이름", text: $name)
                Button("취소", role: .cancel) {}
                Button("완료") { let title = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }; if adding { draft.append(MedicationRoutine(title: title)) } else if let i = draft.firstIndex(where: { $0.id == renameID }) { draft[i].title = title } }
            }
            .sheet(isPresented: $editor) {
                RoutineMedicationEditor(initial: editingItem) { item in
                    guard let i = draft.firstIndex(where: { $0.id == addTo }) else { return }
                    if let j = draft[i].items.firstIndex(where: { $0.id == item.id }) { draft[i].items[j] = item } else { draft[i].items.append(item) }
                }
            }.presentationDetents([.large]).presentationCornerRadius(36).presentationDragIndicator(.hidden)
    }
}
struct RoutineMedicationEditor: View {
    var initial: MedicationItem?
    var save: (MedicationItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var medication = "콘서타"
    @State private var customName = ""
    @State private var dose = 18
    @State private var selectingMedication = false
    @State private var selectingDose = false
    init(initial: MedicationItem?, save: @escaping (MedicationItem) -> Void) {
        self.initial = initial
        self.save = save
        _medication = State(initialValue: initial.map { medicationNames.contains($0.name) ? $0.name : "기타" } ?? "콘서타")
        _customName = State(initialValue: initial?.name ?? "")
        _dose = State(initialValue: initial?.dose ?? 18)
    }
    var body: some View {
        NavigationStack {
            Form {
                Button { selectingMedication = true } label: { HStack { Text("약 종류"); Spacer(); Text(medication) } }
                if medication == "기타" { TextField("약 이름", text: $customName) }
                Button { selectingDose = true } label: { HStack { Text("용량"); Spacer(); Text("\(dose)mg") } }
            }.navigationTitle("루틴에 약 추가").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("저장") { save(MedicationItem(id: initial?.id ?? UUID(), name: medication == "기타" ? customName.trimmingCharacters(in: .whitespacesAndNewlines) : medication, dose: dose)); dismiss() }.disabled(dose <= 0 || (medication == "기타" && customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) } }
        }
            .onChange(of: medication) { dose = medication == "콘서타" ? 18 : 0 }
            .sheet(isPresented: $selectingMedication) { MedicationPicker(medication: $medication) }
            .sheet(isPresented: $selectingDose) { DosePicker(dose: $dose, medication: medication) }
    }
}
