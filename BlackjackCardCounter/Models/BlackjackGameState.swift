import SwiftUI

// MARK: - Game State Management
class BlackjackGameState: ObservableObject {
    // Core game state
    @Published var deck: [Card] = []
    @Published var playerHand: [Card] = []
    @Published var dealerHand: [Card] = []
    @Published var visuallyRevealedDealerHand: [Card] = [] // Only cards that are visually flipped
    @Published var splitHands: [[Card]] = []
    @Published var activeHandIndex: Int = 0
    @Published var isSplit: Bool = false
    @Published var isPlayerTurn: Bool = true
    @Published var showNextHand: Bool = false
    @Published var resultMessage: String? = nil
    @Published var doubledDown: Bool = false
    @Published var dealtPlayerCards: [Card] = []
    @Published var dealtDealerCards: [Card] = []
    @Published var flippedDealerCards: Set<Int> = []
    @Published var lastPayout: Int = 0
    @Published var actualWinnings: Int = 0
    @Published var winningAmount: Int = 0
    @Published var cardsDealt: Int = 0
    @Published var runningCount: Int = 0
    @Published var isTrainingMode: Bool = false
    @Published var numberOfDecks: Int = 0
    
    // Betting state
    @Published var playerBet: Int = 0
    @Published var betChips: [Int] = []
    @Published var lastBet: Int? = nil
    @Published var splitHandBets: [Int] = [] // Individual bet amounts for each split hand
    
    // Debug and overlay state
    @Published var showZeroChipsOverlay: Bool = false
    @Published var debugPayoutMessage: String? = nil
    @Published var showDebugPayout: Bool = false
    
    // Animation state for RegularModeView
    @Published var isDealing: Bool = false
    @Published var isProcessingAction: Bool = false
    @Published var lastActionTime: Date = Date()
    @Published var deckFrame: CGRect = .zero
    @Published var deckPosition: CGPoint = .zero
    @Published var animatingCards: [UUID: Card] = [:]
    @Published var animatingCardPositions: [UUID: CGPoint] = [:]
    @Published var animatingCardScales: [UUID: CGFloat] = [:]
    @Published var animatingCardOpacities: [UUID: Double] = [:]
    @Published var cardFlipRotations: [UUID: Double] = [:]
    @Published var cardFlipScales: [UUID: CGFloat] = [:]
    
    // Position tracking for animations
    @Published var playerCardPositions: [Int: CGPoint] = [:]
    @Published var dealerCardPositions: [Int: CGPoint] = [:]
    @Published var deckOffset: CGFloat = 0
    
    // Legacy animation state (for RegularModeView)
    @Published var cardDealPositions: [String: CGPoint] = [:]
    @Published var cardFinalPositions: [String: CGPoint] = [:]
    @Published var cardScale: [String: CGFloat] = [:]
    
    // Computed properties
    var cardsRemaining: Int { deck.count }
    
    var canSplit: Bool {
        print("🃏 🔴 canSplit called: isSplit=\(isSplit), handCount=\(playerHand.count), bet=\(playerBet), chips=\(XPChipManager.shared.userChips)")
        
        let hasEnoughChips = playerBet <= XPChipManager.shared.userChips
        print("🃏 🔴 CHIP VALIDATION: need \(playerBet), have \(XPChipManager.shared.userChips), RESULT: \(hasEnoughChips ? "PASS" : "FAIL")")
        
        let notSplit = !isSplit
        let correctHandCount = playerHand.count == 2
        
        print("🃏 🔴 ALL VALIDATIONS: notSplit=\(notSplit), correctHandCount=\(correctHandCount), hasEnoughChips=\(hasEnoughChips)")
        
        guard notSplit && correctHandCount && hasEnoughChips else {
            print("🃏 🔴 canSplit FAILED - returning false")
            return false
        }
        
        let card1 = playerHand[0]
        let card2 = playerHand[1]
        
        // Check if both cards have the same splitting value
        let canSplitCards = canSplitCards(card1: card1, card2: card2)
        
        print("🃏 🔴 CARD CHECK: \(card1.rank.rawValue)(\(card1.rank.value)) vs \(card2.rank.rawValue)(\(card2.rank.value)), canSplitCards=\(canSplitCards)")
        print("🃏 🔴 FINAL RESULT: canSplit=\(canSplitCards)")
        
        return canSplitCards
    }
    
