import SwiftUI

struct TrainingModeView: View {
    let map: Map
    
    // Shared game state and managers
    @StateObject private var gameState = BlackjackGameState()
    private let gameEngine = BlackjackGameEngine.shared
    private let bettingManager = BlackjackBettingManager.shared
    private let strategyHelper = BlackjackStrategyHelper.shared
    
    // Training mode specific state
    @AppStorage("trainingDecks") private var numberOfDecks: Int = 6
    @AppStorage("cardUnderglow") private var cardUnderglow: Bool = true
    @State private var showSettings: Bool = false
    @AppStorage("showStrategyHints") private var showStrategyHints: Bool = false
    @State private var showStrategyChart: Bool = false
    @State private var selectedSettingsTab: Int = 0 // 0 = Settings, 1 = Achievements
    @AppStorage("showCardCharts") private var showCardCharts: Bool = false
    @State private var selectedChart: Int = 0 // 0 = Dealt, 1 = Remaining
    
    // Animation state (matching RegularModeView)
    @Namespace private var mgCards
    @State private var tableSize: CGSize = .zero
    @State private var finalPlayerPositions: [UUID: CGPoint] = [:]
    @State private var finalDealerPositions: [UUID: CGPoint] = [:]
    @State private var finalSplitPositions: [[UUID: CGPoint]] = Array(repeating: [:], count: 2)
    @State private var shoeFrame: CGRect = .zero
    @State private var shoePosition: CGPoint = .zero
    // Collect sequencing (now in gameState)
    @State private var visiblePlayerCount: Int = 0
    @State private var visibleDealerCount: Int = 0
    @State private var dealerHoleRevealed: Bool = false
    @State private var discardPile: [Card] = []
    
    // MARK: - Chip Position Helpers
    private struct ChipPositions {
        let hand2BetXOffset: CGFloat
        let hand1BetXOffset: CGFloat
        let hand2DDXOffset: CGFloat
        let hand1DDXOffset: CGFloat
    }
    
    // MARK: - Chip Stack Rendering Helpers (reduce SwiftUI type-check complexity)
    private let chipSize: CGFloat = 44.0
    private let chipSpacing: CGFloat = 45.0 // chipSize (44) + 1
    
    private func chipOffsets(index: Int, horizontal: Bool) -> (x: CGFloat, y: CGFloat) {
        if horizontal {
            return (CGFloat(index) * chipSpacing, 0)
        } else {
            let angle = Double(index) * 0.8
            let radius: CGFloat = 0.5
            return (radius * CGFloat(cos(angle)), radius * CGFloat(sin(angle)))
        }
    }
    
