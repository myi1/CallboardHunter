-- CallboardHunter Dungeon: callboard automation inside instances -- 5-man
-- dungeons AND raids. IsInInstance() already reported both; what was missing was
-- raid boss data, so a raid card naming only its boss could never match.
--
-- Summon Callboard (donation-shop spell) drops a board anywhere, including in a
-- dungeon. This runs the tedious part: reroll until the card for THIS dungeon
-- appears, accept it, share it with the group.
--
-- What it deliberately does NOT do: cast the spell. CastSpellByName is protected
-- on 3.3.5 and needs a hardware event, so no addon can summon the board for you.
-- You cast; this takes over when the board appears. That also keeps CBH free of
-- secure frames and taint.
--
-- Two facts from the spell tooltip shape everything: the board lasts 30 SECONDS
-- and the spell has a 45s cooldown. The reroll loop is bounded by the board
-- despawning no matter how much gold you have; gold limits are the second brake.
local CBH = CallboardHunter
local D = CBH.Dungeon or {}
CBH.Dungeon = D

local DEFAULT_REROLL_COST = 104000     -- 10g 40s in copper, until we observe one
local SETTLE = 0.6                     -- seconds to let the board redraw
local MAX_UNCHANGED = 3                -- rerolls that changed nothing -> give up

D.run = nil        -- active run state, or nil
D.lastCost = DEFAULT_REROLL_COST

local function Opt(key, default)
   local o = CBH.db and CBH.db.options
   if not o or o[key] == nil then return default end
   return o[key]
end

-- ------------------------------------------------------------------ helpers

-- The instance we are standing in, or nil when outdoors. GetRealZoneText inside
-- an instance returns the instance name ("Utgarde Keep").
function D.CurrentInstance()
   if IsInInstance then
      local inside, kind = IsInInstance()
      if not inside then return nil end
      if kind ~= "party" and kind ~= "raid" then return nil end
   else
      return nil
   end
   local z = GetRealZoneText and GetRealZoneText()
   if z == "" then return nil end
   return z
end

-- Text of every card currently on the board, indexed by card number.
function D.ReadCards()
   local out = {}
   for i = 1, 3 do
      local card = _G["ObjectiveFrame" .. i]
      if card and card.IsShown and card:IsShown() then
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

-- Which card (if any) is for the instance we are in (dungeon or raid). Prefers a card that names
-- the instance outright ("Slay X in Utgarde Keep"), then one naming a boss of
-- it - a boss is decisive because SpawnDB knows bosses per DUNGEON, so Utgarde
-- Keep and Utgarde Pinnacle are not confused despite sharing a zone.
function D.MatchCard(cards, instance)
   if not instance then return nil end
   local low = string.lower(instance)
   for i, c in ipairs(cards) do
      if string.find(string.lower(c.text), low, 1, true) then return i, "names the dungeon" end
   end
   for i, c in ipairs(cards) do
      if CBH.SpawnDB.TextMatchesDungeon
         and CBH.SpawnDB.TextMatchesDungeon(c.text, instance) then
         return i, "names one of its bosses"
      end
   end
   return nil
end

-- The board's Reroll button: an enabled Button under the board whose text
-- mentions reroll. Returns nil if the server changes its UI, which stops the run
-- rather than clicking something unknown.
function D.FindReroll()
   local board = _G["ObjectivesMainFrame"]
   if not (board and board.IsShown and board:IsShown()) then return nil end
   local found
   local function walk(f, depth)
      if found or depth > 5 then return end
      for i = 1, select("#", f:GetChildren()) do
         local c = select(i, f:GetChildren())
         if c and c.IsShown and c:IsShown() then
            if c.GetObjectType and c:GetObjectType() == "Button" then
               local label = c.GetText and c:GetText()
               if not label then
                  for r = 1, select("#", c:GetRegions()) do
                     local reg = select(r, c:GetRegions())
                     if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                        label = reg:GetText() or label
                     end
                  end
               end
               if label and string.find(string.lower(label), "reroll", 1, true) then
                  found = c
                  return
               end
            end
            walk(c, depth + 1)
         end
      end
   end
   walk(board, 0)
   return found
