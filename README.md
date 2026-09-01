# CallboardHunter

Companion addon for Project Ebonhold's callboard (Objectives Board) quests,
WoW 3.3.5a. Reads your active callboard objectives and closes the whole loop:

**Board → annotated cards → one-click port to the objective → guidance arrow →
detection/announce/targeting → kill learning → port back to the board.**

## Features

- **Fast-prestige route runner** (`/cbh route`) — the community levelling route
  (Hardcore swap → Dalaran → three-quest chain → Zul'Drak → a callboard grind
  to 80), taking a fresh level 1 all the way to **80** at any ash level, as
  **one button and one line telling you what to do next**. The button ports you, targets and marks the quest giver, or clicks and verifies a
  Hardcore swap; the route's quests **accept and hand in by themselves** once
  you're talking to the NPC. It works out which step you're on from your quest
  log, zone and level, verifies checkpoint ids against the map rather than
  trusting them, and blocks the Zul'Drak leg with a reason if the Argent Stand
  flight path isn't unlocked. `/cbh route hc <tier>` sets the Hardcore tier you
  actually have (or `off`); `/cbh route why` explains a stuck step. On a fresh,
  low-level character CBH offers to start a lap on login (`/cbh route autostart
  off` to silence it).
- **Quest watcher** — parses rare-trophy quests ("Rare Kill in <Zone>") and
  kill objectives ("<Name> slain: n/m"), with `/cbh scan` diagnostics that show
  a per-objective match verdict for pattern tuning.
- **Guidance arrow** — draggable HUD arrow to the nearest relevant point:
  bundled classic rare spawns, your learned camps, or the quest's own POI area.
  Advances as spots are visited/killed; `/cbh next` skips a camped spot.
- **Kill-location learning** — every counted kill records where it happened
  (per objective, per zone, deduped 40yd). The addon gets smarter every grind.
- **Card advisor** — annotates the Objectives Board cards: known camp (with
  spot count), no-data-yet zone, dungeon/raid, or collection. Also harvests
  each card's zone for routing, even for cards you don't pick.
- **Port button / `/cbh port [zone]`** — one click from anywhere: resolves the
  objective's zone (arrow waypoint → rare zone → quest-log text →
  dungeon/known-target map → **quest log zone header** → card zone → learned camp
  → POI map sweep), switches the map
  itself, and clicks the unlocked checkpoint nearest the objective (locked "visit
  the meeting stone" checkpoints are excluded). Dungeon-boss objectives (e.g.
  *Ingvar the Plunderer*, the Utgarde Keep end boss) route to their containing
  zone (Howling Fjord); named outdoor targets route to theirs (e.g. *Banthar* →
  Nagrand). A few objectives route to a specific named checkpoint rather than the
  nearest one (e.g. *Flame Revenant* → the Fordragon Hold checkpoint on the
  Dragonblight map). If it genuinely can't work out a zone it says so rather than
  porting you somewhere wrong. For kill objectives the current quest's POI overrides old
  camps, since the server assigns a fresh area per quest. The chat line says what
  it routed by. With no active callboard quest the button becomes **Port:
  Callboard** back to a board you've used (locations are self-learned when you
  open a board). Greyed out in combat.
- **Detection & announce** — rares detected via mouseover/target/combat log:
  toast + raid warning + sound + secure click-to-Target button (combat-safe,
  click toast body to dismiss). Detected rares' positions are learned.
- **Party announces** (`/cbh party`, off by default) — rare spotted, counted
  kills' completion, and kill progress on rare deaths.
- **Config panel** (`/cbh config`) — dark, colorblind-safe panel for all
  toggles, your **home callboard** (`/cbh sethome`), **blocked checkpoints**
  (ones that drop you inside a dungeon are skipped in auto-routing), and a
  **favourites** list — pick a quest target to hunt for (`/cbh hunt`) before
  you've ever seen its card, from the bundled database plus whatever the
  catalogue has learned.

See [CHANGELOG.md](CHANGELOG.md) for the per-version history.

## Slash commands

