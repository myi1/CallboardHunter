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
