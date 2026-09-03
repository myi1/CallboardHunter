-- CallboardHunter Advisor: annotates the Objectives Board cards and finds
-- checkpoint teleports on the world map. Frame names discovered via /cbh frames:
-- cards = ObjectivesMainFrame > ObjectiveFrame1..3 (anonymous Select buttons);
-- checkpoints = anonymous Buttons on WorldMapButton (Blizzard POIs are named).
local CBH = CallboardHunter
local Advisor = CBH.Advisor or {}
CBH.Advisor = Advisor

-- ---------------------------------------------------------------- card advisor

-- Usage log: every port decision writes to SavedVariables so bugs can be
-- analyzed offline from a whole session at once (/cbh log to view in-game).
function CBH.Log(cat, msg)
   if not CBH.db then return end
   CBH.db.log = CBH.db.log or {}
   local l = CBH.db.log
   l[#l + 1] = { t = time(), when = date("%H:%M:%S"),
                 zone = GetRealZoneText(), cat = cat, msg = msg }
   while #l > 500 do table.remove(l, 1) end
end

local function CardTexts(card)
   local texts = {}
   for i = 1, select("#", card:GetRegions()) do
      local r = select(i, card:GetRegions())
      -- Skip the note WE attached to this card, or the catalogue records our own
      -- annotations as if they were callboard text (1.9.7 shipped exactly that
      -- bug). The star's label needs no matching check here: UI.Text parents
      -- it to card.cbhStar, the button - a child FRAME of card - and
      -- GetRegions() only enumerates regions parented directly to card, never
      -- descending into child frames. That structural fact is what keeps the
      -- star out of this list, not an entry in this condition.
      if r ~= card.cbhNote
         and r and r.GetObjectType and r:GetObjectType() == "FontString" then
         local t = r:GetText()
         if t and t ~= "" then table.insert(texts, t) end
      end
   end
   return texts
end

local function CountPoints(zone, name)
   local mobs = CBH.db and CBH.db.learnedKills and CBH.db.learnedKills[zone]
   local list = mobs and mobs[name]
   return list and #list or 0
end

-- Card shapes this server actually deals. "Kill 10 Azure Manashaper in
-- Crystalsong Forest." was the only one BuildNote ever learned from, but a
-- new user's real card read "10 Earthbound Revenant in Wintergrasp" - no
-- verb at all - and matched nothing. cardZones never learned Wintergrasp for
-- that objective, so it had no vote against this server's Winterspring
-- quest-log header (see the "Thinning the Herd" case below), and the player
-- got ported across the world. "Slay" covers the same shape with the other
-- verb seen on this board; kept short rather than guessing at more.
local KILL_CARD_PATTERNS = {
   "^Kill (%d+) (.-) in (.-)%.?$",
   "^Slay (%d+) (.-) in (.-)%.?$",
   "^(%d+) (.-) in (.-)%.?$",
}

local function BuildNote(desc)
   -- Rare-hunt cards mention "Rare" ("3 Rare creatures in Icecrown" is a real
   -- shape) and, since the verb-less pattern below exists, that shape ALSO
   -- fits "<n> <mob> in <zone>" - "Icecrown" is a real map zone, so it would
   -- otherwise be swallowed as a kill objective (writing the nonsense mob key
   -- "Rare creatures" into cardZones and showing "no camp data" instead of
   -- the rare stamp). Checked first so a rare card can never be shadowed by a
   -- shape that only exists to harvest kill objectives.
   if string.find(string.lower(desc), "rare") then
      return CBH.UI.Stamp("active", true) .. " " .. CBH.UI.Colour("ink", "rare hunt")
   end
   local n, mob, zoneRaw
   for _, pat in ipairs(KILL_CARD_PATTERNS) do
      local _, _, a, b, c = string.find(desc, pat)
      if b then n, mob, zoneRaw = a, b, c; break end
   end
   if mob then
      -- "in" is an ordinary word ("Collect 5 Frozen Orb in the Nexus" fits the
      -- same shape), so the raw capture is trusted only once it names an EXACT
      -- real map zone - which also normalises whatever casing the card used.
      local zone = CBH.SpawnDB.KnownMapZone and CBH.SpawnDB.KnownMapZone(zoneRaw)
      -- A failed check refuses only the WRITE, not the note: fall through to
      -- the branches below instead of ending the function here, or a real
      -- dungeon/raid card like "Slay 10 Scourge in Naxxramas." (Naxxramas is
      -- not an outdoor map zone, so it correctly fails this check) would lose
      -- its "Dungeon/raid:" note along with the write it was right to refuse.
      if zone then
         if CBH.db then
            CBH.db.cardZones[mob] = zone
            if CBH.db.cardZoneVerified then CBH.db.cardZoneVerified[mob] = true end
         end
         local pts = CountPoints(zone, mob)
         local here = (GetRealZoneText() == zone) and " (current zone)" or ""
         if pts > 0 then
            return CBH.UI.Stamp("ready", true) .. " " .. CBH.UI.Colour("ink",
               pts .. " known spot" .. (pts > 1 and "s" or "") .. " in " .. zone .. here)
         end
         return CBH.UI.Stamp("idle", true) .. " " .. CBH.UI.Colour("inkSoft",
            "no camp data - " .. zone .. here)
      end
   end
   -- "Slay Kelthuzad in Naxxramas."
   local _, _, boss, place = string.find(desc, "^Slay (.-) in (.-)%.?$")
   if boss then
      return CBH.UI.Colour("inkSoft", "Dungeon/raid: " .. place)
   end
   -- "Collect 40 Icethorn."
   local _, _, cn, item = string.find(desc, "^Collect (%d+) (.-)%.?$")
   if item then
      return CBH.UI.Colour("inkSoft", "Collection: " .. item)
   end
   return nil
end
Advisor.BuildNote = BuildNote  -- exposed so tests can harvest a card in isolation

local function RefreshCards()
   for i = 1, 3 do
      local card = _G["ObjectiveFrame" .. i]
      if card and card:IsShown() then
         local note
         for _, t in ipairs(CardTexts(card)) do
            -- Catalogue EVERY card, not just the ones BuildNote can parse.
            if CBH.RecordCard then CBH.RecordCard(t) end
            if not note then note = BuildNote(t) end
         end
         if not card.cbhNote then
            -- Ink: this FontString sits on the server's light card art.
            -- Ink: this FontString sits on the server's light card art. Sized a
            -- tier up from meta because it competes with a busy parchment
            -- texture, and only 16px narrower than the card - at -50 the stamp
            -- glyph clipped off the left edge and the line wrapped early.
            card.cbhNote = CBH.UI.Text(card, "label", CBH.UI.INK, CBH.UI.FONT_META)
            card.cbhNote:SetPoint("BOTTOM", card, "BOTTOM", 0, 92) -- clear of the Select button
            card.cbhNote:SetWidth(card:GetWidth() - 16)
            card.cbhNote:SetJustifyH("CENTER")
         end
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
                  self.label:SetText(CBH.Favourites.StarText(self.cbhTarget, true))
               end
            end)
         end
         local title = CardTexts(card)[1]
         local target = title and CBH.SpawnDB.TargetOf(title) or nil
         card.cbhStar.cbhTarget = target
         if target then
            card.cbhStar.label:SetText(CBH.Favourites.StarText(target, true))
            card.cbhStar:Show()
         else
            card.cbhStar:Hide()
         end
         card.cbhNote:SetText(note or "")
      end
   end
end

-- ------------------------------------------------------------- port button

local portBtn
local function EnsurePortButton()
   if portBtn or not (CBH.db and CBH.db.options) then return end
   -- A stamped travel order rather than a stock stone button: the destination
   -- is what CBH exists to answer, so it IS the button's content and the focal
   -- element of the whole addon.
   portBtn = CreateFrame("Button", "CallboardHunterPortButton", UIParent)
   CBH.UI.SkinButton(portBtn, { accent = true, height = 26, minWidth = 132 })
   portBtn:SetLabel("Checkpoint")
   portBtn:SetMovable(true)
   portBtn:RegisterForDrag("RightButton") -- right-drag moves, left-click ports
   portBtn:SetScript("OnDragStart", function(self) self:StartMoving() end)
   portBtn:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local _, _, _, x, y = self:GetPoint()
      CBH.db.options.portBtnPos = { x = x, y = y }
   end)
   local pos = CBH.db.options.portBtnPos
   if pos then portBtn:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
   else portBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 130) end
   portBtn:SetScript("OnClick", function(self)
      if self.mode == "board" then
         CBH.safeCall(Advisor.PortToCallboard)
      else
         CBH.safeCall(Advisor.Port)
      end
   end)
   portBtn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      if self.mode == "board" then
         GameTooltip:AddLine(CBH.UI.Colour("primary", "Return to the callboard"))
         GameTooltip:AddLine("Left-click: port to the checkpoint nearest a callboard you have used.", 1, 1, 1, true)
      else
         GameTooltip:AddLine(CBH.UI.Colour("primary", "Travel order"))
         GameTooltip:AddLine("Left-click: port to the checkpoint nearest your callboard objective.", 1, 1, 1, true)
      end
      GameTooltip:AddLine("Right-click drag: move this button.", 0.7, 0.7, 0.7, true)
      GameTooltip:Show()
   end)
   portBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
   portBtn:Hide()
