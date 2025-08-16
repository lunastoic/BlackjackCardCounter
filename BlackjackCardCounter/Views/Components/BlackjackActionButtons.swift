import SwiftUI

// MARK: - Action Buttons
struct BlackjackActionButtons: View {
    @ObservedObject var gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    let showStrategyHints: Bool
    let getPerfectStrategyAction: () -> String?
    
    var body: some View {
        let _ = print("🃏 BlackjackActionButtons rendered: playerHand.count=\(gameState.playerHand.count), canSplit=\(gameState.canSplit)")
        
        HStack(spacing: 18) {
            PremiumActionButton(
                title: "Double Down",
                systemImage: "arrow.up.right.square.fill",
                color1: "ff8800",
                color2: "ffb300",
                isEnabled: {
                    let canDoubleDown = gameState.canDoubleDown
                    print("🎲 Double Down button check: canDoubleDown=\(canDoubleDown), playerHand.count=\(gameState.playerHand.count)")
                    return canDoubleDown
                }(),
                action: {
                    print("🎲 Double Down tapped. canDoubleDown=\(gameState.canDoubleDown)")
                    gameEngine.doubleDownAction(gameState: gameState)
                },
                highlighted: showStrategyHints && getPerfectStrategyAction() == "Double Down"
            )
            
            PremiumActionButton(
                title: "Hit",
                systemImage: "hand.point.up.left.fill",
                color1: "02a10f",
                color2: "02a10f",
                action: { gameEngine.hitAction(gameState: gameState) },
                highlighted: showStrategyHints && getPerfectStrategyAction() == "Hit"
            )
            
            PremiumActionButton(
                title: "Stand",
                systemImage: "hand.raised.fill",
                color1: "b80802",
                color2: "b80802",
                action: { gameEngine.standAction(gameState: gameState) },
                highlighted: showStrategyHints && getPerfectStrategyAction() == "Stand"
            )
            
            PremiumActionButton(
                title: "Split",
                systemImage: "square.split.2x1.fill",
                color1: "2193b0",
                color2: "6dd5ed",
                isEnabled: {
                    let canSplit = gameState.canSplit
                    let handRanks = gameState.playerHand.map { $0.rank.rawValue }
                    print("🃏 Split button check: canSplit=\(canSplit), playerHand=\(handRanks)")
                    return canSplit
                }(),
                action: {
                    print("🃏 Split tapped. canSplit=\(gameState.canSplit)")
                    gameEngine.splitAction(gameState: gameState)
                },
                highlighted: showStrategyHints && getPerfectStrategyAction() == "Split"
            )
        }
        .frame(maxWidth: 440)
        .padding(.top, 12)
    }
}

// MARK: - PremiumActionButton
struct PremiumActionButton: View {
    let title: String
    let systemImage: String
    let color1: String
    let color2: String
    var isEnabled: Bool = true
    let action: () -> Void
    var highlighted: Bool = false
    
    var body: some View {
        Button(action: { if isEnabled { action() } }) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isEnabled ? .white : .gray)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: color1), Color(hex: color2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(14)
            .shadow(color: highlighted ? .yellow : .clear, radius: 16)
            .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
        }
        // Don’t use .disabled() (it auto-dims to ~50% and stacks with other opacities)
        .allowsHitTesting(isEnabled)                 // blocks taps when “disabled”
        .opacity(isEnabled ? 1.0 : 0.5)              // exactly 50% opacity when not enabled
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

