-- Reproduces the Ragemane report against the REAL Advisor.lua: a Zul'Drak quest
-- that names no zone in its text, while the player stands in Dragonblight.
local ADDON = ADDON_DIR

local function stubFrame()
   local f = {}; setmetatable(f, { __index = function() return function() end end }); return f
end
function CreateFrame() return stubFrame() end
WorldMapFrame = stubFrame()
_G.time = os.time; _G.date = os.date
function GetTime() return 0 end
function GetRealZoneText() return CURRENT_ZONE or "Dragonblight" end
function GetSubZoneText() return "" end
function GetNumQuestWatches() return 0 end
function GetQuestIndexForWatch() return nil end
function QuestPOIGetIconInfo() return nil end
function GetNumPartyMembers() return 0 end
function SendChatMessage() end
function SetMapToCurrentZone() end
function GetPlayerMapPosition() return 0, 0 end

-- Continent/zone lists, so KnownMapZone can validate headers.
MAPSET = nil
function ShowUIPanel() end
function InCombatLockdown() return false end
function UnitCastingInfo() return nil end
function SetMapZoom() end
WorldMapFrame = { IsShown = function() return true end }
function GetMapContinents() return "Eastern Kingdoms", "Kalimdor", "Outland", "Northrend" end
function GetMapZones(c)
   if c == 4 then
      return "Borean Tundra", "Dragonblight", "Grizzly Hills", "Howling Fjord",
             "Icecrown", "Sholazar Basin", "The Storm Peaks", "Zul'Drak", "Wintergrasp",
             "Crystalsong Forest", "Dalaran"
   elseif c == 2 then
      return "Winterspring", "Nagrand"
   end
   return "Alterac Mountains", "Western Plaguelands", "Stormwind", "Stormwind City"
end

-- Quest log WITH headers, exactly how WoW groups it.
QUESTLOG = {}
function GetNumQuestLogEntries() return #QUESTLOG end
function GetQuestLogTitle(i)
   local q = QUESTLOG[i]
   if not q then return nil end
   return q.title, 80, nil, nil, q.header or false, false, false, false, 7000 + i
end
function GetNumQuestLeaderBoards(i)
   local q = QUESTLOG[i]; return (q and q.objectives) and #q.objectives or 0
end
function GetQuestLogLeaderBoard(j, i)
   local q = QUESTLOG[i]; return q and q.objectives and q.objectives[j], "monster", false
end

DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
local function load(f)
   local c, e = loadfile(ADDON .. "/" .. f)
   if not c then error("load " .. f .. ": " .. tostring(e)) end
   c()
end
-- Real load order. Core.lua REASSIGNS the CallboardHunter global and owns the
-- callboard-only predicates, so it has to come first.
load("Core.lua")
local CBH = CallboardHunter
CBH.db = { options = {}, learned = {}, learnedKills = {}, cardZones = {},
           cardZoneVerified = {}, cardCatalogue = {}, callboards = {},
           portOverrides = {}, checkpointBlock = {}, log = {} }
-- This suite exercises ZONE RESOLUTION; the callboard-only filter is a separate
-- concern with its own section below, so keep it off for the rest.
CBH.db.options.callboardOnly = false
function CBH.print(m) if VERBOSE then print("   [cbh] " .. tostring(m)) end end
function CBH.safeCall(fn, ...) if fn then fn(...) end end
function CBH.Log() end
function CBH.IsBlockedCheckpoint() return false end
function CBH.GetQuestPOI() return nil end
function CBH.PlayerZonePos() return nil end
-- UI.lua is loaded because BuildNote (the card-zone harvester under test
-- below) stamps its note through CBH.UI.Stamp/Colour, same as fav_test.lua
-- needs it for Fav.Command's printed rows.
load("SpawnDB.lua"); load("UI.lua"); load("QuestWatcher.lua"); load("Advisor.lua")
function CBH.Arrow.Refresh() end
function CBH.Arrow.GetTargetXY() return nil end
local QW, Advisor = CBH.QuestWatcher, CBH.Advisor

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label,
      tostring(got), ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end

