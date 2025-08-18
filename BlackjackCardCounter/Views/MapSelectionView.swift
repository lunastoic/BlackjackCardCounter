import SwiftUI
 // testtt
struct MapSelectionView: View {
    @State private var selectedIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @ObservedObject private var xpManager = XPChipManager.shared
    @AppStorage("unlockedMaps") private var unlockedMaps: String = "1" // 1 is always unlocked
    
    let maps: [Map] = [
        Map(id: 1, name: "Luna Luxe Casino",       imageName: "RealLunaLuxe",  isLocked: false, requiredLevel: 1),
        Map(id: 2, name: "Io Inferno Lounge",       imageName: "RealLounge",    isLocked: false, requiredLevel: 5),
        Map(id: 3, name: "Europa Ice Palace",       imageName: "RealEuropa",    isLocked: false, requiredLevel: 10),
        Map(id: 4, name: "Ganymede Grand",          imageName: "Ganymede",      isLocked: false, requiredLevel: 15),
        Map(id: 5, name: "Titan Methane Mirage",    imageName: "TitanMethane",  isLocked: false, requiredLevel: 20),
        Map(id: 6, name: "Kepler Fortune",          imageName: "Kepler", isLocked: false, requiredLevel: 25)
    ]
    
    private func isUnlocked(_ map: Map) -> Bool {
        unlockedMaps.split(separator: ",").compactMap { Int($0) }.contains(map.id)
    }

    private func unlockMap(_ map: Map) {
        var ids = Set(unlockedMaps.split(separator: ",").compactMap { Int($0) })
        ids.insert(map.id)
        unlockedMaps = ids.sorted().map(String.init).joined(separator: ",")
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1a3a1a"), Color(hex: "2d5a2d")]),
                startPoint: .top, endPoint: .bottom
            )
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                GameHeaderView()
                
