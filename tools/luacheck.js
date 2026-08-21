const luaparse = require(require('path').join(__dirname, 'node_modules', 'luaparse'));
const fs = require('fs'), path = require('path');
const dir = process.argv[2];
let fail = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.lua'))) {
  const src = fs.readFileSync(path.join(dir, f), 'utf8');
  try { luaparse.parse(src, { luaVersion: '5.1' }); console.log('OK   ' + f); }
  catch (e) { console.log('FAIL ' + f + ': ' + e.message); fail = 1; }
}
process.exit(fail);
