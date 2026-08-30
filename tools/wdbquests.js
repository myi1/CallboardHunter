#!/usr/bin/env node
// Extract quests from a WoW 3.3.5 questcache.wdb into a growing, mergeable pool.
//
// WHY THIS EXISTS. The client caches full quest text — id, title, objectives,
// description — and writes it on a clean exit. It then DELETES the whole Cache
// directory on the next launch. So questcache.wdb is a per-session snapshot that
// destroys itself: whatever is not copied out before you relaunch is gone.
//
// This reads one snapshot and merges it into a pool file that persists, so
// playing normally accumulates the callboard quest list over time instead of
// throwing it away every launch.
//
// Usage:
//   node tools/wdbquests.js                        # finds the cache automatically
//   node tools/wdbquests.js <questcache.wdb>       # explicit snapshot
//   node tools/wdbquests.js --pool my-pool.json    # explicit pool file
//   node tools/wdbquests.js --selftest             # verify the parser
//
// Format (3.3.5): 24-byte header, then records of [uint32 id][uint32 size][payload],
// terminated by eight zero bytes. Strings inside a record are NUL-separated.

const fs = require('fs');
const path = require('path');

const HEADER = 24;
// Callboard content sits in its own id block on Ebonhold; Summon Callboard is
// spell 600647 and observed quests run 600637..601402. Kept wide on purpose —
// mis-tagging a quest is harmless, dropping one is not.
const CB_MIN = 600000, CB_MAX = 601999;
const CB_MARKER = /custom objective/i;
const CB_TITLE = /^wanted:/i;

function parseWDB(buf) {
  if (buf.length < HEADER) throw new Error('too short to be a WDB file');
  const magic = buf.slice(0, 4).toString('latin1');
  const recs = [];
  let off = HEADER;
  while (off + 8 <= buf.length) {
    const id = buf.readUInt32LE(off);
    const size = buf.readUInt32LE(off + 4);
    if (id === 0 && size === 0) break;            // terminator
    off += 8;
    if (size === 0 || off + size > buf.length) break;  // truncated tail
    recs.push({ id, payload: buf.slice(off, off + size) });
    off += size;
  }
  return { magic, recs };
}

// Printable runs inside a record, in file order. The exact field layout varies
// by build, so positions are NOT assumed beyond "the first string is the title"
// — every string is kept so nothing is silently discarded.
function strings(payload, minLen = 4) {
  const out = [];
  let cur = [];
  for (const byte of payload) {
    if (byte >= 0x20 && byte <= 0x7e) { cur.push(byte); continue; }
    if (cur.length >= minLen) out.push(Buffer.from(cur).toString('utf8').trim());
    cur = [];
  }
  if (cur.length >= minLen) out.push(Buffer.from(cur).toString('utf8').trim());
  return out.filter(s => s.length >= minLen);
}

function isCallboard(id, strs) {
  if (id >= CB_MIN && id <= CB_MAX) return true;
  if (strs.length && CB_TITLE.test(strs[0])) return true;
  return strs.some(s => CB_MARKER.test(s));
}

function findCache() {
  // tools/ lives at <game>/Interface/AddOns/CallboardHunter/tools
  const guess = path.resolve(__dirname, '..', '..', '..', '..',
    'Cache', 'WDB', 'enUS', 'questcache.wdb');
  return fs.existsSync(guess) ? guess : null;
}

// ------------------------------------------------------------------ selftest

