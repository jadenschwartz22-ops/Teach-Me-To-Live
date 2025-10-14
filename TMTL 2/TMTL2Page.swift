// TMTL2Page.swift
//☎️
import SwiftUI
import FirebaseAuth

struct TMTL2Page: View {
    @AppStorage("devWipeDayOverride") private var devWipeDayOverride = false
    @State private var blockedUsers: [String] = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? []
    @StateObject private var viewModel = VotingViewModel()
    @State private var searchText = ""
    @State private var showSearch = false
    @FocusState private var searchFieldFocused: Bool
    @State private var showLimitAlert = false
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    @State private var blockAlertMessage = ""
    @State private var reportAlertMessage = ""
    // NEW: control the rain emitter so it pauses off-tab and doesn't restart stacks
    @State private var rainOn = true

    private var isWipeDay: Bool {
#if DEBUG
        if devWipeDayOverride { return true }
#endif
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        return cal.component(.day, from: Date()) == 1
    }

    private let idleBoltGradient = LinearGradient(
        colors: [Color.yellow.opacity(0.6), Color.yellow.opacity(0.4)],
        startPoint: .top, endPoint: .bottom
    )
    private let activeBoltGradient = LinearGradient(
        colors: [Color.white, Color.yellow],
        startPoint: .top, endPoint: .bottom
    )
    private let idleCloudGradient = LinearGradient(
        colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
        startPoint: .top, endPoint: .bottom
    )
    private let activeCloudGradient = LinearGradient(
        colors: [Color.blue, Color.blue],
        startPoint: .top, endPoint: .bottom
    )

    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    @State private var hasLoadedOnce = false

