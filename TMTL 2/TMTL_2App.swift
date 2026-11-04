// TMTL2App.swift
// ☎️

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications

@main
struct TMTL2App: App {
    // Track EULA acceptance
    @AppStorage("hasAcceptedEULA") private var hasAcceptedEULA = false

    // Forward UNUserNotificationCenterDelegate and FCM delegate methods
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // 🔇 Lower Firebase SDK logging noise BEFORE configure
        FirebaseConfiguration.shared.setLoggerLevel(.min)   // ⬅️ added

        // 1️⃣ Configure Firebase
        FirebaseApp.configure()

        
            }
        

    var body: some Scene {
        WindowGroup {
            if hasAcceptedEULA {
                MainTabView()
                    // ① catch deep-links at runtime
                    .onOpenURL { url in
                        print("📥 onOpenURL: \(url)")
                        handleDeepLink(url)
                    }
                    // ② handle a cold-launch from tapping a notification
                    .onAppear {
                        if let pending = appDelegate.launchNotificationUserInfo {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                appDelegate.handlePushUserInfo(pending)
                                appDelegate.launchNotificationUserInfo = nil
                            }
                        }
                        
                        NotificationScheduler.scheduleWisdomReadyIfPending()
                    

                    }
            } else {
                TermsView(
                    onAccept: { hasAcceptedEULA = true },
                    onDecline: { exit(0) }
                )
            }
        }
    }

    /// Parses our tmtl2:// URLs and posts the same NotificationCenter events,
    /// now including an optional `commentId` for comments deep-links.
    private func handleDeepLink(_ url: URL) {
        print("🔍 handleDeepLink got URL:", url)
        guard let host = url.host else { return }

        switch host {
        case "post":
            // tmtl2://post/<postId> → My Posts
            if let postId = url.pathComponents.dropFirst().first {
                NotificationCenter.default.post(name: .switchToMyPostsTab, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("➡️ deep-link → didSelectMyPost(\(postId))")
                    NotificationCenter.default.post(
                        name: .didSelectMyPost,
                        object: nil,
                        userInfo: ["postId": postId]
                    )
                }
            }

        case "comments":
            // tmtl2://comments?wisdomId=<postId>&commentId=<commentId> → My Posts → CommentsView
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let wisdomId = components.queryItems?.first(where: { $0.name == "wisdomId" })?.value
            {
                let commentId = components.queryItems?.first(where: { $0.name == "commentId" })?.value

                // 1) switch to My Posts
                NotificationCenter.default.post(name: .switchToMyPostsTab, object: nil)

                // 2) after 0.5s, dismiss any existing CommentsView
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .closeComments, object: nil)
                }

                // 3) after 0.6s, open the new CommentsView
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    print("➡️ deep-link → openComments(\(wisdomId))")
                    var info: [String: Any] = ["postId": wisdomId]
                    if let cid = commentId { info["commentId"] = cid }
                    NotificationCenter.default.post(
                        name: .openComments,
                        object: nil,
                        userInfo: info
                    )
                }
            }

        case "repoComments":
            // tmtl2://repoComments?wisdomId=<postId>&commentId=<commentId> → Repository → CommentsView
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let wisdomId = components.queryItems?.first(where: { $0.name == "wisdomId" })?.value
            {
                let commentId = components.queryItems?.first(where: { $0.name == "commentId" })?.value

                // 1) switch to Repository
                NotificationCenter.default.post(name: .switchToRepositoryTab, object: nil)

                // 2) after 0.5s, dismiss any existing CommentsView
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .closeComments, object: nil)
                }

                // 3) after 0.6s, open the new CommentsView
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    print("➡️ deep-link → openComments in Repository(\(wisdomId))")
                    var info: [String: Any] = ["postId": wisdomId]
                    if let cid = commentId { info["commentId"] = cid }
                    NotificationCenter.default.post(
                        name: .openComments,
                        object: nil,
                        userInfo: info
                    )
                }
            }

        case "repository":
            // tmtl2://repository or tmtl2://repository/<postId> → Repository scroll
            let comps = url.pathComponents.dropFirst()
            NotificationCenter.default.post(name: .switchToRepositoryTab, object: nil)
            if let postId = comps.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("➡️ deep-link → didSelectRepositoryPost(\(postId))")
                    NotificationCenter.default.post(
                        name: .didSelectRepositoryPost,
                        object: nil,
                        userInfo: ["postId": postId]
                    )
                }
            }

        case "yearInReview":
            // tmtl2://yearInReview → Repository → Year in Review list
            Task { @MainActor in YearInReview.shared.open() }

        default:
            print("⚠️ Unknown deep-link host:", host)
        }
    }
}
