import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("dealerSpeed") private var dealerSpeed = 1.0
    @AppStorage("vibrationEnabled") private var vibrationEnabled = true
    
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
                            
                            Text("⚠️ This will lock all maps except the first one")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                            
                            Divider()
                                .background(Color.white.opacity(0.3))
                                .padding(.vertical, 5)
                            
                            // Force Pairs Toggle for Split Testing
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Force Pairs (Split Testing)")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                    Text("Always deal pairs for testing split functionality")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Toggle("", isOn: .init(
                                    get: { UserDefaults.standard.bool(forKey: "debugForcePairs") },
                                    set: { UserDefaults.standard.set($0, forKey: "debugForcePairs") }
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
                                    set: { UserDefaults.standard.set($0, forKey: "debugForce10s") }
                                ))
                                .labelsHidden()
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.3))
                                .padding(.vertical, 5)
                            
                            // Add 3000 Chips Button for Testing
                            Button(action: {
                                XPChipManager.shared.updateChips(3000)
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Add 3000 Chips (Testing)")
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
                            
                            Text("💰 Adds 3000 chips to your current balance for testing")
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