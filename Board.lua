-- CallboardHunter Board: the callboard reroll engine, shared by every caller.
--
-- This started life inside Dungeon.lua, where it rerolled until the card for the
-- instance you were standing in appeared. Favourites wants the identical loop
-- with one thing different - which card counts as a win - so the loop lives here
-- and the caller supplies a `match(cards)` callback. Nothing in this file knows
-- what a dungeon or a favourite is; if it ever does, the boundary has slipped.
--
-- The rails are the point of the extraction, not an afterthought: the board
-- despawns after ~30 seconds, rerolls cost real gold, and StaticPopup1Button1 is
-- whatever dialog happens to be open. So the loop is bounded by a reroll cap, a
-- gold reserve, a cards-stopped-changing guard, and a confirmation step that
-- refuses to click any dialog that does not name itself as the reroll prompt.
-- Two callers now depend on those, so they are not caller-tunable.
--
-- What it deliberately does NOT do: cast Summon Callboard. CastSpellByName is
-- protected on 3.3.5 and needs a hardware event. You cast; this takes over when
-- the board appears, which also keeps CBH free of secure frames and taint.
local CBH = CallboardHunter
local Board = CBH.Board or {}
CBH.Board = Board

local DEFAULT_REROLL_COST = 104000     -- 10g 40s in copper, until we observe one
local SETTLE = 0.6                     -- seconds to let the board redraw
local MAX_UNCHANGED = 3                -- rerolls that changed nothing -> give up
-- How long Board.Accept waits for a caller to claim the run before ending it
-- itself. See Board.Poll: without this the engine depends on every caller having
-- an event hook, and the one that does not spends gold after it has already won.
local ACCEPT_GRACE = 2

-- The board always has three card slots, and any of them can be empty.
Board.SLOTS = 3

Board.run = nil        -- active run state, or nil
Board.lastCost = DEFAULT_REROLL_COST

-- ------------------------------------------------------------------ helpers

