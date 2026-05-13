import SwiftUI

struct BabyInfoEditView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @Binding var isPresented: Bool

    @State private var draftName = ""
    @State private var draftGender: BabyGender = .boy
    @State private var draftBirthDate = Date()
    @State private var showGenderPicker = false
    @State private var showBirthdayPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#1C1C22").ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Circle().stroke(Color(hex: "#FF67AA"), lineWidth: 5).frame(width: 160, height: 160)
                            .overlay(Text(draftGender.emoji).font(.system(size: 80)))
                        Text("Tap to change")
                            .foregroundStyle(Color(hex: "#FF67AA"))
                            .font(.system(size: 20, weight: .semibold))
                    }

                    groupRow(title: "Name") {
                        TextField("Name", text: $draftName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color(hex: "#FF67AA"))
                    }

                    Button { showGenderPicker = true } label: {
                        groupRow(title: "Gender") {
                            Text(draftGender.rawValue)
                                .foregroundStyle(Color(hex: "#FF67AA"))
                        }
                    }

                    Button { showBirthdayPicker = true } label: {
                        groupRow(title: "Birthday") {
                            Text(draftBirthDate, format: .dateTime.year().month().day())
                                .foregroundStyle(Color(hex: "#FF67AA"))
                        }
                    }

                    Spacer()

                    Button {
                        profileStore.create(
                            name: draftName.isEmpty ? "33" : draftName,
                            gender: draftGender,
                            birthDate: draftBirthDate
                        )
                        isPresented = false
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 22, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "#F36CA3")))
                            .foregroundStyle(.white)
                    }
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { isPresented = false } label: {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(Color(hex: "#FF7A8B"))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Baby Info").foregroundStyle(.white).font(.system(size: 24, weight: .bold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "ellipsis.vertical").foregroundStyle(Color(hex: "#FF67AA"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                let profile = profileStore.currentProfile
                draftName = profile.name
                draftGender = profile.gender
                draftBirthDate = profile.birthDate
            }
            .sheet(isPresented: $showGenderPicker) {
                VStack(spacing: 18) {
                    Text("Gender")
                        .font(.title.bold())
                    Picker("Gender", selection: $draftGender) {
                        ForEach(BabyGender.allCases) { gender in
                            Text("\(gender.emoji) \(gender.rawValue)").tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    Button("Done") { showGenderPicker = false }
                        .primaryButtonStyle()
                }
                .presentationDetents([.height(220)])
            }
            .sheet(isPresented: $showBirthdayPicker) {
                VStack(spacing: 18) {
                    Text("Birthday")
                        .font(.title.bold())
                    DatePicker("", selection: $draftBirthDate, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    Button("Done") { showBirthdayPicker = false }
                        .primaryButtonStyle()
                }
                .presentationDetents([.height(360)])
            }
        }
    }

    private func groupRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            content()
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.08)))
    }
}
