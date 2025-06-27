import SwiftUI

class XPChipManager: ObservableObject {
    static let shared = XPChipManager()
    
    @Published var userChips: Int = UserDefaults.standard.integer(forKey: "userChips") == 0 ? 500 : UserDefaults.standard.integer(forKey: "userChips") {
        didSet { UserDefaults.standard.set(userChips, forKey: "userChips") }
    }
    @Published var userLevel: Int = UserDefaults.standard.integer(forKey: "userLevel") == 0 ? 1 : UserDefaults.standard.integer(forKey: "userLevel") {
        didSet { UserDefaults.standard.set(userLevel, forKey: "userLevel") }
    }
    @Published var userXP: Double = UserDefaults.standard.double(forKey: "userXP") {
        didSet { UserDefaults.standard.set(userXP, forKey: "userXP") }
    }
    let xpPerLevel: Double = 30
    let maxLevel: Int = 25
    
    private init() {}
    
    func addXP(_ amount: Double, didWin: Bool = false) {
        var xpToAdd = amount
        if didWin { xpToAdd += 1 }
        userXP += xpToAdd
        var leveledUp = false
        while userXP >= xpPerLevel && userLevel < maxLevel {
            userXP -= xpPerLevel
            userLevel += 1
            userChips += 1000 // Level up reward
            leveledUp = true
        }
        if userLevel >= maxLevel {
            userXP = 0
        }
        // Notify for animation
        NotificationCenter.default.post(name: .xpChipDidChange, object: nil, userInfo: [
            "xp": userXP,
            "level": userLevel,
            "chips": userChips,
            "leveledUp": leveledUp
        ])
    }
    
    func updateChips(_ amount: Int) {
        userChips += amount
        NotificationCenter.default.post(name: .xpChipDidChange, object: nil, userInfo: [
            "xp": userXP,
            "level": userLevel,
            "chips": userChips,
            "leveledUp": false
        ])
    }
}

extension Notification.Name {
    static let xpChipDidChange = Notification.Name("xpChipDidChange")
} 