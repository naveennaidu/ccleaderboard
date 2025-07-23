# CCLeaderboard

A macOS app for tracking Claude Code usage and competing on a global leaderboard. View your daily token usage, costs, and see how you rank against other Claude Code users worldwide.

## About

CCLeaderboard reads your local Claude Code usage logs, aggregates them by date, and provides detailed insights into your AI usage patterns. You can optionally join a global leaderboard to compare your usage with other developers.

This project is heavily inspired by:
- **Danny and Kieran's [Claude Code HighScore](https://x.com/DannyAziz97/status/1947848556884144320)** - The original inspiration for gamifying Claude Code usage
- **[CCUsage](https://github.com/ryoppippi/ccusage)** - An excellent open-source project for tracking Claude usage that provided reference implementation ideas

## Features

- 📊 **Daily Usage Tracking**: View your Claude Code usage broken down by day
- 💰 **Cost Calculation**: See how much you're spending on different AI models
- 🏆 **Global Leaderboard**: Compare your usage with developers worldwide
- 📱 **Native macOS App**: Built with SwiftUI for a smooth, native experience
- 🔒 **Privacy-First**: Your prompts and project names never leave your device

## How It Works

1. The app reads your local Claude Code JSONL log files from `~/.config/claude/projects/`
2. Usage data is aggregated by date and model
3. You can optionally join the leaderboard by choosing a username
4. Only aggregated statistics (tokens, costs, request counts) are uploaded - never your actual prompts or project details

## Building from Source

Requirements:
- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

```bash
git clone https://github.com/yourusername/ccleaderboard.git
cd ccleaderboard
open ccleaderboard.xcodeproj
```

Build and run in Xcode.

## Backend Setup (Optional)

The app includes a Cloudflare Workers backend for the leaderboard feature. If you want to self-host:

```bash
cd backend
bun install
bun run deploy
```

See [backend/README.md](backend/README.md) for detailed setup instructions.

## Privacy

- **Local First**: All usage analysis happens on your device
- **Opt-in Leaderboard**: You choose if and when to join the global leaderboard
- **No Personal Data**: Only aggregated statistics are shared (token counts, costs, request counts)
- **Open Source**: Review the code to see exactly what data is collected and how

## Contributing

We welcome contributions! Please feel free to submit issues, feature requests, or pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Acknowledgments

Special thanks to:
- Danny and Kieran for creating the original Claude Code high score concept that inspired this project
- The CCUsage project for providing an excellent reference implementation
- The Claude Code team at Anthropic for building an amazing tool

## License

This project is licensed under the MIT License

---

*Happy coding with Claude! May your tokens be efficient and your costs be low.*
