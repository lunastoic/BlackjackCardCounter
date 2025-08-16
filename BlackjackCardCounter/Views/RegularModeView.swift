import SwiftUI
//test
struct RegularModeView: View {
    let map: Map

    // Shared game state and managers
    @StateObject private var gameState = BlackjackGameState()
    private let gameEngine = BlackjackGameEngine.shared
    private let bettingManager = BlackjackBettingManager.shared

    // Regular mode specific state
    @State private var discardPile: [Card] = []
    @Namespace private var cardAnimation              // existing namespace (deck/discard)
    @Namespace private var mgCards                   // matched geometry for card handoff
    @State private var showZeroChipsOverlay = false

    // Table geometry (single source of truth)
    @State private var tableSize: CGSize = .zero

    // Cache exact end positions so static cards “lock” where overlays end
    @State private var finalPlayerPositions: [UUID : CGPoint] = [:]
    @State private var finalDealerPositions: [UUID : CGPoint] = [:]

    // Layout
    private let cardSize = CGSize(width: 60, height: 90)
    private let cardSpacing: CGFloat = 70
    private let dealerYOffset: CGFloat = -43
    private let playerYOffset: CGFloat = -7

    // Animations (straight move + flip)
    private let travelAnim  = Animation.easeInOut(duration: 0.50)
    private let flipAnim    = Animation.easeInOut(duration: 0.26)

    // Visible counts (labels update only after flips complete)
    @State private var visiblePlayerCount: Int = 0
    @State private var visibleDealerCount: Int = 0
    @State private var dealerHoleRevealed: Bool = false  // set when hole card starts flipping

