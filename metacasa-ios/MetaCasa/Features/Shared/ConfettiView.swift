import SwiftUI

/// Confetti overlay — se dispara cuando `trigger` cambia de false a true.
/// 40 partículas con colores brand, cayendo desde arriba con rotación random.
/// Auto-dismiss después de `duration` segundos.
///
/// Uso:
/// ```swift
/// .overlay { ConfettiOverlay(trigger: goalJustCompleted) }
/// ```
struct ConfettiOverlay: View {
    let trigger: Bool

    @State private var fireId = UUID()
    @State private var showParticles = false

    var body: some View {
        ZStack {
            if showParticles {
                GeometryReader { geo in
                    ZStack {
                        ForEach(0..<50, id: \.self) { i in
                            ConfettiParticle(
                                id: fireId,
                                index: i,
                                canvasWidth: geo.size.width,
                                canvasHeight: geo.size.height
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }
        }
        .onChange(of: trigger) { _, newValue in
            if newValue {
                fireId = UUID()
                showParticles = true
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        showParticles = false
                    }
                }
            }
        }
    }
}

private struct ConfettiParticle: View {
    let id: UUID // cambia al re-disparar → forces onAppear
    let index: Int
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    @State private var yPosition: CGFloat = -50
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    private var color: Color {
        [Color.brandPrimary, .brandSecondary, .brandSuccess, .brandWarning, .brandDanger][index % 5]
    }

    private var symbol: String {
        ["circle.fill", "square.fill", "star.fill", "triangle.fill", "seal.fill", "heart.fill"][index % 6]
    }

    private var size: CGFloat {
        CGFloat.random(in: 10...22)
    }

    private var xStart: CGFloat {
        CGFloat.random(in: 0...canvasWidth)
    }

    private var xDrift: CGFloat {
        CGFloat.random(in: -60...60)
    }

    private var delay: Double {
        Double(index) * 0.02
    }

    private var duration: Double {
        Double.random(in: 1.8...2.8)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .position(
                x: xStart + xDrift * CGFloat((yPosition + 50) / (canvasHeight + 100)),
                y: yPosition
            )
            .onAppear {
                withAnimation(.linear(duration: duration).delay(delay)) {
                    yPosition = canvasHeight + 100
                    rotation = Double.random(in: 360...1080) * (Bool.random() ? 1 : -1)
                }
                withAnimation(.linear(duration: 0.6).delay(delay + duration - 0.6)) {
                    opacity = 0
                }
            }
            .id(id)
    }
}
