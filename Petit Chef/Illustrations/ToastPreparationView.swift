import SwiftUI
import RealityKit
import Combine

/// One renderer survives step changes: materials and lighting are never torn down
/// during a SwiftUI transition. Everything is local; the camera is not used.
struct ToastPreparationView: UIViewRepresentable {
    let stepID: String
    var isAnimated: Bool

    func makeCoordinator() -> Studio { Studio() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.isUserInteractionEnabled = false
        view.environment.background = .color(.white)
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        context.coordinator.install(in: view)
        context.coordinator.select(stepID, animated: isAnimated)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.select(stepID, animated: isAnimated)
    }

    static func dismantleUIView(_ view: ARView, coordinator: Studio) {
        coordinator.subscription?.cancel()
        view.scene.anchors.removeAll()
    }

    @MainActor
    final class Studio {
        let anchor = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        var subscription: Cancellable?
        private var step = ""
        private var root = Entity()
        private var outgoing: Entity?
        private var elapsed: Float = 0
        private var entrance: Float = 1
        private var animated = true
        private var cameraFrom = SIMD3<Float>(0.37, 0.43, 0.57)
        private var cameraTarget = SIMD3<Float>(0.37, 0.43, 0.57)
        private var cameraOrigin = SIMD3<Float>(0.37, 0.43, 0.57)
        private var tracks: [(Float) -> Void] = []
        private let materials = PantryMaterials()

        func install(in view: ARView) {
            view.scene.addAnchor(anchor)
            camera.camera.fieldOfViewInDegrees = 37
            camera.look(at: [0, 0.035, 0], from: [0.37, 0.43, 0.57], relativeTo: nil)
            anchor.addChild(camera)
            let key = DirectionalLight()
            key.light.color = UIColor(red: 1, green: 0.95, blue: 0.88, alpha: 1)
            key.light.intensity = 2400
            key.shadow = .init()
            key.look(at: .zero, from: [-0.3, 0.8, 0.4], relativeTo: nil)
            anchor.addChild(key)
            let fill = PointLight()
            fill.light.intensity = 160
            fill.light.attenuationRadius = 3
            fill.position = [0.4, 0.45, -0.1]
            anchor.addChild(fill)
            let floor = ModelEntity(mesh: .generatePlane(width: 6, depth: 6), materials: [materials.porcelain])
            floor.position.y = -0.009
            anchor.addChild(floor)
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                // RealityKit scene updates arrive on the main thread for this ARView.
                MainActor.assumeIsolated {
                    guard let self, self.animated else { return }
                    self.tick(Float(event.deltaTime))
                }
            }
        }

        func select(_ id: String, animated: Bool) {
            self.animated = animated
            guard step != id else {
                if !animated { tick(0) }
                return
            }
            outgoing?.removeFromParent()
            outgoing = step.isEmpty ? nil : root
            root = Entity()
            anchor.addChild(root)
            tracks.removeAll()
            step = id
            cameraOrigin = cameraFrom
            switch id {
            case "dress-tomatoes": cameraTarget = [0.24, 0.32, 0.39]
            case "serve-toast": cameraTarget = [0.26, 0.36, 0.41]
            case "build-toast", "slice-tomatoes": cameraTarget = [0.31, 0.39, 0.48]
            default: cameraTarget = [0.37, 0.43, 0.57]
            }
            elapsed = 0
            entrance = animated && outgoing != nil ? 0 : 1
            switch id {
            case "preheat-toast": oven(baking: false)
            case "slice-tomatoes": chopping()
            case "build-toast": arranging()
            case "bake-toast": oven(baking: true)
            case "dress-tomatoes": dressing()
            default: plating()
            }
            tick(0)
        }

