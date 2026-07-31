import SwiftUI

struct TouchControlsView: View {
    let isPad: Bool
    let onLeft: () -> Void
    let onRight: () -> Void
    let onPush: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: isPad ? 28 : 18) {
                circleButton("chevron.left", size: isPad ? 76 : 60, action: onLeft)
                pushButton
                circleButton("chevron.right", size: isPad ? 76 : 60, action: onRight)
            }
            .padding(.bottom, isPad ? 34 : 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var pushButton: some View {
        Button(action: onPush) {
            Text("PUSH")
                .font(.system(size: isPad ? 17 : 13, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(Theme.marked)
                .frame(width: isPad ? 108 : 84, height: isPad ? 108 : 84)
                .background(Theme.panel.opacity(0.9))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.marked.opacity(0.45), lineWidth: 1.5))
                .shadow(color: Theme.marked.opacity(0.45), radius: 16)
        }
        .buttonStyle(PressScaleStyle())
    }

    private func circleButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(Theme.cyan)
                .frame(width: size, height: size)
                .background(Theme.panel.opacity(0.85))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.cyan.opacity(0.4), lineWidth: 1.5))
                .shadow(color: Theme.cyan.opacity(0.35), radius: 12)
        }
        .buttonStyle(PressScaleStyle())
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