    // Helper function to determine if two cards can be split
    func canSplitCards(card1: Card, card2: Card) -> Bool {
        print("🃏 canSplitCards called: \(card1.rank.rawValue) + \(card2.rank.rawValue)")
        
        // Check if both cards have the same value (not just same rank)
        let value1 = card1.rank.value
        let value2 = card2.rank.value
        
        let result = value1 == value2
        print("🃏 Same value check: \(card1.rank.rawValue)(\(value1)) == \(card2.rank.rawValue)(\(value2)) -> \(result)")
        return result
    }
    
    var canDoubleDown: Bool {
        if isSplit {
            // For split hands, check if active hand has 2 cards and we have enough chips for that hand's bet
            let activeHandBet = splitHandBets.isEmpty ? (playerBet / 2) : splitHandBets[activeHandIndex]
            let activeHand = splitHands[activeHandIndex]
            let result = activeHand.count == 2 && activeHandBet <= XPChipManager.shared.userChips
            print("🎲 canDoubleDown (split): \(result) (handIndex: \(activeHandIndex), cards: \(activeHand.count), handBet: \(activeHandBet), availableChips: \(XPChipManager.shared.userChips))")
            return result
        } else {
            // For regular hands, check if we have enough chips for double down (need playerBet amount more)
            let result = playerHand.count == 2 && playerBet <= XPChipManager.shared.userChips
            print("🎲 canDoubleDown (regular): \(result) (cards: \(playerHand.count), bet: \(playerBet), availableChips: \(XPChipManager.shared.userChips))")
            return result
        }
    }
    
    var activeHand: [Card] {
        isSplit ? splitHands[activeHandIndex] : playerHand
    }
    
    var countMeterColor: Color {
        if runningCount > 0 { return .green }
        if runningCount < 0 { return .red }
        return .yellow
    }
    
    // Reset game state
    func resetGame() {
        let currentNumberOfDecks = numberOfDecks // Preserve the deck count
        deck = []
        playerHand = []
        dealerHand = []
        visuallyRevealedDealerHand = []
        splitHands = []
        activeHandIndex = 0
        isSplit = false
        isPlayerTurn = true
        showNextHand = false
        resultMessage = nil
        doubledDown = false
        dealtPlayerCards = []
        dealtDealerCards = []
        lastPayout = 0
        actualWinnings = 0
        winningAmount = 0
        cardsDealt = 0
        runningCount = 0
        playerBet = 0
        betChips = []
        lastBet = nil
        isDealing = false
        isProcessingAction = false
        lastActionTime = Date()
        deckFrame = .zero
        deckPosition = .zero
        animatingCards.removeAll()
        animatingCardPositions.removeAll()
        animatingCardScales.removeAll()
        animatingCardOpacities.removeAll()
        cardFlipRotations.removeAll()
        cardFlipScales.removeAll()
        playerCardPositions.removeAll()
        dealerCardPositions.removeAll()
        cardDealPositions.removeAll()
        cardFinalPositions.removeAll()
        cardScale.removeAll()
        deckOffset = 0
        showZeroChipsOverlay = false
        debugPayoutMessage = nil
        showDebugPayout = false
        flippedDealerCards.removeAll()
        numberOfDecks = currentNumberOfDecks // Restore the deck count
    }
    
    // Reset for new hand
    func resetForNewHand() {
        playerHand = []
        dealerHand = []
        visuallyRevealedDealerHand = []
        showNextHand = false
        playerBet = 0
        betChips = []
        splitHands = []
        activeHandIndex = 0
        isSplit = false
        isPlayerTurn = true
        doubledDown = false
        dealtPlayerCards = []
        dealtDealerCards = []
        splitHandBets = []
        isDealing = false
        isProcessingAction = false
        lastActionTime = Date()
        animatingCards.removeAll()
        animatingCardPositions.removeAll()
        animatingCardScales.removeAll()
        animatingCardOpacities.removeAll()
        playerCardPositions.removeAll()
        dealerCardPositions.removeAll()
        cardFlipRotations.removeAll()
        cardFlipScales.removeAll()
        flippedDealerCards.removeAll()
    }
} 
