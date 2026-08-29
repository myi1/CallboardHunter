-- CallboardHunter Comm: message transport PROBE.
--
-- Answers one question with evidence: which client-to-client transports does
-- Ebonhold actually relay? Everything about live rare alerts and crowd-sourced
-- spawn data depends on that, so it gets measured before it gets built.
--
-- Established so far (see the spec doc):
--   * CHANNEL is NOT a valid SendAddonMessage distribution on 3.3.5 - the client
--     refuses the call outright (ok=false). Custom-channel sync is dead.
--   * Addon messages themselves work fine here: BigWigs syncs raid timers with
--     SendAddonMessage(..., "RAID"), and the server pushes its own addon
--     messages to clients on the ProjectEbonhold bus.
-- So the transports worth measuring are the SUPPORTED distributions: GUILD,
-- PARTY, RAID. Those are guild/group scoped rather than server-wide, which also
-- makes contributed data far easier to trust - the senders are people you know.
--
-- Deliberate constraints (unchanged):
--   * nothing auto-joins / auto-sends - opt-in slash command only
--   * hard 2s floor between send events, so the probe cannot flood you offline
--   * no access to learned/learnedKills - a failed test cannot corrupt data
local CBH = CallboardHunter
local Comm = CBH.Comm or {}
CBH.Comm = Comm

local CHANNEL = "cbh"
local PREFIX = "CBHPROBE"
local MIN_SEND_GAP = 2.0 -- seconds; anti-flood floor, per send event

-- peer[dist] = messages from someone else (definitive: it reaches other people)
-- mine[dist] = our own broadcast echoed back (proves the server relayed it, but
--              not that anyone else received it)
Comm.stats = { sent = 0, peer = {}, mine = {} }
Comm.lastSend = 0
local seq = 0

local function Version()
   local v = GetAddOnMetadata and GetAddOnMetadata("CallboardHunter", "Version")
   return v or "?"
end

-- ------------------------------------------------------------- pure helpers
-- Free of WoW API calls so they can be unit-tested outside the client.

function Comm.Encode(version, n, who)
   return tostring(version) .. "|" .. tostring(n) .. "|" .. tostring(who)
end

function Comm.Decode(s)
   if type(s) ~= "string" then return nil end
   local _, _, v, n, who = string.find(s, "^(.-)|(.-)|(.*)$")
   if not v then return nil end
   return v, tonumber(n), who
end

-- Anti-flood floor. Pure: caller supplies "now" so tests don't need GetTime.
function Comm.CanSend(now, last)
   last = last or Comm.lastSend or 0
   return (now - last) >= MIN_SEND_GAP
end

-- ------------------------------------------------------------------ channel

local function ChannelIndex()
   if not GetChannelName then return nil end
   local idx = GetChannelName(CHANNEL)
   if idx and idx > 0 then return idx end
   return nil
end
Comm.ChannelIndex = ChannelIndex

function Comm.Join()
   if ChannelIndex() then
      CBH.print("Probe: already in the channel (index " .. ChannelIndex() .. ").")
      return
   end
   JoinTemporaryChannel(CHANNEL)
   if ChatFrame_RemoveChannel then
      for i = 1, NUM_CHAT_WINDOWS or 7 do
         local f = _G["ChatFrame" .. i]
         if f then pcall(ChatFrame_RemoveChannel, f, CHANNEL) end
      end
   end
   local idx = ChannelIndex()
   CBH.Log("comm", "JOIN channel -> index " .. tostring(idx))
   CBH.print("Probe: joined the channel"
      .. (idx and (" (index " .. idx .. ")") or " - /cbh probe status to confirm")
      .. ". Note: channel transports already tested negative here.")
end

function Comm.Leave()
   if not ChannelIndex() then
      CBH.print("Probe: not in the channel.")
      return
   end
   if LeaveChannelByName then LeaveChannelByName(CHANNEL) end
   CBH.Log("comm", "LEAVE channel")
   CBH.print("Probe: left the channel.")
end

-- --------------------------------------------------------------- transports

