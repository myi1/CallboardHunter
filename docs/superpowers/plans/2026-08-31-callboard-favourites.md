# Callboard Favourites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player mark callboard quests as favourites and have CBH reroll the board until one appears, take it, and stop.

**Architecture:** `Dungeon.lua` already owns the reroll loop (reroll → verified confirm → wait for cards to change → match → accept), bounded by reroll cap, gold reserve and board expiry. Only the *match predicate* differs for favourites. Extract that loop into `Board.lua` as an engine taking a `match(cards)` callback; `Dungeon.lua` and a new `Favourites.lua` become its two callers, inheriting the safety rails rather than reimplementing them.

**Tech Stack:** Lua 5.1 (WoW 3.3.5a addon). Tests run offline on fengari via `tools/run_lua.js`. Syntax check via `tools/luacheck.js`. No new dependencies.

## Global Constraints

- **Lua 5.1 only.** No `goto`, no integer division, no `table.unpack` (it is `unpack`). Tests shim `unpack = unpack or table.unpack` because fengari is 5.3.
- **Colourblind rule (hard).** Status is a glyph *plus* a word, never colour alone. Stars must read as filled/empty shape, not gold-vs-grey. See `.interface-design/system.md`.
- **Two grounds.** Anything drawn on a callboard card uses `UI.INK` / `UI.INK_SOFT` and `UI.Stamp(kind, true)`. Dark-surface tiers on card art are unreadable — this shipped as a bug in 1.10.0.
- **Never blind-click a popup.** Only click a dialog whose own text identifies it as the reroll confirmation. Any other dialog stops the run.
- **All strings via `UI.Colour` / `UI.Stamp`**, never raw `|cff` codes.
- **Every commit runs** `node tools/luacheck.js .` clean and all suites green.
- Test suites live in the scratchpad, not the repo: `C:\Users\Yahya\AppData\Local\Temp\claude\E--Games-Ebonhold-Interface-AddOns-CallboardHunter--claude-worktrees-sleepy-albattani-1dcd8e\ec0ef08b-1ea3-4536-9cab-8fbe19796d2a\scratchpad`. Run one with `node <name>_test.js`. Repo-side suites (`route_test.lua`, `cp_test.lua`) run via `cd tools && node run_lua.js <name>.lua`.
- **Regression bar:** `dungeon_test` must stay at 37 passing assertions after the extraction. That is the acceptance condition for Task 2.

## File Structure

| File | Responsibility |
|---|---|
| `Board.lua` *(new)* | The reroll engine. Reads cards, finds the Reroll button, verifies the confirm dialog, enforces cap/reserve/expiry, calls a supplied `match(cards)`, accepts the winner. Knows nothing about dungeons or favourites. |
| `Dungeon.lua` *(modified)* | Keeps instance detection, the entry reminder, quest sharing. Its loop is deleted and replaced by a `Board.Run` call with an instance-match callback. |
| `Favourites.lua` *(new)* | The favourites set, target extraction, the pickable list (bundled ∪ catalogue), `/cbh hunt`, and the star widget on cards. |
| `SpawnDB.lua` *(modified)* | Gains `QUESTS` (63 seed rows) and `SpawnDB.TargetOf(title)`. |
| `Core.lua` *(modified)* | `favourites = {}` default, `/cbh hunt` and `/cbh fav` commands. |
| `Config.lua` *(modified)* | Favourites section listing the database with checkboxes. |
| `CallboardHunter.toc` | Adds `Board.lua` (before `Dungeon.lua`) and `Favourites.lua` (after). |

---

### Task 1: Target extraction and the quest database

**Files:**
- Modify: `SpawnDB.lua` (append near `ClassifyCard`)
- Test: `scratchpad/resolve_test.lua` (append)

**Interfaces:**
- Consumes: nothing.
- Produces: `SpawnDB.TargetOf(title) -> string|nil` and `SpawnDB.QUESTS` (array of `{ target, lo, hi }`).

- [ ] **Step 1: Write the failing test**

Append to `resolve_test.lua` before the final `print("")` block:

