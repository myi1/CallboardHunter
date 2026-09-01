# Route Grind Phase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `Route.lua`'s zone-grind tail with a callboard-quest grind, make the hardcore step perform and verify the switch instead of asking the player to tick it, and start the route on its own after a prestige reset.

**Architecture:** `Route.lua` is a linear list of steps (`Route.STEPS`) driven by one secure button whose `macrotext` is rewritten per step. Three changes: a new `Route.HcCurrent()` reads the live tier out of the server's own frame; `kind = "mode"` gains act-and-verify behaviour; and the four zone-grind steps become a `hcGrind` + `cbGrind` pair. No new frames, no new buttons.

**Tech Stack:** Lua 5.1 (WoW 3.3.5a client). Offline tests run the real source under fengari via `tools/run_lua.js`.

## Global Constraints

- **Lua 5.1 only.** No `goto`, no integer division, no `table.unpack` (it is `unpack`). Suites shim `unpack = unpack or table.unpack` because fengari is 5.3.
- **Never blind-click a dialog.** Only click a popup whose own text identifies it. Anything unrecognised stops the step and tells the player. This is the rule `Board.lua` already follows for the reroll confirmation.
- **Never `SetScript("OnClick")` on `CallboardHunterRouteGo`.** It is a `SecureActionButtonTemplate`; replacing its OnClick silently kills secure behaviour. All actions go through `macrotext` (`Route.lua:1170-1177`).
- **CBH does not cast spells for you.** `CastSpellByName` is protected. A cast only happens because *you* clicked the secure button.
- **All user-facing strings via `UI.Colour` / `UI.Stamp`**, never raw `|cff` codes — except inside `Route.lua`, which predates `UI.lua` and uses its own `BRIGHT`/`DIM`/`R` locals. Follow the local file's convention.
- **Comment voice:** explain *why* a thing exists or what real case forced it, never what the line does.
- **Every commit leaves** `node tools/luacheck.js .` clean and all suites green.
- **Baseline:** 14 suites, 642 assertions, 0 failing. `tools/dungeon_test.lua` is a frozen regression gate at exactly **37** — never modify that file.
- Run tests with `cd tools && node run_all.js`; one suite with `node run_lua.js route_test.lua`.

## File Structure

| File | Responsibility |
|---|---|
| `Route.lua` *(modified)* | All of it. Reading the tier, the act-and-verify mode step, the grind steps, the auto-start trigger. |
| `tools/route_test.lua` *(modified)* | The route state machine's suite. All new assertions land here. |
| `CHANGELOG.md`, `CallboardHunter.toc`, `README.md` *(modified)* | Release. |

`Route.lua` is 1674 lines and already large. This plan does **not** split it: the changes are localised to the step table, `StepDone`, and `Route.Act`, and a split would make the diff unreviewable against a frozen suite. Note it as debt rather than acting on it.

---

### Task 1: Read the live hardcore tier

**Files:**
- Modify: `Route.lua` (new function beside `Route.HcTier`, around line 142)
- Test: `tools/route_test.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Route.HcCurrent() -> number|nil` — the tier the player is on right now, or nil when the control cannot be found.

**Evidence this is possible** (from a live `/cbh frames tree ProjectEbonholdPlayerRunFrame`):

```
- ? (Frame)
   text: |cffffffff29,008|r
   text: |cff00ff00+827%|r
 - ? (Button)
    text: |cffFF4444Hardcore 5|r
```

The tier is a `FontString` on a `Button` nested under `ProjectEbonholdPlayerRunFrame`. The colour code must be stripped before parsing.

- [ ] **Step 1: Write the failing test**

Add near the other `Route.*` unit assertions in `tools/route_test.lua`. The harness has no real frames, so build the shape the dump showed:

