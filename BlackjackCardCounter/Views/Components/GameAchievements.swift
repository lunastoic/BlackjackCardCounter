import SwiftUI

// MARK: - Achievement Model
struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let current: Int
    let goal: Int
    var isComplete: Bool { current >= goal }
}

// MARK: - Achievement Progress Bar
struct AchievementProgressBar: View {
    let progress: Double // 0.0 to 1.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 10)
                
                Capsule()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.yellow]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * progress, height: 10)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Achievements Tab View
struct AchievementsTabView: View {
    var body: some View {
        let achievements: [Achievement] = [
            Achievement(title: "Reach Level 5", description: "Reach player level 5", current: 3, goal: 5),
            Achievement(title: "Reach Level 10", description: "Reach player level 10", current: 7, goal: 10),
            Achievement(title: "Reach Level 20", description: "Reach player level 200", current: 12, goal: 20),
            Achievement(title: "Reach Level 30", description: "Reach player level 30", current: 18, goal: 30),
            Achievement(title: "Reach Level 40", description: "Reach player level 40", current: 25, goal: 40),
            Achievement(title: "Reach Level 50", description: "Reach player level 50", current: 32, goal: 50),
            Achievement(title: "First Blackjack!", description: "Get a natural blackjack (Ace + 10) in a hand", current: 1, goal: 1),
            Achievement(title: "Double Down!", description: "Double down 10 times", current: 4, goal: 10),
            Achievement(title: "Split Master", description: "Split pairs 5 times", current: 2, goal: 5),
            Achievement(title: "Winning Streak", description: "Win 10 hands in a row", current: 6, goal: 10),
            Achievement(title: "Push It Real Good", description: "Get 10 pushes (ties)", current: 3, goal: 10),
            Achievement(title: "Chip Collector", description: "Accumulate 1,000 chips", current: 500, goal: 1000),
            Achievement(title: "Card Counter", description: "Keep a running count above +10", current: 8, goal: 10),
            Achievement(title: "Dealer Busted!", description: "Win 10 hands where the dealer busts", current: 5, goal: 10),
            Achievement(title: "Insurance Expert", description: "Take insurance 5 times", current: 1, goal: 5),
            Achievement(title: "Perfect Strategy", description: "Play 20 hands with perfect basic strategy", current: 10, goal: 20),
            Achievement(title: "Quiz Whiz", description: "Score 100% on a quiz", current: 0, goal: 1),
            Achievement(title: "Big Winner", description: "Win a hand with a bet of 100 chips or more", current: 1, goal: 1),
            Achievement(title: "Comeback Kid", description: "Win after being down to your last 10 chips", current: 0, goal: 1),
            Achievement(title: "Five Card Charlie", description: "Win a hand with 5 cards without busting", current: 0, goal: 1),
            Achievement(title: "Lucky 7s", description: "Get three 7s in a hand", current: 0, goal: 1),
            Achievement(title: "High Roller", description: "Place a bet of 500 chips", current: 0, goal: 1),
            Achievement(title: "No Busts!", description: "Play 10 hands in a row without busting", current: 4, goal: 10),
            Achievement(title: "Dealer Blackjack", description: "Lose to a dealer blackjack 5 times", current: 2, goal: 5),
            Achievement(title: "All In!", description: "Bet all your chips in one hand", current: 0, goal: 1)
        ]
        
        ScrollView {
            VStack(spacing: 18) {
                ForEach(achievements) { achievement in
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: achievement.isComplete ? "trophy.fill" : "trophy")
                            .foregroundColor(achievement.isComplete ? .yellow : .gray)
                            .font(.title2)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(achievement.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(achievement.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                            AchievementProgressBar(progress: min(Double(achievement.current) / Double(achievement.goal), 1.0))
                                .frame(height: 10)
                            Text("\(achievement.current)/\(achievement.goal)")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        if achievement.isComplete {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "23272a").opacity(0.85))
                    .cornerRadius(12)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: 340, minHeight: 220, maxHeight: 340)
    }
}

// Note: Color(hex:) extension already exists elsewhere in the project
