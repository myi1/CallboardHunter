-- CallboardHunter Favourites: mark callboard quests you want, and hunt for them.
--
-- Keys on the TARGET, not the title. A callboard title reads
-- "<flavour prefix>: <target>", and the prefix is decorative - "Dungeon Crawl:
-- Loken" and "Wanted: Loken" are the same contract. Favouriting the title would
-- miss the same job under a different prefix.
local CBH = CallboardHunter
local Fav = CBH.Favourites or {}
CBH.Favourites = Fav

-- A hunt inherits the dungeon brakes until the player sets a favourites-side
-- one. Two separate features spending the same purse should not need the reserve
-- typed in twice, and a player who already said "never go below 500g" meant it.
local function Opt(key, fallbackKey, default)
   local o = CBH.db and CBH.db.options
   if not o then return default end
   if o[key] ~= nil then return o[key] end
   if o[fallbackKey] ~= nil then return o[fallbackKey] end
   return default
end

function Fav.RerollMax() return Opt("favRerollMax", "dungeonRerollMax", 10) end
function Fav.GoldReserve() return Opt("favGoldReserve", "dungeonGoldReserve", 0) end

function Fav.IsFavourite(target)
   if not (target and CBH.db and CBH.db.favourites) then return false end
   return CBH.db.favourites[target] == true
end

function Fav.Toggle(target)
   if not (target and target ~= "" and CBH.db) then return false end
   CBH.db.favourites = CBH.db.favourites or {}
   if CBH.db.favourites[target] then
      CBH.db.favourites[target] = nil
      return false
   end
   CBH.db.favourites[target] = true
   return true
end

function Fav.Count()
   local n = 0
   for _ in pairs((CBH.db and CBH.db.favourites) or {}) do n = n + 1 end
   return n
end

-- Which card (if any) is a favourite. Signature matches what Board.Start wants.
--
-- Slot-indexed, not ipairs: Board.ReadCards is sparse by contract (see its
-- header), so a hidden card 1 would end an ipairs walk before it ever reached
-- the favourite sitting on card 2 - and "no match" is the branch that spends
-- 10g on a reroll.
function Fav.MatchCards(cards)
   if Fav.Count() == 0 then return nil end
   cards = cards or {}
   for i = 1, CBH.Board.SLOTS do
      local c = cards[i]
      -- A card's text is every FontString joined; check each line, because the
      -- title and the objective are separate lines on the same card.
      for line in string.gmatch((c and c.text) or "", "[^|]+") do
         -- Trim BOTH ends before TargetOf sees it: Board.ReadCards joins lines
         -- with " | ", so every non-final line carries a trailing space, and
         -- TargetOf's description-line guard checks for a trailing "." on the
         -- raw string. Left-trimming only would let a stray trailing space
         -- hide that "." and let a description line slip through as a target.
         local trimmed = string.gsub(line, "^%s+", "")
         trimmed = string.gsub(trimmed, "%s+$", "")
         local target = CBH.SpawnDB.TargetOf(trimmed)
         if target and Fav.IsFavourite(target) then
            return i, "favourite: " .. target
         end
      end
   end
   return nil
end

