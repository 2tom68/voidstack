import SwiftUI

struct MenuView: View {
    let isPad: Bool
    let onStart: () -> Void
    let onHowTo: () -> Void

    var body: some View {
        VStack(spacing: isPad ? 20 : 14) {
            Spacer()

            (Text("VOID").foregroundStyle(Theme.cyan) + Text("STACK").foregroundStyle(Theme.magenta))
                .font(.system(size: isPad ? 68 : 46, weight: .black, design: .rounded))
                .tracking(2)
                .glow(Theme.cyan, radius: 10)

            Text("Schiebe die markierten Stapel ins Nichts, bevor sie dich erreichen.")
                .font(.system(size: isPad ? 18 : 15))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: isPad ? 520 : 340)

            VStack(spacing: 12) {
                Button("START", action: onStart)
                    .buttonStyle(PrimaryButtonStyle(isPad: isPad))
                Button("SPIELREGELN", action: onHowTo)
                    .buttonStyle(SecondaryButtonStyle(isPad: isPad))
            }
            .padding(.top, 8)

            Text("Original-Spielkonzept & Umsetzung · keine Verbindung zu Sony oder Kurushi™/Intelligent Qube™")
                .font(.system(size: isPad ? 12 : 10))
                .foregroundStyle(Theme.textDim.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: isPad ? 520 : 320)
                .padding(.top, 26)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RadialGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.16), Theme.void], center: .center, startRadius: 10, endRadius: 500))
    }
}
