import SwiftUI
import UIKit

struct SplitCardOverlay: UIViewRepresentable {
    let splitHands: [[Card]]
    let cardSize: CGSize
    let tableSize: CGSize
    let finalSplitPositions: [[UUID: CGPoint]]
    let collectingCardIds: Set<UUID>
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove all existing card views
        uiView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new card views
        for (handIdx, hand) in splitHands.enumerated() {
            for (cIdx, card) in hand.enumerated() {
                if !collectingCardIds.contains(card.id) {
                    let pos = finalSplitPositions[handIdx][card.id] ?? 
                        SplitCardLayout.shared.getSplitCardPosition(
                            handIndex: handIdx,
                            cardIndex: cIdx,
                            totalCards: hand.count,
                            tableSize: tableSize,
                            cardSize: cardSize
                        )
                    
                    let zIndex = SplitCardLayout.shared.getSplitCardZIndex(handIndex: handIdx, cardIndex: cIdx)
                    
                    let cardView = UIImageView()
                    cardView.image = UIImage(named: card.imageName)
                    cardView.contentMode = .scaleAspectFit
                    cardView.frame = CGRect(
                        x: pos.x - cardSize.width/2,
                        y: pos.y - cardSize.height/2,
                        width: cardSize.width,
                        height: cardSize.height
                    )
                    cardView.layer.cornerRadius = 8
                    cardView.layer.masksToBounds = true
                    cardView.layer.shadowRadius = 3
                    cardView.layer.shadowOpacity = 0.3
                    cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
                    cardView.layer.zPosition = zIndex
                    
                    uiView.addSubview(cardView)
                }
            }
        }
    }
}