function selftest() {
  const mk = (id, strs) => {
    const body = Buffer.concat([
      Buffer.alloc(32),                                    // leading numerics
      Buffer.from(strs.join('\0') + '\0', 'utf8'),
    ]);
    const head = Buffer.alloc(8);
    head.writeUInt32LE(id, 0); head.writeUInt32LE(body.length, 4);
    return Buffer.concat([head, body]);
  };
  const buf = Buffer.concat([
    Buffer.from('WQST'), Buffer.alloc(HEADER - 4),
    mk(600637, ['Wanted: Loken', 'Slay Loken in Halls of Lightning.',
                'This is a custom objective. Upon completion...', 'Loken slain']),
    mk(13375, ['The Heroic Key to the Focusing Iris', 'Deliver the key to Alexstrasza.']),
    mk(601003, ['The Whole Board', 'Complete one Callboard objective of each type.']),
    Buffer.alloc(8),                                       // terminator
    Buffer.from('trailing garbage should be ignored'),
  ]);
  const { recs } = parseWDB(buf);
  const fail = [];
  const ck = (label, got, want) => {
    const ok = String(got) === String(want);
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${label} -> ${got}${ok ? '' : `   EXPECTED ${want}`}`);
    if (!ok) fail.push(label);
  };
  ck('records parsed', recs.length, 3);
  ck('stops at terminator, ignores trailing bytes', recs[recs.length - 1].id, 601003);
  const loken = strings(recs[0].payload);
  ck('title is first string', loken[0], 'Wanted: Loken');
  ck('objective text kept', loken.includes('Loken slain'), true);
  ck('callboard by id range', isCallboard(600637, loken), true);
  ck('callboard by "Wanted:" title', isCallboard(1, ['Wanted: Something']), true);
  ck('callboard by custom-objective marker',
     isCallboard(1, ['X', 'This is a custom objective. blah']), true);
  ck('ordinary quest not tagged', isCallboard(13375, strings(recs[1].payload)), false);
  ck('short noise filtered out', strings(Buffer.from('ab\0cdef\0')).join(','), 'cdef');
  console.log(fail.length ? `\n${fail.length} FAILURE(S)` : '\nALL PASS');
  process.exit(fail.length ? 1 : 0);
}

// ---------------------------------------------------------------------- main

const argv = process.argv.slice(2);
if (argv.includes('--selftest')) selftest();

let poolPath = path.join(__dirname, 'cb-quest-pool.json');
const pi = argv.indexOf('--pool');
if (pi !== -1) { poolPath = argv[pi + 1]; argv.splice(pi, 2); }

const src = argv[0] || findCache();
if (!src) {
  console.error('No questcache.wdb given and none found automatically.\n' +
    'The client DELETES its cache on launch, so run this right after exiting the\n' +
    'game, before starting it again:\n' +
    '  node tools/wdbquests.js "<game>\\Cache\\WDB\\enUS\\questcache.wdb"');
  process.exit(2);
}
if (!fs.existsSync(src)) { console.error('Not found: ' + src); process.exit(2); }

const { magic, recs } = parseWDB(fs.readFileSync(src));
if (magic !== 'WQST' && magic !== 'TSQW') {
  console.error(`Warning: magic is "${magic}", expected a quest cache (WQST).`);
}

let pool = {};
if (fs.existsSync(poolPath)) {
  try { pool = JSON.parse(fs.readFileSync(poolPath, 'utf8')); }
  catch (e) { console.error('Existing pool is unreadable, refusing to overwrite it: ' + e.message); process.exit(3); }
}

const stamp = new Date().toISOString().slice(0, 10);
let added = 0, updated = 0, cbCount = 0;
for (const { id, payload } of recs) {
  const strs = strings(payload);
  if (!strs.length) continue;
  const cb = isCallboard(id, strs);
  if (cb) cbCount++;
  const key = String(id);
  if (pool[key]) {
    // Only grow: a later snapshot may carry more strings than an earlier one.
    if (strs.length > (pool[key].strings || []).length) {
      pool[key].strings = strs; pool[key].title = strs[0]; updated++;
    }
    pool[key].lastSeen = stamp;
  } else {
    pool[key] = { id, title: strs[0], callboard: cb, strings: strs,
                  firstSeen: stamp, lastSeen: stamp };
    added++;
  }
}

fs.writeFileSync(poolPath, JSON.stringify(pool, null, 1) + '\n');
const total = Object.keys(pool).length;
const totalCb = Object.values(pool).filter(q => q.callboard).length;
const ids = Object.values(pool).filter(q => q.callboard).map(q => q.id).sort((a, b) => a - b);

console.log(`snapshot: ${path.basename(src)} — ${recs.length} record(s), ${cbCount} callboard`);
console.log(`pool:     ${total} quest(s) total, ${totalCb} callboard   (+${added} new, ${updated} enriched)`);
if (ids.length) {
  const span = ids[ids.length - 1] - ids[0] + 1;
  console.log(`callboard ids ${ids[0]}..${ids[ids.length - 1]} — ${ids.length} of ~${span} in that span ` +
              `(${Math.round(100 * ids.length / span)}% sampled)`);
}
console.log(`written:  ${poolPath}`);
console.log('\nRun this after every clean exit — the client wipes its cache on next launch.');
