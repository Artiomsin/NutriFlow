import SwiftUI
import UIKit
import GoogleSignIn

struct GoogleAuthButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                googleIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Sign in with Google")
                    .font(.headline)
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.buttonHeight)
            .background(Color.white)
            .cornerRadius(AppRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var googleIcon: Image {
        guard let bundle = googleSignInBundle,
              let url = bundle.url(forResource: "google", withExtension: "png"),
              let uiImage = UIImage(contentsOfFile: url.path)
        else {
            return Image(systemName: "g.circle.fill")
        }
        return Image(uiImage: uiImage)
    }

    private var googleSignInBundle: Bundle? {
        if let mainPath = Bundle.main.path(forResource: "GoogleSignIn_GoogleSignIn", ofType: "bundle") {
            return Bundle(path: mainPath)
        }
        if let classPath = Bundle(for: GIDSignIn.self).path(forResource: "GoogleSignIn_GoogleSignIn", ofType: "bundle") {
            return Bundle(path: classPath)
        }
        return nil
    }
}
