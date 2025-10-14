//
// NotificationName.swift
// TMTL 2
//
// Created by Jaden Schwartz on 6/17/25.
//

import Foundation
extension Notification.Name {
/// App-wide tab/navigation notifications
static let requestNotifications  = Notification.Name("requestNotifications")
static let switchToAddWisdomTab  = Notification.Name("switchToAddWisdomTab")
static let switchToRepositoryTab = Notification.Name("switchToRepositoryTab")
static let switchToMyPostsTab  = Notification.Name("switchToMyPostsTab")
static let didSelectMyPost = Notification.Name("didSelectMyPost")
static let didTapRepositoryTab = Notification.Name("didTapRepositoryTab")
static let didTapMyPostsTab  = Notification.Name("didTapMyPostsTab")
static let didTapMyPostsTabManual  = Notification.Name("didTapMyPostsTabManual")
static let didSelectRepositoryPost = Notification.Name("didSelectRepositoryPost")
static let didPostWisdom = Notification.Name("didPostWisdom")

/// Comments & reporting flow
static let openComments  = Notification.Name("openComments")
static let closeComments = Notification.Name("closeComments")
static let commentsViewed  = Notification.Name("commentsViewed")
static let scrollToCommentBottom = Notification.Name("scrollToCommentBottom")
}
