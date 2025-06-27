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
    
    private init() {}
    
    // MARK: - Hand Value Calculations
    func handValue(_ hand: [Card]) -> Int {
        var total = 0
        var aces = 0
        
        for card in hand {
            if card.rank == .ace {
                aces += 1
            } else {
                total += card.rank.value
            }
        }
        
        // Add all aces as 1
        total += aces
        
        // For as many aces as possible, add 10 (to make them 11) if it doesn't bust
        var value = total
        for _ in 0..<aces {
            if value + 10 <= 21 {
                value += 10
            }
        }
        
        return value
    }
    
    func isBust(_ hand: [Card]) -> Bool {
        handValue(hand) > 21
    }
    
    func isSoftHand(_ hand: [Card]) -> Bool {
        var total = 0
        var aces = 0
        
        for card in hand {
            if card.rank == .ace {
                aces += 1
            } else {
                total += card.rank.value
            }
        }
        
        total += aces // All aces as 1
        
        // If at least one ace can be counted as 11, it's a soft hand
        for _ in 0..<aces {
            if total + 10 <= 21 {
                return true
            }
        }
        
        return false
    }
    
    func getHandValueText(_ hand: [Card]) -> String {
        let value = handValue(hand)
        
        // If two-card blackjack, just show 21
        if hand.count == 2 && ((hand[0].rank == .ace && hand[1].rank.value == 10) || 
                              (hand[1].rank == .ace && hand[0].rank.value == 10)) {
            return "21"
        }
        
        // Only show (Soft) if an ace is actually being counted as 11 in the final value
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
        var valueWithAces = total
        var isSoft = false
        
        for _ in 0..<aces {
            if valueWithAces + 10 <= 21 {
                valueWithAces += 10
                isSoft = true
            }
        }
        
        if isSoft {
            return "\(value) (Soft)"
        }
        
        return "\(value)"
    }
    
    // MARK: - Game Actions
    func hitAction(gameState: BlackjackGameState) {
        guard gameState.deck.count > 0 else { return }
        
        if gameState.isSplit {
            let newCard = gameState.deck.removeFirst()
            gameState.splitHands[gameState.activeHandIndex].append(newCard)
            gameState.runningCount += newCard.countValue
            
            if isBust(gameState.splitHands[gameState.activeHandIndex]) {
                nextSplitHandOrDealer(gameState: gameState)
            }
        } else {
            let newCard = gameState.deck.removeFirst()
            gameState.playerHand.append(newCard)
            gameState.runningCount += newCard.countValue
            
            withAnimation(.easeOut(duration: 0.3)) {
                gameState.dealtPlayerCards.append(newCard)
            }
            
            if isBust(gameState.playerHand) {
                // Reveal dealer's face-down card before ending the turn
                revealDealerCard(gameState: gameState) {
                    self.endPlayerTurn(gameState: gameState, playerBusted: true)
                }
            }
        }
    }
    
    func standAction(gameState: BlackjackGameState) {
        if gameState.isSplit {
            nextSplitHandOrDealer(gameState: gameState)
        } else {
            dealerTurn(gameState: gameState)
        }
    }
    
    func doubleDownAction(gameState: BlackjackGameState) {
        if gameState.isSplit { return }
        
        if gameState.deck.count > 0 && gameState.playerHand.count == 2 && 
           gameState.playerBet * 2 <= XPChipManager.shared.userChips {
            
            XPChipManager.shared.updateChips(-gameState.playerBet)
            gameState.playerBet *= 2
            gameState.doubledDown = true
            
            let newCard = gameState.deck.removeFirst()
            gameState.playerHand.append(newCard)
            gameState.runningCount += newCard.countValue
            
            withAnimation(.easeOut(duration: 0.3)) {
                gameState.dealtPlayerCards.append(newCard)
            }
            
            // Wait for card animation to complete before proceeding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.isBust(gameState.playerHand) {
                    // Reveal dealer's face-down card before ending the turn
                    self.revealDealerCard(gameState: gameState) {
                        self.endPlayerTurn(gameState: gameState, playerBusted: true)
                    }
                } else {
                    self.dealerTurn(gameState: gameState)
                }
            }
        }
    }
    
    func splitAction(gameState: BlackjackGameState) {
        guard gameState.canSplit else { return }
        
        gameState.isSplit = true
        gameState.splitHands = [[gameState.playerHand[0]], [gameState.playerHand[1]]]
        
        if gameState.deck.count > 0 {
            let card1 = gameState.deck.removeFirst()
            gameState.splitHands[0].append(card1)
            gameState.runningCount += card1.countValue
        }
        
        if gameState.deck.count > 0 {
            let card2 = gameState.deck.removeFirst()
            gameState.splitHands[1].append(card2)
            gameState.runningCount += card2.countValue
        }
        
        gameState.activeHandIndex = 0
        gameState.playerBet *= 2
    }
    
    func nextSplitHandOrDealer(gameState: BlackjackGameState) {
        if gameState.activeHandIndex == 0 {
            gameState.activeHandIndex = 1
        } else {
            dealerTurn(gameState: gameState)
        }
    }
    
    func dealerTurn(gameState: BlackjackGameState) {
        gameState.isPlayerTurn = false
        
        // First, reveal the hidden card with a delay
        revealDealerCard(gameState: gameState) {
            // Then proceed with dealer's turn after another delay
            self.dealDealerCardsSequentially(gameState: gameState)
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
                
                withAnimation(.easeOut(duration: 0.3)) {
                    newDealtDealerCards.append(card)
                    // Add the new card index to flipped set so it shows face up
                    gameState.flippedDealerCards.insert(newDealtDealerCards.count - 1)
                }
                
                // Update state after each card
                gameState.dealerHand = dealer
                gameState.runningCount = localRunningCount
                gameState.dealtDealerCards = newDealtDealerCards
                
                // Wait, then deal next card if needed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dealNextCard()
                }
            } else {
                // All done, update deck and end turn
                gameState.deck = localDeck
                self.endPlayerTurn(gameState: gameState, playerBusted: false)
            }
        }
        
        // Start dealing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            dealNextCard()
        }
    }
    
    func endPlayerTurn(gameState: BlackjackGameState, playerBusted: Bool) {
        gameState.isPlayerTurn = false
        var msg = ""
        var payout = 0
        
        if gameState.isSplit {
            let handBet = gameState.playerBet / gameState.splitHands.count
            let playerVals = gameState.splitHands.map { self.handValue($0) }
            let dealerVal = self.handValue(gameState.dealerHand)
            
            for (i, val) in playerVals.enumerated() {
                if val > 21 {
                    msg += "Hand \(i+1): Bust!\n"
                    payout -= handBet // Lose: subtract bet
                } else if dealerVal > 21 || val > dealerVal {
                    msg += "Hand \(i+1): Win!\n"
                    payout += handBet // Win: add bet
                } else if val == dealerVal {
                    msg += "Hand \(i+1): Push.\n"
                    // Push: no change
                } else {
                    msg += "Hand \(i+1): Lose.\n"
                    payout -= handBet // Lose: subtract bet
                }
            }
        } else {
            let playerVal = self.handValue(gameState.playerHand)
            let dealerVal = self.handValue(gameState.dealerHand)
            let playerHasBlackjack = gameState.playerHand.count == 2 && 
                ((gameState.playerHand[0].rank == .ace && gameState.playerHand[1].rank.value == 10) || 
                 (gameState.playerHand[1].rank == .ace && gameState.playerHand[0].rank.value == 10))
            
            if playerBusted {
                msg = "Bust! You lose."
                payout = -gameState.playerBet // Lose: subtract bet
            } else if playerHasBlackjack {
                let blackjackWinnings = Int(Double(gameState.playerBet) * 1.5)
                msg = "Blackjack! $\(blackjackWinnings) won!"
                payout = gameState.playerBet + blackjackWinnings // bet + 1.5x bet
            } else if dealerVal > 21 || playerVal > dealerVal {
                msg = "You win!"
                payout = gameState.playerBet // Win: add bet
            } else if playerVal == dealerVal {
                msg = "Push."
                payout = 0 // Push: no change
            } else {
                msg = "You lose."
                payout = -gameState.playerBet // Lose: subtract bet
            }
        }
        
        gameState.lastPayout = payout // Net gain for display
        handleGameResult(gameState: gameState, payout: payout)
        gameState.resultMessage = msg
    }
    
    private func handleGameResult(gameState: BlackjackGameState, payout: Int) {
        // Calculate expected chip change
        let chipsBefore = XPChipManager.shared.userChips
        
        // For wins, we need to add back the bet amount plus winnings since chips were already subtracted
        let actualPayout = payout > 0 ? payout + gameState.playerBet : payout
        XPChipManager.shared.updateChips(actualPayout)
        
        let chipsAfter = XPChipManager.shared.userChips
        let actualChange = chipsAfter - chipsBefore
        let expectedChange = actualPayout
        
        // Debug payout message for training mode
        gameState.debugPayoutMessage = "Expected: +$\(expectedChange), Actual: +$\(actualChange)"
        gameState.showDebugPayout = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            gameState.showDebugPayout = false
        }
        
        // Add XP: +10 for playing, +20 for a win
        if payout > 0 {
            XPChipManager.shared.addXP(20)
        } else {
            XPChipManager.shared.addXP(10)
        }
        
        // Check for zero chips
        if XPChipManager.shared.userChips <= 0 {
            gameState.showZeroChipsOverlay = true
        }
        
        // Reset bet after payout
        gameState.playerBet = 0
        gameState.betChips = []
        
        // Set showNextHand to false so chips become visible for next bet
        gameState.showNextHand = false
    }
    
    // MARK: - Deck Management
    func resetDeck(gameState: BlackjackGameState, numberOfDecks: Int = 1) {
        gameState.resetGame()
        gameState.deck = Array(repeating: CardDeck.standardDeck(), count: numberOfDecks).flatMap { $0 }.shuffled()
        if XPChipManager.shared.userChips <= 0 {
            XPChipManager.shared.updateChips(500)
        }
    }
    
    func dealInitialCards(gameState: BlackjackGameState) {
        guard gameState.deck.count >= 4 else { 
            resetDeck(gameState: gameState); 
            return 
        }
        
        if gameState.playerBet > XPChipManager.shared.userChips { 
            gameState.playerBet = XPChipManager.shared.userChips 
        }
        
        // Track last bet if this is a new hand
        if gameState.playerBet > 0 {
            gameState.lastBet = gameState.playerBet
        }
        
        // Clear any previous result message
        gameState.resultMessage = nil
        
        // Clear dealt cards arrays
        gameState.dealtPlayerCards = []
        gameState.dealtDealerCards = []
        gameState.flippedDealerCards = [1] // Second dealer card (index 1) starts flipped
        gameState.playerHand = []
        gameState.dealerHand = []
        gameState.showNextHand = true
        gameState.isPlayerTurn = true
        
        // Deal cards sequentially
        dealCardsSequentially(gameState: gameState)
    }
    
    private func dealCardsSequentially(gameState: BlackjackGameState) {
        var localDeck = gameState.deck
        var localRunningCount = gameState.runningCount
        var cardIndex = 0
        
        func dealNextCard() {
            guard cardIndex < 4 else {
                // All cards dealt, check for blackjack
                if gameState.playerHand.count == 2 && 
                   ((gameState.playerHand[0].rank == .ace && gameState.playerHand[1].rank.value == 10) || 
                    (gameState.playerHand[1].rank == .ace && gameState.playerHand[0].rank.value == 10)) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.endPlayerTurn(gameState: gameState, playerBusted: false)
                    }
                }
                return
            }
            
            let card = localDeck.removeFirst()
            localRunningCount += card.countValue
            
            // Deal in order: player, dealer (face down), player, dealer (face up)
            switch cardIndex {
            case 0: // First player card
                gameState.playerHand.append(card)
                withAnimation(.easeOut(duration: 0.3)) {
                    gameState.dealtPlayerCards.append(card)
                }
                print("🎯 Dealt player card 1: \(card.rank.rawValue)\(card.suit.rawValue)")
                
            case 1: // First dealer card (face down)
                gameState.dealerHand.append(card)
                let faceDownCard = Card(suit: card.suit, rank: card.rank, isFaceUp: false)
                withAnimation(.easeOut(duration: 0.3)) {
                    gameState.dealtDealerCards.append(faceDownCard)
                }
                print("🎯 Dealt dealer card 1 (face down): \(card.rank.rawValue)\(card.suit.rawValue)")
                
            case 2: // Second player card
                gameState.playerHand.append(card)
                withAnimation(.easeOut(duration: 0.3)) {
                    gameState.dealtPlayerCards.append(card)
                }
                print("🎯 Dealt player card 2: \(card.rank.rawValue)\(card.suit.rawValue)")
                
            case 3: // Second dealer card (face up)
                gameState.dealerHand.append(card)
                withAnimation(.easeOut(duration: 0.3)) {
                    gameState.dealtDealerCards.append(card)
                }
                print("🎯 Dealt dealer card 2 (face up): \(card.rank.rawValue)\(card.suit.rawValue)")
            default:
                break
            }
            
            // Update state
            gameState.deck = localDeck
            gameState.runningCount = localRunningCount
            gameState.cardsDealt += 1
            
            cardIndex += 1
            
            // Wait before dealing next card
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                dealNextCard()
            }
        }
        
        // Start dealing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dealNextCard()
        }
    }
    
    func dealNewHand(gameState: BlackjackGameState) {
        gameState.resetForNewHand()
    }
    
    // MARK: - Helper Functions
    func revealDealerCard(gameState: BlackjackGameState, completion: @escaping () -> Void) {
        // Reveal the hidden card with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                // Add the first dealer card to flipped set
                gameState.flippedDealerCards.insert(0)
            }
            
            // Call completion after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        }
    }
} 
 