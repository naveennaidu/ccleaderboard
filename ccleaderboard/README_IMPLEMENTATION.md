# Claude Usage Daily Logic Implementation

## Overview

This SwiftUI implementation replicates the daily usage logic from ccusage. It reads Claude Code's JSONL log files, aggregates usage by date, and displays token counts and costs.

## Key Components

### 1. Data Models (`Models/UsageData.swift`)
- **UsageEntry**: Represents raw data from JSONL files
- **DailyUsage**: Aggregated usage data for a single day
- **ModelBreakdown**: Usage breakdown by AI model
- **ModelPricing**: Pricing information for cost calculations

### 2. Data Loader (`Services/UsageDataLoader.swift`)
- Finds Claude data directories (supports both old and new paths)
- Reads and parses JSONL files
- Aggregates usage data by date
- Calculates costs using pre-calculated values or model pricing
- Handles deduplication using message and request IDs

### 3. Views (`Views/DailyUsageView.swift`)
- **DailyUsageView**: Main view showing daily usage list
- **DailyUsageRow**: Expandable row showing daily details
- **SummaryRow**: Shows total costs and tokens
- **ProjectFilterView**: Filter usage by project

## Data Flow

1. **File Discovery**: Searches `~/.config/claude/projects/` and `~/.claude/projects/`
2. **Parsing**: Each JSONL line contains:
   ```json
   {
     "timestamp": "2024-01-15T10:00:00Z",
     "message": {
       "usage": {
         "input_tokens": 1000,
         "output_tokens": 500,
         "cache_creation_input_tokens": 200,
         "cache_read_input_tokens": 100
       },
       "model": "claude-sonnet-4-20250514"
     },
     "costUSD": 0.05
   }
   ```
3. **Aggregation**: Groups entries by date (YYYY-MM-DD)
4. **Cost Calculation**: Uses `costUSD` if available, otherwise calculates from tokens
5. **Display**: Shows aggregated data sorted by date (newest first)

## Key Features

- **Multi-directory support**: Handles both old and new Claude config locations
- **Deduplication**: Prevents counting the same request multiple times
- **Project filtering**: Filter usage by project name
- **Model tracking**: Shows which AI models were used
- **Cache token support**: Tracks cache creation and read tokens
- **Expandable rows**: Tap to see detailed token breakdown

## Usage

The app automatically loads usage data on launch. Use the refresh button to reload and the filter button to filter by project.

## Future Enhancements

- Add monthly and session views
- Implement 5-hour billing blocks
- Add export functionality
- Support custom date ranges
- Real-time monitoring
- Charts and visualizations