end

-- The reroll confirmation popup, and ONLY that popup.
--
-- Clicking StaticPopup1Button1 blindly is dangerous: whatever dialog happens to
-- be open gets confirmed, and that could be "delete this item" or "abandon this
-- quest". So the popup must identify itself as the reroll confirmation before we
-- touch it. If some other dialog is up, we do not click anything.
function D.FindRerollPopup()
   for i = 1, 4 do
      local p = _G["StaticPopup" .. i]
      if p and p.IsShown and p:IsShown() then
         local fs = _G["StaticPopup" .. i .. "Text"]
         local txt = fs and fs.GetText and fs:GetText() or ""
         if string.find(string.lower(txt), "reroll", 1, true) then
            return _G["StaticPopup" .. i .. "Button1"], txt
         end
         return nil, txt   -- a popup, but NOT ours: refuse
      end
   end
   return nil, nil
end

local function Gold(copper)
   return string.format("%dg %ds", math.floor(copper / 10000),
      math.floor((copper % 10000) / 100))
end

-- ------------------------------------------------------------------ the run

function D.Stop(reason)
   local r = D.run
   D.run = nil
   if not r then return end
   local msg = "Callboard automation stopped: " .. reason
   if r.rerolls > 0 then
      msg = msg .. " (" .. r.rerolls .. " reroll" .. (r.rerolls == 1 and "" or "s")
         .. ", spent " .. Gold(r.spent) .. ")"
   end
   CBH.print(msg)
   CBH.Log("dungeon", "STOP " .. reason .. " rerolls=" .. r.rerolls
      .. " spent=" .. r.spent)
end

-- Can we afford another reroll without eating into the reserve?
function D.CanAffordReroll()
   local reserve = Opt("dungeonGoldReserve", 0)
   local have = (GetMoney and GetMoney()) or 0
   return (have - D.lastCost) >= reserve, have, reserve
end

function D.Start(instance)
   if D.run then return end
   D.run = { instance = instance, rerolls = 0, spent = 0, unchanged = 0,
             at = 0, phase = "match", lastSig = nil, shared = false }
   CBH.Log("dungeon", "START in " .. tostring(instance))
end

-- Driven by the Advisor ticker while the board is open.
function D.Tick(now)
   local r = D.run
   if not r then return end
   local board = _G["ObjectivesMainFrame"]
   if not (board and board.IsShown and board:IsShown()) then
      D.Stop("the board despawned")   -- 30s window expired, or it was dismissed
      return
   end
   if r.at > 0 and now < r.at then return end

   local cards = D.ReadCards()
   local sig = ""
   for i = 1, 3 do sig = sig .. "|" .. ((cards[i] and cards[i].text) or "") end

   if r.phase == "wait" then
      -- Waiting for a reroll to actually change the cards.
      if sig == r.lastSig then
         r.unchanged = r.unchanged + 1
         if r.unchanged >= MAX_UNCHANGED then
            D.Stop("the cards stopped changing")
            return
         end
         r.at = now + SETTLE
         return
      end
      r.unchanged = 0
      r.phase = "match"
   end

   local idx, why = D.MatchCard(cards, r.instance)
   if idx then
      D.Accept(cards[idx], why)
      return
   end

   -- No match: consider rerolling.
   local cap = Opt("dungeonRerollMax", 10)
   if cap > 0 and r.rerolls >= cap then
      D.Stop("reroll limit reached (" .. cap .. ") with no card for " .. r.instance)
      return
   end
   local ok, have, reserve = D.CanAffordReroll()
   if not ok then
      D.Stop("that would drop you below your " .. Gold(reserve) .. " reserve (you have "
         .. Gold(have) .. ")")
      return
   end

   local btn = D.FindReroll()
   if not btn then
      D.Stop("no Reroll button found on the board")
      return
   end
   r.before = have
   r.lastSig = sig
   r.phase = "confirm"
   r.at = now + SETTLE
   btn:Click()
   CBH.Log("dungeon", "REROLL #" .. (r.rerolls + 1) .. " clicked")
