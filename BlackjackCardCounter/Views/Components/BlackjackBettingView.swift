import SwiftUI

// MARK: - Betting Interface
struct BlackjackBettingView: View {
    @ObservedObject var gameState: BlackjackGameState
    let bettingManager: BlackjackBettingManager
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Betting Area")
                .font(.subheadline)
                .foregroundColor(.white)
            
            ZStack {
                // Bet chips centered
                HStack(spacing: 4) {
                    ForEach(Array(Set(gameState.betChips)).sorted(), id: \.self) { value in
                        let count = gameState.betChips.filter { $0 == value }.count
                        ZStack {
                            ForEach(0..<count, id: \.self) { index in
                                ChipView(chip: Chip(value: value))
                                    .offset(x: CGFloat(index) * 2, y: CGFloat(index) * 2)
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
                                .font(.headline)
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
                .font(.title2)
                .foregroundColor(.yellow)
            
            // Win/Lose/Push message
            if let result = gameState.resultMessage {
                if gameState.lastPayout > 0 {
                    Text("Win $\(gameState.lastPayout)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                } else if gameState.lastPayout < 0 {
                    Text("Lose -$\(-gameState.lastPayout)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Push")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.top, gameState.resultMessage == nil ? 24 : -16)
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
    
    var body: some View {
        if gameState.lastBet != nil && gameState.resultMessage != nil {
            HStack(spacing: 16) {
                Button(action: {
                    bettingManager.redoBet(gameState: gameState)
                }) {
                    Text("Redo Bet")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "ff9800").opacity(bettingManager.canRedoBet(gameState: gameState) ? 0.85 : 0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!bettingManager.canRedoBet(gameState: gameState))
                
                Button(action: {
                    gameEngine.dealInitialCards(gameState: gameState)
                }) {
                    Text("Deal Cards")
                        .font(.title3)
                        .fontWeight(.bold)
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
        } else {
            Button(action: {
                if gameState.showNextHand {
                    gameEngine.dealNewHand(gameState: gameState)
                } else {
                    gameEngine.dealInitialCards(gameState: gameState)
                }
            }) {
                Text(gameState.showNextHand ? "Next Hand" : "Deal Cards")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(gameState.playerBet > 0 || gameState.showNextHand ? Color(hex: "38b802") : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .disabled(gameState.playerBet == 0 && !gameState.showNextHand)
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