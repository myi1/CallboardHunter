# CallboardHunter

Companion addon for Project Ebonhold's callboard (Objectives Board) quests,
WoW 3.3.5a. Reads your active callboard objectives and closes the whole loop:

**Board → annotated cards → one-click port to the objective → guidance arrow →
detection/announce/targeting → kill learning → port back to the board.**

## Features

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
  objective's zone (arrow waypoint → rare zone → quest-log text → card zone →
  dungeon/known-target map → learned camp → POI map sweep), switches the map
  itself, and clicks the unlocked checkpoint nearest the objective (locked "visit
  the meeting stone" checkpoints are excluded). Dungeon-boss objectives (e.g.
  *Ingvar the Plunderer*, the Utgarde Keep end boss) route to their containing
  zone (Howling Fjord); named outdoor targets route to theirs (e.g. *Banthar* →
  Nagrand). If it genuinely can't work out a zone it says so rather than porting
  you somewhere wrong. For kill objectives the current quest's POI overrides old
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
  toggles, your **home callboard** (`/cbh sethome`), and **blocked checkpoints**
  (ones that drop you inside a dungeon are skipped in auto-routing).

See [CHANGELOG.md](CHANGELOG.md) for the per-version history.

## Slash commands

| Command | Effect |
| --- | --- |
| `/cbh` | help |
| `/cbh config` | open the config panel (all toggles, home board, blocked checkpoints) |
| `/cbh scan` | quest log dump with match verdicts |
| `/cbh port [zone]` | port toward your objective (or an explicit zone) |
| `/cbh sethome` / `home` / `clearhome` | set the Callboard-port home to where you stand / go there / clear it |
| `/cbh block <name>` / `unblock <name>` / `blocked` | exclude checkpoints that drop you inside an instance from auto-routing |
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

Lua 5.1 syntax check (requires Node + `npm install luaparse` next to the
script): `node tools/luacheck.js <addon folder>`. Run it before committing.

Data lives in SavedVariables `CallboardHunterDB`: `learned` (rare sightings),
`learnedKills` (camp points), `cardZones`, `callboards` (board locations).
