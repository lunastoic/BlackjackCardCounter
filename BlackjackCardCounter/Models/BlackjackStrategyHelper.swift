import SwiftUI

// MARK: - Strategy Helper
class BlackjackStrategyHelper {
    static let shared = BlackjackStrategyHelper()
    
    private init() {}
    
    // Returns the perfect strategy action for the current hand and dealer upcard
    func getPerfectStrategyAction(playerHand: [Card], dealerHand: [Card]) -> String? {
        // Only works for non-split hands for now
        let dealerUp = dealerHand.first?.rank.value ?? 0
        let player = playerHand
        
        if player.count == 2 {
            // Check for pairs
            if player[0].rank == player[1].rank {
                let pairValue = player[0].rank.value
                switch pairValue {
                case 1: return "Split" // AA
                case 8: return "Split" // 8-8
                case 9:
                    if (2...6).contains(dealerUp) || dealerUp == 8 || dealerUp == 9 { return "Split" }
                    if dealerUp == 7 || dealerUp == 10 || dealerUp == 1 { return "Stand" }
                case 7:
                    if (2...7).contains(dealerUp) { return "Split" } else { return "Hit" }
                case 6:
                    if (2...6).contains(dealerUp) { return "Split" } else { return "Hit" }
                case 2, 3:
                    if (2...7).contains(dealerUp) { return "Split" } else { return "Hit" }
                case 4:
                    if (5...6).contains(dealerUp) { return "Split" } else { return "Hit" }
                case 5:
                    // Treat as hard 10
                    return getHardTotalAction(total: 10, dealerUp: dealerUp)
                case 10:
                    return "Stand"
                default: break
                }
            }
            
            // Check for soft totals (one ace counted as 11)
            if player.contains(where: { $0.rank == .ace }) {
                let other = player.first { $0.rank != .ace }?.rank.value ?? 1
                let softTotal = 11 + other
                return getSoftTotalAction(total: softTotal, dealerUp: dealerUp)
            }
        }
        
        // Hard totals
        let total = handValue(player)
        return getHardTotalAction(total: total, dealerUp: dealerUp)
    }
    
    // Helper for hard totals
    private func getHardTotalAction(total: Int, dealerUp: Int) -> String {
        switch total {
        case 5,6,7: return "Hit"
        case 8:
            if (5...6).contains(dealerUp) { return "Double Down" } else { return "Hit" }
        case 9:
            if (2...6).contains(dealerUp) { return "Double Down" } else { return "Hit" }
        case 10:
            if (2...9).contains(dealerUp) { return "Double Down" } else { return "Hit" }
        case 11:
            if (2...10).contains(dealerUp) { return "Double Down" } else { return "Hit" }
        case 12:
            if (4...6).contains(dealerUp) { return "Stand" } else { return "Hit" }
        case 13,14,15,16:
            if (2...6).contains(dealerUp) { return "Stand" } else { return "Hit" }
        default:
            return "Stand"
        }
    }
    
    // Helper for soft totals
    private func getSoftTotalAction(total: Int, dealerUp: Int) -> String {
        switch total {
        case 13,14:
            if (4...6).contains(dealerUp) { return "Double Down" } else { return "Hit" }
        case 15,16:
            if (4...6).contains(dealerUp) { return "Double Down" } else { return "Hit" }
        case 17:
            if (3...6).contains(dealerUp) { return "Double Down" } else { return "Hit" }
        case 18:
            if (3...6).contains(dealerUp) { return "Double Down" }
            if (2...8).contains(dealerUp) { return "Stand" } else { return "Hit" }
        case 19:
            if dealerUp == 6 { return "Double Down" } else { return "Stand" }
        case 20,21:
            return "Stand"
        default:
            return "Hit"
        }
    }
    
    // Helper function to calculate hand value
    private func handValue(_ hand: [Card]) -> Int {
        var total = 0
        var aces = 0
        
        for card in hand {
            if card.rank == .ace {
                aces += 1
            } else {
                total += card.rank.value
            }
        }
        
        total += aces
        
        var value = total
        for _ in 0..<aces {
            if value + 10 <= 21 {
                value += 10
            }
        }
        
        return value
    }
    
    // Helper: Cards dealt by value
    func cardsDealtByValue(dealtPlayerCards: [Card], dealtDealerCards: [Card], flippedDealerCards: Set<Int> = []) -> [String: Int] {
        let allRanks: [String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        var counts = [String: Int]()
        
        for rank in allRanks {
            counts[rank] = 0
        }
        
        // In training mode, only count visible dealer cards (flipped cards)
        let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
        let visibleDealerCards: [Card]
        
        print("🎯 Card Counter Debug: trainingModeEnabled=\(trainingModeEnabled)")
        print("🎯 Card Counter Debug: flippedDealerCards=\(flippedDealerCards)")
        print("🎯 Card Counter Debug: dealtDealerCards count=\(dealtDealerCards.count)")
        
        if trainingModeEnabled {
            // Only count dealer cards that are explicitly flipped (visible)
            visibleDealerCards = dealtDealerCards.enumerated().compactMap { index, card in
                let isFlipped = flippedDealerCards.contains(index)
                print("🎯 Training Mode Card Check: Dealer card \(index) (\(card.rank.rawValue)) - flipped: \(isFlipped)")
                return flippedDealerCards.contains(index) ? card : nil
            }
            print("🎯 Training Mode: Visible dealer cards: \(visibleDealerCards.map { $0.rank.rawValue })")
        } else {
            // In regular mode, count all dealer cards
            visibleDealerCards = dealtDealerCards
        }
        
        let allDealt = dealtPlayerCards + visibleDealerCards
        
        for card in allDealt {
            let displayLabel: String
            switch card.rank {
            case .ace: displayLabel = "A"
            case .jack: displayLabel = "J"
            case .queen: displayLabel = "Q"
            case .king: displayLabel = "K"
            default: displayLabel = card.rank.rawValue
            }
            counts[displayLabel, default: 0] += 1
        }
        
        return counts
    }
    
    // Helper: Cards remaining by value
    func cardsRemainingByValue(deck: [Card]) -> [String: Int] {
        let allRanks: [String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        var counts = [String: Int]()
        
        for rank in allRanks {
            counts[rank] = 0
        }
        
        for card in deck {
            let displayLabel: String
            switch card.rank {
            case .ace: displayLabel = "A"
            case .jack: displayLabel = "J"
            case .queen: displayLabel = "Q"
            case .king: displayLabel = "K"
            default: displayLabel = card.rank.rawValue
            }
            counts[displayLabel, default: 0] += 1
        }
        
        return counts
    }
} 
