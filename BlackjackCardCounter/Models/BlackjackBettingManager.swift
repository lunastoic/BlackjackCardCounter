import SwiftUI

// MARK: - Betting Management
class BlackjackBettingManager: ObservableObject {
    static let shared = BlackjackBettingManager()
    
    private init() {}
    
    // MARK: - Betting Actions
    func placeBet(gameState: BlackjackGameState, chipValue: Int) {
        print("🔵 placeBet called with chipValue: \(chipValue)")
        print("🔵 Current playerBet: \(gameState.playerBet)")
        print("🔵 Current betChips: \(gameState.betChips)")
        print("🔵 Available chips: \(XPChipManager.shared.userChips)")
        
        if chipValue <= XPChipManager.shared.userChips {
            gameState.playerBet += chipValue
            gameState.betChips.append(chipValue)
            // Decrease user's chip count when placing a bet
            XPChipManager.shared.updateChips(-chipValue)
            
            print("✅ Bet placed successfully!")
            print("✅ New playerBet: \(gameState.playerBet)")
            print("✅ New betChips: \(gameState.betChips)")
        } else {
            print("❌ Cannot place bet - insufficient chips")
        }
    }
    
    func returnBet(gameState: BlackjackGameState) {
        if let lastBet = gameState.betChips.popLast() {
            gameState.playerBet -= lastBet
            // Add chips back to user's count when returning a bet
            XPChipManager.shared.updateChips(lastBet)
        }
    }
    
    func redoBet(gameState: BlackjackGameState) {
        // Redo Bet logic - clear current bet and place previous bet
        guard let previousBet = gameState.lastBet, 
              XPChipManager.shared.userChips >= previousBet else { return }
        
        // First, clear current bet and add chips back to total
        for chip in gameState.betChips {
            XPChipManager.shared.updateChips(chip)
        }
        
        // Clear current bet
        gameState.playerBet = 0
        gameState.betChips = []
        
        // Now place the previous bet
        gameState.playerBet = previousBet
        
        // Add chips for the previous bet (subtract from total)
        var remaining = previousBet
        var newChips: [Int] = []
        let playerChips = [1, 5, /* 10, */ 25, 50, 100]
        
        for chip in playerChips.sorted(by: >) {
            while remaining >= chip {
                newChips.append(chip)
                remaining -= chip
            }
        }
        
        gameState.betChips.append(contentsOf: newChips)
        
        // Subtract the previous bet amount from total
        XPChipManager.shared.updateChips(-previousBet)
    }
    
    func canPlaceBet(gameState: BlackjackGameState, chipValue: Int) -> Bool {
        // Check if we have enough remaining chips to place this additional bet
        return chipValue <= XPChipManager.shared.userChips
    }
    
    func canRedoBet(gameState: BlackjackGameState) -> Bool {
        guard let lastBet = gameState.lastBet else { return false }
        return XPChipManager.shared.userChips - gameState.playerBet >= lastBet && !gameState.showNextHand
    }
    
    // MARK: - Bet Display
    func getBetChipCounts(gameState: BlackjackGameState) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for chip in gameState.betChips {
            counts[chip, default: 0] += 1
        }
        return counts
    }
    
    func getSortedBetChips(gameState: BlackjackGameState) -> [Int] {
        return Array(Set(gameState.betChips)).sorted()
    }
} 
