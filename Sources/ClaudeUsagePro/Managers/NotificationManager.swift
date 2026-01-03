import Foundation
import UserNotifications

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // Callback-based pattern following TrackerService
    var onPermissionGranted: (() -> Void)?
    var onPermissionDenied: (() -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Rate Limiting

    // Track last notification time per account per type to prevent spam
    // Key format: "accountName:notificationType.identifier"
    private var lastNotificationTimes: [String: Date] = [:]
    private let cooldownInterval: TimeInterval = 5 * 60 // 5 minutes

    override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }

    // MARK: - Notification Types

    enum NotificationType {
        case sessionThreshold75
        case sessionThreshold90
        case weeklyThreshold75
        case weeklyThreshold90
        case sessionReady

        var identifier: String {
            switch self {
            case .sessionThreshold75:
                return "session.threshold.75"
            case .sessionThreshold90:
                return "session.threshold.90"
            case .weeklyThreshold75:
                return "weekly.threshold.75"
            case .weeklyThreshold90:
                return "weekly.threshold.90"
            case .sessionReady:
                return "session.ready"
            }
        }
    }

    // MARK: - Notification Content Builders

    struct NotificationContent {
        let title: String
        let body: String
        let identifier: String
    }

    func buildNotificationContent(
        type: NotificationType,
        accountName: String
    ) -> NotificationContent {
        let title: String
        let body: String

        switch type {
        case .sessionThreshold75:
            title = "Usage Alert"
            body = "\(accountName): Session usage has reached 75%"

        case .sessionThreshold90:
            title = "Usage Alert"
            body = "\(accountName): Session usage has reached 90%"

        case .weeklyThreshold75:
            title = "Usage Alert"
            body = "\(accountName): Weekly usage has reached 75%"

        case .weeklyThreshold90:
            title = "Usage Alert"
            body = "\(accountName): Weekly usage has reached 90%"

        case .sessionReady:
            title = "Session Ready"
            body = "\(accountName): Your session is ready to start"
        }

        return NotificationContent(
            title: title,
            body: body,
            identifier: type.identifier
        )
    }

    // MARK: - Rate Limiting Helpers

    /// Generate a unique key for tracking notification cooldown per account and type
    /// - Parameters:
    ///   - accountName: The name of the account
    ///   - type: The notification type
    /// - Returns: A unique key string in format "accountName:type.identifier"
    func cooldownKey(accountName: String, type: NotificationType) -> String {
        return "\(accountName):\(type.identifier)"
    }

    /// Check if cooldown period has passed since last notification of this type for this account
    /// - Parameters:
    ///   - accountName: The name of the account
    ///   - type: The notification type
    /// - Returns: true if cooldown has passed (can send notification), false if still in cooldown period
    private func canSendNotification(accountName: String, type: NotificationType) -> Bool {
        let key = cooldownKey(accountName: accountName, type: type)

        guard let lastSent = lastNotificationTimes[key] else {
            // Never sent this notification type for this account, so we can send
            return true
        }

        let timeSinceLastSent = Date().timeIntervalSince(lastSent)
        return timeSinceLastSent >= cooldownInterval
    }

    /// Record that a notification was sent for rate limiting tracking
    /// - Parameters:
    ///   - accountName: The name of the account
    ///   - type: The notification type
    private func recordNotificationSent(accountName: String, type: NotificationType) {
        let key = cooldownKey(accountName: accountName, type: type)
        lastNotificationTimes[key] = Date()
    }

    // MARK: - Permission Management

    // Request notification permission from the user
    func requestPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.onError?(error)
                    return
                }

                self?.checkAuthorizationStatus()

                if granted {
                    self?.onPermissionGranted?()
                } else {
                    self?.onPermissionDenied?()
                }
            }
        }
    }

    // Check current authorization status
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    // Send a notification with the given content
    func sendNotification(title: String, body: String, identifier: String) {
        // Check if notifications are authorized
        guard authorizationStatus == .authorized else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Create a trigger that fires immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Schedule the notification
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.onError?(error)
                }
            }
        }
    }

    // Send a typed notification using the content builder
    func sendNotification(type: NotificationType, accountName: String) {
        // Check cooldown to prevent notification spam
        guard canSendNotification(accountName: accountName, type: type) else {
            return
        }

        let content = buildNotificationContent(type: type, accountName: accountName)
        // Use cooldownKey as identifier to ensure uniqueness per account per type
        sendNotification(title: content.title, body: content.body, identifier: cooldownKey(accountName: accountName, type: type))

        // Record that notification was sent for rate limiting
        recordNotificationSent(accountName: accountName, type: type)
    }

    // Remove pending notifications by identifier
    func removePendingNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // Remove all pending notifications
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // Remove delivered notifications by identifier
    func removeDeliveredNotification(identifier: String) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // Remove all delivered notifications
    func removeAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    // Handle notification interaction (user tapped on it)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap if needed
        completionHandler()
    }
}