                Text("Select Map")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)

                Spacer().frame(height: 20)

                // ===== Original custom carousel (GeometryReader + HStack + drag) =====
                GeometryReader { geometry in
                    let cardWidth: CGFloat = 300
                    let cardHeight: CGFloat = 420
                    let spacing: CGFloat = 36
                    let totalWidth = CGFloat(maps.count) * (cardWidth + spacing)
                    let baseOffset = (geometry.size.width - cardWidth) / 2
                    let indexOffset = CGFloat(selectedIndex) * (cardWidth + spacing)
                    let calculatedOffset = baseOffset - indexOffset + dragOffset

                    HStack(alignment: .center, spacing: spacing) {
                        ForEach(maps.indices, id: \.self) { i in
                            let map = maps[i]
                            let isSelected = i == selectedIndex

                            MapCard(
                                map: map,
                                isSelected: isSelected,
                                unlockedMaps: unlockedMaps,
                                xpManager: xpManager,
                                onTap: { selectedIndex = i },
                                unlockAction: {
                                    if xpManager.userLevel >= map.requiredLevel {
                                    unlockMap(map)
                                }
                            }
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            .opacity(isSelected ? 1.0 : 0.6)
                            .scaleEffect(isSelected ? 1.0 : 0.95)
                            .animation(.easeInOut(duration: 0.3), value: selectedIndex)
                            .id("\(map.id)-\(unlockedMaps)") // force refresh on unlock
                        }
                    }
                    .frame(width: totalWidth, alignment: .leading)
                    .offset(x: calculatedOffset)
                    // Improved drag gesture with better snapping logic
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let cardWidthWithSpacing = cardWidth + spacing
                                let dragDistance = value.translation.width
                                
                                // Simplified snapping logic - just use distance threshold
                                let threshold = cardWidthWithSpacing * 0.25 // 25% of card width
                                var newIndex = selectedIndex
                                
                                if abs(dragDistance) > threshold {
                                    if dragDistance < 0 && selectedIndex < maps.count - 1 {
                                        // Swiping left (next card)
                                        newIndex = selectedIndex + 1
                                    } else if dragDistance > 0 && selectedIndex > 0 {
                                        // Swiping right (previous card)
                                        newIndex = selectedIndex - 1
                                    }
                                }
                                
                                // Use clean animation without conflicts
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    selectedIndex = newIndex
                                }
                            }
                    )
                }
                .frame(height: 440)
                // ====================================================================

                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<maps.count, id: \.self) { index in
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
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - MapCard (original layout + tap responsiveness + 0.8s unlock icon + 2× thicker black border)

struct MapCard: View {
    let map: Map
    let isSelected: Bool
    let unlockedMaps: String
    @ObservedObject var xpManager: XPChipManager
    let onTap: () -> Void
    let unlockAction: () -> Void

    @State private var isUnlocking = false
    @State private var wasUnlocked = false
    @State private var showUnlockIcon = false
    @State private var localUnlocked = false

    // For crisp hairline borders scaled to device pixels
    @Environment(\.displayScale) private var displayScale
    private let imageBorderWidth: CGFloat = 2 // 2× thicker than the previous 1px hairline

    // Combine app storage + local transition state
    private var unlocked: Bool {
        let appStorageUnlocked = unlockedMaps.split(separator: ",").compactMap { Int($0) }.contains(map.id)
        return localUnlocked || appStorageUnlocked
    }

    var body: some View {
        ZStack {
            if !unlocked || isUnlocking {
                // Locked state: full-bleed image + dark overlay + lock button
                Image(map.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()

                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.black.opacity(isUnlocking ? 0 : 0.5))
                    .allowsHitTesting(false) // overlay is visual only; don't block taps
                    .animation(.easeInOut(duration: 0.5), value: isUnlocking)

                VStack(spacing: 10) {
                    Spacer()

                    ZStack {
                        // Debug overlay - invisible but ensures clickable area
                        Rectangle()
                            .fill(Color.red.opacity(0.0))
                            .frame(width: 162, height: 162)
                        
                        Image(showUnlockIcon ? "unlock" : "Lock")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 162, height: 162)
                        .opacity(isUnlocking ? 0 : 1)
                        .scaleEffect(isUnlocking ? 2 : 1)
                        .animation(.easeInOut(duration: 0.5), value: isUnlocking)
                    }
                    .frame(width: 162, height: 162)
                    .background(Color.blue.opacity(0.0)) // Invisible debug indicator
                    .contentShape(Rectangle()) // Ensure entire area is tappable
                    .onTapGesture {
                        guard !isUnlocking else { return }
                        guard !showUnlockIcon else { return }
                        guard xpManager.userLevel >= map.requiredLevel else { return }

                        // Show the "unlock" asset briefly, then reveal buttons
                        showUnlockIcon = true

                        // Wait 0.8s, then persist unlock and reveal
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                unlockAction()      // persist to AppStorage
                                localUnlocked = true
                                showUnlockIcon = false
                                // short fade to reveal unlocked card content
                                isUnlocking = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    isUnlocking = false
                                }
                            }
                        }
                    }
                    .zIndex(1000)

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
                // Unlocked: themed rounded card + name + image box + per-map buttons
                RoundedRectangle(cornerRadius: 32)
                    .fill(getMapColor(for: map))

                VStack(spacing: 0) {
                    // Top: name + image with a 2× thicker black border around the image
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
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    // 2× thicker thin black border hugging the clipped image shape
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.black.opacity(0.9), lineWidth: imageBorderWidth / displayScale)
                                )
                        }
                        .padding(.horizontal, 18)
                    }
                    .frame(height: 170)

                    Spacer(minLength: 40)

                    // Per-map themed buttons (same format you sent)
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
                        .opacity(1.0)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unlocked)
                        } else if map.name == "Io Inferno Lounge" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Training Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Learn with visuals and tutorials")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.orange.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Regular Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Classic casino experience")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.orange.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Quiz Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Test your knowledge")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.orange.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                        .opacity(1.0)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unlocked)
                        } else if map.name == "Europa Ice Palace" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Training Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Learn with visuals and tutorials")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color(hex: "00eaff").opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Regular Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Classic casino experience")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color(hex: "00eaff").opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Quiz Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Test your knowledge")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color(hex: "00eaff").opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                        .opacity(1.0)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unlocked)
                    } else if map.name == "Ganymede Grand" {
                            VStack(spacing: 14) {
                                NavigationLink(destination: TrainingModeView(map: map)) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Training Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Learn with visuals and tutorials")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.purple.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Regular Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Classic casino experience")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.purple.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Quiz Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Test your knowledge")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.purple.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 18)
                        .opacity(1.0)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unlocked)
                                            } else if map.name == "Titan Methane Mirage" {
                        VStack(spacing: 14) {
                            NavigationLink(destination: TrainingModeView(map: map)) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Training Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Learn with visuals and tutorials")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.green.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                            }
                            NavigationLink(destination: RegularModeView(map: map)) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Regular Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Classic casino experience")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.green.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                            }
                            NavigationLink(destination: QuizModeView(map: map)) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Quiz Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Test your knowledge")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.green.opacity(0.8))
                                        .shadow(radius: 5)
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 18)
                        .opacity(1.0)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unlocked)
                                            } else if map.name == "Kepler Fortune" {
                        VStack(spacing: 14) {
                            NavigationLink(destination: TrainingModeView(map: map)) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Training Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Learn with visuals and tutorials")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color(hex: "D4AF37").opacity(0.8))
                                        .shadow(radius: 5)
                                )
                            }
                            NavigationLink(destination: RegularModeView(map: map)) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Regular Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Classic casino experience")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                        Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color(hex: "D4AF37").opacity(0.8))
                                        .shadow(radius: 5)
                                )
                            }
                            NavigationLink(destination: QuizModeView(map: map)) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Quiz Mode")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Test your knowledge")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                        Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color(hex: "D4AF37").opacity(0.8))
                                        .shadow(radius: 5)
                                )
            }
        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 18)
                        .opacity(1.0)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unlocked)
                    }
                }
            }
        }
        .frame(width: 300, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .contentShape(Rectangle())
        .onTapGesture {
            if unlocked {
                onTap()
            }
        }
        .onAppear { wasUnlocked = unlocked }
        .onChange(of: unlocked) { newValue in
            if newValue && !wasUnlocked {
                isUnlocking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isUnlocking = false
                }
            }
            // Sync local with AppStorage so the card stays unlocked after reload
            let appStorageUnlocked = unlockedMaps.split(separator: ",").compactMap { Int($0) }.contains(map.id)
            if appStorageUnlocked { localUnlocked = true }
            wasUnlocked = newValue
        }
    }

    // Map theme color (unchanged)
    func getMapColor(for map: Map) -> Color {
        switch map.name {
        case "Luna Luxe Casino":      return Color(hex: "23272a")
        case "Io Inferno Lounge":     return Color(hex: "FF4B2B")
        case "Europa Ice Palace":     return Color(hex: "00B4DB")
        case "Ganymede Grand":        return Color(hex: "834d9b")
        case "Titan Methane Mirage":  return Color(hex: "56ab2f")
        case "Kepler Fortune":        return Color(hex: "FFD700")
        default:                      return Color(hex: "23272a")
        }
    }
}

