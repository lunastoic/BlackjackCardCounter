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
    @Published var cardsDealt: Int = 0
    @Published var runningCount: Int = 0
    
    // Betting state
    @Published var playerBet: Int = 0
    @Published var betChips: [Int] = []
    @Published var lastBet: Int? = nil
    
    // Debug and overlay state
    @Published var showZeroChipsOverlay: Bool = false
    @Published var debugPayoutMessage: String? = nil
    @Published var showDebugPayout: Bool = false
    
    // Animation state for RegularModeView
    @Published var isDealing: Bool = false
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
        !isSplit && playerHand.count == 2 && playerHand[0].rank.value == playerHand[1].rank.value && playerBet * 2 <= XPChipManager.shared.userChips
    }
    
    var canDoubleDown: Bool {
        !doubledDown && !isSplit && playerHand.count == 2 && playerBet * 2 <= XPChipManager.shared.userChips
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
        cardsDealt = 0
        runningCount = 0
        playerBet = 0
        betChips = []
        lastBet = nil
        isDealing = false
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
        isDealing = false
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