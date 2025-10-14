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

  static func scheduleWisdomReady(at date: Date) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { s in
      guard s.authorizationStatus == .authorized else { return }
      var cal = Calendar.current
      cal.timeZone = TimeZone(identifier: "America/Denver")!
      let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

      let content = UNMutableNotificationContent()
      content.title = "Post Wisdom Ready"
      content.body  = "Your wait is over, share new wisdom now!"
      content.sound = .default

      let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
      let request = UNNotificationRequest(
        identifier: "WisdomReady-\(Int(date.timeIntervalSince1970))",
        content: content,
        trigger: trigger
      )
      center.add(request, withCompletionHandler: nil)
    }
  }

  static func scheduleWisdomReadyIfPending() {
    let ts = UserDefaults.standard.double(forKey: "nextWisdomSubmission")
    guard ts > Date().timeIntervalSince1970 else { return }
    scheduleWisdomReady(at: Date(timeIntervalSince1970: ts))
  }
}
