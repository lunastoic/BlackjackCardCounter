import SwiftUI

// MARK: - Action Buttons
struct BlackjackActionButtons: View {
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    let showStrategyHints: Bool
    let getPerfectStrategyAction: () -> String?
    
    var body: some View {
        HStack(spacing: 18) {
            PremiumActionButton(
                title: "Double Down",
                systemImage: "arrow.up.right.square.fill",
                color1: "ff8800",
                color2: "ffb300",
                isEnabled: gameState.canDoubleDown,
                action: { gameEngine.doubleDownAction(gameState: gameState) },
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
                isEnabled: gameState.canSplit,
                action: { gameEngine.splitAction(gameState: gameState) },
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
                .opacity(isEnabled ? 1.0 : 0.4)
            )
            .cornerRadius(14)
            .shadow(color: highlighted ? .yellow : .clear, radius: 16)
            .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
        }
        .disabled(!isEnabled)
    }
} 