```lua
-- The server paints the tier with a colour code; the digit is what matters.
local function FakeRunFrame(label)
  local fs = { GetText = function() return label end,
               GetObjectType = function() return "FontString" end }
  local btn = { GetObjectType = function() return "Button" end,
                GetRegions = function() return fs end,
                GetChildren = function() return end,
                IsShown = function() return true end }
  return { GetObjectType = function() return "Frame" end,
           GetRegions = function() return end,
           GetChildren = function() return btn end,
           IsShown = function() return true end }
end

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 5|r")
check("reads the live tier through its colour code", Route.HcCurrent(), 5)

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("Hardcore 2")
check("reads an uncoloured tier too", Route.HcCurrent(), 2)

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("Softcore")
check("no tier in the text -> nil", Route.HcCurrent(), nil)

_G.ProjectEbonholdPlayerRunFrame = nil
check("no run frame at all -> nil", Route.HcCurrent(), nil)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd tools && node run_lua.js route_test.lua
```

Expected: FAIL — `Route.HcCurrent` is nil, so calling it errors.

- [ ] **Step 3: Write minimal implementation**

Place immediately after `Route.HcTier` (`Route.lua:142-148`):

```lua
-- The tier you are ACTUALLY on, read out of the server's own run frame.
-- Route.HcTier is what you asked for; this is what is true. Discovered by
-- dumping ProjectEbonholdPlayerRunFrame: the tier is a colour-coded FontString
-- on a Button nested inside it, which is the same shape of custom UI Board.lua
-- already drives. The old "No API for this" note meant no documented server
-- function, not an undrivable frame.
local function TierFromText(t)
  if not t then return nil end
  local plain = string.gsub(t, "|c%x%x%x%x%x%x%x%x", "")
  plain = string.gsub(plain, "|r", "")
  return tonumber(string.match(plain, "Hardcore%s+(%d)"))
end

-- The button carrying the tier, so callers can both read AND click it.
function Route.HcButton()
  local root = _G["ProjectEbonholdPlayerRunFrame"]
  if not (root and root.GetChildren) then return nil end
  local found, tier
  local function walk(f, depth)
    if found or depth > 4 or not f.GetChildren then return end
    for i = 1, select("#", f:GetChildren()) do
      local c = select(i, f:GetChildren())
      if c and not found then
        if c.GetRegions and c.GetObjectType and c:GetObjectType() == "Button" then
          for j = 1, select("#", c:GetRegions()) do
            local r = select(j, c:GetRegions())
            if r and r.GetObjectType and r:GetObjectType() == "FontString" then
              local n = TierFromText(r:GetText())
              if n then found, tier = c, n; return end
            end
          end
        end
        walk(c, depth + 1)
      end
    end
  end
  walk(root, 0)
  return found, tier
end

function Route.HcCurrent()
  local _, tier = Route.HcButton()
  return tier
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd tools && node run_lua.js route_test.lua
```

Expected: PASS. Then `cd tools && node run_all.js` — 14 suites, `dungeon_test.lua` still 37.

- [ ] **Step 5: Commit**

```bash
git add Route.lua tools/route_test.lua
git commit -m "route: read the live hardcore tier from the server's run frame"
```

---

### Task 2: The mode step acts and verifies

**Files:**
- Modify: `Route.lua` — `StepDone` (line ~426, the `return false -- mode steps are acknowledged` tail), `Route.Act` (line ~928), and the two `mode` step `detail` strings (lines 75-76, 99-100)
- Test: `tools/route_test.lua`

**Interfaces:**
- Consumes: `Route.HcButton() -> frame|nil, number|nil`, `Route.HcCurrent() -> number|nil` (Task 1).
- Produces: `Route.HcSwitch() -> boolean, string` — attempts the switch, returns whether the tier changed and a reason when it did not.

A mode step currently completes only via `d.acked[step.key]`. It should complete when the tier genuinely equals the target, and fall back to acknowledgement when the control is missing — so a server UI change degrades to today's behaviour instead of breaking the route.

- [ ] **Step 1: Write the failing test**

