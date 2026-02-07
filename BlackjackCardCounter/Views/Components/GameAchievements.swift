import SwiftUI

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
    @StateObject private var viewModel = AchievementsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(viewModel.achievements) { achievement in
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: achievement.isUnlocked ? "trophy.fill" : "trophy")
                            .foregroundColor(achievement.isUnlocked ? .yellow : .gray)
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
                        
                        if achievement.isUnlocked {
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
        .onAppear { Task { await viewModel.refresh() } }
    }
}

// Note: Color(hex:) extension already exists elsewhere in the project
