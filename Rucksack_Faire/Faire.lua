-- Rucksack / Darkmoon Faire: the brains: counting what you have, which turn-ins are open to you, tickets,
-- the Faire's dates, item tooltips, quick turn-ins at the NPCs, and learning from the game.
local ADDON = ...
local RS = Rucksack
if not RS then return end
RS.Module("faire", ADDON, function() local F = RS.Faire if F and F.ev and F.ev.ADDON_LOADED then F.ev.ADDON_LOADED(ADDON) end end)
RS.Faire = RS.Faire or {}
local ns = RS.Faire
local D = ns.D
ns.onLogin = {}
ns.BACKDROP_TMPL = RS.BACKDROP_TMPL

local issecret = issecretvalue or function() return false end
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffc8a165Rucksack|r |cffb48cffFaire:|r " .. msg) end
ns.Print = Print

-- the Faire tool's on/off (sidebar), like Rations and Clean-up
function ns.On() return ns.db and ns.db.enabled ~= false end
function ns.SetOn(v)
  ns.db.enabled = v and true or false
  if ns.UpdateScreenButton then ns.UpdateScreenButton() end
  RS.Changed()
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
function ns.ItemName(id)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not name and GetItemInfo then name = GetItemInfo(id) end
  return name or D.ITEM_NAMES[id] or ("item " .. id)
end
function ns.ItemIcon(id)
  local tex = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
  if not tex and GetItemIcon then tex = GetItemIcon(id) end
  return tex or 134400
end
-- bags, and bags + bank (the game remembers the bank once you've opened it)
function ns.Count(id)
  local count = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not count then return 0, 0 end
  local bags = count(id) or 0
  local all = count(id, true) or bags
  return bags, all
end

---------------------------------------------------------------------------
-- Tickets and reputation
---------------------------------------------------------------------------
function ns.Tickets()
  local n = 0
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, D.TICKET_CURRENCY)
    if ok and type(info) == "table" and type(info.quantity) == "number" then n = n + info.quantity end
  end
  n = n + (select(2, ns.Count(D.TICKET_ITEM)) or 0)
  return n
end

local STANDING = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
-- standing id (4 = Neutral), points into it, points the standing needs, name
function ns.Rep()
  local standing, into, size
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, f = pcall(C_Reputation.GetFactionDataByID, D.FACTION)
    if ok and type(f) == "table" and f.reaction then
      standing = f.reaction
      into = (f.currentStanding or 0) - (f.currentReactionThreshold or 0)
      size = (f.nextReactionThreshold or 0) - (f.currentReactionThreshold or 0)
    end
  end
  if not standing and GetFactionInfoByID then
    local ok, _, _, st, lo, hi, val = pcall(GetFactionInfoByID, D.FACTION)
    if ok and st then standing, into, size = st, (val or 0) - (lo or 0), (hi or 0) - (lo or 0) end
  end
  if not standing then return 4, 0, 3000, "Neutral", false end -- (never met the Faire: everyone starts Neutral)
  return standing, into, size, STANDING[standing] or "?", true
end

-- has your reputation gone past this tier's limit?
local function pastCap(tier)
  local cap = D.TIER_CAP[tier]
  if not cap then return false end
  local standing, into = ns.Rep()
  return standing > cap[1] or (standing == cap[1] and into >= cap[2])
end

---------------------------------------------------------------------------
-- The turn-ins
---------------------------------------------------------------------------
-- what the game showed us beats the built-in data
local function learned(t)
  local L = ns.db and ns.db.learned and ns.db.learned[t.q]
  return (L and L.item) or t.item, (L and L.n) or t.n, (L and L.t) or t.t
end
ns.Learned = learned

-- state: "ready" (can hand in now, times = how many), "short" (need more), "level", "rep" (closed)
function ns.TurninState(t)
  local item, n, tickets = learned(t)
  local bags, all = ns.Count(item)
  local st = { item = item, n = n, tickets = tickets, bags = bags, all = all }
  if UnitLevel("player") < t.lv then
    st.state = "level"
  elseif pastCap(t.tier) then
    st.state = "rep"
  elseif bags >= n then
    st.state, st.times = "ready", math.floor(bags / n)
  else
    st.state, st.need = "short", n - bags
  end
  return st
end

