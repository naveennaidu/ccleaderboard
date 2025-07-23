import SwiftUI

struct JoinLeaderboardView: View {
    @EnvironmentObject var leaderboardService: LeaderboardService
    @Environment(\.dismiss) var dismiss
    
    @State private var username = ""
    @State private var isChecking = false
    @State private var isJoining = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var agreedToTerms = false
    
    private var isValidUsername: Bool {
        let pattern = "^[a-zA-Z0-9_]{3,30}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: username, range: NSRange(location: 0, length: username.utf16.count))
        return matches?.count ?? 0 > 0
    }
    
    private var validationMessage: String {
        if username.isEmpty {
            return "Enter a username"
        } else if username.count < 3 {
            return "Username must be at least 3 characters"
        } else if username.count > 30 {
            return "Username must be 30 characters or less"
        } else if !isValidUsername {
            return "Username can only contain letters, numbers, and underscores"
        } else {
            return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Join the Leaderboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose a username to start competing globally")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
            
            // Username Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .onChange(of: username) {
                            username = username.lowercased()
                        }
                    
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !username.isEmpty && isValidUsername {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                if !validationMessage.isEmpty {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            
            // Terms and Privacy
            VStack(alignment: .leading, spacing: 12) {
                Text("Important Information")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Your username will be publicly visible", systemImage: "eye")
                    Label("Only usage statistics are shared (no prompts or content)", systemImage: "chart.bar")
                    Label("You can leave the leaderboard anytime", systemImage: "arrow.right.square")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                
                Toggle(isOn: $agreedToTerms) {
                    Text("I understand and agree to share my usage statistics")
                        .font(.footnote)
                }
                .toggleStyle(CheckboxToggleStyle())
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button(action: joinLeaderboard) {
                    if isJoining {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Join Leaderboard")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidUsername || !agreedToTerms || isJoining)
            }
            .padding(.bottom)
        }
        .frame(width: 450, height: 550)
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func joinLeaderboard() {
        Task {
            isJoining = true
            do {
                try await leaderboardService.joinLeaderboard(username: username)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isJoining = false
                }
            }
        }
    }
}

// Custom Checkbox Toggle Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            
            configuration.label
        }
    }
}

#Preview {
    JoinLeaderboardView()
        .environmentObject(LeaderboardService())
}
