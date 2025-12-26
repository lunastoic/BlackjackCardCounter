import SwiftUI

struct MapSelectionView: View {
    @State private var selectedIndex: Int = 0
    @State private var unlockingMapID: Int? = nil // Track which map is currently unlocking
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
            Color(hex: "8B0000")
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                GameHeaderView()
                
                Text("Select Map")
                    .font(.fixedSystem(size: 27, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                Spacer().frame(height: 20)

                // ===== Polished MapCarouselView =====
                if #available(iOS 16.0, *) {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        // iPad-specific carousel that forces initial position but allows updates
                        MapCarouselView(
                            maps: maps,
                            selectedIndex: Binding(
                                get: { selectedIndex },
                                set: { newValue in
                                    // Only allow index 0 (Luna Luxe Casino) for iPad
                                    if newValue == 0 {
                                        selectedIndex = newValue
                                    }
                                }
                            ),
                            unlockingMapID: $unlockingMapID,
                            onUnlock: { map in
                                if xpManager.userLevel >= map.requiredLevel {
                                    unlockMap(map)
                                }
                            }
                        )
                        .frame(height: 520)
                        .onAppear {
                            // Force iPad to start at index 0
                            selectedIndex = 0
                        }
                    } else {
                        // iPhone carousel with normal behavior
                        MapCarouselView(
                            maps: maps,
                            selectedIndex: $selectedIndex,
                            unlockingMapID: $unlockingMapID,
                            onUnlock: { map in
                                if xpManager.userLevel >= map.requiredLevel {
                                    unlockMap(map)
                                }
                            }
                        )
                        .frame(height: 520)
                    }


                } else {
                    // Fallback for older iOS versions
                    Text("iOS 16+ Required")
                        .foregroundColor(.white)
                        .frame(height: 520)
                }
                // =============================================

                Spacer()
            }
            .padding(.horizontal, 0)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .disableDynamicType()
            .onAppear {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    selectedIndex = 0
                    // Force it again after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        selectedIndex = 0
                    }
                }
            }

        }
    }
}

// MARK: - MapCard (original layout + tap responsiveness + 0.8s unlock icon + 2× thicker black border)

struct MapCard: View {
    let map: Map
    let isSelected: Bool
    let unlockedMaps: String
    var unlockingMapID: Binding<Int?>? = nil // Managed by parent to survive re-renders
    @ObservedObject var xpManager: XPChipManager
    let onTap: () -> Void
    let unlockAction: () -> Void

    @State private var isUnlocking = false
    @State private var wasUnlocked = false
    @State private var localUnlocked = false
    @State private var isShaking = false
    @State private var showUnlockAsset = false // Still used for local state if binding not provided
    @State private var unlockInProgress = false // Separate flag to prevent multiple taps

    // For crisp hairline borders scaled to device pixels
    @Environment(\.displayScale) private var displayScale
    private let imageBorderWidth: CGFloat = 2 // 2× thicker than the previous 1px hairline

    // Combine app storage + local transition state
    private var unlocked: Bool {
        let appStorageUnlocked = unlockedMaps.split(separator: ",").compactMap { Int($0) }.contains(map.id)
        return localUnlocked || appStorageUnlocked
    }
    
    // Computed property for map card background
    private var mapCardBackground: AnyShapeStyle {
        if map.name == "Luna Luxe Casino" {
            return AnyShapeStyle(Color.clear) // Clear background for Luna Luxe Casino to use Map1Back asset
        } else if map.name == "Io Inferno Lounge" {
            return AnyShapeStyle(Color.clear) // Clear background for Io Inferno Lounge to use Map2B asset
        } else if map.name == "Europa Ice Palace" {
            return AnyShapeStyle(Color.clear) // Clear background for Europa Ice Palace to use Map3B asset
        } else if map.name == "Titan Methane Mirage" {
            return AnyShapeStyle(Color.clear) // Clear background for Titan Methane Mirage to use Map5B asset
        } else if map.name == "Ganymede Grand" {
            return AnyShapeStyle(Color.clear) // Clear background for Ganymede Grand to use Map4B asset
        } else if map.name == "Kepler Fortune" {
            return AnyShapeStyle(Color.clear) // Clear background for Kepler Fortune to use Map6B asset
        } else {
            return AnyShapeStyle(getMapColor(for: map))
        }
    }