```lua
print("")
print("== target extraction (prefixes are decorative) ==")
check("strips a flavour prefix", S.TargetOf("Dungeon Crawl: Loken"), "Loken")
check("same target, other prefix", S.TargetOf("Wanted: Loken"), "Loken")
check("multi-word target", S.TargetOf("Bulk Order: Eternal Earth"), "Eternal Earth")
check("colon inside the target survives", S.TargetOf("Wanted: SI:7 Insignia"), "SI:7 Insignia")
check("no colon -> whole title", S.TargetOf("Beasts of the Plains"), "Beasts of the Plains")
check("description line -> nil", S.TargetOf("Collect 20 Eternal Air."), nil)
check("empty -> nil", S.TargetOf(""), nil)
check("nil -> nil", S.TargetOf(nil), nil)

print("")
print("== bundled quest database ==")
local byTarget = {}
for _, q in ipairs(S.QUESTS) do byTarget[q.target] = q end
check("has the seed rows", #S.QUESTS >= 60, true)
check("Loken is present", byTarget["Loken"] ~= nil, true)
check("  ...with a level band", byTarget["Loken"].hi ~= nil, true)
check("Azure Scalebane is level 80", byTarget["Azure Scalebane"].hi, 80)
check("every row has a target", (function()
   for _, q in ipairs(S.QUESTS) do
      if type(q.target) ~= "string" or q.target == "" then return false end
   end
   return true
end)(), true)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "C:\Users\Yahya\AppData\Local\Temp\claude\E--Games-Ebonhold-Interface-AddOns-CallboardHunter--claude-worktrees-sleepy-albattani-1dcd8e\ec0ef08b-1ea3-4536-9cab-8fbe19796d2a\scratchpad" && node resolve_test.js
```

Expected: FAIL — `attempt to call a nil value (field 'TargetOf')`.

- [ ] **Step 3: Implement `TargetOf` and `QUESTS`**

Add to `SpawnDB.lua` immediately after `SpawnDB.ClassifyCard`:

```lua
-- A callboard title reads "<flavour prefix>: <target>". The prefix is
-- decorative and the target is the job: "Dungeon Crawl: Loken" and
-- "Wanted: Loken" are the same contract, which is why favourites key on the
-- target rather than the whole title. Splits on the FIRST colon only, so a
-- target containing one ("SI:7 Insignia") survives intact.
function SpawnDB.TargetOf(title)
   if type(title) ~= "string" or title == "" then return nil end
   -- Description lines ("Collect 20 Eternal Air.") are not titles.
   if string.sub(title, -1) == "." then return nil end
   local _, _, target = string.find(title, "^[^:]-:%s*(.+)$")
   local out = target or title
   out = string.gsub(out, "^%s+", "")
   out = string.gsub(out, "%s+$", "")
   if out == "" then return nil end
   return out
end
```

Then append the database. **Copy the 63 rows verbatim from `scratchpad/quests_seed.txt`** — they were extracted from the live catalogue and every row traces to a card actually seen:

```lua
-- Bundled quest targets, harvested from real cards (see the spec's Evidence
-- section). lo/hi are the level band the target was observed at. This is the
-- starting list; at runtime it merges with whatever the catalogue has learned,
-- and pooled exports grow it each release.
SpawnDB.QUESTS = {
   { target = "Adamantite Bar", lo = 67, hi = 69 },
   { target = "Adder's Tongue", lo = 77, hi = 80 },
   -- ... all 63 rows from scratchpad/quests_seed.txt, converted to this
   -- key = value form ...
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
node resolve_test.js
```

Expected: PASS, all assertions.

- [ ] **Step 5: Lint and commit**

```bash
cd "E:\Games\Ebonhold\Interface\AddOns\CallboardHunter\.claude\worktrees\sleepy-albattani-1dcd8e" && node tools/luacheck.js . | grep -E "not OK" || echo clean
git add SpawnDB.lua
git commit -m "feat: target extraction and bundled quest database"
```

---

### Task 2: Extract the reroll engine into Board.lua

**Files:**
- Create: `Board.lua`
- Modify: `Dungeon.lua` (delete lines currently at 52–75, 93–145, 153–302 — `ReadCards`, `MatchCard`, `FindReroll`, `FindRerollPopup`, `Stop`, `CanAffordReroll`, `Start`, `Tick`, `TickConfirm`, `Accept`), `CallboardHunter.toc`
- Test: `scratchpad/board_test.lua` *(new)*, `scratchpad/dungeon_test.lua` (unchanged — it is the regression gate)

**Interfaces:**
- Consumes: `SpawnDB.TargetOf` (Task 1) — not directly, but `Board.lua` loads after `SpawnDB.lua`.
- Produces:
  - `Board.ReadCards() -> { [i] = { frame, text } }`
  - `Board.FindReroll() -> Button|nil`
  - `Board.FindRerollPopup() -> Button|nil, string|nil`
  - `Board.Start(opts)` where `opts = { label = string, match = function(cards) -> index|nil, why|nil, onAccept = function(card, why)|nil }`
  - `Board.Poll(now)` — drives the active run; call from the Advisor ticker
  - `Board.Stop(reason)`
  - `Board.run` — active run table or `nil`

- [ ] **Step 1: Write the failing test**

