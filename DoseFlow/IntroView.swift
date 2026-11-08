import SwiftUI
struct IntroView: View {
    @Environment(\.dismiss) var dismiss
    @State private var page = 0
    let titles = ["약효 흐름을 잠금화면에서", "진료용 리포트를 PDF로", "홈 화면에서 바로 기록", "기록과 목표를 한곳에", "약 먹은 날 흐름을 한눈에"]
    let subtitles = ["언제 오르고 언제 떨어지는지, 앱을 열지 않아도 보여요.", "복용·기분·메모를 한 파일로 정리해 진료에 가져가요.", "위젯으로 복용 기록과 예상 시간을 한눈에 봐요.", "매일의 기분과 목표를 차곡차곡 남겨요.", "복용 시간에 맞춰 예상 흐름을 확인해요."]
    var body: some View { NavigationStack { VStack(alignment: .leading, spacing: 20) {
        TabView(selection: $page) { ForEach(0..<5) { index in ZStack { RoundedRectangle(cornerRadius: 32).fill(Color(red: 0.85, green: 0.86, blue: 0.89)); preview(index).padding(24) }.padding(.horizontal, 20).tag(index) } }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: 330)
        HStack(spacing: 16) { ForEach(0..<5) { index in Circle().fill(page == index ? .black : .gray.opacity(0.25)).frame(width: 6, height: 6) } }.frame(maxWidth: .infinity)
        VStack(alignment: .leading, spacing: 18) { Text(titles[page]).font(.system(size: 28, weight: .bold)); Text(subtitles[page]).foregroundStyle(.gray); Label("잠금화면·다이내믹 아일랜드 실시간 예상", systemImage: "iphone"); Label("기록·목표·할 일 무제한", systemImage: "infinity"); Label("진료에 가져가는 PDF 리포트", systemImage: "doc.text") }.padding(.horizontal, 24)
        Spacer()
    }.toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundStyle(.black) } } } } }
    @ViewBuilder func preview(_ index: Int) -> some View {
        if index == 0 { VStack(alignment: .leading, spacing: 22) { HStack { Pill(dose: 36); Text("콘서타 36mg"); Spacer(); Text("6:42:10").font(.title.bold()) }; HStack(spacing: 5) { Capsule().fill(.cyan); Capsule().fill(.red); Capsule().fill(.gray) }.frame(height: 7); Text("상승 ~9:30 · 피크 ~15:30 · 감소 ~17:30").font(.caption).foregroundStyle(.gray) }.padding(20).foregroundStyle(.white).background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 27)) }
        else if index == 1 { VStack(alignment: .leading, spacing: 20) { Text("복용·컨디션 리포트").bold(); Text("2026.10.01 – 10.14").foregroundStyle(.gray); Image(systemName: "waveform.path").font(.system(size: 55)).foregroundStyle(accent); Text("27회 복용     8일 기분 기록").bold() }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 10)) }
        else if index == 2 { HStack { VStack(alignment: .leading, spacing: 10) { Pill(dose: 36); Text("콘서타").foregroundStyle(.gray); Text("6:42").font(.largeTitle.bold()); Text("예상 종료까지").font(.caption).foregroundStyle(.gray) }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 24)); VStack(alignment: .leading, spacing: 25) { Text("오늘 기록").foregroundStyle(.gray); HStack { Pill(dose: 36); Pill(dose: 18) } }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 24)) } }
        else if index == 3 { VStack(spacing: 20) { Text("오늘 어땠나요?").bold(); HStack { ForEach(0..<5) { MoodFace(index: $0) } }; Label("산책하기", systemImage: "checkmark.circle.fill").foregroundStyle(accent) }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 24)) }
        else { VStack(alignment: .leading) { Text("복용 · 예상 흐름").bold(); EffectChart(start: Date()) }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 24)).scaleEffect(0.9) }
    }
}
