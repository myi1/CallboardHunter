# Changelog

All notable changes to CallboardHunter are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/); version numbers match the
GitHub releases and the `.toc`.

## [1.9.0] - 2026-08-30
### Added
- **Fast-prestige route runner (`/cbh route`).** The community levelling route —
  Hardcore swap → Dalaran → the three-quest chain → Zul'Drak → Borean Tundra →
  Icecrown — taking a fresh level 1 all the way to **80** at any ash level, as
  **one button and one line telling you what to do next**. It works out which
  step you're on from live state (quest log, zone, level) rather than making you
  keep a cursor, and survives `/reload`, doing steps by hand, or doing them out
  of order. A new run resets the lap automatically.
  - **One button, every step.** It ports you, targets and marks the quest giver,
    or confirms a Hardcore swap. Secure macro button, so `/targetexact` works;
    attribute changes queue during combat and replay on regen.
  - **Auto accept and turn-in** for the route's own quests — walk to the NPC,
    open their dialog, and it accepts and hands in for you, through gossip menus
    and multi-quest greetings alike. Scoped to those quests only, and a quest
    with a real choice of rewards is left for you. `/cbh route auto` turns it off.
  - **Checkpoint ids are verified, not trusted.** Opening the world map harvests
    every checkpoint button's id/name/unlocked state, so the panel can say
    "310: Dalaran, unlocked" and flag `NAME MISMATCH` if the server renumbers
    one. The Zul'Drak step blocks itself, with a reason, when 304 reads locked.
  - **Levelling steps** are satisfied by your actual level, so they advance on
    their own as you ding (66-72 Borean Tundra, 73-80 Icecrown — bands taken from
    logged runs, since the community post stops at Unu'pe). The button ports you
    back if you strayed, and the label reads `Level 68 / 72`.
    `/cbh route grind <level>` retunes the band you're standing on.
  - **Quest givers are learned** on your first lap and the arrow points itself at
    them on every later one. Each step remembers what it was worth in levels.
  - `/cbh route hc <tier|off>` sets the Hardcore tier you level on;
    `/cbh route why` diagnoses a step that won't advance; `forget` drops a bad
    learned NPC; `full` shows the whole checklist; `exec` hands you the
    self-execute macro; `reset` starts the lap over.

  This lived in **PallyPilot** until now. It moved here because CallboardHunter
  already owns the two things it leans on — the checkpoint port layer and the
  guidance arrow. **Existing route state migrates automatically** on first login:
  harvested checkpoints and learned quest givers carry over.
### Added (tooling)
- `tools/` runs the route state machine against a stubbed WoW API on a Lua VM
  (fengari), so route logic is testable without logging in — **68 checks** across
  `route_test.lua` and `cp_test.lua`. `cd tools && npm install`, then
  `node run_lua.js route_test.lua`. `tools/` also now carries its own
  `package.json`, so `node tools/luacheck.js .` works without hunting for
  luaparse.
### Notes
- The route covers the **levelling leg only** — a fresh level 1 to 80, at any ash
  level, any time. It deliberately does not cover the prestige preamble (farm to
  the ash gate, self-execute, refill the tree); that is a different job.
- `Back` can't undo a levelling step — you can't un-ding — so it says so rather
  than looking like a dead button. `/cbh route reset` is the way back.

## [1.8.0] - 2026-08-30
### Added
- **Dungeon callboard automation** (`/cbh dungeon on` — **off by default**). With
  the Summon Callboard spell: you cast it inside a dungeon, and CBH rerolls the
  board until the card for *that dungeon* appears, accepts it, and shares it with
  your group.

  CBH cannot cast the spell for you — `CastSpellByName` is protected on 3.3.5 and
  needs a real keypress. You cast; CBH takes over the moment the board appears.

  Bounded by three independent stops: the board's own ~30s lifetime, a reroll cap
  (`/cbh dungeon rerolls <n|unlimited>`, default 10) and a gold reserve
  (`/cbh dungeon reserve <gold>`) it will never spend below. Every reroll's cost
  is reported as it goes, with a total when it stops.

  The Confirm click is **verified, never blind** — it only clicks a popup that
  identifies itself as the reroll dialog, and stops if any other dialog is open,
  so it can't confirm something destructive. Sharing happens once per quest and
  only when you're in a group.
### Changed
- Dungeon data is now `SpawnDB.DUNGEONS` (zone **and** bosses per dungeon), with
  the routing table derived from it. A flat name→zone map couldn't tell Utgarde
  Keep from Utgarde Pinnacle — both are "Howling Fjord" — which matching needs.
  Routing behaviour is unchanged.

## [1.7.4] - 2026-08-30
### Fixed
- **The Port button sat on a dead "Port: objective" when you had no callboard
  quest.** CBH recognises any `<name> slain: n/m` objective, which also matches
  ordinary quests — *"Anub'Rekhan slain: 0/1"* from Naxxramas, for one. That
  counted as an active objective, but it resolves to no zone, so the button
  claimed a destination it could not deliver and refused when clicked. It now
  only says "Port: <somewhere>" when it can actually name that somewhere, and
  otherwise falls back to **Port: Home** / **Port: Callboard**. `/cbh port` still
  explains why a specific objective could not be routed.

## [1.7.3] - 2026-08-29
### Fixed
- **The channel probe never could have received anything — that was our bug, not
  the server's.** To stay silent it removed the channel from every chat frame,
  but on 3.3.5 `CHAT_MSG_CHANNEL` only fires for channels *registered* to a chat
  frame, so that killed the events too. It now registers the channel and hides
  only the *display* with a message filter. A second defect: registration was
  skipped whenever the (asynchronous) join hadn't resolved yet — it's now
  unconditional, and re-running `/cbh probe join` repairs a lost registration.

  Credit to **Zendan21's Ravioli Activity Finder**, which does server-wide sync
  on Ebonhold using exactly this pattern; reading it is what exposed the mistake.
### Changed
- **Server-wide rare alerts are viable after all.** Two earlier verdicts here
  ("channel sync is dead", then "guild scope only") were both wrong, and both
  followed from this same broken test.

## [1.7.2] - 2026-08-29
### Fixed
- **Where you actually killed something now outranks what the quest title
  claims.** The callboard hands out *"Thinning the Herd in Winterspring"*, but
  its mobs are in **Wintergrasp** — 21 recorded kill points prove it. CBH trusted
  the title and routed to Winterspring. Your own kill history is now consulted
  before quest text, quest-log headers and cached card zones, since it is the
  only source that comes from something you actually did. When an objective was
  killed in more than one zone the one with the most recorded points wins, which
  is also deterministic (the old scan picked an arbitrary one).
- **Instance hubs that aren't map zones now route.** Real cards reference
  *Coilfang Reservoir*, *Tempest Keep* and *Ulduar*, none of which the world map
  can be pointed at. Added those plus Naxxramas, Vault of Archavon, Black Temple
  and Serpentshrine Cavern.
- **Stale "Alterac Mountains" guesses are cleared from your saved data once.**
  The pre-1.5.0 POI sweep cached its bad guesses, and real databases still carry
  them (`Ingvar the Plunderer`, `Anub'arak` — dungeon bosses nowhere near
  Alterac). Nothing is lost: opening the callboard re-teaches a card zone
  properly.
### Changed
- `/cbh obj` also reports `killedIn=` so every routing source is visible at once.

## [1.7.1] - 2026-08-29
### Fixed
- **Objectives in zones with no bundled spawn data couldn't be routed.**
  `SpawnDB.ZONES` holds only the 15 zones CallboardHunter ships rare data for,
  but it was also being used as "zones we recognise by name" — so an objective
  naming **Wintergrasp** (or Winterspring, Crystalsong Forest, anywhere in the
  old world) matched nothing, and routing fell through to a weaker source that
  answered the wrong zone. Any real world-map zone named in a quest's title or
  objectives is now recognised, with the **longest** name winning so a partial
  name can never shadow a fuller one ("Stormwind City" isn't read as
  "Stormwind"). Recognising a zone and having spawn data for it are now separate
  questions.

  Curated overrides deliberately still outrank this: *Thinning the Herd in
  Winterspring* names a real zone, but continues to route to the Fordragon Hold
  checkpoint.

## [1.7.0] - 2026-08-29
### Added
- **Probe now tests the transports that actually work here: `GUILD`, `PARTY` and
  `RAID`.** `/cbh probe send [guild|party|raid|channel|chat|all]`, with receives
  counted per distribution and split into `[PEER]` vs your own echo. It only
  sends over transports currently available (no guild, no guild send), and `all`
  fans out over every usable one while still counting as a single send event, so
  the 2-second anti-flood floor cannot be bypassed.
### Changed
- **Live alerts are back on the table, at guild/group scope.** 1.6.3 recorded
  channel sync as shelved and over-generalised from it. `CHANNEL` isn't a valid
  `SendAddonMessage` distribution on 3.3.5 - but addon messages themselves work
  fine on this server: BigWigs syncs raid timers over `RAID`, and the server
  pushes addon messages to clients on its own bus. Server-wide alerts are gone;
  guild-scoped ones look viable, and make contributed data easier to trust since
  senders are people you know.

## [1.6.3] - 2026-08-29
### Fixed
- **Objectives phrased `<what> in <Zone>: n/m` were ignored entirely.** CBH only
  understood `<name> slain: n/m`, so an objective like *"Beast Kill in Howling
  Fjord: 0/75"* registered nowhere — the addon believed you had no active
  objective at all and the Port button fell back to `Port: Home`. The generic
  form is now accepted whenever its label names a zone that can be travelled to,
  and routes like any other kill objective (this one → Howling Fjord).
  Objectives with no locatable zone (`Primordial Saronite: 0/25`, `SI:7 Insignia
  (Rutger): 0/1`) are deliberately still ignored, so the button doesn't claim a
  destination it can't deliver.
### Changed
- **Live channel sync is shelved — the probe came back negative.**
  `SendAddonMessage` over a custom channel is refused outright by the 3.3.5
  client (`CHANNEL` isn't a valid distribution type), and plain chat on a shared
  channel didn't cross between two clients either. `/cbh export` is the
  data-sharing path. The probe stays in the addon — it's opt-in and inert — in
  case the server's channel handling ever changes. Full results are recorded in
  `docs/superpowers/specs/2026-08-29-comm-channel-probe-design.md`.

## [1.6.2] - 2026-08-29
### Changed
- **The probe now tells a peer message apart from your own echo.** Custom
  channels broadcast to every member including the sender, so a single client can
  see its own message come back — which previously looked identical to a peer
  receiving it. Results are now labelled `[PEER]` vs `[your own message, echoed
  back]`, counted separately, and `/cbh probe status` prints a verdict saying
  what each outcome actually proves. This makes a solo test genuinely useful: a
  self-echo proves the server carries the channel, and only a PEER line proves it
  reaches another client.

## [1.6.1] - 2026-08-29
### Fixed
- **Quests that name no zone in their text now route by the quest log's own zone
  header.** "Bring Me the Head of Ragemane" (a Zul'Drak quest) resolved to
  nothing, fell through to the map POI sweep, and got back the zone the player
  happened to be standing in — Dragonblight. The quest log already groups quests
  under zone headers, which is the game's own answer to "where is this quest?",
  so CBH now reads that. Headers that aren't places (e.g. "Dungeons", or a
  server's custom grouping) are ignored rather than trusted.
- **The POI sweep can no longer return the zone you're standing in.** Its data is
  stale right after the map changes, which is how it produced "Alterac Mountains"
  in 1.3.x and "Dragonblight" here. That result is now recognised as the artifact
  it is and discarded, and any surviving sweep result is logged so a wrong one
  can be reported.

Resolution order is now: zone named in the text → curated dungeon/target entries
→ **quest log zone header** → card zone → learned camp → POI sweep (last resort).

## [1.6.0] - 2026-08-29
### Added
- **`/cbh probe` — channel transport probe.** Groundwork for live rare alerts and
  crowd-sourced spawn data: measures whether Ebonhold relays client-to-client
  messages on a hidden `cbh` channel, and which transport survives (silent addon
  messages vs plain chat). Two testers run `/cbh probe join`, one runs
  `/cbh probe send`, and `/cbh probe status` (plus `/cbh log`) reports what
  arrived.

  It is **opt-in only — nothing auto-joins**, it has a hard 2-second floor
  between sends so it cannot flood you into a disconnect, and it cannot read or
  write your learned spawn data. Design and results:
  `docs/superpowers/specs/2026-08-29-comm-channel-probe-design.md`.
- **`/cbh export` — share your learned spawn data.** Packages your rare sightings
  *and* your callboard camp points into a clean, self-describing table, then tells
  you to `/reload` and which file to upload. `/cbh export clear` removes it again.
  Contains only spawn data plus your character/realm (for credit and for telling
  contributors apart when merging) — never your home, boards, log or settings.
- **Corroboration counts.** Repeat sightings of the same spot now bump a counter
  instead of being silently discarded, so points are `{x, y, n}`. A spot seen six
  times can outrank one person's single glimpse of a patrolling rare — which is
  what makes pooled data mergeable. Existing 2-element points are read as `n = 1`;
  no migration, nothing to redo.

## [1.5.3] - 2026-08-29
### Fixed
- **Finished rare quests kept driving the addon.** Kill objectives were always
  filtered by "still incomplete", but rare/hot zones never were. A completed rare
  quest kept the arrow pointing at its spawns, kept the Port button stuck on
  `Port: <that zone>` instead of falling back to Home/Callboard, could out-rank an
  objective you actually still had work on (sending you to the wrong zone), and
  printed nonsense progress like "4/3" on the next rare you killed there.
- **Rare sightings were silently dropped whenever the world map was open on
  another zone** — which is exactly the state CBH leaves it in after a port.
  Position reads go against the *displayed* map, so they came back empty and the
  sighting was thrown away. Learning now reads against your own zone and puts
  your map view back. This is a large part of why the learned rare database ends
  up incomplete.
### Added
- **Rare kill positions are learned.** Previously only mouseover/target sightings
  were recorded, so rares you tagged at range or looted after a fight never made
  it into the database. Where a rare *died* is the best spawn evidence there is.

## [1.5.2] - 2026-08-28
### Added
- **Per-objective checkpoint routing** — an objective can now route to a
  *specific* checkpoint, not just the nearest one in a zone. First use: the
  "Flame Revenant" callboard quest ("Thinning the Herd in Winterspring") ports
  to the **Fordragon Hold** checkpoint on the Dragonblight map. The port button
  shows the checkpoint name (e.g. "Port: Fordragon Hold") so you can see where
  it will send you.

## [1.5.1] - 2026-08-28
### Added
- **Full WotLK 5-man boss coverage** for dungeon routing — completing the map
  added in 1.5.0. Now covers every boss you can be sent after: Azjol-Nerub's
  Anub'arak, the Violet Hold's Moragg and Lavanthor, Pit of Saron's Krick, and
  the whole Culling of Stratholme (Salramm, Chrono-Lord Epoch, Mal'Ganis,
  Meathook, the Infinite Corruptor) → Tanaris. Bosses shared with a raid
  (Anub'arak, Prince Taldaram) route to their 5-man dungeon; override with
  `/cbh portvia <zone>` if you get the raid version.

## [1.5.0] - 2026-08-28
### Added
- **Dungeon & named-target routing** — kill objectives whose text names no
  outdoor zone now route to the right zone. A dungeon boss (e.g. *Bring Down
  Ingvar the Plunderer*, the Utgarde Keep end boss) routes to its containing
  zone's checkpoint (Howling Fjord); known outdoor targets do too (e.g. *Steel
  Yourself: Banthar* → Nagrand). Covers the WotLK 5-man dungeons and their
  bosses, every rare CallboardHunter has spawn data for, and an extensible list
  of reported callboard targets.
### Fixed
- **Phantom "Port: Alterac Mountains"** — a dungeon objective used to fall
  through to a map POI sweep that mis-guessed a zone and then *cached* that guess,
  so the wrong destination stuck in the port button across sessions. The sweep's
  guess is no longer cached, and dungeon/target objectives now resolve before it
  ever runs.
- **Port sending you to the zone you're already in** — when no zone could be
  worked out, Port fell back to the current zone's map and teleported you within
  it (e.g. standing in Western Plaguelands, it ported to Chillwind Camp instead
  of the objective's real zone). It now declines with guidance (open the
  callboard, or `/cbh port <zone>`) rather than porting somewhere wrong.

## [1.4.0] - 2026-08-27
### Added
- **Config panel** (`/cbh config`) — a dark, colorblind-safe panel to toggle the
  objective arrow, sound and party-announce; set/clear your home callboard; and
  manage blocked checkpoints (add box + per-row remove) without slash commands.

## [1.3.9] - 2026-08-27
### Added
- **Home callboard** — `/cbh sethome` (stand where you want it); the Callboard
  port button then brings you there when you have no active objective.
### Changed
- Blocked dungeon checkpoints (Azjol-Nerub, Ahn'kahet) are skipped **only** for
  outdoor objectives and **only** in auto-routing — manual map clicks and quests
  inside those dungeons still work.
### Fixed
- Cross-zone ports landing on the wrong map (e.g. an Icecrown objective porting
  to Moa'ki in Dragonblight) — the destination map is now confirmed before the
  checkpoint scan.

## [1.3.8] - 2026-08-27
### Changed
- Azjol-Nerub is blocked by default (its checkpoint drops you inside the
  dungeon). Re-enable with `/cbh unblock Azjol-Nerub`; block others that TP you
  inside an instance with `/cbh block <name>`.

## [1.3.7] - 2026-08-27
### Added
- `/cbh block` / `unblock` / `blocked` — exclude checkpoints that teleport you
  *inside* an instance (useless for outdoor travel) from auto-routing.

## [1.3.6] - 2026-08-27
### Fixed
- Port sometimes choosing a wrong zone (e.g. Alterac Mountains) for objectives
  that were actually elsewhere — it now trusts the zone named in the quest text
  instead of a map sweep that could read stale data.

## [1.3.5] - 2026-08-27
### Fixed
- With more than one active callboard objective, the Port button could resolve to
  a random one. It now follows the objective you're tracking in the quest log and
  is otherwise deterministic; the button label shows where it will send you.

## [1.3.4] - 2026-08-27
### Fixed
- Checkpoint teleport failing / not moving you: the port was interrupting its own
  **Rapid Transit** cast. It now clicks the checkpoint once and ignores re-clicks
  (and movement) until the cast resolves, with clear "on cooldown" /
  "interrupted — stand still" / "hold still until it finishes" messages.

## [1.3.3] - 2026-08-27
### Fixed
- Checkpoint-port bugs reported since v1.2.0: robust checkpoint click (fires the
  handler some checkpoints need on mouse-up), longer map-populate wait
  (0.4s → 0.7s), skips dead clicks when you're already at the nearest checkpoint
  or already in the destination zone.
### Added
- Better port diagnostics: the log records the game's error/cast at click time
  and verifies arrival within 6s (`/cbh log`).

## [1.2.0] - 2026-08-22
- First public release. Quest watcher, guidance arrow, kill-location learning,
  card advisor, one-click checkpoint port, rare detection/announce/targeting,
  and optional party announces.
