import SwiftUI
import UIKit

// MARK: - MapCarouselView
struct MapCarouselView: View {
    let maps: [Map]
    @Binding var selectedIndex: Int
    let onUnlock: (Map) -> Void
    
    @ObservedObject private var xpManager = XPChipManager.shared
    @AppStorage("unlockedMaps") private var unlockedMaps: String = "1"
    
    var body: some View {
        VStack(spacing: 0) {
            if #available(iOS 17.0, *) {
                iOS17CarouselView(
                    maps: maps,
                    selectedIndex: $selectedIndex,
                    unlockedMaps: unlockedMaps,
                    xpManager: xpManager,
                    onUnlock: onUnlock
                )
            } else {
                iOS16CarouselView(
                    maps: maps,
                    selectedIndex: $selectedIndex,
                    unlockedMaps: unlockedMaps,
                    xpManager: xpManager,
                    onUnlock: onUnlock
                )
                .frame(height: 480) // 420 (card height) + 60 (padding)
            }
            
            // Progress bars follow selectedIndex instantly
            HStack(spacing: 8) {
                ForEach(0..<maps.count, id: \.self) { index in
                    Rectangle()
                        .fill(index == selectedIndex ? Color.white : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 3)
                        .cornerRadius(1.5)
                        .animation(.easeInOut(duration: 0.12), value: selectedIndex)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - iOS 17+ Native ScrollView Implementation
@available(iOS 17.0, *)
private struct iOS17CarouselView: UIViewRepresentable {
    let maps: [Map]
    @Binding var selectedIndex: Int
    let unlockedMaps: String
    let xpManager: XPChipManager
    let onUnlock: (Map) -> Void
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = createLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        
        // Prevent vertical scrolling
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = true
        
        // Register cell
        collectionView.register(MapCardCell.self, forCellWithReuseIdentifier: "MapCard")
        
        return collectionView
    }
    
            func updateUIView(_ collectionView: UICollectionView, context: Context) {
            context.coordinator.updateData(
                maps: maps,
                selectedIndex: selectedIndex,
                unlockedMaps: unlockedMaps,
                xpManager: xpManager,
                onUnlock: onUnlock
            )
            
            collectionView.reloadData()
            

            
            // Start continuous scroll position monitoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.startTargetTimer(collectionView: collectionView)
            }
        }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedIndex: $selectedIndex)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(300),
            heightDimension: .absolute(420)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(300),
            heightDimension: .absolute(420)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 24
        section.contentInsets = NSDirectionalEdgeInsets(top: 30, leading: 50, bottom: 30, trailing: 50)
        
        // Add visible items invalidation for scaling effect
        section.visibleItemsInvalidationHandler = { items, offset, environment in
            let containerWidth = environment.container.contentSize.width
            let centerX = offset.x + containerWidth / 2
            
            for item in items {
                let itemCenterX = item.frame.midX
                let distance = abs(itemCenterX - centerX)
                let maxDistance = containerWidth / 3
                
                let scale = max(0.92, 1.0 - (distance / maxDistance) * 0.08)
                let alpha = max(0.75, 1.0 - (distance / maxDistance) * 0.25)
                
                item.transform = CGAffineTransform(scaleX: scale, y: scale)
                item.alpha = alpha
            }
        }
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        private var selectedIndex: Binding<Int>
        
        private var maps: [Map] = []
        private var unlockedMaps: String = ""
        private var xpManager: XPChipManager?
        private var onUnlock: ((Map) -> Void)?
        private var targetTimer: Timer?
        private var isUserScrolling = false
        
        init(selectedIndex: Binding<Int>) {
            self.selectedIndex = selectedIndex
        }
        
        func updateData(
            maps: [Map],
            selectedIndex: Int,
            unlockedMaps: String,
            xpManager: XPChipManager,
            onUnlock: @escaping (Map) -> Void
        ) {
            self.maps = maps
            self.unlockedMaps = unlockedMaps
            self.xpManager = xpManager
            self.onUnlock = onUnlock
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return maps.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapCard", for: indexPath) as! MapCardCell
            
            let map = maps[indexPath.item]
            let isSelected = indexPath.item == selectedIndex.wrappedValue
            
            cell.configure(
                map: map,
                isSelected: isSelected,
                unlockedMaps: unlockedMaps,
                xpManager: xpManager,
                onTap: { [weak self] in
                    self?.selectedIndex.wrappedValue = indexPath.item
                },
                onUnlock: { [weak self] in
                    self?.onUnlock?(map)
                }
            )
            
            // Add target tracking for real-time indicator updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkCardVisibility(collectionView: collectionView, indexPath: indexPath)
            }
            
            return cell
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            isUserScrolling = true
            
            // Update immediately during scroll for real-time tracking
            updateSelectedIndex(from: scrollView)
            
            // Force immediate update based on scroll position
            let scrollOffset = scrollView.contentOffset.x
            let cardWidth = 300.0
            let spacing = 24.0
            let totalCardWidth = cardWidth + spacing
            let estimatedIndex = Int(round(scrollOffset / totalCardWidth))
            
            if estimatedIndex >= 0 && estimatedIndex < maps.count && estimatedIndex != selectedIndex.wrappedValue {
                selectedIndex.wrappedValue = estimatedIndex
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserScrolling = true
            updateSelectedIndex(from: scrollView)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserScrolling = false
            updateSelectedIndex(from: scrollView)
            stopTargetTimer()
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserScrolling = false
                updateSelectedIndex(from: scrollView)
                stopTargetTimer()
            }
        }
        