Create `scratchpad/board_test.lua`. Copy the widget stubs verbatim from the top of `dungeon_test.lua` (through `local function Popup(text)` and the `check` helper), replace the module loads with `load("SpawnDB.lua"); load("Board.lua")`, then add:

```lua
local B = CBH.Board
INSIDE = true

print("== the engine honours a supplied match callback ==")
BuildBoard({ "Alpha", "Beta", "Gamma" })
local seen = nil
B.run = nil; NOW = 1
B.Start({ label = "test", match = function(cards)
   seen = #cards
   for i, c in ipairs(cards) do
      if string.find(c.text, "Beta", 1, true) then return i, "found beta" end
   end
end })
B.Poll(NOW)
check("callback saw all three cards", seen, 3)
check("accepted the matching card", board._children[2].sel._clicks, 1)
check("no reroll needed", rerollBtn._clicks, 0)

print("")
print("== no match -> rerolls, then stops at the cap ==")
CBH.db.options.dungeonRerollMax = 1
BuildBoard({ "Alpha", "Beta", "Gamma" })
B.run = nil; NOW = 10
B.Start({ label = "test", match = function() return nil end })
B.Poll(NOW)
check("clicked reroll", rerollBtn._clicks, 1)
Popup("Reroll selection for 10g 40s?")
NOW = 11; B.Poll(NOW)
check("confirmed", _G["StaticPopup1Button1"]._clicks, 1)
BuildBoard({ "Delta", "Epsilon", "Zeta" })
NOW = 12; B.Poll(NOW)
NOW = 13; B.Poll(NOW)
check("stopped at the cap", B.run, nil)
CBH.db.options.dungeonRerollMax = 10

print("")
print("== SAFETY: still refuses a non-reroll dialog ==")
BuildBoard({ "Alpha" })
B.run = nil; NOW = 20
B.Start({ label = "test", match = function() return nil end })
B.Poll(NOW)
Popup("Are you sure you want to DELETE this item?")
NOW = 21; B.Poll(NOW)
check("did not click it", _G["StaticPopup1Button1"]._clicks, 0)
check("stopped the run", B.run, nil)

print("")
print("== onAccept fires with the winning card ==")
BuildBoard({ "Alpha", "Beta" })
local gotWhy = nil
B.run = nil; NOW = 30
B.Start({ label = "test",
   match = function(cards) return 1, "first card" end,
   onAccept = function(card, why) gotWhy = why end })
B.Poll(NOW)
check("onAccept received the reason", gotWhy, "first card")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "C:\Users\Yahya\AppData\Local\Temp\claude\E--Games-Ebonhold-Interface-AddOns-CallboardHunter--claude-worktrees-sleepy-albattani-1dcd8e\ec0ef08b-1ea3-4536-9cab-8fbe19796d2a\scratchpad"
sed 's|rare_test.lua|board_test.lua|' rare_test.js > board_test.js
node board_test.js
```

Expected: FAIL — `load Board.lua` errors, file does not exist.

- [ ] **Step 3: Create `Board.lua`**

Move the following functions out of `Dungeon.lua` **unchanged in behaviour**, renaming `D.` to `Board.` and replacing the hard-coded instance match with the `opts.match` callback: `ReadCards`, `FindReroll`, `FindRerollPopup`, `Gold`, `Stop`, `CanAffordReroll`, `Tick`, `TickConfirm`, `Accept`.

Key differences from the current `Dungeon.lua` versions:

```lua
-- Board.Start replaces D.Start. `opts.match` is the only thing that varies
-- between callers: Dungeon passes "is this card for the instance I am in",
-- Favourites passes "is this card's target on my list".
function Board.Start(opts)
   if Board.run then return false end
   if not (opts and opts.match) then return false end
   Board.run = { label = opts.label or "board", match = opts.match,
                 onAccept = opts.onAccept, rerolls = 0, spent = 0,
                 unchanged = 0, at = 0, phase = "match", lastSig = nil }
   CBH.Log("board", "START " .. tostring(opts.label))
   return true
end
```

In `Board.Tick`, replace the `D.MatchCard(cards, r.instance)` call with:

```lua
   local idx, why = r.match(cards)
   if idx and cards[idx] then
      Board.Accept(cards[idx], why)
      return
   end
```

And in `Board.Accept`, after clicking Select, call the hook:

```lua
   r.phase = "accepted"
   sel:Click()
   if r.onAccept then r.onAccept(card, why) end
```

Add `Board.Poll`, which replaces the phase dispatch currently at the bottom of `Dungeon.Poll`. This is the only entry point callers use to drive a run:

```lua
-- Drive the active run one tick. Callers own deciding WHETHER to poll (their
-- own enable flag, their own board checks); this owns what happens next.
function Board.Poll(now)
   local r = Board.run
   if not r then return end
   if r.phase == "confirm" then Board.TickConfirm(now) else Board.Tick(now) end
end
```

