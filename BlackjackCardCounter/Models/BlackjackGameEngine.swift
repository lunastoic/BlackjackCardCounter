import SwiftUI

// MARK: - CardDeck Helper
struct CardDeck {
    static func standardDeck() -> [Card] {
        var deck: [Card] = []
        for suit in CardSuit.allCases {
            for rank in CardRank.allCases {
                deck.append(Card(suit: suit, rank: rank, isFaceUp: true))
            }
        }
        return deck
    }
}

// MARK: - Game Logic Engine
class BlackjackGameEngine: ObservableObject {
    static let shared = BlackjackGameEngine()
    
    // Animation callbacks (wired from RegularModeView)
    var hitAnimationCallback: ((Card, Bool, @escaping () -> Void) -> Void)?
    var splitAnimationCallback: ((Card, Int, @escaping () -> Void) -> Void)?
    
    private init() {}

    // MARK: - Debug helpers
    private enum CardRecipient {
        case player
        case dealer
    }
    
    private var debugEightCardQueue: [CardRank] = []
    private var debugEightCardSuitIndex: Int = 0
    
    private func isEightCardDebugEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: "debugEightCardUser")
    }
    
    private func nextEightCardRank() -> CardRank {
        if debugEightCardQueue.isEmpty {
            // Fixed 8-card debug pattern: 2,2,2,2,3,A,2,6
            debugEightCardQueue = [.two, .two, .two, .two, .three, .ace, .two, .six]
        }
        return debugEightCardQueue.removeFirst()
    }
    
    private func nextEightCardSuit() -> CardSuit {
        let suits = CardSuit.allCases
        let suit = suits[debugEightCardSuitIndex % suits.count]
        debugEightCardSuitIndex = (debugEightCardSuitIndex + 1) % suits.count
        return suit
    }
    
    /// When "8 cards for player and dealer" debug mode is enabled, always return a generated
    /// low-value card (four 2s then four 3s, repeating) for both player and dealer.
    /// Cards are synthesized so we can reuse values without depleting the deck or
    /// falling back to higher ranks.
    private func drawCard(for recipient: CardRecipient, deck: inout [Card]) -> Card {
        if isEightCardDebugEnabled() {
            let targetRank = nextEightCardRank()
            let generatedCard = Card(suit: nextEightCardSuit(), rank: targetRank, isFaceUp: true)
            return generatedCard
        }
        
        guard !deck.isEmpty else {
            // Fallback for unexpected empty deck states during debug testing
            return Card(suit: .spades, rank: .two, isFaceUp: true)
        }
        
        return deck.removeFirst()
    }
    
    // MARK: - Hand Value Calculations
    func handValue(_ hand: [Card]) -> Int {
        var total = 0
        var aces = 0
        for card in hand {
            if card.rank == .ace { aces += 1 } else { total += card.rank.value }
        }
        total += aces
        var value = total
        for _ in 0..<aces {
            if value + 10 <= 21 { value += 10 }
        }
        return value
    }
    
    func isBust(_ hand: [Card]) -> Bool { handValue(hand) > 21 }
    
    func isBlackjack(_ hand: [Card]) -> Bool {
        return hand.count == 2 && handValue(hand) == 21
    }
    
    // Check if current active split hand should auto-advance (21 or blackjack)
    private func checkSplitHandAutoAdvance(gameState: BlackjackGameState) {
        guard gameState.isSplit else { return }
        
        let activeHand = gameState.splitHands[gameState.activeHandIndex]
        let activeValue = handValue(activeHand)
        
        print("🃏 checkSplitHandAutoAdvance: Hand \(gameState.activeHandIndex == 1 ? 1 : 2) value=\(activeValue), processing=\(gameState.isProcessingAction)")
        
        // Auto-advance if active hand has 21 (blackjack or regular 21)
        if activeValue == 21 {
            let handNumber = gameState.activeHandIndex == 1 ? 1 : 2
            print("🃏 Split hand \(handNumber) (index \(gameState.activeHandIndex)) has 21 - auto-advancing")
            
            // Clear processing flag to allow auto-advance
            gameState.isProcessingAction = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🃏 Auto-advance executing for hand \(handNumber)")
                
                // Ensure we're not stuck in processing state
                gameState.isProcessingAction = false
                
                if gameState.activeHandIndex == 0 {
                    // Hand 2 (left, last hand) - go to dealer
                    print("🃏 Last hand complete, starting dealer turn")
                    self.dealerTurn(gameState: gameState)
                } else {
                    // Hand 1 (right) - go to Hand 2
                    print("🃏 Moving from Hand 1 to Hand 2")
                    gameState.activeHandIndex = 0
                    
                    // Check if Hand 2 also has 21 and should auto-advance to dealer
                    let hand2Value = self.handValue(gameState.splitHands[0])
                    if hand2Value == 21 {
                        print("🃏 Hand 2 also has 21 - going directly to dealer")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.dealerTurn(gameState: gameState)
                        }
                    } else {
                        // Hand 2 doesn't have 21, check for auto-advance normally
                        self.checkSplitHandAutoAdvance(gameState: gameState)
                    }
                }
            }
        }
    }
    
    func isSoftHand(_ hand: [Card]) -> Bool {
        var total = 0
        var aces = 0
        for card in hand {
            if card.rank == .ace { aces += 1 } else { total += card.rank.value }
        }
        total += aces
        for _ in 0..<aces {
            if total + 10 <= 21 { return true }
        }
        return false
    }
    
    func getHandValueText(_ hand: [Card]) -> String {
        let value = handValue(hand)
        
        // Only show "21" for natural blackjack (first two cards = 21)
        if hand.count == 2 &&
            ((hand[0].rank == .ace && hand[1].rank.value == 10) ||
                              (hand[1].rank == .ace && hand[0].rank.value == 10)) {
            return "21"
        }
        
        // For all other hands, just show the value
        var total = 0
        var aces = 0
        for card in hand {
            if card.rank == .ace { aces += 1 } else { total += card.rank.value }
        }
        total += aces
        var valueWithAces = total
        var isSoft = false
        for _ in 0..<aces {
            if valueWithAces + 10 <= 21 { valueWithAces += 10; isSoft = true }
        }
        return isSoft ? "Soft \(total)/\(value)" : "\(value)"
    }
    
    // MARK: - Actions
        func hitAction(gameState: BlackjackGameState) {
        // Prevent rapid button tapping with multiple checks
        let now = Date()
        let timeSinceLastAction = now.timeIntervalSince(gameState.lastActionTime)
        
        let hasDrawableCard = gameState.deck.count > 0 || isEightCardDebugEnabled()
        guard hasDrawableCard,
              !gameState.isProcessingAction,
              timeSinceLastAction >= 0.6 else { 
            print("🎯 hitAction: BLOCKED - processing=\(gameState.isProcessingAction), timeSince=\(timeSinceLastAction)")
            return 
        }
        
        gameState.isProcessingAction = true
        gameState.lastActionTime = now
        print("🎯 hitAction: Processing locked at \(now)")

        if gameState.isSplit {
            var deck = gameState.deck
            let newCard = drawCard(for: .player, deck: &deck)
            gameState.deck = deck
            gameState.runningCount += newCard.countValue
            gameState.cardsDealt += 1
            
            // Check for shuffling after dealing card
            checkForShuffling(gameState: gameState)
            
            // Check for bust immediately on split hand (before animation)
            let splitHandBusted = isBust(gameState.splitHands[gameState.activeHandIndex] + [newCard])
            if splitHandBusted {
                print("🎯 Split hand will bust with \(handValue(gameState.splitHands[gameState.activeHandIndex] + [newCard])) - proceeding to next hand")
            }
            
            if let splitCB = splitAnimationCallback {
                splitCB(newCard, gameState.activeHandIndex) {
                    gameState.splitHands[gameState.activeHandIndex].append(newCard)
                    
                    // Unlock after animation completes
                    gameState.isProcessingAction = false
                    print("🎯 hitAction: Split animation processing unlocked")
                    
                    if splitHandBusted {
                        self.nextSplitHandOrDealer(gameState: gameState)
                    } else {
                        // Check if hand has 21 and should auto-advance
                        self.checkSplitHandAutoAdvance(gameState: gameState)
                    }
                }
            } else {
                // Fallback if no animation callback
                gameState.splitHands[gameState.activeHandIndex].append(newCard)
                
                // Add a delay before unlocking to prevent rapid tapping
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    gameState.isProcessingAction = false
                    print("🎯 hitAction: Split fallback processing unlocked")
                }
                
                if splitHandBusted {
                    self.nextSplitHandOrDealer(gameState: gameState)
                } else {
                    // Check if hand has 21 and should auto-advance
                    self.checkSplitHandAutoAdvance(gameState: gameState)
                }
            }
                } else {
            var deck = gameState.deck
            let newCard = drawCard(for: .player, deck: &deck)
            gameState.deck = deck
            gameState.runningCount += newCard.countValue
            gameState.cardsDealt += 1
            
            // Check for shuffling after dealing card
            checkForShuffling(gameState: gameState)

            if let cb = hitAnimationCallback {
                cb(newCard, true) { 
                    // Add card to dealt cards immediately for visual display
                    gameState.dealtPlayerCards.append(newCard)
                    
                    // Delay adding to playerHand to match dealer flip timing (0.1 seconds after flip)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Add card to player hand AFTER flip animation completes
                        gameState.playerHand.append(newCard)
                        
                        // Check for bust after card is added to hand
                        let playerBusted = self.isBust(gameState.playerHand)
                        if playerBusted {
                            print("🎯 Player busted with \(self.handValue(gameState.playerHand)) - hiding buttons")
                            gameState.isPlayerTurn = false // This will hide the action buttons immediately
                            
                            // Reveal dealer card and end turn if busted
                            self.revealDealerCard(gameState: gameState) {
                                self.endPlayerTurn(gameState: gameState, playerBusted: true)
                            }
                        }
                    }
                    
                    // Unlock after animation completes
                    gameState.isProcessingAction = false
                    print("🎯 hitAction: Animation processing unlocked")
                }
            } else {
                // Fallback: add card immediately if no animation callback
                gameState.playerHand.append(newCard)
                
                // Check for bust immediately to hide action buttons
                let playerBusted = self.isBust(gameState.playerHand)
                if playerBusted {
                    print("🎯 Player busted with \(self.handValue(gameState.playerHand)) - hiding buttons")
                    gameState.isPlayerTurn = false // This will hide the action buttons immediately
                }
                
                withAnimation(.easeOut(duration: 0.3)) {
                    gameState.dealtPlayerCards.append(newCard)
                }
                // Unlock after animation delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    gameState.isProcessingAction = false
                    print("🎯 hitAction: Fallback processing unlocked")
                }
                
                if playerBusted {
                    self.revealDealerCard(gameState: gameState) {
                        self.endPlayerTurn(gameState: gameState, playerBusted: true)
                    }
                }
            }
        }
    }
    
    func standAction(gameState: BlackjackGameState) {
        if gameState.isSplit { nextSplitHandOrDealer(gameState: gameState) }
        else { dealerTurn(gameState: gameState) }
    }
    
    func doubleDownAction(gameState: BlackjackGameState) {
        if gameState.isSplit {
            doubleDownSplitAction(gameState: gameState)
        } else {
            doubleDownRegularAction(gameState: gameState)
        }
    }
    
    private func doubleDownRegularAction(gameState: BlackjackGameState) {
        // Prevent rapid button tapping
        let now = Date()
        let timeSinceLastAction = now.timeIntervalSince(gameState.lastActionTime)
        
        guard !gameState.isProcessingAction,
              timeSinceLastAction >= 0.6 else { 
            print("🎲 Double Down Regular: BLOCKED - processing=\(gameState.isProcessingAction), timeSince=\(timeSinceLastAction)")
            return 
        }
        
        gameState.isProcessingAction = true
        gameState.lastActionTime = now
        print("🎲 Double Down Regular: Processing locked at \(now)")
        
        // Check max bet: after doubling, total bet should be <= 2x max bet
        // Since we're doubling, current bet must be <= max bet
        let wouldExceedMaxBet = gameState.playerBet > gameState.maxBet
        if wouldExceedMaxBet {
            print("🎲 Double Down Regular: BLOCKED - current bet \(gameState.playerBet) exceeds max bet \(gameState.maxBet)")
            gameState.isProcessingAction = false
            return
        }
        
        let hasDrawableCard = gameState.deck.count > 0 || isEightCardDebugEnabled()
        
        if hasDrawableCard,
           gameState.playerHand.count == 2,
           gameState.playerBet <= XPChipManager.shared.userChips {
            
            XPChipManager.shared.updateChips(-gameState.playerBet)
            
            // ADD VISUAL CHIPS: Create separate right-side stack for double down
            let originalBetChips = gameState.betChips
            gameState.additionalBetChips = originalBetChips // Create right-side stack
            print("🎲 Double Down: Added \(originalBetChips.count) visual chips to RIGHT side. Main chips: \(gameState.betChips.count), Additional chips: \(gameState.additionalBetChips.count)")
            
            gameState.playerBet *= 2
            gameState.doubledDown = true
            
            // End player's turn immediately - no more actions allowed after double down
            gameState.isPlayerTurn = false
            print("🎲 Double Down executed - player turn ended, buttons hidden")
            
            // Ensure deck position is set for animation
            if gameState.deckPosition == .zero {
                print("🎲 Double Down Regular: WARNING - deck position is zero, setting default")
                gameState.deckPosition = CGPoint(x: UIScreen.main.bounds.width * 0.85, y: UIScreen.main.bounds.height * 0.15)
            }
            
            var deck = gameState.deck
            let newCard = drawCard(for: .player, deck: &deck)
            gameState.deck = deck
            gameState.playerHand.append(newCard)
            gameState.runningCount += newCard.countValue
            
            // Check for shuffling after dealing card
            checkForShuffling(gameState: gameState)
            
            print("🎲 Double Down Regular: Card dealt: \(newCard.rank.rawValue)\(newCard.suit.rawValue), deckPosition: \(gameState.deckPosition)")
            
            if let cb = hitAnimationCallback {
                cb(newCard, true) {
                    gameState.dealtPlayerCards.append(newCard)
                    // Unlock processing after animation completes
                    gameState.isProcessingAction = false
                    print("🎲 Double Down Regular: Animation processing unlocked")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if self.isBust(gameState.playerHand) {
                            self.revealDealerCard(gameState: gameState) {
                                self.endPlayerTurn(gameState: gameState, playerBusted: true)
                            }
                        } else {
                            self.dealerTurn(gameState: gameState)
                        }
                    }
                }
            } else {
                // Fallback if no animation callback - just append the card
                gameState.dealtPlayerCards.append(newCard)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Unlock processing after fallback completes
                    gameState.isProcessingAction = false
                    print("🎲 Double Down Regular: Fallback processing unlocked")
                    
                    if self.isBust(gameState.playerHand) {
                        self.revealDealerCard(gameState: gameState) {
                            self.endPlayerTurn(gameState: gameState, playerBusted: true)
                        }
                    } else {
                        self.dealerTurn(gameState: gameState)
                    }
                }
            }
        }
    }
    
    private func doubleDownSplitAction(gameState: BlackjackGameState) {
        // Prevent rapid button tapping
        let now = Date()
        let timeSinceLastAction = now.timeIntervalSince(gameState.lastActionTime)
        
        guard !gameState.isProcessingAction,
              timeSinceLastAction >= 0.6 else { 
            print("🎲 Double Down Split: BLOCKED - processing=\(gameState.isProcessingAction), timeSince=\(timeSinceLastAction)")
            return 
        }
        
        gameState.isProcessingAction = true
        gameState.lastActionTime = now
        print("🎲 Double Down Split: Processing locked at \(now)")
        
        print("🎲 Double Down Split: Checking conditions - deck.count=\(gameState.deck.count), activeHandIndex=\(gameState.activeHandIndex), splitHands.count=\(gameState.splitHands.count)")
        if gameState.activeHandIndex < gameState.splitHands.count {
            print("🎲 Double Down Split: Active hand cards count=\(gameState.splitHands[gameState.activeHandIndex].count)")
        }
        
        let hasDrawableCard = gameState.deck.count > 0 || isEightCardDebugEnabled()
        
        guard hasDrawableCard,
              gameState.activeHandIndex < gameState.splitHands.count,
              gameState.splitHands[gameState.activeHandIndex].count == 2 else {
            print("🎲 Double Down Split: Invalid conditions - deck.count=\(gameState.deck.count), activeHandIndex=\(gameState.activeHandIndex), splitHands.count=\(gameState.splitHands.count)")
            if gameState.activeHandIndex < gameState.splitHands.count {
                print("🎲 Double Down Split: Active hand cards count=\(gameState.splitHands[gameState.activeHandIndex].count)")
            }
            // Unlock processing even on failure
            gameState.isProcessingAction = false
            // Clean up any animation state that might be stuck
            gameState.animatingCards.removeAll()
            gameState.animatingCardPositions.removeAll()
            gameState.cardFlipRotations.removeAll()
            print("🎲 Double Down Split: Cleaned up animation state on failure")
            return
        }
        
        let activeHandBet = gameState.splitHandBets[gameState.activeHandIndex]
        
        // Check max bet: after doubling this hand, total bet should be <= 4x max bet (if both hands doubled)
        // For a single hand double down, check that this hand's bet <= max bet
        let wouldExceedMaxBet = activeHandBet > gameState.maxBet
        if wouldExceedMaxBet {
            print("🎲 Double Down Split: BLOCKED - hand bet \(activeHandBet) exceeds max bet \(gameState.maxBet)")
            gameState.isProcessingAction = false
            gameState.animatingCards.removeAll()
            gameState.animatingCardPositions.removeAll()
            gameState.cardFlipRotations.removeAll()
            return
        }
        
        guard activeHandBet <= XPChipManager.shared.userChips else {
            print("🎲 Double Down Split: Not enough chips. Need: \(activeHandBet), Have: \(XPChipManager.shared.userChips)")
            // Unlock processing on chip validation failure
            gameState.isProcessingAction = false
            // Clean up any animation state that might be stuck
            gameState.animatingCards.removeAll()
            gameState.animatingCardPositions.removeAll()
            gameState.cardFlipRotations.removeAll()
            print("🎲 Double Down Split: Cleaned up animation state on chip validation failure")
            return
        }
        
        print("🎲 Double Down Split: Hand \(gameState.activeHandIndex + 1), bet: \(activeHandBet)")
        
        // Deduct the additional bet for this hand
        XPChipManager.shared.updateChips(-activeHandBet)
        
        // ADD VISUAL CHIPS: Create double down chip stack for the specific hand
        // After split: betChips = Hand 2 (left), additionalBetChips = Hand 1 (right)
        // When doubling down, we need to add chips to the right of the doubled hand
        if gameState.activeHandIndex == 0 {
            // Doubling down on Hand 2 (left stack) - add chips to the right of betChips
            gameState.doubleDownChipsHand2 = gameState.betChips
            print("🎲 Double Down Split: Created double down stack with \(gameState.betChips.count) chips for Hand 2 (left)")
        } else {
            // Doubling down on Hand 1 (right stack) - add chips to the right of additionalBetChips
            gameState.doubleDownChipsHand1 = gameState.additionalBetChips
            print("🎲 Double Down Split: Created double down stack with \(gameState.additionalBetChips.count) chips for Hand 1 (right)")
        }
        
        // Double the bet for this specific hand
        gameState.splitHandBets[gameState.activeHandIndex] *= 2
        
        // Track which hand was doubled down
        gameState.doubledDownHandIndex = gameState.activeHandIndex
        
        // Update total player bet
        gameState.playerBet = gameState.splitHandBets.reduce(0, +)
        
        print("🎲 Double Down Split: Hand \(gameState.activeHandIndex + 1) bet now: \(gameState.splitHandBets[gameState.activeHandIndex]), total bet: \(gameState.playerBet)")
        
        // Ensure deck position is set for animation
        if gameState.deckPosition == .zero {
            print("🎲 Double Down Split: WARNING - deck position is zero, setting default")
            gameState.deckPosition = CGPoint(x: UIScreen.main.bounds.width * 0.85, y: UIScreen.main.bounds.height * 0.15)
        }
        
        // Deal one card to the active hand
        var deck = gameState.deck
        let newCard = drawCard(for: .player, deck: &deck)
        gameState.deck = deck
        gameState.runningCount += newCard.countValue
        gameState.cardsDealt += 1
        
        // Check for shuffling after dealing card
        checkForShuffling(gameState: gameState)
        
        print("🎲 Double Down Split: Card dealt: \(newCard.rank.rawValue)\(newCard.suit.rawValue), deckPosition: \(gameState.deckPosition)")
        
        // Use split animation callback for proper animation
        if let splitCB = splitAnimationCallback {
            print("🎲 Double Down Split: Using split animation callback")
            
            // Add timeout protection using Timer
            var timeoutTimer: Timer?
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                print("🎲 Double Down Split: Animation timeout - forcing completion")
                gameState.isProcessingAction = false
                gameState.animatingCards.removeAll()
                gameState.animatingCardPositions.removeAll()
                gameState.cardFlipRotations.removeAll()
            }
            
            splitCB(newCard, gameState.activeHandIndex) {
                // Cancel timeout since animation completed
                timeoutTimer?.invalidate()
                timeoutTimer = nil
                
                // Add card to the split hand after animation completes
                gameState.splitHands[gameState.activeHandIndex].append(newCard)
                
                // Unlock processing after animation completes
                gameState.isProcessingAction = false
                print("🎲 Double Down Split: Animation processing unlocked")
                
                // Check if this hand busts
                let handBusted = self.isBust(gameState.splitHands[gameState.activeHandIndex])
                
                if handBusted {
                    print("🎲 Double Down Split: Hand \(gameState.activeHandIndex + 1) busted")
                    // Move to next hand or dealer
                    self.nextSplitHandOrDealer(gameState: gameState)
                } else {
                    print("🎲 Double Down Split: Hand \(gameState.activeHandIndex + 1) completed")
                    // Move to next hand or dealer
                    self.nextSplitHandOrDealer(gameState: gameState)
                }
            }
        } else {
            // Fallback if no animation callback - use simple animation
            print("🎲 Double Down Split: Using fallback animation")
            
            // Add card immediately for fallback
            gameState.splitHands[gameState.activeHandIndex].append(newCard)
            
            let handBusted = self.isBust(gameState.splitHands[gameState.activeHandIndex])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Unlock processing after fallback completes
                gameState.isProcessingAction = false
                print("🎲 Double Down Split: Fallback processing unlocked")
                
                if handBusted {
                    print("🎲 Double Down Split: Hand \(gameState.activeHandIndex + 1) busted")
                    self.nextSplitHandOrDealer(gameState: gameState)
                } else {
                    print("🎲 Double Down Split: Hand \(gameState.activeHandIndex + 1) completed")
                    self.nextSplitHandOrDealer(gameState: gameState)
                }
            }
        }
    }
    
    func splitAction(gameState: BlackjackGameState) {
        print("🃏 🟡 splitAction called: playerBet=\(gameState.playerBet), userChips=\(XPChipManager.shared.userChips)")
        // If a previous round's lose animation left chips hidden, unhide before splitting.
        gameState.hideBetChipsDuringLoseAnimation = false
        
        let hasEnoughChips = gameState.playerBet <= XPChipManager.shared.userChips
        let hasValidCards = gameState.canSplitCards(card1: gameState.playerHand[0], card2: gameState.playerHand[1])
        
        // Check max bet: after splitting, total bet will be 2x current bet, which should be <= 2x max bet
        // So current bet must be <= max bet
        let wouldExceedMaxBet = gameState.playerBet > gameState.maxBet
        if wouldExceedMaxBet {
            print("🃏 Split: BLOCKED - current bet \(gameState.playerBet) exceeds max bet \(gameState.maxBet)")
            return
        }
        
        print("🃏 🟡 splitAction CHIP CHECK: need \(gameState.playerBet), have \(XPChipManager.shared.userChips), RESULT: \(hasEnoughChips ? "PASS" : "FAIL")")
        print("🃏 🟡 splitAction validation: handCount=\(gameState.playerHand.count), hasEnough=\(hasEnoughChips), validCards=\(hasValidCards)")
        
        guard gameState.playerHand.count == 2,
              hasEnoughChips,
              hasValidCards
        else { 
            print("🃏 🟡 splitAction BLOCKED - guard failed")
            return 
        }

        print("🃏 splitAction proceeding - deducting \(gameState.playerBet) chips")
        // Take the second bet
        XPChipManager.shared.updateChips(-gameState.playerBet)
        
        // ADD VISUAL CHIPS: Create separate right-side stack for split
        let originalBetChips = gameState.betChips
        gameState.additionalBetChips = originalBetChips // Create right-side stack for second hand
        print("🃏 Split: Created RIGHT side stack with \(originalBetChips.count) chips for second hand. Main chips: \(gameState.betChips.count), Additional chips: \(gameState.additionalBetChips.count)")
        
        gameState.isSplit = true
        // Double the total bet amount since we now have two hands with equal bets
        gameState.playerBet *= 2
        print("🃏 Split complete - total bet now: \(gameState.playerBet) (\(gameState.playerBet/2) per hand)")
        
        gameState.splitHands = [[gameState.playerHand[0]], [gameState.playerHand[1]]]
        gameState.splitHandBets = [gameState.playerBet / 2, gameState.playerBet / 2] // Initialize equal bets for each hand
        gameState.activeHandIndex = 1  // Start with right hand (matches dealing order)

        // Deal follow-up cards to RIGHT hand first, then LEFT using the same animation profile
        dealSplitCardsSequentially(gameState: gameState)
    }

    // RIGHT then LEFT, same move+flip timing. Append after animation to enable autolock.
    private func dealSplitCardsSequentially(gameState: BlackjackGameState) {
        let order = [1, 0]  // 1 = right hand, 0 = left hand
        var step = 0

        func dealNext() {
            guard step < order.count else { return }
            let handIndex = order[step]
            let hasDrawableCard = !gameState.deck.isEmpty || isEightCardDebugEnabled()
            guard handIndex < gameState.splitHands.count, hasDrawableCard else { return }

            // Debug: Force specific cards for split hands when debugForcePairs is enabled
            let forcePairs = UserDefaults.standard.bool(forKey: "debugForcePairs")
            let eightCardDebug = isEightCardDebugEnabled()
            var card: Card
            
            if eightCardDebug {
                card = drawCard(for: .player, deck: &gameState.deck)
                print("🎲 Debug: 8 cards for player and dealer enabled - dealt \(card.rank.rawValue) to split hand \(handIndex)")
            } else if forcePairs && handIndex == 0 {
                // Hand 2 (left hand, index 0) - force an Ace for easy 21 testing
                if let aceIndex = gameState.deck.firstIndex(where: { $0.rank == .ace }) {
                    card = gameState.deck.remove(at: aceIndex)
                    print("🎲 Debug: Forced Ace for Hand 2 (left)")
                } else {
                    card = gameState.deck.removeFirst()
                    print("🎲 Debug: No Ace available, using: \(card.rank.rawValue)")
                }
            } else {
                // Normal card dealing or Hand 1
                card = gameState.deck.removeFirst()
                if forcePairs {
                    print("🎲 Debug: Normal card for Hand 1 (right): \(card.rank.rawValue)")
                }
            }
            
            gameState.runningCount += card.countValue
            gameState.cardsDealt += 1  // Add this line to count split cards
            
            // Check for shuffling after dealing card
            checkForShuffling(gameState: gameState)

            if let splitCB = splitAnimationCallback {
                splitCB(card, handIndex) {
                    gameState.splitHands[handIndex].append(card)  // add only after anim completes
                    
                    // Check if the hand that just received a card should auto-advance
                    if gameState.activeHandIndex == handIndex {
                        // Add a small delay to ensure card is fully processed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.checkSplitHandAutoAdvance(gameState: gameState)
                        }
                    }
                    
                    step += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dealNext() }
                }
            } else {
                // Fallback if no UI callback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    gameState.splitHands[handIndex].append(card)
                    
                    // Check if the hand that just received a card should auto-advance
                    if gameState.activeHandIndex == handIndex {
                        // Add a small delay to ensure card is fully processed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.checkSplitHandAutoAdvance(gameState: gameState)
                        }
                    }
                    
                    step += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dealNext() }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dealNext() }
    }
    
    func nextSplitHandOrDealer(gameState: BlackjackGameState) {
        if gameState.activeHandIndex == 1 { 
            gameState.activeHandIndex = 0  // Right → Left (Hand 2)
            // Check if Hand 2 already has blackjack/21 and should auto-advance to dealer
            checkSplitHandAutoAdvance(gameState: gameState)
        } else {
            // Check if both split hands are busted
            let hand1Busted = isBust(gameState.splitHands[1])
            let hand2Busted = isBust(gameState.splitHands[0])
            
            if hand1Busted && hand2Busted {
                print("🃏 Both split hands busted - dealer only reveals face-down card")
                // Both hands busted, dealer only reveals face-down card, no additional hits
                dealerTurnRevealOnly(gameState: gameState)
            } else {
                dealerTurn(gameState: gameState)  // Normal dealer turn with hits
            }
        }
    }
    
    func dealerTurn(gameState: BlackjackGameState) {
        gameState.isPlayerTurn = false
        revealDealerCard(gameState: gameState) {
            self.dealDealerCardsSequentially(gameState: gameState)
        }
    }
    
    func dealerTurnRevealOnly(gameState: BlackjackGameState) {
        gameState.isPlayerTurn = false
        print("🃏 Dealer turn - reveal only (both hands busted)")
        revealDealerCard(gameState: gameState) {
            // After revealing the face-down card, immediately end the turn
            // No additional dealer hits since both player hands are busted
            self.endPlayerTurn(gameState: gameState, playerBusted: true)
        }
    }
    
    func dealDealerCardsSequentially(gameState: BlackjackGameState) {
        var dealer = gameState.dealerHand
        var localDeck = gameState.deck
        var localRunningCount = gameState.runningCount
        var newDealtDealerCards = gameState.dealtDealerCards
        
        let forceEight = isEightCardDebugEnabled()
        
        func dealNextCard() {
            if self.handValue(dealer) < 17, (!localDeck.isEmpty || forceEight) {
                var card: Card
                let forcePairs = UserDefaults.standard.bool(forKey: "debugForcePairs")
                
                if forceEight {
                    card = drawCard(for: .dealer, deck: &localDeck)
                    print("🎲 Debug: 8 cards for player and dealer enabled - dealer draws \(card.rank.rawValue)")
                } else if forcePairs {
                    // When force pairs is enabled, make dealer always bust
                    let currentValue = self.handValue(dealer)
                    print("🎲 Debug: Force Pairs enabled - Dealer current value: \(currentValue)")
                    
                    // Strategy: Always give dealer a 10-value card to maximize chance of bust
                    // If dealer has 12-16, a 10 will bust them
                    // If dealer has less, keep giving 10s until they bust
                    let availableTens = localDeck.enumerated().filter { _, card in
                        card.rank.value == 10
                    }
                    
                    if let (index, _) = availableTens.first {
                        card = localDeck.remove(at: index)
                        print("🎲 Debug: Forced dealer to draw 10-value card: \(card.rank.rawValue) (current: \(currentValue) -> new: \(currentValue + 10))")
                    } else {
                        // No 10s available, find highest card that will bust or get close
                        let targetValue = 22 - currentValue // Minimum card value needed to bust
                        let availableCards = localDeck.enumerated().filter { _, card in
                            let cardValue = card.rank.value
                            return cardValue >= targetValue
                        }
                        
                        if let (index, _) = availableCards.first {
                            card = localDeck.remove(at: index)
                            print("🎲 Debug: Forced dealer to bust with \(card.rank.rawValue) (value: \(card.rank.value))")
                        } else {
                            // Get the highest value card available
                            if let (index, _) = localDeck.enumerated().max(by: { $0.1.rank.value < $1.1.rank.value }) {
                                card = localDeck.remove(at: index)
                                print("🎲 Debug: No bust card available, using highest: \(card.rank.rawValue)")
                            } else {
                                card = localDeck.removeFirst()
                                print("🎲 Debug: Fallback to first card: \(card.rank.rawValue)")
                            }
                        }
                    }
                } else {
                    // Normal card dealing
                    card = localDeck.removeFirst()
                }
                
                dealer.append(card)
                localRunningCount += card.countValue
                gameState.cardsDealt += 1
                
                if let cb = hitAnimationCallback {
                    cb(card, false) {
                        newDealtDealerCards.append(card)
                        gameState.flippedDealerCards.insert(newDealtDealerCards.count - 1)
                        gameState.dealtDealerCards = newDealtDealerCards
                        // Update counting state immediately for additional dealer cards (no flip animation)
                        gameState.countingRevealedDealerCards.insert(newDealtDealerCards.count - 1)
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.4)) {
                        newDealtDealerCards.append(card)
                        gameState.flippedDealerCards.insert(newDealtDealerCards.count - 1)
                    }
                    gameState.dealtDealerCards = newDealtDealerCards
                    // Update counting state immediately for additional dealer cards (no flip animation)
                    gameState.countingRevealedDealerCards.insert(newDealtDealerCards.count - 1)
                }
                
                gameState.visuallyRevealedDealerHand.append(card)
                gameState.dealerHand = dealer
                gameState.runningCount = localRunningCount
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dealNextCard() }
            } else {
                gameState.deck = localDeck
                self.endPlayerTurn(gameState: gameState, playerBusted: false)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dealNextCard() }
    }

    
    func endPlayerTurn(gameState: BlackjackGameState, playerBusted: Bool) {
        gameState.isPlayerTurn = false
        gameState.isProcessingAction = false
        gameState.isProcessingAction = false
        var msg = ""
        var payout = 0
        
        if gameState.isSplit {
            let playerVals = gameState.splitHands.map { self.handValue($0) }
            let dealerVal = self.handValue(gameState.dealerHand)
            var totalWinningAmount = 0
            
            for (i, val) in playerVals.enumerated() {
                let handNumber = i == 1 ? 1 : 2  // Match display logic: index 1 = Hand 1, index 0 = Hand 2
                let hand = gameState.splitHands[i]
                let handBet = gameState.splitHandBets[i] // Use individual hand bet
                
                // Check for 21 on this split hand (not natural blackjack)
                let has21 = val == 21
                
                if val > 21 { 
                    msg += "Hand \(handNumber): Bust!\n"; 
                    payout -= handBet 
                }
                else if val == dealerVal { 
                    msg += "Hand \(handNumber): Push.\n"; 
                    payout += handBet 
                    totalWinningAmount += handBet // Include push amount in total winnings
                }
                else if has21 { 
                    // Check if it's natural blackjack (first two cards = 21)
                    let isNaturalBlackjack = hand.count == 2 &&
                        ((hand[0].rank == .ace && hand[1].rank.value == 10) ||
                         (hand[1].rank == .ace && hand[0].rank.value == 10))
                    
                    if isNaturalBlackjack {
                        msg += "Hand \(handNumber): 21!\n"; 
                    } else {
                        msg += "Hand \(handNumber): Win!\n"; 
                    }
                    payout += handBet * 2 // Split hands with 21 get 1:1 payout (double)
                    totalWinningAmount += handBet * 2 // Track winning amount for display
                }
                else if dealerVal > 21 || val > dealerVal { 
                    msg += "Hand \(handNumber): Win!\n"; 
                    payout += handBet * 2 
                    totalWinningAmount += handBet * 2 // Track winning amount for display
                }
                else { 
                    msg += "Hand \(handNumber): Lose.\n"; 
                    payout -= handBet 
                }
            }
            
            // Set the winning amount for display (total amount won including pushes)
            gameState.winningAmount = totalWinningAmount
        } else {
            let playerVal = handValue(gameState.playerHand)
            let dealerVal = handValue(gameState.dealerHand)
            let playerBlackjack = gameState.playerHand.count == 2 && playerVal == 21
            let dealerBlackjack = gameState.dealerHand.count == 2 && dealerVal == 21
            
            print("🃏 endPlayerTurn: playerVal=\(playerVal), dealerVal=\(dealerVal), playerBlackjack=\(playerBlackjack), dealerBlackjack=\(dealerBlackjack), playerHand.count=\(gameState.playerHand.count)")
            
            if playerBusted {
                payout = -gameState.playerBet
            } else if playerBlackjack {
                if dealerBlackjack {
                    payout = gameState.playerBet // push
                    msg = "Push"
                    print("🃏 endPlayerTurn: Push - both have blackjack")
                } else {
                    let win = Int(Double(gameState.playerBet) * 1.5)
                    payout = gameState.playerBet + win
                    msg = "Blackjack! Won $\(win)"
                    print("🃏 endPlayerTurn: Player blackjack wins! win=\(win), payout=\(payout)")
                }
            } else if dealerBlackjack {
                payout = -gameState.playerBet
                msg = "Dealer Blackjack"
            } else if dealerVal > 21 || playerVal > dealerVal {
                payout = gameState.playerBet * 2
            } else if playerVal == dealerVal {
                payout = 0
            } else {
                payout = -gameState.playerBet
            }
        }
        
        gameState.lastPayout = payout
        
        // Calculate total amount returned for display
        if gameState.isSplit {
            // For splits, use the totalWinningAmount (total amount returned)
            gameState.actualWinnings = gameState.winningAmount
            print("💰 SPLIT: totalWinningAmount=\(gameState.winningAmount), actualWinnings=\(gameState.actualWinnings), playerBet=\(gameState.playerBet)")
        } else {
            // For single hands, use payout logic
            if payout > 0 {
                gameState.actualWinnings = payout // payout already includes bet + winnings
                print("💰 WIN: payout=\(payout), actualWinnings=\(gameState.actualWinnings), playerBet=\(gameState.playerBet)")
            } else if payout == 0 {
                gameState.actualWinnings = gameState.playerBet // Push - show amount they get back (their bet)
                print("💰 PUSH: payout=\(payout), actualWinnings=\(gameState.actualWinnings) (bet returned)")
            } else {
                // Loss - show amount they get back (0 for total loss)
                gameState.actualWinnings = 0
                print("💰 LOSS: payout=\(payout), actualWinnings=\(gameState.actualWinnings)")
            }
        }
        
        // Set showNextHand to false immediately when round ends to ensure buttons are visible
        // This fixes the issue where buttons don't show when forced blackjack is off
        gameState.showNextHand = false
        
        handleGameResult(gameState: gameState, payout: payout)
        gameState.resultMessage = msg
        gameState.showPostGameButtons = true // Show buttons after game ends
        gameState.showResultNotification = true // Show notifications when game ends
        
        // For losses, save chips for animation then clear betting state immediately
        if payout < 0 {
            print("💰 LOSS: Saving chips for animation then clearing betting state")
            // Save bet amount for display purposes
            gameState.displayBetAmount = gameState.playerBet
            // Save chips for lose animation before clearing
            gameState.savedLoseChips = gameState.betChips
            // Clear betting state immediately so Deal Cards button becomes disabled
            gameState.playerBet = 0
            gameState.betChips = []
        }
        
        // Shuffle deck if needed after round ends
        if gameState.needsShuffling {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.shuffleDeckIfNeeded(gameState: gameState)
            }
        }
        
        // DISABLED: Automatic card collection animation after round ends
        // Cards will only be collected when user takes action (clicks Redo Bet or places a chip)
        // DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        //     let bettingManager = BlackjackBettingManager.shared
        //     bettingManager.animateCardsBackToDeck(gameState: gameState)
        // }
    }
    
    private func handleGameResult(gameState: BlackjackGameState, payout: Int) {
        // Check if training mode is enabled - skip payouts if it is
        let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
        
        // Immediately mark that any chips currently on the table were NOT placed by the user for the next hand.
        // This keeps the Deal Cards button dim until the user actively bets again (chip tap or redo bet).
        gameState.userPlacedCurrentBet = false
        
        if !trainingModeEnabled {
            let before = XPChipManager.shared.userChips
            
            // Calculate chips to credit based on result:
            // - Win (payout > 0): Return original bet + winnings
            // - Push (payout = 0): Return original bet only
            // - Loss (payout < 0): Return nothing (bet is lost)
            let credited: Int
            if payout > 0 {
                credited = payout  // Win: payout already includes bet + winnings
            } else if payout == 0 {
                credited = gameState.playerBet  // Push: return bet only
            } else {
                credited = 0  // Loss: return nothing
            }
            
            XPChipManager.shared.updateChips(credited)
            let after = XPChipManager.shared.userChips
            _ = after - before // actualChange not used; keep for future debugging

            print("💰 Game result: payout=\(payout), playerBet=\(gameState.playerBet), credited=\(credited)")
            gameState.debugPayoutMessage = "" // suppress debug overlay
            gameState.showDebugPayout = false
            
            // Award XP based on outcome: Win = 3 XP, Push = 2 XP, Loss = 1 XP
            if payout > 0 {
                XPChipManager.shared.addXP(3) // Win
            } else if payout == 0 { 
                XPChipManager.shared.addXP(2) // Push
            } else {
                XPChipManager.shared.addXP(1) // Loss
            }
            if XPChipManager.shared.userChips <= 0 { gameState.showZeroChipsOverlay = true }
        } else {
            print("🎓 Training Mode: No payouts or XP awarded - training mode enabled")
        }
        
        // Only clear betting state for pushes, not for losses (losses are handled above with animation delay)
        // Wins: keep chips briefly for visual payout, then auto-collect them after a short delay so the deal button re-disables.
        if !gameState.isCollectingPhase && payout == 0 {
            gameState.playerBet = 0
            gameState.betChips = []
            gameState.userPlacedCurrentBet = false
            print("💰 Clearing chips for push result")
        } else if payout > 0 {
            print("💰 Preserving chips for win result temporarily (will auto-collect)")
            // Hide "Return Bet" immediately during payout + auto-collect (covers the 2s delay too).
            gameState.isAutoCollectingWinnings = true
            let betSnapshot = gameState.betChips
            let addSnapshot = gameState.additionalBetChips
            let dd1Snapshot = gameState.doubleDownChipsHand1
            let dd2Snapshot = gameState.doubleDownChipsHand2
            let playerBetSnapshot = gameState.playerBet
            
            // After 2 seconds, collect winnings back to the player's stash and clear the table chips
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // If the player has already placed a new bet, do nothing
                guard gameState.betChips == betSnapshot,
                      gameState.additionalBetChips == addSnapshot,
                      gameState.doubleDownChipsHand1 == dd1Snapshot,
                      gameState.doubleDownChipsHand2 == dd2Snapshot,
                      gameState.playerBet == playerBetSnapshot else {
                    print("💰 Auto-collect skipped: player already placed a new bet")
                    gameState.isAutoCollectingWinnings = false
                    return
                }
                
                print("💰 Auto-collecting winnings back to player stash after payout")
                gameState.autoCollectWinningsToggle.toggle()
                // Don't clear chips here - let the animation function clear them after animation completes
                // This ensures both payout chips (winChips) and bet chips are visible during animation
                gameState.playerBet = 0
                gameState.displayBetAmount = 0
                gameState.userPlacedCurrentBet = false
            }
        } else if gameState.isCollectingPhase {
            print("🎯 EndRound: Preserving betting state during card collection animation")
        } else if payout < 0 {
            print("💰 Preserving chips for loss result (will be cleared after animation)")
        }
        gameState.showNextHand = false
    }
    
    // MARK: - Deck Management
    func resetDeck(gameState: BlackjackGameState, numberOfDecks: Int = 1) {
        // Don't reset the game if we're in the middle of a card collection animation
        if !gameState.isCollectingPhase {
            gameState.resetGame()
        } else {
            print("🎯 EndRound: Skipping resetGame during card collection animation")
        }
        debugEightCardQueue.removeAll()
        debugEightCardSuitIndex = 0
        gameState.deck = Array(repeating: CardDeck.standardDeck(), count: numberOfDecks).flatMap { $0 }.shuffled()
        gameState.originalDeck = gameState.deck // Store original deck for shuffling
        gameState.needsShuffling = false
        gameState.showShufflingNotification = false
        if XPChipManager.shared.userChips <= 0 { XPChipManager.shared.updateChips(500) }
    }
    
    func dealInitialCards(
        gameState: BlackjackGameState,
        useRegularModeAnimation: Bool = false,
        animationCallback: ((Card, Int, @escaping () -> Void) -> Void)? = nil
    ) {
        if isEightCardDebugEnabled() {
            debugEightCardQueue.removeAll()
            debugEightCardSuitIndex = 0
        }
        // Check if shuffling is needed before dealing
        checkForShuffling(gameState: gameState)
        
        // If shuffling is needed, don't start a new game
        if gameState.needsShuffling {
            print("🔄 Cannot deal new cards - deck needs shuffling")
            return
        }
        
        guard gameState.deck.count >= 4 else { resetDeck(gameState: gameState); return }
        gameState.isDealing = true
        
        // Always ensure betting chips are visible when starting a new round.
        // Lose animations intentionally leave this true; reset here so the next hand doesn't "lose" the chips visually.
        gameState.hideBetChipsDuringLoseAnimation = false

        // Save the bet for redo functionality (never modify the actual bet)
        if gameState.playerBet > 0 { gameState.lastBet = gameState.playerBet }
        
        gameState.resultMessage = nil
        gameState.dealtPlayerCards = []
        gameState.dealtDealerCards = []
        gameState.flippedDealerCards = [1]
        gameState.countingRevealedDealerCards = [1] // Second dealer card is immediately visible for counting
        gameState.playerHand = []
        gameState.dealerHand = []
        gameState.visuallyRevealedDealerHand = []
        gameState.splitHands = []
        gameState.activeHandIndex = 0
        gameState.isSplit = false
        gameState.showNextHand = true
        gameState.isPlayerTurn = true
        
        dealCardsSequentially(gameState: gameState, useRegularModeAnimation: useRegularModeAnimation, animationCallback: animationCallback)
    }
    
    private func dealCardsSequentially(
        gameState: BlackjackGameState,
        useRegularModeAnimation: Bool = false,
        animationCallback: ((Card, Int, @escaping () -> Void) -> Void)? = nil
    ) {
        var localDeck = gameState.deck
        var localRunning = gameState.runningCount
        var i = 0
        let forceEight = isEightCardDebugEnabled()
        
        func dealNext() {
            guard i < 4 else {
                gameState.isDealing = false
                // Blackjack check now happens after dealer's second card is added (in case 3)
                return
            }
            
            var card: Card
            let forcePairs = UserDefaults.standard.bool(forKey: "debugForcePairs")
            let force10s = UserDefaults.standard.bool(forKey: "debugForce10s")
            
            if forceEight {
                let recipient: CardRecipient = (i == 1 || i == 3) ? .dealer : .player
                card = drawCard(for: recipient, deck: &localDeck)
                print("🎲 Debug: 8 cards for player and dealer enabled - dealt \(card.rank.rawValue) to \(recipient == .player ? "player" : "dealer") at index \(i)")
            } else if forcePairs && (i == 0 || i == 2) {
                // Force pairs logic (existing)
                if i == 0 {
                    card = localDeck.removeFirst()
                } else {
                    let first = gameState.playerHand[0]
                    if let idx = localDeck.firstIndex(where: { $0.rank.value == first.rank.value }) {
                        card = localDeck.remove(at: idx)
                    } else { card = localDeck.removeFirst() }
                }
            } else if UserDefaults.standard.bool(forKey: "forcedBlackjacks") {
                // Force blackjack for player only (first two cards)
                if i == 0 || i == 2 {
                    // Player's cards - force blackjack (indices 0 and 2)
                    if i == 0 {
                        // First player card: Ace
                        if let idx = localDeck.firstIndex(where: { $0.rank == .ace }) {
                            card = localDeck.remove(at: idx)
                            print("🎲 Debug: Forced Ace for player blackjack (first card)")
                        } else {
                            card = localDeck.removeFirst()
                            print("🎲 Debug: No Ace available for forced blackjack")
                        }
                    } else {
                        // Second player card: 10-value card
                        let tenValueRanks: [CardRank] = [.ten, .jack, .queen, .king]
                        if let idx = localDeck.firstIndex(where: { tenValueRanks.contains($0.rank) }) {
                            card = localDeck.remove(at: idx)
                            print("🎲 Debug: Forced 10-value card for player blackjack (second card)")
                        } else {
                            card = localDeck.removeFirst()
                            print("🎲 Debug: No 10-value card available for forced blackjack")
                        }
                    }
                } else {
                    // Dealer's cards - deal normally
                    card = localDeck.removeFirst()
                }
            } else if force10s {
                // Force 10-value cards (10, J, Q, K) for all dealt cards
                let tenValueRanks: [CardRank] = [.ten, .jack, .queen, .king]
                if let idx = localDeck.firstIndex(where: { tenValueRanks.contains($0.rank) }) {
                    card = localDeck.remove(at: idx)
                    print("🎲 Debug: Forced 10-value card: \(card.rank.rawValue)")
                } else {
                    card = localDeck.removeFirst()
                    print("🎲 Debug: No 10-value cards available, using: \(card.rank.rawValue)")
                }
            } else {
                card = localDeck.removeFirst()
            }
            localRunning += card.countValue

            switch i {
            case 0:
                gameState.playerHand.append(card)
                
                // Chips are already minimized in the "Deal Cards" button action
                // No need to minimize again here - just proceed with dealing
                
                if useRegularModeAnimation, let cb = animationCallback { cb(card, i) { gameState.dealtPlayerCards.append(card) } }
                else { withAnimation(.easeOut(duration: 0.3)) { gameState.dealtPlayerCards.append(card) } }

            case 1:
                // Dealer's first card (face down)
                if forcePairs {
                    // When force pairs is enabled, give dealer a LOW card so they must hit
                    // Strategy: Give dealer 6 (hole card) so with any face card they'll have 16 and must hit
                    let lowValueRanks: [CardRank] = [.six, .five, .four, .three, .two]
                    if let idx = localDeck.firstIndex(where: { lowValueRanks.contains($0.rank) }) {
                        card = localDeck.remove(at: idx)
                        print("🎲 Debug: Forced LOW card for dealer (face down): \(card.rank.rawValue) - dealer will need to hit!")
                    }
                }
                gameState.dealerHand.append(card)
                let down = Card(suit: card.suit, rank: card.rank, isFaceUp: false)
                if useRegularModeAnimation, let cb = animationCallback { cb(down, i) { gameState.dealtDealerCards.append(down) } }
                else { withAnimation(.easeOut(duration: 0.3)) { gameState.dealtDealerCards.append(down) } }

            case 2:
                // Add card to playerHand immediately for blackjack detection
                gameState.playerHand.append(card)
                
                if useRegularModeAnimation, let cb = animationCallback { 
                    cb(card, i) { 
                        gameState.dealtPlayerCards.append(card)
                    } 
                } else { 
                    withAnimation(.easeOut(duration: 0.3)) { gameState.dealtPlayerCards.append(card) }
                }

            case 3:
                // Dealer's second card (face up)
                if forcePairs {
                    // When force pairs is enabled, give dealer a 10-value card
                    // Combined with low hole card (6), dealer will have 16 and MUST hit
                    let tenValueRanks: [CardRank] = [.ten, .jack, .queen, .king]
                    if let idx = localDeck.firstIndex(where: { tenValueRanks.contains($0.rank) }) {
                        card = localDeck.remove(at: idx)
                        print("🎲 Debug: Forced 10-value card for dealer (face up): \(card.rank.rawValue) - dealer will have ~16 and must hit!")
                    }
                }
                gameState.dealerHand.append(card)
                if useRegularModeAnimation, let cb = animationCallback {
                    cb(card, i) {
                        gameState.dealtDealerCards.append(card)
                        gameState.visuallyRevealedDealerHand.append(card)
                        
                        // After dealer's second card is added, check for player natural blackjack
                        // Use gameState values since they're updated after each card
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.checkForNaturalBlackjack(gameState: gameState)
                        }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { gameState.dealtDealerCards.append(card) }
                    gameState.visuallyRevealedDealerHand.append(card)
                    
                    // After dealer's second card is added, check for player natural blackjack
                    // Use gameState values since they're updated after each card
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.checkForNaturalBlackjack(gameState: gameState)
                    }
                }
            default: break
            }
            
            gameState.deck = localDeck
            gameState.runningCount = localRunning
            gameState.cardsDealt += 1
            
            // Check for shuffling after dealing each card
            checkForShuffling(gameState: gameState)
            
            i += 1
            
            // Only continue dealing if we haven't detected a blackjack
            if i < 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dealNext() }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dealNext() }
    }

    /// Check for natural blackjack after all initial cards are dealt
    private func checkForNaturalBlackjack(gameState: BlackjackGameState) {
        // Ensure we have exactly 2 player cards
        guard gameState.playerHand.count == 2 else {
            print("🃏 Blackjack check: Player hand has \(gameState.playerHand.count) cards, skipping check")
            return
        }
        
        // Detect natural blackjack (any Ace + any 10-value) for 2-card player hand
        let playerVal = handValue(gameState.playerHand)
        let playerNaturalBlackjack = playerVal == 21
        
        print("🃏 Blackjack check: Player hand value = \(playerVal), cards = \(gameState.playerHand.map { "\($0.rank.rawValue)" })")
        
        if playerNaturalBlackjack {
            print("🃏 Natural blackjack detected! Resolving...")
            // Ensure cardsDealt is correct
            if gameState.cardsDealt < 4 {
                gameState.cardsDealt = 4
            }
            gameState.isDealing = false
            resolvePlayerNaturalBlackjack(gameState: gameState)
        }
    }
    
    /// Resolve a player natural blackjack (first two cards = 21) for both modes.
    /// Immediately ends player turn, hides buttons, reveals dealer hole for push check, then finishes.
    private func resolvePlayerNaturalBlackjack(gameState: BlackjackGameState) {
        print("🃏 resolvePlayerNaturalBlackjack called")
        
        // Track natural blackjack for achievements/stats
        Task { await AchievementsStore.shared.incrementStat(.blackjacks, by: 1) }
        
        // Hide player actions immediately (sync on main thread)
        DispatchQueue.main.async {
            print("🃏 Hiding player actions - setting isPlayerTurn=false, isProcessingAction=true")
            gameState.isPlayerTurn = false
            gameState.isProcessingAction = true
            
            // Reveal dealer hole card and then end hand (handles push vs win)
            self.revealDealerCard(gameState: gameState) {
                print("🃏 Dealer card revealed, calling endPlayerTurn")
                self.endPlayerTurn(gameState: gameState, playerBusted: false)
                print("🃏 endPlayerTurn completed, resultMessage=\(gameState.resultMessage ?? "nil")")
            }
        }
    }
    
    func dealNewHand(gameState: BlackjackGameState) { gameState.resetForNewHand() }
    
    // MARK: - Deck Shuffling Logic
    func checkForShuffling(gameState: BlackjackGameState) {
        // Calculate shuffle point based on ACTUAL deck size, not numberOfDecks setting
        let totalDeckSize = gameState.deck.count + gameState.cardsDealt
        let shufflePoint: Int
        
        if totalDeckSize <= 104 {
            // Small decks (1-2 decks): Show shuffle message at last 14 cards
            shufflePoint = 14
        } else {
            // Large decks (4+ decks): Show shuffle message at last 52 cards
            shufflePoint = 52
        }
        
        // Check if we have reached the shuffle point
        if gameState.deck.count <= shufflePoint && !gameState.needsShuffling {
            print("🔄 Deck needs shuffling: \(gameState.deck.count) cards remaining (shuffle point: \(shufflePoint) for total deck size: \(totalDeckSize))")
            gameState.needsShuffling = true
            gameState.showShufflingNotification = true
        }
    }
    
    func shuffleDeckIfNeeded(gameState: BlackjackGameState) {
        guard gameState.needsShuffling else { return }
        
        print("🔄 Shuffling deck...")
        gameState.deck = gameState.originalDeck.shuffled()
        gameState.needsShuffling = false
        gameState.showShufflingNotification = false
        gameState.runningCount = 0 // Reset running count after shuffle
        gameState.cardsDealt = 0 // Reset cards dealt count
        print("🔄 Deck shuffled: \(gameState.deck.count) cards available")
    }
    
    // MARK: - Dealer hole reveal
    func revealDealerCard(gameState: BlackjackGameState, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Wait 0.5 seconds before starting flip animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Start flip animation
                withAnimation(.easeInOut(duration: 0.6)) {
                    gameState.flippedDealerCards.insert(0)
                }
                // Update counting state and visually revealed hand after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    gameState.countingRevealedDealerCards.insert(0)
                    if gameState.dealerHand.count > 0 {
                        // Only add if not already in visuallyRevealedDealerHand
                        if !gameState.visuallyRevealedDealerHand.contains(where: { $0.id == gameState.dealerHand[0].id }) {
                            gameState.visuallyRevealedDealerHand.append(gameState.dealerHand[0])
                        }
                    }
                    completion()
                }
            }
        }
    }
} 

 
