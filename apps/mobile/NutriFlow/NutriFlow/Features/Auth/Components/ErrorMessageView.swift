
import SwiftUI

struct ErrorMessageView: View {
    
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppColors.error)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.errorBackground)
            .cornerRadius(AppRadius.small)
    }
}
