import SwiftUI

// MARK: - Simple Chip Win/Lose Animation System
struct ChipWinLoseAnimation: View {
    @ObservedObject var gameState: BlackjackGameState
    @State private var winChips: [AnimatedChip] = []
    @State private var loseChips: [AnimatedChip] = []
    @State private var savedLoseChips: [Int] = [] // Save chips for lose animation
    
    var body: some View {
        GeometryReader { geo in
            // Convert global chip positions -> local offsets using the overlay's actual global frame.
            let frame = geo.frame(in: .global)
            let _ = print("🎯 CHIP OVERLAY FRAME: minX=\(frame.minX), minY=\(frame.minY), maxX=\(frame.maxX), maxY=\(frame.maxY), midX=\(frame.midX), midY=\(frame.midY)")
            
            // Use a top-left anchored container so mapping (global -> local) is stable across
            // both Training + Regular modes (avoids center-offset drift).
            ZStack(alignment: .topLeading) {
            // Shared debug palette for chip overlays
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

            // Win animation chips - overlay circles that follow animation
            ForEach(Array(winChips.enumerated()), id: \.element.id) { idx, chip in
                ZStack {
                    Circle()
                        .fill(debugColors[idx % debugColors.count])
                        .frame(width: 44, height: 44)
                        .opacity(1.0)
                    ChipView(chip: Chip(value: chip.value))
                }
                    .position(
                        x: chip.position.x - frame.minX,
                        y: chip.position.y - frame.minY
                )
                .opacity(chip.opacity)
                .scaleEffect(chip.scale)
                .zIndex(20000) // Keep overlays above everything
            }
            
            // Lose animation chips - overlay circles that follow animation
            ForEach(Array(loseChips.enumerated()), id: \.element.id) { idx, chip in
                ZStack {
                    Circle()
                        .fill(debugColors[idx % debugColors.count])
                        .frame(width: 44, height: 44)
                        .opacity(1.0)
                    ChipView(chip: Chip(value: chip.value))
                }
                    .position(
                        x: chip.position.x - frame.minX,
                        y: chip.position.y - frame.minY
                )
                .opacity(chip.opacity)
                .scaleEffect(chip.scale)
                .zIndex(20000)
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // Don't interfere with user interactions
        .clipped() // Prevent overflow
        .allowsHitTesting(false) // Don't interfere with user interactions
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fixed frame to prevent layout shifts
        .zIndex(9999) // Ensure animation is above everything
        .background(Color.clear) // Transparent background
        .clipped() // Prevent overflow
        .onChange(of: gameState.resultMessage) { resultMessage in
            print("🔍 DEBUG: resultMessage changed to: \(resultMessage ?? "nil"), showResultNotification: \(gameState.showResultNotification)")
            
            if let result = resultMessage, gameState.showResultNotification {
                // FIXED: Use gameState.isTrainingMode instead of unreliable UserDefaults
                let trainingModeEnabled = gameState.isTrainingMode
                
                print("🔍 🚨 CORRECT TRAINING MODE DETECTION:")
                print("🔍 🚨 gameState.isTrainingMode = \(trainingModeEnabled)")
                print("🔍 🚨 Mode=\(trainingModeEnabled ? "Training" : "Regular"), lastPayout=\(gameState.lastPayout)")
                
                // COMPREHENSIVE ANIMATION LOGIC - Handle ALL scenarios
                handleAllAnimationScenarios(resultMessage: result, trainingModeEnabled: trainingModeEnabled)
            } else if resultMessage == nil {
                // Clear win chips when notification disappears
                print("🔍 DEBUG: Clearing win chips - resultMessage is nil")
                winChips.removeAll()
            }
        }
        .onChange(of: gameState.betChips) { newBetChips in
            // Trigger animations when user places new bet after round ends
            print("🎯 CHIP CHANGE: newBetChips count=\(newBetChips.count), lastPayout=\(gameState.lastPayout), resultMessage=\(gameState.resultMessage ?? "nil")")
            
            // Only trigger animations if there's a result message (round ended)
            if newBetChips.count > 0 && gameState.resultMessage != nil {
                if gameState.lastPayout > 0 {
                    // User won - animate betting area clearing (chips disappear)
                    print("🎯 TRIGGERING WIN CLEAR ANIMATION from betChips change")
                    startWinBettingClearAnimation()
                }
                // Note: Push animation should NOT trigger here - it's handled by card collection
                // Note: Lose animation now happens immediately when user loses, not when placing new bet
            }
        }
        .onChange(of: gameState.lastBet) { lastBet in
            // Trigger animations when user clicks redo bet after round ends
            print("🎯 REDO BET CHANGE: lastBet=\(lastBet ?? 0), lastPayout=\(gameState.lastPayout), resultMessage=\(gameState.resultMessage ?? "nil")")
            
            // Only trigger animations if there's a result message (round ended)
            if lastBet != nil && gameState.resultMessage != nil {
                if gameState.lastPayout > 0 {
                    // User won - animate betting area clearing (chips disappear)
                    print("🎯 TRIGGERING WIN CLEAR ANIMATION from redo bet")
                    startWinBettingClearAnimation()
                }
                // Note: Push animation should NOT trigger here - it's handled by card collection
                // Note: Lose animation now happens immediately when user loses, not when clicking redo bet
            }
        }
        // Auto-collect winnings + bet chips after payout (triggered from game engine)
        .onChange(of: gameState.autoCollectWinningsToggle) { _ in
            if gameState.lastPayout > 0 {
                startAutoCollectWinningsAnimation()
            }
        }
    }
    
    // MARK: - Comprehensive Animation Handler
    private func handleAllAnimationScenarios(resultMessage: String, trainingModeEnabled: Bool) {
        print("🎯 COMPREHENSIVE: Analyzing all animation scenarios")
        print("🎯 COMPREHENSIVE: isSplit=\(gameState.isSplit), additionalBetChips=\(gameState.additionalBetChips.count), lastPayout=\(gameState.lastPayout)")
        
        // SCENARIO 1: DUAL STACK (Double Down or Split with additional chips)
        if !gameState.additionalBetChips.isEmpty {
            print("🎯 SCENARIO 1: DUAL STACK - Handling double down/split animations")
            handleDualStackResults(resultMessage: resultMessage, trainingModeEnabled: trainingModeEnabled)
            return
        }
        
        // SCENARIO 2: SINGLE STACK (Regular play or split without additional chips showing)
        if gameState.isSplit {
            print("🎯 SCENARIO 2A: SPLIT (Single Stack) - Analyzing split results")
            let splitResults = analyzeSplitResults(resultMessage: resultMessage)
            
            if splitResults.hasWin && splitResults.hasLose {
                // Mixed split with single stack - this shouldn't happen but handle gracefully
                print("🎯 SPLIT MIXED (Single Stack): Using regular win/lose logic based on net payout")
                if gameState.lastPayout > 0 {
                    startSingleStackWinAnimation(trainingModeEnabled: trainingModeEnabled)
                } else if gameState.lastPayout < 0 {
                    startSingleStackLoseAnimation(trainingModeEnabled: trainingModeEnabled)
                }
            } else if splitResults.hasWin && !splitResults.hasLose {
                print("🎯 SPLIT WIN (Single Stack): Starting win animation")
                startSingleStackWinAnimation(trainingModeEnabled: trainingModeEnabled)
            } else if splitResults.hasLose && !splitResults.hasWin {
                print("🎯 SPLIT LOSE (Single Stack): Starting lose animation")
                startSingleStackLoseAnimation(trainingModeEnabled: trainingModeEnabled)
            } else {
                print("🎯 SPLIT PUSH (Single Stack): All hands pushed, no animation")
            }
        } else {
            print("🎯 SCENARIO 2B: REGULAR PLAY (Single Stack)")
            if gameState.lastPayout > 0 {
                print("🎯 REGULAR WIN: Starting win animation")
                startSingleStackWinAnimation(trainingModeEnabled: trainingModeEnabled)
            } else if gameState.lastPayout < 0 {
                print("🎯 REGULAR LOSE: Starting lose animation")
                startSingleStackLoseAnimation(trainingModeEnabled: trainingModeEnabled)
            } else {
                print("🎯 REGULAR PUSH: No animation - money returned, no payout")
                // Push = no animation, money just stays with player
            }
        }
    }
    
    // MARK: - Single Stack Animation Helpers
    private func startSingleStackWinAnimation(trainingModeEnabled: Bool) {
        if trainingModeEnabled {
            print("🔍 🚨 CALLING TRAINING MODE WIN ANIMATION")
            startTrainingModeWinAnimation()
        } else {
            print("🔍 🚨 CALLING REGULAR MODE WIN ANIMATION")
            startRegularModeWinAnimation()
        }
    }
    
    private func startSingleStackLoseAnimation(trainingModeEnabled: Bool) {
        if trainingModeEnabled {
            print("🔍 🚨 CALLING TRAINING MODE LOSE ANIMATION")
            startTrainingModeLoseAnimation()
        } else {
            print("🔍 🚨 CALLING REGULAR MODE LOSE ANIMATION")
            startRegularModeLoseAnimation()
        }
    }
    
    // MARK: - NEW Mode-Specific Animation Functions
    private func startRegularModeWinAnimation() {
        guard gameState.betChips.count > 0 && gameState.lastPayout > 0 else { 
            print("💰 REGULAR WIN: Guard failed - betChips=\(gameState.betChips.count), lastPayout=\(gameState.lastPayout)")
            return 
        }
        
        print("💰 REGULAR MODE WIN: Starting payout animation")
        
        // Clear any existing win chips
        winChips.removeAll()
        
        let dealerPos = getDealerPosition()
        // REGULAR MODE SPECIFIC: Non-split win payout chips should land touching the LEFT side of the on-table stack.
        // Regular Mode uses GeometryReader to capture bettingAreaPosition, and chips are offset relative to that center.
        // View calculates: rowStart = -22.5 (relative), firstUserX = 22.5 (relative)
        // So payout chip is 45pt to the left of user chip (touching)
        let chipSize: CGFloat = 44.0
        let chipSpacing: CGFloat = chipSize + 1.0 // 45pt: touching
        let payoutCount = 1
        let bettingPos = getRegularModeBettingPosition()
        let centerX = bettingPos.x
        
        // REGULAR MODE FIX: Calculate payout position to match exact view layout
        // The view renders: user chip at offset(x: firstUserX) where firstUserX = 22.5 (relative to center)
        // So user chip is at: centerX + 22.5
        // Payout chip should be: centerX + 22.5 - 45 = centerX - 22.5
        let userStackCount = 1
        let totalCount = payoutCount + userStackCount // 2 chips total
        let rowStartRelative = -chipSpacing * CGFloat(max(totalCount - 1, 0)) / 2.0 // -22.5
        let firstUserXRelative = rowStartRelative + CGFloat(payoutCount) * chipSpacing // 22.5
        let userChipX = centerX + firstUserXRelative // center + 22.5
        // REGULAR MODE: Payout chip must be exactly 45pt to the left (touching, no overlap)
        let payoutChipX = userChipX - chipSpacing // center + 22.5 - 45 = center - 22.5
        let clampedStart = clampedRowStartX(startX: payoutChipX, count: payoutCount, spacing: chipSpacing, chipSize: chipSize)
        
        let source = gameState.betChips.sorted(by: >)
        for chipValue in source.prefix(payoutCount) {
            winChips.append(AnimatedChip(id: UUID(), value: chipValue, position: dealerPos, opacity: 1.0, scale: 1.0))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // REGULAR MODE SPECIFIC FIX FOR NON-SPLIT NON-DD ONLY:
            // The bettingAreaPosition is captured at frame.midY of the 60pt container
            // For Regular Mode non-split, shift UP to align with actual chip rendering position
            // This is Regular Mode specific - Training Mode uses +97 and works perfectly
            let regularModeNonSplitYOffset: CGFloat = 0 // Shift UP by 20 points from previous position
            let regularModeChipY = bettingPos.y + regularModeNonSplitYOffset
            
            // REGULAR MODE X: Calculate payout X to be exactly 45pt to the left of user chip
            // View: rowStart = -22.5, firstUserX = 22.5, so user chip at center + 22.5
            // Payout: center - 22.5 (exactly 45pt to the left, touching, no overlap)
            let finalPayoutX = centerX + rowStartRelative // centerX - 22.5
            
            print("💰 REGULAR WIN (NON-SPLIT NON-DD): Regular Mode specific Y adjustment")
            print("💰 REGULAR WIN: bettingPos.y=\(bettingPos.y), offset=\(regularModeNonSplitYOffset), chipY=\(regularModeChipY)")
            print("💰 REGULAR WIN: finalPayoutX=\(finalPayoutX), userChipX=\(userChipX), spacing=\(userChipX - finalPayoutX)")
            
            for i in 0..<min(payoutCount, winChips.count) {
                let xPos = finalPayoutX + CGFloat(i) * chipSpacing
                winChips[i].position = CGPoint(x: xPos, y: regularModeChipY)
                print("💰 REGULAR WIN: Payout chip \(i) final position: (\(xPos), \(regularModeChipY))")
            }
        }
    }
    
    private func startTrainingModeWinAnimation() {
        guard gameState.betChips.count > 0 && gameState.lastPayout > 0 else { 
            print("💰 TRAINING WIN: Guard failed - betChips=\(gameState.betChips.count), lastPayout=\(gameState.lastPayout)")
            return 
        }
        
        print("💰 TRAINING MODE WIN: Starting payout animation")
        
        // Clear any existing win chips
        winChips.removeAll()
        
        let dealerPos = getDealerPosition()
        
        // Non-split training win payout chips should land touching the LEFT side of the on-table stack.
        // Match the layout logic from TrainingModeView: centered row [payout][bet]
        // View calculates: rowStart = -22.5 (relative), firstUserX = 22.5 (relative)
        // So payout chip is 45pt to the left of user chip (touching)
        let chipSize: CGFloat = 44.0
        let chipSpacing: CGFloat = chipSize + 1.0 // 45pt: touching
        let payoutCount = 1
        let bettingPos = getTrainingModeBettingPosition()
        let centerX = bettingPos.x
        // Calculate where user chip is positioned (relative to center, then add to center)
        let userStackCount = 1
        let totalCount = payoutCount + userStackCount // 2 chips total
        let rowStartRelative = -chipSpacing * CGFloat(max(totalCount - 1, 0)) / 2.0 // -22.5
        let firstUserXRelative = rowStartRelative + CGFloat(payoutCount) * chipSpacing // 22.5
        let userChipX = centerX + firstUserXRelative // center + 22.5
        // Payout chip is 45pt to the left of user chip (touching)
        let payoutChipX = userChipX - chipSpacing // center + 22.5 - 45 = center - 22.5
        let clampedStart = clampedRowStartX(startX: payoutChipX, count: payoutCount, spacing: chipSpacing, chipSize: chipSize)
        
        let source = gameState.betChips.sorted(by: >)
        for chipValue in source.prefix(payoutCount) {
            winChips.append(AnimatedChip(id: UUID(), value: chipValue, position: dealerPos, opacity: 1.0, scale: 1.0))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // For non-split, non-double-down: shift payout chip down to align with betting chips
            let adjustedY = bettingPos.y + 97 // Same offset as split scenarios
            // Match view layout: payout chip should be 45pt to the left of user chip (touching)
            // View calculates: rowStart = -22.5 (relative), firstUserX = 22.5 (relative)
            // So payout at center - 22.5, user at center + 22.5 (45pt apart, touching)
            print("💰 TRAINING WIN: centerX=\(centerX), userChipX=\(userChipX), payoutChipX=\(payoutChipX), clampedStart=\(clampedStart), adjustedY=\(adjustedY)")
            for i in 0..<min(payoutCount, winChips.count) {
                let xPos = clampedStart + CGFloat(i) * chipSpacing
                winChips[i].position = CGPoint(x: xPos, y: adjustedY)
                print("💰 TRAINING WIN: Payout chip \(i) at (\(xPos), \(adjustedY))")
            }
        }
    }
    
    private func startRegularModeLoseAnimation() {
        // Use saved chips for lose animation (betChips were cleared to disable Deal Cards button)
        let chipsToAnimate = gameState.savedLoseChips.isEmpty ? gameState.betChips : gameState.savedLoseChips
        guard !chipsToAnimate.isEmpty else { 
            print("💰 REGULAR MODE LOSE: No chips to animate")
            return 
        }
        
        print("💰 REGULAR MODE LOSE: Starting smooth slide animation with \(chipsToAnimate.count) chips")
        
        // REGULAR MODE: Hardcoded lose position
        let loseX: CGFloat = UIScreen.main.bounds.width * 0.5  // Center X
        let loseY: CGFloat = UIScreen.main.bounds.height * 0.75 - 110  // Above betting area
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // Create animation chips that start from betting area
        for (index, chipValue) in chipsToAnimate.enumerated() {
            let angle = Double(index) * 0.8  // Tighter spiral
            let radius: CGFloat = 2.0        // Closer stacking
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            
            let loseChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: CGPoint(
                    x: loseX + xOffset,
                    y: loseY + yOffset
                ),
                opacity: 1.0,
                scale: 1.0
            )
            loseChips.append(loseChip)
        }
        
        // Hide the actual betting chips immediately so only animated chips are visible
        gameState.hideBetChipsDuringLoseAnimation = true
        
        // Smooth slide animation at angle toward dealer (up and to the right)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 REGULAR MODE LOSE: Sliding chips toward dealer at angle")
            withAnimation(.easeOut(duration: 1.0)) {
                for i in 0..<loseChips.count {
                    loseChips[i].position = CGPoint(
                        x: UIScreen.main.bounds.width + 100, // Off-screen to the right
                        y: UIScreen.main.bounds.height * 0.25 // Up toward dealer area
                    )
                    loseChips[i].opacity = 0.0 // Fade out completely
                }
            }
        }
        
        // Clean up after animation and keep chips gone
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            loseChips.removeAll()
            // Clear saved chips after animation completes
            gameState.savedLoseChips.removeAll()
            // Don't reset hideBetChipsDuringLoseAnimation flag - keep chips hidden
            // The betting manager will handle clearing the actual bet chips
            print("💰 REGULAR MODE LOSE: Animation complete, chips permanently gone")
        }
    }
    
