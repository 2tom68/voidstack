import SceneKit
import SwiftUI

struct GameSceneView: UIViewRepresentable {
    let coordinator: GameSceneCoordinator

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = coordinator.scene
        view.delegate = coordinator
        view.isPlaying = true
        view.rendersContinuously = true
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
