import SwiftUI

struct GameModeSelectionView: View {
    let map: Map
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]),
                         startPoint: .top,
                         endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text(map.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    NavigationLink(destination: TrainingModeView(map: map)) {
                        GameModeButton(title: "Training Mode",
                                     description: "Learn with visual aids and tutorials",
                                     systemImage: "book.fill")
                    }
                    
                    NavigationLink(destination: RegularModeView(map: map)) {
                        GameModeButton(title: "Regular Mode",
                                     description: "Practice your counting skills",
                                     systemImage: "play.fill")
                    }
                    
                    NavigationLink(destination: QuizModeView(map: map)) {
                        GameModeButton(title: "Quiz Mode",
                                     description: "Test your knowledge",
                                     systemImage: "questionmark.circle.fill")
                    }
                }
                .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                    Text("Back")
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct GameModeButton: View {
    let title: String
    let description: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 50)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.fixedSystem(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.fixedSystem(size: 11, weight: .regular))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(hex: "4A4A4A"))
                .shadow(radius: 5)
        )
    }
}

struct QuizModeView: View {
    let map: Map
    @Environment(\.dismiss) private var dismiss
    @State private var currentCards: [Card] = []
    @State private var currentCount: Int = 0
    @State private var showAnswer: Bool = false
    @State private var isCorrect: Bool = false
    @State private var progressCircles: Int = 0
    @State private var showCards: Bool = false
    @State private var cardDisplayTime: Double = 0.8
    @State private var isShowingResult: Bool = false
    @State private var currentCardIndex: Int = 0
    @State private var answerOptions: [Int] = []
    @State private var correctAnswerIndex: Int = 0
    @State private var showClaimReward: Bool = false
    @State private var isQuizInSession: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]),
                         startPoint: .top,
                         endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Card Counting Quiz")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Count the cards quickly!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                // Progress circles
                VStack(spacing: 12) {
                    Text("Progress")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<9, id: \.self) { index in
                            Circle()
                                .fill(index < progressCircles ? Color(hex: "FFD700") : Color.gray.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    
                    Text("\(progressCircles)/9")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding()
                
                // Claim Reward Button
                Button(action: {
                    claimReward()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .font(.title2)
                        Text("Claim Reward")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "FFD700"), Color(hex: "FFA500")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color(hex: "FFD700").opacity(0.5), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(showClaimReward ? 1.0 : 0.1)
                .opacity(showClaimReward ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showClaimReward)
                
                Spacer()
                
                // Single card display area
                VStack(spacing: 16) {
                    if showCards && currentCardIndex < currentCards.count {
                        VStack(spacing: 12) {
                            Image(currentCards[currentCardIndex].imageName)
                                .resizable()
                                .aspectRatio(0.7, contentMode: .fit)
                                .frame(width: 120, height: 180)
                                .shadow(radius: 5)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            
                            Text("Card \(currentCardIndex + 1) of \(currentCards.count)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    } else {
                        // Empty space when no cards are shown
                        Color.clear
                            .frame(height: 180)
                    }
                }
                .padding()
                
                Spacer()
                
                // Answer buttons area
                VStack(spacing: 16) {
                    if showAnswer {
                        VStack(spacing: 12) {
                            Text("What was the count?")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { index in
                                    Button(action: {
                                        checkAnswer(selectedIndex: index)
                                    }) {
                                        Text("\(answerOptions[index])")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(getButtonColor(for: index))
                                            .cornerRadius(12)
                                            .shadow(radius: 3)
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // Result display
                    if isShowingResult {
                        VStack(spacing: 8) {
                            Text(isCorrect ? "Correct! +3 XP" : "Incorrect!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(isCorrect ? .green : .red)
                            
                            if !isCorrect {
                                Text("Correct count was: \(currentCount)")
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                            }
                            
                            Button("Next Question") {
                                nextQuestion()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding()
                
                // Start button
                if !isQuizInSession && !showCards && !showAnswer && !isShowingResult && !showClaimReward {
                    Button("Start Quiz") {
                        startQuiz()
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.title3)
                    .fontWeight(.bold)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                    Text("Back")
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func getButtonColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "FF6B6B"), // Red
            Color(hex: "4ECDC4"), // Teal
            Color(hex: "45B7D1"), // Blue
            Color(hex: "96CEB4")  // Green
        ]
        return colors[index % colors.count]
    }
    
    private func startQuiz() {
        isQuizInSession = true
        generateNewQuestion()
    }
    
    private func generateNewQuestion() {
        // Generate 3-7 random cards
        let numberOfCards = Int.random(in: 3...7)
        var cards: [Card] = []
        var count = 0
        
        for _ in 0..<numberOfCards {
            let randomSuit = CardSuit.allCases.randomElement()!
            let randomRank = CardRank.allCases.randomElement()!
            let card = Card(suit: randomSuit, rank: randomRank, isFaceUp: true)
            cards.append(card)
            count += card.countValue
        }
        
        currentCards = cards
        currentCount = count
        currentCardIndex = 0
        showAnswer = false
        isCorrect = false
        isShowingResult = false
        
        // Generate answer options
        generateAnswerOptions()
        
        // Start showing cards one by one
        showNextCard()
    }
    
    private func generateAnswerOptions() {
        // Generate 3 wrong answers and 1 correct answer
        var options: Set<Int> = [currentCount]
        
        // Add wrong answers
        while options.count < 4 {
            let wrongAnswer = currentCount + Int.random(in: -5...5)
            if wrongAnswer != currentCount {
                options.insert(wrongAnswer)
            }
        }
        
        answerOptions = Array(options).shuffled()
        correctAnswerIndex = answerOptions.firstIndex(of: currentCount) ?? 0
    }
    
    private func showNextCard() {
        if currentCardIndex < currentCards.count {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCards = true
            }
            
            // Show card for display time
            DispatchQueue.main.asyncAfter(deadline: .now() + cardDisplayTime) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCards = false
                }
                
                // Wait for card to fully disappear before showing next card
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    currentCardIndex += 1
                    showNextCard()
                }
            }
        } else {
            // All cards shown, show answer options
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAnswer = true
                }
            }
        }
    }
    
    private func checkAnswer(selectedIndex: Int) {
        isCorrect = selectedIndex == correctAnswerIndex
        
        if isCorrect {
            // Award XP
            XPChipManager.shared.addXP(3)
            
            // Increment progress
            progressCircles += 1
            if progressCircles >= 9 {
                // Quiz completed - show claim reward button
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showClaimReward = true
                }
            }
        } else {
            // Reset progress on wrong answer
            progressCircles = 0
            showClaimReward = false
            isQuizInSession = false
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showAnswer = false
            isShowingResult = true
        }
    }
    
    private func claimReward() {
        // Give user 250 chips
        XPChipManager.shared.updateChips(250)
        
        // Reset progress and hide claim reward button
        withAnimation(.easeInOut(duration: 0.3)) {
            progressCircles = 0
            showClaimReward = false
            isQuizInSession = false
        }
    }
    
    private func nextQuestion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingResult = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generateNewQuestion()
        }
    }
}

#Preview {
    NavigationView {
        GameModeSelectionView(map: Map(id: 1, name: "Mercury", imageName: "MercuryImage", isLocked: false, requiredLevel: 1, maxBet: 1_000))
    }
} 