    private func chipStackAnyView(chips: [Int], debugColors: [Color], horizontal: Bool) -> AnyView {
        let sorted = chips.sorted(by: >)
        return AnyView(
            ZStack {
                ForEach(Array(sorted.enumerated()), id: \.offset) { index, chipValue in
                    let offs = chipOffsets(index: index, horizontal: horizontal)
                    ZStack {
                        Circle()
                            .fill(debugColors[index % debugColors.count])
                            .frame(width: chipSize, height: chipSize)
                        ChipView(chip: Chip(value: chipValue))
                    }
                    .offset(x: offs.x, y: offs.y)
                    .zIndex(20000 + Double(index))
                    .opacity(gameState.hideBetChipsDuringLoseAnimation ? 0 : 1)
                    .transition(.identity)
                    .transaction { $0.animation = nil }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 60)
        )
    }
    
    private func computeChipPositions() -> ChipPositions {
        // NOTE: Betting stacks should NOT shift based on win/loss.
        // Only apply a small +7pt nudge while payout chips are being shown/animated.
        let hand2Doubled = !gameState.doubleDownChipsHand2.isEmpty
        let hand1Doubled = !gameState.doubleDownChipsHand1.isEmpty
        let _ = gameState.lastPayout > 0 && gameState.showResultNotification
        let hasRegularDD = !gameState.isSplit && !gameState.additionalBetChips.isEmpty
        let regularUserStackCount: Int = hasRegularDD ? 2 : 1
        let regularPayoutCount: Int = (gameState.lastPayout > 0 && gameState.showResultNotification) ? (hasRegularDD ? 2 : 1) : 0
        let regularTotalCount: Int = regularUserStackCount + regularPayoutCount
        
        // When payout chips are present (while payout chips are animating / placed),
        // shift BOTH stacks per hand slightly right to make room on the left.
        // Tuned so the 2 payout chips per hand fit cleanly on the left.
        let hasPayoutChips = gameState.lastPayout > 0 && gameState.showResultNotification
        let payoutOffset: CGFloat = hasPayoutChips ? 36.0 : 0.0
        
        // Non-split: treat the payout+user stacks as one touching row that stays centered.
        // Row positions: start at -spacing*(total-1)/2; payout chips are first; user stacks follow.
        let nonSplitRowStart: CGFloat = -chipSpacing * CGFloat(max(regularTotalCount - 1, 0)) / 2.0
        let nonSplitFirstUserX: CGFloat = nonSplitRowStart + CGFloat(regularPayoutCount) * chipSpacing
        // Extra spacing between the two 4-chip groups (Figma mock):
        // push Hand 2 group slightly left, Hand 1 group slightly right.
        let hand2GroupTweak: CGFloat = hasPayoutChips ? -1.0 : 0.0
        let hand1GroupTweak: CGFloat = hasPayoutChips ? 7.0 : 0.0
        
        // Hand 2 bet chips: Fixed position (no win/loss shift), plus payout nudge
        let hand2BetXOffset: CGFloat = gameState.isSplit ? 
            (-70.0 + payoutOffset + hand2GroupTweak) : (hasRegularDD ? (nonSplitFirstUserX + chipSpacing) : nonSplitFirstUserX)
        
        // In split: Hand 1 bet stack on the right.
        // In non-split: additionalBetChips represents the double-down stack; it should touch the LEFT of the main bet stack.
        let hand1BetXOffset: CGFloat = gameState.isSplit ? 
            (70.0 + (hand1Doubled ? 10.0 : 0.0) + payoutOffset + hand1GroupTweak) :
            (hasRegularDD ? nonSplitFirstUserX : 0.0)
        
        // Hand 2 double down chips: Position to the LEFT of bet chips (44 points to the left, touching)
        // Bet chips are at -70.0, so DD chips at -70.0 - 44.0 = -114.0
        // Also offset right when payout chips present
        let hand2DDXOffset: CGFloat = gameState.isSplit ? 
            (hand2Doubled ? (-114.0 + payoutOffset + hand2GroupTweak) : (-110.0 + payoutOffset + hand2GroupTweak)) : 0.0
        
        // Hand 1 double down chips: Also offset right when payout chips present
        let hand1DDXOffset: CGFloat = gameState.isSplit ? 
            (hand1Doubled ? (80.0 + 45.0 + payoutOffset + hand1GroupTweak) : (30.0 + payoutOffset + hand1GroupTweak)) : 120.0
        
        return ChipPositions(
            hand2BetXOffset: hand2BetXOffset,
            hand1BetXOffset: hand1BetXOffset,
            hand2DDXOffset: hand2DDXOffset,
            hand1DDXOffset: hand1DDXOffset
        )
    }
    
    var body: some View {
        GeometryReader { tableGeo in
        ZStack {
            // Background image - ensure it covers the entire screen
            Image("GreenSuede")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .ignoresSafeArea(.all, edges: .all)
            
            // Shoe and Deck assets - EXACT COPY FROM REGULAR MODE (behind everything)
            VStack {
                Spacer().frame(height: 100) // Position at top like regular mode
                
                HStack {
                    // Left side: Deck
                    VStack {
                        Image("DeckCover")
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(width: 48, height: 72)
                            .shadow(radius: 4)
                            .offset(x: -5, y: 25) // Shift deck cover 5 points to the left and 25 points down
                        Text("Deck")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .offset(x: -5, y: 25) // Shift "Deck" text 5 points to the left and 25 points down
                    }
                    
                    Spacer()
                    
                    // Right side: Shoe
                    VStack {
                        Image("DeckCover")
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(width: 48, height: 72)
                            .shadow(radius: 4)
                            .offset(y: 25) // Shift shoe 25 points down
                            .overlay(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            let f = geometry.frame(in: .named("table"))
                                            shoeFrame = f
                                            shoePosition = CGPoint(x: f.midX, y: f.midY)
                                            gameState.deckFrame = f
                                            gameState.deckPosition = shoePosition // dealing origin
                                        }
                                        .onChange(of: geometry.frame(in: .named("table"))) { newF in
                                            shoeFrame = newF
                                            shoePosition = CGPoint(x: newF.midX, y: newF.midY)
                                            gameState.deckFrame = newF
                                            gameState.deckPosition = shoePosition
                                        }
                                }
                            )
                        Text("Shoe")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .offset(y: 25) // Shift "Shoe" text 25 points down
                    }
                }
                .padding(.horizontal, 32)
                
            Spacer() // Push to top
        }
        .offset(y: -57) // Shift deck and shoe assets up by 57 points
        .zIndex(1) // Above background but below card counter meter
            
            // Background text - arched like a rainbow (behind everything)
            GeometryReader { geo in
                ZStack {
                    // "Luna Luxe Casino" - top arc (matching RegularModeView)
                    createArchedText(
                        text: "Luna Luxe Casino",
                        fontSize: 36,
                        width: geo.size.width * 0.8,
                        height: 80,
                        centerX: geo.size.width / 2,
                        centerY: geo.size.height / 2 - 175
                    )
                    
                    // "Blackjack pays 3 to 2" - middle arc (matching RegularModeView)
                    createArchedText(
                        text: "Blackjack pays 3 to 2",
                        fontSize: 24,
                        width: geo.size.width * 0.7,
                        height: 60,
                        centerX: geo.size.width / 2,
                        centerY: geo.size.height / 2 - 145
                    )
                    
                    // "Dealer must hit on soft 17" - bottom arc (matching RegularModeView)
                    createArchedText(
                        text: "Dealer must hit on soft 17",
                        fontSize: 16,
                        width: geo.size.width * 0.75,
                        height: 50,
                        centerX: geo.size.width / 2,
                        centerY: geo.size.height / 2 - 115
                    )
                }
                .offset(y: -11) // Shift all background text up by 11 points
                .allowsHitTesting(false)
            }
            .zIndex(0)
            
            VStack(spacing: 0) {
                // Game Header
                ZStack(alignment: .topTrailing) {
                    GameHeaderView()
                    
                    if gameState.showDebugPayout, let msg = gameState.debugPayoutMessage {
                        Text(msg)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(14)
                            .shadow(radius: 8)
                            .padding(.trailing, 8)
                            .padding(.top, 2)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(2)
                    }
                }
                
                                 // Card Counter
                 ZStack {
                     CardCounterView(
                         gameState: gameState,
                         xOffset: UIDevice.current.userInterfaceIdiom == .pad ? -330 : -154,
                         yOffset: UIDevice.current.userInterfaceIdiom == .pad ? 510 : 443
                     )
                }
                
                // Visualizers at the top
                VStack(spacing: 8) {
                    CardCounterMeterTM(gameState: gameState)
                    
                    if showCardCharts {
                        VStack(spacing: 4) {
                            Picker("Chart", selection: $selectedChart) {
                                Text("Dealt").tag(0)
                                Text("Remaining").tag(1)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 180)
                            .padding(.bottom, 2)
                            
                            ZStack {
                                if selectedChart == 0 {
                                    BarChartView(
                                        data: strategyHelper.cardsDealtByValue(
                                            dealtPlayerCards: gameState.dealtPlayerCards,
                                            dealtDealerCards: gameState.dealtDealerCards,
                                            flippedDealerCards: gameState.flippedDealerCards,
                                            countingRevealedDealerCards: gameState.countingRevealedDealerCards
                                        ),
                                        maxBarHeight: 36,
                                        barColor: .green,
                                        title: "Cards Dealt",
                                        yLabel: "# Dealt"
                                    )
                                } else {
                                    BarChartView(
                                        data: strategyHelper.cardsRemainingByValue(deck: gameState.deck),
                                        maxBarHeight: 36,
                                        barColor: .blue,
                                        title: "Cards Remaining",
                                        yLabel: "# Left"
                                    )
                                }
                            }
                            .background(Color.black.opacity(0.18))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.top, 12)
                
                Spacer().frame(height: 8)
                
                // iPhone-specific spacing above player cards
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Spacer().frame(height: 15)
                }
                
                // Player and Dealer cards area (offset to match RegularModeView positioning)
                GeometryReader { geo in
                    let _ = max(max(gameState.dealtPlayerCards.count, gameState.isSplit ? gameState.splitHands.flatMap { $0 }.count : 2), max(gameState.dealtDealerCards.count, 2))
                    let _: CGFloat = 60 // Fixed card width to prevent layout shifts
                    
                    // Update table size when geometry changes
                    let _ = DispatchQueue.main.async {
                        if tableSize != geo.size {
                            tableSize = geo.size
                        }
                    }
                    
                    
                    VStack(spacing: 0) {
                        // Dealer cards
                        VStack(spacing: 8) {
                            VStack(spacing: 4) {
                                Text("Dealer")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(dealerValueLabel())
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                            
                            // Hidden placeholders to keep layout stable (like RegularModeView)
                            HStack(spacing: 8) {
                                ForEach(Array(gameState.dealtDealerCards.enumerated()), id: \.offset) { idx, card in
                                TrainingModeFlipCardView(card: card,
                                        isFlipped: gameState.flippedDealerCards.contains(idx),
                                            width: CardMetrics.cardSize.width, glowWidth: 8)
                                        .opacity(0.0)
                                        .transaction { $0.animation = nil }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        // Fixed spacing between dealer and player (like RegularModeView)
                        Spacer().frame(height: 32)
                        
                        // Player - PLACEHOLDER (real Player title moved to isolated ZStack layer)
                        VStack(spacing: 8) {
                            // Placeholder for Player title - will be drawn in isolated layer
                            Color.clear.frame(height: 20)
                            
                            if gameState.isSplit {
                                    // Split labels + hidden placeholders only (real cards are drawn in overlay)
                                    VStack(spacing: 4) {
                                        // Placeholder for split yellow number - will be drawn in isolated layer
                                        Color.clear.frame(height: 20)

                                HStack(spacing: 24) {
                                    ForEach(gameState.splitHands.indices, id: \.self) { idx in
                                        VStack {
                                            HStack {
                                                        Text("Hand \(idx == 1 ? 1 : 2)\(isHandActive(idx) ? " (Active)" : "")")
                                                            .font(.headline).foregroundColor(isHandActive(idx) ? .yellow : .gray)
                                                            .offset(y: -22) // Shift up by 22 points away from cards
                                                        Text(gameEngine.getHandValueText(gameState.splitHands[idx]))
                                                            .font(.system(size: 17, weight: .bold))
                                                    .foregroundColor(.yellow)
                                                            .offset(y: -22) // Shift up by 22 points away from cards
                                            }
                                            
                                                    // Fixed-width placeholder (prevents layout shifts)
                                                    let handCards = gameState.splitHands[idx]
                                                    
                                                    // Ask the layout for the hand's framed width (already constrained)
                                                    let frame = SplitCardLayout.shared.getSplitHandFrame(
                                                        handIndex: idx,
                                                        cardCount: handCards.count,
                                                        cardSize: CardMetrics.cardSize,
                                                        tableSize: tableSize
                                                    )
                                                    
                                                    // Reserve only this space; no invisible cards that expand with count
                                                    Color.clear
                                                        .frame(width: frame.width, height: frame.height)
                                                }
                                        }
                                    }
                                }
                            } else {
                                    // Placeholder for non-split yellow number - will be drawn in isolated layer
                                    Color.clear.frame(height: 20)

                                // Hidden placeholders for non-split player - ALWAYS reserve space
                                HStack(spacing: 8) {
                                    // Always show 2 placeholder cards to reserve space
                                        ForEach(0..<2, id: \.self) { _ in
                                            Color.clear
                                                .frame(width: CardMetrics.cardSize.width, height: CardMetrics.cardSize.height)
                                        }
                                    }
                                    .frame(minWidth: 200, minHeight: 90)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 140)
                        // Removed conditional offset that was causing betting area to move during card dealing
                        
                        // Fixed spacing after player section (exactly like RegularModeView)
                        Spacer().frame(height: 32)
                        
                        // iPad-specific spacing above action buttons (like RegularModeView)
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Spacer().frame(height: CardMetrics.extraSpacerHeight(isIPad: true))
                        }
                        
                        // Shuffling notification is now handled as overlay - removed from here
                        
                        // Removed extra spacers that Regular Mode doesn't have:
                        // - Removed Spacer().frame(height: 24)
                        // - Removed duplicate Spacer().frame(height: 32)
                        // Now matches Regular Mode spacing exactly
                        
                        // Removed betting area from main VStack - now positioned as separate overlay
                        
                        // Removed action buttons from main VStack to prevent betting area from being pushed down
                        
                        // Removed Deal Cards button from main VStack - now positioned as overlay under chip selection
                        
            }
            .overlay(
                // Shuffling notification overlay - doesn't affect layout
                ShufflingNotification(gameState: gameState)
                    .zIndex(1000) // High z-index to appear on top
            )
                }
                .onAppear {
                    gameEngine.resetDeck(gameState: gameState, numberOfDecks: numberOfDecks)
                    // Ensure all cards are visible in training mode
                    visiblePlayerCount = gameState.playerHand.count
                    visibleDealerCount = gameState.dealerHand.count
                }
                .onChange(of: gameState.playerHand.count) { handCount in
                    // Recalculate player card positions when hand count changes (like regular mode)
                    CardPositioning.recalculateAllCardPositions(
                        isPlayerCard: true,
                        newCount: handCount,
                        tableSize: tableSize,
                        dealtPlayerCards: gameState.dealtPlayerCards,
                        dealtDealerCards: gameState.dealtDealerCards,
                        finalPlayerPositions: &finalPlayerPositions,
                        finalDealerPositions: &finalDealerPositions
                    )
                    
                    // In training mode, keep visible count static to prevent layout shifts
                    // visiblePlayerCount is set once on appear and stays static
                    let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
                    
                    // Auto-play logic for training mode when hand count changes
                    if trainingModeEnabled && gameState.isPlayerTurn && handCount >= 2 {
                        // Wait for processing to complete, then check auto-play
                        waitForProcessingToComplete()
                    }
                }
                .onChange(of: gameState.isPlayerTurn) { isPlayerTurn in
                    // Auto-play logic for training mode when player turn starts
                    let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
                    
                    if trainingModeEnabled && !isPlayerTurn {
                        // If dealer hasn't started playing after a delay, something is wrong
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if gameState.flippedDealerCards.count <= 1 && gameState.resultMessage == nil {
                                // Dealer hasn't started playing after 2 seconds
                            }
                        }
                    }
                    
                    if trainingModeEnabled && isPlayerTurn && gameState.playerHand.count >= 2 {
                        // Add delay to ensure dealing is complete (speed adjusted with safe minimums)
                        DispatchQueue.main.asyncAfter(deadline: .now() + safeDelay(0.5)) {
                            if gameState.isPlayerTurn && !gameState.isDealing {
                                print("🎓 Training Mode: Player turn started, checking hand...")
                                checkAndAutoPlay()
                            }
                        }
                    }
                }
                .onChange(of: gameState.resultMessage) { resultMessage in
                    // Auto-start next hand in continuous training mode
                    let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
                    
                    if trainingModeEnabled && isContinuousAutoPlay && resultMessage != nil {
                        let delay = safeDelay(1.5) // Reduced from 3.0 to 1.5 seconds
                        print("🎓 Hand finished with result: \(resultMessage ?? "nil"), starting next hand in \(delay) seconds...")
                        
                        // Wait a bit to see the result, then clear and deal next hand (speed adjusted with safe minimums)
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            // Check if stop was requested or auto play is disabled
                            if self.stopRequested || !self.isContinuousAutoPlay {
                                // Auto play was stopped, reset flags and return to normal mode
                                self.isAutoPlaying = false
                                self.isContinuousAutoPlay = false
                                self.stopRequested = false
                                self.stopButtonPressed = false
                                // Disable training mode to return to normal betting interface
                                UserDefaults.standard.set(false, forKey: "trainingModeEnabled")
                                // Clear all game state to show clean betting interface
                                gameState.resultMessage = nil
                                gameState.playerHand = []
                                gameState.dealerHand = []
                                gameState.dealtPlayerCards = []
                                gameState.dealtDealerCards = []
                                gameState.visuallyRevealedDealerHand = []
                                gameState.flippedDealerCards = []
                                gameState.countingRevealedDealerCards = []
                                gameState.showNextHand = false
                                gameState.isPlayerTurn = true
                                gameState.playerBet = 0
                                gameState.betChips = []
                                gameState.lastBet = nil
                                return 
                            }
                            
                            // Clear the current hand
                            gameState.resultMessage = nil
                            gameState.playerHand = []
                            gameState.dealerHand = []
                            gameState.dealtPlayerCards = []
                            gameState.dealtDealerCards = []
                            gameState.visuallyRevealedDealerHand = []
                            gameState.flippedDealerCards = []
                            gameState.showNextHand = false
                            gameState.isPlayerTurn = true
                            gameState.playerBet = 0
                            gameState.betChips = []
                            
                            // Deal next hand
                            self.dealNextTrainingHand()
                        }
                    }
                }

            .onDisappear {
                // Return any unplayed bets when leaving the view
                if gameState.playerBet > 0 && !gameState.showNextHand && gameState.resultMessage == nil {
                    print("🔄 Training Mode: Returning unplayed bet of $\(gameState.playerBet)")
                    XPChipManager.shared.updateChips(gameState.playerBet)
                    gameState.playerBet = 0
                    gameState.betChips = []
                }
            }
            }
            
            // Floating button to open strategy chart
            VStack {
                HStack {
                    Button(action: { showStrategyChart = true }) {
                        Image(systemName: "lightbulb.fill")
                            .font(.fixedSystem(size: 28, weight: .regular))
                            .foregroundColor(.yellow)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                            .shadow(radius: 6)
                    }
                    .padding(.leading, 8)
                    .offset(y: -230)
                    
                    Spacer()
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.fixedSystem(size: 28, weight: .regular))
                            .foregroundColor(.white)
                            .padding()
                            .shadow(radius: 6)
                    }
                    .padding(.trailing, 8)
                    .offset(y: -240)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .offset(y: -30)
            
        }
        .overlay {
            // ISOLATED PLAYER TITLE LAYER - Completely separate from GeometryReader
            ZStack {
                // Player title - completely isolated from card animations
                Text("Player")
                    .font(.fixedSystem(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .position(
                        x: UIScreen.main.bounds.width / 2, 
                        y: gameState.dealtPlayerCards.isEmpty && gameState.dealtDealerCards.isEmpty ? 360 : 360
                    )
                    .offset(y: -10) // Shift up by 10 points total (5 + 5)
                    .zIndex(10000) // Highest z-index
                
                // Yellow number - completely isolated from card animations (only show for non-split hands)
                if !gameState.isSplit {
                    Text(playerValueLabel())
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.yellow)
                        .offset(y: -6)
                        .position(
                            x: UIScreen.main.bounds.width / 2, 
                            y: gameState.dealtPlayerCards.isEmpty && gameState.dealtDealerCards.isEmpty ? 390 : 390
                        )
                        .offset(y: -10) // Shift up by 10 points total (5 + 5)
                        .zIndex(10000) // Highest z-index
                }
            }
            .allowsHitTesting(false) // Don't interfere with touch events
        }
        .overlay {
            if gameState.showZeroChipsOverlay {
                ZeroChipsOverlay(isPresented: $gameState.showZeroChipsOverlay)
            }
            
            
            // Define trainingModeEnabled at the top of overlay scope
            let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
            
            
            
            // ---- Completely Independent Training Mode Buttons ----
                        if trainingModeEnabled {
                if !isContinuousAutoPlay && !gameState.isDealing && (gameState.resultMessage != nil || !gameState.showNextHand) {
                                Button(action: {
                                    // Start continuous auto-play
                                    startContinuousAutoPlay()
                                }) {
                                    Text("Start Training Hand")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                    .frame(maxWidth: .infinity)
                    .clipped()
                    // Removed absolute positioning - now uses natural VStack flow
                    .zIndex(24) // Below betting area but above action buttons
                    .allowsHitTesting(true)
                    .background(Color.clear)
                    .clipped()
                            }
                            
                            // Stop button during continuous auto-play
                            if isContinuousAutoPlay {
                                VStack(spacing: 16) {
                                    Button(action: {
                                        stopButtonPressed = true
                                        stopContinuousAutoPlay()
                                    }) {
                                        Text("Stop")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 32)
                                            .padding(.vertical, 12)
                                .background(stopButtonPressed ? Color.gray : Color(hex: "ff0000"))
                                            .cornerRadius(12)
                                    }
                                    
                                    // Speed control wheel
                                    VStack(spacing: 8) {
                                        Text("Speed")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 8) {
                                            Image(systemName: "tortoise.fill")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            Slider(
                                                value: sliderSpeedBinding,
                                                in: 0.3...3.0,
                                                step: 0.1,
                                                onEditingChanged: { editing in
                                                    isDraggingSpeed = editing
                                                    if editing {
                                                        print("🎮 Speed slider: Started dragging")
                                                    } else {
                                                        // Commit the speed change on release
                                                        autoPlaySpeed = 3.3 - tempSliderSpeed
                                                        print("🎮 Speed slider: Released, new speed = \(autoPlaySpeed)")
                                                    }
                                                }
                                            )
                                            .frame(width: 120)
                                            .accentColor(.yellow)
                                            
                                            Image(systemName: "hare.fill")
                                                .font(.caption)
                                                .foregroundColor(.yellow)
                                        }
                                        
                                        Text(speedLabel(isDraggingSpeed ? (3.3 - tempSliderSpeed) : autoPlaySpeed))
                                            .font(.caption)
                                            .foregroundColor(isDraggingSpeed ? .orange : .yellow)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(12)
                                }
                    // Removed absolute positioning - now uses natural VStack flow
                    .zIndex(24) // Below betting area but above action buttons
                    .allowsHitTesting(true)
                    .background(Color.clear)
                    .clipped()
                    .offset(y: 100) // Push down to avoid overlapping with user cards
                }
            }
            
            
            // ---- Action Buttons Overlay (ABSOLUTE POSITION) ----
            if gameState.isPlayerTurn && gameState.playerHand.count >= 2 && !isContinuousAutoPlay {
                // Check if current active hand has blackjack or is busted (don't show buttons if so)
                let activeHasBlackjack = gameState.isSplit && 
                    gameEngine.isBlackjack(gameState.splitHands[gameState.activeHandIndex])
                
                let playerBusted = gameState.isSplit ? 
                    gameEngine.isBust(gameState.splitHands[gameState.activeHandIndex]) :
                    gameEngine.isBust(gameState.playerHand)
                
                if !activeHasBlackjack && !playerBusted {
                    BlackjackActionButtons(
                        gameState: gameState,
                        gameEngine: gameEngine,
                        showStrategyHints: showStrategyHints,
                        getPerfectStrategyAction: {
                            strategyHelper.getPerfectStrategyAction(
                                playerHand: gameState.activeHand,
                                dealerHand: gameState.dealerHand
                            )
                        }
                    )
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.75)
                    .zIndex(998) // Below betting area
                }
            }
            
            // ---- Deal Cards Button Overlay (ABSOLUTE POSITION) ----
            // Hide during dealer turn (flipping cards) or when hand is in progress
            let dealerIsFlipping = !gameState.isPlayerTurn && !gameState.dealerHand.isEmpty && !gameState.isDealing
            let _ = gameState.isDealing || gameState.isProcessingAction || dealerIsFlipping
            
            // ALWAYS show buttons when chip selection is visible - simplified logic
            let chipSelectionVisible = !gameState.showNextHand
            let showingResult = gameState.resultMessage != nil && gameState.showResultNotification
            let isActiveGameplay = (gameState.playerHand.count >= 2 && gameState.isPlayerTurn) || isContinuousAutoPlay
            // Hide buttons during dealer's turn ONLY if round is still in progress (showNextHand is true)
            // After round ends (showNextHand is false), show buttons regardless of dealer turn status
            let dealerHasCards = !gameState.dealerHand.isEmpty
            let dealerTurnInProgress = gameState.showNextHand && dealerHasCards && !gameState.isPlayerTurn && !gameState.isDealing
            
            if (chipSelectionVisible || showingResult) && !isActiveGameplay && !dealerTurnInProgress {

                VStack(spacing: 16) {
                    DealNextHandButtons(
                        gameState: gameState,
                        gameEngine: gameEngine,
                        bettingManager: bettingManager,
                        animationCallback: { card, index, completion in
                            // index: 0=P1, 1=D1 (hole), 2=P2, 3=D2 (up)
                            if index == 0 {
                                visiblePlayerCount = 0
                                visibleDealerCount = 0
                                dealerHoleRevealed = false
                                finalPlayerPositions.removeAll()
                                finalDealerPositions.removeAll()
                                finalSplitPositions = Array(repeating: [:], count: 2)
                            }

                            let isPlayer = (index == 0 || index == 2)
                            let slotIndex: Int = isPlayer ? (index == 0 ? 0 : 1) : (index == 1 ? 0 : 1)

                            let midX = tableSize.width * 0.5
                            let startX = midX - (CardMetrics.cardSpacing / 2)
                            let x = startX + CGFloat(slotIndex) * CardMetrics.cardSpacing
                            let y = CardPositioning.yForHand(isPlayer: isPlayer, size: tableSize)
                            let destination = CGPoint(x: x, y: y)

                            if isPlayer { finalPlayerPositions[card.id] = destination }
                            else { finalDealerPositions[card.id] = destination }

                            let shouldFlip = (index != 1)
                            CardAnimator.animateDeal(
                                card: card,
                                to: destination,
                                shouldFlip: shouldFlip,
                                deckPosition: gameState.deckPosition,
                                gameState: gameState
                            ) {
                                withAnimation(.easeInOut(duration: 0.001)) { completion() }
                                CardAnimator.cleanupAnimatedCard(
                                    card.id,
                                    gameState: gameState
                                )
                                if isPlayer { 
                                    visiblePlayerCount += 1 
                                } else { 
                                    visibleDealerCount += 1 
                                }
                            }
                        }
                    )
                }
                // Shift down slightly to match Regular Mode spacing relative to chip selection
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.8 + 4)
                .zIndex(997) // Below action buttons
            }
            
            // ---- Animated and Static Cards Overlay ----
            TrainingModeAnimatedCardsOverlay(
                animatingCards: gameState.animatingCards,
                animatingCardPositions: gameState.animatingCardPositions,
                cardFlipRotations: gameState.cardFlipRotations,
                arrivalOrder: gameState.arrivalOrder,
                collectingCardIds: gameState.collectingCardIds,
                isCollectingPhase: gameState.isCollectingPhase,
                dealtPlayerCards: gameState.dealtPlayerCards,
                dealtDealerCards: gameState.dealtDealerCards,
                flippedDealerCards: gameState.flippedDealerCards,
                finalPlayerPositions: finalPlayerPositions,
                finalDealerPositions: finalDealerPositions,
                tableSize: tableSize,
                mgCards: mgCards,
                isSplit: gameState.isSplit
            )
            .offset(y: gameState.isSplit ? 17 : 27) // Move up 10 points when split (27 - 10 = 17), otherwise 27 points down
            .allowsHitTesting(false)
            
            // Split cards overlay (copied from RegularModeView)
            if gameState.isSplit {
                ZStack {
                    // Static split cards
                    ForEach(gameState.splitHands.indices, id: \.self) { handIdx in
                        ForEach(Array(gameState.splitHands[handIdx].enumerated()), id: \.offset) { cIdx, card in
                            if !gameState.animatingCards.keys.contains(card.id) {
                                let pos = finalSplitPositions[handIdx][card.id] ?? CardPositioning.splitStaticPosition(handIndex: handIdx, cardIndex: cIdx, totalCards: gameState.splitHands[handIdx].count, tableSize: tableSize)
                                let zIndex = SplitCardLayout.shared.getSplitCardZIndex(handIndex: handIdx, cardIndex: cIdx)
                                TrainingModeFlipCardView(card: card, isFlipped: true, width: CardMetrics.cardSize.width, glowWidth: 8)
                                    .matchedGeometryEffect(id: card.id, in: mgCards)
                                    .position(pos)
                                    .zIndex(zIndex)
                                    .opacity(gameState.collectingCardIds.contains(card.id) ? 0 : 1)
                                    .allowsHitTesting(false)
                                    .transition(.identity)
                            }
                        }
                    }
                    
                    // Animated split cards (in the same overlay)
                    ForEach(Array(gameState.animatingCards.keys), id: \.self) { cardId in
                        if let card = gameState.animatingCards[cardId],
                           let pos = gameState.animatingCardPositions[cardId] {
                            
                            let core = ZStack {
                                Image(card.imageName(isTrainingMode: true))
                                    .resizable()
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .frame(width: CardMetrics.cardSize.width, height: CardMetrics.cardSize.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 3)
                                    .opacity((gameState.cardFlipRotations[cardId] ?? 0) > 90 ? 1 : 0)
                                    .rotation3DEffect(
                                        .degrees((gameState.cardFlipRotations[cardId] ?? 0) - 180),
                                        axis: (x: 0, y: 1, z: 0), perspective: 0.6
                                    )

                                Image("DeckCover")
                                    .resizable()
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .frame(width: CardMetrics.cardSize.width, height: CardMetrics.cardSize.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 3)
                                    .opacity((gameState.cardFlipRotations[cardId] ?? 0) > 0 ? 0 : 1)
                                    .rotation3DEffect(
                                        .degrees(gameState.cardFlipRotations[cardId] ?? 0),
                                        axis: (x: 0, y: 1, z: 0), perspective: 0.6
                                    )
                                    .allowsHitTesting(false)
                                    .zIndex(-1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .allowsHitTesting(false)

                            Group {
                                if gameState.isCollectingPhase { core.position(pos) }
                                else { core.matchedGeometryEffect(id: card.id, in: mgCards).position(pos) }
                            }
                            .allowsHitTesting(false)
                            .zIndex(1000 + Double(gameState.arrivalOrder[cardId] ?? 0)) // Higher z-index for animated cards
                        }
                    }
                }
                .offset(y: 17) // Move up 10 points when split (27 - 10 = 17)
                .allowsHitTesting(false)
            }
            
            // Place Chip Notification - positioned at the very top layer
            PlaceChipNotification(isVisible: $gameState.showPlaceChipNotification)
            
            // Chip Win/Lose Animation - Clean and simple animation system
            ChipWinLoseAnimation(gameState: gameState)
                .ignoresSafeArea(.all)
                .zIndex(99999) // Highest z-index to ensure visibility
            
            // Strategy chart overlay - positioned at the absolute top layer
            if showStrategyChart {
                BlackjackStratChartTM(showStrategyChart: $showStrategyChart)
                    .zIndex(999999) // Highest possible z-index
            }
            
            // Settings overlay - positioned at the absolute top layer
            // ---- COMPLETELY SEPARATE BETTING AREA (NO LAYOUT INTERFERENCE) ----
            if !isContinuousAutoPlay {
                // Pre-compute chip positions using helper function
                let chipPositions = computeChipPositions()
                let centerX = UIScreen.main.bounds.width / 2
                let chipsY = UIScreen.main.bounds.height * 0.7 - 30 - 88 + 50
                let titleY = UIScreen.main.bounds.height * 0.7 - 30 - 88
                let _ = gameState.lastPayout > 0 && gameState.showResultNotification
                // Keep the on-table stacks exactly as-is; only shift their X positions via computeChipPositions().
                let horizontal = false
                
                // Betting Area Title - SEPARATE VStack
                Text("Betting Area")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 24)
                    .padding(.top, 12)
                    .position(x: centerX, y: titleY)
                    .zIndex(1001)
                
                
                // Shared debug palette for chip overlays
                let debugColors: [Color] = [
                    Color(red: 0.5, green: 0, blue: 0),      // dark red
                    Color(red: 1.0, green: 0.4, blue: 0.4),  // light red
                    Color(red: 0.8, green: 0.4, blue: 0.0),  // dark orange
                    Color(red: 1.0, green: 0.65, blue: 0.3), // light orange
                    Color(red: 0.7, green: 0.6, blue: 0.0),  // dark yellow
                    Color(red: 0.9, green: 0.8, blue: 0.3),  // light yellow
                    Color(red: 0.0, green: 0.2, blue: 0.5),  // dark blue
                    Color(red: 0.4, green: 0.6, blue: 1.0)   // light blue
                ]
                
                // Bet Chip Stack (Hand 2 / Left) - Keep using .position() for rendering
                chipStackAnyView(chips: gameState.betChips, debugColors: debugColors, horizontal: horizontal)
                    .position(x: centerX + chipPositions.hand2BetXOffset, y: chipsY)
                    .onAppear {
                        if gameState.isSplit { print("🎰 CHIP STACK (H2 Bet): Fixed left position for split") }
                    }
                .animation(.easeOut(duration: 0.4), value: gameState.resultMessage)
                .zIndex(1001)
                .transaction { $0.animation = nil }
                
                // Additional Bet Chips (Split Hand 1) - SEPARATE ZStack
                if !gameState.additionalBetChips.isEmpty {
                    chipStackAnyView(chips: gameState.additionalBetChips, debugColors: debugColors, horizontal: horizontal)
                        .position(x: centerX + chipPositions.hand1BetXOffset, y: chipsY)
                    .zIndex(1001)
                    .animation(.easeOut(duration: 0.4), value: gameState.resultMessage)
                    .onAppear {
                        if gameState.isSplit { print("🎰 CHIP STACK (H1 Bet): Fixed right position for split") }
                    }
                }
                
                // Double Down Chips for Hand 2 (Left) - SEPARATE ZStack
                if !gameState.doubleDownChipsHand2.isEmpty {
                    chipStackAnyView(chips: gameState.doubleDownChipsHand2, debugColors: debugColors, horizontal: horizontal)
                        .position(x: centerX + chipPositions.hand2DDXOffset, y: chipsY)
                    .zIndex(1001)
                    .animation(.easeOut(duration: 0.4), value: gameState.resultMessage)
                    .onAppear {
                        if gameState.isSplit {
                            print("🎰 CHIP 3 (H2 DD User): Dynamically positioned")
                        }
                    }
                }
                
                // Double Down Chips for Hand 1 (Right) - SEPARATE ZStack
                if !gameState.doubleDownChipsHand1.isEmpty {
                    chipStackAnyView(chips: gameState.doubleDownChipsHand1, debugColors: debugColors, horizontal: horizontal)
                        .position(x: centerX + chipPositions.hand1DDXOffset, y: chipsY)
                    .zIndex(1001)
                    .animation(.easeOut(duration: 0.4), value: gameState.resultMessage)
                    .onAppear {
                        if gameState.isSplit {
                            print("🎰 CHIP 7 (H1 DD User): Dynamically positioned")
                        }
                    }
                }
                
                // Bet Amount Text with Unknown and Return Bet Buttons - SEPARATE ZStack
                ZStack {
                    // Centered Bet Amount Text
                    Text("Bet: $\(gameState.displayBetAmount > 0 ? gameState.displayBetAmount : (gameState.playerBet > 0 ? gameState.playerBet : gameState.displayBetAmount))")
                        .font(.fixedSystem(size: 18, weight: .semibold))
                        .foregroundColor(.yellow)
                        .padding(.vertical, 5)
                    
                    // Unknown Button on the left (Training Mode only) - with autoplay logic
                    HStack {
                        if !isContinuousAutoPlay && !gameState.isDealing && (gameState.resultMessage != nil || gameState.isCollectingPhase || !gameState.showNextHand) && !(gameState.playerHand.count >= 2 && gameState.isPlayerTurn) {
                            Button(action: {
                                // Start auto play mode (same as training mode enabled)
                                UserDefaults.standard.set(true, forKey: "trainingModeEnabled")
                                startContinuousAutoPlay()
                            }) {
                                Text("Autoplay")
                                    .font(.fixedSystem(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "ff0000"))
                                    .cornerRadius(8)
                            }
                        }
                        Spacer()
                    }
                    
                    // Return Bet Button on the right
                    // Hide during dealer turn (flipping cards) or when hand is in progress
                    let dealerIsFlipping = !gameState.isPlayerTurn && !gameState.dealerHand.isEmpty && !gameState.isDealing
                    let handInProgressHere = gameState.isDealing || gameState.isProcessingAction || dealerIsFlipping
                    
                    HStack {
                        Spacer()
                        if !gameState.isAutoCollectingWinnings
                            && !gameState.betChips.isEmpty
                            && !handInProgressHere
                            && (gameState.resultMessage != nil || gameState.isCollectingPhase || !gameState.showNextHand)
                            && !(gameState.playerHand.count >= 2 && gameState.isPlayerTurn)
                            && !isContinuousAutoPlay {
                            Button(action: {
                                bettingManager.returnBet(gameState: gameState)
                            }) {
                                Text("Return Bet")
                                    .font(.fixedSystem(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "ff0000"))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.7 - 30 - 88 + 100)
                .zIndex(1001)
                
                // Win/Lose/Push Notifications - SEPARATE
                if gameState.resultMessage != nil, gameState.showResultNotification {
                    if gameState.lastPayout > 0 {
                        Text("Win $\(gameState.actualWinnings)")
                            .font(.fixedSystem(size: 16, weight: .bold))
                            .foregroundColor(.green)
                            .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.7 - 30 - 88 + 120)
                            .zIndex(1001)
                    } else if gameState.lastPayout < 0 {
                        Text("Lose $\(abs(gameState.lastPayout))")
                            .font(.fixedSystem(size: 16, weight: .bold))
                            .foregroundColor(.red)
                            .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.7 - 30 - 88 + 120)
                            .zIndex(1001)
                    } else {
                        Text("Push $\(gameState.actualWinnings)")
                            .font(.fixedSystem(size: 16, weight: .bold))
                            .foregroundColor(.green)
                            .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.7 - 30 - 88 + 120)
                            .zIndex(1001)
                    }
                }
                
                // User's Available Chips - SEPARATE
                if !gameState.showNextHand {
                    ChipSelectionView(
                        gameState: gameState,
                        bettingManager: bettingManager
                    )
                    .disabled(gameState.isDealing)
                    // Shift down slightly to match Regular Mode spacing under Win/Lose text
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.7 - 30 - 88 + 160 - 1)
                    .zIndex(1001)
                }
            }
            
            if showSettings {
                SettingsOverlay(
                    showSettings: $showSettings,
                    selectedSettingsTab: $selectedSettingsTab,
                    numberOfDecks: $numberOfDecks,
                    cardUnderglow: $cardUnderglow,
                    showStrategyHints: $showStrategyHints,
                    showCardCharts: $showCardCharts,
                    gameState: gameState,
                    gameEngine: gameEngine
                )
                .zIndex(999998) // Second highest z-index (below strategy chart)
            }
        }
        .frame(maxWidth: 1000) // Limit width on larger screens
        .frame(maxWidth: .infinity) // Center the content
        .disableDynamicType()
        .onAppear {
            gameState.isTrainingMode = true
            // Initialize numberOfDecks if not set
            if gameState.numberOfDecks == 0 {
                gameState.numberOfDecks = numberOfDecks
            }
            // Ensure training mode is disabled by default when entering training mode view
            UserDefaults.standard.set(false, forKey: "trainingModeEnabled")
            // Enable strategy hints by default in training mode for the yellow glow effect
            if !UserDefaults.standard.bool(forKey: "showStrategyHints") {
                UserDefaults.standard.set(true, forKey: "showStrategyHints")
                showStrategyHints = true
            }
            // Ensure all cards are visible in training mode
            visiblePlayerCount = gameState.dealtPlayerCards.count
            visibleDealerCount = gameState.dealtDealerCards.count
        }
                .onChange(of: gameState.dealtPlayerCards) { newCards in
            // Clear positions when cards are reset (new game) - like regular mode
            if gameState.dealtPlayerCards.isEmpty {
                finalPlayerPositions.removeAll()
                finalDealerPositions.removeAll()
            }
            // Keep visible count static to prevent layout shifts
            // visiblePlayerCount is set once on appear and stays static
            print("🎓 Training Mode: dealtPlayerCards changed to \(newCards.count) cards - keeping visiblePlayerCount static")
        }
        .onChange(of: gameState.dealtDealerCards) { newCards in
            // Ensure all dealt dealer cards are visible in training mode
            visibleDealerCount = newCards.count
            print("🎓 Training Mode: Updated visibleDealerCount to \(visibleDealerCount) for \(newCards.count) dealt cards")
        }
        .onChange(of: gameState.dealerHand.count) { dealerCount in
            // In training mode, ensure all dealer cards are visible
            let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
            if trainingModeEnabled {
                visibleDealerCount = dealerCount
            }
        }
        .onChange(of: gameState.splitHands) { splitHands in
            // In training mode, ensure all split cards are visible
            let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
            if trainingModeEnabled && gameState.isSplit {
                let totalSplitCards = splitHands.flatMap { $0 }.count
                print("🎓 Training Mode: Split hands changed - total cards: \(totalSplitCards)")
                // Update visiblePlayerCount to show all split cards
                visiblePlayerCount = totalSplitCards
            }
        }
        .coordinateSpace(name: "table")
        .onAppear {
            gameState.isTrainingMode = true
            tableSize = tableGeo.size
            // Deck position will be set by the shoe overlay geometry reader
            // Initialize numberOfDecks if not set
            if gameState.numberOfDecks == 0 {
                gameState.numberOfDecks = numberOfDecks
            }
            _ = UIImage(named: "DeckCover")
            ["AS", "KH", "7D", "9C"].forEach { _ = UIImage(named: $0) }
            gameEngine.resetDeck(gameState: gameState)
            
            // Hit animation callback (matching RegularModeView)
            gameEngine.hitAnimationCallback = { [weak gameState] card, isPlayerCard, completion in
                guard let gameState = gameState else { return }
                
                let currentCount = isPlayerCard ? gameState.dealtPlayerCards.count : gameState.dealtDealerCards.count
                let x = CardPositioning.xForCard(index: currentCount, count: currentCount + 1, size: tableSize)
                let y = CardPositioning.yForHand(isPlayer: isPlayerCard, size: tableSize)
                let destination = CGPoint(x: x, y: y)
                
                CardPositioning.recalculateAllCardPositions(
                    isPlayerCard: isPlayerCard,
                    newCount: currentCount + 1,
                    tableSize: tableSize,
                    dealtPlayerCards: gameState.dealtPlayerCards,
                    dealtDealerCards: gameState.dealtDealerCards,
                    finalPlayerPositions: &finalPlayerPositions,
                    finalDealerPositions: &finalDealerPositions
                )

                CardAnimator.animateHit(
                    card: card,
                    to: destination,
                    deckPosition: gameState.deckPosition,
                    gameState: gameState
                ) {
                    withAnimation(.easeInOut(duration: 0.001)) { 
                        completion() 
                    }
                    CardAnimator.cleanupAnimatedCard(
                        card.id,
                        gameState: gameState
                    )
                    if isPlayerCard { 
                        visiblePlayerCount += 1 
                    } else { 
                        visibleDealerCount += 1 
                    }
                }
            }
            
            // Split animation callback (matching RegularModeView)
            gameEngine.splitAnimationCallback = { [weak gameState] card, handIndex, completion in
                guard let gameState = gameState else { return }
                
                let countBefore = gameState.splitHands[handIndex].count
                let destination = CardPositioning.splitStaticPosition(
                    handIndex: handIndex, 
                    cardIndex: countBefore, 
                    totalCards: countBefore + 1, 
                    tableSize: tableSize
                )
                finalSplitPositions[handIndex][card.id] = destination
                
                print("🎯 Split Animation: card=\(card.rank.rawValue)\(card.suit.rawValue), handIndex=\(handIndex), destination=\(destination), deckPosition=\(gameState.deckPosition)")

                CardAnimator.animateSplit(
                    card: card,
                    to: destination,
                    deckPosition: gameState.deckPosition,
                    gameState: gameState
                ) {
                    CardAnimator.cleanupAnimatedCard(
                        card.id,
                        gameState: gameState
                    )
                    completion()
                }
            }
        }
        .onChange(of: tableGeo.size) { newSize in
            tableSize = newSize
        }
        .onDisappear {
            gameEngine.hitAnimationCallback = nil
            gameEngine.splitAnimationCallback = nil
        }
        }
    }
    
    // State to prevent multiple auto-play actions
    @State private var isAutoPlaying = false
    
    // State for continuous auto-play loop
    @State private var isContinuousAutoPlay = false
    
    // State to track if stop was requested (allows current hand to finish)
    @State private var stopRequested = false
    
    // State to track if stop button was pressed (for visual feedback)
    @State private var stopButtonPressed = false
    
    // Speed control state (1.0 = normal, 0.5 = 2x faster, 2.0 = 2x slower)
    @State private var autoPlaySpeed: Double = 1.0
    
    // Temporary speed while dragging (doesn't affect timing until released)
    @State private var tempSliderSpeed: Double = 2.3 // 3.3 - 1.0 = 2.3 (normal position)
    
    // Track if user is currently dragging the slider
    @State private var isDraggingSpeed: Bool = false
    
    // Layout constants (now using shared CardMetrics)
    
    // Table geometry tracking
    // Visible counts (now using shared state from top)
    
    
    // Binding for the inverted slider (so slow is on left, fast is on right)
    private var sliderSpeedBinding: Binding<Double> {
        Binding(
            get: { self.tempSliderSpeed },
            set: { newValue in
                self.tempSliderSpeed = newValue
                // Only update actual speed when not dragging (on release)
                if !self.isDraggingSpeed {
                    self.autoPlaySpeed = 3.3 - newValue
                }
            }
        )
    }
    
    // Helper function for speed label
    private func speedLabel(_ speed: Double) -> String {
        if speed < 0.6 {
            return "Very Fast"
        } else if speed < 0.9 {
            return "Fast"
        } else if speed < 1.1 {
            return "Normal"
        } else if speed < 1.5 {
            return "Slow"
        } else {
            return "Very Slow"
        }
    }
    
    // MARK: - Layout helpers (now using shared CardPositioning)
    
    // MARK: - Labels (from regular mode)
    private func playerValueLabel() -> String {
        let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
        
        // In training mode, use dealtPlayerCards for score calculation to match displayed cards
        // This fixes the invisible card issue where cards are displayed but not counted in score
        let shown = trainingModeEnabled ? gameState.dealtPlayerCards : Array(gameState.playerHand.prefix(visiblePlayerCount))
        guard !shown.isEmpty else { return "0" }
        return gameEngine.getHandValueText(shown)
    }
    
    private func isHandActive(_ handIndex: Int) -> Bool {
        // Check if this hand is the current active hand
        guard gameState.activeHandIndex == handIndex else { return false }
        
        // Check if the player can still take actions on this hand
        let hand = gameState.splitHands[handIndex]
        
        // If hand has blackjack (21), it's not active
        if gameEngine.isBlackjack(hand) {
            return false
        }
        
        // If hand is busted, it's not active
        if gameEngine.isBust(hand) {
            return false
        }
        
        // If we're in dealer's turn (not player's turn), no hands are active
        if !gameState.isPlayerTurn {
            return false
        }
        
        return true
    }
    
    // Helper function to get safe delay with minimum limits
    private func safeDelay(_ baseDelay: Double) -> Double {
        let adjustedDelay = baseDelay * autoPlaySpeed
        // Set minimum delays to prevent freezing/race conditions
        switch baseDelay {
        case 0.5: return max(adjustedDelay, 0.2) // minimum 0.2s for turn transitions (faster)
        case 1.0: return max(adjustedDelay, 0.3) // minimum 0.3s for actions (faster)
        case 1.2: return max(adjustedDelay, 0.4) // minimum 0.4s for flag resets (faster)
        case 1.5: return max(adjustedDelay, 0.5) // minimum 0.5s for processing (faster)
        case 2.0: return max(adjustedDelay, 0.4) // minimum 0.4s for dealing (much faster)
        case 3.0: return max(adjustedDelay, 0.5) // minimum 0.5s for hand clearing (much faster)
        default: return max(adjustedDelay, 0.2) // default minimum (faster)
        }
    }
    
    // Wait for game engine to finish processing, then trigger auto-play
    private func waitForProcessingToComplete() {
        let baseCheckInterval = 0.15 // Base check interval
        let checkInterval = max(baseCheckInterval, 0.1 * autoPlaySpeed) // Scale with speed, but keep minimum
        
        func checkProcessing() {
            // Double-check that we should still be auto-playing
            let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
            
            guard trainingModeEnabled && (isContinuousAutoPlay || stopRequested) && gameState.isPlayerTurn && !isAutoPlaying else {
                return
            }
            
            if !gameState.isProcessingAction {
                print("🎓 Training Mode: Processing complete, triggering auto-play...")
                
                // Always use a consistent delay to ensure hand is fully updated
                let stabilityDelay = autoPlaySpeed < 0.5 ? 0.4 : safeDelay(0.6)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + stabilityDelay) {
                    // Final check before auto-play
                    if gameState.isPlayerTurn && !self.isAutoPlaying && !gameState.isProcessingAction {
                        // Double-check the hand is properly updated
                        let playerValue = gameEngine.handValue(gameState.playerHand)
                        print("🎓 Training Mode: About to check auto-play with player value: \(playerValue)")
                        print("🎓 Training Mode: Current hand: \(gameState.playerHand.map { "\($0.rank.rawValue) of \($0.suit.rawValue)" })")
                        self.checkAndAutoPlay()
                    }
                }
            } else {
                print("🎓 Training Mode: Still processing, checking again in \(checkInterval)s...")
                DispatchQueue.main.asyncAfter(deadline: .now() + checkInterval) {
                    checkProcessing()
                }
            }
        }
        
        // Start checking after an initial delay that scales with speed
        let initialDelay = autoPlaySpeed < 0.5 ? 0.2 : checkInterval
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
            checkProcessing()
        }
    }
    
    // MARK: - Continuous Auto-Play Functions
    private func startContinuousAutoPlay() {
        print("🎓 Starting continuous auto-play...")
        
        // Return any chips placed on the betting area before starting auto play
        if gameState.playerBet > 0 {
            print("🎓 Returning \(gameState.playerBet) chips before starting auto play...")
            // Return all bet chips to the user
            for chip in gameState.betChips {
                XPChipManager.shared.updateChips(chip)
            }
            // Clear the bet
            gameState.playerBet = 0
            gameState.betChips = []
            print("🎓 Chips returned successfully")
        }
        
        isContinuousAutoPlay = true
        // Sync temp slider position with current speed
        tempSliderSpeed = 3.3 - autoPlaySpeed
        dealNextTrainingHand()
        
        // Start backup monitoring system
        startBackupMonitoring()
    }
    
    // Backup monitoring to ensure auto-play doesn't get stuck
    private func startBackupMonitoring() {
        guard isContinuousAutoPlay else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
            
            if trainingModeEnabled && self.isContinuousAutoPlay && gameState.isPlayerTurn {
                let playerValue = gameEngine.handValue(gameState.playerHand)
                let handCount = gameState.playerHand.count
                
                if handCount >= 2 && playerValue >= 17 && playerValue <= 21 && !self.isAutoPlaying && !gameState.isProcessingAction {
                    // Force stand action if player has 17+ and auto play is stuck
                    gameEngine.standAction(gameState: gameState)
                } else if handCount >= 2 && playerValue < 17 && playerValue > 0 && !self.isAutoPlaying && !gameState.isProcessingAction {
                    self.waitForProcessingToComplete()
                }
            }
            
            // Continue monitoring
            self.startBackupMonitoring()
        }
    }
    
    private func stopContinuousAutoPlay() {
        print("🎓 Stopping continuous auto-play...")
        
        // Set stop requested flag but keep auto play running for current hand
        stopRequested = true
        
        // If no hand is currently in progress, reset immediately
        if gameState.playerHand.isEmpty && gameState.dealerHand.isEmpty {
            print("🎓 No hand in progress - resetting immediately")
            isContinuousAutoPlay = false
            stopRequested = false
            stopButtonPressed = false
            isAutoPlaying = false
            // Disable training mode to return to normal betting interface
            UserDefaults.standard.set(false, forKey: "trainingModeEnabled")
            // Clear all game state to show clean betting interface
            gameState.resultMessage = nil
            gameState.playerHand = []
            gameState.dealerHand = []
            gameState.dealtPlayerCards = []
            gameState.dealtDealerCards = []
            gameState.visuallyRevealedDealerHand = []
            gameState.flippedDealerCards = []
            gameState.countingRevealedDealerCards = []
            gameState.showNextHand = false
            gameState.isPlayerTurn = true
            gameState.playerBet = 0
            gameState.betChips = []
            gameState.lastBet = nil
        } else {
            print("🎓 Hand in progress - will finish current hand then stop")
            // Keep isContinuousAutoPlay = true so current hand continues
            // The result message handler will handle the cleanup when hand finishes
        }
        
        print("🎓 Auto play stop requested - current hand will finish then stop")
    }
    
    private func dealNextTrainingHand() {
        guard isContinuousAutoPlay && !stopRequested else { 
            // Auto play was stopped, reset the auto playing flag
            isAutoPlaying = false
            return 
        }
        
        // Reset auto-play flag for new hand
        isAutoPlaying = false
        
        // Set minimum bet for training mode only if user has placed chips
        if gameState.playerBet == 0 && !gameState.betChips.isEmpty {
            gameState.playerBet = 10
        }
        
        print("🎓 Dealing next training hand...")
        gameEngine.dealInitialCards(
            gameState: gameState,
            useRegularModeAnimation: true,
            animationCallback: { card, index, completion in
                // index: 0=P1, 1=D1 (hole), 2=P2, 3=D2 (up)
                if index == 0 {
                    visiblePlayerCount = 0
                    visibleDealerCount = 0
                    dealerHoleRevealed = false
                    finalPlayerPositions.removeAll()
                    finalDealerPositions.removeAll()
                    finalSplitPositions = Array(repeating: [:], count: 2)
                }

                let isPlayer = (index == 0 || index == 2)
                let slotIndex: Int = isPlayer ? (index == 0 ? 0 : 1) : (index == 1 ? 0 : 1)

                let midX = tableSize.width * 0.5
                let startX = midX - (CardMetrics.cardSpacing / 2)
                let x = startX + CGFloat(slotIndex) * CardMetrics.cardSpacing
                let y = CardPositioning.yForHand(isPlayer: isPlayer, size: tableSize)
                let destination = CGPoint(x: x, y: y)

                if isPlayer { finalPlayerPositions[card.id] = destination }
                else { finalDealerPositions[card.id] = destination }

                let shouldFlip = (index != 1)
                CardAnimator.animateDeal(
                    card: card,
                    to: destination,
                    shouldFlip: shouldFlip,
                    deckPosition: gameState.deckPosition,
                    gameState: gameState
                ) {
                    withAnimation(.easeInOut(duration: 0.001)) { completion() }
                    CardAnimator.cleanupAnimatedCard(
                        card.id,
                        gameState: gameState
                    )
                    if isPlayer { 
                        visiblePlayerCount += 1 
                    } else { 
                        visibleDealerCount += 1 
                    }
                }
            }
        )
        
        // Trigger auto-play after initial cards are dealt (speed adjusted with safe minimums)
        DispatchQueue.main.asyncAfter(deadline: .now() + safeDelay(1.0)) { // Reduced from 2.0 to 1.0 seconds
            guard self.isContinuousAutoPlay else { return }
            print("🎓 Training Mode: Initial deal complete, triggering auto-play...")
            self.checkAndAutoPlay()
        }
    }
    
    // Helper function for training mode auto-play
    private func checkAndAutoPlay() {
        let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
        let playerValue = gameEngine.handValue(gameState.playerHand)
        let isBusted = playerValue > 21
        
        // Check if this is a soft hand (contains Ace counted as 11)
        let hasAce = gameState.playerHand.contains { $0.rank == .ace }
        let _ = gameEngine.getHandValueText(gameState.playerHand)
        
        // Check and auto-play called
        
        // Enhanced guard conditions - allow current hand to continue even if stop requested
        guard trainingModeEnabled && 
              (isContinuousAutoPlay || stopRequested) && 
              gameState.isPlayerTurn && 
              !isAutoPlaying && 
              !gameState.isProcessingAction &&
              gameState.playerHand.count >= 2 else {
            return
        }
        
        // Check for bust first - if busted, don't take any action (game should end automatically)
        if isBusted {
            return
        }
        
        // Set flag to prevent multiple actions
        isAutoPlaying = true
        
        // Auto-stand if player has 17 or higher (and not busted)
        if playerValue >= 17 {
            // Player auto-standing
            
            // For 21 or soft 20, use slightly shorter delay to ensure immediate response
            let standDelay = (playerValue == 21 || (hasAce && playerValue == 20)) ? safeDelay(0.4) : safeDelay(0.5) // Reduced delays
            DispatchQueue.main.asyncAfter(deadline: .now() + standDelay) {
                // Store the state before calling standAction
                let wasPlayerTurn = gameState.isPlayerTurn
                
                gameEngine.standAction(gameState: gameState)
                
                // Check if standAction actually worked (player turn should end)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if gameState.isPlayerTurn == wasPlayerTurn && gameState.isPlayerTurn {
                        // Force the dealer turn manually
                        gameState.isPlayerTurn = false
                    } else if gameState.flippedDealerCards.count <= 1 && gameState.resultMessage == nil {
                        // Force dealer hole card flip
                        gameState.flippedDealerCards.insert(0)
                        if gameState.dealerHand.count > 0 {
                            gameState.visuallyRevealedDealerHand.append(gameState.dealerHand[0])
                        }
                    }
                }
                
                self.isAutoPlaying = false
            }
        } else if playerValue < 17 {
            // Auto-hit if player has less than 17 (and not busted)
            DispatchQueue.main.asyncAfter(deadline: .now() + safeDelay(0.5)) { // Reduced from 1.0 to 0.5 seconds
                gameEngine.hitAction(gameState: gameState)
                
                // Add verification that hit worked
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Reduced from 1.0 to 0.5 seconds
                    let _ = gameState.playerHand.count
                    let newValue = gameEngine.handValue(gameState.playerHand)
                    
                    // If we should continue hitting but auto-play stopped, force it
                    if newValue < 17 && newValue <= 21 && gameState.isPlayerTurn && !self.isAutoPlaying {
                        self.waitForProcessingToComplete()
                    }
                }
            }
            // Reset flag after a short delay to allow for next auto-play check (speed adjusted with safe minimums)
            DispatchQueue.main.asyncAfter(deadline: .now() + safeDelay(0.6)) { // Reduced from 1.2 to 0.6 seconds
                self.isAutoPlaying = false
            }
        } else {
            // Safety: reset flag if no action taken
            isAutoPlaying = false
        }
    }

    
    private func dealerValueLabel() -> String {
        let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
        
        // If no dealer cards are dealt yet, show "?"
        if gameState.dealerHand.isEmpty {
            return "?"
        }
        
        // If dealer cards are showing deck covers (face-down), show "?"
        // Check if any dealer cards are actually face-up by looking at flippedDealerCards
        if gameState.flippedDealerCards.isEmpty {
            return "?"
        }
        
        if trainingModeEnabled && gameState.isPlayerTurn {
            // In training mode during player turn, only show the up card (second card)
            if gameState.dealerHand.count >= 2 && gameState.flippedDealerCards.contains(1) {
                return gameEngine.getHandValueText([gameState.dealerHand[1]])
            } else {
                return "?"
            }
        } else if trainingModeEnabled && !gameState.isPlayerTurn {
            // In training mode after player turn, show full dealer hand
            // Only show cards that are fully revealed for counting purposes
            let fullyRevealedCards = gameState.dealerHand.enumerated().compactMap { index, card in
                return gameState.countingRevealedDealerCards.contains(index) ? card : nil
            }
            return gameEngine.getHandValueText(fullyRevealedCards)
        } else if gameState.isPlayerTurn {
            // During player turn, only show the second dealer card (index 1 in dealt cards, but index 0 in visually revealed)
            if gameState.visuallyRevealedDealerHand.count > 0 {
            return gameEngine.getHandValueText([gameState.visuallyRevealedDealerHand[0]])
            } else {
                return "?"
            }
        } else {
            // Only show cards that are fully revealed for counting purposes
            let fullyRevealedCards = gameState.visuallyRevealedDealerHand.enumerated().compactMap { index, card in
                return gameState.countingRevealedDealerCards.contains(index) ? card : nil
            }
            return gameEngine.getHandValueText(fullyRevealedCards)
        }
    }
    
    private func createArchedText(text: String, fontSize: CGFloat, width: CGFloat, height: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        let chars = Array(text)
        let count = chars.count
        let charSpacing = width / CGFloat(max(count - 1, 1))
        
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let x = centerX - width / 2 + CGFloat(i) * charSpacing
                
                // Calculate y position to create a gentle arch
                let progress = CGFloat(i) / CGFloat(max(count - 1, 1)) // 0 to 1
                let archHeight = height * 0.3 // How much the middle is raised
                let y = centerY - archHeight * sin(progress * .pi) // Creates a smooth arch
                
                ZStack {
                    // Golden border layer (larger, underneath)
                    Text(String(chars[i]))
                        .font(.fixedSystem(size: fontSize + 4, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.15))
                        .position(x: x, y: y)
                    
                    // White text layer (smaller, on top)
                    Text(String(chars[i]))
                        .font(.fixedSystem(size: fontSize, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Strategy Chart Overlay

// MARK: - Settings Overlay
struct SettingsOverlay: View {
    @Binding var showSettings: Bool
    @Binding var selectedSettingsTab: Int
    @Binding var numberOfDecks: Int
    @Binding var cardUnderglow: Bool
    @Binding var showStrategyHints: Bool
    @Binding var showCardCharts: Bool
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture { showSettings = false }
        
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Tab bar
                HStack(spacing: 0) {
                    Button(action: { selectedSettingsTab = 0 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                            Text("Settings")
                                .font(.headline)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(selectedSettingsTab == 0 ? Color(hex: "23272a") : Color.clear)
                        .foregroundColor(selectedSettingsTab == 0 ? .yellow : .white)
                        .opacity(selectedSettingsTab == 0 ? 1.0 : 0.5)
                    }
                    
                    Button(action: { selectedSettingsTab = 1 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(.title2)
                            Text("Achievements")
                                .font(.headline)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(selectedSettingsTab == 1 ? Color(hex: "23272a") : Color.clear)
                        .foregroundColor(selectedSettingsTab == 1 ? .yellow : .white)
                        .opacity(selectedSettingsTab == 1 ? 1.0 : 0.5)
                    }
                }
                .background(Color(hex: "1a1a2e").opacity(0.95))
                
                // Tab content
                if selectedSettingsTab == 0 {
                    SettingsTabView(
                        numberOfDecks: $numberOfDecks,
                        cardUnderglow: $cardUnderglow,
                        showStrategyHints: $showStrategyHints,
                        showCardCharts: $showCardCharts,
                        showSettings: $showSettings,
                        gameState: gameState,
                        gameEngine: gameEngine
                    )
                } else {
                    AchievementsTabView()
                }
            }
            .background(Color(hex: "16213e").opacity(0.95))
            .cornerRadius(24)
            .shadow(radius: 20)
            .frame(maxWidth: 340)
            .offset(y: -UIScreen.main.bounds.height * 0.18)
        }
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @Binding var numberOfDecks: Int
    @Binding var cardUnderglow: Bool
    @Binding var showStrategyHints: Bool
    @Binding var showCardCharts: Bool
    @Binding var showSettings: Bool
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                HStack {
                    Text("Decks:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Picker("Decks", selection: $numberOfDecks) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("6").tag(6)
                        Text("8").tag(8)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 220)
                    .disabled(gameState.isDealing || 
                             (gameState.isPlayerTurn && !gameState.playerHand.isEmpty))
                    .onChange(of: numberOfDecks) { newValue in
                        // Check if game is finished (result message shown)
                        let isGameFinished = gameState.resultMessage != nil
                        
                        // If game is finished, wait 2 seconds before allowing deck change
                        if isGameFinished {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                // Double-check that game is still finished after delay
                                if gameState.resultMessage != nil {
                                    // Game is still finished, safe to change decks
                                    gameState.dealtPlayerCards.removeAll()
                                    gameState.dealtDealerCards.removeAll()
                                    gameState.playerHand.removeAll()
                                    gameState.dealerHand.removeAll()
                                    gameState.visuallyRevealedDealerHand.removeAll()
                                    gameState.resultMessage = nil
                                    gameState.showNextHand = false
                                    
                                    gameState.numberOfDecks = newValue
                                    // Store current deck position before reset
                                    let currentDeckPosition = gameState.deckPosition
                                    gameEngine.resetDeck(gameState: gameState, numberOfDecks: newValue)
                                    // Restore the deck position for animation after reset
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        gameState.deckPosition = currentDeckPosition
                                    }
                                }
                            }
                            return
                        }
                        
                        // Game is not finished, safe to change decks immediately
                        gameState.dealtPlayerCards.removeAll()
                        gameState.dealtDealerCards.removeAll()
                        gameState.playerHand.removeAll()
                        gameState.dealerHand.removeAll()
                        gameState.visuallyRevealedDealerHand.removeAll()
                        gameState.resultMessage = nil
                        gameState.showNextHand = false
                        
                        gameState.numberOfDecks = newValue
                        // Store current deck position before reset
                        let currentDeckPosition = gameState.deckPosition
                        gameEngine.resetDeck(gameState: gameState, numberOfDecks: newValue)
                        // Restore the deck position for animation after reset
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            gameState.deckPosition = currentDeckPosition
                        }
                    }
                }
                
                HStack {
                    Text("Card Underglow:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Toggle("", isOn: $cardUnderglow)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Show Perfect Strategy Hints:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Toggle("", isOn: $showStrategyHints)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Show Card Charts:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Toggle("", isOn: $showCardCharts)
                        .labelsHidden()
                }
                
            }
            
            Button(action: { showSettings = false }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color(hex: "ff0000"))
                    .cornerRadius(12)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 340)
        .padding(.top, 24)
    }
}

