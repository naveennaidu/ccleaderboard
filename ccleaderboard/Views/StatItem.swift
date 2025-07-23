import SwiftUI

struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
            }
        }
    }
}

#Preview {
    HStack {
        StatItem(
            label: "Avg Daily",
            value: "$12.50",
            icon: "chart.line.uptrend.xyaxis"
        )
        
        StatItem(
            label: "Total Tokens",
            value: "125,000",
            icon: "text.word.spacing"
        )
    }
    .padding()
}