-- CallboardHunter Route: a guided runner for the community "fast prestige"
-- route. The centrepiece is the LEVELLING LEG -- Dalaran -> Zul'Drak, three
-- quests that carry a fresh run to ~64 -- with the ash / self-execute / tree
-- refill preamble tracked around it.
--
-- AUTOMATION BOUNDARY. We READ state and DRAW the next step; nothing here
-- moves your character, picks a target, or acts while you are away. What this
-- removes is the REMEMBERING -- which step you are on, which checkpoint id,
-- whether the prerequisite is unlocked, what the last lap's XP yield was.
--
-- The ONE thing that acts for you is auto accept / turn-in, and only inside a
-- quest dialog YOU walked to and opened, and only for the three quests in
-- Route.STEPS. That is ordinary unprotected 3.3.5 API (AcceptQuest /
-- CompleteQuest / GetQuestReward), the same kind EbonholdHub's auto-pick engine
-- already uses for echo draws. It is still a click you would otherwise make by
-- hand, in a window already on your screen -- not a bot playing unattended.
-- /cbh route auto turns it off. See the Auto accept section for the scoping.
--
-- Two things are LEARNED rather than hardcoded, because this is a custom server
-- and a wrong guess is worse than an honest blank:
--   * checkpoint id -> name/unlocked, harvested off the world map's own buttons
--     (they carry checkpointId / nodeName / isUnlocked -- found via /cbh portscan);
--   * quest giver / turn-in coordinates, recorded the first time you run the
--     chain, so every later lap can point an arrow at them.
local CBH = CallboardHunter
local Route = CBH.Route

local GOLD   = "|cffe0b352"
local BRIGHT = "|cfff6d888"
local DIM    = "|cffb4a586"
local EMBER  = "|cffd9694a"
local VERD   = "|cff8aa96a"
local R      = "|r"

-- Colourblind-safe status markers: the letters carry the meaning, colour only
-- reinforces it (never classify by hue alone in this UI).
local MARK_DONE    = "[" .. VERD   .. "OK" .. R .. "]"
local MARK_NOW     = "[" .. GOLD   .. ">>" .. R .. "]"
local MARK_TODO    = "[  ]"
local MARK_BLOCKED = "[" .. EMBER  .. "!!" .. R .. "]"
local MARK_MANUAL  = "[" .. BRIGHT .. "~~" .. R .. "]"

-- ---------------------------------------------------------------------------
-- Route data
-- ---------------------------------------------------------------------------

-- Checkpoint ids come from the route's own macros. They are VALIDATED at
-- runtime against the harvested map table -- if the server renumbers them the
-- panel says "NAME MISMATCH" instead of teleporting you somewhere random.
Route.CP = {
  DALARAN = { id = "310", zone = "Dalaran",       label = "Dalaran" },
  ZULDRAK = { id = "304", zone = "Zul'Drak",      label = "Zul'Drak - The Argent Stand" },
  BOREAN  = { id = "296", zone = "Borean Tundra", label = "Borean Tundra - Unu'pe" },
  -- The 64->80 half of the leg. 334 is the Icecrown checkpoint that reads
  -- unlocked in a harvested table; 340 (Argent Tournament Grounds) is the other
  -- one, and /cbh route cp 340 goes there if you prefer it.
  ICECROWN = { id = "334", zone = "Icecrown", label = "Icecrown - The Argent Vanguard" },
}

-- Quest titles are the stable key: GetQuestLogTitle hands us titles, and
-- IsQuestFlaggedCompleted does not exist on 3.3.5a, so turn-ins are tracked by
-- watching a quest leave the log after its QUEST_COMPLETE.
local Q_PREP  = "Preparations for War"
local Q_LEARN = "Learning to Leave and Return: The Magical Way"
local Q_CALL  = "The Champion's Call!"

-- This route is the LEVELLING LEG and nothing else: a fresh level 1 to ~64, at
-- any ash level, any time. The prestige preamble (farm to the ash gate,
-- self-execute, refill the tree) used to sit at the front of this list, which
-- made step 1 read "Ash 0 / 10,771,440" to someone standing in Durotar who just
-- wants to level. That is a different job; it does not belong here.
--
-- kind: mode | port | quest
Route.STEPS = {
  { key = "hcStart", kind = "mode", hcStep = true, tierKey = "start",
    detail = "CBH clicks the tier control on the run frame and checks it took. If the server's UI moves, switch it yourself and Mark done." },
  { key = "dala1", kind = "port", cp = "DALARAN",
    text = "Port to Dalaran",
    detail = "Checkpoint 310. Puts you at Krasus' Landing." },
  { key = "q1", kind = "quest", quest = Q_PREP, phase = "turnin",
    text = "Quest 1: " .. Q_PREP,
    detail = "Krasus' Landing, Dalaran." },
  { key = "q2", kind = "quest", quest = Q_LEARN, phase = "turnin",
    text = "Quest 2: " .. Q_LEARN,
    detail = "Dalaran." },
  { key = "q3a", kind = "quest", quest = Q_CALL, phase = "accept",
    text = "Quest 3: pick up " .. Q_CALL,
    detail = "Dalaran, near the training dummies." },
  { key = "zd", kind = "port", cp = "ZULDRAK", needsUnlock = true,
    text = "Port to Zul'Drak (The Argent Stand)",
    detail = "Checkpoint 304. Needs The Argent Stand flight path unlocked first." },
  { key = "q3b", kind = "quest", quest = Q_CALL, phase = "turnin",
    text = "Quest 3: hand in " .. Q_CALL,
    detail = "The Argent Stand, Zul'Drak. On HC5 with XP passives maxed you should land near 64." },

  { key = "dala2", kind = "port", cp = "DALARAN",
    text = "Port back to Dalaran",
    detail = "Checkpoint 310." },
  { key = "hcEnd", kind = "mode", hcStep = true, tierKey = "end",
    detail = "CBH clicks the tier control on the run frame and checks it took. If the server's UI moves, switch it yourself and Mark done. "
      .. "Stay put if you can hold the higher one safely." },
  { key = "bt", kind = "port", cp = "BOREAN",
    text = "Port to Borean Tundra (Unu'pe)",
    detail = "Checkpoint 296. Carry on levelling from here." },

  -- 64 -> 80. The route post stops at Unu'pe ("carry on levelling from here"),
  -- so these two zone/level bands are not transcribed from it -- they come from
  -- keepsy's own logged runs, which put 66-72 in Borean Tundra and 73-80 in
  -- Icecrown. Targets are editable with /cbh route grind <level>.
  { key = "grindBt", kind = "level", target = 72, cp = "BOREAN",
    text = "Level to 72 in Borean Tundra",
    detail = "Kill your way up. The button ports you back here if you stray." },
  { key = "ice", kind = "port", cp = "ICECROWN",
    text = "Port to Icecrown (The Argent Vanguard)",
    detail = "Checkpoint 334. Icecrown carries you the rest of the way." },
  { key = "grindIce", kind = "level", target = 80, cp = "ICECROWN",
    text = "Level to 80 in Icecrown",
    detail = "The last stretch. Route ends when you ding 80." },
}

-- ---------------------------------------------------------------------------
-- Saved state
-- ---------------------------------------------------------------------------

local function DB()
  CBH.db.route = CBH.db.route or {}
  local d = CBH.db.route
  d.acked       = d.acked       or {}  -- manual steps ticked off this lap
  d.turnedIn    = d.turnedIn    or {}  -- quest title -> true, this lap
  d.learned     = d.learned     or {}  -- quest title -> { give = {...}, turn = {...} }
  d.checkpoints = d.checkpoints or {}  -- id (string) -> { name, unlocked, at }
  d.xp          = d.xp          or {}  -- quest title -> { from, to, when }
  d.laps        = d.laps        or 0
  d.suppress    = d.suppress    or {}  -- port key -> zone it was stepped back in
  if d.mini == nil then d.mini = true end -- compact panel is the default view
  return d
end

-- Hardcore tiers are configurable because the route's "HC5" is the author's
-- ladder, not yours -- you cannot switch to a tier you have not unlocked.
-- /cbh route hc <n> sets the one you level on, /cbh route hc off drops both
-- mode steps entirely for people who never switch.
function Route.HcTier(which)
  local d = DB()
  if which == "start" then return tonumber(d.hcStart) or 5 end
  return tonumber(d.hcEnd) or 3
end

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

-- Level bands for the 64->80 grind steps, overridable per character.
function Route.GrindTarget(key, fallback)
  local d = DB()
  local v = d.grind and tonumber(d.grind[key])
  return v or fallback
end

function Route.HcEnabled()
  return DB().hc ~= "off"
end