print("== the reported bug: Ragemane, standing in Dragonblight ==")
CURRENT_ZONE = "Dragonblight"
QUESTLOG = {
   { title = "Dragonblight", header = true },
   { title = "The Heroic Key to the Focusing Iris", objectives = { "In progress" } },
   { title = "Zul'Drak", header = true },
   { title = "Bring Me the Head of Ragemane", objectives = { "Ragemane slain: 0/1" } },
}
QW.Update(true)
check("header resolves the zone", Advisor.ZoneFromQuestHeader(4), "Zul'Drak")
local dest = Advisor.ResolveDestination()
check("routes to Zul'Drak (not Dragonblight)", dest, "Zul'Drak")

print("\n== header is used even with the map/POI sweep enabled ==")
local dest2 = Advisor.ResolveDestination(nil, true)
check("still Zul'Drak with sweep allowed", dest2, "Zul'Drak")

print("\n== non-zone headers are ignored, not trusted blindly ==")
QUESTLOG = {
   { title = "Dungeons", header = true },
   { title = "Some Server Quest", objectives = { "Whatsit slain: 0/1" } },
}
QW.Update(true)
check("'Dungeons' header rejected", Advisor.ZoneFromQuestHeader(2), nil)
check("unresolvable -> nil (Port declines)", Advisor.ResolveDestination(), nil)

print("\n== curated entries still outrank the header ==")
-- Flame Revenant's header says Winterspring, but it must route to the
-- Fordragon Hold checkpoint on the Dragonblight map.
CURRENT_ZONE = "Icecrown"
QUESTLOG = {
   { title = "Winterspring", header = true },
   { title = "Thinning the Herd in Winterspring", objectives = { "Flame Revenant slain: 0/10" } },
}
QW.Update(true)
check("header would say Winterspring", Advisor.ZoneFromQuestHeader(2), "Winterspring")
local d3, _, _, _, via = Advisor.ResolveDestination()
check("curated override wins", d3, "Dragonblight")
check("  ...with its checkpoint", via, "Fordragon Hold")

print("\n== explicit zone in the text still wins over the header ==")
QUESTLOG = {
   { title = "Dragonblight", header = true },   -- deliberately WRONG header
   { title = "Cull the herd in Sholazar Basin", objectives = { "Mammoth slain: 0/6" } },
}
QW.Update(true)
check("text beats header", Advisor.ResolveDestination(), "Sholazar Basin")

print("")
print("== 'Beast Kill in Howling Fjord: 0/75' (reported 2026-08-29) ==")
CURRENT_ZONE = "Outland"
QUESTLOG = {
   { title = "Howling Fjord", header = true },
   { title = "Fjord Stalkers", objectives = { "Beast Kill in Howling Fjord: 0/75" } },
}
QW.Update(true)
check("objective is registered at all", CBH.killObjectives["Beast Kill in Howling Fjord"] ~= nil, true)
check("  progress parsed", CBH.killObjectives["Beast Kill in Howling Fjord"].need, 75)
check("routes to Howling Fjord (not Home)", Advisor.ResolveDestination(), "Howling Fjord")

print("")
print("== objectives with no locatable zone are NOT claimed ==")
-- These sit in the same quest log (ICC / SI:7). CBH can't travel to them, so it
-- must not register them and pretend the Port button has somewhere to go.
QUESTLOG = {
   { title = "Icecrown", header = true },
   { title = "The Sacred and the Corrupt", objectives = {
        "Light's Vengeance: 0/1", "Primordial Saronite: 0/25" } },
   { title = "The Eastern Plagues", objectives = { "SI:7 Insignia (Rutger): 0/1" } },
}
QW.Update(true)
check("collection objective ignored", CBH.killObjectives["Primordial Saronite"], nil)
check("quest-item objective ignored", CBH.killObjectives["Light's Vengeance"], nil)
check("colon-in-label objective ignored", CBH.killObjectives["SI:7 Insignia (Rutger)"], nil)

print("")
print("== a completed zone objective doesn't keep routing ==")
QUESTLOG = {
   { title = "Howling Fjord", header = true },
   { title = "Fjord Stalkers", objectives = { "Beast Kill in Howling Fjord: 75/75" } },
}
QW.Update(true)
check("registered but complete", CBH.killObjectives["Beast Kill in Howling Fjord"].have, 75)
check("finished -> no destination", Advisor.ResolveDestination(), nil)