// MARK: - Buttons (same components you had)

struct NeonGameModeButton: View {
    let title: String
    let description: String
    let systemImage: String
    let gradient: Gradient
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.white)
                .font(.title3.bold())
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .overlay(
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.title3)
                    .padding(.trailing, 26) // 16 (original) + 10 (move left) = 26
            }
        )
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
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .overlay(
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title3)
                    .padding(.trailing, 26) // 16 (original) + 10 (move left) = 26
            }
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            ZStack {
                // Single solid color background with fade
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.3))

                // Glass material effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .blendMode(.overlay)

                // Simple border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct LockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 162, height: 162) // Explicit size matching the image
            .background(Color.clear) // Clear background for full hit area
            .contentShape(Rectangle()) // Ensure entire rectangular area is tappable
            .scaleEffect(configuration.isPressed ? 0.7 : 1.0)
            .brightness(configuration.isPressed ? -0.3 : 0)
            .saturation(configuration.isPressed ? 0.7 : 1.0)
            .shadow(
                color: Color.white.opacity(configuration.isPressed ? 0.05 : 1.0),
                radius: configuration.isPressed ? 0 : 15,
                x: 0,
                y: configuration.isPressed ? 0 : 8
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.5 : 0.0), lineWidth: 4)
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationView {
        MapSelectionView()
    }
} 

