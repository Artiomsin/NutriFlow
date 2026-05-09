
import SwiftUI

struct ErrorMessageView: View {
    
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Color.red.opacity(0.85))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .cornerRadius(10)
    }
}