print("")
print("== zones with no bundled spawn data (reported 2026-08-29) ==")
CURRENT_ZONE = "Dalaran"
QUESTLOG = {
   { title = "Wintergrasp", header = true },
   { title = "Southern Sabotage", objectives = { "Beast Kill in Wintergrasp: 0/10" } },
}
QW.Update(true)
check("Wintergrasp objective registered", CBH.killObjectives["Beast Kill in Wintergrasp"] ~= nil, true)
check("routes to Wintergrasp, NOT Winterspring", Advisor.ResolveDestination(), "Wintergrasp")

QUESTLOG = {
   { title = "Crystalsong Forest", header = true },
   { title = "Gathering the Shards", objectives = { "Azure Manashaper slain in Crystalsong Forest: 0/10" } },
}
QW.Update(true)
check("Crystalsong (no spawn data) resolves", Advisor.ResolveDestination(), "Crystalsong Forest")

print("")
print("== BuildNote harvests card zones (reported 2026-08-31) ==")
-- The actual reported card, verbatim, has no verb at all: "10 Earthbound
-- Revenant in Wintergrasp". The original pattern required a literal "Kill "
-- prefix, so this never matched and cardZones never learned Wintergrasp for
-- that objective - see the end-to-end reproduction further down.
CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}
Advisor.BuildNote("10 Earthbound Revenant in Wintergrasp")
check("verb-less card, no period", CBH.db.cardZones["Earthbound Revenant"], "Wintergrasp")
check("  ...marked verified", CBH.db.cardZoneVerified["Earthbound Revenant"], true)

CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}
Advisor.BuildNote("10 Earthbound Revenant in Wintergrasp.")
check("verb-less card, with period", CBH.db.cardZones["Earthbound Revenant"], "Wintergrasp")

CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}
Advisor.BuildNote("Kill 10 Azure Manashaper in Crystalsong Forest.")
check("the original 'Kill N X in Zone.' shape still learns",
   CBH.db.cardZones["Azure Manashaper"], "Crystalsong Forest")

CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}
Advisor.BuildNote("Slay 10 Earthbound Revenant in Wintergrasp.")
check("a leading 'Slay' also learns", CBH.db.cardZones["Earthbound Revenant"], "Wintergrasp")

-- "in" is an everyday word - a non-kill card can contain it without naming a
-- zone at all. The trailing text must be an EXACT real map zone before it is
-- trusted, or this would harvest "the Nexus" as if it were one.
CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}
Advisor.BuildNote("5 Frozen Orb in the Nexus")
check("fake trailing zone -> nothing written (KnownMapZone guard)",
   CBH.db.cardZones["Frozen Orb"], nil)
Advisor.BuildNote("Collect 5 Frozen Orb in the Nexus")
check("  ...the verbed 'Collect' form doesn't harvest a zone either",
   CBH.db.cardZones["Frozen Orb"], nil)

-- A failed KnownMapZone check must refuse only the WRITE, not the note: a
-- real dungeon/raid card ("Naxxramas" is not an outdoor map zone, so the
-- count-card branch above correctly declines it) still has to fall through
-- to the "Slay <boss> in <place>" branch below it, or the correct
-- "Dungeon/raid:" note silently disappears along with the write.
CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}
check("dungeon count-card falls through to the boss/raid note",
   Advisor.BuildNote("Slay 10 Scourge in Naxxramas."),
   CBH.UI.Colour("inkSoft", "Dungeon/raid: Naxxramas"))
check("  ...and still writes nothing to cardZones",
   CBH.db.cardZones["Scourge"], nil)
-- Same shape, "Kill" instead of "Slay": no boss/Collect/rare branch matches a
-- "Kill N X in Dungeon." card, so this one falls all the way through to no
-- note at all - correct, since CBH has nothing useful to say about it, and
-- confirms the fallthrough doesn't fabricate a note for a shape nothing
-- recognises.
check("dungeon count-card with no matching fallback note -> nil",
   Advisor.BuildNote("Kill 10 Murloc in Utgarde Keep."), nil)
check("  ...and still writes nothing to cardZones", CBH.db.cardZones["Murloc"], nil)

