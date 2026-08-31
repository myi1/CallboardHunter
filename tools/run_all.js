// Runs every *_test.lua in this folder and reports the per-suite assertion
// counts, so a regression shows up as a changed number rather than silence.
//
//   node run_all.js
//
// Exits non-zero if any suite fails, so it works as a pre-commit gate.
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const suites = fs.readdirSync(__dirname).filter(f => f.endsWith('_test.lua')).sort();
let failed = 0, total = 0;

for (const s of suites) {
  let out, ok = true;
  try {
    out = execFileSync(process.execPath, [path.join(__dirname, 'run_lua.js'), s],
                       { cwd: __dirname, encoding: 'utf8' });
  } catch (e) {
    ok = false;
    out = (e.stdout || '') + (e.stderr || '');
  }
  // route_test.lua and cp_test.lua print "<n> checks, 0 failed" instead of
  // "ALL <n> PASS" — recognise both so a passing suite isn't reported as FAIL.
  const m = out.match(/ALL (\d+) PASS/) || out.match(/(\d+) checks, 0 failed/);
  // The exit code is authoritative: a suite is "ok" only if it BOTH exited
  // zero AND printed a recognised success line. A non-zero exit after a
  // success line (e.g. a Lua error in a cleanup phase past "ALL n PASS")
  // must still show as FAIL, not contradict itself by printing "ok".
  if (ok && m) { total += Number(m[1]); console.log(`  ok    ${s.padEnd(20)} ${m[1]} assertions`); }
  else { failed++; console.log(`  FAIL  ${s}`); console.log(out.trim().split('\n').slice(-6).join('\n')); }
}

console.log(`\n${suites.length} suites, ${total} assertions, ${failed} failing`);
process.exit(failed ? 1 : 0);
