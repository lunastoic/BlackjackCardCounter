import SwiftUI

// MARK: - Training Mode Specific Components

// Note: CardCountMeter moved to CardCounterMeterTM.swift

// MARK: - Bar Chart View
struct BarChartView: View {
    let data: [String: Int] // e.g., ["A": 2, "2": 4, ...]
    let maxBarHeight: CGFloat
    let barColor: Color
    let title: String
    let yLabel: String
    let xLabels: [String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(xLabels, id: \.self) { label in
                    let value = data[label] ?? 0
                    let maxValue = (data.values.max() ?? 1)
                    
                    VStack {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(barColor)
                            .frame(height: maxBarHeight * CGFloat(value) / CGFloat(max(maxValue, 1)))
                        Text(label)
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(height: maxBarHeight)
            
            Text(yLabel)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(Color(hex: "0f3460").opacity(0.8))
        .cornerRadius(12)
    }
}

// MARK: - Strategy Chart View
struct StrategyChartView: View {
    let headers: [String]
    let rows: [[String]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // X axis label
            HStack {
                Spacer().frame(width: 40)
                Text("Dealer's Card")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
            
            HStack(spacing: 2) {
                Text("Player's Cards")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .frame(width: 40, height: 22)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.black)
                    .cornerRadius(4)
                
                ForEach(headers.dropFirst(), id: \.self) { header in
                    Text(header)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .frame(width: 32, height: 22)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                }
            }
            
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 2) {
                    Text(row[0])
                        .font(.caption2)
                        .fontWeight(.bold)
                        .frame(width: 40, height: 22)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                    
                    ForEach(row.dropFirst(), id: \.self) { cell in
                        Text(cell)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .frame(width: 32, height: 22)
                            .background(cellColor(cell))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    func cellColor(_ cell: String) -> Color {
        switch cell {
        case "H": return Color.green.opacity(0.8)
        case "S": return Color.red.opacity(0.8)
        case "D": return Color.orange.opacity(0.8)
        case "P": return Color.purple.opacity(0.8)
        default: return Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Legend Cell
struct LegendCell: View {
    let label: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.18))
        .cornerRadius(6)
    }
}

// Note: Achievement model and AchievementProgressBar moved to GameAchievements.swift

// MARK: - Clamp Extension
extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
} 