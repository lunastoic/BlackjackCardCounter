import SwiftUI

// MARK: - Card Positioning
// Pure helper functions for consistent card positioning across Regular and Training modes

struct CardPositioning {
    
    // MARK: - Y Position Helpers
    static func yForHand(isPlayer: Bool, size: CGSize) -> CGFloat {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let playerY: CGFloat = size.height * CardMetrics.playerYMultiplier(isIPad: isIPad)
        let dealerY: CGFloat = (size.height * CardMetrics.dealerYMultiplier(isIPad: isIPad)) + CardMetrics.dealerYOffset(isIPad: isIPad)
        return isPlayer ? (playerY + CardMetrics.playerYOffset) : (dealerY + CardMetrics.dealerYOffset)
    }
    
    // MARK: - X Position Helpers
    private static func spacing(for count: Int, isPlayer: Bool) -> CGFloat {
        let width = CardMetrics.cardSize.width
        
        if isPlayer {
            switch count {
            case ...3: return CardMetrics.cardSpacing                     // Full cards through 3
            case 4...5: return width * 0.80                              // 80% visible for 4-5 cards
            case 6: return width * 0.70                                  // 70% visible for 6 cards
            default: return width * 0.60                                 // 60% visible for 7+ cards (up to 8 tested)
            }
        } else {
            if count <= 4 { return CardMetrics.cardSpacing }              // Dealer full cards through 4
            return width * 0.80                                          // Dealer 80% visible starting at 5 cards
        }
    }
    
    static func xForCard(index: Int, count: Int, size: CGSize, isPlayer: Bool) -> CGFloat {
        let midX = size.width * 0.5
        let cardSpacing = spacing(for: count, isPlayer: isPlayer)
        let totalWidth = CGFloat(max(count - 1, 0)) * cardSpacing
        let startX = midX - totalWidth / 2
        return startX + CGFloat(index) * cardSpacing
    }
    
    static func xForStaticCard(idx: Int, count: Int, size: CGSize, isDealing: Bool, isPlayer: Bool) -> CGFloat {
        if isDealing && count <= 2 {
            let midX = size.width * 0.5
            let startX = midX - (CardMetrics.cardSpacing / 2)
            return startX + CGFloat(idx) * CardMetrics.cardSpacing
        } else {
            return xForCard(index: idx, count: count, size: size, isPlayer: isPlayer)
        }
    }
    
    // MARK: - Split Card Positioning (delegates to SplitCardLayout)
    static func splitStaticPosition(handIndex: Int, cardIndex: Int, totalCards: Int, tableSize: CGSize) -> CGPoint {
        return SplitCardLayout.shared.getSplitCardPosition(
            handIndex: handIndex,
            cardIndex: cardIndex,
            totalCards: totalCards,
            tableSize: tableSize,
            cardSize: CardMetrics.cardSize
        )
    }
    
    // MARK: - Position Management
    static func recalculateAllCardPositions(
        isPlayerCard: Bool,
        newCount: Int,
        tableSize: CGSize,
        dealtPlayerCards: [Card],
        dealtDealerCards: [Card],
        finalPlayerPositions: inout [UUID: CGPoint],
        finalDealerPositions: inout [UUID: CGPoint]
    ) {
        if isPlayerCard {
            for (index, card) in dealtPlayerCards.enumerated() {
                let x = xForCard(index: index, count: newCount, size: tableSize, isPlayer: true)
                let y = yForHand(isPlayer: true, size: tableSize)
                finalPlayerPositions[card.id] = CGPoint(x: x, y: y)
            }
        } else {
            for (index, card) in dealtDealerCards.enumerated() {
                let x = xForCard(index: index, count: newCount, size: tableSize, isPlayer: false)
                let y = yForHand(isPlayer: false, size: tableSize)
                finalDealerPositions[card.id] = CGPoint(x: x, y: y)
            }
        }
    }
}
