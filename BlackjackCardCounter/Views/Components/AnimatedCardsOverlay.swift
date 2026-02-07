import SwiftUI

// MARK: - Animated Cards Overlay
// Reusable overlay for animated and static cards (excluding split cards)

struct AnimatedCardsOverlay: View {
    // Animation state
    let animatingCards: [UUID: Card]
    let animatingCardPositions: [UUID: CGPoint]
    let cardFlipRotations: [UUID: Double]
    let arrivalOrder: [UUID: Int]
    let collectingCardIds: Set<UUID>
    let isCollectingPhase: Bool
    
    // Card data
    let dealtPlayerCards: [Card]
    let dealtDealerCards: [Card]
    let flippedDealerCards: Set<Int>
    
    // Position data
    let finalPlayerPositions: [UUID: CGPoint]
    let finalDealerPositions: [UUID: CGPoint]
    let tableSize: CGSize
    
    // Animation namespace
    let mgCards: Namespace.ID
    
    // Split state
    let isSplit: Bool
    
    var body: some View {
        ZStack {
            // Animated cards overlay
            ForEach(Array(animatingCards.keys), id: \.self) { cardId in
                if let card = animatingCards[cardId],
                   let pos = animatingCardPositions[cardId] {
                    
                    // Only show animated cards for non-split hands (split cards are in separate overlay)
                    if !isSplit {
                        let core = ZStack {
                            // Use face image regardless of `card.isFaceUp` — flip is controlled by rotation.
                            Image(card.faceImageName(isTrainingMode: false))
                                .resizable()
                                .aspectRatio(0.7, contentMode: .fit)
                                .frame(width: CardMetrics.cardSize.width, height: CardMetrics.cardSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 3)
                                .opacity((cardFlipRotations[cardId] ?? 0) > 90 ? 1 : 0)
                                .rotation3DEffect(
                                    .degrees((cardFlipRotations[cardId] ?? 0) - 180),
                                    axis: (x: 0, y: 1, z: 0), perspective: 0.6
                                )

                            Image("DeckCover")
                                .resizable()
                                .aspectRatio(0.7, contentMode: .fit)
                                .frame(width: CardMetrics.cardSize.width, height: CardMetrics.cardSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 3)
                                .opacity((cardFlipRotations[cardId] ?? 0) > 0 ? 0 : 1)
                                .rotation3DEffect(
                                    .degrees(cardFlipRotations[cardId] ?? 0),
                                    axis: (x: 0, y: 1, z: 0), perspective: 0.6
                                )
                                .allowsHitTesting(false)
                                .zIndex(-1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .allowsHitTesting(false)

                        Group {
                            if isCollectingPhase { 
                                core.position(pos) 
                            } else { 
                                core.matchedGeometryEffect(id: card.id, in: mgCards).position(pos) 
                            }
                        }
                        .allowsHitTesting(false)
                        .zIndex(1000 + Double(arrivalOrder[cardId] ?? 0)) // Much higher z-index for animated cards
                    }
                }
            }

            // Static cards (dealer)
            ForEach(Array(dealtDealerCards.enumerated()), id: \.offset) { idx, card in
                if !animatingCards.keys.contains(card.id) {
                    let computedX = CardPositioning.xForStaticCard(
                        idx: idx, 
                        count: dealtDealerCards.count, 
                        size: tableSize,
                            isDealing: false, // This should be passed as parameter if needed
                            isPlayer: false
                    )
                    let computedY = CardPositioning.yForHand(isPlayer: false, size: tableSize)
                    let pos = finalDealerPositions[card.id] ?? CGPoint(x: computedX, y: computedY)

                    FlipCardView(
                        card: card,
                        isFlipped: flippedDealerCards.contains(idx),
                        width: CardMetrics.cardSize.width,
                        glowWidth: 0
                    )
                    .matchedGeometryEffect(id: card.id, in: mgCards)
                    .position(pos)
                    .offset(y: isSplit ? 10 : 0) // Counter-offset to keep dealer cards in place when split
                    .opacity(collectingCardIds.contains(card.id) ? 0 : 1)
                    .allowsHitTesting(false)
                    .transition(.identity)
                    .animation(.easeInOut(duration: 0.3), value: dealtDealerCards.count)
                }
            }

            // Static cards (player non-split)
            if !isSplit {
                ForEach(Array(dealtPlayerCards.enumerated()), id: \.offset) { idx, card in
                    if !animatingCards.keys.contains(card.id) {
                        let computedX = CardPositioning.xForStaticCard(
                            idx: idx, 
                            count: dealtPlayerCards.count, 
                            size: tableSize,
                            isDealing: false, // This should be passed as parameter if needed
                            isPlayer: true
                        )
                        let computedY = CardPositioning.yForHand(isPlayer: true, size: tableSize)
                        let pos = finalPlayerPositions[card.id] ?? CGPoint(x: computedX, y: computedY)

                        FlipCardView(card: card, isFlipped: true, width: CardMetrics.cardSize.width, glowWidth: 0)
                            .matchedGeometryEffect(id: card.id, in: mgCards)
                            .position(pos)
                            .opacity(collectingCardIds.contains(card.id) ? 0 : 1)
                            .allowsHitTesting(false)
                            .transition(.identity)
                            .animation(.easeInOut(duration: 0.3), value: dealtPlayerCards.count)
                    }
                }
            }
        }
    }
}
