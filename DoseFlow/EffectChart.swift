import SwiftUI

struct EffectChart: View {
    var start: Date
    var peakStart: Double = 6
    var peakEnd: Double = 10
    var duration: Double = 12
    var mood: Int?
    @State private var cursor: CGFloat?
    private let total = 16.0
    func curve(_ size: CGSize, closed: Bool) -> Path {
        let w = size.width, h = size.height
        var p = Path(); p.move(to: CGPoint(x: 0, y: h))
        p.addCurve(to: CGPoint(x: w*0.065, y: h*0.5), control1: CGPoint(x: w*0.025, y: h*0.84), control2: CGPoint(x: w*0.04, y: h*0.56))
        p.addCurve(to: CGPoint(x: w*0.28, y: h*0.34), control1: CGPoint(x: w*0.13, y: h*0.40), control2: CGPoint(x: w*0.25, y: h*0.40))
        p.addCurve(to: CGPoint(x: w*0.5, y: h*0.025), control1: CGPoint(x: w*0.38, y: h*0.08), control2: CGPoint(x: w*0.43, y: h*0.025))
        p.addCurve(to: CGPoint(x: w, y: h*0.73), control1: CGPoint(x: w*0.60, y: h*0.15), control2: CGPoint(x: w*0.66, y: h*0.48))
        if closed { p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath() }; return p
    }
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    curve(geo.size, closed: true).fill(.gray.opacity(0.07))
                    HStack(spacing: 0) {
                        Color.clear.frame(width: geo.size.width*0.03)
                        shade(.cyan).frame(width: geo.size.width*0.065)
                        Color.clear.frame(width: geo.size.width*CGFloat(peakStart/total-0.095))
                        shade(.red).frame(width: geo.size.width*CGFloat((peakEnd-peakStart)/total))
                        shade(.purple).frame(width: geo.size.width*CGFloat((duration-peakEnd)/total))
                        Spacer(minLength: 0)
                    }.mask(curve(geo.size, closed: true))
                    curve(geo.size, closed: false).stroke(.black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                    if let cursor {
                        Rectangle().fill(.gray).frame(width: 1, height: geo.size.height).offset(x: cursor*geo.size.width)
                        Text(clock(start.addingTimeInterval(Double(cursor)*total*3600))).font(.system(size: 11, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 5).background(.white, in: Capsule()).overlay(Capsule().stroke(.gray.opacity(0.2))).position(x: min(max(cursor*geo.size.width, 35), geo.size.width-35), y: 10)
                    }
                }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { cursor = min(max($0.location.x/geo.size.width, 0), 1) })
            }.frame(height: 222)
            Divider().padding(.top, 12)
            HStack { Text(clock(start)); Spacer(); Text(clock(start.addingTimeInterval(total*3600))) }.font(.system(size: 9)).foregroundStyle(.secondary).padding(.top, 4)
            VStack(alignment: .leading) {
                Text("기분 기록").font(.system(size: 11))
                ZStack { if let mood { Circle().fill(moodColors[mood]).frame(width: 16, height: 16) }; if let cursor { GeometryReader { geo in Rectangle().fill(.gray).frame(width: 1, height: 37).offset(x: cursor*geo.size.width) } } }.frame(height: 40)
            }.padding(.top, 9)
        }
    }
    func shade(_ color: Color) -> some View { LinearGradient(colors: [color.opacity(0.48), color.opacity(0.025)], startPoint: .top, endPoint: .bottom) }
}
