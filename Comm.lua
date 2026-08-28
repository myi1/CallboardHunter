-- CallboardHunter Comm: channel transport PROBE.
--
-- Answers one question with evidence: does Ebonhold's core relay
-- client-to-client messages on a custom channel, and if so which transport
-- survives - addon messages (silent) or plain chat messages (visible to anyone
-- who joins the channel)? Everything about live rare alerts / crowd-sourced
-- spawn data depends on that answer, so it gets measured before it gets built.
--
-- Deliberate constraints (see docs/superpowers/specs/2026-08-29-comm-channel-probe-design.md):
--   * nothing auto-joins - opt-in slash command only, no passive behaviour
--   * hard 2s floor between sends, so the probe cannot flood you off the server
--   * no access to learned/learnedKills - a failed test cannot corrupt data
local CBH = CallboardHunter
local Comm = CBH.Comm or {}
CBH.Comm = Comm

local CHANNEL = "cbh"
local PREFIX = "CBHPROBE"
local MIN_SEND_GAP = 2.0 -- seconds; anti-flood floor

Comm.stats = { addon = 0, chat = 0, sent = 0 }
Comm.lastSend = 0
local seq = 0

local function Version()
   local v = GetAddOnMetadata and GetAddOnMetadata("CallboardHunter", "Version")
   return v or "?"
end

-- ------------------------------------------------------------ pure helpers
-- Kept free of WoW API calls so they can be unit-tested outside the client.

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

-- GetChannelName(name) returns the channel index, or 0/nil when not joined.
local function ChannelIndex()
   if not GetChannelName then return nil end
   local idx = GetChannelName(CHANNEL)
   if idx and idx > 0 then return idx end
   return nil
end
Comm.ChannelIndex = ChannelIndex

function Comm.Join()
   if ChannelIndex() then
      CBH.print("Probe: already in '" .. CHANNEL .. "' (index " .. ChannelIndex() .. ").")
      return
   end
   -- Temporary: does not persist across sessions and is not written to the
   -- player's saved channel list.
   JoinTemporaryChannel(CHANNEL)
   -- Keep it out of the chat windows so the probe stays silent.
   if ChatFrame_RemoveChannel then
      for i = 1, NUM_CHAT_WINDOWS or 7 do
         local f = _G["ChatFrame" .. i]
         if f then pcall(ChatFrame_RemoveChannel, f, CHANNEL) end
      end
   end
   local idx = ChannelIndex()
   CBH.Log("comm", "JOIN '" .. CHANNEL .. "' -> index " .. tostring(idx))
   if idx then
      CBH.print("Probe: joined '" .. CHANNEL .. "' (index " .. idx .. "). "
         .. "Have the other tester do the same, then /cbh probe send.")
   else
      -- The join is asynchronous on some cores; status will show it shortly.
      CBH.print("Probe: join requested for '" .. CHANNEL
         .. "'. Run /cbh probe status in a moment to confirm the index.")
   end
end

function Comm.Leave()
   if not ChannelIndex() then
      CBH.print("Probe: not in '" .. CHANNEL .. "'.")
      return
   end
   if LeaveChannelByName then LeaveChannelByName(CHANNEL) end
   CBH.Log("comm", "LEAVE '" .. CHANNEL .. "'")
   CBH.print("Probe: left '" .. CHANNEL .. "'.")
end

-- alsoChat: additionally fire transport 2 (visible chat message).
function Comm.Send(alsoChat)
   local idx = ChannelIndex()
   if not idx then
      CBH.print("Probe: not in '" .. CHANNEL .. "' yet - /cbh probe join first.")
      return
   end
   local now = GetTime()
   if not Comm.CanSend(now) then
      CBH.print(string.format(
         "Probe: throttled - wait %.1fs (anti-flood floor is %ds).",
         MIN_SEND_GAP - (now - Comm.lastSend), MIN_SEND_GAP))
      return
   end
   Comm.lastSend = now
   seq = seq + 1
   local payload = Comm.Encode(Version(), seq, UnitName("player") or "?")
   Comm.stats.sent = Comm.stats.sent + 1

   -- Transport 1: addon message (silent). The 4th arg is the channel INDEX.
   local ok1 = pcall(SendAddonMessage, PREFIX, payload, "CHANNEL", idx)
   CBH.Log("comm", "SEND addon seq=" .. seq .. " idx=" .. idx
      .. " ok=" .. tostring(ok1))
   -- Transport 2: plain chat (visible to anyone who joined the channel).
   local ok2
   if alsoChat then
      ok2 = pcall(SendChatMessage, PREFIX .. " " .. payload, "CHANNEL", nil, idx)
      CBH.Log("comm", "SEND chat seq=" .. seq .. " ok=" .. tostring(ok2))
   end
   CBH.print("Probe: sent #" .. seq .. " (addon"
      .. (alsoChat and " + chat" or "") .. "). Ask the other tester what arrived.")
end

function Comm.Status()
   local idx = ChannelIndex()
   CBH.print("Probe status:")
   CBH.print("  channel '" .. CHANNEL .. "': "
      .. (idx and ("JOINED, index " .. idx) or "NOT JOINED"))
   CBH.print("  sent: " .. Comm.stats.sent
      .. " | received addon: " .. Comm.stats.addon
      .. " | received chat: " .. Comm.stats.chat)
   if Comm.stats.addon > 0 then
      CBH.print("  -> addon messages DO relay on this server.")
   elseif Comm.stats.chat > 0 then
      CBH.print("  -> only chat messages relay; addon messages are stripped.")
   else
      CBH.print("  -> nothing received yet (need a second tester in the channel).")
   end
end

-- ------------------------------------------------------------------- events

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, ...)
   if event == "CHAT_MSG_ADDON" then
      -- 3.3.5: prefix, message, distribution, sender
      if a1 ~= PREFIX then return end
      Comm.stats.addon = Comm.stats.addon + 1
      local v, n, who = Comm.Decode(a2)
      CBH.Log("comm", "RECV addon from " .. tostring(a4) .. " dist=" .. tostring(a3)
         .. " v=" .. tostring(v) .. " seq=" .. tostring(n) .. " who=" .. tostring(who))
      CBH.print("|cff30ff00Probe RECV (addon)|r from " .. tostring(a4)
         .. " - v" .. tostring(v) .. " seq " .. tostring(n))
   else
      -- CHAT_MSG_CHANNEL: message, sender, ... only care about our own probe text
      if type(a1) ~= "string" or string.sub(a1, 1, string.len(PREFIX)) ~= PREFIX then
         return
      end
      Comm.stats.chat = Comm.stats.chat + 1
      local v, n, who = Comm.Decode(string.sub(a1, string.len(PREFIX) + 2))
      CBH.Log("comm", "RECV chat from " .. tostring(a2)
         .. " v=" .. tostring(v) .. " seq=" .. tostring(n) .. " who=" .. tostring(who))
      CBH.print("|cff30ff00Probe RECV (chat)|r from " .. tostring(a2)
         .. " - v" .. tostring(v) .. " seq " .. tostring(n))
   end
end)

function Comm.Command(arg)
   arg = string.lower(arg or "")
   if arg == "join" then Comm.Join()
   elseif arg == "leave" then Comm.Leave()
   elseif arg == "status" or arg == "" then Comm.Status()
   elseif arg == "send" then Comm.Send(false)
   elseif arg == "send chat" or arg == "sendchat" then Comm.Send(true)
   else
      CBH.print("/cbh probe join | send | send chat | status | leave")
   end
end
