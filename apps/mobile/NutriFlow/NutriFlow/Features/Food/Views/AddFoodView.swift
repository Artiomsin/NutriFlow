//
//  AddFoodView.swift
//  Nutriflow
//

import SwiftUI

struct AddFoodView: View {

    @Bindable var foodViewModel: FoodViewModel
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {

        VStack(spacing: 20) {

            header

            form

            Spacer()

            saveButton
        }
        .padding()
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear { AnalyticsService.shared.track(.screenView(screen: "add_food")) }
    }

    private var header: some View {

        HStack {

            Text("Add Food")
                .font(.title2.bold())
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private var form: some View {

        VStack(spacing: 14) {

            AppTextField(
                title: "Food name",
                text: $foodViewModel.name
            )

            AppTextField(
                title: "Calories",
                text: $foodViewModel.calories,
                keyboardType: UIKeyboardType.numberPad
            )

            AppTextField(
                title: "Protein (g)",
                text: $foodViewModel.protein,
                keyboardType: UIKeyboardType.numberPad
            )

            AppTextField(
                title: "Fat (g)",
                text: $foodViewModel.fat,
                keyboardType: UIKeyboardType.numberPad
            )

            AppTextField(
                title: "Carbs (g)",
                text: $foodViewModel.carbs,
                keyboardType: UIKeyboardType.numberPad
            )
        }
    }

    private var saveButton: some View {

        Button {

            Task {
                await foodViewModel.createFood()
                onSave()
                dismiss()
            }

        } label: {

            if case .saving = foodViewModel.state {
                ProgressView()
                    .tint(.black)
            } else {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.accent)
        .cornerRadius(12)
        .disabled(foodViewModel.name.isEmpty || foodViewModel.calories.isEmpty)
    }
}

#Preview {
    AddFoodViewPreview()
}

struct AddFoodViewPreview: View {

    var body: some View {
        let foodVM = FoodViewModel(
            service: MockFoodService()
        )

        AddFoodView(
            foodViewModel: foodVM,
            onSave: {}
        )
        .preferredColorScheme(.dark)
    }
}
