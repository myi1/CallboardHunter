# Changelog

All notable changes to CallboardHunter are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/); version numbers match the
GitHub releases and the `.toc`.

## [1.11.0] - 2026-08-31
### Added
- **Favourites.** Star a callboard quest and CBH remembers it, and `/cbh hunt`
  rerolls the open board until one shows up. Favourites key on the **quest's
  target**, not its title: a callboard title reads `<flavour prefix>: <target>`,
  and the prefix is decorative - *"Dungeon Crawl: Loken"* and *"Wanted: Loken"*
  are the same contract. Favouriting the title would have missed the same job
  under a different prefix.
- **The star, on every card** — `[*]` filled / `[ ]` hollow, so the on/off state
  is carried by shape and survives colour being stripped out. Click it to
  toggle; a matching FAVOURITES list in `/cbh config` lets you pick quests you
  have not met yet, not just ones already sitting on a card.
- **`/cbh hunt`** refuses outright, with an explanation, when you have no
  favourites set — not a silent no-op. An empty list would otherwise reroll
  forever with nothing to stop for.
- **A hunt states its bound before it spends anything**, and inherits the brakes
  you already set: `/cbh hunt` uses your `/cbh dungeon` reroll cap and gold
  reserve until you give favourites its own with `/cbh fav rerolls <n>` /
  `/cbh fav reserve <gold>`. A reserve you typed once covers both features.
- **`/cbh hunt stop`** calls a hunt off without closing the board. It only ever
  stops a hunt — a dungeon run that happens to be live is not its to kill.
- **A bundled 63-target database** (`SpawnDB.QUESTS`) so favourites and their
  level bands are pickable before you have ever personally seen the card; it
  keeps growing from whatever `/cbh catalogue` has learned on your account.
### Changed
- **`Board.lua` extracted from `Dungeon.lua`.** The reroll/accept/share engine
  that used to be dungeon-only now drives both `/cbh dungeon` and `/cbh hunt`
  through a caller-supplied match callback. Internal only — no user-facing
  change.
### Fixed
- **`/cbh config` could not open.** Every function in `Config.lua` reads bare
  `UI.xxx`, but the file never bound `UI` to anything. There is no build step
  that concatenates the addon's files - each `.lua` is its own Lua chunk, so
  `UI.lua`'s `local UI` never left `UI.lua`. The panel would have thrown
  "attempt to index a nil value (global 'UI')" on the very first line of
  `OpenConfig`. Found while wiring up the favourites list above; `Config.lua`
  now binds `local UI = CBH.UI` (and `Fav`) the way every other file does.
- **The card catalogue is purged of CBH's own card notes, once.** Before 1.9.8
  the catalogue recorded the annotations CBH draws on cards as if the server had
  written them; one real database held 97 such entries out of 346. They showed
  up in the new favourites picker as rows that look real and can never match a
  card — favourite one and a hunt would reroll to its cap with no possible win.
  They are dropped from the database at login and skipped in the picker.
- **`/cbh dungeon off` mid-run stops the run** instead of orphaning it. The run
  state is shared with `/cbh hunt` now, so an orphan answered every later hunt
  with "already working the board" until a `/reload`.

## [1.10.2] - 2026-08-31
### Fixed
- **More contrast on card notes.** The 1.10.1 ink was still a mid-tone and washed
  out against the bright card texture at small sizes. Ink is now near-black brown
  and measures **10.2:1** against the card art (was well under); every stamp
  colour clears 6.5:1. `ui_test.lua` pins real WCAG ratios against a sample of
  the actual parchment rather than a luminance guess — 4.5:1 minimum, 7:1 for
  body ink.
- **The stamp glyph no longer clips.** Card notes were 50px narrower than the
  card, so `>` was cut off at the left edge and lines wrapped early. Now 16px,
  centred, and a size tier larger to hold its own against the texture.

## [1.10.1] - 2026-08-31
### Fixed
- **Card notes were unreadable.** 1.10.0 put parchment-coloured text onto the
  callboard's own card art, which is light parchment — pale on pale. CBH draws on
  two grounds: its own dark panels, and the server's light cards, which it does
  not control. Card text is now ink (`#2a1f14`) and the stamps darken to match
  (`> READY` on paper uses a dark brass, not the bright one).

  `ui_test.lua` guards it by luminance from here: dark-ground text must be light,
  parchment-ground text must be dark, and every stamp must be darker on paper
  than on wood.

## [1.10.0] - 2026-08-30
### Changed
- **One interface instead of four.** CBH had grown a teal-on-charcoal config
  panel, a gold/parchment route panel, a black tooltip toast, and a stock
  Blizzard button — four visual languages in one addon, every one of them using
  stock fonts. All surfaces now draw from a shared `UI.lua`.

  The direction comes from what a callboard actually is: a notice board in a
  hold. Oiled wood and parchment, brass for the one actionable thing, wax red and
  verdigris reserved for status. Depth is a surface shift plus a hairline border —
  no shadows anywhere.