-- The steps actually in play. Mode steps drop out when hardcore switching is
-- off, and carry the configured tier when it is on.
function Route.Steps()
  local out = {}
  for _, st in ipairs(Route.STEPS) do -- the MASTER list, not the filtered one
    if st.hcStep then
      if Route.HcEnabled() then
        st.tier = Route.HcTier(st.tierKey)
        st.text = (st.tierKey == "start")
          and ("Switch to Hardcore " .. st.tier)
          or ("Drop to Hardcore " .. st.tier .. " (optional)")
        out[#out + 1] = st
      end
    else
      out[#out + 1] = st
    end
  end
  -- Grind targets come from saved config so /cbh route grind can retune them.
  for _, st in ipairs(out) do
    if st.kind == "level" then
      st.target = Route.GrindTarget(st.key, st.key == "grindIce" and 80 or 72)
      st.text = "Level to " .. st.target .. " in " .. (Route.CP[st.cp] and Route.CP[st.cp].zone or "?")
    end
  end
  return out
end

local function Say(m) DEFAULT_CHAT_FRAME:AddMessage(m) end

-- Quest titles are compared through this, never raw. Two of the three route
-- quests contain an apostrophe, and this server mixes the straight (') and
-- curly (U+2019) forms in its own data -- HubSync already has to emit echo
-- names both ways. A raw compare would just silently never match, and the
-- route would sit on "pick up quest 3" forever with no error to explain it.
local function NormTitle(s)
  s = tostring(s or "")
  s = string.gsub(s, "\226\128\153", "'") -- right single quotation mark
  s = string.gsub(s, "\226\128\152", "'") -- left single quotation mark
  s = string.gsub(s, "%s+", " ")
  s = string.gsub(s, "^%s*(.-)%s*$", "%1")
  return string.lower(s)
end
Route.NormTitle = NormTitle

-- Find a quest in a scanned log regardless of which apostrophe it was spelled
-- with. Linear over the ~25 entries of a quest log; called a handful of times
-- per refresh, so the cost is noise.
local function QFind(qlog, want)
  if qlog[want] then return qlog[want] end
  local w = NormTitle(want)
  for title, entry in pairs(qlog) do
    if NormTitle(title) == w then return entry end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Live state readers (all nil-guarded -- every one of these can be absent)
-- ---------------------------------------------------------------------------

local function PlayerPos()
  if not (WorldMapFrame and WorldMapFrame:IsShown()) then SetMapToCurrentZone() end
  local x, y = GetPlayerMapPosition("player")
  if not x or (x == 0 and y == 0) then return nil end
  return x, y
end

-- Quest log scan keyed on title. Collapsed headers hide their quests from
-- GetQuestLogTitle on 3.3.5, so expand for the scan -- and only re-collapse
-- when the player had EVERY header shut (the clean-log case). Half-open logs
-- are left expanded rather than guessing wrong and hiding a quest they were
-- watching.
--
-- ExpandQuestHeader itself fires QUEST_LOG_UPDATE, which is what we scan FROM,
-- so `inScan` breaks that loop and a short cache keeps the repeated updates
-- during a catch-up burst from costing anything.
local scanCache, scanAt, inScan = nil, 0, false

-- noExpand: never touch the header state. The compact panel re-renders on a
-- ticker, and expanding + re-collapsing the quest log once a second would make
-- it visibly jump under the player. UI refreshes therefore scan read-only and
-- rely on the event-driven scans (which may expand) to latch quest progress.
local function ScanQuestLog(force, noExpand)
  if inScan then return scanCache or {} end
  local now = (GetTime and GetTime()) or 0
  if not force and scanCache and (now - scanAt) < 0.5 then return scanCache end

  inScan = true
  local found = {}
  local n = GetNumQuestLogEntries()
  if n and n > 0 then
    local headers, collapsed = 0, 0
    for i = 1, n do
      local _, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
      if isHeader then
        headers = headers + 1
        if isCollapsed then collapsed = collapsed + 1 end
      end
    end

    local expandedByUs = false
    if collapsed > 0 and not noExpand and ExpandQuestHeader then
      ExpandQuestHeader(0)
      expandedByUs = true
      n = GetNumQuestLogEntries()
    end

    for i = 1, n do
      local title, level, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
      if title and not isHeader then
        found[title] = {
          index = i,
          complete = (isComplete == 1 or isComplete == true),
          level = level,
        }
      end
    end

    if expandedByUs and headers > 0 and collapsed == headers and CollapseQuestHeader then
      CollapseQuestHeader(0)
    end
  end

  inScan = false
  scanCache, scanAt = found, now
  return found
end

Route.ScanQuestLog = ScanQuestLog

-- ---------------------------------------------------------------------------
-- Checkpoint harvest. The map's own buttons carry checkpointId / nodeName /
-- isUnlocked, so harvesting them turns the route's bare numbers into names we
-- can verify -- and lets us pre-check the Argent Stand prerequisite before you
-- commit to that leg.
-- ---------------------------------------------------------------------------

function Route.CpScan(verbose)
  local d = DB()
  local n = 0
  if not (WorldMapFrame and WorldMapButton) then
    if verbose then CBH.print("Open the world map first, then /cbh route cpscan.") end
    return 0
  end
  local function walk(f, depth)
    if depth > 6 or not f or not f.GetChildren then return end
    for i = 1, select("#", f:GetChildren()) do
      local c = select(i, f:GetChildren())
      if c then
        local id = rawget(c, "checkpointId")
        if id ~= nil then
          local key = tostring(id)
          local prev = d.checkpoints[key]
          d.checkpoints[key] = {
            name = rawget(c, "nodeName") or (prev and prev.name) or "?",
            unlocked = rawget(c, "isUnlocked"),
            at = time(),
          }
          n = n + 1
        end
        walk(c, depth + 1)
      end
    end
  end
  walk(WorldMapFrame, 0)
  if verbose then
    if n == 0 then
      CBH.print("No checkpoint buttons on this map. Open the Northrend/continent "
        .. "view and run it again.")
    else
      CBH.print("Checkpoints harvested: " .. GOLD .. n .. R .. DIM
        .. " on this map, " .. Route.CpCount() .. " known in total." .. R)
    end
  end
  return n
end

function Route.CpCount()
  local c = 0
  for _ in pairs(DB().checkpoints) do c = c + 1 end
  return c
end

-- What we know about one route checkpoint: name, unlocked, and whether the
-- harvested name plausibly matches the zone the route expects.
function Route.CpInfo(cpKey)
  local cp = Route.CP[cpKey]
  if not cp then return nil end
  local known = DB().checkpoints[cp.id]
  if not known then
    return { id = cp.id, label = cp.label, zone = cp.zone, known = false }
  end
  local nm = string.lower(tostring(known.name or ""))
  local zoneWord = string.lower(string.match(cp.zone, "^([%a']+)") or cp.zone)
  -- Tri-state on purpose: true = verified, false = the id points somewhere
  -- else, nil = nothing harvested yet. Written long-hand because an
  -- `x and y or nil` chain collapses a genuine false into nil, which would
  -- silently disable the mismatch warning.
  local matches = nil
  if nm ~= "" and nm ~= "?" then
    matches = (string.find(nm, zoneWord, 1, true) ~= nil)
      or (string.find(string.lower(cp.label), nm, 1, true) ~= nil)
  end
  return {
    id = cp.id, label = cp.label, zone = cp.zone, known = true,
    name = known.name, unlocked = known.unlocked, matches = matches,
  }
end

-- ---------------------------------------------------------------------------
-- Porting. Prefers the server's own request (what the route's macro uses),
-- falls back to CallboardHunter's map-click port, last resort prints the macro.
-- Only ever reached from a click or a slash command you typed.
-- ---------------------------------------------------------------------------

function Route.HasServerPort()
  local PE = _G.ProjectEbonhold
  return PE ~= nil and type(PE.sendToServer) == "function"
    and PE.CS ~= nil and PE.CS.REQUEST_USE_CHECKPOINT ~= nil
end

function Route.PortMacro(id)
  return "/run ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_USE_CHECKPOINT, \""
    .. tostring(id) .. "\")"
end

function Route.PortTo(cpKey)
  local cp = Route.CP[cpKey]
  if not cp then
    CBH.print("Unknown checkpoint key: " .. tostring(cpKey))
    return false
  end
  local info = Route.CpInfo(cpKey)
  if info and info.known and info.unlocked == false then
    CBH.print(EMBER .. "Checkpoint " .. cp.id .. " (" .. tostring(info.name)
      .. ") is LOCKED for you." .. R .. DIM
      .. " Reach it on foot once and this step works on every later lap." .. R)
    return false
  end
  if Route.HasServerPort() then
    local PE = _G.ProjectEbonhold
    local ok = pcall(PE.sendToServer, PE.CS.REQUEST_USE_CHECKPOINT, tostring(cp.id))
    if ok then
      CBH.print("Travelling to " .. BRIGHT .. cp.label .. R .. DIM
        .. " (checkpoint " .. cp.id .. "). Stand still -- it casts." .. R)
      return true
    end
  end
  -- Living inside CallboardHunter means the map-click port is just a local
  -- call: walk the world map's checkpoint buttons and click the right one.
  if CBH.Advisor and CBH.Advisor.Port then
    CBH.print(DIM .. "Server checkpoint call unavailable -- routing through "
      .. "the map port instead." .. R)
    CBH.safeCall(CBH.Advisor.Port, cp.zone)
    return true
  end
  CBH.print(EMBER .. "No porting route available." .. R .. " Use this macro:")
  Say("  " .. BRIGHT .. Route.PortMacro(cp.id) .. R)
  return false
end

-- ---------------------------------------------------------------------------
-- Step resolution. The current step is DERIVED from live state on every
-- refresh, never stored as a cursor -- so doing things out of order, by hand,
-- or after a /reload all resolve correctly.
-- ---------------------------------------------------------------------------

local function StepDone(step, qlog)
  local d = DB()
  if d.acked[step.key] then return true end
  if step.kind == "level" then
    return (UnitLevel("player") or 0) >= (step.target or 80)
  elseif step.kind == "quest" then
    if d.turnedIn[NormTitle(step.quest)] then return true end
    if step.phase == "accept" then return QFind(qlog, step.quest) ~= nil end
    return false
  elseif step.kind == "port" then
    local cp = Route.CP[step.cp]
    if not cp then return false end
    -- A port step completes by you being in the zone, which means Back alone
    -- cannot undo it while you are standing there -- it would re-satisfy on the
    -- next refresh. Back therefore records the zone it was undone in, and the
    -- suppression lifts the moment you leave, so re-arriving completes it again.
    local sup = d.suppress and d.suppress[step.key]
    if sup then
      if sup == GetRealZoneText() then return false end
      d.suppress[step.key] = nil
    end
    return GetRealZoneText() == cp.zone
  elseif step.kind == "mode" then
    -- Detected now, not merely acknowledged: the tier is readable, so a step
    -- that claims to have switched can be checked against reality.
    local now = Route.HcCurrent()
    return now ~= nil and now == step.tier
  end
  return false
end

local function StepBlocked(step)
  if step.kind == "port" and step.needsUnlock then
    local info = Route.CpInfo(step.cp)
    if info and info.known and info.unlocked == false then
      return "The Argent Stand flight path is not unlocked -- reach it once on foot or by flight."
    end
  end
  return nil
end

-- Index of the current step, plus the scanned quest log (so callers that
-- already need it do not scan twice).
--
-- Progress through a linear route is MONOTONIC, so each step is latched the
-- moment it is reached and satisfied. Without the latch a port step un-completes
-- as soon as you leave that zone -- port to Zul'Drak, hand in, port home, and
-- the route would send you straight back to Zul'Drak forever.
function Route.Current(noExpand)
  local qlog = ScanQuestLog(false, noExpand)
  local d = DB()
  for i, step in ipairs(Route.Steps()) do
    if not StepDone(step, qlog) then return i, qlog end
    d.acked[step.key] = true
  end
  return nil, qlog
end

-- ---------------------------------------------------------------------------
-- Quest watching: accept, complete, and the learned coordinates
-- ---------------------------------------------------------------------------

local pendingTurnIn = nil -- title captured at QUEST_COMPLETE
local levelBefore = nil
local seenInLog = {}      -- route quest -> true while it sits in the quest log

-- The server announces every hand-in with ERR_QUEST_COMPLETE_S ("%s completed.").
-- That is the single most reliable turn-in signal on 3.3.5a -- there is no
-- QUEST_TURNED_IN event, and the QUEST_COMPLETE -> quest-leaves-the-log
-- handshake this used to rely on can be missed entirely when the hand-in is
-- automatic or when a catch-up level burst floods the event queue.
local donePattern
local function QuestDonePattern()
  if donePattern then return donePattern end
  local fmt = _G.ERR_QUEST_COMPLETE_S or "%s completed."
  local esc = string.gsub(fmt, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
  esc = string.gsub(esc, "%%s", "(.+)")
  donePattern = "^" .. esc .. "$"
  return donePattern
end

-- NPC recorded for a step's give/turn-in, if any. Defined here because both
-- the targeting macro and the compact panel need it.
function Route.StepSpotNpc(step)
  if not (step and step.kind == "quest") then return nil end
  local rec = DB().learned[NormTitle(step.quest)]
  local spot = rec and rec[(step.phase == "accept") and "give" or "turn"]
  return spot and spot.npc or nil
end

local function IsRouteQuest(title)
  if not title then return false end
  local want = NormTitle(title)
  -- The master list, not the filtered one: a quest is a route quest whether or
  -- not the hardcore steps happen to be switched on.
  for _, s in ipairs(Route.STEPS) do
    if s.kind == "quest" and NormTitle(s.quest) == want then return true end
  end
  return false
end

-- Learned locations, XP yields and turn-ins are all keyed by NormTitle so a
-- record written from one apostrophe spelling is still found under the other.
local function Learn(title, which)
  local d = DB()
  local x, y = PlayerPos()
  if not x then return end
  local key = NormTitle(title)
  -- ONLY the dialog NPC. Falling back to UnitName("target") would happily
  -- record whatever mob you were hitting at the time as the quest giver, and a
  -- wrong name is worse than no name -- it sends you to the wrong place AND
  -- makes the target button target the wrong thing.
  local who = UnitName and UnitName("npc") or nil
  local prev = d.learned[key] and d.learned[key][which]
  d.learned[key] = d.learned[key] or {}
  d.learned[key][which] = {
    zone = GetRealZoneText(),
    x = x, y = y,
    npc = who or (prev and prev.npc) or nil,
    at = time(),
  }
end

local function OnQuestAccepted()
  if inScan then return end
  local d = DB()
  local qlog = ScanQuestLog(true) -- the quest we care about only just landed
  for title in pairs(qlog) do
    local key = NormTitle(title)
    if IsRouteQuest(title) and not (d.learned[key] and d.learned[key].give) then
      Learn(title, "give")
      CBH.print("Learned where " .. BRIGHT .. title .. R .. DIM
        .. " starts -- next lap the arrow points straight at it." .. R)
    end
  end
  if Route.panel and Route.panel:IsShown() then Route.Refresh() end
end

local function OnQuestComplete()
  local title = GetTitleText and GetTitleText()
  if IsRouteQuest(title) then
    pendingTurnIn = title
    levelBefore = UnitLevel("player")
    Learn(title, "turn")
  end
end

-- One place that records a hand-in, whichever of the three signals spotted it.
-- Idempotent: the signals overlap on purpose, because any one of them alone has
-- been observed to miss.
local function MarkTurnedIn(title, how)
  if not title then return end
  local d = DB()
  local key = NormTitle(title)
  if d.turnedIn[key] then return end
  d.turnedIn[key] = true
  seenInLog[key] = nil
  local after = UnitLevel("player")
  if levelBefore and after and after >= levelBefore then
    d.xp[key] = { from = levelBefore, to = after, when = time() }
  end
  d.lastDetect = { title = title, how = how, at = time() }
  CBH.print(VERD .. "Route step done: " .. R .. BRIGHT .. title .. R
    .. ((levelBefore and after and after > levelBefore)
        and (DIM .. "  (" .. levelBefore .. " -> " .. after .. ")" .. R) or "")
    .. DIM .. "  [" .. tostring(how) .. "]" .. R)
  pendingTurnIn, levelBefore = nil, nil
  Route.Refresh()
end
Route.MarkTurnedIn = MarkTurnedIn

-- Signal 1 (primary): the server said so in chat.
local function OnSystemMessage(msg)
  if type(msg) ~= "string" then return end
  local title = string.match(msg, QuestDonePattern())
  if title and IsRouteQuest(title) then MarkTurnedIn(title, "chat") end
end

-- Signal 2 (backup): a route quest that WAS in the log no longer is. Only
-- counts as a hand-in when we had also seen it complete or had it pending,
-- so abandoning a quest does not tick the step off.
local function OnQuestLogUpdate()
  if inScan then return end -- our own ExpandQuestHeader bounced back at us
  local qlog = ScanQuestLog(true)

  for _, st in ipairs(Route.Steps()) do
    if st.kind == "quest" then
      local key = NormTitle(st.quest)
      local entry = QFind(qlog, st.quest)
      if entry then
        seenInLog[key] = entry.complete and "complete" or "active"
      elseif seenInLog[key] == "complete" or NormTitle(pendingTurnIn or "") == key then
        MarkTurnedIn(st.quest, "left the log")
      end
    end
  end

  -- Signal 3 (legacy): the reward screen fired and the quest is now gone.
  if pendingTurnIn and not QFind(qlog, pendingTurnIn) then
    MarkTurnedIn(pendingTurnIn, "reward taken")
  end
  Route.Refresh()
end

-- ---------------------------------------------------------------------------
-- Auto accept / auto turn-in
--
-- SCOPE: only the three quests in Route.STEPS, and only once you have walked to
-- the NPC and opened their dialog yourself. This does not move you, target
-- anyone, or act while you are away -- it presses "Accept" and "Complete" in a
-- window you opened. AcceptQuest / CompleteQuest / GetQuestReward are ordinary
-- unprotected 3.3.5 API (Questie and AutoTurnIn have used them for years, and
-- EbonholdHub's own auto-pick engine calls PerkService.SelectPerk the same way).
-- Deliberately narrow: a blanket auto-accept would swallow quests you never
-- wanted, and there is no undo for that. Toggle with /cbh route auto.
-- ---------------------------------------------------------------------------

function Route.AutoOn()
  local d = DB()
  return d.auto ~= false
end

-- Gossip quest lists return a flat vararg whose stride has differed between
-- builds. Rather than hardcode one, count STRINGS: every title is a string and
-- every other field is a number/boolean, so the Nth string is quest N.
local function GossipIndexOf(fn, want)
  if type(fn) ~= "function" then return nil end
  local ok, n = pcall(function() return select("#", fn()) end)
  if not ok or not n or n == 0 then return nil end
  local wanted, idx = NormTitle(want), 0
  for i = 1, n do
    local v = select(i, fn())
    if type(v) == "string" then
      idx = idx + 1
      if NormTitle(v) == wanted then return idx end
    end
  end
  return nil
end

-- The route quest we are currently expecting, if any. Auto-actions only ever
-- fire for this one.
local function ExpectedQuest()
  local cur = Route.Current(true)
  local step = cur and Route.Steps()[cur] or nil
  if step and step.kind == "quest" then return step.quest, step.phase end
  return nil
end

-- Any route quest is fair game for accept/turn-in, not just the expected one --
-- doing the chain slightly out of order should still work.
local function AutoWanted(title)
  return Route.AutoOn() and IsRouteQuest(title)
end

local function OnGossipShow()
  if not Route.AutoOn() then return end
  for _, s in ipairs(Route.Steps()) do
    if s.kind == "quest" then
      -- Turn-ins first: finishing a quest beats picking up the next one.
      local i = GossipIndexOf(_G.GetGossipActiveQuests, s.quest)
      if i and SelectGossipActiveQuest then SelectGossipActiveQuest(i) return end
    end
  end
  for _, s in ipairs(Route.Steps()) do
    if s.kind == "quest" then
      local i = GossipIndexOf(_G.GetGossipAvailableQuests, s.quest)
      if i and SelectGossipAvailableQuest then SelectGossipAvailableQuest(i) return end
    end
  end
end

-- The older non-gossip multi-quest greeting uses clean indexed accessors.
local function OnQuestGreeting()
  if not Route.AutoOn() then return end
  local nAct = (GetNumActiveQuests and GetNumActiveQuests()) or 0
  for i = 1, nAct do
    local t = GetActiveTitle and GetActiveTitle(i)
    if t and AutoWanted(t) and SelectActiveQuest then SelectActiveQuest(i) return end
  end
  local nAvail = (GetNumAvailableQuests and GetNumAvailableQuests()) or 0
  for i = 1, nAvail do
    local t = GetAvailableTitle and GetAvailableTitle(i)
    if t and AutoWanted(t) and SelectAvailableQuest then SelectAvailableQuest(i) return end
  end
end

local function OnQuestDetail()
  local title = GetTitleText and GetTitleText()
  if AutoWanted(title) and AcceptQuest then
    AcceptQuest()
    CBH.print(VERD .. "Accepted: " .. R .. BRIGHT .. tostring(title) .. R)
  end
end

local function OnQuestProgress()
  local title = GetTitleText and GetTitleText()
  if not AutoWanted(title) then return end
  if IsQuestCompletable and IsQuestCompletable() and CompleteQuest then
    CompleteQuest()
  end
end

-- Reward screen. A quest with a CHOICE of rewards is left alone -- picking the
-- wrong one is not undoable, and none of the route quests should have one, so
-- if it happens it is a signal that the server's version differs from the
-- route's and you should look at it yourself.
local function OnQuestCompleteAuto()
  local title = GetTitleText and GetTitleText()
  if not AutoWanted(title) then return end
  local choices = (GetNumQuestChoices and GetNumQuestChoices()) or 0
  if choices > 1 then
    CBH.print(EMBER .. "Pick a reward yourself" .. R .. DIM .. " for \"" .. tostring(title)
      .. "\" (" .. choices .. " choices -- not auto-taking that)." .. R)
    return
  end
  if GetQuestReward then GetQuestReward(1) end
end

-- ---------------------------------------------------------------------------
-- Targeting the step's NPC
--
-- TargetUnit is protected, so targeting has to come from a macro on a secure
-- button -- the same shape CallboardHunter's click-to-target toast already uses
-- on this client. The button runs "/targetexact <npc>" and then calls back in
-- here to place the marker.
-- ---------------------------------------------------------------------------

-- Raid marker to drop on the step NPC. 8 = skull. Markers are distinguishable
-- by SHAPE, not just colour, which is why this is a usable cue here.
local MARK_NAMES = { "star", "circle", "diamond", "triangle", "moon",
                     "square", "cross", "skull" }

function Route.MarkIndex()
  local n = tonumber(CBH.db and CBH.db.options and CBH.db.options.routeMark)
  if n and n >= 1 and n <= 8 then return n end
  return 8
end

-- Called from the button's macro, immediately after /targetexact.
function Route.OnTargeted()
  local cur = Route.Current(true)
  local step = cur and Route.Steps()[cur] or nil
  local want = step and Route.StepSpotNpc(step) or nil

  if not UnitExists("target") then
    CBH.print(EMBER .. "Couldn't find " .. R .. BRIGHT .. tostring(want or "them") .. R
      .. EMBER .. " nearby." .. R .. DIM
      .. " They have to be in range to target. The arrow still points at the spot." .. R)
    return
  end

  local idx = Route.MarkIndex()
  if SetRaidTarget then pcall(SetRaidTarget, "target", idx) end
  local got = GetRaidTargetIndex and GetRaidTargetIndex("target")
  local name = UnitName("target") or "?"
  if got then
    CBH.print("Targeted " .. BRIGHT .. name .. R .. DIM .. " and marked with the "
      .. (MARK_NAMES[got] or ("#" .. got)) .. "." .. R)
  else
    -- Raid icons are a group feature; solo the call is a silent no-op. Say so
    -- once rather than leaving you wondering where the skull is.
    CBH.print("Targeted " .. BRIGHT .. name .. R .. DIM
      .. ".  (No marker -- raid icons need a party on this client.)" .. R)
  end
end

-- ---------------------------------------------------------------------------
-- Panel
-- ---------------------------------------------------------------------------

local ROW_H = 15

function Route.Build()
  if Route.panel then return Route.panel end
  local f = CreateFrame("Frame", "CallboardHunterRoutePanel", UIParent)
  f:SetWidth(440)
  f:SetHeight(64 + #Route.Steps() * ROW_H + 120)
  f:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    CBH.db.route = CBH.db.route or {}
    local _, _, _, x, y = self:GetPoint()
    CBH.db.route.pos = { x = x, y = y }
  end)
  f:SetFrameStrata("MEDIUM")

  local pos = CBH.db.route and CBH.db.route.pos
  if pos then
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
  end

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", 0, -14)
  f.title:SetText(GOLD .. "Prestige Route" .. R)

  f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -3)
  f.sub:SetWidth(400)

  f.rows = {}
  for i = 1, #Route.Steps() do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 14, -(52 + (i - 1) * ROW_H))
    fs:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    fs:SetJustifyH("LEFT")
    f.rows[i] = fs
  end

  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.note:SetPoint("TOPLEFT", 14, -(60 + #Route.Steps() * ROW_H))
  f.note:SetPoint("RIGHT", f, "RIGHT", -14, 0)
  f.note:SetJustifyH("LEFT")
  f.note:SetHeight(30)

  -- Primary action for the current step (port / point / glow the tree node).
  f.act = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.act:SetWidth(186); f.act:SetHeight(22)
  f.act:SetPoint("BOTTOMLEFT", 16, 44)

  -- "Done" for the steps we cannot detect (hardcore swaps, tree refill).
  f.ack = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.ack:SetWidth(120); f.ack:SetHeight(22)
  f.ack:SetPoint("LEFT", f.act, "RIGHT", 8, 0)
  f.ack:SetText("Mark done")
  f.ack:SetScript("OnClick", function() Route.Ack() end)

  -- Way back to the one-button view.
  f.compact = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.compact:SetWidth(80); f.compact:SetHeight(20)
  f.compact:SetPoint("BOTTOMRIGHT", -16, 19)
  f.compact:SetText("Compact")
  f.compact:SetScript("OnClick", function() Route.SetMode(true) end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  f:SetScript("OnShow", function() Route.Refresh() end)
  f:Hide()
  Route.panel = f
  return f
end

function Route.Ack()
  local i = Route.Current()
  if not i then
    CBH.print("Route complete -- /cbh route reset starts the next lap.")
    return
  end
  local step = Route.Steps()[i]
  DB().acked[step.key] = true
  CBH.print(VERD .. "Marked done: " .. R .. step.text)
  Route.Refresh()
end

-- Point CallboardHunter's arrow at a learned giver / turn-in location.
function Route.PointAtQuest(step)
  local d = DB()
  local rec = d.learned[NormTitle(step.quest)]
  local which = (step.phase == "accept") and "give" or "turn"
  local spot = rec and rec[which]
  if not spot then
    CBH.print(DIM .. "No location learned for " .. R .. BRIGHT .. step.quest .. R
      .. DIM .. " (" .. which .. ") yet -- do it once by hand and it is recorded "
      .. "for every later lap. Route says: " .. R .. (step.detail or "?"))
    return
  end
  if GetRealZoneText() ~= spot.zone then
    CBH.print("That one is in " .. BRIGHT .. spot.zone .. R .. DIM
      .. " -- port there first." .. R)
    return
  end
  local Arrow = CBH.Arrow
  if Arrow and Arrow.SetCustom then
    Arrow.SetCustom(spot.x, spot.y, spot.npc or step.quest)
    CBH.print("Arrow set to " .. BRIGHT .. (spot.npc or step.quest) .. R
      .. DIM .. string.format("  (%.1f, %.1f)", spot.x * 100, spot.y * 100) .. R)
  else
    CBH.print(string.format("%s is at %.1f, %.1f in %s.",
      spot.npc or step.quest, spot.x * 100, spot.y * 100, spot.zone))
  end
end

-- Shared by the full panel's Act button AND the compact panel's one-click
-- Advance -- there is only one "click the tier control and see if it took"
-- behaviour, and the compact panel is the DEFAULT view, so it needs the same
-- verification the full panel got or a failed switch is invisible there too.
-- Acking on success is belt-and-braces: StepDone's own tier check already
-- catches it, but latching the moment we know it worked means a flaky re-read
-- immediately afterward can't un-satisfy a step that genuinely just switched.
local function DoModeSwitch(step)
  local ok, why = Route.HcSwitch(step.tier)
  if ok then
    DB().acked[step.key] = true
    CBH.print("Now on " .. BRIGHT .. "Hardcore " .. step.tier .. R .. ".")
  else
    CBH.print(why)
  end
end

function Route.Act()
  local i = Route.Current()
  if not i then
    CBH.print("Route complete -- /cbh route reset starts the next lap.")
    return
  end
  local step = Route.Steps()[i]
  if step.kind == "port" then
    Route.PortTo(step.cp)
  elseif step.kind == "level" then
    Route.PortTo(step.cp)
  elseif step.kind == "quest" then
    Route.PointAtQuest(step)
  elseif step.kind == "mode" then
    DoModeSwitch(step)
  end
  Route.Refresh()
end

local function RefreshFull()
  local f = Route.panel
  if not f then return end
  local cur = Route.Current(true) -- read-only scan: never expand under a refresh
  local d = DB()

  f.sub:SetText(DIM .. "Lap " .. (d.laps + 1) .. "  |  level " .. UnitLevel("player")
    .. "  |  " .. tostring(GetRealZoneText()) .. R)

  for i, step in ipairs(Route.Steps()) do
    local row = f.rows[i]
    -- Current() guarantees everything before `cur` is satisfied, so index order
    -- IS the truth here. Re-testing each step would light up a later one just
    -- because you happen to be standing in its zone already.
    local done = (cur == nil) or (i < cur)
    local blocked = (i == cur) and StepBlocked(step) or nil
    local mark
    if done then
      mark = MARK_DONE
    elseif blocked then
      mark = MARK_BLOCKED
    elseif i == cur then
      mark = MARK_NOW
    elseif step.kind == "mode" then
      mark = MARK_MANUAL
    else
      mark = MARK_TODO
    end

    local body = step.text
    if step.kind == "port" then
      local info = Route.CpInfo(step.cp)
      if info and info.known then
        local tag = "cp " .. info.id
        if info.name and info.name ~= "?" then tag = tag .. ": " .. info.name end
        if info.unlocked == false then tag = tag .. " LOCKED" end
        if info.matches == false then tag = tag .. " NAME MISMATCH" end
        body = body .. DIM .. "  [" .. tag .. "]" .. R
      elseif info then
        body = body .. DIM .. "  [cp " .. info.id .. ", unverified]" .. R
      end
    elseif step.kind == "quest" then
      local x = d.xp[NormTitle(step.quest)]
      if x and x.to and x.from and x.to > x.from then
        body = body .. DIM .. "  [last lap " .. x.from .. "->" .. x.to .. "]" .. R
      end
    end

    local colour = done and VERD or ((i == cur) and BRIGHT or DIM)
    row:SetText(mark .. " " .. colour .. body .. R)
  end

  if cur then
    local step = Route.Steps()[cur]
    local blocked = StepBlocked(step)
    f.note:SetText((blocked and (EMBER .. "BLOCKED: " .. blocked .. R)
        or (GOLD .. "Now: " .. R .. BRIGHT .. step.text .. R))
      .. "\n" .. DIM .. (step.detail or "") .. R)
    local labels = {
      port = "Port there", quest = "Point me at it", mode = "How to switch",
      level = "Back to the zone",
    }
    f.act:SetText(labels[step.kind] or "Go")
    f.act:SetScript("OnClick", function() Route.Act() end)
    f.ack:SetText((step.kind == "mode") and "Mark done" or "Skip step")
  else
    f.note:SetText(VERD .. "Route complete." .. R .. "\n" .. DIM
      .. "Reset to start the next lap -- learned locations are kept." .. R)
    f.act:SetText("Reset lap")
    f.act:SetScript("OnClick", function() Route.Reset() end)
    f.ack:SetText("Mark done")
  end
end

-- ---------------------------------------------------------------------------
-- Compact mode: exactly ONE button, and one line telling you what to do next.
-- This is the default view. Everything else lives on a slash command or the
-- full checklist (/cbh route full) -- a second button on screen is a decision
-- you have to make mid-run, and the point here is not having to.
-- ---------------------------------------------------------------------------

-- The learned location for a quest step, if we have one yet.
local function StepSpot(step)
  if not (step and step.kind == "quest") then return nil end
  local rec = DB().learned[NormTitle(step.quest)]
  return rec and rec[(step.phase == "accept") and "give" or "turn"] or nil
end

-- Point CallboardHunter's arrow at the current step without being asked. Only
-- clears an arrow we set ourselves, so callboard routing is never stomped.
local arrowKey = nil
local function SyncArrow(step)
  local Arrow = CBH.Arrow
  if not (Arrow and Arrow.SetCustom) then return end
  local spot = StepSpot(step)
  if not spot or GetRealZoneText() ~= spot.zone then
    if arrowKey and Arrow.ClearCustom then Arrow.ClearCustom() end
    arrowKey = nil
    return
  end
  if arrowKey == step.key then return end
  arrowKey = step.key
  Arrow.SetCustom(spot.x, spot.y, spot.npc or step.quest)
end

-- Label for the one button plus the guide line under it.
-- Returns: label, kind, guide.
local function ActionFor(step, blocked)
  if not step then
    return "Start the next lap", "reset",
      "Route complete. Click to reset for the next prestige lap."
  end

  if step.kind == "port" then
    if blocked then return "Blocked", "port", blocked end
    local cp = Route.CP[step.cp]
    return "Port to " .. (cp and cp.label or "?"), "port",
      "Click the button. Stand still while it casts."

  elseif step.kind == "quest" then
    local spot = StepSpot(step)
    local verb = (step.phase == "accept") and "Pick up" or "Hand in"
    local auto = Route.AutoOn()
      and "  Just talk to them -- it accepts and hands in for you."
      or "  Talk to them and accept/hand in yourself (auto is off)."
    if spot and spot.npc then
      return "Target " .. spot.npc, "quest",
        verb .. " \"" .. step.quest .. "\" from " .. spot.npc .. " in " .. spot.zone
        .. string.format(" (%.0f, %.0f).", spot.x * 100, spot.y * 100)
        .. "  The button targets and marks them." .. auto
    end
    if spot then
      return "Point me there", "quest",
        verb .. " \"" .. step.quest .. "\" in " .. spot.zone
        .. string.format(" (%.0f, %.0f).", spot.x * 100, spot.y * 100) .. auto
    end
    return "Where is it?", "quest",
      verb .. " \"" .. step.quest .. "\" -- " .. (step.detail or "")
      .. "  Walk there once and the spot is remembered for every later lap."

  elseif step.kind == "level" then
    local lvl = UnitLevel("player") or 0
    local cp = Route.CP[step.cp]
    return "Level " .. lvl .. " / " .. step.target, "level",
      "Grind here until " .. step.target .. ". " .. (step.detail or "")
      .. (cp and ("  Button ports you back to " .. cp.label .. ".") or "")

  elseif step.kind == "mode" then
    return "Switch to Hardcore " .. step.tier, "mode",
      "CBH clicks the tier control on the run frame and checks it took. If the "
      .. "server's UI moves instead, finish it yourself in the popup, then "
      .. "/cbh route full and Mark done there."

  end
  return step.text, step.kind, (step.detail or "")
end

-- One click = do the next thing. `mode` used to be the only step with nothing
-- to do but confirm; now the click drives the same switch-and-verify as the
-- full panel's Act button (see DoModeSwitch) -- this is the DEFAULT view, so a
-- silently-failed switch would otherwise be invisible here.
function Route.Advance()
  local cur = Route.Current()
  if not cur then Route.Reset() return end
  local step = Route.Steps()[cur]
  if step.kind == "port" then
    Route.PortTo(step.cp)
  elseif step.kind == "level" then
    -- Nothing to do but kill things; the click is a way back if you strayed.
    Route.PortTo(step.cp)
  elseif step.kind == "quest" then
    Route.PointAtQuest(step)
  elseif step.kind == "mode" then
    DoModeSwitch(step)
  end
  Route.Refresh()
end

-- Undo one step, for the mis-click. Clears the latch AND the underlying record,
-- otherwise the step would just re-satisfy itself on the next refresh.
function Route.Back()
  local d = DB()
  local cur = Route.Current()
  local idx = (cur and cur - 1) or #Route.Steps()
  if idx < 1 then CBH.print("Already at the first step.") return end
  local step = Route.Steps()[idx]
  d.acked[step.key] = nil
  if step.kind == "quest" then d.turnedIn[NormTitle(step.quest)] = nil end
  if step.kind == "port" then
    d.suppress = d.suppress or {}
    d.suppress[step.key] = GetRealZoneText()
  end
  arrowKey = nil
  -- A port step re-satisfies from live state while you stand in its zone.
  -- Say so rather than looking like the click did nothing.
  if Route.Current() ~= idx then
    CBH.print(EMBER .. "Can't step back onto \"" .. step.text .. "\"" .. R .. DIM
      .. " -- it still reads as done from live state." .. R)
  else
    CBH.print("Back to: " .. BRIGHT .. step.text .. R)
  end
  Route.Refresh()
end

function Route.BuildMini()
  if Route.miniPanel then return Route.miniPanel end
  local f = CreateFrame("Frame", "CallboardHunterRouteMini", UIParent)
  f:SetWidth(264)
  f:SetHeight(128)
  f:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 20,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    CBH.db.route = CBH.db.route or {}
    local _, _, _, x, y = self:GetPoint()
    CBH.db.route.miniPos = { x = x, y = y }
  end)
  local mp = CBH.db.route and CBH.db.route.miniPos
  if mp then f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", mp.x, mp.y) end

  f.head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.head:SetPoint("TOPLEFT", 12, -11)
  f.head:SetPoint("RIGHT", f, "RIGHT", -26, 0)
  f.head:SetJustifyH("LEFT")

  -- THE button, and the only one. Secure, because targeting an NPC needs
  -- /targetexact from a macro (TargetUnit is protected) and Self-Execution
  -- needs a spell cast. Everything else routes through /run, so one button
  -- covers every step.
  --
  -- NOTE: never SetScript("OnClick") on this. SecureActionButtonTemplate wires
  -- its own OnClick to dispatch the action; replacing (or nil-ing) it silently
  -- kills the secure behaviour. All logic goes through macrotext instead.
  f.go = CreateFrame("Button", "CallboardHunterRouteGo", f,
    "SecureActionButtonTemplate,UIPanelButtonTemplate")
  f.go:SetWidth(240); f.go:SetHeight(34)
  f.go:SetPoint("TOPLEFT", 12, -27)
  f.go:RegisterForClicks("AnyUp")
  f.go:SetAttribute("type", "macro")

  f.guide = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.guide:SetPoint("TOPLEFT", 12, -66)
  f.guide:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  f.guide:SetJustifyH("LEFT")
  f.guide:SetJustifyV("TOP")
  f.guide:SetHeight(52)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

  -- Zone changes fire an event, but a port landing or a hand-in can settle
  -- between events; a one-second tick keeps the button honest.
  f.tick = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    self.tick = self.tick + elapsed
    if self.tick < 1.0 then return end
    self.tick = 0
    CBH.safeCall(Route.Refresh)
  end)
  f:SetScript("OnShow", function() Route.Refresh() end)
  f:Hide()
  Route.miniPanel = f
  return f
end

-- Secure attributes cannot be touched in combat, so changes are queued and
-- replayed on PLAYER_REGEN_ENABLED (the same shape CallboardHunter uses).
local pendingAttrs, appliedKey = nil, nil

local function ApplyAttrs(f, spec)
  local key = (spec.type or "-") .. "|" .. (spec.macrotext or spec.spell or "-")
  if key == appliedKey then return true end
  if InCombatLockdown() then
    pendingAttrs = spec
    return false
  end
  f.go:SetAttribute("type", spec.type)
  f.go:SetAttribute("macrotext", spec.macrotext)
  f.go:SetAttribute("spell", spec.spell)
  appliedKey = key
  pendingAttrs = nil
  return true
end

function Route.FlushAttrs()
  if not (pendingAttrs and Route.miniPanel) then return end
  if InCombatLockdown() then return end
  local spec = pendingAttrs
  pendingAttrs = nil
  appliedKey = nil
  ApplyAttrs(Route.miniPanel, spec)
  Route.Refresh()
end

-- What the button should DO for this step, as secure attributes.
local RUN = "/run CallboardHunter.Route."
local function AttrsFor(step, kind)
  if kind == "quest" then
    local npc = Route.StepSpotNpc(step)
    if npc then
      -- /targetexact, then mark it from Lua where the result can be checked.
      return { type = "macro",
               macrotext = "/targetexact " .. npc .. "\n" .. RUN .. "OnTargeted()" }
    end
  end
  return { type = "macro", macrotext = RUN .. "Advance()" }
end

local function RefreshMini()
  local f = Route.miniPanel
  if not f then return end
  local cur = Route.Current(true) -- read-only scan: never expand under a ticker
  local step = cur and Route.Steps()[cur] or nil
  local blocked = step and StepBlocked(step) or nil
  local label, kind, guide = ActionFor(step, blocked)

  SyncArrow(step)

  f.head:SetText(GOLD
    .. (cur and ("Step " .. cur .. "/" .. #Route.Steps()) or "Route complete") .. R
    .. DIM .. "   lvl " .. UnitLevel("player") .. "  " .. tostring(GetRealZoneText())
    .. (Route.AutoOn() and "" or "  [auto OFF]") .. R)

  local ok = ApplyAttrs(f, AttrsFor(step, kind))
  f.go:SetText(label .. (ok and "" or DIM .. "  (in combat)" .. R))
  if blocked then f.go:Disable() else f.go:Enable() end

  f.guide:SetText((blocked and (EMBER .. guide .. R)) or (DIM .. guide .. R))
end

function Route.SetMode(mini)
  local d = DB()
  d.mini = mini and true or false
  Route.Build(); Route.BuildMini()
  if mini then Route.panel:Hide(); Route.miniPanel:Show()
  else Route.miniPanel:Hide(); Route.panel:Show() end
end

function Route.Refresh()
  if Route.panel and Route.panel:IsShown() then RefreshFull() end
  if Route.miniPanel and Route.miniPanel:IsShown() then RefreshMini() end
end

function Route.Toggle()
  Route.Build(); Route.BuildMini()
  local d = DB()
  local mini = (d.mini ~= false)
  local f = mini and Route.miniPanel or Route.panel
  local other = mini and Route.panel or Route.miniPanel
  other:Hide()
  if f:IsShown() then f:Hide() else f:Show() end
end

-- newRun: reset triggered by a death/restart rather than by hand. The route is
-- the levelling leg start to finish, so a new run simply starts it over -- there
-- is no preamble left to skip past.
function Route.Reset(quiet, newRun)
  local d = DB()
  d.laps = (d.laps or 0) + 1
  d.acked, d.turnedIn, d.suppress = {}, {}, {}
  if not quiet then
    CBH.print("Route reset -- lap " .. GOLD .. (d.laps + 1) .. R .. DIM
      .. ". Learned locations and checkpoint names are kept." .. R)
  end
  Route.Refresh()
end

-- ---------------------------------------------------------------------------
-- Chat report + diagnostics
-- ---------------------------------------------------------------------------

function Route.Report()
  local cur = Route.Current()
  local d = DB()
  Say(GOLD .. "Prestige Route" .. R .. DIM .. "  lap " .. (d.laps + 1)
    .. " | level " .. UnitLevel("player") .. " | " .. tostring(GetRealZoneText()) .. R)
  for i, step in ipairs(Route.Steps()) do
    local done = (cur == nil) or (i < cur)
    local mark = done and MARK_DONE or ((i == cur) and MARK_NOW or MARK_TODO)
    Say("  " .. mark .. " " .. (done and VERD or ((i == cur) and BRIGHT or DIM))
      .. step.text .. R)
  end
  if cur then Say(DIM .. "  -> " .. (Route.Steps()[cur].detail or "") .. R) end
end

-- Everything the addon believes about the step you are stuck on, so a "why
-- won't this go" question has an answer instead of a guess.
function Route.Why()
  local cur = Route.Current()
  local d = DB()
  local qlog = ScanQuestLog(true)
  Say(GOLD .. "Route diagnosis" .. R)
  if not cur then Say("  Route is complete."); return end
  local step = Route.Steps()[cur]
  Say("  Step " .. cur .. "/" .. #Route.Steps() .. ": " .. BRIGHT .. step.text .. R)
  Say("  kind=" .. step.kind .. (step.phase and ("  phase=" .. step.phase) or ""))
  Say("  zone: " .. BRIGHT .. tostring(GetRealZoneText()) .. R
    .. DIM .. "   level " .. UnitLevel("player") .. R)

  if step.kind == "quest" then
    local entry = QFind(qlog, step.quest)
    Say("  quest: " .. BRIGHT .. step.quest .. R)
    Say("    in your log: " .. (entry and (VERD .. "yes" .. R) or (EMBER .. "NO" .. R))
      .. (entry and ("   complete: " .. (entry.complete and (VERD .. "yes" .. R)
          or (EMBER .. "no" .. R))) or ""))
    Say("    marked handed in: "
      .. (d.turnedIn[NormTitle(step.quest)] and (VERD .. "yes" .. R) or (DIM .. "no" .. R)))
    local npc = Route.StepSpotNpc(step)
    Say("    learned NPC: " .. (npc and (BRIGHT .. npc .. R) or (DIM .. "none yet" .. R)))
    Say("    auto accept/turn-in: "
      .. (Route.AutoOn() and (VERD .. "ON" .. R) or (EMBER .. "OFF" .. R)))
    -- The titles the client is actually reporting, so a spelling mismatch is
    -- visible rather than mysterious.
    Say(DIM .. "    titles currently in your log:" .. R)
    local n = 0
    for title in pairs(qlog) do
      n = n + 1
      if n <= 12 then Say(DIM .. "      " .. title .. R) end
    end
    if n == 0 then Say(DIM .. "      (none)" .. R) end
  elseif step.kind == "level" then
    Say("  need level " .. BRIGHT .. step.target .. R .. DIM
      .. "   you are " .. (UnitLevel("player") or 0) .. R)
    Say(DIM .. "    retune with /cbh route grind " .. step.target .. R)
  elseif step.kind == "port" then
    local info = Route.CpInfo(step.cp)
    Say("  checkpoint " .. (info and info.id or "?") .. ": "
      .. (info and info.known and (BRIGHT .. tostring(info.name) .. R
          .. (info.unlocked == false and (EMBER .. " LOCKED" .. R) or (VERD .. " unlocked" .. R)))
        or (DIM .. "not harvested -- open the world map" .. R)))
    Say("  need to be in: " .. BRIGHT .. Route.CP[step.cp].zone .. R)
  end

  local ld = d.lastDetect
  if ld then
    Say(DIM .. "  last hand-in seen: " .. tostring(ld.title)
      .. " via " .. tostring(ld.how) .. R)
  end
  Say(DIM .. "  Stuck anyway? " .. R .. GOLD .. "/cbh route ok" .. R .. DIM
    .. " ticks this step off by hand." .. R)
end

function Route.Api()
  Say(GOLD .. "Route API probe" .. R)
  local PE = _G.ProjectEbonhold
  Say("  ProjectEbonhold:  " .. (PE and (VERD .. "present" .. R) or (EMBER .. "MISSING" .. R)))
  Say("  sendToServer:     " .. ((PE and type(PE.sendToServer) == "function")
    and (VERD .. "yes" .. R) or (EMBER .. "no" .. R)))
  Say("  CS.REQUEST_USE_CHECKPOINT: "
    .. ((PE and PE.CS and PE.CS.REQUEST_USE_CHECKPOINT ~= nil)
        and (VERD .. tostring(PE.CS.REQUEST_USE_CHECKPOINT) .. R) or (EMBER .. "no" .. R)))
  Say("  CallboardHunter fallback:  "
    .. ((CBH.HasCallboardHunter and CBH.HasCallboardHunter())
        and (VERD .. "yes" .. R) or (DIM .. "no" .. R)))
  Say("  Checkpoints known: " .. GOLD .. Route.CpCount() .. R .. DIM
    .. "  (open the world map, then /cbh route cpscan)" .. R)
  for _, k in ipairs({ "DALARAN", "ZULDRAK", "BOREAN" }) do
    local info = Route.CpInfo(k)
    if info and info.known then
      Say("    " .. info.id .. " -> " .. BRIGHT .. tostring(info.name) .. R
        .. (info.unlocked == false and (EMBER .. " LOCKED" .. R) or (VERD .. " unlocked" .. R))
        .. ((info.matches == false)
            and (EMBER .. "  (does not look like " .. info.zone .. ")" .. R) or ""))
    elseif info then
      Say("    " .. info.id .. " -> " .. DIM .. "unverified (" .. info.label .. ")" .. R)
    end
  end
end

function Route.Macros()
  Say(GOLD .. "Route macros" .. R .. DIM
    .. "  (if you would rather use macros than the panel)" .. R)
  for _, k in ipairs({ "DALARAN", "ZULDRAK", "BOREAN" }) do
    local cp = Route.CP[k]
    Say("  " .. BRIGHT .. cp.label .. R)
    Say("    " .. Route.PortMacro(cp.id))
  end
end

function Route.ListCheckpoints()
  local d = DB()
  local ids = {}
  for id in pairs(d.checkpoints) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
  if #ids == 0 then
    CBH.print("No checkpoints harvested yet -- open the world map, then /cbh route cpscan.")
    return
  end
  Say(GOLD .. "Known checkpoints (" .. #ids .. ")" .. R)
  for _, id in ipairs(ids) do
    local c = d.checkpoints[id]
    Say("  " .. id .. "  "
      .. ((c.unlocked == false) and (EMBER .. "[LOCKED]" .. R) or (VERD .. "[open]" .. R))
      .. " " .. tostring(c.name))
  end
end

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

function Route.Command(arg)
  local raw = arg or ""
  local cmd, rest = string.match(raw, "^(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  if cmd == "" or cmd == "show" then
    Route.Toggle()
  elseif cmd == "status" or cmd == "list" then
    Route.Report()
  elseif cmd == "next" or cmd == "go" then
    Route.Build(); Route.BuildMini(); Route.Advance()
  elseif cmd == "mini" or cmd == "compact" then
    Route.SetMode(true)
  elseif cmd == "full" or cmd == "steps" then
    Route.SetMode(false)
  elseif cmd == "back" or cmd == "undo" then
    Route.Build(); Route.BuildMini(); Route.Back()
  elseif cmd == "why" or cmd == "debug" then
    Route.Why()
  elseif cmd == "forget" then
    -- Learned NPC/coords can be wrong (before v0.74 a missing dialog NPC fell
    -- back to whatever you had targeted). This throws the bad one away so the
    -- next real hand-in records the right one.
    local d = DB()
    if string.lower(rest) == "all" then
      d.learned = {}
      CBH.print("Forgot every learned quest location. They re-learn as you do the chain.")
    else
      local cur = Route.Current()
      local step = cur and Route.Steps()[cur]
      if step and step.kind == "quest" then
        d.learned[NormTitle(step.quest)] = nil
        CBH.print("Forgot the learned location for " .. BRIGHT .. step.quest .. R
          .. DIM .. ". It re-learns next time you actually hand it in." .. R)
      else
        CBH.print("Current step isn't a quest. Use /cbh route forget all to clear them all.")
      end
    end
    Route.Refresh()
  elseif cmd == "mark" then
    local n = tonumber(rest)
    CBH.db.options = CBH.db.options or {}
    if n and n >= 1 and n <= 8 then
      CBH.db.options.routeMark = n
      CBH.print("Step marker set to #" .. n .. ".")
    else
      CBH.print("Usage: /cbh route mark <1-8>  (1 star, 2 circle, 3 diamond, "
        .. "4 triangle, 5 moon, 6 square, 7 cross, 8 skull; currently "
        .. Route.MarkIndex() .. ")")
    end
  elseif cmd == "grind" then
    -- Retune a level band. Applies to whichever grind step you are on, so
    -- "/cbh route grind 74" while in Borean Tundra moves that hand-off later.
    local n = tonumber(rest)
    local cur = Route.Current()
    local step = cur and Route.Steps()[cur]
    if not (step and step.kind == "level") then
      CBH.print("Stand on a levelling step first (Borean Tundra or Icecrown)."
        .. DIM .. "  Current bands: " .. Route.GrindTarget("grindBt", 72) .. " then "
        .. Route.GrindTarget("grindIce", 80) .. "." .. R)
    elseif n and n >= 2 and n <= 80 then
      local d = DB()
      d.grind = d.grind or {}
      d.grind[step.key] = n
      CBH.print("Levelling band set: leave " .. (Route.CP[step.cp] and Route.CP[step.cp].zone
        or "?") .. " at " .. GOLD .. n .. R .. ".")
    else
      CBH.print("Usage: " .. GOLD .. "/cbh route grind <level>" .. R)
    end
    Route.Refresh()
  elseif cmd == "hc" or cmd == "hardcore" then
    local d = DB()
    local a = string.lower(rest or "")
    if a == "off" or a == "none" then
      d.hc = "off"
      CBH.print("Hardcore steps removed from the route." .. DIM
        .. "  The route is now purely: port, quests, port." .. R)
    else
      local n = tonumber(a)
      if n and n >= 0 and n <= 10 then
        d.hc, d.hcStart = nil, n
        if (tonumber(d.hcEnd) or 3) > n then d.hcEnd = n end
        CBH.print("Levelling on Hardcore " .. GOLD .. n .. R .. DIM
          .. ".  The route's own guide says 5; use whatever tier you have unlocked."
          .. R)
      else
        CBH.print("Usage: " .. GOLD .. "/cbh route hc <tier>" .. R .. " or "
          .. GOLD .. "/cbh route hc off" .. R .. DIM .. "  (currently "
          .. (Route.HcEnabled() and ("HC" .. Route.HcTier("start") .. " -> HC"
              .. Route.HcTier("end")) or "off") .. ")" .. R)
      end
    end
    Route.Refresh()
  elseif cmd == "auto" then
    local d = DB()
    d.auto = not Route.AutoOn()
    CBH.print("Auto accept / turn-in: " .. (d.auto and (VERD .. "ON" .. R) or (EMBER .. "OFF" .. R))
      .. DIM .. " -- only ever fires for the three route quests, and only in a "
      .. "dialog you opened yourself." .. R)
    Route.Refresh()
  elseif cmd == "ok" or cmd == "done" then
    Route.Build(); Route.Ack()
  elseif cmd == "reset" or cmd == "lap" then
    Route.Build(); Route.Reset()
  elseif cmd == "cpscan" then
    Route.CpScan(true); Route.Refresh()
  elseif cmd == "checkpoints" then
    Route.ListCheckpoints()
  elseif cmd == "api" or cmd == "probe" then
    Route.Api()
  elseif cmd == "macro" or cmd == "macros" then
    Route.Macros()
  elseif cmd == "cp" then
    local id = string.match(rest, "^(%d+)$")
    if not id then
      CBH.print("Usage: /cbh route cp <checkpoint id>")
      return
    end
    if Route.HasServerPort() then
      local PE = _G.ProjectEbonhold
      pcall(PE.sendToServer, PE.CS.REQUEST_USE_CHECKPOINT, id)
      CBH.print("Requested checkpoint " .. id .. ".")
    else
      CBH.print("Server checkpoint call unavailable. Macro:")
      Say("  " .. BRIGHT .. Route.PortMacro(id) .. R)
    end
  elseif cmd == "exec" then
    -- Self-Execution belongs to the prestige loop, not to levelling, so it is
    -- no longer a route step. It is one line in a macro; here it is.
    CBH.print("Self-Execution isn't part of the levelling route. Bind this:")
    Say("  " .. BRIGHT .. "/cast Self-Execution" .. R)
  else
    CBH.print("Route: " .. GOLD .. "/cbh route" .. R .. " panel | " .. GOLD .. "why" .. R
      .. " diagnose a stuck step | " .. GOLD .. "forget" .. R .. " re-learn the NPC | "
      .. GOLD .. "auto" .. R .. " | " .. GOLD .. "hc <tier|off>" .. R .. " | "
      .. GOLD .. "grind <level>" .. R .. " | "
      .. GOLD .. "mark <1-8>" .. R .. " | "
      .. GOLD .. "next" .. R
      .. " do the step | " .. GOLD .. "back" .. R .. " undo | " .. GOLD .. "full" .. R
      .. "/" .. GOLD .. "mini" .. R .. " view | " .. GOLD .. "ok" .. R .. " mark done | "
      .. GOLD .. "reset" .. R .. " new lap | " .. GOLD .. "cpscan" .. R .. " | "
      .. GOLD .. "checkpoints" .. R .. " | " .. GOLD .. "cp <id>" .. R .. " | "
      .. GOLD .. "api" .. R .. " | " .. GOLD .. "macro" .. R .. " | " .. GOLD .. "exec" .. R)
  end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

-- This ran as a PallyPilot module before it moved in here. Carry the state
-- across once: harvested checkpoint ids/names and learned quest givers are the
-- expensive part -- rebuilding them costs a real lap.
function Route.MigrateFromPallyPilot()
  local old = _G.PallyPilotDB and _G.PallyPilotDB.route
  if type(old) ~= "table" then return false end
  local mine = DB()
  if mine.migrated or mine.laps or next(mine.checkpoints or {}) then return false end
  for k, v in pairs(old) do mine[k] = v end
  mine.migrated = true
  local n = 0
  for _ in pairs(mine.checkpoints or {}) do n = n + 1 end
  CBH.print("Route moved into CallboardHunter -- carried over " .. n
    .. " checkpoints and your learned quest givers. Use " .. GOLD .. "/cbh route" .. R .. ".")
  return true
end

function Route.Init()
  Route.Build()
  Route.BuildMini()

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("QUEST_ACCEPTED")
  ev:RegisterEvent("QUEST_COMPLETE")
  ev:RegisterEvent("QUEST_LOG_UPDATE")
  ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  -- Auto accept / turn-in, route quests only (see the section above).
  ev:RegisterEvent("GOSSIP_SHOW")
  ev:RegisterEvent("QUEST_GREETING")
  ev:RegisterEvent("QUEST_DETAIL")
  ev:RegisterEvent("QUEST_PROGRESS")
  -- The server's own "<quest> completed." line: the most reliable hand-in
  -- signal on this client.
  ev:RegisterEvent("CHAT_MSG_SYSTEM")
  -- Secure attributes queued during combat get replayed here.
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "QUEST_ACCEPTED" then
      CBH.safeCall(OnQuestAccepted)
    elseif event == "QUEST_COMPLETE" then
      -- Record first (level/coords), then take the reward.
      CBH.safeCall(OnQuestComplete)
      CBH.safeCall(OnQuestCompleteAuto)
    elseif event == "QUEST_LOG_UPDATE" then
      CBH.safeCall(OnQuestLogUpdate)
    elseif event == "GOSSIP_SHOW" then
      CBH.safeCall(OnGossipShow)
    elseif event == "QUEST_GREETING" then
      CBH.safeCall(OnQuestGreeting)
    elseif event == "QUEST_DETAIL" then
      CBH.safeCall(OnQuestDetail)
    elseif event == "QUEST_PROGRESS" then
      CBH.safeCall(OnQuestProgress)
    elseif event == "CHAT_MSG_SYSTEM" then
      CBH.safeCall(OnSystemMessage, arg1)
    elseif event == "PLAYER_REGEN_ENABLED" then
      CBH.safeCall(Route.FlushAttrs)
    else
      CBH.safeCall(Route.Refresh)
    end
  end)

  -- A fresh run resets the lap on its own: the level collapsing back to the low
  -- single digits is the unambiguous "you died and restarted" signal.
  local lastLevel = UnitLevel("player")
  local lvlWatch = CreateFrame("Frame")
  lvlWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
  lvlWatch:RegisterEvent("PLAYER_LEVEL_UP")
  lvlWatch:SetScript("OnEvent", function()
    local lvl = UnitLevel("player")
    if lastLevel and lvl and lvl < lastLevel - 10 and lvl < 10 then
      Route.Reset(true, true)
      CBH.print(GOLD .. "New run detected" .. R .. DIM
        .. " -- route reset to the levelling leg. " .. R .. GOLD .. "/cbh route" .. R)
    end
    lastLevel = lvl
  end)

  -- Harvest checkpoint ids whenever the map opens. Free, and it is what turns
  -- "310" into "Dalaran, unlocked" on the panel.
  if WorldMapFrame and WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function() CBH.safeCall(Route.CpScan, false) end)
  end
end