```lua
-- Detection: a mode step is done when the tier actually matches.
_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 3|r")
DB().acked = {}
DB().hcEnd = 3
check("mode step is done when the tier already matches", Route.HcCurrent(), 3)

-- Switching: clicking is attempted, and success is judged by re-reading.
local clicks = 0
local btn, _ = Route.HcButton()
btn.Click = function() clicks = clicks + 1 end
local ok, why = Route.HcSwitch(3)
check("already on target -> no click needed", clicks, 0)
check("  ...and it reports success", ok, true)

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 5|r")
local b2 = Route.HcButton()
clicks = 0
b2.Click = function() clicks = clicks + 1 end
ok, why = Route.HcSwitch(3)
check("a real change clicks the server's control", clicks, 1)
check("  ...but refuses to claim success when the tier did not move", ok, false)
check("  ...and says why", string.find(tostring(why), "still on") ~= nil, true)

_G.ProjectEbonholdPlayerRunFrame = nil
ok, why = Route.HcSwitch(3)
check("no control -> not a success", ok, false)
check("  ...and points at manual acknowledgement",
      string.find(tostring(why), "Mark done") ~= nil, true)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd tools && node run_lua.js route_test.lua
```

Expected: FAIL — `Route.HcSwitch` is nil.

- [ ] **Step 3: Write minimal implementation**

Add after `Route.HcCurrent`:

```lua
-- Perform the switch, then CHECK it. The old step asked you to tick a box, which
-- meant a failed switch looked exactly like a successful one and the route
-- carried on regardless. Returns ok, reason.
function Route.HcSwitch(target)
  local btn, tier = Route.HcButton()
  if not btn then
    return false, "Could not find the tier control -- switch it yourself and Mark done."
  end
  if tier == target then return true end
  btn:Click()
  local _, now = Route.HcButton()
  if now == target then return true end
  return false, "Clicked the tier control but you are still on Hardcore "
    .. tostring(now) .. " -- finish it in the popup, then Mark done."
end
```

In `StepDone`, replace the final `return false -- mode steps are acknowledged, not detected` with:

```lua
  elseif step.kind == "mode" then
    -- Detected now, not merely acknowledged: the tier is readable, so a step
    -- that claims to have switched can be checked against reality.
    local now = Route.HcCurrent()
    return now ~= nil and now == step.tier
  end
  return false
```

In `Route.Act`, replace the `elseif step.kind == "mode" then` branch:

```lua
  elseif step.kind == "mode" then
    local ok, why = Route.HcSwitch(step.tier)
    if ok then
      CBH.print("Now on " .. BRIGHT .. "Hardcore " .. step.tier .. R .. ".")
    else
      CBH.print(why)
    end
```

Update both mode steps' `detail` to stop claiming there is no API:

```lua
detail = "CBH clicks the tier control on the run frame and checks it took. If the server's UI moves, switch it yourself and Mark done."
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd tools && node run_lua.js route_test.lua && node run_all.js
```

Expected: PASS, `dungeon_test.lua` still 37.

- [ ] **Step 5: Commit**

```bash
git add Route.lua tools/route_test.lua
git commit -m "route: the hardcore step switches and verifies instead of asking"
```

---

### Task 3: Replace the zone grind with a callboard grind

**Files:**
- Modify: `Route.lua` — `Route.STEPS` tail (lines 99-117), `Route.HcTier` (line 142), `Route.Steps` (line 161)
- Test: `tools/route_test.lua`

**Interfaces:**
- Consumes: `Route.HcSwitch`, `Route.HcCurrent` (Tasks 1-2).
- Produces: step keys `hcGrind` and `cbGrind`; `Route.HcTier("grind") -> number`.

Today's tail is `hcEnd` → `bt` → `grindBt` (level 72) → `ice` → `grindIce` (level 80): a Borean Tundra / Icecrown zone grind. Replace all five with a hardcore switch and a single callboard grind step. Per the spec, the tier switch happens **once** at the start of the grind and is then left alone.

`kind = "level"` already exists and `StepDone` already completes it on `UnitLevel >= target`, and its button ports to `step.cp` — so "port to Dalaran" needs no new mechanism.

- [ ] **Step 1: Write the failing test**

