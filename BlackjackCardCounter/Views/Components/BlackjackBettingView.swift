import SwiftUI

// MARK: - Betting Interface
struct BlackjackBettingView: View {
    @ObservedObject var gameState: BlackjackGameState
    let bettingManager: BlackjackBettingManager
    let gameEngine: BlackjackGameEngine
    
    init(gameState: BlackjackGameState, bettingManager: BlackjackBettingManager) {
        self.gameState = gameState
        self.bettingManager = bettingManager
        self.gameEngine = BlackjackGameEngine.shared
        // Disable all animations globally for this view
        UIView.setAnimationsEnabled(false)
    }
    
    // Hide during dealer turn (flipping cards) or when hand is in progress
    private var dealerIsFlipping: Bool {
        !gameState.isPlayerTurn && !gameState.dealerHand.isEmpty && !gameState.isDealing
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed "Betting Area" title - moves down when chips are present
            Text("Betting Area")
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 24) // Fixed height to prevent movement
                .padding(.top, 12) // Add top padding to prevent cutoff in training mode
                .offset(y: !gameState.betChips.isEmpty ? 10 : 0) // Move down 10 points when chips are placed
            
            // Dynamic content area - chips and notifications move here
            VStack(spacing: 0) {
                ZStack {
                    // Debug overlay: 8 circles covering chip span (payout + bets)
                    let debugColors: [Color] = [
                        Color(red: 0.5, green: 0, blue: 0),      // dark red
                        Color(red: 1.0, green: 0.4, blue: 0.4),  // light red
                        Color(red: 0.8, green: 0.4, blue: 0.0),  // dark orange
                        Color(red: 1.0, green: 0.65, blue: 0.3), // light orange
                        Color(red: 0.7, green: 0.6, blue: 0.0),  // dark yellow
                        Color(red: 0.9, green: 0.8, blue: 0.3),  // light yellow
                        Color(red: 0.0, green: 0.2, blue: 0.5),  // dark blue
                        Color(red: 0.4, green: 0.6, blue: 1.0)   // light blue
                    ]
                    let startX: CGFloat = -(7 * 45.0) / 2 // center 8 circles at 45pt spacing
                    ForEach(0..<8, id: \.self) { idx in
                        Circle()
                            .fill(debugColors[idx])
                            .frame(width: 44, height: 44)
                            .offset(x: startX + CGFloat(idx) * 45.0, y: 0)
                            .zIndex(20000)
                            .allowsHitTesting(false)
                    }

                    // Main bet chips centered - simple offset when chips are present
                    ZStack {
                        ForEach(Array(gameState.betChips.sorted(by: >).enumerated()), id: \.offset) { index, chipValue in
                            // Spiral ALL chips in one stack: highest value at bottom, smallest at top
                            let angle = Double(index) * 0.8  // Tighter spiral
                            let radius: CGFloat = 2.0        // Closer stacking
                            let xOffset = radius * cos(angle)
                            let yOffset = radius * sin(angle)

                            ZStack {
                                Circle()
                                    .fill(debugColors[index % debugColors.count])
                                    .frame(width: 44, height: 44)
                                ChipView(chip: Chip(value: chipValue))
                            }
                                .offset(x: xOffset, y: yOffset)
                                .zIndex(20000 + Double(index)) // force overlay above chips
                                .opacity(gameState.hideBetChipsDuringLoseAnimation ? 0 : 1) // Hide with opacity instead of removing
                                .transition(.identity) // No transition animations
                                .transaction { $0.animation = nil } // Completely disable all animations
                                .allowsHitTesting(false) // Disable interaction with betting chips
                        }
                    }
                    .transaction { $0.animation = nil } // Completely disable all animations
                    .offset(y: !gameState.betChips.isEmpty ? 10 : 0) // Move down 10 points when chips are placed
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    // Capture the betting area position (offset up by 57 points for chip animation)
                                    let globalFrame = geometry.frame(in: .global)
                                    let centerX = globalFrame.midX
                                    let centerY = globalFrame.midY - 57
                                    gameState.bettingAreaPosition = CGPoint(x: centerX, y: centerY)
                                    print("🎯 BETTING AREA POSITION: (\(centerX), \(centerY))")
                                }
                                .onChange(of: geometry.frame(in: .global)) { newFrame in
                                    // Update position if it changes (offset up by 57 points for chip animation)
                                    let centerX = newFrame.midX
                                    let centerY = newFrame.midY - 57
                                    gameState.bettingAreaPosition = CGPoint(x: centerX, y: centerY)
                                    print("🎯 BETTING AREA POSITION UPDATE: (\(centerX), \(centerY))")
                                }
                        }
                    )
                    .onAppear {
                        print("🎯 BlackjackBettingView appeared with betChips: \(gameState.betChips)")
                    }
                    .onChange(of: gameState.betChips) { newBetChips in
                        print("🎯 betChips changed to: \(newBetChips)")
                    }
                    
                    // Additional bet chips (right position - blue circle) - simple offset
                    // Hide during lose animation just like main chips
                    if !gameState.additionalBetChips.isEmpty {
                        ZStack {
                            ForEach(Array(gameState.additionalBetChips.sorted(by: >).enumerated()), id: \.offset) { index, chipValue in
                                // Spiral ALL chips in one stack: highest value at bottom, smallest at top
                            let angle = Double(index) * 0.8  // Tighter spiral
                            let radius: CGFloat = 2.0        // Closer stacking
                                let xOffset = radius * cos(angle)
                                let yOffset = radius * sin(angle)

                                ZStack {
                                    Circle()
                                        .fill(debugColors[index % debugColors.count])
                                        .frame(width: 44, height: 44)
                                    ChipView(chip: Chip(value: chipValue))
                                }
                                    .offset(x: xOffset, y: yOffset)
                                    .zIndex(20000 + Double(index))
                                    .opacity(gameState.hideBetChipsDuringLoseAnimation ? 0 : 1) // Hide with opacity instead of removing
                                    .transition(.identity) // No transition animations
                                    .transaction { $0.animation = nil } // Completely disable all animations
                            }
                        }
                        .transaction { $0.animation = nil } // Completely disable all animations
                        .offset(x: 60) // Same distance as payout animation (60 points right)
                        .onAppear {
                            print("🎯 BlackjackBettingView appeared with additionalBetChips: \(gameState.additionalBetChips)")
                        }
                        .onChange(of: gameState.additionalBetChips) { newAdditionalChips in
                            print("🎯 additionalBetChips changed to: \(newAdditionalChips)")
                        }
                    }
                }
                
                // Return Bet Button positioned on the right
                let dealerIsFlippingHere = !gameState.isPlayerTurn && !gameState.dealerHand.isEmpty && !gameState.isDealing
                let handInProgressHere = gameState.isDealing || gameState.isProcessingAction || dealerIsFlippingHere
                if !gameState.isAutoCollectingWinnings && gameState.playerBet > 0 && !gameState.showNextHand && !handInProgressHere {
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
                
                            Text("Bet: $\(gameState.displayBetAmount > 0 ? gameState.displayBetAmount : (gameState.playerBet > 0 ? gameState.playerBet : gameState.displayBetAmount))")
                    .font(.fixedSystem(size: 18, weight: .semibold))
                    .foregroundColor(.yellow)
                    .offset(y: !gameState.betChips.isEmpty ? 5 : 0) // Move down as soon as chips are placed
                    .padding(.vertical, 10) // Add vertical padding to prevent clipping
                
                // Win/Lose/Push message - text in yellow, numbers in green/red
                // Works for both splits and non-splits
                if gameState.resultMessage != nil, gameState.showResultNotification {
                    if gameState.lastPayout > 0 {
                        // Win: text yellow, number green
                        HStack(spacing: 2) {
                            Text("Win ")
                                .font(.fixedSystem(size: 18, weight: .semibold))
                                .foregroundColor(.yellow)
                            Text("$\(gameState.actualWinnings)")
                                .font(.fixedSystem(size: 18, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .multilineTextAlignment(.center)
                    } else if gameState.lastPayout < 0 {
                        // Lose: text yellow, number red
                        HStack(spacing: 2) {
                            Text("Lose ")
                                .font(.fixedSystem(size: 18, weight: .semibold))
                                .foregroundColor(.yellow)
                            Text("$\(-gameState.lastPayout)")
                                .font(.fixedSystem(size: 18, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .multilineTextAlignment(.center)
                    } else {
                        // Push: both text and number in yellow
                        Text("Push $\(gameState.playerBet)")
                            .font(.fixedSystem(size: 18, weight: .semibold))
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding(.top, -10) // Negative padding to eliminate gap
        .transaction { $0.animation = nil } // Completely disable all animations
        .allowsHitTesting(true) // Keep hit testing enabled for the betting area
        .disableDynamicType()
        .onAppear {
            // Force disable all animations when view appears
            withAnimation(.none) {
                // This ensures no animations are applied
            }
            print("🎯 BETTING VIEW: onAppear - resultMessage=\(gameState.resultMessage ?? "nil"), showNotification=\(gameState.showResultNotification), isSplit=\(gameState.isSplit)")
        }
        .onChange(of: gameState.resultMessage) { newResult in
            print("🎯 BETTING VIEW: resultMessage changed to \(newResult ?? "nil"), showNotification=\(gameState.showResultNotification), lastPayout=\(gameState.lastPayout)")
        }
        .onChange(of: gameState.showResultNotification) { showNotification in
            print("🎯 BETTING VIEW: showResultNotification changed to \(showNotification), resultMessage=\(gameState.resultMessage ?? "nil")")
        }
    }
}

// MARK: - Chip Selection View
struct ChipSelectionView: View {
    @ObservedObject var gameState: BlackjackGameState
    let bettingManager: BlackjackBettingManager
    @State private var pressedChip: Int? = nil
    
    private let playerChips = [1, 5, /* 10, */ 25, 50, 100]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(playerChips, id: \.self) { value in
                Button(action: {
                    print("🎰 Chip \(value) tapped")
                    // Add visual feedback
                    pressedChip = value
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        pressedChip = nil
                    }
                    bettingManager.placeBet(gameState: gameState, chipValue: value)
                }) {
                    ChipView(chip: Chip(value: value))
                        .scaleEffect(pressedChip == value ? 0.9 : 1.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(pressedChip == value ? Color.yellow : Color.white.opacity(0.5), lineWidth: pressedChip == value ? 3 : 2)
                        )
                }
                .disabled(!bettingManager.canPlaceBet(gameState: gameState, chipValue: value))
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                // Store the actual position of this chip
                                let globalFrame = geometry.frame(in: .global)
                                let centerX = globalFrame.midX
                                let centerY = globalFrame.midY
                                gameState.chipSelectionPositions[value] = CGPoint(x: centerX, y: centerY)
                                print("🎰 CHIP POSITION: Chip \(value) at (\(centerX), \(centerY))")
                            }
                            .onChange(of: geometry.frame(in: .global)) { newFrame in
                                // Update position if it changes
                                let centerX = newFrame.midX
                                let centerY = newFrame.midY
                                gameState.chipSelectionPositions[value] = CGPoint(x: centerX, y: centerY)
                                print("🎰 CHIP POSITION UPDATE: Chip \(value) at (\(centerX), \(centerY))")
                            }
                    }
                )
            }
        }
        .transaction { $0.animation = nil } // Completely disable all animations
        // Keep chip selection fixed; otherwise it jumps when bet chips auto-collect/clear.
        .offset(y: 0)
        .padding(.horizontal, 8) // Add horizontal padding for better spacing
        .padding(.vertical, 8) // Add vertical padding for better spacing
        .padding(.bottom, 12)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        // Capture the chip selection area position
                        let globalFrame = geometry.frame(in: .global)
                        let centerX = globalFrame.midX
                        let centerY = globalFrame.midY
                        gameState.chipSelectionAreaPosition = CGPoint(x: centerX, y: centerY)
                        print("🎯 CHIP SELECTION AREA POSITION: (\(centerX), \(centerY))")
                    }
                    .onChange(of: geometry.frame(in: .global)) { newFrame in
                        // Update position if it changes
                        let centerX = newFrame.midX
                        let centerY = newFrame.midY
                        gameState.chipSelectionAreaPosition = CGPoint(x: centerX, y: centerY)
                        print("🎯 CHIP SELECTION AREA POSITION UPDATE: (\(centerX), \(centerY))")
                    }
            }
        )
    }
}

