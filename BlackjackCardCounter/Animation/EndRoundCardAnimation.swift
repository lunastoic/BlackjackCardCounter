import SwiftUI

// MARK: - End Round Card Animation
// Specialized animation for collecting cards back to the deck (top-left) at the end of a round

class EndRoundCardAnimation {
    
    // MARK: - Collect Cards to Deck Animation
    static func collectCardsToDeck(
        playerCards: [Card],
        dealerCards: [Card],
        deckPosition: CGPoint,
        dealtPlayerCards: [Card],
        dealtDealerCards: [Card],
        flippedDealerCards: Set<Int>,
        gameState: BlackjackGameState,
        onComplete: @escaping () -> Void
    ) {
        gameState.isCollectingPhase = true
        gameState.collectingCardIds.removeAll()
        gameState.arrivalOrder.removeAll()
        
        print("🎯 EndRound: Starting SIMULTANEOUS card collection animation")
        print("🎯 EndRound: Player cards: \(playerCards.count), Dealer cards: \(dealerCards.count)")
        
        // NEW: Animate player and dealer cards SIMULTANEOUSLY
        var completionCount = 0
        let totalAnimations = (playerCards.isEmpty ? 0 : 1) + (dealerCards.isEmpty ? 0 : 1)
        
        func checkCompletion() {
            completionCount += 1
            if completionCount >= totalAnimations {
                print("🎯 EndRound: SIMULTANEOUS animation completed for both player and dealer")
                // Final cleanup after both animations complete
                clearCollectedCardsFromUI(gameState: gameState, collectedCards: playerCards + dealerCards)
                onComplete()
            }
        }
        
        if totalAnimations == 0 {
            print("🎯 EndRound: No cards to collect")
            onComplete()
            return
        }
        
        // Start player card animation (if any)
        if !playerCards.isEmpty {
            animateCardStack(
                cards: playerCards,
                deckPosition: deckPosition,
                isPlayer: true,
                gameState: gameState
            ) {
                print("🎯 EndRound: Player card stack animation completed")
                checkCompletion()
            }
        }
        
        // Start dealer card animation SIMULTANEOUSLY (if any)
        if !dealerCards.isEmpty {
            animateCardStack(
                cards: dealerCards,
                deckPosition: deckPosition,
                isPlayer: false,
                gameState: gameState
            ) {
                print("🎯 EndRound: Dealer card stack animation completed")
                checkCompletion()
            }
        }
    }
    
    // MARK: - Animate Card Stack (Simplified)
    private static func animateCardStack(
        cards: [Card],
        deckPosition: CGPoint,
        isPlayer: Bool,
        gameState: BlackjackGameState,
        onComplete: @escaping () -> Void
    ) {
        guard !cards.isEmpty else { onComplete(); return }
        
        print("🎯 EndRound: Animating \(cards.count) \(isPlayer ? "player" : "dealer") cards as a stack")
        
        // Calculate center position for the stack - center under the yellow number
        let centerX: CGFloat = 200 // Center of the screen (400 width / 2)
        
        print("🎯 EndRound: Screen size: 400x800, Center X should be 200")
        
        // Set up all cards at their current positions first and capture the exact Y position
        var exactY: CGFloat = 0
        for (index, card) in cards.enumerated() {
            let id = card.id
            
            // Calculate current position for each card
            let currentX = CardPositioning.xForStaticCard(idx: index, count: cards.count, size: CGSize(width: 400, height: 800), isDealing: false, isPlayer: isPlayer)
            let currentY = CardPositioning.yForHand(isPlayer: isPlayer, size: CGSize(width: 400, height: 800))
            let currentPos = CGPoint(x: currentX, y: currentY)
            
            // Capture the exact Y position from the first card
            if index == 0 {
                exactY = currentY
            }
            
            gameState.animatingCardPositions[id] = currentPos
            print("🎯 EndRound: Card \(index) initial position: \(currentPos)")
            gameState.cardFlipRotations[id] = 180 // All cards face up initially
            gameState.animatingCards[id] = card
            gameState.collectingCardIds.insert(id)
            gameState.arrivalOrder[id] = index
            
            // Remove from UI arrays immediately
            if isPlayer {
                gameState.dealtPlayerCards.removeAll { $0.id == card.id }
            } else {
                gameState.dealtDealerCards.removeAll { $0.id == card.id }
                gameState.visuallyRevealedDealerHand.removeAll { $0.id == card.id }
            }
        }
        
        // Update stack center with the exact Y position from the cards
        // Account for training mode offset (27 points down) by subtracting it
        let trainingModeOffset: CGFloat = 27
        let adjustedY = exactY - trainingModeOffset
        let stackCenter = CGPoint(x: centerX, y: adjustedY)
        print("🎯 EndRound: Stack center position for \(isPlayer ? "player" : "dealer"): \(stackCenter)")
        print("🎯 EndRound: Training mode offset compensated: -\(trainingModeOffset) points")
        
        // Clear hand arrays
        if isPlayer {
            gameState.playerHand.removeAll()
            gameState.splitHands.removeAll()
            gameState.isSplit = false
            gameState.activeHandIndex = 0
        } else {
            gameState.dealerHand.removeAll()
            gameState.flippedDealerCards.removeAll()
            gameState.countingRevealedDealerCards.removeAll()
        }
        
        // First: Center all cards together (stack them) while keeping card values visible
        print("🎯 EndRound: Centering \(cards.count) cards to stack at: \(stackCenter)")
        
        // Phase 1: Center all cards instantly (no animation) to create a stack
        for card in cards {
            let id = card.id
            // Set all cards to the same center position instantly
            gameState.animatingCardPositions[id] = stackCenter
            // Keep cards face up (showing their values) during centering
            gameState.cardFlipRotations[id] = 180
        }
        
        // Phase 2: After a brief moment, animate the entire stack to the deck
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            for card in cards {
                let id = card.id
                // Animate the entire stack to the deck
                withAnimation(CardMetrics.collectTravelAnim) {
                    gameState.animatingCardPositions[id] = deckPosition
                }
                
                // Flip to deck cover during travel to the deck
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(CardMetrics.flipAnim) {
                        gameState.cardFlipRotations[id] = 0 // Flip to deck cover
                    }
                }
            }
            