```lua
check("the zone grind is gone", Route.StepIndex("grindBt"), nil)
check("  ...and so is its Icecrown half", Route.StepIndex("grindIce"), nil)
check("the grind tier switch exists", Route.StepIndex("hcGrind") ~= nil, true)
check("the callboard grind exists", Route.StepIndex("cbGrind") ~= nil, true)
check("the switch comes before the grind",
      Route.StepIndex("hcGrind") < Route.StepIndex("cbGrind"), true)

local steps = Route.Steps()
local grind = steps[Route.StepIndex("cbGrind")]
check("the grind ends at 80", grind.target, 80)
check("its button ports to Dalaran", grind.cp, "DALARAN")

DB().hcGrind = 4
check("the grind tier is configurable", Route.HcTier("grind"), 4)
DB().hcGrind = nil
check("and defaults to the levelling tier", Route.HcTier("grind"), Route.HcTier("start"))

-- The grind must not assume the chain lands you at 64: ash XP nodes move it.
W.level = 71
check("not done at 71", Route.StepDoneFor("cbGrind"), false)
W.level = 80
check("done at 80", Route.StepDoneFor("cbGrind"), true)
```

`Route.StepIndex(key)` and `Route.StepDoneFor(key)` are small test seams added in Step 3.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd tools && node run_lua.js route_test.lua
```

Expected: FAIL — `Route.StepIndex` is nil, and `grindBt` still exists.

- [ ] **Step 3: Write minimal implementation**

Replace `Route.STEPS` lines 99-117 (`hcEnd` through `grindIce`) with:

```lua
  -- The lap used to end with a Borean Tundra / Icecrown zone grind. keepsy runs
  -- callboard quests instead, so the tail is now: switch tier once, then work
  -- the callboard from Dalaran until 80. The chain's landing level is NOT fixed
  -- at 64 -- ash XP nodes move it -- so the grind simply runs until you ding 80
  -- from wherever the turn-in left you.
  { key = "hcGrind", kind = "mode", hcStep = true, tierKey = "grind",
    detail = "Set the tier you can hold for the callboard grind. Done once here, not every quest." },
  { key = "cbGrind", kind = "level", target = 80, cp = "DALARAN",
    text = "Level to 80 on callboard quests",
    detail = "Summon the board, take a quest, run it, come back. The button ports you to Dalaran." },
}
```

Extend `Route.HcTier` to know the third tier:

```lua
function Route.HcTier(which)
  local d = DB()
  if which == "start" then return tonumber(d.hcStart) or 5 end
  -- The grind tier defaults to the levelling one so a first run needs no setup.
  if which == "grind" then return tonumber(d.hcGrind) or (tonumber(d.hcStart) or 5) end
  return tonumber(d.hcEnd) or 3
end
```

In `Route.Steps`, the `hcStep` branch builds `st.text` from `tierKey`; add the grind wording:

```lua
        st.text = (st.tierKey == "start")
          and ("Switch to Hardcore " .. st.tier)
          or ((st.tierKey == "grind")
            and ("Switch to Hardcore " .. st.tier .. " for the grind")
            or ("Drop to Hardcore " .. st.tier .. " (optional)"))
```

Add the two test seams beside `Route.Steps`:

```lua
-- Test seams: the suite needs to ask about a step by key without reaching into
-- the private step table or duplicating the filtering Route.Steps does.
function Route.StepIndex(key)
  for i, st in ipairs(Route.Steps()) do
    if st.key == key then return i end
  end
  return nil
end

function Route.StepDoneFor(key)
  local i = Route.StepIndex(key)
  if not i then return nil end
  return StepDone(Route.Steps()[i], ScanQuestLog(false, true)) and true or false