    private func startTrainingModeLoseAnimation() {
        // Use saved chips for lose animation (betChips were cleared to disable Deal Cards button)
        let chipsToAnimate = gameState.savedLoseChips.isEmpty ? gameState.betChips : gameState.savedLoseChips
        guard !chipsToAnimate.isEmpty else { 
            print("💰 TRAINING MODE LOSE: No chips to animate")
            return 
        }
        
        print("💰 TRAINING MODE LOSE: Starting smooth slide animation with \(chipsToAnimate.count) chips")
        
        // TRAINING MODE: Hardcoded lose position - 57 points higher than regular mode
        let baseLoseX: CGFloat = UIScreen.main.bounds.width * 0.5  // Center X
        let baseLoseY: CGFloat = UIScreen.main.bounds.height * 0.75 - 167  // 57 points higher than regular mode
        
        // SPLIT ADJUSTMENT: If user has split hands, offset down by 15 points
        let splitOffset: CGFloat = gameState.isSplit ? 15 : 0
        let loseX = baseLoseX
        let loseY = baseLoseY + splitOffset
        
        print("💰 TRAINING MODE LOSE: isSplit=\(gameState.isSplit), splitOffset=\(splitOffset)")
        print("💰 TRAINING MODE LOSE: loseX=\(loseX), loseY=\(loseY) (base: \(baseLoseY))")
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // Create animation chips that start from betting area
        for (index, chipValue) in chipsToAnimate.enumerated() {
            let angle = Double(index) * 0.8  // Tighter spiral
            let radius: CGFloat = 2.0        // Closer stacking
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            
            let loseChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: CGPoint(
                    x: loseX + xOffset,
                    y: loseY + yOffset
                ),
                opacity: 1.0,
                scale: 1.0
            )
            loseChips.append(loseChip)
        }
        
        // Hide the actual betting chips immediately so only animated chips are visible
        gameState.hideBetChipsDuringLoseAnimation = true
        
