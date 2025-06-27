import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]),
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 30) {
                    // Title
                    Text("Blackjack Card Counter")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    // Home screen image
                    Image("HouseDealer")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 8)
                    // Main menu buttons
                    VStack(spacing: 20) {
                        NavigationLink(destination: MapSelectionView()) {
                            MenuButton(title: "Start Counting", systemImage: "play.fill")
                        }
                        NavigationLink(destination: SettingsView()) {
                            MenuButton(title: "Settings", systemImage: "gear")
                        }
                        NavigationLink(destination: HowToPlayView()) {
                            MenuButton(title: "How to Play", systemImage: "book.fill")
                        }
                    }
                }
                .padding()
            }
            .overlay(
                GeometryReader { geo in
                    NavigationLink(destination: RewardsView()) {
                        RewardsButton()
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            )
        }
    }
}

// Custom button style for menu items
struct MenuButton: View {
    let title: String
    let systemImage: String
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(hex: "0f3460"))
                .shadow(radius: 5)
        )
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct RewardsButton: View {
    @AppStorage("lastDailyRewardDate") var lastDailyRewardDate: Double = 0
    @State private var animate = false
    var rewardAvailable: Bool {
        let now = Date().timeIntervalSince1970
        return now - lastDailyRewardDate > 24 * 60 * 60
    }
    var body: some View {
        Text("🎁 Rewards")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 60)
            .background(rewardAvailable ? Color.yellow : Color.gray)
            .cornerRadius(18)
            .shadow(color: rewardAvailable ? .yellow : .clear, radius: 12)
            .scaleEffect(animate && rewardAvailable ? 1.08 : 1.0)
            .animation(rewardAvailable ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: animate)
            .onAppear { animate = true }
    }
} 