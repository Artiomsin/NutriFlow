//
//  ChangePasswordViewModel.swift
//  Nutriflow
//
//  Created by Artem on 31.10.2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class ChangePasswordViewModel {


    enum State {
        case idle
        case loading
        case success
        case error(AppError)
    }

    var state: State = .idle

    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""

    var fieldErrors = FormFieldErrors()

    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }


    @ObservationIgnored
    private let authService: AuthServiceProtocol


    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }


    func onAppear() {
        state = .idle
        fieldErrors.removeAll()
    }


    func changePassword() async {
        guard validatePasswords() else {
            state = .idle
            return
        }

        state = .loading

        do {
            try await authService.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )

            state = .success
            clearPasswords()

        } catch {
            show(error: error)
        }
    }

    
    func validateCurrentPassword() {
        fieldErrors.clear("currentPassword")

        if currentPassword.isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(for: FieldErrorCode.required.rawValue),
                for: "currentPassword"
            )
        }
    }

    private func validatePasswords() -> Bool {
        fieldErrors.removeAll()

        if currentPassword.isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(
                    for: FieldErrorCode.required.rawValue
                ),
                for: "currentPassword"
            )
        }

        if newPassword.isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(
                    for: FieldErrorCode.required.rawValue
                ),
                for: "newPassword"
            )
        }

        if confirmPassword.isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(
                    for: FieldErrorCode.required.rawValue
                ),
                for: "confirmPassword"
            )
        }

        if !newPassword.isEmpty &&
            !confirmPassword.isEmpty &&
            newPassword != confirmPassword {

            fieldErrors.set(
                String(
                    localized: "form.error.password_mismatch",
                    defaultValue: "Passwords do not match."
                ),
                for: "confirmPassword"
            )
        }

        if !currentPassword.isEmpty &&
            !newPassword.isEmpty &&
            currentPassword == newPassword {

            fieldErrors.set(
                String(
                    localized: "form.error.password_same",
                    defaultValue: "New password must differ from current password."
                ),
                for: "newPassword"
            )
        }

        return fieldErrors.isEmpty
    }

   

    private func show(error: Error) {
        switch ErrorHandler.handle(
            error,
            supportedFields: [
                "currentPassword",
                "newPassword",
                "confirmPassword"
            ]
        ) {
        case .fieldErrors(let errors):
            fieldErrors = errors
            state = .idle

        case .general(let appError):
            state = .error(appError)
        }
    }


    func clearFieldError(_ field: String) {
        fieldErrors.clear(field)
    }

    func clearPasswords() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        fieldErrors.removeAll()
    }

    func resetState() {
        state = .idle
        fieldErrors.removeAll()
    }
}
