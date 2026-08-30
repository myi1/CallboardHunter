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

## Route state-machine tests

`Route.lua` is a state machine over the fast-prestige route, so it can be run
head-first against a stubbed WoW API. [fengari](https://fengari.io/) is a Lua VM
in JavaScript; `run_lua.js` loads a script into it.

```bash
node run_lua.js route_test.lua
node run_lua.js cp_test.lua
```

- **`route_test.lua`** walks a full lap and asserts where the step pointer lands
  at each transition, then drives the auto accept / turn-in engine through the
  real event wiring. Load-bearing cases: the backtrack one (leaving Zul'Drak must
  not un-complete the Zul'Drak port and send the route round in a circle), the
  apostrophe one (the server spells a quest title with a curly `’`), and the
  hand-in detection that reads the server's own `"<quest> completed."` line.
- **`cp_test.lua`** covers checkpoint harvesting off the world map, the
  locked/unlocked read, the Argent Stand prerequisite block, and the
  name-mismatch warning if the server renumbers a checkpoint.

Point them at another copy with `CBH_ROUTE=/path/to/Route.lua`.

Both exit non-zero on failure, so they work as a pre-commit gate.

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
