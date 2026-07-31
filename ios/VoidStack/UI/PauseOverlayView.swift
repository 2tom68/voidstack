import SwiftUI

struct PauseOverlayView: View {
    let isPad: Bool
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("PAUSE")
                .font(.system(size: isPad ? 30 : 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(2)
            Button("WEITER", action: onResume)
                .buttonStyle(PrimaryButtonStyle(isPad: isPad))
            Button("HAUPTMENÜ", action: onQuit)
                .buttonStyle(SecondaryButtonStyle(isPad: isPad))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(Theme.void.opacity(0.55))
    }
}
