import SwiftUI

struct DailyUsageTableRow: View {
    let daily: DailyUsage
    let tokenFormatter: NumberFormatter
    let currencyFormatter: NumberFormatter
    let isHovered: Bool
    
    var body: some View {
        HStack {
            // Date
            Text(daily.dateString)
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Models
            HStack(spacing: 4) {
                ForEach(Array(daily.modelsUsed.prefix(2)), id: \.self) { model in
                    Text("- \(model)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if daily.modelsUsed.count > 2 {
                    Text("+\(daily.modelsUsed.count - 2)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Input Tokens
            Text(tokenFormatter.string(from: NSNumber(value: daily.inputTokens)) ?? "0")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            // Output Tokens
            Text(tokenFormatter.string(from: NSNumber(value: daily.outputTokens)) ?? "0")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            // Cost
            Text(currencyFormatter.string(from: NSNumber(value: daily.totalCost)) ?? "$0.00")
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
    }
}
