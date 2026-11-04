import UIKit
import UserNotifications
import Firebase
import FirebaseAuth
import FirebaseMessaging
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    var launchNotificationUserInfo: [AnyHashable: Any]?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            launchNotificationUserInfo = remote
        }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        signInAnonymouslyAndSaveToken()
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Swift.print("✅ APNs token set on FCM.")
        PushRegistrar.ensureFCMTokenSaved()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Swift.print("❌ Failed to register for APNs:", error.localizedDescription)
    }

    private func signInAnonymouslyAndSaveToken() {
        Auth.auth().signInAnonymously { authResult, error in
            if let err = error {
                Swift.print("💥 Auth error:", err.localizedDescription)
                return
            }
            guard let user = authResult?.user else {
                Swift.print("⚠️ Anonymous sign-in returned no user.")
                return
            }
            Swift.print("✅ Signed in anonymously as UID:", user.uid)
            PushRegistrar.ensureFCMTokenSaved()
        }
    }

    @objc
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Swift.print("✅ FCM refreshed token:", token)
        PushRegistrar.save(token)
    }

    @objc
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Swift.print("📬 Foreground push received:", notification.request.content.userInfo)
        completionHandler([.banner, .sound])
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Swift.print("📩 APNs remote notification delivered:", userInfo)
        completionHandler(.newData)
    }

    @objc
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Swift.print("🏷️ didReceive notification, userInfo =", userInfo)

        if let type = userInfo["type"] as? String, type == "comment",
           let postId = userInfo["wisdomId"] as? String {
            var components = URLComponents()
            components.scheme = "tmtl2"
            components.host = "comments"
            var queryItems = [URLQueryItem(name: "wisdomId", value: postId)]
            if let commentId = userInfo["commentId"] as? String {
                queryItems.append(URLQueryItem(name: "commentId", value: commentId))
            }
            components.queryItems = queryItems
            if let url = components.url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                completionHandler()
                return
            }
        }

        if let type = userInfo["type"] as? String, type == "like" || type == "topPost",
           let postId = userInfo["wisdomId"] as? String,
           let url = URL(string: "tmtl2://repository/\(postId)") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            completionHandler()
            return
        }

        if let linkString = userInfo["link"] as? String,
           let url = URL(string: linkString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            completionHandler()
            return
        }

        handlePushUserInfo(userInfo)
        completionHandler()
    }

    func handlePushUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "like":
            if let postId = userInfo["wisdomId"] as? String {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .switchToRepositoryTab, object: nil)
                    NotificationCenter.default.post(name: .didSelectMyPost, object: nil, userInfo: ["postId": postId])
                }
            }
        case "yearInReview":
            Task { @MainActor in YearInReview.shared.open() }
        case "wipeDay":
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .switchToRepositoryTab, object: nil)
                NotificationCenter.default.post(name: .didTapRepositoryTab, object: nil)
            }
        case "addWisdom":
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .switchToAddWisdomTab, object: nil)
            }
        default:
            break
        }
    }
}
