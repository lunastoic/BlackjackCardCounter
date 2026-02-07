import SwiftUI
import UIKit

enum CardSuit: String, CaseIterable {
    case spades = "♠️"
    case hearts = "♥️"
    case diamonds = "♦️"
    case clubs = "♣️"
}

enum CardRank: String, CaseIterable {
    case ace = "A"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "J"
    case queen = "Q"
    case king = "K"
    
    var value: Int {
        switch self {
        case .ace: return 11
        case .jack, .queen, .king: return 10
        default: return Int(rawValue) ?? 0
        }
    }
    
    var countValue: Int {
        switch self {
        case .two, .three, .four, .five, .six: return 1
        case .seven, .eight, .nine: return 0
        case .ten, .jack, .queen, .king, .ace: return -1
        }
    }
}

enum ChipDenomination: Int, CaseIterable {
    case one = 1
    case five = 5
    case twentyFive = 25
    case hundred = 100
    case fiveHundred = 500
    
    var color: Color {
        switch self {
        case .one: return .white
        case .five: return .red
        case .twentyFive: return .green
        case .hundred: return .black
        case .fiveHundred: return .purple
        }
    }
    
    var imageName: String {
        "chip_\(rawValue)"
    }
}

struct Card: Identifiable, Equatable {
    let id = UUID()
    let suit: CardSuit
    let rank: CardRank
    var isFaceUp: Bool = false
    
    var imageName: String {
        if !isFaceUp {
            return "DeckCover"
        }
        
        let rankString: String
        switch rank {
        case .ace: rankString = "Ace"
        case .jack: rankString = "Jack"
        case .queen: rankString = "Queen"
        case .king: rankString = "King"
        default: rankString = "\(rank.rawValue)"
        }
        
        let suitString: String
        switch suit {
        case .spades: suitString = "Spades"
        case .hearts: suitString = "Hearts"
        case .diamonds: suitString = "Diamonds"
        case .clubs: suitString = "Clubs"
        }
        
        // The imageset folder names are the correct names to use
        // They already handle the inconsistencies in the file names
        return "\(rankString)Of\(suitString)"
    }
    
    func imageName(isTrainingMode: Bool, useTrainingCardsFolder: Bool = false) -> String {
        if !isFaceUp {
            return "DeckCover"
        }
        return faceImageName(isTrainingMode: isTrainingMode, useTrainingCardsFolder: useTrainingCardsFolder)
    }
    
    /// Returns the face image name regardless of `isFaceUp`.
    /// Used for flip animations where `isFlipped` controls visibility.
    /// - Parameters:
    ///   - isTrainingMode: Whether we're in training mode (affects fallback behavior)
    ///   - useTrainingCardsFolder: Whether to use TrainingCards folder assets (user setting)
    func faceImageName(isTrainingMode: Bool, useTrainingCardsFolder: Bool = false) -> String {
        let rankString: String
        switch rank {
        case .ace: rankString = "Ace"
        case .jack: rankString = "Jack"
        case .queen: rankString = "Queen"
        case .king: rankString = "King"
        default: rankString = "\(rank.rawValue)"
        }
        
        let suitString: String
        switch suit {
        case .spades: suitString = "Spades"
        case .hearts: suitString = "Hearts"
        case .diamonds: suitString = "Diamonds"
        case .clubs: suitString = "Clubs"
        }
        
        let baseName = "\(rankString)Of\(suitString)"
        
        // If useTrainingCardsFolder is enabled, use TrainingCards folder assets
        if useTrainingCardsFolder {
            let trainingCardsName = "TrainingCards_\(baseName)"
            if UIImage(named: trainingCardsName) != nil {
                return trainingCardsName
            }
            // Fallback to legacy T_ prefix if present
            let legacyTrainingName = "T_\(baseName)"
            if UIImage(named: legacyTrainingName) != nil {
                return legacyTrainingName
            }
            // Last resort: regular asset
            return baseName
        }
        
        // When useTrainingCardsFolder is disabled (default), always use regular Cards folder (base name)
        return baseName
    }
    
    var countValue: Int {
        rank.countValue
    }
    
    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.id == rhs.id && lhs.suit == rhs.suit && lhs.rank == rhs.rank && lhs.isFaceUp == rhs.isFaceUp
    }
}

struct Chip: Identifiable {
    let id = UUID()
    let value: Int
}

// Asset Names
enum AssetName {
    // Card Assets
    static let cardBack = "card_back"
    static let cardPlaceholder = "card_placeholder"
    
    // Chip Assets
    static func chip(denomination: ChipDenomination) -> String {
        "chip_\(denomination.rawValue)"
    }
    
    static func chipStack(denomination: ChipDenomination, count: Int) -> String {
        "chip_stack_\(denomination.rawValue)_\(count)"
    }
    
    // Card Assets
    static func card(suit: CardSuit, rank: CardRank) -> String {
        "\(rank.rawValue)_\(suit.rawValue)"
    }
} 

// MARK: - Custom Font Extension for Consistent Sizing
extension Font {
    /// Fixed-size fonts that ignore Dynamic Type settings for consistent UI layout
    static func fixedSystem(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }
    
    /// Capped dynamic fonts that scale down but have a maximum size limit
    static func cappedSystem(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }
    
    static func fixedTitle() -> Font {
        return .system(size: 28, weight: .bold, design: .default)
    }
    
    static func fixedHeadline() -> Font {
        return .system(size: 17, weight: .semibold, design: .default)
    }
    
    static func fixedSubheadline() -> Font {
        return .system(size: 15, weight: .regular, design: .default)
    }
    
    static func fixedBody() -> Font {
        return .system(size: 16, weight: .regular, design: .default)
    }
    
    static func fixedCaption() -> Font {
        return .system(size: 12, weight: .regular, design: .default)
    }
}

// MARK: - Text Extension for Dynamic Type Control
extension Text {
    /// Apply fixed sizing that ignores Dynamic Type
    func fixedSize() -> some View {
        self.dynamicTypeSize(.large) // Lock to a specific size
    }
}

// MARK: - View Extension for Consistent Dynamic Type Control
extension View {
    /// Disable Dynamic Type scaling for the entire view
    func disableDynamicType() -> some View {
        self.dynamicTypeSize(.large) // Lock to standard large size
    }
    
    /// Limit Dynamic Type to reasonable bounds
    func limitDynamicType() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.xxxLarge) // Prevent extreme sizes
    }
    
    /// Cap Dynamic Type at current size but allow scaling down for smaller text preferences
    func cappedDynamicType() -> some View {
        self.dynamicTypeSize(.small...DynamicTypeSize.large) // Allow small to current size
    }
} 
