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
        print("🔵 Max bet: \(gameState.maxBet)")
        
        // Check if adding this chip would exceed max bet per hand
        let newBet = gameState.playerBet + chipValue
        if newBet > gameState.maxBet {
            print("❌ Cannot place bet - would exceed max bet of $\(gameState.maxBet). Current bet: $\(gameState.playerBet), trying to add: $\(chipValue)")
            return
        }
        
        if chipValue <= XPChipManager.shared.userChips {
            // Starting a new betting sequence: clear any prior display amount from previous round
            gameState.displayBetAmount = 0
            // Reset flags so UI/buttons aren't blocked
            gameState.hideBetChipsDuringLoseAnimation = false
            gameState.isAutoCollectingWinnings = false
            gameState.isCollectingPhase = false
            gameState.isDealing = false        // ensure Deal Cards tap isn't short-circuited
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
                    gameState.originalLargestChip = nil
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
        
        // CRITICAL: Store the largest chip FIRST before any consolidation logic
        // This ensures we always know the top chip user wants to see, even if consolidation runs
        // ALWAYS track the chipValue being placed - this is what user actually wants to see
        let currentLargest = gameState.originalLargestChip ?? 0
        let newLargest = max(currentLargest, chipValue) // Always use chipValue, not array max
        
        // Update originalLargestChip IMMEDIATELY - this must happen before consolidation check
        // This is the chip user actually placed, regardless of what's in betChips array
        if newLargest > currentLargest {
            gameState.originalLargestChip = newLargest
            print("💰 Updated originalLargestChip: $\(newLargest) (was $\(currentLargest), placed: $\(chipValue))")
        }
        
        // CRITICAL: NEVER consolidate if user placed ANY chip >= 100 OR if originalLargestChip >= 100
        // This prevents creating smaller chips (like 100) that would show briefly
        // Europa Ice Palace: User places 10x 1k chips -> originalLargestChip = 1000 -> no consolidation
        // Io Inferno Lounge: User places 10x 500 chips -> originalLargestChip = 500 -> no consolidation
        // Ganymede Grand works because it never consolidates (all chips are >= 100)
        let hasLargeChips = chipValue >= 100 || 
                           newLargest >= 100 ||  // Use newLargest since we just updated originalLargestChip
                           gameState.betChips.contains { $0 >= 100 }
        
        // NEVER consolidate if user has placed chips >= 100 - this is the key to preventing 100 chip flash
        if hasLargeChips {
            print("💰 Skipping consolidation - user placed chip $\(chipValue), originalLargestChip=$\(newLargest) >= 100, preserving all chips")
        } else {
            // Only consolidate very small chips (all <= 25) if there are many of them
            let shouldConsolidate = gameState.betChips.count > 15 && 
                                    gameState.betChips.allSatisfy { $0 <= 25 }
            
            if !gameState.hasEverDealtCards && shouldConsolidate {
                // Only consolidate very small chips to prevent lag
                consolidateChips(gameState: gameState)
                // After consolidation, update originalLargestChip to reflect new max
                if let newMax = gameState.betChips.max(), newMax > (gameState.originalLargestChip ?? 0) {
                    gameState.originalLargestChip = newMax
                    print("💰 Updated originalLargestChip after consolidation: $\(newMax)")
                }
            }
        }
        
        // Never optimize - it breaks down chips incorrectly
        // The minimization on deal cards will handle reducing to single chip
        
        // Filter out any chips that don't exist in the current map's configuration
        filterInvalidChips(gameState: gameState)
        
        // Don't clear displayBetAmount here - only clear it when starting a new game
            // Decrease user's chip count when placing a bet
            XPChipManager.shared.updateChips(-chipValue)
            
            // Clear win/lose notification when chip is placed (both training and regular mode)
            print("🎓 Training Mode Check: resultMessage=\(gameState.resultMessage ?? "nil")")
            
            if gameState.resultMessage != nil {
                print("🎯 CLEARING NOTIFICATION: result=\(String(describing: gameState.resultMessage)), lastPayout=\(gameState.lastPayout)")
                print("🎯 Clearing result notification when chip is placed (both modes)")
                gameState.showResultNotification = false
                gameState.resultMessage = nil
            }
            
            // Trigger card collection animation when user places a chip (both modes)
            if !gameState.dealtPlayerCards.isEmpty {
                print("🎯 Starting card collection animation when chip is placed")
                print("🎯 Betting state before animation: playerBet=\(gameState.playerBet), betChips=\(gameState.betChips)")
                print("🎯 Betting state before animation: resultMessage=\(String(describing: gameState.resultMessage)), showResultNotification=\(gameState.showResultNotification)")
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
        
        // Reset blocking flags so buttons/actions are enabled immediately
        gameState.isDealing = false
        gameState.isCollectingPhase = false
        gameState.isProcessingAction = false
        gameState.showNextHand = false
        gameState.userPlacedCurrentBet = true
        
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
        gameState.originalLargestChip = nil
        gameState.displayChip = nil // Clear display chip
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
        
        // Get available chip denominations from map's configuration
        let playerChips: [Int]
        if let map = gameState.currentMap {
            playerChips = Array(map.assetConfig.chipImages.keys).sorted(by: >)
        } else {
            // Fallback to default chips
            playerChips = [1, 5, 25, 50, 100]
        }
        
        for chip in playerChips {
            while remaining >= chip {
                newChips.append(chip)
                remaining -= chip
            }
        }
        
        gameState.betChips.append(contentsOf: newChips)
        
        // Reset chip display flags so chips are visible after redo bet
        // This ensures chips show up visibly when redo bet is clicked
        gameState.hasEverDealtCards = false
        gameState.chipsMinimized = false
        
        // Store the largest chip from ALL chips (new + existing) for gameplay minimization
        // This ensures we always track the top chip the user wants to see
        let allChips = gameState.betChips + newChips
        if let largestChip = allChips.max() {
            // Always update to the maximum chip value
            let currentLargest = gameState.originalLargestChip ?? 0
            if largestChip > currentLargest {
                gameState.originalLargestChip = largestChip
                gameState.displayChip = nil // Clear display chip when redoing bet
                print("💰 RedoBet: Updated originalLargestChip: $\(largestChip) (was $\(currentLargest))")
            }
        }
        
        // Don't optimize - it breaks down chips incorrectly
        // The minimization on deal cards will handle reducing to single chip
        
        // Subtract the previous bet amount from total
        XPChipManager.shared.updateChips(-previousBet)
        gameState.userPlacedCurrentBet = true
        
        // Clear win/lose notification when redo bet is used (both training and regular mode)
        if gameState.resultMessage != nil {
            print("🎯 Clearing result notification when redo bet is used (both modes)")
            gameState.showResultNotification = false
            gameState.resultMessage = nil
        }
        
        // Trigger card collection animation when user clicks Redo Bet (both modes)
        if !gameState.dealtPlayerCards.isEmpty {
            print("🎯 Starting card collection animation when redo bet is used")
            print("🎯 Betting state before animation: playerBet=\(gameState.playerBet), betChips=\(gameState.betChips)")
            print("🎯 Betting state before animation: resultMessage=\(String(describing: gameState.resultMessage)), showResultNotification=\(gameState.showResultNotification)")
            animateCardsBackToDeck(gameState: gameState)
        }
    }
    
    func canPlaceBet(gameState: BlackjackGameState, chipValue: Int) -> Bool {
        // Only block while actively dealing
        if gameState.isDealing {
            print("🎰 canPlaceBet: Blocked - isDealing=\(gameState.isDealing)")
            return false
        }
        
        // Check if we have enough remaining chips to place this additional bet
        guard chipValue <= XPChipManager.shared.userChips else { 
            print("🎰 canPlaceBet: Insufficient chips - need \(chipValue), have \(XPChipManager.shared.userChips)")
            return false 
        }
        
        // Check if adding this chip would exceed max bet per hand
        let newBet = gameState.playerBet + chipValue
        let canPlace = newBet <= gameState.maxBet
        if !canPlace {
            print("🎰 canPlaceBet: Would exceed max bet - current bet: \(gameState.playerBet), adding: \(chipValue), max: \(gameState.maxBet)")
        } else {
            print("🎰 canPlaceBet: ALLOWED - chipValue=\(chipValue), playerBet=\(gameState.playerBet), newBet=\(newBet), maxBet=\(gameState.maxBet)")
        }
        return canPlace
    }
    
    func canRedoBet(gameState: BlackjackGameState) -> Bool {
        guard let lastBet = gameState.lastBet else { return false }
        return XPChipManager.shared.userChips - gameState.playerBet >= lastBet && !gameState.showNextHand
    }
    
    // MARK: - Chip Optimization for Gameplay
    /// Consolidates chips to a single chip during gameplay to prevent lag
    /// This happens "behind closed doors" - view never sees intermediate states
    /// ALWAYS uses originalLargestChip - this is what user actually placed and wants to see
    static func minimizeChipsForGameplay(gameState: BlackjackGameState) {
        guard let map = gameState.currentMap else { 
            print("⚠️ minimizeChipsForGameplay: No map set")
            return 
        }
        
        let availableChips = Array(map.assetConfig.chipImages.keys).sorted(by: >) // Largest first
        
        // ALWAYS use originalLargestChip - this is the largest chip user actually placed
        // This ensures we show the correct top chip (e.g., 1000 in Europa, 500 in Io Inferno, not 100)
        guard let originalLargest = gameState.originalLargestChip else {
            print("⚠️ ERROR: No originalLargestChip stored! Using fallback.")
            // Fall back to largest chip from current array that exists in map
            // Filter out any chips that don't exist in map's configuration
            let validChips = gameState.betChips.filter { availableChips.contains($0) }
            if let fallback = validChips.max() {
                gameState.betChips = [fallback]
                print("💰 Using fallback chip: $\(fallback) from valid chips: \(validChips)")
            } else if let fallback = availableChips.first {
                gameState.betChips = [fallback]
                print("💰 Using map's largest chip as fallback: $\(fallback)")
            } else {
                print("⚠️ CRITICAL: No chips available in map \(map.name)!")
            }
            return
        }
        
        // Verify the original largest chip exists in current map's configuration
        guard availableChips.contains(originalLargest) else {
            print("⚠️ ERROR: originalLargestChip $\(originalLargest) not in map \(map.name)! Available: \(availableChips)")
            // Fall back to largest available chip from map
            if let fallback = availableChips.first {
                gameState.betChips = [fallback]
                print("💰 Using map's largest chip as fallback: $\(fallback)")
            }
            return
        }
        
        // IMMEDIATELY replace with ONLY the original largest chip
        // CRITICAL: This is a direct assignment - no intermediate steps, no consolidation
        // The view will see ONLY this chip, never any intermediate states
        gameState.betChips = [originalLargest]
        print("💰 Minimized betChips for gameplay: Keeping ONLY originalLargestChip $\(originalLargest), removed all others (bet total: $\(gameState.playerBet))")
        
        // Consolidate additionalBetChips to single chip - use the largest chip from the original
        if !gameState.additionalBetChips.isEmpty {
            let largestChip = gameState.additionalBetChips.max() ?? gameState.additionalBetChips.first!
            gameState.additionalBetChips = [largestChip]
            print("💰 Minimized additionalBetChips for gameplay: 1 chip of $\(largestChip)")
        }
        
        // Consolidate doubleDownChipsHand1 to single chip - use the largest chip from the original
        if !gameState.doubleDownChipsHand1.isEmpty {
            let largestChip = gameState.doubleDownChipsHand1.max() ?? gameState.doubleDownChipsHand1.first!
            gameState.doubleDownChipsHand1 = [largestChip]
            print("💰 Minimized doubleDownChipsHand1 for gameplay: 1 chip of $\(largestChip)")
        }
        
        // Consolidate doubleDownChipsHand2 to single chip - use the largest chip from the original
        if !gameState.doubleDownChipsHand2.isEmpty {
            let largestChip = gameState.doubleDownChipsHand2.max() ?? gameState.doubleDownChipsHand2.first!
            gameState.doubleDownChipsHand2 = [largestChip]
            print("💰 Minimized doubleDownChipsHand2 for gameplay: 1 chip of $\(largestChip)")
        }
        
        // No transition animation needed - chips are minimized immediately
        // The view will switch directly from stacked to single chip
    }
    
    // MARK: - Chip Optimization
    /// Optimizes chips to use the largest denominations possible to prevent lag with large bets
    /// This rebuilds the chip array from the total bet amount using the largest available chips
    /// Always preserves the full bet amount - never loses money
    /// IMPORTANT: Only consolidates UP, never breaks down chips that user actually placed
    private func optimizeChipsForDisplay(gameState: BlackjackGameState) {
        guard let map = gameState.currentMap else { return }
        
        let availableChips = Array(map.assetConfig.chipImages.keys).sorted(by: >) // Largest first
        let currentTotal = gameState.betChips.reduce(0, +)
        
        // If total is 0 or we have no chips, nothing to optimize
        guard currentTotal > 0, !availableChips.isEmpty else { return }
        
        // Only optimize if we have more than 8 chips (prevents unnecessary work for small bets)
        guard gameState.betChips.count > 8 else { return }
        
        // CRITICAL: Don't optimize if we have the original largest chip - preserve what user placed
        // This prevents breaking down chips into smaller denominations (like Ganymede Grand behavior)
        if let originalLargest = gameState.originalLargestChip {
            // If user placed chips with this denomination, preserve them completely
            if gameState.betChips.contains(originalLargest) {
                print("💰 Skipping optimization - preserving originalLargestChip $\(originalLargest)")
                return
            }
            // Also skip if originalLargest is > 100 (user placed large chips, don't touch them)
            if originalLargest > 100 {
                print("💰 Skipping optimization - user placed large chips ($\(originalLargest)), preserving them")
                return
            }
        }
        
        // Rebuild chips using largest denominations possible
        // Always use the largest chips first to minimize the total number of chip views
        var remaining = currentTotal
        var optimizedChips: [Int] = []
        
        for chip in availableChips {
            let count = remaining / chip
            if count > 0 {
                optimizedChips.append(contentsOf: Array(repeating: chip, count: count))
                remaining -= chip * count
            }
        }
        
        // If there's any remaining (shouldn't happen with proper chip denominations, but handle it)
        if remaining > 0 {
            // Use smallest available chip to cover remainder
            if let smallestChip = availableChips.last {
                optimizedChips.append(smallestChip)
                remaining -= smallestChip
                print("⚠️ Optimization: Added extra chip to cover remainder")
            }
        }
        
        // Verify we preserved the total
        let optimizedTotal = optimizedChips.reduce(0, +)
        guard optimizedTotal == currentTotal else {
            print("⚠️ Optimization failed: Total mismatch (\(optimizedTotal) vs \(currentTotal))")
            return
        }
        
        // Only update if we've optimized (fewer chips or better denominations)
        let originalCount = gameState.betChips.count
        if optimizedChips.count < originalCount {
            gameState.betChips = optimizedChips.sorted(by: >)
            print("💰 Optimized chips: \(optimizedChips.count) chips (was \(originalCount)) - Total: $\(currentTotal)")
        } else if optimizedChips.count == originalCount && optimizedChips.sorted(by: >) != gameState.betChips.sorted(by: >) {
            // Same count but better denominations (more large chips)
            gameState.betChips = optimizedChips.sorted(by: >)
            print("💰 Optimized chip denominations - Total: $\(currentTotal)")
        }
    }
    
    // MARK: - Chip Consolidation
    private func consolidateChips(gameState: BlackjackGameState) {
        // CRITICAL: Don't consolidate if user placed large chips (>= 100) - preserve what they placed
        // This prevents creating 100 chips that would show briefly during transition
        // This is why Ganymede Grand works (all chips >= 100, no consolidation)
        if let originalLargest = gameState.originalLargestChip, originalLargest >= 100 {
            print("💰 Skipping consolidation - user placed large chips ($\(originalLargest)), preserving them")
            return
        }
        
        // Also skip if current chips contain any chip >= 100
        // This prevents consolidation from creating 100 chips in Europa/Io Inferno
        if gameState.betChips.contains(where: { $0 >= 100 }) {
            print("💰 Skipping consolidation - chips contain values >= 100, preserving them")
            return
        }
        
        // Also skip if ANY chip in array is >= 100 (double check)
        let maxChip = gameState.betChips.max() ?? 0
        if maxChip >= 100 {
            print("💰 Skipping consolidation - max chip is $\(maxChip) >= 100, preserving them")
            return
        }
        
        // Get available chip denominations from map's configuration
        guard let map = gameState.currentMap else {
            // No map set, use default consolidation
            consolidateChipsDefault(gameState: gameState)
            return
        }
        
        // Ensure we have valid chip configuration for this map
        guard !map.assetConfig.chipImages.isEmpty else {
            print("⚠️ Map \(map.name) has no chip configuration - skipping consolidation")
            return
        }
        
        let availableChips = Array(map.assetConfig.chipImages.keys).sorted(by: >) // Sort descending
        print("💰 Consolidating chips for map \(map.name) with available denominations: \(availableChips)")
        consolidateChipsWithDenominations(gameState: gameState, availableChips: availableChips)
    }
    
    // Default consolidation for Luna Luxe Casino (1, 5, 25, 50, 100)
    private func consolidateChipsDefault(gameState: BlackjackGameState) {
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
    
    // Dynamic consolidation based on available chip denominations
    /// IMPORTANT: Only consolidates UP (smaller → larger), never breaks down chips user placed
    private func consolidateChipsWithDenominations(gameState: BlackjackGameState, availableChips: [Int]) {
        let availableChipsSet = Set(availableChips)
        var chipCounts: [Int: Int] = [:]
        
        // Count each chip denomination - ONLY count chips that exist in the map's configuration
        for chip in gameState.betChips {
            // Only process chips that are valid for this map
            if availableChipsSet.contains(chip) {
                chipCounts[chip, default: 0] += 1
            }
        }
        
        // If no valid chips to consolidate, return early
        guard !chipCounts.isEmpty else {
            // If all chips were invalid, clear betChips
            if !gameState.betChips.isEmpty {
                gameState.betChips = []
                print("💰 All chips were invalid for this map - cleared betChips")
            }
            return
        }
        
        // CRITICAL: Don't consolidate if we have the original largest chip - preserve what user placed
        // This prevents breaking down chips into smaller denominations (like Ganymede Grand behavior)
        // Also skip if ANY chips are >= 100 to prevent creating 100 chips that show briefly
        if let originalLargest = gameState.originalLargestChip {
            // Skip if originalLargest is >= 100 (user placed large chips, don't touch them)
            // This prevents creating 100 chips that would show briefly (Europa Ice Palace issue)
            if originalLargest >= 100 {
                print("💰 Skipping consolidation - user placed large chips ($\(originalLargest)), preserving them")
                return
            }
            // If user placed chips with this denomination, preserve them completely
            if chipCounts[originalLargest] != nil {
                print("💰 Skipping consolidation - preserving originalLargestChip $\(originalLargest)")
                return
            }
        }
        
        // Also skip if current chips contain any chip >= 100
        // This prevents consolidation from creating 100 chips
        if gameState.betChips.contains(where: { $0 >= 100 }) {
            print("💰 Skipping consolidation - chips contain values >= 100, preserving them")
            return
        }
        
        // Also skip if max chip in array is >= 100 (triple check)
        let maxChipInArray = gameState.betChips.max() ?? 0
        if maxChipInArray >= 100 {
            print("💰 Skipping consolidation - max chip in array is $\(maxChipInArray) >= 100, preserving them")
            return
        }
        
        var needsConsolidation = false
        var newChips: [Int] = []
        
        // Process chips from smallest to largest (ascending order)
        let sortedChips = availableChips.sorted() // Sort ascending
        
        // For each chip denomination, try to consolidate into the next higher denomination
        // ONLY consolidate UP, never break down
        for i in 0..<sortedChips.count - 1 {
            let currentChip = sortedChips[i]
            let nextChip = sortedChips[i + 1]
            
            // Only process if we have chips of this denomination
            guard let count = chipCounts[currentChip], count > 0 else { continue }
            
            // Calculate how many of current chip = 1 of next chip
            let ratio = nextChip / currentChip
            
            if count >= ratio {
                let consolidatedCount = count / ratio
                let remaining = count % ratio
                
                // Only consolidate if the next chip is available in the map's configuration
                if availableChipsSet.contains(nextChip) {
                    newChips.append(contentsOf: Array(repeating: nextChip, count: consolidatedCount))
                    if remaining > 0 {
                        newChips.append(contentsOf: Array(repeating: currentChip, count: remaining))
                    }
                    chipCounts.removeValue(forKey: currentChip)
                    needsConsolidation = true
                    print("💰 Consolidated \(consolidatedCount * ratio) x $\(currentChip) → \(consolidatedCount) x $\(nextChip)")
                } else {
                    // Next chip not available, keep current chips as-is
                    newChips.append(contentsOf: Array(repeating: currentChip, count: count))
                    chipCounts.removeValue(forKey: currentChip)
                }
            } else {
                // Not enough to consolidate, keep as is
                newChips.append(contentsOf: Array(repeating: currentChip, count: count))
                chipCounts.removeValue(forKey: currentChip)
            }
        }
        
        // Add remaining chips that weren't consolidated (these are the largest denominations)
        for (chip, count) in chipCounts {
            // Double-check that chip is valid before adding
            if availableChipsSet.contains(chip) {
                newChips.append(contentsOf: Array(repeating: chip, count: count))
            }
        }
        
        // Final safety check: only keep chips that exist in the map's configuration
        // This ensures we never create chips with values that don't exist
        newChips = newChips.filter { availableChipsSet.contains($0) }
        
        // Only update betChips if consolidation actually occurred AND the result is different
        // This prevents unnecessary updates that could trigger view refreshes
        let sortedNewChips = newChips.sorted(by: >)
        if needsConsolidation && sortedNewChips != gameState.betChips {
            gameState.betChips = sortedNewChips
            print("💰 Chips after consolidation: \(gameState.betChips)")
        } else if !needsConsolidation && sortedNewChips != gameState.betChips {
            // No consolidation occurred but chips are different - this shouldn't happen, but log it
            print("⚠️ Consolidation didn't occur but chips changed - this may indicate a bug")
        }
    }
    
    // Filter out chips that don't exist in the current map's configuration
    private func filterInvalidChips(gameState: BlackjackGameState) {
        guard let map = gameState.currentMap else { return }
        BlackjackBettingManager.filterInvalidChipsForMap(gameState: gameState, map: map)
    }
    
    // Filter chips for a specific map (can be called externally)
    static func filterInvalidChipsForMap(gameState: BlackjackGameState, map: Map) {
        let availableChips = Set(map.assetConfig.chipImages.keys)
        let originalCount = gameState.betChips.count
        let originalBet = gameState.playerBet
        
        // Filter betChips to only include chips that exist in the map's configuration
        // IMPORTANT: Only filter out chips that are truly invalid - never break down valid chips
        let filteredBetChips = gameState.betChips.filter { availableChips.contains($0) }
        
        // Only update if we actually filtered something out
        if filteredBetChips != gameState.betChips {
            gameState.betChips = filteredBetChips
            print("💰 Filtered out invalid chips from betChips: \(gameState.betChips) -> \(filteredBetChips)")
        }
        
        // Also filter additionalBetChips, doubleDownChipsHand1, doubleDownChipsHand2
        let filteredAdditional = gameState.additionalBetChips.filter { availableChips.contains($0) }
        if filteredAdditional != gameState.additionalBetChips {
            gameState.additionalBetChips = filteredAdditional
            print("💰 Filtered out invalid chips from additionalBetChips")
        }
        
        let filteredDD1 = gameState.doubleDownChipsHand1.filter { availableChips.contains($0) }
        if filteredDD1 != gameState.doubleDownChipsHand1 {
            gameState.doubleDownChipsHand1 = filteredDD1
            print("💰 Filtered out invalid chips from doubleDownChipsHand1")
        }
        
        let filteredDD2 = gameState.doubleDownChipsHand2.filter { availableChips.contains($0) }
        if filteredDD2 != gameState.doubleDownChipsHand2 {
            gameState.doubleDownChipsHand2 = filteredDD2
            print("💰 Filtered out invalid chips from doubleDownChipsHand2")
        }
        
        // Recalculate playerBet based on filtered chips
        let filteredBet = gameState.betChips.reduce(0, +) +
                         gameState.additionalBetChips.reduce(0, +) +
                         gameState.doubleDownChipsHand1.reduce(0, +) +
                         gameState.doubleDownChipsHand2.reduce(0, +)
        
        if filteredBet != originalBet {
            print("⚠️ Filtered invalid chips: original bet \(originalBet), filtered bet \(filteredBet)")
            // Only update playerBet if we actually filtered chips - don't modify if chips are valid
            gameState.playerBet = filteredBet
        }
        
        if gameState.betChips.count != originalCount {
            print("💰 Filtered out \(originalCount - gameState.betChips.count) invalid chip(s) not in map configuration")
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
                print("🎯 Betting state after animation: resultMessage=\(String(describing: gameState.resultMessage)), showResultNotification=\(gameState.showResultNotification)")
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