        private func tick(_ delta: Float) {
            if animated { elapsed += min(delta, 1 / 15) }
            entrance = animated ? min(1, entrance + delta / 0.6) : 1
            let blend = ease(entrance)
            cameraFrom = cameraOrigin + (cameraTarget - cameraOrigin) * blend
            camera.look(at: [0, 0.035, 0], from: cameraFrom, relativeTo: nil)
            root.position.y = (1 - blend) * -0.045
            root.components.set(OpacityComponent(opacity: blend))
            if let outgoing {
                outgoing.position.y = blend * 0.08
                outgoing.components.set(OpacityComponent(opacity: 1 - blend))
                if entrance >= 1 { outgoing.removeFromParent(); self.outgoing = nil }
            }
            for track in tracks { track(animated ? elapsed : 3.8) }
        }

        @discardableResult
        private func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ material: PhysicallyBasedMaterial,
                         radius: Float = 0.003, parent: Entity? = nil) -> ModelEntity {
            let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: radius), materials: [material])
            entity.position = position
            (parent ?? root).addChild(entity)
            return entity
        }

        @discardableResult
        private func sphere(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ material: PhysicallyBasedMaterial,
                            parent: Entity? = nil) -> ModelEntity {
            let entity = ModelEntity(mesh: .generateSphere(radius: 1), materials: [material])
            entity.scale = size
            entity.position = position
            (parent ?? root).addChild(entity)
            return entity
        }

        private func board() {
            box([0.38, 0.015, 0.25], [0, 0, 0], materials.wood, radius: 0.02)
        }

        /// Irregular sourdough silhouette with a separately textured crumb and crust.
        private func bread(at position: SIMD3<Float>, toasted: Bool = false, parent: Entity? = nil) -> Entity {
            let group = Entity()
            group.position = position
            (parent ?? root).addChild(group)
            let crust = ModelEntity(mesh: materials.breadMesh, materials: [materials.crust])
            group.addChild(crust)
            let crumb = ModelEntity(mesh: materials.breadMesh, materials: [toasted ? materials.toastedCrumb : materials.crumb])
            crumb.scale = [0.90, 0.13, 0.87]
            crumb.position.y = 0.0107
            group.addChild(crumb)
            return group
        }

        private func cheese(at position: SIMD3<Float>, parent: Entity) -> Entity {
            let group = Entity()
            group.position = position
            parent.addChild(group)
            let slice = ModelEntity(mesh: materials.cheeseMesh, materials: [materials.cheese])
            slice.scale = [0.45, 0.38, 0.6]
            group.addChild(slice)
            return group
        }

        private func tomato(at position: SIMD3<Float>, parent: Entity? = nil) -> Entity {
            let group = Entity()
            group.position = position
            (parent ?? root).addChild(group)
            sphere([0.038, 0.006, 0.037], .zero, materials.skin, parent: group)
            sphere([0.034, 0.003, 0.032], [0, 0.005, 0], materials.flesh, parent: group)
            for lobe in 0..<5 {
                let angle = Float(lobe) * .pi * 2 / 5
                let x = sin(angle) * 0.017
                let z = cos(angle) * 0.017
                let pocket = sphere([0.009, 0.0012, 0.014], [x, 0.0078, z], materials.juice, parent: group)
                pocket.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
                for seed in 0..<3 {
                    sphere([0.0013, 0.0006, 0.0024],
                           [x + Float(seed - 1) * 0.003, 0.009, z], materials.seed, parent: group)
                }
            }
            return group
        }

        private func dicedTomato(at position: SIMD3<Float>, parent: Entity? = nil) -> Entity {
            let group = Entity()
            group.position = position
            (parent ?? root).addChild(group)
            let flesh = ModelEntity(mesh: materials.tomatoMesh, materials: [materials.flesh])
            group.addChild(flesh)
            box([0.014, 0.010, 0.0015], [0, -0.001, -0.008], materials.skin, radius: 0.0006, parent: group)
            sphere([0.004, 0.001, 0.005], [0.001, 0.0065, 0.001], materials.juice, parent: group)
            sphere([0.0009, 0.0007, 0.002], [0.001, 0.0075, 0.002], materials.seed, parent: group)
            return group
        }

        private func basil(at position: SIMD3<Float>, parent: Entity? = nil) -> Entity {
            let group = Entity()
            group.position = position
            (parent ?? root).addChild(group)
            let leaf = ModelEntity(mesh: materials.leafMesh, materials: [materials.leaf])
            group.addChild(leaf)
            box([0.001, 0.001, 0.038], [0, 0.001, 0], materials.vein, radius: 0.0004, parent: group)
            for i in 0..<4 {
                for side: Float in [-1, 1] {
                    let vein = box([0.001, 0.0005, 0.015], [side * 0.004, 0.0013, Float(i) * 0.008 - 0.011], materials.vein, radius: 0.0002, parent: group)
                    vein.orientation = simd_quatf(angle: side * 0.8, axis: [0, 1, 0])
                }
            }
            return group
        }

        private func chopping() {
            board()
            let whole = sphere([0.043, 0.038, 0.041], [-0.1, 0.045, -0.055], materials.skin)
            whole.orientation = simd_quatf(angle: 0.2, axis: [0, 0, 1])
            for i in 0..<4 {
                let leaf = basil(at: [-0.1, 0.082, -0.055])
                leaf.scale = [0.45, 0.45, 0.45]
                leaf.orientation = simd_quatf(angle: Float(i) * .pi / 2, axis: [0, 1, 0])
            }
            let slice = tomato(at: [0.0, 0.021, 0])
            slice.scale = [1.2, 1, 1.2]
            let knife = Entity()
            root.addChild(knife)
            let blade = ModelEntity(mesh: materials.knifeMesh, materials: [materials.steel])
            knife.addChild(blade)
            box([0.025, 0.020, 0.084], [0, 0.018, 0.095], materials.handle, radius: 0.007, parent: knife)
            for z: Float in [0.073, 0.115] {
                sphere([0.003, 0.001, 0.003], [0, 0.029, z], materials.steel, parent: knife)
            }
            tracks.append { time in
                let beat = time.truncatingRemainder(dividingBy: 1.8) / 1.8
                let cut = sin(beat * .pi)
                knife.position = [0.015, 0.022 + 0.055 * cut * cut, -0.025]
                knife.orientation = simd_quatf(angle: -0.12 + 0.24 * cut, axis: [1, 0, 0])
            }
            for i in 0..<10 {
                let base: SIMD3<Float> = [0.060 + Float(i % 3) * 0.022, 0.020, Float(i / 3) * 0.022 - 0.025]
                let cube = dicedTomato(at: base)
                cube.orientation = simd_quatf(angle: Float(i) * 1.7, axis: [0, 1, 0])
                tracks.append { time in
                    let phase = (time + Float(i) * 0.15).truncatingRemainder(dividingBy: 5) / 5
                    cube.position = base + SIMD3<Float>(0.008 * sin(phase * .pi), 0, 0)
                }
            }
            _ = cheese(at: [-0.11, 0.019, 0.069], parent: root)
        }

        private func arranging() {
            board()
            for x: Float in [-0.085, 0.085] {
                let toast = bread(at: [x, 0.020, 0])
                for i in 0..<3 {
                    let target: SIMD3<Float> = [Float(i - 1) * 0.027, 0.021, 0]
                    let slice = cheese(at: target, parent: toast)
                    slice.orientation = simd_quatf(angle: Float(i - 1) * 0.18, axis: [0, 1, 0])
                    tracks.append { time in
                        let cycle = time.truncatingRemainder(dividingBy: 7)
                        let progress = ease((cycle - Float(i) * 0.65) / 1.35)
                        let reset = ease((cycle - 6) / 1)
                        slice.position = target + SIMD3<Float>(0, (1 - progress + reset) * 0.12, 0)
                        slice.components.set(OpacityComponent(opacity: progress * (1 - reset)))
                    }
                }
            }
            _ = basil(at: [-0.14, 0.013, 0.085])
        }

        private func oven(baking: Bool) {
            // Open-front oven, rack, hinged door and separate control knob.
            let metal = materials.enamel
            box([0.33, 0.017, 0.23], [0, 0.012, 0], metal)
            box([0.017, 0.22, 0.23], [-0.16, 0.12, 0], metal)
            box([0.017, 0.22, 0.23], [0.16, 0.12, 0], metal)
            box([0.33, 0.024, 0.23], [0, 0.232, 0], metal)
            box([0.30, 0.19, 0.012], [0, 0.118, -0.115], materials.handle)
            box([0.33, 0.047, 0.018], [0, 0.213, 0.119], metal)
            let dial = sphere([0.015, 0.015, 0.009], [0.11, 0.214, 0.134], materials.steel)
            box([0.002, 0.011, 0.002], [0, 0.004, 0.010], materials.handle, parent: dial)
            // The tiny indicator is an emissive physical light, not a text overlay.
            sphere([0.004, 0.004, 0.003], [0.065, 0.214, 0.131], materials.heat)
            for i in 0..<11 {
                box([0.003, 0.003, 0.195], [Float(i - 5) * 0.024, 0.085, -0.004], materials.steel, radius: 0.001)
            }
            let tray = Entity()
            root.addChild(tray)
            box([0.268, 0.007, 0.166], [0, 0, 0], materials.steel, parent: tray)
            for x: Float in [-0.068, 0.068] {
                let toast = bread(at: [x, 0.014, 0], toasted: baking, parent: tray)
                toast.scale = [0.80, 0.8, 0.90]
                if baking {
                    for i in 0..<3 {
                        let slice = cheese(at: [Float(i - 1) * 0.03, 0.019, 0], parent: toast)
                        slice.scale.y = 0.65
                        for j in 0..<4 {
                            sphere([0.003, 0.001, 0.004], [Float(j - 2) * 0.01, 0.003, Float((j + i) % 3 - 1) * 0.009], materials.crust, parent: slice)
                        }
                    }
                }
            }
            let door = Entity()
            door.position = [0, 0.025, 0.122]
            root.addChild(door)
            box([0.322, 0.16, 0.009], [0, 0.080, 0], metal, parent: door)
            box([0.263, 0.109, 0.005], [0, 0.079, 0.006], materials.glass, parent: door)
            box([0.24, 0.009, 0.014], [0, 0.146, 0.023], materials.steel, parent: door)
            let warm = PointLight()
            warm.light.color = UIColor(red: 1, green: 0.66, blue: 0.28, alpha: 1)
            warm.light.intensity = 8
            warm.light.attenuationRadius = 0.6
            warm.position = [0, 0.16, 0.045]
            root.addChild(warm)
            root.scale = [0.85, 0.85, 0.85]
            tracks.append { time in
                let cycle = time.truncatingRemainder(dividingBy: 8)
                let insert = ease((cycle - 0.8) / 2)
                let reopen = ease((cycle - 6.2) / 1.8)
                tray.position = [0, 0.091, 0.16 * (1 - insert + reopen)]
                let shut = ease((cycle - 3) / 1.4) * (1 - reopen)
                door.orientation = simd_quatf(angle: (1 - shut) * 1.38, axis: [1, 0, 0])
                dial.orientation = simd_quatf(angle: -ease(cycle / 1.5) * 2.3, axis: [0, 0, 1])
                warm.light.intensity = baking ? 12 : 3 + 9 * ease(cycle / 2)
            }
        }

        private func dressing() {
            let bowl = ModelEntity(mesh: materials.bowlMesh, materials: [materials.porcelain])
            root.addChild(bowl)
            for i in 0..<25 {
                let angle = Float(i) * 2.4
                let radius: Float = 0.023 + Float(i % 5) * 0.012
                let cube = dicedTomato(at: [sin(angle) * radius, 0.035 + Float(i % 3) * 0.015, cos(angle) * radius])
                tracks.append { time in
                    let turn = sin(time * 1.1) * 0.25
                    cube.position.x = sin(angle + turn) * radius
                    cube.position.z = cos(angle + turn) * radius
                    cube.position.y = 0.038 + Float(i % 3) * 0.015 + max(0, sin(time * 1.1 + angle)) * 0.010
                    cube.orientation = simd_quatf(angle: angle + turn, axis: [0, 1, 0])
                }
            }
            for i in 0..<4 {
                let leaf = basil(at: [Float(i - 2) * 0.022, 0.075, Float(i % 2) * 0.03 - 0.012])
                leaf.orientation = simd_quatf(angle: Float(i), axis: [0, 1, 0])
            }
            let spoon = Entity()
            root.addChild(spoon)
            sphere([0.021, 0.004, 0.03], [0, 0, 0], materials.wood, parent: spoon)
            box([0.011, 0.008, 0.15], [0, 0.001, 0.095], materials.wood, radius: 0.004, parent: spoon)
            tracks.append { time in
                let turn = time * 1.1
                spoon.position = [sin(turn) * 0.052, 0.055, cos(turn) * 0.052]
                spoon.orientation = simd_quatf(angle: turn, axis: [0, 1, 0]) * simd_quatf(angle: -0.5, axis: [1, 0, 0])
            }
        }

        private func plating() {
            let plate = ModelEntity(mesh: .generateCylinder(height: 0.008, radius: 0.173), materials: [materials.porcelain])
            root.addChild(plate)
            for (side, x) in [Float(-0.071), Float(0.071)].enumerated() {
                let toast = bread(at: [x, 0.019, 0], toasted: true)
                toast.orientation = simd_quatf(angle: -0.15, axis: [0, 1, 0])
                for i in 0..<3 { _ = cheese(at: [Float(i - 1) * 0.03, 0.021, 0], parent: toast) }
                for i in 0..<12 {
                    let target: SIMD3<Float> = [Float(i % 4 - 2) * 0.024 + 0.01 + sin(Float(i) * 2.4) * 0.005,
                                                  0.032 + Float(i % 3) * 0.002,
                                                  Float(i / 4 - 1) * 0.022 + cos(Float(i) * 2.4) * 0.005]
                    let cube = dicedTomato(at: target, parent: toast)
                    cube.orientation = simd_quatf(angle: Float(i) * 2.4, axis: [0, 1, 0])
                    cube.scale = [1 + Float(i % 3) * 0.12, 0.75 + Float(i % 4) * 0.1, 0.9 + Float(i % 2) * 0.2]
                    tracks.append { time in
                        let progress = ease((time - Float(i) * 0.08 - Float(side) * 0.3) / 0.8)
                        cube.position = target + SIMD3<Float>(0, (1 - progress) * 0.1, 0)
                        cube.components.set(OpacityComponent(opacity: progress))
                    }
                }
                for i in 0..<2 {
                    let target: SIMD3<Float> = [Float(i) * 0.047 - 0.025, 0.050, 0]
                    let leaf = basil(at: target, parent: toast)
                    tracks.append { time in
                        let progress = ease((time - 1.7 - Float(i) * 0.3) / 1.2)
                        leaf.isEnabled = progress > 0.001
                        leaf.position = target + SIMD3<Float>(0, (1 - progress) * 0.10, 0)
                        leaf.orientation = simd_quatf(angle: Float(i) + (1 - progress) * 1.7, axis: [0, 1, 0])
                        leaf.components.set(OpacityComponent(opacity: progress))
                    }
                }
            }
        }
    }
}