            // Complete after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Ensure isCollectingPhase is reset when animation completes
                gameState.isCollectingPhase = false
                print("🎯 EndRound: Animation completed, isCollectingPhase set to false")
                onComplete()
            }
        }
    }
    
    // MARK: - Collect Single Group of Cards (Old - Keep for reference)
    private static func collectCardGroup(
        cards: [Card],
        deckPosition: CGPoint,
        dealtPlayerCards: [Card],
        dealtDealerCards: [Card],
        flippedDealerCards: Set<Int>,
        gameState: BlackjackGameState,
        clearUI: Bool,
        onComplete: @escaping () -> Void
    ) {
        guard !cards.isEmpty else { onComplete(); return }
        
        gameState.isCollectingPhase = true
        gameState.collectingCardIds.removeAll()
        gameState.arrivalOrder.removeAll()
        
        // Only clear hand arrays if this is the first group (player cards)
        // This prevents dealer cards from showing DeckCover prematurely in UI
        if dealtPlayerCards.contains(cards.first ?? Card(suit: .hearts, rank: .ace)) {
            gameState.playerHand.removeAll()
            gameState.splitHands.removeAll()
            gameState.isSplit = false
            gameState.activeHandIndex = 0
            print("🎯 EndRound: Cleared player hand arrays for player card collection")
        }
        // Don't clear dealer hand arrays here - let them show actual card values until animation starts
        
        // Prevent layout shifts during collection
        print("🎯 EndRound: Starting card collection animation for \(cards.count) cards")
        
        func startCollect(at index: Int) {
            if index >= cards.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    // Only clear UI if this is the final group
                    if clearUI {
                        clearCollectedCardsFromUI(gameState: gameState, collectedCards: cards)
                    }
                    
                    // Clear all animation state
                    gameState.animatingCards.removeAll()
                    gameState.animatingCardPositions.removeAll()
                    gameState.cardFlipRotations.removeAll()
                    gameState.collectingCardIds.removeAll()
                    gameState.arrivalOrder.removeAll()
                    
                    // Keep isCollectingPhase = true for a bit longer to prevent other functions from clearing betting state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        gameState.isCollectingPhase = false
                        print("🎯 EndRound: isCollectingPhase set to false after 0.5 second delay")
                    }
                    
                    onComplete()
                }
                return
            }
            
            let card = cards[index]
            let id = card.id
            
            // Set up card for animation - calculate current positions
            if let pIndex = dealtPlayerCards.firstIndex(of: card) {
                // Player card - calculate current position
                let startPos = CGPoint(
                    x: CardPositioning.xForStaticCard(idx: pIndex, count: dealtPlayerCards.count, size: CGSize(width: 400, height: 800), isDealing: false, isPlayer: true),
                    y: CardPositioning.yForHand(isPlayer: true, size: CGSize(width: 400, height: 800))
                )
                gameState.animatingCardPositions[id] = startPos
                gameState.cardFlipRotations[id] = 180 // Player cards are face up
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { gameState.animatingCards[id] = card }
                
                // Remove player card from UI immediately when animation starts
                gameState.dealtPlayerCards.removeAll { $0.id == card.id }
                print("🎯 EndRound: Player card \(card.rank.rawValue) removed from UI, starting from \(startPos), going to deck at \(deckPosition)")
            } else if let dIndex = dealtDealerCards.firstIndex(of: card) {
                // Dealer card - calculate current position (same as player cards)
                let startPos = CGPoint(
                    x: CardPositioning.xForStaticCard(idx: dIndex, count: dealtDealerCards.count, size: CGSize(width: 400, height: 800), isDealing: false, isPlayer: false),
                    y: CardPositioning.yForHand(isPlayer: false, size: CGSize(width: 400, height: 800))
                )
                gameState.animatingCardPositions[id] = startPos
                gameState.cardFlipRotations[id] = 180 // Dealer cards are face up (same as player cards)
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { gameState.animatingCards[id] = card }
                
                // Remove dealer card from UI immediately when animation starts
                gameState.dealtDealerCards.removeAll { $0.id == card.id }
                gameState.visuallyRevealedDealerHand.removeAll { $0.id == card.id }
                
                // Don't clear dealer hand arrays here - let them show actual card values until final cleanup
                
                print("🎯 EndRound: Dealer card \(card.rank.rawValue) removed from UI, starting from \(startPos), going to deck at \(deckPosition)")
            }
            
            gameState.collectingCardIds.insert(id)
            gameState.arrivalOrder[id] = index
            
            // Animate card to deck position (top-left)
            withAnimation(CardMetrics.collectTravelAnim) {
                gameState.animatingCardPositions[id] = deckPosition
            }
            
            // Both player and dealer cards should flip back to deck cover during travel
            if dealtPlayerCards.contains(card) {
                // Player card - flip back to deck cover during travel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(CardMetrics.flipAnim) {
                        gameState.cardFlipRotations[id] = 0 // Flip back to deck cover
                    }
                }
            } else if dealtDealerCards.contains(card) {
                // Dealer card - also flip back to deck cover during travel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(CardMetrics.flipAnim) {
                        gameState.cardFlipRotations[id] = 0 // Flip back to deck cover
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) { 
                startCollect(at: index + 1) 
            }
        }
        
        startCollect(at: 0)
    }
    
    // MARK: - Clear Cards from UI and Update Tracking
    private static func clearCollectedCardsFromUI(gameState: BlackjackGameState, collectedCards: [Card]) {
        print("🎯 EndRound: Final cleanup for \(collectedCards.count) cards")
        
        // Cards should already be cleared from UI arrays when animation started
        // Just ensure everything is clean
        print("🎯 EndRound: Final check - dealt player cards: \(gameState.dealtPlayerCards.count), dealt dealer cards: \(gameState.dealtDealerCards.count)")
        
        // Clear any remaining cards (should be empty already)
        gameState.dealtPlayerCards.removeAll()
        gameState.dealtDealerCards.removeAll()
        gameState.visuallyRevealedDealerHand.removeAll()
        gameState.animatingCards.removeAll()
        
        // Clear hand arrays in final cleanup
        gameState.playerHand.removeAll()
        gameState.dealerHand.removeAll()
        gameState.splitHands.removeAll()
        gameState.isSplit = false
        gameState.activeHandIndex = 0
        gameState.flippedDealerCards.removeAll()
        gameState.countingRevealedDealerCards.removeAll()
        
        // IMPORTANT: In training mode, preserve the button positioning state
        // by setting a flag that indicates cards were just collected
        let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
        if trainingModeEnabled {
            // Set a flag to maintain button positioning after card collection
            gameState.showNextHand = true // This helps maintain button positioning
            gameState.cardsJustCollected = true // Track that cards were just collected
            gameState.isPlayerTurn = true // Ensure player turn state is maintained
            print("🎯 EndRound: Training mode - preserving button positioning after card collection")
            print("🎯 EndRound: Training mode - showNextHand=\(gameState.showNextHand), cardsJustCollected=\(gameState.cardsJustCollected)")
            
            // Add a small delay to ensure these flags stick and override any other changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                gameState.showNextHand = true
                gameState.cardsJustCollected = true
                gameState.isPlayerTurn = true
                print("🎯 EndRound: Training mode - reinforced button positioning flags after 0.1s delay")
            }
        }
        
        // Update cards dealt count (keep track of total cards dealt)
        gameState.cardsDealt += collectedCards.count
        print("🎯 EndRound: Updated cards dealt count to \(gameState.cardsDealt)")
        
        // Reset game state but preserve betting information
        // Don't set showNextHand = true as it might hide betting options
        // Only set isPlayerTurn if not in training mode (training mode handles this above)
        if !trainingModeEnabled {
            gameState.isPlayerTurn = true
        }
        
        // IMPORTANT: Preserve betting state - don't clear these:
        // - gameState.playerBet (user's bet amount)
        // - gameState.betChips (chips on betting area)
        // - gameState.resultMessage (win/lose message)
        // - gameState.showResultNotification (notification visibility)
        
        // Also preserve other important state that might be cleared elsewhere
        gameState.isProcessingAction = false
        
        // Ensure isCollectingPhase is reset in final cleanup
        gameState.isCollectingPhase = false
        print("🎯 EndRound: Final cleanup completed, isCollectingPhase reset to false")
        print("🎯 EndRound: Betting state after final cleanup: playerBet=\(gameState.playerBet), betChips=\(gameState.betChips)")
    }
}
