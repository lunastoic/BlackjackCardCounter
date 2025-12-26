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
        print("🔵 Last payout: \(gameState.lastPayout)")
        
        if chipValue <= XPChipManager.shared.userChips {
            // Starting a new betting sequence: clear any prior display amount from previous round
            gameState.displayBetAmount = 0
            // Reset the hide flag to ensure chips are visible
            gameState.hideBetChipsDuringLoseAnimation = false
            // If a previous win is mid auto-collect, cancel the "hide Return Bet" gating.
            gameState.isAutoCollectingWinnings = false
            gameState.userPlacedCurrentBet = true
            // Handle previous round results when placing new bet
            if gameState.resultMessage != nil {
                if gameState.lastPayout > 0 {
                    // WIN SCENARIO: Clear betting area for fresh start
                    print("🔵 WIN SCENARIO: Clearing betting area for fresh start")
                    // Return current bet chips to user's total (these were winnings)
                    let currentBetValue = gameState.betChips.reduce(0, +)
                    if currentBetValue > 0 {
                        XPChipManager.shared.updateChips(currentBetValue)
                        print("🔵 WIN SCENARIO: Returned \(currentBetValue) chips to user total")
                    }
                    // Clear betting area (including additional chips from double down/split)
                    gameState.playerBet = 0
                    gameState.betChips = []
                    gameState.additionalBetChips = [] // Clear the right-side stack from previous round
                } else if gameState.lastPayout < 0 {
                    // LOSE SCENARIO: Betting area already cleared by game engine
                    print("🔵 LOSE SCENARIO: Betting area already cleared (chips were lost)")
                    // Don't return chips to user - they were lost
                    // Betting state already cleared by game engine when loss occurred
                    // Reset the animation flag so betting chips can be visible again
                    gameState.hideBetChipsDuringLoseAnimation = false
                }
            }
            
            // Add chip to betting area immediately (no animation)
        gameState.playerBet += chipValue
        gameState.betChips.append(chipValue)
        
        // Consolidate chips to prevent lag (e.g., 5x $1 → 1x $5)
        consolidateChips(gameState: gameState)
        
        // Don't clear displayBetAmount here - only clear it when starting a new game
            // Decrease user's chip count when placing a bet
            XPChipManager.shared.updateChips(-chipValue)
            
            // Clear win/lose notification when chip is placed (both training and regular mode)
            let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
            let isTrainingMode = gameState.isTrainingMode
            print("🎓 Training Mode Check: trainingModeEnabled=\(trainingModeEnabled), isTrainingMode=\(isTrainingMode), resultMessage=\(gameState.resultMessage ?? "nil")")
            
            if gameState.resultMessage != nil {
                print("🎯 CLEARING NOTIFICATION: result=\(gameState.resultMessage ?? "nil"), lastPayout=\(gameState.lastPayout)")
                print("🎯 Clearing result notification when chip is placed (both modes)")
                gameState.showResultNotification = false
                gameState.resultMessage = nil
            }
            
            // Trigger card collection animation when user places a chip (both modes)
            if !gameState.dealtPlayerCards.isEmpty {
                print("🎯 Starting card collection animation when chip is placed")
                print("🎯 Betting state before animation: playerBet=\(gameState.playerBet), betChips=\(gameState.betChips)")
                print("🎯 Betting state before animation: resultMessage=\(gameState.resultMessage), showResultNotification=\(gameState.showResultNotification)")
                animateCardsBackToDeck(gameState: gameState)
            }
            
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
        // Clear display amount when returning bet
        gameState.displayBetAmount = 0
    }
    
    func redoBet(gameState: BlackjackGameState) {
        // Redo Bet logic - use ORIGINAL bet only (not including splits/DD)
        guard let previousBet = gameState.lastBet, 
              XPChipManager.shared.userChips >= previousBet else { return }
        
        print("🔄 REDO BET: Original bet was \(previousBet)")
        print("🔄 REDO BET: Current playerBet is \(gameState.playerBet)")
        print("🔄 REDO BET: Current betChips: \(gameState.betChips)")
        print("🔄 REDO BET: Current additionalBetChips: \(gameState.additionalBetChips)")
        
        // Handle current bet based on last round result
        if gameState.lastPayout > 0 {
            // WIN SCENARIO: Return ALL chips to user (bet + payouts + DD chips)
            print("🔄 REDO BET WIN: Returning all chips to user")
            let totalChipsOnTable = gameState.betChips.reduce(0, +) + 
                                    gameState.additionalBetChips.reduce(0, +) +
                                    gameState.doubleDownChipsHand1.reduce(0, +) +
                                    gameState.doubleDownChipsHand2.reduce(0, +)
            XPChipManager.shared.updateChips(totalChipsOnTable)
            print("🔄 REDO BET WIN: Returned \(totalChipsOnTable) chips to user")
        } else if gameState.lastPayout < 0 {
            // LOSE SCENARIO: Betting area already cleared by game engine
            print("🔄 REDO BET LOSE: Betting area already cleared (chips were lost)")
            gameState.hideBetChipsDuringLoseAnimation = false
        } else {
            // PUSH SCENARIO: Return all chips normally
            print("🔄 REDO BET PUSH: Returning all chips to user")
            let totalChipsOnTable = gameState.betChips.reduce(0, +) + 
                                    gameState.additionalBetChips.reduce(0, +) +
                                    gameState.doubleDownChipsHand1.reduce(0, +) +
                                    gameState.doubleDownChipsHand2.reduce(0, +)
            XPChipManager.shared.updateChips(totalChipsOnTable)
        }
        
        // Clear current bet (including ALL chip stacks from double down/split)
        gameState.playerBet = 0
        gameState.betChips = []
        gameState.additionalBetChips = [] // Clear the right-side stack from previous round
        gameState.doubleDownChipsHand2 = [] // Clear double down chips for Hand 2
        gameState.doubleDownChipsHand1 = [] // Clear double down chips for Hand 1
        gameState.displayBetAmount = 0 // Clear display amount for losses
        gameState.hideBetChipsDuringLoseAnimation = false // Reset hide flag
        gameState.isAutoCollectingWinnings = false // Ensure Return Bet isn't hidden going into redo bet
        
        // Now place ONLY the ORIGINAL bet (not the total with splits/DD)
        gameState.playerBet = previousBet
        print("🔄 REDO BET: Placing original bet of \(previousBet)")
        
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
        gameState.userPlacedCurrentBet = true
        
        // Clear win/lose notification when redo bet is used (both training and regular mode)
        let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
        let isTrainingMode = gameState.isTrainingMode
        if gameState.resultMessage != nil {
            print("🎯 Clearing result notification when redo bet is used (both modes)")
            gameState.showResultNotification = false
            gameState.resultMessage = nil
        }
        
        // Trigger card collection animation when user clicks Redo Bet (both modes)
        if !gameState.dealtPlayerCards.isEmpty {
            print("🎯 Starting card collection animation when redo bet is used")
            print("🎯 Betting state before animation: playerBet=\(gameState.playerBet), betChips=\(gameState.betChips)")
            print("🎯 Betting state before animation: resultMessage=\(gameState.resultMessage), showResultNotification=\(gameState.showResultNotification)")
            animateCardsBackToDeck(gameState: gameState)
        }
    }
    
    func canPlaceBet(gameState: BlackjackGameState, chipValue: Int) -> Bool {
        // Check if we have enough remaining chips to place this additional bet
        return chipValue <= XPChipManager.shared.userChips
    }
    
    func canRedoBet(gameState: BlackjackGameState) -> Bool {
        guard let lastBet = gameState.lastBet else { return false }
        return XPChipManager.shared.userChips - gameState.playerBet >= lastBet && !gameState.showNextHand
    }
    
    // MARK: - Chip Consolidation
    private func consolidateChips(gameState: BlackjackGameState) {
        var chipCounts: [Int: Int] = [:]
        
        // Count each chip denomination
        for chip in gameState.betChips {
            chipCounts[chip, default: 0] += 1
        }
        
        var needsConsolidation = false
        var newChips: [Int] = []
        
        // Consolidation rules:
        // 5x $1 → 1x $5
        if let count1 = chipCounts[1], count1 >= 5 {
            let consolidatedCount = count1 / 5
            let remaining = count1 % 5
            newChips.append(contentsOf: Array(repeating: 5, count: consolidatedCount))
            newChips.append(contentsOf: Array(repeating: 1, count: remaining))
            chipCounts.removeValue(forKey: 1)
            needsConsolidation = true
            print("💰 Consolidated \(consolidatedCount * 5) x $1 → \(consolidatedCount) x $5")
        }
        
        // 5x $5 → 1x $25
        if let count5 = chipCounts[5], count5 >= 5 {
            let consolidatedCount = count5 / 5
            let remaining = count5 % 5
            newChips.append(contentsOf: Array(repeating: 25, count: consolidatedCount))
            newChips.append(contentsOf: Array(repeating: 5, count: remaining))
            chipCounts.removeValue(forKey: 5)
            needsConsolidation = true
            print("💰 Consolidated \(consolidatedCount * 5) x $5 → \(consolidatedCount) x $25")
        }
        
        // 2x $25 → 1x $50
        if let count25 = chipCounts[25], count25 >= 2 {
            let consolidatedCount = count25 / 2
            let remaining = count25 % 2
            newChips.append(contentsOf: Array(repeating: 50, count: consolidatedCount))
            newChips.append(contentsOf: Array(repeating: 25, count: remaining))
            chipCounts.removeValue(forKey: 25)
            needsConsolidation = true
            print("💰 Consolidated \(consolidatedCount * 2) x $25 → \(consolidatedCount) x $50")
        }
        
        // 2x $50 → 1x $100
        if let count50 = chipCounts[50], count50 >= 2 {
            let consolidatedCount = count50 / 2
            let remaining = count50 % 2
            newChips.append(contentsOf: Array(repeating: 100, count: consolidatedCount))
            newChips.append(contentsOf: Array(repeating: 50, count: remaining))
            chipCounts.removeValue(forKey: 50)
            needsConsolidation = true
            print("💰 Consolidated \(consolidatedCount * 2) x $50 → \(consolidatedCount) x $100")
        }
        
        // Add remaining chips that weren't consolidated
        for (chip, count) in chipCounts {
            newChips.append(contentsOf: Array(repeating: chip, count: count))
        }
        
        // Update betChips if consolidation occurred
        if needsConsolidation {
            gameState.betChips = newChips.sorted(by: >)
            print("💰 Chips after consolidation: \(gameState.betChips)")
        }
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
    
    // MARK: - Card Collection Animation
    func animateCardsBackToDeck(gameState: BlackjackGameState) {
        // Get player and dealer cards separately
        let playerCards = gameState.dealtPlayerCards
        let dealerCards = gameState.dealtDealerCards
        
        guard !playerCards.isEmpty || !dealerCards.isEmpty else {
            print("🎯 No cards to collect")
            return
        }
        
        print("🎯 Collecting \(playerCards.count) player cards and \(dealerCards.count) dealer cards back to deck")
        
        // Use the deck collection position as the collection target (top-left deck asset)
        let deckPosition = gameState.deckCollectionPosition != .zero ? gameState.deckCollectionPosition : CGPoint(x: 50, y: 100)
        print("🎯 Using deck collection position for collection: \(deckPosition)")
        
        // Use the new EndRoundCardAnimation to collect cards to the deck
        EndRoundCardAnimation.collectCardsToDeck(
            playerCards: playerCards,
            dealerCards: dealerCards,
            deckPosition: deckPosition,
            dealtPlayerCards: gameState.dealtPlayerCards,
            dealtDealerCards: gameState.dealtDealerCards,
            flippedDealerCards: gameState.flippedDealerCards,
            gameState: gameState
            ) {
                print("🎯 All card collection animation completed")
                print("🎯 Betting state after animation: playerBet=\(gameState.playerBet), betChips=\(gameState.betChips)")
                print("🎯 Betting state after animation: resultMessage=\(gameState.resultMessage), showResultNotification=\(gameState.showResultNotification)")
                print("🎯 Betting state after animation: isCollectingPhase=\(gameState.isCollectingPhase)")
                print("🎯 Betting state after animation: showNextHand=\(gameState.showNextHand), showPostGameButtons=\(gameState.showPostGameButtons)")
                print("🎯 Betting state after animation: isPlayerTurn=\(gameState.isPlayerTurn), isProcessingAction=\(gameState.isProcessingAction)")
                
                // Add a delay to check if something clears the betting state after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🎯 Betting state 1 second after animation: playerBet=\(gameState.playerBet), betChips=\(gameState.betChips)")
                    print("🎯 Betting state 1 second after animation: isCollectingPhase=\(gameState.isCollectingPhase)")
                }
                
                // Add another delay to check after isCollectingPhase is set to false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("🎯 Betting state 2 seconds after animation: playerBet=\(gameState.playerBet), betChips=\(gameState.betChips)")
                    print("🎯 Betting state 2 seconds after animation: isCollectingPhase=\(gameState.isCollectingPhase)")
                }
                
                // Cards are now collected back to the deck, ready for the next round
            }
    }
} 