    var body: some View {
        ZStack {
            // Background for Luna Luxe Casino
            if unlocked && map.name == "Luna Luxe Casino" {
                Image("Map1Back")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 480)
                    .rotationEffect(.degrees(180))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
            
            // Background for Io Inferno Lounge
            if unlocked && map.name == "Io Inferno Lounge" {
                Image("Map2B")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 480)
                    .rotationEffect(.degrees(180))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
            
            // Background for Europa Ice Palace
            if unlocked && map.name == "Europa Ice Palace" {
                Image("Map3B")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 480)
                    .rotationEffect(.degrees(180))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
            
            // Background for Titan Methane Mirage
            if unlocked && map.name == "Titan Methane Mirage" {
                Image("Map5B")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 480)
                    .rotationEffect(.degrees(180))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
            
            // Background for Ganymede Grand
            if unlocked && map.name == "Ganymede Grand" {
                Image("Map4B")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 480)
                    .rotationEffect(.degrees(180))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
            
            // Background for Kepler Fortune
            if unlocked && map.name == "Kepler Fortune" {
                Image("Map6B")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 480)
                    .rotationEffect(.degrees(180))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
            
            // Black background card only for unlocked maps to create border effect
            if unlocked && map.name != "Luna Luxe Casino" && map.name != "Io Inferno Lounge" && map.name != "Europa Ice Palace" && map.name != "Titan Methane Mirage" && map.name != "Ganymede Grand" && map.name != "Kepler Fortune" {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.black)
                    .allowsHitTesting(false)
            }
            
            // Keep the locked overlay visible either while still locked OR while we are showing the unlock asset.
            // Drop isUnlocking from the condition so the unlock asset never disappears mid-transition.
            // Keep overlay visible if: we're showing unlock asset OR map is still locked
            // CRITICAL: showUnlockAsset takes absolute priority - if true, overlay MUST stay visible
            if showUnlockAsset || (unlockingMapID?.wrappedValue == map.id) || !unlocked {
                // Locked state: full-bleed image + dark overlay + lock/unlock swap
                Image(map.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .opacity(1)

                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.black.opacity(0.5))
                    .allowsHitTesting(false)
                    .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)

                VStack(spacing: 10) {
                    Spacer()

                    ZStack {
                        // Debug overlay - invisible but ensures clickable area
                        Rectangle()
                            .fill(Color.red.opacity(0.0))
                            .frame(width: 162, height: 162)
                        
                        // Simple direct replacement: show unlock OR lock, not both
                        // Use both local state and parent-managed state to ensure it survives re-renders
                        if showUnlockAsset || (unlockingMapID?.wrappedValue == map.id) {
                            Image("unlock")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 162, height: 162)
                                .shadow(color: .white.opacity(0.8), radius: 20, x: 0, y: 0)
                                .transaction { $0.animation = nil }
                        } else {
                            Image("Lock")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 162, height: 162)
                            .offset(x: isShaking ? 8 : 0)
                                .shadow(color: .white.opacity(0.8), radius: 20, x: 0, y: 0)
                                .transaction { $0.animation = nil }
                        }
                    }
                    .frame(width: 162, height: 162)
                    .background(Color.blue.opacity(0.0)) // Invisible debug indicator
                    .contentShape(Rectangle()) // Ensure entire area is tappable
                    .zIndex(2000)
                    .onTapGesture {
                        // BULLETPROOF: Prevent ANY interaction during unlock process
                        guard !unlockInProgress else { return }
                        guard !isUnlocking else { return }
                        guard !showUnlockAsset else { return }
                        
                        if xpManager.userLevel >= map.requiredLevel {
                            // CRITICAL: Set ALL flags immediately to prevent any other taps
                            unlockInProgress = true
                            showUnlockAsset = true
                            unlockingMapID?.wrappedValue = map.id // Set parent-managed state
                            isUnlocking = true

                            // Hold unlock asset for 0.6s, then unlock the map
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                // CRITICAL: Re-confirm flags are still set
                                if !showUnlockAsset || !unlockInProgress {
                                    // Something reset them - restore immediately
                                    showUnlockAsset = true
                                    unlockingMapID?.wrappedValue = map.id
                                    unlockInProgress = true
                                }
                                
                                // Unlock the map
                                unlockAction()
                                localUnlocked = true
                                
                                // CRITICAL: Force unlock asset to stay visible - set it again
                                showUnlockAsset = true
                                unlockingMapID?.wrappedValue = map.id
                                unlockInProgress = true
                                
                                // Keep unlock asset visible as map reveals - don't reset isUnlocking yet
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    // Re-confirm unlock asset is still showing
                                    showUnlockAsset = true
                                    unlockingMapID?.wrappedValue = map.id
                                    unlockInProgress = true
                                    isUnlocking = false
                                }
                                
                                // Keep unlock asset visible for full reveal (0.4 second after unlock, total 1.0s from tap)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    // Only reset AFTER map is fully revealed
                                    showUnlockAsset = false
                                    if unlockingMapID?.wrappedValue == map.id {
                                        unlockingMapID?.wrappedValue = nil
                                    }
                                    unlockInProgress = false
                                }
                            }
                        } else {
                            // Shake the lock to indicate insufficient level (left-right "no")
                            withAnimation(.easeInOut(duration: 0.07).repeatCount(5, autoreverses: true)) {
                                isShaking = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                isShaking = false
                            }
                        }
                    }
                    .zIndex(1000)

                    Text(map.name)
                        .font(.fixedSystem(size: 19, weight: .bold))
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
                .frame(width: 300, height: 480)
                .background(Color.clear)
            } else {
                // Unlocked: themed rounded card + name + image box + per-map buttons
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // Top: name + image with a 2× thicker black border around the image
                    VStack(spacing: 8) {
                        Text(map.name)
                                .font(.fixedSystem(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 30)
                            .padding(.horizontal, 8)
                                .offset(y: 3)

                        ZStack {
                            if map.name == "Luna Luxe Casino" {
                                // Black background for Luna Luxe Casino image
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.3))
                                    .frame(height: 160)
                                    .frame(maxWidth: .infinity)
                            } else {
                                // Black background for other maps
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.3))
                                .frame(height: 160)
                                    .frame(maxWidth: .infinity)
                            }

                            Image(map.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        (map.name == "Luna Luxe Casino" || map.name == "Io Inferno Lounge" || map.name == "Europa Ice Palace" || map.name == "Titan Methane Mirage" || map.name == "Ganymede Grand" || map.name == "Kepler Fortune")
                                        ? RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(hex: "FFD700"),  // Bright gold
                                                        Color(hex: "FFA500"),  // Orange gold
                                                        Color(hex: "FFD700")   // Bright gold
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.0
                                            )
                                        : nil
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
                                    ZStack {
                                        Image("Map1B1")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "book")
                                                .font(.fixedSystem(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Training Mode")
                                                    .font(.fixedSystem(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Learn with visuals and tutorials")
                                                    .font(.fixedSystem(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                    }
                                }
                                
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    ZStack {
                                        Image("Map1B1")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "play")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Regular Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Classic casino experience")
                                                .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                            }
                                        .padding()
                                    }
                                }
                                
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    ZStack {
                                        Image("Map1B1")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "questionmark.circle")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Quiz Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Test your knowledge")
                                                .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                    }
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
                                    ZStack {
                                        Image("Map2B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "book")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Training Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Learn with visuals and tutorials")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    ZStack {
                                        Image("Map2B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "play")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Regular Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Classic casino experience")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    ZStack {
                                        Image("Map2B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "questionmark.circle")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Quiz Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Test your knowledge")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
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
                                    ZStack {
                                        Image("Map3B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "book")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Training Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Learn with visuals and tutorials")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    ZStack {
                                        Image("Map3B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "play")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Regular Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Classic casino experience")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    ZStack {
                                        Image("Map3B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "questionmark.circle")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Quiz Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Test your knowledge")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
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
                                    ZStack {
                                        Image("Map4B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "book")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Training Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Learn with visuals and tutorials")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    ZStack {
                                        Image("Map4B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "play")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Regular Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Classic casino experience")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    ZStack {
                                        Image("Map4B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "questionmark.circle")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Quiz Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Test your knowledge")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
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
                                    ZStack {
                                        Image("Map5B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "book")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Training Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Learn with visuals and tutorials")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    ZStack {
                                        Image("Map5B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "play")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Regular Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Classic casino experience")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    ZStack {
                                        Image("Map5B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "questionmark.circle")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Quiz Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Test your knowledge")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
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
                                    ZStack {
                                        Image("Map6B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "book")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Training Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Learn with visuals and tutorials")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: RegularModeView(map: map)) {
                                    ZStack {
                                        Image("Map6B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "play")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Regular Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Classic casino experience")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                NavigationLink(destination: QuizModeView(map: map)) {
                                    ZStack {
                                        Image("Map6B2")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 60)
                                        
                                        HStack {
                                            Image(systemName: "questionmark.circle")
                                                .font(.system(size: 23, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading) {
                                                Text("Quiz Mode")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Test your knowledge")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                    }
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
                .frame(width: 297, height: 476)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(mapCardBackground)
                )
            }
        }
        .frame(width: 300, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: (map.name == "Luna Luxe Casino" || map.name == "Io Inferno Lounge" || map.name == "Europa Ice Palace" || map.name == "Titan Methane Mirage" || map.name == "Ganymede Grand" || map.name == "Kepler Fortune") ? 12 : 32))
        .overlay(
            // Max bet text for all maps - positioned as overlay to not affect title
            // Only show when map is fully unlocked AND unlock asset is not showing
            Group {
                if unlocked && !showUnlockAsset && unlockingMapID?.wrappedValue != map.id && map.name == "Luna Luxe Casino" {
                    Text("Max bet: $1000")
                        .font(.fixedSystem(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .offset(y: -17)
                } else if unlocked && !showUnlockAsset && unlockingMapID?.wrappedValue != map.id && map.name == "Io Inferno Lounge" {
                    Text("Max bet: $5000")
                        .font(.fixedSystem(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .offset(y: -17)
                } else if unlocked && !showUnlockAsset && unlockingMapID?.wrappedValue != map.id && map.name == "Europa Ice Palace" {
                    Text("Max bet: $10,000")
                        .font(.fixedSystem(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .offset(y: -17)
                } else if unlocked && !showUnlockAsset && unlockingMapID?.wrappedValue != map.id && map.name == "Ganymede Grand" {
                    Text("Max bet: $50,000")
                        .font(.fixedSystem(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .offset(y: -17)
                } else if unlocked && !showUnlockAsset && unlockingMapID?.wrappedValue != map.id && map.name == "Titan Methane Mirage" {
                    Text("Max bet: $250,000")
                        .font(.fixedSystem(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .offset(y: -17)
                } else if unlocked && !showUnlockAsset && unlockingMapID?.wrappedValue != map.id && map.name == "Kepler Fortune" {
                    Text("Max bet: $1,000,000")
                        .font(.fixedSystem(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .offset(y: -17)
                }
            }
        )
        .contentShape(Rectangle())
        // Use simultaneousGesture so it doesn't steal taps from the mode NavigationLinks.
        .simultaneousGesture(TapGesture().onEnded {
            if unlocked {
                onTap()
            }
        })
        .onAppear { 
            // Preserve state during unlock transition; just capture current unlocked state
            wasUnlocked = unlocked
            // Don't reset showUnlockAsset on appear - let the unlock process handle it
        }
        .onChange(of: unlocked) { newValue in
            // CRITICAL: If unlockInProgress is true, tap handler owns everything - DO ABSOLUTELY NOTHING
            if unlockInProgress {
                // Tap handler is in control - do NOTHING, don't touch ANY state
                wasUnlocked = newValue
                return
            }
            
            // Only handle external unlocks (not from tap)
            if newValue && !wasUnlocked && !unlockInProgress {
                // External unlock - handle it
                unlockInProgress = true
                showUnlockAsset = true
                unlockingMapID?.wrappedValue = map.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showUnlockAsset = false
                    if unlockingMapID?.wrappedValue == map.id {
                        unlockingMapID?.wrappedValue = nil
                    }
                    unlockInProgress = false
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

