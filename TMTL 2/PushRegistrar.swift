import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

enum PushRegistrar {
    static func ensureFCMTokenSaved() {
        Messaging.messaging().token { token, error in
            guard error == nil, let token = token, let uid = Auth.auth().currentUser?.uid else { return }
            Firestore.firestore().collection("users").document(uid).setData(["fcmToken": token], merge: true)
            Messaging.messaging().subscribe(toTopic: "announcements", completion: nil)
        }
    }
}
