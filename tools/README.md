# tools

Offline checks. Neither needs the game client — which matters, because the only
other way to test this addon is to log in and read a screenshot.

Install the dependencies once:

```bash
npm install
```

## Syntax check

Parses every `.lua` in a folder as Lua 5.1 (the client's version).

```bash
node luacheck.js ..
```

## Test suites

Fourteen fengari suites execute the addon's OWN source — not a reimplementation of
it — against a stubbed WoW 3.3.5 API. [fengari](https://fengari.io/) is a Lua VM
in JavaScript; `run_lua.js` loads a script into it and `run_all.js` runs every
`*_test.lua` in this folder in one pass.

```bash
node run_all.js                    # everything, with per-suite assertion counts
node run_lua.js <suite>.lua        # one suite, e.g. dungeon_test.lua
node run_lua.js <suite>.lua -v     # verbose: prints every check, not just failures
```

Point a suite at another checkout with `CBH_ADDON=/path/to/CallboardHunter`.
`route_test.lua` and `cp_test.lua` instead take `CBH_ROUTE=/path/to/Route.lua`,
for pointing just that one file elsewhere.

- **`board_test.lua`** — the shared reroll engine on its own: the caller's
  match callback, the sparse card list a hidden slot produces, skipping CBH's
  own card annotation, the reroll cap, refusing an unknown dialog, the
  cards-stopped-changing settle rail, and a won run ending itself.
- **`cb_zone_test.lua`** — which zones are valid `Port: Callboard` destinations
  (never an instance), the one-time purges of unreachable callboards and of
  pre-1.9.8 self-annotations in the card catalogue, and refusing to set home
  while inside an instance.
- **`comm_test.lua`** — the addon-message payload round-trip, the anti-flood
  floor, per-transport availability gating, self-echo vs peer-message counting,
  and that joining the channel actually registers a display filter rather than
  silently unhooking it.
- **`config_test.lua`** — that `/cbh config` actually builds (an unbound
  global shipped in three releases without failing a suite), the favourites
  picker's rows, level bands, and its dark-surface glyph colours.
- **`cp_test.lua`** — checkpoint harvesting off the world map, the
  locked/unlocked read, the Argent Stand prerequisite block, and the
  name-mismatch warning if the server renumbers a checkpoint.
- **`dungeon_test.lua`** — the dungeon-board auto-select/reroll loop: card
  matching (including raid boss cards), never confirming the wrong popup
  dialog, the gold-reserve and reroll-cap limits, sharing the accepted quest
  with the group, and the instance-entry reminder.
- **`export_test.lua`** — SpawnDB corroboration counts and the legacy
  2-element point migration, the shape (and privacy) of the exported table,
  and the card catalogue's classification and progress-counter normalisation.
- **`fav_test.lua`** — favourites keyed on the card's target rather than its
  flavour prefix, the pickable list merged from bundled and learned data
  (minus CBH's own annotations), and `/cbh hunt`: its refusals, the brakes it
  inherits from `/cbh dungeon`, `hunt stop`, and a won hunt ending at once.
- **`header_test.lua`** — Advisor's zone resolution: inferring a zone from the
  quest-log header, curated checkpoint overrides beating both the header and
  learned kills, raid bosses being routable, the callboard-only whitelist, and
  the Dalaran-floats-over-Crystalsong map redirect.
- **`rare_test.lua`** — rare-hunt quest completion tracking, and the regression
  where a finished rare quest could hijack the Port button ahead of a
  genuinely active objective.
- **`resolve_test.lua`** — the zone-routing table for dungeon/raid/Classic/Outland
  bosses and instance aliases, instance-name detection (longest match wins),
  and card-type classification.
- **`route_test.lua`** — walks a full lap and asserts where the step pointer
  lands at each transition, then drives the auto accept / turn-in engine
  through the real event wiring. Load-bearing cases: the backtrack one (leaving
  Zul'Drak must not un-complete the Zul'Drak port and send the route round in a
  circle), the apostrophe one (the server spells a quest title with a curly
  `’`), and the hand-in detection that reads the server's own
  `"<quest> completed."` line.
- **`shared_board_test.lua`** — both callers over one engine, which is where
  `Board.run` being shared bites: `/cbh dungeon off` mid-run must not strand
  the board and lock `/cbh hunt` out of it, and neither caller may stop the
  other's run.
- **`ui_test.lua`** — the colour-blind-safe status stamps (glyph and word,
  never colour alone), the type scale, and WCAG contrast ratios for text on
  both the dark UI ground and the parchment card art.

All exit non-zero on failure, so `run_all.js` — or any suite run individually —
works as a pre-commit gate.

## wdbquests.js — harvest quest text from the client cache

The client caches full quest text (id, title, objectives, description) and writes
it on a **clean exit** — then **deletes the whole `Cache\` directory on the next
launch**. `questcache.wdb` is a per-session snapshot that destroys itself.

This reads one snapshot and merges it into a pool file that persists, so playing
normally accumulates the callboard quest list instead of throwing it away:

    node tools/wdbquests.js                    # finds the cache automatically
    node tools/wdbquests.js <questcache.wdb>   # or point it at one
    node tools/wdbquests.js --pool mine.json   # explicit pool file
    node tools/wdbquests.js --selftest         # verify the parser

**Run it right after exiting the game, before starting it again.** Anything not
copied out before the next launch is gone.

Re-running merges: a quest already in the pool is only *enriched* (a later
snapshot may carry more strings), never duplicated. Callboard quests are tagged
by id range, a `Wanted:` title, or the "custom objective" marker, and the summary
reports how much of the id span you have sampled.

The pool file is gitignored — it is your data, so publishing it is a deliberate
`git add -f`.
