import SwiftUI

// MARK: - Hand Display Components
struct BlackjackHandView: View {
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        VStack(spacing: 0) {
            // Dealer area
            DealerHandView(gameState: gameState, gameEngine: gameEngine)
            
            Spacer().frame(height: 8)
            
            // Player area
            PlayerHandView(gameState: gameState, gameEngine: gameEngine)
        }
    }
}

// MARK: - Dealer Hand View
struct DealerHandView: View {
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Dealer")
                    .font(.fixedSystem(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(gameState.isPlayerTurn ? String(gameEngine.handValue([gameState.dealerHand.first].compactMap { $0 })) : gameEngine.getHandValueText(gameState.dealerHand))
                    .font(.fixedSystem(size: 15, weight: .regular))
                    .foregroundColor(.yellow)
            }
            
            HStack(spacing: 8) {
                ForEach(gameState.dealtDealerCards.indices, id: \.self) { idx in
                    if idx == 0 || !gameState.isPlayerTurn {
                        CardView(card: gameState.dealtDealerCards[idx], width: 60, glowWidth: 70)
                            .layoutPriority(1)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        Image("DeckCover")
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(width: 60, height: 90)
                            .shadow(radius: 3)
                            .layoutPriority(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Player Hand View
struct PlayerHandView: View {
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Player")
                    .font(.fixedSystem(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(gameState.isSplit ? gameEngine.getHandValueText(gameState.splitHands[gameState.activeHandIndex]) : gameEngine.getHandValueText(gameState.playerHand))
                    .font(.fixedSystem(size: 15, weight: .regular))
                    .foregroundColor(.yellow)
            }
            
            if gameState.isSplit {
                SplitHandsView(gameState: gameState, gameEngine: gameEngine)
            } else {
                RegularPlayerHandView(gameState: gameState)
            }
        }
        .frame(height: 240)
        .disableDynamicType()
    }
}

// MARK: - Regular Player Hand View
struct RegularPlayerHandView: View {
    let gameState: BlackjackGameState
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(gameState.dealtPlayerCards) { card in
                CardView(card: card, width: 60, glowWidth: 70)
                    .layoutPriority(1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Split Hands View
struct SplitHandsView: View {
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        HStack(spacing: 24) {
            ForEach(gameState.splitHands.indices, id: \.self) { idx in
                VStack {
                    HStack {
                                                    Text("Hand \(idx == 1 ? 1 : 2)\(gameState.activeHandIndex == idx ? " (Active)" : "")")
                            .font(.caption)
                            .foregroundColor(gameState.activeHandIndex == idx ? .yellow : .gray)
                        Text(gameEngine.getHandValueText(gameState.splitHands[idx]))
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(gameState.splitHands[idx]) { card in
                            CardView(card: card, width: 60, glowWidth: 70)
                                .layoutPriority(1)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}

// MARK: - Flip Card View (natural flip: back 0→180, face -180→0; no lingering rotation at rest)
struct FlipCardView: View {
    let card: Card
    let isFlipped: Bool
    var width: CGFloat = 60
    var glowWidth: CGFloat = 70
    @AppStorage("cardUnderglow") private var cardUnderglow: Bool = true

    // Flip control
    private let flipDuration: Double = 0.26
    @State private var isAnimatingFlip: Bool = false
    @State private var rotation: Double = 0          // 0 → 180 during flip
    @State private var showingFace: Bool = false     // which side is shown at rest (no rotation)
    
    var body: some View {
        ZStack {
            
            Group {
                if isAnimatingFlip {
                    // During flip: two layers with opposing rotations for a natural hinge
            ZStack {
                        // FACE (becomes visible after 90°, ends at 0°)
                Image(cardImageName)
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(width: width, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(rotation >= 90 ? 1 : 0)
                            .rotation3DEffect(
                                .degrees(rotation - 180),
                                axis: (x: 0, y: 1, z: 0), perspective: 0.6
                            )
                
                        // BACK (starts at 0°, disappears after 90°)
                        Image("DeckCover")
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(width: width, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(rotation >= 90 ? 0 : 1)
                            .rotation3DEffect(
                                .degrees(rotation),
                                axis: (x: 0, y: 1, z: 0), perspective: 0.6
                            )
                    }
                } else {
                    // At rest: render a single side without any rotation
                    if showingFace {
                        Image(cardImageName)
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(width: width, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                Image("DeckCover")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(width: width, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.3), value: showingFace)
            }
        .onAppear {
            showingFace = isFlipped
            rotation = 0
        }
        .onChange(of: isFlipped) { newValue in
            guard showingFace != newValue else { return }
            // Run a consistent flip: BACK 0→180, FACE -180→0
            isAnimatingFlip = true
            rotation = 0
            withAnimation(.easeInOut(duration: flipDuration)) {
                rotation = 180
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + flipDuration) {
                showingFace = newValue
                isAnimatingFlip = false
                rotation = 0 // normalize at rest
            }
        }
    }
    
    // Calculate the card image name based on card value (uses regular assets for regular mode)
    private var cardImageName: String {
        // Use face image regardless of `card.isFaceUp` — flip state is driven by `isFlipped`.
        return card.faceImageName(isTrainingMode: false)
    }
    
}

// MARK: - Card View
struct CardView: View {
    let card: Card
    var width: CGFloat = 60
    var glowWidth: CGFloat = 70
    @State private var appeared: Bool = false
    @State private var imageLoadFailed: Bool = false
    @AppStorage("cardUnderglow") private var cardUnderglow: Bool = true
    
    var body: some View {
        ZStack {
            
            if imageLoadFailed {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: 90)
                    .overlay(
                        VStack {
                            Text(card.rank.rawValue)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(card.suit.rawValue)
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    )
            } else {
                Image(card.imageName(isTrainingMode: false))
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(width: width, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onAppear {
                        // Check if image exists
                        if UIImage(named: card.imageName(isTrainingMode: false)) == nil {
                            print("❌ Image not found: \(card.imageName(isTrainingMode: false))")
                            imageLoadFailed = true
                        }
                    }
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: appeared)
        .offset(y: appeared ? 0 : -250)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: appeared)
        .onAppear { 
            appeared = true
            print("🃏 Loading card image: \(card.imageName(isTrainingMode: false)) for \(card.rank.rawValue) of \(card.suit.rawValue)")
        }
    }
    
} 