-- available() returns true, or false plus the reason to show the player.
local TRANSPORTS = {
   guild = { dist = "GUILD", chat = false, order = 1,
      available = function()
         if IsInGuild and not IsInGuild() then return false, "you are not in a guild" end
         return true
      end },
   party = { dist = "PARTY", chat = false, order = 2,
      available = function()
         if GetNumPartyMembers and GetNumPartyMembers() == 0 then
            return false, "you are not in a party"
         end
         return true
      end },
   raid = { dist = "RAID", chat = false, order = 3,
      available = function()
         if GetNumRaidMembers and GetNumRaidMembers() == 0 then
            return false, "you are not in a raid"
         end
         return true
      end },
   -- Kept so the negative result stays reproducible, not because it works.
   channel = { dist = "CHANNEL", chat = false, order = 4,
      available = function()
         if not ChannelIndex() then return false, "not in the probe channel" end
         return true
      end },
   chat = { dist = "CHANNEL", chat = true, order = 5,
      available = function()
         if not ChannelIndex() then return false, "not in the probe channel" end
         return true
      end },
}
Comm.TRANSPORTS = TRANSPORTS

local function SendOne(name, t, payload)
   local ok, err
   if t.chat then
      ok, err = pcall(SendChatMessage, PREFIX .. " " .. payload, "CHANNEL", nil, ChannelIndex())
   elseif t.dist == "CHANNEL" then
      ok, err = pcall(SendAddonMessage, PREFIX, payload, "CHANNEL", ChannelIndex())
   else
      ok, err = pcall(SendAddonMessage, PREFIX, payload, t.dist)
   end
   CBH.Log("comm", "SEND " .. name .. " (" .. t.dist .. (t.chat and "/chat" or "/addon")
      .. ") seq=" .. seq .. " ok=" .. tostring(ok)
      .. (ok and "" or (" err=" .. tostring(err))))
   return ok
end

