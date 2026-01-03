import Foundation
import Combine
import SwiftUI

class AccountSession: ObservableObject, Identifiable {
    let id: UUID
    @Published var account: ClaudeAccount
    @Published var isFetching: Bool = false

    private var previousSessionPercentage: Double?
    private var previousWeeklyPercentage: Double?
    private var hasReceivedFirstUpdate: Bool = false

    private var tracker: TrackerService?
    private var cursorTracker: CursorTrackerService?
    private var timer: Timer?
    var onRefreshTick: (() -> Void)?
    
    init(account: ClaudeAccount) {
        self.id = account.id
        self.account = account
        
        if account.type == .claude {
            self.tracker = TrackerService()
        } else {
            self.cursorTracker = CursorTrackerService()
        }
        
        setupTracker()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startMonitoring() {
        print("[DEBUG] Session: Starting monitoring for \(account.name)")
        fetchNow()
        scheduleRefreshTimer()
    }
    
    /// Schedules a repeating refresh timer that periodically triggers a usage update.
    /// 
    /// Invalidates any existing timer, reads the refresh interval from UserDefaults under the key `"refreshInterval"` (defaults to 300 seconds if the stored value is not positive), and creates a repeating `Timer` assigned to the `timer` property. On each tick the timer calls `fetchNow()` and invokes `onRefreshTick` if provided.
    func scheduleRefreshTimer() {
        timer?.invalidate()
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        let time = interval > 0 ? interval : 300
        
        timer = Timer.scheduledTimer(withTimeInterval: time, repeats: true) { [weak self] _ in
            self?.fetchNow()
            self?.onRefreshTick?()
        }
    }
    
    /// Attempts to wake the account session when the session is ready, optionally as an automatic wake-up.
    /// - Parameters:
    ///   - isAuto: When `true`, treat this as an automatic wake-up; the ping will be skipped if the user setting `autoWakeUp` is disabled. On successful ping the session's usage data will be refreshed shortly after.
    func ping(isAuto: Bool = false) {
        if isAuto && !UserDefaults.standard.bool(forKey: "autoWakeUp") {
            print("[DEBUG] Session: Auto-ping cancelled (setting disabled).")
            return
        }

        guard let usageData = account.usageData,
              usageData.sessionPercentage == 0,
              usageData.sessionReset == "Ready" else {
            print("[DEBUG] Session: Ping skipped (session not ready).")
            return
        }
        print("[DEBUG] Session: \(isAuto ? "Auto" : "Manual") ping requested.")
        tracker?.onPingComplete = { [weak self] success in
            if success {
                print("[DEBUG] Session: Ping finished, refreshing data...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.fetchNow()
                }
            } else {
                print("[ERROR] Session: Ping failed.")
            }
        }
        tracker?.pingSession()
    }
    
    /// Initiates an immediate usage fetch for the current account and marks the session as fetching.
    /// 
    /// If a fetch is already in progress this method returns without action. For Claude accounts it
    /// delegates to the configured tracker using the account's cookies; for non-Claude (Cursor)
    /// accounts it performs an asynchronous cursor usage fetch and forwards the result to
    /// `handleCursorUsageResult(_:)`. The method sets `isFetching` to `true` when a fetch starts.
    func fetchNow() {
        guard !isFetching else { return }
        isFetching = true
        
        if account.type == .claude {
            tracker?.fetchUsage(cookies: account.cookies)
        } else {
            Task {
                do {
                    let info = try await cursorTracker?.fetchCursorUsage()
                    if let info = info {
                        self.handleCursorUsageResult(.success(info))
                    }
                } catch {
                    self.handleCursorUsageResult(.failure(error))
                }
            }
        }
    }
    
    /// Processes the result of a Cursor usage fetch and integrates it into the session state.
    /// 
    /// Runs on the main queue, clears the fetching flag, and on success converts the provided `CursorUsageInfo` into a `UsageData` object which is applied via `updateWithUsageData(_:)`. If the fetched info contains an email and the account name begins with `"Account "` or `"Cursor"`, updates the account name to `Cursor (<email>)`. On failure, logs the error.
    /// - Parameter result: The result of a Cursor usage fetch; on success contains `CursorUsageInfo`, on failure contains an `Error`.
    private func handleCursorUsageResult(_ result: Result<CursorUsageInfo, Error>) {
        DispatchQueue.main.async {
            self.isFetching = false
            switch result {
            case .success(let info):
                let percentage = info.planLimit > 0 ? Double(info.planUsed) / Double(info.planLimit) : 0
                let usageData = UsageData(
                    sessionPercentage: percentage,
                    sessionReset: "Ready",
                    sessionResetDisplay: "\(info.planUsed) / \(info.planLimit)",
                    weeklyPercentage: 0,
                    weeklyReset: "Ready",
                    tier: info.planType ?? "Pro",
                    email: info.email,
                    fullName: nil,
                    orgName: "Cursor",
                    planType: info.planType,
                    cursorUsed: info.planUsed,
                    cursorLimit: info.planLimit
                )
                self.updateWithUsageData(usageData)
                
                if let email = info.email, self.account.name.starts(with: "Account ") || self.account.name.starts(with: "Cursor") {
                    self.account.name = "Cursor (\(email))"
                }
            case .failure(let error):
                print("[ERROR] Cursor Session: Fetch failed: \(error)")
            }
        }
    }
    
    /// Apply a new usage snapshot to the session, update stored previous percentages, send notifications, and perform any follow-up actions (auto wake/personalize name).
    /// 
    /// Updates the account's stored usage data, records the prior session and weekly percentages (unless this is the first update), logs a debug summary, checks thresholds and sends notifications, and if the session transitioned to "Ready" will trigger an automatic wake/ping when the `autoWakeUp` setting is enabled. Also replaces the account's display name with the usage email when the name begins with "Account ".
    /// - Parameter usageData: The new usage snapshot to apply to the account.
    private func updateWithUsageData(_ usageData: UsageData) {
        if self.hasReceivedFirstUpdate {
            self.previousSessionPercentage = self.account.usageData?.sessionPercentage
            self.previousWeeklyPercentage = self.account.usageData?.weeklyPercentage
        } else {
            self.hasReceivedFirstUpdate = true
        }

        self.account.usageData = usageData

        print("[DEBUG] UsageData \(self.account.name): session=\(Int(usageData.sessionPercentage * 100))% reset=\(usageData.sessionReset) weekly=\(Int(usageData.weeklyPercentage * 100))% reset=\(usageData.weeklyReset)")

        self.checkThresholdCrossingsAndNotify(usageData: usageData)

        if self.didTransitionToReady(previousPercentage: self.previousSessionPercentage, currentPercentage: usageData.sessionPercentage, currentReset: usageData.sessionReset) {
            if UserDefaults.standard.bool(forKey: "autoWakeUp") {
                print("[DEBUG] Session: Auto-waking up \(self.account.name)...")
                self.ping(isAuto: true)
            }
        }

        if let email = usageData.email, self.account.name.starts(with: "Account ") {
            self.account.name = email
        }
    }
    
    /// Determines whether a value has crossed the given threshold upward since the previous measurement.
    /// - Parameters:
    ///   - previous: The previous value, or `nil` if none is available.
    ///   - current: The current value to compare against the threshold.
    ///   - threshold: The threshold to test for crossing.
    /// - Returns: `true` if a previous value exists and it was below `threshold` while `current` is greater than or equal to `threshold`, `false` otherwise.
    private func didCrossThreshold(previous: Double?, current: Double, threshold: Double) -> Bool {
        guard let prev = previous else { return false }
        return prev < threshold && current >= threshold
    }

    /// Determines whether the session usage transitioned from a non-zero value to a reset-ready state.
    /// - Parameters:
    ///   - previousPercentage: The previous session usage percentage, or `nil` if unknown.
    ///   - currentPercentage: The current session usage percentage.
    ///   - currentReset: The current session reset status string (e.g., `"Ready"`).
    /// - Returns: `true` if a previous percentage exists and was greater than 0, the current percentage is 0, and the current reset status equals `"Ready"`; `false` otherwise.
    private func didTransitionToReady(previousPercentage: Double?, currentPercentage: Double, currentReset: String) -> Bool {
        guard let prev = previousPercentage else { return false }
        return prev > 0 && currentPercentage == 0 && currentReset == "Ready"
    }

    /// Sends notifications when usage crosses configured thresholds or when a session resets to Ready.
    /// 
    /// Iterates configured session and weekly threshold definitions and, for each one that was crossed upward
    /// compared to the stored previous percentages and is enabled in user notification settings, posts a notification
    /// for that threshold. If the session percentage transitions to zero with a `sessionReset` of `"Ready"`,
    /// posts a session-ready notification when allowed by settings.
    private func checkThresholdCrossingsAndNotify(usageData: UsageData) {
        let accountName = account.name

        for config in ThresholdDefinitions.sessionThresholds
        where didCrossThreshold(previous: previousSessionPercentage, current: usageData.sessionPercentage, threshold: config.threshold)
            && NotificationSettings.shouldSend(type: config.notificationType) {
            let thresholdPercent = Int(config.threshold * 100)
            NotificationManager.shared.sendNotification(type: config.notificationType, accountName: accountName, thresholdPercent: thresholdPercent)
        }

        for config in ThresholdDefinitions.weeklyThresholds
        where didCrossThreshold(previous: previousWeeklyPercentage, current: usageData.weeklyPercentage, threshold: config.threshold)
            && NotificationSettings.shouldSend(type: config.notificationType) {
            let thresholdPercent = Int(config.threshold * 100)
            NotificationManager.shared.sendNotification(type: config.notificationType, accountName: accountName, thresholdPercent: thresholdPercent)
        }

        if didTransitionToReady(previousPercentage: previousSessionPercentage, currentPercentage: usageData.sessionPercentage, currentReset: usageData.sessionReset) {
            if NotificationSettings.shouldSend(type: .sessionReady) {
                NotificationManager.shared.sendNotification(type: .sessionReady, accountName: accountName)
            }
        }
    }

    /// Configure the tracker callbacks to apply incoming usage updates and handle errors.
    ///
    /// Sets `tracker?.onUpdate` to update `isFetching` and integrate new usage data (on the main queue),
    /// and sets `tracker?.onError` to clear `isFetching` and log the failure.
    private func setupTracker() {
        tracker?.onUpdate = { [weak self] usageData in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isFetching = false
                var data = usageData
                data.sessionResetDisplay = usageData.sessionReset
                self.updateWithUsageData(data)
            }
        }

        tracker?.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.isFetching = false
                print("[ERROR] Session: Fetch failed for \(self?.account.name ?? "?"): \(error)")
            }
        }
    }
}