import SwiftUI

struct CardCounterView: View {
    @ObservedObject var gameState: BlackjackGameState
    var xOffset: CGFloat = -24
    var yOffset: CGFloat = 400
    @AppStorage("regularDecks") private var regularDecks: Int = 6
    @AppStorage("trainingDecks") private var trainingDecks: Int = 6
    
    private var totalCardsInDeck: Int {
        // Determine which deck setting to use based on the current view
        // This will be set by the parent view
        let decksCount = gameState.isTrainingMode ? trainingDecks : regularDecks
        return decksCount * 52
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Cards dealt: \(gameState.cardsDealt)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
            
            Text("Cards remaining: \(totalCardsInDeck - gameState.cardsDealt)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .offset(x: xOffset, y: yOffset)
    }
}

#Preview {
    ZStack {
        Color.black
        CardCounterView(gameState: BlackjackGameState())
    }
}
