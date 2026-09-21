import SwiftUI
import PhotosUI
import Kingfisher

struct AddFoodView: View {
    let onSave: () -> Void
    let todayFoodVM: TodayFoodViewModel
    let onSearchCatalog: (() -> Void)?
    let onSelectPopular: ((CatalogFood) -> Void)?

    @State private var viewModel: AddFoodViewModel
    @State private var photosItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var prefsStore = PreferencesStore.shared

    private enum Field: Hashable {
        case name
        case grams
        case calories
        case protein
        case fat
        case carbs
    }

    @FocusState private var focusedField: Field?

    init(onSave: @escaping () -> Void, viewModel: AddFoodViewModel, todayFoodVM: TodayFoodViewModel, onSearchCatalog: (() -> Void)? = nil, onSelectPopular: ((CatalogFood) -> Void)? = nil) {
        self.onSave = onSave
        self.todayFoodVM = todayFoodVM
        self.onSearchCatalog = onSearchCatalog
        self.onSelectPopular = onSelectPopular
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                searchCatalogButton
                if !viewModel.popularFoods.isEmpty { popularSection }
                if viewModel.isLoadingPopular && viewModel.popularFoods.isEmpty {
                    ProgressView()
                        .tint(AppColors.accent)
                }
                photoPicker
                formSection()
                categorySection()
                saveButton
            }
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Add Food")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.trackScreenView()
            await viewModel.loadCategories()
            await viewModel.loadPopular()
        }
        .onChange(of: photosItem) { _, item in loadImage(item) }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Popular")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.popularFoods) { food in
                        PopularCard(food: food, preferred: prefsStore.preferredUnits) {
                            onSelectPopular?(food)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var searchCatalogButton: some View {
        Button {
            onSearchCatalog?()
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search catalog")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(14)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.medium)
        }
        .buttonStyle(.plain)
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $photosItem, matching: .images) {
            if let data = selectedImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            } else {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.surfaceSecondary)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                            Text("Add photo")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
            }
        }
    }

    private func formSection() -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Details", icon: "square.and.pencil")
                AppTextField(title: "Food name", text: $viewModel.name, submitLabel: .return, focus: $focusedField, focusValue: .name) {
                    nextField(.grams)
                }
                AppTextField(title: viewModel.gramsLabel, text: $viewModel.grams, keyboardType: .decimalPad, submitLabel: .return, focus: $focusedField, focusValue: .grams) {
                    nextField(.calories)
                }
                AppTextField(title: viewModel.caloriesLabel, text: $viewModel.calories, keyboardType: .numberPad, submitLabel: .return, focus: $focusedField, focusValue: .calories) {
                    nextField(.protein)
                }
                HStack(spacing: 12) {
                    AppTextField(title: viewModel.proteinLabel, text: $viewModel.protein, keyboardType: .decimalPad, submitLabel: .return, focus: $focusedField, focusValue: .protein) {
                        nextField(.fat)
                    }
                    AppTextField(title: viewModel.fatLabel, text: $viewModel.fat, keyboardType: .decimalPad, submitLabel: .return, focus: $focusedField, focusValue: .fat) {
                        nextField(.carbs)
                    }
                    AppTextField(title: viewModel.carbsLabel, text: $viewModel.carbs, keyboardType: .decimalPad, submitLabel: .return, focus: $focusedField, focusValue: .carbs) {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func categorySection() -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Category", icon: "tag.fill")
                Menu {
                    Button("None") { viewModel.selectedCategory = nil }
                    ForEach(viewModel.categories) { cat in
                        Button(cat.name) { viewModel.selectedCategory = cat }
                    }
                } label: {
                    HStack {
                        Text(viewModel.selectedCategory?.name ?? "Select category")
                            .foregroundColor(viewModel.selectedCategory == nil ? AppColors.textTertiary : AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(14)
                    .background(AppColors.surfaceSecondary)
                    .cornerRadius(AppRadius.medium)
                }
            }
        }
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private var saveButton: some View {
        Button {
            dismissKeyboard()
            Task {
                await viewModel.createEntry(imageData: selectedImageData)
                if case .idle = viewModel.state {
                    await todayFoodVM.reloadAfterMutation()
                    todayFoodVM.notifyDataMutated()
                    onSave()
                }
            }
        } label: {
            switch viewModel.state {
            case .uploading, .saving:
                ProgressView().tint(AppColors.accentOnPrimary)
            case .error(let e):
                Text(e.localizedDescription).font(.caption).foregroundColor(AppColors.error)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            case .idle:
                Text("Save")
                    .font(.headline)
                    .foregroundColor(AppColors.accentOnPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(canSave ? AppColors.accent : AppColors.accent.opacity(0.3))
        .cornerRadius(AppRadius.medium)
        .disabled(!canSave)
    }

    private var canSave: Bool {
        !viewModel.name.isEmpty && !viewModel.grams.isEmpty && !viewModel.calories.isEmpty
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private func nextField(_ field: Field) {
        Task { @MainActor in
            focusedField = field
        }
    }

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            selectedImageData = ImageCompressor.optimizedJPEGData(
                data,
                maxDimension: 800,
                quality: 0.8
            )
        }
    }
}

#Preview {
    NavigationStack {
        AddFoodView(onSave: {}, viewModel: AddFoodViewModel(service: MockFoodService(), coordinator: nil), todayFoodVM: TodayFoodViewModel(service: MockFoodService(), coordinator: AppCoordinator(container: AppDependencyContainer())))
    }
    
}

private struct PopularCard: View {
    let food: CatalogFood
    let preferred: PreferredUnits
    let onTap: () -> Void

    private var hasCategory: Bool {
        guard let category = food.categoryName else { return false }
        return !category.isEmpty && category != "NOT A BRANDED ITEM"
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                imageView
                    .frame(width: 175, height: 205)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("\(UnitConversion.formatEnergyValue(kcal: food.caloriesPer100g, preferred: preferred))")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(UnitConversion.formatEnergyUnit(preferred: preferred))")
                            .font(.system(size: 9))
                        Spacer()
                    }
                    .foregroundColor(.white)

                    HStack(spacing: 4) {
                        macroPill(color: Color(red: 0.4, green: 0.72, blue: 1.0), label: "P", grams: food.proteinPer100g)
                        macroPill(color: Color(red: 1.0, green: 0.6, blue: 0.3), label: "F", grams: food.fatPer100g)
                        macroPill(color: Color(red: 0.5, green: 0.85, blue: 0.55), label: "C", grams: food.carbsPer100g)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(10)
            }
            .frame(width: 175, height: 205)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            .overlay(alignment: .topLeading) {
                if hasCategory {
                    Text((food.categoryName ?? "").uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageView: some View {
        ZStack {
            FoodImagePlaceholder(cornerRadius: 0, iconSize: 28)
            if let url = food.imageUrl.flatMap({ URL(string: $0) }) {
                KFImage(url)
                    .fade(duration: 0.25)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
    }

    private func macroPill(color: Color, label: String, grams: Int?) -> some View {
        let unit = preferred.weight == .imperial ? "oz" : "g"
        return HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text("\(UnitConversion.macroDisplay(grams: Double(grams ?? 0), preferred: preferred)) \(unit)")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.25), in: Capsule())
    }
}
