import SwiftUI
import PhotosUI

struct BabyInfoEditView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @Binding var isPresented: Bool

    @State private var draftName = ""
    @State private var draftGender: BabyGender = .boy
    @State private var draftBirthDate = Date()
    @State private var draftAvatarEmoji: String?
    @State private var draftAvatarImageData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showGenderPicker = false
    @State private var showBirthdayPicker = false
    @State private var showAvatarPicker = false

    private let avatarOptions = ["👶🏻", "👶🏼", "👶🏽", "👦🏻", "👧🏻", "🧒🏻", "😊", "🥰", "😴", "🍼", "🌙", "⭐️"]

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
                        }
                        .padding(.vertical, 2)
                        .softProfileCard(cornerRadius: 22)

                        Button {
                            profileStore.create(
                                name: draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "宝宝" : draftName.trimmingCharacters(in: .whitespacesAndNewlines),
                                gender: draftGender,
                                birthDate: draftBirthDate,
                                avatarEmoji: draftAvatarEmoji,
                                avatarImageData: draftAvatarImageData
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
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.white.opacity(0.92)))
                            .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 1))
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
                draftAvatarEmoji = profile.avatarEmoji
                draftAvatarImageData = profile.avatarImageData
            }
            .onChange(of: selectedPhoto) { _, item in
                Task { await loadAvatarImage(from: item) }
            }
            .sheet(isPresented: $showGenderPicker) {
                VStack(spacing: 18) {
                    Text("选择性别")
                        .font(BBBFont.font(size: 17, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Picker("性别", selection: $draftGender) {
                        ForEach(BabyGender.allCases) { gender in
                            Text("\(gender.emoji) \(genderTitle(gender))").tag(gender)
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
                    .presentationDetents([.height(390)])
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
                                    .white,
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
                        .foregroundStyle(.white)
                        .frame(width: 27, height: 27)
                        .background(Circle().fill(DesignToken.primaryGradient))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
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
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .softProfileCard(cornerRadius: 22)
    }

    private var avatarPickerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("选择头像")
                .font(BBBFont.font(size: 17, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 15, weight: .bold))
                    Text("从照片中选择")
                        .font(BBBFont.font(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.line)
                }
                .foregroundStyle(DesignToken.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .softProfileCard(cornerRadius: 18, shadowOpacity: 0.04)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(avatarOptions, id: \.self) { avatar in
                    Button {
                        draftAvatarEmoji = avatar
                        draftAvatarImageData = nil
                        showAvatarPicker = false
                    } label: {
                        Text(avatar)
                            .font(.system(size: 28))
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(avatar == selectedAvatar ? DesignToken.primary.opacity(0.20) : .white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(avatar == selectedAvatar ? DesignToken.primary : DesignToken.line.opacity(0.34), lineWidth: avatar == selectedAvatar ? 2 : 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(20)
        .background(ProfileSoftBackground())
    }

    private var selectedAvatar: String {
        draftAvatarEmoji ?? draftGender.emoji
    }

    @ViewBuilder
    private func avatarPreview(size: CGFloat, emojiSize: CGFloat) -> some View {
        if let draftAvatarImageData,
           let image = UIImage(data: draftAvatarImageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(selectedAvatar)
                .font(.system(size: emojiSize))
        }
    }

    @MainActor
    private func loadAvatarImage(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.82) else {
            return
        }
        draftAvatarImageData = compressed
        draftAvatarEmoji = nil
        showAvatarPicker = false
        selectedPhoto = nil
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignToken.line.opacity(0.55))
            .frame(height: 1)
            .padding(.leading, 20)
    }

    private func groupRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
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
        case .boy: return "男宝"
        case .girl: return "女宝"
        }
    }
}
