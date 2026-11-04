// RepositoryView.swift
// TMTL 2
// ☎️
// Created by Jaden Schwartz on 6/4/25.

import SwiftUI

struct RepositoryView: View {
    // MARK: – Inputs from parent (TMTL2Page)
    let wisdomList: [WisdomEntry]
    let userReactions: [String: ReactionType]
    let votesToday: Int
    let maxVotes: Int
    let isLoading: Bool

    @Binding var searchText: String
    @Binding var showSearch: Bool
    @FocusState var searchFieldFocused: Bool

    @Binding var showLimitAlert: Bool
    @Binding var showReportAlert: Bool
    @Binding var showBlockAlert: Bool
    @Binding var blockAlertMessage: String
    @Binding var reportAlertMessage: String

    let idleBolt: LinearGradient
    let activeBolt: LinearGradient
    let idleCloud: LinearGradient
    let activeCloud: LinearGradient

    let currentUserId: String

    // ── Path for NavigationStack to push CommentsView
    @State private var navigationPath: [String] = []

    // Actions injected by parent
    let loadAction: () -> Void
    let voteAction: (WisdomEntry, ReactionType) -> Void
    let reportAction: (WisdomEntry) -> Void
    let blockAction: (WisdomEntry) -> Void

    /// Live post with the highest score (ties: earliest). Nil unless someone scored >= 1.
    private var topPost: WisdomEntry? {
        wisdomList
            .filter { $0.expiresAt > Date() && $0.score >= 1 }
            .min { ($0.score, $1.createdAt) > ($1.score, $0.createdAt) }
    }

    // Filtered array, based on searchText
    private var filteredWisdom: [WisdomEntry] {
        guard !searchText.isEmpty else { return wisdomList }
        return wisdomList.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                contentGroup
                searchOverlay
            }
            .background(Color.black)      // ← fix 1/2
            .ignoresSafeArea()            // ← fix 2/2
            .copyToast()

            // Alerts
            .alert("Daily limit reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You may only judge \(maxVotes) entries per day.")
            }
            .alert(reportAlertMessage, isPresented: $showReportAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert(blockAlertMessage, isPresented: $showBlockAlert) {
                Button("OK", role: .cancel) {}
            }

            // Deep‐link navigation
            .navigationDestination(for: String.self) { postId in
                if let entry = wisdomList.first(where: { $0.id == postId }) {
                    CommentsView(wisdom: entry)
                } else {
                    EmptyView()
                }
            }
        }
    }

    // MARK: – Main content switching
    private var contentGroup: some View {
        Group {
            if isLoading && wisdomList.isEmpty {
                initialLoadingView
            } else if isLoading {
                refreshLoadingView
            } else if wisdomList.isEmpty {
                emptyWisdomView
            } else {
                wisdomListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var initialLoadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading Wisdom…")
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .foregroundColor(.white)
                .padding()
            Spacer()
        }
    }

    private var refreshLoadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
                .padding(.top, 16)
            Spacer()
        }
    }

    private var emptyWisdomView: some View {
        VStack {
            Spacer()
            Text("The ink has run dry — add some wisdom.")
                .foregroundColor(.white)
                .font(.custom("Palatino", size: 20))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 40)
            Spacer()
        }
    }

    private func topPostCard(_ entry: WisdomEntry) -> some View {
        Button { navigationPath = [entry.id] } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Top this month", systemImage: "crown.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("\(entry.createdAt.formatted(.dateTime.month(.abbreviated).day())) · \(entry.score) ⚡")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(entry.text)
                    .font(.custom("Palatino", size: 18))
                    .foregroundColor(.white)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .neumorphic()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: – The scrollable list
    private var wisdomListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Reserve space under the overlay
                Color.clear
                    .frame(height: showSearch ? 70 : 20)
                    .id("top")

                VStack(alignment: .leading, spacing: 20) {
                    if searchText.isEmpty, let top = topPost { topPostCard(top) }
                    ForEach(filteredWisdom) { entry in
                        ZStack {
                            // hidden link for programmatic scroll
                            NavigationLink(value: entry.id) { EmptyView() }
                                .hidden()

                            // visible row
                            NavigationLink(destination: CommentsView(wisdom: entry)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    WisdomRow(
                                        entry: entry,
                                        hasVoted: userReactions[entry.id] != nil,
                                        isMine: entry.authorId == currentUserId,
                                        upAction: { voteOrAlert(entry, type: .up) },
                                        downAction: { voteOrAlert(entry, type: .down) },
                                        idleBolt: idleBolt,
                                        activeBolt: activeBolt,
                                        idleCloud: idleCloud,
                                        activeCloud: activeCloud,
                                        userReaction: userReactions[entry.id]
                                    )
                                    Text("\(entry.commentCount) comments")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button { Clipboard.copy(entry.text) } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                Button(role: .destructive) { reportAction(entry) } label: {
                                    Label("Report", systemImage: "flag.fill")
                                }
                                Button { blockAction(entry) } label: {
                                    Label("Block User", systemImage: "hand.raised.fill")
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 80)
            }
            .refreshable { loadAction() }
            .animation(nil, value: filteredWisdom.map(\.id)) // ← use IDs to avoid Equatable requirement

            // handle deep-link then repost for bottom scroll
            .onReceive(NotificationCenter.default.publisher(for: .openComments)) { notif in
                guard let postId = notif.userInfo?["postId"] as? String else { return }
                withAnimation { proxy.scrollTo(postId, anchor: .top) }
                DispatchQueue.main.async {
                    navigationPath = [postId]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NotificationCenter.default.post(
                            name: .scrollToCommentBottom,
                            object: nil,
                            userInfo: notif.userInfo
                        )
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didTapRepositoryTab)) { _ in
                DispatchQueue.main.async {
                    if CommentsView.didHandleRepoTap {
                        CommentsView.didHandleRepoTap = false
                    } else {
                        withAnimation { proxy.scrollTo("top", anchor: .top) }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didSelectMyPost)) { notif in
                if let postId = notif.userInfo?["postId"] as? String {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation { proxy.scrollTo(postId, anchor: .center) }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didSelectRepositoryPost)) { notif in
                guard let postId = notif.userInfo?["postId"] as? String else { return }
                withAnimation { proxy.scrollTo(postId, anchor: .center) }
            }
        }
    }

    // MARK: – Search button & field overlay
    @ViewBuilder
    private var searchOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    withAnimation { showSearch.toggle() }
                    if showSearch { searchFieldFocused = true }
                    else { searchText = "" }
                } label: {
                    Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .padding(.trailing, 16)
            }

            if showSearch {
                TextField("Search wisdom…", text: $searchText)
                    .focused($searchFieldFocused)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer().frame(height: showSearch ? 8 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: showSearch ? 96 : 52, alignment: .top)
        .contentShape(Rectangle())
        .background(Color.black.opacity(0.001))
        .offset(y: -25)   // move ONLY the search overlay up a bit
        .zIndex(10)

        // Keyboard toolbar scoped to this overlay (and its TextField)
        .toolbar {
            if showSearch && searchFieldFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { searchFieldFocused = false }
                }
            }
        }
    }

    // MARK: – Helpers
    private func voteOrAlert(_ entry: WisdomEntry, type: ReactionType) {
        if votesToday < maxVotes {
            voteAction(entry, type)
        } else {
            showLimitAlert = true
        }
    }
}
