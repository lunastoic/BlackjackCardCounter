//
//  ContentView.swift
//  BlackjackCardCounter
//
//  Created by Christopher on 5/29/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("userChips") private var userChips: Int = 500
    @AppStorage("lastDailyRewardDate") var lastDailyRewardDate: Double = 0
    @State private var showZeroChipsOverlay = false
    @State private var hasBeenClicked = false
    @State private var animate = false
    
    var rewardAvailable: Bool {
        let now = Date().timeIntervalSince1970
        return now - lastDailyRewardDate > 24 * 60 * 60
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(hex: "8B0000")
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Game Header
                    GameHeaderView()
                    
                    // Title
                    if let _ = UIImage(named: "BlackJack Card Counter") {
                        Image("BlackJack Card Counter")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 105)
                            .frame(maxWidth: 394)
                    } else {
                        Text("Blackjack Card Counter")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Home screen image with rewards button overlay
                    ZStack {
                        Image("HouseDealer")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 8)
                        
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    NavigationLink(destination: RewardsView()) {
                                        Image("CTRewards")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 64)
                                            .contentShape(Rectangle())
                                            .accessibilityLabel("Rewards")
                                            .colorMultiply(rewardAvailable ? Color.white : Color.gray)
                                            .scaleEffect(animate && rewardAvailable && !hasBeenClicked ? 1.08 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animate)
                                    }
                                }
                                .onAppear {
                                    if rewardAvailable && !hasBeenClicked {
                                        startSpringAnimation()
                                    }
                                }
                                .onChange(of: rewardAvailable) { isAvailable in
                                    if isAvailable && !hasBeenClicked {
                                        startSpringAnimation()
                                    } else {
                                        animate = false
                                    }
                                }
                                .padding(.trailing, 30)
                            }
                            .padding(.top, 25)
                            Spacer()
                        }
                        .allowsHitTesting(true)
                        .zIndex(10)
                    }
                    .clipped()
                    
                    // Main menu buttons (replace text buttons with image assets)
                    VStack(spacing: 20) {
                        // Start Counting -> CTStart
                        NavigationLink(destination: MapSelectionView()) {
                            Image("CTStart")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 64)
                                .contentShape(Rectangle())
                                .accessibilityLabel("Start Counting")
                        }
                        .onTapGesture {
                            if userChips <= 0 {
                                showZeroChipsOverlay = true
                            }
                        }
                        
                        // Settings -> CTSettings
                        NavigationLink(destination: SettingsView()) {
                            Image("CTSettings")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 64)
                                .contentShape(Rectangle())
                                .accessibilityLabel("Settings")
                        }
                        
                        // How to Play -> CTHowToPlay
                        NavigationLink(destination: HowToPlayView()) {
                            Image("CTHowToPlay")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 64)
                                .contentShape(Rectangle())
                                .accessibilityLabel("How to Play")
                        }
                    }
                    .offset(y: UIDevice.current.userInterfaceIdiom == .pad ? -100 : 0) // Shift buttons up 80 points on iPad only
                }
                .padding()
                .frame(maxWidth: 600)          // Limit width on larger screens
                .frame(maxWidth: .infinity)     // Center the content
            }
            .overlay {
                if showZeroChipsOverlay {
                    ZeroChipsOverlay(isPresented: $showZeroChipsOverlay)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force full screen on iPad
    }
    
    private func startSpringAnimation() {
        animate = true
        Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { timer in
            if rewardAvailable && !hasBeenClicked {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animate = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        animate = false
                    }
                }
            } else {
                timer.invalidate()
                animate = false
            }
        }
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct RewardsButton: View {
    @AppStorage("lastDailyRewardDate") var lastDailyRewardDate: Double = 0
    @State private var animate = false
    @Binding var hasBeenClicked: Bool
    
    var rewardAvailable: Bool {
        let now = Date().timeIntervalSince1970
        return now - lastDailyRewardDate > 24 * 60 * 60
    }
    
    var body: some View {
        ZStack {
            Text("🎁 Rewards")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 60)
                .background(rewardAvailable ? Color.yellow : Color.gray)
                .cornerRadius(18)
                .shadow(color: rewardAvailable ? .yellow : .clear, radius: 12, x: 0, y: 4)
        }
        .scaleEffect(animate && rewardAvailable && !hasBeenClicked ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animate)
        .zIndex(1)
        .onAppear {
            if rewardAvailable && !hasBeenClicked {
                startSpringAnimation()
            }
        }
        .onChange(of: rewardAvailable) { isAvailable in
            if isAvailable && !hasBeenClicked {
                startSpringAnimation()
            } else {
                animate = false
            }
        }
    }
    
    private func startSpringAnimation() {
        animate = true
        Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { timer in
            if rewardAvailable && !hasBeenClicked {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animate = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        animate = false
                    }
                }
            } else {
                timer.invalidate()
                animate = false
            }
        }
    }
}

#Preview {
    ContentView()
}

