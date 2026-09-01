//
//  ScanFoodView.swift
//  Nutriflow
//
//  Created by Artem on 28.08.2026.
//

import SwiftUI
import UIKit

struct ScanFoodView: View {
    
    let onFinished: ([FoodAnalysisItem], Data?) -> Void
    
    @State
    private var viewModel: ScanFoodViewModel
    
    @Environment(\.dismiss)
    private var dismiss
    
    init (service: FoodServiceProtocol, onFinished: @escaping ([FoodAnalysisItem], Data?)-> Void){
        self.onFinished = onFinished
        _viewModel = State(
            initialValue: ScanFoodViewModel(
                camera: CameraService(),
                foodService: service
            )
        )
        
    }
    
    var body: some View {
        ZStack{
            AppTheme.background
                .ignoresSafeArea()
            
            content
        }
        .navigationTitle("ScanFood")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar{
            ToolbarItem(placement: .cancellationAction){
                Button("Cancel"){
                    viewModel.stopCamera()
                    dismiss()
                }
            }
        }
        .task {
            print("[Scan] view appear, preparing camera")
            await viewModel.prepareCamera()
        }
        .onDisappear{
            print("[Scan] view disappear, stopping camera")
            viewModel.stopCamera()
        }
    }
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .preparing:
            ProgressView()
                .tint(AppTheme.accent)
            
        case .ready:
            cameraContent
            
        case .capturing, .analyzing:
            loadingView(title: "Wait, analyzing...")
            
        case .completed:
            completedView
            
        case .notFound:
            notFoundView
            
        case .failed(let message):
            errorView(message)
        }
    }
    
    private var cameraContent: some View{
        ZStack{
            CameraPreview(session: viewModel.camera.session)
                .ignoresSafeArea()
            VStack {
                Spacer()
                
                shutterButton
            }
            .padding(.bottom, 30)
        }
    }
    
    private var shutterButton: some View {
        Button {
            Task { await viewModel.scan() }
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 76, height: 76)
                
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 4)
                    .frame(width: 88, height: 88)
            }
        }
    }
    
    private func loadingView(title: String) -> some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppTheme.accent)

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(AppTheme.accent)
            
            Text("Found \(viewModel.result.count) food item(s)")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button("View Result") {
                print("[Scan] user tapped View Result")
                onFinished(viewModel.result, viewModel.capturedImageData)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
    }
    
    private var notFoundView: some View {
        VStack(spacing: 16){
            Image(systemName: "magnifyingglass")
                .font(.system(size: 42))
                .foregroundColor(AppTheme.textSecondary)

            Text("No food recognized")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text("Try again with better lighting and food clearly visible.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 30)

            Button("Take another photo"){
                Task {
                    viewModel.reset()
                    await viewModel.prepareCamera()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16){
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42))
                .foregroundColor(AppTheme.accent)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 30)
            
            Button("Try again"){
                Task{await viewModel.prepareCamera()}
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            Button("Cancel"){
                dismiss()
            }
            .buttonStyle(.bordered)
            .foregroundColor(AppTheme.textSecondary)
        }
    }
    
}
