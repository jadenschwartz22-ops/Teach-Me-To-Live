# Deployed Cloud Functions (source of truth)

This is the code actually running on Firebase project `tmtl2-59ed3`.
Firebase Functions **v1** SDK, Node 22, 6 functions:

| Function | Trigger | What it does |
|---|---|---|
| `onReactionWrite` | `wisdom/{id}/reactions/{rid}` create | Push to post author on a like |
| `onCommentCreate` | `wisdom/{id}/comments/{cid}` create | Push to post author on a comment |
| `onWisdomCreate` | `wisdom/{id}` create | Broadcast to everyone else who hasn't opted out |
| `archiveDeletedPost` | `wisdom/{id}` delete | Copy to `deleted_posts_archive` |
| `archiveDeletedComment` | comment delete | Copy to `deleted_comments_archive` |
| `cleanupOldArchives` | scheduled daily | Drop archives older than a year |

`onWisdomCreate` skips any user whose `users/{uid}.notifyOnNewPost` is `false`
(set by the toggle on the app's My Posts page). A **missing field counts as
opted in**, so users who never touch the toggle keep getting broadcasts.

## Do not confuse with the other copies

`../functions/` (in this repo), `~/tmtl2-cloud` and `~/tmtl-functions` are
**stale v2-SDK rewrites**. None of them contain `onWisdomCreate`, and none are
wired to a live `firebase.json`. Ignore them; edit here.

## Deploying

The Firebase CLI is logged out on this machine, so deploy with gcloud. The
default gcloud account (`jaden@protoquiz.com`) **cannot see this project** —
pass `--account` explicitly:

```sh
gcloud functions deploy onWisdomCreate \
  --project tmtl2-59ed3 \
  --account=jadenschwartz22@gmail.com \
  --region=us-central1 --runtime=nodejs22 \
  --entry-point=onWisdomCreate \
  --trigger-event=providers/cloud.firestore/eventTypes/document.create \
  --trigger-resource="projects/tmtl2-59ed3/databases/(default)/documents/wisdom/{wisdomId}" \
  --memory=256MB --source=.
```

`firebase.json.reference` is a copy of the deploy config from the old outer
repo, kept for reference.