-- which: a transport name, or "all" for every currently available one. The 2s
-- floor applies to the whole batch, so "all" cannot be used to bypass it.
function Comm.Send(which)
   which = (which and which ~= "" and string.lower(which)) or "all"
   local now = GetTime()
   if not Comm.CanSend(now) then
      CBH.print(string.format("Probe: throttled - wait %.1fs (anti-flood floor is %ds).",
         MIN_SEND_GAP - (now - Comm.lastSend), MIN_SEND_GAP))
      return
   end

   local picked = {}
   if which == "all" then
      for name, t in pairs(TRANSPORTS) do
         if t.available() then picked[#picked + 1] = { name = name, t = t } end
      end
      table.sort(picked, function(a, b) return a.t.order < b.t.order end)
      if #picked == 0 then
         CBH.print("Probe: no transport usable right now - be in a guild, party or"
            .. " raid (or /cbh probe join for the channel test).")
         return
      end
   else
      local t = TRANSPORTS[which]
      if not t then
         CBH.print("Probe: unknown transport - use guild | party | raid | channel | chat | all.")
         return
      end
      local ok, why = t.available()
      if not ok then
         CBH.print("Probe: cannot send via " .. which .. " - " .. tostring(why) .. ".")
         return
      end
      picked[1] = { name = which, t = t }
   end

   Comm.lastSend = now
   seq = seq + 1
   Comm.stats.sent = Comm.stats.sent + 1
   local payload = Comm.Encode(Version(), seq, (UnitName and UnitName("player")) or "?")
   local names = {}
   for _, p in ipairs(picked) do
      SendOne(p.name, p.t, payload)
      names[#names + 1] = p.name
   end
   CBH.print("Probe: sent #" .. seq .. " via " .. table.concat(names, ", ")
      .. ". Watch for a [PEER] line here or on another client.")
end

local function Bump(tbl, key)
   tbl[key] = (tbl[key] or 0) + 1
end

function Comm.Status()
   local s = Comm.stats
   CBH.print("Probe status:  sent: " .. s.sent)
   local idx = ChannelIndex()
   CBH.print("  probe channel: " .. (idx and ("joined, index " .. idx) or "not joined"))
   -- What can we even test from where we are standing right now?
   local avail = {}
   for name, t in pairs(TRANSPORTS) do
      if t.available() then avail[#avail + 1] = name end
   end
   table.sort(avail)
   CBH.print("  usable now: " .. (#avail > 0 and table.concat(avail, ", ") or "(none)"))

   local any = false
   for _, dist in ipairs({ "GUILD", "PARTY", "RAID", "CHANNEL", "CHANNEL-chat" }) do
      local p, m = s.peer[dist] or 0, s.mine[dist] or 0
      if p > 0 or m > 0 then
         any = true
         CBH.print("  " .. dist .. ": PEER " .. p .. ", self-echo " .. m
            .. (p > 0 and "  <- WORKS, reaches other players"
                      or "  <- relayed back to you, no peer seen yet"))
      end
   end
   if not any then CBH.print("  nothing received yet.") end

   local best
   for _, dist in ipairs({ "GUILD", "RAID", "PARTY" }) do
      if (s.peer[dist] or 0) > 0 then best = dist break end
   end
   if best then
      CBH.print("  VERDICT: " .. best .. " addon messages reach other players."
         .. " Live alerts are viable at that scope.")
   elseif (s.mine.GUILD or 0) + (s.mine.PARTY or 0) + (s.mine.RAID or 0) > 0 then
      CBH.print("  VERDICT: the server relays your addon messages back to you, so"
         .. " the transport works - confirm with a second player to be certain.")
   else
      CBH.print("  VERDICT: no addon message received yet. Send while a guildmate or"
         .. " party member is online and also running CallboardHunter.")
   end
end

-- ------------------------------------------------------------------- events

-- Exposed (not an inline closure) so the receive logic can be tested directly.
function Comm.OnEvent(event, a1, a2, a3, a4)
   local payload, sender, dist
   if event == "CHAT_MSG_ADDON" then
      -- 3.3.5: prefix, message, distribution, sender
      if a1 ~= PREFIX then return end
      payload, sender, dist = a2, a4, (a3 or "?")
   else
      -- CHAT_MSG_CHANNEL: message, sender, ... only our own probe text matters
      if type(a1) ~= "string" or string.sub(a1, 1, string.len(PREFIX)) ~= PREFIX then
         return
      end
      payload, sender, dist = string.sub(a1, string.len(PREFIX) + 2), a2, "CHANNEL-chat"
   end
   local v, n, who = Comm.Decode(payload)
   -- Distinguish a genuine peer from the server echoing our own broadcast back.
   -- Both prove the transport carries traffic, but only the first proves it
   -- REACHES someone else - and conflating them gives a false "it works".
   local me = UnitName and UnitName("player")
   local isSelf = (me ~= nil and tostring(sender) == me)
   Bump(isSelf and Comm.stats.mine or Comm.stats.peer, dist)
   CBH.Log("comm", "RECV " .. dist .. " from " .. tostring(sender)
      .. (isSelf and " [SELF-ECHO]" or " [PEER]")
      .. " v=" .. tostring(v) .. " seq=" .. tostring(n) .. " who=" .. tostring(who))
   CBH.print("|cff30ff00Probe RECV|r " .. dist .. " from " .. tostring(sender)
      .. (isSelf and " |cffffff00[your own message, echoed back]|r"
                 or " |cff30ff00[PEER]|r")
      .. " - v" .. tostring(v) .. " seq " .. tostring(n))
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
   Comm.OnEvent(event, a1, a2, a3, a4)
end)

function Comm.Command(arg)
   arg = string.lower(arg or "")
   local _, _, verb, rest = string.find(arg, "^(%S*)%s*(.-)$")
   if verb == "join" then Comm.Join()
   elseif verb == "leave" then Comm.Leave()
   elseif verb == "send" then Comm.Send(rest)
   elseif verb == "status" or verb == "" then Comm.Status()
   else
      CBH.print("/cbh probe send [guild|party|raid|channel|chat|all] | status | join | leave")
   end
end