end
```

`StepDone` and `ScanQuestLog` are locals declared above `Route.Steps`; if `Route.StepDoneFor` sits before them, move it below their definitions rather than forward-declaring.

- [ ] **Step 4: Run test to verify it passes**

```bash
cd tools && node run_lua.js route_test.lua && node run_all.js
```

Expected: PASS. `route_test.lua` walks a full lap; if a lap-walk assertion breaks because the tail changed, that is a **real** expectation to update — the lap genuinely has different steps now. Update those expectations, but do not weaken any assertion that is not about the removed steps.

- [ ] **Step 5: Commit**

```bash
git add Route.lua tools/route_test.lua
git commit -m "route: callboard grind to 80 replaces the zone grind"
```

---

### Task 4: Summon the callboard from the route button

**Files:**
- Modify: `Route.lua` — `Route.Refresh`'s macrotext assignment for the current step
- Test: `tools/route_test.lua`

**Interfaces:**
- Consumes: step key `cbGrind` (Task 3).
- Produces: nothing new; changes the `macrotext` the existing secure button carries.

The route has exactly one button, `CallboardHunterRouteGo`, a `SecureActionButtonTemplate` with `type = "macro"` (`Route.lua:1170-1177`). Every action is a `macrotext`. A spell cast is legal from it because *the player's click* is the hardware event — CBH still never casts on its own.

**The grind is a two-action cycle on one button.** The spec asks for "summon a callboard quest, then port to Dalaran" repeating until 80, but `Route.Current` latches progress monotonically -- a repeating pair of steps would fight that latch, and the route has exactly one button anyway.

Resolve it by making the single `cbGrind` step's button **context-sensitive**, which is also what the cycle looks like in play:

- **Not in Dalaran** (you are out running the quest) -> the button ports you to Dalaran, via the existing `kind = "level"` behaviour.
- **In Dalaran** -> the button summons the board so you can take the next quest.

One step, one button, always the thing you need next. An unconditional summon override would make the port unreachable, because overriding the macrotext replaces what `Route.Act` would otherwise do -- that would strand you wherever the quest ended.

- [ ] **Step 1: Write the failing test**

```lua
W.zone = "Dalaran"
check("in Dalaran the button summons the board",
      string.find(Route.MacroFor("cbGrind") or "", "Summon Callboard", 1, true) ~= nil, true)
check("  ...as a cast, so the player's click is the hardware event",
      string.find(Route.MacroFor("cbGrind") or "", "/cast", 1, true) ~= nil, true)

W.zone = "Icecrown"
check("away from Dalaran it does NOT summon, so the port stays reachable",
      Route.MacroFor("cbGrind"), nil)

W.zone = "Dalaran"
check("a port step is never given the summon", Route.MacroFor("dala1"), nil)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd tools && node run_lua.js route_test.lua
```

Expected: FAIL — `Route.MacroFor` is nil.

- [ ] **Step 3: Write minimal implementation**

Add beside `Route.StepIndex`:

```lua
-- The macrotext a given step puts on the secure button. Factored out of Refresh
-- so the suite can assert what the button will actually do without building a
-- real frame -- and so the summon has exactly one definition.
function Route.MacroFor(key)
  local i = Route.StepIndex(key)
  if not i then return nil end
  local step = Route.Steps()[i]
  if step.key == "cbGrind" then
    -- The grind is a loop: come back to Dalaran, summon, take a quest, leave.
    -- One button serves both halves, so it follows where you are. Away from
    -- Dalaran the answer is nil, which lets Refresh build the normal port macro
    -- -- an unconditional summon would leave you no way back.
    local cp = Route.CP["DALARAN"]
    if cp and GetRealZoneText() == cp.zone then
      -- CBH never casts this itself; CastSpellByName is protected. It is on the
      -- secure button so that YOUR click is the hardware event that casts it.
      return "/cast Summon Callboard"
    end
    return nil
  end
  return nil -- every other step keeps whatever Refresh already builds
end
```

In `Route.Refresh`, where the current step's macrotext is set, prefer `Route.MacroFor` when it answers:

```lua
  local custom = Route.MacroFor(step.key)
  if custom then
    f.go:SetAttribute("macrotext", custom)
  else
    -- ...existing macrotext construction, unchanged...
  end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd tools && node run_lua.js route_test.lua && node run_all.js
```

- [ ] **Step 5: Commit**

```bash
git add Route.lua tools/route_test.lua
git commit -m "route: the grind step's button casts Summon Callboard"
```

---

### Task 5: Show the ash counter beside the tier

**Files:**
- Modify: `Route.lua` -- new `Route.AshCurrent`, and the panel header built in `Route.Refresh`
- Test: `tools/route_test.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `Route.AshCurrent() -> number|nil` -- ash collected this run, or nil.

The spec is explicit that this is **display only and nothing may depend on it**, for a substantive reason: what lets you hold a higher tier is your *permanent* tree investment, but the readable figure is this run's collected ash, near zero exactly when the grind tier is chosen. A threshold rule against it would be wrong in the same direction every run -- most restrictive when you are most powerful. Showing it settles, with real numbers watched across a prestige boundary, whether it tracks capability or just the run.

