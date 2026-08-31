// Runs a .lua test on a real Lua 5.3 VM (fengari) so the addon's OWN source is
// executed, not a reimplementation of it.
//
//   node run_lua.js dungeon_test.lua        # from this folder
//   node run_lua.js dungeon_test.lua -v     # verbose
//
// ADDON_DIR is derived from this file's location, so the suites run in any
// checkout or worktree. CBH_ADDON overrides it to test another copy, the same
// way CBH_ROUTE points route_test.lua at another Route.lua.
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require(path.join(__dirname, 'node_modules', 'fengari'));

const ADDON = process.env.CBH_ADDON || path.join(__dirname, '..');
const file = process.argv[2];
if (!file) { console.error('usage: node run_lua.js <test.lua> [-v]'); process.exit(2); }

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

lua.lua_pushstring(L, to_luastring(ADDON.replace(/\\/g, '/')));
lua.lua_setglobal(L, to_luastring('ADDON_DIR'));
lua.lua_pushboolean(L, process.argv.includes('-v'));
lua.lua_setglobal(L, to_luastring('VERBOSE'));

if (lauxlib.luaL_dofile(L, to_luastring(path.resolve(__dirname, file))) !== lua.LUA_OK) {
  console.error(lua.lua_tojsstring(L, -1));
  process.exit(1);
}
