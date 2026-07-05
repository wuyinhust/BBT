import SpriteKit
import SwiftUI
import UIKit

struct LiveIslandSceneView: View {
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @State private var scene = LiveIslandScene()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea()
            .onAppear {
                scene.updateAnimalPresences(companionPresences)
                scene.isPaused = false
            }
            .onDisappear {
                scene.isPaused = true
            }
            .onChange(of: companionStore.selectedID) { _, _ in
                scene.updateAnimalPresences(companionPresences)
            }
            .onChange(of: temperamentStore.result?.animalID) { _, _ in
                scene.updateAnimalPresences(companionPresences)
            }
            .onChange(of: recruitmentStore.recruitedIDs) { _, _ in
                scene.updateAnimalPresences(companionPresences)
            }
    }

    private var companionPresences: [CompanionAnimalPresence] {
        BabyCompanion.companionPageAnimals(
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID,
            recruitedIDs: recruitmentStore.recruitedIDs
        )
    }
}

final class LiveIslandScene: SKScene {
    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let worldSize = CGSize(width: 1800, height: 1350)
    private let panoramaSize = CGSize(width: 2880, height: 2160)
    private let panoramaAssetName = "live_island_panorama"
    private var lastTouchLocation: CGPoint?
    private var animalNodes: [AnimalNode] = []
    private var animalSpecs: [AnimalSpec] = []
    private static var textureCache: [String: SKTexture] = [:]

    private struct AnimalSpec {
        let id: String
        let assetName: String
        let start: CGPoint
        let height: CGFloat
    }

    private struct AnimalSceneMetadata {
        let start: CGPoint
        let height: CGFloat
    }

    private static let animalMetadata: [String: AnimalSceneMetadata] = [
        "piggy": .init(start: CGPoint(x: 580, y: 690), height: 90),
        "fenny": .init(start: CGPoint(x: 1030, y: 880), height: 88),
        "ferry": .init(start: CGPoint(x: 710, y: 470), height: 86),
        "cal": .init(start: CGPoint(x: 930, y: 625), height: 78),
        "bunny_lulu": .init(start: CGPoint(x: 1190, y: 520), height: 84),
        "fawn_mimi": .init(start: CGPoint(x: 1330, y: 815), height: 100),
        "samoyed_momo": .init(start: CGPoint(x: 1490, y: 900), height: 94),
        "otter_tangtang": .init(start: CGPoint(x: 500, y: 545), height: 88),
        "redpanda_youyou": .init(start: CGPoint(x: 1240, y: 1030), height: 92),
        "koala_anan": .init(start: CGPoint(x: 820, y: 980), height: 88),
        "sloth_nono": .init(start: CGPoint(x: 1450, y: 650), height: 92),
        "chipmunk_huohuo": .init(start: CGPoint(x: 1010, y: 365), height: 76)
    ]

    override init() {
        super.init(size: worldSize)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        size = view.bounds.size
        view.allowsTransparency = true
        view.backgroundColor = .clear
        removeAllChildren()
        worldNode.removeAllChildren()
        animalNodes.removeAll()

        addChild(worldNode)
        createWorld()

        camera = cameraNode
        updateCameraScale()
        cameraNode.position = defaultCameraPosition()
        addChild(cameraNode)
        clampCamera()
    }

    func updateAnimalPresences(_ presences: [CompanionAnimalPresence]) {
        animalSpecs = presences.map { presence in
            let metadata = Self.animalMetadata[presence.id] ?? AnimalSceneMetadata(
                start: CGPoint(x: worldSize.width / 2, y: worldSize.height / 2),
                height: 86
            )
            return AnimalSpec(
                id: presence.id,
                assetName: presence.companion.portraitAssetName,
                start: metadata.start,
                height: metadata.height
            )
        }

        guard worldNode.parent != nil else { return }
        rebuildAnimals()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        updateCameraScale()
        clampCamera()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchLocation = touches.first?.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let current = touches.first?.location(in: self), let lastTouchLocation else { return }
        let delta = CGPoint(x: lastTouchLocation.x - current.x, y: lastTouchLocation.y - current.y)
        cameraNode.position.x += delta.x
        cameraNode.position.y += delta.y
        self.lastTouchLocation = current
        clampCamera()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchLocation = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchLocation = nil
    }

