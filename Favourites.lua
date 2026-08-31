-- CallboardHunter Favourites: mark callboard quests you want, and hunt for them.
--
-- Keys on the TARGET, not the title. A callboard title reads
-- "<flavour prefix>: <target>", and the prefix is decorative - "Dungeon Crawl:
-- Loken" and "Wanted: Loken" are the same contract. Favouriting the title would
-- miss the same job under a different prefix.
local CBH = CallboardHunter
local Fav = CBH.Favourites or {}
CBH.Favourites = Fav

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
function Fav.MatchCards(cards)
   if Fav.Count() == 0 then return nil end
   for i, c in ipairs(cards or {}) do
      -- A card's text is every FontString joined; check each line, because the
      -- title and the objective are separate lines on the same card.
      for line in string.gmatch(c.text or "", "[^|]+") do
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
      add(CBH.SpawnDB.TargetOf(text), meta and meta.lo, meta and meta.hi)
   end
   for _, e in ipairs(rows) do e.favourite = Fav.IsFavourite(e.target) end
   table.sort(rows, function(a, b) return a.target < b.target end)
   return rows
end
