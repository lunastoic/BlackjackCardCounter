//
//  ContentView.swift
//  BlackjackCardCounter
//
//  Created by Christopher on 5/29/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("userChips") private var userChips: Int = 500
    @State private var showZeroChipsOverlay = false
    @State private var hasBeenClicked = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: [Color(hex: "1a3a1a"), Color(hex: "2d5a2d")]),
                             startPoint: .top,
                             endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Game Header
                    GameHeaderView()
                    
                    // Title
                    Text("Blackjack Card Counter")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
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
                                        RewardsButton(hasBeenClicked: $hasBeenClicked)
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
                    
                    // Main menu buttons
                    VStack(spacing: 20) {
                        NavigationLink(destination: MapSelectionView()) {
                            MenuButton(title: "Start Counting", systemImage: "play.fill")
                        }
                        .onTapGesture {
                            if userChips <= 0 {
                                showZeroChipsOverlay = true
                            }
                        }
                        
                        NavigationLink(destination: SettingsView()) {
                            MenuButton(title: "Settings", systemImage: "gear")
                        }
                        
                        NavigationLink(destination: HowToPlayView()) {
                            MenuButton(title: "How to Play", systemImage: "book.fill")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 600) // Limit width on larger screens
                .frame(maxWidth: .infinity) // Center the content
            }
            .overlay {
                if showZeroChipsOverlay {
                    ZeroChipsOverlay(isPresented: $showZeroChipsOverlay)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force full screen on iPad
    }
}

// Custom button style for menu items
struct MenuButton: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: 280)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(hex: "38b802"))
                .shadow(radius: 5)
        )
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
