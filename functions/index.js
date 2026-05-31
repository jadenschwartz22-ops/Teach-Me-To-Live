/**
 * Teach Me To Live - Cloud Functions
 *
 * Functions:
 * 1. Archive System - Save deleted posts/comments to time capsule
 * 2. Push Notifications - Like and comment notifications
 *
 * Collections:
 * - wisdom -> deleted_posts_archive (posts)
 * - wisdom/{wisdomId}/comments -> deleted_comments_archive (comments)
 *
 * Archived Data Includes:
 * - Original post/comment data (text, authorId, timestamps, votes, etc.)
 * - Deletion metadata (deletedAt timestamp, deletion reason if available)
 * - Original document ID preserved for reference
 */

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp({
  projectId: process.env.GCP_PROJECT || "tmtl2-59ed3",
});
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════
// PUSH NOTIFICATIONS (Like & Comment)
// ═══════════════════════════════════════════════════════════════════════════

async function getUserFcmToken(uid) {
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data()?.fcmToken || null;
}

/**
 * Send push notification when someone likes a post
 */
exports.onReactionWrite = functions.firestore
  .document('wisdom/{wisdomId}/reactions/{reactionId}')
  .onCreate(async (snapshot, context) => {
    const wisdomId = context.params.wisdomId;
    const reactionData = snapshot.data();

    if (!reactionData) {
      console.log(`Reaction doc missing data—aborting.`);
      return null;
    }

    const reactorId = reactionData.authorId;
    if (!reactorId) {
      console.log(`Reaction ${snapshot.id} has no authorId—skipping.`);
      return null;
    }

    const postSnap = await db.collection("wisdom").doc(wisdomId).get();
    if (!postSnap.exists) {
      console.log(`Wisdom ${wisdomId} not found—aborting like notification.`);
      return null;
    }

    const authorId = postSnap.data().authorId || "";
    console.log(`onReactionWrite → reactorId = ${reactorId}, authorId = ${authorId}`);

    if (reactorId === authorId) {
      console.log(`Skipping self-like notification for user ${reactorId}`);
      return null;
    }

    const fcmToken = await getUserFcmToken(authorId);
    if (!fcmToken) {
      console.log(`No FCM token for ${authorId}—cannot send like notification.`);
      return null;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: "Someone liked your post!",
        body: "Tap to view which post was liked.",
      },
      data: {
        wisdomId,
        type: "like",
        link: `tmtl2://post/${wisdomId}`
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`→ Sent like notification for post ${wisdomId} to user ${authorId}.`);
      return null;
    } catch (err) {
      console.error("❌ Error sending like notification:", err);
      return null;
    }
  });

/**
 * Send push notification when someone comments on a post
 */
exports.onCommentCreate = functions.firestore
  .document('wisdom/{wisdomId}/comments/{commentId}')
  .onCreate(async (snapshot, context) => {
    const wisdomId = context.params.wisdomId;
    const commentId = context.params.commentId;

    // fetch the wisdom post to get its author
    const postSnap = await db.collection("wisdom").doc(wisdomId).get();
    if (!postSnap.exists) {
      console.log(`Wisdom ${wisdomId} not found—aborting comment notification.`);
      return null;
    }
    const authorId = postSnap.data().authorId || "";

    // fetch the new comment to find who posted it
    const commentSnap = await db
      .collection("wisdom")
      .doc(wisdomId)
      .collection("comments")
      .doc(commentId)
      .get();

    if (!commentSnap.exists) {
      console.log(`Comment ${commentId} not found—aborting comment notification.`);
      return null;
    }

    const commenterId = commentSnap.data().authorId || "";
    console.log(`onCommentCreate → commenterId = ${commenterId}, authorId = ${authorId}`);

    if (commenterId === authorId) {
      console.log(`Skipping self-comment notification for user ${commenterId}`);
      return null;
    }

    const fcmToken = await getUserFcmToken(authorId);
    if (!fcmToken) {
      console.log(`No FCM token for ${authorId}—cannot send comment notification.`);
      return null;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: "New comment on your post!",
        body: "Tap to read the comments.",
      },
      data: {
        wisdomId,
        type: "comment",
        link: `tmtl2://comments?wisdomId=${wisdomId}`
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`→ Sent comment notification for post ${wisdomId} to user ${authorId}.`);
      return null;
    } catch (err) {
      console.error("❌ Error sending comment notification:", err);
      return null;
    }
  });

/**
 * Broadcast a generic push to every OTHER user when someone posts wisdom.
 * Privacy-safe: no author identity, no post content.
 */