end

-- Confirm step runs on its own so the popup has a frame to appear in.
function D.TickConfirm(now)
   local r = D.run
   if not r or r.phase ~= "confirm" then return end
   if now < r.at then return end
   local yes, txt = D.FindRerollPopup()
   if not yes then
      if txt then
         -- A dialog is open that is NOT the reroll confirmation. Never click it.
         D.Stop("an unexpected dialog is open, refusing to confirm it")
      else
         -- No popup at all: some servers reroll without confirmation.
         r.rerolls = r.rerolls + 1
         r.phase = "wait"
         r.at = now + SETTLE
      end
      return
   end
   yes:Click()
   r.rerolls = r.rerolls + 1
   local nowMoney = (GetMoney and GetMoney()) or 0
   if r.before and r.before > nowMoney then
      local delta = r.before - nowMoney
      D.lastCost = delta            -- learn the real cost
      r.spent = r.spent + delta
   else
      r.spent = r.spent + D.lastCost
   end
   CBH.print("Callboard reroll " .. r.rerolls .. " - spent " .. Gold(r.spent) .. " so far.")
   r.phase = "wait"
   r.at = now + SETTLE
end

function D.Accept(card, why)
   local r = D.run
   if not (r and card) then return end
   -- The card's Select button is its first shown Button child.
   local sel
   for i = 1, select("#", card.frame:GetChildren()) do
      local c = select(i, card.frame:GetChildren())
      if c and c.IsShown and c:IsShown() and c.GetObjectType
         and c:GetObjectType() == "Button" then
         sel = c
         break
      end
   end
   if not sel then
      D.Stop("found the card but not its Select button")
      return
   end
   CBH.print("Callboard: taking the " .. r.instance .. " quest (" .. why .. ")"
      .. (r.rerolls > 0 and (" after " .. r.rerolls .. " reroll"
          .. (r.rerolls == 1 and "" or "s") .. ", " .. Gold(r.spent)) or "") .. ".")
   CBH.Log("dungeon", "ACCEPT " .. why .. " rerolls=" .. r.rerolls .. " spent=" .. r.spent)
   r.phase = "accepted"
   sel:Click()
   -- Sharing happens on QUEST_ACCEPTED, which tells us the quest log index.
end

-- Share the freshly accepted quest, once, and only when there is a group.
function D.OnQuestAccepted(questIndex)
   local r = D.run
   if not r or r.shared then return end
   r.shared = true
   D.run = nil
   if not Opt("dungeonShare", true) then return end
   local party = (GetNumPartyMembers and GetNumPartyMembers()) or 0
   local raid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
   if party == 0 and raid == 0 then
      CBH.Log("dungeon", "SHARE skipped: solo")
      return
   end
   if not (questIndex and SelectQuestLogEntry and QuestLogPushQuest) then return end
   SelectQuestLogEntry(questIndex)
   local ok = pcall(QuestLogPushQuest)
   CBH.Log("dungeon", "SHARE idx=" .. tostring(questIndex) .. " ok=" .. tostring(ok))
   if ok then CBH.print("Shared the quest with your group.") end
end

-- Tell the player, once per instance, that the board is worth summoning here.
-- Without this the feature is invisible: it is off by default and only ever acts
-- once a board is already open, so a player who never runs /cbh dungeon on gets
-- no signal that anything exists. (This was in the design and was missed in the
-- first implementation - the symptom was walking into a dungeon and seeing
-- nothing at all.)
local OFF_HINTS = 3   -- stop nagging about the off switch after a few dungeons

