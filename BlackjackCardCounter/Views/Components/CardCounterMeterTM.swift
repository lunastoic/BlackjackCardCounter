import SwiftUI

// MARK: - Card Counter Meter for Training Mode
struct CardCounterMeterTM: View {
    @ObservedObject var gameState: BlackjackGameState
    
    // Calculate training mode running count (only count revealed cards)
    private var trainingModeRunningCount: Int {
        var count = 0
        
        // Count all player cards (always revealed)
        for card in gameState.dealtPlayerCards {
            count += card.countValue
        }
        
        // Count only revealed dealer cards
        for (index, card) in gameState.dealtDealerCards.enumerated() {
            if gameState.countingRevealedDealerCards.contains(index) {
                count += card.countValue
            }
        }
        
        return count
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Card Counter Meter")
                .font(.headline)
                .foregroundColor(.white)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.yellow, Color.green]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 24)
                
                GeometryReader { geo in
                    let width = geo.size.width
                    let minCount = -10.0
                    let maxCount = 10.0
                    let clamped = Double(trainingModeRunningCount).clamped(to: minCount...maxCount)
                    let normalized = (clamped - minCount) / (maxCount - minCount) // 0 to 1
                    let xOffset = CGFloat(normalized) * (width - 48) // 48 = width of number label
                    
                    Text("\(trainingModeRunningCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 48, height: 32)
                        .background(Color.white.opacity(0.85))
                        .cornerRadius(12)
                        .offset(x: xOffset)
                        .shadow(radius: 4)
                }
                .frame(height: 32)
            }
            .frame(height: 32)
            .frame(maxWidth: 240) // Constrain width to fit between deck and shoe (reduced from 280)
        }
        .frame(maxWidth: 240) // Constrain overall width (reduced from 280)
    }
}
