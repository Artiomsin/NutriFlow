//
//  AddFoodView.swift
//  Nutriflow
//
//  Created by Artem on 19.05.26.
//

import SwiftUI

struct AddFoodView: View {

    @ObservedObject var viewModel: FoodViewModel
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
                text: $viewModel.name
            )

            AppTextField(
                title: "Calories",
                text: $viewModel.calories,
                keyboardType: UIKeyboardType.numberPad
            )

            AppTextField(
                title: "Protein (g)",
                text: $viewModel.protein,
                keyboardType: UIKeyboardType.numberPad
            )

            AppTextField(
                title: "Fat (g)",
                text: $viewModel.fat,
                keyboardType: UIKeyboardType.numberPad
            )

            AppTextField(
                title: "Carbs (g)",
                text: $viewModel.carbs,
                keyboardType: UIKeyboardType.numberPad
            )
        }
    }

    private var saveButton: some View {

        Button {

            Task {
                await viewModel.createFood()
                dismiss()
            }

        } label: {

            if case .saving = viewModel.state {
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
        .disabled(viewModel.name.isEmpty || viewModel.calories.isEmpty)
    }
}
