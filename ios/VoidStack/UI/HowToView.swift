import SwiftUI

struct HowToView: View {
    let isPad: Bool
    let onBack: () -> Void

    private let rules: [(String, Color)] = [
        ("Rote, pulsierende Stapel musst du wegschieben, bevor sie die vordere Kante erreichen.", Theme.marked),
        ("Blaue Stapel darfst du nicht wegschieben — lass sie einfach vorbeiziehen.", Theme.safe),
        ("Ein falsch geschobener blauer Stapel oder ein rot erreichtes Vorderfeld kostet ein Leben.", Theme.textDim),
        ("Ketten aus mehreren markierten Stapeln in Folge geben Combo-Bonus.", Theme.textDim),
        ("Mit steigendem Level wird das Tempo höher.", Theme.textDim),
    ]

    var body: some View {
        VStack(spacing: isPad ? 26 : 18) {
            Spacer()
            Text("SPIELREGELN")
                .font(.system(size: isPad ? 30 : 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(1.5)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(rules.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(rules[i].1).frame(width: 7, height: 7).padding(.top, 7)
                        Text(rules[i].0)
                            .font(.system(size: isPad ? 17 : 14))
                            .foregroundStyle(Color(white: 0.85))
                    }
                }
            }
            .frame(maxWidth: isPad ? 560 : 380, alignment: .leading)

            Button("ZURÜCK", action: onBack)
                .buttonStyle(SecondaryButtonStyle(isPad: isPad))
                .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.void.opacity(0.97))
    }
}
