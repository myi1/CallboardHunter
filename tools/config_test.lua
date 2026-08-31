-- Executes the REAL Config.lua (over the REAL UI.lua, SpawnDB.lua and
-- Favourites.lua) against stubbed WoW frame APIs.
--
-- Why this file exists: nothing else in this suite ever loads Config.lua, and
-- luacheck.js is a bare luaparse.parse syntax check with no scope/undefined-
-- global analysis. That gap is exactly how Config.lua shipped three releases
-- (1.10.0-1.10.2) reading bare UI.xxx with no `local UI` ever bound to it -
-- every addon file is its own Lua chunk (no build step concatenates them), so
-- UI.lua's own `local UI` never reached this file, and /cbh config would have
-- thrown "attempt to index a nil value (global 'UI')" on its first line. Every
-- suite stayed green the whole time. This file exists so that class of bug
-- fails a suite instead of shipping silently again.
local ADDON = ADDON_DIR

-- ---- fake widget tree --------------------------------------------------
-- A generic mock, not a per-widget-type one: Config.lua drives CreateFrame,
-- CheckButton, ScrollFrame, EditBox and plain buttons, and calls dozens of
-- WoW frame methods (SetPoint, SetBackdrop, EnableMouse, ...) purely for
-- layout - none of that changes behaviour under test, so unknown methods
-- fall back to a cached noop via __index rather than being hand-stubbed one
-- by one (same approach as cp_test.lua's MockFrame).
local ALL_FRAMES = {}
local function MockFrame(name)
   local f = { _shown = false, _scripts = {}, _text = "" }
   function f:Show() self._shown = true end
   function f:Hide() self._shown = false end
   function f:IsShown() return self._shown end
   function f:SetScript(k, fn) self._scripts[k] = fn end
   function f:Click(k) if self._scripts[k or "OnClick"] then self._scripts[k or "OnClick"](self) end end
   function f:SetText(t) self._text = t end
   function f:GetText() return self._text end
   function f:SetChecked(v) self._checked = v end
   function f:GetChecked() return self._checked end
   function f:CreateFontString() local fs = MockFrame("fs"); ALL_FRAMES[#ALL_FRAMES + 1] = fs; return fs end
   function f:CreateTexture() local t = MockFrame("tex"); ALL_FRAMES[#ALL_FRAMES + 1] = t; return t end
   setmetatable(f, { __index = function(t, k)
      local noop = function() return nil end
      rawset(t, k, noop); return noop
   end })
   return f
end
function CreateFrame(_, name, _parent, template)
   local f = MockFrame(name or "anon")
   if name then _G[name] = f end
   -- UICheckButtonTemplate normally spawns a child FontString the game names
   -- "<name>Text"; MakeCheck (Config.lua) looks it up by that name and calls
   -- t:SetText(...) unconditionally, so without this a DISPLAY checkbox would
   -- crash on a nil index before OpenConfig ever reaches the code under test.
   if template == "UICheckButtonTemplate" and name then
      _G[name .. "Text"] = MockFrame(name .. "Text")
   end
   ALL_FRAMES[#ALL_FRAMES + 1] = f
   return f
end
UIParent = MockFrame("UIParent")

CallboardHunter = { SpawnDB = {} }
local CBH = CallboardHunter
function CBH.print() end

local function load(f) local c, e = loadfile(ADDON .. "/" .. f); if not c then error(e) end; c() end
load("UI.lua"); load("SpawnDB.lua"); load("Favourites.lua"); load("Config.lua")
local Fav = CBH.Favourites
local HEX = CBH.UI.HEX

CBH.db = { options = { arrow = true, sound = true, partyAnnounce = false },
           checkpointBlock = {}, cardCatalogue = {}, favourites = {} }

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label, tostring(got),
      ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end

-- A favourites row is `CreateFrame("Button", nil, panel.favContent)` - it has
-- no name, so it never lands in _G. Find one by the target substring in its
-- own .text field. rawget, not f.text: the mock's __index auto-vivifies ANY
-- missing key as a noop function and caches it, so a plain f.text on a frame
-- that never got a real .text field would silently return a function, not
-- nil, and this would misreport "found" for every frame in the tree.
local function findRow(target)
   for _, f in ipairs(ALL_FRAMES) do
      local txt, band = rawget(f, "text"), rawget(f, "band")
      if txt and type(txt) == "table" and band then
         local t = txt:GetText()
         if t and string.find(t, target, 1, true) then return f end
      end
   end
   return nil
end

print("== the panel actually builds ==")
-- The regression guard: an unbound global (this bug's exact shape) raises
-- inside UI.Skin, the first UI call in OpenConfig, so merely completing
-- without error IS the assertion.
local ok, err = pcall(CBH.OpenConfig)
check("OpenConfig ran without error", ok, true)
if not ok then print("  error: " .. tostring(err)) end

local panel = _G.CallboardHunterConfig
check("panel was created and named, as every other addon frame is", panel ~= nil, true)

print("")
print("== a favourites row: bundled data, level band, toggle round-trip ==")
-- Loken (SpawnDB.lua) is lo == hi == 80, so this doubles as the "single
-- level" BandText case the review asked to cover explicitly.
local loken = findRow("Loken")
check("found Loken in the pickable list", loken ~= nil, true)
if loken then
   check("starts unfavourited: hollow bracket", string.find(loken.text:GetText(), "[ ]", 1, true) ~= nil, true)
   check("band shows the single level, not a range", loken.band:GetText(), "[80]")
   check("off glyph uses the dark-surface 'muted' colour",
      string.find(loken.text:GetText(), "|cff" .. HEX.muted, 1, true) ~= nil, true)
   check("off glyph does NOT use the card-ground 'inkSoft' colour (the trap)",
      string.find(loken.text:GetText(), "|cff" .. HEX.inkSoft, 1, true) ~= nil, false)

   loken:Click()
   check("click toggled the underlying favourite", Fav.IsFavourite("Loken"), true)
   CBH.RefreshConfig()
   check("row shows a filled bracket after refresh", string.find(loken.text:GetText(), "[*]", 1, true) ~= nil, true)
   check("on glyph uses the dark-surface 'verdigris' colour",
      string.find(loken.text:GetText(), "|cff" .. HEX.verdigris, 1, true) ~= nil, true)
   check("on glyph does NOT use the card-ground 'brassInk' colour (the trap)",
      string.find(loken.text:GetText(), "|cff" .. HEX.brassInk, 1, true) ~= nil, false)

   loken:Click()
   CBH.RefreshConfig()
   check("toggling again reverts it", Fav.IsFavourite("Loken"), false)
end
CBH.db.favourites = {}

print("")
print("== BandText's other two shapes: a real range, and no data at all ==")
-- Adamantite Bar (SpawnDB.lua) is lo=67, hi=69 - the "[lo-hi]" range branch,
-- which Loken's single-level case above does not exercise.
local ore = findRow("Adamantite Bar")
check("found a range-banded target", ore ~= nil, true)
if ore then check("band shows the full range", ore.band:GetText(), "[67-69]") end

-- A catalogue-only entry the game never tagged with a level (meta.lo/hi both
-- nil) must not crash BandText or print the word "nil" into the panel.
CBH.db.cardCatalogue["Wanted: Zzyzx the Untagged"] = {}
CBH.RefreshConfig()
local untagged = findRow("Zzyzx the Untagged")
check("a never-leveled catalogue entry still appears", untagged ~= nil, true)
if untagged then check("its band is blank, not \"nil\"", untagged.band:GetText(), "") end
CBH.db.cardCatalogue = {}

print("")
print("== an empty pickable list: the panel does not stay stuck on old rows ==")
-- Fav.List() in real play is never actually empty (SpawnDB.QUESTS ships 63
-- rows), so hitting the #favList == 0 branch at all requires clearing the
-- bundled table for this one check, restored immediately after.
local savedQuests = CBH.SpawnDB.QUESTS
CBH.SpawnDB.QUESTS = {}
CBH.RefreshConfig()
check("the (none) label shows once the list is empty", panel.favEmpty:IsShown(), true)
if loken then check("the old Loken row is hidden, not left showing stale data", loken:IsShown(), false) end

CBH.SpawnDB.QUESTS = savedQuests
CBH.RefreshConfig()
check("the (none) label hides again once data comes back", panel.favEmpty:IsShown(), false)
if loken then check("the pool recovers: Loken's row is visible again", loken:IsShown(), true) end

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end