-- Bundled database merged with everything the catalogue has learned.
function Fav.List()
   local rows, byTarget = {}, {}
   local function add(target, lo, hi)
      if not target or target == "" then return end
      local e = byTarget[target]
      if e then
         if lo and (not e.lo or lo < e.lo) then e.lo = lo end
         if hi and (not e.hi or hi > e.hi) then e.hi = hi end
         return
      end
      e = { target = target, lo = lo, hi = hi }
      byTarget[target] = e
      rows[#rows + 1] = e
   end
   for _, q in ipairs((CBH.SpawnDB and CBH.SpawnDB.QUESTS) or {}) do
      add(q.target, q.lo, q.hi)
   end
   for text, meta in pairs((CBH.db and CBH.db.cardCatalogue) or {}) do
      -- Skip CBH's own annotations. Before 1.9.8 the catalogue recorded them
      -- (Export.lua's |c guard is newer than the databases it protects), and an
      -- upgraded client still carries hundreds. Left in, they become PICKABLE
      -- rows here - and a favourite keyed on "Naxxramas|r" is one no real card
      -- can ever match, so the next hunt rerolls to the cap and cannot win.
      -- Core.lua purges them from the database too; this keeps the view honest
      -- for a client that has not reloaded yet.
      if not string.find(text, "|c", 1, true) then
         add(CBH.SpawnDB.TargetOf(text), meta and meta.lo, meta and meta.hi)
      end
   end
   for _, e in ipairs(rows) do e.favourite = Fav.IsFavourite(e.target) end
   table.sort(rows, function(a, b) return a.target < b.target end)
   return rows
end

-- Abort a hunt without having to close the board. Only ever ours: a dungeon run
-- that happens to be live is not this command's to kill.
function Fav.Stop()
   local r = CBH.Board.run
   if not (r and r.label == "favourites") then
      CBH.print("No favourites hunt is running.")
      return false
   end
   CBH.Board.Stop("you stopped the hunt")
   return true
end

-- Explicit start only. There is no 30-second timer at a permanent callboard, so
-- nothing may spend gold without being asked for in that moment - unlike the
-- dungeon case, where the board despawning is a natural brake.
function Fav.Hunt(arg)
   if string.lower(arg or "") == "stop" then return Fav.Stop() end
   local board = _G["ObjectivesMainFrame"]
   if not (board and board.IsShown and board:IsShown()) then
      CBH.print("Open a callboard first, then hunt.")
      return false
   end
   if Fav.Count() == 0 then
      CBH.print("No favourites yet - click the star on a card, or pick some in"
         .. " /cbh config. Hunting with an empty list would reroll forever.")
      return false
   end
   if CBH.Board.run then
      CBH.print("Already working the board - let it finish, or /cbh hunt stop.")
      return false
   end
   local cap = Fav.RerollMax()
   local reserve = Fav.GoldReserve()
   local started = CBH.Board.Start({
      label = "favourites",
      -- "label" is the ownership token ("favourites"); "subject" is what the
      -- player reads. Leaving subject unset would fall back to the label
      -- itself and print "taking the favourites quest" - grammatically off,
      -- and a wasted chance to reuse Task 2's label/subject split the way
      -- Dungeon.lua does ("taking the Utgarde Keep quest").
      subject = "favourite",
      match = Fav.MatchCards,
      -- The brakes are the dungeon path's until /cbh fav says otherwise. A hunt
      -- that inherited neither (the shipped default) gave a player with a 500g
      -- reserve set exactly no reserve at all the moment they typed /cbh hunt.
      rerollMax = cap,
      goldReserve = reserve,
      -- Favourites has no QUEST_ACCEPTED hook by design, so nothing else ends
      -- this run. Board.Poll's grace window would eventually, but leaving it to
      -- that means one more 0.5s tick of a live run after the hunt has already
      -- won - and a won hunt should be over the instant it is won.
      onAccept = function() CBH.Board.run = nil end,
   })
   if started then
      -- Say the bound BEFORE the first reroll. Otherwise the player's first
      -- feedback from a gold-spending loop is "reroll 1 - spent 10g 40s".
      local n = Fav.Count()
      CBH.print(CBH.UI.Stamp("active") .. " hunting " .. n .. " favourite"
         .. (n == 1 and "" or "s") .. ", "
         .. (cap == 0 and "unlimited rerolls" or ("up to " .. cap .. " reroll"
             .. (cap == 1 and "" or "s") .. " (~"
             .. CBH.Board.Gold(cap * CBH.Board.lastCost) .. ")"))
         .. ", reserve " .. CBH.Board.Gold(reserve)
         .. ". /cbh hunt stop to call it off.")
   end
   return started
end

-- No Favourites equivalent of Dungeon.OnQuestAccepted (which shares the quest
-- with the group on QUEST_ACCEPTED): hunting a favourite has no group-sharing
-- use case, so there is nothing for the event to do.
--
-- What the missing hook DID do, until it was found in review, was end the run.
-- Dungeon's hook nils Board.run as a side effect; favourites had no hook, so an
-- accepted run stayed live and this poll kept driving it at 0.5s: Select clicked
-- again every tick, and once the taken card left the board, "no favourite here"
-- became a paid reroll - gold spent AFTER the hunt had already won, with no
-- despawn to brake it at a permanent board. The run now ends at the accept
-- (Fav.Hunt's onAccept), with Board.Poll's grace window behind it.
function Fav.Poll(now)
   if CBH.Board.run and CBH.Board.run.label == "favourites" then
      CBH.Board.Poll(now)
   end
end

-- A filled vs hollow bracket, never colour alone: keepsy is colourblind, and
-- the whole UI system holds to shape-plus-word.
--
-- One function for both grounds, because the glyphs are the thing that must not
-- drift: while the card star and the config panel each owned a private copy of
-- "[*]"/"[ ]" under near-miss names (StarText / FavGlyph), changing the shape
-- would have landed in one of them only. `onParchment` picks the tier the way
-- UI.Stamp does - ink on the server's light card art, dark-surface colours on
-- CBH's own panels (getting that backwards shipped unreadable in 1.10.0).
--
-- The on-state is verdigris, not brass: UI.lua reserves brass for the single
-- actionable thing in a view, and a card already spends it on UI.Stamp("ready").
function Fav.StarText(target, onParchment)
   local on = Fav.IsFavourite(target)
   local key
   if onParchment then key = on and "verdigrisInk" or "inkSoft"
   else key = on and "verdigris" or "muted" end
   return CBH.UI.Colour(key, on and "[*]" or "[ ]")
end

local function Usage()
   CBH.print("/cbh fav list | clear | rerolls <n|unlimited> | reserve <gold>"
      .. "  |  /cbh hunt [stop]")
end

function Fav.Command(arg)
   arg = string.lower(arg or "")
   local _, _, verb, rest = string.find(arg, "^(%S*)%s*(.-)$")
   if verb == "hunt" then
      Fav.Hunt(rest)
   elseif verb == "" or verb == "list" then
      local n = Fav.Count()
      CBH.print(n .. " favourite" .. (n == 1 and "" or "s") .. ".")
      if n > 0 then
         for target in pairs(CBH.db.favourites) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. CBH.UI.Stamp("ready") .. " " .. target)
         end
      end
      local cap = Fav.RerollMax()
      CBH.print("Hunt limits: " .. (cap == 0 and "unlimited rerolls" or (cap .. " rerolls"))
         .. ", reserve " .. CBH.Board.Gold(Fav.GoldReserve()) .. ".")
      Usage()
   elseif verb == "clear" then
      CBH.db.favourites = {}
      CBH.print("Favourites cleared.")
   elseif verb == "rerolls" then
      local o = CBH.db and CBH.db.options
      if not o then return end
      if rest == "unlimited" or rest == "0" then
         o.favRerollMax = 0
         CBH.print("Hunt reroll limit: unlimited. Nothing but the reserve stops it -"
            .. " a permanent callboard never despawns.")
      else
         local num = tonumber(rest)
         if not num or num < 0 then
            CBH.print("Usage: /cbh fav rerolls <number|unlimited>")
         else
            o.favRerollMax = math.floor(num)
            CBH.print("Hunt reroll limit: " .. o.favRerollMax .. " per hunt (~"
               .. CBH.Board.Gold(o.favRerollMax * CBH.Board.lastCost) .. ").")
         end
      end
   elseif verb == "reserve" then
      local o = CBH.db and CBH.db.options
      if not o then return end
      local g = tonumber(rest)
      if not g or g < 0 then
         CBH.print("Usage: /cbh fav reserve <gold>  (never reroll below this)")
      else
         o.favGoldReserve = math.floor(g) * 10000
         CBH.print("Hunt gold reserve: " .. math.floor(g) .. "g - hunting stops before"
            .. " dropping below it.")
      end
   else
      CBH.print("Don't know '" .. verb .. "'.")
      Usage()
   end
end