**Do not** wire it to tier selection. The spec puts that out of scope.

From the live dump, ash is a `FontString` under `ProjectEbonholdPlayerRunFrame`, comma-formatted and colour-coded -- `|cffffffff29,008|r` -- alongside an XP-looking `|cff00ff00+827%|r` that must not be mistaken for it.

- [ ] **Step 1: Write the failing test**

```lua
local function FakeAshFrame(...)
  local labels, regions = { ... }, {}
  for i, t in ipairs(labels) do
    regions[i] = { GetText = function() return t end,
                   GetObjectType = function() return "FontString" end }
  end
  local inner = { GetObjectType = function() return "Frame" end,
                  GetRegions = function() return unpack(regions) end,
                  GetChildren = function() return end,
                  IsShown = function() return true end }
  return { GetObjectType = function() return "Frame" end,
           GetRegions = function() return end,
           GetChildren = function() return inner end,
           IsShown = function() return true end }
end

_G.ProjectEbonholdPlayerRunFrame = FakeAshFrame("|cffffffff29,008|r", "|cff00ff00+827%|r")
check("reads ash through the colour code and comma", Route.AshCurrent(), 29008)

_G.ProjectEbonholdPlayerRunFrame = FakeAshFrame("|cff00ff00+827%|r")
check("a percentage is not ash", Route.AshCurrent(), nil)

_G.ProjectEbonholdPlayerRunFrame = nil
check("no run frame -> nil", Route.AshCurrent(), nil)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd tools && node run_lua.js route_test.lua
```

Expected: FAIL -- `Route.AshCurrent` is nil.

- [ ] **Step 3: Write minimal implementation**

```lua
-- Ash collected this run, off the same frame the tier comes from. DISPLAY ONLY,
-- deliberately: what decides whether you can hold a tier is PERMANENT tree
-- investment, while this figure is per-run and near zero exactly when the grind
-- tier gets picked. Shown so it can be watched across a prestige boundary before
-- anything is built on it.
function Route.AshCurrent()
  local root = _G["ProjectEbonholdPlayerRunFrame"]
  if not (root and root.GetChildren) then return nil end
  local found
  local function walk(f, depth)
    if found or depth > 4 then return end
    if f.GetRegions then
      for i = 1, select("#", f:GetRegions()) do
        local r = select(i, f:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == "FontString" then
          local plain = string.gsub(r:GetText() or "", "|c%x%x%x%x%x%x%x%x", "")
          plain = string.gsub(plain, "|r", "")
          -- A percent sign or a leading + marks the XP bonus, not ash.
          if not string.find(plain, "%%") and not string.find(plain, "^%s*%+") then
            local n = tonumber((string.gsub(plain, ",", "")))
            if n then found = n; return end
          end
        end
      end
    end
    if not f.GetChildren then return end
    for i = 1, select("#", f:GetChildren()) do
      local c = select(i, f:GetChildren())
      if c and not found then walk(c, depth + 1) end
    end
  end
  walk(root, 0)
  return found
end
```

In `Route.Refresh`, append it to the panel header, so an unreadable figure simply shows nothing:

```lua
  local ash = Route.AshCurrent()
  if ash then
    f.head:SetText(f.head:GetText() .. DIM .. "   ash " .. ash .. R)
  end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd tools && node run_lua.js route_test.lua && node run_all.js
```

- [ ] **Step 5: Commit**

```bash
git add Route.lua tools/route_test.lua
git commit -m "route: show ash collected beside the tier, display only"
```

---

### Task 6: Auto-start after a prestige reset

**Files:**
- Modify: `Route.lua` — event registration and a new `Route.MaybeAutoStart`
- Test: `tools/route_test.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Route.MaybeAutoStart() -> boolean` — true when it offered to start.

**Read this before writing code.** The spec deliberately leaves the trigger unresolved: nobody has dumped `ProjectEbonholdPlayerRunFrame` immediately after a prestige reset, so the exact signal is unknown. **Do not invent one.**

Implement the spec's stated fallback, which is safe without that observation:

> on login, if the route is not started and the character is below the Zul'Drak turn-in's level, offer to start it — a prompt, not an automatic start. Prompting on a false positive costs one dismissal; auto-starting on one would hijack a character mid-play.

