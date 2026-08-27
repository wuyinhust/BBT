import SwiftUI

/// Reusable bottle amount control used by the quick-feeding flow.
/// It intentionally lives outside the retired detailed feeding recorder.
struct InteractiveBottleView: View {
    @Binding var amount: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color
    @State private var fillPulse = false

    private let bottleFillTop: CGFloat = 0.44
    private let bottleFillBottom: CGFloat = 0.954

    private var progress: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((amount - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Image("feeding_bottle_empty")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(0.8)

                Image("feeding_bottle_full")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .scaleEffect(fillPulse ? 1.012 : 1, anchor: .bottom)
                    .mask(alignment: .bottom) {
                        BottleMilkMask(
                            progress: progress,
                            topRatio: bottleFillTop,
                            bottomRatio: bottleFillBottom
                        )
                    }
                    .opacity(0.8)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: progress)

                BottleMilkSurfaceGlow(
                    progress: progress,
                    topRatio: bottleFillTop,
                    bottomRatio: bottleFillBottom,
                    tint: tint
                )
                .opacity(progress > 0.02 ? (fillPulse ? 0.58 : 0.30) : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: progress)
                .animation(.easeOut(duration: 0.16), value: fillPulse)
                .allowsHitTesting(false)

                Image("feeding_bottle_empty")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .blendMode(.multiply)
                    .opacity(0.34)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fillTop = proxy.size.height * bottleFillTop
                        let fillBottom = proxy.size.height * bottleFillBottom
                        let ratio = 1 - min(max((value.location.y - fillTop) / max(fillBottom - fillTop, 1), 0), 1)
                        let rawValue = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            amount = snapped(rawValue)
                        }
                    }
            )
        }
        .accessibilityLabel("奶瓶量")
        .accessibilityValue(AppMeasurementFormat.volume(amount))
        .onChange(of: amount) { _, _ in
            fillPulse = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 170_000_000)
                fillPulse = false
            }
        }
    }

    private func snapped(_ value: Double) -> Double {
        let snappedValue = (value / step).rounded() * step
        return min(max(snappedValue, range.lowerBound), range.upperBound)
    }
}

private struct BottleMilkMask: Shape {
    var progress: Double
    let topRatio: CGFloat
    let bottomRatio: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clamped = min(max(progress, 0), 1)
        let fillTopLimit = rect.minY + rect.height * topRatio
        let fillBottom = rect.minY + rect.height * bottomRatio
        let fillTop = fillBottom - (fillBottom - fillTopLimit) * clamped
        let wave = rect.height * 0.01

        path.move(to: CGPoint(x: rect.minX, y: fillBottom))
        path.addLine(to: CGPoint(x: rect.minX, y: fillTop))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: fillTop),
            control1: CGPoint(x: rect.minX + rect.width * 0.38, y: fillTop + wave),
            control2: CGPoint(x: rect.minX + rect.width * 0.62, y: fillTop - wave)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: fillBottom))
        path.closeSubpath()
        return path
    }
}

private struct BottleMilkSurfaceGlow: View {
    let progress: Double
    let topRatio: CGFloat
    let bottomRatio: CGFloat
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            let fillTopLimit = proxy.size.height * topRatio
            let fillBottom = proxy.size.height * bottomRatio
            let y = fillBottom - (fillBottom - fillTopLimit) * clamped

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignToken.glassFill.opacity(0.34),
                            tint.opacity(0.18),
                            DesignToken.glassFill.opacity(0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.width * 0.58, height: max(2, proxy.size.height * 0.009))
                .blur(radius: proxy.size.height * 0.002)
                .position(x: proxy.size.width * 0.50, y: y)
        }
    }
}
