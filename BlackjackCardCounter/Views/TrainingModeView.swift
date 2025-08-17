import SwiftUI

struct TrainingModeView: View {
    let map: Map
    
    // Shared game state and managers
    @StateObject private var gameState = BlackjackGameState()
    private let gameEngine = BlackjackGameEngine.shared
    private let bettingManager = BlackjackBettingManager.shared
    private let strategyHelper = BlackjackStrategyHelper.shared
    
    // Training mode specific state
    @AppStorage("trainingDecks") private var numberOfDecks: Int = 6
    @AppStorage("cardUnderglow") private var cardUnderglow: Bool = true
    @State private var showSettings: Bool = false
    @AppStorage("showStrategyHints") private var showStrategyHints: Bool = false
    @State private var showStrategyChart: Bool = false
    @State private var selectedSettingsTab: Int = 0 // 0 = Settings, 1 = Achievements
    @AppStorage("showCardCharts") private var showCardCharts: Bool = false
    @State private var selectedChart: Int = 0 // 0 = Dealt, 1 = Remaining
    
    var body: some View {
        ZStack {
            // Background gradient - ensure it covers the entire screen
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1a3a1a"), Color(hex: "2d5a2d")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all, edges: .all)
            
            // Background text - arched like a rainbow (behind everything)
            GeometryReader { geo in
                ZStack {
                    // "Luna Luxe Casino" - top arc
                    createArchedText(
                        text: "Luna Luxe Casino",
                        fontSize: 36,
                        width: geo.size.width * 0.8,
                        height: 80,
                        centerX: geo.size.width / 2,
                        centerY: geo.size.height / 2 - 125
                    )
                    
                    // "Blackjack pays 3 to 2" - middle arc
                    createArchedText(
                        text: "Blackjack pays 3 to 2",
                        fontSize: 24,
                        width: geo.size.width * 0.7,
                        height: 60,
                        centerX: geo.size.width / 2,
                        centerY: geo.size.height / 2 - 95
                    )
                    
                    // "Dealer must hit on soft 17" - bottom arc
                    createArchedText(
                        text: "Dealer must hit on soft 17",
                        fontSize: 16,
                        width: geo.size.width * 0.75,
                        height: 50,
                        centerX: geo.size.width / 2,
                        centerY: geo.size.height / 2 - 65
                    )
                }
                .allowsHitTesting(false)
            }
            .zIndex(0)
            
            VStack(spacing: 0) {
                // Game Header
                ZStack(alignment: .topTrailing) {
                    GameHeaderView()
                    
                    if gameState.showDebugPayout, let msg = gameState.debugPayoutMessage {
                        Text(msg)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(14)
                            .shadow(radius: 8)
                            .padding(.trailing, 8)
                            .padding(.top, 2)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(2)
                    }
                }
                
                // Visualizers at the top
                VStack(spacing: 8) {
                    CardCountMeter(runningCount: gameState.runningCount)
                    
                    if showCardCharts {
                        VStack(spacing: 4) {
                            Picker("Chart", selection: $selectedChart) {
                                Text("Dealt").tag(0)
                                Text("Remaining").tag(1)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 180)
                            .padding(.bottom, 2)
                            
                            ZStack {
                                if selectedChart == 0 {
                                    BarChartView(
                                        data: strategyHelper.cardsDealtByValue(
                                            dealtPlayerCards: gameState.dealtPlayerCards,
                                            dealtDealerCards: gameState.dealtDealerCards
                                        ),
                                        maxBarHeight: 36,
                                        barColor: .green,
                                        title: "Cards Dealt",
                                        yLabel: "# Dealt"
                                    )
                                } else {
                                    BarChartView(
                                        data: strategyHelper.cardsRemainingByValue(deck: gameState.deck),
                                        maxBarHeight: 36,
                                        barColor: .blue,
                                        title: "Cards Remaining",
                                        yLabel: "# Left"
                                    )
                                }
                            }
                            .background(Color.black.opacity(0.18))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.top, 12)
                
                Spacer().frame(height: 8)
                
                // iPhone-specific spacing above player cards
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Spacer().frame(height: 15)
                }
                
                // Player and Dealer cards area
                GeometryReader { geo in
                    let maxPlayerCards = max(gameState.dealtPlayerCards.count, gameState.isSplit ? gameState.splitHands.flatMap { $0 }.count : 2)
                    let maxDealerCards = max(gameState.dealtDealerCards.count, 2)
                    let maxCards = max(maxPlayerCards, maxDealerCards)
                    let cardWidth = min(60, (geo.size.width - CGFloat(maxCards - 1) * 8) / CGFloat(maxCards))
                    
                    VStack(spacing: 0) {
                        // Dealer cards
                        VStack(spacing: 8) {
                            HStack {
                                Text("Dealer")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(dealerValueLabel())
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                            }
                            
                            HStack(spacing: 8) {
                                ForEach(gameState.dealtDealerCards.indices, id: \.self) { idx in
                                    FlipCardView(
                                        card: gameState.dealtDealerCards[idx],
                                        isFlipped: gameState.flippedDealerCards.contains(idx),
                                        width: cardWidth,
                                        glowWidth: cardWidth + 10
                                    )
                                    .layoutPriority(1)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .offset(y: UIDevice.current.userInterfaceIdiom == .phone ? -15 : 0)
                        
                        // Spacing between dealer and player - 5 points more on iPhone
                        Spacer().frame(height: UIDevice.current.userInterfaceIdiom == .phone ? 13 : 8)
                        
                        // Player cards
                        VStack(spacing: 8) {
                            HStack {
                                Text("Player")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(gameState.isSplit ? gameEngine.getHandValueText(gameState.splitHands[gameState.activeHandIndex]) : gameEngine.getHandValueText(gameState.playerHand))
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                            }
                            
                            if gameState.isSplit {
                                HStack(spacing: 24) {
                                    ForEach(gameState.splitHands.indices, id: \.self) { idx in
                                        VStack {
                                            HStack {
                                                Text("Hand \(idx == 1 ? 1 : 2)\(gameState.activeHandIndex == idx ? " (Active)" : "")")
                                                    .font(.caption)
                                                    .foregroundColor(gameState.activeHandIndex == idx ? .yellow : .gray)
                                                Text(gameEngine.getHandValueText(gameState.splitHands[idx]))
                                                    .font(.caption)
                                                    .foregroundColor(.yellow)
                                            }
                                            
                                            HStack(spacing: 8) {
                                                ForEach(gameState.splitHands[idx]) { card in
                                                    CardView(card: card, width: cardWidth, glowWidth: cardWidth + 10)
                                                        .layoutPriority(1)
                                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .center)
                                        }
                                    }
                                }
                            } else {
                                HStack(spacing: 8) {
                                    ForEach(gameState.dealtPlayerCards) { card in
                                        CardView(card: card, width: cardWidth, glowWidth: cardWidth + 10)
                                            .layoutPriority(1)
                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .frame(height: 240)
                        
                        // iPad-specific spacing above action buttons
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Spacer().frame(height: 250)
                        }
                        
                        // Show result message after round
                        if gameState.showNextHand && gameState.isPlayerTurn {
                            // Check if current active hand has blackjack (don't show buttons if so)
                            let activeHasBlackjack = gameState.isSplit && 
                                gameEngine.isBlackjack(gameState.splitHands[gameState.activeHandIndex])
                            
                            if !activeHasBlackjack {
                                BlackjackActionButtons(
                                    gameState: gameState,
                                    gameEngine: gameEngine,
                                    showStrategyHints: showStrategyHints,
                                    getPerfectStrategyAction: {
                                        strategyHelper.getPerfectStrategyAction(
                                            playerHand: gameState.playerHand,
                                            dealerHand: gameState.dealerHand
                                        )
                                    }
                                )
                            }
                        }
                        
                        Spacer().frame(height: 24)
                        
                        // Betting area
                        BlackjackBettingView(
                            gameState: gameState,
                            bettingManager: bettingManager,
                            gameEngine: gameEngine
                        )
                        .disabled(gameState.isDealing)
                        
                        // Chips at the bottom (always visible before a hand is dealt or after a round is over)
                        if !gameState.showNextHand {
                            ChipSelectionView(
                                gameState: gameState,
                                bettingManager: bettingManager
                            )
                            .disabled(gameState.isDealing)
                        }
                        
                        // Deal/Next Hand Button at the very bottom
                        if gameState.resultMessage != nil || (!gameState.showNextHand && gameState.playerHand.isEmpty && gameState.dealerHand.isEmpty) {
                            DealNextHandButtons(
                                gameState: gameState,
                                gameEngine: gameEngine,
                                bettingManager: bettingManager
                            )
                        }
                    }
                            }
            .onAppear {
                gameEngine.resetDeck(gameState: gameState, numberOfDecks: numberOfDecks)
            }
            .onDisappear {
                // Return any unplayed bets when leaving the view
                if gameState.playerBet > 0 && !gameState.showNextHand && gameState.resultMessage == nil {
                    print("🔄 Training Mode: Returning unplayed bet of $\(gameState.playerBet)")
                    XPChipManager.shared.updateChips(gameState.playerBet)
                    gameState.playerBet = 0
                    gameState.betChips = []
                }
            }
            }
            
            // Floating button to open strategy chart
            VStack {
                HStack {
                    Button(action: { showStrategyChart = true }) {
                        Image(systemName: "tablecells")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                            .shadow(radius: 6)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .shadow(radius: 6)
                    }
                    .padding(.trailing, 8)
                    .offset(y: -230)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .offset(y: -30)
            
            // Strategy chart overlay
            if showStrategyChart {
                StrategyChartOverlay(showStrategyChart: $showStrategyChart)
            }
            
            // Settings Modal Overlay
            if showSettings {
                SettingsOverlay(
                    showSettings: $showSettings,
                    selectedSettingsTab: $selectedSettingsTab,
                    numberOfDecks: $numberOfDecks,
                    cardUnderglow: $cardUnderglow,
                    showStrategyHints: $showStrategyHints,
                    showCardCharts: $showCardCharts,
                    gameState: gameState,
                    gameEngine: gameEngine
                )
            }
        }
        .overlay {
            if gameState.showZeroChipsOverlay {
                ZeroChipsOverlay(isPresented: $gameState.showZeroChipsOverlay)
            }
        }
        .frame(maxWidth: 1000) // Limit width on larger screens
        .frame(maxWidth: .infinity) // Center the content
    }
    
    private func dealerValueLabel() -> String {
        if gameState.visuallyRevealedDealerHand.count < 1 {
            return "?"
        } else if gameState.isPlayerTurn {
            // During player turn, only show the second dealer card (index 1 in dealt cards, but index 0 in visually revealed)
            return gameEngine.getHandValueText([gameState.visuallyRevealedDealerHand[0]])
        } else {
            return gameEngine.getHandValueText(gameState.visuallyRevealedDealerHand)
        }
    }
    
    private func createArchedText(text: String, fontSize: CGFloat, width: CGFloat, height: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        let chars = Array(text)
        let count = chars.count
        let charSpacing = width / CGFloat(max(count - 1, 1))
        
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let x = centerX - width / 2 + CGFloat(i) * charSpacing
                
                // Calculate y position to create a gentle arch
                let progress = CGFloat(i) / CGFloat(max(count - 1, 1)) // 0 to 1
                let archHeight = height * 0.3 // How much the middle is raised
                let y = centerY - archHeight * sin(progress * .pi) // Creates a smooth arch
                
                ZStack {
                    // Golden border layer (larger, underneath)
                    Text(String(chars[i]))
                        .font(.system(size: fontSize + 4, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.15))
                        .position(x: x, y: y)
                    
                    // White text layer (smaller, on top)
                    Text(String(chars[i]))
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Strategy Chart Overlay
struct StrategyChartOverlay: View {
    @Binding var showStrategyChart: Bool
    
    var body: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture { showStrategyChart = false }
        
        VStack(spacing: 16) {
            Text("Blackjack Strategy Chart")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
                .padding(.top, 16)
            
            // Key legend
            HStack(spacing: 12) {
                LegendCell(label: "H", text: "Hit", color: .green)
                LegendCell(label: "D", text: "Double Down", color: .orange)
                LegendCell(label: "S", text: "Stand", color: .red)
                LegendCell(label: "P", text: "Split", color: .purple)
            }
            .padding(.bottom, 4)
            
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    // Hard Totals
                    Text("Hard Totals")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    StrategyChartView(
                        headers: ["Total", "2", "3", "4", "5", "6", "7", "8", "9", "10", "A"],
                        rows: [
                            ["5-7", "H", "H", "H", "H", "H", "H", "H", "H", "H", "H"],
                            ["8",   "H", "H", "H", "H", "D", "H", "H", "H", "H", "H"],
                            ["9",   "D", "D", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["10",  "D", "D", "D", "D", "D", "D", "D", "H", "H", "H"],
                            ["11",  "D", "D", "D", "D", "D", "D", "D", "D", "D", "D"],
                            ["12",  "H", "H", "S", "S", "S", "H", "H", "H", "H", "H"],
                            ["13-16", "S", "S", "S", "S", "S", "H", "H", "H", "H", "H"],
                            ["17+", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S"]
                        ]
                    )
                    
                    // Soft Totals
                    Text("Soft Totals (one Ace counted as 11)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    StrategyChartView(
                        headers: ["Soft Total", "2", "3", "4", "5", "6", "7", "8", "9", "10", "A"],
                        rows: [
                            ["A2/13", "H", "H", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A3/14", "H", "H", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A4/15", "H", "H", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A5/16", "H", "D", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A6/17", "D", "D", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A7/18", "S", "D", "D", "D", "D", "S", "S", "H", "H", "H"],
                            ["A8/19", "S", "S", "S", "S", "D", "S", "S", "S", "S", "S"],
                            ["A9/20+", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S"]
                        ]
                    )
                    
                    // Pair Splits
                    Text("Pair Splits")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    StrategyChartView(
                        headers: ["Pair", "2", "3", "4", "5", "6", "7", "8", "9", "10", "A"],
                        rows: [
                            ["2-2", "P", "P", "P", "P", "P", "P", "H", "H", "H", "H"],
                            ["3-3", "P", "P", "P", "P", "P", "P", "H", "H", "H", "H"],
                            ["4-4", "H", "H", "P", "P", "P", "H", "H", "H", "H", "H"],
                            ["5-5", "D", "D", "D", "D", "D", "D", "D", "H", "H", "H"],
                            ["6-6", "P", "P", "P", "P", "P", "P", "H", "H", "H", "H"],
                            ["7-7", "P", "P", "P", "P", "P", "P", "H", "S", "H", "H"],
                            ["8-8", "P", "P", "P", "P", "P", "P", "P", "P", "P", "P"],
                            ["9-9", "P", "P", "P", "S", "P", "P", "S", "P", "S", "P"],
                            ["10-10", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S"],
                            ["A-A", "P", "P", "P", "P", "P", "P", "P", "P", "P", "P"]
                        ]
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .frame(width: 400, height: 500)
            .background(Color(hex: "23272a").opacity(0.98))
            .cornerRadius(22)
            
            Button(action: { showStrategyChart = false }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color(hex: "ff0000"))
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .frame(maxWidth: 440)
        .background(Color(hex: "23272a").opacity(0.98))
        .cornerRadius(28)
        .shadow(radius: 24)
        .padding(.top, 60)
    }
}

// MARK: - Settings Overlay
struct SettingsOverlay: View {
    @Binding var showSettings: Bool
    @Binding var selectedSettingsTab: Int
    @Binding var numberOfDecks: Int
    @Binding var cardUnderglow: Bool
    @Binding var showStrategyHints: Bool
    @Binding var showCardCharts: Bool
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture { showSettings = false }
        
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Tab bar
                HStack(spacing: 0) {
                    Button(action: { selectedSettingsTab = 0 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                            Text("Settings")
                                .font(.headline)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(selectedSettingsTab == 0 ? Color(hex: "23272a") : Color.clear)
                        .foregroundColor(selectedSettingsTab == 0 ? .yellow : .white)
                        .opacity(selectedSettingsTab == 0 ? 1.0 : 0.5)
                    }
                    
                    Button(action: { selectedSettingsTab = 1 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(.title2)
                            Text("Achievements")
                                .font(.headline)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(selectedSettingsTab == 1 ? Color(hex: "23272a") : Color.clear)
                        .foregroundColor(selectedSettingsTab == 1 ? .yellow : .white)
                        .opacity(selectedSettingsTab == 1 ? 1.0 : 0.5)
                    }
                }
                .background(Color(hex: "1a1a2e").opacity(0.95))
                
                // Tab content
                if selectedSettingsTab == 0 {
                    SettingsTabView(
                        numberOfDecks: $numberOfDecks,
                        cardUnderglow: $cardUnderglow,
                        showStrategyHints: $showStrategyHints,
                        showCardCharts: $showCardCharts,
                        showSettings: $showSettings,
                        gameState: gameState,
                        gameEngine: gameEngine
                    )
                } else {
                    AchievementsTabView()
                }
            }
            .background(Color(hex: "16213e").opacity(0.95))
            .cornerRadius(24)
            .shadow(radius: 20)
            .frame(maxWidth: 340)
            .offset(y: -UIScreen.main.bounds.height * 0.18)
        }
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @Binding var numberOfDecks: Int
    @Binding var cardUnderglow: Bool
    @Binding var showStrategyHints: Bool
    @Binding var showCardCharts: Bool
    @Binding var showSettings: Bool
    let gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                HStack {
                    Text("Decks:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Picker("Decks", selection: $numberOfDecks) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("6").tag(6)
                        Text("8").tag(8)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 220)
                    .onChange(of: numberOfDecks) { _ in
                        gameEngine.resetDeck(gameState: gameState, numberOfDecks: numberOfDecks)
                    }
                }
                
                HStack {
                    Text("Card Underglow:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Toggle("", isOn: $cardUnderglow)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Show Perfect Strategy Hints:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Toggle("", isOn: $showStrategyHints)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Show Card Charts:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Toggle("", isOn: $showCardCharts)
                        .labelsHidden()
                }
            }
            
            Button(action: { showSettings = false }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color(hex: "ff0000"))
                    .cornerRadius(12)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 340)
        .padding(.top, 24)
    }
}

// MARK: - Achievements Tab View
struct AchievementsTabView: View {
    var body: some View {
        let achievements: [Achievement] = [
            Achievement(title: "Reach Level 5", description: "Reach player level 5", current: 3, goal: 5),
            Achievement(title: "Reach Level 10", description: "Reach player level 10", current: 7, goal: 10),
            Achievement(title: "Reach Level 20", description: "Reach player level 20", current: 12, goal: 20),
            Achievement(title: "Reach Level 30", description: "Reach player level 30", current: 18, goal: 30),
            Achievement(title: "Reach Level 40", description: "Reach player level 40", current: 25, goal: 40),
            Achievement(title: "Reach Level 50", description: "Reach player level 50", current: 32, goal: 50),
            Achievement(title: "First Blackjack!", description: "Get a natural blackjack (Ace + 10) in a hand", current: 1, goal: 1),
            Achievement(title: "Double Down!", description: "Double down 10 times", current: 4, goal: 10),
            Achievement(title: "Split Master", description: "Split pairs 5 times", current: 2, goal: 5),
            Achievement(title: "Winning Streak", description: "Win 10 hands in a row", current: 6, goal: 10),
            Achievement(title: "Push It Real Good", description: "Get 10 pushes (ties)", current: 3, goal: 10),
            Achievement(title: "Chip Collector", description: "Accumulate 1,000 chips", current: 500, goal: 1000),
            Achievement(title: "Card Counter", description: "Keep a running count above +10", current: 8, goal: 10),
            Achievement(title: "Dealer Busted!", description: "Win 10 hands where the dealer busts", current: 5, goal: 10),
            Achievement(title: "Insurance Expert", description: "Take insurance 5 times", current: 1, goal: 5),
            Achievement(title: "Perfect Strategy", description: "Play 20 hands with perfect basic strategy", current: 10, goal: 20),
            Achievement(title: "Quiz Whiz", description: "Score 100% on a quiz", current: 0, goal: 1),
            Achievement(title: "Big Winner", description: "Win a hand with a bet of 100 chips or more", current: 1, goal: 1),
            Achievement(title: "Comeback Kid", description: "Win after being down to your last 10 chips", current: 0, goal: 1),
            Achievement(title: "Five Card Charlie", description: "Win a hand with 5 cards without busting", current: 0, goal: 1),
            Achievement(title: "Lucky 7s", description: "Get three 7s in a hand", current: 0, goal: 1),
            Achievement(title: "High Roller", description: "Place a bet of 500 chips", current: 0, goal: 1),
            Achievement(title: "No Busts!", description: "Play 10 hands in a row without busting", current: 4, goal: 10),
            Achievement(title: "Dealer Blackjack", description: "Lose to a dealer blackjack 5 times", current: 2, goal: 5),
            Achievement(title: "All In!", description: "Bet all your chips in one hand", current: 0, goal: 1)
        ]
        
        ScrollView {
            VStack(spacing: 18) {
                ForEach(achievements) { achievement in
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: achievement.isComplete ? "trophy.fill" : "trophy")
                            .foregroundColor(achievement.isComplete ? .yellow : .gray)
                            .font(.title2)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(achievement.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(achievement.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                            AchievementProgressBar(progress: min(Double(achievement.current) / Double(achievement.goal), 1.0))
                                .frame(height: 10)
                            Text("\(achievement.current)/\(achievement.goal)")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        if achievement.isComplete {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "23272a").opacity(0.85))
                    .cornerRadius(12)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: 340, minHeight: 220, maxHeight: 340)
    }
}

#Preview {
    TrainingModeView(map: Map(id: 1, name: "Mercury", imageName: "MercuryImage", isLocked: false, requiredLevel: 1))
}

// Custom extension for rounding specific corners
import SwiftUI

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// ArchTextModifier for arched text effect
struct ArchTextModifier: ViewModifier {
    var width: CGFloat
    var height: CGFloat
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let text = (content as? Text) ?? Text("")
                    ArchText(text: text, width: width, height: height)
                }
            )
            .opacity(0) // Hide the original
    }
}

struct ArchText: View {
    let text: Text
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        let string = Mirror(reflecting: text).descendant("storage", "anyTextStorage", "storage", "verbatim") as? String ?? ""
        let chars = Array(string)
        let count = chars.count
        let charSpacing = width / CGFloat(max(count - 1, 1))
        
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let x = width / 2 + CGFloat(i) * charSpacing - width / 2
                
                // Calculate y position to create a gentle arch
                let progress = CGFloat(i) / CGFloat(max(count - 1, 1)) // 0 to 1
                let archHeight = height * 0.3 // How much the middle is raised
                let y = height / 2 - archHeight * sin(progress * .pi) // Creates a smooth arch
                
                Text(String(chars[i]))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
                    .position(x: x, y: y)
            }
        }
        .frame(width: width, height: height)
    }
}

