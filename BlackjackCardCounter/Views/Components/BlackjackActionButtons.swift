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
                    let canDoubleDown = gameState.canDoubleDown && !gameState.isProcessingAction
                    print("🎲 Double Down button check: canDoubleDown=\(gameState.canDoubleDown), processing=\(gameState.isProcessingAction), final=\(canDoubleDown)")
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
                isEnabled: !gameState.isProcessingAction && Date().timeIntervalSince(gameState.lastActionTime) >= 0.6,
                action: { 
                    print("🎯 Hit button tapped")
                    gameEngine.hitAction(gameState: gameState) 
                },
                highlighted: showStrategyHints && getPerfectStrategyAction() == "Hit"
            )
            
            PremiumActionButton(
                title: "Stand",
                systemImage: "hand.raised.fill",
                color1: "b80802",
                color2: "b80802",
                isEnabled: !gameState.isProcessingAction,
                action: { gameEngine.standAction(gameState: gameState) },
                highlighted: showStrategyHints && getPerfectStrategyAction() == "Stand"
            )
            
            PremiumActionButton(
                title: "Split",
                systemImage: "square.split.2x1.fill",
                color1: "2193b0",
                color2: "6dd5ed",
                isEnabled: {
                    let canSplit = gameState.canSplit && !gameState.isProcessingAction
                    let handRanks = gameState.playerHand.map { $0.rank.rawValue }
                    print("🃏 Split button check: canSplit=\(gameState.canSplit), processing=\(gameState.isProcessingAction), final=\(canSplit)")
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
        .disableDynamicType()
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
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: { 
            if isEnabled { 
                // Add press animation
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                
                // Execute the action
                action()
                
                // Reset press state after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
            } 
        }) {
            // Custom asset button
            Group {
                if title == "Double Down" {
                    Image("DDAssetButton")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                } else if title == "Hit" {
                    Image("HitAssetButton")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                } else if title == "Stand" {
                    Image("StandAssetButton")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                } else if title == "Split" {
                    Image("SplitAssetButton")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0) // Press animation
            .shadow(color: highlighted ? .yellow : .clear, radius: 16)
            .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
        }
        // Don’t use .disabled() (it auto-dims to ~50% and stacks with other opacities)
        .allowsHitTesting(isEnabled)                 // blocks taps when “disabled”
        .opacity(isEnabled ? 1.0 : 0.5)              // exactly 50% opacity when not enabled
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