exports.onWisdomCreate = functions.firestore
  .document('wisdom/{wisdomId}')
  .onCreate(async (snapshot, context) => {
    const wisdomId = context.params.wisdomId;
    const authorId = snapshot.data()?.authorId || "";

    // Collect every user's FCM token except the author's.
    const usersSnap = await db.collection("users").get();
    const tokens = [];
    usersSnap.forEach(doc => {
      if (doc.id === authorId) return;
      const token = doc.data()?.fcmToken;
      if (token) tokens.push(token);
    });

    if (tokens.length === 0) {
      console.log("No recipient tokens for wisdom broadcast—skipping.");
      return null;
    }

    const payload = {
      notification: {
        title: "New wisdom was shared",
        body: "Someone just posted. Tap to read it.",
      },
      data: {
        wisdomId,
        type: "newPost",
        // Repository (shared feed) — recipient doesn't own this post, so route
        // there rather than My Posts. Handled by the existing `link` fallback.
        link: `tmtl2://repository/${wisdomId}`,
      },
    };

    // sendEachForMulticast caps at 500 tokens per call—batch it.
    const invalidTokens = [];
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const res = await admin.messaging().sendEachForMulticast({ tokens: batch, ...payload });
      res.responses.forEach((r, idx) => {
        const code = r.error?.code;
        if (code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-argument") {
          invalidTokens.push(batch[idx]);
        }
      });
      console.log(`Wisdom broadcast batch: ${res.successCount} sent, ${res.failureCount} failed.`);
    }

    // Prune dead tokens so future broadcasts stay cheap.
    if (invalidTokens.length > 0) {
      const prune = db.batch();
      usersSnap.forEach(doc => {
        if (invalidTokens.includes(doc.data()?.fcmToken)) {
          prune.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
        }
      });
      await prune.commit();
      console.log(`Pruned ${invalidTokens.length} dead FCM tokens.`);
    }

    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════
// ARCHIVE SYSTEM (Time Capsule)
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Archive deleted wisdom posts
 * Triggered when a document in the "wisdom" collection is deleted
 */
exports.archiveDeletedPost = functions.firestore
  .document('wisdom/{postId}')
  .onDelete(async (snapshot, context) => {
    const postId = context.params.postId;
    const postData = snapshot.data();

    console.log(`Archiving deleted post: ${postId}`);

    try {
      // Create archive document with original data + deletion metadata
      await db.collection('deleted_posts_archive').doc(postId).set({
        // Original post data
        ...postData,

        // Deletion metadata
        originalId: postId,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),

        // Preserve original timestamps (convert if needed)
        createdAt: postData.createdAt || null,
        expiresAt: postData.expiresAt || null,
        deleteAt: postData.deleteAt || null,

        // Archive metadata
        archivedBy: 'cloud-function',
        archiveVersion: '1.0'
      });

      console.log(`Successfully archived post ${postId}`);
      return null;
    } catch (error) {
      console.error(`Failed to archive post ${postId}:`, error);
      // Don't throw - we don't want to prevent deletion if archiving fails
      return null;
    }
  });

/**
 * Archive deleted comments
 * Triggered when a comment is deleted from any wisdom post's comments subcollection
 */
exports.archiveDeletedComment = functions.firestore
  .document('wisdom/{postId}/comments/{commentId}')
  .onDelete(async (snapshot, context) => {
    const postId = context.params.postId;
    const commentId = context.params.commentId;
    const commentData = snapshot.data();

    console.log(`Archiving deleted comment: ${commentId} from post ${postId}`);

    try {
      // Create archive document with original data + deletion metadata
      await db.collection('deleted_comments_archive').doc(commentId).set({
        // Original comment data
        ...commentData,

        // Reference to parent post
        parentWisdomId: postId,

        // Deletion metadata
        originalId: commentId,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),

        // Preserve original timestamp
        timestamp: commentData.timestamp || null,

        // Archive metadata
        archivedBy: 'cloud-function',
        archiveVersion: '1.0'
      });

      console.log(`Successfully archived comment ${commentId}`);
      return null;
    } catch (error) {
      console.error(`Failed to archive comment ${commentId}:`, error);
      // Don't throw - we don't want to prevent deletion if archiving fails
      return null;
    }
  });

/**
 * Optional: Clean up old archives after 1 year
 * Runs daily at midnight UTC
 */
exports.cleanupOldArchives = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Running archive cleanup job');

    const oneYearAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 365 * 24 * 60 * 60 * 1000)
    );

    try {
      // Clean up old posts
      const oldPosts = await db.collection('deleted_posts_archive')
        .where('deletedAt', '<', oneYearAgo)
        .limit(500) // Process in batches to avoid timeouts
        .get();

      const postBatch = db.batch();
      let postCount = 0;

      oldPosts.forEach(doc => {
        postBatch.delete(doc.ref);
        postCount++;
      });

      if (postCount > 0) {
        await postBatch.commit();
        console.log(`Deleted ${postCount} old archived posts`);
      }

      // Clean up old comments
      const oldComments = await db.collection('deleted_comments_archive')
        .where('deletedAt', '<', oneYearAgo)
        .limit(500)
        .get();

      const commentBatch = db.batch();
      let commentCount = 0;

      oldComments.forEach(doc => {
        commentBatch.delete(doc.ref);
        commentCount++;
      });

      if (commentCount > 0) {
        await commentBatch.commit();
        console.log(`Deleted ${commentCount} old archived comments`);
      }

      console.log(`Archive cleanup complete: ${postCount} posts, ${commentCount} comments removed`);
      return null;
    } catch (error) {
      console.error('Archive cleanup failed:', error);
      return null;
    }
  });
