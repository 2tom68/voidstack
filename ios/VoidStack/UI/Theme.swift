import SwiftUI

enum Theme {
    static let void = Color(red: 0x05/255, green: 0x03/255, blue: 0x0f/255)
    static let panel = Color(red: 0x0c/255, green: 0x09/255, blue: 0x20/255)
    static let cyan = Color(red: 0x4b/255, green: 0xe9/255, blue: 0xff/255)
    static let magenta = Color(red: 0xff/255, green: 0x3e/255, blue: 0xc8/255)
    static let marked = Color(red: 0xff/255, green: 0x3e/255, blue: 0x6a/255)
    static let safe = Color(red: 0x3e/255, green: 0xc8/255, blue: 0xff/255)
    static let amber = Color(red: 0xff/255, green: 0xb6/255, blue: 0x3e/255)
    static let textDim = Color(red: 0x8f/255, green: 0xb4/255, blue: 0xd9/255)
}

struct GlowText: ViewModifier {
    let color: Color
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius)
            .shadow(color: color.opacity(0.6), radius: radius * 2.4)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 8) -> some View {
        modifier(GlowText(color: color, radius: radius))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isPad: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isPad ? 22 : 17, weight: .heavy, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(Theme.void)
            .padding(.vertical, isPad ? 18 : 14)
            .padding(.horizontal, isPad ? 52 : 38)
            .background(
                LinearGradient(colors: [Theme.cyan, Color(red: 0.49, green: 0.99, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Theme.cyan.opacity(0.6), radius: 18)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var isPad: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isPad ? 20 : 15, weight: .heavy, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(.white)
            .padding(.vertical, isPad ? 16 : 12)
            .padding(.horizontal, isPad ? 44 : 32)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cyan.opacity(0.35), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
