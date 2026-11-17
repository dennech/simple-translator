import SwiftUI

struct TranslationActivity: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !active || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3) { index in
                    let wave = reduceMotion ? 0.5 : (sin(time * 3.2 - Double(index) * 0.85) + 1) / 2
                    Circle().fill(.blue.opacity(0.35 + wave * 0.55))
                        .frame(width: 4, height: 4)
                        .offset(y: reduceMotion ? 0 : -2.5 * wave)
                }
            }
        }
        .frame(width: 22, height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Перевод идёт")
        .accessibilityHidden(!active)
        .allowsHitTesting(false)
    }
}

struct TranslationPaneBackground: View {
    let working: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            LinearGradient(colors: [.blue.opacity(colorScheme == .dark ? 0.065 : 0.03), .indigo.opacity(0.025)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !working || reduceMotion)) { timeline in
                let phase = reduceMotion ? 0 : sin(timeline.date.timeIntervalSinceReferenceDate * 0.65)
                GeometryReader { geometry in
                    ZStack {
                        RadialGradient(colors: [.blue.opacity(0.10), .clear],
                            center: UnitPoint(x: 0.22 + phase * 0.12, y: 0.18),
                            startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.8)
                        RadialGradient(colors: [.indigo.opacity(0.07), .clear],
                            center: UnitPoint(x: 0.82 - phase * 0.12, y: 0.8),
                            startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.75)
                    }
                }
            }
            .opacity(working ? 1 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: working)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
