import Foundation

struct AchievementDefinition: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let statKey: StatsKey?
    let goal: Int?
}

struct UnlockedAchievement: Codable, Hashable {
    let id: String
    let unlockedAt: Date?
}

enum StatsKey: String, Codable, CaseIterable, Hashable {
    case handsPlayed
    case blackjacks
    case doubles
    case splits
    case wins
    case pushes
    case losses
    case winStreakBest
    case lossStreakBest
    case noBustCurrent
    case noBustBest
}

struct Stats: Codable, Hashable {
    var handsPlayed: Int = 0
    var blackjacks: Int = 0
    var doubles: Int = 0
    var splits: Int = 0
    var wins: Int = 0
    var pushes: Int = 0
    var losses: Int = 0
    var winStreakBest: Int = 0
    var lossStreakBest: Int = 0
    var noBustCurrent: Int = 0
    var noBustBest: Int = 0
}

struct AchievementsFile: Codable {
    var schemaVersion: Int
    var stats: Stats
    var unlocked: [UnlockedAchievement]
}
