import SwiftUI

// MARK: - Betting Interface
struct BlackjackBettingView: View {
    @ObservedObject var gameState: BlackjackGameState
    let bettingManager: BlackjackBettingManager
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Betting Area")
                .font(.fixedSystem(size: 15, weight: .regular))
                .foregroundColor(.white)
            
            ZStack {
                // Bet chips centered
                HStack(spacing: 4) {
                    ForEach(Array(Set(gameState.betChips)).sorted(), id: \.self) { value in
                        let count = gameState.betChips.filter { $0 == value }.count
                        ZStack {
                            ForEach(0..<count, id: \.self) { index in
                                let angle = Double(index) * 1.2
                                let radius: CGFloat = 4.0 // Smaller radius for tighter spiral
                                let xOffset = radius * cos(angle)
                                let yOffset = radius * sin(angle)
                                
                                ChipView(chip: Chip(value: value))
                                    .offset(x: xOffset, y: yOffset)
                                    .zIndex(Double(index))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .onAppear {
                    print("🎯 BlackjackBettingView appeared with betChips: \(gameState.betChips)")
                }
                .onChange(of: gameState.betChips) { newBetChips in
                    print("🎯 betChips changed to: \(newBetChips)")
                }
                
                // Return Bet Button positioned on the right
                if gameState.playerBet > 0 && !gameState.showNextHand {
                    HStack {
                        Spacer()
                        Button(action: {
                            bettingManager.returnBet(gameState: gameState)
                        }) {
                            Text("Return Bet")
                                .font(.fixedSystem(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "b80802"))
                                .cornerRadius(8)
                        }
                        .offset(y: -35)
                    }
                }
            }
            
            Text("Bet: $\(gameState.playerBet)")
                .font(.fixedSystem(size: 18, weight: .semibold))
                .foregroundColor(.yellow)
            
            // Win/Lose/Push message
            if let result = gameState.resultMessage {
                if gameState.lastPayout > 0 {
                    Text("Win $\(gameState.lastPayout)")
                        .font(.fixedSystem(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "00FF41"))
                        .multilineTextAlignment(.center)
                        .offset(y: -8)
                } else if gameState.lastPayout < 0 {
                    Text("Lose -$\(-gameState.lastPayout)")
                        .font(.fixedSystem(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "DC143C"))
                        .multilineTextAlignment(.center)
                        .offset(y: -8)
                } else {
                    Text("Push")
                        .font(.fixedSystem(size: 18, weight: .bold))
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                        .offset(y: -8)
                }
            }
        }
        .padding(.top, gameState.resultMessage == nil ? 24 : -16)
        .disableDynamicType()
    }
}

// MARK: - Chip Selection View
struct ChipSelectionView: View {
    @ObservedObject var gameState: BlackjackGameState
    let bettingManager: BlackjackBettingManager
    
    private let playerChips = [1, 5, 10, 25, 50, 100]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(playerChips, id: \.self) { value in
                Button(action: {
                    print("🎰 Chip \(value) tapped")
                    bettingManager.placeBet(gameState: gameState, chipValue: value)
                }) {
                    ChipView(chip: Chip(value: value))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        )
                }
                .disabled(!bettingManager.canPlaceBet(gameState: gameState, chipValue: value))
            }
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Deal/Next Hand Buttons
struct DealNextHandButtons: View {
    @ObservedObject var gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    let bettingManager: BlackjackBettingManager
    var animationCallback: ((Card, Int, @escaping () -> Void) -> Void)? = nil
    
    var body: some View {
        if gameState.lastBet != nil && gameState.resultMessage != nil {
            HStack(spacing: 16) {
                Button(action: {
                    bettingManager.redoBet(gameState: gameState)
                }) {
                    Text("Redo Bet")
                        .font(.fixedSystem(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "ff9800").opacity(bettingManager.canRedoBet(gameState: gameState) ? 0.85 : 0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!bettingManager.canRedoBet(gameState: gameState))
                
                Button(action: {
                    if gameState.isDealing { return }
                    gameState.isDealing = true // Lock UI immediately to prevent double deal
                    
                    // Check if we're in RegularModeView (deck position is set)
                    let useRegularAnimation = gameState.deckPosition != .zero
                    gameEngine.dealInitialCards(
                        gameState: gameState, 
                        useRegularModeAnimation: useRegularAnimation,
                        animationCallback: animationCallback
                    )
                }) {
                    Text("Deal Cards")
                        .font(.fixedSystem(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(gameState.playerBet > 0 ? Color(hex: "38b802") : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .disabled(gameState.playerBet == 0)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal)
        } else if !gameState.showNextHand && gameState.playerHand.isEmpty && gameState.dealerHand.isEmpty {
            Button(action: {
                if gameState.isDealing { return }
                gameState.isDealing = true // Lock UI immediately to prevent double deal
                
                // Check if we're in RegularModeView (deck position is set)
                let useRegularAnimation = gameState.deckPosition != .zero
                gameEngine.dealInitialCards(
                    gameState: gameState, 
                    useRegularModeAnimation: useRegularAnimation,
                    animationCallback: animationCallback
                )
            }) {
                Text("Deal Cards")
                    .font(.fixedSystem(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(gameState.playerBet > 0 ? Color(hex: "38b802") : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .disabled(gameState.playerBet == 0)
            .frame(maxWidth: 440)
            .padding(.horizontal)
        }
    }
}

// MARK: - ChipView
struct ChipView: View {
    let chip: Chip
    
    var body: some View {
        Image("Chip_\(chip.value)")
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(width: 40, height: 40)
            .shadow(radius: 2)
    }
} 