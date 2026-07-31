import SceneKit
import SwiftUI

struct GameSceneView: UIViewRepresentable {
    let coordinator: GameSceneCoordinator
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = coordinator.scene
        view.delegate = coordinator
        view.isPlaying = true
        view.rendersContinuously = true
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60

        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeLeft))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeRight))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
    }

    final class Coordinator: NSObject {
        let onSwipeLeft: () -> Void
        let onSwipeRight: () -> Void

        init(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) {
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
        }

        @objc func swipeLeft() { onSwipeLeft() }
        @objc func swipeRight() { onSwipeRight() }
    }
}
