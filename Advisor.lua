-- CallboardHunter Advisor: annotates the Objectives Board cards and finds
-- checkpoint teleports on the world map. Frame names discovered via /cbh frames:
-- cards = ObjectivesMainFrame > ObjectiveFrame1..3 (anonymous Select buttons);
-- checkpoints = anonymous Buttons on WorldMapButton (Blizzard POIs are named).
local CBH = CallboardHunter
local Advisor = CBH.Advisor or {}
CBH.Advisor = Advisor

-- ---------------------------------------------------------------- card advisor

local function CardTexts(card)
   local texts = {}
   for i = 1, select("#", card:GetRegions()) do
      local r = select(i, card:GetRegions())
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
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

local function BuildNote(desc)
   -- "Kill 10 Azure Manashaper in Crystalsong Forest."
   local _, _, n, mob, zone = string.find(desc, "^Kill (%d+) (.-) in (.+)%.$")
   if mob then
      if CBH.db then CBH.db.cardZones[mob] = zone end
      local pts = CountPoints(zone, mob)
      local here = (GetRealZoneText() == zone) and " (current zone)" or ""
      if pts > 0 then
         return "|cff30ff00Known camp: " .. pts .. " spot" .. (pts > 1 and "s" or "") ..
            " in " .. zone .. here .. "|r"
      end
      return "|cffffff00No camp data yet - " .. zone .. here .. "|r"
   end
   -- "Slay Kelthuzad in Naxxramas."
   local _, _, boss, place = string.find(desc, "^Slay (.-) in (.+)%.$")
   if boss then
      return "|cffaaaaaaDungeon/raid: " .. place .. "|r"
   end
   -- "Collect 40 Icethorn."
   local _, _, cn, item = string.find(desc, "^Collect (%d+) (.+)%.$")
   if item then
      return "|cffaaaaaaCollection: " .. item .. "|r"
   end
   -- Rare trophy cards mention "Rare"
   if string.find(string.lower(desc), "rare") then
      return "|cff30ff00Rare hunt - arrow will guide|r"
   end
   return nil
end

local function RefreshCards()
   for i = 1, 3 do
      local card = _G["ObjectiveFrame" .. i]
      if card and card:IsShown() then
         local note
         for _, t in ipairs(CardTexts(card)) do
            note = BuildNote(t)
            if note then break end
         end
         if not card.cbhNote then
            card.cbhNote = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            card.cbhNote:SetPoint("BOTTOM", card, "BOTTOM", 0, 92) -- clear of the Select button
            card.cbhNote:SetWidth(card:GetWidth() - 50)
         end
         card.cbhNote:SetText(note or "")
      end
   end
end

-- ------------------------------------------------------------- port button

local portBtn
local function EnsurePortButton()
   if portBtn or not (CBH.db and CBH.db.options) then return end
   portBtn = CreateFrame("Button", "CallboardHunterPortButton", UIParent, "UIPanelButtonTemplate")
   portBtn:SetWidth(120); portBtn:SetHeight(22)
   portBtn:SetText("Port: checkpoint")
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
   portBtn:SetScript("OnClick", function() CBH.safeCall(Advisor.Port) end)
   portBtn:Hide()
end

local function AnyObjectiveActive()
   if CBH.hotZones and next(CBH.hotZones) then return true end
   for _, ko in pairs(CBH.killObjectives or {}) do
      if not ko.need or (ko.have or 0) < ko.need then return true end
   end
   return false
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
   end
   if Advisor.portAt and GetTime() >= Advisor.portAt then
      Advisor.portAt = nil
      CBH.safeCall(Advisor.DoPort)
   end
   CBH.safeCall(EnsurePortButton)
   if portBtn then
      if AnyObjectiveActive() then portBtn:Show() else portBtn:Hide() end
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
      local l1, l2 = ReadTooltip(c)
      local combined = string.lower((l1 or "") .. " " .. (l2 or ""))
      local label
      if string.find(combined, "checkpoint", 1, true)
         or string.find(combined, "travel", 1, true) then
         label = (l1 and l1 ~= "") and l1 or "Checkpoint"
      end
      -- Custom buttons usually carry their data as Lua fields; if the tooltip
      -- route failed, look for checkpoint-ish strings on the button itself.
      local nameField
      if not label then
         for k, v in pairs(c) do
            if type(v) == "string" then
               local lv = string.lower(v)
               if string.find(lv, "checkpoint", 1, true)
                  or string.find(lv, "travel", 1, true) then
                  label = v
               elseif k == "name" or k == "Name" or k == "label" then
                  nameField = v
               end
            end
         end
         if label and nameField then label = nameField end
      end
      if diagnose then
         CBH.print("  btn#" .. stats.unnamed .. " [" .. parentName .. ", " ..
            math.floor(c:GetWidth() or 0) .. "x" .. math.floor(c:GetHeight() or 0) ..
            "] tooltip: '" .. tostring(l1) .. "' / '" .. tostring(l2) .. "'" ..
            (label and " -> CHECKPOINT" or ""))
         local fields = {}
         for k, v in pairs(c) do
            local tv = type(v)
            if tv == "string" or tv == "number" or tv == "boolean" then
               table.insert(fields, tostring(k) .. "=" .. tostring(v))
            else
               table.insert(fields, tostring(k) .. ":" .. tv)
            end
         end
         if #fields > 0 then
            CBH.print("    fields: " .. string.sub(table.concat(fields, ", "), 1, 220))
         end
         local nt = c.GetNormalTexture and c:GetNormalTexture()
         local tex = nt and nt:GetTexture()
         if tex then CBH.print("    texture: " .. tostring(tex)) end
      end
      if label then
         local cx, cy = c:GetCenter()
         if cx and cy then
            table.insert(out, { btn = c, name = label,
               x = (cx - left) / w, y = (top - cy) / h })
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

local function DoPort()
   local cps, stats = FindCheckpoints(false)
   if #cps == 0 then
      CBH.print("No checkpoints found (unnamed map buttons: " .. stats.unnamed ..
         "). Run /cbh portscan with the map open and report the output.")
      return
   end
   -- Aim for the current arrow waypoint if there is one, else the player.
   local rx, ry
   if CBH.Arrow.GetTargetXY then rx, ry = CBH.Arrow.GetTargetXY() end
   if not rx then rx, ry = GetPlayerMapPosition("player") end
   if not rx or (rx == 0 and ry == 0) then rx, ry = 0.5, 0.5 end
   local best, bestD
   for _, cp in ipairs(cps) do
      local dx, dy = cp.x - rx, cp.y - ry
      local d = dx * dx + dy * dy
      if not bestD or d < bestD then best, bestD = cp, d end
   end
   CBH.print("Traveling to nearest checkpoint: " .. tostring(best.name))
   best.btn:Click()
end
Advisor.DoPort = DoPort

function Advisor.Port()
   if InCombatLockdown() then
      CBH.print("Cannot travel while in combat.")
      return
   end
   if not WorldMapFrame:IsShown() then
      -- The server populates its map buttons on show; scan on a short delay.
      -- (ToggleWorldMap does not exist on this client.)
      ShowUIPanel(WorldMapFrame)
      Advisor.portAt = GetTime() + 0.4
      return
   end
   DoPort()
end
