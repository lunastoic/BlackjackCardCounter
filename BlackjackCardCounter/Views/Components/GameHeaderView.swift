import SwiftUI

struct GameHeaderView: View {
    @ObservedObject var xpManager = XPChipManager.shared
    @State private var isAnimatingXP = false
    @State private var isAnimatingChips = false
    
    private let xpPerLevel: Double = 30
    private var progress: Double {
        if xpManager.userLevel >= xpManager.maxLevel {
            return 1.0 // Show 100% when at max level
        } else {
            return min(xpManager.userXP / xpPerLevel, 1.0)
        }
    }
    
    var body: some View {
        HStack {
            // Chips Counter
            HStack(spacing: 4) {
                Text("Chips:")
                    .font(.fixedSystem(size: 19, weight: .bold))
                    .foregroundColor(.yellow)
                Text("\(xpManager.userChips)")
                    .font(.fixedSystem(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))
            .cornerRadius(20)
            .scaleEffect(isAnimatingChips ? 1.1 : 1.0)
            .animation(nil, value: isAnimatingChips)
            
            Spacer()
            
            // Level and XP
            HStack(spacing: 12) {
                // Level Badge
                ZStack {
                    Circle()
                        .fill(Color(hex: "0f3460"))
                        .frame(width: 32, height: 32)
                    Text("\(xpManager.userLevel)")
                        .font(.fixedSystem(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // XP Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "2193b0"), Color(hex: "00c853"), Color(hex: "43ea7a")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 8)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(width: 100, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))
            .cornerRadius(20)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .disableDynamicType()
        .onReceive(NotificationCenter.default.publisher(for: .xpChipDidChange)) { _ in
            isAnimatingXP = true
            isAnimatingChips = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimatingXP = false
                isAnimatingChips = false
            }
        }
    }
}

#Preview {
    GameHeaderView()
        .preferredColorScheme(.dark)
        .background(Color.black)
} 