// MARK: - Deal/Next Hand Buttons
struct DealNextHandButtons: View {
    @ObservedObject var gameState: BlackjackGameState
    let gameEngine: BlackjackGameEngine
    let bettingManager: BlackjackBettingManager
    var animationCallback: ((Card, Int, @escaping () -> Void) -> Void)? = nil
    
    // ALWAYS show buttons when chip selection is visible - no other conditions
    private var shouldShowButtons: Bool {
        // Show when chip selection is visible OR results are showing
        let chipSelectionVisible = !gameState.showNextHand
        let showingResult = (gameState.resultMessage != nil && gameState.showResultNotification) || gameState.showPostGameButtons
        return chipSelectionVisible || showingResult
    }

    private var hasPlacedChip: Bool {
        gameState.userPlacedCurrentBet && gameState.playerBet > 0 && !gameState.betChips.isEmpty
    }
    private var dealButtonOpacity: Double { hasPlacedChip ? 1.0 : 0.2 }
    private var dealButtonSaturation: Double { hasPlacedChip ? 1.0 : 0.0 }

    // Only hide during active gameplay (dealing cards or player turn with cards)
    // Dealer turn is handled separately - only hide if round is still in progress (showNextHand is true)
    private var isActiveGameplay: Bool {
        (gameState.isDealing && gameState.playerHand.count >= 2) || 
        (gameState.isPlayerTurn && gameState.playerHand.count >= 2) ||
        gameState.isProcessingAction
    }
    