-- Rare-hunt cards are checked BEFORE the count-card patterns: "Icecrown" is a
-- real map zone, so "3 Rare creatures in Icecrown" also fits the verb-less
-- "<n> <mob> in <zone>" shape and would otherwise be swallowed as a kill
-- objective - writing the nonsense mob key "Rare creatures" into cardZones
-- and showing "no camp data" instead of the rare stamp. Pinned here so this
-- specific priority inversion cannot regress again.
CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}
check("a rare-hunt card is not mistaken for a kill objective",
   Advisor.BuildNote("3 Rare creatures in Icecrown"),
   CBH.UI.Stamp("active", true) .. " " .. CBH.UI.Colour("ink", "rare hunt"))
check("  ...and doesn't pollute cardZones",
   CBH.db.cardZones["Rare creatures"], nil)
CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}

print("")
print("== card zone outranks a mislabelled header (reported 2026-08-31) ==")
-- The actual user report: v1.10.2, a brand-new install (no learned kills), a
-- card reading "10 Earthbound Revenant in Wintergrasp" but the quest log
-- files "Population Management: Earthbound Revenant" under a "Winterspring"
-- header - Wintergrasp (Northrend) and Winterspring (Kalimdor) share nothing
-- but a spelling coincidence. Neither the quest title nor its objective names
-- any zone, so with no card seen yet and no kill history, resolution used to
-- fall straight through to the header and teleport across the world.
CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}
CBH.db.learnedKills = {}
CURRENT_ZONE = "Dalaran"
QUESTLOG = {
   { title = "Winterspring", header = true },
   { title = "Population Management: Earthbound Revenant",
     objectives = { "Earthbound Revenant slain: 0/10" } },
}
QW.Update(true)
check("the header alone would say Winterspring", Advisor.ZoneFromQuestHeader(2), "Winterspring")
check("before the card is ever seen, the header decides (wrongly)",
   Advisor.ResolveDestination(), "Winterspring")
-- Simulate the callboard card being on screen, exactly as BuildNote sees it.
Advisor.BuildNote("10 Earthbound Revenant in Wintergrasp")
check("THE BUG: routes to Wintergrasp, not Winterspring",
   Advisor.ResolveDestination(), "Wintergrasp")
CBH.db.cardZones, CBH.db.cardZoneVerified = {}, {}

print("")
print("== curated override still beats the general zone scan ==")
-- "Thinning the Herd in Winterspring" names a real map zone now that the general
-- scan exists. It must STILL route to Fordragon Hold, not to Winterspring.
CURRENT_ZONE = "Icecrown"
QUESTLOG = {
   { title = "Winterspring", header = true },
   { title = "Thinning the Herd in Winterspring", objectives = { "Flame Revenant slain: 0/10" } },
}
QW.Update(true)
local wd, _, _, _, wvia = Advisor.ResolveDestination()
check("still Dragonblight", wd, "Dragonblight")
check("  ...still Fordragon Hold", wvia, "Fordragon Hold")

print("")
print("== longest zone name wins (no partial-name shadowing) ==")
check("Stormwind City beats Stormwind", CBH.SpawnDB.FindMapZoneIn("Kill 5 rats in Stormwind City"), "Stormwind City")
check("bare Stormwind still matches", CBH.SpawnDB.FindMapZoneIn("Kill 5 rats in Stormwind"), "Stormwind")
check("no zone -> nil", CBH.SpawnDB.FindMapZoneIn("Collect 5 apples"), nil)

print("")
print("== objectives outrank the title (reported by xMetaMorph, v1.11.0 fresh install) ==")
-- The server stamps every card title with a "<Zone>:" category prefix, not a
-- location - "Winterspring: Whispering Wind" hands out an objective that
-- plainly reads "in Wintergrasp." Scanning the title first (the old order)
-- returned Winterspring on a fresh install with no kill history to override
-- it. This pins that a real zone found in an OBJECTIVE outranks one found in
-- the TITLE - the same "title can be wrong" principle ZoneFromLearnedKills
-- already applies to kills, now applied inside this source itself.
QUESTLOG = {
   { title = "Winterspring: Whispering Wind", objectives = { "Whispering Wind in Wintergrasp." } },
}
QW.Update(true)
check("title alone would say Winterspring",
   CBH.SpawnDB.FindMapZoneIn("Winterspring: Whispering Wind"), "Winterspring")
check("objective alone says Wintergrasp",
   CBH.SpawnDB.FindMapZoneIn("Whispering Wind in Wintergrasp."), "Wintergrasp")
