import Foundation

/// Centralized constants for the application
enum Constants {

    // MARK: - URLs

    /// URL constants for API endpoints
    enum URLs {
        /// Claude.ai login page
        static let claudeLogin = URL(string: "https://claude.ai/login")!
        /// Claude.ai chats page (used to detect successful login)
        static let claudeChats = URL(string: "https://claude.ai/chats")!
        /// Cursor API base URL
        static let cursorAPI = URL(string: "https://api2.cursor.sh")!
    }

    // MARK: - UserDefaults Keys

    /// Keys for UserDefaults storage
    enum UserDefaultsKeys {
        /// Refresh interval in seconds
        static let refreshInterval = "refreshInterval"
        /// Whether to auto-wake sessions when ready
        static let autoWakeUp = "autoWakeUp"
        /// Encoded array of saved accounts
        static let savedAccounts = "savedAccounts"
        /// Whether debug logging is enabled
        static let debugModeEnabled = "debugModeEnabled"
        /// Whether keychain migration has been completed
        static let keychainMigrationComplete = "keychainMigrationComplete"
    }

    // MARK: - Timeouts

    /// Timeout constants for various operations
    enum Timeouts {
        /// Timeout for ping operations (seconds)
        static let pingTimeout: TimeInterval = 15
        /// Default refresh interval (seconds)
        static let defaultRefreshInterval: TimeInterval = 300
        /// Delay after ping before fetching data (seconds)
        static let pingRefreshDelay: TimeInterval = 2.0
        /// Network request timeout (seconds)
        static let networkRequestTimeout: TimeInterval = 30
    }

    // MARK: - Notifications

    /// Constants for notification behavior
    enum Notifications {
        /// Cooldown period between same notification type (seconds)
        static let cooldownInterval: TimeInterval = 300 // 5 minutes
    }

    // MARK: - Usage Thresholds

    /// Default threshold values for gauge color transitions.
    /// User-configurable thresholds are stored in NotificationSettings.
    enum UsageThresholds {
        /// Low usage threshold (gauge transitions from green to yellow)
        static let low: Double = 0.50
        /// Medium usage threshold (default for user-configurable lower alert)
        static let medium: Double = 0.75
        /// High usage threshold (default for user-configurable higher alert)
        static let high: Double = 0.90
    }

    // MARK: - GLM

    /// Constants specific to GLM Coding Plan accounts
    enum GLM {
        /// Rolling window for session limits (hours)
        static let sessionWindowHours: Double = 5.0
        /// Display label for the session window
        static let sessionWindowLabel = "Session usage"
    }

    // MARK: - Bundle Identifiers

    /// Bundle identifier constants
    enum BundleIdentifiers {
        /// Fallback identifier if Bundle.main.bundleIdentifier is nil
        static let fallback = "com.claudeusagepro"

        /// Current app's bundle identifier
        static var current: String {
            Bundle.main.bundleIdentifier ?? fallback
        }
    }
}
