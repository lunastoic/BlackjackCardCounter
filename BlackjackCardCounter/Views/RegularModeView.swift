import SwiftUI

struct RegularModeView: View {
    let map: Map
    
    // Shared game state and managers
    @StateObject private var gameState = BlackjackGameState()
    private let gameEngine = BlackjackGameEngine.shared
    private let bettingManager = BlackjackBettingManager.shared
    
    // Regular mode specific state
    @State private var discardPile: [Card] = []
    @Namespace private var cardAnimation
    @State private var showZeroChipsOverlay = false
    
    var body: some View {
        ZStack {
            Color(hex: "1a1a2e")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                GameHeaderView()
                
                VStack(spacing: 0) {
                    // Deck and Discard piles at the top
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
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .onAppear {
                                                gameState.deckFrame = geometry.frame(in: .global)
                                                gameState.deckPosition = CGPoint(
                                                    x: geometry.frame(in: .global).midX,
                                                    y: geometry.frame(in: .global).midY
                                                )
                                            }
                                            .onChange(of: geometry.frame(in: .global)) { newFrame in
                                                gameState.deckFrame = newFrame
                                                gameState.deckPosition = CGPoint(
                                                    x: newFrame.midX,
                                                    y: newFrame.midY
                                                )
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
                    
                    // Dealer area
                    VStack(spacing: 8) {
                        Text("Dealer")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("(\(dealerValueLabel()))")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                        HStack(spacing: 8) {
                            ForEach(gameState.dealtDealerCards.indices, id: \.self) { idx in
                                FlipCardView(
                                    card: gameState.dealtDealerCards[idx],
                                    isFlipped: gameState.flippedDealerCards.contains(idx),
                                    width: 60,
                                    glowWidth: 0
                                )
                                .matchedGeometryEffect(id: "dealerCard_\(idx)_\(gameState.dealtDealerCards[idx].id)", in: cardAnimation)
                                .animation(nil, value: gameState.dealtDealerCards.count)
                            }
                                }
                            }
                    
                    Spacer().frame(height: 32)
                    
                    // Player area
                    VStack(spacing: 8) {
                        Text("Player")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(gameEngine.getHandValueText(gameState.playerHand))
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                        HStack(spacing: 8) {
                            ForEach(gameState.dealtPlayerCards.indices, id: \.self) { idx in
                                CardView(card: gameState.dealtPlayerCards[idx], width: 60, glowWidth: 0)
                                    .matchedGeometryEffect(id: "playerCard_\(gameState.dealtPlayerCards[idx].id)", in: cardAnimation)
                                    .animation(nil, value: gameState.dealtPlayerCards.count)
                            }
                        }
                    }
                    
                    Spacer().frame(height: 32)
                    
                    // Result message
                    if let result = gameState.resultMessage {
                        Text(result)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 8)
                    }
                    
                    // Betting area
                    BlackjackBettingView(
                        gameState: gameState,
                        bettingManager: bettingManager,
                        gameEngine: gameEngine
                    )
                    
                    // Chips at the bottom (always visible before a hand is dealt or after a round is over)
                    if !gameState.showNextHand {
                        ChipSelectionView(
                            gameState: gameState,
                            bettingManager: bettingManager
                        )
                    }
                    
                    // Deal/Next Hand Button at the very bottom
                    if gameState.resultMessage != nil || (!gameState.showNextHand && gameState.playerHand.isEmpty && gameState.dealerHand.isEmpty) {
                        DealNextHandButtons(
                            gameState: gameState,
                            gameEngine: gameEngine,
                            bettingManager: bettingManager
                        )
                        }
                    
                    // Action buttons
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
            
            // Animating cards overlay (on top of everything)
            ForEach(Array(gameState.animatingCards.keys), id: \.self) { cardId in
                if let card = gameState.animatingCards[cardId] {
                    ZStack {
                        // Card face (shown when flipped)
                        Image(card.imageName)
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(width: 60, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 3)
                            .opacity(gameState.cardFlipRotations[cardId] ?? 0 > 90 ? 1.0 : 0.0)
                        
                        // Deck cover (shown when not flipped)
                        Image("DeckCover")
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(width: 60, height: 90)
                            .shadow(radius: 3)
                            .opacity(gameState.cardFlipRotations[cardId] ?? 0 > 90 ? 0.0 : 1.0)
                    }
                    .position(
                        x: gameState.animatingCardPositions[cardId]?.x ?? 0,
                        y: gameState.animatingCardPositions[cardId]?.y ?? 0
                    )
                    .scaleEffect(gameState.animatingCardScales[cardId] ?? 1.0)
                    .opacity(gameState.animatingCardOpacities[cardId] ?? 1.0)
                    .rotation3DEffect(
                        .degrees(gameState.cardFlipRotations[cardId] ?? 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .scaleEffect(gameState.cardFlipScales[cardId] ?? 1.0)
                    .allowsHitTesting(false)
                }
            }
        }
        .overlay {
            if showZeroChipsOverlay {
                ZeroChipsOverlay(isPresented: $showZeroChipsOverlay)
            }
        }
        .onAppear {
            gameEngine.resetDeck(gameState: gameState)
        }
    }
    
    private func dealerValueLabel() -> String {
        if gameState.dealerHand.count < 2 {
            return "?"
        } else if gameState.isPlayerTurn {
            return gameEngine.getHandValueText([gameState.dealerHand[1]])
        } else {
            return gameEngine.getHandValueText(gameState.dealerHand)
        }
    }
}

#Preview {
    RegularModeView(map: Map(id: 1, name: "Mercury", imageName: "MercuryImage", isLocked: false, requiredLevel: 1))
} 
