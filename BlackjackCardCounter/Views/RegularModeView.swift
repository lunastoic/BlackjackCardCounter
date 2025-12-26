import SwiftUI

struct RegularModeView: View {
    let map: Map
    
    // Shared state/managers
    @StateObject private var gameState = BlackjackGameState()
    private let gameEngine = BlackjackGameEngine.shared
    private let bettingManager = BlackjackBettingManager.shared
    
    // Namespaces
    @Namespace private var cardAnimation
    @Namespace private var mgCards

    // Table geometry
    @State private var tableSize: CGSize = .zero

    // Final locked positions for static cards
    @State private var finalPlayerPositions: [UUID: CGPoint] = [:]
    @State private var finalDealerPositions: [UUID: CGPoint] = [:]
    @State private var finalSplitPositions: [[UUID: CGPoint]] = Array(repeating: [:], count: 2) // [left,right]

    // Top-right “Shoe” (origin + collect target)
    @State private var shoeFrame: CGRect = .zero
    @State private var shoePosition: CGPoint = .zero

    // Collect sequencing (now in gameState)

    // Layout - now using shared CardMetrics

    // Visible counts
    @State private var visiblePlayerCount: Int = 0
    @State private var visibleDealerCount: Int = 0
    @State private var dealerHoleRevealed: Bool = false

    // Misc
    @State private var discardPile: [Card] = []
    @State private var showZeroChipsOverlay = false
    @State private var showSettings = false
    @State private var selectedSettingsTab: Int = 0
    @AppStorage("regularDecks") private var numberOfDecks: Int = 6
    
