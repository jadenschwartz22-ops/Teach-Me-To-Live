import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

enum PushRegistrar {
    /// Fetch the current FCM token and store it on users/{uid}. Safe to call any time.
    static func ensureFCMTokenSaved() {
        Messaging.messaging().token { token, error in
            guard error == nil, let token else { return }
            save(token)
        }
    }

    static func save(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).setData(["fcmToken": token], merge: true)
        Messaging.messaging().subscribe(toTopic: "announcements", completion: nil)
    }
}
