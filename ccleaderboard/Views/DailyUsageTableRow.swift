import SwiftUI

struct DailyUsageTableRow: View {
    let daily: DailyUsage
    let tokenFormatter: NumberFormatter
    let currencyFormatter: NumberFormatter
    let isHovered: Bool
    
    private func simplifyModelName(_ model: String) -> String {
        if model.contains("opus-4") {
            return "opus-4"
        } else if model.contains("sonnet-4") {
            return "sonnet-4"
        } else if model.contains("haiku") {
            return "haiku"
        }
        return model
    }
    
    private func colorForModel(_ model: String) -> Color {
        let simplified = simplifyModelName(model)
        switch simplified {
        case "opus-4":
            return Color.purple
        case "sonnet-4":
            return Color.blue
        case "haiku":
            return Color.green
        default:
            return Color.gray
        }
    }
    
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
                    Text(simplifyModelName(model))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(colorForModel(model))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(colorForModel(model).opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(colorForModel(model).opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                if daily.modelsUsed.count > 2 {
                    Text("+\(daily.modelsUsed.count - 2)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
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
