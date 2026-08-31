-- Executes the REAL Comm.lua under stubbed 3.3.5 APIs. Covers the payload
-- round-trip, the anti-flood floor, transport availability gating, and the
-- self-echo vs peer distinction that decides how a test result is read.
local ADDON = ADDON_DIR

local function stubFrame()
   local f = {}
   setmetatable(f, { __index = function() return function() return nil end end })
   return f
end
function CreateFrame() return stubFrame() end
function GetTime() return NOW or 0 end
function GetAddOnMetadata() return "1.7.0" end
function UnitName() return "Keepsy" end
function GetChannelName() return CHANNEL_IDX or 0 end
function JoinTemporaryChannel() JOINED = "temporary" end
function JoinChannelByName(n, pw, frame) JOINED = "byname"; JOIN_FRAME = frame end
ADDED, FILTERED = nil, nil
function ChatFrame_AddChannel(f, n) ADDED = n end
function ChatFrame_AddMessageEventFilter(ev, fn) FILTERED = ev; FILTER_FN = fn end
DEFAULT_CHAT_FRAME = { GetID = function() return 1 end }
function LeaveChannelByName() end
function IsInGuild() return IN_GUILD end
function GetNumPartyMembers() return PARTY or 0 end
function GetNumRaidMembers() return RAID or 0 end
SENT = {}
function SendAddonMessage(prefix, msg, dist) SENT[#SENT + 1] = "addon:" .. dist end
function SendChatMessage(msg, kind) SENT[#SENT + 1] = "chat:" .. kind end
NUM_CHAT_WINDOWS = 1
function ChatFrame_RemoveChannel() end
_G.ChatFrame1 = stubFrame()

CallboardHunter = {}
local CBH = CallboardHunter
PRINTED = {}
function CBH.print(m) PRINTED[#PRINTED + 1] = tostring(m); if VERBOSE then print("   [cbh] " .. tostring(m)) end end
function CBH.Log() end

local chunk, err = loadfile(ADDON .. "/Comm.lua")
if not chunk then error("load Comm.lua: " .. tostring(err)) end
chunk()
local Comm = CBH.Comm

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label,
      tostring(got), ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end
local function sentJoined() return table.concat(SENT, " ") end

print("== payload round-trip ==")
local p = Comm.Encode("1.7.0", 7, "Keepsy")
check("encodes", p, "1.7.0|7|Keepsy")
local v, seq, who = Comm.Decode(p)
check("decodes version", v, "1.7.0")
check("decodes seq", seq, 7)
check("decodes sender", who, "Keepsy")
local _, _, w2 = Comm.Decode(Comm.Encode("1.7.0", 1, "Opol|usia"))
check("sender with a pipe survives", w2, "Opol|usia")
check("rejects junk", Comm.Decode("not-a-payload"), nil)
check("rejects nil", Comm.Decode(nil), nil)

print("\n== anti-flood floor ==")
check("first send allowed", Comm.CanSend(100, 0), true)
check("same instant refused", Comm.CanSend(100, 100), false)
check("1.9s later refused", Comm.CanSend(101.9, 100), false)
check("2.0s later allowed", Comm.CanSend(102.0, 100), true)

print("\n== transport gating: only send what is actually possible ==")
IN_GUILD, PARTY, RAID, CHANNEL_IDX = false, 0, 0, 0
NOW, Comm.lastSend, SENT = 500, 0, {}
Comm.Send("guild")
check("no guild -> nothing sent", #SENT, 0)
Comm.Send("party")
check("no party -> nothing sent", #SENT, 0)
NOW = 600
Comm.Send("all")
check("nothing usable -> nothing sent", #SENT, 0)
check("  ...and no send is recorded", Comm.stats.sent, 0)

print("\n== guild transport ==")
IN_GUILD = true
NOW, Comm.lastSend, SENT = 700, 0, {}
Comm.Send("guild")
check("guild send uses GUILD distribution", sentJoined(), "addon:GUILD")
check("  counted", Comm.stats.sent, 1)
NOW = 701 -- inside the floor
Comm.Send("guild")
check("throttled inside 2s", #SENT, 1)
NOW = 703
Comm.Send("guild")
check("allowed after the floor", #SENT, 2)

print("\n== 'all' fans out over every usable transport, once ==")
PARTY, RAID, CHANNEL_IDX = 2, 0, 5
NOW, Comm.lastSend, SENT = 800, 0, {}
Comm.Send("all")
check("guild+party+channel+chat sent", sentJoined(),
   "addon:GUILD addon:PARTY addon:CHANNEL chat:CHANNEL")
check("  counts as ONE send event", Comm.stats.sent, 3)
NOW = 801
Comm.Send("all")
check("  ...so 'all' cannot bypass the floor", #SENT, 4)

print("\n== self-echo vs peer (a solo test must not read as success) ==")
Comm.stats.peer, Comm.stats.mine = {}, {}
Comm.OnEvent("CHAT_MSG_ADDON", "CBHPROBE", "1.7.0|1|Keepsy", "GUILD", "Keepsy")
check("self-echo recorded as self", Comm.stats.mine.GUILD, 1)
check("  ...and NOT as a peer", Comm.stats.peer.GUILD, nil)
Comm.OnEvent("CHAT_MSG_ADDON", "CBHPROBE", "1.7.0|4|Opolusia", "GUILD", "Opolusia")
check("peer recorded as peer", Comm.stats.peer.GUILD, 1)
check("  ...self count unchanged", Comm.stats.mine.GUILD, 1)
Comm.OnEvent("CHAT_MSG_ADDON", "CBHPROBE", "1.7.0|5|Opolusia", "PARTY", "Opolusia")
check("distributions counted separately", Comm.stats.peer.PARTY, 1)
Comm.OnEvent("CHAT_MSG_CHANNEL", "CBHPROBE 1.7.0|9|Opolusia", "Opolusia")
check("chat transport tagged distinctly", Comm.stats.peer["CHANNEL-chat"], 1)

print("\n== foreign traffic is ignored ==")
Comm.OnEvent("CHAT_MSG_ADDON", "SOMEOTHERADDON", "junk", "GUILD", "Someone")
Comm.OnEvent("CHAT_MSG_CHANNEL", "hi guys anyone lfm", "Randomer")
check("other addon prefixes ignored", Comm.stats.peer.GUILD, 1)
check("normal channel chat ignored", Comm.stats.peer["CHANNEL-chat"], 1)

print("\n== status reports a verdict without erroring ==")
PRINTED = {}
Comm.Status()
local joined = table.concat(PRINTED, "\n")
check("prints a VERDICT line", string.find(joined, "VERDICT") ~= nil, true)
check("names the working transport", string.find(joined, "GUILD addon messages reach") ~= nil, true)

print("")
print("== channel join must REGISTER, not unhook (the false-negative bug) ==")
CHANNEL_IDX = 0
Comm.Join()
check("joins bound to a chat frame", JOINED, "byname")
check("  ...with a frame id", JOIN_FRAME, 1)
CHANNEL_IDX = 7          -- now "in" the channel
Comm.Join()              -- re-run so the post-join registration path executes
check("registers the channel (events need this)", ADDED, "cbh")
check("installs a display filter instead", FILTERED, "CHAT_MSG_CHANNEL")
-- the filter must hide OUR traffic and leave everyone else's alone
check("filters our own protocol text", FILTER_FN(nil, nil, "CBHPROBE 1.7.0|1|Keepsy"), true)
check("leaves normal chat visible", FILTER_FN(nil, nil, "anyone up for ICC?"), false)

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end