// Note: AchievementsTabView moved to GameAchievements.swift

#Preview {
    TrainingModeView(map: Map(id: 1, name: "Mercury", imageName: "MercuryImage", isLocked: false, requiredLevel: 1))
}

// Custom extension for rounding specific corners
import SwiftUI

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// ArchTextModifier for arched text effect
struct ArchTextModifier: ViewModifier {
    var width: CGFloat
    var height: CGFloat
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    // Content cannot be cast to Text, so use empty text as placeholder
                    ArchText(text: Text(""), width: width, height: height)
                }
            )
            .opacity(0) // Hide the original
    }
}

struct ArchText: View {
    let text: Text
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        let string = Mirror(reflecting: text).descendant("storage", "anyTextStorage", "storage", "verbatim") as? String ?? ""
        let chars = Array(string)
        let count = chars.count
        let charSpacing = width / CGFloat(max(count - 1, 1))
        
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let x = width / 2 + CGFloat(i) * charSpacing - width / 2
                
                // Calculate y position to create a gentle arch
                let progress = CGFloat(i) / CGFloat(max(count - 1, 1)) // 0 to 1
                let archHeight = height * 0.3 // How much the middle is raised
                let y = height / 2 - archHeight * sin(progress * .pi) // Creates a smooth arch
                
