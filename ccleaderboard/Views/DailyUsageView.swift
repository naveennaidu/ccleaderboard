import SwiftUI

struct DailyUsageView: View {
    @StateObject private var dataLoader = UsageDataLoader()
    @State private var selectedProject: String? = nil
    @State private var showProjectFilter = false
	
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 4
        return formatter
    }()
	
    private let tokenFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
	
    var body: some View {
        VStack {
            // Show selected directory path
            if let selectedDir = dataLoader.selectedDirectory {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    Text(selectedDir.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Change") {
                        dataLoader.selectDirectory()
                    }
                    .buttonStyle(.link)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
				
            if dataLoader.isLoading {
                ProgressView("Loading usage data...")
                    .padding()
            } else if let error = dataLoader.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error loading data")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if dataLoader.dailyUsage.isEmpty && dataLoader.selectedDirectory == nil {
                VStack {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Select Claude Data Directory")
                        .font(.headline)
                    Text("Click the button below to select your Claude config directory\n(usually ~/.config/claude or ~/.claude)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
						
                    Button("Select Directory") {
                        dataLoader.selectDirectory()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .padding()
            } else if dataLoader.dailyUsage.isEmpty {
                VStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No usage data found")
                        .font(.headline)
                    Text("Make sure the selected directory contains Claude usage data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
						
                    Button("Select Different Directory") {
                        dataLoader.selectDirectory()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
                .padding()
            } else {
                List {
                    // Total summary section
                    Section("Summary") {
                        SummaryRow(dailyUsage: dataLoader.dailyUsage)
                    }
						
                    // Daily usage rows
                    Section("Daily Usage") {
                        ForEach(dataLoader.dailyUsage) { daily in
                            DailyUsageRow(
                                daily: daily,
                                tokenFormatter: tokenFormatter,
                                currencyFormatter: currencyFormatter
                            )
                        }
                    }
                }
            }
        }
        //		.navigationTitle("Claude Usage")
        //		.toolbar {
        //			ToolbarItem(placement: .navigation) {
        //				Button(action: { dataLoader.loadDailyUsage() }) {
        //					Image(systemName: "arrow.clockwise")
        //				}
        //			}
//
        //			ToolbarItem(placement: .navigation) {
        //				Button(action: { showProjectFilter.toggle() }) {
        //					Image(systemName: "line.horizontal.3.decrease.circle")
        //				}
        //			}
        //		}
        .sheet(isPresented: $showProjectFilter) {
            ProjectFilterView(selectedProject: $selectedProject) {
                dataLoader.loadDailyUsage(project: selectedProject)
            }
        }
        .onAppear {
            dataLoader.loadDailyUsage()
        }
    }
}

struct DailyUsageRow: View {
    let daily: DailyUsage
    let tokenFormatter: NumberFormatter
    let currencyFormatter: NumberFormatter
    @State private var isExpanded = false
	
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack {
                VStack(alignment: .leading) {
                    Text(daily.dateString)
                        .font(.headline)
                    if let project = daily.project {
                        Text(project)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
				
                Spacer()
				
                VStack(alignment: .trailing) {
                    Text(currencyFormatter.string(from: NSNumber(value: daily.totalCost)) ?? "$0.00")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text("\(tokenFormatter.string(from: NSNumber(value: daily.totalTokens)) ?? "0") tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
			
            // Expandable details
            if isExpanded {
                Divider()
				
                VStack(alignment: .leading, spacing: 4) {
                    TokenRow(label: "Input", value: daily.inputTokens, formatter: tokenFormatter)
                    TokenRow(label: "Output", value: daily.outputTokens, formatter: tokenFormatter)
                    if daily.cacheCreationTokens > 0 {
                        TokenRow(label: "Cache Create", value: daily.cacheCreationTokens, formatter: tokenFormatter)
                    }
                    if daily.cacheReadTokens > 0 {
                        TokenRow(label: "Cache Read", value: daily.cacheReadTokens, formatter: tokenFormatter)
                    }
					
                    if !daily.modelsUsed.isEmpty {
                        Divider()
                        Text("Models: \(daily.modelsUsed.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}

struct TokenRow: View {
    let label: String
    let value: Int
    let formatter: NumberFormatter
	
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(formatter.string(from: NSNumber(value: value)) ?? "0")
                .font(.caption.monospacedDigit())
        }
    }
}

struct SummaryRow: View {
    let dailyUsage: [DailyUsage]
	
    private var totalCost: Double {
        dailyUsage.reduce(0) { $0 + $1.totalCost }
    }
	
    private var totalTokens: Int {
        dailyUsage.reduce(0) { $0 + $1.totalTokens }
    }
	
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter
    }()
	
    private let tokenFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
	
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Total")
                    .font(.headline)
                Text("\(dailyUsage.count) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
			
            Spacer()
			
            VStack(alignment: .trailing) {
                Text(currencyFormatter.string(from: NSNumber(value: totalCost)) ?? "$0.00")
                    .font(.headline)
                    .foregroundColor(.green)
                Text("\(tokenFormatter.string(from: NSNumber(value: totalTokens)) ?? "0") tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProjectFilterView: View {
    @Binding var selectedProject: String?
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
	
    // In a real app, you'd get this list from scanning available projects
    let projects = ["All Projects", "project1", "project2", "project3"]
	
    var body: some View {
        NavigationView {
            List {
                ForEach(projects, id: \.self) { project in
                    HStack {
                        Text(project)
                        Spacer()
                        if (project == "All Projects" && selectedProject == nil) ||
                            (project == selectedProject)
                        {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if project == "All Projects" {
                            selectedProject = nil
                        } else {
                            selectedProject = project
                        }
                    }
                }
            }
            .navigationTitle("Filter by Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DailyUsageView()
}