Keep `DEFAULT_REROLL_COST`, `SETTLE`, `MAX_UNCHANGED`, `Opt` and the gold-reserve logic exactly as they are — they are the safety rails and must not change during a move.

- [ ] **Step 4: Rewrite `Dungeon.lua` to call the engine**

Delete the moved functions. `Dungeon.lua` keeps `CurrentInstance`, `MatchCard`, `OnQuestAccepted`, `OnZoneChanged`, `Command`, and gains:

```lua
-- The instance match, handed to the shared engine. Everything else about the
-- loop - rerolling, the verified confirm, the cap and reserve - lives in
-- Board.lua and is shared with favourites.
function D.Poll(now)
   if not Opt("dungeonAuto", false) then return end
   local board = _G["ObjectivesMainFrame"]
   if not (board and board.IsShown and board:IsShown()) then
      if CBH.Board.run and CBH.Board.run.label == "dungeon" then
         CBH.Board.Stop("the board despawned")
      end
      return
   end
   if not CBH.Board.run then
      local instance = D.CurrentInstance()
      if not instance then return end
      D.instance = instance
      CBH.Board.Start({
         label = "dungeon",
         match = function(cards) return D.MatchCard(cards, D.instance) end,
      })
   end
   CBH.Board.Poll(now)
end
```

`D.MatchCard` keeps its current signature and body — `dungeon_test` depends on it.

- [ ] **Step 5: Add `Board.lua` to the TOC**

In `CallboardHunter.toc`, insert `Board.lua` on the line **before** `Dungeon.lua`:

```
Comm.lua
Board.lua
Dungeon.lua
```

- [ ] **Step 6: Run both suites**

```bash
node board_test.js && node dungeon_test.js
```

Expected: `board_test` passes; **`dungeon_test` still reports `ALL 37 PASS`**. If dungeon assertions drop, the extraction changed behaviour — fix before continuing, do not adjust the test.

- [ ] **Step 7: Lint and commit**

```bash
cd "E:\Games\Ebonhold\Interface\AddOns\CallboardHunter\.claude\worktrees\sleepy-albattani-1dcd8e" && node tools/luacheck.js . | grep -E "not OK" || echo clean
git add Board.lua Dungeon.lua CallboardHunter.toc
git commit -m "refactor: extract the reroll engine into Board.lua"
```

---

### Task 3: The favourites set and pickable list

**Files:**
- Create: `Favourites.lua`
- Modify: `Core.lua` (defaults), `CallboardHunter.toc`
- Test: `scratchpad/fav_test.lua` *(new)*

**Interfaces:**
- Consumes: `SpawnDB.TargetOf`, `SpawnDB.QUESTS` (Task 1).
- Produces:
  - `Fav.IsFavourite(target) -> boolean`
  - `Fav.Toggle(target) -> boolean` (new state)
  - `Fav.Count() -> number`
  - `Fav.List() -> { { target, lo, hi, favourite } }` sorted by target, bundled ∪ catalogue
  - `Fav.MatchCards(cards) -> index|nil, why|nil`

- [ ] **Step 1: Write the failing test**

Create `scratchpad/fav_test.lua` with the widget stubs from `dungeon_test.lua`, loading `SpawnDB.lua` then `Favourites.lua`, then:

