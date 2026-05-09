
import SwiftUI

struct PrimaryButton: View {
    
    let title: String
    
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.green)
                .cornerRadius(12)
        }
    }
}
