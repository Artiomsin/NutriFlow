import SwiftUI
import PhotosUI

struct AddFoodView: View {
    let onSave: () -> Void
    let todayFoodVM: TodayFoodViewModel
    let onSearchCatalog: (() -> Void)?

    @State private var addFoodVM: AddFoodViewModel
    @State private var photosItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var prefsStore = PreferencesStore.shared

    init(onSave: @escaping () -> Void, foodService: FoodServiceProtocol, todayFoodVM: TodayFoodViewModel, onSearchCatalog: (() -> Void)? = nil) {
        self.onSave = onSave
        self.todayFoodVM = todayFoodVM
        self.onSearchCatalog = onSearchCatalog
        _addFoodVM = State(initialValue: AddFoodViewModel(service: foodService, coordinator: nil))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                searchCatalogButton
                photoPicker
                form
                categoryPicker
                saveButton
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Add Food")
        .navigationBarTitleDisplayMode(.inline)
        .task { await addFoodVM.loadCategories() }
        .onChange(of: photosItem) { _, item in loadImage(item) }
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
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $photosItem, matching: .images) {
            if let data = selectedImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.cardBackground)
                    .frame(height: 120)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(AppTheme.accent)
                            Text("Add photo")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
            }
        }
    }

    private var form: some View {
        VStack(spacing: 14) {
            AppTextField(title: "Food name", text: $addFoodVM.name)

            AppTextField(title: prefsStore.preferredUnits.weight == .imperial ? "Ounces" : "Grams", text: $addFoodVM.grams, keyboardType: .decimalPad)

            AppTextField(title: "Calories", text: $addFoodVM.calories, keyboardType: .numberPad)

            HStack(spacing: 12) {
                AppTextField(title: "Protein (\(prefsStore.preferredUnits.weight == .imperial ? "oz" : "g"))", text: $addFoodVM.protein, keyboardType: .decimalPad)
                AppTextField(title: "Fat (\(prefsStore.preferredUnits.weight == .imperial ? "oz" : "g"))", text: $addFoodVM.fat, keyboardType: .decimalPad)
                AppTextField(title: "Carbs (\(prefsStore.preferredUnits.weight == .imperial ? "oz" : "g"))", text: $addFoodVM.carbs, keyboardType: .decimalPad)
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.caption.weight(.medium))
                .foregroundColor(AppTheme.textSecondary)

            Menu {
                Button("None") { addFoodVM.selectedCategory = nil }
                ForEach(addFoodVM.categories) { cat in
                    Button(cat.name) { addFoodVM.selectedCategory = cat }
                }
            } label: {
                HStack {
                    Text(addFoodVM.selectedCategory?.name ?? "Select category")
                        .foregroundColor(addFoodVM.selectedCategory == nil ? AppTheme.textTertiary : AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppTheme.textTertiary)
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                let isImperial = prefsStore.preferredUnits.weight == .imperial
                let toGrams: (Double) -> Int = { Int(($0 * 28.35).rounded()) }
                let normalizedGrams = addFoodVM.grams.replacingOccurrences(of: ",", with: ".")
                let normalizedProtein = addFoodVM.protein.replacingOccurrences(of: ",", with: ".")
                let normalizedFat = addFoodVM.fat.replacingOccurrences(of: ",", with: ".")
                let normalizedCarbs = addFoodVM.carbs.replacingOccurrences(of: ",", with: ".")
                let actualGrams: Int? = {
                    guard let value = Double(normalizedGrams), value > 0 else { return nil }
                    return isImperial ? toGrams(value) : Int(value.rounded())
                }()
                let parseMacro: (String) -> Int? = { Double($0).map { isImperial ? toGrams($0) : Int($0.rounded()) } }
                let actualProtein: Int? = parseMacro(normalizedProtein)
                let actualFat: Int? = parseMacro(normalizedFat)
                let actualCarbs: Int? = parseMacro(normalizedCarbs)

                await addFoodVM.createEntry(imageData: selectedImageData, actualGrams: actualGrams, actualProtein: actualProtein, actualFat: actualFat, actualCarbs: actualCarbs)
                if case .idle = addFoodVM.state {
                    await todayFoodVM.reloadAfterAdd()
                    onSave()
                }
            }
        } label: {
            switch addFoodVM.state {
            case .uploading, .saving:
                ProgressView().tint(.black)
            case .error(let e):
                Text(e.localizedDescription).font(.caption).foregroundColor(AppTheme.error)
            case .idle:
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(canSave ? AppTheme.accent : AppTheme.accent.opacity(0.3))
        .cornerRadius(12)
        .disabled(!canSave)
    }

    private var canSave: Bool {
        !addFoodVM.name.isEmpty && !addFoodVM.grams.isEmpty && !addFoodVM.calories.isEmpty
    }

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            guard let image = UIImage(data: data) else { return }
            let thumb = image.preparingThumbnail(of: CGSize(width: 800, height: 800))
            selectedImageData = thumb?.jpegData(compressionQuality: 0.8)
        }
    }
}

#Preview {
    NavigationStack {
        AddFoodView(onSave: {}, foodService: MockFoodService(), todayFoodVM: TodayFoodViewModel(service: MockFoodService(), coordinator: AppCoordinator(container: AppDependencyContainer())))
    }
    .preferredColorScheme(.dark)
}