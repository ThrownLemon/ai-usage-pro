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

    override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }

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
