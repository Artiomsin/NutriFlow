//
//  DailySummarySection.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI

struct DailySummarySection: View {

    @ObservedObject var viewModel: DailySummaryViewModel

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            header

            content
        }
    }

    private var header: some View {

        HStack {

            Text("Today's Overview")
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)

            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {

        switch viewModel.state {

        case .idle, .loading:
            ProgressView()

        case .loaded(let summary):
            DailySummaryCard(summary: summary)

        case .error(let error):
            ErrorMessageView(text: error.localizedDescription)
        }
    }
}
