//
//  DailySummaryViewModel.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import Foundation

@MainActor
final class DailySummaryViewModel: ObservableObject {

    @Published private(set) var state: DailySummaryState = .idle

    private let session: SessionManager
    private let service: DailySummaryServiceProtocol

    var onUnauthorized: (() -> Void)?

    init(session: SessionManager, service: DailySummaryServiceProtocol) {
        self.session = session
        self.service = service
    }


    func loadToday() async {

        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        state = .loading

        do {
            let result = try await service.getTodayDailySummary(token: token)
            state = .loaded(result)

        } catch let error as APIError {

            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
            }

            state = .error(error)

        } catch {
            state = .error(error)
        }
    }

   

    func loadByDate(date: String) async {

        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        state = .loading

        do {
            let result = try await service.getDailySummaryByDate(
                token: token,
                date: date
            )

            state = .loaded(result)

        } catch let error as APIError {

            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
            }

            state = .error(error)

        } catch {
            state = .error(error)
        }
    }

/*
    func loadRange(from: String, to: String) async {

        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        state = .loadingRange

        do {
            let result = try await service.getDailySummaryRange(
                token: token,
                from: from,
                to: to
            )

            state = .loadedRange(result)

        } catch let error as APIError {

            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
            }

            state = .error(error)

        } catch {
            state = .error(error)
        }
    }
    */
    func setPreviewState(_ newState: DailySummaryState) {
        state = newState
    }
}