    override func update(_ currentTime: TimeInterval) {
        for animal in animalNodes {
            animal.root.zPosition = 1_000 - animal.root.position.y
        }
    }

    private func createWorld() {
        addPanoramaBackground()
        addAnimals()
    }

    private func addPanoramaBackground() {
        if UIImage(named: panoramaAssetName) != nil {
            let background = SKSpriteNode(imageNamed: panoramaAssetName)
            background.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
            background.size = panoramaSize
            background.zPosition = -100
            worldNode.addChild(background)
        } else {
            let fallback = SKShapeNode(rectOf: worldSize)
            fallback.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
            fallback.fillColor = UIColor(hex: "#BEEA9A")
            fallback.strokeColor = .clear
            fallback.zPosition = -100
            worldNode.addChild(fallback)
        }
    }

    private func addAnimals() {
        for spec in animalSpecs {
            let node = makeAnimalNode(spec)
            node.root.position = spec.start
            animalNodes.append(node)
            worldNode.addChild(node.root)
        }
    }

    private func rebuildAnimals() {
        for animal in animalNodes {
            animal.root.removeAllActions()
            animal.root.removeFromParent()
        }
        animalNodes.removeAll()
        addAnimals()
    }

    private func makeAnimalNode(_ spec: AnimalSpec) -> AnimalNode {
        let root = SKNode()
        root.name = spec.id

        let visual = SKNode()
        root.addChild(visual)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: spec.height * 0.58, height: spec.height * 0.16))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: spec.height * 0.05)
        root.addChild(shadow)

        if let texture = texture(for: spec.assetName) {
            let animal = SKSpriteNode(texture: texture)
            animal.anchorPoint = CGPoint(x: 0.5, y: 0)
            animal.size = size(for: texture, targetHeight: spec.height)
            animal.position = .zero
            animal.zPosition = 1
            visual.addChild(animal)
        } else {
            let fallback = SKShapeNode(circleOfRadius: spec.height * 0.38)
            fallback.fillColor = UIColor(hex: "#BDA6F2")
            fallback.strokeColor = UIColor.white.withAlphaComponent(0.74)
            fallback.lineWidth = 3
            fallback.position = CGPoint(x: 0, y: spec.height * 0.38)
            visual.addChild(fallback)
        }

        return AnimalNode(root: root, visual: visual)
    }

    private func texture(for assetName: String) -> SKTexture? {
        if let cached = Self.textureCache[assetName] {
            return cached
        }

        guard let image = UIImage(named: assetName),
              let prepared = image.preparedForLiveScene(),
              let cgImage = prepared.cgImage else {
            return nil
        }

        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .linear
        Self.textureCache[assetName] = texture
        return texture
    }

    private func size(for texture: SKTexture, targetHeight: CGFloat) -> CGSize {
        let textureSize = texture.size()
        guard textureSize.height > 0 else {
            return CGSize(width: targetHeight, height: targetHeight)
        }
        return CGSize(
            width: targetHeight * textureSize.width / textureSize.height,
            height: targetHeight
        )
    }

    private func clampCamera() {
        guard size.width > 0, size.height > 0 else { return }
        let halfWidth = size.width * cameraNode.xScale / 2
        let halfHeight = size.height * cameraNode.yScale / 2
        cameraNode.position.x = clamped(cameraNode.position.x, min: halfWidth, max: worldSize.width - halfWidth)
        cameraNode.position.y = clamped(cameraNode.position.y, min: halfHeight, max: worldSize.height - halfHeight)
    }

    private func updateCameraScale() {
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(worldSize.width / size.width, worldSize.height / size.height)
        cameraNode.setScale(scale)
    }

    private func defaultCameraPosition() -> CGPoint {
        CGPoint(x: 520, y: worldSize.height / 2)
    }

    private func clamped(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        guard minValue <= maxValue else { return (minValue + maxValue) / 2 }
        return min(max(value, minValue), maxValue)
    }
}

