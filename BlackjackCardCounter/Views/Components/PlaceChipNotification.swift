import SwiftUI

// MARK: - Place Chip Notification Component
struct PlaceChipNotification: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        if isVisible {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    
                    Text("Place a chip first")
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .offset(y: -geometry.size.height * 0.25 - 175) // Position above betting area, 175 points higher
                }
                .frame(maxWidth: .infinity) // Center horizontally
            }
            .zIndex(99999) // Very high z-index to ensure visibility
            .transition(.opacity.combined(with: .scale))
            .onAppear {
                print("🎯 PlaceChipNotification: Notification is now visible")
            }
        }
    }
}

// MARK: - Notification Manager
class PlaceChipNotificationManager: ObservableObject {
    @Published var isVisible: Bool = false
    
    func showNotification() {
        print("🎯 PlaceChipNotificationManager: Showing notification")
        isVisible = true
        
        // Hide message after 2.1 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.isVisible = false
            }
        }
    }
    
    func hideNotification() {
        isVisible = false
    }
}
