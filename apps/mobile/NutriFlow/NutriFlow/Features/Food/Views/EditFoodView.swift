import SwiftUI
import UIKit
import Kingfisher
import PhotosUI

struct EditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditFoodViewModel
    let onSave: () async -> Void
    @FocusState private var nameFocused: Bool
    @FocusState private var caloriesFocused: Bool
    @FocusState private var proteinFocused: Bool
    @FocusState private var fatFocused: Bool
    @FocusState private var carbsFocused: Bool
    @FocusState private var gramsFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    photoSection()
                    foodSection()
                    macrosSection()
                    servingSection()
                    if viewModel.source == "user" { categorySection() }

                    if viewModel.showNameWarning {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                            Text("Change the name to save")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .background(.red.opacity(0.1))
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    saveButton()
                }
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .animation(.easeInOut(duration: 0.25), value: viewModel.showNameWarning)
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if !nameFocused {
                        Spacer()
                        Button("Done") { dismissKeyboard() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .task { await viewModel.loadCategories() }
            .onChange(of: viewModel.photosItem) { _, item in viewModel.loadImage(item) }
            .onChange(of: viewModel.grams) { _, newValue in viewModel.recalculateMacros(from: newValue) }
            .onChange(of: viewModel.name) { _, _ in viewModel.showNameWarning = false }
        }
        .tint(AppTheme.accent)
    }

    init(viewModel: EditFoodViewModel, onSave: @escaping () async -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSave = onSave
    }

    private func dismissKeyboard() {
        nameFocused = false
        caloriesFocused = false
        proteinFocused = false
        fatFocused = false
        carbsFocused = false
        gramsFocused = false
    }

    // MARK: - Sections

    private func photoSection() -> some View {
        VStack(spacing: 12) {
            sectionLabel("Photo", icon: "camera.fill")
            PhotosPicker(selection: $viewModel.photosItem, matching: .images) {
                PhotoSectionContent(image: viewModel.selectedImage, imageUrl: viewModel.entry.displayImageUrl)
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
    }

    private func foodSection() -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Food", icon: "fork.knife")
                AppTextField(title: "Name", text: $viewModel.name, focus: $nameFocused)
                AppTextField(title: viewModel.caloriesLabel, text: $viewModel.calories, keyboardType: .numberPad, focus: $caloriesFocused)
            }
        }
    }

    private func macrosSection() -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Macros", icon: "chart.pie.fill")
                HStack(spacing: 12) {
                    AppTextField(title: viewModel.proteinLabel, text: $viewModel.protein, keyboardType: .decimalPad, focus: $proteinFocused)
                    AppTextField(title: viewModel.fatLabel, text: $viewModel.fat, keyboardType: .decimalPad, focus: $fatFocused)
                    AppTextField(title: viewModel.carbsLabel, text: $viewModel.carbs, keyboardType: .decimalPad, focus: $carbsFocused)
                }
            }
        }
    }

    private func servingSection() -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Serving", icon: "scalemass.fill")
                AppTextField(title: viewModel.gramsLabel, text: $viewModel.grams, keyboardType: .decimalPad, focus: $gramsFocused)
            }
        }
    }

    private func categorySection() -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Category", icon: "tag.fill")
                Menu {
                    Button("None") { viewModel.selectedCategoryName = nil }
                    ForEach(viewModel.categories) { cat in
                        Button(cat.name) { viewModel.selectedCategoryName = cat.name }
                    }
                } label: {
                    HStack {
                        Text(viewModel.selectedCategoryName ?? viewModel.entry.categoryName ?? "Select category")
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(14)
                    .background(AppTheme.fieldBackground)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                }
            }
        }
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppTheme.accent)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    // MARK: - Save

    private func saveButton() -> some View {
        Button {
            save()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                    Text("Save Changes")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
            )
            .foregroundColor(.black)
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 6)
        }
        .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
        .opacity((viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading) ? 0.6 : 1)
    }

    private func save() {
        dismissKeyboard()
        Task {
            guard await viewModel.save() else { return }
            dismiss()
            await onSave()
        }
    }
}

#Preview {
    EditFoodView(
        viewModel: EditFoodViewModel(
            entry: FoodEntry(
                id: "1",
                userId: "1",
                name: "Chicken Breast",
                calories: 165,
                protein: 31,
                fat: 4,
                carbs: 0,
                foodId: nil,
                grams: 200,
                unit: "g",
                categoryName: "Meat",
                imageUrl: nil,
                createdAt: "2026-07-13T10:00:00Z",
                updatedAt: nil
            ),
            foodService: MockFoodService()
        ),
        onSave: {}
    )
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}

private struct PhotoSectionContent: View {
    let image: UIImage?
    let imageUrl: String?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let url = imageUrl.flatMap({ URL(string: $0) }) {
            KFImage(url)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.fieldBackground)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accent)
                        Text("Tap to change photo")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
        }
    }
}
