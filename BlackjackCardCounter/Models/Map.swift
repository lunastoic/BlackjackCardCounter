import Foundation
import SwiftUI

struct Map: Identifiable {
    let id: Int
    let name: String
    let imageName: String
    let isLocked: Bool
    let requiredLevel: Int
    let maxBet: Int
    
    // Asset configuration for each map
    var assetConfig: MapAssetConfiguration {
        switch id {
        case 1: // Luna Luxe Casino
            return MapAssetConfiguration(
                cardBackImage: "CardBack", // Update when you have the asset
                chipImages: [
                    1: "Chip_1",
                    5: "Chip_5",
                    25: "Chip_25",
                    50: "Chip_50",
                    100: "Chip_100"
                ],
                backgroundGradient: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                tableTexture: "Gray_Suede"
            )
        case 2: // Io Inferno Lounge
            return MapAssetConfiguration(
                cardBackImage: "CardBack", // Placeholder - update when asset is ready
                chipImages: [
                    5: "Inferno_5",
                    25: "Inferno_25",
                    50: "Inferno_50",
                    250: "Inferno_250",
                    500: "Inferno_500"
                ],
                backgroundGradient: [Color(hex: "1a1a2e"), Color(hex: "16213e")], // Placeholder
                tableTexture: "Orange_Suede"
            )
        case 3: // Europa Ice Palace
            return MapAssetConfiguration(
                cardBackImage: "CardBack", // Placeholder - update when asset is ready
                chipImages: [
                    25: "Europa_25",
                    50: "Europa_50",
                    100: "Europa_100",
                    500: "Europa_500",
                    1000: "Europa_1k"
                ],
                backgroundGradient: [Color(hex: "1a1a2e"), Color(hex: "16213e")], // Placeholder
                tableTexture: "Blue_Suede"
            )
        case 4: // Ganymede Grand
            return MapAssetConfiguration(
                cardBackImage: "CardBack", // Placeholder - update when asset is ready
                chipImages: [
                    100: "gang_100",
                    250: "gang_250",
                    500: "gang_500",
                    2500: "gang_2.5k",
                    5000: "gang_5k"
                ],
                backgroundGradient: [Color(hex: "1a1a2e"), Color(hex: "16213e")], // Placeholder
                tableTexture: "Purple_Suede"
            )
        case 5: // Titan Methane Mirage
            return MapAssetConfiguration(
                cardBackImage: "CardBack", // Placeholder - update when asset is ready
                chipImages: [
                    250: "Titan_250",
                    1000: "Titan_1k",
                    2500: "Titan_2.5k",
                    10000: "Titan_10k",
                    25000: "Titan_25_K"  // Updated asset name to match user's rename
                ],
                backgroundGradient: [Color(hex: "1a1a2e"), Color(hex: "16213e")], // Placeholder
                tableTexture: "GreenSuede"
            )
        case 6: // Kepler Fortune
            return MapAssetConfiguration(
                cardBackImage: "CardBack", // Placeholder - update when asset is ready
                chipImages: [
                    1: "Chip_1",
                    5: "Chip_5",
                    25: "Chip_25",
                    50: "Chip_50",
                    100: "Chip_100"
                ],
                backgroundGradient: [Color(hex: "1a1a2e"), Color(hex: "16213e")], // Placeholder
                tableTexture: "Yellow_Suede"
            )
        default:
            return MapAssetConfiguration.default
        }
    }
}

// MARK: - Map Asset Configuration
struct MapAssetConfiguration {
    let cardBackImage: String
    let chipImages: [Int: String] // [chipValue: imageName]
    let backgroundGradient: [Color]
    let tableTexture: String?
    
    static let `default` = MapAssetConfiguration(
        cardBackImage: "CardBack",
        chipImages: [
            1: "Chip_1",
            5: "Chip_5",
            25: "Chip_25",
            50: "Chip_50",
            100: "Chip_100"
        ],
        backgroundGradient: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
        tableTexture: nil
    )
} 