private func ease(_ value: Float) -> Float {
    let t = min(1, max(0, value))
    return t * t * (3 - 2 * t)
}

/// Small procedural meshes and seeded textures, generated once per cooking renderer.
/// No network, downloaded assets or nondeterministic geometry in the render loop.
@MainActor
private final class PantryMaterials {
    let porcelain = material(0xF5F3EE, roughness: 0.28)
    lazy var crust = breadSurface(crust: true)
    let skin = material(0xAD2318, roughness: 0.20)
    let flesh = material(0xD34629, roughness: 0.38)
    let juice = material(0xBA3522, roughness: 0.10)
    let seed = material(0xE8BA6E, roughness: 0.40)
    let cheese = material(0xF8F0D5, roughness: 0.35)
    let leaf = material(0x42672C, roughness: 0.40)
    let vein = material(0x718546, roughness: 0.65)
    let steel = material(0xC7C6BE, roughness: 0.23, metallic: 0.85)
    let handle = material(0x292A27, roughness: 0.50)
    let enamel = material(0xC9C6BA, roughness: 0.27, metallic: 0.35)
    let glass = material(0x292F2C, roughness: 0.08, metallic: 0.30)
    lazy var crumb = breadSurface()
    lazy var toastedCrumb = breadSurface(toasted: true)
    lazy var wood = textured(kind: .wood)
    lazy var heat: PhysicallyBasedMaterial = {
        var result = material(0xF4A34B, roughness: 0.5)
        result.emissiveColor = .init(color: UIColor.orange)
        result.emissiveIntensity = 1.8
        return result
    }()
    lazy var tomatoMesh: MeshResource = {
        // An irregular cut piece with bevelled edges, not a sphere or perfect die.
        let outline: [SIMD2<Float>] = [
            [-0.007, -0.008], [0.005, -0.008], [0.009, -0.004], [0.008, 0.006],
            [0.004, 0.009], [-0.005, 0.007], [-0.009, 0.003], [-0.009, -0.004]
        ]
        var vertices: [SIMD3<Float>] = [[0, 0.007, 0], [0, -0.006, 0]]
        var triangles: [UInt32] = []
        for (scale, y): (Float, Float) in [(0.88, -0.006), (1, -0.0045), (1, 0.0045), (0.82, 0.007)] {
            for p in outline { vertices.append([p.x * scale, y + p.x * 0.08, p.y * scale]) }
        }
        for i in 0..<8 {
            let a = UInt32(i), b = UInt32((i + 1) % 8)
            triangles += [0, 26 + b, 26 + a, 1, 2 + a, 2 + b]
            for row: UInt32 in 0..<3 {
                let lower = 2 + row * 8, upper = lower + 8
                triangles += [lower + a, upper + a, upper + b, lower + a, upper + b, lower + b]
            }
        }
        var descriptor = MeshDescriptor(name: "Diced tomato")
        descriptor.positions = .init(vertices)
        descriptor.primitives = .triangles(triangles)
        return (try? .generate(from: [descriptor])) ?? .generateBox(size: [0.018, 0.013, 0.018], cornerRadius: 0.002)
    }()
    lazy var breadMesh = organicMesh(width: 0.133, depth: 0.085, height: 0.020, irregularity: 0.035)
    lazy var cheeseMesh = organicMesh(width: 0.10, depth: 0.08, height: 0.012, irregularity: 0.06)
    lazy var leafMesh = organicMesh(width: 0.027, depth: 0.047, height: 0.001, irregularity: 0.10)
    lazy var knifeMesh: MeshResource = {
        // A thin tapered wedge, with a pointed tip and bevelled cutting edge.
        let positions: [SIMD3<Float>] = [
            [-0.001, 0, -0.10], [0.001, 0, -0.10], [-0.001, 0, 0.05], [0.001, 0, 0.05],
            [-0.0025, 0.032, -0.064], [0.0025, 0.032, -0.064], [-0.0025, 0.032, 0.05], [0.0025, 0.032, 0.05]
        ]
        var descriptor = MeshDescriptor(name: "Forged blade")
        descriptor.positions = .init(positions)
        descriptor.primitives = .triangles([0, 2, 6, 0, 6, 4, 1, 5, 7, 1, 7, 3, 4, 6, 7, 4, 7, 5, 0, 4, 5, 0, 5, 1, 2, 3, 7, 2, 7, 6, 0, 1, 3, 0, 3, 2])
        return (try? .generate(from: [descriptor])) ?? .generateBox(size: [0.003, 0.03, 0.15])
    }()
    lazy var bowlMesh: MeshResource = {
        // Lathed, double-sided ceramic bowl with an actual open interior.
        let profile: [(Float, Float)] = [(0, 0.007), (0.065, 0.007), (0.091, 0.024), (0.115, 0.065), (0.118, 0.073), (0.113, 0.073), (0.107, 0.063), (0.083, 0.030), (0.06, 0.014), (0, 0.014)]
        var points: [SIMD3<Float>] = []
        var triangles: [UInt32] = []
        let segments = 64
        for (radius, height) in profile {
            for i in 0...segments {
                let a = Float(i) * .pi * 2 / Float(segments)
                points.append([sin(a) * radius, height, cos(a) * radius])
            }
        }
        for row in 0..<(profile.count - 1) {
            for i in 0..<segments {
                let a = UInt32(row * (segments + 1) + i), b = a + UInt32(segments + 1)
                triangles += [a, b, a + 1, a + 1, b, b + 1]
            }
        }
        var descriptor = MeshDescriptor(name: "Ceramic bowl")
        descriptor.positions = .init(points)
        descriptor.primitives = .triangles(triangles)
        return (try? .generate(from: [descriptor])) ?? .generateSphere(radius: 0.10)
    }()

