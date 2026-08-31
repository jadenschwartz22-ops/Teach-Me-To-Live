import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit
import UserNotifications

/// One home for the "notify me when someone else posts" preference.
///
/// The value is mirrored to `users/{uid}.notifyOnNewPost`, which the
/// `onWisdomCreate` Cloud Function reads before broadcasting. A missing field
/// means opted in, so existing users keep receiving posts until they opt out.
enum NewPostNotifications {
    static let defaultsKey = "notifyOnNewPost"

    /// Local mirror of the stored preference. Defaults to on.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    /// Persists the preference locally and to Firestore. When enabling, makes
    /// sure we actually hold push permission and a fresh FCM token first —
    /// otherwise the flag is on but no device is reachable.
    static func setEnabled(_ enabled: Bool, completion: ((Bool) -> Void)? = nil) {
        guard enabled else {
            persist(false)
            completion?(false)
            return
        }

        requestAuthorizationIfNeeded { granted in
            persist(granted)
            completion?(granted)
        }
    }

    private static func persist(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .setData(["notifyOnNewPost": enabled], merge: true)
    }

    private static func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    completion(true)
                }
            case .denied:
                // Only Settings can undo a denial; report failure so the UI can say so.
                DispatchQueue.main.async { completion(false) }
            default:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted { UIApplication.shared.registerForRemoteNotifications() }
                        completion(granted)
                    }
                }
            }
        }
    }
}