check("THE BUG: the objective's zone wins, not the title's",
   Advisor.ZoneFromAnyMapName({ questIndex = 1 }), "Wintergrasp")

print("")
print("== objective still wins when title and objective name DIFFERENT zones ==")
QUESTLOG = {
   { title = "Icecrown: Cleanup Duty", objectives = { "Widget slain in Zul'Drak: 0/5" } },
}
QW.Update(true)
check("objective's zone (Zul'Drak) wins over the title's (Icecrown)",
   Advisor.ZoneFromAnyMapName({ questIndex = 1 }), "Zul'Drak")

print("")
print("== the title is still the fallback when no objective names a zone ==")
QUESTLOG = {
   { title = "Cleanup Duty in Icecrown", objectives = { "Widget collected: 0/5" } },
}
QW.Update(true)
check("no objective names a zone, so the title decides",
   Advisor.ZoneFromAnyMapName({ questIndex = 1 }), "Icecrown")

print("")
print("== neither title nor objective names a zone: still nil (Chalkie's card) ==")
-- Chalkie's card, fixed in this same release: neither the title nor the
-- objective names a zone at all, so this source must stay out of the way and
-- let resolution fall through to the harvested card zone (see the full
-- end-to-end pin further up, "card zone outranks a mislabelled header").
QUESTLOG = {
   { title = "Population Management: Earthbound Revenant",
     objectives = { "Earthbound Revenant slain: 0/10" } },
}
QW.Update(true)
check("no zone anywhere -> nil, falls through",
   Advisor.ZoneFromAnyMapName({ questIndex = 1 }), nil)

