import SwiftUI

struct CompanionPickerView: View {
    @EnvironmentObject private var companionStore: CompanionStore
    @Binding var isPresented: Bool

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            Color(hex: "#F5F5F8").ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button("关闭") { isPresented = false }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
                    Spacer()
                    Text("选择你的伙伴")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black)
                    Spacer()
                    Color.clear.frame(width: 82, height: 50)
                }
                .padding(.horizontal, 24)
                .padding(.top, 44)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(BabyCompanion.all) { companion in
                        Button {
                            companionStore.selectedID = companion.id
                        } label: {
                            companionCard(companion)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 18)
                Spacer()
            }
        }
    }

    private func companionCard(_ companion: BabyCompanion) -> some View {
        let isSelected = companionStore.selectedID == companion.id

        return VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Text(companion.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                    Text(companion.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: "#9B9BA3"))
                }

                Spacer(minLength: 0)

                Text(companion.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: "#9B9BA3"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 18)

            if isSelected {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("当前伙伴")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear.frame(height: 22)
            }
        }
        .padding(20)
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.8)))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color(hex: "#6FB5FF") : .clear, lineWidth: 2)
        )
    }
}
