import SpriteKit
import SwiftUI

struct LiveIslandSceneView: View {
    @State private var scene = LiveIslandScene()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea()
            .onAppear {
                scene.isPaused = false
            }
            .onDisappear {
                scene.isPaused = true
            }
    }
}

final class LiveIslandScene: SKScene {
    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let worldSize = CGSize(width: 1800, height: 1800)
    private var lastTouchLocation: CGPoint?
    private var animalNodes: [AnimalNode] = []

    private struct AnimalSpec {
        let id: String
        let emoji: String
        let name: String
        let tint: UIColor
        let start: CGPoint
        let line: String
    }

    private let animals: [AnimalSpec] = [
        .init(id: "piggy", emoji: "🐷", name: "粉咕", tint: UIColor(hex: "#F7A9B8"), start: CGPoint(x: 770, y: 930), line: "我刚刚绕小木屋走了一圈"),
        .init(id: "fox", emoji: "🦊", name: "芬灵", tint: UIColor(hex: "#F4A261"), start: CGPoint(x: 1110, y: 1010), line: "宝宝今天的节奏很稳"),
        .init(id: "duck", emoji: "🦆", name: "柯噜", tint: UIColor(hex: "#F8D66D"), start: CGPoint(x: 960, y: 760), line: "草地这里很适合晒太阳"),
        .init(id: "otter", emoji: "🦦", name: "雪溜", tint: UIColor(hex: "#9D7B60"), start: CGPoint(x: 610, y: 1120), line: "我发现了一朵会发光的小花"),
        .init(id: "cat", emoji: "🐱", name: "奶霜", tint: UIColor(hex: "#FFD6A5"), start: CGPoint(x: 1240, y: 810), line: "小木屋窗边很暖"),
        .init(id: "rabbit", emoji: "🐰", name: "米团", tint: UIColor(hex: "#F8E8FF"), start: CGPoint(x: 1280, y: 1240), line: "今天也要轻轻记录呀"),
        .init(id: "panda", emoji: "🐼", name: "团团", tint: UIColor(hex: "#CDE7F0"), start: CGPoint(x: 520, y: 720), line: "我在等下一条成长消息"),
        .init(id: "koala", emoji: "🐨", name: "云朵", tint: UIColor(hex: "#B9C1CC"), start: CGPoint(x: 1420, y: 980), line: "宝宝睡醒后心情应该不错"),
        .init(id: "chick", emoji: "🐥", name: "啾啾", tint: UIColor(hex: "#FFE66D"), start: CGPoint(x: 840, y: 1320), line: "我把今天的好运收好了"),
        .init(id: "deer", emoji: "🦌", name: "鹿也", tint: UIColor(hex: "#C99C6A"), start: CGPoint(x: 1060, y: 1370), line: "森林直播间开播中")
    ]

