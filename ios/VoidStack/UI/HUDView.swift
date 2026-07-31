import SwiftUI

struct HUDView: View {
    @ObservedObject var game: GameEngine
    let dangerActive: Bool
    let isPad: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: isPad ? 28 : 18) {
                stat("SCORE", "\(game.score)")
                stat("LEVEL", "\(game.level)")
                stat("COMBO", "×\(game.combo)")
                HStack(spacing: 4) {
                    ForEach(0..<GameEngine.startLives, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i < game.lives ? Theme.marked : Color.white.opacity(0.15))
                            .frame(width: isPad ? 16 : 13, height: isPad ? 16 : 13)
                            .rotationEffect(.degrees(45))
                            .shadow(color: i < game.lives ? Theme.marked.opacity(0.8) : .clear, radius: 6)
                    }
                }
            }
            .padding(.horizontal, isPad ? 22 : 16)
            .padding(.vertical, isPad ? 12 : 8)
            .background(Theme.panel.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cyan.opacity(0.25), lineWidth: 1))
            .shadow(color: Theme.cyan.opacity(0.2), radius: 18)

            if dangerActive {
                Text("GEFAHR")
                    .font(.system(size: isPad ? 15 : 12, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(LinearGradient(colors: [Theme.marked, Theme.amber], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Theme.marked.opacity(0.6), radius: 10)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, isPad ? 24 : 12)
        .padding(.top, isPad ? 20 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: isPad ? 12 : 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.textDim)
            Text(value)
                .font(.system(size: isPad ? 24 : 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.cyan)
                .glow(Theme.cyan, radius: 4)
                .monospacedDigit()
        }
    }
}
