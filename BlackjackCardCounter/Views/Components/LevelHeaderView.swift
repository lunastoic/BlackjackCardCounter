import SwiftUI

struct LevelHeaderView: View {
    @AppStorage("userLevel") private var userLevel: Int = 1
    @AppStorage("userXP") private var userXP: Double = 0
    @AppStorage("xpToNextLevel") private var xpToNextLevel: Double = 1000
    
    private var progress: Double {
        min(userXP / xpToNextLevel, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // Level Badge
                ZStack {
                    Circle()
                        .fill(Color(hex: "0f3460"))
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Text("\(userLevel)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Level Text
                Text("Level \(userLevel)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // XP Text
                Text("\(Int(userXP))/\(Int(xpToNextLevel)) XP")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal)
            
            // Progress Bar
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
                                gradient: Gradient(colors: [Color(hex: "00B4DB"), Color(hex: "834d9b")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(hex: "1a1a2e").opacity(0.95))
    }
}

#Preview {
    LevelHeaderView()
        .preferredColorScheme(.dark)
} 