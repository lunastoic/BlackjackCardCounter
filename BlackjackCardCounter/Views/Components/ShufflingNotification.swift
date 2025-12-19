import SwiftUI

struct ShufflingNotification: View {
    @ObservedObject var gameState: BlackjackGameState
    
    var body: some View {
        if gameState.showShufflingNotification {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "shuffle")
                        .foregroundColor(.yellow)
                        .font(.title2)
                    
                    Text("Shuffling deck after this round")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 2) {
                    Text("\(gameState.deck.count) cards remaining")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .opacity(0.8)
                    
                    // Calculate shuffle point based on ACTUAL deck size
                    let totalDeckSize = gameState.deck.count + gameState.cardsDealt
                    let shufflePoint = totalDeckSize <= 104 ? 14 : 52
                    Text("Shuffle at \(shufflePoint) cards")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .opacity(0.7)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow, lineWidth: 2)
                    )
            )
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: gameState.showShufflingNotification)
        }
    }
}

#Preview {
    let gameState = BlackjackGameState()
    gameState.showShufflingNotification = true
    gameState.deck = Array(repeating: Card(suit: .hearts, rank: .ace), count: 5)
    
    return ShufflingNotification(gameState: gameState)
        .background(Color.green)
}