    private func breadSurface(toasted: Bool = false, crust: Bool = false) -> PhysicallyBasedMaterial {
        let size = 256
        var rng = SeededGrain()
        var heights = (0..<(size * size)).map { _ in Float(rng.next()) * 0.15 }
        for _ in 0..<(crust ? 1400 : 650) {
            let cx = Int(rng.next() * 255), cy = Int(rng.next() * 255)
            let rx = 1 + Int(rng.next() * (crust ? 2 : 5))
            let ry = max(1, Int(Float(rx) * Float(0.5 + rng.next())))
            let depth = Float(0.2 + rng.next() * 0.7)
            for y in max(0, cy - ry)...min(size - 1, cy + ry) {
                for x in max(0, cx - rx)...min(size - 1, cx + rx) {
                    let u = Float(x - cx) / Float(rx), v = Float(y - cy) / Float(ry)
                    let radius = u * u + v * v
                    if radius < 1 { heights[y * size + x] -= (1 - radius) * depth }
                }
            }
        }
        var colors = [UInt8](repeating: 255, count: size * size * 4)
        var normals = colors
        let base: SIMD3<Float> = crust ? [0.65, 0.38, 0.15] : toasted ? [0.84, 0.64, 0.36] : [0.94, 0.84, 0.62]
        for y in 0..<size {
            for x in 0..<size {
                let index = y * size + x
                let h = heights[index]
                let dx = heights[y * size + min(size - 1, x + 1)] - heights[y * size + max(0, x - 1)]
                let dy = heights[min(size - 1, y + 1) * size + x] - heights[max(0, y - 1) * size + x]
                let normal = simd_normalize(SIMD3<Float>(-dx * 1.7, dy * 1.7, 1)) * 0.5 + 0.5
                let shade = max(0.28, 1 + h * (crust ? 0.35 : 0.75))
                for channel in 0..<3 {
                    colors[index * 4 + channel] = UInt8(min(255, max(0, base[channel] * shade * 255)))
                    normals[index * 4 + channel] = UInt8(min(255, max(0, normal[channel] * 255)))
                }
            }
        }
        func texture(_ bytes: [UInt8], semantic: TextureResource.Semantic) -> TextureResource? {
            guard let provider = CGDataProvider(data: Data(bytes) as CFData),
                  let image = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                                      bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            else { return nil }
            return try? TextureResource(image: image, options: .init(semantic: semantic))
        }
        var result = material(0xFFFFFF, roughness: 0.92)
        if let color = texture(colors, semantic: .color) { result.baseColor.texture = .init(color) }
        if let normal = texture(normals, semantic: .normal) { result.normal.texture = .init(normal) }
        return result
    }

