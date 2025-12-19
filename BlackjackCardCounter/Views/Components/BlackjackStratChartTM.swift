import SwiftUI

// MARK: - Blackjack Strategy Chart for Training Mode
struct BlackjackStratChartTM: View {
    @Binding var showStrategyChart: Bool
    
    var body: some View {
        ZStack {
            // Full screen overlay background
            Color.black.opacity(0.8)
                .ignoresSafeArea(.all)
            .onTapGesture { showStrategyChart = false }
        
            // Strategy chart content
        VStack(spacing: 16) {
            Text("Blackjack Strategy Chart")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
                .padding(.top, 16)
            
            // Key legend
            HStack(spacing: 12) {
                LegendCell(label: "H", text: "Hit", color: .green)
                LegendCell(label: "D", text: "Double Down", color: .orange)
                LegendCell(label: "S", text: "Stand", color: .red)
                LegendCell(label: "P", text: "Split", color: .purple)
            }
            .padding(.bottom, 4)
            
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    // Hard Totals
                    Text("Hard Totals")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    StrategyChartView(
                        headers: ["Total", "2", "3", "4", "5", "6", "7", "8", "9", "10", "A"],
                        rows: [
                            ["5-7", "H", "H", "H", "H", "H", "H", "H", "H", "H", "H"],
                            ["8",   "H", "H", "H", "H", "D", "H", "H", "H", "H", "H"],
                            ["9",   "D", "D", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["10",  "D", "D", "D", "D", "D", "D", "D", "H", "H", "H"],
                            ["11",  "D", "D", "D", "D", "D", "D", "D", "D", "D", "D"],
                            ["12",  "H", "H", "S", "S", "S", "H", "H", "H", "H", "H"],
                            ["13-16", "S", "S", "S", "S", "S", "H", "H", "H", "H", "H"],
                            ["17+", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S"]
                        ]
                    )
                    
                    // Soft Totals
                    Text("Soft Totals (one Ace counted as 11)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    StrategyChartView(
                        headers: ["Soft Total", "2", "3", "4", "5", "6", "7", "8", "9", "10", "A"],
                        rows: [
                            ["A2/13", "H", "H", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A3/14", "H", "H", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A4/15", "H", "H", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A5/16", "H", "D", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A6/17", "D", "D", "D", "D", "D", "H", "H", "H", "H", "H"],
                            ["A7/18", "S", "D", "D", "D", "D", "S", "S", "H", "H", "H"],
                            ["A8/19", "S", "S", "S", "S", "D", "S", "S", "S", "S", "S"],
                            ["A9/20+", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S"]
                        ]
                    )
                    
                    // Pair Splits
                    Text("Pair Splits")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    StrategyChartView(
                        headers: ["Pair", "2", "3", "4", "5", "6", "7", "8", "9", "10", "A"],
                        rows: [
                            ["2-2", "P", "P", "P", "P", "P", "P", "H", "H", "H", "H"],
                            ["3-3", "P", "P", "P", "P", "P", "P", "H", "H", "H", "H"],
                            ["4-4", "H", "H", "P", "P", "P", "H", "H", "H", "H", "H"],
                            ["5-5", "D", "D", "D", "D", "D", "D", "D", "H", "H", "H"],
                            ["6-6", "P", "P", "P", "P", "P", "P", "H", "H", "H", "H"],
                            ["7-7", "P", "P", "P", "P", "P", "P", "H", "S", "H", "H"],
                            ["8-8", "P", "P", "P", "P", "P", "P", "P", "P", "P", "P"],
                            ["9-9", "P", "P", "P", "S", "P", "P", "S", "P", "S", "P"],
                            ["10-10", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S"],
                            ["A-A", "P", "P", "P", "P", "P", "P", "P", "P", "P", "P"]
                        ]
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .frame(width: 400, height: 500)
            .background(Color(hex: "23272a").opacity(0.98))
            .cornerRadius(22)
            
            Button(action: { showStrategyChart = false }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color(hex: "ff0000"))
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .frame(maxWidth: 440)
        .background(Color(hex: "23272a").opacity(0.98))
        .cornerRadius(28)
        .shadow(radius: 24)
        .padding(.top, 60)
        }
        .zIndex(99999) // Ensure entire overlay is on top
    }
}

// Note: StrategyChartView and LegendCell are imported from TrainingModeComponents.swift