    var body: some View {
        GeometryReader { tableGeo in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "1a3a1a"), Color(hex: "2d5a2d")]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Background arched text
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
                    }
                    .allowsHitTesting(false)
                }
                .zIndex(0)

                VStack(spacing: 0) {
                    GameHeaderView()

                    VStack(spacing: 0) {
                        // Deck & Discard (top)
                        HStack {
                            // Deck pile (left)
                            VStack {
                                Image("DeckCover")
                                    .resizable()
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .frame(width: 48, height: 72)
                                    .shadow(radius: 4)
                                    .matchedGeometryEffect(id: "deckPile", in: cardAnimation)
                                    .scaleEffect(gameState.isDealing ? 0.95 : 1.0)
                                    .offset(x: gameState.isDealing ? -2 : 0, y: gameState.isDealing ? -1 : 0)
                                    .animation(.easeInOut(duration: 0.2), value: gameState.isDealing)
                                    .overlay(
                                        GeometryReader { geometry in
                                            Color.clear
                                                .onAppear {
                                                    let f = geometry.frame(in: .named("table"))
                                                    gameState.deckFrame = f
                                                    gameState.deckPosition = CGPoint(x: f.midX, y: f.midY)
                                                }
                                                .onChange(of: geometry.frame(in: .named("table"))) { newF in
                                                    gameState.deckFrame = newF
                                                    gameState.deckPosition = CGPoint(x: newF.midX, y: newF.midY)
                                                }
                                        }
                                    )
                                Text("Deck")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            // Discard pile (right)
                            VStack {
                                if let lastDiscard = discardPile.last {
                                    CardView(card: lastDiscard, width: 48, glowWidth: 0)
                                        .matchedGeometryEffect(id: "discardPile", in: cardAnimation)
                                } else {
                                    Image("DeckCover")
                                        .resizable()
                                        .aspectRatio(0.7, contentMode: .fit)
                                        .frame(width: 48, height: 72)
                                        .opacity(0.3)
                                        .matchedGeometryEffect(id: "discardPile", in: cardAnimation)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 12)

                        Spacer().frame(height: 16)

                        // Dealer
                        VStack(spacing: 8) {
                            Text("Dealer").font(.headline).foregroundColor(.white)
                            Text(dealerValueLabel()).font(.subheadline).foregroundColor(.yellow)

                            // Hidden placeholders (stable IDs)
                            HStack(spacing: 8) {
                                ForEach(Array(gameState.dealtDealerCards.enumerated()), id: \.element.id) { idx, card in
                                    FlipCardView(
                                        card: card,
                                        isFlipped: gameState.flippedDealerCards.contains(idx),
                                        width: cardSize.width, glowWidth: 0
                                    )
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
                            Text("Player").font(.headline).foregroundColor(.white)
                            Text(playerValueLabel())
                                .font(.subheadline).foregroundColor(.yellow)

                            // Hidden placeholders (stable IDs)
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
                        .frame(height: 140)

                        Spacer().frame(height: 32)

                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Spacer().frame(height: 250)
                        }

                        if let result = gameState.resultMessage {
                            Text(result)
                                .font(.title2).fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 8)
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
                                    // index: 0=P1, 1=D1 (hole, no flip), 2=P2, 3=D2 (upcard)
                                    if index == 0 {
                                        // new round — reset visible counters & flags
                                        visiblePlayerCount = 0
                                        visibleDealerCount = 0
                                        dealerHoleRevealed = false
                                        finalPlayerPositions.removeAll()
                                        finalDealerPositions.removeAll()
                                    }

                                    let isPlayer = (index == 0 || index == 2)

                                    // Slot mapping for initial two cards (no stacking)
                                    let slotIndex: Int = isPlayer
                                        ? (index == 0 ? 0 : 1)
                                        : (index == 1 ? 0 : 1)

                                    let midX = tableSize.width * 0.5
                                    let startX = midX - (cardSpacing / 2)
                                    let x = startX + CGFloat(slotIndex) * cardSpacing
                                    let y = yForHand(isPlayer: isPlayer, size: tableSize)
                                    let destination = CGPoint(x: x, y: y)

                                    if isPlayer { finalPlayerPositions[card.id] = destination }
                                    else { finalDealerPositions[card.id] = destination }

                                    let shouldFlip = (index != 1) // dealer hole-card stays down
                                    animateDeal(card: card, to: destination, shouldFlip: shouldFlip) {
                                        withAnimation(.easeInOut(duration: 0.001)) { completion() }
                                        cleanupAnimatedCard(card.id)

                                        // Bump visible counters ONLY after flip has completed
                                        if isPlayer {
                                            visiblePlayerCount += 1
                                        } else {
                                            if index == 3 {            // dealer upcard (flipped)
                                                visibleDealerCount = 1 // show ONLY the upcard during player's turn
                                            }
                                            // hole card remains hidden; will be counted when its flip finishes
                                        }
                                    }
                                }
                            )
                        }

                        if gameState.showNextHand && gameState.isPlayerTurn && gameState.resultMessage == nil {
                            BlackjackActionButtons(
                                gameState: gameState,
                                gameEngine: gameEngine,
                                showStrategyHints: false,
                                getPerfectStrategyAction: { nil }
                            )
                        }

                        Spacer()
                    }
                }

                // ---- Animated cards overlay (straight move + flip) ----
                ForEach(Array(gameState.animatingCards.keys), id: \.self) { cardId in
                    if let card = gameState.animatingCards[cardId] {
                        ZStack {
                            // Face (opposite half; ends at 0°)
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

                            // Back (0° → 180°)
                            Image("DeckCover")
                                .resizable()
                                .aspectRatio(0.7, contentMode: .fit)
                                .frame(width: cardSize.width, height: cardSize.height)
                                .shadow(radius: 3)
                                .opacity((gameState.cardFlipRotations[cardId] ?? 0) > 90 ? 0 : 1)
                                .rotation3DEffect(
                                    .degrees(gameState.cardFlipRotations[cardId] ?? 0),
                                    axis: (x: 0, y: 1, z: 0), perspective: 0.6
                                )
                        }
                        .matchedGeometryEffect(id: card.id, in: mgCards)
                        .position(
                            x: gameState.animatingCardPositions[cardId]?.x ?? gameState.deckPosition.x,
                            y: gameState.animatingCardPositions[cardId]?.y ?? gameState.deckPosition.y
                        )
                        .allowsHitTesting(false)
                        .zIndex(10)
                    }
                }

                // ---- Static cards (lock to cached positions) ----
                // Dealer
                ForEach(Array(gameState.dealtDealerCards.enumerated()), id: \.element.id) { idx, card in
                    if !gameState.animatingCards.keys.contains(card.id) {
                        let computedX = xForStaticCard(idx: idx, count: gameState.dealtDealerCards.count, size: tableSize)
                        let computedY = yForHand(isPlayer: false, size: tableSize)
                        let pos = finalDealerPositions[card.id] ?? CGPoint(x: computedX, y: computedY)

                        FlipCardView(
                            card: card,
                            isFlipped: gameState.flippedDealerCards.contains(idx),
                            width: cardSize.width, glowWidth: 0
                        )
                        .matchedGeometryEffect(id: card.id, in: mgCards)
                        .position(pos)
                        .opacity(1)
                        .allowsHitTesting(false)
                        .transition(.identity)
                        .animation(.easeInOut(duration: 0.3), value: gameState.dealtDealerCards.count)
                    }
                }

                // Player
                ForEach(Array(gameState.dealtPlayerCards.enumerated()), id: \.element.id) { idx, card in
                    if !gameState.animatingCards.keys.contains(card.id) {
                        let computedX = xForStaticCard(idx: idx, count: gameState.dealtPlayerCards.count, size: tableSize)
                        let computedY = yForHand(isPlayer: true, size: tableSize)
                        let pos = finalPlayerPositions[card.id] ?? CGPoint(x: computedX, y: computedY)

                        FlipCardView(card: card, isFlipped: true, width: cardSize.width, glowWidth: 0)
                            .matchedGeometryEffect(id: card.id, in: mgCards)
                            .position(pos)
                            .opacity(1)
                            .allowsHitTesting(false)
                            .transition(.identity)
                            .animation(.easeInOut(duration: 0.3), value: gameState.dealtPlayerCards.count)
                    }
                }
            }
            .coordinateSpace(name: "table")
            .onAppear {
                tableSize = tableGeo.size

                // Prewarm images
                _ = UIImage(named: "DeckCover")
                ["AS", "KH", "7D", "9C"].forEach { _ = UIImage(named: $0) }

                gameEngine.resetDeck(gameState: gameState)

                // Hit animations
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

                        // Visible counts update AFTER flip ends
                        if isPlayerCard {
                            visiblePlayerCount += 1
                        } else {
                            visibleDealerCount += 1
                        }
                    }
                }
            }
            .onChange(of: tableGeo.size) { newSize in
                tableSize = newSize
            }
            // Dealer HOLE card: update value ONLY when the hole card's flip actually completes.
            .onChange(of: gameState.flippedDealerCards) { newSet in
                // If index 1 just flipped (starts flipping), bump visible count after flip duration
                if newSet.contains(1), !dealerHoleRevealed {
                    dealerHoleRevealed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                        visibleDealerCount = max(visibleDealerCount, 2)
                    }
                }
            }
            .onDisappear {
                gameEngine.hitAnimationCallback = nil
            }
            .overlay {
                if showZeroChipsOverlay {
                    ZeroChipsOverlay(isPresented: $showZeroChipsOverlay)
                }
            }
        }
    }

    // MARK: - Value labels (use only cards that are visually revealed)
    private func dealerValueLabel() -> String {
        let shown = dealerShownCards()
        guard !shown.isEmpty else { return "?" }
        return gameEngine.getHandValueText(shown)
    }

    // IMPORTANT FIX:
    // During player's turn: show ONLY the upcard when it's visible (count >= 1).
    // After player's turn ends but BEFORE the hole flip completes: STILL show ONLY the upcard
    //   to avoid flashing the hole-card value by itself.
    // After the hole flip completes (we bump visibleDealerCount to >= 2): show both, then include hits.
    private func dealerShownCards() -> [Card] {
        // If we don't even have two cards dealt, show none
        guard gameState.dealerHand.count >= 1 else { return [] }

        let upcardIndex = 1
        let holeIndex = 0

        if gameState.isPlayerTurn {
            // During player's turn, only the upcard is ever shown when visible
            if visibleDealerCount >= 1, gameState.dealerHand.count > upcardIndex {
                return [gameState.dealerHand[upcardIndex]]
            } else {
                return []
            }
        } else {
            // Player's turn ended.
            // If the hole hasn't finished its flip yet (we haven't bumped visibleDealerCount to 2),
            // keep showing ONLY the upcard to prevent a transient hole-only value.
            if visibleDealerCount == 1 {
                if gameState.dealerHand.count > upcardIndex {
                    return [gameState.dealerHand[upcardIndex]]
                } else {
                    return []
                }
            } else {
                // Hole has flipped (visibleDealerCount >= 2) — now show in deal order.
                return Array(gameState.dealerHand.prefix(visibleDealerCount))
            }
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

    // Keep initial 2-card layout during initial deal to avoid re-centering jumps
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
                        .font(.system(size: fontSize + 4, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.15))
                        .position(x: x, y: y)
                    Text(String(chars[i]))
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .position(x: x, y: y)
                }
            }
        }
    }

    // MARK: - Position Management
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
        let cardId = card.id

        gameState.animatingCards[cardId] = card
        gameState.animatingCardPositions[cardId] = gameState.deckPosition
        gameState.cardFlipRotations[cardId] = 0 // back

        withAnimation(travelAnim) {
            gameState.animatingCardPositions[cardId] = destination
        }

        let travelT: Double = 0.50
        if shouldFlip {
            DispatchQueue.main.asyncAfter(deadline: .now() + travelT) {
                withAnimation(flipAnim) { gameState.cardFlipRotations[cardId] = 180 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { completion() }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + travelT) { completion() }
        }
    }

    private func animateHitCard(card: Card, to destination: CGPoint, completion: @escaping () -> Void) {
        let cardId = card.id
        gameState.animatingCards[cardId] = card
        gameState.animatingCardPositions[cardId] = gameState.deckPosition
        gameState.cardFlipRotations[cardId] = 0

        withAnimation(travelAnim) {
            gameState.animatingCardPositions[cardId] = destination
        }

        let travelT: Double = 0.50
        DispatchQueue.main.asyncAfter(deadline: .now() + travelT) {
            withAnimation(flipAnim) { gameState.cardFlipRotations[cardId] = 180 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { completion() }
        }
    }

    private func cleanupAnimatedCard(_ cardId: UUID) {
        gameState.animatingCards.removeValue(forKey: cardId)
        gameState.animatingCardPositions.removeValue(forKey: cardId)
        gameState.animatingCardScales.removeValue(forKey: cardId)
        gameState.animatingCardOpacities.removeValue(forKey: cardId)
        gameState.cardFlipRotations.removeValue(forKey: cardId)
        gameState.cardFlipScales.removeValue(forKey: cardId)
    }

    // Collect to discard (unchanged)
    private func collectCardsToDiscard(onComplete: @escaping () -> Void) {
        let allCards = gameState.dealtPlayerCards + gameState.dealtDealerCards
        let discardPos = CGPoint(x: gameState.deckFrame.maxX + 120, y: gameState.deckFrame.minY + 36)
        var remaining = allCards.count

        for card in allCards {
            let cardId = card.id
            gameState.animatingCards[cardId] = card
            gameState.animatingCardPositions[cardId] =
                gameState.playerCardPositions[gameState.dealtPlayerCards.firstIndex(of: card) ?? 0] ?? discardPos
            gameState.animatingCardScales[cardId] = 1.0
            gameState.animatingCardOpacities[cardId] = 1.0
            withAnimation(.easeInOut(duration: 0.7)) {
                gameState.animatingCardPositions[cardId] = discardPos
                gameState.animatingCardScales[cardId] = 0.7
                gameState.animatingCardOpacities[cardId] = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                gameState.animatingCards.removeValue(forKey: cardId)
                gameState.animatingCardPositions.removeValue(forKey: cardId)
                gameState.animatingCardScales.removeValue(forKey: cardId)
                gameState.animatingCardOpacities.removeValue(forKey: cardId)
                remaining -= 1
                if remaining == 0 {
                    discardPile.append(contentsOf: allCards)
                    gameState.dealtPlayerCards = []
                    gameState.dealtDealerCards = []
                    visiblePlayerCount = 0
                    visibleDealerCount = 0
                    dealerHoleRevealed = false
                    onComplete()
                }
            }
        }
    }
}

#Preview {
    RegularModeView(map: Map(id: 1, name: "Mercury", imageName: "MercuryImage", isLocked: false, requiredLevel: 1))
}

