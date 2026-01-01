import SwiftUI

@main
struct ClaudeUsageProApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthManager() 
    
    var body: some Scene {
        MenuBarExtra {
            ContentView(appState: appState, authManager: authManager)
                .environmentObject(appState)
        } label: {
            let icon = appState.sessions.isEmpty ? "xmark.circle" : "checkmark.circle"
            Image(systemName: icon)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var authManager: AuthManager
    
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            HStack {
                Text("Claude Usage Pro")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Material.bar)
            
            Divider()
            
            // Main Content Area
            if showSettings {
                SettingsView()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.sessions) { session in
                            AccountRowSessionView(session: session)
                        }
                        
                        AddAccountCardView {
                            authManager.startLogin()
                        }
                    }
                    .padding(20)

                }
            }
            
            Divider()
            
            // Bottom Toolbar
            HStack(spacing: 8) {
                HoverIconButton(image: showSettings ? "checkmark" : "gearshape.fill", helpText: showSettings ? "Done" : "Settings") {
                    withAnimation {
                        showSettings.toggle()
                    }
                }
                
                if !showSettings, !appState.sessions.isEmpty {
                    HoverIconButton(image: "arrow.clockwise", helpText: "Refresh Data Now") {
                        appState.refreshAll()
                    }
                }
                
                Spacer()
                
                if !showSettings, !appState.sessions.isEmpty {
                    CountdownView(target: appState.nextRefresh)
                        .help("Time until next automatic refresh")
                }
                
                Spacer()
                
                QuitButton()
            }
            .padding(12)
            .background(Material.bar)
        }
        .frame(width: 450, height: 600) // Default size: wider for emails, tall for 4 cards
        .background(Material.ultraThin)
        .onAppear {
            authManager.onLoginSuccess = { cookies in
                print("[DEBUG] App: Login success.")
                appState.addAccount(cookies: cookies)
            }
            appState.nextRefresh = Date().addingTimeInterval(300)
        }
    }
}



// Custom Button Component for reliable hover
struct HoverIconButton: View {
    let image: String
    let helpText: String
    var color: Color = .primary
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.system(size: 14, weight: .medium)) // Slightly larger icon
                .foregroundColor(isHovering ? color : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHovering)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle()) // Ensures entire 32x32 area is clickable
        .help(helpText)
        .onHover { hover in
            isHovering = hover
        }
    }
}

struct QuitButton: View {
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            Image(systemName: "power")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isHovering ? .red : .secondary) // Red on hover to indicate destructive/quit
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Color.red.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovering ? Color.red.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
                )
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHovering)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("Quit Application")
        .onHover { hover in
            isHovering = hover
        }
    }
}

struct AddAccountCardView: View {
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("Add Account")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 24)
            .background(Material.regular)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(isHovering ? .primary.opacity(0.5) : .secondary.opacity(0.3))
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovering = hover
        }
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

class AppState: ObservableObject {
    @Published var sessions: [AccountSession] = []
    @Published var nextRefresh: Date = Date()
    
    private let defaults = UserDefaults.standard
    private let accountsKey = "savedAccounts"
    
    init() {
        loadAccounts()
    }
    
    func addAccount(cookies: [HTTPCookie]) {
        let newAccount = ClaudeAccount(
            id: UUID(),
            name: "Account \(sessions.count + 1)",
            cookies: cookies,
            usageData: nil
        )
        let session = AccountSession(account: newAccount)
        sessions.append(session)
        saveAccounts()
        // Updated call: use startMonitoring() from Managers/AccountSession
        session.startMonitoring()
    }
    
    func removeAccount(id: UUID) {
        sessions.removeAll { $0.account.id == id }
        saveAccounts()
    }
    
    func refreshAll() {
        print("[DEBUG] AppState: Refreshing all accounts...")
        for session in sessions {
            // Updated call: use fetchNow() from Managers/AccountSession
            session.fetchNow()
        }
        // Force UI update for countdown visual
        nextRefresh = Date().addingTimeInterval(300)
    }
    
    private func saveAccounts() {
        let accounts = sessions.map { $0.account }
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: accountsKey)
        }
    }
    
    private func loadAccounts() {
        if let data = defaults.data(forKey: accountsKey),
           var accounts = try? JSONDecoder().decode([ClaudeAccount].self, from: data) {
            // Clear cached usageData so all cards start with loading animation
            for i in accounts.indices {
                accounts[i].usageData = nil
            }
            
            // Maps to Managers/AccountSession
            self.sessions = accounts.map { AccountSession(account: $0) }
            
            // Restart monitoring for loaded sessions
            for session in self.sessions {
                session.startMonitoring()
            }
        }
    }
}

struct CountdownView: View {
    let target: Date
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let diff = target.timeIntervalSince(context.date)
            if diff > 0 {
                Text("Refresh: \(timeString(from: diff))")
                    .font(.system(.caption2, design: .rounded).monospacedDigit())
                    .foregroundColor(.secondary)
            } else {
                Text("Refreshing...")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Wrapper for the row that observes the session object
struct AccountRowSessionView: View {
    @ObservedObject var session: AccountSession
    
    var body: some View {
        UsageView(account: session.account) {
            print("Ping clicked for \(session.account.name)")
            session.ping()
        }
        .padding(.vertical, 4)
    }
}