- **Status is a stamp, never a colour.** `> ACTIVE`, `+ DONE`, `x BLOCKED`,
  `> READY` — a glyph *and* a word, so meaning survives with the colour stripped
  out. Colour only reinforces. A test pins this invariant.

- **The Port button names its destination.** `Fordragon Hold`, not
  `Port: objective`. Answering "where do I go next" is what CBH is for, so the
  destination is now the focal element rather than a generic verb on a stock
  stone button. It sizes to fit its label and dims in combat.

- **A real type scale** replaces stock font objects: FRIZQT for names, ARIALN
  condensed for counts and metadata (it reads as a ledger hand), stepping
  10/11/12/13/14/16/18. Section labels drop to the smallest condensed tier —
  they are structure, not content.

The design system is recorded in `.interface-design/system.md`.

## [1.9.8] - 2026-08-30
### Added
- **Outland and Classic instances.** The dungeon table only ever covered
  Northrend, so *"Purge the Darkness: Kelidan the Breaker"* resolved to nothing —
  Kelidan is the Blood Furnace end boss, in Hellfire Peninsula. Added every
  Outland dungeon and raid (Hellfire Citadel, Coilfang, Auchindoun, Tempest Keep,
  Gruul's, Karazhan, Magisters' Terrace, Sunwell, Black Temple) and the Classic
  instances (Deadmines through Naxxramas-era raids), with their bosses.

  Both spellings of punctuated names are listed — the server does not always use
  Blizzard's apostrophes, and the reported card said "Kelidan" where Blizzard
  writes "Keli'dan".

  Classic Stratholme is now known (Eastern Plaguelands) alongside the Culling of
  Stratholme (Tanaris); longest-match keeps them apart.

## [1.9.7] - 2026-08-30
### Fixed
- **`Port: The Storm Peaks` with no callboard quest active.** The callboard-only
  filter added in 1.9.5 judged an objective by its **target name**, so Maerys's
  *"The Maddening Deep"* (defeat Yogg-Saron in Ulduar) passed — the callboard
  does offer a *"Topple the Tyrant: Yogg-Saron"* card, and both name the same
  boss. It now judges the **quest title**, which tells the two apart, so the
  meta-quest falls through to `Port: Home` while the real board contract still
  routes.
- **`cardZones` was being written by resolution caching**, not just by reading
  cards — despite being documented as "harvested from callboard cards". That made
  it claim objectives the callboard never offered, and 1.9.5 then trusted it as
  evidence. The writeback is gone and the filter now takes evidence only from the
  card catalogue, which nothing but a board writes to.
- **CBH was cataloguing its own card annotations.** `CardTexts` read every
  FontString on a card including the note CBH draws on it, so entries like
  `|cffaaaaaaDungeon/raid: Ulduar|r` were recorded as callboard text. Our own note
  is skipped, coloured text is refused outright, and existing entries are cleared
  from your catalogue once.

## [1.9.6] - 2026-08-30
### Fixed
- **`Port: Home` to Dalaran failed with "No checkpoints found".** Dalaran floats
  over Crystalsong Forest, and the checkpoint named "Dalaran" sits on the
  **Crystalsong map** — Dalaran's own city map carries no checkpoint buttons at
  all, so pointing the map at it found nothing. Setting your home there (now
  practical with the Summon Callboard spell) hit this every time.

  Porting to a zone with no checkpoints of its own now scans the right map while
  keeping the destination intact: the map shows Crystalsong Forest, the
  checkpoint named "Dalaran" is preferred, and the chat line reads
  "Dalaran via Crystalsong Forest's map". This is a *map* redirect, distinct from
  the existing `/cbh portvia`, which prefers a differently-named checkpoint on the
  map already shown. Both `Port: Home` and objective ports honour it, and the
  map-assertion retry now checks the map being scanned rather than the
  destination — otherwise it fought its own redirect.

## [1.9.5] - 2026-08-30
### Added
- **Callboard-only routing** (`/cbh cbonly`, on by default). The Port button now
  ignores objectives the callboard never gave you. CBH recognises any
  `<name> slain: n/m` objective, which also matches ordinary quests — so
  Naxxramas' `Anub'Rekhan slain: 0/1` was steering the button. It now routes only
  objectives it has actually **seen on a board**, using `cardZones` and the card
  catalogue as evidence; everything else falls through to `Port: Home`.

  **It stays inactive until at least one board has been seen.** A filter with no
  data would hide everything, so a fresh install behaves exactly as before and
  starts filtering only once it has something to filter on. `/cbh cbonly off`
  restores the old behaviour.

  This is what the 1.9.4 note asked about: `Anub'Rekhan` goes back to
  `Port: Home`, while genuine callboard work like *Flame Revenant* still routes
  to Fordragon Hold.

