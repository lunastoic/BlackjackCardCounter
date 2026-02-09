import SwiftUI

struct TrainingTabView: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Training Options")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Configure training-specific behaviors here.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button(action: { showSettings = false }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color(hex: "ff0000"))
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .frame(maxWidth: 340)
    }
}

#Preview {
    TrainingTabView(showSettings: .constant(false))
}