    override init() {
        super.init(size: UIScreen.main.bounds.size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        view.backgroundColor = .clear
        removeAllChildren()
        worldNode.removeAllChildren()
        animalNodes.removeAll()

        addChild(worldNode)
        createWorld()

        camera = cameraNode
        cameraNode.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        addChild(cameraNode)
        clampCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
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
        let ground = SKShapeNode(rectOf: worldSize)
        ground.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        ground.fillColor = UIColor(hex: "#39D385")
        ground.strokeColor = .clear
        ground.zPosition = -100
        worldNode.addChild(ground)

        addGradientBands()
        addRiver()
        addDecorations()
        addCabin()
        addAnimals()
        addFloatingLights()
    }

    private func addGradientBands() {
        let top = SKShapeNode(rect: CGRect(x: 0, y: worldSize.height - 360, width: worldSize.width, height: 360))
        top.fillColor = UIColor(hex: "#79B6FF")
        top.strokeColor = .clear
        top.alpha = 0.72
        top.zPosition = -95
        worldNode.addChild(top)

        let shade = SKShapeNode(rect: CGRect(x: 0, y: 0, width: worldSize.width, height: 260))
        shade.fillColor = UIColor(hex: "#138C55")
        shade.strokeColor = .clear
        shade.alpha = 0.42
        shade.zPosition = -94
        worldNode.addChild(shade)
    }

    private func addRiver() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 1560))
        path.addCurve(to: CGPoint(x: 520, y: 1505), control1: CGPoint(x: 180, y: 1490), control2: CGPoint(x: 330, y: 1600))
        path.addCurve(to: CGPoint(x: 1080, y: 1535), control1: CGPoint(x: 730, y: 1400), control2: CGPoint(x: 900, y: 1610))
        path.addCurve(to: CGPoint(x: 1800, y: 1490), control1: CGPoint(x: 1320, y: 1450), control2: CGPoint(x: 1550, y: 1590))

        let river = SKShapeNode(path: path)
        river.strokeColor = UIColor(hex: "#7BAFFF")
        river.lineWidth = 92
        river.lineCap = .round
        river.alpha = 0.8
        river.zPosition = -80
        worldNode.addChild(river)

        let highlight = SKShapeNode(path: path)
        highlight.strokeColor = UIColor.white.withAlphaComponent(0.26)
        highlight.lineWidth = 18
        highlight.lineCap = .round
        highlight.zPosition = -79
        worldNode.addChild(highlight)
    }

    private func addCabin() {
        let cabin = SKNode()
        cabin.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2 + 70)
        cabin.zPosition = 100

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 300, height: 54))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.16)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -120)
        cabin.addChild(shadow)

        let body = SKShapeNode(rectOf: CGSize(width: 270, height: 205), cornerRadius: 30)
        body.fillColor = UIColor(hex: "#F7D69C")
        body.strokeColor = UIColor(hex: "#9C6B40")
        body.lineWidth = 8
        body.position = CGPoint(x: 0, y: -10)
        cabin.addChild(body)

        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: -165, y: 80))
        roofPath.addLine(to: CGPoint(x: 0, y: 225))
        roofPath.addLine(to: CGPoint(x: 165, y: 80))
        roofPath.closeSubpath()
        let roof = SKShapeNode(path: roofPath)
        roof.fillColor = UIColor(hex: "#7BC3BF")
        roof.strokeColor = UIColor(hex: "#4D8F8D")
        roof.lineWidth = 8
        cabin.addChild(roof)

        let door = SKShapeNode(rectOf: CGSize(width: 72, height: 116), cornerRadius: 24)
        door.fillColor = UIColor(hex: "#A66C43")
        door.strokeColor = UIColor(hex: "#72452C")
        door.lineWidth = 5
        door.position = CGPoint(x: -52, y: -68)
        cabin.addChild(door)

        let window = SKShapeNode(rectOf: CGSize(width: 76, height: 76), cornerRadius: 18)
        window.fillColor = UIColor(hex: "#BFE8FF")
        window.strokeColor = UIColor(hex: "#7A6A55")
        window.lineWidth = 6
        window.position = CGPoint(x: 70, y: -18)
        cabin.addChild(window)

        let title = SKLabelNode(text: "BabyBuddy 小木屋")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 30
        title.fontColor = UIColor(hex: "#4B425E")
        title.position = CGPoint(x: 0, y: -164)
        cabin.addChild(title)

        worldNode.addChild(cabin)
    }

    private func addAnimals() {
        for spec in animals {
            let node = makeAnimalNode(spec)
            node.root.position = spec.start
            animalNodes.append(node)
            worldNode.addChild(node.root)
            startWander(node)
        }
    }

    private func makeAnimalNode(_ spec: AnimalSpec) -> AnimalNode {
        let root = SKNode()
        root.name = spec.id

        let visual = SKNode()
        root.addChild(visual)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 86, height: 24))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.14)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -38)
        root.addChild(shadow)

        let body = SKShapeNode(circleOfRadius: 42)
        body.fillColor = spec.tint
        body.strokeColor = UIColor.white.withAlphaComponent(0.9)
        body.lineWidth = 6
        visual.addChild(body)

        let emoji = SKLabelNode(text: spec.emoji)
        emoji.fontSize = 48
        emoji.verticalAlignmentMode = .center
        emoji.horizontalAlignmentMode = .center
        emoji.position = CGPoint(x: 0, y: 0)
        visual.addChild(emoji)

        let name = SKLabelNode(text: spec.name)
        name.fontName = "AvenirNext-Bold"
        name.fontSize = 17
        name.fontColor = UIColor(hex: "#4E4960")
        name.position = CGPoint(x: 0, y: -72)
        root.addChild(name)

        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 7, duration: 1.1),
            .moveBy(x: 0, y: -7, duration: 1.1)
        ])
        visual.run(.repeatForever(bob), withKey: "bob")

        addSpeechBubble(text: spec.line, to: root)
        return AnimalNode(root: root, visual: visual)
    }

    private func addSpeechBubble(text: String, to root: SKNode) {
        let bubble = SKNode()
        bubble.position = CGPoint(x: 0, y: 86)
        bubble.alpha = 0

        let width = max(CGFloat(text.count) * 12 + 34, 130)
        let card = SKShapeNode(rectOf: CGSize(width: width, height: 54), cornerRadius: 24)
        card.fillColor = UIColor.white.withAlphaComponent(0.94)
        card.strokeColor = UIColor.clear
        bubble.addChild(card)

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 17
        label.fontColor = UIColor(hex: "#504A63")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        bubble.addChild(label)

        root.addChild(bubble)

        let show = SKAction.fadeIn(withDuration: 0.24)
        let hold = SKAction.wait(forDuration: 2.8)
        let hide = SKAction.fadeOut(withDuration: 0.35)
        let wait = SKAction.wait(forDuration: Double.random(in: 5.0...11.0))
        bubble.run(.repeatForever(.sequence([wait, show, hold, hide])))
    }

    private func addDecorations() {
        let flowerColors = ["#FFE36E", "#F9A8D4", "#FFFFFF", "#B6F2A0"]
        for index in 0..<90 {
            let x = CGFloat.random(in: 80...(worldSize.width - 80))
            let y = CGFloat.random(in: 80...(worldSize.height - 120))
            if abs(x - worldSize.width / 2) < 230 && abs(y - worldSize.height / 2) < 260 { continue }

            if index % 5 == 0 {
                let bush = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 70...130), height: CGFloat.random(in: 52...92)))
                bush.fillColor = UIColor(hex: ["#7FD366", "#6FC65F", "#91DC70"].randomElement() ?? "#7FD366")
                bush.strokeColor = .clear
                bush.position = CGPoint(x: x, y: y)
                bush.alpha = 0.9
                bush.zPosition = -20
                worldNode.addChild(bush)
            } else if index % 3 == 0 {
                let grass = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 12...24), height: CGFloat.random(in: 36...70)), cornerRadius: 8)
                grass.fillColor = UIColor(hex: "#1BA85E").withAlphaComponent(0.65)
                grass.strokeColor = .clear
                grass.position = CGPoint(x: x, y: y)
                grass.zRotation = CGFloat.random(in: -0.45...0.45)
                grass.zPosition = -10
                worldNode.addChild(grass)
            } else {
                let flower = SKLabelNode(text: ["✿", "✦", "●"].randomElement() ?? "✿")
                flower.fontSize = CGFloat.random(in: 16...27)
                flower.fontColor = UIColor(hex: flowerColors.randomElement() ?? "#FFE36E")
                flower.position = CGPoint(x: x, y: y)
                flower.alpha = CGFloat.random(in: 0.55...0.95)
                flower.zPosition = -5
                worldNode.addChild(flower)
            }
        }
    }

    private func addFloatingLights() {
        for _ in 0..<16 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...8))
            dot.fillColor = UIColor(hex: "#FFF7A8")
            dot.strokeColor = .clear
            dot.glowWidth = 10
            dot.position = CGPoint(
                x: CGFloat.random(in: 160...(worldSize.width - 160)),
                y: CGFloat.random(in: 160...(worldSize.height - 160))
            )
            dot.zPosition = 500
            dot.alpha = 0.25
            worldNode.addChild(dot)

            let flicker = SKAction.sequence([
                .fadeAlpha(to: 0.9, duration: Double.random(in: 0.8...1.8)),
                .fadeAlpha(to: 0.2, duration: Double.random(in: 0.8...1.8))
            ])
            dot.run(.repeatForever(flicker))
        }
    }

    private func startWander(_ animal: AnimalNode) {
        let destination = randomWalkablePoint(near: animal.root.position)
        let distance = hypot(destination.x - animal.root.position.x, destination.y - animal.root.position.y)
        let duration = max(TimeInterval(distance / CGFloat.random(in: 35...58)), 1.6)
        let wait = SKAction.wait(forDuration: Double.random(in: 0.8...2.6))
        let face = SKAction.run { [weak animal] in
            guard let animal else { return }
            animal.visual.xScale = destination.x < animal.root.position.x ? -1 : 1
        }
        let move = SKAction.move(to: destination, duration: duration)
        move.timingMode = .easeInEaseOut
        let next = SKAction.run { [weak self, weak animal] in
            guard let animal else { return }
            self?.startWander(animal)
        }
        animal.root.run(.sequence([wait, face, move, next]), withKey: "wander")
    }

    private func randomWalkablePoint(near point: CGPoint) -> CGPoint {
        let radius = CGFloat.random(in: 180...420)
        let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
        let proposed = CGPoint(
            x: point.x + cos(angle) * radius,
            y: point.y + sin(angle) * radius
        )
        return CGPoint(
            x: min(max(proposed.x, 130), worldSize.width - 130),
            y: min(max(proposed.y, 130), worldSize.height - 180)
        )
    }

    private func clampCamera() {
        guard size.width > 0, size.height > 0 else { return }
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        cameraNode.position.x = min(max(cameraNode.position.x, halfWidth), worldSize.width - halfWidth)
        cameraNode.position.y = min(max(cameraNode.position.y, halfHeight), worldSize.height - halfHeight)
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
