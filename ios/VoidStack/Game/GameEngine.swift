import Foundation
import Combine

/// VOIDSTACK — core game logic. Ported 1:1 from the web version's game.js so both
/// platforms share identical rules. Original ruleset; no third-party game logic used.

struct Stack: Identifiable, Equatable {
    let id: Int
    var col: Int
    var row: Int
    let height: Int
    let marked: Bool
}

enum GameEvent {
    case reset
    case started
    case selected(Int)
    case spawned(Stack)
    case advanced(Stack)
    case clearedMarked(stack: Stack, gained: Int, combo: Int)
    case pushedSafe(Stack)
    case pushEmpty(col: Int)
    case passedSafe(Stack)
    case lifeLost(reason: LifeLostReason, stack: Stack?, lives: Int)
    case levelUp(Int)
    case gameOver(score: Int, bestCombo: Int, level: Int)
}

enum LifeLostReason {
    case pushedSafe
    case escaped
}

@MainActor
final class GameEngine: ObservableObject {
    static let cols = 5
    static let rows = 9
    static let startLives = 3

    private static let baseTickMs: Double = 950
    private static let minTickMs: Double = 340
    private static let tickStepPerLevel: Double = 55
    private static let clearsPerLevel = 8

    @Published private(set) var score = 0
    @Published private(set) var combo = 0
    @Published private(set) var bestCombo = 0
    @Published private(set) var level = 1
    @Published private(set) var lives = startLives
    @Published private(set) var selectedCol = GameEngine.cols / 2
    @Published private(set) var isGameOver = false
    @Published private(set) var stacksByCol: [Int: Stack] = [:]

    var isRunning = false
    let events = PassthroughSubject<GameEvent, Never>()

    private var clearsThisLevel = 0
    private var accumMs: Double = 0
    private var nextId = 1

    var stacks: [Stack] { Array(stacksByCol.values) }

    var tickMs: Double {
        max(Self.minTickMs, Self.baseTickMs - Double(level - 1) * Self.tickStepPerLevel)
    }

    var dangerCols: Set<Int> {
        Set(stacksByCol.values.filter { $0.marked && $0.row <= 2 }.map(\.col))
    }

    func reset() {
        stacksByCol = [:]
        selectedCol = Self.cols / 2
        score = 0
        combo = 0
        bestCombo = 0
        level = 1
        lives = Self.startLives
        clearsThisLevel = 0
        accumMs = 0
        isGameOver = false
        isRunning = false
        events.send(.reset)
    }

    func start() {
        isRunning = true
        events.send(.started)
    }

    func selectDelta(_ delta: Int) {
        guard isRunning, !isGameOver else { return }
        selectedCol = min(Self.cols - 1, max(0, selectedCol + delta))
        events.send(.selected(selectedCol))
    }

    func selectCol(_ col: Int) {
        guard isRunning, !isGameOver else { return }
        selectedCol = min(Self.cols - 1, max(0, col))
        events.send(.selected(selectedCol))
    }

    func push() {
        guard isRunning, !isGameOver else { return }
        guard let stack = stacksByCol[selectedCol] else {
            events.send(.pushEmpty(col: selectedCol))
            return
        }
        stacksByCol.removeValue(forKey: selectedCol)

        if stack.marked {
            let multiplier = 1.0 + Double(combo) * 0.25
            let gained = Int((100.0 * Double(stack.height) * multiplier).rounded())
            score += gained
            combo += 1
            bestCombo = max(bestCombo, combo)
            clearsThisLevel += 1
            events.send(.clearedMarked(stack: stack, gained: gained, combo: combo))
            maybeLevelUp()
        } else {
            combo = 0
            events.send(.pushedSafe(stack))
            loseLife(reason: .pushedSafe, stack: stack)
        }
    }

    func update(dtMs: Double) {
        guard isRunning, !isGameOver else { return }
        accumMs += dtMs
        let interval = tickMs
        while accumMs >= interval {
            accumMs -= interval
            advance()
        }
    }

    private func maybeLevelUp() {
        if clearsThisLevel >= Self.clearsPerLevel {
            clearsThisLevel = 0
            level += 1
            events.send(.levelUp(level))
        }
    }

    private func loseLife(reason: LifeLostReason, stack: Stack?) {
        lives -= 1
        events.send(.lifeLost(reason: reason, stack: stack, lives: lives))
        if lives <= 0 { end() }
    }

    private func end() {
        isGameOver = true
        isRunning = false
        events.send(.gameOver(score: score, bestCombo: bestCombo, level: level))
    }

    private func spawn() {
        let freeCols = (0..<Self.cols).filter { stacksByCol[$0] == nil }
        guard !freeCols.isEmpty else { return }

        let spawnChance = min(0.85, 0.45 + Double(level) * 0.04)
        let markedChance = min(0.62, 0.32 + Double(level) * 0.03)

        for col in freeCols {
            guard Double.random(in: 0..<1) <= spawnChance else { continue }
            let stack = Stack(
                id: nextId,
                col: col,
                row: Self.rows - 1,
                height: 1 + Int.random(in: 0..<3),
                marked: Double.random(in: 0..<1) < markedChance
            )
            nextId += 1
            stacksByCol[col] = stack
            events.send(.spawned(stack))
        }
    }

    private func advance() {
        for (col, var stack) in stacksByCol {
            stack.row -= 1
            if stack.row < 0 {
                stacksByCol.removeValue(forKey: col)
                if stack.marked {
                    loseLife(reason: .escaped, stack: stack)
                } else {
                    score += 10
                    events.send(.passedSafe(stack))
                }
            } else {
                stacksByCol[col] = stack
                events.send(.advanced(stack))
            }
        }
        spawn()
    }
}
