import Combine
import Foundation

enum AppScreen {
    case menu, howto, playing, paused, gameOver
}

@MainActor
final class GameController: ObservableObject {
    let game = GameEngine()
    let audio = AudioEngine()
    let scene = GameSceneCoordinator()

    @Published var screen: AppScreen = .menu
    @Published var dangerCols: Set<Int> = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        scene.onFrame = { [weak self] dtMs in
            guard let self else { return }
            Task { @MainActor in
                self.tick(dtMs: dtMs)
            }
        }
        game.events
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &cancellables)
    }

    private func tick(dtMs: Double) {
        game.update(dtMs: dtMs)
        dangerCols = game.dangerCols
        scene.setDangerCols(dangerCols)
        scene.setSelected(game.selectedCol)
    }

    private func handle(_ event: GameEvent) {
        switch event {
        case .selected(let col):
            scene.setSelected(col)
        case .spawned(let stack):
            scene.spawnStack(stack)
        case .advanced(let stack):
            scene.rollStack(stack)
            audio.playRoll()
        case .clearedMarked(let stack, _, let combo):
            scene.removeStack(id: stack.id)
            scene.burst(col: stack.col, row: stack.row, marked: true)
            audio.playClearMarked(combo: combo)
        case .pushedSafe(let stack):
            scene.removeStack(id: stack.id)
            audio.playPushFail()
            scene.shake(amp: 0.28, duration: 0.3)
        case .pushEmpty:
            audio.playSelect()
        case .passedSafe(let stack):
            scene.removeStack(id: stack.id)
        case .lifeLost(let reason, let stack, _):
            scene.shake(amp: 0.45, duration: 0.4)
            if reason == .escaped, let stack {
                scene.removeStack(id: stack.id)
                scene.burst(col: stack.col, row: 0, marked: true)
                audio.playEscapeAlarm()
            }
        case .levelUp:
            audio.playLevelUp()
        case .gameOver:
            audio.playGameOver()
            audio.stopAmbient()
            screen = .gameOver
        case .reset, .started:
            break
        }
    }

    func startGame() {
        audio.resume()
        audio.startAmbient()
        scene.clearStacks()
        game.reset()
        game.start()
        screen = .playing
    }

    func pauseGame() {
        guard screen == .playing else { return }
        game.isRunning = false
        screen = .paused
    }

    func resumeGame() {
        game.isRunning = true
        screen = .playing
    }

    func quitToMenu() {
        audio.stopAmbient()
        game.isRunning = false
        screen = .menu
    }

    func selectLeft() {
        game.selectDelta(-1)
        audio.playSelect()
    }

    func selectRight() {
        game.selectDelta(1)
        audio.playSelect()
    }

    func selectColumn(_ col: Int) {
        game.selectCol(col)
        audio.playSelect()
    }

    func pushSelected() {
        game.push()
    }
}
