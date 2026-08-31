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
--
-- Slot-indexed, not ipairs: Board.ReadCards is sparse by contract (see its
-- header), and an ipairs walk stops at the first hidden slot - which would call
-- a board holding this instance's card "no match" and pay 10g to reroll it away.
function D.MatchCard(cards, instance)
   if not instance then return nil end
   cards = cards or {}
   local low = string.lower(instance)
   for i = 1, CBH.Board.SLOTS do
      local c = cards[i]
      if c and string.find(string.lower(c.text), low, 1, true) then
         return i, "names the dungeon"
      end
   end
   for i = 1, CBH.Board.SLOTS do
      local c = cards[i]
      if c and CBH.SpawnDB.TextMatchesDungeon
         and CBH.SpawnDB.TextMatchesDungeon(c.text, instance) then
         return i, "names one of its bosses"
      end
   end
   return nil
end

-- ------------------------------------------------------------------ the run

-- Share the freshly accepted quest, once, and only when there is a group.
-- QUEST_ACCEPTED fires for every quest from every source, so the run has to be
-- ours before we end it and push it to the party.
--
-- Ending the run IS what makes this once-only - a second QUEST_ACCEPTED finds no
-- run and returns. (There was also an r.shared flag here, set on the line before
-- the run was nil'd, so nothing could ever read it back.)
function D.OnQuestAccepted(questIndex)
   local r = CBH.Board and CBH.Board.run
   if not r or r.label ~= "dungeon" then return end
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
   local board = _G["ObjectivesMainFrame"]
   local shown = board and board.IsShown and board:IsShown()
   -- Cleared AHEAD of the off-switch gate on purpose: a despawn is an
   -- observation about the world, not an action on it. Behind the gate, turning
   -- automation off mid-summon would leave D.worked set after the board went
   -- away, and the next board would be refused as though it were the one we had
   -- already worked. This is the release that matters in game, where the board
   -- is one long-lived frame that summons show and despawns hide.
   if not shown then D.worked = nil end
   if not Opt("dungeonAuto", false) then return end
   if not shown then
      if CBH.Board.run and CBH.Board.run.label == "dungeon" then
         CBH.Board.Stop("the board despawned")
      end
      return
   end
   if not CBH.Board.run then
      -- ONE auto-started run per board. Board.run going nil does NOT mean the
      -- board is fresh - it means our last run ended, and every way it can end
      -- leaves this board already worked:
      --
      --   * Accepted, and QUEST_ACCEPTED never arrived. Board.Poll's grace rail
      --     releases the run 2s after the click (Board.lua:200-209), so without
      --     this guard the very next tick starts a SECOND run against the board
      --     we just took a card from - and the card is gone, so it does not
      --     match, so it rerolls, at 10g 40s a go up to the cap.
      --   * Stopped on the reroll cap. A fresh run starts at rerolls = 0, which
      --     turns the cap into a per-run figure the board's 30s lifetime resets
      --     over and over, instead of the per-summon limit the player set.
      --
      -- Two things release it, and both mean "a different board". The despawn
      -- above is the one that fires in game. This one compares the frame we
      -- worked against the frame in front of us now: a board we have never seen
      -- before is unambiguously not the board we already worked, however it got
      -- here. It can only ever release the guard for a genuinely new frame, so
      -- it cannot mask the case above.
      --
      -- NOT released by a manual reroll: spotting one means tracking card
      -- signatures outside a run, and re-arming on it puts us straight back on
      -- the paid path. The player who rerolls by hand can take the card by hand
      -- - the board is theirs for ~30s.
      if D.worked == board then return end
      local instance = D.CurrentInstance()
      if not instance then return end   -- only automate inside dungeons
      D.instance = instance
      -- Marked on START, not on accept: what makes a restart cost gold is that a
      -- run happened here at all, not how it ended.
      if CBH.Board.Start({
         label = "dungeon",
         subject = instance,   -- what the player reads: "the Utgarde Keep quest"
         match = function(cards) return D.MatchCard(cards, D.instance) end,
         rerollMax = Opt("dungeonRerollMax", 10),
         goldReserve = Opt("dungeonGoldReserve", 0),
      }) then D.worked = board end
   end
   -- Drive our own run and nobody else's. Not politeness: a run that accepted
   -- without ever rerolling still has at = 0, so nothing rate-limits a second
   -- poll in the same pass, and it would click Select on the same card twice.
   if CBH.Board.run and CBH.Board.run.label == "dungeon" then CBH.Board.Poll(now) end
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
      -- Turning it off with a run in flight used to strand that run: D.Poll
      -- returns on the off switch before it reaches either the despawn stop or
      -- the label guard, so nothing polled it and nothing expired it. Board.run
      -- is shared now, so a stranded dungeon run also refused every /cbh hunt
      -- with "already working the board" until a /reload. Stopped after the line
      -- above so the player reads the switch, then what it did to the run.
      if verb == "off" and CBH.Board.run and CBH.Board.run.label == "dungeon" then
         CBH.Board.Stop("dungeon automation turned off")
      end
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
