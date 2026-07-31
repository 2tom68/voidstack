import SceneKit
import UIKit

/// VOIDSTACK — SceneKit neon renderer. Mirrors the structure of the web renderer.js:
/// board/grid/edge construction, per-stack node sync, particle bursts and camera shake.
final class GameSceneCoordinator: NSObject, SCNSceneRendererDelegate {
    static let cell: Float = 1.25

    let scene = SCNScene()
    private let cameraNode = SCNNode()
    private var baseCameraPosition = SCNVector3(0, 8.6, 6.4)
    private var reticleNode: SCNNode!
    private var dotTexture = VoidStackTextures.softDot()

    private final class StackVisual {
        let node: SCNNode
        var targetX: Float
        var targetZ: Float
        let marked: Bool
        init(node: SCNNode, targetX: Float, targetZ: Float, marked: Bool) {
            self.node = node
            self.targetX = targetX
            self.targetZ = targetZ
            self.marked = marked
        }
    }

    private var stackNodes: [Int: StackVisual] = [:]
    private var selectedCol: Int = GameEngine.cols / 2
    private var dangerCols: Set<Int> = []

    private var shakeTime: Float = 0
    private var shakeAmp: Float = 0
    private var elapsed: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    /// Called by GameEngine.update each frame; injected so the render loop can double as the game loop.
    var onFrame: ((Double) -> Void)?

    override init() {
        super.init()
        buildScene()
    }

    static func colToX(_ col: Int) -> Float {
        (Float(col) - Float(GameEngine.cols - 1) / 2) * cell
    }
    static func rowToZ(_ row: Int) -> Float {
        -Float(row) * cell
    }

    private func buildScene() {
        scene.background.contents = VoidStackColor.voidBG
        scene.fogColor = VoidStackColor.voidBG
        scene.fogStartDistance = 4
        scene.fogEndDistance = 26
        scene.fogDensityExponent = 1.4

        let camera = SCNCamera()
        camera.fieldOfView = 48
        camera.zNear = 0.1
        camera.zFar = 100
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.bloomIntensity = 0.9
        camera.bloomThreshold = 0.55
        camera.bloomBlurRadius = 10
        cameraNode.camera = camera
        cameraNode.position = baseCameraPosition
        cameraNode.look(at: SCNVector3(0, 0, Self.rowToZ(4)))
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = UIColor(red: 0.16, green: 0.23, blue: 0.4, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light!.type = .omni
        key.light!.color = VoidStackColor.cyan
        key.light!.intensity = 350
        key.position = SCNVector3(0, 6, 2)
        scene.rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light!.type = .omni
        rim.light!.color = VoidStackColor.magenta
        rim.light!.intensity = 260
        rim.position = SCNVector3(0, 4, Self.rowToZ(GameEngine.rows))
        scene.rootNode.addChildNode(rim)

        buildBoard()
        buildBackdrop()
    }

    private func buildBoard() {
        let boardW = Float(GameEngine.cols) * Self.cell
        let boardD = Float(GameEngine.rows) * Self.cell

        let floorGeo = SCNPlane(width: CGFloat(boardW + 2), height: CGFloat(boardD + 4))
        let floorMat = SCNMaterial()
        floorMat.lightingModel = .physicallyBased
        floorMat.diffuse.contents = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)
        floorMat.emission.contents = VoidStackTextures.floorGrid(cols: GameEngine.cols + 4, rows: GameEngine.rows + 4)
        floorMat.emission.intensity = 0.9
        floorMat.roughness.contents = 0.8
        floorGeo.materials = [floorMat]
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.eulerAngles.x = -.pi / 2
        floorNode.position = SCNVector3(0, -0.01, Self.rowToZ(GameEngine.rows / 2 - 1))
        scene.rootNode.addChildNode(floorNode)

        let edgeGeo = SCNBox(width: CGFloat(boardW + 0.6), height: 0.08, length: 0.14, chamferRadius: 0)
        let edgeMat = SCNMaterial()
        edgeMat.lightingModel = .constant
        edgeMat.emission.contents = VoidStackColor.magenta
        edgeMat.diffuse.contents = VoidStackColor.magenta
        edgeGeo.materials = [edgeMat]
        let edgeNode = SCNNode(geometry: edgeGeo)
        edgeNode.position = SCNVector3(0, 0.04, Self.rowToZ(0) + 0.6)
        scene.rootNode.addChildNode(edgeNode)

        let reticleGeo = SCNTorus(ringRadius: CGFloat(Self.cell) * 0.38, pipeRadius: CGFloat(Self.cell) * 0.04)
        let reticleMat = SCNMaterial()
        reticleMat.lightingModel = .constant
        reticleMat.emission.contents = VoidStackColor.cyan
        reticleMat.diffuse.contents = VoidStackColor.cyan
        reticleGeo.materials = [reticleMat]
        let reticle = SCNNode(geometry: reticleGeo)
        reticle.eulerAngles.x = .pi / 2
        reticle.position = SCNVector3(Self.colToX(selectedCol), 0.03, Self.rowToZ(0))
        scene.rootNode.addChildNode(reticle)
        reticleNode = reticle
    }

