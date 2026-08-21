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
            card.cbhNote:SetPoint("BOTTOM", card, "BOTTOM", 0, 44)
            card.cbhNote:SetWidth(card:GetWidth() - 30)
         end
         card.cbhNote:SetText(note or "")
      end
   end
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
end)

-- ------------------------------------------------------------- checkpoint port

local function FindCheckpoints()
   local out = {}
   if not WorldMapButton then return out end
   local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
   local left, top = WorldMapButton:GetLeft(), WorldMapButton:GetTop()
   if not (w and h and left and top) or w == 0 or h == 0 then return out end
   for i = 1, select("#", WorldMapButton:GetChildren()) do
      local c = select(i, WorldMapButton:GetChildren())
      if c and not c:GetName() and c:GetObjectType() == "Button" and c:IsShown() then
         local label
         local onEnter = c:GetScript("OnEnter")
         if onEnter then
            pcall(onEnter, c)
            local l1 = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText() or ""
            local l2 = GameTooltipTextLeft2 and GameTooltipTextLeft2:GetText() or ""
            GameTooltip:Hide()
            local combined = string.lower(l1 .. " " .. l2)
            if string.find(combined, "checkpoint", 1, true)
               or string.find(combined, "travel", 1, true) then
               label = l1 ~= "" and l1 or "Checkpoint"
            end
         end
         if label then
            local cx, cy = c:GetCenter()
            if cx and cy then
               table.insert(out, { btn = c, name = label,
                  x = (cx - left) / w, y = (top - cy) / h })
            end
         end
      end
   end
   return out
end

function Advisor.Port()
   if InCombatLockdown() then
      CBH.print("Cannot travel while in combat.")
      return
   end
   if not WorldMapFrame:IsShown() then ToggleWorldMap() end
   local cps = FindCheckpoints()
   if #cps == 0 then
      CBH.print("No checkpoints found on this map view. Open the zone map that has your discovered checkpoints.")
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
