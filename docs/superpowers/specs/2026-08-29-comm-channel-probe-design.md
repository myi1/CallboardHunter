# CallboardHunter — channel transport probe

**Date:** 2026-08-29
**Status:** implemented (v1.6.0), awaiting in-game result

## Problem

CallboardHunter's bundled rare spawn points are approximate, and the learned
layer only ever helps the player who recorded it. The community (Ebonhold
Discord) wants to pool data. Two routes were considered:

1. **File export** — write learned data to SavedVariables, contributors upload
   the file, maintainer merges into `SpawnDB.STATIC` by hand.
2. **Live channel sync** — every client joins a hidden channel, broadcasts what
   it learns, and updates from peers in real time.

Route 2 is strictly more interesting: if clients can talk, the headline feature
isn't data pooling at all, it's **live rare alerts** ("Time-Lost Proto Drake
spotted in Storm Peaks") pushed to every user on the server. Crowd-sourced
coordinates fall out as a side effect.

Route 2 rests on an assumption that cannot be verified from outside the game:
**does Ebonhold's core relay client-to-client messages on a custom channel?**
Private-server cores vary — some pass addon messages through, some strip or
throttle them. Designing a sync protocol before answering that is building on
sand.

## Scope of this document

This spec covers **only the probe** that answers the transport question. The
sync protocol, trust model, and alert UX are deliberately out of scope and get
their own spec once the probe reports back.

## Design

New module `Comm.lua` — one concern per file, matching the existing layout, and
keeping diagnostic code out of `Advisor.lua`.

### Two transports, tested side by side

| # | Transport | Notes |
|---|---|---|
| 1 | `SendAddonMessage("CBHPROBE", payload, "CHANNEL", idx)` | The clean path. Invisible to players, no chat spam. |
| 2 | `SendChatMessage(payload, "CHANNEL", nil, idx)` | Fallback if the core strips addon messages. Works nearly everywhere, but the text is visible to anyone who manually joins the channel. |

Testing both in one session answers not just *whether* messaging works but
*which* transport survives — the single fact the real protocol hangs on.

### Commands

- `/cbh probe join` — `JoinTemporaryChannel("cbh")`. Temporary so it does not
  persist across sessions; never bound to a chat frame, so it stays silent.
- `/cbh probe send` — transport 1. `/cbh probe send chat` — also transport 2.
- `/cbh probe status` — joined state, channel index, per-transport receive counts.
- `/cbh probe leave` — `LeaveChannelByName("cbh")`.

Received messages print sender + transport + payload **and** are written through
`CBH.Log("comm", …)`, so `/cbh log` captures the whole session. The tester can
paste that log for offline analysis rather than having to interpret results.

### Payload

`<version>|<sequence>|<sender>` — addon version, a per-session counter, and the
sending character. Nothing sensitive, and small enough to never approach the
255-byte addon-message limit.

### Safety constraints

These are requirements, not implementation details:

- **Nothing auto-joins.** Opt-in command only. No passive behaviour reaches users
  who merely update the addon. Auto-join is a disclosure decision that has not
  been made yet.
- **Hard 2-second minimum between sends**, enforced in code. The probe cannot
  flood the sender into a "sending messages too quickly" disconnect.
- **No access to spawn data.** The probe never reads or writes `learned` /
  `learnedKills`, so a failed test cannot corrupt the database.

### Success criteria

| Observation | Conclusion |
|---|---|
| Peer receives transport 1 | Addon messages relay — build the clean protocol |
| Only transport 2 arrives | Chat transport only — workable, with visibility tradeoffs |
| Neither arrives | Channel sync is not viable on Ebonhold; fall back to file export |

## Testing

- `tools/luacheck.js` for syntax.
- fengari (Lua VM under Node) unit tests for the payload encode/decode round-trip
  and the throttle — specifically that a second send inside the 2s window is
  refused. Pure functions (`Comm.Encode`, `Comm.Decode`, `Comm.CanSend`) exist so
  this logic is testable without the WoW client.
- The channel behaviour itself is in-game only. That is the point of the probe.

## Results

_To be filled in after testing. Record: server, date, both testers' characters,
which transports arrived, and any error messages._

- [ ] Transport 1 (addon message over channel):
- [ ] Transport 2 (chat message over channel):
- [ ] Notes:

## Follow-up (out of scope here)

Once the transport is known, the sync design must address:

- **Throttling** — batch and broadcast deltas only, never the whole database.
- **Data poisoning** — an open channel is `/cbh import` with the safety off.
  Incoming data lands in a quarantined `contributed` layer and only becomes
  routable after *k* independent senders (proposed: 3) corroborate a point within
  the dedupe radius. First-hand `learned` data is never overwritten by the
  network. This is what makes live sync compatible with the earlier decision to
  keep unvetted coordinates away from players.
- **Privacy / opt-in UX** — broadcasting reveals position when a rare is seen.
  Must be disclosed and toggleable from the existing config panel.
- **Sighting counts** — `Learn`/`LearnKill` should bump a counter when a sighting
  lands inside the dedupe radius (points become `{x, y, n}`; legacy 2-element
  points read as `n = 1`), so corroboration is measurable both locally and across
  contributors.
