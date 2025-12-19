import SwiftUI

// MARK: - Card Animator
// Helper service for consistent card animations across Regular and Training modes

class CardAnimator {
    
    // MARK: - Deal Animation
    static func animateDeal(
        card: Card,
        to destination: CGPoint,
        shouldFlip: Bool,
        deckPosition: CGPoint,
        gameState: BlackjackGameState,
        completion: @escaping () -> Void
    ) {
        let id = card.id
        gameState.animatingCardPositions[id] = deckPosition
        gameState.cardFlipRotations[id] = 0
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { gameState.animatingCards[id] = card }

        withAnimation(CardMetrics.travelAnim) { 
            gameState.animatingCardPositions[id] = destination 
        }

        let travelT: Double = 0.50
        if shouldFlip {
            DispatchQueue.main.asyncAfter(deadline: .now() + travelT) {
                withAnimation(CardMetrics.flipAnim) { 
                    gameState.cardFlipRotations[id] = 180 
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { 
                    completion() 
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + travelT) { 
                completion() 
            }
        }
    }
    
    // MARK: - Hit Animation
    static func animateHit(
        card: Card,
        to destination: CGPoint,
        deckPosition: CGPoint,
        gameState: BlackjackGameState,
        completion: @escaping () -> Void
    ) {
        let id = card.id
        gameState.animatingCardPositions[id] = deckPosition
        gameState.cardFlipRotations[id] = 0
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { gameState.animatingCards[id] = card }
        
        print("🎯 AnimateHitCard: card=\(card.rank.rawValue)\(card.suit.rawValue), from=\(deckPosition), to=\(destination), animatingCards.count=\(gameState.animatingCards.count)")

        withAnimation(CardMetrics.travelAnim) { 
            gameState.animatingCardPositions[id] = destination 
        }

        let travelT: Double = 0.50
        DispatchQueue.main.asyncAfter(deadline: .now() + travelT) {
            withAnimation(CardMetrics.flipAnim) { 
                gameState.cardFlipRotations[id] = 180 
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { 
                completion() 
            }
        }
    }
    
    // MARK: - Split Animation
    static func animateSplit(
        card: Card,
        to destination: CGPoint,
        deckPosition: CGPoint,
        gameState: BlackjackGameState,
        completion: @escaping () -> Void
    ) {
        let id = card.id
        gameState.animatingCardPositions[id] = deckPosition
        gameState.cardFlipRotations[id] = 0
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { gameState.animatingCards[id] = card }
        
        print("🎯 Split Animation: card=\(card.rank.rawValue)\(card.suit.rawValue), destination=\(destination), deckPosition=\(deckPosition)")
        print("🎯 Split AnimateHitCard: card=\(card.rank.rawValue)\(card.suit.rawValue), from=\(deckPosition), to=\(destination), animatingCards.count=\(gameState.animatingCards.count)")

        withAnimation(CardMetrics.travelAnim) { 
            gameState.animatingCardPositions[id] = destination 
        }

        let travelT: Double = 0.50
        DispatchQueue.main.asyncAfter(deadline: .now() + travelT) {
            withAnimation(CardMetrics.flipAnim) { 
                gameState.cardFlipRotations[id] = 180 
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                withAnimation(.easeInOut(duration: 0.001)) { 
                    completion() 
                }
            }
        }
    }
    
    // MARK: - Collect to Shoe Animation
    static func collectCardsToDiscard(
        sequence: [Card],
        shoePosition: CGPoint,
        finalPlayerPositions: [UUID: CGPoint],
        finalDealerPositions: [UUID: CGPoint],
        dealtPlayerCards: [Card],
        dealtDealerCards: [Card],
        flippedDealerCards: Set<Int>,
        tableSize: CGSize,
        gameState: BlackjackGameState,
        onComplete: @escaping () -> Void
    ) {
        guard !sequence.isEmpty else { onComplete(); return }

        gameState.isCollectingPhase = true
        gameState.collectingCardIds.removeAll()
        gameState.arrivalOrder.removeAll()

        func startCollect(at index: Int) {
            if index >= sequence.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    // Clear all state
                    gameState.animatingCards.removeAll()
                    gameState.animatingCardPositions.removeAll()
                    gameState.cardFlipRotations.removeAll()
                    gameState.collectingCardIds.removeAll()
                    gameState.arrivalOrder.removeAll()
                    gameState.isCollectingPhase = false
                    onComplete()
                }
                return
            }

            let card = sequence[index]
            let id = card.id

            if let pIndex = dealtPlayerCards.firstIndex(of: card) {
                let startPos = finalPlayerPositions[id]
                    ?? CGPoint(
                        x: CardPositioning.xForStaticCard(idx: pIndex, count: dealtPlayerCards.count, size: tableSize, isDealing: false),
                        y: CardPositioning.yForHand(isPlayer: true, size: tableSize)
                    )
                gameState.animatingCardPositions[id] = startPos
                gameState.cardFlipRotations[id] = 180
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { gameState.animatingCards[id] = card }
            } else if let dIndex = dealtDealerCards.firstIndex(of: card) {
                let startPos = finalDealerPositions[id]
                    ?? CGPoint(
                        x: CardPositioning.xForStaticCard(idx: dIndex, count: dealtDealerCards.count, size: tableSize, isDealing: false),
                        y: CardPositioning.yForHand(isPlayer: false, size: tableSize)
                    )
                gameState.animatingCardPositions[id] = startPos
                let isFaceUp = flippedDealerCards.contains(dIndex)
                gameState.cardFlipRotations[id] = isFaceUp ? 180 : 0
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { gameState.animatingCards[id] = card }
            }

            gameState.collectingCardIds.insert(id)
            gameState.arrivalOrder[id] = index

            withAnimation(CardMetrics.collectTravelAnim) {
                gameState.animatingCardPositions[id] = shoePosition
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) { 
                startCollect(at: index + 1) 
            }
        }

        startCollect(at: 0)
    }
    
    // MARK: - Cleanup
    static func cleanupAnimatedCard(
        _ id: UUID,
        gameState: BlackjackGameState
    ) {
        gameState.animatingCards.removeValue(forKey: id)
        gameState.animatingCardPositions.removeValue(forKey: id)
        gameState.animatingCardScales.removeValue(forKey: id)
        gameState.animatingCardOpacities.removeValue(forKey: id)
        gameState.cardFlipRotations.removeValue(forKey: id)
        gameState.cardFlipScales.removeValue(forKey: id)
    }
}
