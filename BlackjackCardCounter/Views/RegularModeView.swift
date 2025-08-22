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

    // Collect sequencing
    @State private var collectingCardIds: Set<UUID> = []
    @State private var arrivalOrder: [UUID: Int] = [:]
    @State private var isCollectingPhase: Bool = false

    // Layout
    private let cardSize = CGSize(width: 60, height: 90)
    private let cardSpacing: CGFloat = 70
    private let dealerYOffset: CGFloat = -43
    private let playerYOffset: CGFloat = -7
    private let splitYOffset: CGFloat = 4   // ↓ lower split cards by 4pt

    // Animations
    private let travelAnim = Animation.easeInOut(duration: 0.50)
    private let flipAnim = Animation.easeInOut(duration: 0.26)
    private let collectTravelAnim = Animation.easeInOut(duration: 1.00)

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
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1a3a1a"), Color(hex: "2d5a2d")]),
                    startPoint: .top, endPoint: .bottom
            )
                .ignoresSafeArea()
            
                // Decorative arch text
            GeometryReader { geo in
                ZStack {
                    createArchedText(
                            text: "Luna Luxe Casino", fontSize: 36,
                            width: geo.size.width * 0.8, height: 80,
                            centerX: geo.size.width / 2, centerY: geo.size.height / 2 - 125
                    )
                    createArchedText(
                            text: "Blackjack pays 3 to 2", fontSize: 24,
                            width: geo.size.width * 0.7, height: 60,
                            centerX: geo.size.width / 2, centerY: geo.size.height / 2 - 95
                    )
                    createArchedText(
                            text: "Dealer must hit on soft 17", fontSize: 16,
                            width: geo.size.width * 0.75, height: 50,
                            centerX: geo.size.width / 2, centerY: geo.size.height / 2 - 65
                    )
                    }.allowsHitTesting(false)
            }
            .zIndex(0)
            
            VStack(spacing: 0) {
                GameHeaderView()
                
                VStack(spacing: 0) {
                        // Top row: decorative Deck (left) + functional Shoe (right)
                    HStack {
                        VStack {
                            Image("DeckCover")
                                .resizable()
                                .aspectRatio(0.7, contentMode: .fit)
                                .frame(width: 48, height: 72)
                                .shadow(radius: 4)
                            Text("Deck")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
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
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    
                    Spacer().frame(height: 16)
                    
                        // Dealer
                    VStack(spacing: 8) {
                            Text("Dealer").font(.headline).foregroundColor(.white)
                            Text(dealerValueLabel()).font(.subheadline).foregroundColor(.yellow)
                                .offset(y: -6)
                        
                            // Hidden placeholders to keep layout stable
                        HStack(spacing: 8) {
                                ForEach(Array(gameState.dealtDealerCards.enumerated()), id: \.element.id) { idx, card in
                                    FlipCardView(card: card,
                                    isFlipped: gameState.flippedDealerCards.contains(idx),
                                                 width: cardSize.width, glowWidth: 0)
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
                                        .font(.fixedSystem(size: 15, weight: .regular)).foregroundColor(.yellow)
                                        .offset(y: -6)

                                    HStack(spacing: 24) {
                                        ForEach(gameState.splitHands.indices, id: \.self) { idx in
                                            VStack {
                                                HStack {
                                                    Text("Hand \(idx == 1 ? 1 : 2)\(gameState.activeHandIndex == idx ? " (Active)" : "")")
                                                        .font(.fixedSystem(size: 12, weight: .regular))
                                                        .foregroundColor(gameState.activeHandIndex == idx ? .yellow : .gray)
                                                    Text(gameEngine.getHandValueText(gameState.splitHands[idx]))
                                                        .font(.fixedSystem(size: 12, weight: .regular))
                            .foregroundColor(.yellow)
                                                        .offset(y: -6)
                                                }

                                                // Hidden placeholder rows (keep layout)
                                                let handCards = gameState.splitHands[idx]
                                                let overlap = handCards.count > 4
                                                if overlap {
                                                    ZStack {
                                                        ForEach(Array(handCards.enumerated()), id: \.element.id) { i, card in
                                                            CardView(card: card, width: cardSize.width, glowWidth: 0)
                                                                .offset(x: CGFloat(i) * (cardSize.width * 0.25))
                                                                .opacity(0.0)
                                                                .transaction { $0.animation = nil }
                                                        }
                                                    }
                                                    .frame(width: CGFloat(handCards.count - 1) * (cardSize.width * 0.25) + cardSize.width)
                                                } else {
                                                    HStack(spacing: 8) {
                                                        ForEach(handCards) { card in
                                                            CardView(card: card, width: cardSize.width, glowWidth: 0)
                                                                .opacity(0.0)
                                                                .transaction { $0.animation = nil }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                Text(playerValueLabel()).font(.subheadline).foregroundColor(.yellow)
                                    .offset(y: -6)

                                // Hidden placeholders for non-split player
                        HStack(spacing: 8) {
                                    ForEach(Array(gameState.dealtPlayerCards.enumerated()), id: \.element.id) { _, card in
                                        CardView(card: card, width: cardSize.width, glowWidth: 0)
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
                    
                        if UIDevice.current.userInterfaceIdiom == .pad { Spacer().frame(height: 250) }
                    
                        if let result = gameState.resultMessage, !result.isEmpty {
                        Text(result)
                                .font(.title2).fontWeight(.bold)
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 8)
                                .offset(y: -5)
                    }
                    
                    BlackjackBettingView(
                        gameState: gameState,
                        bettingManager: bettingManager,
                        gameEngine: gameEngine
                    )
                    .disabled(gameState.isDealing)
                    
                    if !gameState.showNextHand {
                        ChipSelectionView(
                            gameState: gameState,
                            bettingManager: bettingManager
                        )
                        .disabled(gameState.isDealing)
                    }
                    
                        if gameState.resultMessage != nil
                            || (!gameState.showNextHand && gameState.playerHand.isEmpty && gameState.dealerHand.isEmpty) {

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
                                    let startX = midX - (cardSpacing / 2)
                                    let x = startX + CGFloat(slotIndex) * cardSpacing
                                    let y = yForHand(isPlayer: isPlayer, size: tableSize)
                                    let destination = CGPoint(x: x, y: y)

                                    if isPlayer { finalPlayerPositions[card.id] = destination }
                                    else { finalDealerPositions[card.id] = destination }

                                    let shouldFlip = (index != 1)
                                    animateDeal(card: card, to: destination, shouldFlip: shouldFlip) {
                                        withAnimation(.easeInOut(duration: 0.001)) { completion() }
                                        cleanupAnimatedCard(card.id)
                                        if isPlayer { visiblePlayerCount += 1 }
                                        else if index == 3 { visibleDealerCount = 1 }
                                    }
                                }
                            )
                        }

                                                if gameState.isPlayerTurn && gameState.playerHand.count >= 2 {
                            // Check if current active hand has blackjack or is busted (don't show buttons if so)
                            let activeHasBlackjack = gameState.isSplit ? 
                                gameEngine.isBlackjack(gameState.splitHands[gameState.activeHandIndex]) :
                                gameEngine.isBlackjack(gameState.playerHand)
                            
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
            
            
                // ---- Animated overlay (move + flip) ----
            ForEach(Array(gameState.animatingCards.keys), id: \.self) { cardId in
                    if let card = gameState.animatingCards[cardId],
                       let pos = gameState.animatingCardPositions[cardId] {

                        let core = ZStack {
                        Image(card.imageName)
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                                .frame(width: cardSize.width, height: cardSize.height)
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
                                .frame(width: cardSize.width, height: cardSize.height)
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
                            if isCollectingPhase { core.position(pos) }
                            else { core.matchedGeometryEffect(id: card.id, in: mgCards).position(pos) }
                        }
                        .allowsHitTesting(false)
                        .zIndex(100 + Double(arrivalOrder[cardId] ?? 0))
                    }
                }

                // ---- Static cards (dealer) ----
                ForEach(Array(gameState.dealtDealerCards.enumerated()), id: \.element.id) { idx, card in
                    if !gameState.animatingCards.keys.contains(card.id) {
                        let computedX = xForStaticCard(idx: idx, count: gameState.dealtDealerCards.count, size: tableSize)
                        let computedY = yForHand(isPlayer: false, size: tableSize)
                        let pos = finalDealerPositions[card.id] ?? CGPoint(x: computedX, y: computedY)

                        FlipCardView(card: card,
                                     isFlipped: gameState.flippedDealerCards.contains(idx),
                                     width: cardSize.width,
                                     glowWidth: 0)
                            .matchedGeometryEffect(id: card.id, in: mgCards)
                            .position(pos)
                            .opacity(collectingCardIds.contains(card.id) ? 0 : 1)
                            .allowsHitTesting(false)
                            .transition(.identity)
                            .animation(.easeInOut(duration: 0.3), value: gameState.dealtDealerCards.count)
                    }
                }

                // ---- Static cards (player non-split) ----
                if !gameState.isSplit {
                    ForEach(Array(gameState.dealtPlayerCards.enumerated()), id: \.element.id) { idx, card in
                        if !gameState.animatingCards.keys.contains(card.id) {
                            let computedX = xForStaticCard(idx: idx, count: gameState.dealtPlayerCards.count, size: tableSize)
                            let computedY = yForHand(isPlayer: true, size: tableSize)
                            let pos = finalPlayerPositions[card.id] ?? CGPoint(x: computedX, y: computedY)

                            FlipCardView(card: card, isFlipped: true, width: cardSize.width, glowWidth: 0)
                                .matchedGeometryEffect(id: card.id, in: mgCards)
                                .position(pos)
                                .opacity(collectingCardIds.contains(card.id) ? 0 : 1)
                    .allowsHitTesting(false)
                                .transition(.identity)
                                .animation(.easeInOut(duration: 0.3), value: gameState.dealtPlayerCards.count)
                }
            }
        }

                // ---- Static cards (SPLIT) — autolock with matchedGeometryEffect ----
                if gameState.isSplit {
                    ForEach(gameState.splitHands.indices, id: \.self) { handIdx in
                        ForEach(Array(gameState.splitHands[handIdx].enumerated()), id: \.element.id) { cIdx, card in
                            if !gameState.animatingCards.keys.contains(card.id) {
                                let pos = finalSplitPositions[handIdx][card.id] ?? splitStaticPosition(handIndex: handIdx, cardIndex: cIdx)
                                FlipCardView(card: card, isFlipped: true, width: cardSize.width, glowWidth: 0)
                                    .matchedGeometryEffect(id: card.id, in: mgCards)
                                    .position(pos)
                                    .opacity(collectingCardIds.contains(card.id) ? 0 : 1)
                                    .allowsHitTesting(false)
                                    .transition(.identity)
            }
        }
                    }
                }
            }
        .coordinateSpace(name: "table")
        .onAppear {
                tableSize = tableGeo.size
                _ = UIImage(named: "DeckCover")
                ["AS", "KH", "7D", "9C"].forEach { _ = UIImage(named: $0) }
            gameEngine.resetDeck(gameState: gameState)
            
                // Hit animation callback
            gameEngine.hitAnimationCallback = { [weak gameState] card, isPlayerCard, completion in
                guard let gameState = gameState else { return }
                    let currentCount = isPlayerCard ? gameState.dealtPlayerCards.count : gameState.dealtDealerCards.count
                    let x = xForCard(index: currentCount, count: currentCount + 1, size: tableSize)
                    let y = yForHand(isPlayer: isPlayerCard, size: tableSize)
                    let destination = CGPoint(x: x, y: y)
                    recalculateAllCardPositions(isPlayerCard: isPlayerCard, newCount: currentCount + 1)

                    animateHitCard(card: card, to: destination) {
                        withAnimation(.easeInOut(duration: 0.001)) { completion() }
                        cleanupAnimatedCard(card.id)
                        if isPlayerCard { visiblePlayerCount += 1 } else { visibleDealerCount += 1 }
                    }
                }
                
                // Split animation callback — pre-register landing position for autolock
                gameEngine.splitAnimationCallback = { [weak gameState] card, handIndex, completion in
                    guard let gameState = gameState else { return }
                    let countBefore = gameState.splitHands[handIndex].count
                    let destination = splitStaticPosition(handIndex: handIndex, cardIndex: countBefore)
                    finalSplitPositions[handIndex][card.id] = destination

                    animateHitCard(card: card, to: destination) {
                        withAnimation(.easeInOut(duration: 0.001)) { completion() }
                        cleanupAnimatedCard(card.id)
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
                if gameState.playerBet > 0 && !gameState.showNextHand && gameState.resultMessage == nil {
                    XPChipManager.shared.updateChips(gameState.playerBet)
                    gameState.playerBet = 0
                    gameState.betChips = []
                }
            }
            .overlay {
                if showZeroChipsOverlay { ZeroChipsOverlay(isPresented: $showZeroChipsOverlay) }
                
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

    // MARK: - Layout helpers
    private func yForHand(isPlayer: Bool, size: CGSize) -> CGFloat {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let playerY: CGFloat = isIPad ? size.height * 0.50 : size.height * 0.55
        let dealerY: CGFloat = isIPad ? size.height * 0.36 : size.height * 0.38
        return isPlayer ? (playerY + playerYOffset) : (dealerY + dealerYOffset)
    }

    private func xForCard(index: Int, count: Int, size: CGSize) -> CGFloat {
        let midX = size.width * 0.5
        let totalWidth = CGFloat(max(count - 1, 0)) * cardSpacing
        let startX = midX - totalWidth / 2
        return startX + CGFloat(index) * cardSpacing
    }

    private func xForStaticCard(idx: Int, count: Int, size: CGSize) -> CGFloat {
        if gameState.isDealing && count <= 2 {
            let midX = size.width * 0.5
            let startX = midX - (cardSpacing / 2)
            return startX + CGFloat(idx) * cardSpacing
        } else {
            return xForCard(index: idx, count: count, size: size)
        }
    }
    
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
    
    // MARK: - Split landing positions
    private func splitStaticPosition(handIndex: Int, cardIndex: Int) -> CGPoint {
        // handIndex: 0 = left, 1 = right (visual)
        let midX = tableSize.width * 0.5
        let gap: CGFloat = 180
        let centerX = (handIndex == 0) ? (midX - gap/2) : (midX + gap/2)
        let y = yForHand(isPlayer: true, size: tableSize) + splitYOffset  // ↓ apply 4pt offset

        if cardIndex <= 1 {
            // two-slot layout for first two cards
            let start = centerX - (cardSpacing / 2)
            let x = start + CGFloat(cardIndex) * cardSpacing
            return CGPoint(x: x, y: y)
        } else {
            // overlapping for 3rd+ in the same hand
            let x = centerX + CGFloat(cardIndex - 1) * (cardSize.width * 0.25)
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Position management
    private func recalculateAllCardPositions(isPlayerCard: Bool, newCount: Int) {
        if isPlayerCard {
            for (index, card) in gameState.dealtPlayerCards.enumerated() {
                let x = xForCard(index: index, count: newCount, size: tableSize)
                let y = yForHand(isPlayer: true, size: tableSize)
                finalPlayerPositions[card.id] = CGPoint(x: x, y: y)
                }
            } else {
            for (index, card) in gameState.dealtDealerCards.enumerated() {
                let x = xForCard(index: index, count: newCount, size: tableSize)
                let y = yForHand(isPlayer: false, size: tableSize)
                finalDealerPositions[card.id] = CGPoint(x: x, y: y)
            }
        }
    }

    // MARK: - Animations
    private func animateDeal(card: Card, to destination: CGPoint, shouldFlip: Bool, completion: @escaping () -> Void) {
        let id = card.id
        gameState.animatingCardPositions[id] = gameState.deckPosition
        gameState.cardFlipRotations[id] = 0
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { gameState.animatingCards[id] = card }

        withAnimation(travelAnim) { gameState.animatingCardPositions[id] = destination }

        let travelT: Double = 0.50
        if shouldFlip {
            DispatchQueue.main.asyncAfter(deadline: .now() + travelT) {
                withAnimation(self.flipAnim) { self.gameState.cardFlipRotations[id] = 180 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { completion() }
        }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + travelT) { completion() }
        }
    }

    private func animateHitCard(card: Card, to destination: CGPoint, completion: @escaping () -> Void) {
        let id = card.id
        gameState.animatingCardPositions[id] = gameState.deckPosition
        gameState.cardFlipRotations[id] = 0
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { gameState.animatingCards[id] = card }

        withAnimation(travelAnim) { gameState.animatingCardPositions[id] = destination }

        let travelT: Double = 0.50
        DispatchQueue.main.asyncAfter(deadline: .now() + travelT) {
            withAnimation(self.flipAnim) { self.gameState.cardFlipRotations[id] = 180 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { completion() }
                }
            }

    private func cleanupAnimatedCard(_ id: UUID) {
        gameState.animatingCards.removeValue(forKey: id)
        gameState.animatingCardPositions.removeValue(forKey: id)
        gameState.animatingCardScales.removeValue(forKey: id)
        gameState.animatingCardOpacities.removeValue(forKey: id)
        gameState.cardFlipRotations.removeValue(forKey: id)
        gameState.cardFlipScales.removeValue(forKey: id)
    }

    // MARK: - Collect to Shoe (sequential)
    private func collectCardsToDiscard(onComplete: @escaping () -> Void) {
        let sequence: [Card] = gameState.dealtPlayerCards + gameState.dealtDealerCards
        guard !sequence.isEmpty else { onComplete(); return }

        isCollectingPhase = true
        collectingCardIds.removeAll()
        arrivalOrder.removeAll()

        func startCollect(at index: Int) {
            if index >= sequence.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    discardPile.append(contentsOf: sequence)
                    gameState.dealtPlayerCards = []
                    gameState.dealtDealerCards = []
                    finalPlayerPositions.removeAll()
                    finalDealerPositions.removeAll()
                    finalSplitPositions = Array(repeating: [:], count: 2)
                    visiblePlayerCount = 0
                    visibleDealerCount = 0
                    dealerHoleRevealed = false
                    gameState.animatingCards.removeAll()
                    gameState.animatingCardPositions.removeAll()
                    gameState.animatingCardScales.removeAll()
                    gameState.animatingCardOpacities.removeAll()
                    gameState.cardFlipRotations.removeAll()
                    gameState.cardFlipScales.removeAll()
                    collectingCardIds.removeAll()
                    arrivalOrder.removeAll()
                    isCollectingPhase = false
                    onComplete()
                }
                return
            }

            let card = sequence[index]
            let id = card.id

            if let pIndex = gameState.dealtPlayerCards.firstIndex(of: card) {
                let startPos = finalPlayerPositions[id]
                    ?? CGPoint(x: xForStaticCard(idx: pIndex, count: gameState.dealtPlayerCards.count, size: tableSize),
                               y: yForHand(isPlayer: true, size: tableSize))
                gameState.animatingCardPositions[id] = startPos
                gameState.cardFlipRotations[id] = 180
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { gameState.animatingCards[id] = card }
            } else if let dIndex = gameState.dealtDealerCards.firstIndex(of: card) {
                let startPos = finalDealerPositions[id]
                    ?? CGPoint(x: xForStaticCard(idx: dIndex, count: gameState.dealtDealerCards.count, size: tableSize),
                               y: yForHand(isPlayer: false, size: tableSize))
                gameState.animatingCardPositions[id] = startPos
                let isFaceUp = gameState.flippedDealerCards.contains(dIndex)
                gameState.cardFlipRotations[id] = isFaceUp ? 180 : 0
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { gameState.animatingCards[id] = card }
            }

            collectingCardIds.insert(id)
            arrivalOrder[id] = index

            withAnimation(collectTravelAnim) {
                gameState.animatingCardPositions[id] = shoePosition
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) { startCollect(at: index + 1) }
        }

        startCollect(at: 0)
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
                    .onChange(of: numberOfDecks) { _ in
                        gameEngine.resetDeck(gameState: gameState, numberOfDecks: numberOfDecks)
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

