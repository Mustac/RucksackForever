-- Rucksack: tells you when a newer Rucksack is out (16 Nov); since 18 Nov only for releases he picks (ANNOUNCE)
-- The game can't look on the internet, so the copies tell each other: each says its version, quietly,
-- to your guild when you log in and to your group when you join one (hidden addon messages, nobody sees
-- them). A copy that hears an older version answers that player alone with its own. The newest version
-- heard is remembered, so the next time you log in, chat says "a new Rucksack is out" until you have it.
-- Once per session, never in a fight. Settings: "Tell me when a new version is out" (on).
local ns = Rucksack
if not ns then return end

local PREFIX = "Rucksack"
local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local MINE = meta and select(2, pcall(meta, "Rucksack", "Version")) or nil
if type(MINE) ~= "string" then MINE = nil end
-- (18 Nov) the version we tell other players about: only the releases he picks (he: "lets remove for
-- now to say to people to notify them on new update, I will tell you specifically which update I want
-- to notify"). Copies say this instead of their own version, so nobody hears of a release he didn't
-- pick. To announce a release: set it to that version. 1.8.7 = the first one with this file: no notice.
local ANNOUNCE = "1.8.7"
local V = {}
ns.Version = V
V.mine = MINE

-- "1.8.10" > "1.8.9": compare number by number
local function parts(v)
  local t = {}
  for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end
  return t
end
function V.Newer(a, b) -- is a newer than b?
  if not a or not b then return false end
  local x, y = parts(a), parts(b)
  if #x == 0 then return false end
  for i = 1, math.max(#x, #y) do
    local p, q = x[i] or 0, y[i] or 0
    if p ~= q then return p > q end
  end
  return false
end
local function on() return ns.db and ns.db.updateNotice ~= false end

local told = false
local function tell()
  if told or not on() or not MINE then return end
  local newest = ns.db.newestSeen
  if not V.Newer(newest, MINE) then return end
  if InCombatLockdown() then return end -- (after the fight: PLAYER_REGEN_ENABLED)
  told = true
  ns.Print("|cff66dd66a new version is out: " .. newest .. "|r (you have " .. MINE .. "). Please update it in the CurseForge app.")
end
V.Tell = tell

local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local function say(channel, target)
  if not MINE or not send then return end
  local v = (ANNOUNCE and V.Newer(MINE, ANNOUNCE)) and ANNOUNCE or MINE -- (never more than we have)
  pcall(send, PREFIX, "V:" .. v, channel, target)
end

-- (an older copy says its version: tell that player ours, once per player and session)
local answered = {}
local lastGroup = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
pcall(ev.RegisterEvent, ev, "GROUP_ROSTER_UPDATE")
pcall(ev.RegisterEvent, ev, "CHAT_MSG_ADDON")
pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, e, a1, a2, a3, a4)
  if e == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    elseif RegisterAddonMessagePrefix then pcall(RegisterAddonMessagePrefix, PREFIX) end
    -- (what an earlier session heard: say it a little after the login messages)
    C_Timer.After(8, tell)
    -- (and tell the guild ours, a little later still)
    C_Timer.After(15, function() if IsInGuild and IsInGuild() then say("GUILD") end end)
  elseif e == "GROUP_ROSTER_UPDATE" or e == "PLAYER_ENTERING_WORLD" then
    local now = GetTime and GetTime() or 0
    if now - lastGroup < 60 then return end
    if IsInRaid and IsInRaid() then
      lastGroup = now
      C_Timer.After(3, function() say((IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "RAID") end)
    elseif IsInGroup and IsInGroup() then
      lastGroup = now
      C_Timer.After(3, function() say((LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY") end)
    end
  elseif e == "CHAT_MSG_ADDON" then
    if a1 ~= PREFIX or type(a2) ~= "string" then return end
    local theirs = a2:match("^V:(%S+)$")
    if not theirs or not MINE then return end
    local sender = a4
    if V.Newer(theirs, MINE) then
      if not ns.db then return end
      if V.Newer(theirs, ns.db.newestSeen or MINE) or not ns.db.newestSeen then ns.db.newestSeen = theirs end
      tell()
    elseif V.Newer((ANNOUNCE and V.Newer(MINE, ANNOUNCE)) and ANNOUNCE or MINE, theirs) and type(sender) == "string" and not answered[sender] then
      answered[sender] = true
      C_Timer.After(2 + math.random() * 3, function() say("WHISPER", sender) end)
    end
  elseif e == "PLAYER_REGEN_ENABLED" then
    if not told and ns.db and V.Newer(ns.db.newestSeen, MINE) then C_Timer.After(2, tell) end
  end
end)

-- once you have it (or something newer), there's nothing to tell any more
table.insert(ns.onLogin, function()
  if ns.db and ns.db.newestSeen and MINE and not V.Newer(ns.db.newestSeen, MINE) then ns.db.newestSeen = nil end
end)
