import SwiftUI

struct ZeroChipsOverlay: View {
    @Binding var isPresented: Bool
    @AppStorage("lastDailyRewardDate") private var lastDailyRewardDate: Double = 0
    
    private var canClaimReward: Bool {
        let now = Date().timeIntervalSince1970
        return now - lastDailyRewardDate > 24 * 60 * 60
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "circle.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("No Chips Available")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("You need chips to play!")
                    .foregroundColor(.white.opacity(0.8))
                
                if canClaimReward {
                    NavigationLink(destination: RewardsView()) {
                        Text("Get Free Chips")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.yellow)
                            .cornerRadius(25)
                    }
                } else {
                    Text("Come back in 24 hours for more chips!")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button("Close") {
                    isPresented = false
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 10)
            }
            .padding(30)
            .background(Color(hex: "1a1a2e"))
            .cornerRadius(20)
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    ZeroChipsOverlay(isPresented: .constant(true))
} 