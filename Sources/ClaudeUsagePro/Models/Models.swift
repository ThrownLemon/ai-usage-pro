import Foundation
import WebKit

enum AccountType: String, Codable {
    case claude
    case cursor
    case glm
}

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

struct ClaudeAccount: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var type: AccountType = .claude
    var usageData: UsageData?

    // Sensitive data - stored in Keychain, not UserDefaults
    // These are transient properties that load from Keychain on-demand
    var cookieProps: [[String: String]] = []
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
    
    var limitDetails: String {
        return usageData?.tier ?? "Fetching..."
    }
    
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
    
    init(name: String, cookies: [HTTPCookie], type: AccountType = .claude) {
        self.name = name
        self.type = type
        self.cookieProps = cookies.compactMap { $0.toCodable() }
    }
    
    init(id: UUID, name: String, cookies: [HTTPCookie], usageData: UsageData?, type: AccountType = .claude) {
        self.id = id
        self.name = name
        self.type = type
        self.cookieProps = cookies.compactMap { $0.toCodable() }
        self.usageData = usageData
    }

    // GLM-specific initializer with API token
    init(name: String, apiToken: String) {
        self.name = name
        self.type = .glm
        self.apiToken = apiToken
        self.cookieProps = []
    }

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
