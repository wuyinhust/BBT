import AVFoundation
import SwiftUI
import UIKit

enum LiveIslandCameraLabPhase: String, Codable, CaseIterable {
    case closed
    case peeking
    case open
    case shooting
    case printing
    case slotting
    case settled

    var stablePhase: LiveIslandCameraLabPhase {
        switch self {
        case .shooting, .printing, .slotting:
            return .settled
        default:
            return self
        }
    }
}

struct LiveIslandPolaroid: Identifiable, Codable, Equatable {
    let id: UUID
    var imageFilename: String
    var createdAt: Date
    var rotation: Double
}

private struct LiveIslandCameraLabSnapshot: Codable {
    var phase: LiveIslandCameraLabPhase
    var islandProgress: Double
    var pendingQueue: [LiveIslandPolaroid]
    var polaroids: [LiveIslandPolaroid]
    var restoredAt: Date
}

@MainActor
final class LiveIslandCameraLabStore: ObservableObject {
    @Published var phase: LiveIslandCameraLabPhase = .closed
    @Published var islandProgress: Double = 0
    @Published var pendingQueue: [LiveIslandPolaroid] = []
    @Published var polaroids: [LiveIslandPolaroid] = []

    private let fileManager: FileManager
    private let folderURL: URL
    private let snapshotURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folderURL = documentsURL.appendingPathComponent("LiveIslandCameraLab", isDirectory: true)
        snapshotURL = folderURL.appendingPathComponent("lab_state.json")
        createFolderIfNeeded()
        load()
    }

    func restoreStableOpenState() {
        if phase == .shooting || phase == .printing || phase == .slotting {
            phase = .settled
            islandProgress = 1
            persist()
        }
    }

    func updateDragProgress(_ progress: Double) {
        islandProgress = min(max(progress, 0), 1)
        switch islandProgress {
        case 0:
            phase = .closed
        case 0..<0.78:
            phase = .peeking
        default:
            phase = .open
        }
    }

    func settleOpen() {
        phase = .open
        islandProgress = 1
        persist()
    }

    func settleClosed() {
        phase = .closed
        islandProgress = 0
        pendingQueue.removeAll()
        persist()
    }

    func setPhase(_ nextPhase: LiveIslandCameraLabPhase) {
        phase = nextPhase
        persist()
    }

    func storePrintedImage(_ image: UIImage) throws -> LiveIslandPolaroid {
        createFolderIfNeeded()
        let imageID = UUID()
        let filename = "\(imageID.uuidString).jpg"
        let url = folderURL.appendingPathComponent(filename)
        let normalizedImage = image.normalizedForLiveIslandLab()
        guard let data = normalizedImage.jpegData(compressionQuality: 0.96) else {
            throw LiveIslandCameraLabError.imageEncodingFailed
        }
        try data.write(to: url, options: [.atomic])

        let item = LiveIslandPolaroid(
            id: imageID,
            imageFilename: filename,
            createdAt: Date(),
            rotation: Double.random(in: -4.5...4.5)
        )
        pendingQueue.append(item)
        persist()
        return item
    }

    func finishPrinting(_ item: LiveIslandPolaroid) {
        pendingQueue.removeAll { $0.id == item.id }
        polaroids.removeAll { $0.id == item.id }
        polaroids.insert(item, at: 0)
        polaroids = Array(polaroids.prefix(12))
        phase = .settled
        islandProgress = 1
        persist()
    }

    func image(for polaroid: LiveIslandPolaroid) -> UIImage? {
        UIImage(contentsOfFile: folderURL.appendingPathComponent(polaroid.imageFilename).path)
    }

    private func load() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder.liveIslandLabDecoder.decode(LiveIslandCameraLabSnapshot.self, from: data) else {
            return
        }

        let restoredPhase = snapshot.phase.stablePhase
        let recoveredPrintedItems = restoredPhase == .settled ? snapshot.pendingQueue : []
        let recoveredIDs = Set(recoveredPrintedItems.map(\.id))

        phase = restoredPhase
        islandProgress = restoredPhase == .closed ? 0 : max(snapshot.islandProgress, 1)
        pendingQueue = restoredPhase == .settled ? [] : snapshot.pendingQueue
        polaroids = Array((recoveredPrintedItems + snapshot.polaroids.filter { !recoveredIDs.contains($0.id) }).prefix(12))
    }

    private func persist() {
        createFolderIfNeeded()
        let stablePhase = phase.stablePhase
        let snapshot = LiveIslandCameraLabSnapshot(
            phase: stablePhase,
            islandProgress: stablePhase == .closed ? 0 : islandProgress,
            pendingQueue: pendingQueue,
            polaroids: polaroids,
            restoredAt: Date()
        )
        guard let data = try? JSONEncoder.liveIslandLabEncoder.encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: [.atomic])
    }

    private func createFolderIfNeeded() {
        guard !fileManager.fileExists(atPath: folderURL.path) else { return }
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }
}

