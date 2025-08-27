import SwiftUI

// MARK: - Split Card Layout Manager
class SplitCardLayout: ObservableObject {
    static let shared = SplitCardLayout()
    private init() {}

    // Each subsequent card shifts right by 75% of its width => 25% overlap
    private func step(_ cardSize: CGSize) -> CGFloat { cardSize.width * 0.60 }

    // Center position for each split card with overlapping and max width constraint
    func getSplitCardPosition(handIndex: Int, cardIndex: Int, totalCards: Int, tableSize: CGSize, cardSize: CGSize) -> CGPoint {
        let midX = tableSize.width * 0.5
        let gap: CGFloat = 180
        let centerX = (handIndex == 0) ? (midX - gap/2) : (midX + gap/2)
        let baseY  = tableSize.height * 0.55 - 7 + 12

        // Shift Hand 1 (right hand) to the left by 20 points
        let adjustedCenterX = (handIndex == 1) ? centerX - 20 : centerX

        if cardIndex == 0 {
            // First card: center it under the hand label
            return CGPoint(x: adjustedCenterX, y: baseY)
        } else {
            // Subsequent cards: stack with 40% overlap
            let firstCardX = adjustedCenterX
            let baseOverlap = step(cardSize) // 40% overlap (0.60 * card width)
            
            // Calculate maximum width with base overlap
            let maxWidthWithOverlap = cardSize.width + CGFloat(totalCards - 1) * baseOverlap
            let maxAllowedWidth: CGFloat = 250 // Increased maximum width for more cards
            
            // If we exceed max width, reduce overlap proportionally
            let overlap: CGFloat
            if maxWidthWithOverlap <= maxAllowedWidth {
                overlap = baseOverlap // Use normal 40% overlap
            } else {
                // Reduce overlap to fit within max width
                let excessWidth = maxWidthWithOverlap - maxAllowedWidth
                let reductionPerCard = excessWidth / CGFloat(totalCards - 1)
                overlap = baseOverlap - reductionPerCard
            }
            
            let x = firstCardX + CGFloat(cardIndex) * overlap
            return CGPoint(x: x, y: baseY)
        }
    }

    // Later cards on top
    func getSplitCardZIndex(handIndex: Int, cardIndex: Int) -> Double {
        Double(cardIndex)
    }

    // Frame that encloses the overlapped fan with max width constraint
    func getSplitHandFrame(handIndex: Int, cardCount: Int, cardSize: CGSize, tableSize: CGSize) -> CGRect {
        let midX = tableSize.width * 0.5
        let gap: CGFloat = 180
        let centerX = (handIndex == 0) ? (midX - gap/2) : (midX + gap/2)
        let baseY  = tableSize.height * 0.55 - 7 + 12

        // Shift Hand 1 (right hand) to the left by 20 points
        let adjustedCenterX = (handIndex == 1) ? centerX - 20 : centerX

        if cardCount == 0 {
            return CGRect.zero
        } else {
            // Calculate width with overlapping and constraint
            let baseOverlap = step(cardSize) // 40% overlap
            let maxWidthWithOverlap = cardSize.width + CGFloat(cardCount - 1) * baseOverlap
            let maxAllowedWidth: CGFloat = 250 // Increased maximum width for more cards
            
            let width: CGFloat
            if maxWidthWithOverlap <= maxAllowedWidth {
                width = maxWidthWithOverlap // Use normal width with overlap
            } else {
                width = maxAllowedWidth // Constrain to max width
            }
            
            let x = adjustedCenterX - width / 2 // Center the entire hand
            return CGRect(x: x, y: baseY - cardSize.height/2, width: width, height: cardSize.height)
        }
    }
}

// MARK: - Split Card View Component
struct SplitCardView: View {
    let card: Card
    let handIndex: Int
    let cardIndex: Int
    let totalCards: Int
    let cardSize: CGSize
    let tableSize: CGSize

    var body: some View {
        let position = SplitCardLayout.shared.getSplitCardPosition(
            handIndex: handIndex,
            cardIndex: cardIndex,
            totalCards: totalCards,
            tableSize: tableSize,
            cardSize: cardSize
        )
        let zIndex = SplitCardLayout.shared.getSplitCardZIndex(handIndex: handIndex, cardIndex: cardIndex)

        FlipCardView(card: card, isFlipped: true, width: cardSize.width, glowWidth: 0)
            .position(position)   // position uses center
            .zIndex(zIndex)
    }
}
