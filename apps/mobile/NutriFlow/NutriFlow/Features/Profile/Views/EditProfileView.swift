//
//  EditProfileView.swift
//  Nutriflow
//
//  Created by Artem on 13.05.26.
//

import SwiftUI


struct EditProfileView: View {

    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {

        ZStack {

            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                
                HStack {

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                    }

                    Spacer()

                    Text("Edit Profile")
                        .foregroundColor(.white)
                        .font(.headline)

                    Spacer()

                    Spacer()
                        .frame(width: 24)
                }
                .padding()
                .background(Color.black.opacity(0.3))

                ScrollView {

                    VStack(spacing: 20) {

                        AppTextField(title: "Weight", text: $viewModel.weight)
                        AppTextField(title: "Height", text: $viewModel.height)
                        AppTextField(title: "Age", text: $viewModel.age)

                        // SAVE BUTTON ПОСЛЕ ВСЕХ ПОЛЕЙ
                        PrimaryButton(title: "Save") {

                            Task {
                                await viewModel.updateProfile()
                                dismiss()
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