    var body: some View {
        GeometryReader { tableGeo in
        ZStack {
            // Background
            Image("GreenSuede")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .ignoresSafeArea()
            
                // Decorative arch text
            GeometryReader { geo in
                ZStack {
                    createArchedText(
                            text: "Luna Luxe Casino", fontSize: 36,
                            width: geo.size.width * 0.8, height: 80,
                            centerX: geo.size.width / 2, centerY: geo.size.height / 2 - 175
                    )
                    createArchedText(
                            text: "Blackjack pays 3 to 2", fontSize: 24,
                            width: geo.size.width * 0.7, height: 60,
                            centerX: geo.size.width / 2, centerY: geo.size.height / 2 - 145
                    )
                    createArchedText(
                            text: "Dealer must hit on soft 17", fontSize: 16,
                            width: geo.size.width * 0.75, height: 50,
                            centerX: geo.size.width / 2, centerY: geo.size.height / 2 - 115
                    )
                    }.allowsHitTesting(false)
            }
            .zIndex(0)
            
            VStack(spacing: 0) {
                GameHeaderView()
                
                VStack(spacing: 0) {
                        // Top row: decorative Deck (left) + functional Shoe (right)
                    HStack {
                        ZStack {
                        VStack {
                            Image("DeckCover")
                                .resizable()
                                .aspectRatio(0.7, contentMode: .fit)
                                .frame(width: 48, height: 72)
                                .shadow(radius: 4)
                                .offset(x: -30) // Shift deck cover 30 points to the left
                                .overlay(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .onAppear {
                                                let f = geometry.frame(in: .named("table"))
                                                // Account for the -30 offset to get the actual deck position
                                                let deckPos = CGPoint(x: f.midX - 30, y: f.midY)
                                                gameState.deckCollectionPosition = deckPos // Store deck position for collection animation
                                                print("🎯 Deck collection position captured: \(deckPos) (with -30 offset)")
                                            }
                                            .onChange(of: geometry.frame(in: .named("table"))) { newF in
                                                // Account for the -30 offset to get the actual deck position
                                                let deckPos = CGPoint(x: newF.midX - 30, y: newF.midY)
                                                gameState.deckCollectionPosition = deckPos
                                                print("🎯 Deck collection position updated: \(deckPos) (with -30 offset)")
                                            }
                                    }
                                )
                            Text("Deck")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .offset(x: -30) // Shift "Deck" text 30 points to the left to match
                            }
                            
                            CardCounterView(gameState: gameState)
                        }
                        
                        Spacer()
                        
                        VStack {
                                Image("DeckCover")
                                    .resizable()
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .frame(width: 48, height: 72)
                                    .shadow(radius: 4)
                                    .overlay(
                                        GeometryReader { geometry in
                                            Color.clear
                                                .onAppear {
                                                    let f = geometry.frame(in: .named("table"))
                                                    shoeFrame = f
                                                    shoePosition = CGPoint(x: f.midX, y: f.midY)
                                                    gameState.deckFrame = f
                                                    gameState.deckPosition = shoePosition // dealing origin (shoe position for dealing cards)
                                                }
                                                .onChange(of: geometry.frame(in: .named("table"))) { newF in
                                                    shoeFrame = newF
                                                    shoePosition = CGPoint(x: newF.midX, y: newF.midY)
                                                    gameState.deckFrame = newF
                                                    gameState.deckPosition = shoePosition // dealing origin (shoe position for dealing cards)
                                                }
                                        }
                                    )
                                Text("Shoe")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    
                    Spacer().frame(height: 16)
                    
                        // Dealer
                    VStack(spacing: 8) {
                            Text("Dealer").font(.headline).foregroundColor(.white)
                            Text(dealerValueLabel()).font(.system(size: 17, weight: .bold)).foregroundColor(.yellow)
                                .offset(y: -6)
                        
                            // Hidden placeholders to keep layout stable
                        HStack(spacing: 8) {
                                    ForEach(Array(gameState.dealtDealerCards.enumerated()), id: \.element.id) { idx, card in
                                    FlipCardView(card: card,
                                    isFlipped: gameState.flippedDealerCards.contains(idx),
                                                 width: CardMetrics.cardSize.width, glowWidth: 0)
                                        .opacity(0.0)
                                        .transaction { $0.animation = nil }
                            }
                        }
                            .frame(minWidth: 200, minHeight: 90)
                            .frame(maxWidth: .infinity)
                    }
                        .frame(height: 140)
                    
                    Spacer().frame(height: 32)
                    
                        // Player
                    VStack(spacing: 8) {
                            Text("Player").font(.fixedSystem(size: 17, weight: .semibold)).foregroundColor(.white)

                            if gameState.isSplit {
                                // Split labels + hidden placeholders only (real cards are drawn in overlay)
                                VStack(spacing: 4) {
                                    Text(gameEngine.getHandValueText(gameState.splitHands[gameState.activeHandIndex]))
                                        .font(.system(size: 17, weight: .bold)).foregroundColor(.yellow)
                                        .offset(y: -6)

                                    HStack(spacing: 24) {
                                        ForEach(gameState.splitHands.indices, id: \.self) { idx in
                                            VStack {
                                                HStack {
                                                    Text("Hand \(idx == 1 ? 1 : 2)\(isHandActive(idx) ? " (Active)" : "")")
                                                        .font(.headline).foregroundColor(isHandActive(idx) ? .yellow : .gray)
                                                    Text(gameEngine.getHandValueText(gameState.splitHands[idx]))
                                                        .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.yellow)
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
                                Text(playerValueLabel()).font(.system(size: 17, weight: .bold)).foregroundColor(.yellow)
                                    .offset(y: -6)

                                // Hidden placeholders for non-split player
                        HStack(spacing: 8) {
                                    ForEach(Array(gameState.dealtPlayerCards.enumerated()), id: \.element.id) { _, card in
                                        CardView(card: card, width: CardMetrics.cardSize.width, glowWidth: 0)
                                            .opacity(0.0)
                                            .transaction { $0.animation = nil }
                            }
                        }
                                .frame(minWidth: 200, minHeight: 90)
                                .frame(maxWidth: .infinity)
                            }
                    }
                        .frame(height: 140)
                    
                    Spacer().frame(height: 32)
                    
                        if UIDevice.current.userInterfaceIdiom == .pad { Spacer().frame(height: CardMetrics.extraSpacerHeight(isIPad: true)) }
                    
                        // Shuffling notification is now handled as overlay - removed from here
                    
                        // Result message is now displayed in overlay to prevent layout movement
                    
                    VStack(spacing: 0) { // Fixed spacing: 0 to prevent any layout shifts
                        // Betting Area Title
                        Text("Betting Area")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(height: 24)
                            .padding(.top, 12)
                        
                        // Chip stacks container — match Training Mode chip layout/offsets
                        let hasPayoutChips = gameState.lastPayout > 0 && gameState.showResultNotification
                        let payoutOffset: CGFloat = hasPayoutChips ? 36.0 : 0.0
                        let hand2GroupTweak: CGFloat = hasPayoutChips ? -1.0 : 0.0
                        let hand1GroupTweak: CGFloat = hasPayoutChips ? 7.0 : 0.0
                        
                        let isSplit = gameState.isSplit
                        let hand1Doubled = isSplit && !gameState.doubleDownChipsHand1.isEmpty
                        
                        ZStack {
                            if isSplit {
                                // Hand 2 (left)
                                if !gameState.doubleDownChipsHand2.isEmpty {
                                    chipStackView(for: gameState.doubleDownChipsHand2)
                                        .offset(x: -114.0 + payoutOffset + hand2GroupTweak)
                                }
                                chipStackView(for: gameState.betChips)
                                    .offset(x: -70.0 + payoutOffset + hand2GroupTweak)
                                
                                // Hand 1 (right)
                                chipStackView(for: gameState.additionalBetChips)
                                    .offset(x: 70.0 + (hand1Doubled ? 10.0 : 0.0) + payoutOffset + hand1GroupTweak)
                                
                                if !gameState.doubleDownChipsHand1.isEmpty {
                                    // Keep Hand 1 DD stack positioned like Training Mode (touching on the left of bet)
                                    chipStackView(for: gameState.doubleDownChipsHand1)
                                        .offset(x: (hand1Doubled ? (80.0 + 45.0) : 30.0) + payoutOffset + hand1GroupTweak)
                                }
                            } else {
                                // Non-split: if doubled down, show the DD stack touching the LEFT of the main bet stack.
                                // During payout display, shift the user stacks so the full row stays centered under the title.
                                let chipSize: CGFloat = 44.0
                                let chipSpacing: CGFloat = chipSize + 1.0 // 45pt: touching
                                let hasRegularDD = !gameState.additionalBetChips.isEmpty
                                
                                // If payout chips are present, we conceptually have a single horizontal row:
                                // [payout chips ...] [user chips ...], all touching and centered.
                                let userStackCount = hasRegularDD ? 2 : 1
                                let payoutCount = hasPayoutChips ? (hasRegularDD ? 2 : 1) : 0
                                let totalCount = userStackCount + payoutCount
                                let rowStart: CGFloat = -chipSpacing * CGFloat(max(totalCount - 1, 0)) / 2.0
                                let firstUserX: CGFloat = rowStart + CGFloat(payoutCount) * chipSpacing
                                
                                if hasRegularDD {
                                    chipStackView(for: gameState.additionalBetChips)
                                        .offset(x: firstUserX)
                                    chipStackView(for: gameState.betChips)
                                        .offset(x: firstUserX + chipSpacing)
                                } else {
                                    chipStackView(for: gameState.betChips)
                                        .offset(x: firstUserX)
                                }
                            }
                        }
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .animation(.none, value: gameState.isSplit)
                            .transaction { $0.animation = nil }
                        // Capture on-table chip row position for payout animations (global coordinates).
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        let frame = geometry.frame(in: .global)
                                        gameState.bettingAreaPosition = CGPoint(x: frame.midX, y: frame.midY)
                                    }
                                    .onChange(of: geometry.frame(in: .global)) { newFrame in
                                        gameState.bettingAreaPosition = CGPoint(x: newFrame.midX, y: newFrame.midY)
                                    }
                            }
                        )
                        
                        // Bet Amount Text with Return Bet Button - Fixed height to prevent layout shifts
                        ZStack {
                            // Centered Bet Amount Text
                            Text("Bet: $\(gameState.playerBet)")
                                .font(.fixedSystem(size: 18, weight: .semibold))
                                .foregroundColor(.yellow)
                                .padding(.vertical, 5)
                            
                            // Return Bet Button on the right
                            // Match Training Mode logic exactly
                            let dealerIsFlipping = !gameState.isPlayerTurn && !gameState.dealerHand.isEmpty && !gameState.isDealing
                            let handInProgress = gameState.isDealing || gameState.isProcessingAction || dealerIsFlipping
                            
                            HStack {
                                Spacer()
                                if !gameState.isAutoCollectingWinnings
                                    && !gameState.betChips.isEmpty
                                    && !handInProgress
                                    && (gameState.resultMessage != nil || gameState.isCollectingPhase || !gameState.showNextHand)
                                    && !(gameState.playerHand.count >= 2 && gameState.isPlayerTurn) {
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
                                } else {
                                    // Reserve space for button even when hidden to prevent layout shifts
                                    Color.clear
                                        .frame(width: 100, height: 36)
                                }
                            }
                        }
                        .frame(height: 40) // Fixed height to prevent shifts
                        
                        // Win/Lose/Push Notifications - Fixed height to prevent layout shifts
                        Group {
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
                            } else {
                                // Reserve space even when notification is not shown to prevent layout shifts
                                Text("")
                                    .font(.fixedSystem(size: 16, weight: .bold))
                                    .frame(height: 20)
                                    .opacity(0)
                            }
                        }
                        .frame(height: 20) // Fixed height
                        
                        // User's Available Chips - Fixed position to prevent shifts
                        if !gameState.showNextHand {
                            ChipSelectionView(
                                gameState: gameState,
                                bettingManager: bettingManager
                            )
                            .disabled(gameState.isDealing)
                            .offset(y: 0) // Explicitly set to prevent any shifts
                        }
                        
                        
                    }
                    
                    // ALWAYS show buttons when chip selection is visible - simplified logic
                    let chipSelectionVisible = !gameState.showNextHand
                    let showingResult = (gameState.resultMessage != nil && gameState.showResultNotification) || gameState.showPostGameButtons
                    let isActiveGameplay = (gameState.playerHand.count >= 2 && gameState.isPlayerTurn) || 
                                          (gameState.isDealing && gameState.playerHand.count >= 2) ||
                                          gameState.isProcessingAction
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
                                        if isPlayer { visiblePlayerCount += 1 }
                                        else if index == 3 { visibleDealerCount = 1 }
                                    }
                                }
                            )
                        }
                    }
                    
                    if gameState.isPlayerTurn && gameState.playerHand.count >= 2 {
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
                            showStrategyHints: false,
                            getPerfectStrategyAction: { nil }
                        )
                            }
                    }
                    
                    Spacer()
                }
            }
            
            // Simple settings button
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .shadow(radius: 6)
            }
            .position(x: UIScreen.main.bounds.width - 40, y: 185)
            
            
                // ---- Animated and Static Cards Overlay ----
                AnimatedCardsOverlay(
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

                // Split cards moved to overlay - see below
        }
                .coordinateSpace(name: "table")
                .overlay(
                    // Shuffling notification overlay - doesn't affect layout
                    ShufflingNotification(gameState: gameState)
                        .zIndex(1000) // High z-index to appear on top
                )
        .onAppear {
            gameState.isTrainingMode = false
            tableSize = tableGeo.size
            // Ensure deck position is set for animation
            if gameState.deckPosition == .zero {
                gameState.deckPosition = CGPoint(x: tableSize.width * 0.5, y: tableSize.height * 0.5)
            }
            // Initialize numberOfDecks if not set
            if gameState.numberOfDecks == 0 {
                gameState.numberOfDecks = numberOfDecks
            }
                _ = UIImage(named: "DeckCover")
                ["AS", "KH", "7D", "9C"].forEach { _ = UIImage(named: $0) }
            gameEngine.resetDeck(gameState: gameState)
            
                // Hit animation callback
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
                
                // Split animation callback — pre-register landing position for autolock
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
            .onChange(of: gameState.flippedDealerCards) { newSet in
                if newSet.contains(1), !dealerHoleRevealed {
                    dealerHoleRevealed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { visibleDealerCount = max(visibleDealerCount, 2) }
            }
        }
        .onDisappear {
            gameEngine.hitAnimationCallback = nil
                gameEngine.splitAnimationCallback = nil
                if gameState.playerBet > 0 && !gameState.showNextHand && gameState.resultMessage == nil && !gameState.isCollectingPhase {
                    XPChipManager.shared.updateChips(gameState.playerBet)
                    gameState.playerBet = 0
                    gameState.betChips = []
                }
            }
            .overlay {
                if showZeroChipsOverlay { ZeroChipsOverlay(isPresented: $showZeroChipsOverlay) }
                // Regular Mode: do not show the large black-box result overlay (it can overlap cards).
                // We rely on the in-layout Win/Lose/Push text under the bet amount instead.
                
                // Settings overlay (simplified for Regular Mode)
                if showSettings {
                    RegularModeSettingsOverlay(
                        showSettings: $showSettings,
                        selectedSettingsTab: $selectedSettingsTab,
                        numberOfDecks: $numberOfDecks,
                        gameState: gameState,
                        gameEngine: gameEngine
                    )
                }
                
                // Split cards overlay - back to working approach
                if gameState.isSplit {
                    ZStack {
                        // Static split cards
                        ForEach(gameState.splitHands.indices, id: \.self) { handIdx in
                            ForEach(Array(gameState.splitHands[handIdx].enumerated()), id: \.element.id) { cIdx, card in
                                if !gameState.animatingCards.keys.contains(card.id) {
                                    let pos = finalSplitPositions[handIdx][card.id] ?? CardPositioning.splitStaticPosition(handIndex: handIdx, cardIndex: cIdx, totalCards: gameState.splitHands[handIdx].count, tableSize: tableSize)
                                    let zIndex = SplitCardLayout.shared.getSplitCardZIndex(handIndex: handIdx, cardIndex: cIdx)
                                    FlipCardView(card: card, isFlipped: true, width: CardMetrics.cardSize.width, glowWidth: 0)
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
                                    Image(card.imageName(isTrainingMode: false))
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
                    .allowsHitTesting(false)
                }
                
                // Place Chip Notification - positioned at the very top layer
                PlaceChipNotification(isVisible: $gameState.showPlaceChipNotification)
                
                // Chip Win/Lose Animation - Clean and simple animation system
                ChipWinLoseAnimation(gameState: gameState)
                    .zIndex(99999) // Highest z-index to ensure visibility
                
                // Chip Placement Animation - Animate chips from selection to betting area
                    .zIndex(99998) // Just below win/lose animation
            }
        }
        .disableDynamicType()
    }
    
    // MARK: - Labels
    private func dealerValueLabel() -> String {
        let shown = dealerShownCards()
        guard !shown.isEmpty else { return "?" }
        return gameEngine.getHandValueText(shown)
    }

    private func dealerShownCards() -> [Card] {
        guard gameState.dealerHand.count >= 1 else { return [] }
        let upcardIndex = 1
        if gameState.isPlayerTurn {
            return (visibleDealerCount >= 1 && gameState.dealerHand.count > upcardIndex)
                ? [gameState.dealerHand[upcardIndex]] : []
        } else {
            if visibleDealerCount == 1 {
                return gameState.dealerHand.count > upcardIndex ? [gameState.dealerHand[upcardIndex]] : []
            } else { return Array(gameState.dealerHand.prefix(visibleDealerCount)) }
        }
    }

    private func playerValueLabel() -> String {
        let shown = Array(gameState.playerHand.prefix(visiblePlayerCount))
        guard !shown.isEmpty else { return "0" }
        return gameEngine.getHandValueText(shown)
    }

    // MARK: - Chip stack layout helpers
    private struct ChipStackData: Identifiable {
        let id: String
        let chips: [Int]
    }
    
    /// Builds the ordered list of chip stacks to display for the current hand state.
    /// Order keeps related stacks together: left-hand double → left bet → right bet → right-hand double.
    private func chipStacksForCurrentState() -> [ChipStackData] {
        if gameState.isSplit {
            return [
                ChipStackData(id: "dd-left", chips: gameState.doubleDownChipsHand2),
                ChipStackData(id: "left-bet", chips: gameState.betChips),
                ChipStackData(id: "right-bet", chips: gameState.additionalBetChips),
                ChipStackData(id: "dd-right", chips: gameState.doubleDownChipsHand1)
            ].filter { !$0.chips.isEmpty }
        } else {
            // Non-split: show base stack plus optional double-down stack.
            return [
                ChipStackData(id: "main", chips: gameState.betChips),
                ChipStackData(id: "extra", chips: gameState.additionalBetChips)
            ].filter { !$0.chips.isEmpty }
        }
    }
    
    /// Renders a single spiral stack with the same stacking logic used in animations.
    private func chipStackView(for chips: [Int]) -> some View {
        ZStack {
            ForEach(Array(chips.sorted(by: >).enumerated()), id: \.offset) { index, chipValue in
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
        .animation(.none, value: chips.count)
    }

    // MARK: - Layout helpers (now using shared CardPositioning)
    
    private func createArchedText(text: String, fontSize: CGFloat, width: CGFloat, height: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        let chars = Array(text)
        let count = chars.count
        let charSpacing = width / CGFloat(max(count - 1, 1))
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let x = centerX - width / 2 + CGFloat(i) * charSpacing
                let progress = CGFloat(i) / CGFloat(max(count - 1, 1))
                let archHeight = height * 0.3
                let y = centerY - archHeight * sin(progress * .pi)
                
                ZStack {
                    Text(String(chars[i]))
                        .font(.fixedSystem(size: fontSize + 4, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.15))
                        .position(x: x, y: y)
                    Text(String(chars[i]))
                        .font(.fixedSystem(size: fontSize, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .position(x: x, y: y)
                }
            }
        }
    }
    

    

    
    // MARK: - Split hand active status
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
    
    // MARK: - Split hand result color coding
    private func colorForSplitHandResult(_ line: String) -> Color {
        if line.contains("Win!") {
            return Color(hex: "00FF41") // Green for wins
        } else if line.contains("Lose.") || line.contains("Bust!") {
            return Color(hex: "DC143C") // Red for losses/busts
        } else if line.contains("Push.") {
            return .yellow // Yellow for pushes
        } else if line.contains("21!") {
            return .yellow // Yellow for natural blackjack
        } else {
            return .yellow // Default yellow for other cases
        }
    }
    
    // MARK: - Split Hand Result View
    private func SplitHandResultView(line: String) -> some View {
        HStack(spacing: 0) {
            // Extract hand label (e.g., "Hand 1: " or "Hand 2: ")
            if let colonIndex = line.firstIndex(of: ":") {
                let handLabel = String(line[..<colonIndex]) + ": "
                let resultText = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                // Hand label in yellow
                Text(handLabel)
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.yellow)
                
                // Result in appropriate color
                Text(resultText)
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(colorForSplitHandResult(resultText))
            } else {
                // Fallback if no colon found
                Text(line)
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
        }
        .multilineTextAlignment(.center)
    }
    
    // MARK: - Split landing positions and position management (now using shared CardPositioning)

    // MARK: - Animations (now using shared CardAnimator)

    // MARK: - Collect to Shoe (sequential) - now using shared CardAnimator
    private func collectCardsToDiscard(onComplete: @escaping () -> Void) {
        let sequence: [Card] = gameState.dealtPlayerCards + gameState.dealtDealerCards
        
        CardAnimator.collectCardsToDiscard(
            sequence: sequence,
            shoePosition: shoePosition,
            finalPlayerPositions: finalPlayerPositions,
            finalDealerPositions: finalDealerPositions,
            dealtPlayerCards: gameState.dealtPlayerCards,
            dealtDealerCards: gameState.dealtDealerCards,
            flippedDealerCards: gameState.flippedDealerCards,
            tableSize: tableSize,
            gameState: gameState
        ) {
            // Clean up after collection
            discardPile.append(contentsOf: sequence)
            gameState.dealtPlayerCards = []
            gameState.dealtDealerCards = []
            finalPlayerPositions.removeAll()
            finalDealerPositions.removeAll()
            finalSplitPositions = Array(repeating: [:], count: 2)
            visiblePlayerCount = 0
            visibleDealerCount = 0
            dealerHoleRevealed = false
            onComplete()
        }
    }
}

// MARK: - Regular Mode Settings Overlay
struct RegularModeSettingsOverlay: View {
    @Binding var showSettings: Bool
    @Binding var selectedSettingsTab: Int
    @Binding var numberOfDecks: Int
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
                    RegularModeSettingsTabView(
                        numberOfDecks: $numberOfDecks,
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

// MARK: - Regular Mode Settings Tab View
struct RegularModeSettingsTabView: View {
    @Binding var numberOfDecks: Int
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
        }
        .padding(20)
    }

}


#Preview {
    RegularModeView(map: Map(id: 1, name: "Mercury", imageName: "MercuryImage", isLocked: false, requiredLevel: 1))
} 