| Command | Effect |
| --- | --- |
| `/cbh` | help |
| `/cbh route` | fast-prestige levelling route: one button, one instruction |
| `/cbh route hc <tier｜off>` | Hardcore tier to level on (default 5) |
| `/cbh route hc grind <n>` | tier to hold during the callboard grind (defaults to the levelling tier) |
| `/cbh route grind <level>` | retune the callboard grind's end level (default 80) |
| `/cbh route autostart <off｜on>` | stop / resume offering to start a lap on login |
| `/cbh route auto` | toggle auto accept / turn-in of the route's quests |
| `/cbh route why` / `forget` | diagnose a stuck step / drop a bad learned NPC |
| `/cbh config` | open the config panel (all toggles, home board, blocked checkpoints) |
| `/cbh scan` | quest log dump with match verdicts |
| `/cbh port [zone]` | port toward your objective (or an explicit zone) |
| `/cbh portvia` | list the checkpoints from your last port, numbered |
| `/cbh portvia <n>` | send the current objective via that checkpoint |
| `/cbh portvia none` | back to the nearest checkpoint |
| `/cbh sethome` / `home` / `clearhome` | set the Callboard-port home to where you stand / go there / clear it |
| `/cbh block <name>` / `unblock <name>` / `blocked` | exclude checkpoints that drop you inside an instance from auto-routing |
| `/cbh dungeon on｜off` | dungeon callboard automation: reroll to the dungeon's card, accept, share (off by default) |
| `/cbh dungeon rerolls <n｜unlimited>` / `reserve <gold>` / `share on｜off` | bound the reroll loop |
| `/cbh fav` / `fav clear` | list or clear your favourite callboard quests |
| `/cbh fav rerolls <n｜unlimited>` / `reserve <gold>` | bound a hunt (defaults to the `/cbh dungeon` numbers) |
| `/cbh hunt` / `hunt stop` | reroll the open board until a favourite appears / call it off |
| `/cbh cbonly` / `cbonly off` | route only objectives the callboard actually gave you (default on) |
| `/cbh catalogue` / `catalogue dump` | every distinct callboard card seen, with its level band (ships with the export) |
| `/cbh export` / `export clear` | package your learned rare + camp points for sharing (then `/reload`), or remove the export |
| `/cbh probe join｜send｜send chat｜status｜leave` | channel transport probe — tests whether clients can talk to each other (opt-in; never auto-joins) |
| `/cbh next` | skip the current arrow waypoint |
| `/cbh track <zone>` / `untrack` / `debug` | force/clear/test hot zones |
| `/cbh arrow` / `sound` / `party` | toggles |
| `/cbh frames [text|map]` / `portscan` | discovery/diagnostic tools for the server's custom UI |
| `/cbh reset` | reset options (keeps learned data), then `/reload` |

## Server-UI integration notes (discovered via /cbh frames)

- Objectives Board: `ObjectivesMainFrame` > `ObjectiveFrame1..3`.
- Checkpoint tooltips: `ProjectEbonholdCheckpointTooltip` ("<Name>" / "Click to
  travel to this checkpoint."); locked ones say "Not yet unlocked".
- Checkpoint buttons: unnamed Buttons under `WorldMapButton`.
- If a server patch breaks integration, re-run `/cbh frames` / `/cbh portscan`
  and adjust `Advisor.lua`.

## Development

Lua 5.1 syntax check: `cd tools && npm install && node luacheck.js ..`.
Run it before committing.

`Route.lua` is a state machine, so it also runs offline against a stubbed WoW
API on a Lua VM: `node run_lua.js route_test.lua` and `node run_lua.js
cp_test.lua` (68 checks, non-zero exit on failure). See `tools/README.md`.

Data lives in SavedVariables `CallboardHunterDB`: `learned` (rare sightings),
`learnedKills` (camp points), `cardZones`, `callboards` (board locations).
Learned points are `{x, y, n}` where `n` counts how many times that spot was
corroborated; legacy 2-element points read as `n = 1`.

## Contributing spawn data

The bundled rare spawn points are approximate and improve with real sightings.
To contribute yours:

1. `/cbh export`
2. `/reload` (this is what actually writes the file)
3. Upload `World of Warcraft\WTF\Account\<YOUR ACCOUNT>\SavedVariables\CallboardHunter.lua`

The export carries only spawn data plus your character/realm, so contributions can
be credited and told apart when merging. `/cbh export clear` removes it.
