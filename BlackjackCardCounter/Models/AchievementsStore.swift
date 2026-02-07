import Foundation

@MainActor
final class AchievementsViewModel: ObservableObject {
    @Published var achievements: [AchievementViewData] = []
    @Published var unlockedCount: Int = 0
    @Published var totalCount: Int = 0
    
    private let store = AchievementsStore.shared
    
    func refresh() async {
        let data = await store.snapshot()
        let defs = AchievementsStore.definitions
        let unlockedIds = Set(data.unlocked.map { $0.id })
        let unlockedMap = Dictionary(uniqueKeysWithValues: data.unlocked.map { ($0.id, $0.unlockedAt as Date?) })
        
        let viewData: [AchievementViewData] = defs.map { def in
            let isUnlocked = unlockedIds.contains(def.id)
            let current: Int
            if let key = def.statKey {
                current = data.stats.value(for: key)
            } else {
                current = 0
            }
            let goal = def.goal ?? 1
            return AchievementViewData(
                id: def.id,
                title: def.title,
                description: def.detail,
                current: current,
                goal: goal,
                isUnlocked: isUnlocked,
                unlockedAt: unlockedMap[def.id] ?? nil
            )
        }
        
        await MainActor.run {
            self.achievements = viewData
            self.totalCount = defs.count
            self.unlockedCount = viewData.filter { $0.isUnlocked }.count
        }
    }
}

struct AchievementViewData: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let current: Int
    let goal: Int
    let isUnlocked: Bool
    let unlockedAt: Date?
}

actor AchievementsStore {
    static let shared = AchievementsStore()
    nonisolated static let definitions: [AchievementDefinition] = [
        AchievementDefinition(id: "reach_level_5", title: "Reach Level 5", detail: "Reach player level 5", statKey: .handsPlayed, goal: 5),
        AchievementDefinition(id: "reach_level_10", title: "Reach Level 10", detail: "Reach player level 10", statKey: .handsPlayed, goal: 10),
        AchievementDefinition(id: "reach_level_20", title: "Reach Level 20", detail: "Reach player level 20", statKey: .handsPlayed, goal: 20),
        AchievementDefinition(id: "first_blackjack", title: "First Blackjack!", detail: "Get three natural blackjacks (Ace + 10) in hands", statKey: .blackjacks, goal: 3),
        AchievementDefinition(id: "double_down", title: "Double Down!", detail: "Double down 10 times", statKey: .doubles, goal: 10),
        AchievementDefinition(id: "split_master", title: "Split Master", detail: "Split pairs 5 times", statKey: .splits, goal: 5),
        AchievementDefinition(id: "winning_streak", title: "Winning Streak", detail: "Win 10 hands in a row", statKey: .winStreakBest, goal: 10),
        AchievementDefinition(id: "push_count", title: "Push It Real Good", detail: "Get 10 pushes (ties)", statKey: .pushes, goal: 10),
        AchievementDefinition(id: "chip_collector", title: "Chip Collector", detail: "Accumulate 1,000 chips", statKey: .wins, goal: 1000),
        AchievementDefinition(id: "card_counter", title: "Card Counter", detail: "Keep a running count above +10", statKey: nil, goal: nil),
        AchievementDefinition(id: "dealer_busted", title: "Dealer Busted!", detail: "Win 10 hands where the dealer busts", statKey: .wins, goal: 10),
        AchievementDefinition(id: "perfect_strategy", title: "Perfect Strategy", detail: "Play 20 hands with perfect basic strategy", statKey: nil, goal: 20),
        AchievementDefinition(id: "comeback_kid", title: "Comeback Kid", detail: "Win after being down to your last 10 chips", statKey: nil, goal: 1),
        AchievementDefinition(id: "high_roller", title: "High Roller", detail: "Place a bet of 500 chips", statKey: nil, goal: 1),
        AchievementDefinition(id: "no_busts", title: "No Busts!", detail: "Play 10 hands in a row without busting", statKey: .noBustBest, goal: 10),
        AchievementDefinition(id: "dealer_blackjack", title: "Dealer Blackjack", detail: "Lose to a dealer blackjack 5 times", statKey: nil, goal: 5),
        AchievementDefinition(id: "all_in", title: "All In!", detail: "Bet all your chips in one hand", statKey: nil, goal: 1)
    ]
    
    private let schemaVersion = 1
    private let fileName = "achievements.json"
    private var persisted: AchievementsFile
    
    private init() {
        persisted = AchievementsStore.loadFromDisk(fileName: fileName) ?? AchievementsFile(schemaVersion: schemaVersion, stats: Stats(), unlocked: [])
    }
    
    func snapshot() async -> AchievementsFile { persisted }
    
    func isAchievementUnlocked(id: String) -> Bool {
        return persisted.unlocked.contains { $0.id == id }
    }
    
    func markAchievementUnlocked(id: String, unlockedAt: Date = Date()) async {
        // Stop-tracking rule: never re-unlock or re-evaluate
        guard !isAchievementUnlocked(id: id) else { return }
        persisted.unlocked.append(UnlockedAchievement(id: id, unlockedAt: unlockedAt))
        save()
    }
    
    func incrementStat(_ key: StatsKey, by amount: Int = 1) async {
        var stats = persisted.stats
        stats.increment(key, by: amount)
        persisted.stats = stats
        save()
    }
    
    func resetNoBustStreak() async {
        var stats = persisted.stats
        stats.noBustCurrent = 0
        persisted.stats = stats
        save()
    }
    
    func incrementNoBustStreak() async {
        var stats = persisted.stats
        stats.noBustCurrent += 1
        stats.noBustBest = max(stats.noBustBest, stats.noBustCurrent)
        persisted.stats = stats
        save()
    }
    
    private func save() {
        persisted.schemaVersion = schemaVersion
        AchievementsStore.saveToDisk(fileName: fileName, data: persisted)
    }
    
    private static func loadFromDisk(fileName: String) -> AchievementsFile? {
        do {
            let url = try applicationSupportURL().appendingPathComponent(fileName)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AchievementsFile.self, from: data)
        } catch {
            return nil
        }
    }
    
    private static func saveToDisk(fileName: String, data: AchievementsFile) {
        do {
            let url = try applicationSupportURL().appendingPathComponent(fileName)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            // swallow for now; add logging later
        }
    }
    
    private static func applicationSupportURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}

private extension Stats {
    mutating func increment(_ key: StatsKey, by amount: Int) {
        switch key {
        case .handsPlayed: handsPlayed += amount
        case .blackjacks: blackjacks += amount
        case .doubles: doubles += amount
        case .splits: splits += amount
        case .wins: wins += amount
        case .pushes: pushes += amount
        case .losses: losses += amount
        case .winStreakBest: winStreakBest = max(winStreakBest, amount)
        case .lossStreakBest: lossStreakBest = max(lossStreakBest, amount)
        case .noBustCurrent: noBustCurrent = max(0, noBustCurrent + amount)
        case .noBustBest: noBustBest = max(noBustBest, amount)
        }
    }
    
    func value(for key: StatsKey) -> Int {
        switch key {
        case .handsPlayed: return handsPlayed
        case .blackjacks: return blackjacks
        case .doubles: return doubles
        case .splits: return splits
        case .wins: return wins
        case .pushes: return pushes
        case .losses: return losses
        case .winStreakBest: return winStreakBest
        case .lossStreakBest: return lossStreakBest
        case .noBustCurrent: return noBustCurrent
        case .noBustBest: return noBustBest
        }
    }
}