## [1.9.4] - 2026-08-30
### Added
- **Raid callboard automation.** `IsInInstance()` already reported raids, but the
  raid entries carried **empty boss lists** — so a card naming only its boss
  ("Wanted: Festergut") could never match and the automation sat idle. Naxxramas,
  Ulduar, Icecrown Citadel, Trial of the Crusader, Vault of Archavon, Obsidian
  Sanctum, Eye of Eternity, Ruby Sanctum and Onyxia's Lair now carry their bosses.
- **The catalogue buckets by objective type** — `open world`, `dungeon`, `raid`,
  `collection`, `other` — matching how the server groups them (Maerys's "The
  Whole Board" asks for one of each type). `/cbh catalogue` summarises per type
  and `dump` lists them grouped. Entries recorded before types existed are
  classified on read, so nothing needs migrating.

  The vocabulary beyond "open world" and "dungeon" isn't visible to an addon, so
  types are derived from card *shape*; anything unrecognised is kept as `other`
  rather than discarded.
### Changed
- **Raid bosses are now routable, which changes the Port button for ordinary raid
  quests.** `Anub'Rekhan slain: 0/1` (Naxxramas) previously resolved to nothing
  and the button fell back to `Port: Home`; it now reads `Port: Dragonblight`,
  because that is where Naxxramas is. This is a deliberate consequence of adding
  raid data — CBH still cannot tell a callboard quest from an ordinary one, so it
  routes what it can place and offers Home only when it genuinely cannot.

## [1.9.3] - 2026-08-30
### Added
- **`tools/wdbquests.js`** — pulls quest text out of the client's own cache.
  `questcache.wdb` holds full id/title/objectives/description for everything the
  client was shown, written on a clean exit — and the client **deletes the entire
  `Cache\` directory on the next launch**, so it is a snapshot that destroys
  itself. This merges one snapshot into a pool file that persists, so playing
  normally accumulates the callboard list instead of discarding it every session.

  Re-running enriches rather than duplicates, callboard quests are tagged (id
  range, `Wanted:` title, or the "custom objective" marker), and the summary
  reports how much of the id span has been sampled. `--selftest` verifies the
  parser against a synthetic cache. Run it right after exiting the game.

  Confirmed working against a real cache: `600637 Wanted: Loken — "Slay Loken in
  Halls of Lightning." / "Loken slain"`.

## [1.9.2] - 2026-08-30
### Fixed
- **Callboards summoned inside a dungeon were remembered as places to travel
  back to.** `LearnCallboard` was written when boards were permanent world
  objects; the Summon Callboard spell drops a temporary 30-second board anywhere,
  including instances. Walking into Halls of Stone recorded it as a Port:
  Callboard destination — an instance with no world map, no checkpoint, and
  instance-local coordinates. CBH now refuses to learn one inside an instance or
  in any zone the world map doesn't have, never picks an unreachable entry, and
  **clears the bad ones from your saved data once** (real databases already carry
  `Naxxramas`, `The Obsidian Sanctum` and `Ahn'kahet: The Old Kingdom`).
  `/cbh sethome` is refused inside an instance for the same reason.
- **Dungeon automation gave no sign it existed.** It's off by default and only
  acts once a board is already open, so walking into a dungeon showed nothing at
  all — the entry reminder was in the design and was missed in the 1.8.0
  implementation. CBH now says, once per dungeon, either that it's ready or how
  to turn it on (`/cbh dungeon on`). The off-hint stops after three dungeons
  rather than nagging forever.

## [1.9.1] - 2026-08-30
### Added
- **Card catalogue** (`/cbh catalogue`). Every distinct callboard card you see is
  now recorded verbatim, with the level band you saw it at. `cardZones` only ever
  stored cards matching `"Kill N <mob> in <zone>"`, so collection and slay cards
  were never recorded at all — the observed objective list was undercounting its
  own source. Live progress counters are normalised out of the key, so
  `Beast Kill in Howling Fjord: 0/75` and `.../75/75` are one entry, not two.

  It rides along with `/cbh export`, which is what makes a level-banded 1-80
  callboard quest list buildable once several players pool their exports — no
  single player can produce one, since a fast-prestige route skips levels 11-52
  entirely. `/cbh catalogue dump` lists what you have.
### Fixed
- `/cbh export` refused to write when you had no spawn data, even with a
  catalogue worth sharing. A player who has only opened boards still has
  something to contribute.

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