        private func updateSelectedIndex(from scrollView: UIScrollView) {
            guard let collectionView = scrollView as? UICollectionView else { return }
            
            // Check all visible cells to find which one is most centered
            var bestIndex: Int?
            var bestDistance: CGFloat = .greatestFiniteMagnitude
            let screenCenter = collectionView.frame.width / 2
            
            for cell in collectionView.visibleCells {
                guard let indexPath = collectionView.indexPath(for: cell) else { continue }
                let cellFrame = cell.convert(cell.bounds, to: collectionView)
                let cellCenter = cellFrame.midX
                let distance = abs(cellCenter - screenCenter)
                
                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = indexPath.item
                }
            }
            
            if let newIndex = bestIndex, newIndex != self.selectedIndex.wrappedValue {
                self.selectedIndex.wrappedValue = newIndex
            }
        }
        
        private func checkCardVisibility(collectionView: UICollectionView, indexPath: IndexPath) {
            guard let cell = collectionView.cellForItem(at: indexPath) else { return }
            
            let cellFrame = cell.convert(cell.bounds, to: collectionView)
            let screenCenter = collectionView.frame.width / 2
            let cellCenter = cellFrame.midX
            let distance = abs(cellCenter - screenCenter)
            
            // If this card is closest to center, update selectedIndex
            if distance < 150 && indexPath.item != self.selectedIndex.wrappedValue {
                self.selectedIndex.wrappedValue = indexPath.item
            }
        }
        
        func startTargetTimer(collectionView: UICollectionView?) {
            targetTimer?.invalidate()
            targetTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let collectionView = collectionView else { return }
                
                // Only update if user is not actively scrolling
                if !self.isUserScrolling {
                    self.updateSelectedIndex(from: collectionView)
                }
            }
        }
        
        private func stopTargetTimer() {
            targetTimer?.invalidate()
            targetTimer = nil
        }
    }
}

// MARK: - iOS 16 UICollectionView Implementation
@available(iOS 16.0, *)
private struct iOS16CarouselView: UIViewRepresentable {
    let maps: [Map]
    @Binding var selectedIndex: Int
    let unlockedMaps: String
    let xpManager: XPChipManager
    let onUnlock: (Map) -> Void
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = createLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        
        // Prevent vertical scrolling
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = true
        
        // Register cell
        collectionView.register(MapCardCell.self, forCellWithReuseIdentifier: "MapCard")
        
