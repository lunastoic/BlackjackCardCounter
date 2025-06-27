import SwiftUI

struct RewardsView: View {
    @ObservedObject var xpManager = XPChipManager.shared
    @AppStorage("lastDailyRewardDate") var lastDailyRewardDate: Double = 0
    @AppStorage("lastAdRewardDate") var lastAdRewardDate: Double = 0
    @State private var showAdReward: Bool = false
    @State private var showClaimed: Bool = false
    @State private var now: Date = Date()
    let dailyRewardAmount = 500
    let adRewardAmount = 1000
    let adCooldown: TimeInterval = 0 // For now, allow ad reward any time user is out of chips
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var dailyAvailable: Bool {
        let elapsed = now.timeIntervalSince1970 - lastDailyRewardDate
        return elapsed > 24 * 60 * 60
    }
    var adAvailable: Bool {
        // Only allow ad reward if user is out of chips and daily is not available
        return xpManager.userChips == 0 && !dailyAvailable
    }
    var nextDaily: TimeInterval {
        max(0, 24 * 60 * 60 - (now.timeIntervalSince1970 - lastDailyRewardDate))
    }
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 32) {
                Text("Rewards")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                    .padding(.top, 32)
                VStack(spacing: 24) {
                    // Daily Reward
                    VStack(spacing: 10) {
                        Text("Daily Reward")
                            .font(.title2)
                            .foregroundColor(.white)
                        if dailyAvailable {
                            Button(action: {
                                XPChipManager.shared.updateChips(dailyRewardAmount)
                                lastDailyRewardDate = Date().timeIntervalSince1970
                                showClaimed = true
                            }) {
                                Text("Claim 500 Chips")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 40)
                                    .background(Color.yellow)
                                    .cornerRadius(16)
                                    .shadow(radius: 8)
                            }
                            .padding(.top, 6)
                        } else {
                            VStack(spacing: 4) {
                                Text("Claimed! Come back in:")
                                    .foregroundColor(.gray)
                                Text(timeString(from: nextDaily))
                                    .font(.title2)
                                    .foregroundColor(.yellow)
                                    .monospacedDigit()
                            }
                        }
                    }
                    Divider().background(Color.white.opacity(0.3))
                    // Ad Reward
                    VStack(spacing: 10) {
                        Text("Need More Chips?")
                            .font(.title2)
                            .foregroundColor(.white)
                        if adAvailable {
                            Button(action: {
                                // Simulate ad watching
                                XPChipManager.shared.updateChips(adRewardAmount)
                                lastAdRewardDate = Date().timeIntervalSince1970
                                showAdReward = true
                            }) {
                                Text("Watch Ad for 1000 Chips")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 40)
                                    .background(Color.blue)
                                    .cornerRadius(16)
                                    .shadow(radius: 8)
                            }
                        } else {
                            Text("Watch an ad to get more chips when you're out!")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(hex: "23272a").opacity(0.92))
                .cornerRadius(22)
                .shadow(radius: 16)
                Spacer()
            }
            .padding(.horizontal, 24)
            .onReceive(timer) { _ in
                now = Date()
            }
            .alert(isPresented: $showClaimed) {
                Alert(title: Text("Chips Added!"), message: Text("500 chips have been added to your account."), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showAdReward) {
                Alert(title: Text("Chips Added!"), message: Text("1000 chips have been added to your account."), dismissButton: .default(Text("OK")))
            }
        }
    }
    func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    RewardsView()
} 
