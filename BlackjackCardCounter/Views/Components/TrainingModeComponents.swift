import SwiftUI

// MARK: - Training Mode Specific Components

// MARK: - Card Count Meter
struct CardCountMeter: View {
    let runningCount: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Card Counter Meter")
                .font(.headline)
                .foregroundColor(.white)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.yellow, Color.green]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 24)
                
                GeometryReader { geo in
                    let width = geo.size.width
                    let minCount = -10.0
                    let maxCount = 10.0
                    let clamped = Double(runningCount).clamped(to: minCount...maxCount)
                    let normalized = (clamped - minCount) / (maxCount - minCount) // 0 to 1
                    let xOffset = CGFloat(normalized) * (width - 48) // 48 = width of number label
                    
                    Text("\(runningCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 48, height: 32)
                        .background(Color.white.opacity(0.85))
                        .cornerRadius(12)
                        .offset(x: xOffset)
                        .shadow(radius: 4)
                }
                .frame(height: 32)
            }
            .frame(height: 32)
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}

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

// MARK: - Achievement Model and Progress Bar
struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let current: Int
    let goal: Int
    var isComplete: Bool { current >= goal }
}

struct AchievementProgressBar: View {
    let progress: Double // 0.0 to 1.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 10)
                
                Capsule()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.yellow]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * progress, height: 10)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Clamp Extension
extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
} 