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
                    .font(.headline)
                    .foregroundColor(.white)
                Text("(\(gameState.isPlayerTurn ? String(gameEngine.handValue([gameState.dealerHand.first].compactMap { $0 })) : gameEngine.getHandValueText(gameState.dealerHand)))")
                    .font(.subheadline)
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
                    .font(.headline)
                    .foregroundColor(.white)
                Text("(\(gameState.isSplit ? gameEngine.getHandValueText(gameState.splitHands[gameState.activeHandIndex]) : gameEngine.getHandValueText(gameState.playerHand)))")
                    .font(.subheadline)
                    .foregroundColor(.yellow)
            }
            
            if gameState.isSplit {
                SplitHandsView(gameState: gameState, gameEngine: gameEngine)
            } else {
                RegularPlayerHandView(gameState: gameState)
            }
        }
        .frame(height: 240)
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
                        Text("Hand \(idx + 1)\(gameState.activeHandIndex == idx ? " (Active)" : "")")
                            .font(.caption)
                            .foregroundColor(gameState.activeHandIndex == idx ? .yellow : .gray)
                        Text("(\(gameEngine.getHandValueText(gameState.splitHands[idx])))")
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

// MARK: - Flip Card View
struct FlipCardView: View {
    let card: Card
    let isFlipped: Bool
    var width: CGFloat = 60
    var glowWidth: CGFloat = 70
    @AppStorage("cardUnderglow") private var cardUnderglow: Bool = true
    
    var body: some View {
        ZStack {
            if cardUnderglow && glowColor != .clear {
                RoundedRectangle(cornerRadius: 12)
                    .fill(glowColor)
                    .frame(width: glowWidth, height: 98)
                    .blur(radius: 12)
                    .opacity(0.7)
            }
            
            ZStack {
                // Card face (shown when flipped)
                Image(cardImageName)
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(width: width, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 3)
                    .opacity(isFlipped ? 1.0 : 0.0)
                
                // Deck cover (shown when not flipped)
                Image("DeckCover")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(width: width, height: 90)
                    .shadow(radius: 3)
                    .opacity(isFlipped ? 0.0 : 1.0)
            }
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.easeInOut(duration: 0.6), value: isFlipped)
        }
    }
    
    // Calculate the card image name based on flip state
    private var cardImageName: String {
        let rankString: String
        switch card.rank {
        case .ace: rankString = "Ace"
        case .jack: rankString = "Jack"
        case .queen: rankString = "Queen"
        case .king: rankString = "King"
        default: rankString = "\(card.rank.rawValue)"
        }
        
        let suitString: String
        switch card.suit {
        case .spades: suitString = "Spades"
        case .hearts: suitString = "Hearts"
        case .diamonds: suitString = "Diamonds"
        case .clubs: suitString = "Clubs"
        }
        
        return "\(rankString)Of\(suitString)"
    }
    
    var glowColor: Color {
        switch card.rank {
        case .ten, .jack, .queen, .king, .ace:
            return Color.red
        case .two, .three, .four, .five, .six:
            return Color.green
        default:
            return Color.clear
        }
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
            if cardUnderglow && glowColor != .clear {
                RoundedRectangle(cornerRadius: 12)
                    .fill(glowColor)
                    .frame(width: glowWidth, height: 98)
                    .blur(radius: 12)
                    .opacity(0.7)
            }
            
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
                Image(card.imageName)
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(width: width, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 3)
                    .onAppear {
                        // Check if image exists
                        if UIImage(named: card.imageName) == nil {
                            print("❌ Image not found: \(card.imageName)")
                            imageLoadFailed = true
                        }
                    }
            }
        }
        .offset(y: appeared ? 0 : -250)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: appeared)
        .onAppear { 
            appeared = true
            print("🃏 Loading card image: \(card.imageName) for \(card.rank.rawValue) of \(card.suit.rawValue)")
        }
    }
    
    var glowColor: Color {
        switch card.rank {
        case .ten, .jack, .queen, .king, .ace:
            return Color.red
        case .two, .three, .four, .five, .six:
            return Color.green
        default:
            return Color.clear
        }
    }
} 