```lua
local Fav = CBH.Favourites
CBH.db.favourites = {}
CBH.db.cardCatalogue = {}

print("== toggling ==")
check("not favourite initially", Fav.IsFavourite("Loken"), false)
check("toggle on returns true", Fav.Toggle("Loken"), true)
check("  ...and it sticks", Fav.IsFavourite("Loken"), true)
check("toggle off returns false", Fav.Toggle("Loken"), false)
check("  ...and it clears", Fav.IsFavourite("Loken"), false)
check("nil is safe", Fav.Toggle(nil), false)

print("")
print("== matching keys on the target, not the title ==")
CBH.db.favourites = { ["Loken"] = true }
BuildBoard({ "Bulk Order: Eternal Earth", "Dungeon Crawl: Loken", "No Mercy: Azure Scalebane" })
local idx, why = Fav.MatchCards(CBH.Board and CBH.Board.ReadCards() or ReadCardsStub())
check("found the favourite", idx, 2)
check("  ...and says why", string.find(why or "", "Loken", 1, true) ~= nil, true)

BuildBoard({ "Wanted: Loken" })
check("same target, different prefix", (Fav.MatchCards(ReadCardsStub())), 1)

BuildBoard({ "Bulk Order: Eternal Earth" })
check("no favourite present", Fav.MatchCards(ReadCardsStub()), nil)

print("")
print("== progress counters do not break matching ==")
CBH.db.favourites = { ["Azure Scalebane"] = true }
BuildBoard({ "No Mercy: Azure Scalebane", "Azure Scalebane slain: 3/10" })
check("matches despite the counter", (Fav.MatchCards(ReadCardsStub())), 1)

print("")
print("== the pickable list is bundled union catalogue ==")
CBH.db.favourites = {}
CBH.db.cardCatalogue = { ["Sweep and Clear: Brand New Mob"] = { n = 1, lo = 80, hi = 80 } }
local list = Fav.List()
local names = {}
for _, e in ipairs(list) do names[e.target] = e end
check("includes a bundled target", names["Loken"] ~= nil, true)
check("includes a learned target", names["Brand New Mob"] ~= nil, true)
check("marks favourites", names["Loken"].favourite, false)
CBH.db.favourites = { ["Loken"] = true }
local list2 = Fav.List()
local n2 = {}
for _, e in ipairs(list2) do n2[e.target] = e end
check("  ...once favourited", n2["Loken"].favourite, true)
check("no duplicates", (function()
   local seen, dupes = {}, 0
   for _, e in ipairs(Fav.List()) do
      if seen[e.target] then dupes = dupes + 1 end
      seen[e.target] = true
   end
   return dupes
end)(), 0)
check("count reflects the set", Fav.Count(), 1)
```

Add this helper near the top of `fav_test.lua`, after `BuildBoard` is defined, because `Fav.MatchCards` takes the card list rather than reading it itself:

```lua
function ReadCardsStub()
   local out = {}
   for i = 1, 3 do
      local card = _G["ObjectiveFrame" .. i]
      if card and card:IsShown() then
         local texts = {}
         for r = 1, select("#", card:GetRegions()) do
            local reg = select(r, card:GetRegions())
            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
               local t = reg:GetText()
               if t and t ~= "" then texts[#texts + 1] = t end
            end
         end
         out[i] = { frame = card, text = table.concat(texts, " | ") }
      end
   end
   return out
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
sed 's|rare_test.lua|fav_test.lua|' rare_test.js > fav_test.js
node fav_test.js
```

Expected: FAIL — `Favourites.lua` does not exist.

- [ ] **Step 3: Create `Favourites.lua`**

```lua
-- CallboardHunter Favourites: mark callboard quests you want, and hunt for them.
--
-- Keys on the TARGET, not the title. A callboard title reads
-- "<flavour prefix>: <target>", and the prefix is decorative - "Dungeon Crawl:
-- Loken" and "Wanted: Loken" are the same contract. Favouriting the title would
-- miss the same job under a different prefix.
local CBH = CallboardHunter
local Fav = CBH.Favourites or {}
CBH.Favourites = Fav

function Fav.IsFavourite(target)
   if not (target and CBH.db and CBH.db.favourites) then return false end
   return CBH.db.favourites[target] == true
end

function Fav.Toggle(target)
   if not (target and target ~= "" and CBH.db) then return false end
   CBH.db.favourites = CBH.db.favourites or {}
   if CBH.db.favourites[target] then
      CBH.db.favourites[target] = nil
      return false
   end
   CBH.db.favourites[target] = true
   return true
end

function Fav.Count()
   local n = 0
   for _ in pairs((CBH.db and CBH.db.favourites) or {}) do n = n + 1 end
   return n
end

-- Which card (if any) is a favourite. Signature matches what Board.Start wants.
function Fav.MatchCards(cards)
   if Fav.Count() == 0 then return nil end
   for i, c in ipairs(cards or {}) do
      -- A card's text is every FontString joined; check each line, because the
      -- title and the objective are separate lines on the same card.
      for line in string.gmatch(c.text or "", "[^|]+") do
         local target = CBH.SpawnDB.TargetOf((string.gsub(line, "^%s+", "")))
         if target and Fav.IsFavourite(target) then
            return i, "favourite: " .. target
         end
      end
   end
   return nil
end

-- Bundled database merged with everything the catalogue has learned.
function Fav.List()
   local rows, byTarget = {}, {}
   local function add(target, lo, hi)
      if not target or target == "" then return end
      local e = byTarget[target]
      if e then
         if lo and (not e.lo or lo < e.lo) then e.lo = lo end
         if hi and (not e.hi or hi > e.hi) then e.hi = hi end
         return
      end
      e = { target = target, lo = lo, hi = hi }
      byTarget[target] = e
      rows[#rows + 1] = e
   end
   for _, q in ipairs((CBH.SpawnDB and CBH.SpawnDB.QUESTS) or {}) do
      add(q.target, q.lo, q.hi)
   end
   for text, meta in pairs((CBH.db and CBH.db.cardCatalogue) or {}) do
      add(CBH.SpawnDB.TargetOf(text), meta and meta.lo, meta and meta.hi)
   end
   for _, e in ipairs(rows) do e.favourite = Fav.IsFavourite(e.target) end
   table.sort(rows, function(a, b) return a.target < b.target end)
   return rows
end
```

