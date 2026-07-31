import SwiftUI

struct ContentView: View {
    @StateObject private var controller = GameController()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ZStack {
            GameSceneView(
                coordinator: controller.scene,
                onSwipeLeft: controller.selectLeft,
                onSwipeRight: controller.selectRight
            )
                .ignoresSafeArea()

            if controller.screen == .playing || controller.screen == .paused {
                HUDView(
                    game: controller.game,
                    dangerActive: !controller.dangerCols.isEmpty,
                    isPad: isPad
                )

                VStack {
                    HStack {
                        Spacer()
                        pauseButton
                    }
                    Spacer()
                }
                .padding(isPad ? 20 : 12)

                if controller.screen == .playing {
                    TouchControlsView(
                        isPad: isPad,
                        onLeft: controller.selectLeft,
                        onRight: controller.selectRight,
                        onPush: controller.pushSelected
                    )
                }
            }

            switch controller.screen {
            case .menu:
                MenuView(isPad: isPad, onStart: controller.startGame, onHowTo: { controller.screen = .howto })
            case .howto:
                HowToView(isPad: isPad, onBack: { controller.screen = .menu })
            case .paused:
                PauseOverlayView(isPad: isPad, onResume: controller.resumeGame, onQuit: controller.quitToMenu)
            case .gameOver:
                GameOverView(isPad: isPad, score: controller.game.score, onRetry: controller.startGame, onMenu: controller.quitToMenu)
            case .playing:
                EmptyView()
            }
        }
        .background(Color.black)
        .statusBarHidden(true)
        .onChange(of: controller.screen) { _, newValue in
            if newValue != .playing { /* keep ambient running through pause; stopped explicitly on gameOver/menu */ }
        }
    }

    private var pauseButton: some View {
        Button(action: controller.pauseGame) {
            Image(systemName: "pause.fill")
                .font(.system(size: isPad ? 16 : 13, weight: .bold))
                .foregroundStyle(Theme.cyan)
                .frame(width: isPad ? 44 : 36, height: isPad ? 44 : 36)
                .background(Theme.panel.opacity(0.85))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.cyan.opacity(0.4), lineWidth: 1))
        }
        .opacity(controller.screen == .playing ? 1 : 0)
        .allowsHitTesting(controller.screen == .playing)
    }
}
