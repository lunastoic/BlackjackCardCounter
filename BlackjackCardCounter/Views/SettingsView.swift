import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("dealerSpeed") private var dealerSpeed = 1.0
    @AppStorage("vibrationEnabled") private var vibrationEnabled = true
    @AppStorage("forcedBlackjacks") private var forcedBlackjacks = false
    @ObservedObject private var xpManager = XPChipManager.shared
    
    @State private var resetMapsPressed = false
    @State private var removeLevelsPressed = false
    @State private var addLevelsPressed = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]),
                         startPoint: .top,
                         endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Sound Settings
                    SettingsSection(title: "Sound") {
                        Toggle("Enable Sound", isOn: $soundEnabled)
                            .tint(Color(hex: "e94560"))
                        
                        Toggle("Enable Vibration", isOn: $vibrationEnabled)
                            .tint(Color(hex: "e94560"))
                    }
                    
                    // Dealer Speed Settings
                    SettingsSection(title: "Game Speed") {
                        VStack(alignment: .leading) {
                            Text("Dealer Speed")
                                .foregroundColor(.white)
                            
                            Slider(value: $dealerSpeed, in: 0.5...2.0, step: 0.1)
                                .tint(Color(hex: "e94560"))
                            
                            HStack {
                                Text("Slow")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("Fast")
                                    .foregroundColor(.gray)
                            }
                            .font(.caption)
                        }
                    }
                    
                    // About Section
                    SettingsSection(title: "About") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Version 1.0.0")
                                .foregroundColor(.gray)
                            
                            Text("© 2024 Blackjack Counter")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Debug Section (Remove before launch)
                    SettingsSection(title: "Debug") {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: {
                                // Reset maps to locked state (only first map unlocked)
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    resetMapsPressed = false
                                }
                                UserDefaults.standard.set("1", forKey: "unlockedMaps")
                            }) {
                                HStack {
                                    Image(systemName: "lock.rotation")
                                        .foregroundColor(.red)
                                    Text("Reset Maps (Debug)")
                                        .foregroundColor(.red)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(resetMapsPressed ? 0.95 : 1.0)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !resetMapsPressed {
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                resetMapsPressed = true
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            resetMapsPressed = false
                                        }
                                    }
                            )
                            
                            Text("⚠️ This will lock all maps except the first one")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                            
                            // Remove 5 Levels Button (Debug)
                            Button(action: {
                                // Remove 5 levels, but ensure level doesn't go below 1
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    removeLevelsPressed = false
                                }
                                let newLevel = max(1, xpManager.userLevel - 5)
                                xpManager.userLevel = newLevel
                                // Reset XP to 0 when removing levels
                                xpManager.userXP = 0
                            }) {
                                HStack {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Remove 5 Levels (Debug)")
                                        .foregroundColor(.orange)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.orange, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(removeLevelsPressed ? 0.95 : 1.0)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !removeLevelsPressed {
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                removeLevelsPressed = true
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            removeLevelsPressed = false
                                        }
                                    }
                            )
                            
                            Text("⚠️ Removes 5 levels from your current level (minimum level 1)")
                                .font(.caption)
                                .foregroundColor(.orange.opacity(0.8))
                            
                            // Add 5 Levels Button (Debug)
                            Button(action: {
                                // Add 5 levels, but ensure level doesn't exceed max level (25)
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    addLevelsPressed = false
                                }
                                let newLevel = min(25, xpManager.userLevel + 5)
                                xpManager.userLevel = newLevel
                                // Reset XP to 0 when adding levels
                                xpManager.userXP = 0
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Add 5 Levels (Debug)")
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(addLevelsPressed ? 0.95 : 1.0)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !addLevelsPressed {
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                addLevelsPressed = true
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            addLevelsPressed = false
                                        }
                                    }
                            )
                            
                            Text("⚠️ Adds 5 levels to your current level (maximum level 25)")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.8))
                            
                            Divider()
                                .background(Color.white.opacity(0.3))
                                .padding(.vertical, 5)
                            
                            // Force Pairs Toggle for Split Testing
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Force Pairs (Split Testing)")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                    Text("Player gets pairs for splitting, dealer always busts")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Toggle("", isOn: .init(
                                    get: { UserDefaults.standard.bool(forKey: "debugForcePairs") },
                                    set: { 
                                        UserDefaults.standard.set($0, forKey: "debugForcePairs")
                                        // Reset deck when toggling to ensure fresh randomization
                                        if !$0 {
                                            print("🎲 Force Pairs DISABLED - Resetting deck for fresh randomization")
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }
                            
                            // Force 10s Toggle for High Value Testing
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Force 10s (High Value Testing)")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                    Text("Player and dealer get 10-value cards (10, J, Q, K)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Toggle("", isOn: .init(
                                    get: { UserDefaults.standard.bool(forKey: "debugForce10s") },
                                    set: { 
                                        UserDefaults.standard.set($0, forKey: "debugForce10s")
                                        // Reset deck when toggling to ensure fresh randomization
                                        if !$0 {
                                            print("🎲 Force 10s DISABLED - Resetting deck for fresh randomization")
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }
                            
                            // 8 Card for User (lowest ranks first)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("8 cards for player and dealer")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                    Text("Player and dealer draw fixed low sequence; reuse cards, skip discard pile")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Toggle("", isOn: .init(
                                    get: { UserDefaults.standard.bool(forKey: "debugEightCardUser") },
                                    set: { UserDefaults.standard.set($0, forKey: "debugEightCardUser") }
                                ))
                                .labelsHidden()
                            }
                            
                            // Force Blackjacks Toggle for Testing
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Force Blackjacks (Testing)")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                    Text("Player and dealer always get blackjack")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Toggle("", isOn: $forcedBlackjacks)
                                    .labelsHidden()
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.3))
                                .padding(.vertical, 5)
                            
                            // Add 10000 Chips Button for Testing
                            Button(action: {
                                XPChipManager.shared.updateChips(10000)
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Add 10000 Chips (Testing)")
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.green, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("💰 Adds 10000 chips to your current balance for testing")
                                .font(.caption)
                                .foregroundColor(.green.opacity(0.8))
                        }
                    }
                            }
            .padding()
        }
        .disableDynamicType()
    }
        .navigationTitle("Settings")
    }
}

struct SettingsSection<Content: View>: View {
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

#Preview {
    NavigationView {
        SettingsView()
    }
} 