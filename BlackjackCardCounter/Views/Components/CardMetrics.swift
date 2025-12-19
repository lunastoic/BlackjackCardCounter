import SwiftUI

// MARK: - Card Metrics
// Shared constants for consistent card positioning and animations across Regular and Training modes

struct CardMetrics {
    // Card dimensions
    static let cardSize = CGSize(width: 60, height: 90)
    
    // Spacing and positioning
    static let cardSpacing: CGFloat = 70
    static let dealerYOffset: CGFloat = -43
    static let playerYOffset: CGFloat = -7
    static let splitYOffset: CGFloat = 12   // ↓ lower split cards by 12pt
    
    // Layout spacing
    static let interHandGap: CGFloat = 32
    static let sideMargins: CGFloat = 32
    
    // Animation durations and easings
    static let travelAnim = Animation.easeInOut(duration: 0.50)
    static let flipAnim = Animation.easeInOut(duration: 0.26)
    static let collectTravelAnim = Animation.easeInOut(duration: 1.00)
    
    // Device-specific adjustments
    static func playerYMultiplier(isIPad: Bool) -> CGFloat {
        return isIPad ? 0.40 : 0.55
    }
    
    static func dealerYMultiplier(isIPad: Bool) -> CGFloat {
        return isIPad ? 0.26 : 0.38
    }
    
    static func dealerYOffset(isIPad: Bool) -> CGFloat {
        return isIPad ? 21 : 0
    }
    
    static func extraSpacerHeight(isIPad: Bool) -> CGFloat {
        return isIPad ? 250 : 0
    }
}
