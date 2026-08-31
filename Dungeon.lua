-- CallboardHunter Dungeon: callboard automation inside instances -- 5-man
-- dungeons AND raids. IsInInstance() already reported both; what was missing was
-- raid boss data, so a raid card naming only its boss could never match.
--
-- Summon Callboard (donation-shop spell) drops a board anywhere, including in a
-- dungeon. This runs the tedious part: reroll until the card for THIS dungeon
-- appears, accept it, share it with the group.
--
-- The rerolling itself is not here. It is the same loop favourites needs, so it
-- lives in Board.lua and this file supplies the only part that is specific to
-- dungeons: "is this card for the instance I am standing in". What stays here is
-- the instance detection, that question, the entry reminder and quest sharing.
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

-- ------------------------------------------------------------------ the run

-- Share the freshly accepted quest, once, and only when there is a group.
function D.OnQuestAccepted(questIndex)
   local r = CBH.Board and CBH.Board.run
   if not r or r.shared then return end
   r.shared = true
   CBH.Board.run = nil
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
-- instance, then hands the tick to the shared engine. The instance match is all
-- this file contributes: rerolling, the verified confirm, the cap and the
-- reserve live in Board.lua and are shared with favourites.
function D.Poll(now)
   if not Opt("dungeonAuto", false) then return end
   local board = _G["ObjectivesMainFrame"]
   if not (board and board.IsShown and board:IsShown()) then
      if CBH.Board.run and CBH.Board.run.label == "dungeon" then
         CBH.Board.Stop("the board despawned")
      end
      return
   end
   if not CBH.Board.run then
      local instance = D.CurrentInstance()
      if not instance then return end   -- only automate inside dungeons
      D.instance = instance
      CBH.Board.Start({
         label = "dungeon",
         match = function(cards) return D.MatchCard(cards, D.instance) end,
      })
   end
   CBH.Board.Poll(now)
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
         .. " | reserve: " .. CBH.Board.Gold(Opt("dungeonGoldReserve", 0))
         .. " | share: " .. (Opt("dungeonShare", true) and "ON" or "OFF"))
      CBH.print("/cbh dungeon on|off | rerolls <n|unlimited> | reserve <gold> | share on|off")
   end
end
