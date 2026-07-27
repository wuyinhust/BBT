import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
    @State private var showAvatarPicker = false
    @State private var showAvatarRecorder = false
    @State private var avatarImportError: String?

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
                        }
                        .padding(.vertical, 2)
                        .softProfileCard(cornerRadius: DesignToken.largeCardRadius)

                        Button {
                            profileStore.create(
                                name: draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "宝宝" : draftName.trimmingCharacters(in: .whitespacesAndNewlines),
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
                            isPresented = false
                        } label: {
                            Text("保存修改")
                                .font(BBBFont.font(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                        }
                        .primaryButtonStyle()
                        .padding(.top, 6)

                        Spacer(minLength: 18)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DesignToken.textPrimary)
                            .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
                            .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.92)))
                            .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.86), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
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
            .task(id: selectedPhoto) {
                await loadAvatarImage(from: selectedPhoto)
            }
            .sheet(isPresented: $showAvatarRecorder) {
                AvatarVideoRecorder { url in
                    useRecordedAvatarVideo(url)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showGenderPicker) {
                VStack(spacing: 18) {
                    Text("选择性别")
                        .font(BBBFont.font(size: 17, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Picker("性别", selection: $draftGender) {
                        ForEach(BabyGender.allCases) { gender in
                            Text(genderTitle(gender)).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    Button("完成") { showGenderPicker = false }
                        .primaryButtonStyle()
                }
                .padding(.top, 10)
                .background(ProfileSoftBackground())
                .presentationDetents([.height(220)])
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
            .sheet(isPresented: $showAvatarPicker) {
                avatarPickerSheet
                    .presentationDetents([.height(620)])
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
                showAvatarPicker = true
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
                Text("点击头像更换")
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, DesignToken.compactHorizontalPadding)
        .softProfileCard(cornerRadius: DesignToken.largeCardRadius)
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
                        showAvatarRecorder = true
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
                        showAvatarPicker = false
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
                                    showAvatarPicker = false
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
                                        showAvatarPicker = false
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

    private func applyAvatarSnapshot(_ snapshot: BabyAvatarSnapshot) {
        draftAvatarEmoji = snapshot.emoji
        draftAvatarImageData = snapshot.imageData
        draftAvatarCompanionID = snapshot.companionID
        draftAvatarVideoFilename = snapshot.videoFilename
    }

    @MainActor
    private func loadAvatarImage(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else {
            return
        }
        guard !Task.isCancelled else { return }
        let compressed = await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                UIImage(data: data)?.jpegData(compressionQuality: 0.82)
            }
        }.value
        guard !Task.isCancelled, let compressed else { return }
        draftAvatarImageData = compressed
        draftAvatarEmoji = nil
        draftAvatarCompanionID = nil
        draftAvatarVideoFilename = nil
        showAvatarPicker = false
        selectedPhoto = nil
    }

    @MainActor
    private func useRecordedAvatarVideo(_ temporaryURL: URL) {
        do {
            let filename = try BabyAvatarVideoStore.saveVideo(from: temporaryURL)
            draftAvatarVideoFilename = filename
            draftAvatarEmoji = nil
            draftAvatarImageData = nil
            draftAvatarCompanionID = nil
            showAvatarPicker = false
        } catch {
            avatarImportError = "无法保存这段头像视频，请重试。"
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

private struct AvatarVideoRecorder: UIViewControllerRepresentable {
    var onComplete: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.videoMaximumDuration = 3
        picker.videoQuality = .typeMedium

        let usesCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        if usesCamera {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        if UIImagePickerController.availableMediaTypes(for: picker.sourceType)?.contains(UTType.movie.identifier) == true {
            picker.mediaTypes = [UTType.movie.identifier]
        }
        if usesCamera {
            picker.cameraCaptureMode = .video
            if UIImagePickerController.isCameraDeviceAvailable(.front) {
                picker.cameraDevice = .front
            }
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onComplete: (URL) -> Void
        private let dismiss: DismissAction

        init(onComplete: @escaping (URL) -> Void, dismiss: DismissAction) {
            self.onComplete = onComplete
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let url = info[.mediaURL] as? URL {
                onComplete(url)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
