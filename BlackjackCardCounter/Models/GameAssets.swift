import SwiftUI

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

struct Card: Identifiable {
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
    
    var countValue: Int {
        rank.countValue
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
