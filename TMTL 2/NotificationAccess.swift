import UIKit
import UserNotifications

/// One home for OS notification permission. iOS Settings is the only opt-out;
/// when it is off the feed shows a banner, and we ask early while undecided.
@MainActor
final class NotificationAccess: ObservableObject {
    static let shared = NotificationAccess()

    @Published private(set) var status = UNAuthorizationStatus.notDetermined
    var isOff: Bool { status == .denied }
    var isOn: Bool { status == .authorized || status == .provisional || status == .ephemeral }
    @Published var showWhy = false

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in await NotificationAccess.shared.refresh() }
        }
    }

    /// Re-read the OS setting; also (re)registers for remote notifications when allowed.
    func refresh() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if isOn { UIApplication.shared.registerForRemoteNotifications() }
        if status == .notDetermined { showWhy = true }
    }

    func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        await refresh()
    }

    /// iOS owns the switch: ask while undecided, otherwise send the person to Settings.
    func toggleTapped() {
        if status == .notDetermined { Task { await request() } } else { openSettings() }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
    }
}
