import SwiftUI

struct HowToPlayView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]),
                         startPoint: .top,
                         endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Mission Statement
                    InfoSection(title: "Our Mission") {
                        Text("Blackjack Counter is designed to help you master the art of card counting in a fun, engaging, and legal way. Our goal is to make learning card counting accessible to everyone while maintaining the highest standards of responsible gaming.")
                            .foregroundColor(.white)
                    }
                    
                    // Legal Information
                    InfoSection(title: "Legal Information") {
                        Text("Card counting is 100% legal! It's a skill-based strategy that uses your memory and mathematical abilities. While casinos may ask you to leave if they suspect you're counting cards, the practice itself is completely legal.")
                            .foregroundColor(.white)
                    }
                    
                    // How to Count Cards
                    InfoSection(title: "How to Count Cards") {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("We use the Hi-Lo counting system:")
                                .foregroundColor(.white)
                            
                            CountRule(value: "+1", cards: "2, 3, 4, 5, 6")
                            CountRule(value: "0", cards: "7, 8, 9")
                            CountRule(value: "-1", cards: "10, J, Q, K, A")
                            
                            Text("Keep a running count by adding or subtracting these values as cards are dealt.")
                                .foregroundColor(.white)
                                .padding(.top, 5)
                        }
                    }
                    
                    // Game Modes
                    InfoSection(title: "Game Modes") {
                        VStack(alignment: .leading, spacing: 15) {
                            GameModeInfo(title: "Training Mode",
                                       description: "Learn with visual aids and step-by-step tutorials")
                            
                            GameModeInfo(title: "Regular Mode",
                                       description: "Practice your counting skills in a realistic setting")
                            
                            GameModeInfo(title: "Quiz Mode",
                                       description: "Test your knowledge with various challenges")
                        }
                    }
                    
                    // Tips
                    InfoSection(title: "Tips for Success") {
                        VStack(alignment: .leading, spacing: 10) {
                            TipItem(text: "Start with Training Mode to learn the basics")
                            TipItem(text: "Practice regularly to improve your speed")
                            TipItem(text: "Focus on accuracy before speed")
                            TipItem(text: "Use the visual aids until you're comfortable")
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("How to Play")
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(hex: "0f3460"))
                )
        }
    }
}

struct CountRule: View {
    let value: String
    let cards: String
    
    var body: some View {
        HStack {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "e94560"))
                .frame(width: 40)
            
            Text(cards)
                .foregroundColor(.white)
        }
    }
}

struct GameModeInfo: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

struct TipItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "e94560"))
            Text(text)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    TrainingModeView(map: Map(id: 1, name: "Mercury", imageName: "MercuryImage", isLocked: false, requiredLevel: 1))
} 
