const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require(path.join(__dirname, 'node_modules', 'fengari'));

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const file = process.argv[2];
if (lauxlib.luaL_dofile(L, to_luastring(file)) !== lua.LUA_OK) {
  console.error(lua.lua_tojsstring(L, -1));
  process.exit(1);
}