- [ ] **Step 4: Add the default and the TOC entry**

In `Core.lua`, add to `DEFAULTS` after `cardCatalogue`:

```lua
   favourites = {},    -- [questTarget] = true; see Favourites.lua
```

In `CallboardHunter.toc`, add `Favourites.lua` after `Dungeon.lua`:

```
Board.lua
Dungeon.lua
Favourites.lua
```

- [ ] **Step 5: Run test to verify it passes**

```bash
node fav_test.js
```

Expected: PASS, all assertions.

- [ ] **Step 6: Lint and commit**

```bash
cd "E:\Games\Ebonhold\Interface\AddOns\CallboardHunter\.claude\worktrees\sleepy-albattani-1dcd8e" && node tools/luacheck.js . | grep -E "not OK" || echo clean
git add Favourites.lua Core.lua CallboardHunter.toc
git commit -m "feat: favourites set and pickable quest list"
```

---

### Task 4: The hunt

**Files:**
- Modify: `Favourites.lua`, `Core.lua` (slash command)
- Test: `scratchpad/fav_test.lua` (append)

**Interfaces:**
- Consumes: `Board.Start`, `Board.Poll`, `Board.run` (Task 2); `Fav.MatchCards`, `Fav.Count` (Task 3).
- Produces: `Fav.Hunt()`, `Fav.Poll(now)`, `Fav.Command(arg)`.

- [ ] **Step 1: Write the failing test**

Append to `fav_test.lua`:

```lua
print("")
print("== hunt refuses to start with an empty list ==")
CBH.db.favourites = {}
PRINTED = {}
BuildBoard({ "Alpha", "Beta", "Gamma" })
CBH.Board.run = nil; NOW = 100
check("did not start", Fav.Hunt(), false)
check("  ...and said why", string.find(table.concat(PRINTED, " "), "favourite") ~= nil, true)
check("  ...clicked nothing", rerollBtn._clicks, 0)

print("")
print("== hunt takes a favourite that is already on the board ==")
CBH.db.favourites = { ["Loken"] = true }
BuildBoard({ "Bulk Order: Eternal Earth", "Wanted: Loken", "No Mercy: Azure Scalebane" })
CBH.Board.run = nil; NOW = 110
check("started", Fav.Hunt(), true)
Fav.Poll(NOW)
check("took the favourite", board._children[2].sel._clicks, 1)
check("without rerolling", rerollBtn._clicks, 0)

print("")
print("== hunt rerolls when no favourite is present ==")
BuildBoard({ "Bulk Order: Eternal Earth" })
CBH.Board.run = nil; NOW = 120
Fav.Hunt()
Fav.Poll(NOW)
check("clicked reroll", rerollBtn._clicks, 1)

print("")
print("== hunt needs an open board ==")
board._shown = false
CBH.Board.run = nil; PRINTED = {}
check("refuses with no board", Fav.Hunt(), false)
board._shown = true
```

- [ ] **Step 2: Run test to verify it fails**

```bash
node fav_test.js
```

Expected: FAIL — `attempt to call a nil value (field 'Hunt')`.

- [ ] **Step 3: Implement the hunt**

Append to `Favourites.lua`:

```lua
-- Explicit start only. There is no 30-second timer at a permanent callboard, so
-- nothing may spend gold without being asked for in that moment - unlike the
-- dungeon case, where the board despawning is a natural brake.
function Fav.Hunt()
   local board = _G["ObjectivesMainFrame"]
   if not (board and board.IsShown and board:IsShown()) then
      CBH.print("Open a callboard first, then hunt.")
      return false
   end
   if Fav.Count() == 0 then
      CBH.print("No favourites yet - click the star on a card, or pick some in"
         .. " /cbh config. Hunting with an empty list would reroll forever.")
      return false
   end
   if CBH.Board.run then
      CBH.print("Already working the board - let it finish.")
      return false
   end
   return CBH.Board.Start({
      label = "favourites",
      match = Fav.MatchCards,
   })
end

function Fav.Poll(now)
   if CBH.Board.run and CBH.Board.run.label == "favourites" then
      CBH.Board.Poll(now)
   end
end

function Fav.Command(arg)
   arg = string.lower(arg or "")
   if arg == "hunt" then
      Fav.Hunt()
   elseif arg == "" or arg == "list" then
      local n = Fav.Count()
      CBH.print(n .. " favourite" .. (n == 1 and "" or "s") .. ".")
      if n > 0 then
         for target in pairs(CBH.db.favourites) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. CBH.UI.Stamp("ready") .. " " .. target)
         end
      end
      CBH.print("/cbh fav clear  |  /cbh hunt to reroll toward one.")
   elseif arg == "clear" then
      CBH.db.favourites = {}
      CBH.print("Favourites cleared.")
   end
end
```