    private func buildBackdrop() {
        let count = 260
        var positions: [SCNVector3] = []
        for _ in 0..<count {
            positions.append(SCNVector3(
                Float.random(in: -30...30),
                Float.random(in: 0...20),
                Self.rowToZ(GameEngine.rows / 2) + Float.random(in: -40...40)
            ))
        }
        let source = SCNGeometrySource(vertices: positions)
        let indices: [Int32] = Array(0..<Int32(count))
        let element = SCNGeometryElement(indices: indices, primitiveType: .point)
        element.pointSize = 3
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 3
        let geo = SCNGeometry(sources: [source], elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.emission.contents = VoidStackColor.cyan
        mat.diffuse.contents = VoidStackColor.cyan
        mat.transparency = 0.5
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Sync from GameEngine

    func syncStacks(_ stacks: [Stack]) {
        var seen = Set<Int>()
        for stack in stacks {
            seen.insert(stack.id)
            if let visual = stackNodes[stack.id] {
                visual.targetX = Self.colToX(stack.col)
                visual.targetZ = Self.rowToZ(stack.row)
            } else {
                let node = makeStackNode(stack)
                stackNodes[stack.id] = StackVisual(
                    node: node,
                    targetX: Self.colToX(stack.col),
                    targetZ: Self.rowToZ(stack.row),
                    marked: stack.marked
                )
            }
        }
        for (id, visual) in stackNodes where !seen.contains(id) {
            visual.node.removeFromParentNode()
            stackNodes.removeValue(forKey: id)
        }
    }

    private func makeStackNode(_ stack: Stack) -> SCNNode {
        let group = SCNNode()
        let color = stack.marked ? VoidStackColor.marked : VoidStackColor.safe
        let cubeH: CGFloat = 0.58
        for i in 0..<stack.height {
            let size = CGFloat(0.94 * Self.cell)
            let box = SCNBox(width: size, height: cubeH, length: size, chamferRadius: 0.04)
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = stack.marked
                ? UIColor(red: 0.13, green: 0.04, blue: 0.08, alpha: 1)
                : UIColor(red: 0.04, green: 0.09, blue: 0.13, alpha: 1)
            mat.emission.contents = color
            mat.emission.intensity = stack.marked ? 0.85 : 0.5
            mat.roughness.contents = 0.4
            mat.metalness.contents = 0.2
            box.materials = [mat]
            let cube = SCNNode(geometry: box)
            cube.position = SCNVector3(0, Float(i) * Float(cubeH + 0.03) + Float(cubeH) / 2, 0)
            group.addChildNode(cube)
        }
        group.position = SCNVector3(Self.colToX(stack.col), 0, Self.rowToZ(stack.row))
        scene.rootNode.addChildNode(group)
        return group
    }

    func setSelected(_ col: Int) {
        selectedCol = col
    }

    func setDangerCols(_ cols: Set<Int>) {
        dangerCols = cols
    }

    func burst(col: Int, row: Int, marked: Bool) {
        let system = SCNParticleSystem()
        system.particleImage = dotTexture
        system.birthRate = 900
        system.emissionDuration = 0.06
        system.loops = false
        system.particleLifeSpan = 0.9
        system.particleLifeSpanVariation = 0.2
        system.particleSize = 0.09
        system.particleSizeVariation = 0.04
        system.spreadingAngle = 180
        system.particleVelocity = 3.2
        system.particleVelocityVariation = 1.6
        system.acceleration = SCNVector3(0, -4, 0)
        system.blendMode = .additive
        system.isAffectedByGravity = false
        system.particleColor = marked ? VoidStackColor.marked : VoidStackColor.safe
        system.particleColorVariation = SCNVector4(0.05, 0.05, 0.05, 0)
        system.emitterShape = SCNSphere(radius: 0.05)

        let node = SCNNode()
        node.position = SCNVector3(Self.colToX(col), 0.5, Self.rowToZ(row))
        node.addParticleSystem(system)
        scene.rootNode.addChildNode(node)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            node.removeFromParentNode()
        }
    }

    func shake(amp: Float = 0.35, duration: Float = 0.35) {
        shakeAmp = amp
        shakeTime = duration
    }

    // MARK: - SCNSceneRendererDelegate

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt: Double = lastUpdateTime == 0 ? 0 : min(0.05, time - lastUpdateTime)
        lastUpdateTime = time
        elapsed += dt

        onFrame?(dt * 1000)

        for (_, visual) in stackNodes {
            let node = visual.node
            let t: Float = min(1, Float(dt) * 10)
            node.position.x += (visual.targetX - node.position.x) * t
            node.position.z += (visual.targetZ - node.position.z) * t

            if visual.marked {
                let pulse = 0.75 + Float(sin(elapsed * 6)) * 0.35
                for cube in node.childNodes {
                    cube.geometry?.firstMaterial?.emission.intensity = CGFloat(pulse)
                }
            }
        }

        if let reticle = reticleNode {
            let tx = Self.colToX(selectedCol)
            let t: Float = min(1, Float(dt) * 12)
            reticle.position.x += (tx - reticle.position.x) * t
            let s = 1 + Float(sin(elapsed * 8)) * 0.08
            reticle.scale = SCNVector3(s, s, s)
            let color = dangerCols.contains(selectedCol) ? VoidStackColor.marked : VoidStackColor.cyan
            reticle.geometry?.firstMaterial?.emission.contents = color
            reticle.geometry?.firstMaterial?.diffuse.contents = color
        }

        if shakeTime > 0 {
            shakeTime -= Float(dt)
            let f = max(0, shakeTime)
            let amp = shakeAmp * f
            cameraNode.position = SCNVector3(
                baseCameraPosition.x + Float.random(in: -0.5...0.5) * amp,
                baseCameraPosition.y + Float.random(in: -0.5...0.5) * amp,
                baseCameraPosition.z + Float.random(in: -0.5...0.5) * amp
            )
        } else {
            cameraNode.position = baseCameraPosition
        }
    }
}