-- every turn-in, flat
function ns.AllTurnins()
  local out = {}
  for _, g in ipairs(D.TURNINS) do for _, t in ipairs(g.list) do out[#out + 1] = t end end
  return out
end
local BY_QUEST, BY_ITEM = {}, {}
for _, g in ipairs(D.TURNINS) do
  for _, t in ipairs(g.list) do
    t.npc = g.npc
    BY_QUEST[t.q] = t
    if t.more then BY_QUEST[t.more] = t end
    BY_ITEM[t.item] = BY_ITEM[t.item] or {}
    table.insert(BY_ITEM[t.item], t)
  end
end
ns.BY_QUEST, ns.BY_ITEM = BY_QUEST, BY_ITEM
-- (10 Nov) Clean-up never deletes or sells Darkmoon turn-in items (many are grey "trash" like Small
-- Furry Paws), unless you untick "Keep Darkmoon turn-in items"
function RS.FaireKeep(id)
  return id and BY_ITEM[id] and not (ns.db and ns.db.keepItems == false) and true or false
end
table.insert(RS.keepers, RS.FaireKeep)

-- what you could hand in right now: turn-ins, tickets
function ns.ReadyNow()
  local count, tickets, used = 0, 0, {}
  for _, t in ipairs(ns.AllTurnins()) do
    local st = ns.TurninState(t)
    if st.state == "ready" then
      -- (two quests can share an item: don't count the same items twice)
      local left = st.bags - (used[st.item] or 0)
      local times = math.floor(left / st.n)
      if times > 0 then
        used[st.item] = (used[st.item] or 0) + times * st.n
        count, tickets = count + times, tickets + times * st.tickets
      end
    end
  end
  return count, tickets
end

---------------------------------------------------------------------------
-- The Faire's dates (realm time)
---------------------------------------------------------------------------
local function days(y, m, d) -- days since 1970-01-01
  if m <= 2 then y, m = y - 1, m + 12 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local doy = math.floor((153 * (m - 3) + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end
local function realmMinutes()
  local t = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
  if t and t.year then return days(t.year, t.month, t.monthDay) * 1440 + (t.hour or 0) * 60 + (t.minute or 0) end
  local d = date("*t")
  return days(d.year, d.month, d.day) * 1440 + d.hour * 60 + d.min
end
-- open (true/false), where ("Elwynn"/"Mulgore"), minutes left or until it opens, the start date
function ns.FaireStatus()
  local now = realmMinutes()
  for _, s in ipairs(D.SCHEDULE) do
    local start = days(s[1], s[2], s[3]) * 1440 + 4 * 60
    local stop = start + 7 * 1440
    if now < start then return false, s[4], start - now, s end
    if now < stop then return true, s[4], stop - now, s end
  end
  return nil
end
function ns.Span(min)
  if min >= 1440 * 2 then return math.floor(min / 1440) .. " days" end
  if min >= 120 then return math.floor(min / 60) .. " hours" end
  return math.max(1, math.floor(min)) .. " min"
end
function ns.FaireLine()
  local open, where, left = ns.FaireStatus()
  if open == nil then return "|cff999999Faire dates after April 2027 aren't known yet: check the calendar|r" end
  local spot = D.FAIRE_SPOT[where]
  if open then return ("|cff66dd66Faire is open|r in %s, %s left"):format(spot.zone, ns.Span(left)) end
  return ("Next Faire: %s, in %s"):format(spot.zone, ns.Span(left))
end

---------------------------------------------------------------------------
-- Darkmoon cards in your bags (and the bank, when you open it)
---------------------------------------------------------------------------
local function scanCards(bags, into)
  local GetSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local GetLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
  if not (GetSlots and GetLink) then return end
  for _, bag in ipairs(bags) do
    for slot = 1, (GetSlots(bag) or 0) do
      local link = GetLink(bag, slot)
      local name = link and link:match("%[(.-)%]")
      if name then
        local card, deck = name:match("^(%a+) of (%a+)$")
        if card and D.DECK_TRINKET[deck] then into[deck .. ":" .. card] = true end
        local full = name:match("^(%a+) Deck$")
        if full and D.DECK_TRINKET[full] then into[full .. ":deck"] = true end
      end
    end
  end
end
function ns.ScanCards()
  if not ns.char then return end
  local bags = {}
  scanCards({ 0, 1, 2, 3, 4 }, bags)
  ns.char.cardsBags = bags
end
local function scanBankCards()
  if not ns.char then return end
  local bank = {}
  local list = { -1 }
  for b = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 6) do list[#list + 1] = b end
  pcall(scanCards, list, bank)
  ns.char.cardsBank = bank
end
function ns.HasCard(deck, card)
  local c = ns.char
  if not c then return false end
  local k = deck .. ":" .. card
  if (c.cardsBags and c.cardsBags[k]) then return "bags" end
  if (c.cardsBank and c.cardsBank[k]) then return "bank" end
  return false
end

---------------------------------------------------------------------------
-- Your profession window: which turn-in items you can make, and from what
---------------------------------------------------------------------------
local function scanTradeSkillModern()
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs and T.GetRecipeSchematic) then return end
  for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
    local ok, sch = pcall(T.GetRecipeSchematic, rid, false)
    local id = ok and type(sch) == "table" and sch.outputItemID
    local info = T.GetRecipeInfo and T.GetRecipeInfo(rid)
    if id and BY_ITEM[id] and (not info or info.learned ~= false) then
      local mats = {}
      for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
        local r = slot.reagents and slot.reagents[1]
        if r and r.itemID then mats[#mats + 1] = { name = ns.ItemName(r.itemID), n = slot.quantityRequired or 1 } end
      end
      ns.db.recipes[id] = { mats = mats, by = UnitName("player") }
      ns.char.canMake[id] = true
    end
  end
end
local function scanTradeSkill()
  if not (GetNumTradeSkills and GetTradeSkillItemLink) then return scanTradeSkillModern() end
  local n = GetNumTradeSkills() or 0
  for i = 1, n do
    local link = GetTradeSkillItemLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id and BY_ITEM[id] then
      local mats = {}
      for j = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0) do
        local name, _, need = GetTradeSkillReagentInfo(i, j)
        if name then mats[#mats + 1] = { name = name, n = need or 1 } end
      end
      ns.db.recipes[id] = { mats = mats, by = UnitName("player") }
      ns.char.canMake[id] = true
    end
  end
end

---------------------------------------------------------------------------
-- Other characters: how many of each turn-in item they have (for the tooltip)
---------------------------------------------------------------------------
local function charKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
local function saveAlts()
  if not ns.db then return end
  local mine = {}
  for id in pairs(BY_ITEM) do
    local _, all = ns.Count(id)
    if all > 0 then mine[id] = all end
  end
  ns.db.alts[charKey()] = mine
end

---------------------------------------------------------------------------
-- Tooltips: "Darkmoon: Rinling, 5 = 1 turn-in (4 tickets)"
---------------------------------------------------------------------------
local function addTooltip(tip, id)
  if not id or not ns.db or not ns.On() or ns.db.tooltips == false then return end
  local list = BY_ITEM[id]
  if not list then return end
  for _, t in ipairs(list) do
    local _, n, tickets = learned(t)
    tip:AddLine(("|cffb48cffDarkmoon:|r %s wants %d (%d ticket%s)"):format(t.npc, n, tickets, tickets == 1 and "" or "s"), 1, 1, 1)
  end
  local bags, all = ns.Count(id)
  local t = list[1]
  local _, n = learned(t)
  local line = ("You have %d"):format(bags) .. (all > bags and (" (+%d in the bank)"):format(all - bags) or "")
  if bags >= n then line = line .. (": |cff66dd66%d turn-in%s ready|r"):format(math.floor(bags / n), math.floor(bags / n) == 1 and "" or "s")
  else line = line .. (", %d more for the next turn-in"):format(n - bags) end
  tip:AddLine(line, 0.8, 0.8, 0.8)
  local me = charKey()
  for who, items in pairs(ns.db.alts) do
    if who ~= me and items[id] then tip:AddLine(("  %s has %d"):format(who:match("^[^-]+"), items[id]), 0.6, 0.6, 0.6) end
  end
  tip:Show()
end
local function hookTooltips()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
      if tip ~= GameTooltip and tip ~= ItemRefTooltip then return end
      local id = data and data.id
      if issecret(id) then return end
      addTooltip(tip, id)
    end)
  else
    local function onItem(tip)
      local _, link = tip:GetItem()
      local id = link and tonumber(link:match("item:(%d+)"))
      addTooltip(tip, id)
    end
    GameTooltip:HookScript("OnTooltipSetItem", onItem)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", onItem) end
  end
end

---------------------------------------------------------------------------
-- At the Faire: quick turn-ins, and learning the real quest details
---------------------------------------------------------------------------
local function npcID()
  local guid = UnitGUID("npc")
  if not guid or issecret(guid) then return nil end
  return tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end
local function atTurninNPC() local id = npcID() return id and D.NPCS[id] and true or false end
local function quick() return ns.On() and ns.db.quick ~= false and not IsShiftKeyDown() and atTurninNPC() end

-- can we hand this quest in, by what's in the bags?
local function haveFor(q)
  local t = BY_QUEST[q]
  if not t then return false end
  local item, n = learned(t)
  return (ns.Count(item)) >= n
end
local function haveForTitle(title)
  for _, t in ipairs(ns.AllTurnins()) do
    if t.title == title then return haveFor(t.q), t end
  end
  return false
end

local ev = CreateFrame("Frame")
ns.ev = ev
-- (events this game version doesn't have are skipped instead of stopping the addon)
local function on(e, fn) if pcall(ev.RegisterEvent, ev, e) then ev[e] = fn end end
ev:SetScript("OnEvent", function(self, e, ...) local fn = self[e] if fn then fn(...) end end)

on("ADDON_LOADED", function(name)
  if name ~= ADDON or ns.db then return end -- (once: from the event or from Rucksack's loader)
  RucksackFaireDB = RucksackFaireDB or RS.legacy.faire or {}
  RucksackFaireCharDB = RucksackFaireCharDB or RS.legacy.faireChar or {}
  local db, c = RucksackFaireDB, RucksackFaireCharDB
  -- (10 Nov) carry over what the old Faire Forever addon saved (it's now just an empty shell
  -- that keeps its saved data readable): account data once, each character's on its next login
  if type(FaireForeverDB) == "table" and not db.migrated then
    for k, v in pairs(FaireForeverDB) do if db[k] == nil then db[k] = v end end
    db.migrated = true
  end
  if type(FaireForeverCharDB) == "table" and not c.migrated then
    for k, v in pairs(FaireForeverCharDB) do if c[k] == nil then c[k] = v end end
    c.migrated = true
  end
  if db.enabled == nil then db.enabled = true end
  -- (1.7.1) the on-screen ticket button / prize card is off unless you turn it on: the Pocket's
  -- Tickets line shows the same. (Hidden once for everyone who had it from before.)
  if not db.screenButtonOffOnce then db.screenButtonOffOnce = true db.screenButton = nil end
  if db.keepItems == nil then db.keepItems = true end
  db.learned = db.learned or {}
  db.recipes = db.recipes or {}
  db.alts = db.alts or {}
  if db.quick == nil then db.quick = true end
  if db.tooltips == nil then db.tooltips = true end
  c.canMake = c.canMake or {}
  c.history = c.history or {}
  ns.db, ns.char = db, c
  -- (1.7) ticked in Settings > Modules while playing: the login already happened
  if IsLoggedIn and IsLoggedIn() and ev.PLAYER_LOGIN then C_Timer.After(0, ev.PLAYER_LOGIN) end
end)
on("PLAYER_LOGIN", function()
  hookTooltips()
  ns.ScanCards()
  for _, fn in ipairs(ns.onLogin) do pcall(fn) end
  local open = ns.FaireStatus()
  if open and ns.On() and ns.db.loginNote ~= false then Print(ns.FaireLine() .. ".  /faire to open.") end
end)

local pending = false
local function refresh()
  if pending then return end
  pending = true
  C_Timer.After(0.3, function()
    pending = false
    ns.ScanCards()
    saveAlts()
    if ns.Refresh then ns.Refresh() end
    if ns.PaintScreenButton then ns.PaintScreenButton() end
    RS.Changed() -- (Rucksack's Home, sidebar and Pocket)
  end)
end
on("BAG_UPDATE_DELAYED", refresh)
on("CURRENCY_DISPLAY_UPDATE", refresh)
on("UPDATE_FACTION", refresh)
on("PLAYER_LEVEL_UP", refresh)
on("BANKFRAME_OPENED", function() scanBankCards() refresh() end)
on("TRADE_SKILL_SHOW", function() pcall(scanTradeSkill) end)
on("TRADE_SKILL_UPDATE", function() pcall(scanTradeSkill) end)
on("TRADE_SKILL_LIST_UPDATE", function() pcall(scanTradeSkill) end)
on("TRADE_SKILL_DATA_SOURCE_CHANGED", function() pcall(scanTradeSkill) end)
on("PLAYER_LOGOUT", saveAlts)

-- the NPC's list: hand in finished quests first, then pick ones we have the items for
on("GOSSIP_SHOW", function()
  if not quick() or not C_GossipInfo then return end
  for _, q in ipairs(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) do
    if q.isComplete and BY_QUEST[q.questID] then C_GossipInfo.SelectActiveQuest(q.questID) return end
  end
  for _, q in ipairs(C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}) do
    if BY_QUEST[q.questID] and haveFor(q.questID) then C_GossipInfo.SelectAvailableQuest(q.questID) return end
  end
end)
-- (older style quest list)
on("QUEST_GREETING", function()
  if not quick() then return end
  for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
    local title, done = GetActiveTitle(i)
    if done and haveForTitle(title) then SelectActiveQuest(i) return end
  end
  for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
    if haveForTitle(GetAvailableTitle(i)) then SelectAvailableQuest(i) return end
  end
end)
on("QUEST_DETAIL", function()
  local q = GetQuestID and GetQuestID()
  if quick() and q and BY_QUEST[q] and haveFor(q) then AcceptQuest() end
end)
on("QUEST_PROGRESS", function()
  local q = GetQuestID and GetQuestID()
  local t = q and BY_QUEST[q]
  if t and atTurninNPC() and GetNumQuestItems and GetNumQuestItems() == 1 then
    -- learn what this turn-in really asks for
    local _, _, n = GetQuestItemInfo("required", 1)
    local link = GetQuestItemLink and GetQuestItemLink("required", 1)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id and n and n > 0 then
      local L = ns.db.learned[t.q] or {}
      L.item, L.n = id, n
      ns.db.learned[t.q] = L
    end
  end
  if quick() and t and IsQuestCompletable() then CompleteQuest() end
end)
on("QUEST_COMPLETE", function()
  local q = GetQuestID and GetQuestID()
  local t = q and BY_QUEST[q]
  if t and atTurninNPC() and GetNumRewardCurrencies and GetQuestCurrencyInfo then
    for i = 1, GetNumRewardCurrencies() do
      local name, _, amount = GetQuestCurrencyInfo("reward", i)
      if name and amount and amount > 0 and name:find("Ticket") then
        local L = ns.db.learned[t.q] or {}
        L.t = amount
        ns.db.learned[t.q] = L
      end
    end
  end
  if npcID() == D.PRIZE_NPC then ns.pendingPrize = GetTitleText and GetTitleText() end
  if quick() and t and (GetNumQuestChoices() or 0) <= 1 then GetQuestReward(1) end
end)
-- the reward log: tickets earned and prizes bought, per Faire
on("QUEST_TURNED_IN", function(q)
  local t = BY_QUEST[q]
  local _, _, _, s = ns.FaireStatus()
  local week = s and ("%d-%02d-%02d"):format(s[1], s[2], s[3]) or date("%Y-%m-%d")
  local h = ns.char.history
  if t then
    local _, _, tickets = learned(t)
    h[#h + 1] = { when = date("%Y-%m-%d %H:%M"), week = week, got = tickets, what = t.title }
  else
    local title = ns.pendingPrize
    ns.pendingPrize = nil
    for _, p in ipairs(D.PRIZES) do
      if title and title:find(p.name, 1, true) then
        h[#h + 1] = { when = date("%Y-%m-%d %H:%M"), week = week, spent = p.cost, what = p.name }
        break
      end
    end
  end
  while #h > 200 do table.remove(h, 1) end
  refresh()
end)

---------------------------------------------------------------------------
-- /faire
---------------------------------------------------------------------------
SLASH_RUCKSACKFAIRE1 = "/faire"
SLASH_RUCKSACKFAIRE2 = "/dmf"
SlashCmdList.RUCKSACKFAIRE = function(msg)
  local m = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if m == "clear" then if ns.Map then ns.Map.Clear() end return end
  if m == "track" then
    ns.db.tracker = ns.db.tracker == false
    if ns.PaintScreenButton then ns.PaintScreenButton() end
    ns.Print(ns.db.tracker and "prize tracker on (pick a prize on the Prizes tab)." or "prize tracker off.")
    return
  end
  if m == "button" then
    ns.db.screenButton = not ns.db.screenButton
    if ns.UpdateScreenButton then ns.UpdateScreenButton() end
    ns.Print(ns.db.screenButton and "on-screen button on." or "on-screen button off (/faire button brings it back).")
    return
  end
  if ns.Open then ns.Open(m ~= "" and m or nil) end
end
