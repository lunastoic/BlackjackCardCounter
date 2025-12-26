import SwiftUI

// MARK: - Training Mode Card Components with Glow Effects

struct TrainingModeFlipCardView: View {
    let card: Card
    let isFlipped: Bool
    let width: CGFloat
    let glowWidth: CGFloat
    @AppStorage("cardUnderglow") private var cardUnderglow: Bool = true
    
    // Flip control (matching regular mode)
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
                        faceView
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
                        faceView
                    } else {
                        Image("DeckCover")
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(width: width, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(cardUnderglow && showingFace && glowColor != .clear ? glowColor : Color.clear, lineWidth: cardUnderglow && showingFace && glowColor != .clear ? 2 : 0)
                    .blur(radius: 1)
            )
            .shadow(color: cardUnderglow && showingFace && glowColor != .clear ? glowColor.opacity(0.8) : .black.opacity(0.18), radius: cardUnderglow && showingFace && glowColor != .clear ? 2 : 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
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
    
    // Calculate the card image name based on card value (uses T_ prefixed assets for training mode)
    private var cardImageName: String {
        // Always use the face-up version of the card for training mode
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
        @unknown default: suitString = "Clubs"
        }
        
        // Always use T_ prefix for training mode
        let baseName = "\(rankString)Of\(suitString)"
        let imageName = "T_\(baseName)"
        return imageName
    }

    private var faceView: some View {
        Group {
            if UIImage(named: cardImageName) != nil {
                Image(cardImageName)
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
            } else {
                // Fallback: render rank/suit so we never show a blank outline card
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.25))
                    .overlay(
                        VStack(spacing: 2) {
                            Text(card.rank.rawValue)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            Text(card.suit.rawValue)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    )
            }
        }
        .frame(width: width, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // Training mode glow color logic
    private var glowColor: Color {
        switch card.rank {
        case .ten, .jack, .queen, .king, .ace:
            return Color.red // Bright neon red
        case .two, .three, .four, .five, .six:
            return Color(red: 0.0, green: 1.0, blue: 0.0) // Vibrant neon green
        case .seven, .eight, .nine:
            return Color(red: 0.3, green: 0.3, blue: 0.3) // Darker neon gray
        @unknown default:
            return Color.clear
        }
    }
}

struct TrainingModeCardView: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    let glowWidth: CGFloat
    @AppStorage("cardUnderglow") private var cardUnderglow: Bool = true
    
    @State private var appeared = false
    @State private var imageLoadFailed = false
    
    var body: some View {
        ZStack {
            if imageLoadFailed {
                // Fallback view if image fails to load
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay(
                        Text("?")
                            .font(.title)
                            .foregroundColor(.white)
                    )
            } else {
                Image(card.imageName(isTrainingMode: true))
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onAppear {
                        // Check if image exists
                        if UIImage(named: card.imageName(isTrainingMode: true)) == nil {
                            imageLoadFailed = true
                        }
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardUnderglow && glowColor != .clear ? glowColor : Color.clear, lineWidth: cardUnderglow && glowColor != .clear ? 2 : 0)
                .blur(radius: 1)
        )
        .shadow(color: cardUnderglow && glowColor != .clear ? glowColor.opacity(0.8) : .black.opacity(0.18), radius: cardUnderglow && glowColor != .clear ? 2 : 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.3), value: glowColor)
        .offset(y: appeared ? 0 : -250)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: appeared)
        .onAppear { 
            appeared = true 
        }
    }
    
    // Training mode glow color logic
    private var glowColor: Color {
        switch card.rank {
        case .ten, .jack, .queen, .king, .ace:
            return Color.red // Bright neon red
        case .two, .three, .four, .five, .six:
            return Color(red: 0.0, green: 1.0, blue: 0.0) // Vibrant neon green
        case .seven, .eight, .nine:
            return Color(red: 0.3, green: 0.3, blue: 0.3) // Darker neon gray
        @unknown default:
            return Color.clear
        }
    }
}
