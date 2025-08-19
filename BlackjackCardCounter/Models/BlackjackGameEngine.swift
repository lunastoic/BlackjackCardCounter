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
        if hand.count == 2 &&
            ((hand[0].rank == .ace && hand[1].rank.value == 10) ||
                              (hand[1].rank == .ace && hand[0].rank.value == 10)) {
            return "21"
        }
        
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
            gameState.splitHands[gameState.activeHandIndex].append(newCard)
            gameState.runningCount += newCard.countValue
            
            // Check for bust immediately on split hand
            let splitHandBusted = isBust(gameState.splitHands[gameState.activeHandIndex])
            if splitHandBusted {
                print("🎯 Split hand busted with \(handValue(gameState.splitHands[gameState.activeHandIndex])) - proceeding to next hand")
            }
            
            // Add a delay before unlocking to prevent rapid tapping
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                gameState.isProcessingAction = false
                print("🎯 hitAction: Split processing unlocked")
            }
            
            if splitHandBusted {
                nextSplitHandOrDealer(gameState: gameState)
            } else {
                // Check if hand has 21 and should auto-advance
                checkSplitHandAutoAdvance(gameState: gameState)
            }
                } else {
            let newCard = gameState.deck.removeFirst()
            gameState.playerHand.append(newCard)
            gameState.runningCount += newCard.countValue

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
        if gameState.deck.count > 0,
           gameState.playerHand.count == 2,
           gameState.playerBet <= XPChipManager.shared.userChips {
            
            XPChipManager.shared.updateChips(-gameState.playerBet)
            gameState.playerBet *= 2
            gameState.doubledDown = true
            
            let newCard = gameState.deck.removeFirst()
            gameState.playerHand.append(newCard)
            gameState.runningCount += newCard.countValue
            
            if let cb = hitAnimationCallback {
                cb(newCard, true) {
                    gameState.dealtPlayerCards.append(newCard)
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
                withAnimation(.easeOut(duration: 0.3)) {
                    gameState.dealtPlayerCards.append(newCard)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            dealerTurn(gameState: gameState)  // Left → Dealer
        }
    }
    
    func dealerTurn(gameState: BlackjackGameState) {
        gameState.isPlayerTurn = false
        revealDealerCard(gameState: gameState) {
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
                
                if let cb = hitAnimationCallback {
                    cb(card, false) {
                        newDealtDealerCards.append(card)
                        gameState.flippedDealerCards.insert(newDealtDealerCards.count - 1)
                        gameState.dealtDealerCards = newDealtDealerCards
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.4)) {
                        newDealtDealerCards.append(card)
                        gameState.flippedDealerCards.insert(newDealtDealerCards.count - 1)
                    }
                    gameState.dealtDealerCards = newDealtDealerCards
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
            let handBet = gameState.playerBet / gameState.splitHands.count
            let playerVals = gameState.splitHands.map { self.handValue($0) }
            let dealerVal = self.handValue(gameState.dealerHand)
            
            for (i, val) in playerVals.enumerated() {
                let handNumber = i == 1 ? 1 : 2  // Match display logic: index 1 = Hand 1, index 0 = Hand 2
                if val > 21 { msg += "Hand \(handNumber): Bust!\n"; payout -= handBet }
                else if dealerVal > 21 || val > dealerVal { msg += "Hand \(handNumber): Win!\n"; payout += handBet }
                else if val == dealerVal { msg += "Hand \(handNumber): Push.\n" }
                else { msg += "Hand \(handNumber): Lose.\n"; payout -= handBet }
            }
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
            } else if dealerVal > 21 || playerVal > dealerVal { payout = gameState.playerBet }
            else if playerVal == dealerVal { payout = 0 }
            else { payout = -gameState.playerBet }
        }
        
        gameState.lastPayout = payout
        handleGameResult(gameState: gameState, payout: payout)
        gameState.resultMessage = msg
    }
    
    private func handleGameResult(gameState: BlackjackGameState, payout: Int) {
        let before = XPChipManager.shared.userChips
        
        // Calculate chips to credit based on result:
        // - Win (payout > 0): Return original bet + winnings
        // - Push (payout = 0): Return original bet only
        // - Loss (payout < 0): Return nothing (bet is lost)
        let credited: Int
        if payout > 0 {
            credited = payout + gameState.playerBet  // Win: bet + winnings
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.endPlayerTurn(gameState: gameState, playerBusted: false)
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
                if gameState.dealerHand.count > 0 {
                    gameState.visuallyRevealedDealerHand.append(gameState.dealerHand[0])
                }
                completion()
            }
        }
    }
} 

 