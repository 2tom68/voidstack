import SwiftUI

struct GameOverView: View {
    let isPad: Bool
    let score: Int
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("GAME OVER")
                .font(.system(size: isPad ? 30 : 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(2)
            Text("\(score)")
                .font(.system(size: isPad ? 76 : 58, weight: .black, design: .rounded))
                .foregroundStyle(Theme.amber)
                .glow(Theme.amber, radius: 10)
                .monospacedDigit()
            Text("PUNKTE")
                .font(.system(size: isPad ? 14 : 12, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Theme.textDim)
                .padding(.bottom, 14)

            Button("NOCHMAL", action: onRetry)
                .buttonStyle(PrimaryButtonStyle(isPad: isPad))
            Button("HAUPTMENÜ", action: onMenu)
                .buttonStyle(SecondaryButtonStyle(isPad: isPad))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.void.opacity(0.96))
    }
}