print("")
print("== your own kills beat a lying quest title (reported 2026-08-29) ==")
-- Real data: the quest is titled "Thinning the Herd in Winterspring", but the
-- mobs are in WINTERGRASP - 21 recorded kill points there say so. The mob here
-- is a stand-in ("Frostwing Sentry") rather than the original report's
-- "Whispering Wind": that name now carries its own curated TARGET_CHECKPOINT
-- entry (Star's Rest, see SpawnDB.lua) which is deliberately allowed to
-- outrank even learned kills, the same way Flame Revenant already does below -
-- so it can no longer stand in for "nothing curated overrides this source
-- order" the way it did when this test was written. That interaction is
-- pinned for the real name in the next block.
CURRENT_ZONE = "Dalaran"
CBH.db.learnedKills = {
   ["Wintergrasp"] = { ["Frostwing Sentry"] = { {0.5,0.5,3}, {0.6,0.6,2} } },
}
CBH.db.cardZones = { ["Frostwing Sentry"] = "Winterspring" }  -- stale/wrong card
QUESTLOG = {
   { title = "Winterspring", header = true },
   { title = "Thinning the Herd in Winterspring", objectives = { "Frostwing Sentry slain: 0/10" } },
}
QW.Update(true)
check("kills outrank title AND header AND card", Advisor.ResolveDestination(), "Wintergrasp")
check("  learned-kill source reports it", Advisor.ZoneFromLearnedKills("Frostwing Sentry"), "Wintergrasp")

print("")
print("== whispering wind's curated override beats even 21 recorded kills ==")
-- The exact scenario above, but for the REAL mob name from the original
-- report. Whispering Wind now carries its own TARGET_CHECKPOINT entry (Star's
-- Rest, Change 2 of the xMetaMorph fix) which must win here on purpose - see
-- "curated overrides still beat learned kills" for Flame Revenant further
-- down. Pinned so a future change to ZoneFromQuestText's priority cannot
-- silently let kill history override the maintainer's routing call again.
CBH.db.learnedKills = {
   ["Wintergrasp"] = { ["Whispering Wind"] = { {0.5,0.5,3}, {0.6,0.6,2} } },
}
CBH.db.cardZones = { ["Whispering Wind"] = "Winterspring" }
QUESTLOG = {
   { title = "Winterspring", header = true },
   { title = "Thinning the Herd in Winterspring", objectives = { "Whispering Wind slain: 0/10" } },
}
QW.Update(true)
local wwd, _, _, _, wwvia = Advisor.ResolveDestination()
check("curated override still wins over 21 recorded kills", wwd, "Dragonblight")
check("  ...forces the Star's Rest checkpoint", wwvia, "Star")
CBH.db.learnedKills, CBH.db.cardZones = {}, {}

print("")
print("== most-evidence zone wins, deterministically ==")
CBH.db.learnedKills = {
   ["Wintergrasp"] = { ["Contested Mob"] = { {0.1,0.1,1} } },
   ["Icecrown"]    = { ["Contested Mob"] = { {0.2,0.2,1}, {0.3,0.3,1}, {0.4,0.4,1} } },
}
check("zone with more points wins", Advisor.ZoneFromLearnedKills("Contested Mob"), "Icecrown")
check("unknown objective -> nil", Advisor.ZoneFromLearnedKills("Never Killed"), nil)
CBH.db.learnedKills, CBH.db.cardZones = {}, {}

print("")
print("== curated overrides still beat learned kills ==")
CBH.db.learnedKills = { ["Wintergrasp"] = { ["Flame Revenant"] = { {0.5,0.5,9} } } }
QUESTLOG = {
   { title = "Winterspring", header = true },
   { title = "Thinning the Herd in Winterspring", objectives = { "Flame Revenant slain: 0/10" } },
}
QW.Update(true)
local fd, _, _, _, fvia = Advisor.ResolveDestination()
check("still routes via Dragonblight map", fd, "Dragonblight")
check("  ...to Fordragon Hold", fvia, "Fordragon Hold")
CBH.db.learnedKills = {}

print("")
print("== port button: no routable objective -> Home (reported 2026-08-30) ==")
CBH.db.home = { zone = "Dalaran", x = 0.5, y = 0.5 }
CBH.db.learnedKills, CBH.db.cardZones = {}, {}
CURRENT_ZONE = "Crystalsong Forest"
-- An objective CBH genuinely cannot place. (Anub'Rekhan was the original report,
-- but raid bosses are known since 1.9.4, so that one now routes to Dragonblight
-- on purpose - see the raid test below.)
QUESTLOG = {
   { title = "Dungeons", header = true },
   { title = "Slay The Unknowable", objectives = { "The Unknowable slain: 0/1" } },
}
QW.Update(true)
check("objective is seen but unroutable", Advisor.ResolveDestination(), nil)
local lbl, mode = Advisor.ComputeButton()
check("button offers Home, not a dead 'objective'", lbl, "Port: Home")
check("  ...and clicking uses board mode", mode, "board")

print("")
print("== a routable objective still wins over Home ==")
QUESTLOG = {
   { title = "Howling Fjord", header = true },
   { title = "Fjord Stalkers", objectives = { "Beast Kill in Howling Fjord: 0/75" } },
}
QW.Update(true)
local lbl2, mode2 = Advisor.ComputeButton()
check("routes to the objective", lbl2, "Port: Howling Fjord")
check("  ...in objective mode", mode2, "objective")

print("")
print("== no home set falls back to a learned callboard ==")
CBH.db.home = nil
CBH.db.callboards = { { zone = "Dalaran", x = 0.5, y = 0.5 } }
QUESTLOG = {
   { title = "Dungeons", header = true },
   { title = "Slay The Unknowable", objectives = { "The Unknowable slain: 0/1" } },
}
QW.Update(true)
check("offers the callboard", (Advisor.ComputeButton()), "Port: Callboard")
CBH.db.callboards = {}
check("nothing at all -> no button", (Advisor.ComputeButton()), nil)

print("")
print("== raid bosses are routable now (behaviour change in 1.9.4) ==")
-- Naxxramas sits in Dragonblight, so an ordinary raid quest naming its boss is
-- now placeable. This is the objective from the 1.7.4 "should send me home"
-- report: it no longer falls back to Home, because CBH can actually route it.
CBH.db.home = { zone = "Dalaran", x = 0.5, y = 0.5 }
CURRENT_ZONE = "Icecrown"
QUESTLOG = {
   { title = "Dungeons", header = true },
   { title = "Anub'Rekhan Must Die!", objectives = { "Anub'Rekhan slain: 0/1" } },
}
QW.Update(true)
check("routes to Naxxramas' zone", Advisor.ResolveDestination(), "Dragonblight")
check("  ...so the button offers it", (Advisor.ComputeButton()), "Port: Dragonblight")

print("")
print("== callboard-only whitelist (judged on the QUEST TITLE) ==")
CBH.db.home = { zone = "Dalaran", x = 0.5, y = 0.5 }
CBH.db.options.callboardOnly = true
CBH.db.cardZones, CBH.db.cardCatalogue = {}, {}
CURRENT_ZONE = "Icecrown"
QUESTLOG = {
   { title = "Dungeons", header = true },
   { title = "The Maddening Deep", objectives = { "Yogg-Saron slain: 0/1" } },
}
QW.Update(true)
check("inactive with no cards seen", CBH.CallboardOnlyActive(), false)
check("  ...so it still routes", Advisor.ResolveDestination(), "The Storm Peaks")

-- The reported case: a real callboard card names the same boss, but the ACTIVE
-- quest is Maerys's meta-quest, not the board contract.
CBH.db.cardCatalogue = {
   ["Topple the Tyrant: Yogg-Saron"] = { n = 1 },
   ["Kill 10 Flame Revenant in Wintergrasp."] = { n = 1 },
}
check("active once cards are known", CBH.CallboardOnlyActive(), true)
check("meta-quest sharing a boss is NOT callboard work",
   CBH.IsCallboardQuest("The Maddening Deep", "Yogg-Saron"), false)
check("  ...so it is filtered out", Advisor.ResolveDestination(), nil)
check("  ...and the button offers Home", (Advisor.ComputeButton()), "Port: Home")

-- The actual board contract for the same boss still routes.
QUESTLOG = {
   { title = "The Storm Peaks", header = true },
   { title = "Topple the Tyrant: Yogg-Saron", objectives = { "Yogg-Saron slain: 0/1" } },
}
QW.Update(true)
check("the real board quest is callboard work",
   CBH.IsCallboardQuest("Topple the Tyrant: Yogg-Saron", "Yogg-Saron"), true)
check("  ...and routes", Advisor.ResolveDestination(), "The Storm Peaks")

print("")
print("== cardZones is no longer treated as evidence ==")
CBH.db.cardCatalogue = { ["Kill 10 Flame Revenant in Wintergrasp."] = { n = 1 } }
CBH.db.cardZones = { ["Yogg-Saron"] = "The Storm Peaks" }   -- stale resolution cache
check("a cardZones entry alone does not qualify",
   CBH.IsCallboardQuest("The Maddening Deep", "Yogg-Saron"), false)
check("catalogue-only count", CBH.KnownCallboardCount(), 1)

print("")
print("== it can be switched off ==")
CBH.db.options.callboardOnly = false
check("off means inactive", CBH.CallboardOnlyActive(), false)
CBH.db.options.callboardOnly = false
CBH.db.cardZones, CBH.db.cardCatalogue = {}, {}

print("")
print("== Dalaran home: scan Crystalsong's map, not Dalaran's (reported 2026-08-30) ==")
-- Dalaran floats over Crystalsong Forest and its own map carries no checkpoint
-- buttons, so pointing the map at Dalaran finds nothing at all.
check("Dalaran redirects to Crystalsong", Advisor.MapViaFor("Dalaran"), "Crystalsong Forest")
check("an ordinary zone does not redirect", Advisor.MapViaFor("Icecrown"), nil)
check("nil-safe", Advisor.MapViaFor(nil), nil)

CBH.db.home = { zone = "Dalaran", x = 0.5, y = 0.5 }
CBH.db.callboards = {}
CURRENT_ZONE = "Icecrown"
Advisor.portMapZone, Advisor.portViaName = nil, nil
Advisor.PortToCallboard()
check("map scanned is Crystalsong", Advisor.portMapZone, "Crystalsong Forest")
check("  ...but the destination is still Dalaran", Advisor.lastDestZone, "Dalaran")
check("  ...forcing the checkpoint named Dalaran", Advisor.portViaName, "Dalaran")

print("")
print("== a normal home is untouched ==")
CBH.db.home = { zone = "Howling Fjord", x = 0.5, y = 0.5 }
Advisor.portMapZone, Advisor.portViaName = nil, nil
Advisor.PortToCallboard()
check("no redirect", Advisor.portMapZone, nil)
check("no forced checkpoint", Advisor.portViaName, nil)
check("destination unchanged", Advisor.lastDestZone, "Howling Fjord")
CBH.db.home = nil

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end
