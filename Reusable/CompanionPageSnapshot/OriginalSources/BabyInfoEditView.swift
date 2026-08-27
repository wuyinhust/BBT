import SwiftUI
import PhotosUI
import AVFoundation
import AVKit

private enum AvatarSheetDestination: String, Identifiable {
    case chooser
    case recorder

    var id: String { rawValue }
}

struct BabyInfoEditView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @Binding var isPresented: Bool

    @State private var draftName = ""
    @State private var draftGender: BabyGender = .boy
    @State private var draftBirthDate = Date()
    @State private var draftHeightCm = ""
    @State private var draftWeightKg = ""
    @State private var draftWeightOunces = ""
    @State private var draftAvatarEmoji: String?
    @State private var draftAvatarImageData: Data?
    @State private var draftAvatarCompanionID: String?
    @State private var draftAvatarVideoFilename: String?
    @State private var draftAvatarHistory: [BabyAvatarSnapshot] = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showGenderPicker = false
    @State private var showBirthdayPicker = false
    @State private var activeAvatarSheet: AvatarSheetDestination?
    @State private var avatarImportError: String?
    @State private var activeGrowthMetric: GrowthMetricKind?

    var body: some View {
        NavigationStack {
            ZStack {
                ProfileSoftBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        avatarCard

                        VStack(spacing: 0) {
                            groupRow(title: "名字") {
                                TextField("宝宝名字", text: $draftName)
                                    .textInputAutocapitalization(.never)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(DesignToken.textPrimary)
                                    .font(BBBFont.font(size: 14, weight: .semibold))
                            }

                            divider

                            Button { showGenderPicker = true } label: {
                                groupRow(title: "性别") {
                                    HStack(spacing: 8) {
                                        Text(genderTitle(draftGender))
                                            .foregroundStyle(DesignToken.textPrimary)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(DesignToken.line)
                                    }
                                    .font(BBBFont.font(size: 14, weight: .semibold))
                                }
                            }
                            .buttonStyle(.plain)

                            divider

                            Button { showBirthdayPicker = true } label: {
                                groupRow(title: "出生日期") {
                                    HStack(spacing: 8) {
                                        Text(draftBirthDate, format: .dateTime.year().month().day())
                                            .foregroundStyle(DesignToken.textPrimary)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(DesignToken.line)
                                    }
                                    .font(BBBFont.font(size: 14, weight: .semibold))
                                }
                            }
                            .buttonStyle(.plain)

                            divider

                            groupRow(title: "身高") {
                                HStack(spacing: 5) {
                                    TextField("--", text: $draftHeightCm)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(DesignToken.textPrimary)
                                        .font(BBBFont.font(size: 14, weight: .semibold))
                                        .frame(maxWidth: 74)
                                    Text(AppMeasurementFormat.heightUnit)
                                        .foregroundStyle(DesignToken.textSecondary)
                                        .font(BBBFont.font(size: 13, weight: .semibold))
                                }
                            }

                            divider

                            groupRow(title: "体重") {
                                HStack(spacing: 5) {
                                    TextField("--", text: $draftWeightKg)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(DesignToken.textPrimary)
                                        .font(BBBFont.font(size: 14, weight: .semibold))
                                        .frame(maxWidth: 74)
                                    Text(AppMeasurementFormat.weightPrimaryUnit)
                                        .foregroundStyle(DesignToken.textSecondary)
                                        .font(BBBFont.font(size: 13, weight: .semibold))

                                    if AppMeasurementFormat.currentSystem == .imperial {
                                        TextField("--", text: $draftWeightOunces)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .foregroundStyle(DesignToken.textPrimary)
                                            .font(BBBFont.font(size: 14, weight: .semibold))
                                            .frame(maxWidth: 58)
                                        Text(AppMeasurementFormat.weightSecondaryUnit)
                                            .foregroundStyle(DesignToken.textSecondary)
                                            .font(BBBFont.font(size: 13, weight: .semibold))
                                    }
                                }
                            }

                            divider

                            Button { activeGrowthMetric = .height } label: {
                                groupRow(title: "身高曲线") {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(DesignToken.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)

                            divider

                            Button { activeGrowthMetric = .weight } label: {
                                groupRow(title: "体重曲线") {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(DesignToken.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                        .softProfileCard(cornerRadius: DesignToken.largeCardRadius)

                        Spacer(minLength: 18)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppPageCloseButton {
                        saveDraft()
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("宝宝资料")
                        .foregroundStyle(DesignToken.textPrimary)
                        .font(BBBFont.font(size: 17, weight: .bold))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                let profile = profileStore.currentProfile
                draftName = profile.name
                draftGender = profile.gender
                draftBirthDate = profile.birthDate
                loadMeasurementDrafts(profile)
                draftAvatarEmoji = profile.avatarEmoji
                draftAvatarImageData = profile.avatarImageData
                draftAvatarCompanionID = profile.avatarCompanionID
                draftAvatarVideoFilename = profile.avatarVideoFilename
                draftAvatarHistory = profile.avatarHistoryItems
            }
            .onDisappear(perform: saveDraft)
            .task(id: selectedPhoto) {
                await loadAvatarImage(from: selectedPhoto)
            }
            .sheet(isPresented: $showGenderPicker) {
                NavigationStack {
                    List {
                        ForEach(BabyGender.allCases) { gender in
                            Button {
                                draftGender = gender
                                showGenderPicker = false
                            } label: {
                                HStack {
                                    Text(genderTitle(gender))
                                        .foregroundStyle(DesignToken.textPrimary)
                                    Spacer()
                                    if draftGender == gender {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(DesignToken.primary)
                                    }
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(ProfileSoftBackground().ignoresSafeArea())
                    .navigationTitle("选择性别")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showBirthdayPicker) {
                VStack(spacing: 18) {
                    Text("选择生日")
                        .font(BBBFont.font(size: 17, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    DatePicker("", selection: $draftBirthDate, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    Button("完成") { showBirthdayPicker = false }
                        .primaryButtonStyle()
                }
                .padding(.top, 10)
                .background(ProfileSoftBackground())
                .presentationDetents([.height(360)])
            }
            .sheet(item: $activeAvatarSheet) { destination in
                switch destination {
                case .chooser:
                    avatarPickerSheet
                        .presentationDetents([.height(620)])
                case .recorder:
                    AvatarVideoRecorder { url in
                        useRecordedAvatarVideo(url)
                    }
                    .ignoresSafeArea()
                    .presentationBackground(.black)
                }
            }
            .sheet(item: $activeGrowthMetric) { kind in
                GrowthMetricSheet(kind: kind)
                    .presentationBackground(DesignToken.surfaceSoft)
            }
            .alert("头像导入失败", isPresented: Binding(
                get: { avatarImportError != nil },
                set: { if !$0 { avatarImportError = nil } }
            )) {
                Button("知道了", role: .cancel) { avatarImportError = nil }
            } message: {
                Text(avatarImportError ?? "")
            }
        }
    }

    private var avatarCard: some View {
        VStack(spacing: 10) {
            Button {
                activeAvatarSheet = .chooser
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignToken.surfaceRaised,
                                    DesignToken.primary.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .overlay(avatarPreview(size: 90, emojiSize: 44))
                        .overlay(Circle().stroke(DesignToken.primary.opacity(0.48), lineWidth: 2))

                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(width: 27, height: 27)
                        .background(Circle().fill(DesignToken.primaryGradient))
                        .overlay(Circle().stroke(DesignToken.onPrimary, lineWidth: 2))
                        .offset(x: -2, y: -2)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("更换头像")

            VStack(spacing: 4) {
                Text(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "宝宝" : draftName)
                    .font(BBBFont.font(size: 20, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, DesignToken.compactHorizontalPadding)
    }

    private var avatarPickerSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("更换头像")
                    .font(BBBFont.font(size: 17, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 12) {
                    Button {
                        activeAvatarSheet = .recorder
                    } label: {
                        avatarSourceTile(icon: "video.fill", title: "录个动态头像", tint: DesignToken.accentBlue)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .frame(maxWidth: .infinity)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        avatarSourceTile(icon: "photo.fill", title: "从照册中选择", tint: DesignToken.primary)
                    }
                    .frame(maxWidth: .infinity)

                    Button {
                        activeAvatarSheet = nil
                    } label: {
                        currentAvatarTile
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Buddy 立绘")
                        .font(BBBFont.font(size: 13, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(BabyCompanion.all) { companion in
                                Button {
                                    draftAvatarCompanionID = companion.id
                                    draftAvatarEmoji = nil
                                    draftAvatarImageData = nil
                                    draftAvatarVideoFilename = nil
                                    activeAvatarSheet = nil
                                } label: {
                                    VStack(spacing: 7) {
                                        Image(companion.portraitAssetName)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(7)
                                            .frame(width: 62, height: 62)
                                            .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.94)))
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        draftAvatarCompanionID == companion.id ? DesignToken.primary : DesignToken.line.opacity(0.34),
                                                        lineWidth: draftAvatarCompanionID == companion.id ? 2.5 : 1
                                                    )
                                            )
                                        Text(companion.localizedName)
                                            .font(BBBFont.font(size: 10, weight: .semibold))
                                            .foregroundStyle(DesignToken.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if !draftAvatarHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("历史头像")
                            .font(BBBFont.font(size: 13, weight: .bold))
                            .foregroundStyle(DesignToken.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(draftAvatarHistory.filter(\.isRenderable)) { item in
                                    Button {
                                        applyAvatarSnapshot(item)
                                        activeAvatarSheet = nil
                                    } label: {
                                        BabyAvatarSnapshotView(
                                            snapshot: item,
                                            fallbackEmoji: selectedAvatar,
                                            size: 58,
                                            emojiSize: 28,
                                            isSelected: item.isSameAvatar(as: currentAvatarSnapshot)
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

            }
            .padding(DesignToken.screenHorizontalPadding)
        }
        .background(ProfileSoftBackground())
    }

    private func avatarSourceTile(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.62)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: tint.opacity(0.22), radius: 10, y: 5)
                )
            Text(title.localized)
                .font(BBBFont.font(size: 11, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var currentAvatarTile: some View {
        VStack(spacing: 8) {
            ZStack {
                if let selectedHistory = draftAvatarHistory.first(where: { $0.isSameAvatar(as: currentAvatarSnapshot) }) {
                    BabyAvatarSnapshotView(
                        snapshot: selectedHistory,
                        fallbackEmoji: selectedAvatar,
                        size: 58,
                        emojiSize: 28,
                        isSelected: true
                    )
                } else {
                    avatarPreview(size: 58, emojiSize: 28)
                }
            }
            .frame(width: 58, height: 58)

            Text("我的当前头像")
                .font(BBBFont.font(size: 11, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var selectedAvatar: String {
        draftAvatarEmoji ?? draftGender.emoji
    }

    @ViewBuilder
    private func avatarPreview(size: CGFloat, emojiSize: CGFloat) -> some View {
        BabyProfileAvatarView(
            profile: draftAvatarProfile,
            size: size,
            emojiSize: emojiSize,
            lineWidth: 0,
            motionScale: 0.9
        )
    }

    private var draftAvatarProfile: BabyProfileData {
        BabyProfileData(
            name: draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "宝宝" : draftName,
            gender: draftGender,
            birthDate: draftBirthDate,
            heightCm: canonicalHeightValue,
            weightKg: canonicalWeightValue,
            avatarEmoji: draftAvatarEmoji,
            avatarImageData: draftAvatarImageData,
            avatarCompanionID: draftAvatarCompanionID,
            avatarVideoFilename: draftAvatarVideoFilename,
            avatarHistory: draftAvatarHistory,
            avatarMotionEnabled: true
        )
    }

    private var currentAvatarSnapshot: BabyAvatarSnapshot {
        draftAvatarProfile.avatarSnapshot
    }

    private func avatarHistoryForSave() -> [BabyAvatarSnapshot] {
        let current = currentAvatarSnapshot
        var items = draftAvatarHistory.filter { !$0.isSameAvatar(as: current) }
        let original = profileStore.currentProfile.avatarSnapshot
        if original.isRenderable && !original.isSameAvatar(as: current) {
            items.removeAll { $0.isSameAvatar(as: original) }
            items.insert(original, at: 0)
        }
        return Array(items.prefix(8))
    }

    private func saveDraft() {
        profileStore.create(
            name: draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "宝宝"
                : draftName.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: draftGender,
            birthDate: draftBirthDate,
            heightCm: canonicalHeightValue,
            weightKg: canonicalWeightValue,
            avatarEmoji: draftAvatarEmoji,
            avatarImageData: draftAvatarImageData,
            avatarCompanionID: draftAvatarCompanionID,
            avatarVideoFilename: draftAvatarVideoFilename,
            avatarHistory: avatarHistoryForSave()
        )
    }

    private func applyAvatarSnapshot(_ snapshot: BabyAvatarSnapshot) {
        draftAvatarEmoji = snapshot.emoji
        draftAvatarImageData = snapshot.imageData
        draftAvatarCompanionID = snapshot.companionID
        draftAvatarVideoFilename = snapshot.videoFilename
    }

    @MainActor
    private func loadAvatarImage(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              data.count <= BBBDataSafetyLimits.maxImageDataBytes else {
            return
        }
        guard !Task.isCancelled else { return }
        let compressed = await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                BBBImageDataImporter.downsampledJPEG(data: data, compressionQuality: 0.82)
            }
        }.value
        guard !Task.isCancelled, let compressed else { return }
        draftAvatarImageData = compressed
        draftAvatarEmoji = nil
        draftAvatarCompanionID = nil
        draftAvatarVideoFilename = nil
        activeAvatarSheet = nil
        selectedPhoto = nil
    }

    @MainActor
    @discardableResult
    private func useRecordedAvatarVideo(_ temporaryURL: URL) -> Bool {
        do {
            let filename = try BabyAvatarVideoStore.saveVideo(from: temporaryURL)
            draftAvatarVideoFilename = filename
            draftAvatarEmoji = nil
            draftAvatarImageData = nil
            draftAvatarCompanionID = nil
            activeAvatarSheet = nil
            return true
        } catch {
            avatarImportError = "无法保存这段头像视频，请重试。"
            return false
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignToken.line.opacity(0.55))
            .frame(height: 1)
            .padding(.leading, 20)
    }

    private func groupRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title.localized)
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
            Spacer()
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func genderTitle(_ gender: BabyGender) -> String {
        switch gender {
        case .boy: return "男宝".localized
        case .girl: return "女宝".localized
        }
    }

    private func metricText(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "" }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private var canonicalHeightValue: Double? {
        guard let displayValue = decimalValue(from: draftHeightCm) else { return nil }
        return AppMeasurementFormat.centimeters(fromHeightValue: displayValue)
    }

    private var canonicalWeightValue: Double? {
        guard let primaryValue = decimalValue(from: draftWeightKg) else { return nil }
        guard AppMeasurementFormat.currentSystem == .imperial else { return primaryValue }
        let ounces = AppMeasurementFormat.parseNumber(draftWeightOunces) ?? 0
        return AppMeasurementFormat.kilograms(pounds: primaryValue, ounces: ounces)
    }

    private func loadMeasurementDrafts(_ profile: BabyProfileData) {
        if let height = profile.heightCm, height.isFinite {
            let displayHeight = AppMeasurementFormat.heightValue(fromCentimeters: height)
            draftHeightCm = AppMeasurementFormat.inputNumber(displayHeight, maximumFractionDigits: 1)
        } else {
            draftHeightCm = ""
        }

        guard let weight = profile.weightKg, weight.isFinite else {
            draftWeightKg = ""
            draftWeightOunces = ""
            return
        }

        if AppMeasurementFormat.currentSystem == .imperial {
            let displayWeight = AppMeasurementFormat.poundsAndOunces(fromKilograms: weight)
            draftWeightKg = String(displayWeight.pounds)
            draftWeightOunces = AppMeasurementFormat.inputNumber(displayWeight.ounces, maximumFractionDigits: 1)
        } else {
            draftWeightKg = metricText(weight)
            draftWeightOunces = ""
        }
    }

    private func decimalValue(from text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = AppMeasurementFormat.parseNumber(normalized), value > 0 else {
            return nil
        }
        return value
    }
}

private struct AvatarVideoRecorder: View {
    let onComplete: (URL) -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = AvatarVideoCameraModel()
    @State private var recordedURL: URL?
    @State private var reviewPlayer: AVQueuePlayer?
    @State private var reviewLooper: AVPlayerLooper?
    @State private var recordingStartedAt: Date?
    @State private var recordingElapsed: TimeInterval = 0
    @State private var isFinishingRecording = false
    @State private var focusPoint: CGPoint?
    @State private var zoomAtGestureStart: CGFloat = 1
    @State private var didConfirmRecording = false
    @State private var isCameraSurfaceVisible = false
    @State private var recorderError: String?

    private let maxRecordingDuration: TimeInterval = 3

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let recordedURL {
                reviewSurface(url: recordedURL)
            } else {
                captureSurface
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .task {
            isCameraSurfaceVisible = true
            await camera.configure()
        }
        .task(id: recordingStartedAt) {
            await updateRecordingClock()
        }
        .onDisappear {
            isCameraSurfaceVisible = false
            camera.stop()
            removeUnconfirmedRecording()
        }
        .onChange(of: scenePhase) { _, phase in
            guard isCameraSurfaceVisible, recordedURL == nil else { return }
            if phase == .active {
                Task { await camera.configure() }
            } else {
                camera.stop()
            }
        }
        .alert("录制失败", isPresented: Binding(
            get: { camera.recordingErrorMessage != nil },
            set: { if !$0 { camera.recordingErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(camera.recordingErrorMessage ?? "请重试。")
        }
        .alert("相机不可用", isPresented: Binding(
            get: { recorderError != nil },
            set: { if !$0 { recorderError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(recorderError ?? "请重试。")
        }
    }

    private var captureSurface: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                cameraTopBar(title: "动态头像", onClose: closeRecorder)

                Spacer(minLength: 10)

                if camera.errorMessage == nil {
                    cameraPreview
                } else {
                    cameraUnavailableView(message: camera.errorMessage ?? "相机不可用。")
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 12)

                Text(camera.isRecording ? "再次点击停止，最长 3 秒" : "点击开始录制，头像会循环播放")
                    .font(BBBFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                captureControls
                    .padding(.top, 10)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
            }
            .padding(.top, max(proxy.safeAreaInsets.top, 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var cameraPreview: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                AvatarVideoCameraPreview(
                    session: camera.session,
                    position: camera.activePosition
                )
                .frame(width: side, height: side)

                Circle()
                    .stroke(
                        .white.opacity(camera.isRecording ? 0.88 : 0.52),
                        style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                    )
                    .frame(width: side * 0.72, height: side * 0.72)
                    .overlay(alignment: .bottom) {
                        Text("头像取景区")
                            .font(BBBFont.font(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.38), in: Capsule())
                            .offset(y: 28)
                    }
                    .allowsHitTesting(false)

                if !camera.isConfigured {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.1)
                }

                if camera.isRecording {
                    VStack {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text(recordingTimeText)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.44), in: Capsule())
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                }

                if let focusPoint {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(.white.opacity(0.92), lineWidth: 1.5)
                        .frame(width: 54, height: 54)
                        .position(focusPoint)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(Rectangle())
            .gesture(focusGesture(size: CGSize(width: side, height: side)))
            .simultaneousGesture(zoomGesture)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 14)
    }

    private var captureControls: some View {
        HStack(alignment: .center) {
            cameraChromeButton(
                systemName: "camera.rotate",
                accessibilityLabel: "切换前后摄像头"
            ) {
                camera.switchCamera()
            }
            .disabled(!camera.isConfigured || camera.isRecording || camera.isSwitchingCamera)

            Spacer()

            Button {
                toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.34), lineWidth: 5)
                        .frame(width: 92, height: 92)

                    Circle()
                        .trim(from: 0, to: camera.isRecording ? recordingProgress : 1)
                        .stroke(.red, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 92, height: 92)

                    Circle()
                        .fill(camera.isRecording ? .red : .white)
                        .frame(width: camera.isRecording ? 62 : 68, height: camera.isRecording ? 62 : 68)

                    if camera.isRecording {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    }
                }
                .animation(.easeOut(duration: 0.14), value: camera.isRecording)
            }
            .buttonStyle(.plain)
            .disabled(!camera.isConfigured || isFinishingRecording)
            .accessibilityLabel(camera.isRecording ? "停止录制" : "开始录制动态头像")
            .accessibilityValue(camera.isRecording ? recordingTimeText : "最长 3 秒")

            Spacer()

            VStack(spacing: 5) {
                Image(systemName: camera.activePosition == .front ? "person.crop.circle" : "camera.aperture")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                Text(camera.activePosition == .front ? "前置" : "后置")
                    .font(BBBFont.font(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.76))
            }
            .frame(width: 64, height: 64)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("当前摄像头")
            .accessibilityValue(camera.activePosition == .front ? "前置" : "后置")
        }
        .padding(.horizontal, 28)
        .frame(height: 104)
    }

    private func reviewSurface(url: URL) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                cameraTopBar(title: "确认动态头像", onClose: closeRecorder)

                Spacer(minLength: 20)

                Text("这段视频看起来合适吗？")
                    .font(BBBFont.font(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer(minLength: 18)

                Group {
                    if let reviewPlayer {
                        VideoPlayer(player: reviewPlayer)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(Circle())
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(width: min(proxy.size.width - 48, 300), height: min(proxy.size.width - 48, 300))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.6), lineWidth: 2)
                )
                .task(id: url) {
                    prepareReviewPlayer(url)
                }

                Text("确认后会保存为宝宝头像，并在头像位置循环播放。")
                    .font(BBBFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)

                Spacer(minLength: 24)

                HStack(spacing: 12) {
                    Button("重拍") {
                        discardRecordingAndRetry()
                    }
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.white.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))

                    Button("使用这段") {
                        confirmRecording()
                    }
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .primaryButtonStyle()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 14))
            }
            .padding(.top, max(proxy.safeAreaInsets.top, 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cameraTopBar(title: String, onClose: @escaping () -> Void) -> some View {
        HStack {
            cameraChromeButton(systemName: "xmark", accessibilityLabel: "关闭动态头像拍摄", action: onClose)
            Spacer()
            Text(title)
                .font(BBBFont.font(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }

    private func cameraChromeButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
                .background(.white.opacity(0.13), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func cameraUnavailableView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
            Text(message.localized)
                .font(BBBFont.font(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
            if camera.canOpenSettingsForError {
                Button("前往设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .frame(minHeight: DesignToken.minimumTapSize)
                .background(Capsule().fill(.white))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recordingProgress: CGFloat {
        min(max(CGFloat(recordingElapsed / maxRecordingDuration), 0), 1)
    }

    private var recordingTimeText: String {
        String(format: "0:%.1f", min(recordingElapsed, maxRecordingDuration))
    }

    private func toggleRecording() {
        if camera.isRecording {
            finishRecording()
            return
        }
        guard camera.isConfigured, !isFinishingRecording else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("avatar-recording-\(UUID().uuidString)")
            .appendingPathExtension("mov")
        recordingStartedAt = Date()
        recordingElapsed = 0
        camera.startRecording(to: url) { result in
            recordingStartedAt = nil
            recordingElapsed = 0
            isFinishingRecording = false

            switch result {
            case .success(let finishedURL):
                guard isCameraSurfaceVisible else {
                    try? FileManager.default.removeItem(at: finishedURL)
                    return
                }
                camera.stop()
                recordedURL = finishedURL
            case .failure:
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func finishRecording() {
        guard camera.isRecording, !isFinishingRecording else { return }
        isFinishingRecording = true
        camera.stopRecording()
    }

    private func updateRecordingClock() async {
        guard let recordingStartedAt else {
            recordingElapsed = 0
            return
        }

        while !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(recordingStartedAt)
            recordingElapsed = min(max(elapsed, 0), maxRecordingDuration)
            if elapsed >= maxRecordingDuration {
                finishRecording()
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func prepareReviewPlayer(_ url: URL) {
        reviewPlayer?.pause()
        reviewPlayer = nil
        reviewLooper = nil

        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        reviewPlayer = player
        reviewLooper = looper
        player.play()
    }

    private func discardRecordingAndRetry() {
        if let recordedURL {
            try? FileManager.default.removeItem(at: recordedURL)
        }
        reviewPlayer?.pause()
        reviewPlayer = nil
        reviewLooper = nil
        recordedURL = nil
        didConfirmRecording = false
        Task { await camera.configure() }
    }

    private func confirmRecording() {
        guard let recordedURL else { return }
        guard onComplete(recordedURL) else {
            recorderError = "无法保存这段头像视频，请重试。"
            return
        }
        didConfirmRecording = true
        dismiss()
    }

    private func closeRecorder() {
        dismiss()
    }

    private func removeUnconfirmedRecording() {
        guard !didConfirmRecording, let recordedURL else { return }
        try? FileManager.default.removeItem(at: recordedURL)
    }

    private func focusGesture(size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                focusPoint = value.location
                camera.focus(at: CGPoint(
                    x: min(max(value.location.y / size.height, 0), 1),
                    y: min(max(1 - value.location.x / size.width, 0), 1)
                ))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.18)) { focusPoint = nil }
                }
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                camera.setZoomFactor(zoomAtGestureStart * value.magnification, ramped: false)
            }
            .onEnded { _ in
                zoomAtGestureStart = camera.zoomFactor
            }
    }
}

private struct AvatarVideoCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let position: AVCaptureDevice.Position

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.updateConnection(position: position)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.updateConnection(position: position)
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: ()) {
        uiView.previewLayer.session = nil
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        func updateConnection(position: AVCaptureDevice.Position) {
            guard let connection = previewLayer.connection else { return }
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            connection.automaticallyAdjustsVideoMirroring = false
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = position == .front
            }
        }
    }
}

private final class AvatarVideoCameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @MainActor @Published var isConfigured = false
    @MainActor @Published var isRecording = false
    @MainActor @Published var isSwitchingCamera = false
    @MainActor @Published var activePosition: AVCaptureDevice.Position = .front
    @MainActor @Published var zoomFactor: CGFloat = 1
    @MainActor @Published var displayZoomMultiplier: CGFloat = 1
    @MainActor @Published var errorMessage: String?
    @MainActor @Published var canOpenSettingsForError = false
    @MainActor @Published var recordingErrorMessage: String?

    private let sessionQueue = DispatchQueue(label: "babybuddy.avatar.camera.session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var pendingURL: URL?
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?
    private let lifecycleLock = NSLock()
    private var configurationGeneration = 0
    private var isStopped = true

    func configure() async {
        let generation = beginConfigurationGeneration()
        let authorized = await requestAccessIfNeeded()
        guard !Task.isCancelled, isConfigurationCurrent(generation) else { return }
        guard authorized else {
            await MainActor.run {
                guard self.isConfigurationCurrent(generation) else { return }
                errorMessage = "未获得相机权限，请在系统设置中允许访问相机。"
                canOpenSettingsForError = true
            }
            return
        }

        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard self.isConfigurationCurrent(generation) else {
                    continuation.resume()
                    return
                }
                self.configureSession(generation: generation)
                continuation.resume()
            }
        }
    }

    func stop() {
        invalidateConfigurationGeneration()
        sessionQueue.async {
            self.recordingCompletion = nil
            let pendingURL = self.pendingURL
            self.pendingURL = nil
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            if let pendingURL {
                try? FileManager.default.removeItem(at: pendingURL)
            }
            Task { @MainActor in
                guard self.configurationIsStopped() else { return }
                self.isConfigured = false
                self.isRecording = false
                self.isSwitchingCamera = false
            }
        }
    }

    @MainActor
    func startRecording(
        to url: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard isConfigured,
              !isRecording,
              let generation = activeConfigurationGeneration() else {
            return
        }

        isRecording = true
        recordingErrorMessage = nil
        sessionQueue.async {
            guard self.isConfigurationCurrent(generation),
                  self.session.isRunning,
                  !self.movieOutput.isRecording else {
                self.failRecording(generation: generation, message: "相机尚未准备好，请稍后重试。")
                return
            }

            self.pendingURL = url
            self.recordingCompletion = completion
            self.movieOutput.maxRecordedDuration = CMTime(seconds: 3, preferredTimescale: 600)
            self.configureMovieConnection(position: self.currentInput?.device.position ?? .front)
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        sessionQueue.async {
            guard self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
    }

    @MainActor
    func switchCamera() {
        guard !isRecording,
              !isSwitchingCamera,
              let generation = activeConfigurationGeneration() else {
            return
        }
        isSwitchingCamera = true
        let target: AVCaptureDevice.Position = activePosition == .front ? .back : .front
        sessionQueue.async {
            self.replaceCameraInput(position: target, generation: generation)
        }
    }

    @MainActor
    func focus(at normalizedPoint: CGPoint) {
        guard let generation = activeConfigurationGeneration() else { return }
        sessionQueue.async {
            guard self.isConfigurationCurrent(generation),
                  let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = normalizedPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = normalizedPoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            } catch {}
        }
    }

    @MainActor
    func setZoomFactor(_ factor: CGFloat, ramped: Bool = true) {
        guard let generation = activeConfigurationGeneration() else { return }
        sessionQueue.async {
            guard self.isConfigurationCurrent(generation),
                  let device = self.currentInput?.device else { return }
            let maximum = min(device.maxAvailableVideoZoomFactor, 6)
            let clamped = min(max(factor, device.minAvailableVideoZoomFactor), maximum)
            do {
                try device.lockForConfiguration()
                if ramped {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 8)
                } else {
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
                Task { @MainActor in
                    guard self.isConfigurationCurrent(generation) else { return }
                    self.zoomFactor = clamped
                }
            } catch {}
        }
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

    private func configureSession(generation: Int) {
        guard isConfigurationCurrent(generation) else { return }

        if !session.inputs.isEmpty, !session.outputs.isEmpty {
            configureMovieConnection(position: currentInput?.device.position ?? .front)
            startSessionIfNeeded(generation: generation)
            return
        }

        guard let device = Self.cameraDevice(position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(movieOutput) else {
            publishCameraError(generation: generation, message: "当前设备无法启动相机。")
            return
        }

        Self.configurePreviewFrameRate(for: device)
        Self.resetDefaultZoom(for: device)
        session.beginConfiguration()
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        session.addInput(input)
        currentInput = input
        session.addOutput(movieOutput)
        movieOutput.maxRecordedDuration = CMTime(seconds: 3, preferredTimescale: 600)
        configureMovieConnection(position: .front)
        session.commitConfiguration()

        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            errorMessage = nil
            canOpenSettingsForError = false
            activePosition = .front
            displayZoomMultiplier = device.displayVideoZoomFactorMultiplier
            zoomFactor = device.videoZoomFactor
        }
        startSessionIfNeeded(generation: generation)
    }

    private func replaceCameraInput(position: AVCaptureDevice.Position, generation: Int) {
        defer {
            Task { @MainActor in
                guard self.isConfigurationCurrent(generation) else { return }
                self.isSwitchingCamera = false
            }
        }
        guard isConfigurationCurrent(generation),
              let device = Self.cameraDevice(position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        Self.configurePreviewFrameRate(for: device)
        Self.resetDefaultZoom(for: device)
        let oldInput = currentInput
        var installedPosition = oldInput?.device.position ?? position
        session.beginConfiguration()
        if let oldInput {
            session.removeInput(oldInput)
        }
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
            installedPosition = position
        } else if let oldInput, session.canAddInput(oldInput) {
            session.addInput(oldInput)
            currentInput = oldInput
            installedPosition = oldInput.device.position
        }
        configureMovieConnection(position: installedPosition)
        session.commitConfiguration()

        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            activePosition = installedPosition
            displayZoomMultiplier = device.displayVideoZoomFactorMultiplier
            zoomFactor = device.videoZoomFactor
        }
    }

    private func configureMovieConnection(position: AVCaptureDevice.Position) {
        guard let connection = movieOutput.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = position == .front
        }
    }

    private static func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private static func configurePreviewFrameRate(for device: AVCaptureDevice) {
        let targetFPS = 30.0
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= targetFPS && $0.maxFrameRate >= targetFPS
        }) else { return }
        do {
            try device.lockForConfiguration()
            let duration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {}
    }

    private static func resetDefaultZoom(for device: AVCaptureDevice) {
        let multiplier = max(device.displayVideoZoomFactorMultiplier, 0.01)
        let oneTimesFactor = min(
            max(1 / multiplier, device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )
        do {
            try device.lockForConfiguration()
            device.cancelVideoZoomRamp()
            device.videoZoomFactor = oneTimesFactor
            device.unlockForConfiguration()
        } catch {}
    }

    private func startSessionIfNeeded(generation: Int) {
        guard isConfigurationCurrent(generation) else { return }
        if !session.isRunning {
            session.startRunning()
        }
        guard isConfigurationCurrent(generation) else {
            session.stopRunning()
            return
        }
        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            self.isConfigured = true
        }
    }

    private func publishCameraError(generation: Int, message: String) {
        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            errorMessage = message
            canOpenSettingsForError = false
            isConfigured = false
        }
    }

    private func failRecording(generation: Int, message: String) {
        let completion = recordingCompletion
        recordingCompletion = nil
        let url = pendingURL
        pendingURL = nil
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        let error = NSError(
            domain: "BabyBuddy.AvatarVideoCamera",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            isRecording = false
            recordingErrorMessage = message
            completion?(.failure(error))
        }
    }

    private func beginConfigurationGeneration() -> Int {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        configurationGeneration &+= 1
        isStopped = false
        return configurationGeneration
    }

    private func invalidateConfigurationGeneration() {
        lifecycleLock.lock()
        configurationGeneration &+= 1
        isStopped = true
        lifecycleLock.unlock()
    }

    private func isConfigurationCurrent(_ generation: Int) -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return !isStopped && generation == configurationGeneration
    }

    private func configurationIsStopped() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isStopped
    }

    private func activeConfigurationGeneration() -> Int? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isStopped ? nil : configurationGeneration
    }
}

extension AvatarVideoCameraModel: @unchecked Sendable {}

extension AvatarVideoCameraModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        sessionQueue.async {
            let completion = self.recordingCompletion
            self.recordingCompletion = nil
            self.pendingURL = nil

            guard let completion else {
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }

            if let error {
                try? FileManager.default.removeItem(at: outputFileURL)
                Task { @MainActor in
                    self.isRecording = false
                    self.recordingErrorMessage = "视频保存失败，请重试。"
                    completion(.failure(error))
                }
            } else {
                Task { @MainActor in
                    self.isRecording = false
                    completion(.success(outputFileURL))
                }
            }
        }
    }
}