        // Smooth slide animation at angle toward dealer (up and to the right)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 TRAINING MODE LOSE: Sliding chips toward dealer at angle")
            withAnimation(.easeOut(duration: 1.0)) {
                for i in 0..<loseChips.count {
                    loseChips[i].position = CGPoint(
                        x: UIScreen.main.bounds.width + 100, // Off-screen to the right
                        y: UIScreen.main.bounds.height * 0.25 // Up toward dealer area
                    )
                    loseChips[i].opacity = 0.0 // Fade out completely
                }
            }
        }
        
        // Clean up after animation and keep chips gone
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            loseChips.removeAll()
            // Clear saved chips after animation completes
            gameState.savedLoseChips.removeAll()
            // Don't reset hideBetChipsDuringLoseAnimation flag - keep chips hidden
            // The betting manager will handle clearing the actual bet chips
            print("💰 TRAINING MODE LOSE: Animation complete, chips permanently gone")
        }
    }
    
    // MARK: - Win Animation (Dealer pays out matching chips) - REGULAR MODE ONLY
    private func startWinAnimation() {
        guard gameState.betChips.count > 0 && gameState.lastPayout > 0 else { return }
        
        print("💰 WIN ANIMATION (REGULAR): Starting payout animation")
        
        // Clear any existing win chips
        winChips.removeAll()
        
        // Create matching chips for the payout
        let dealerPos = getDealerPosition()
        let payoutPos = getRegularModePayoutPosition()
        
        // Create chips that match the user's bet
        // Use the SAME spiral order as BlackjackBettingView: sorted(by: >) for highest value at bottom
        let sortedChips = gameState.betChips.sorted(by: >)
        for (index, chipValue) in sortedChips.enumerated() {
            let winChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: dealerPos,
                opacity: 1.0,
                scale: 1.0
            )
            winChips.append(winChip)
        }
        
        // Animate chips from dealer to betting area (LEFT side of original bet)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in 0..<winChips.count {
                // Use the SAME spiral logic as BlackjackBettingView for perfect alignment
                // This matches: let angle = Double(index) * 0.8, radius = 2.0
                let angle = Double(i) * 0.8  // Tighter spiral
                let radius: CGFloat = 2.0    // Closer stacking
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                // REGULAR MODE: Use the perfect working position from dedicated function
                winChips[i].position = CGPoint(
                    x: payoutPos.x + xOffset, // Use calculated payout position + spiral offset
                    y: payoutPos.y + yOffset // Use calculated payout position + spiral offset
                )
            }
        }
    }
    
    // MARK: - Training Win Animation (Dealer pays out matching chips) - TRAINING MODE ONLY
    private func startTrainingWinAnimation() {
        guard gameState.betChips.count > 0 && gameState.lastPayout > 0 else { return }
        
        print("💰 TRAINING WIN ANIMATION: Starting payout animation")
        
        // Clear any existing win chips
        winChips.removeAll()
        
        // Create matching chips for the payout
        let dealerPos = getDealerPosition()
        let payoutPos = getTrainingModePayoutPosition()
        
        // Create chips that match the user's bet
        // Use the SAME spiral order as BlackjackBettingView: sorted(by: >) for highest value at bottom
        let sortedChips = gameState.betChips.sorted(by: >)
        for (index, chipValue) in sortedChips.enumerated() {
            let winChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: dealerPos,
                opacity: 1.0,
                scale: 1.0
            )
            winChips.append(winChip)
        }
        
        // Animate chips from dealer to betting area (LEFT side of original bet)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in 0..<winChips.count {
                // Use the SAME spiral logic as BlackjackBettingView for perfect alignment
                // This matches: let angle = Double(index) * 0.8, radius = 2.0
                let angle = Double(i) * 0.8  // Tighter spiral
                let radius: CGFloat = 2.0    // Closer stacking
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                // TRAINING MODE: Use dedicated training mode position function
                winChips[i].position = CGPoint(
                    x: payoutPos.x + xOffset, // Use calculated training mode payout position + spiral offset
                    y: payoutPos.y + yOffset // Use calculated training mode payout position + spiral offset
                )
            }
        }
    }
    
    // MARK: - Lose Animation (Smooth slide toward dealer side) - REGULAR MODE ONLY
    private func startLoseAnimation() {
        // Use saved chips for lose animation (betChips were cleared to disable Deal Cards button)
        let chipsToAnimate = gameState.savedLoseChips.isEmpty ? gameState.betChips : gameState.savedLoseChips
        guard !chipsToAnimate.isEmpty else { 
            print("💰 LOSE ANIMATION (REGULAR): No chips to animate")
            return 
        }
        
        print("💰 LOSE ANIMATION (REGULAR): Starting smooth slide animation with \(chipsToAnimate.count) chips")
        
        let losePos = getRegularModeLosePosition()
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // Create animation chips that start from betting area
        for (index, chipValue) in chipsToAnimate.enumerated() {
            let angle = Double(index) * 0.8  // Tighter spiral
            let radius: CGFloat = 2.0        // Closer stacking
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            
            let loseChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: CGPoint(
                    x: losePos.x + xOffset, // Use calculated regular mode lose position + spiral offset
                    y: losePos.y + yOffset // Use calculated regular mode lose position + spiral offset
                ),
                opacity: 1.0,
                scale: 1.0
            )
            loseChips.append(loseChip)
        }
        
        // Hide the actual betting chips immediately so only animated chips are visible
        gameState.hideBetChipsDuringLoseAnimation = true
        
        // Smooth slide animation at angle toward dealer (up and to the right)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 LOSE ANIMATION (REGULAR): Sliding chips toward dealer at angle")
            withAnimation(.easeOut(duration: 1.0)) {
                for i in 0..<loseChips.count {
                    loseChips[i].position = CGPoint(
                        x: UIScreen.main.bounds.width + 100, // Off-screen to the right
                        y: UIScreen.main.bounds.height * 0.25 // Up toward dealer area
                    )
                    loseChips[i].opacity = 0.0 // Fade out completely
                }
            }
        }
        
        // Clean up after animation and keep chips gone
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            loseChips.removeAll()
            // Clear saved chips after animation completes
            gameState.savedLoseChips.removeAll()
            // Don't reset hideBetChipsDuringLoseAnimation flag - keep chips hidden
            // The betting manager will handle clearing the actual bet chips
            print("💰 LOSE ANIMATION (REGULAR): Animation complete, chips permanently gone")
        }
    }
    
    // MARK: - Training Lose Animation (Smooth slide toward dealer side) - TRAINING MODE ONLY
    private func startTrainingLoseAnimation() {
        // Use saved chips for lose animation (betChips were cleared to disable Deal Cards button)
        let chipsToAnimate = gameState.savedLoseChips.isEmpty ? gameState.betChips : gameState.savedLoseChips
        guard !chipsToAnimate.isEmpty else { 
            print("💰 TRAINING LOSE ANIMATION: No chips to animate")
            return 
        }
        
        print("💰 TRAINING LOSE ANIMATION: Starting smooth slide animation with \(chipsToAnimate.count) chips")
        
        let losePos = getTrainingModeLosePosition()
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // Create animation chips that start from betting area
        for (index, chipValue) in chipsToAnimate.enumerated() {
            let angle = Double(index) * 0.8  // Tighter spiral
            let radius: CGFloat = 2.0        // Closer stacking
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            
            let loseChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: CGPoint(
                    x: losePos.x + xOffset, // Use calculated training mode lose position + spiral offset
                    y: losePos.y + yOffset // Use calculated training mode lose position + spiral offset
                ),
                opacity: 1.0,
                scale: 1.0
            )
            loseChips.append(loseChip)
        }
        
        // Hide the actual betting chips immediately so only animated chips are visible
        gameState.hideBetChipsDuringLoseAnimation = true
        
        // Smooth slide animation at angle toward dealer (up and to the right)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 TRAINING LOSE ANIMATION: Sliding chips toward dealer at angle")
            withAnimation(.easeOut(duration: 1.0)) {
                for i in 0..<loseChips.count {
                    loseChips[i].position = CGPoint(
                        x: UIScreen.main.bounds.width + 100, // Off-screen to the right
                        y: UIScreen.main.bounds.height * 0.25 // Up toward dealer area
                    )
                    loseChips[i].opacity = 0.0 // Fade out completely
                }
            }
        }
        
        // Clean up after animation and keep chips gone
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            loseChips.removeAll()
            // Clear saved chips after animation completes
            gameState.savedLoseChips.removeAll()
            // Don't reset hideBetChipsDuringLoseAnimation flag - keep chips hidden
            // The betting manager will handle clearing the actual bet chips
            print("💰 TRAINING LOSE ANIMATION: Animation complete, chips permanently gone")
        }
    }
    
    // MARK: - Win Betting Clear Animation (After win, clear betting area)
    private func startWinBettingClearAnimation() {
        // Clear win chips immediately - betting area should be cleared for new round
        winChips.removeAll()
        
        // No animation needed - just clear the betting area like in real blackjack
        // The game logic will handle clearing the actual bet chips
    }

    // MARK: - Chip Boundary Detection
    private func chipFrame(at position: CGPoint) -> CGRect {
        let chipSize: CGFloat = 44.0
        return CGRect(
            x: position.x - chipSize / 2,
            y: position.y - chipSize / 2,
            width: chipSize,
            height: chipSize
        )
    }
    
    private func chipsOverlap(_ pos1: CGPoint, _ pos2: CGPoint) -> Bool {
        let frame1 = chipFrame(at: pos1)
        let frame2 = chipFrame(at: pos2)
        return frame1.intersects(frame2)
    }
    
    private func findNonOverlappingPosition(
        desiredX: CGFloat,
        y: CGFloat,
        existingPositions: [CGPoint],
        minSpacing: CGFloat = 50.0
    ) -> CGFloat {
        var testX = desiredX
        let chipSize: CGFloat = 44.0
        let halfChip = chipSize / 2
        
        // Check if desired position overlaps with any existing chip
        var attempts = 0
        while attempts < 100 {
            let testPos = CGPoint(x: testX, y: y)
            var overlaps = false
            
            for existingPos in existingPositions {
                if chipsOverlap(testPos, existingPos) {
                    overlaps = true
                    break
                }
            }
            
            if !overlaps {
                return testX
            }
            
            // Shift right by minimum spacing
            testX += minSpacing
            attempts += 1
        }
        
        // Fallback: return position with extra spacing
        return desiredX + minSpacing
    }
    
    /// Clamp a horizontal row so it stays on-screen for small devices.
    private func clampedRowStartX(
        startX: CGFloat,
        count: Int,
        spacing: CGFloat,
        chipSize: CGFloat = 44.0,
        margin: CGFloat = 18
    ) -> CGFloat {
        guard count > 0 else { return startX }
        // Clamp based on the chip centers so rendered edges stay on-screen.
        let totalSpan = spacing * CGFloat(max(count - 1, 0))
        let halfChip = chipSize / 2
        let minStart = margin + halfChip
        let maxStart = UIScreen.main.bounds.width - margin - halfChip - totalSpan
        return min(maxStart, max(minStart, startX))
    }
    
    /// Compute a row start so chips are centered on a desired x while staying on-screen.
    private func rowStartAligned(
        desiredCenter: CGFloat,
        count: Int,
        spacing: CGFloat,
        chipSize: CGFloat = 44.0,
        margin: CGFloat = 18
    ) -> CGFloat {
        guard count > 0 else { return desiredCenter }
        let span = spacing * CGFloat(max(count - 1, 0))
        let start = desiredCenter - span / 2
        return clampedRowStartX(startX: start, count: count, spacing: spacing, chipSize: chipSize, margin: margin)
    }

    /// Compute starts for two horizontal rows (left/right) so they stay on-screen with a gap.
    private func payoutRowStarts(
        leftCount: Int,
        rightCount: Int,
        spacing: CGFloat,
        chipSize: CGFloat = 44.0,
        margin: CGFloat = 18.0,
        minGap: CGFloat = 12.0
    ) -> (leftStart: CGFloat, rightStart: CGFloat) {
        let screen = UIScreen.main.bounds.width
        let leftWidth = leftCount > 0 ? chipSize + spacing * CGFloat(max(leftCount - 1, 0)) : 0
        let rightWidth = rightCount > 0 ? chipSize + spacing * CGFloat(max(rightCount - 1, 0)) : 0
        
        // Ideal gap is whatever space remains after margins; enforce minimum.
        var gap = max(minGap, screen - 2 * margin - leftWidth - rightWidth)
        // If total exceeds available, shrink gap until it fits.
        let available = screen - 2 * margin
        let totalNeeded = leftWidth + rightWidth + gap
        if totalNeeded > available {
            gap = max(0, gap - (totalNeeded - available))
        }
        
        let totalSpan = leftWidth + rightWidth + gap
        let leftStart = max(margin, (screen - totalSpan) / 2)
        let rightStart = min(screen - margin - rightWidth, leftStart + leftWidth + gap)
        
        return (leftStart, rightStart)
    }
    
    // MARK: - Auto Collect Winnings Animation (bet + winnings back to chip selection)
    private func startAutoCollectWinningsAnimation() {
        print("💰 AUTO-COLLECT: Animating bet and winnings back to chip selection")
        gameState.isAutoCollectingWinnings = true
        
        // Use chip selection as the target; fallback to bottom-center if missing
        let targetPos = getChipSelectionPosition() != .zero
            ? getChipSelectionPosition()
            : CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.9)
        
        // Build a list of on-table stacks to animate (bet + additional + DD)
        var tableChips: [AnimatedChip] = []
        
        // Include main bet chips (approximate their current on-table positions)
        if !gameState.betChips.isEmpty {
            let centerX = UIScreen.main.bounds.width * 0.5
            let baseY = gameState.isTrainingMode
                ? UIScreen.main.bounds.height * 0.7 - 30 - 88 + 50
                : UIScreen.main.bounds.height * 0.75
            for (index, chipValue) in gameState.betChips.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                tableChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: centerX - 52.5 + xOffset, y: baseY + yOffset),
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
        }
        
        // Include additional/right stack chips
        if !gameState.additionalBetChips.isEmpty {
            let centerX = UIScreen.main.bounds.width * 0.5
            let baseY = gameState.isTrainingMode
                ? UIScreen.main.bounds.height * 0.7 - 30 - 88 + 50
                : UIScreen.main.bounds.height * 0.75
            for (index, chipValue) in gameState.additionalBetChips.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                tableChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: centerX + 97.5 + xOffset, y: baseY + yOffset),
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
        }
        
        // Include double-down stacks if present
        if !gameState.doubleDownChipsHand2.isEmpty {
            let centerX = UIScreen.main.bounds.width * 0.5
            let baseY = gameState.isTrainingMode
                ? UIScreen.main.bounds.height * 0.7 - 30 - 88 + 50
                : UIScreen.main.bounds.height * 0.75
            // Calculate position to match TrainingModeView's hand2DDXOffset calculation
            // Hand 2 double down chips: Position to the LEFT of bet chips (44 points to the left, touching)
            // Bet chips are at -70.0, so DD chips at -70.0 - 44.0 = -114.0
            // When payout chips are present, betting chips are offset right by 2 chip widths
            let hand2Won = gameState.resultMessage?.contains("Hand 2: Win") == true
            let h2PayoutShift: CGFloat = hand2Won ? 184.0 : 0.0
            let hasPayoutChips = gameState.lastPayout > 0 && gameState.showResultNotification
            let chipSpacing: CGFloat = 45.0 // chipSize (44) + 1
            // When payout chips are present, the on-table stacks shift right by 36pt (TrainingModeView),
            // plus a small inter-hand gap tweak to match the Figma mock.
            let payoutOffset: CGFloat = hasPayoutChips ? 36.0 : 0.0
            let hand2GroupTweak: CGFloat = hasPayoutChips ? -1.0 : 0.0
            let hand1GroupTweak: CGFloat = hasPayoutChips ? 7.0 : 0.0
            let hand2DDXOffset: CGFloat = gameState.isSplit ? 
                (-114.0 + h2PayoutShift + payoutOffset) : 0.0
            for (index, chipValue) in gameState.doubleDownChipsHand2.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                tableChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: centerX + hand2DDXOffset + xOffset, y: baseY + yOffset),
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
        }
        
        if !gameState.doubleDownChipsHand1.isEmpty {
            let centerX = UIScreen.main.bounds.width * 0.5
            let baseY = gameState.isTrainingMode
                ? UIScreen.main.bounds.height * 0.7 - 30 - 88 + 50
                : UIScreen.main.bounds.height * 0.75
            for (index, chipValue) in gameState.doubleDownChipsHand1.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                tableChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: centerX + 57.5 + xOffset, y: baseY + yOffset),
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
        }
        
        // Animate both winnings (winChips) and table chips together toward target
        let animationDuration = 0.6
        
        // If nothing to animate, end immediately (prevents Return Bet being hidden too long)
        if winChips.isEmpty && tableChips.isEmpty {
            gameState.isAutoCollectingWinnings = false
            return
        }
        
        // Animate existing winChips (winnings)
        withAnimation(.easeInOut(duration: animationDuration)) {
            for i in 0..<winChips.count {
                winChips[i].position = targetPos
                winChips[i].opacity = 0.0
                winChips[i].scale = 0.6
            }
        }
        
        // Use loseChips to animate the table stacks
        loseChips = tableChips
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            for i in 0..<loseChips.count {
                loseChips[i].position = targetPos
                loseChips[i].opacity = 0.0
                loseChips[i].scale = 0.6
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.1) {
            winChips.removeAll()
            loseChips.removeAll()
            gameState.isAutoCollectingWinnings = false
        }
    }
    
    // MARK: - Push Chips Return Animation (After push, return bet chips to selection)
    func startPushChipsReturnAnimation() {
        print("💰 PUSH RETURN: Starting push chip return animation")
        
        let chipSelectionPos = getChipSelectionPosition()
        let trainingModeEnabled = gameState.isTrainingMode
        let centerX: CGFloat = UIScreen.main.bounds.width * 0.5
        let baseY: CGFloat = trainingModeEnabled ? 
            UIScreen.main.bounds.height * 0.7 - 30 - 88 + 50 :
            UIScreen.main.bounds.height * 0.75
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // For split hands, animate all remaining chips back
        if gameState.isSplit {
            print("💰 PUSH RETURN SPLIT: Animating split hand chips back")
            
            // Animate betChips (Hand 2, left) if they exist
            if !gameState.betChips.isEmpty {
                for (index, chipValue) in gameState.betChips.enumerated() {
                    let angle = Double(index) * 0.8
                    let radius: CGFloat = 2.0
                    let xOffset = radius * cos(angle)
                    let yOffset = radius * sin(angle)
                    
                    loseChips.append(AnimatedChip(
                        id: UUID(),
                        value: chipValue,
                        position: CGPoint(x: centerX - 52.5 + xOffset, y: baseY + yOffset),  // Bet at -52.5
                        opacity: 1.0,
                        scale: 1.0
                    ))
                }
            }
            
            // Animate doubleDownChipsHand2 if they exist
            if !gameState.doubleDownChipsHand2.isEmpty {
                for (index, chipValue) in gameState.doubleDownChipsHand2.enumerated() {
                    let angle = Double(index) * 0.8
                    let radius: CGFloat = 2.0
                    let xOffset = radius * cos(angle)
                    let yOffset = radius * sin(angle)
                    
                    loseChips.append(AnimatedChip(
                        id: UUID(),
                        value: chipValue,
                        position: CGPoint(x: centerX - 92.5 + xOffset, y: baseY + yOffset),  // DD at -92.5
                        opacity: 1.0,
                        scale: 1.0
                    ))
                }
            }
            
            // Animate additionalBetChips (Hand 1, right) if they exist
            if !gameState.additionalBetChips.isEmpty {
                for (index, chipValue) in gameState.additionalBetChips.enumerated() {
                    let angle = Double(index) * 0.8
                    let radius: CGFloat = 2.0
                    let xOffset = radius * cos(angle)
                    let yOffset = radius * sin(angle)
                    
                    loseChips.append(AnimatedChip(
                        id: UUID(),
                        value: chipValue,
                        position: CGPoint(x: centerX + 97.5 + xOffset, y: baseY + yOffset),  // Bet at +97.5 (normal position)
                        opacity: 1.0,
                        scale: 1.0
                    ))
                }
            }
            
            // Animate doubleDownChipsHand1 if they exist
            if !gameState.doubleDownChipsHand1.isEmpty {
                for (index, chipValue) in gameState.doubleDownChipsHand1.enumerated() {
                    let angle = Double(index) * 0.8
                    let radius: CGFloat = 2.0
                    let xOffset = radius * cos(angle)
                    let yOffset = radius * sin(angle)
                    
                    loseChips.append(AnimatedChip(
                        id: UUID(),
                        value: chipValue,
                        position: CGPoint(x: centerX + 52.5 + xOffset, y: baseY + yOffset),  // DD at +52.5 (normal position)
                        opacity: 1.0,
                        scale: 1.0
                    ))
                }
            }
        } else {
            // Regular (non-split) push - animate betChips only
            print("💰 PUSH RETURN REGULAR: Animating regular hand chips back")
            let bettingPos = trainingModeEnabled ? getTrainingModeBettingPosition() : getRegularModeBettingPosition()
            
            for (index, chipValue) in gameState.betChips.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                loseChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: bettingPos.x + xOffset, y: bettingPos.y + yOffset),
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
        }
        
        // Hide actual chips immediately
        gameState.hideBetChipsDuringLoseAnimation = true
        
        // Animate chips to chip selection area
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 PUSH RETURN: Animating \(loseChips.count) chips to selection")
            withAnimation(.easeInOut(duration: 0.6)) {
                for i in 0..<loseChips.count {
                    loseChips[i].position = chipSelectionPos
                    loseChips[i].opacity = 0.0
                }
            }
        }
        
        // Clean up and clear all chip arrays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            loseChips.removeAll()
            gameState.betChips.removeAll()
            gameState.additionalBetChips.removeAll()
            gameState.doubleDownChipsHand2.removeAll()
            gameState.doubleDownChipsHand1.removeAll()
            gameState.hideBetChipsDuringLoseAnimation = false
            print("💰 PUSH RETURN: Animation complete, all chips cleared")
        }
    }
    
    // MARK: - Position Helpers
    private func getDealerPosition() -> CGPoint {
        return CGPoint(
            x: UIScreen.main.bounds.width * 0.5,
            y: UIScreen.main.bounds.height * 0.3 // Dealer area
        )
    }
    
    // MARK: - Mode-Specific Position Functions
    private func getRegularModeBettingPosition() -> CGPoint {
        // Prefer the captured on-table chip row position for accurate animations.
        if gameState.bettingAreaPosition != .zero {
            return gameState.bettingAreaPosition
        }
        return CGPoint(x: UIScreen.main.bounds.width * 0.5, y: UIScreen.main.bounds.height * 0.75)
    }
    
    private func getTrainingModeBettingPosition() -> CGPoint {
        // Training Mode: Use calculated chipsY directly (screen coordinate).
        // The overlay will convert this correctly using its frame offset.
        let calculatedY = UIScreen.main.bounds.height * 0.7 - 30 - 88 + 50
        let calculatedPos = CGPoint(x: UIScreen.main.bounds.width * 0.5, y: calculatedY)
        print("💰 TRAINING MODE: Using calculated position: \(calculatedPos)")
        return calculatedPos
    }
    
    private func getRegularModePayoutPosition() -> CGPoint {
        let betting = getRegularModeBettingPosition()
        let position = CGPoint(
            x: betting.x - 60, // Left of betting area
            y: betting.y - 110 // Above betting area (perfect regular mode position)
        )
        print("🔍 REGULAR PAYOUT POSITION: x=\(position.x), y=\(position.y)")
        print("🔍 REGULAR BETTING POSITION: x=\(betting.x), y=\(betting.y)")
        return position
    }
    
    private func getTrainingModePayoutPosition() -> CGPoint {
        // Position payout chips directly in the betting area, to the left of the bet chips
        let position = CGPoint(
            x: UIScreen.main.bounds.width * 0.5 - 50, // 50 points left of center (next to bet chip)
            y: UIScreen.main.bounds.height * 0.75 + 15 // Slightly below the "Bet: $200" text
        )
        print("🔍 TRAINING PAYOUT POSITION: x=\(position.x), y=\(position.y)")
        return position
    }
    
    private func getRegularModeLosePosition() -> CGPoint {
        let betting = getRegularModeBettingPosition()
        return CGPoint(
            x: betting.x, // Same X as betting area
            y: betting.y - 110 // Above betting area (perfect regular mode position)
        )
    }
    
    private func getTrainingModeLosePosition() -> CGPoint {
        let betting = getTrainingModeBettingPosition()
        return CGPoint(
            x: betting.x, // Same X as betting area
            y: betting.y - 110 // Above betting area (training mode adjusted)
        )
    }
    
    private func getChipSelectionPosition() -> CGPoint {
        // Prefer captured chip selection center when available.
        if gameState.chipSelectionAreaPosition != .zero {
            return gameState.chipSelectionAreaPosition
        }
        return CGPoint(x: UIScreen.main.bounds.width * 0.5, y: UIScreen.main.bounds.height * 0.88)
    }
    
    // MARK: - Dual Stack Results Detection and Handling
    private func handleDualStackResults(resultMessage: String, trainingModeEnabled: Bool) {
        print("🎯 DUAL STACK: Analyzing results for dual stack scenario")
        print("🎯 DUAL STACK: Main chips: \(gameState.betChips), Additional chips: \(gameState.additionalBetChips)")
        print("🎯 DUAL STACK: Result message: \(resultMessage)")
        print("🎯 DUAL STACK: lastPayout=\(gameState.lastPayout), playerBet=\(gameState.playerBet)")
        
        if gameState.isSplit {
            // For splits, analyze individual hand results
            let splitResults = analyzeSplitResults(resultMessage: resultMessage)
            let losingHands = getLosingSplitHands(resultMessage: resultMessage)
            let pushedHands = getPushedSplitHands(resultMessage: resultMessage)
            
            print("🎯 SPLIT ANALYSIS: \(splitResults)")
            print("🎯 SPLIT DETAILS: Losing=\(losingHands), Pushed=\(pushedHands)")
            
            if splitResults.hasWin && splitResults.hasLose {
                // MIXED SPLIT: Win one, lose one
                // Step 1: Animate losing hands away FIRST
                print("🎯 DUAL STACK MIXED: Animating losing hands away first, then payout")
                animateLosingSplitHands(losingHands: losingHands, trainingModeEnabled: trainingModeEnabled) {
                    // Step 2: After losing chips are removed, pay out winning hands
                    print("🎯 DUAL STACK MIXED: Losing hands removed, now paying out winning hands")
                    self.startDualStackWinAnimation(trainingModeEnabled: trainingModeEnabled)
                }
            } else if splitResults.hasWin && !splitResults.hasLose {
                // WIN ALL NON-PUSH HANDS: Only wins and/or pushes
                print("🎯 DUAL STACK WIN: Starting payout animations (wins only, no pushes)")
                startDualStackWinAnimation(trainingModeEnabled: trainingModeEnabled)
            } else if splitResults.hasLose && !splitResults.hasWin {
                // LOSE ALL NON-PUSH HANDS: Only losses and/or pushes
                print("🎯 DUAL STACK LOSE: Starting lose animation (losses only)")
                animateLosingSplitHands(losingHands: losingHands, trainingModeEnabled: trainingModeEnabled)
            } else {
                // ALL PUSHES: No animation needed, chips stay visible
                print("🎯 DUAL STACK PUSH: All hands pushed, chips stay visible until card collection")
            }
        } else {
            // For double down, use robust payout logic
            print("🎯 DUAL STACK DOUBLE DOWN: Analyzing payout logic")
            
            if gameState.lastPayout > 0 {
                // WIN: Positive payout (could be full win or partial win)
                print("🎯 DUAL STACK WIN: Starting dual payout animations (lastPayout > 0)")
                startDualStackWinAnimation(trainingModeEnabled: trainingModeEnabled)
            } else if gameState.lastPayout < 0 {
                // LOSE: Negative payout
                print("🎯 DUAL STACK LOSE: Starting dual lose animation (lastPayout < 0)")
                startDualStackLoseAnimation(trainingModeEnabled: trainingModeEnabled)
            } else {
                // PUSH: Zero payout - no animation, money returned
                print("🎯 DUAL STACK PUSH: Double down/split pushed, no animation - money returned")
                // Push = no animation, chips stay with player (money back)
            }
        }
    }
    
    private func analyzeSplitResults(resultMessage: String) -> (hasWin: Bool, hasLose: Bool, hasPush: Bool) {
        let lines = resultMessage.components(separatedBy: "\n").filter { !$0.isEmpty }
        var hasWin = false
        var hasLose = false
        var hasPush = false
        
        for line in lines {
            if line.contains("Win!") || line.contains("21!") {
                hasWin = true
            } else if line.contains("Lose.") || line.contains("Bust!") {
                hasLose = true
            } else if line.contains("Push.") {
                hasPush = true
            }
        }
        
        print("🎯 SPLIT RESULTS: Win=\(hasWin), Lose=\(hasLose), Push=\(hasPush)")
        return (hasWin: hasWin, hasLose: hasLose, hasPush: hasPush)
    }
    
    // Parse which specific hands won in a split scenario
    private func getWinningSplitHands(resultMessage: String) -> Set<Int> {
        var winningHands: Set<Int> = []
        let lines = resultMessage.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            // Parse "Hand 1: Win!" or "Hand 2: Win!" or "Hand 1: 21!" etc.
            if line.contains("Hand 1:") && (line.contains("Win") || line.contains("21") || line.contains("Blackjack")) {
                winningHands.insert(1) // Hand 1 (index 1 in splitHands)
            } else if line.contains("Hand 2:") && (line.contains("Win") || line.contains("21") || line.contains("Blackjack")) {
                winningHands.insert(0) // Hand 2 (index 0 in splitHands)
            }
        }
        
        print("🎯 WINNING HANDS: \(winningHands)")
        return winningHands
    }
    
    // Parse which specific hands pushed in a split scenario
    private func getPushedSplitHands(resultMessage: String) -> Set<Int> {
        var pushedHands: Set<Int> = []
        let lines = resultMessage.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            // Parse "Hand 1: Push." or "Hand 2: Push."
            if line.contains("Hand 1:") && line.contains("Push.") {
                pushedHands.insert(1) // Hand 1 (index 1 in splitHands)
            } else if line.contains("Hand 2:") && line.contains("Push.") {
                pushedHands.insert(0) // Hand 2 (index 0 in splitHands)
            }
        }
        
        print("🎯 PUSHED HANDS: \(pushedHands)")
        return pushedHands
    }
    
    // Parse which specific hands lost in a split scenario
    private func getLosingSplitHands(resultMessage: String) -> Set<Int> {
        var losingHands: Set<Int> = []
        let lines = resultMessage.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            // Parse "Hand 1: Lose." or "Hand 2: Bust!" etc.
            if line.contains("Hand 1:") && (line.contains("Lose.") || line.contains("Bust!")) {
                losingHands.insert(1) // Hand 1 (index 1 in splitHands)
            } else if line.contains("Hand 2:") && (line.contains("Lose.") || line.contains("Bust!")) {
                losingHands.insert(0) // Hand 2 (index 0 in splitHands)
            }
        }
        
        print("🎯 LOSING HANDS: \(losingHands)")
        return losingHands
    }
    
    private func hasMixedSplitResults(resultMessage: String) -> Bool {
        let lines = resultMessage.components(separatedBy: "\n").filter { !$0.isEmpty }
        var hasWin = false
        var hasLose = false
        
        for line in lines {
            if line.contains("Win!") || line.contains("21!") {
                hasWin = true
            } else if line.contains("Lose.") || line.contains("Bust!") {
                hasLose = true
            }
            // Push doesn't count as win or lose for mixed results
        }
        
        let isMixed = hasWin && hasLose
        print("🎯 MIXED SPLIT CHECK: hasWin=\(hasWin), hasLose=\(hasLose), isMixed=\(isMixed)")
        return isMixed
    }
    
    // MARK: - Dual Stack Win Animation (Only animate actual wins, not pushes)
    private func startDualStackWinAnimation(trainingModeEnabled: Bool) {
        print("💰 DUAL STACK WIN: Starting payout animations (wins only, no pushes)")
        
        // Clear any existing win chips
        winChips.removeAll()
        
        let dealerPos = getDealerPosition()
        
        // Use captured betting area position for accurate Y alignment (works for both modes).
        // Both modes now use GeometryReader to capture the actual global position.
        let bettingPos = trainingModeEnabled ? getTrainingModeBettingPosition() : getRegularModeBettingPosition()
        let payoutY = bettingPos.y
        print("💰 DUAL STACK WIN: trainingModeEnabled=\(trainingModeEnabled), bettingPos=\(bettingPos), payoutY=\(payoutY)")
        
        // Compute payout X positions depending on scenario
        let centerX: CGFloat = UIScreen.main.bounds.width * 0.5
        
        // CASINO-STYLE LAYOUT (DD always LEFT of bet, payouts LEFT of user chips, 50pt spacing):
        // Hand 2 center: -80, Hand 1 center: +80
        // User chips: DD2 at -105 (LEFT), Bet2 at -55 (RIGHT), DD1 at +55 (LEFT), Bet1 at +105 (RIGHT)
        // Payouts: 50pt to the LEFT of leftmost user chip (keeps a clean gap)
        // Layout: [PayoutDD2] [PayoutBet2] [DD2] [Bet2] ..gap.. [DD1] [Bet1] [PayoutBet1] [PayoutDD1]
        //         -205        -155         -105   -55              +55   +105   +5          +55
        
        // For split: Use casino-style positions centered under Hand 1 and Hand 2
        // For double down (non-split): keep previous layout (main at center-60, additional at center-120)
        let currentPayoutX: CGFloat = (trainingModeEnabled && gameState.isSplit) ? (centerX - 155) : (centerX - 60)
        let leftPayoutX: CGFloat = {
            if trainingModeEnabled && gameState.isSplit {
                // Check which hand was doubled down
                if let doubledHand = gameState.doubledDownHandIndex {
                    // Hand 0 (Hand 2, left) doubled: doubleDown chips at center-97.5, payout at center-187.5
                    // Hand 1 (Hand 1, right) doubled: doubleDown chips at center+52.5, payout at center+7.5
                    return doubledHand == 0 ? (centerX - 205) : (centerX + 5)
                } else {
                    // Just split, no double down: payout for Hand 1 bet at center+7.5
                    return centerX + 5
                }
            } else {
                // Regular double down: payout at center-120
                return currentPayoutX - 60
            }
        }()
        
        print("💰 DUAL STACK WIN: Current payout at x=\(currentPayoutX), Left payout at x=\(leftPayoutX), y=\(payoutY)")
        print("💰 DUAL STACK WIN: Training mode: \(trainingModeEnabled), Split: \(gameState.isSplit)")
        print("💰 DUAL STACK WIN: bettingPos=\(bettingPos), payoutY=\(payoutY), bettingAreaPosition=\(gameState.bettingAreaPosition)")
        
        // For splits (both Training and Regular), only animate payouts for winning hands.
        if gameState.isSplit, let resultMessage = gameState.resultMessage {
            let winningHands = getWinningSplitHands(resultMessage: resultMessage)
            
            // Hand 2 (index 0) is in betChips (left stack)
            // Hand 1 (index 1) is in additionalBetChips (right stack)
            let hand2WonParsed = winningHands.contains(0)
            let hand1WonParsed = winningHands.contains(1)
            
            print("💰 SPLIT PAYOUT: Hand 1 won: \(hand1WonParsed), Hand 2 won: \(hand2WonParsed)")
            print("💰 SPLIT PAYOUT: betChips=\(gameState.betChips.count), doubleDownChipsHand2=\(gameState.doubleDownChipsHand2.count)")
            print("💰 SPLIT PAYOUT: additionalBetChips=\(gameState.additionalBetChips.count), doubleDownChipsHand1=\(gameState.doubleDownChipsHand1.count)")
            
            // Only create payout animations for winning hands.
            // Split-only: 1 payout chip per winning hand.
            // Split + (per-hand) double-down: 2 payout chips for that doubled hand.
            if hand2WonParsed {
                let isHand2Doubled = !gameState.doubleDownChipsHand2.isEmpty
                let payoutCount = isHand2Doubled ? 2 : 1
                
                let doubleDownChips2 = gameState.doubleDownChipsHand2.sorted(by: >)
                let mainStackChips = gameState.betChips.sorted(by: >)
                let source = isHand2Doubled ? (doubleDownChips2 + mainStackChips) : mainStackChips
                
                for chipValue in source.prefix(payoutCount) {
                    winChips.append(AnimatedChip(
                        id: UUID(),
                        value: chipValue,
                        position: dealerPos,
                        opacity: 1.0,
                        scale: 1.0
                    ))
                }
            }
            
            if hand1WonParsed {
                let isHand1Doubled = !gameState.doubleDownChipsHand1.isEmpty
                let payoutCount = isHand1Doubled ? 2 : 1
                
                let doubleDownChips1 = gameState.doubleDownChipsHand1.sorted(by: >)
                let additionalStackChips = gameState.additionalBetChips.sorted(by: >)
                let source = isHand1Doubled ? (doubleDownChips1 + additionalStackChips) : additionalStackChips
                
                print("💰 SPLIT PAYOUT Hand 1: Creating \(payoutCount) payout chip(s)")
                for chipValue in source.prefix(payoutCount) {
                    winChips.append(AnimatedChip(
                        id: UUID(),
                        value: chipValue,
                        position: dealerPos,
                        opacity: 1.0,
                        scale: 1.0
                    ))
                }
            }
            
            // Animate chips to payout positions
            let hand2WonForAnimation = hand2WonParsed
            let hand1WonForAnimation = hand1WonParsed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Precompute sorted chip stacks for both hands
                let mainStackChips = gameState.betChips.sorted(by: >)
                let additionalStackChips = gameState.additionalBetChips.sorted(by: >)
                let doubleDownChips2 = gameState.doubleDownChipsHand2.sorted(by: >)
                let doubleDownChips1 = gameState.doubleDownChipsHand1.sorted(by: >)
                
                var chipIndex = 0
                // Shared layout constants for clean horizontal rows (chip asset is 44x44)
                let chipSize: CGFloat = 44.0
                let chipSpacing: CGFloat = chipSize + 1.0 // 45pt: touch without gaps, stay on-screen
                // Use captured betting position for accurate Y alignment (same as non-split)
                var bettingPosForSplit = trainingModeEnabled ? getTrainingModeBettingPosition() : getRegularModeBettingPosition()
                
                // TRAINING MODE FIX: For split scenarios, shift payout chips down to align with betting chips
                if trainingModeEnabled {
                    // Add offset to shift chips down to match where betting chips are rendered
                    bettingPosForSplit = CGPoint(x: bettingPosForSplit.x, y: bettingPosForSplit.y + 97) // Shift down 97 points to align with betting chips
                    print("💰 SPLIT PAYOUT (Training): Adjusted Y position down by 97pt: \(bettingPosForSplit)")
                }
                
                let baseY = bettingPosForSplit.y
                print("💰 SPLIT PAYOUT: trainingModeEnabled=\(trainingModeEnabled), bettingPosForSplit=\(bettingPosForSplit), baseY=\(baseY)")
                
                print("\n")
                print("🎯 ╔═══════════════════════════════════════════════╗")
                print("🎯 ║           PAYOUT ROUND START                  ║")
                print("🎯 ╚═══════════════════════════════════════════════╝")
                
                // IMPORTANT: Use the same parsed win flags we used when creating `winChips`,
                // otherwise we can index past the end of `winChips` (crash), especially in split-only.
                let hand2Won = hand2WonForAnimation
                let hand1Won = hand1WonForAnimation
                
                // Payout placement: keep existing stacks where they are, but they shift +7pt right while payout shows.
                // Place 2 payout chips directly to the LEFT of each hand’s leftmost on-table stack (touching).
                let hand2Doubled = !doubleDownChips2.isEmpty
                let hand1Doubled = !doubleDownChips1.isEmpty
                // IMPORTANT: The on-table stacks do not shift based on win/loss.
                // We only nudge stacks +7pt while payout chips are shown.
                let h2PayoutShift: CGFloat = 0.0
                let h1PayoutShift: CGFloat = 0.0
                let payoutOffset: CGFloat = 36.0
                let hand2GroupTweak: CGFloat = -1.0
                let hand1GroupTweak: CGFloat = 7.0
                
                // On-table stack X positions (match TrainingModeView offsets)
                let h2BetX = centerX + (-70.0 + h2PayoutShift + payoutOffset + hand2GroupTweak)
                let h2DDX = centerX + (-114.0 + h2PayoutShift + payoutOffset + hand2GroupTweak) // only valid when doubled
                let h2LeftmostStackX = hand2Doubled ? min(h2BetX, h2DDX) : h2BetX
                
                let h1BetX = centerX + (70.0 + h1PayoutShift + (hand1Doubled ? 10.0 : 0.0) + payoutOffset + hand1GroupTweak)
                let h1DDX = centerX + (hand1Doubled ? (80.0 + h1PayoutShift + 45.0 + payoutOffset + hand1GroupTweak) : (30.0 + h1PayoutShift + payoutOffset + hand1GroupTweak))
                let h1LeftmostStackX = hand1Doubled ? min(h1BetX, h1DDX) : h1BetX
                
                // Animate Hand 2 payout if it won - 1 chip (split-only) or 2 chips (if that hand was doubled),
                // placed immediately left of the leftmost stack (touching).
                if hand2Won {
                    let hasH2DD = !doubleDownChips2.isEmpty
                    let payoutCount = hasH2DD ? 2 : 1
                    let hand2PayoutStartX = h2LeftmostStackX - (chipSpacing * CGFloat(payoutCount))
                    let clampedStart = clampedRowStartX(startX: hand2PayoutStartX, count: payoutCount, spacing: chipSpacing, chipSize: chipSize)
                    print("🎯 HAND 2 PAYOUT POSITIONING (hasDD=\(hasH2DD), leftmostStackX=\(h2LeftmostStackX), payoutStartX=\(clampedStart), count=\(payoutCount)):")
                    
                    for i in 0..<payoutCount {
                        guard chipIndex < winChips.count else { break }
                        let xPos = clampedStart + CGFloat(i) * chipSpacing
                        winChips[chipIndex].position = CGPoint(x: xPos, y: baseY) // Use baseY (adjusted for Training Mode) instead of payoutY
                        chipIndex += 1
                    }
                }
                
                // Animate Hand 1 payout if it won - 1 chip (split-only) or 2 chips (if that hand was doubled),
                // placed immediately left of the leftmost stack (touching).
                if hand1Won {
                    let hasH1DD = !doubleDownChips1.isEmpty
                    let payoutCount = hasH1DD ? 2 : 1
                    let hand1PayoutStartX = h1LeftmostStackX - (chipSpacing * CGFloat(payoutCount))
                    let clampedStart = clampedRowStartX(startX: hand1PayoutStartX, count: payoutCount, spacing: chipSpacing, chipSize: chipSize)
                    print("🎯 HAND 1 PAYOUT POSITIONING (hasDD=\(hasH1DD), leftmostStackX=\(h1LeftmostStackX), payoutStartX=\(clampedStart), count=\(payoutCount)):")
                    
                    for i in 0..<payoutCount {
                        guard chipIndex < winChips.count else { break }
                        let xPos = clampedStart + CGFloat(i) * chipSpacing
                        winChips[chipIndex].position = CGPoint(x: xPos, y: baseY) // Use baseY (adjusted for Training Mode) instead of payoutY
                        chipIndex += 1
                    }
                }
                
                print("🎯 ╔═══════════════════════════════════════════════╗")
                print("🎯 ║           PAYOUT ROUND END                    ║")
                print("🎯 ╚═══════════════════════════════════════════════╝")
                print("\n")
                
                // Split payout animation complete
            }
        } else {
            // Non-split dual-stack payout (double-down)
            let mainStackChips = gameState.betChips.sorted(by: >)
            let additionalStackChips = gameState.additionalBetChips.sorted(by: >)
            let doubleDownChips2 = gameState.doubleDownChipsHand2.sorted(by: >)
            let doubleDownChips1 = gameState.doubleDownChipsHand1.sorted(by: >)
            
            print("💰 DUAL STACK WIN: Main stack chips: \(mainStackChips), Additional stack chips: \(additionalStackChips), DD2: \(doubleDownChips2), DD1: \(doubleDownChips1)")
            
            // Non-split: always pay 2 chips on a double-down win (matches existing visuals).
            let hand2Count = 0
            let hand1Count = 0
            let hand2Payout: [Int] = []
            let hand1Payout: [Int] = []
            
            winChips.removeAll()
            // Create chips for non-split using the existing non-split win logic below.
            // (Keep this branch minimal to avoid mixed split crashes.)
            if !gameState.isSplit {
                // Non-split double-down: always animate TWO payout chips (one per on-table stack),
                // even if each stack only has one chip.
                let payoutChips = Array((additionalStackChips + mainStackChips).prefix(2))
                for chipValue in payoutChips {
                winChips.append(AnimatedChip(id: UUID(), value: chipValue, position: dealerPos, opacity: 1.0, scale: 1.0))
            }
            }
            
            // Animate chips to positions to the left of each hand's bet chips
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let chipSize: CGFloat = 44.0
                let chipSpacing: CGFloat = chipSize + 1.0 // 45pt: touching
                
                // Non-split double-down: render a 4-chip horizontal row centered under the title:
                // [payout][payout][DD][BET] all touching.
                let payoutCount = 2
                let userStackCount = 2
                let totalCount = payoutCount + userStackCount
                
                // Both modes: Use captured bettingAreaPosition for accurate alignment.
                // Both modes: Use captured bettingAreaPosition for accurate alignment.
                // Both now use GeometryReader to capture actual global position.
                var bettingPos = trainingModeEnabled ? getTrainingModeBettingPosition() : getRegularModeBettingPosition()
                
                // TRAINING MODE FIX: For non-split double-down, shift payout chips down to align with betting chips
                if trainingModeEnabled && !gameState.isSplit {
                    // Add offset to shift chips down to match where betting chips are rendered
                    // chipsY calculation: UIScreen.main.bounds.height * 0.7 - 30 - 88 + 50
                    // The calculated position might be too high, so add a downward offset
                    bettingPos = CGPoint(x: bettingPos.x, y: bettingPos.y + 97) // Shift down 97 points to align with betting chips
                    print("💰 NON-SPLIT DD PAYOUT (Training): Adjusted Y position down by 97pt: \(bettingPos)")
                }
                
                print("💰 NON-SPLIT DD PAYOUT: trainingModeEnabled=\(trainingModeEnabled), bettingPos=\(bettingPos)")
                
                let rowStart = centerX - chipSpacing * CGFloat(max(totalCount - 1, 0)) / 2.0
                let clampedStart = clampedRowStartX(startX: rowStart, count: totalCount, spacing: chipSpacing, chipSize: chipSize)
                
                // Payout chips occupy the first two slots of the row.
                for i in 0..<min(payoutCount, winChips.count) {
                    let xPos = clampedStart + CGFloat(i) * chipSpacing
                    winChips[i].position = CGPoint(x: xPos, y: bettingPos.y)
                    print("💰 NON-SPLIT DD PAYOUT: Chip \(i) at x=\(xPos), y=\(bettingPos.y)")
                }
            }
        }
    }
    
    // MARK: - Dual Stack Lose Animation (Both stacks lose)
    private func startDualStackLoseAnimation(trainingModeEnabled: Bool) {
        print("💰 DUAL STACK LOSE: Starting dual lose animation")
        print("💰 DUAL STACK LOSE: Main chips count: \(gameState.betChips.count), Additional chips count: \(gameState.additionalBetChips.count)")
        print("💰 DUAL STACK LOSE: Training mode: \(trainingModeEnabled), Split: \(gameState.isSplit)")
        
        // Guard: Ensure we have chips to animate
        guard !gameState.betChips.isEmpty || !gameState.additionalBetChips.isEmpty else {
            print("💰 DUAL STACK LOSE: No chips to animate - both stacks are empty")
            return
        }
        
        // Calculate base positions
        let baseLoseY: CGFloat = trainingModeEnabled ? 
            UIScreen.main.bounds.height * 0.75 - 167 :  // Training mode
            UIScreen.main.bounds.height * 0.75 - 110     // Regular mode
        
        // Apply split offset for training mode
        let splitOffset: CGFloat = (trainingModeEnabled && gameState.isSplit) ? 15 : 0
        let loseY = baseLoseY + splitOffset
        
        // Main stack position:
        // - Split: main bet stack is centered under left hand area in the existing animation system
        // - Non-split double-down: main bet stack is the RIGHT stack in the centered pair (+22.5)
        let chipSpacing: CGFloat = 45.0
        let mainStackX: CGFloat = UIScreen.main.bounds.width * 0.5 + (gameState.isSplit ? 0 : (chipSpacing / 2.0))
        
        // Additional stack position:
        // - Split: right-side bet stack (+60)
        // - Non-split double-down: DD stack is the LEFT stack in the centered pair (-22.5)
        let additionalStackX: CGFloat = UIScreen.main.bounds.width * 0.5 + (gameState.isSplit ? 60 : -(chipSpacing / 2.0))
        
        print("💰 DUAL STACK LOSE: Main stack at x=\(mainStackX), Additional stack at x=\(additionalStackX), y=\(loseY)")
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // Create animation chips for main stack (tighter stacking)
        for (index, chipValue) in gameState.betChips.enumerated() {
            let angle = Double(index) * 0.8  // Reduced angle for tighter spiral
            let radius: CGFloat = 2.0        // Reduced radius for closer stacking
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            
            let loseChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: CGPoint(
                    x: mainStackX + xOffset,
                    y: loseY + yOffset
                ),
                opacity: 1.0,
                scale: 1.0
            )
            loseChips.append(loseChip)
        }
        
        // Create animation chips for additional stack (tighter stacking)
        for (index, chipValue) in gameState.additionalBetChips.enumerated() {
            let angle = Double(index) * 0.8  // Reduced angle for tighter spiral
            let radius: CGFloat = 2.0        // Reduced radius for closer stacking
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            
            let loseChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: CGPoint(
                    x: additionalStackX + xOffset,
                    y: loseY + yOffset
                ),
                opacity: 1.0,
                scale: 1.0
            )
            loseChips.append(loseChip)
        }
        
        // Hide BOTH the main and additional betting chips immediately
        gameState.hideBetChipsDuringLoseAnimation = true
        print("💰 DUAL STACK LOSE: Set hideBetChipsDuringLoseAnimation = true to hide BOTH chip stacks")
        
        // Animate both stacks to the same destination (dealer area) SIMULTANEOUSLY
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 DUAL STACK LOSE: Sliding BOTH stacks toward dealer SIMULTANEOUSLY")
            print("💰 DUAL STACK LOSE: Animating \(loseChips.count) total chips (\(gameState.betChips.count) main + \(gameState.additionalBetChips.count) additional)")
            
            withAnimation(.easeOut(duration: 1.0)) {
                // Animate ALL chips (both stacks) to the same destination at the same time
                for i in 0..<loseChips.count {
                    loseChips[i].position = CGPoint(
                        x: UIScreen.main.bounds.width + 100, // Off-screen to the right (dealer direction)
                        y: UIScreen.main.bounds.height * 0.25 // Up toward dealer area
                    )
                    loseChips[i].opacity = 0.0 // Fade out completely
                }
            }
        }
        
        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            loseChips.removeAll()
            // Clear both chip arrays
            gameState.betChips.removeAll()
            gameState.additionalBetChips.removeAll()
            // Reset the hide flag so chips can be shown again
            gameState.hideBetChipsDuringLoseAnimation = false
            print("💰 DUAL STACK LOSE: Animation complete, both stacks cleared, hide flag reset")
        }
    }
    
    // MARK: - Mixed Split Sequential Animation (Lose losing stack first, then payout for winning stack)
    private func startMixedSplitSequentialAnimation(trainingModeEnabled: Bool) {
        print("💰 MIXED SPLIT SEQUENTIAL: Starting lose animation first, then IMMEDIATE payout")
        
        guard let resultMessage = gameState.resultMessage else { return }
        
        // Determine which hand lost
        let lines = resultMessage.components(separatedBy: "\n").filter { !$0.isEmpty }
        var hand1Lost = false
        var hand2Lost = false
        
        for line in lines {
            if line.contains("Hand 1:") && (line.contains("Lose.") || line.contains("Bust!")) {
                hand1Lost = true
            } else if line.contains("Hand 2:") && (line.contains("Lose.") || line.contains("Bust!")) {
                hand2Lost = true
            }
        }
        
        print("💰 MIXED SPLIT: Hand 1 lost: \(hand1Lost), Hand 2 lost: \(hand2Lost)")
        
        // Step 1: Animate away the losing stack
        if hand1Lost {
            // Hand 1 (right stack) lost - animate it away
            startRightStackLoseAnimation(trainingModeEnabled: trainingModeEnabled) {
                // Step 2: IMMEDIATELY start payout for Hand 2 (left stack) if it won
                if !hand2Lost {
                    print("💰 MIXED SPLIT SEQUENTIAL: Hand 1 removed, IMMEDIATELY starting payout for Hand 2")
                    DispatchQueue.main.async {
                        self.startMainStackPayoutAnimation(trainingModeEnabled: trainingModeEnabled)
                    }
                }
            }
        } else if hand2Lost {
            // Hand 2 (left stack) lost - animate it away, then payout Hand 1 (right stack)
            startLeftStackLoseAnimation(trainingModeEnabled: trainingModeEnabled) {
                if !hand1Lost {
                    print("💰 MIXED SPLIT SEQUENTIAL: Hand 2 removed, IMMEDIATELY starting payout for Hand 1")
                    DispatchQueue.main.async {
                        self.startAdditionalStackPayoutAnimation(trainingModeEnabled: trainingModeEnabled)
                    }
                }
            }
        }
    }
    
    private func startRightStackLoseAnimation(trainingModeEnabled: Bool, completion: @escaping () -> Void) {
        print("💰 RIGHT STACK LOSE: Animating away additional bet chips")
        
        // Calculate position for additional stack (right side - blue circle area) - 6 points higher
        let baseLoseY: CGFloat = trainingModeEnabled ? 
            UIScreen.main.bounds.height * 0.75 - 173 :  // Training mode (6 points higher)
            UIScreen.main.bounds.height * 0.75 - 116     // Regular mode (6 points higher)
        
        let splitOffset: CGFloat = (trainingModeEnabled && gameState.isSplit) ? 15 : 0
        let loseY = baseLoseY + splitOffset
        // In split, additionalBetChips is the right stack; in non-split double-down, it's the LEFT stack in the centered pair.
        let chipSpacing: CGFloat = 45.0
        let additionalStackX: CGFloat = UIScreen.main.bounds.width * 0.5 + (gameState.isSplit ? 60 : -(chipSpacing / 2.0))
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // Create animation chips for additional stack only
        for (index, chipValue) in gameState.additionalBetChips.enumerated() {
            let angle = Double(index) * 0.8  // Tighter spiral
            let radius: CGFloat = 2.0        // Closer stacking
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            
            let loseChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: CGPoint(
                    x: additionalStackX + xOffset,
                    y: loseY + yOffset
                ),
                opacity: 1.0,
                scale: 1.0
            )
            loseChips.append(loseChip)
        }
        
        // Animate right stack away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 RIGHT STACK LOSE: Sliding right stack toward dealer")
            withAnimation(.easeOut(duration: 0.8)) {  // Faster animation for sequential
                for i in 0..<loseChips.count {
                    loseChips[i].position = CGPoint(
                        x: UIScreen.main.bounds.width + 100, // Off-screen to the right
                        y: UIScreen.main.bounds.height * 0.25 // Up toward dealer area
                    )
                    loseChips[i].opacity = 0.0 // Fade out completely
                }
            }
        }
        
        // Clean up and call completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loseChips.removeAll()
            gameState.additionalBetChips.removeAll() // Clear the right stack
            print("💰 RIGHT STACK LOSE: Right stack cleared, calling completion")
            completion()
        }
    }
    
    private func startLeftStackLoseAnimation(trainingModeEnabled: Bool, completion: @escaping () -> Void) {
        print("💰 LEFT STACK LOSE: Animating away main bet chips (Hand 2)")
        
        // Calculate position for main stack (left side) - 6 points higher
        let baseLoseY: CGFloat = trainingModeEnabled ? 
            UIScreen.main.bounds.height * 0.75 - 173 :  // Training mode (6 points higher)
            UIScreen.main.bounds.height * 0.75 - 116     // Regular mode (6 points higher)
        
        let splitOffset: CGFloat = (trainingModeEnabled && gameState.isSplit) ? 15 : 0
        let loseY = baseLoseY + splitOffset
        let mainStackX: CGFloat = UIScreen.main.bounds.width * 0.5 - 60  // Left side (matches betting area for split)
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // Create animation chips for main stack only
        for (index, chipValue) in gameState.betChips.enumerated() {
            let angle = Double(index) * 0.8  // Tighter spiral
            let radius: CGFloat = 2.0        // Closer stacking
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            
            let loseChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: CGPoint(
                    x: mainStackX + xOffset,
                    y: loseY + yOffset
                ),
                opacity: 1.0,
                scale: 1.0
            )
            loseChips.append(loseChip)
        }
        
        // Animate left stack away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 LEFT STACK LOSE: Sliding left stack toward dealer")
            withAnimation(.easeOut(duration: 0.8)) {  // Faster animation for sequential
                for i in 0..<loseChips.count {
                    loseChips[i].position = CGPoint(
                        x: UIScreen.main.bounds.width + 100, // Off-screen to the right
                        y: UIScreen.main.bounds.height * 0.25 // Up toward dealer area
                    )
                    loseChips[i].opacity = 0.0 // Fade out completely
                }
            }
        }
        
        // Clean up and call completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loseChips.removeAll()
            gameState.betChips.removeAll() // Clear the left stack
            print("💰 LEFT STACK LOSE: Left stack cleared, calling completion")
            completion()
        }
    }
    
    // MARK: - Animate Losing Split Hands Away
    private func animateLosingSplitHands(losingHands: Set<Int>, trainingModeEnabled: Bool, completion: (() -> Void)? = nil) {
        print("💰 LOSING SPLIT HANDS: Animating away hands \(losingHands)")
        
        let baseLoseY: CGFloat = trainingModeEnabled ? 
            UIScreen.main.bounds.height * 0.75 - 167 :  // Training mode
            UIScreen.main.bounds.height * 0.75 - 110     // Regular mode
        
        let splitOffset: CGFloat = (trainingModeEnabled && gameState.isSplit) ? 3 : 0
        let loseY = baseLoseY + splitOffset
        let centerX: CGFloat = UIScreen.main.bounds.width * 0.5
        
        // Clear any existing lose chips
        loseChips.removeAll()
        
        // Animate Hand 2 (index 0, left stack) if it lost
        if losingHands.contains(0) {
            print("💰 LOSING SPLIT: Animating Hand 2 (left) away")
            
            // Add betChips to lose animation
            for (index, chipValue) in gameState.betChips.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                loseChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: centerX - 52.5 + xOffset, y: loseY + yOffset),  // Bet at -52.5
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
            
            // Add doubleDownChipsHand2 if they exist
            for (index, chipValue) in gameState.doubleDownChipsHand2.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                loseChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: centerX - 92.5 + xOffset, y: loseY + yOffset),  // DD at -92.5
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
        }
        
        // Animate Hand 1 (index 1, right stack) if it lost
        if losingHands.contains(1) {
            print("💰 LOSING SPLIT: Animating Hand 1 (right) away")
            
            // Add additionalBetChips to lose animation (no shift since losing)
            for (index, chipValue) in gameState.additionalBetChips.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                loseChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: centerX + 97.5 + xOffset, y: loseY + yOffset),  // Bet at +97.5 (normal position)
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
            
            // Add doubleDownChipsHand1 if they exist
            for (index, chipValue) in gameState.doubleDownChipsHand1.enumerated() {
                let angle = Double(index) * 0.8
                let radius: CGFloat = 2.0
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                loseChips.append(AnimatedChip(
                    id: UUID(),
                    value: chipValue,
                    position: CGPoint(x: centerX + 52.5 + xOffset, y: loseY + yOffset),  // DD at +52.5 (normal position)
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
        }
        
        // DON'T hide all chips - we'll clear the specific losing hand arrays immediately
        // This way winning chips stay visible while losing chips animate away
        
        // Clear the chip arrays for losing hands IMMEDIATELY so they don't render
        if losingHands.contains(0) {
            gameState.betChips.removeAll()
            gameState.doubleDownChipsHand2.removeAll()
        }
        if losingHands.contains(1) {
            gameState.additionalBetChips.removeAll()
            gameState.doubleDownChipsHand1.removeAll()
        }
        
        // Animate chips away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💰 LOSING SPLIT: Sliding chips toward dealer")
            withAnimation(.easeOut(duration: 1.0)) {
                for i in 0..<loseChips.count {
                    loseChips[i].position = CGPoint(
                        x: UIScreen.main.bounds.width + 100,
                        y: UIScreen.main.bounds.height * 0.25
                    )
                    loseChips[i].opacity = 0.0
                }
            }
        }
        
        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            loseChips.removeAll()
            print("💰 LOSING SPLIT: Animation complete, losing hands cleared")
            
            // Call completion callback if provided
            completion?()
        }
    }
    
    private func startMainStackPayoutAnimation(trainingModeEnabled: Bool) {
        print("💰 MAIN STACK PAYOUT: Starting payout for remaining main stack")
        
        // Clear any existing win chips
        winChips.removeAll()
        
        let dealerPos = getDealerPosition()
        
        // Calculate position (current payout position) - matches other animations with final fine-tuning
        let basePayoutY: CGFloat = trainingModeEnabled ? 
            UIScreen.main.bounds.height * 0.75 - 191.5 + 77 - 3 :  // Training mode (moved down 77 points, then up 3)
            UIScreen.main.bounds.height * 0.75 - 130.2 + 18     // Regular mode (moved down 18 points)
        
        let splitOffset: CGFloat = (trainingModeEnabled && gameState.isSplit) ? 3 : 0
        let payoutY = basePayoutY + splitOffset
        
        // For split: Hand 2 (left stack) pays to center-120, for regular/double down: pays to center-60
        let centerX: CGFloat = UIScreen.main.bounds.width * 0.5
        let payoutX: CGFloat = (trainingModeEnabled && gameState.isSplit) ? (centerX - 120) : (centerX - 60)
        
        // Create chips for main stack payout
        for (index, chipValue) in gameState.betChips.enumerated() {
            let winChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: dealerPos,
                opacity: 1.0,
                scale: 1.0
            )
            winChips.append(winChip)
        }
        
        // Animate chips to payout position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in 0..<winChips.count {
                let angle = Double(i) * 0.8  // Tighter spiral
                let radius: CGFloat = 2.0    // Closer stacking
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                winChips[i].position = CGPoint(
                    x: payoutX + xOffset,
                    y: payoutY + yOffset
                )
            }
            
            print("💰 MAIN STACK PAYOUT: Animated \(winChips.count) chips to payout position")
        }
    }
    
    private func startAdditionalStackPayoutAnimation(trainingModeEnabled: Bool) {
        print("💰 ADDITIONAL STACK PAYOUT: Starting payout for remaining additional stack (Hand 1)")
        
        // Clear any existing win chips
        winChips.removeAll()
        
        let dealerPos = getDealerPosition()
        
        // Calculate position (current payout position) - matches other animations with final fine-tuning
        let basePayoutY: CGFloat = trainingModeEnabled ? 
            UIScreen.main.bounds.height * 0.75 - 191.5 + 77 - 3 :  // Training mode (moved down 77 points, then up 3)
            UIScreen.main.bounds.height * 0.75 - 130.2 + 18     // Regular mode (moved down 18 points)
        
        let splitOffset: CGFloat = (trainingModeEnabled && gameState.isSplit) ? 3 : 0
        let payoutY = basePayoutY + splitOffset
        
        // For split: Hand 1 (right stack) pays to center
        // For split + double down on Hand 0: additional chips at center, payout at center-60
        // For split + double down on Hand 1: additional chips at center+120, payout at center+60
        // For regular/double down: pays to center-120
        let centerX: CGFloat = UIScreen.main.bounds.width * 0.5
        let payoutX: CGFloat = {
            if trainingModeEnabled && gameState.isSplit {
                // Check which hand was doubled down
                if let doubledHand = gameState.doubledDownHandIndex {
                    // Hand 0 (left) doubled: additional chips at center, payout at center-60
                    // Hand 1 (right) doubled: additional chips at center+120, payout at center+60
                    return doubledHand == 0 ? (centerX - 60) : (centerX + 60)
                } else {
                    // Just split, no double down: additional at center+60, payout at center
                    return centerX
                }
            } else {
                // Regular double down: payout at center-120
                return centerX - 120
            }
        }()
        
        // Create chips for additional stack payout
        for (index, chipValue) in gameState.additionalBetChips.enumerated() {
            let winChip = AnimatedChip(
                id: UUID(),
                value: chipValue,
                position: dealerPos,
                opacity: 1.0,
                scale: 1.0
            )
            winChips.append(winChip)
        }
        
        // Animate chips to payout position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in 0..<winChips.count {
                let angle = Double(i) * 0.8  // Tighter spiral
                let radius: CGFloat = 2.0    // Closer stacking
                let xOffset = radius * cos(angle)
                let yOffset = radius * sin(angle)
                
                winChips[i].position = CGPoint(
                    x: payoutX + xOffset,
                    y: payoutY + yOffset
                )
            }
            
            print("💰 ADDITIONAL STACK PAYOUT: Animated \(winChips.count) chips to payout position")
        }
    }
    
    // Helper function to remove chips by value (highest first) and return removed chips
    private func removeChipsByValue(amount: Int) -> [Int] {
        var remainingAmount = amount
        var removedChips: [Int] = []
        var availableChips = gameState.betChips.sorted(by: >) // Highest value first
        
        print("💰 REMOVE CHIPS: Need to remove $\(amount) from chips: \(gameState.betChips)")
        
        // Remove chips starting with highest value
        var i = 0
        while i < availableChips.count && remainingAmount > 0 {
            let chipValue = availableChips[i]
            if chipValue <= remainingAmount {
                removedChips.append(chipValue)
                remainingAmount -= chipValue
                availableChips.remove(at: i)
                print("💰 REMOVE CHIPS: Removed $\(chipValue) chip, remaining: $\(remainingAmount)")
            } else {
                i += 1
            }
        }
        
        // Update gameState.betChips to reflect remaining chips
        gameState.betChips = availableChips.sorted(by: >) // Maintain highest-to-lowest order
        
        print("💰 REMOVE CHIPS: Removed chips: \(removedChips), Remaining chips: \(gameState.betChips)")
        return removedChips
    }
    
    // Helper function to create chips for a specific amount (mimics betting distribution)
    private func createChipsForAmount(_ amount: Int) -> [Int] {
        // For simplicity, create chips using the same distribution as current bet
        // This could be enhanced to use optimal chip combinations
        let currentChips = gameState.betChips.sorted(by: >) // Highest first
        let totalCurrentValue = currentChips.reduce(0, +)
        
        if totalCurrentValue <= 0 {
            // Fallback: create chips using common denominations
            return createOptimalChips(for: amount)
        }
        
        // Scale current chip distribution to match the amount
        let ratio = Double(amount) / Double(totalCurrentValue)
        var resultChips: [Int] = []
        
        for chip in currentChips {
            let scaledValue = Int(Double(chip) * ratio)
            if scaledValue > 0 {
                resultChips.append(scaledValue)
            }
        }
        
        // If scaling doesn't work well, fall back to optimal chips
        if resultChips.isEmpty || resultChips.reduce(0, +) != amount {
            return createOptimalChips(for: amount)
        }
        
        return resultChips.sorted(by: >) // Highest first
    }
    
    // Helper function to create optimal chip combination for an amount
    private func createOptimalChips(for amount: Int) -> [Int] {
        let denominations = [100, 50, 25, 10, 5, 1] // Common chip values
        var remainingAmount = amount
        var chips: [Int] = []
        
        for denomination in denominations {
            while remainingAmount >= denomination {
                chips.append(denomination)
                remainingAmount -= denomination
            }
        }
        
        return chips.sorted(by: >) // Highest first
    }
}

// MARK: - Animated Chip Model
struct AnimatedChip {
    let id: UUID
    let value: Int
    var position: CGPoint
    var opacity: Double
    var scale: CGFloat
}