end

-- Remember where callboards are: called while an Objectives Board is open.
local function LearnCallboard()
   if not (CBH.db and CBH.db.callboards) then return end
   -- A board summoned inside a dungeon is temporary and unreachable; recording it
   -- pollutes the Port: Callboard list with somewhere you can never go back to.
   if IsInInstance and IsInInstance() then return end
   if CBH.IsPortableCallboardZone
      and not CBH.IsPortableCallboardZone(GetRealZoneText()) then return end
   if not WorldMapFrame:IsShown() then SetMapToCurrentZone() end
   local x, y = GetPlayerMapPosition("player")
   if not x or (x == 0 and y == 0) then return end
   local zone = GetRealZoneText()
   for _, b in ipairs(CBH.db.callboards) do
      if b.zone == zone then
         local dx, dy = b.x - x, b.y - y
         if (dx * dx + dy * dy) < 0.0009 then return end -- same board
      end
   end
   table.insert(CBH.db.callboards, { zone = zone, x = x, y = y })
   CBH.print("Callboard location learned: " .. zone .. ". The port button can bring you back here.")
end

-- Is this kill objective callboard work? Judged on the QUEST TITLE, not the
-- target name: "The Maddening Deep" (a Maerys meta-quest) and the callboard's
-- "Topple the Tyrant: Yogg-Saron" name the same boss, and only the second is a
-- board contract. Matching on the name alone let the first through.
local function IsCallboardKill(name, ko)
   local title = ko and ko.questIndex and GetQuestLogTitle
      and (GetQuestLogTitle(ko.questIndex)) or nil
   return CBH.IsCallboardQuest and CBH.IsCallboardQuest(title, name) or false
end

local function AnyObjectiveActive()
   -- Completed rare quests don't count, or the button stays stuck on
   -- "Port: <zone>" forever instead of falling back to Home/Callboard.
   for _, info in pairs(CBH.hotZones or {}) do
      if not info.done then return true end
   end
   local cbOnly = CBH.CallboardOnlyActive and CBH.CallboardOnlyActive()
   for name, ko in pairs(CBH.killObjectives or {}) do
      if not ko.need or (ko.have or 0) < ko.need then
         if not cbOnly or IsCallboardKill(name, ko) then return true end
      end
   end
   return false
end

-- What the port button should say, and which mode a click uses. Extracted from
-- the ticker so it can be tested without a running UI.
--
-- The button only claims "objective" when it can name a real destination. CBH
-- recognises any "<name> slain: n/m" objective, which also matches ordinary
-- quests - "Anub'Rekhan slain: 0/1" from Naxxramas, for one. With no callboard
-- quest at all the button used to sit on a dead "Port: objective" that simply
-- refused when clicked, instead of offering Home. If nothing resolves, fall
-- through to Home/Callboard; /cbh port still explains why an objective could not
-- be routed.
function Advisor.ComputeButton()
   local destZone, via
   -- ResolveDestination clears this itself, but it is not called at all when no
   -- objective is active - which is exactly when a leftover target does harm,
   -- since /cbh portvia would then save a pick under a quest you have already
   -- turned in. This ticker is what notices the quest log emptying, so it is
   -- what has to clear it.
   Advisor.lastDestTarget = nil
   if AnyObjectiveActive() and Advisor.ResolveDestination then
      local d, _, _, _, v = Advisor.ResolveDestination()
      destZone, via = d, v
   end
   if destZone then Advisor.lastDestZone = destZone end
   -- Show the forced checkpoint when an objective routes to a specific one
   -- (e.g. "Port: Fordragon Hold"), otherwise the destination zone. A curated
   -- `via` may be a list of faction alternatives, so it is rendered rather than
   -- concatenated - and the player's own pick, if they made one, is what the
   -- button should promise, since that is what DoPort will actually use.
   -- Gated on destZone, NOT on the pick. A saved pick outlives the quest it was
   -- made for, so reading it first would keep this button in "objective" mode
   -- with a checkpoint for a quest you already turned in - re-creating the dead
   -- "Port: objective" button described above, and hiding Home behind it.
   local shown
   if destZone then
      -- A multi-name via is a faction pair, and which one exists is only known
      -- once the map is scanned. Promise the zone rather than a base the
      -- player may not even be able to use; a single name is still shown.
      local promise = via
      if type(promise) == "table" and #promise ~= 1 then promise = nil end
      shown = Advisor.PortTargetViaFor(Advisor.lastDestTarget) or promise or destZone
   end
   if shown then return "Port: " .. Advisor.ViaText(shown), "objective" end
   if CBH.db and CBH.db.home then return "Port: Home", "board" end
   if CBH.db and CBH.db.callboards and #CBH.db.callboards > 0 then
      return "Port: Callboard", "board"
   end
   return nil, nil
end

-- Poll for the server frame (created by the ProjectEbonhold addon at its own
-- pace) and keep card notes fresh while the board is open (reroll swaps text
-- without hiding the frame).
local ticker = CreateFrame("Frame")
ticker.t = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
   self.t = self.t + elapsed
   if self.t < 0.5 then return end
   self.t = 0
   local board = _G["ObjectivesMainFrame"]
   if board and board:IsShown() then
      CBH.safeCall(RefreshCards)
      CBH.safeCall(LearnCallboard)
   end
   -- Dungeon automation runs off the same board polling (opt-in, instances only).
   if CBH.Dungeon and CBH.Dungeon.Poll then
      CBH.safeCall(CBH.Dungeon.Poll, GetTime())
   end
   -- Favourites hunt: explicit-start only (/cbh hunt), so this just drives a run
   -- that is already live rather than deciding on its own to start one.
   if CBH.Favourites and CBH.Favourites.Poll then
      CBH.safeCall(CBH.Favourites.Poll, GetTime())
   end
   if Advisor.portAt and GetTime() >= Advisor.portAt then
      Advisor.portAt = nil
      CBH.safeCall(Advisor.DoPort)
   end
   CBH.safeCall(EnsurePortButton)
   if portBtn then
      local label, mode = Advisor.ComputeButton()
      if label then
         portBtn.mode = mode
         -- The button names the place, not the verb: "Fordragon Hold", not
         -- "Port: objective". Strip the prefix the label still carries.
         local shown = string.gsub(label, "^Port:%s*", "")
         if portBtn:GetLabel() ~= shown then portBtn:SetLabel(shown) end
         local usable = not InCombatLockdown()
         if usable then portBtn:Enable() else portBtn:Disable() end
         portBtn:SetEnabledLook(usable)
         portBtn:Show()
      else
         portBtn:Hide()
      end
   end
end)

-- ------------------------------------------------------------- checkpoint port

-- Invoke a button's OnEnter to populate its tooltip. 3.3.5-era scripts often
-- read the legacy global `this` instead of self, so set it for the call.
local function ReadTooltip(c)
   local onEnter = c:GetScript("OnEnter")
   if not onEnter then return nil, nil, false end
   local prevThis = this
   this = c
   local ok = pcall(onEnter, c)
   this = prevThis
   -- Map elements in 3.3.5 use WorldMapTooltip, everything else GameTooltip.
   local l1 = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText() or ""
   local l2 = GameTooltipTextLeft2 and GameTooltipTextLeft2:GetText() or ""
   if l1 == "" and l2 == "" and WorldMapTooltipTextLeft1 then
      l1 = WorldMapTooltipTextLeft1:GetText() or ""
      l2 = (WorldMapTooltipTextLeft2 and WorldMapTooltipTextLeft2:GetText()) or ""
   end
   -- Ebonhold's checkpoints use their own tooltip frame (found via /cbh frames):
   -- ProjectEbonholdCheckpointTooltip holds "<Name>" / "Click to travel...".
   if l1 == "" and l2 == "" then
      local cpt = _G["ProjectEbonholdCheckpointTooltip"]
      if cpt then
         local texts = {}
         for i = 1, select("#", cpt:GetRegions()) do
            local r = select(i, cpt:GetRegions())
            if r and r.GetObjectType and r:GetObjectType() == "FontString" then
               local t = r:GetText()
               if t and t ~= "" then table.insert(texts, t) end
            end
         end
         l1 = texts[1] or ""
         l2 = texts[2] or ""
         cpt:Hide()
      end
   end
   GameTooltip:Hide()
   if WorldMapTooltip then WorldMapTooltip:Hide() end
   return l1, l2, ok