private final class AnimalNode {
    let root: SKNode
    let visual: SKNode

    init(root: SKNode, visual: SKNode) {
        self.root = root
        self.visual = visual
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red, green, blue: UInt64
        switch hex.count {
        case 6:
            (red, green, blue) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (red, green, blue) = (255, 255, 255)
        }
        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}

private extension UIImage {
    func preparedForLiveScene() -> UIImage? {
        guard let cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return self
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var visited = [Bool](repeating: false, count: width * height)
        var queue: [Int] = []
        queue.reserveCapacity(width * 2 + height * 2)

        func enqueueIfBackground(x: Int, y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else { return }
            let pixelIndex = y * width + x
            guard !visited[pixelIndex] else { return }
            let byteIndex = pixelIndex * bytesPerPixel
            guard pixels.isTransparentOrLightBackground(at: byteIndex) else { return }
            visited[pixelIndex] = true
            queue.append(pixelIndex)
        }

        for x in 0..<width {
            enqueueIfBackground(x: x, y: 0)
            enqueueIfBackground(x: x, y: height - 1)
        }
        for y in 0..<height {
            enqueueIfBackground(x: 0, y: y)
            enqueueIfBackground(x: width - 1, y: y)
        }

        var head = 0
        while head < queue.count {
            let pixelIndex = queue[head]
            head += 1
            let x = pixelIndex % width
            let y = pixelIndex / width
            pixels[pixelIndex * bytesPerPixel + 3] = 0

            enqueueIfBackground(x: x + 1, y: y)
            enqueueIfBackground(x: x - 1, y: y)
            enqueueIfBackground(x: x, y: y + 1)
            enqueueIfBackground(x: x, y: y - 1)
        }

        let cropRect = pixels.visibleCropRect(width: width, height: height, bytesPerPixel: bytesPerPixel)

        guard let outputContext = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
              let output = outputContext.makeImage() else {
            return self
        }

        let cropped = output.cropping(to: cropRect) ?? output
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

private extension Array where Element == UInt8 {
    func isTransparentOrLightBackground(at index: Int) -> Bool {
        let red = self[index]
        let green = self[index + 1]
        let blue = self[index + 2]
        let alpha = self[index + 3]
        let maxChannel = Swift.max(red, Swift.max(green, blue))
        let minChannel = Swift.min(red, Swift.min(green, blue))
        return alpha < 12 || (red > 224 && green > 224 && blue > 220 && maxChannel - minChannel < 36)
    }

    func visibleCropRect(width: Int, height: Int, bytesPerPixel: Int) -> CGRect {
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * bytesPerPixel
                if self[index + 3] > 12 {
                    minX = Swift.min(minX, x)
                    minY = Swift.min(minY, y)
                    maxX = Swift.max(maxX, x)
                    maxY = Swift.max(maxY, y)
                }
            }
        }

        guard minX <= maxX, minY <= maxY else {
            return CGRect(x: 0, y: 0, width: width, height: height)
        }

        let padding = Swift.max(4, Int(CGFloat(Swift.max(maxX - minX, maxY - minY)) * 0.03))
        let cropX = Swift.max(minX - padding, 0)
        let cropY = Swift.max(minY - padding, 0)
        let cropMaxX = Swift.min(maxX + padding, width - 1)
        let cropMaxY = Swift.min(maxY + padding, height - 1)

        return CGRect(
            x: cropX,
            y: cropY,
            width: cropMaxX - cropX + 1,
            height: cropMaxY - cropY + 1
        )
    }
}
