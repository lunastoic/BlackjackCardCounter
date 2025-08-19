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
    }
}

// MARK: - iOS 17+ Native ScrollView Implementation
@available(iOS 17.0, *)
private struct iOS17CarouselView: View {
    let maps: [Map]
    @Binding var selectedIndex: Int
    let unlockedMaps: String
    let xpManager: XPChipManager
    let onUnlock: (Map) -> Void
    
    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 420
    private let cardSpacing: CGFloat = 24
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: cardSpacing) {
                ForEach(maps.indices, id: \.self) { index in
                    let map = maps[index]
                    let isSelected = index == selectedIndex
                    
                    MapCard(
                        map: map,
                        isSelected: isSelected,
                        unlockedMaps: unlockedMaps,
                        xpManager: xpManager,
                        onTap: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedIndex = index
                            }
                        },
                        unlockAction: { onUnlock(map) }
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(isSelected ? 1.0 : 0.92)
                    .opacity(isSelected ? 1.0 : 0.75)
                    .animation(.easeInOut(duration: 0.3), value: selectedIndex)
                }
            }
            .padding(.horizontal, 50) // Add side padding for peek effect
            .padding(.vertical, 30) // Add more vertical padding to prevent clipping
        }
        .frame(height: cardHeight + 60) // Set explicit height for the scroll view
        .scrollIndicators(.hidden)
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
        collectionView.decelerationRate = .fast
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        
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
        
        // Scroll to selected index if needed
        DispatchQueue.main.async {
            let indexPath = IndexPath(item: selectedIndex, section: 0)
            if collectionView.numberOfItems(inSection: 0) > selectedIndex {
                collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            }
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
            
            return cell
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            updateSelectedIndex(from: scrollView)
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                updateSelectedIndex(from: scrollView)
            }
        }
        
        private func updateSelectedIndex(from scrollView: UIScrollView) {
            guard let collectionView = scrollView as? UICollectionView else { return }
            
            let centerPoint = CGPoint(
                x: scrollView.contentOffset.x + scrollView.frame.width / 2,
                y: scrollView.frame.height / 2
            )
            
            if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
                DispatchQueue.main.async {
                    self.selectedIndex.wrappedValue = indexPath.item
                }
            }
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