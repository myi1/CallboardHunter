-- Callboards summoned inside instances must never be remembered as destinations.
local ADDON = ADDON_DIR
function GetMapContinents() return "Northrend" end
function GetMapZones() return "Dragonblight", "Icecrown", "Howling Fjord", "Dalaran" end
-- Core.lua REASSIGNS the CallboardHunter global at load, so it must be loaded
-- before anything caches a reference to it.
function CreateFrame() local f = {} setmetatable(f, {__index=function() return function() end end}) return f end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
function IsInInstance() return INSIDE end
function GetPlayerMapPosition() return 0.5, 0.5 end
function SetMapToCurrentZone() end
function GetRealZoneText() return ZONE or "Dragonblight" end
function GetTime() return 0 end
_G.time = os.time; _G.date = os.date

local c = loadfile(ADDON .. "/Core.lua"); c()
local CBH = CallboardHunter
c = loadfile(ADDON .. "/SpawnDB.lua"); c()
PRINTED = {}
function CBH.print(m) PRINTED[#PRINTED + 1] = tostring(m) end
CBH.db = { learned = {}, callboards = {}, options = {} }

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label, tostring(got),
      ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end

print("== which zones can Port: Callboard return you to? ==")
check("a real outdoor zone", CBH.IsPortableCallboardZone("Dragonblight"), true)
check("Halls of Stone (instance)", CBH.IsPortableCallboardZone("Halls of Stone"), false)
check("Naxxramas (instance)", CBH.IsPortableCallboardZone("Naxxramas"), false)
check("Ahn'kahet: The Old Kingdom", CBH.IsPortableCallboardZone("Ahn'kahet: The Old Kingdom"), false)
check("The Obsidian Sanctum", CBH.IsPortableCallboardZone("The Obsidian Sanctum"), false)
check("nil", CBH.IsPortableCallboardZone(nil), false)
check("empty", CBH.IsPortableCallboardZone(""), false)

print("")
print("== the one-time purge drops exactly the unreachable ones ==")
CBH.db.callboards = {
   { zone = "Dragonblight", x = 0.5, y = 0.5 },
   { zone = "Naxxramas", x = 0.4, y = 0.4 },
   { zone = "Dalaran", x = 0.3, y = 0.3 },
   { zone = "The Obsidian Sanctum", x = 0.2, y = 0.2 },
   { zone = "Halls of Stone", x = 0.1, y = 0.1 },
}
CBH.db.purgedInstanceBoards = nil
PRINTED = {}
CBH.PurgeUnreachableCallboards()
check("kept only the reachable", #CBH.db.callboards, 2)
check("  first is Dragonblight", CBH.db.callboards[1].zone, "Dragonblight")
check("  second is Dalaran", CBH.db.callboards[2].zone, "Dalaran")
check("told the player", string.find(PRINTED[1] or "", "Forgot 3") ~= nil, true)

print("")
print("== the purge runs once, not every login ==")
CBH.db.callboards[#CBH.db.callboards + 1] = { zone = "Naxxramas", x = 0, y = 0 }
PRINTED = {}
CBH.PurgeUnreachableCallboards()
check("second run is a no-op", #CBH.db.callboards, 3)
check("  ...and says nothing", #PRINTED, 0)

print("")
print("== setting home inside an instance is refused ==")
INSIDE = true
PRINTED = {}
check("refused", CBH.SetHomeHere(), false)
check("  ...with a reason", string.find(PRINTED[1] or "", "instance") ~= nil, true)

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end
