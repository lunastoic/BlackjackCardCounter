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
    @Published var countingRevealedDealerCards: Set<Int> = [] // Cards that are fully revealed for counting purposes
    @Published var lastPayout: Int = 0
    @Published var actualWinnings: Int = 0
    @Published var winningAmount: Int = 0
    @Published var displayBetAmount: Int = 0 // For display purposes when betting state is cleared
    @Published var cardsDealt: Int = 0
    @Published var runningCount: Int = 0
    @Published var isTrainingMode: Bool = false
    @Published var numberOfDecks: Int = 0
    @Published var currentMap: Map? = nil // Current map for asset configuration
    
    // Betting state
    @Published var playerBet: Int = 0
    @Published var betChips: [Int] = []
    @Published var originalLargestChip: Int? = nil // Store the largest chip before consolidation for gameplay minimization
    @Published var displayChip: Int? = nil // SINGLE chip to display during gameplay - set IMMEDIATELY when deal starts, never modified during gameplay
    @Published var additionalBetChips: [Int] = [] // Right-side stack for double down/split
    @Published var doubleDownChipsHand2: [Int] = [] // Double down chips for Hand 2 (left)
    @Published var doubleDownChipsHand1: [Int] = [] // Double down chips for Hand 1 (right)
    @Published var savedLoseChips: [Int] = [] // Chips saved for lose animation
    @Published var lastBet: Int? = nil
    @Published var splitHandBets: [Int] = [] // Individual bet amounts for each split hand
    @Published var doubledDownHandIndex: Int? = nil // Track which split hand was doubled down (0 or 1)
    @Published var hideBetChipsDuringLoseAnimation: Bool = false // Hide bet chips during lose animation
    @Published var maxBet: Int = 1_000 // Maximum bet per hand (default, set from map)
    
    // Chip selection positions (from GeometryReader) - kept for potential future use
    @Published var chipSelectionPositions: [Int: CGPoint] = [:] // Chip Value -> Position
    
    // Fixed positions for chip animation (like card deck position)
    @Published var chipSelectionAreaPosition: CGPoint = .zero // Where chips are selected
    @Published var bettingAreaPosition: CGPoint = .zero // Where chips are placed
    
    // Debug and overlay state
    @Published var showZeroChipsOverlay: Bool = false
    @Published var debugPayoutMessage: String? = nil
    @Published var showDebugPayout: Bool = false
    @Published var showPlaceChipNotification: Bool = false
    @Published var showPostGameButtons: Bool = false // Track when to show redo bet, deal cards, auto play buttons
    @Published var showResultNotification: Bool = true // Track when to show win/lose notifications
    @Published var userPlacedCurrentBet: Bool = false // True only when user explicitly placed/redo bet this round
    @Published var autoCollectWinningsToggle: Bool = false // Triggers animation to collect winnings back to user
    @Published var isAutoCollectingWinnings: Bool = false // True while chips animate back to chip selection
    
    // Deck shuffling state
    @Published var showShufflingNotification: Bool = false // Show "shuffling deck after this round" notification
    @Published var needsShuffling: Bool = false // Track if deck needs to be shuffled after current round
    @Published var originalDeck: [Card] = [] // Store original deck for shuffling
    
    // Animation state for RegularModeView
    @Published var isDealing: Bool = false
    @Published var isProcessingAction: Bool = false
    @Published var lastActionTime: Date = Date()
    @Published var deckFrame: CGRect = .zero
    @Published var deckPosition: CGPoint = .zero // Used for dealing cards (shoe position)
    @Published var deckCollectionPosition: CGPoint = .zero // Used for collecting cards (deck position)
    @Published var animatingCards: [UUID: Card] = [:]
    @Published var animatingCardPositions: [UUID: CGPoint] = [:]
    @Published var animatingCardScales: [UUID: CGFloat] = [:]
    @Published var animatingCardOpacities: [UUID: Double] = [:]
    @Published var cardFlipRotations: [UUID: Double] = [:]
    @Published var cardFlipScales: [UUID: CGFloat] = [:]
    
    // Collection animation state
    @Published var collectingCardIds: Set<UUID> = []
    @Published var arrivalOrder: [UUID: Int] = [:]
    @Published var isCollectingPhase: Bool = false
    @Published var cardsJustCollected: Bool = false // Track when cards were just collected (for training mode button positioning)
    @Published var hasEverDealtCards: Bool = false // Track if cards have ever been dealt (for stable button positioning)
    @Published var isTransitioningChips: Bool = false // Track when chips are transitioning from stacked to single
    @Published var chipsMinimized: Bool = false // Track when chips have been minimized for gameplay (prevents showing intermediate states)
    
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
        print("🃏 🔴 canSplit called: isSplit=\(isSplit), handCount=\(playerHand.count), bet=\(playerBet), maxBet=\(maxBet), chips=\(XPChipManager.shared.userChips)")
        
        let hasEnoughChips = playerBet <= XPChipManager.shared.userChips
        let withinMaxBet = playerBet <= maxBet // Current bet must be <= max bet (after split it will be 2x max bet max)
        print("🃏 🔴 CHIP VALIDATION: need \(playerBet), have \(XPChipManager.shared.userChips), RESULT: \(hasEnoughChips ? "PASS" : "FAIL")")
        print("🃏 🔴 MAX BET VALIDATION: bet \(playerBet), maxBet \(maxBet), RESULT: \(withinMaxBet ? "PASS" : "FAIL")")
        
        let notSplit = !isSplit
        let correctHandCount = playerHand.count == 2
        
        print("🃏 🔴 ALL VALIDATIONS: notSplit=\(notSplit), correctHandCount=\(correctHandCount), hasEnoughChips=\(hasEnoughChips), withinMaxBet=\(withinMaxBet)")
        
        guard notSplit && correctHandCount && hasEnoughChips && withinMaxBet else {
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
            let hasEnoughChips = activeHandBet <= XPChipManager.shared.userChips
            let withinMaxBet = activeHandBet <= maxBet // Each hand's bet must be <= max bet
            let result = activeHand.count == 2 && hasEnoughChips && withinMaxBet
            print("🎲 canDoubleDown (split): \(result) (handIndex: \(activeHandIndex), cards: \(activeHand.count), handBet: \(activeHandBet), maxBet: \(maxBet), availableChips: \(XPChipManager.shared.userChips))")
            return result
        } else {
            // For regular hands, check if we have enough chips for double down (need playerBet amount more)
            // And check that current bet <= max bet (after doubling it will be 2x max bet max)
            let hasEnoughChips = playerBet <= XPChipManager.shared.userChips
            let withinMaxBet = playerBet <= maxBet // Current bet must be <= max bet
            let result = playerHand.count == 2 && hasEnoughChips && withinMaxBet
            print("🎲 canDoubleDown (regular): \(result) (cards: \(playerHand.count), bet: \(playerBet), maxBet: \(maxBet), availableChips: \(XPChipManager.shared.userChips))")
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
        doubledDownHandIndex = nil
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
        // Only clear betting state if we're not in the middle of a card collection animation
        if !isCollectingPhase {
            playerBet = 0
            betChips = []
            originalLargestChip = nil
            displayChip = nil // Clear display chip
            additionalBetChips = [] // Clear additional bet chips
            doubleDownChipsHand2 = [] // Clear double down chips for Hand 2
            doubleDownChipsHand1 = [] // Clear double down chips for Hand 1
            savedLoseChips = [] // Clear saved chips for lose animation
            displayBetAmount = 0 // Clear display amount when starting new game
            userPlacedCurrentBet = false
            
            // Clear chip selection positions
            chipSelectionPositions.removeAll()
            
            // Clear fixed positions
            chipSelectionAreaPosition = .zero
            bettingAreaPosition = .zero
        } else {
            print("🎯 EndRound: Preserving betting state in resetGame during card collection")
        }
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
        collectingCardIds.removeAll()
        arrivalOrder.removeAll()
        isCollectingPhase = false
        cardsJustCollected = false
        hasEverDealtCards = false
        isTransitioningChips = false
        chipsMinimized = false
        playerCardPositions.removeAll()
        dealerCardPositions.removeAll()
        cardDealPositions.removeAll()
        cardFinalPositions.removeAll()
        cardScale.removeAll()
        deckOffset = 0
        showZeroChipsOverlay = false
        debugPayoutMessage = nil
        showDebugPayout = false
        showPlaceChipNotification = false
        hideBetChipsDuringLoseAnimation = false
        flippedDealerCards.removeAll()
        countingRevealedDealerCards.removeAll()
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
        displayChip = nil // Clear display chip
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
        collectingCardIds.removeAll()
        arrivalOrder.removeAll()
        isCollectingPhase = false
        flippedDealerCards.removeAll()
        countingRevealedDealerCards.removeAll()
        userPlacedCurrentBet = false
    }
} 
