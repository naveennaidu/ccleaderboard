import Foundation
import Combine
import AppKit

class UsageDataLoader: ObservableObject {
	@Published var dailyUsage: [DailyUsage] = []
	@Published var isLoading = false
	@Published var error: Error?
	@Published var selectedDirectory: URL?
	
	private let fileManager = FileManager.default
	private let jsonDecoder = JSONDecoder()
	private let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd"
		formatter.timeZone = TimeZone.current
		return formatter
	}()
	
	private let isoDateFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()
	
	private let isoDateFormatterNoFraction: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime]
		return formatter
	}()
	
	// Get Claude data directories
	private func getClaudePaths() -> [URL] {
		guard let selectedDir = selectedDirectory else {
			print("❌ No directory selected")
			return []
		}
		
		print("📁 Selected directory: \(selectedDir.path)")
		
		// Check if this is already a projects directory
		if selectedDir.lastPathComponent == "projects" {
			print("✅ Already a projects directory")
			return [selectedDir]
		}
		
		// Check for projects subdirectory
		let projectsDir = selectedDir.appendingPathComponent("projects")
		print("🔍 Checking for projects subdirectory: \(projectsDir.path)")
		if fileManager.fileExists(atPath: projectsDir.path) {
			print("✅ Found projects subdirectory")
			return [projectsDir]
		}
		
		// If user selected home directory, check default paths
		if selectedDir.path == fileManager.homeDirectoryForCurrentUser.path {
			print("🏠 Selected home directory, checking default paths...")
			var paths: [URL] = []
			let defaultPaths = [
				selectedDir.appendingPathComponent(".config/claude/projects"),
				selectedDir.appendingPathComponent(".claude/projects")
			]
			
			for path in defaultPaths {
				print("🔍 Checking: \(path.path)")
				if fileManager.fileExists(atPath: path.path) {
					print("✅ Found: \(path.path)")
					paths.append(path)
				} else {
					print("❌ Not found: \(path.path)")
				}
			}
			return paths
		}
		
		print("⚠️ No valid Claude paths found in selected directory")
		return []
	}
	
	// Extract project name from file path
	private func extractProjectName(from path: String) -> String {
		let components = path.components(separatedBy: "/projects/")
		guard components.count > 1,
			  let projectPath = components.last else { return "unknown" }
		
		let projectComponents = projectPath.components(separatedBy: "/")
		return projectComponents.first ?? "unknown"
	}
	
	// Find all JSONL files
	private func findUsageFiles() -> [URL] {
		var allFiles: [URL] = []
		let claudePaths = getClaudePaths()
		
		print("🔍 Searching for JSONL files in \(claudePaths.count) path(s)")
		
		for basePath in claudePaths {
			print("📂 Scanning: \(basePath.path)")
			var fileCount = 0
			
			if let enumerator = fileManager.enumerator(at: basePath,
													   includingPropertiesForKeys: [.isRegularFileKey],
													   options: [.skipsHiddenFiles]) {
				for case let fileURL as URL in enumerator {
					if fileURL.pathExtension == "jsonl" {
						allFiles.append(fileURL)
						fileCount += 1
						print("  ✅ Found: \(fileURL.lastPathComponent) in \(fileURL.deletingLastPathComponent().lastPathComponent)")
					}
				}
			}
			print("  📊 Found \(fileCount) JSONL files in this path")
		}
		
		print("📊 Total JSONL files found: \(allFiles.count)")
		return allFiles
	}
	
	// Calculate cost for an entry
	private func calculateCost(for entry: UsageEntry) -> Double {
		// If pre-calculated cost exists, use it
		if let cost = entry.costUSD {
			return cost
		}
		
		// Otherwise calculate based on model pricing
		guard let model = entry.message.model,
			  let pricing = defaultModelPricing[model] else {
			return 0
		}
		
		let usage = entry.message.usage
		let inputCost = Double(usage.input_tokens) * pricing.inputCostPerToken
		let outputCost = Double(usage.output_tokens) * pricing.outputCostPerToken
		let cacheCreationCost = Double(usage.cache_creation_input_tokens ?? 0) * pricing.cacheCreationCostPerToken
		let cacheReadCost = Double(usage.cache_read_input_tokens ?? 0) * pricing.cacheReadCostPerToken
		
		return inputCost + outputCost + cacheCreationCost + cacheReadCost
	}
	
	// Show directory picker
	func selectDirectory() {
		let openPanel = NSOpenPanel()
		openPanel.title = "Select Claude Data Directory"
		openPanel.message = "Select your Claude config directory (usually ~/.config/claude or ~/.claude)"
		openPanel.canChooseFiles = false
		openPanel.canChooseDirectories = true
		openPanel.canCreateDirectories = false
		openPanel.allowsMultipleSelection = false
		openPanel.showsHiddenFiles = true
		
		// Set default directory to home
		openPanel.directoryURL = fileManager.homeDirectoryForCurrentUser
		
		if openPanel.runModal() == .OK {
			selectedDirectory = openPanel.url
			print("✅ User selected directory: \(openPanel.url?.path ?? "nil")")
			loadDailyUsage()
		} else {
			print("❌ User cancelled directory selection")
		}
	}
	
	// Load and aggregate daily usage data
	func loadDailyUsage(since: Date? = nil, until: Date? = nil, project: String? = nil) {
		print("\n🚀 Starting loadDailyUsage...")
		print("  📅 Since: \(since?.description ?? "nil")")
		print("  📅 Until: \(until?.description ?? "nil")")
		print("  📁 Project filter: \(project ?? "nil")")
		
		guard selectedDirectory != nil else {
			print("⚠️ No directory selected, prompting user...")
			// Prompt user to select directory
			selectDirectory()
			return
		}
		
		isLoading = true
		error = nil
		
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			guard let self = self else { return }
			
			do {
				let files = self.findUsageFiles()
				
				if files.isEmpty {
					print("❌ No JSONL files found!")
					throw NSError(domain: "UsageDataLoader", code: 1, userInfo: [
						NSLocalizedDescriptionKey: "No usage data found in selected directory. Make sure you selected the correct Claude config directory."
					])
				}
				
				var dailyData: [String: DailyUsage] = [:] // Key: date string
				var processedHashes = Set<String>() // For deduplication
				var totalEntriesProcessed = 0
				var totalLinesSkipped = 0
				
				// Process each file
				for (fileIndex, file) in files.enumerated() {
					print("\n📄 Processing file \(fileIndex + 1)/\(files.count): \(file.lastPathComponent)")
					let projectName = self.extractProjectName(from: file.path)
					print("  📁 Project: \(projectName)")
					
					// Filter by project if specified
					if let filterProject = project, projectName != filterProject {
						print("  ⏭️ Skipping (project filter)")
						continue
					}
					
					// Read file content
					let content = try String(contentsOf: file, encoding: .utf8)
					let lines = content.components(separatedBy: .newlines)
					print("  📏 Lines in file: \(lines.count)")
					
					var entriesInFile = 0
					var skippedInFile = 0
					
					// Process each line
					for (lineIndex, line) in lines.enumerated() {
						guard !line.isEmpty else { continue }
						
						do {
							// Parse JSON
							guard let data = line.data(using: .utf8) else {
								print("    ⚠️ Line \(lineIndex): Failed to convert to data")
								skippedInFile += 1
								continue
							}
							let entry = try self.jsonDecoder.decode(UsageEntry.self, from: data)
							entriesInFile += 1
							
							// Create deduplication hash
							let hash = "\(entry.message.id ?? ""):\(entry.requestId ?? "")"
							if !hash.isEmpty && processedHashes.contains(hash) {
								continue
							}
							processedHashes.insert(hash)
							
							// Parse timestamp - try with fractional seconds first, then without
							var timestamp = self.isoDateFormatter.date(from: entry.timestamp)
							if timestamp == nil {
								timestamp = self.isoDateFormatterNoFraction.date(from: entry.timestamp)
							}
							
							guard let timestamp = timestamp else {
								print("    ⚠️ Failed to parse timestamp: \(entry.timestamp)")
								skippedInFile += 1
								continue
							}
							
							// Check date filters
							if let since = since, timestamp < since {
								skippedInFile += 1
								continue
							}
							if let until = until, timestamp > until {
								skippedInFile += 1
								continue
							}
							
							// Get date string
							let dateString = self.dateFormatter.string(from: timestamp)
							
							// Calculate cost
							let cost = self.calculateCost(for: entry)
							
							// Aggregate by date
							if dailyData[dateString] == nil {
								dailyData[dateString] = DailyUsage(
									date: self.dateFormatter.date(from: dateString)!,
									dateString: dateString
								)
							}
							
							dailyData[dateString]?.addEntry(entry, cost: cost, project: projectName)
							totalEntriesProcessed += 1
							
						} catch let error {
							// Skip invalid JSON lines
							if lineIndex < 5 { // Only log first few errors
								print("    ❌ Line \(lineIndex): JSON decode error: \(error.localizedDescription)")
								if line.count < 200 {
									print("      Content: \(line)")
								}
							}
							skippedInFile += 1
							continue
						}
					}
					
					print("  ✅ Processed: \(entriesInFile) entries, Skipped: \(skippedInFile)")
					totalLinesSkipped += skippedInFile
				}
				
				print("\n📊 Processing complete:")
				print("  ✅ Total entries processed: \(totalEntriesProcessed)")
				print("  ⏭️ Total lines skipped: \(totalLinesSkipped)")
				print("  📅 Unique days: \(dailyData.count)")
				
				// Sort by date (descending)
				let sortedData = dailyData.values.sorted { $0.date > $1.date }
				
				// Calculate model breakdowns
				let finalData = sortedData.map { daily in
					var updatedDaily = daily
					updatedDaily.modelBreakdowns = self.calculateModelBreakdowns(for: daily)
					return updatedDaily
				}
				
				// Update on main thread
				DispatchQueue.main.async {
					print("✅ Updating UI with \(finalData.count) days of data")
					self.dailyUsage = finalData
					self.isLoading = false
				}
				
			} catch let error {
				print("❌ Error in loadDailyUsage: \(error.localizedDescription)")
				DispatchQueue.main.async {
					self.error = error
					self.isLoading = false
				}
			}
		}
	}
	
	// Calculate model breakdowns for a daily usage
	private func calculateModelBreakdowns(for daily: DailyUsage) -> [ModelBreakdown] {
		// This is a simplified version - in the real implementation,
		// you would track individual entries by model during aggregation
		var breakdowns: [ModelBreakdown] = []
		
		for model in daily.modelsUsed {
			var breakdown = ModelBreakdown(modelName: model)
			// In a real implementation, you'd aggregate these values per model
			// For now, we'll just show the model was used
			breakdowns.append(breakdown)
		}
		
		return breakdowns
	}
}