        return collectionView
    }
    
            func updateUIView(_ collectionView: UICollectionView, context: Context) {
            context.coordinator.updateData(
                maps: maps,
                selectedIndex: selectedIndex,
                unlockedMaps: unlockedMaps,
                xpManager: xpManager,
                onUnlock: onUnlock
            )
            
            collectionView.reloadData()
            

            
            // Start continuous scroll position monitoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.startTargetTimer(collectionView: collectionView)
            }
        }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedIndex: $selectedIndex)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(300),
            heightDimension: .absolute(420)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(300),
            heightDimension: .absolute(420)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 24
        section.contentInsets = NSDirectionalEdgeInsets(top: 30, leading: 50, bottom: 30, trailing: 50)
        
        // Add visible items invalidation for scaling effect
        section.visibleItemsInvalidationHandler = { items, offset, environment in
            let containerWidth = environment.container.contentSize.width
            let centerX = offset.x + containerWidth / 2
            
            for item in items {
                let itemCenterX = item.frame.midX
                let distance = abs(itemCenterX - centerX)
                let maxDistance = containerWidth / 3
                
                let scale = max(0.92, 1.0 - (distance / maxDistance) * 0.08)
                let alpha = max(0.75, 1.0 - (distance / maxDistance) * 0.25)
                
                item.transform = CGAffineTransform(scaleX: scale, y: scale)
                item.alpha = alpha
            }
        }
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        private var selectedIndex: Binding<Int>
        
        private var maps: [Map] = []
        private var unlockedMaps: String = ""
        private var xpManager: XPChipManager?
        private var onUnlock: ((Map) -> Void)?
        private var targetTimer: Timer?
        private var isUserScrolling = false
        
        init(selectedIndex: Binding<Int>) {
            self.selectedIndex = selectedIndex
        }
        
        func updateData(
            maps: [Map],
            selectedIndex: Int,
            unlockedMaps: String,
            xpManager: XPChipManager,
            onUnlock: @escaping (Map) -> Void
        ) {
            self.maps = maps
            self.unlockedMaps = unlockedMaps
            self.xpManager = xpManager
            self.onUnlock = onUnlock
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return maps.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapCard", for: indexPath) as! MapCardCell
            
            let map = maps[indexPath.item]
            let isSelected = indexPath.item == selectedIndex.wrappedValue
            
            cell.configure(
                map: map,
                isSelected: isSelected,
                unlockedMaps: unlockedMaps,
                xpManager: xpManager,
                onTap: { [weak self] in
                    self?.selectedIndex.wrappedValue = indexPath.item
                },
                onUnlock: { [weak self] in
                    self?.onUnlock?(map)
                }
            )
            
            // Add target tracking for real-time indicator updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkCardVisibility(collectionView: collectionView, indexPath: indexPath)
            }
            
            return cell
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            isUserScrolling = true
            
            // Update immediately during scroll for real-time tracking
            updateSelectedIndex(from: scrollView)
            
            // Force immediate update based on scroll position
            let scrollOffset = scrollView.contentOffset.x
            let cardWidth = 300.0
            let spacing = 24.0
            let totalCardWidth = cardWidth + spacing
            let estimatedIndex = Int(round(scrollOffset / totalCardWidth))
            
            if estimatedIndex >= 0 && estimatedIndex < maps.count && estimatedIndex != selectedIndex.wrappedValue {
                selectedIndex.wrappedValue = estimatedIndex
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserScrolling = true
            updateSelectedIndex(from: scrollView)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserScrolling = false
            updateSelectedIndex(from: scrollView)
            stopTargetTimer()
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserScrolling = false
                updateSelectedIndex(from: scrollView)
                stopTargetTimer()
            }
        }
        
        private func updateSelectedIndex(from scrollView: UIScrollView) {
            guard let collectionView = scrollView as? UICollectionView else { return }
            
            // Check all visible cells to find which one is most centered
            var bestIndex: Int?
            var bestDistance: CGFloat = .greatestFiniteMagnitude
            let screenCenter = collectionView.frame.width / 2
            
            for cell in collectionView.visibleCells {
                guard let indexPath = collectionView.indexPath(for: cell) else { continue }
                let cellFrame = cell.convert(cell.bounds, to: collectionView)
                let cellCenter = cellFrame.midX
                let distance = abs(cellCenter - screenCenter)
                
                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = indexPath.item
                }
            }
            
            if let newIndex = bestIndex, newIndex != self.selectedIndex.wrappedValue {
                self.selectedIndex.wrappedValue = newIndex
            }
        }
        
        private func checkCardVisibility(collectionView: UICollectionView, indexPath: IndexPath) {
            guard let cell = collectionView.cellForItem(at: indexPath) else { return }
            
            let cellFrame = cell.convert(cell.bounds, to: collectionView)
            let screenCenter = collectionView.frame.width / 2
            let cellCenter = cellFrame.midX
            let distance = abs(cellCenter - screenCenter)
            
            // If this card is closest to center, update selectedIndex
            if distance < 150 && indexPath.item != self.selectedIndex.wrappedValue {
                self.selectedIndex.wrappedValue = indexPath.item
            }
        }
        
        func startTargetTimer(collectionView: UICollectionView?) {
            targetTimer?.invalidate()
            targetTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let collectionView = collectionView else { return }
                
                // Only update if user is not actively scrolling
                if !self.isUserScrolling {
                    self.updateSelectedIndex(from: collectionView)
                }
            }
        }
        
        private func stopTargetTimer() {
            targetTimer?.invalidate()
            targetTimer = nil
        }
    }
}

// MARK: - UICollectionViewCell for iOS 16
@available(iOS 16.0, *)
final class MapCardCell: UICollectionViewCell {
    private var hostingController: UIHostingController<AnyView>?
    
    func configure(
        map: Map,
        isSelected: Bool,
        unlockedMaps: String,
        xpManager: XPChipManager?,
        onTap: @escaping () -> Void,
        onUnlock: @escaping () -> Void
    ) {
        // Remove previous hosting controller
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        
        // Create SwiftUI view
        let mapCardView = MapCard(
            map: map,
            isSelected: isSelected,
            unlockedMaps: unlockedMaps,
            xpManager: xpManager ?? XPChipManager.shared,
            onTap: onTap,
            unlockAction: onUnlock
        )
        
        // Wrap in hosting controller
        let hostingController = UIHostingController(rootView: AnyView(mapCardView))
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = contentView.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        contentView.addSubview(hostingController.view)
        self.hostingController = hostingController
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
} 
