"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendTestToUid = exports.onCommentCreated = exports.onReactionCreated = void 0;
/* eslint-disable */
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
admin.initializeApp({
    projectId: process.env.GCP_PROJECT || "tmtl2-59ed3",
});
async function getUserFcmToken(uid) {
    const doc = await admin.firestore().collection("users").doc(uid).get();
    if (!doc.exists)
        return null;
    return doc.data()?.fcmToken || null;
}
// ── LIKE NOTIFICATIONS ──────────────────────────────────────────────────────
exports.onReactionCreated = (0, firestore_1.onDocumentCreated)({ region: "us-central1", document: "wisdom/{wisdomId}/reactions/{reactionId}" }, async (event) => {
    const wisdomId = event.params.wisdomId;
    const reactionSnap = event.data; // the new reaction doc
    const reactionData = reactionSnap.data();
    if (!reactionData) {
        console.log(`Reaction doc missing data—aborting.`);
        return;
    }
    const reactorId = reactionData.authorId;
    if (!reactorId) {
        console.log(`Reaction ${reactionSnap.id} has no authorId—skipping.`);
        return;
    }
    const postSnap = await admin.firestore().collection("wisdom").doc(wisdomId).get();
    if (!postSnap.exists) {
        console.log(`Wisdom ${wisdomId} not found—aborting like notification.`);
        return;
    }
    const authorId = postSnap.data().authorId || "";
    console.log(`onReactionCreated → reactorId = ${reactorId}, authorId = ${authorId}`);
    if (reactorId === authorId) {
        console.log(`Skipping self-like notification for user ${reactorId}`);
        return;
    }
    const fcmToken = await getUserFcmToken(authorId);
    if (!fcmToken) {
        console.log(`No FCM token for ${authorId}—cannot send like notification.`);
        return;
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
    }
    catch (err) {
        console.error("❌ Error sending like notification:", err);
    }
});
// ── COMMENT NOTIFICATIONS ───────────────────────────────────────────────────
exports.onCommentCreated = (0, firestore_1.onDocumentCreated)({ region: "us-central1", document: "wisdom/{wisdomId}/comments/{commentId}" }, async (event) => {
    const wisdomId = event.params.wisdomId;
    const commentId = event.params.commentId;
    // fetch the wisdom post to get its author
    const postSnap = await admin.firestore().collection("wisdom").doc(wisdomId).get();
    if (!postSnap.exists) {
        console.log(`Wisdom ${wisdomId} not found—aborting comment notification.`);
        return;
    }
    const authorId = postSnap.data().authorId || "";
    // fetch the new comment to find who posted it
    const commentSnap = await admin
        .firestore()
        .collection("wisdom")
        .doc(wisdomId)
        .collection("comments")
        .doc(commentId)
        .get();
    if (!commentSnap.exists) {
        console.log(`Comment ${commentId} not found—aborting comment notification.`);
        return;
    }
    const commenterId = commentSnap.data().authorId || "";
    console.log(`onCommentCreated → commenterId = ${commenterId}, authorId = ${authorId}`);
    if (commenterId === authorId) {
        console.log(`Skipping self-comment notification for user ${commenterId}`);
        return;
    }
    const fcmToken = await getUserFcmToken(authorId);
    if (!fcmToken) {
        console.log(`No FCM token for ${authorId}—cannot send comment notification.`);
        return;
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
    }
    catch (err) {
        console.error("❌ Error sending comment notification:", err);
    }
});
exports.sendTestToUid = onRequest({ region: "us-central1" }, async (req, res) => {
    try {
        const uid = String(req.query.uid || "");
        const type = String(req.query.type || "like");
        const wisdomId = String(req.query.wisdomId || "demo123");
        const commentId = req.query.commentId ? String(req.query.commentId) : undefined;
        if (!uid) {
            res.status(400).send("Missing uid");
            return;
        }
        const token = await getUserFcmToken(uid);
        if (!token) {
            res.status(400).send("No FCM token for uid");
            return;
        }
        const data = { type, wisdomId };
        if (commentId)
            data.commentId = commentId;
        let title = "Test notification";
        let body = "Tap to open";
        let link = "tmtl2://repository";
        if (type === "like") {
            title = "Someone liked your post!";
            body = "Tap to view.";
            link = `tmtl2://post/${wisdomId}`;
        }
        else if (type === "comment") {
            title = "New comment on your post!";
            body = "Tap to read.";
            link = `tmtl2://comments?wisdomId=${wisdomId}${commentId ? `&commentId=${commentId}` : ""}`;
        }
        else if (type === "addWisdom") {
            title = "Time to add wisdom";
            body = "Share something new.";
            link = "tmtl2://addWisdom";
        }
        else if (type === "wipeDay") {
            title = "Today is Wipe Day";
            body = "Check the top posts.";
            link = "tmtl2://repository";
        }
        const msg = {
            token,
            notification: { title, body },
            data: { ...data, link },
            apns: { payload: { aps: { sound: "default" } } }
        };
        await admin.messaging().send(msg);
        res.status(200).send("ok");
    }
    catch (e) {
        console.error("sendTestToUid error:", e?.errorInfo || e);
        res.status(500).send(e?.message || "Internal error");
    }
});
//# sourceMappingURL=index.js.map