- [ ] **Step 4: Wire the slash commands**

In `Core.lua`, add before the `elseif cmd == "export"` branch:

```lua
   elseif cmd == "hunt" then
      if CBH.Favourites then CBH.safeCall(CBH.Favourites.Hunt) end
   elseif cmd == "fav" or cmd == "favourites" then
      if CBH.Favourites then CBH.safeCall(CBH.Favourites.Command, arg) end
```

And add `| hunt | fav` to the help string.

In `Advisor.lua`, beside the existing `CBH.Dungeon.Poll` call in the ticker:

```lua
   if CBH.Favourites and CBH.Favourites.Poll then
      CBH.safeCall(CBH.Favourites.Poll, GetTime())
   end
```

- [ ] **Step 5: Run test to verify it passes**

```bash
node fav_test.js
```

Expected: PASS.

- [ ] **Step 6: Lint, run every suite, commit**

```bash
cd "C:\Users\Yahya\AppData\Local\Temp\claude\E--Games-Ebonhold-Interface-AddOns-CallboardHunter--claude-worktrees-sleepy-albattani-1dcd8e\ec0ef08b-1ea3-4536-9cab-8fbe19796d2a\scratchpad"
for t in rare resolve comm export header dungeon cb_zone ui board fav; do printf '%-9s ' "$t"; node ${t}_test.js 2>&1 | tail -1; done
cd "E:\Games\Ebonhold\Interface\AddOns\CallboardHunter\.claude\worktrees\sleepy-albattani-1dcd8e" && node tools/luacheck.js . | grep -E "not OK" || echo clean
git add Favourites.lua Core.lua Advisor.lua
git commit -m "feat: /cbh hunt - reroll toward a favourite"
```

---

### Task 5: The star on each card

**Files:**
- Modify: `Advisor.lua` (`RefreshCards`, around line 84)
- Test: `scratchpad/fav_test.lua` (append)

**Interfaces:**
- Consumes: `Fav.Toggle`, `Fav.IsFavourite`, `SpawnDB.TargetOf`.
- Produces: `Fav.StarText(target) -> string` — the glyph shown on a card.

- [ ] **Step 1: Write the failing test**

Append to `fav_test.lua`:

```lua
print("")
print("== the star reads as a shape, not a colour ==")
CBH.db.favourites = {}
local off = Fav.StarText("Loken")
Fav.Toggle("Loken")
local on = Fav.StarText("Loken")
check("off and on differ", off ~= on, true)
local function strip(s)
   s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
   return (string.gsub(s, "|r", ""))
end
check("still differ with colour stripped", strip(off) ~= strip(on), true)
check("off is the hollow glyph", strip(off), "[ ]")
check("on is the filled glyph", strip(on), "[*]")
check("unknown target still renders", strip(Fav.StarText("Nobody")), "[ ]")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
node fav_test.js
```

Expected: FAIL — `attempt to call a nil value (field 'StarText')`.

- [ ] **Step 3: Implement `StarText`**

Append to `Favourites.lua`:

```lua
-- A filled vs hollow bracket, never colour alone: keepsy is colourblind, and
-- the whole UI system holds to shape-plus-word. Drawn on the server's light
-- card art, so it uses the ink tiers rather than the dark-surface ones.
function Fav.StarText(target)
   local on = Fav.IsFavourite(target)
   return CBH.UI.Colour(on and "brassInk" or "inkSoft", on and "[*]" or "[ ]")
end
```

- [ ] **Step 4: Draw it on the card**

In `Advisor.lua`'s `RefreshCards`, after `card.cbhNote` is created and its text set, add a clickable star. Insert immediately before `card.cbhNote:SetText(note or "")`:

