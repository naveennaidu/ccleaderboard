import Foundation

// MARK: - Raw Usage Data (from JSONL)
struct UsageEntry: Codable {
	let timestamp: String
	let version: String?
	let message: Message
	let requestId: String?
	let costUSD: Double?
	
	struct Message: Codable {
		let id: String?
		let usage: Usage
		let model: String?
	}
	
	struct Usage: Codable {
		let input_tokens: Int
		let output_tokens: Int
		let cache_creation_input_tokens: Int?
		let cache_read_input_tokens: Int?
	}
}

// MARK: - Aggregated Daily Usage
struct DailyUsage: Identifiable {
	let id = UUID()
	let date: Date
	let dateString: String // YYYY-MM-DD format
	var inputTokens: Int = 0
	var outputTokens: Int = 0
	var cacheCreationTokens: Int = 0
	var cacheReadTokens: Int = 0
	var totalCost: Double = 0
	var modelsUsed: Set<String> = []
	var modelBreakdowns: [ModelBreakdown] = []
	var project: String?
	
	var totalTokens: Int {
		inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
	}
	
	mutating func addEntry(_ entry: UsageEntry, cost: Double, project: String?) {
		inputTokens += entry.message.usage.input_tokens
		outputTokens += entry.message.usage.output_tokens
		cacheCreationTokens += entry.message.usage.cache_creation_input_tokens ?? 0
		cacheReadTokens += entry.message.usage.cache_read_input_tokens ?? 0
		totalCost += cost
		
		if let model = entry.message.model, model != "<synthetic>" {
			modelsUsed.insert(model)
		}
		
		self.project = project
	}
}

// MARK: - Model Breakdown
struct ModelBreakdown: Identifiable {
	let id = UUID()
	let modelName: String
	var inputTokens: Int = 0
	var outputTokens: Int = 0
	var cacheCreationTokens: Int = 0
	var cacheReadTokens: Int = 0
	var cost: Double = 0
	
	var totalTokens: Int {
		inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
	}
}

// MARK: - Model Pricing
struct ModelPricing {
	let inputCostPerToken: Double
	let outputCostPerToken: Double
	let cacheCreationCostPerToken: Double
	let cacheReadCostPerToken: Double
}

// Default pricing for known models (costs per token)
let defaultModelPricing: [String: ModelPricing] = [
	"claude-sonnet-4-20250514": ModelPricing(
		inputCostPerToken: 3.0 / 1_000_000,
		outputCostPerToken: 15.0 / 1_000_000,
		cacheCreationCostPerToken: 3.75 / 1_000_000,
		cacheReadCostPerToken: 0.30 / 1_000_000
	),
	"claude-opus-4-20250514": ModelPricing(
		inputCostPerToken: 15.0 / 1_000_000,
		outputCostPerToken: 75.0 / 1_000_000,
		cacheCreationCostPerToken: 18.75 / 1_000_000,
		cacheReadCostPerToken: 1.50 / 1_000_000
	)
]