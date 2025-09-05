import SwiftUI

// MARK: - Betting Interface
struct BlackjackBettingView: View {
    @ObservedObject var gameState: BlackjackGameState
    let bettingManager: BlackjackBettingManager
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Betting Area")
                .font(.headline)
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
                    // For split hands, show the total winning amount; otherwise show actual winnings
                    let displayAmount = gameState.isSplit ? gameState.winningAmount : gameState.actualWinnings
                    Text("Win $\(displayAmount)")
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
                    // Push - show the amount you get back
                    let pushAmount = gameState.isSplit ? gameState.playerBet / gameState.splitHands.count : gameState.playerBet
                    Text("Push $\(pushAmount)")
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
    
    private let playerChips = [1, 5, /* 10, */ 25, 50, 100]
    
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
    @State private var showPlaceBetMessage = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                if gameState.lastBet != nil && gameState.resultMessage != nil {
                HStack(spacing: 16) {
                    Button(action: {
                        bettingManager.redoBet(gameState: gameState)
                    }) {
                        Text("Redo Bet")
                            .font(.fixedSystem(size: 20, weight: .bold))
                            .frame(width: 120)
                            .padding(.horizontal)
                            .padding(.vertical)
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
                            .frame(width: 120)
                            .padding(.horizontal)
                            .padding(.vertical)
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
                    
                    // Check if user has placed a bet
                    if gameState.playerBet == 0 {
                        // Show notification message
                        showPlaceBetMessage = true
                        
                        // Hide message after 2.1 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showPlaceBetMessage = false
                            }
                        }
                        return
                    }
                    
                    gameState.isDealing = true // Lock UI immediately to prevent double deal
                    
                    // Check if we're in RegularModeView (deck position is set)
                    let useRegularAnimation = gameState.deckPosition != .zero
                    gameEngine.dealInitialCards(
                        gameState: gameState, 
                        useRegularModeAnimation: useRegularAnimation,
                        animationCallback: animationCallback
                    )
                }) {
                    ZStack {
                        // Custom asset background
                        Image("DealButton1")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 48)
                            .colorMultiply(gameState.playerBet > 0 ? Color.white : Color.gray)
                        
                        // Text overlay
                        Text("Deal Cards")
                            .font(.fixedSystem(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
            }
            }
            
            // Notification message overlay - positioned 180 points up
            if showPlaceBetMessage {
                Text("Place a chip first")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .offset(y: -180)
                    .transition(.opacity.combined(with: .scale))
            }
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