import SwiftUI

// MARK: - Split Card Layout Manager
class SplitCardLayout: ObservableObject {
    static let shared = SplitCardLayout()
    private init() {}

    // Each subsequent card shifts right by 75% of its width => 25% overlap
    private func step(_ cardSize: CGSize) -> CGFloat { cardSize.width * 0.60 }

    // Center position for each split card with overlapping
    func getSplitCardPosition(handIndex: Int, cardIndex: Int, totalCards: Int, tableSize: CGSize, cardSize: CGSize) -> CGPoint {
        let midX = tableSize.width * 0.5
        let gap: CGFloat = 180
        let centerX = (handIndex == 0) ? (midX - gap/2) : (midX + gap/2)
        let baseY  = tableSize.height * 0.55 - 7 + 12

        if cardIndex == 0 {
            // First card: center it under the hand label
            return CGPoint(x: centerX, y: baseY)
        } else {
            // Subsequent cards: stack with 40% overlap
            let firstCardX = centerX
            let overlap = step(cardSize) // 40% overlap (0.60 * card width)
            let x = firstCardX + CGFloat(cardIndex) * overlap
            return CGPoint(x: x, y: baseY)
        }
    }

    // Later cards on top
    func getSplitCardZIndex(handIndex: Int, cardIndex: Int) -> Double {
        Double(cardIndex)
    }

    // Frame that encloses the overlapped fan
    func getSplitHandFrame(handIndex: Int, cardCount: Int, cardSize: CGSize, tableSize: CGSize) -> CGRect {
        let midX = tableSize.width * 0.5
        let gap: CGFloat = 180
        let centerX = (handIndex == 0) ? (midX - gap/2) : (midX + gap/2)
        let baseY  = tableSize.height * 0.55 - 7 + 12

        if cardCount == 0 {
            return CGRect.zero
        } else {
            // Calculate width based on first card centered + subsequent cards with 40% overlap
            let overlap = step(cardSize) // 40% overlap
            let width = cardSize.width + CGFloat(cardCount - 1) * overlap
            let x = centerX // Start from center (first card position)
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