end

local function FindCheckpoints(diagnose)
   local out = {}
   local stats = { unnamed = 0 }
   if not (WorldMapFrame and WorldMapButton) then return out, stats end
   local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
   local left, top = WorldMapButton:GetLeft(), WorldMapButton:GetTop()
   if not (w and h and left and top) or w == 0 or h == 0 then return out, stats end

   local function inspect(c, parentName)
      stats.unnamed = stats.unnamed + 1
      -- Ebonhold checkpoint buttons carry clean fields (found via /cbh portscan):
      -- checkpointId, nodeName, isUnlocked, isFactionAllowed.
      local cpId = rawget(c, "checkpointId")
      local nodeName = rawget(c, "nodeName")
      local unlocked = rawget(c, "isUnlocked")
      local faction = rawget(c, "isFactionAllowed")
      local isCP = (cpId ~= nil) or (nodeName ~= nil and unlocked ~= nil)
      if not isCP then
         -- Fallback for builds without those fields: tooltip scrape.
         local l1, l2 = ReadTooltip(c)
         local combined = string.lower((l1 or "") .. " " .. (l2 or ""))
         if string.find(combined, "not yet unlocked", 1, true) then
            isCP, unlocked, nodeName = true, false, (l1 ~= "" and l1) or "Checkpoint"
         elseif string.find(combined, "click to travel", 1, true) then
            isCP, unlocked, nodeName = true, true, (l1 ~= "" and l1) or "Checkpoint"
         end
      end
      if diagnose then
         CBH.print("  btn#" .. stats.unnamed .. " [" .. parentName .. "] cp=" ..
            tostring(cpId) .. " name=" .. tostring(nodeName) .. " unlocked=" ..
            tostring(unlocked) .. " faction=" .. tostring(faction) ..
            (isCP and (unlocked ~= false and (faction ~= false and " -> USE" or " -> WRONG FACTION")
            or " -> LOCKED") or ""))
      end
      if isCP then
         if unlocked == false then
            stats.locked = (stats.locked or 0) + 1
         elseif faction ~= false then
            local cx, cy = c:GetCenter()
            if cx and cy then
               table.insert(out, { btn = c, name = nodeName or "Checkpoint",
                  x = (cx - left) / w, y = (top - cy) / h })
            end
         end
      end
   end

   -- The server may parent its checkpoint buttons anywhere under the map;
   -- walk the whole WorldMapFrame tree for unnamed, visible Buttons.
   local function walk(f, depth)
      if depth > 6 then return end
      for i = 1, select("#", f:GetChildren()) do
         local c = select(i, f:GetChildren())
         if c and c.IsShown and c:IsShown() then
            if not c:GetName() and c:GetObjectType() == "Button" then
               inspect(c, tostring(f:GetName() or "?"))
            end
            walk(c, depth + 1)
         end
      end
   end
   walk(WorldMapFrame, 0)
   return out, stats
end

-- Diagnostic: /cbh portscan with the map open.
function Advisor.PortScan()
   if not WorldMapFrame:IsShown() then
      CBH.print("Open the world map first, then run /cbh portscan.")
      return
   end
   CBH.print("Scanning unnamed map buttons:")
   local cps, stats = FindCheckpoints(true)
   CBH.print("Candidates: " .. stats.unnamed .. ", validated checkpoints: " .. #cps)
end

-- All interesting points (rare spawns + learned camps of active objectives)
-- for a given zone, in that zone's normalized coordinates.
local function PointsForZone(zone)
   local pts = {}
   local hot = CBH.QuestWatcher.IsZoneHot and CBH.QuestWatcher.IsZoneHot(zone)
   if hot then
      for _, p in ipairs(CBH.SpawnDB.GetPoints(zone)) do table.insert(pts, p) end
   end
   local mobs = CBH.db and CBH.db.learnedKills and CBH.db.learnedKills[zone]
   if mobs then
      for name, list in pairs(mobs) do
         local ko = (CBH.killObjectives or {})[name]
         if ko and (not ko.need or (ko.have or 0) < ko.need) then
            for _, p in ipairs(list) do table.insert(pts, { x = p[1], y = p[2] }) end
         end
      end
   end
   return pts
end

-- Is this a real world-map zone we could actually point the map at? Used to
-- sanity-check quest-log headers, which can also be categories ("Dungeons",
-- "Class", a server's custom grouping) rather than places. Returns the properly
-- cased zone name, or nil. Cached: the continent/zone lists don't change.
local function KnownMapZone(name)
   return CBH.SpawnDB.KnownMapZone and CBH.SpawnDB.KnownMapZone(name) or nil
end

-- The quest log groups quests under ZONE HEADERS - the game's own answer to
-- "where is this quest?", and far more trustworthy than sweeping every map for
-- a POI. "Bring Me the Head of Ragemane" names no zone in its text and isn't a
-- rare we have data for, but it sits under the "Zul'Drak" header; without this
-- it fell through to the sweep, which returned whatever map was already loaded
-- (Dragonblight, the zone the player was standing in). Walk back to the nearest
-- header and use it only when it names a real zone.
local function ZoneFromQuestHeader(questIndex)
   if not questIndex or not GetQuestLogTitle then return nil end
   for i = questIndex - 1, 1, -1 do
      local title, _, _, _, isHeader = GetQuestLogTitle(i)
      if isHeader then return KnownMapZone(title) end
   end
   return nil
end
Advisor.ZoneFromQuestHeader = ZoneFromQuestHeader

-- Decide which zone to travel to: explicit arg > current arrow waypoint >
-- active rare zone > zone of a learned camp > zone harvested from a card.
-- Find a zone name mentioned in the quest's title or objective text.
local function ZoneFromQuestText(ko)
   if not ko.questIndex then return end
   local texts = { (GetQuestLogTitle(ko.questIndex)) }
   for j = 1, GetNumQuestLeaderBoards(ko.questIndex) do
      table.insert(texts, (GetQuestLogLeaderBoard(j, ko.questIndex)))
   end
   -- An explicit outdoor zone named in the text is the most reliable source.
   for _, t in ipairs(texts) do
      if t then
         local lt = string.lower(t)
         for zone in pairs(CBH.SpawnDB.ZONES) do
            if string.find(lt, string.lower(zone), 1, true) then return zone end
         end
      end
   end
   -- Otherwise, a dungeon/boss or known target named in the text resolves to the
   -- outdoor zone we route to (see SpawnDB.ZoneForTargetText). Example: "Bring
   -- Down Ingvar the Plunderer" / "Ingvar the Plunderer slain: 0/1" names the
   -- Utgarde Keep end boss but no outdoor zone -> Howling Fjord (isDungeon=true,
   -- so DoPort routes by zone and doesn't chase an outdoor POI that doesn't
   -- exist). Before this, the name matched nothing and the fragile POI sweep
   -- confidently mis-picked "Alterac Mountains".
   for _, t in ipairs(texts) do
      local zone, isDungeon, via = CBH.SpawnDB.ZoneForTargetText(t)
      if zone then return zone, isDungeon, via end
   end
end

-- Any real map zone named in the title/objectives. Kept SEPARATE from
-- ZoneFromQuestText because it is markedly less trustworthy: a quest title can
-- simply be wrong. "Thinning the Herd in Winterspring" hands out objectives whose
-- mobs are actually in WINTERGRASP - confirmed by 21 recorded kills there - so
-- this source must lose to anything empirical.
--
-- Objectives are scanned before the title, not after. "Winterspring:
-- Whispering Wind" carries the server's "<Zone>:" category prefix as its
-- title, but the objective plainly reads "Whispering Wind in Wintergrasp." A
-- fresh install with no kill history to fall back on had nothing to override
-- the title, so it ported straight past the mobs (reported by xMetaMorph,
-- v1.11.0). The title stays in the scan as the last resort - still better
-- than nothing when no objective names a zone at all.
local function ZoneFromAnyMapName(ko)
   if not ko.questIndex then return nil end
   local texts = {}
   for j = 1, GetNumQuestLeaderBoards(ko.questIndex) do
      table.insert(texts, (GetQuestLogLeaderBoard(j, ko.questIndex)))
   end
   table.insert(texts, (GetQuestLogTitle(ko.questIndex)))
   for _, t in ipairs(texts) do
      local zone = CBH.SpawnDB.FindMapZoneIn and CBH.SpawnDB.FindMapZoneIn(t)
      if zone then return zone end
   end
   return nil
end
Advisor.ZoneFromAnyMapName = ZoneFromAnyMapName  -- exposed so tests can pin the objective/title order directly

-- Where you have ACTUALLY completed this objective before. This is ground truth
-- from your own kills, so it outranks quest text, headers and cached card zones -
-- all of which can be wrong. Picks the zone with the most recorded points, which
-- is also deterministic (the old first-match pairs() scan was not).
local function ZoneFromLearnedKills(name)
   local lk = CBH.db and CBH.db.learnedKills
   if not lk then return nil end
   local best, bestN
   for z, mobs in pairs(lk) do
      local list = mobs[name]
      local n = list and #list or 0
      if n > 0 and (not bestN or n > bestN or (n == bestN and z < best)) then
         best, bestN = z, n
      end
   end
   return best
end
Advisor.ZoneFromLearnedKills = ZoneFromLearnedKills

-- A card zone BuildNote harvested AND validated against a real map zone (see
-- cardZoneVerified in BuildNote). Deliberately narrower than "whatever
-- CBH.SpawnDB.CardZoneFor(name) returns" (source 6 below, the player's own
-- unverified cardZones entry or a bundled default): the one-time repair in
-- Core.lua only strips entries worth exactly "Alterac Mountains", the one
-- false positive the pre-1.5.0 POI sweep is documented to have produced, so
-- an upgraded database can still be carrying some OTHER stale sweep guess
-- under cardZones that nothing has ever disproven, and a bundled default is
-- someone else's harvest rather than this player's own. Trusting either of
-- those over the header would let an unconfirmed guess outrank a header that
-- happens to be correct. cardZoneVerified is a SAVED flag, not a momentary
-- check: once BuildNote validates a card, this objective outranks the header
-- on every login from then on, until that card is harvested again and
-- overwrites the entry - trusted until re-harvested, not just in the instant
-- it was seen.
local function ZoneFromVerifiedCard(name)
   if not (CBH.db and CBH.db.cardZoneVerified and CBH.db.cardZoneVerified[name]) then
      return nil
   end
   return CBH.db.cardZones and CBH.db.cardZones[name]
end
Advisor.ZoneFromVerifiedCard = ZoneFromVerifiedCard

-- Last resort: sweep every zone map looking for the quest's POI marker.
-- Changes the displayed map, so only used on an actual Port click (which is
-- about to set the map anyway).
local function FindQuestZoneByPOI(questID)
   if not (questID and QuestPOIGetIconInfo) then return end
   for c = 1, select("#", GetMapContinents()) do
      local zones = { GetMapZones(c) }
      for z, zn in ipairs(zones) do
         SetMapZoom(c, z)
         if QuestMapUpdateAllQuests then pcall(QuestMapUpdateAllQuests) end
         local x, y = CBH.GetQuestPOI(questID)
         if x then return zn, x, y end
      end
   end
end

-- Some zones are reached better via an adjacent zone's checkpoint (e.g.
-- Dalaran floats over Crystalsong Forest). Built-in defaults; user overrides win.
local DEFAULT_PORT_VIA = {
   ["Crystalsong Forest"] = "Dalaran",
}