                Text(String(chars[i]))
                    .font(.fixedSystem(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
                    .position(x: x, y: y)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Betting Area View (Extracted for Compiler Performance)
struct BettingAreaView: View {
    @ObservedObject var gameState: BlackjackGameState
    let bettingManager: BlackjackBettingManager
    let gameEngine: BlackjackGameEngine
    let tableSize: CGSize?
    @Binding var isContinuousAutoPlay: Bool
    let startContinuousAutoPlay: () -> Void
    
    var body: some View {
        VStack(spacing: 0) { // Original spacing to match previous layout
            // Betting Area Title
            Text("Betting Area")
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 24)
                .padding(.top, 12)
            
            // Spiral Chip Stack
            ZStack {
                ForEach(Array(gameState.betChips.sorted(by: >).enumerated()), id: \.offset) { index, chipValue in
                    let angle = Double(index) * 0.8
                    let radius: CGFloat = 2.0
                    let xOffset = radius * cos(angle)
                    let yOffset = radius * sin(angle)
                    
                    ChipView(chip: Chip(value: chipValue))
                        .offset(x: xOffset, y: yOffset)
                        .zIndex(Double(index))
                        .opacity(gameState.hideBetChipsDuringLoseAnimation ? 0 : 1)
                        .transition(.identity)
                        .transaction { $0.animation = nil }
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 60)
            .transaction { $0.animation = nil }
            
            // Bet Amount Text with Return Bet Button
            ZStack {
                // Centered Bet Amount Text
                Text("Bet: $\(gameState.playerBet)")
                    .font(.fixedSystem(size: 18, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(.vertical, 5)
                
                // Unknown Button on the left (Training Mode only) - with autoplay logic
                HStack {
                    if !isContinuousAutoPlay && !gameState.isDealing && (gameState.resultMessage != nil || gameState.isCollectingPhase || !gameState.showNextHand) && !(gameState.playerHand.count >= 2 && gameState.isPlayerTurn) {
                        Button(action: {
                            // Start auto play mode (same as training mode enabled)
                            UserDefaults.standard.set(true, forKey: "trainingModeEnabled")
                            startContinuousAutoPlay()
                        }) {
                            Text("Autoplay")
                                .font(.fixedSystem(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: "ff0000"))
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                }
                
                // Return Bet Button on the right
                HStack {
                    Spacer()
                    if !gameState.betChips.isEmpty && !gameState.isDealing && (gameState.resultMessage != nil || gameState.isCollectingPhase || !gameState.showNextHand) && !(gameState.playerHand.count >= 2 && gameState.isPlayerTurn) && !isContinuousAutoPlay {
                        Button(action: {
                            bettingManager.returnBet(gameState: gameState)
                        }) {
                            Text("Return Bet")
                                .font(.fixedSystem(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: "ff0000"))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Win/Lose/Push Notifications
            if gameState.resultMessage != nil, gameState.showResultNotification {
                if gameState.lastPayout > 0 {
                    Text("Win $\(gameState.actualWinnings)")
                        .font(.fixedSystem(size: 16, weight: .bold))
                        .foregroundColor(.green)
                } else if gameState.lastPayout < 0 {
                    Text("Lose $\(abs(gameState.actualWinnings))")
                        .font(.fixedSystem(size: 16, weight: .bold))
                        .foregroundColor(.red)
                } else {
                    Text("Push $\(gameState.actualWinnings)")
                        .font(.fixedSystem(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            
            // User's Available Chips
            if !gameState.showNextHand {
                ChipSelectionView(
                    gameState: gameState,
                    bettingManager: bettingManager
                )
                .disabled(gameState.isDealing)
            }
            
            
        }
    }
}

