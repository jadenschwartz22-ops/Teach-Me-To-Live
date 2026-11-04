import UIKit
import UserNotifications

/// One home for OS notification permission. iOS Settings is the only opt-out;
/// when it is off the feed shows a banner, and we ask early while undecided.
@MainActor
final class NotificationAccess: ObservableObject {
    static let shared = NotificationAccess()

    @Published private(set) var isOff = false
    @Published var showWhy = false

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in await NotificationAccess.shared.refresh() }
        }
    }

    /// Re-read the OS setting; also (re)registers for remote notifications when allowed.
    func refresh() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        isOff = status == .denied
        if status == .authorized || status == .provisional { UIApplication.shared.registerForRemoteNotifications() }
        if status == .notDetermined { showWhy = true }
    }

    func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        await refresh()
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
    }
}