-- Some zones have NO checkpoint on their own map, so pointing the map at them
-- finds nothing at all. Dalaran is the case: it floats over Crystalsong Forest,
-- and the checkpoint named "Dalaran" sits on the CRYSTALSONG map. Setting home
-- in Dalaran therefore failed with "No checkpoints found (unnamed map buttons:
-- 0)" - the Dalaran city map has no checkpoint buttons to find.
--
-- This is a MAP redirect, distinct from DEFAULT_PORT_VIA above: that one prefers
-- a differently-named checkpoint on the map we are already showing, whereas this
-- changes WHICH MAP to show. The destination stays Dalaran; only the map we scan
-- for its checkpoint changes.
local DEFAULT_MAP_VIA = {
   ["Dalaran"] = "Crystalsong Forest",
}
local function MapViaFor(zone)
   if not zone then return nil end
   local u = CBH.db and CBH.db.mapOverrides and CBH.db.mapOverrides[zone]
   if u == "" then return nil end
   return u or DEFAULT_MAP_VIA[zone]
end
Advisor.MapViaFor = MapViaFor
local function PortViaFor(zone)
   if not zone then return nil end
   local u = CBH.db and CBH.db.portOverrides and CBH.db.portOverrides[zone]
   if u == "" then return nil end          -- explicitly cleared
   return u or DEFAULT_PORT_VIA[zone]
end
Advisor.PortViaFor = PortViaFor

