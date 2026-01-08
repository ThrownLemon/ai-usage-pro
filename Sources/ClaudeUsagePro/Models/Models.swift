import Foundation
import WebKit

/// Types of accounts supported by the application.
enum AccountType: String, Codable {
    /// Claude.ai account
    case claude
    /// Cursor IDE account
    case cursor
    /// GLM Coding Plan account
    case glm
}

/// Usage statistics for an account, normalized across different provider types.
struct UsageData: Hashable, Codable {
    var sessionPercentage: Double
    var sessionReset: String
    var sessionResetDisplay: String
    var weeklyPercentage: Double
    var weeklyReset: String
    var weeklyResetDisplay: String
    var tier: String
    var email: String?

    var fullName: String?
    var orgName: String?
    var planType: String?

    var cursorUsed: Int?
    var cursorLimit: Int?

    // GLM-specific fields
    var glmSessionUsed: Double?
    var glmSessionLimit: Double?
    var glmMonthlyUsed: Double?
    var glmMonthlyLimit: Double?
}

/// Represents a user account with credentials and usage data.
/// Credentials are stored in Keychain, not UserDefaults.
struct ClaudeAccount: Identifiable, Hashable, Codable {
    /// Unique identifier for this account
    var id = UUID()
    /// Display name for the account
    var name: String
    /// Type of account (claude, cursor, or glm)
    var type: AccountType = .claude
    /// Current usage statistics, if fetched
    var usageData: UsageData?

    // Sensitive data - stored in Keychain, not UserDefaults
    // These are transient properties that load from Keychain on-demand
    /// Cookie properties for Claude accounts (loaded from Keychain)
    var cookieProps: [[String: String]] = []
    /// API token for GLM accounts (loaded from Keychain)
    var apiToken: String?

    // CodingKeys excludes sensitive data (cookieProps, apiToken)
    // These are stored separately in Keychain
    enum CodingKeys: String, CodingKey {
        case id, name, type, usageData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(AccountType.self, forKey: .type) ?? .claude
        usageData = try container.decodeIfPresent(UsageData.self, forKey: .usageData)
        // Sensitive data loaded separately from Keychain
        cookieProps = []
        apiToken = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(usageData, forKey: .usageData)
        // Sensitive data (cookieProps, apiToken) saved separately to Keychain
    }

    // MARK: - Keychain Integration

    /// Save sensitive credentials to Keychain
    /// - Returns: true if all credentials were saved successfully, false on any error
    @discardableResult
    func saveCredentialsToKeychain() -> Bool {
        var success = true
        do {
            if !cookieProps.isEmpty {
                try KeychainService.save(cookieProps, forKey: KeychainService.cookiesKey(for: id))
            }
            if let token = apiToken {
                try KeychainService.save(token, forKey: KeychainService.apiTokenKey(for: id))
            }
        } catch {
            Log.error(Log.Category.keychain, "Failed to save credentials: \(error)")
            success = false
        }
        return success
    }

    /// Load sensitive credentials from Keychain
    mutating func loadCredentialsFromKeychain() {
        do {
            if let cookies: [[String: String]] = try KeychainService.load(forKey: KeychainService.cookiesKey(for: id)) {
                cookieProps = cookies
            }
            if let token = try KeychainService.loadString(forKey: KeychainService.apiTokenKey(for: id)) {
                apiToken = token
            }
        } catch {
            Log.error(Log.Category.keychain, "Failed to load credentials: \(error)")
        }
    }

    /// Delete credentials from Keychain (call when removing account)
    func deleteCredentialsFromKeychain() {
        do {
            try KeychainService.delete(forKey: KeychainService.cookiesKey(for: id))
            try KeychainService.delete(forKey: KeychainService.apiTokenKey(for: id))
        } catch {
            Log.error(Log.Category.keychain, "Failed to delete credentials: \(error)")
        }
    }
    
    /// Display string for the account's tier/plan
    var limitDetails: String {
        return usageData?.tier ?? "Fetching..."
    }

    /// Converts stored cookie properties back to HTTPCookie objects
    var cookies: [HTTPCookie] {
        return cookieProps.compactMap { props in
            // Convert String keys back to HTTPCookiePropertyKey
            var convertedProps: [HTTPCookiePropertyKey: Any] = [:]
            for (k, v) in props {
                convertedProps[HTTPCookiePropertyKey(rawValue: k)] = v
            }
            if let secure = props[HTTPCookiePropertyKey.secure.rawValue] {
                  convertedProps[.secure] = (secure == "TRUE" || secure == "true")
            }
            if let discard = props[HTTPCookiePropertyKey.discard.rawValue] {
                  convertedProps[.discard] = (discard == "TRUE" || discard == "true")
            }
            return HTTPCookie(properties: convertedProps)
        }
    }
    
    /// Creates a new Claude or Cursor account with cookies.
    /// - Parameters:
    ///   - name: Display name for the account
    ///   - cookies: Authentication cookies
    ///   - type: Account type (defaults to .claude)
    init(name: String, cookies: [HTTPCookie], type: AccountType = .claude) {
        self.name = name
        self.type = type
        self.cookieProps = cookies.compactMap { $0.toCodable() }
    }

    /// Creates an account with a specific ID, cookies, and optional usage data.
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Display name
    ///   - cookies: Authentication cookies
    ///   - usageData: Pre-existing usage data
    ///   - type: Account type (defaults to .claude)
    init(id: UUID, name: String, cookies: [HTTPCookie], usageData: UsageData?, type: AccountType = .claude) {
        self.id = id
        self.name = name
        self.type = type
        self.cookieProps = cookies.compactMap { $0.toCodable() }
        self.usageData = usageData
    }

    /// Creates a new GLM account with an API token.
    /// - Parameters:
    ///   - name: Display name for the account
    ///   - apiToken: GLM API token
    init(name: String, apiToken: String) {
        self.name = name
        self.type = .glm
        self.apiToken = apiToken
        self.cookieProps = []
    }

    /// Creates a GLM account with a specific ID, token, and optional usage data.
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Display name
    ///   - apiToken: GLM API token
    ///   - usageData: Pre-existing usage data
    init(id: UUID, name: String, apiToken: String, usageData: UsageData?) {
        self.id = id
        self.name = name
        self.type = .glm
        self.apiToken = apiToken
        self.usageData = usageData
        self.cookieProps = []
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: ClaudeAccount, rhs: ClaudeAccount) -> Bool {
        lhs.id == rhs.id
    }
}
