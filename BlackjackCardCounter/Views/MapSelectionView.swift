import SwiftUI

struct MapSelectionView: View {
    @State private var selectedIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @ObservedObject private var xpManager = XPChipManager.shared
    @AppStorage("unlockedMaps") private var unlockedMaps: String = "1" // comma-separated IDs, 1 is always unlocked
    
    let maps: [Map] = [
        Map(id: 1, name: "Luna Luxe Casino", imageName: "RealLunaLuxe", isLocked: false, requiredLevel: 1),
        Map(id: 2, name: "Io Inferno Lounge", imageName: "RealLounge", isLocked: false, requiredLevel: 5),
        Map(id: 3, name: "Europa Ice Palace", imageName: "RealEuropa", isLocked: false, requiredLevel: 10),
        Map(id: 4, name: "Ganymede Grand", imageName: "Ganymede", isLocked: false, requiredLevel: 15),
        Map(id: 5, name: "Titan Methane Mirage", imageName: "TitanMethane", isLocked: false, requiredLevel: 20),
        Map(id: 6, name: "Kelper Fortune", imageName: "KelperFortune", isLocked: false, requiredLevel: 25)
    ]
    
    private func isUnlocked(_ map: Map) -> Bool {
        unlockedMaps.split(separator: ",").compactMap { Int($0) }.contains(map.id)
    }
    private func unlockMap(_ map: Map) {
        var ids = Set(unlockedMaps.split(separator: ",").compactMap { Int($0) })
        ids.insert(map.id)
        unlockedMaps = ids.sorted().map { String($0) }.joined(separator: ",")
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "1a3a1a"), Color(hex: "2d5a2d")]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                // Game Header
                GameHeaderView()
                
                Text("Select Map")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                Spacer().frame(height: 20)
                // Carousel
                GeometryReader { geometry in
                    let cardWidth: CGFloat = 300
                    let cardHeight: CGFloat = 420
                    let spacing: CGFloat = 36
                    let totalWidth = CGFloat(maps.count) * (cardWidth + spacing)
                    let baseOffset = (geometry.size.width - cardWidth) / 2
                    let calculatedOffset = baseOffset - CGFloat(selectedIndex) * (cardWidth + spacing) + dragOffset
                    HStack(spacing: spacing) {
                        ForEach(maps.indices, id: \ .self) { i in
                            let map = maps[i]
                            let isSelected = i == selectedIndex
                            let unlocked = isUnlocked(map)
                            MapCard(map: map, isSelected: isSelected, unlocked: unlocked) {
                                if unlocked {
                                    selectedIndex = i
                                } else if xpManager.userLevel >= map.requiredLevel {
                                    unlockMap(map)
                                }
                            }
                            .frame(width: cardWidth, height: cardHeight)
                            .opacity(isSelected ? 1.0 : 0.6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                        }
                    }
                    .frame(width: totalWidth, alignment: .leading)
                    .offset(x: calculatedOffset)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let cardWidthWithSpacing = cardWidth + spacing
                                let velocity = value.predictedEndTranslation.width - value.translation.width
                                let shouldAdvance = abs(velocity) > 50 || abs(value.translation.width) > cardWidthWithSpacing / 2
                                var newIndex = selectedIndex
                                if shouldAdvance {
                                    if value.translation.width < 0 && selectedIndex < maps.count - 1 {
                                        newIndex += 1
                                    } else if value.translation.width > 0 && selectedIndex > 0 {
                                        newIndex -= 1
                                    }
                                }
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                    selectedIndex = newIndex
                                }
                            }
                    )
                }
                .frame(height: 440)
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<maps.count, id: \ .self) { index in
                        Rectangle()
                            .fill(index == selectedIndex ? Color.white : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .padding(.bottom, 20)
                Spacer()
            }
            .padding(.horizontal, 0)
            .frame(maxWidth: 800) // Limit width on larger screens
            .frame(maxWidth: .infinity) // Center the content
        }
    }
}