-- This server mixes the straight (') and curly (U+2019) apostrophe within its
-- own checkpoint names, the same quirk Route.lua's NormTitle already exists to
-- survive on quest titles. Folded out here too so a curated `via` (see
-- SpawnDB.TARGET_CHECKPOINT - "Stars' Rest" was verified from a real port log,
-- but the next server-side edit could still re-spell it) keeps matching
-- instead of silently missing and falling back to the nearest checkpoint.
-- Defined up here, above its callers: /cbh portvia folds names too, and it
-- sits earlier in the file than DoPort where this used to live.
local function FoldApostrophe(s)
   return (string.gsub(tostring(s or ""), "\226\128\153", "'"))
end
Advisor.FoldApostrophe = FoldApostrophe  -- exposed so tests can pin curly/straight folding directly

-- A `via` may be one name or a list of alternatives (see the faction note in
-- DoPort). Anything that PRINTS one has to cope with both, so it goes through
-- here rather than concatenating a value that might be a table.
local function ViaText(v)
   if type(v) ~= "table" then return tostring(v) end
   return table.concat(v, " or ")
end
Advisor.ViaText = ViaText

-- A per-OBJECTIVE checkpoint override, which beats the per-zone one above.
-- Dragonblight is the case that forced it: Whispering Wind and Flame Revenant
-- are both there and want different checkpoints, so one zone-keyed entry
-- cannot serve both. Keyed on the objective's target name, lowercased, which
-- is the same key SpawnDB's shipped TARGET_CHECKPOINT defaults use.
local function PortTargetViaFor(target)
   if not target then return nil end
   local t = CBH.db and CBH.db.portTargets and CBH.db.portTargets[string.lower(target)]
   if t == "" then return nil end          -- explicitly cleared
   return t
end
Advisor.PortTargetViaFor = PortTargetViaFor

local function IsWatched(questIndex)
   if not questIndex or not GetNumQuestWatches then return false end
   for w = 1, GetNumQuestWatches() do
      if GetQuestIndexForWatch(w) == questIndex then return true end
   end
   return false
end
Advisor.IsWatched = IsWatched

-- Resolve one kill objective to (zone, points). The zone named in the quest
-- TEXT is the reliable source ("Kill N X in <Zone>") and needs no map sweep, so
-- it comes first. DoPort then reads the quest's live POI on THAT zone's map for
-- precise checkpoint routing. The POI *sweep* is a last resort only: right after
-- SetMapZoom the POI data is stale, so it false-positived on the first zone in
-- the list (Alterac Mountains) for many unrelated quests.
local function ResolveKill(name, ko, allowSweep)
   -- Source order, most trustworthy first:
   --   1. a zone we ship spawn data for, named in the text, or a curated override
   --   2. where you have actually killed this objective before (ground truth)
   --   3. any real zone named in the text  - a quest TITLE can be wrong
   --   4. a card zone BuildNote harvested and validated - the server's own
   --      statement of where the mobs are, for objectives whose quest-log
   --      text names no zone at all. cardZoneVerified is a SAVED flag, not a
   --      one-time check: once a card is harvested this way it outranks the
   --      header on every login from then on, until that card is harvested
   --      again and overwrites the entry - trusted until re-harvested, not
   --      just in the instant it was seen. Outranks the header on purpose:
   --      "Population Management: Earthbound Revenant" sits under a
   --      "Winterspring" header on this server but its card reads "10
   --      Earthbound Revenant in Wintergrasp" - the header is a category this
   --      server mislabels, the card is the mobs' actual location.
   --   5. the quest log's zone header
   --   6. CBH.SpawnDB.CardZoneFor(name): the player's own cached card zone if
   --      one exists, else a bundled SpawnDB.CARD_ZONES default. Neither is
   --      confirmed by anything THIS player did, so both rank below the
   --      header rather than above it - a legacy cardZones entry can still
   --      hold a pre-1.5.0 POI-sweep guess nothing has disproven (see
   --      ZoneFromVerifiedCard), and a bundled default is someone else's
   --      harvest, not this player's observation.
   local zone, isDungeon, via = ZoneFromQuestText(ko)
   zone = zone or ZoneFromLearnedKills(name)
   zone = zone or ZoneFromAnyMapName(ko)
   zone = zone or ZoneFromVerifiedCard(name)
   zone = zone or ZoneFromQuestHeader(ko.questIndex)
   zone = zone or CBH.SpawnDB.CardZoneFor(name)
   if zone then
      -- Deliberately NOT cached into cardZones. That table is documented as
      -- "harvested from callboard cards", and writing resolutions into it made
      -- it claim things the callboard never offered - which then fed the
      -- callboard-only whitelist as if it were evidence.
      return zone, PointsForZone(zone), isDungeon, via
   end
   -- Nothing named it: fall back to the (fragile) POI sweep. Its guess is used
   -- for THIS port only and is deliberately NOT cached into cardZones - caching
   -- a stale-POI guess is exactly what pinned the phantom "Alterac Mountains"
   -- onto Utgarde Keep's Ingvar the Plunderer and made the wrong port label
   -- stick across sessions. (Dungeon/known targets now resolve above, so the
   -- sweep is a genuine last resort.)
   if allowSweep and ko.questID then
      local zn, qx, qy = FindQuestZoneByPOI(ko.questID)
      -- POI data is stale right after SetMapZoom, so the sweep false-positives
      -- on whatever map was loaded before: historically the first zone in the
      -- list ("Alterac Mountains") and the zone the player is standing in
      -- ("Dragonblight" for a Zul'Drak quest). A result equal to the current
      -- zone is that artifact - and porting there is refused downstream anyway -
      -- so treat it as no answer rather than a confident wrong one.
      if zn and zn == GetRealZoneText() then
         CBH.Log("port", "SWEEP rejected '" .. tostring(zn) .. "' for '"
            .. tostring(name) .. "' (= current zone; stale-POI artifact)")
         zn = nil
      end
      if zn then
         CBH.Log("port", "SWEEP used '" .. zn .. "' for '" .. tostring(name)
            .. "' (last resort - report if wrong)")
         return zn, { { x = qx, y = qy } }
      end
   end
end

-- Pure resolver: returns destZone, points, questID, preferPOI. Callers store
-- what they need; the label ticker must not mutate in-flight port state.
local function ResolveDestination(zoneArg, allowSweep)
   -- Cleared on EVERY resolve, then set again below only if a kill objective
   -- actually wins. It must not be sticky the way lastDestZone is: three
   -- things now key off it (the port button's label, the port's own via
   -- lookup, and /cbh portvia's "which objective am I setting?"), so a value
   -- left over from a quest you have since turned in - or from before you
   -- typed "/cbh port <zone>", which returns below without resolving an
   -- objective at all - makes all three answer for the wrong quest. That is
   -- how a pick meant for one zone got saved under another objective's name.
   Advisor.lastDestTarget = nil
   if zoneArg and zoneArg ~= "" then return zoneArg, PointsForZone(zoneArg) end
   if CBH.Arrow.GetTargetXY then
      local tx, ty, isFarm, tname = CBH.Arrow.GetTargetXY()
      if tx then
         local qid, prefer
         if isFarm and tname then
            local ko = (CBH.killObjectives or {})[tname]
            if ko then qid, prefer = ko.questID, true end
         end
         return GetRealZoneText(), { { x = tx, y = ty } }, qid, prefer
      end
   end
   -- Multiple active objectives: choose DETERMINISTICALLY, preferring the quest
   -- you're actually tracking (watched). A plain pairs() over hotZones returned
   -- a random one each click — that's why heading to Crystalsong sometimes
   -- tried to port to Alterac and needed a re-click. Now: watched first, then a
   -- stable tie-break (questIndex, then name), so the same click always resolves
   -- the same way and the port button label shows where it will send you.
   local cands = {}
   for zone, info in pairs(CBH.hotZones or {}) do
      -- Skip finished rare quests: a completed one used to win the sort (watched
      -- or lower questIndex) and port you to a zone you had nothing left to do in.
      if not info.done then
         cands[#cands + 1] = { kind = "hot", zone = zone, qi = info.questIndex,
            w = IsWatched(info.questIndex) and 1 or 0 }
      end
   end
   -- Callboard-only mode: an ordinary quest that happens to match
   -- "<name> slain: n/m" is not callboard work, so it must not steer the Port
   -- button. Inactive until at least one board has been seen.
   local cbOnly = CBH.CallboardOnlyActive and CBH.CallboardOnlyActive()
   for name, ko in pairs(CBH.killObjectives or {}) do
      if (not ko.need or (ko.have or 0) < ko.need)
         and (not cbOnly or IsCallboardKill(name, ko)) then
         cands[#cands + 1] = { kind = "kill", name = name, ko = ko,
            qi = ko.questIndex, w = IsWatched(ko.questIndex) and 1 or 0 }
      end
   end
   table.sort(cands, function(a, b)
      if a.w ~= b.w then return a.w > b.w end
      if (a.qi or 9999) ~= (b.qi or 9999) then return (a.qi or 9999) < (b.qi or 9999) end
      return tostring(a.zone or a.name) < tostring(b.zone or b.name)
   end)
   for _, c in ipairs(cands) do
      if c.kind == "hot" then
         -- A rare-sighting zone has no single target name to key an override on.
         Advisor.lastDestTarget = nil
         return c.zone, PointsForZone(c.zone), nil, false
      else
         local zone, pts, isDungeon, via = ResolveKill(c.name, c.ko, allowSweep)
         if zone then
            -- Remembered so /cbh portvia knows WHICH objective a pick applies
            -- to. Set only once the objective actually resolves, mirroring how
            -- lastDestZone stays sticky rather than clearing on a failed probe.
            Advisor.lastDestTarget = c.name
            -- An objective-specific checkpoint override (e.g. Flame Revenant ->
            -- Fordragon Hold on the Dragonblight map): carry the checkpoint name
            -- through so DoPort forces it; no POI chase.
            if via then return zone, pts, nil, false, via end
            -- A dungeon objective has no outdoor quest POI to chase: route to
            -- the containing zone's checkpoint by position, don't prefer/prefetch
            -- a POI that lives inside the instance.
            if isDungeon then return zone, pts, nil, false end
            return zone, pts, c.ko.questID, true
         end
      end
   end
   return nil, nil
end
Advisor.ResolveDestination = ResolveDestination

-- /cbh portvia [n|name|none] - send the current objective via a different
-- checkpoint. No arg lists the checkpoints from your last port, numbered, so
-- picking one is "/cbh portvia 3" and never requires spelling a name: the
-- first version of this command took only an exact name, and getting the
-- apostrophe wrong in "Stars' Rest" was enough to silently do nothing.
function Advisor.PortVia(arg)
   arg = arg and (arg:gsub("^%s+", ""):gsub("%s+$", "")) or ""
   -- This acts on the objective you are ON. An earlier version keyed it to
   -- whichever objective was ported LAST, which reads fine in isolation and is
   -- wrong the moment those differ: with Raging Flame Infestation active and
   -- an older Skeletal Archmage port still captured, "/cbh portvia 2" replied
   -- "Skeletal Archmage will now port via The Argent Vanguard, Icecrown" -
   -- a pick saved against a quest the player was not doing, pointing at a
   -- checkpoint in a zone that quest is not in.
   local target, zone = Advisor.lastDestTarget, Advisor.lastDestZone
   -- Only when nothing is live: a sweep-only objective is not resolvable
   -- between ports, so the port's own captured name is the sole record of it.
   if not target and Advisor.lastCandidateTarget then
      target, zone = Advisor.lastCandidateTarget, Advisor.lastCandidateZone
   end
   local label = target or zone

   -- Both sides of this comparison are now sourced independently - the live
   -- objective, and the name the PORT captured for itself - so it is a real
   -- check. It could not do its job while both were read from one sticky
   -- field, which is why it was briefly removed rather than repaired.
   local function listOwner()
      local c = Advisor.lastCandidates
      if not c or #c == 0 then return nil end
      return Advisor.lastCandidateTarget or Advisor.lastCandidateZone
   end
   local function freshList()
      local c = Advisor.lastCandidates
      if not c or #c == 0 then return nil end
      if Advisor.lastCandidateTarget ~= target then return nil end
      if Advisor.lastCandidateZone ~= zone then return nil end
      return c
   end
   -- Naming what the numbers DID belong to is the whole difference between
   -- "this is broken" and "port for this one first".
   local function staleNote()
      local owner = listOwner()
      if owner then
         return "  The last port was for " .. tostring(owner) .. ", so those"
            .. " numbers aren't for " .. tostring(label) .. ".  Port for "
            .. tostring(label) .. " first, then run /cbh portvia."
      end
      return "  Port once, then run /cbh portvia to pick from what was on the map."
   end

   local function currentPick()
      if target then
         local t = PortTargetViaFor(target)
         if t then return t, "you picked it for " .. target end
      end
      if zone then
         local z = PortViaFor(zone)
         if z then return z, "you picked it for the whole of " .. zone end
      end
      return nil, nil
   end

   if arg == "" then
      local pick, why = currentPick()
      if label then
         CBH.print("Port routing for " .. tostring(label)
            .. ((zone and target) and ("  (" .. zone .. ")") or ""))
      else
         CBH.print("No current objective - open the board or accept a callboard quest first.")
      end
      -- With no objective there is nothing to offer a list FOR, and saying
      -- "port once, then run this again" would be advice about a quest the
      -- line above just said does not exist. Fall through to what IS useful:
      -- everything already saved.
      local list = label and freshList() or nil
      if not label then       -- nothing to list for; fall through to saved picks
      elseif list then
         local pl = pick and FoldApostrophe(string.lower(pick)) or nil
         for i, name in ipairs(list) do
            local mark = "   "
            if pl and string.find(FoldApostrophe(string.lower(name)), pl, 1, true) then
               mark = " * "      -- glyph AND the word "current" below; never colour alone
            end
            CBH.print("  " .. mark .. i .. ". " .. name
               .. ((mark ~= "   ") and "  (current)" or ""))
         end
         CBH.print("Pick one: /cbh portvia <number>   clear it: /cbh portvia none")
      else
         if pick then CBH.print("  currently: " .. pick .. "  (" .. why .. ")") end
         CBH.print("  No checkpoint list for " .. tostring(label) .. "."
            .. staleNote())
      end
      -- Everything saved, so a player can see and undo picks made elsewhere.
      local any = false
      for t, v in pairs((CBH.db and CBH.db.portTargets) or {}) do
         if v ~= "" then
            if not any then CBH.print("Saved picks:"); any = true end
            CBH.print("  " .. t .. " -> " .. v)
         end
      end
      for z, v in pairs((CBH.db and CBH.db.portOverrides) or {}) do
         if v ~= "" then
            if not any then CBH.print("Saved picks:"); any = true end
            CBH.print("  " .. z .. " (whole zone) -> " .. v)
         end
      end
      return
   end

   if not label then
      CBH.print("No current objective known - open the board or accept a callboard quest first.")
      return
   end
   CBH.db.portTargets = CBH.db.portTargets or {}
   CBH.db.portOverrides = CBH.db.portOverrides or {}

   local low = string.lower(arg)
   if low == "none" or low == "off" then
      -- Clear BOTH levels for this objective, so "none" means what it says
      -- rather than clearing one and leaving the other still steering.
      if target then CBH.db.portTargets[string.lower(target)] = "" end
      if zone then CBH.db.portOverrides[zone] = "" end
      CBH.print("Cleared port routing for " .. tostring(label)
         .. "  - back to the nearest checkpoint.")
      return
   end

   local name = arg
   local n = tonumber(arg)
   if n then
      local list = freshList()
      if not list then
         CBH.print("No checkpoint list for " .. tostring(label) .. "."
            .. staleNote())
         return
      end
      if not list[n] then
         CBH.print("There is no " .. n .. " in the list - run /cbh portvia"
            .. " to see it again (" .. #list .. " checkpoint"
            .. ((#list == 1) and "" or "s") .. ").")
         return
      end
      name = list[n]
   end

   if target then
      CBH.db.portTargets[string.lower(target)] = name
      CBH.print(target .. " will now port via " .. name .. ".")
   else
      CBH.db.portOverrides[zone] = name
      CBH.print("Everything in " .. zone .. " will now port via " .. name .. ".")
   end
end

-- Diagnostic: /cbh obj - ground truth on every active objective and how it resolves.
function Advisor.DumpObjectives()
   CBH.print("Active objectives:")
   for zone, info in pairs(CBH.hotZones or {}) do
      CBH.print("  RARE zone=" .. zone .. " " .. tostring(info.have) .. "/"
         .. tostring(info.need) .. (info.done and " |cffff5050[done]|r" or "")
         .. " qid=" .. tostring(info.questID)
         .. " watched=" .. tostring(IsWatched(info.questIndex)))
   end
   local any = false
   for name, ko in pairs(CBH.killObjectives or {}) do
      any = true
      local done = ko.need and (ko.have or 0) >= ko.need
      local cz = CBH.db and CBH.db.cardZones and CBH.db.cardZones[name]
      local camp
      for z, mobs in pairs((CBH.db and CBH.db.learnedKills) or {}) do
         if mobs[name] and #mobs[name] > 0 then camp = z break end
      end
      CBH.print("  KILL '" .. name .. "' " .. tostring(ko.have) .. "/" ..
         tostring(ko.need) .. (done and " |cffff5050[done]|r" or "") ..
         " watched=" .. tostring(IsWatched(ko.questIndex)))
      CBH.print("     cardZone=" .. tostring(cz) .. " textZone=" ..
         tostring(ZoneFromQuestText(ko)) .. " headerZone=" ..
         tostring(ZoneFromQuestHeader(ko.questIndex)) .. " killedIn="
         .. tostring(ZoneFromLearnedKills(name)) .. " camp=" .. tostring(camp))
   end
   if not any then CBH.print("  (no kill objectives)") end
   CBH.print("Open the map & /cbh port to route by live POI (overrides the above).")
end

-- Point the world map at a zone by name (case-insensitive).
local function SetMapByZoneName(zoneName)
   local want = string.lower(zoneName)
   for c = 1, select("#", GetMapContinents()) do
      local zones = { GetMapZones(c) }
      for z, zn in ipairs(zones) do
         if string.lower(zn) == want then
            SetMapZoom(c, z)
            return true
         end
      end
   end
   return false
end

-- Read quest POI buttons (the numbered map blobs) directly off the map, for
-- clients where QuestPOIGetIconInfo yields nothing.
local function HarvestQuestPOIButtons()
   local out = {}
   local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
   local left, top = WorldMapButton:GetLeft(), WorldMapButton:GetTop()
   if not (w and h and left and top) or w == 0 then return out end
   local function walk(f, depth)
      if depth > 6 then return end
      for i = 1, select("#", f:GetChildren()) do
         local c = select(i, f:GetChildren())
         if c and c.IsShown and c:IsShown() then
            if c:GetObjectType() == "Button" then
               for r = 1, select("#", c:GetRegions()) do
                  local reg = select(r, c:GetRegions())
                  if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                     local t = reg:GetText()
                     if t and string.find(t, "^%d+$") then
                        local cx, cy = c:GetCenter()
                        if cx then
                           table.insert(out, { x = (cx - left) / w, y = (top - cy) / h })
                        end
                     end
                  end
               end
            end
            walk(c, depth + 1)
         end
      end
   end
   walk(WorldMapFrame, 0)
   return out
end

local function DoPort()
   -- Make sure the DESTINATION zone's map is actually displayed before scanning.
   -- The world map can revert to the player's current zone between Advisor.Port
   -- and here, which made an Icecrown objective scan the Dragonblight map and
   -- pick Moa'ki. Re-assert the map and retry a few times before giving up.
   -- Assert the map we actually intend to SCAN. For a redirected destination
   -- (Dalaran -> the Crystalsong map) that is not the destination zone.
   local wantMap = Advisor.portMapZone or Advisor.lastDestZone
   if wantMap then
      local want = string.gsub(string.lower(wantMap), "%s", "")
      local cur = string.lower(tostring(GetMapInfo() or ""))
      if want ~= "" and cur ~= ""
         and not (string.find(cur, want, 1, true) or string.find(want, cur, 1, true)) then
         if (Advisor.portMapTries or 0) < 4 then
            Advisor.portMapTries = (Advisor.portMapTries or 0) + 1
            if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
            SetMapByZoneName(wantMap)
            Advisor.portAt = GetTime() + 0.4 -- rescan once the map settles
            return
         end
         CBH.Log("port", "MAP-STUCK: wanted " .. tostring(wantMap)
            .. " but map is " .. tostring(GetMapInfo()) .. " - scanning anyway")
      end
   end
   Advisor.portMapTries = nil
   local cps, stats = FindCheckpoints(false)
   local pts = Advisor.portPoints
   Advisor.portPoints = nil
   local routedBy = (pts and #pts > 0) and "camp/waypoint" or "your position"
   -- The quest's own POI marks the CURRENT assignment area. For kill
   -- objectives it overrides learned camps (the server can assign a different
   -- part of the zone each time); otherwise it fills in when no points exist.
   if Advisor.portQuestID then
      if QuestMapUpdateAllQuests then pcall(QuestMapUpdateAllQuests) end
      if QuestPOIUpdateIcons then pcall(QuestPOIUpdateIcons) end
      local px, py = CBH.GetQuestPOI(Advisor.portQuestID)
      local src = "quest area"
      if not px and Advisor.portPreferPOI then
         -- API gave nothing: read the numbered POI button off the map itself.
         local btns = HarvestQuestPOIButtons()
         if #btns > 0 then
            px, py = btns[1].x, btns[1].y
            src = "quest area (map marker)"
         end
      end
      if px and (Advisor.portPreferPOI or not pts or #pts == 0) then
         pts = { { x = px, y = py } }
         routedBy = src
      end
   end
   Advisor.portQuestID = nil
   Advisor.portPreferPOI = false
   CBH.Log("port", "scan: map=" .. tostring(GetMapInfo()) .. " cps=" .. #cps
      .. " locked=" .. (stats.locked or 0) .. " unnamed=" .. (stats.unnamed or 0)
      .. " basis=" .. routedBy .. " pts=" .. ((pts and #pts) or 0)
      .. (pts and pts[1] and string.format(" pt1=%.2f/%.2f", pts[1].x, pts[1].y) or ""))
   if #cps == 0 then
      if (stats.locked or 0) > 0 then
         CBH.Log("port", "FAIL: 0 unlocked checkpoints (" .. stats.locked .. " locked)")
         CBH.print("No unlocked checkpoints on this map (" .. stats.locked ..
            " locked). Visit a meeting stone there to unlock one first.")
      else
         CBH.Log("port", "FAIL: 0 checkpoints, " .. (stats.unnamed or 0) .. " unnamed buttons")
         CBH.print("No checkpoints found (unnamed map buttons: " .. stats.unnamed ..
            "). Run /cbh portscan with the map open and report the output.")
      end
      return
   end
   -- Remember what was on the map for /cbh portvia to offer as a numbered list.
   -- This is the whole reason picking is easy: the names come off the player's
   -- OWN map, already filtered by FindCheckpoints to what is unlocked and
   -- allowed for their faction, so they cannot pick something they can't use
   -- and never have to spell a name. Captured on every port, so the list a
   -- player sees is always the one from the port they just watched go wrong.
   local seen = {}
   Advisor.lastCandidates = {}
   for _, cp in ipairs(cps) do
      local n = cp.name and tostring(cp.name)
      if n and n ~= "" and not seen[string.lower(n)] then
         seen[string.lower(n)] = true
         table.insert(Advisor.lastCandidates, n)
      end
   end
   Advisor.lastCandidateTarget = Advisor.portTarget
   Advisor.lastCandidateZone = Advisor.lastDestZone

   local best, bestD, viaHit
   -- Port-via override: force the checkpoint whose name matches, if present.
   -- The wanted name may be a LIST. That is how a faction-split default is
   -- expressed (Stars' Rest for Alliance, Agmar's Hammer for Horde): rather
   -- than asking UnitFactionGroup and maintaining a faction table, offer both
   -- and let the map decide, since FindCheckpoints already dropped whichever
   -- one this player cannot use. Order is preference, not priority.
   if Advisor.portViaName then
      local wants = Advisor.portViaName
      if type(wants) ~= "table" then wants = { wants } end
      for _, w in ipairs(wants) do
         local want = FoldApostrophe(string.lower(tostring(w)))
         for _, cp in ipairs(cps) do
            if cp.name and string.find(FoldApostrophe(string.lower(cp.name)), want, 1, true) then
               best, viaHit = cp, true
               break
            end
         end
         if best then break end
      end
   end
   -- A blocked checkpoint (e.g. Azjol-Nerub, which drops you INSIDE the dungeon)
   -- is skipped by auto-routing UNLESS you're actually going there — the
   -- destination zone or an active objective's quest text names it. Only affects
   -- CBH's auto-pick; the game's own map checkpoint stays clickable by hand.
   local function usable(cpName)
      if not (CBH.IsBlockedCheckpoint and CBH.IsBlockedCheckpoint(cpName)) then
         return true
      end
      local low = string.lower(cpName or "")
      local dest = Advisor.lastDestZone
      if dest then
         local dl = string.lower(dest)
         if string.find(dl, low, 1, true) or string.find(low, dl, 1, true) then return true end
      end
      for _, ko in pairs(CBH.killObjectives or {}) do
         local qi = ko.questIndex
         if qi and GetQuestLogTitle then
            local title = GetQuestLogTitle(qi)
            if title and string.find(string.lower(title), low, 1, true) then return true end
            for j = 1, (GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(qi) or 0) do
               local t = GetQuestLogLeaderBoard(j, qi)
               if t and string.find(string.lower(t), low, 1, true) then return true end
            end
         end
      end
      return false
   end
   if not best then
      local anyBest, anyD
      for _, cp in ipairs(cps) do
         local d
         if pts and #pts > 0 then
            -- Closest checkpoint to ANY objective point in the destination zone.
            for _, p in ipairs(pts) do
               local dx, dy = cp.x - p.x, cp.y - p.y
               local dd = dx * dx + dy * dy
               if not d or dd < d then d = dd end
            end
         else
            local rx, ry = GetPlayerMapPosition("player")
            if not rx or (rx == 0 and ry == 0) then rx, ry = 0.5, 0.5 end
            local dx, dy = cp.x - rx, cp.y - ry
            d = dx * dx + dy * dy
         end
         if not anyD or d < anyD then anyBest, anyD = cp, d end
         if usable(cp.name) and (not bestD or d < bestD) then best, bestD = cp, d end
      end
      if not best then best = anyBest end -- everything blocked: better than nothing
   end
   local note = (viaHit and Advisor.portViaNote) or ("routed by " .. routedBy)
   Advisor.portViaNote = nil
   Advisor.portViaName = nil
   CBH.print("Traveling to checkpoint: " .. tostring(best.name) .. " (" .. note .. ")")
   local names = {}
   for i = 1, math.min(#cps, 6) do names[i] = tostring(cps[i].name) end
   CBH.Log("port", "CLICK '" .. tostring(best.name) .. "' (" .. note
      .. (bestD and string.format(", d2=%.4f", bestD) or "")
      .. ") candidates: " .. table.concat(names, ", "))
   -- Arrival verification: did the click actually move us within 6s?
   local w = Advisor.portWatch or CreateFrame("Frame")
   Advisor.portWatch = w
   w.t0 = GetTime()
   w.from = tostring(GetRealZoneText()) .. "/" .. tostring(GetSubZoneText())
   w.cp = tostring(best.name)
   -- Already-there guard: if the destination is our current zone and the chosen
   -- checkpoint sits essentially where we stand, the click is a no-op (this was
   -- the largest share of NO-MOVE logs). Report instead of firing a dead click.
   local curZone = GetRealZoneText()
   if curZone and Advisor.lastDestZone and curZone == Advisor.lastDestZone then
      local rx, ry = GetPlayerMapPosition("player")
      if rx and ry and (rx ~= 0 or ry ~= 0) then
         local dx, dy = best.x - rx, best.y - ry
         if (dx * dx + dy * dy) < 0.0016 then -- ~0.04 map units
            CBH.print("Already at the nearest checkpoint in " .. curZone
               .. " (" .. tostring(best.name) .. ") - fly or walk from here.")
            CBH.Log("port", "SKIP: already at '" .. tostring(best.name)
               .. "' in " .. curZone)
            return
         end
      end
   end
   -- The checkpoint casts a spell ("Rapid Transit") with a cast time AND a
   -- cooldown. Never fire while it's already casting — re-firing interrupts our
   -- own cast (the START -> Interrupted -> START churn in the logs).
   if UnitCastingInfo and UnitCastingInfo("player") then
      CBH.Log("port", "SKIP: teleport already casting")
      CBH.print("Teleport already casting - hold still, don't re-click.")
      return
   end

   -- Watch ~12s (cast + travel), confirm arrival, and turn the spell's errors
   -- into plain guidance (on cooldown / interrupted by moving).
   local WATCH = 12
   local function stopWatch(self)
      self:SetScript("OnUpdate", nil)
      self:SetScript("OnEvent", nil)
      self:UnregisterEvent("UI_ERROR_MESSAGE")
      self:UnregisterEvent("UNIT_SPELLCAST_START")
      self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
      Advisor.portBusy = false
   end
   w:UnregisterAllEvents()
   w:RegisterEvent("UI_ERROR_MESSAGE")
   w:RegisterEvent("UNIT_SPELLCAST_START")
   w:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
   w:SetScript("OnEvent", function(self, event, a1, a2)
      if GetTime() - self.t0 > WATCH then return end
      if event == "UI_ERROR_MESSAGE" then
         local msg = tostring(a1)
         CBH.Log("port", "ERROR at click: " .. msg)
         if string.find(msg, "not ready") then
            CBH.print("Checkpoint teleport is on cooldown - wait a moment, then try again.")
            stopWatch(self)
         elseif string.find(msg, "nterrupt") or string.find(msg, "moving") then
            CBH.print("Teleport was interrupted - stand still (don't move) and click Port again.")
            stopWatch(self)
         end
      elseif a1 == "player" then
         CBH.Log("port", event .. ": " .. tostring(a2))
      end
   end)
   w:SetScript("OnUpdate", function(self)
      local now = tostring(GetRealZoneText()) .. "/" .. tostring(GetSubZoneText())
      if now ~= self.from then
         CBH.Log("port", "OK: " .. self.from .. " -> " .. now
            .. " via '" .. self.cp .. "'")
         stopWatch(self)
      elseif GetTime() - self.t0 > WATCH then
         CBH.Log("port", "NO-MOVE: still at " .. now .. " "
            .. WATCH .. "s after clicking '" .. self.cp .. "'")
         stopWatch(self)
      end
   end)
   -- Fire ONCE. Firing multiple handlers double-casts Rapid Transit and each
   -- interrupts the last, which is what broke this in 1.3.3.
   Advisor.portBusy = true
   CBH.print("Traveling to " .. tostring(best.name) .. " - hold still until the teleport finishes.")
   best.btn:Click()
end
Advisor.DoPort = DoPort

function Advisor.Port(zoneArg)
   if InCombatLockdown() then
      CBH.print("Cannot travel while in combat.")
      return
   end
   -- A teleport already in flight (casting or being verified): don't re-fire —
   -- re-clicking interrupts the Rapid Transit cast.
   if Advisor.portBusy or (UnitCastingInfo and UnitCastingInfo("player")) then
      CBH.print("A teleport is already in progress - hold still until it finishes.")
      return
   end
   local destZone, pts, qid, prefer, objVia = ResolveDestination(zoneArg, true)
   -- Couldn't work out a zone for any active objective. DON'T fall back to the
   -- current zone's map (below) - that ports you to a checkpoint in the zone you
   -- already stand in, which is never the right answer for an objective that's
   -- elsewhere. (This was the "Steel Yourself: Banthar" symptom: standing in
   -- Western Plaguelands, Port sent you to Chillwind Camp instead of Nagrand.)
   -- Decline with guidance instead.
   if not destZone then
      CBH.print("Couldn't work out a zone for your active objective(s) - open the"
         .. " callboard so its card can teach me the zone, or use /cbh port <zone>.")
      CBH.Log("port", "REQUEST arg='" .. tostring(zoneArg)
         .. "' -> UNRESOLVED, declined (would have ported inside the current zone)")
      return
   end
   -- Already in the destination zone: the checkpoint network doesn't hop you
   -- around within a zone, so this would be a dead click. Say so instead.
   if destZone and GetRealZoneText() == destZone then
      CBH.print("You're already in " .. destZone .. " - fly or walk to the spot.")
      CBH.Log("port", "SKIP: already in dest zone " .. destZone)
      return
   end
   Advisor.lastDestZone = destZone
   Advisor.portMapTries = nil
   Advisor.portPoints = pts
   Advisor.portQuestID = qid
   -- Captured HERE, not read again later, because this resolve ran with the
   -- POI sweep enabled and the 0.5s button ticker's does not. An objective
   -- that only resolves through the sweep is therefore unknowable between
   -- ports: a tick landing in the 0.7s gap before DoPort would clear the
   -- target and fail to re-find it, and the port would lose track of which
   -- objective it was for. The port's identity belongs to the port request.
   Advisor.portTarget = Advisor.lastDestTarget
   Advisor.portPreferPOI = prefer or false
   CBH.Log("port", "REQUEST arg='" .. tostring(zoneArg) .. "' -> dest="
      .. tostring(destZone) .. " pts=" .. ((pts and #pts) or 0)
      .. " qid=" .. tostring(qid) .. " prefPOI=" .. tostring(prefer or false))
   -- Port-via: an objective-specific checkpoint override (e.g. Flame Revenant ->
   -- Fordragon Hold) wins; else a zone's map can carry a checkpoint named for
   -- another zone (Crystalsong's map has a Dalaran checkpoint). Prefer that named
   -- checkpoint on THIS map rather than switching maps.
   local mapZone = MapViaFor(destZone)
   Advisor.portMapZone = mapZone
   -- With a map redirect the checkpoint we want is the one NAMED for the
   -- destination, sitting on the other zone's map.
   -- Precedence, most specific first: what YOU picked for this objective, then
   -- the shipped default for it, then what you picked for the whole zone, then
   -- the map-redirect case. A player's own pick outranks a shipped default
   -- because the default is a guess about a server we cannot inspect and the
   -- pick came off their live map.
   local via = PortTargetViaFor(Advisor.lastDestTarget)
      or objVia or PortViaFor(destZone) or (mapZone and destZone) or nil
   Advisor.portViaName = (via and via ~= (mapZone or destZone)) and via or nil
   Advisor.portViaNote = Advisor.portViaName
      and (destZone .. " via " .. (mapZone and (mapZone .. "'s map")
         or Advisor.ViaText(Advisor.portViaName)))
      or nil
   if not WorldMapFrame:IsShown() then
      -- (ToggleWorldMap does not exist on this client.)
      ShowUIPanel(WorldMapFrame)
   end
   if destZone then
      if not SetMapByZoneName(mapZone or destZone) then
         CBH.Log("port", "MAP-MISS: no map for '" .. tostring(mapZone or destZone)
            .. "', falling back to current zone map")
         CBH.print("No map found for zone '" .. tostring(destZone) .. "' - using current map.")
         SetMapToCurrentZone()
      end
   else
      SetMapToCurrentZone()
   end
   -- Checkpoint buttons repopulate when the displayed map changes; scan shortly.
   Advisor.portAt = GetTime() + 0.7
end

-- Travel back to a callboard you have used (prefers one in the current zone).
function Advisor.PortToCallboard()
   if InCombatLockdown() then
      CBH.print("Cannot travel while in combat.")
      return
   end
   -- A set home callboard wins (a point in a zone; we port to the checkpoint
   -- nearest it, e.g. Stars' Rest). Otherwise the nearest learned board.
   local pick = CBH.db and CBH.db.home
   if not (pick and pick.zone) then
      local list = (CBH.db and CBH.db.callboards) or {}
      if #list == 0 then
         CBH.print("No callboard location learned yet - open an Objectives Board once,"
            .. " or /cbh sethome where you want your home.")
         return
      end
      local zone = GetRealZoneText()
      for _, b in ipairs(list) do
         if b.zone == zone and CBH.IsPortableCallboardZone(b.zone) then pick = b break end
      end
      if not pick then
         -- Never fall back to an entry we cannot travel to.
         for _, b in ipairs(list) do
            if CBH.IsPortableCallboardZone(b.zone) then pick = b break end
         end
      end
      if not pick then
         CBH.print("No callboard location you can travel back to - open a board"
            .. " outdoors once, or /cbh sethome where you want your home.")
         return
      end
   end
   CBH.Log("port", "CALLBOARD request -> " .. tostring(pick.zone)
      .. string.format(" %.2f/%.2f", pick.x or 0, pick.y or 0))
   Advisor.portPoints = { { x = pick.x, y = pick.y } }
   Advisor.portQuestID = nil
   -- Going home is not objective work, so this port owns no target. Left set,
   -- the previous objective's name would be stamped onto the checkpoints
   -- harvested here and /cbh portvia would save a home-zone pick against it.
   Advisor.portTarget = nil
   Advisor.portPreferPOI = false
   Advisor.lastDestZone = pick.zone
   Advisor.portMapTries = nil
   -- Same redirect as Advisor.Port: a home in Dalaran must scan the Crystalsong
   -- map, because Dalaran's own map carries no checkpoints. Without this,
   -- "Port: Home" to Dalaran reported "No checkpoints found".
   local mapZone = MapViaFor(pick.zone)
   Advisor.portMapZone = mapZone
   Advisor.portViaName = mapZone and pick.zone or nil
   Advisor.portViaNote = mapZone and (pick.zone .. " via " .. mapZone .. "'s map") or nil
   if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
   if not SetMapByZoneName(mapZone or pick.zone) then SetMapToCurrentZone() end
   Advisor.portAt = GetTime() + 0.7
end
