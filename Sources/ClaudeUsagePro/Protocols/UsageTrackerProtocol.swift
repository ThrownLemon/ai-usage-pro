import Foundation

/// Protocol defining the interface for usage tracking services.
/// All trackers (Claude, Cursor, GLM) should conform to this protocol
/// to provide a unified interface for fetching usage data.
protocol UsageTracker: Sendable {
    /// Fetch current usage data from the service.
    /// - Returns: Usage data normalized to the common UsageData format
    /// - Throws: Service-specific errors if the fetch fails
    func fetchUsage() async throws -> UsageData
}

/// Protocol for trackers that support session ping/wake functionality.
/// Currently only ClaudeTrackerService supports this feature.
protocol SessionPingable {
    /// Ping the session to wake it up and start a new session.
    /// - Returns: True if the ping was successful
    func pingSession() async throws -> Bool
}

/// Configuration required for different tracker types.
/// Used by the factory to create the appropriate tracker instance.
enum TrackerConfiguration {
    case claude(cookies: [HTTPCookie])
    case cursor
    case glm(apiToken: String)
}

/// Factory for creating tracker instances based on account type.
enum TrackerFactory {
    /// Create a usage tracker for the given configuration.
    /// - Parameter config: The tracker configuration specifying type and credentials
    /// - Returns: A tracker instance conforming to UsageTracker
    @MainActor
    static func create(for config: TrackerConfiguration) -> any UsageTracker {
        switch config {
        case .claude(let cookies):
            return ClaudeTrackerAdapter(cookies: cookies)
        case .cursor:
            return CursorTrackerAdapter()
        case .glm(let apiToken):
            return GLMTrackerAdapter(apiToken: apiToken)
        }
    }
}

// MARK: - Adapter for CursorTrackerService

/// Adapter that wraps CursorTrackerService to conform to UsageTracker protocol.
final class CursorTrackerAdapter: UsageTracker, @unchecked Sendable {
    private let service = CursorTrackerService()

    func fetchUsage() async throws -> UsageData {
        let info = try await service.fetchCursorUsage()

        let sessionPercentage = info.planLimit > 0
            ? Double(info.planUsed) / Double(info.planLimit)
            : 0.0

        return UsageData(
            sessionPercentage: sessionPercentage,
            sessionReset: "Ready",
            sessionResetDisplay: "\(info.planUsed) / \(info.planLimit)",
            weeklyPercentage: 0,
            weeklyReset: "Ready",
            weeklyResetDisplay: "\(info.planUsed) / \(info.planLimit)",
            tier: info.planType ?? "Pro",
            email: info.email,
            fullName: nil,
            orgName: "Cursor",
            planType: info.planType,
            cursorUsed: info.planUsed,
            cursorLimit: info.planLimit
        )
    }
}

// MARK: - Adapter for GLMTrackerService

/// Adapter that wraps GLMTrackerService to conform to UsageTracker protocol.
final class GLMTrackerAdapter: UsageTracker, @unchecked Sendable {
    private let service = GLMTrackerService()
    private let apiToken: String

    init(apiToken: String) {
        self.apiToken = apiToken
    }

    func fetchUsage() async throws -> UsageData {
        let info = try await service.fetchGLMUsage(apiToken: apiToken)

        // Calculate session reset display (5-hour rolling window)
        let sessionRemainingHours = (1.0 - info.sessionPercentage) * Constants.GLM.sessionWindowHours
        let hours = Int(sessionRemainingHours)
        let minutes = Int((sessionRemainingHours - Double(hours)) * 60)

        let sessionResetDisplay: String
        if hours > 0 && minutes > 0 {
            sessionResetDisplay = String(format: "Resets in %dh %dm", hours, minutes)
        } else if hours > 0 {
            sessionResetDisplay = String(format: "Resets in %dh", hours)
        } else if minutes > 0 {
            sessionResetDisplay = String(format: "Resets in %dm", minutes)
        } else {
            sessionResetDisplay = "Resets in <1m"
        }

        // Weekly display shows usage/limit for GLM
        let weeklyResetDisplay = info.monthlyLimit > 0
            ? String(format: "%.0f / %.0f", info.monthlyUsed, info.monthlyLimit)
            : String(format: "%.1f%%", info.monthlyPercentage * 100)

        return UsageData(
            sessionPercentage: info.sessionPercentage,
            sessionReset: "Ready",
            sessionResetDisplay: sessionResetDisplay,
            weeklyPercentage: info.monthlyPercentage,
            weeklyReset: "Ready",
            weeklyResetDisplay: weeklyResetDisplay,
            tier: "GLM Coding Plan",
            email: nil,
            fullName: nil,
            orgName: "GLM",
            planType: "Coding Plan",
            glmSessionUsed: info.sessionUsed,
            glmSessionLimit: info.sessionLimit,
            glmMonthlyUsed: info.monthlyUsed,
            glmMonthlyLimit: info.monthlyLimit
        )
    }
}

// MARK: - Adapter for TrackerService (Claude)

/// Adapter that wraps TrackerService to conform to UsageTracker protocol.
/// This adapter bridges the callback-based TrackerService to async/await.
@MainActor
final class ClaudeTrackerAdapter: UsageTracker, SessionPingable, @unchecked Sendable {
    private let service: TrackerService
    private let cookies: [HTTPCookie]

    init(cookies: [HTTPCookie]) {
        self.cookies = cookies
        self.service = TrackerService()
    }

    nonisolated func fetchUsage() async throws -> UsageData {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                self.service.onUpdate = { usageData in
                    var data = usageData
                    data.sessionResetDisplay = usageData.sessionReset
                    continuation.resume(returning: data)
                }
                self.service.onError = { error in
                    continuation.resume(throwing: error)
                }
                self.service.fetchUsage(cookies: self.cookies)
            }
        }
    }

    nonisolated func pingSession() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                self.service.onPingComplete = { success in
                    continuation.resume(returning: success)
                }
                self.service.pingSession()
            }
        }
    }
}