function D.OnZoneChanged()
   local instance = D.CurrentInstance()
   if not instance then
      D.announced = nil
      return
   end
   if D.announced == instance then return end
   D.announced = instance
   if Opt("dungeonAuto", false) then
      CBH.print(instance .. ": cast Summon Callboard and CBH will reroll to this"
         .. " instance's quest, accept it, and share it with the group.")
      return
   end
   local o = CBH.db and CBH.db.options
   local shown = (o and o.dungeonHintsShown) or 0
   if shown >= OFF_HINTS then return end
   if o then o.dungeonHintsShown = shown + 1 end
   CBH.print(instance .. ": callboard automation is OFF. /cbh dungeon on lets CBH"
      .. " reroll the board to this instance's quest, accept it and share it."
      .. " (" .. (OFF_HINTS - shown - 1) .. " more reminder"
      .. ((OFF_HINTS - shown - 1) == 1 and "" or "s") .. ".)")
end

-- ---------------------------------------------------------------- entry point

-- Called by the Advisor ticker. Starts a run when the board opens inside an
-- instance, then drives it.
function D.Poll(now)
   if not Opt("dungeonAuto", false) then return end
   local board = _G["ObjectivesMainFrame"]
   local open = board and board.IsShown and board:IsShown()
   if not open then
      if D.run then D.Stop("the board despawned") end
      return
   end
   if not D.run then
      local instance = D.CurrentInstance()
      if not instance then return end   -- only automate inside dungeons
      D.Start(instance)
   end
   if D.run and D.run.phase == "confirm" then D.TickConfirm(now) else D.Tick(now) end
end

-- /cbh dungeon ...
function D.Command(arg)
   arg = string.lower(arg or "")
   local _, _, verb, rest = string.find(arg, "^(%S*)%s*(.-)$")
   local o = CBH.db and CBH.db.options
   if not o then return end
   if verb == "on" or verb == "off" then
      o.dungeonAuto = (verb == "on")
      CBH.print("Dungeon callboard automation " .. (o.dungeonAuto and "ON" or "OFF")
         .. ((verb == "on") and " - you still cast Summon Callboard yourself;"
             .. " CBH takes over when the board appears." or "."))
   elseif verb == "rerolls" then
      if rest == "unlimited" or rest == "0" then
         o.dungeonRerollMax = 0
         CBH.print("Reroll limit: unlimited (the board still despawns after ~30s).")
      else
         local n = tonumber(rest)
         if not n or n < 0 then
            CBH.print("Usage: /cbh dungeon rerolls <number|unlimited>")
         else
            o.dungeonRerollMax = math.floor(n)
            CBH.print("Reroll limit: " .. o.dungeonRerollMax .. " per summon.")
         end
      end
   elseif verb == "reserve" then
      local g = tonumber(rest)
      if not g or g < 0 then
         CBH.print("Usage: /cbh dungeon reserve <gold>  (never reroll below this)")
      else
         o.dungeonGoldReserve = math.floor(g) * 10000
         CBH.print("Gold reserve: " .. math.floor(g) .. "g - rerolling stops before"
            .. " dropping below it.")
      end
   elseif verb == "share" then
      o.dungeonShare = (rest ~= "off")
      CBH.print("Quest sharing " .. (o.dungeonShare and "ON" or "OFF") .. ".")
   else
      CBH.print("Dungeon automation: " .. (Opt("dungeonAuto", false) and "ON" or "OFF")
         .. " | rerolls: " .. (Opt("dungeonRerollMax", 10) == 0 and "unlimited"
             or Opt("dungeonRerollMax", 10))
         .. " | reserve: " .. Gold(Opt("dungeonGoldReserve", 0))
         .. " | share: " .. (Opt("dungeonShare", true) and "ON" or "OFF"))
      CBH.print("/cbh dungeon on|off | rerolls <n|unlimited> | reserve <gold> | share on|off")
   end
end
