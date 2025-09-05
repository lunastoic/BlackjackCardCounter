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
        
        // Auto-advance if active hand has 21 (blackjack or regular 21)
        if activeValue == 21 {
            let handNumber = gameState.activeHandIndex == 1 ? 1 : 2
            print("🃏 Split hand \(handNumber) (index \(gameState.activeHandIndex)) has 21 - auto-advancing")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🃏 Auto-advance executing for hand \(handNumber)")
                if gameState.activeHandIndex == 0 {
                    // Hand 2 (left, last hand) - go to dealer
                    print("🃏 Last hand complete, starting dealer turn")
                    self.dealerTurn(gameState: gameState)
                } else {
                    // Hand 1 (right) - go to Hand 2
                    print("🃏 Moving from Hand 1 to Hand 2")
                    gameState.activeHandIndex = 0
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
        
        guard gameState.deck.count > 0, 
              !gameState.isProcessingAction,
              timeSinceLastAction >= 0.6 else { 
            print("🎯 hitAction: BLOCKED - processing=\(gameState.isProcessingAction), timeSince=\(timeSinceLastAction)")
            return 
        }
        
        gameState.isProcessingAction = true
        gameState.lastActionTime = now
        print("🎯 hitAction: Processing locked at \(now)")

        if gameState.isSplit {
            let newCard = gameState.deck.removeFirst()
            gameState.runningCount += newCard.countValue
            gameState.cardsDealt += 1
            
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
            let newCard = gameState.deck.removeFirst()
            gameState.playerHand.append(newCard)
            gameState.runningCount += newCard.countValue
            gameState.cardsDealt += 1

            // Check for bust immediately to hide action buttons
            let playerBusted = isBust(gameState.playerHand)
            if playerBusted {
                print("🎯 Player busted with \(handValue(gameState.playerHand)) - hiding buttons")
                gameState.isPlayerTurn = false // This will hide the action buttons immediately
            }

            if let cb = hitAnimationCallback {
                cb(newCard, true) { 
                    gameState.dealtPlayerCards.append(newCard)
                    // Unlock after animation completes
                    gameState.isProcessingAction = false
                    print("🎯 hitAction: Animation processing unlocked")
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    gameState.dealtPlayerCards.append(newCard)
                }
                // Unlock after animation delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    gameState.isProcessingAction = false
                    print("🎯 hitAction: Fallback processing unlocked")
                }
            }

            if playerBusted {
                revealDealerCard(gameState: gameState) {
                    self.endPlayerTurn(gameState: gameState, playerBusted: true)
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
        
        if gameState.deck.count > 0,
           gameState.playerHand.count == 2,
           gameState.playerBet <= XPChipManager.shared.userChips {
            
            XPChipManager.shared.updateChips(-gameState.playerBet)
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
            
            let newCard = gameState.deck.removeFirst()
            gameState.playerHand.append(newCard)
            gameState.runningCount += newCard.countValue
            
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
        
        guard gameState.deck.count > 0,
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
        
        // Double the bet for this specific hand
        gameState.splitHandBets[gameState.activeHandIndex] *= 2
        
        // Update total player bet
        gameState.playerBet = gameState.splitHandBets.reduce(0, +)
        
        print("🎲 Double Down Split: Hand \(gameState.activeHandIndex + 1) bet now: \(gameState.splitHandBets[gameState.activeHandIndex]), total bet: \(gameState.playerBet)")
        
        // Ensure deck position is set for animation
        if gameState.deckPosition == .zero {
            print("🎲 Double Down Split: WARNING - deck position is zero, setting default")
            gameState.deckPosition = CGPoint(x: UIScreen.main.bounds.width * 0.85, y: UIScreen.main.bounds.height * 0.15)
        }
        
        // Deal one card to the active hand
        let newCard = gameState.deck.removeFirst()
        gameState.runningCount += newCard.countValue
        gameState.cardsDealt += 1
        
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
        
        let hasEnoughChips = gameState.playerBet <= XPChipManager.shared.userChips
        let hasValidCards = gameState.canSplitCards(card1: gameState.playerHand[0], card2: gameState.playerHand[1])
        
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
            guard handIndex < gameState.splitHands.count, !gameState.deck.isEmpty else { return }

            // Debug: Force specific cards for split hands when debugForcePairs is enabled
            let forcePairs = UserDefaults.standard.bool(forKey: "debugForcePairs")
            var card: Card
            
            if forcePairs && handIndex == 0 {
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

            if let splitCB = splitAnimationCallback {
                splitCB(card, handIndex) {
                    gameState.splitHands[handIndex].append(card)  // add only after anim completes
                    
                    // Check if the hand that just received a card should auto-advance
                    if gameState.activeHandIndex == handIndex {
                        self.checkSplitHandAutoAdvance(gameState: gameState)
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
                        self.checkSplitHandAutoAdvance(gameState: gameState)
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
        
        func dealNextCard() {
            if self.handValue(dealer) < 17, !localDeck.isEmpty {
                let card = localDeck.removeFirst()
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
            let blackjack = gameState.playerHand.count == 2 &&
                ((gameState.playerHand[0].rank == .ace && gameState.playerHand[1].rank.value == 10) || 
                 (gameState.playerHand[1].rank == .ace && gameState.playerHand[0].rank.value == 10))
            
            if playerBusted { payout = -gameState.playerBet }
            else if blackjack {
                let win = Int(Double(gameState.playerBet) * 1.5)
                msg = "Blackjack!"
                payout = gameState.playerBet + win
            } else if dealerVal > 21 || playerVal > dealerVal { payout = gameState.playerBet * 2 }
            else if playerVal == dealerVal { payout = 0 }
            else { payout = -gameState.playerBet }
        }
        
        gameState.lastPayout = payout
        
        // Calculate actual winnings for display (total amount won = bet + winnings)
        if payout > 0 {
            gameState.actualWinnings = payout // payout already includes bet + winnings
            print("💰 WIN: payout=\(payout), actualWinnings=\(gameState.actualWinnings), playerBet=\(gameState.playerBet)")
        } else if payout == 0 {
            gameState.actualWinnings = 0 // Push - no winnings
            print("💰 PUSH: payout=\(payout), actualWinnings=\(gameState.actualWinnings)")
        } else {
            gameState.actualWinnings = 0 // Loss - no winnings
            print("💰 LOSS: payout=\(payout), actualWinnings=\(gameState.actualWinnings)")
        }
        
        handleGameResult(gameState: gameState, payout: payout)
        gameState.resultMessage = msg
    }
    
    private func handleGameResult(gameState: BlackjackGameState, payout: Int) {
        // Check if training mode is enabled - skip payouts if it is
        let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
        
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
            let actualChange = after - before

            print("💰 Game result: payout=\(payout), playerBet=\(gameState.playerBet), credited=\(credited)")
            gameState.debugPayoutMessage = "Expected: +$\(credited), Actual: +$\(actualChange)"
            gameState.showDebugPayout = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { gameState.showDebugPayout = false }
            
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
        
        gameState.playerBet = 0
        gameState.betChips = []
        gameState.showNextHand = false
    }
    
    // MARK: - Deck Management
    func resetDeck(gameState: BlackjackGameState, numberOfDecks: Int = 1) {
        gameState.resetGame()
        gameState.deck = Array(repeating: CardDeck.standardDeck(), count: numberOfDecks).flatMap { $0 }.shuffled()
        if XPChipManager.shared.userChips <= 0 { XPChipManager.shared.updateChips(500) }
    }
    
    func dealInitialCards(
        gameState: BlackjackGameState,
        useRegularModeAnimation: Bool = false,
        animationCallback: ((Card, Int, @escaping () -> Void) -> Void)? = nil
    ) {
                guard gameState.deck.count >= 4 else { resetDeck(gameState: gameState); return }
        gameState.isDealing = true

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
        
        func dealNext() {
            guard i < 4 else {
                gameState.isDealing = false
                if gameState.playerHand.count == 2 && 
                   ((gameState.playerHand[0].rank == .ace && gameState.playerHand[1].rank.value == 10) || 
                    (gameState.playerHand[1].rank == .ace && gameState.playerHand[0].rank.value == 10)) {
                    
                    let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
                    print("🎓 Player has blackjack! trainingModeEnabled=\(trainingModeEnabled)")
                    
                    if trainingModeEnabled {
                        // In training mode, reveal dealer card first so we can see what they had
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.revealDealerCard(gameState: gameState) {
                                // After revealing dealer card, end the hand
                                self.endPlayerTurn(gameState: gameState, playerBusted: false)
                            }
                        }
                    } else {
                        // In regular mode, immediately end the hand (original behavior)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.endPlayerTurn(gameState: gameState, playerBusted: false)
                        }
                    }
                }
                return
            }
            
            var card: Card
            let forcePairs = UserDefaults.standard.bool(forKey: "debugForcePairs")
            let force10s = UserDefaults.standard.bool(forKey: "debugForce10s")
            
            if forcePairs && (i == 0 || i == 2) {
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
                if useRegularModeAnimation, let cb = animationCallback { cb(card, i) { gameState.dealtPlayerCards.append(card) } }
                else { withAnimation(.easeOut(duration: 0.3)) { gameState.dealtPlayerCards.append(card) } }

            case 1:
                gameState.dealerHand.append(card)
                let down = Card(suit: card.suit, rank: card.rank, isFaceUp: false)
                if useRegularModeAnimation, let cb = animationCallback { cb(down, i) { gameState.dealtDealerCards.append(down) } }
                else { withAnimation(.easeOut(duration: 0.3)) { gameState.dealtDealerCards.append(down) } }

            case 2:
                gameState.playerHand.append(card)
                if useRegularModeAnimation, let cb = animationCallback { cb(card, i) { gameState.dealtPlayerCards.append(card) } }
                else { withAnimation(.easeOut(duration: 0.3)) { gameState.dealtPlayerCards.append(card) } }

            case 3:
                gameState.dealerHand.append(card)
                if useRegularModeAnimation, let cb = animationCallback {
                    cb(card, i) {
                        gameState.dealtDealerCards.append(card)
                        gameState.visuallyRevealedDealerHand.append(card)
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { gameState.dealtDealerCards.append(card) }
                    gameState.visuallyRevealedDealerHand.append(card)
                }
            default: break
            }
            
            gameState.deck = localDeck
            gameState.runningCount = localRunning
            gameState.cardsDealt += 1
            i += 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dealNext() }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dealNext() }
    }
    
    func dealNewHand(gameState: BlackjackGameState) { gameState.resetForNewHand() }
    
    // MARK: - Dealer hole reveal
    func revealDealerCard(gameState: BlackjackGameState, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.6)) { gameState.flippedDealerCards.insert(0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                // Update counting state after flip animation completes
                gameState.countingRevealedDealerCards.insert(0)
                if gameState.dealerHand.count > 0 {
                    gameState.visuallyRevealedDealerHand.append(gameState.dealerHand[0])
                }
                completion()
            }
        }
    }
} 

 