If the controller supplies a confirmed reset signal, use it *in addition*. Otherwise ship the prompt and say so in your report.

- [ ] **Step 1: Write the failing test**

```lua
DB().acked = {}; DB().turnedIn = {}; DB().started = nil
W.level = 3
PRINTED = {}
check("offers on login at a low level with no route in progress",
      Route.MaybeAutoStart(), true)
check("  ...by prompting, not starting", DB().started, nil)
check("  ...and says how to start it",
      #PRINTED > 0 and string.find(PRINTED[1], "/cbh route") ~= nil, true)

DB().started = true
PRINTED = {}
check("does not nag once the route is under way", Route.MaybeAutoStart(), false)

DB().started = nil
W.level = 78
check("does not offer to a high-level character", Route.MaybeAutoStart(), false)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd tools && node run_lua.js route_test.lua
```

Expected: FAIL — `Route.MaybeAutoStart` is nil.

- [ ] **Step 3: Write minimal implementation**

```lua
-- Offer, never start. A prestige reset is not yet observable from anything CBH
-- can read -- the run frame has not been dumped immediately after one -- so this
-- infers "fresh run" from a low level with no route in progress. That inference
-- WILL sometimes be wrong (an alt, a friend's character), which is exactly why
-- it prompts: a wrong prompt costs one dismissal, a wrong auto-start hijacks
-- someone's session.
function Route.MaybeAutoStart()
  local d = DB()
  if d.started then return false end
  if d.autoStartOff then return false end
  if (UnitLevel("player") or 80) > 10 then return false end
  CBH.print("Fresh run? " .. BRIGHT .. "/cbh route" .. R
    .. " opens the lap. " .. DIM .. "/cbh route autostart off" .. R .. " silences this.")
  return true
end
```

Call it from the existing `PLAYER_ENTERING_WORLD` handler in `Route.lua`. If the file has no such handler, register one beside the other route events rather than adding a new frame.

Add the opt-out to the route's slash handling, beside `hc` and `grind`:

```lua
  elseif sub == "autostart" then
    DB().autoStartOff = (rest == "off") or nil
    CBH.print("Route auto-start prompt: " .. ((rest == "off") and "off" or "on"))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd tools && node run_lua.js route_test.lua && node run_all.js
```

- [ ] **Step 5: Commit**

```bash
git add Route.lua tools/route_test.lua
git commit -m "route: offer to start a fresh lap instead of auto-starting one"
```

---

### Task 7: Docs and release

**Files:**
- Modify: `CallboardHunter.toc`, `CHANGELOG.md`, `README.md`
- Test: full suite

- [ ] **Step 1: Bump the version**

In `CallboardHunter.toc`, set `## Version: 1.12.0`. This is a feature release: the route's tail changed and the hardcore step behaves differently.

- [ ] **Step 2: Document the commands**

Add to `README.md`'s command table:

```
| `/cbh route hc grind <n>` | tier to hold during the callboard grind |
| `/cbh route autostart off` | stop offering to start a lap on login |
```

- [ ] **Step 3: Write the changelog**

Add a `## [1.12.0]` section above `## [1.11.1]` covering, under `### Changed`: the zone grind replaced by a callboard grind that runs from wherever the Zul'Drak turn-in leaves you to 80, since ash XP nodes move that landing level; and the hardcore step now clicking the server's own tier control and verifying the tier actually changed, instead of asking you to tick a box. Under `### Added`: the grind-tier setting, and the login prompt.

State plainly that the old *"No API for this"* note was wrong — the tier is a button on `ProjectEbonholdPlayerRunFrame`, found by dumping the frame.

- [ ] **Step 4: Run everything**

```bash
cd tools && node run_all.js
node tools/luacheck.js .
```

Expected: 14 suites green, `dungeon_test.lua` at exactly 37, luacheck clean.

- [ ] **Step 5: Commit**

```bash
git add CallboardHunter.toc CHANGELOG.md README.md
git commit -m "v1.12.0: callboard grind phase and a real hardcore switch"
```

**Do not push, tag, or publish a release.** Those are the maintainer's decisions and are handled outside this plan.
