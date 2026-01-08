import Foundation

/// Centralized constants for the application
enum Constants {

    // MARK: - URLs

    enum URLs {
        static let claudeLogin = URL(string: "https://claude.ai/login")!
        static let claudeChats = URL(string: "https://claude.ai/chats")!
        static let cursorAPI = URL(string: "https://api2.cursor.sh")!
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let refreshInterval = "refreshInterval"
        static let autoWakeUp = "autoWakeUp"
        static let savedAccounts = "savedAccounts"
        static let debugModeEnabled = "debugModeEnabled"
        static let keychainMigrationComplete = "keychainMigrationComplete"
    }

    // MARK: - Timeouts

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

    enum GLM {
        /// Rolling window for session limits (hours)
        static let sessionWindowHours: Double = 5.0
        /// Display label for the session window
        static let sessionWindowLabel = "5 Hours Quota"
    }

    // MARK: - Bundle Identifiers

    enum BundleIdentifiers {
        static let fallback = "com.claudeusagepro"

        static var current: String {
            Bundle.main.bundleIdentifier ?? fallback
        }
    }
}