    @State private var countdownText = ""
    private let countdownTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            // was: RainEmitter(animate: true, maxBirthRate: 5)
            RainEmitter(animate: rainOn, maxBirthRate: 5)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(1)
            VStack(spacing: 0) {
                debugButton
                Text(isWipeDay ? "Like Tears in Rain…" : "The Repository")
                    .foregroundColor(.white)
                    .font(.custom("Palatino", size: 28))
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                if !isWipeDay && !countdownText.isEmpty {
                    Text(countdownText)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)
                } else {
                    Spacer().frame(height: 8)
                }
                if isWipeDay {
                    WipeDayView(
                        lastMonthTop: viewModel.lastMonthTop,
                        loadLastMonthTop: { viewModel.loadLastMonthTop() }
                    )
                } else {
                    RepositoryView(
                        wisdomList: viewModel.wisdomList,
                        userReactions: viewModel.userReactions,
                        votesToday: viewModel.votesToday,
                        maxVotes: viewModel.maxVotes,
                        isLoading: viewModel.isLoading,
                        searchText: $searchText,
                        showSearch: $showSearch,
                        searchFieldFocused: _searchFieldFocused,
                        showLimitAlert: $showLimitAlert,
                        showReportAlert: $showReportAlert,
                        showBlockAlert: $showBlockAlert,
                        blockAlertMessage: $blockAlertMessage,
                        reportAlertMessage: $reportAlertMessage,
                        idleBolt: idleBoltGradient,
                        activeBolt: activeBoltGradient,
                        idleCloud: idleCloudGradient,
                        activeCloud: activeCloudGradient,
                        currentUserId: currentUserId,
                        loadAction: { Task { await viewModel.load() } },
                        voteAction: viewModel.vote(_:type:),
                        reportAction: { entry in
                            FirestoreService.shared.addReport(
                                wisdomId: entry.id,
                                reporterId: viewModel.userId,
                                reason: "Inappropriate content"
                            ) { error in
                                if error != nil {
                                    print("🚩 Failed to report.")
                                    reportAlertMessage = "Report failed. Please try again."
                                } else {
                                    reportAlertMessage = "Thanks—post reported."
                                    Task { await viewModel.load() }
                                }
                                showReportAlert = true
                            }
                        },
                        blockAction: { entry in
                            if entry.authorId == currentUserId {
                                blockAlertMessage = "You can’t block yourself."
                                showBlockAlert = true
                                return
                            }
                            if !blockedUsers.contains(entry.authorId) {
                                blockedUsers.append(entry.authorId)
                                UserDefaults.standard.set(blockedUsers, forKey: "blockedUsers")
                            }
                            blockAlertMessage = "User blocked until next wipe-day."
                            showBlockAlert = true
                        }
                    )
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    if searchFieldFocused {
                        searchFieldFocused = false
                    }
                }
            )
            .onAppear {
                if isWipeDay {
                    blockedUsers = []
                    UserDefaults.standard.removeObject(forKey: "blockedUsers")
                } else {
                    updateCountdown()
                }

                // ✅ Show spinner immediately, then start loading after the view is on-screen
                viewModel.isLoading = true
                DispatchQueue.main.async {
                    Task { await viewModel.load() }
                }

                // keep your existing visuals
                rainOn = true
            }

            .onDisappear {
                // NEW: pause rain when leaving this tab/view
                rainOn = false
                viewModel.stopListening()     
            }
            .onReceive(countdownTimer) { _ in
                if isWipeDay {
                    countdownText = ""
                } else {
                    updateCountdown()
                }
            }
            .onChange(of: isWipeDay) { _, newValue in
                if newValue {
                    viewModel.loadLastMonthTop()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didPostWisdom)) { _ in
                Task { await viewModel.load() }
            }
            .alert("Daily limit reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You may only judge \(viewModel.maxVotes) entries per day.")
            }
            .alert(reportAlertMessage, isPresented: $showReportAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert(blockAlertMessage, isPresented: $showBlockAlert) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: viewModel.isLoading) { _, newValue in
                print("👁‍🗨 TMTL2Page sees viewModel.isLoading = \(newValue)")
            }

        }
    }

    private var debugButton: some View {
#if DEBUG
        Button {
            devWipeDayOverride.toggle()
        } label: {
            Text(devWipeDayOverride ? "🚨 WIPE-DAY ON" : "wipe-day off")
                .font(.caption2)
                .foregroundColor(.yellow)
                .padding(.top, 10)
        }
#else
        EmptyView()
#endif
    }

    private func startOfNextMonthMT(from now: Date = Date()) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        var comps = cal.dateComponents([.year, .month], from: now)
        comps.day = 1
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        let startOfThisMonth = cal.date(from: comps)!
        return cal.date(byAdding: DateComponents(month: 1), to: startOfThisMonth)!
    }

    private func updateCountdown() {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/Denver")!

        let target = startOfNextMonthMT()
        let startOfTodayMT = cal.startOfDay(for: Date())
        let startOfTargetMT = cal.startOfDay(for: target)

        let days = max(0, cal.dateComponents([.day], from: startOfTodayMT, to: startOfTargetMT).day ?? 0)
        countdownText = days == 1 ? "1 day until Wipe Day" : "\(days) days until Reset"
    }

    private func processLaunchNotificationIfNeeded() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let launchInfo = appDelegate.launchNotificationUserInfo
        else { return }
        appDelegate.launchNotificationUserInfo = nil
        if let type = launchInfo["type"] as? String {
            switch type {
            case "comment":
                if let postId = launchInfo["wisdomId"] as? String {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .switchToRepositoryTab, object: nil)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print(" → (cold) posting openComments(\(postId))")
                        NotificationCenter.default.post(
                            name: .openComments,
                            object: nil,
                            userInfo: ["postId": postId]
                        )
                    }
                }
            case "like":
                if let postId = launchInfo["wisdomId"] as? String {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .switchToRepositoryTab, object: nil)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print(" → (cold) posting didSelectMyPost(\(postId))")
                        NotificationCenter.default.post(
                            name: .didSelectMyPost,
                            object: nil,
                            userInfo: ["postId": postId]
                        )
                    }
                }
            case "wipeDay":
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .switchToRepositoryTab, object: nil)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print(" → (cold) posting didTapRepositoryTab (wipeDay)")
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
}

struct TMTL2Page_Previews: PreviewProvider {
    static var previews: some View {
        TMTL2Page()
    }
}
