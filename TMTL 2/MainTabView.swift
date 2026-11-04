//☎️
import SwiftUI
import UIKit
struct MainTabView: View {
    @State private var selection: Int = 0
    @ObservedObject private var notifications = NotificationAccess.shared
    var body: some View {
        ZStack {
            // ① Paint the entire screen (including behind status bar) black
            Color.black
                .ignoresSafeArea(.all)
            // ② Overlay the custom UITabBarController
            CustomTabBarController(selection: $selection)
            // Let it extend under the bottom safe area as before
                .edgesIgnoringSafeArea(.bottom)
        }
        .task { await notifications.refresh() }
        .alert("Get a ping when someone shares wisdom", isPresented: $notifications.showWhy) {
            Button("Continue") { Task { await notifications.request() } }
        }
    }
}
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}


struct CustomTabBarController: UIViewControllerRepresentable {
    @Binding var selection: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        // 1) Force all UINavigationBars to be black
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = .black
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // 2) Create the UITabBarController
        let tabBarController = UITabBarController()

        // Ensure the controller's root view is black
        tabBarController.view.backgroundColor = .black

        // ── Observe “switchToRepositoryTab” and switch to tab index 1
        NotificationCenter.default.addObserver(
            forName: .switchToRepositoryTab,
            object: nil,
            queue: .main
        ) { _ in
            print("🛠 CustomTabBarController: received switchToRepositoryTab → selecting tab index 1")
            UIView.performWithoutAnimation {
                tabBarController.selectedIndex = 1
                tabBarController.view.layoutIfNeeded()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .switchToMyPostsTab,
            object: nil,
            queue: .main
        ) { _ in
            UIView.performWithoutAnimation {
                tabBarController.selectedIndex = 3
                tabBarController.view.layoutIfNeeded()
            }
        }

        // ─── Welcome tab (index 0) ───
        let welcomeRoot = WelcomeView(selection: $selection)
            .ignoresSafeArea(.all, edges: .all)
        let welcomeVC = UIHostingController(rootView: welcomeRoot)
        welcomeVC.tabBarItem = UITabBarItem(
            title: "Welcome",
            image: UIImage(systemName: "house.fill"),
            tag: 0
        )
        welcomeVC.view.backgroundColor = .black

        // ─── Repository tab (index 1) ───
        // Repository tab: host your repo page in a NavigationStack with a black background
        let repoRoot = NavigationStack {
            TMTL2Page()
        }
        .ignoresSafeArea(.all, edges: .all)
        .background(Color.black)
        let repoVC = UIHostingController(rootView: repoRoot)
        repoVC.tabBarItem = UITabBarItem(
            title: "Repository",
            image: UIImage(systemName: "bolt.circle"),
            tag: 1
        )
        repoVC.view.backgroundColor = .black

        // ✅ Pre-warm to avoid first-switch construction delay
        repoVC.loadViewIfNeeded()


        // ─── Add Wisdom tab (index 2) ───
        let addWisdomRoot = AddWisdomView()
            .ignoresSafeArea(.all, edges: .all)
        let addWisdomVC = UIHostingController(rootView: addWisdomRoot)
        addWisdomVC.tabBarItem = UITabBarItem(
            title: "Add Wisdom",
            image: UIImage(systemName: "square.and.pencil"),
            tag: 2
        )
        addWisdomVC.view.backgroundColor = .black

        // ─── My Posts tab (index 3) ───
        let myPostsRoot = MyPostsView()
            .ignoresSafeArea(.all, edges: .all)
        let myPostsVC = UIHostingController(rootView: myPostsRoot)
        myPostsVC.tabBarItem = UITabBarItem(
            title: "My Posts",
            image: UIImage(systemName: "person.circle"),
            tag: 3
        )
        myPostsVC.view.backgroundColor = .black

        #if DEBUG
        // ─── Reports tab (index 4) ───
        let reportsRoot = ReportedContentView()
            .ignoresSafeArea(.all, edges: .all)
        let reportsVC = UIHostingController(rootView: reportsRoot)
        reportsVC.tabBarItem = UITabBarItem(
            title: "Reports",
            image: UIImage(systemName: "exclamationmark.bubble"),
            tag: 4
        )
        reportsVC.view.backgroundColor = .black

        tabBarController.viewControllers = [
            welcomeVC,
            repoVC,
            addWisdomVC,
            myPostsVC,
            reportsVC
        ]
        #else
        tabBarController.viewControllers = [
            welcomeVC,
            repoVC,
            addWisdomVC,
            myPostsVC
        ]
        #endif

        // Sync initial selection
        tabBarController.selectedIndex = selection
        tabBarController.delegate = context.coordinator

        // ─── Tab‐bar appearance: black background, gray unselected, white selected ───
        let appearance = UITabBarAppearance()
        appearance.backgroundColor = UIColor.black
        appearance.stackedLayoutAppearance.normal.iconColor = .gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        tabBarController.tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBarController.tabBar.scrollEdgeAppearance = appearance
        }

        return tabBarController
    }

    func updateUIViewController(_ uiViewController: UITabBarController, context: Context) {
        if uiViewController.selectedIndex != selection {
            UIView.performWithoutAnimation {
                uiViewController.selectedIndex = selection
                uiViewController.view.layoutIfNeeded()
            }
        }
    }

    class Coordinator: NSObject, UITabBarControllerDelegate {
        var parent: CustomTabBarController
        init(_ parent: CustomTabBarController) {
            self.parent = parent
        }

        func tabBarController(
            _ tabBarController: UITabBarController,
            didSelect viewController: UIViewController
        ) {
            UIView.performWithoutAnimation {
                let previous = parent.selection
                let current  = tabBarController.selectedIndex
                parent.selection = current

                // If “Repository” (1) was tapped again
                if previous == 1 && current == 1 {
                    NotificationCenter.default.post(name: .didTapRepositoryTab, object: nil)
                }
                // If “My Posts” (3) was tapped again
                if previous == 3 && current == 3 {
                    NotificationCenter.default.post(name: .didTapMyPostsTabManual, object: nil)
                }
            }
        }
    }
}
