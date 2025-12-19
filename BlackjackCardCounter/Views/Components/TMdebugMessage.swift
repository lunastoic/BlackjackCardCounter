import SwiftUI

// MARK: - Training Mode Debug Messages
struct TMdebugMessage {
    
    // MARK: - Auto-play Trigger Messages
    static func triggeringWaitForProcessing(currentValue: Int) {
        print("🎓 Training Mode: ✅ TRIGGERING waitForProcessingToComplete() - current value: \(currentValue)")
    }
    
    static func detected21(handCount: Int) {
        print("🎓 Training Mode: 🎯 DETECTED 21 WITH \(handCount) CARDS!")
    }
    
    static func detectedNeedToHit(currentValue: Int) {
        print("🎓 Training Mode: 🎯 DETECTED \(currentValue) - NEED TO CONTINUE HITTING")
    }
    
    static func detectedShouldStand(currentValue: Int) {
        print("🎓 Training Mode: 🎯 DETECTED \(currentValue) - SHOULD STAND")
    }
    
    static func notTriggeringAutoPlay(trainingEnabled: Bool, isPlayerTurn: Bool, handCount: Int) {
        print("🎓 Training Mode: ❌ NOT TRIGGERING auto-play check:")
        print("  - trainingEnabled: \(trainingEnabled)")
        print("  - isPlayerTurn: \(isPlayerTurn)")
        print("  - handCount >= 2: \(handCount >= 2)")
    }
    
    // MARK: - Player Turn Change Messages
    static func playerTurnChanged(isPlayerTurn: Bool, handCount: Int, isDealing: Bool, trainingEnabled: Bool) {
        print("🎓 Training Mode: Player turn changed to \(isPlayerTurn), handCount=\(handCount), isDealing=\(isDealing), trainingEnabled=\(trainingEnabled)")
    }
    
    static func playerTurnEnded() {
        print("🎓 Training Mode: 🔄 PLAYER TURN ENDED - DEALER SHOULD PLAY NOW...")
    }
    
    static func dealerHandInfo(dealerHandCount: Int, flippedDealerCards: Set<Int>, visuallyRevealedCount: Int, resultMessage: String?, isDealing: Bool) {
        print("🎓 Training Mode: Dealer hand count: \(dealerHandCount)")
        print("🎓 Training Mode: Flipped dealer cards: \(flippedDealerCards)")
        print("🎓 Training Mode: Visual revealed dealer: \(visuallyRevealedCount)")
        print("🎓 Training Mode: Result message: \(resultMessage ?? "nil")")
        print("🎓 Training Mode: Is dealing: \(isDealing)")
    }
    
    static func dealerNotPlayingWarning(isPlayerTurn: Bool, isDealing: Bool) {
        print("🎓 Training Mode: ⚠️ WARNING: Dealer hasn't started playing after 2 seconds!")
        print("🎓 Training Mode: Current state - isPlayerTurn=\(isPlayerTurn), isDealing=\(isDealing)")
    }
    
    // MARK: - Auto-play Check Messages
    static func checkAndAutoPlayCalled() {
        print("🎓 Training Mode: checkAndAutoPlay() called")
    }
    
    static func autoPlayStateInfo(trainingEnabled: Bool, isPlayerTurn: Bool, playerValue: Int, isBusted: Bool, playerHand: [String], hasAce: Bool, handText: String, isAutoPlaying: Bool, isContinuousAutoPlay: Bool, isProcessingAction: Bool, handCount: Int, isDraggingSpeed: Bool) {
        print("🎓 Training Mode: trainingEnabled=\(trainingEnabled), isPlayerTurn=\(isPlayerTurn), playerValue=\(playerValue), isBusted=\(isBusted)")
        print("🎓 Training Mode: playerHand=\(playerHand)")
        print("🎓 Training Mode: hasAce=\(hasAce), handText='\(handText)'")
        print("🎓 Training Mode: isAutoPlaying=\(isAutoPlaying), isContinuousAutoPlay=\(isContinuousAutoPlay)")
        print("🎓 Training Mode: isProcessingAction=\(isProcessingAction), handCount=\(handCount)")
        print("🎓 Training Mode: isDraggingSpeed=\(isDraggingSpeed)")
    }
    
    static func autoPlayBlocked(isContinuousAutoPlay: Bool, isPlayerTurn: Bool, isAutoPlaying: Bool, isProcessingAction: Bool, handCount: Int) {
        print("🎓 Training Mode: ❌ AUTO-PLAY BLOCKED - CONDITIONS NOT MET:")
        print("  - isContinuousAutoPlay: \(isContinuousAutoPlay)")
        print("  - isPlayerTurn: \(isPlayerTurn)")
        print("  - isAutoPlaying: \(isAutoPlaying)")
        print("  - isProcessingAction: \(isProcessingAction)")
        print("  - handCount: \(handCount)")
    }
    
    static func playerBusted(playerValue: Int) {
        print("🎓 Training Mode: ❌ Player busted at \(playerValue) - stopping auto-play")
    }
    
    static func decisionTime(playerValue: Int) {
        print("🎓 Training Mode: 🎯 DECISION TIME - Player value: \(playerValue)")
    }
    
    static func willStandSoft(playerValue: Int) {
        print("🎓 Training Mode: ✅ WILL STAND - SOFT \(playerValue) (has Ace)")
    }
    
    static func willStandHard(playerValue: Int) {
        print("🎓 Training Mode: ✅ WILL STAND - HARD \(playerValue)")
    }
    