private enum LiveIslandCameraLabError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        "照片保存失败"
    }
}

struct LiveIslandCameraLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = LiveIslandCameraLabStore()
    @StateObject private var camera = LiveIslandCameraLabCameraModel()

    @State private var activePrintItem: LiveIslandPolaroid?
    @State private var activePrintImage: UIImage?
    @State private var printScale: CGFloat = 0.18
    @State private var printOffset: CGSize = .zero
    @State private var printRotationX: Double = 68
    @State private var printOpacity: Double = 0
    @State private var popScale: CGFloat = 1
    @State private var dragStartProgress: Double = 0
    @State private var errorMessage: String?
    @State private var isCaptureLocked = false
    @State private var animationRunID = UUID()

    private let islandClosedWidth: CGFloat = 132
    private let islandClosedHeight: CGFloat = 38

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    labBackground
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        liveIslandHeader(in: proxy)
                            .padding(.top, 18)
                            .zIndex(3)

                        Spacer(minLength: 20)

                        slotSection(in: proxy)
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if let activePrintImage {
                        activePolaroid(image: activePrintImage)
                            .frame(width: 176, height: 220)
                            .scaleEffect(printScale * popScale)
                            .rotation3DEffect(.degrees(printRotationX), axis: (x: 1, y: 0, z: 0), perspective: 0.62)
                            .offset(printOffset)
                            .opacity(printOpacity)
                            .shadow(color: .black.opacity(0.22), radius: 18, y: 12)
                            .zIndex(2)
                    }

                    shutterButton(in: proxy)
                        .zIndex(4)
                }
                .contentShape(Rectangle())
                .gesture(openDragGesture)
                .overlay(alignment: .bottom) {
                    statusStrip
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }
            }
            .navigationTitle("动态岛拍立得")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        closeImmediately()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("关闭测试页")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("完成")
                            .font(BBBFont.font(size: 15, weight: .bold))
                    }
                }
            }
        }
        .task {
            store.restoreStableOpenState()
            await camera.configure()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                store.restoreStableOpenState()
            }
        }
    }

    private var labBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "#F8FBFF"),
                Color(hex: "#F7F1FA"),
                Color(hex: "#FFF7EC")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func liveIslandHeader(in proxy: GeometryProxy) -> some View {
        let progress = CGFloat(store.islandProgress)
        let openWidth = min(proxy.size.width - 34, 348)
        let width = islandClosedWidth + (openWidth - islandClosedWidth) * progress
        let height = islandClosedHeight + (244 - islandClosedHeight) * progress
        let cornerRadius = islandClosedHeight / 2 + (34 - islandClosedHeight / 2) * progress

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 18, y: 8)

            if progress > 0.06 {
                cameraPreview
                    .opacity(Double((progress - 0.06) / 0.94))
                    .padding(.top, 44)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(Color(hex: "#0F0F12"))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().fill(Color(hex: "#2B3440")).frame(width: 5, height: 5))
                Capsule()
                    .fill(Color(hex: "#1D1D22"))
                    .frame(width: 48, height: 12)
                Circle()
                    .fill(camera.isConfigured ? Color(hex: "#5ED890") : Color(hex: "#73717A"))
                    .frame(width: 7, height: 7)
            }
            .padding(.top, 13)
            .opacity(Double(0.72 + progress * 0.28))
        }
        .frame(width: width, height: height)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: store.islandProgress)
    }

    private var cameraPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(hex: "#141419"))

            if camera.isConfigured {
                LiveIslandCameraLabPreviewView(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Text("LIVE")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.red.opacity(0.82)))
                            .padding(12)
                    }
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("正在打开相机")
                        .font(BBBFont.font(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
        }
    }

    private func shutterButton(in proxy: GeometryProxy) -> some View {
        let isOpen = store.islandProgress > 0.88
        return VStack {
            Spacer()
                .frame(height: 286)

            Button {
                captureOnce()
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.84), lineWidth: 4)
                            .frame(width: 58, height: 58)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: 88, height: 88)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!isOpen || !camera.isConfigured || isCaptureLocked)
            .opacity(isOpen ? 1 : 0)
            .scaleEffect(isOpen ? 1 : 0.82)
            .animation(.spring(response: 0.36, dampingFraction: 0.78), value: isOpen)

            Spacer()
        }
        .frame(width: proxy.size.width)
    }

    private func slotSection(in proxy: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            slotMouth

            ZStack {
                ForEach(Array(store.polaroids.prefix(7).enumerated()), id: \.element.id) { index, polaroid in
                    if let image = store.image(for: polaroid) {
                        storedPolaroid(image: image, polaroid: polaroid, index: index)
                    }
                }

                if store.polaroids.isEmpty {
                    emptySlotHint
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(246, proxy.size.height * 0.32))
        }
        .padding(.horizontal, 20)
    }

    private var slotMouth: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: "#2A2930"))
                .frame(height: 28)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 7)
            Capsule()
                .fill(.white.opacity(0.28))
                .frame(height: 5)
                .padding(.horizontal, 26)
                .offset(y: -7)
            Text("PRINT SLOT")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .tracking(1.4)
        }
        .frame(maxWidth: 286)
    }

    private var emptySlotHint: some View {
        VStack(spacing: 9) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(hex: "#9A9098"))
            Text("拖动打开，按下快门")
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary.opacity(0.76))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
    }

    private func activePolaroid(image: UIImage) -> some View {
        polaroidCard(image: image)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 92, height: 4)
                    .padding(.bottom, 16)
            }
    }

    private func storedPolaroid(image: UIImage, polaroid: LiveIslandPolaroid, index: Int) -> some View {
        let scale = 1 - CGFloat(index) * 0.038
        let y = CGFloat(index) * 13
        let x = CGFloat(index - 3) * 12
        return polaroidCard(image: image)
            .frame(width: 162, height: 204)
            .scaleEffect(scale)
            .rotationEffect(.degrees(polaroid.rotation + Double(index - 2) * 1.2))
            .offset(x: x, y: y)
            .zIndex(Double(20 - index))
            .shadow(color: .black.opacity(0.12), radius: 11, y: 7)
    }

    private func polaroidCard(image: UIImage) -> some View {
        VStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .clipped()

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(hex: "#E7DFDA"))
                .frame(width: 78, height: 5)
                .opacity(0.78)
        }
        .padding(.top, 11)
        .padding(.horizontal, 11)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: "#FFFDF8"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: "#EDE4DD"), lineWidth: 1)
                )
        )
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            phasePill
            Spacer(minLength: 8)
            Text(errorMessage ?? "已保存 \(store.polaroids.count) 张")
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(errorMessage == nil ? DesignToken.textSecondary : Color.red.opacity(0.82))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var phasePill: some View {
        Text(store.phase.rawValue.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.82)))
    }

    private var openDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isCaptureLocked else { return }
                if abs(value.translation.height) < 2, abs(value.translation.width) < 2 {
                    dragStartProgress = store.islandProgress
                }
                let delta = Double(value.translation.height / 210)
                store.updateDragProgress(dragStartProgress + delta)
            }
            .onEnded { value in
                guard !isCaptureLocked else { return }
                let projectedProgress = store.islandProgress + Double(value.predictedEndTranslation.height - value.translation.height) / 260
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    if projectedProgress > 0.44 {
                        store.settleOpen()
                    } else {
                        store.settleClosed()
                    }
                }
            }
    }

    private func captureOnce() {
        guard !isCaptureLocked, camera.isConfigured, store.islandProgress > 0.88 else { return }
        let runID = UUID()
        animationRunID = runID
        isCaptureLocked = true
        errorMessage = nil
        store.setPhase(.shooting)

        camera.capture { image in
            Task { @MainActor in
                guard animationRunID == runID else {
                    isCaptureLocked = false
                    return
                }
                do {
                    let item = try store.storePrintedImage(image)
                    activePrintItem = item
                    activePrintImage = image.normalizedForLiveIslandLab()
                    await runPrintAnimation(for: item, runID: runID)
                } catch {
                    errorMessage = error.localizedDescription
                    store.setPhase(.open)
                    isCaptureLocked = false
                }
            }
        }
    }

    private func runPrintAnimation(for item: LiveIslandPolaroid, runID: UUID) async {
        resetActivePrintPose()
        guard animationRunID == runID else { return }

        store.setPhase(.printing)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            printOpacity = 1
            printScale = 0.56
            printOffset = CGSize(width: 0, height: 134)
            printRotationX = 32
        }

        try? await Task.sleep(nanoseconds: 430_000_000)
        guard animationRunID == runID else { return }

        store.setPhase(.slotting)
        withAnimation(.interpolatingSpring(stiffness: 165, damping: 19)) {
            printScale = 0.88
            printOffset = CGSize(width: 0, height: 424)
            printRotationX = 7
        }

        try? await Task.sleep(nanoseconds: 540_000_000)
        guard animationRunID == runID else { return }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.44)) {
            popScale = 1.08
        }
        try? await Task.sleep(nanoseconds: 130_000_000)
        guard animationRunID == runID else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            popScale = 1
            printOpacity = 0
        }

        try? await Task.sleep(nanoseconds: 180_000_000)
        guard animationRunID == runID else { return }
        store.finishPrinting(item)
        activePrintItem = nil
        activePrintImage = nil
        isCaptureLocked = false
    }

    private func resetActivePrintPose() {
        printScale = 0.18
        printOffset = CGSize(width: 0, height: 14)
        printRotationX = 68
        printOpacity = 0
        popScale = 1
    }

    private func closeImmediately() {
        animationRunID = UUID()
        activePrintItem = nil
        activePrintImage = nil
        isCaptureLocked = false
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            store.settleClosed()
        }
    }
}

private final class LiveIslandCameraLabCameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @MainActor @Published var isConfigured = false

    private let sessionQueue = DispatchQueue(label: "babybuddy.live-island-camera-lab.session")
    private let output = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage) -> Void)?

    func configure() async {
        let authorized = await requestAccessIfNeeded()
        guard authorized else { return }

        await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.configureSession()
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capture(completion: @escaping (UIImage) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = output.maxPhotoQualityPrioritization
        if output.maxPhotoDimensions.width > 0, output.maxPhotoDimensions.height > 0 {
            settings.maxPhotoDimensions = output.maxPhotoDimensions
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    private func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureSession() {
        guard session.inputs.isEmpty, session.outputs.isEmpty else {
            startSessionIfNeeded()
            return
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(output)
        else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .quality
        if let maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }) {
            output.maxPhotoDimensions = maxPhotoDimensions
        }
        session.commitConfiguration()

        startSessionIfNeeded()
    }

    private func startSessionIfNeeded() {
        guard !session.isRunning else {
            Task { @MainActor in
                isConfigured = true
            }
            return
        }
        session.startRunning()
        Task { @MainActor in
            isConfigured = true
        }
    }
}

extension LiveIslandCameraLabCameraModel: @unchecked Sendable {}

extension LiveIslandCameraLabCameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        Task { @MainActor in
            captureCompletion?(image)
            captureCompletion = nil
        }
    }
}

private struct LiveIslandCameraLabPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewView: UIView {
        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

private extension JSONEncoder {
    static var liveIslandLabEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var liveIslandLabDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension UIImage {
    func normalizedForLiveIslandLab() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