```lua
         -- Favourite toggle. The card's own title is the first FontString, so
         -- the target comes from there rather than from the note we drew.
         if not card.cbhStar then
            card.cbhStar = CreateFrame("Button", nil, card)
            card.cbhStar:SetWidth(22); card.cbhStar:SetHeight(18)
            card.cbhStar:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6)
            card.cbhStar.label = CBH.UI.Text(card.cbhStar, "label",
               CBH.UI.INK_SOFT, CBH.UI.FONT_META)
            card.cbhStar.label:SetPoint("CENTER", card.cbhStar, "CENTER", 0, 0)
            card.cbhStar:SetScript("OnClick", function(self)
               if self.cbhTarget then
                  CBH.Favourites.Toggle(self.cbhTarget)
                  self.label:SetText(CBH.Favourites.StarText(self.cbhTarget))
               end
            end)
         end
         local title = CardTexts(card)[1]
         local target = title and CBH.SpawnDB.TargetOf(title) or nil
         card.cbhStar.cbhTarget = target
         if target then
            card.cbhStar.label:SetText(CBH.Favourites.StarText(target))
            card.cbhStar:Show()
         else
            card.cbhStar:Hide()
         end
```

Also add `card.cbhStar` to the skip list in `CardTexts` so the star is never catalogued as card text, beside the existing `card.cbhNote` check:

```lua
      if r ~= card.cbhNote and r ~= (card.cbhStar and card.cbhStar.label)
         and r and r.GetObjectType and r:GetObjectType() == "FontString" then
```

- [ ] **Step 5: Run test to verify it passes**

```bash
node fav_test.js
```

Expected: PASS.

- [ ] **Step 6: Lint and commit**

```bash
cd "E:\Games\Ebonhold\Interface\AddOns\CallboardHunter\.claude\worktrees\sleepy-albattani-1dcd8e" && node tools/luacheck.js . | grep -E "not OK" || echo clean
git add Favourites.lua Advisor.lua
git commit -m "feat: favourite star on callboard cards"
```

---

### Task 6: Config panel list, docs, release

**Files:**
- Modify: `Config.lua`, `README.md`, `CHANGELOG.md`, `CallboardHunter.toc`
- Test: full suite run

- [ ] **Step 1: Add the favourites section to the config panel**

In `Config.lua`, after the blocked-checkpoints section, add a scrolling list built from `Fav.List()`. Follow the existing `RefreshConfig` row-pooling pattern (`rows[i]` reuse, `row.text`, `row.del`) rather than inventing a new one. Each row shows `Fav.StarText(target) .. " " .. target` plus its level band in `UI.TEXT_MUTED`, and clicking toggles. Use `UI.Text(row, "body", UI.TEXT_SECONDARY)` — this is the addon's own dark panel, so dark-surface tiers are correct here, unlike on cards.

- [ ] **Step 2: Bump the version**

In `CallboardHunter.toc`, set `## Version: 1.11.0`.

- [ ] **Step 3: Document it**

Add to `README.md`'s command table:

```
| `/cbh fav` / `fav clear` | list or clear your favourite callboard quests |
| `/cbh hunt` | reroll the open board until a favourite appears |
```

Add a `## [1.11.0]` CHANGELOG entry covering: favourites keyed on the quest target (so `Dungeon Crawl: Loken` and `Wanted: Loken` are one thing), the star on cards, `/cbh hunt` with its empty-list refusal, the bundled 63-target database that grows from the catalogue, and the `Board.lua` extraction as an internal change.

- [ ] **Step 4: Run everything**

```bash
cd "C:\Users\Yahya\AppData\Local\Temp\claude\E--Games-Ebonhold-Interface-AddOns-CallboardHunter--claude-worktrees-sleepy-albattani-1dcd8e\ec0ef08b-1ea3-4536-9cab-8fbe19796d2a\scratchpad"
for t in rare resolve comm export header dungeon cb_zone ui board fav; do printf '%-9s ' "$t"; node ${t}_test.js 2>&1 | tail -1; done
cd "E:\Games\Ebonhold\Interface\AddOns\CallboardHunter\.claude\worktrees\sleepy-albattani-1dcd8e\tools" && node run_lua.js route_test.lua | tail -1 && node run_lua.js cp_test.lua | tail -1
```

Expected: every suite passes, `dungeon_test` still at 37.

- [ ] **Step 5: Commit, push, release, update the live folder**

```bash
cd "E:\Games\Ebonhold\Interface\AddOns\CallboardHunter\.claude\worktrees\sleepy-albattani-1dcd8e"
git add -A && git commit -m "v1.11.0: callboard favourites"
git push origin HEAD:main
git push origin HEAD:refs/heads/claude/sleepy-albattani-1dcd8e
git archive --format=zip --prefix=CallboardHunter/ -o "<scratchpad>/CallboardHunter-v1.11.0.zip" HEAD
gh release create v1.11.0 "<scratchpad>/CallboardHunter-v1.11.0.zip#CallboardHunter-v1.11.0.zip" --repo myi1/CallboardHunter --latest --title "CallboardHunter v1.11.0" --notes-file <notes>
git -C "E:\Games\Ebonhold\Interface\AddOns\CallboardHunter" merge --ff-only origin/main
```
