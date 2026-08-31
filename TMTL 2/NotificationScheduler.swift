import Foundation
import UserNotifications

enum NotificationScheduler {
  /// Formerly scheduled wipe-day notifications. Now a no-op that also
  /// cleans up any previously scheduled wipe-day requests to ensure
  /// they don't fire.
  static func scheduleWipeDayNotifications() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["WipeDayTomorrow", "WipeDayToday"])
  }

  /// Posting is unlimited, so the old "you may post again" reminder no longer
  /// applies. Cancels any request left pending from a previous version and
  /// clears the stored cooldown so nothing re-arms it.
  static func scheduleWisdomReadyIfPending() {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let stale = requests.map(\.identifier).filter { $0.hasPrefix("WisdomReady-") }
      guard !stale.isEmpty else { return }
      center.removePendingNotificationRequests(withIdentifiers: stale)
    }
    UserDefaults.standard.removeObject(forKey: "nextWisdomSubmission")
  }
}
