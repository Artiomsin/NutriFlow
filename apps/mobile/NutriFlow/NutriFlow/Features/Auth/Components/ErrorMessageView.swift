
import SwiftUI

struct ErrorMessageView: View {
    
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppTheme.error)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.errorBackground)
            .cornerRadius(AppTheme.cornerRadiusSmall)
    }
}
