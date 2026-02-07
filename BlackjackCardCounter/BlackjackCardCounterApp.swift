//
//  BlackjackCardCounterApp.swift
//  BlackjackCardCounter
//
//  Created by Christopher on 5/29/25.
//

import SwiftUI

@main
struct BlackjackCardCounterApp: App {
    init() {
        // Ensure card underglow is enabled by default on first launch
        if UserDefaults.standard.object(forKey: "cardUnderglow") == nil {
            UserDefaults.standard.set(true, forKey: "cardUnderglow")
        }
        
        // DISABLE DEBUG SETTINGS BY DEFAULT to ensure proper randomization
        UserDefaults.standard.set(false, forKey: "debugForcePairs")
        UserDefaults.standard.set(false, forKey: "debugForce10s")
        UserDefaults.standard.set(false, forKey: "debugEightCardUser")
        print("🎲 App initialized: Debug settings disabled for proper randomization")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
