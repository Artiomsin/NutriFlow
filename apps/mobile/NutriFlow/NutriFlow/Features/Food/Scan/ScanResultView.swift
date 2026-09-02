import SwiftUI
import Kingfisher
import UIKit

struct ScanResultView: View {

    @State private var viewModel: ScanResultViewModel
    let onFinished: () -> Void

    init(viewModel: ScanResultViewModel, onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                ForEach(viewModel.items) { item in
                    itemRow(item)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.error)
                }

                addToDiaryButton
            }
            .padding(.horizontal, AppTheme.paddingHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(AppTheme.background)
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 8)
            }

            Text("Found \(viewModel.selectedItems.count) food(s)")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 16) {
                Label(viewModel.totalCaloriesText, systemImage: "flame")
                Label(viewModel.totalGramsText, systemImage: "scalemass")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
        )
    }

    private func itemRow(_ item: EditableScanFood) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    viewModel.toggle(id: item.id)
                } label: {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(item.isSelected ? AppTheme.accent : AppTheme.textTertiary)
                }
                .buttonStyle(.plain)

                itemThumbnail(item)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.line")
                            .font(.caption)
                            .foregroundColor(AppTheme.accent)

                        TextField("Food name", text: Binding(
                            get: { item.nameText },
                            set: { viewModel.updateName(id: item.id, $0) }
                        ))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .tint(AppTheme.accent)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                            .fill(AppTheme.fieldBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
                            )
                    )

                    Menu {
                        Button("None") { viewModel.setCategory(id: item.id, nil) }
                        ForEach(viewModel.categories) { cat in
                            Button(cat.name) { viewModel.setCategory(id: item.id, cat.name) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "tag")
                                .font(.footnote)
                            Text(item.categoryName ?? "Category")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(item.categoryName == nil ? AppTheme.textSecondary : AppTheme.textPrimary)
                    }
                    .onAppear { Task { await viewModel.loadCategories() } }
                }

                Spacer()
            }

            Divider()
                .overlay(AppTheme.cardBorder)

            macroFields(item)

            HStack {
                Spacer()

                weightField(item)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .opacity(item.isSelected ? 1 : 0.55)
    }

    private func weightField(_ item: EditableScanFood) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Weight")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.accent)

            HStack(spacing: 4) {
                TextField("0", text: Binding(
                    get: { item.gramsText },
                    set: { viewModel.updateGramsText(id: item.id, $0) }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .tint(AppTheme.accent)
                .frame(width: 50)

                Text(UnitConversion.displayUnit(for: item.baseUnit, preferred: viewModel.preferredUnits))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent.opacity(0.85))
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .fixedSize()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(AppTheme.fieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                            .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                    )
            )
        }
    }

    private func macroFields(_ item: EditableScanFood) -> some View {
        HStack(spacing: 8) {
            macroField(
                label: "Cal",
                unit: viewModel.preferredUnits.energy == .kj ? "kJ" : "kcal",
                color: .orange,
                text: Binding(
                    get: { item.caloriesText },
                    set: { viewModel.updateCaloriesText(id: item.id, $0) }
                )
            )
            macroField(
                label: "Protein",
                unit: viewModel.preferredUnits.weight == .imperial ? "oz" : "g",
                color: Color(red: 0.9, green: 0.3, blue: 0.3),
                text: Binding(
                    get: { item.proteinText },
                    set: { viewModel.updateMacroText(id: item.id, field: .protein, $0) }
                )
            )
            macroField(
                label: "Fat",
                unit: viewModel.preferredUnits.weight == .imperial ? "oz" : "g",
                color: Color(red: 0.2, green: 0.5, blue: 0.9),
                text: Binding(
                    get: { item.fatText },
                    set: { viewModel.updateMacroText(id: item.id, field: .fat, $0) }
                )
            )
            macroField(
                label: "Carbs",
                unit: viewModel.preferredUnits.weight == .imperial ? "oz" : "g",
                color: Color(red: 0.2, green: 0.7, blue: 0.3),
                text: Binding(
                    get: { item.carbsText },
                    set: { viewModel.updateMacroText(id: item.id, field: .carbs, $0) }
                )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroField(label: String, unit: String, color: Color, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)

            HStack(spacing: 4) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .tint(AppTheme.accent)

                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color.opacity(0.85))
            }
            .padding(.horizontal, 6)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(AppTheme.fieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                            .stroke(color.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func itemThumbnail(_ item: EditableScanFood) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.1, green: 0.15, blue: 0.25))

            Image(systemName: "fork.knife")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.5))

            if let url = item.imageURL {
                KFImage(url)
                    .fade(duration: 0.25)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var addToDiaryButton: some View {
        Button {
            Task {
                guard await viewModel.addToDiary() else { return }
                onFinished()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                    Text("Add to Diary — \(viewModel.totalCaloriesText)")
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
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundColor(.black)
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 6)
        }
        .disabled(viewModel.isLoading || viewModel.selectedItems.isEmpty)
        .opacity((viewModel.isLoading || viewModel.selectedItems.isEmpty) ? 0.6 : 1)
    }
}

#Preview {
    NavigationStack {
        ScanResultView(
            viewModel: ScanResultViewModel(
                items: [
                    FoodAnalysisItem(
                        name: "Chicken breast",
                        category: "Meat",
                        grams: 150,
                        calories: 165,
                        protein: 31,
                        fat: 3.6,
                        carbs: 0,
                        unit: "g",
                        imageUrl: nil,
                        confidence: 0.95,
                        foodId: nil,
                        source: "ai",
                        aiCalories: 165,
                        catalogCalories: nil
                    ),
                    FoodAnalysisItem(
                        name: "Rice",
                        category: "Grains",
                        grams: 100,
                        calories: 130,
                        protein: 2.7,
                        fat: 0.3,
                        carbs: 28,
                        unit: "g",
                        imageUrl: nil,
                        confidence: 0.9,
                        foodId: nil,
                        source: "ai",
                        aiCalories: 130,
                        catalogCalories: nil
                    )
                ],
                imageData: SamplePhoto.data,
                service: MockFoodService(),
                todayFoodVM: TodayFoodViewModel(
                    service: MockFoodService(),
                    coordinator: AppCoordinator(container: AppDependencyContainer())
                ),
                coordinator: nil
            ),
            onFinished: {}
        )
    }
    .preferredColorScheme(.dark)
}

private enum SamplePhoto {
    /// Renders a small placeholder "plate of food" JPEG so the preview shows
    /// where the scanned photo appears in the result header.
    static var data: Data? {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 40, y: 40, width: 320, height: 320))
            UIColor.systemGreen.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 100, y: 120, width: 120, height: 120))
            UIColor.brown.setFill()
            ctx.cgContext.fill(CGRect(x: 170, y: 80, width: 70, height: 200))
        }
        return image.jpegData(compressionQuality: 0.85)
    }
}