    private enum TextureKind { case crumb, toast, wood }
    private func textured(kind: TextureKind) -> PhysicallyBasedMaterial {
        let size = 512
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        var random = SeededGrain()
        let image = renderer.image { context in
            let cg = context.cgContext
            (kind == .wood ? UIColor(red: 0.72, green: 0.55, blue: 0.36, alpha: 1) : UIColor(red: 0.91, green: 0.78, blue: 0.53, alpha: 1)).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
            for _ in 0..<6000 {
                let x = random.next() * 512, y = random.next() * 512
                let radius = 0.4 + random.next() * (kind == .wood ? 1 : 4.5)
                let dark = random.next()
                let color = kind == .wood
                    ? UIColor(red: 0.28, green: 0.17, blue: 0.07, alpha: 0.04 + dark * 0.13)
                    : UIColor(red: 0.36, green: 0.23, blue: 0.09, alpha: 0.08 + dark * (kind == .toast ? 0.4 : 0.20))
                cg.setFillColor(color.cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: radius * (kind == .wood ? 100 : 1.5), height: radius))
            }
        }
        var result = material(0xFFFFFF, roughness: kind == .wood ? 0.65 : 0.94)
        if let cgImage = image.cgImage,
           let texture = try? TextureResource(image: cgImage, options: .init(semantic: .color)) {
            result.baseColor.texture = .init(texture)
        }
        return result
    }

    private func organicMesh(width: Float, depth: Float, height: Float, irregularity: Float) -> MeshResource {
        let segments = 64
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        func rim(_ i: Int) -> SIMD3<Float> {
            let a = Float(i) * .pi * 2 / Float(segments)
            let irregular = 1 + irregularity * sin(a * 5) + irregularity * 0.4 * cos(a * 9)
            return [cos(a) * width / 2 * irregular, 0, sin(a) * depth / 2 * irregular]
        }
        func vertex(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ uv: SIMD2<Float>) {
            indices.append(UInt32(positions.count)); positions.append(p); normals.append(n); uvs.append(uv)
        }
        // Separate cap and side vertices preserve the cut face's flat normal, and
        // unwrap the crust around the perimeter instead of stretching one pixel.
        for i in 0..<segments {
            let a = rim(i), b = rim(i + 1)
            for side: Float in [1, -1] {
                let points = side > 0 ? [SIMD3<Float>.zero, b, a] : [.zero, a, b]
                for point in points {
                    vertex(point + [0, side * height / 2, 0], [0, side, 0], [point.x / width + 0.5, point.z / depth + 0.5])
                }
            }
            let na = simd_normalize(SIMD3<Float>(a.x / (width * width), 0, a.z / (depth * depth)))
            let nb = simd_normalize(SIMD3<Float>(b.x / (width * width), 0, b.z / (depth * depth)))
            let u = Float(i) / Float(segments), v = Float(i + 1) / Float(segments)
            vertex(a + [0, height / 2, 0], na, [u, 1])
            vertex(b + [0, height / 2, 0], nb, [v, 1])
            vertex(b - [0, height / 2, 0], nb, [v, 0])
            vertex(a + [0, height / 2, 0], na, [u, 1])
            vertex(b - [0, height / 2, 0], nb, [v, 0])
            vertex(a - [0, height / 2, 0], na, [u, 0])
        }
        var descriptor = MeshDescriptor(name: "Hand-shaped surface")
        descriptor.positions = .init(positions)
        descriptor.normals = .init(normals)
        descriptor.textureCoordinates = .init(uvs)
        descriptor.primitives = .triangles(indices)
        return (try? .generate(from: [descriptor])) ?? .generateBox(size: [width, height, depth])
    }
}

private func material(_ hex: UInt32, roughness: Float, metallic: Float = 0) -> PhysicallyBasedMaterial {
    var result = PhysicallyBasedMaterial()
    result.baseColor = .init(tint: UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                                         green: CGFloat((hex >> 8) & 255) / 255,
                                         blue: CGFloat(hex & 255) / 255, alpha: 1))
    result.roughness = .init(floatLiteral: roughness)
    result.metallic = .init(floatLiteral: metallic)
    return result
}

private struct SeededGrain {
    var value: UInt64 = 5381
    mutating func next() -> Double {
        value = value &* 6364136223846793005 &+ 1442695040888963407
        return Double(value >> 33) / Double(UInt32.max >> 1)
    }
}