-- Text of every card currently on the board, keyed by SLOT NUMBER 1..Board.SLOTS.
--
-- SPARSE ON PURPOSE: a slot whose frame is hidden gets no entry, so slot 2 can
-- exist while slot 1 does not. Iterate with `for i = 1, CBH.Board.SLOTS`, never
-- ipairs - ipairs stops dead at the first hole, and a matcher that stops early
-- silently declares "no match" and pays 10g for a reroll while the card it
-- wanted is sitting right there on slot 2.
function Board.ReadCards()
   local out = {}
   for i = 1, Board.SLOTS do
      local card = _G["ObjectiveFrame" .. i]
      if card and card.IsShown and card:IsShown() then
         local texts = {}
         for r = 1, select("#", card:GetRegions()) do
            local reg = select(r, card:GetRegions())
            -- Skip the note CBH itself drew on this card. Advisor.lua:26-32 has
            -- the same skip for the same reason: 1.9.7 catalogued its own
            -- annotations and read them back as if the server had written them.
            -- Here the damage is worse than a dirty catalogue - the note names a
            -- zone ("Dungeon/raid: Naxxramas"), so a matcher keying on card text
            -- can match CBH's own words and accept the wrong quest.
            if reg ~= card.cbhNote
               and reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
               local t = reg:GetText()
               if t and t ~= "" then texts[#texts + 1] = t end
            end
         end
         out[i] = { frame = card, text = table.concat(texts, " | ") }
      end
   end
   return out
end

-- The board's Reroll button: an enabled Button under the board whose text
-- mentions reroll. Returns nil if the server changes its UI, which stops the run
-- rather than clicking something unknown.
function Board.FindReroll()
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
function Board.FindRerollPopup()
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

-- Public because callers report the same reserve back to the player.
function Board.Gold(copper)
   return string.format("%dg %ds", math.floor(copper / 10000),
      math.floor((copper % 10000) / 100))
end
local Gold = Board.Gold

-- ------------------------------------------------------------------ the run

function Board.Stop(reason)
   local r = Board.run
   Board.run = nil
   if not r then return end
   local msg = "Callboard automation stopped: " .. reason
   if r.rerolls > 0 then
      msg = msg .. " (" .. r.rerolls .. " reroll" .. (r.rerolls == 1 and "" or "s")
         .. ", spent " .. Gold(r.spent) .. ")"
   end
   CBH.print(msg)
   CBH.Log("board", "STOP " .. reason .. " rerolls=" .. r.rerolls
      .. " spent=" .. r.spent)
end

-- Can we afford another reroll without eating into the reserve? The reserve is
-- the caller's number, not ours - see Board.Start.
function Board.CanAffordReroll(reserve)
   reserve = reserve or 0
   local have = (GetMoney and GetMoney()) or 0
   return (have - Board.lastCost) >= reserve, have, reserve
end

-- `opts.match` is the only thing that varies between callers: Dungeon passes
-- "is this card for the instance I am in", Favourites passes "is this card's
-- target on my list". Refusing to start a second run is what keeps the two of
-- them from fighting over one board.
--
-- THE MATCH CONTRACT. `match(cards)` receives exactly what Board.ReadCards
-- returns: a table keyed by SLOT NUMBER 1..Board.SLOTS, SPARSE, because a
-- hidden card slot has no entry. Walk it with `for i = 1, CBH.Board.SLOTS do
-- local c = cards[i]; if c then ... end end`; ipairs stops at the first hole and
-- turns a card that IS on the board into a paid reroll. Return the slot number
-- of the winning card (plus an optional reason string), or nil for no match. The
-- number must be a slot that exists in `cards` - naming one that does not stops
-- the run rather than falling through to the reroll path.
--
-- The cap and the reserve arrive as numbers rather than being read from saved
-- variables here, so the engine never has to know whose settings they are. The
-- run snapshots them at Start, which is also when the player last had a chance
-- to change their mind.
--
-- `label` is identity - it is what a caller compares to decide whether a live
-- run is its own. `subject` is display - it is the noun the player reads in
-- "taking the Utgarde Keep quest". Keeping them apart matters because the
-- ownership guards would otherwise be tied to whatever reads well in a sentence.
function Board.Start(opts)
   if Board.run then return false end
   if not (opts and opts.match) then return false end
   Board.run = { label = opts.label or "board", match = opts.match,
                 subject = opts.subject or opts.label or "board",
                 onAccept = opts.onAccept, rerolls = 0, spent = 0,
                 rerollMax = opts.rerollMax or 10,
                 goldReserve = opts.goldReserve or 0,
                 unchanged = 0, at = 0, phase = "match", lastSig = nil }
   CBH.Log("board", "START " .. tostring(opts.label))
   return true
end

-- Drive the active run one tick. Callers own deciding WHETHER to poll (their
-- own enable flag, their own board checks); this owns what happens next.
function Board.Poll(now)
   local r = Board.run
   if not r then return end
   if r.phase == "accepted" then
      -- The hunt is already won. A caller may want the run to outlive the click
      -- for a moment (Dungeon reads its quest-log index off QUEST_ACCEPTED and
      -- ends the run there), so give it a grace window - then end the run
      -- ourselves. Neither half of this is optional: without the return the next
      -- 0.5s tick clicks Select again, and without the clear a caller with no
      -- event hook leaves Board.run set forever, which blocks every later run
      -- from BOTH features until a /reload.
      if not r.doneAt or now >= r.doneAt then Board.run = nil end
      return
   end
   if r.phase == "confirm" then Board.TickConfirm(now) else Board.Tick(now) end
end

function Board.Tick(now)
   local r = Board.run
   if not r then return end
   local board = _G["ObjectivesMainFrame"]
   if not (board and board.IsShown and board:IsShown()) then
      Board.Stop("the board despawned")   -- 30s window expired, or it was dismissed
      return
   end
   if r.at > 0 and now < r.at then return end

   local cards = Board.ReadCards()
   local sig = ""
   for i = 1, Board.SLOTS do sig = sig .. "|" .. ((cards[i] and cards[i].text) or "") end

   if r.phase == "wait" then
      -- Waiting for a reroll to actually change the cards.
      if sig == r.lastSig then
         r.unchanged = r.unchanged + 1
         if r.unchanged >= MAX_UNCHANGED then
            Board.Stop("the cards stopped changing")
            return
         end
         r.at = now + SETTLE
         return
      end
      r.unchanged = 0
      r.phase = "match"
   end

   local idx, why = r.match(cards)
   if idx then
      -- A caller that names an empty slot used to fall through to "no match",
      -- which is the PAID branch. Say so and stop instead: a matcher that has
      -- lost track of the board is not a reason to spend the player's gold.
      if not cards[idx] then
         Board.Stop("the match callback named a card that is not on the board")
         return
      end
      Board.Accept(cards[idx], why)
      return
   end

   -- No match: consider rerolling.
   local cap = r.rerollMax
   if cap > 0 and r.rerolls >= cap then
      Board.Stop("reroll limit reached (" .. cap .. ") with no card for " .. r.subject)
      return
   end
   local ok, have, reserve = Board.CanAffordReroll(r.goldReserve)
   if not ok then
      Board.Stop("that would drop you below your " .. Gold(reserve) .. " reserve (you have "
         .. Gold(have) .. ")")
      return
   end

   local btn = Board.FindReroll()
   if not btn then
      Board.Stop("no Reroll button found on the board")
      return
   end
   r.before = have
   r.lastSig = sig
   r.phase = "confirm"
   r.at = now + SETTLE
   btn:Click()
   CBH.Log("board", "REROLL #" .. (r.rerolls + 1) .. " clicked")
end

-- Confirm step runs on its own so the popup has a frame to appear in.
function Board.TickConfirm(now)
   local r = Board.run
   if not r or r.phase ~= "confirm" then return end
   if now < r.at then return end
   local yes, txt = Board.FindRerollPopup()
   if not yes then
      if txt then
         -- A dialog is open that is NOT the reroll confirmation. Never click it.
         Board.Stop("an unexpected dialog is open, refusing to confirm it")
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
      Board.lastCost = delta        -- learn the real cost
      r.spent = r.spent + delta
   else
      r.spent = r.spent + Board.lastCost
   end
   CBH.print("Callboard reroll " .. r.rerolls .. " - spent " .. Gold(r.spent) .. " so far.")
   r.phase = "wait"
   r.at = now + SETTLE
end

function Board.Accept(card, why)
   local r = Board.run
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
      Board.Stop("found the card but not its Select button")
      return
   end
   -- A reason is optional in the match contract, so the message survives without
   -- one rather than erroring mid-click and leaving the run half-done.
   local reason = why or "it matched"
   CBH.print("Callboard: taking the " .. r.subject .. " quest (" .. reason .. ")"
      .. (r.rerolls > 0 and (" after " .. r.rerolls .. " reroll"
          .. (r.rerolls == 1 and "" or "s") .. ", " .. Gold(r.spent)) or "") .. ".")
   CBH.Log("board", "ACCEPT " .. reason .. " rerolls=" .. r.rerolls .. " spent=" .. r.spent)
   r.phase = "accepted"
   -- Deadline for a caller to claim the run; Board.Poll ends it after this.
   r.doneAt = ((GetTime and GetTime()) or 0) + ACCEPT_GRACE
   sel:Click()
   -- The caller decides what "accepted" means for it - Dungeon shares the quest
   -- on QUEST_ACCEPTED, which is the event that tells it the quest log index.
   if r.onAccept then r.onAccept(card, why) end
end