struct MapCard: View {
    let map: Map
    let isSelected: Bool
    let unlocked: Bool
    let onTap: () -> Void
    @State private var isUnlocking = false
    @State private var wasUnlocked = false
    var body: some View {
        ZStack {
            if !unlocked || isUnlocking {
                // Locked state: show zoomed image, overlay, and lock
                Image(map.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.black.opacity(isUnlocking ? 0 : 0.5))
                    .animation(.easeInOut(duration: 0.5), value: isUnlocking)
                VStack(spacing: 10) {
                    Spacer()
                    Image("LockedLock")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 162, height: 162)
                        .opacity(isUnlocking ? 0 : 1)
                        .scaleEffect(isUnlocking ? 2 : 1)
                        .animation(.easeInOut(duration: 0.5), value: isUnlocking)
                    Text(map.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(isUnlocking ? 0 : 1)
                        .animation(.easeInOut(duration: 0.5), value: isUnlocking)
                    Text("Unlocks at Level \(map.requiredLevel)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                        .opacity(isUnlocking ? 0 : 1)
                        .animation(.easeInOut(duration: 0.5), value: isUnlocking)
                    Spacer()
                }
            } else {
                // Unlocked state: show normal card and buttons
                RoundedRectangle(cornerRadius: 32)
                    .fill(getMapColor(for: map))
                VStack(spacing: 0) {
                    // Top half: name and image
                    VStack(spacing: 8) {
                        Text(map.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 30)
                            .padding(.horizontal, 8)
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.3))
                                .frame(height: 160)
                            Image(map.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 18)
                    }
                    .frame(height: 170)
                    Spacer(minLength: 40)
                    if unlocked {
                        if map.name == "Luna Luxe Casino" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                    GameModeButton(title: "Training Mode", description: "Learn with visuals and tutorials", systemImage: "book.fill")
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    GameModeButton(title: "Regular Mode", description: "Classic casino experience", systemImage: "play.fill")
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    GameModeButton(title: "Quiz Mode", description: "Test your knowledge", systemImage: "questionmark.circle.fill")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                        } else if map.name == "Io Inferno Lounge" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Training Mode",
                                        description: "Learn with visuals and tutorials",
                                        systemImage: "book.fill",
                                        gradient: Gradient(colors: [Color.orange.opacity(0.85), Color.orange.opacity(0.65)]),
                                        iconColor: .orange
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Regular Mode",
                                        description: "Classic casino experience",
                                        systemImage: "play.fill",
                                        gradient: Gradient(colors: [Color.orange.opacity(0.85), Color.orange.opacity(0.65)]),
                                        iconColor: .orange
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Quiz Mode",
                                        description: "Test your knowledge",
                                        systemImage: "questionmark.circle.fill",
                                        gradient: Gradient(colors: [Color.orange.opacity(0.85), Color.orange.opacity(0.65)]),
                                        iconColor: .orange
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                        } else if map.name == "Europa Ice Palace" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Training Mode",
                                        description: "Learn with visuals and tutorials",
                                        systemImage: "book.fill",
                                        gradient: Gradient(colors: [Color(hex: "00eaff"), Color(hex: "00eaff")]),
                                        iconColor: Color(hex: "00eaff")
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Regular Mode",
                                        description: "Classic casino experience",
                                        systemImage: "play.fill",
                                        gradient: Gradient(colors: [Color(hex: "00eaff"), Color(hex: "00eaff")]),
                                        iconColor: Color(hex: "00eaff")
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Quiz Mode",
                                        description: "Test your knowledge",
                                        systemImage: "questionmark.circle.fill",
                                        gradient: Gradient(colors: [Color(hex: "00eaff"), Color(hex: "00eaff")]),
                                        iconColor: Color(hex: "00eaff")
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                        } else if map.name == "Ganymede Grand" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                    LiquidGlassGameModeButton(
                                        title: "Training Mode",
                                        description: "Learn with visuals and tutorials",
                                        systemImage: "book.fill",
                                        color: Color.purple
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    LiquidGlassGameModeButton(
                                        title: "Regular Mode",
                                        description: "Classic casino experience",
                                        systemImage: "play.fill",
                                        color: Color.purple
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    LiquidGlassGameModeButton(
                                        title: "Quiz Mode",
                                        description: "Test your knowledge",
                                        systemImage: "questionmark.circle.fill",
                                        color: Color.purple
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                        } else if map.name == "Titan Methane Mirage" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                    LiquidGlassGameModeButton(
                                        title: "Training Mode",
                                        description: "Learn with visuals and tutorials",
                                        systemImage: "book.fill",
                                        color: Color.green
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    LiquidGlassGameModeButton(
                                        title: "Regular Mode",
                                        description: "Classic casino experience",
                                        systemImage: "play.fill",
                                        color: Color.green
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    LiquidGlassGameModeButton(
                                        title: "Quiz Mode",
                                        description: "Test your knowledge",
                                        systemImage: "questionmark.circle.fill",
                                        color: Color.green
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                        } else if map.name == "Europa Ice Palace" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Training Mode",
                                        description: "Learn with visuals and tutorials",
                                        systemImage: "book.fill",
                                        gradient: Gradient(colors: [Color(hex: "007AFF").opacity(0.85), Color(hex: "007AFF").opacity(0.65)]),
                                        iconColor: Color(hex: "007AFF")
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Regular Mode",
                                        description: "Classic casino experience",
                                        systemImage: "play.fill",
                                        gradient: Gradient(colors: [Color(hex: "007AFF").opacity(0.85), Color(hex: "007AFF").opacity(0.65)]),
                                        iconColor: Color(hex: "007AFF")
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Quiz Mode",
                                        description: "Test your knowledge",
                                        systemImage: "questionmark.circle.fill",
                                        gradient: Gradient(colors: [Color(hex: "007AFF").opacity(0.85), Color(hex: "007AFF").opacity(0.65)]),
                                        iconColor: Color(hex: "007AFF")
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                        } else {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Training Mode",
                                        description: "Learn with visuals and tutorials",
                                        systemImage: "book.fill",
                                        gradient: Gradient(colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.8)]),
                                        iconColor: .cyan
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Regular Mode",
                                        description: "Classic casino experience",
                                        systemImage: "play.fill",
                                        gradient: Gradient(colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.7)]),
                                        iconColor: .yellow
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    NeonGameModeButton(
                                        title: "Quiz Mode",
                                        description: "Test your knowledge",
                                        systemImage: "questionmark.circle.fill",
                                        gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.indigo.opacity(0.8)]),
                                        iconColor: .purple
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                        }
                    }
                }
                // Overlay for locked maps (other than Europa Ice Palace)
                if !unlocked && map.name != "Europa Ice Palace" {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.black.opacity(0.5))
                    VStack(spacing: 10) {
                        Spacer()
                        Image("LockedLock")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 162, height: 162)
                        Text(map.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("Unlocks at Level \(map.requiredLevel)")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
        .onTapGesture { onTap() }
        .frame(width: 300, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .onAppear { wasUnlocked = unlocked }
        .onChange(of: unlocked) { newValue in
            if newValue && !wasUnlocked {
                isUnlocking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isUnlocking = false
                }
            }
            wasUnlocked = newValue
        }
    }
    // Helper for vibrant color
    func getMapColor(for map: Map) -> Color {
        switch map.name {
            case "Luna Luxe Casino": return Color(hex: "23272a")
            case "Io Inferno Lounge": return Color(hex: "FF4B2B")
            case "Europa Ice Palace": return Color(hex: "00B4DB")
            case "Ganymede Grand": return Color(hex: "834d9b")
            case "Titan Methane Mirage": return Color(hex: "56ab2f")
            case "Kelper Fortune": return Color(hex: "FFD700")
            default: return Color(hex: "23272a")
        }
    }
}

struct NeonGameModeButton: View {
    let title: String
    let description: String
    let systemImage: String
    let gradient: Gradient
    let iconColor: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(iconColor)
                .font(.title3.bold())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(iconColor.opacity(0.7), lineWidth: 2)
                .shadow(color: iconColor.opacity(0.7), radius: 8, x: 0, y: 0)
        )
        .shadow(color: iconColor.opacity(0.4), radius: 12, x: 0, y: 0)
    }
}

struct LiquidGlassGameModeButton: View {
    let title: String
    let description: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.white)
                .font(.title3.bold())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            ZStack {
                // Base glass background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.15),
                                color.opacity(0.08)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Glass blur effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .blendMode(.overlay)
                
                // Subtle inner glow
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.3),
                                color.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Highlight for glass effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.4),
                            color.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    NavigationView {
        MapSelectionView()
    }
} 