    static func willHit(playerValue: Int) {
        print("🎓 Training Mode: ✅ WILL HIT (value \(playerValue) < 17)")
    }
    
    // MARK: - Stand Action Messages
    static func playerAutoStanding(handDescription: String, handCount: Int, handCards: [String], handText: String, isPlayerTurn: Bool, dealerHandCount: Int, flippedCards: Set<Int>) {
        print("🎓 Training Mode: ✅ Player auto-standing at \(handDescription)")
        print("🎓 Training Mode: Hand details - \(handCount) cards: \(handCards)")
        print("🎓 Training Mode: Full hand text: '\(handText)'")
        print("🎓 Training Mode: Before stand - isPlayerTurn=\(isPlayerTurn)")
        print("🎓 Training Mode: Before stand - dealerHand=\(dealerHandCount), flippedCards=\(flippedCards)")
    }
    
    static func preStandState(isPlayerTurn: Bool, isSplit: Bool) {
        print("🎓 Training Mode: Pre-stand state - isPlayerTurn=\(isPlayerTurn), isSplit=\(isSplit)")
    }
    
    static func standActionCompleted() {
        print("🎓 Training Mode: 🎯 STAND ACTION COMPLETED")
    }
    
    static func postStandState(isPlayerTurn: Bool, dealerHandCount: Int, flippedCards: Set<Int>) {
        print("🎓 Training Mode: Post-stand state - isPlayerTurn=\(isPlayerTurn)")
        print("🎓 Training Mode: Post-stand dealer - dealerHand=\(dealerHandCount), flippedCards=\(flippedCards)")
    }
    
    static func immediateCheck(isPlayerTurn: Bool, flippedDealerCards: Set<Int>, dealerHandCount: Int, visuallyRevealedCount: Int, resultMessage: String?, isDealing: Bool) {
        print("🎓 Training Mode: 🔍 IMMEDIATE CHECK (0.5s after stand):")
        print("  - isPlayerTurn: \(isPlayerTurn)")
        print("  - flippedDealerCards: \(flippedDealerCards)")
        print("  - dealerHand count: \(dealerHandCount)")
        print("  - visuallyRevealedDealerHand: \(visuallyRevealedCount)")
        print("  - resultMessage: \(resultMessage ?? "nil")")
        print("  - isDealing: \(isDealing)")
    }
    
    static func delayedCheck(isPlayerTurn: Bool, flippedDealerCards: Set<Int>) {
        print("🎓 Training Mode: 🔍 DELAYED CHECK (2.0s after stand):")
        print("  - isPlayerTurn: \(isPlayerTurn)")
        print("  - flippedDealerCards: \(flippedDealerCards)")
    }
    
    static func standActionFailed(currentValue: Int) {
        print("🎓 Training Mode: ⚠️ STAND ACTION FAILED - Player turn didn't end!")
        print("🎓 Training Mode: Current player value: \(currentValue)")
        print("🎓 Training Mode: Forcing dealer turn manually...")
    }
    
    static func dealerTurnStartedButHoleCardNotFlipped() {
        print("🎓 Training Mode: ⚠️ DEALER TURN STARTED BUT HOLE CARD NOT FLIPPED!")
        print("🎓 Training Mode: Manually triggering dealer card reveal...")
    }
    
    // MARK: - Hit Action Messages
    static func playerAutoHitting(playerValue: Int, handCards: [String]) {
        print("🎓 Training Mode: 🎯 Player auto-hitting at \(playerValue)")
        print("🎓 Training Mode: Current hand before hit: \(handCards)")
    }
    
    static func executingHitAction() {
        print("🎓 Training Mode: 🔥 EXECUTING HIT ACTION NOW...")
    }
    
    static func hitActionCompleted() {
        print("🎓 Training Mode: 🔥 HIT ACTION COMPLETED")
    }
    
    static func hitVerification(newHandCount: Int, newValue: Int, newHand: [String], isPlayerTurn: Bool, shouldContinue: Bool) {
        print("🎓 Training Mode: 🔍 HIT VERIFICATION:")
        print("  - New hand count: \(newHandCount)")
        print("  - New hand value: \(newValue)")
        print("  - New hand: \(newHand)")
        print("  - isPlayerTurn: \(isPlayerTurn)")
        print("  - Should continue: \(shouldContinue)")
    }
    
    static func autoPlayStoppedIncorrectly() {
        print("🎓 Training Mode: ⚠️ AUTO-PLAY STOPPED INCORRECTLY - FORCING CONTINUATION")
    }
    
    static func resettingAutoPlayingFlag() {
        print("🎓 Training Mode: 🔄 Resetting isAutoPlaying flag")
    }
    
    // MARK: - Processing Check Messages
    static func processingCheck(trainingEnabled: Bool, isContinuous: Bool, isPlayerTurn: Bool, isAutoPlaying: Bool) {
        print("🔄 Processing Check: trainingEnabled=\(trainingEnabled), isContinuous=\(isContinuous), isPlayerTurn=\(isPlayerTurn), isAutoPlaying=\(isAutoPlaying)")
    }
    
    static func processingCheckStopped(trainingEnabled: Bool, isContinuous: Bool, isPlayerTurn: Bool, isAutoPlaying: Bool) {
        print("🎓 Training Mode: ❌ PROCESSING CHECK STOPPED - Conditions changed")
        print("  - trainingEnabled: \(trainingEnabled)")
        print("  - isContinuousAutoPlay: \(isContinuous)")
        print("  - isPlayerTurn: \(isPlayerTurn)")
        print("  - isAutoPlaying: \(isAutoPlaying)")
    }
}
