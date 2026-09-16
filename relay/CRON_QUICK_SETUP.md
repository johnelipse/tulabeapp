# Tulabe Push Relay - Cron Job Setup (cron-job.org)

The relay polls the Tulabe API itself on a timer (`POLL_INTERVAL_MIN`), but on
Render's free tier the process sleeps after ~15 min idle and the in-process
timer freezes. To stay reliable, schedule the relay's `poll` endpoint from an
external cron service. This follows the same pattern used in
`Phil-Of-Africa-Safaris` (secure route + secret header + JSON result +
cron-job.org).

## 1) The endpoint

```
GET or POST https://apprelay-bg2i.onrender.com/api/push/poll
```

It runs one "is there new content on Tulabe?" cycle and returns JSON:

```json
{"ok":true,"notified":1,"pruned":0,"title":"New Movie","url":"https://.../movie/123"}
```

- No new content -> `"notified":0` (still a success).
- Poller misconfigured -> `400 {"error":"poller not configured (...)"}`.
- Backend/FCM error -> `503 {"error":"..."}`.

## 2) Shared secret (optional, recommended)

If you set `RELAY_KEY` on the relay, callers must present it. The relay accepts
all three standard header styles:

```
X-Relay-Key: <key>              # used by the mobile app (PUSH_RELAY_KEY)
X-API-Key: <key>                # cron-job.org
Authorization: Bearer <key>     # cron-job.org
```

LEAVE `RELAY_KEY` EMPTY for now if you are not going to set it on Render.

## 3) Create the cron job

1. Sign up at https://cron-job.org
2. Click **Create cronjob**:

| Field | Value |
|-------|-------|
| Title | Tulabe push poll |
| URL | `https://apprelay-bg2i.onrender.com/api/push/poll` |
| Method | POST |
| Schedule | Every 5 minutes (`*/5 * * * *`) |
| Timeout | 30 seconds |
| Headers | `X-API-Key: <your RELAY_KEY>` (only if RELAY_KEY is set) |
| Notify on failure | Yes |

> **Use `*/5 * * * *` (not `*/15`).** Render's free tier sleeps after ~15 min
> idle. A `*/15` job hits right at the sleep boundary, so the relay is usually
> cold-starting: Render answers with a large HTML cold-start/error page while
> your app boots, and cron-job.org caps responses at 8 KB — the job then shows
> `Failed (output too large)` even though your endpoint itself returns a tiny
> JSON. A 5-minute cadence keeps the service warm so it never sleeps and every
> run returns the small JSON response.

3. Save, then click **Execute now** to test. A green `200 {"ok":true,...}`
   response confirms the relay is reachable and the poll ran.

## 4) Verify

- cron-job.org dashboard shows past executions with HTTP 200.
- `curl https://apprelay-bg2i.onrender.com/api/push/health` shows
  `"poller":{"enabled":true,...}` and `lastCursor` advancing when new content
  is added.
- You receive a "New on Tulabe" push when the next movie/series is published.

## 5) Notes

- First poll after the relay (re)deploys or its volume is wiped sets a baseline
  and does NOT notify about already-existing content (no backlog spam).
- Free tier allows up to 3 cron jobs; 5-minute cadence is plenty for new-title
  alerts and also keeps the service awake so the job never cold-starts.
- Device tokens are stored in a plain file on Render's **ephemeral** disk. Any
  cold start / redeploy wipes them, so after a deploy or a long idle period the
  phone must open the app once to re-register. Acceptable for a hobby service,
  but if this ever needs to be production-grade, move tokens + cursor into a
  tiny managed store (e.g. a free Postgres/Upstash instance).