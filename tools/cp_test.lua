-- Checkpoint harness: harvesting, id validation, and the Argent Stand
-- prerequisite block. These are the parts that guard against the route's
-- hardcoded checkpoint numbers being wrong on this server.

-- Run from this folder:  node run_lua.js route_test.lua
local ROUTE = os.getenv("CBH_ROUTE") or "../Route.lua"

local W = { zone = "Dalaran", level = 80, runAsh = 0, now = 1000 }
local out = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) out[#out + 1] = m end }
function GetTime() W.now = W.now + 1; return W.now end
time = os.time; date = os.date
function GetRealZoneText() return W.zone end
function UnitLevel() return W.level end
function UnitName() return "NPC" end
function GetTitleText() return nil end
function SetMapToCurrentZone() end
function GetPlayerMapPosition() return 0.5, 0.5 end
function InCombatLockdown() return false end
function GetSpellName() return nil end
BOOKTYPE_SPELL = "spell"
function GetNumQuestLogEntries() return 0, 0 end
function GetQuestLogTitle() return nil end
function ExpandQuestHeader() end
function CollapseQuestHeader() end

local function MockFrame(name, children)
  local f = { _name = name, _shown = false, _scripts = {}, _kids = children or {} }
  function f:Show() self._shown = true
    if self._scripts.OnShow then self._scripts.OnShow(self) end end
  function f:Hide() self._shown = false end
  function f:IsShown() return self._shown end
  function f:SetScript(k, fn) self._scripts[k] = fn end
  function f:HookScript(k, fn) self._scripts[k] = fn end
  function f:SetText(t) self._text = t end
  function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
  function f:GetChildren() return (unpack or table.unpack)(self._kids) end
  function f:CreateFontString() return MockFrame(name .. ".fs") end
  setmetatable(f, { __index = function(t, k)
    local noop = function() return nil end
    rawset(t, k, noop); return noop
  end })
  return f
end

-- Three checkpoint buttons as the server draws them: id, name, unlocked.
local function CpButton(id, nodeName, unlocked)
  local b = MockFrame("cp" .. id)
  rawset(b, "checkpointId", id)
  rawset(b, "nodeName", nodeName)
  rawset(b, "isUnlocked", unlocked)
  return b
end

UIParent = MockFrame("UIParent")
WorldMapButton = MockFrame("WorldMapButton")
WorldMapFrame = MockFrame("WorldMapFrame", {
  CpButton(310, "Dalaran", true),
  CpButton(304, "The Argent Stand", false), -- locked: the route's prerequisite
  CpButton(296, "Unu'pe", true),
  CpButton(999, "Somewhere Else", true),
})
function CreateFrame(_, name) return MockFrame(name or "anon") end

EbonholdPlayerRunData = { soulPoints = 0 }

-- --------------------------------------------------------- load the module
-- Route.lua expects the CallboardHunter namespace and its shared helpers, so
-- stand up just enough of Core.lua rather than dofile'ing the whole addon.
CallboardHunter = {
  Route = {},
  Arrow = {},
  Advisor = {},
  db = { options = {}, route = {} },
}
local CBH = CallboardHunter
function CBH.print(m) out[#out + 1] = "CBH: " .. tostring(m) end
-- Surface errors instead of swallowing them: the real safeCall prints and moves
-- on, which is right in-game and useless in a test.
function CBH.safeCall(fn, ...)
  if not fn then return end
  local ok, err = pcall(fn, ...)
  if not ok then error("safeCall: " .. tostring(err), 0) end
end

dofile(ROUTE)
local RT = CallboardHunter.Route

local fails, checks = 0, 0
local function check(cond, label, detail)
  checks = checks + 1
  if cond then print("  ok   " .. label)
  else fails = fails + 1; print("  FAIL " .. label .. "  " .. tostring(detail)) end
end

print("PrestigeRoute checkpoints")
RT.Build(); RT.BuildMini()
RT.SetMode(false) -- assertions below read the full panel's note line

local n = RT.CpScan(false)
check(n == 4, "harvested every checkpoint button", n)
check(RT.CpCount() == 4, "all four cached", RT.CpCount())

local dala = RT.CpInfo("DALARAN")
check(dala.known and dala.name == "Dalaran", "310 resolves to Dalaran", dala.name)
check(dala.matches == true, "310 name matches the expected zone", dala.matches)
check(dala.unlocked == true, "310 reads unlocked", dala.unlocked)

local zd = RT.CpInfo("ZULDRAK")
check(zd.known and zd.unlocked == false, "304 reads LOCKED", zd.unlocked)

local bt = RT.CpInfo("BOREAN")
check(bt.name == "Unu'pe", "296 resolves to Unu'pe", bt.name)

-- Porting to a locked checkpoint must refuse rather than fire the request.
out = {}
local ok = RT.PortTo("ZULDRAK")
check(ok == false, "port to a locked checkpoint refuses", ok)
check(#out > 0 and string.find(out[1], "LOCKED", 1, true) ~= nil,
  "and says why", out[1])

-- A locked 304 must BLOCK the Zul'Drak step, not merely mark it pending.
-- Walk the route to that step first.
local d = CallboardHunter.db.route
d.acked = { hcStart = true }
d.turnedIn = {}
for _, t in ipairs({ "Preparations for War",
                     "Learning to Leave and Return: The Magical Way",
                     "The Champion's Call!" }) do
  d.turnedIn[RT.NormTitle(t)] = true
end
local cur = RT.Current()
check(RT.Steps()[cur].key == "zd", "route sits on the Zul'Drak port", RT.Steps()[cur].key)

RT.Refresh()
local note = RT.panel.note._text or ""
check(string.find(note, "BLOCKED", 1, true) ~= nil,
  "panel shows the step as BLOCKED", note)
check(string.find(note, "Argent Stand", 1, true) ~= nil,
  "and names the missing flight path", note)

-- Now unlock it and confirm the block clears.
rawset(WorldMapFrame._kids[2], "isUnlocked", true)
RT.CpScan(false)
RT.Refresh()
note = RT.panel.note._text or ""
check(string.find(note, "BLOCKED", 1, true) == nil, "unlocking clears the block", note)

-- A renumbered server checkpoint must be flagged, not silently trusted.
rawset(WorldMapFrame._kids[1], "nodeName", "Booty Bay")
RT.CpScan(false)
local mis = RT.CpInfo("DALARAN")
check(mis.matches == false, "310 pointing elsewhere flags a mismatch", mis.matches)

RT.Api(); RT.ListCheckpoints(); RT.Macros()
print(string.format("\n%d checks, %d failed", checks, fails))
if fails > 0 then os.exit(1) end