    // Hide buttons during dealer's turn ONLY if round is still in progress (showNextHand is true)
    // After round ends (showNextHand is false), show buttons regardless of dealer turn status
    private var dealerTurnInProgress: Bool {
        gameState.showNextHand && !gameState.dealerHand.isEmpty && !gameState.isPlayerTurn && !gameState.isDealing
    }
    
    var body: some View {
        if shouldShowButtons && !isActiveGameplay && !dealerTurnInProgress {
                HStack(spacing: 16) {
                if gameState.lastBet != nil {
                    Button(action: {
                        bettingManager.redoBet(gameState: gameState)
                    }) {
                        ZStack {
                            Image("RedoBetButton")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 60)
                                .colorMultiply(bettingManager.canRedoBet(gameState: gameState) ? Color.white : Color.gray)
                            Text("Redo Bet")
                                .font(.fixedSystem(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(!bettingManager.canRedoBet(gameState: gameState))
                }

                Button(action: {
                    if gameState.isDealing { return }
                    gameState.isDealing = true

                    gameState.additionalBetChips = []
                    gameState.doubleDownChipsHand1 = []
                    gameState.doubleDownChipsHand2 = []
                    
                    let originalBet = gameState.playerBet
                    gameState.betChips = []
                    var remaining = originalBet
                    let chipDenominations = [100, 50, 25, 5, 1]
                    for denom in chipDenominations {
                        while remaining >= denom {
                            gameState.betChips.append(denom)
                            remaining -= denom
                        }
                    }
                    
                    let trainingModeEnabled = UserDefaults.standard.bool(forKey: "trainingModeEnabled")
                    if trainingModeEnabled {
                        gameState.resultMessage = nil
                        gameState.showPostGameButtons = false
                        gameState.showResultNotification = true
                    }
                    
                    let useRegularAnimation = gameState.deckPosition != .zero
                    gameEngine.dealInitialCards(
                        gameState: gameState, 
                        useRegularModeAnimation: useRegularAnimation,
                        animationCallback: animationCallback
                    )
                }) {
                        ZStack {
                        Image("DealButton2")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 60)
                            .colorMultiply(hasPlacedChip ? Color.white : Color.gray)
                                .saturation(dealButtonSaturation)
                        Text("Deal Cards")
                            .font(.fixedSystem(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .opacity(dealButtonOpacity)
                }
                .disabled(!hasPlacedChip || gameState.isCollectingPhase)
            }
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
            .frame(width: 44, height: 44) // Increased size for better visibility
            .shadow(radius: 3) // Increased shadow for better definition
    }
} 