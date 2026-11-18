-- Rucksack / Clean-up (was AutoDelete)
-- Replaces the game's "Do you want to destroy X?" Yes/No box with Always / Yes / No.
-- "Always" remembers the item (15 Nov: it no longer deletes it on the spot). Remembered items are
-- deleted on your next key press (or a click on the trash button) once your bags are nearly full
-- (fewer than minFree empty slots), the cheapest stack first (vendor price x stack). Right after
-- something is added the bags are checked once, so with full bags the cheapest one goes at once.
-- An item set to "as soon as I get it" (its page in the window) doesn't wait for full bags. Never in combat.
-- Why a key press: the game only lets an addon delete an item inside a click or a key press.
local ns = Rucksack
if not ns then return end
-- (1.7) Clean-up's own saved settings (from 1.x: taken over from the core's file)
ns.Module("del", (...), function()
  RucksackDeleteDB = RucksackDeleteDB or ns.legacy.del or {}
  ns.del = RucksackDeleteDB
end)
local Print, SlotInfo, CursorItem = ns.Print, ns.SlotInfo, ns.CursorItem
local DB

local Del = {}
ns.Del = Del

---------------------------------------------------------------------------
-- Finding remembered items in the bags
---------------------------------------------------------------------------
local function FreeSlots()
  local free = 0
  for bag = 0, ns.NUM_BAGS do
    local n, family = ns.GetFree(bag)
    if n and (family == nil or family == 0) then free = free + n end
  end
  return free
end
Del.FreeSlots = FreeSlots
local function BagsNearlyFull() return FreeSlots() < (DB.minFree or 2) end
Del.BagsNearlyFull = function() return DB and BagsNearlyFull() end
-- all ordinary bag slots (for "6 of 80 free")
function Del.TotalSlots()
  local n = 0
  for bag = 0, ns.NUM_BAGS do
    local _, family = ns.GetFree(bag)
    if family == nil or family == 0 then n = n + (ns.GetNumSlots(bag) or 0) end
  end
  return n
end

local function sellPrice(id) return select(11, ns.GetInfo(id)) or 0 end
-- (15 Nov) no vendor buys it (the game knows the item and its price is 0)
function Del.CantSell(id)
  local name, _, _, _, _, _, _, _, _, _, price = ns.GetInfo(id)
  return name ~= nil and (price or 0) == 0
end
-- (15 Nov) conjured things a class makes again for free (a mage's water, food and mana gems): the
-- tooltip says "Conjured Item". A warlock's stones say it too, but they cost a Soul Shard: not those.
local SHARD_STONES = { "Healthstone", "Soulstone", "Spellstone", "Firestone" }
local conjTip
function Del.IsConjured(id, link)
  if not id then return false end
  local name = ns.NameOf(id, link)
  if type(name) == "string" then
    for _, w in ipairs(SHARD_STONES) do if name:find(w, 1, true) then return false end end
  end
  local word = ITEM_CONJURED or "Conjured Item"
  if C_TooltipInfo and C_TooltipInfo.GetItemByID then
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if ok and data and data.lines then
      for _, l in ipairs(data.lines) do if l.leftText == word then return true end end
      return false
    end
  end
  if not conjTip then
    local ok, tip = pcall(CreateFrame, "GameTooltip", "RucksackConjScanTip", nil, "GameTooltipTemplate")
    if not ok or not tip then return false end
    conjTip = tip
  end
  if not conjTip.SetHyperlink then return false end
  conjTip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
  conjTip:ClearLines()
  if not pcall(conjTip.SetHyperlink, conjTip, "item:" .. id) then return false end
  for i = 2, (conjTip.NumLines and conjTip:NumLines() or 0) do
    local fs = _G["RucksackConjScanTipTextLeft" .. i]
    if fs and fs:GetText() == word then return true end
  end
  return false
end

-- (1.7.4) The junk pool: what Clean-up deletes or sells by itself (no quality to pick any more).
--  * grey items
--  * white weapons and armour in your bags, unless it's an upgrade: the slot is empty, or you wear
--    grey or white there with less armour (weapons: less damage per second). It only counts as an
--    upgrade when you can wear it (your armour and weapon types, your level).
--  * soulbound gear of any quality your class can't use (unbound stays: an alt, the Auction House)
-- Never: items with no vendor price, quest and key items, shirts and tabards, and (from white up)
-- food and drink, potions, reagents, trade goods, bags. Keep and the modules' keeps always win.
local SAFE_CLASS = { [0] = true, [1] = true, [5] = true, [7] = true, [12] = true, [13] = true }
local SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local DUAL = { WARRIOR = true, ROGUE = true, HUNTER = true } -- (an empty off hand only counts for these)
local statsOf = (C_Item and C_Item.GetItemStats) or GetItemStats
-- how good a piece is: damage per second for weapons, armour for the rest (item level if neither)
local function score(link, classID)
  if not link then return 0 end
  local st = statsOf and select(2, pcall(statsOf, link))
  if type(st) == "table" then
    local v = classID == 2 and st.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or st.RESISTANCE0_NAME
    if v and v > 0 then return v end
  end
  return (select(4, ns.GetInfo(link))) or 0
end
local function slotOf(id, equipLoc)
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if (not equipLoc or equipLoc == "") and instant then equipLoc = select(4, instant(id)) end
  return equipLoc
end
local function isUpgrade(id, link)
  local _, l, _, _, minLv, _, _, _, equipLoc, _, _, classID = ns.GetInfo(link or id)
  equipLoc = slotOf(id, equipLoc)
  local slots = SLOTS[equipLoc or ""]
  if not slots then return false end
  if ns.Sell and ns.Sell.CantUseType(id) then return false end
  if minLv and minLv > (UnitLevel("player") or 1) then return false end
  local mine = score(link or l, classID)
  local class = select(2, UnitClass("player"))
  for _, s in ipairs(slots) do
    if not (s == 17 and equipLoc == "INVTYPE_WEAPON" and not DUAL[class]) then
      local eq = GetInventoryItemLink("player", s)
      if not eq then return true end
      -- (1.7.4) better than what you wear there, whatever its colour
      if score(eq, classID) < mine then return true end
    end
  end
  return false
end
Del.IsUpgrade = isUpgrade
-- (1.7.4) profession tools: never deleted or sold by Clean-up, whatever their colour (another
-- character may need them). By item, by name (in case a server uses its own), and every fishing pole.
local TOOL_IDS = { [7005] = true, [2901] = true, [5956] = true, [6219] = true, [10498] = true, [9149] = true,
  [6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true,
  [6256] = true, [6365] = true, [6366] = true, [6367] = true, [12225] = true, [19022] = true, [19970] = true }
local TOOL_NAMES = { ["skinning knife"] = true, ["mining pick"] = true, ["blacksmith hammer"] = true, ["arclight spanner"] = true,
  ["gyromatic micro-adjustor"] = true, ["philosopher's stone"] = true, ["runed copper rod"] = true, ["runed silver rod"] = true,
  ["runed golden rod"] = true, ["runed truesilver rod"] = true, ["runed arcanite rod"] = true }
function Del.IsTool(id)
  if not id then return false end
  if TOOL_IDS[id] then return true end
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if instant then
    local _, _, _, _, _, classID, sub = instant(id)
    if classID == 2 and sub == 20 then return true end -- (a fishing pole)
  end
  local name = ns.NameOf(id)
  return name and TOOL_NAMES[name:lower()] or false
end
table.insert(ns.keepers, Del.IsTool)
table.insert(ns.uses, function(id) if Del.IsTool(id) then return "Profession: a profession tool" end end)
local boundSeen = {} -- id -> true once a bound copy was seen in your bags
-- why an item is junk (bag and slot: that very copy, for "soulbound"), or nil
local function byRule(id, bag, slot)
  if DB.keep[id] or ns.KeepItem(id) then return nil end
  local name, link, quality, _, _, _, _, _, equipLoc, _, sell, classID = ns.GetInfo(id)
  if not name or not quality or not sell or sell <= 0 then return nil end
  if classID == 12 or classID == 13 then return nil end
  equipLoc = slotOf(id, equipLoc)
  local gear = (classID == 2 or classID == 4) and SLOTS[equipLoc or ""] ~= nil
  if quality == 0 then
    if gear and isUpgrade(id, link) then return nil end
    return "grey (junk)"
  end
  if SAFE_CLASS[classID] or not gear then return nil end
  local cant = ns.Sell and ns.Sell.CantUseType(id)
  if cant then
    local bound
    if bag and slot and ns.Sell.Soulbound then bound = ns.Sell.Soulbound(bag, slot) if bound then boundSeen[id] = true end
    else bound = boundSeen[id] end
    if bound then
      local armour = cant:match("^sell armor: (.+)$")
      return armour and ("soulbound " .. armour .. ", you don't wear it") or ("soulbound, " .. cant)
    end
  end
  -- (1.7.4) white: only gear your class can't wear, or worse than what you wear in that slot
  if quality == 1 then
    if cant then return "white, " .. (cant:match("^sell armor: (.+)$") and ("you don't wear " .. cant:match("^sell armor: (.+)$")) or cant) end
    if not isUpgrade(id, link) then return "white, worse than what you wear" end
  end
  return nil
end
Del.ByRule = function(id, bag, slot) return DB and byRule(id, bag, slot) end
Del.ByQuality = Del.ByRule -- (older name)
-- (10 Nov) Rations' rules: water on a character that drinks none (as soon as it lands), food and
-- water for below a level (when bags are nearly full). Keep wins over them too.
local function byFood(id)
  if DB.keep[id] or not (ns.Eat and ns.Eat.DeleteReason) then return nil end
  return ns.Eat.DeleteReason(id)
end
Del.ByFood = function(id) if DB then return byFood(id) end end
local function onList(id, bag, slot)
  if ns.KeepItem(id) then return false end -- (Darkmoon turn-in items, scrolls... stay)
  if bag and ns.Bags and ns.Bags.BankSlot and ns.Bags.BankSlot(bag, slot, id) then return false end -- (15 Nov: on its way to the bank)
  if bag and ns.AutoOpen and ns.AutoOpen.WillOpen and ns.AutoOpen.WillOpen(bag, slot) then return false end -- (16 Nov: a clam to open first)
  if DB.sell[id] then return false end -- (1.8.2 Sell: sold at a vendor, never thrown away)
  if Del.SlotSell(bag, slot, id) then return false end -- (15 Nov: this very stack is marked for sale)
  if Del.SlotJunk(bag, slot, id) then return true end  -- (15 Nov: this very stack is marked to be thrown away)
  return DB.items[id] or byRule(id, bag, slot) or (byFood(id) and true)
end
Del.OnList = function(id, bag, slot) return DB and onList(id, bag, slot) and true or false end
-- why an item goes, in words (for lists and tooltips)
function Del.Reason(id)
  if not DB then return nil end
  if DB.sell[id] then return "sell only: sold at a vendor, never thrown away" end
  if DB.items[id] then return DB.now[id] and "on your list (as soon as you get it)" or "on your list" end
  local junk = byRule(id)
  if junk then return junk end
  local why = byFood(id)
  if why then return why end
end
local function goesNow(id)
  if DB.now[id] then return true end
  local why, now = byFood(id)
  return why and now == "now"
end

-- Active quest item requirements: lowercase item name -> how many your current quests still want
-- in total (the objective's full amount: the items are handed in at the end). Read from the quest
-- log, with whichever quest API this client has; cached for a moment (bags and the log update a lot).
local reqCache, reqAt = nil, -1
local function GetQuestRequirements()
  local now = GetTime()
  if reqCache and now - reqAt < 0.5 then return reqCache end
  local reqByName, titles = {}, {}
  local seen = 0
  local function addObjective(text, numReq, title)
    if type(text) ~= "string" or text == "" then return end
    local name, _, r = text:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    if not name then
      local _, r2, name2 = text:match("^%s*(%d+)%s*/%s*(%d+)%s+(.+)$")
      if name2 then name, r = name2, r2 end
    end
    if name then
      name = name:gsub("^%s+", ""):gsub("%s+$", ""):lower()
      local need = tonumber(numReq) or tonumber(r) or 0
      if name ~= "" and need > 0 then
        reqByName[name] = (reqByName[name] or 0) + need
        if title then titles[name] = titles[name] or {} table.insert(titles[name], title) end
      end
    end
  end
  -- the older quest log (Classic clients): titles and objective lines by index
  if GetNumQuestLogEntries and GetQuestLogTitle and GetQuestLogLeaderBoard then
    local okN, num = pcall(GetNumQuestLogEntries)
    for i = 1, (okN and tonumber(num) or 0) do
      local okT, title, _, _, isHeader = pcall(GetQuestLogTitle, i)
      if okT and title and not isHeader then
        seen = seen + 1
        local nObj = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0
        for j = 1, nObj do
          local okL, text, objType = pcall(GetQuestLogLeaderBoard, j, i)
          if okL and (not objType or objType == "item" or objType == "object") then addObjective(text, nil, title) end
        end
      end
    end
  end
  -- the newer one, when the older one isn't there (or found nothing)
  if seen == 0 and C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
    local okN, num = pcall(C_QuestLog.GetNumQuestLogEntries)
    for i = 1, (okN and tonumber(num) or 0) do
      local okI, info = pcall(C_QuestLog.GetInfo, i)
      if okI and info and not info.isHeader and info.questID then
        local okO, objs = pcall(C_QuestLog.GetQuestObjectives, info.questID)
        if okO and type(objs) == "table" then
          for _, obj in ipairs(objs) do
            if not obj.type or obj.type == "item" or obj.type == "object" then addObjective(obj.text, obj.numRequired, info.title) end
          end
        end
      end
    end
  end
  reqCache, reqAt = reqByName, now
  Del.questTitles = titles
  return reqByName
end

-- How many of item `id` your current quests need (0: none; math.huge: keep them all).
-- By its name in the quest objectives (also "Gnoll Paw" for "Gnoll Paws"). An item that starts a
-- quest you haven't taken yet is kept. Other quest items no current quest asks for may go.
local function QuestNeedForItem(id, link, bag, slot, reqMap)
  reqMap = reqMap or GetQuestRequirements()
  local nm = ns.NameOf(id, link)
  if nm then
    local low = nm:lower()
    local need = reqMap[low]
    if need and need > 0 then return need end
    if #low >= 4 then
      for key, n in pairs(reqMap) do
        if n > 0 and (key == low .. "s" or key == low .. "es" or low == key .. "s") then return n end
      end
    end
  end
  if bag and slot and ns.GetQuestInfo then
    local okQ, qi, qid, active = pcall(ns.GetQuestInfo, bag, slot)
    if okQ and qi then
      if type(qi) == "table" then qid, active = qi.questID, qi.isActive end
      if qid and not active then return math.huge end -- (starts a quest)
    end
  end
  return 0
end
Del.QuestNeed = function(id, link) return QuestNeedForItem(id, link, nil, nil, GetQuestRequirements()) end
-- (1.7.4) for the warning when you delete it by hand
table.insert(ns.uses, function(id, link)
  local need = QuestNeedForItem(id, link, nil, nil, GetQuestRequirements())
  if need == 0 then return nil end
  local nm = (ns.NameOf(id, link) or ""):lower()
  local t = Del.questTitles and (Del.questTitles[nm] or Del.questTitles[nm .. "s"] or Del.questTitles[nm .. "es"])
  local which = t and ("|cffffd100" .. table.concat(t, ", ") .. "|r") or "a quest you have"
  if need == math.huge then return "Quest: it starts a quest" end
  return "Quest: " .. which .. " needs " .. need
end)

-- The cheapest remembered stack (vendor price x count) that may go now, and how many items are
-- waiting in total. Quest items are protected up to the exact required quest amount; only excess
-- above the quest requirement is deleted!
local keptForQuest = {}
function Del.KeptForQuest() return keptForQuest end
local function ScanBags(ready)
  local best, bestValue, total, stacks = nil, nil, 0, 0
  local cands = {} -- (1.7.4) everything that can go, cheapest first (tooltips list them)
  wipe(keptForQuest)
  local full = BagsNearlyFull()
  local reqMap = GetQuestRequirements()
  local byID = {}
  for bag = 0, ns.NUM_BAGS do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, count, link, icon, locked = SlotInfo(bag, slot)
      if id and onList(id, bag, slot) then
        local g = byID[id]
        if not g then
          g = {
            id = id,
            total = 0,
            need = QuestNeedForItem(id, link, bag, slot, reqMap),
            slots = {},
          }
          byID[id] = g
        elseif g.need == 0 then
          local slotNeed = QuestNeedForItem(id, link, bag, slot, reqMap)
          if slotNeed > 0 then g.need = slotNeed end
        end
        g.total = g.total + count
        if not locked then
          g.slots[#g.slots + 1] = { bag = bag, slot = slot, id = id, count = count, link = link, icon = icon }
        end
      end
    end
  end
  for id, g in pairs(byID) do
    local excess = g.total - (g.need or 0)
    if g.need and g.need > 0 then keptForQuest[id] = math.min(g.need, g.total) end
    if excess > 0 and (not ready or full or goesNow(id)) then
      total = total + excess
      stacks = stacks + 1
      -- Prefer a slot whose stack count <= excess (so we can delete a whole small stack first),
      -- otherwise pick the smallest stack and split off `excess` from it!
      table.sort(g.slots, function(a, b) return a.count < b.count end)
      local chosen, delCount
      for _, s in ipairs(g.slots) do
        if s.count <= excess then
          chosen, delCount = s, s.count
          break
        end
      end
      if not chosen and g.slots[1] then
        chosen, delCount = g.slots[1], excess
      end
      if chosen and delCount and delCount > 0 then
        local value = sellPrice(id) * delCount
        cands[#cands + 1] = { id = id, link = chosen.link, count = excess, value = sellPrice(id) * excess }
        if not best or value < bestValue then
          best = {
            bag = chosen.bag,
            slot = chosen.slot,
            id = id,
            count = chosen.count,
            deleteCount = delCount,
            link = chosen.link,
            icon = chosen.icon,
            questNeed = g.need,
          }
          bestValue = value
        end
      end
    end
  end
  table.sort(cands, function(a, b) return a.value < b.value end)
  if not ready then Del.cands = cands end
  return best, total, stacks, bestValue
end
-- (1.7.4) a tooltip block: what can go, first one marked, and when
function Del.TipList(maxLines)
  local list = Del.cands or {}
  local free, keep = FreeSlots(), DB.minFree or 2
  if #list == 0 then
    GameTooltip:AddLine("Nothing in your bags can be thrown away.", 0.8, 0.8, 0.8, true)
    return
  end
  GameTooltip:AddLine(#list .. (#list == 1 and " item" or " items") .. " in your bags can be thrown away when your bags fill up:", 1, 1, 1, true)
  for i, c in ipairs(list) do
    if i > (maxLines or 8) then GameTooltip:AddLine(("... and %d more"):format(#list - i + 1), 0.7, 0.7, 0.7) break end
    GameTooltip:AddDoubleLine((c.link or ns.NameOf(c.id)) .. (c.count > 1 and (" x" .. c.count) or "") .. (i == 1 and "  |cffffd100<- first|r" or ""),
      ns.Sell.Money(c.value), 1, 1, 1, 1, 1, 1)
  end
  if free < keep then
    GameTooltip:AddLine(("Only %d free, you keep %d: the first one goes on your next key press."):format(free, keep), 1, 0.4, 0.4, true)
  else
    GameTooltip:AddLine(("You have %d free, you keep %d. Nothing goes until you're below %d."):format(free, keep, keep), 0.7, 0.7, 0.7, true)
  end
end
Del.Scan = function(ready) if DB then return ScanBags(ready) end end

local Refresh -- below

-- Deletes one remembered stack. Must be called from a click or a key press.
-- force = true (trash button / key binding): any remembered stack, full bags or not.
local function RecordMeta(id, link, count, wasDeleted, how)
  if not DB or not id then return end
  DB.meta = DB.meta or {}
  local m = DB.meta[id] or {}
  local l = (type(link) == "string" and link) or (type(DB.items[id]) == "string" and DB.items[id]) or m.link or ns.LinkOf(id)
  if l then m.link = l end
  local nm = ns.NameOf(id, l)
  if nm and not nm:match("^item %d+$") then m.name = nm end
  local ic = ns.GetIcon(id)
  if ic then m.icon = ic end
  local q = ns.QualityOf(id, l)
  if q ~= nil then m.quality = q end
  if wasDeleted then
    m.lastDeleted = time()
    m.deletedCount = (m.deletedCount or 0) + (count or 1)
    if how then m.lastHow = how end
    -- (10 Nov) the delete history: the last 100, newest first
    DB.history = DB.history or {}
    table.insert(DB.history, 1, { id = id, link = l, count = count or 1, t = m.lastDeleted, how = how })
    while #DB.history > 100 do table.remove(DB.history) end
  end
  DB.meta[id] = m
end
Del.RecordMeta = RecordMeta

-- (1.7.4) the delete limit: a stack worth more than DB.maxValue isn't deleted. Clean-up stops,
-- tells you once, and waits: until you choose (click the trash button: Delete it / Keep it / Not
-- now), or until you free up a bag slot yourself.
local ShowBlocked -- below
function Del.Blocked() return Del.blocked end
-- (17 Nov, 1.9) the slider beside the bag sets this too: "Delete only items worth up to". 10s to 5g
-- in 10s steps, nil = no limit. Over it, Clean-up never deletes by itself: it's sold at a vendor.
Del.LIMIT_STEP, Del.LIMIT_STEPS = 1000, 50
function Del.Limit() return DB and DB.maxValue end
function Del.SetLimit(v)
  if not DB then return end
  if v then
    v = math.max(1, math.min(Del.LIMIT_STEPS, math.floor(v / Del.LIMIT_STEP + 0.5))) * Del.LIMIT_STEP
    DB.lastLimit = v
  end
  DB.maxValue = v
  if Refresh then Refresh() end
  if ns.Changed then ns.Changed() end
end
local function DeleteOne(force)
  if not DB or not DB.enabled then return false end
  if InCombatLockdown() then return false end
  if CursorHasItem() or (SpellIsTargeting and SpellIsTargeting()) then return false end
  local it, _, _, value = ScanBags(not force)
  if not it then return false end
  if DB.maxValue and (value or 0) > DB.maxValue and Del.allowOnce ~= it.id then
    local b = Del.blocked
    if not b or b.id ~= it.id then
      Del.blocked = { id = it.id, link = it.link, value = value, free = FreeSlots() }
      Print("your bags are nearly full, but " .. (it.link or ns.NameOf(it.id)) .. " (" .. ns.Sell.Money(value) .. ") is worth more than your " ..
        ns.Sell.Money(DB.maxValue) .. " delete limit, so it's kept for a vendor. Click the trash button to choose.")
      Refresh()
    end
    if force and ShowBlocked then ShowBlocked() end
    return false
  end
  Del.allowOnce, Del.blocked = nil, nil
  local delCount = it.deleteCount or it.count
  if delCount < it.count and ns.SplitBagItem then
    ns.SplitBagItem(it.bag, it.slot, delCount)
  else
    delCount = it.count
    ns.PickupBagItem(it.bag, it.slot)
  end
  local id = CursorItem()
  if id == it.id then
    RecordMeta(it.id, it.link, delCount, true, DB.items[it.id] and "always" or Del.SlotJunk(it.bag, it.slot, it.id) and "once" or byRule(it.id, it.bag, it.slot) and "quality" or "rations")
    DeleteCursorItem()
    DB.deleted = (DB.deleted or 0) + delCount
    if DB.chat then
      local qNote = (it.questNeed and it.questNeed > 0 and it.questNeed < math.huge)
        and (" |cff66dd66(kept " .. it.questNeed .. " for quest)|r") or ""
      Print("deleted " .. (it.link or ns.NameOf(it.id)) .. (delCount > 1 and (" x" .. delCount) or "") .. qNote)
    end
    C_Timer.After(0.3, function() Refresh() end)
    return true
  end
  ClearCursor() -- the slot changed under us: delete nothing
  return false
end
-- (1.7.4) the trash button and the RuckDelete macro do the same thing: throw the first item away
-- now (or, over the delete limit, ask what to do); with nothing to throw away, open the Clean-up page
function Del.Click()
  if InCombatLockdown() then Print("waiting until combat ends.") return end
  if Del.blocked then if Del.ShowBlocked then Del.ShowBlocked() end return end
  if not ScanBags(false) then Rucksack_Open("del") return end
  DeleteOne(true)
end
function AutoDelete_DeleteNext() Del.Click() end
-- (15 Nov) right after something goes on the list: look at the bags now, so with nearly full bags
-- the cheapest waiting stack goes straight away (the usual rule: the cheapest, not always the new
-- one). Everything that adds to the list is a click, and the game only deletes inside a click.
function Del.CheckNow()
  if CursorHasItem() then ClearCursor() end
  -- (15 Nov) at a vendor: he buys what's waiting, nothing is thrown away
  if ns.Sell and ns.Sell.Kick and ns.Sell.Kick() then return false end
  local ok, did = pcall(DeleteOne, false)
  return ok and did or false
end

-- (1.7.4) grey items are on the list already (they go by themselves): not added, only un-kept
function Del.IsGrey(id, link) return ns.QualityOf(id, link) == 0 end
function Del.Add(id, link)
  if Del.IsGrey(id, link) then
    DB.keep[id], DB.sell[id] = nil, nil
    Refresh()
    Del.CheckNow()
    return false, "grey"
  end
  local savedLink = link or ns.LinkOf(id)
  DB.items[id] = savedLink or true
  DB.keep[id], DB.sell[id] = nil, nil
  RecordMeta(id, savedLink, 0, false, "always")
  Refresh()
  Del.CheckNow()
  return true
end
-- (15 Nov) Sell, three ways. "Always": every one of this item, at every vendor (DB.sell, as before).
-- "Sell all": every stack you have right now, once. "Sell stack": just the stack you're holding,
-- once. The last two are marks on bag slots (this character's): [bag:slot] = item id. A mark is
-- good while that slot still holds that item; anything else in the slot and it's dropped.
-- The delete box marks single stacks the same way: "Delete N" = junkSlots (thrown away by the usual
-- rule: bags nearly full, cheapest first; a vendor buys it before that), "Sell N" = sellSlots.
local function slotKey(bag, slot) return bag .. ":" .. slot end
local function slotMarks(which)
  which = which or "sellSlots"
  ns.char[which] = ns.char[which] or {}
  return ns.char[which]
end
local function slotMarked(which, bag, slot, id)
  local m = bag and slot and ns.char and ns.char[which]
  if not m then return false end
  local want = m[slotKey(bag, slot)]
  if not want then return false end
  if id == nil then id = SlotInfo(bag, slot) end
  if want ~= id then m[slotKey(bag, slot)] = nil return false end
  return true
end
function Del.SlotSell(bag, slot, id) return slotMarked("sellSlots", bag, slot, id) end
function Del.SlotJunk(bag, slot, id) return slotMarked("junkSlots", bag, slot, id) end
local function clearSlotMarks(id)
  for _, which in ipairs({ "sellSlots", "junkSlots" }) do
    local m = ns.char and ns.char[which]
    if m then for k, v in pairs(m) do if v == id then m[k] = nil end end end
  end
end
-- marks whose stack is gone (sold, deleted, moved, used up): dropped, so nothing that lands there later goes
local function sweepSlotMarks()
  for _, which in ipairs({ "sellSlots", "junkSlots" }) do
    local m = ns.char and ns.char[which]
    if m and next(m) then
      for k, want in pairs(m) do
        local bag, slot = k:match("^(-?%d+):(%d+)$")
        if not bag or SlotInfo(tonumber(bag), tonumber(slot)) ~= want then m[k] = nil end
      end
    end
  end
end
local sweeper = CreateFrame("Frame")
pcall(sweeper.RegisterEvent, sweeper, "BAG_UPDATE_DELAYED")
sweeper:SetScript("OnEvent", function() pcall(sweepSlotMarks) end)
-- the stack on your cursor: which slot it came from (the game locks that slot while you hold it)
function Del.HeldSlot(id)
  for bag = 0, ns.NUM_BAGS do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local sid, _, _, _, locked = SlotInfo(bag, slot)
      if sid == id and locked then return bag, slot end
    end
  end
end
function Del.SellStack(bag, slot, id)
  if not bag or not slot then return false end
  slotMarks("sellSlots")[slotKey(bag, slot)] = id
  slotMarks("junkSlots")[slotKey(bag, slot)] = nil
  Refresh()
  if ns.Sell and ns.Sell.Kick then ns.Sell.Kick() end -- (at a vendor: sold right away)
  return true
end
-- this one stack is junk: thrown away by the usual rule (and the bags are looked at right away)
function Del.JunkStack(bag, slot, id)
  if not bag or not slot then return false end
  slotMarks("junkSlots")[slotKey(bag, slot)] = id
  slotMarks("sellSlots")[slotKey(bag, slot)] = nil
  Refresh()
  Del.CheckNow()
  return true
end
-- every stack of it in your bags right now; -> how many stacks, how many items
function Del.SellAllNow(id)
  local stacks, items, m = 0, 0, slotMarks()
  for bag = 0, ns.NUM_BAGS do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local sid, count = SlotInfo(bag, slot)
      if sid == id then m[slotKey(bag, slot)] = id stacks, items = stacks + 1, items + (count or 1) end
    end
  end
  Refresh()
  if ns.Sell and ns.Sell.Kick then ns.Sell.Kick() end -- (at a vendor: sold right away)
  return stacks, items
end
-- (1.8) keep it: off your list, and the rules leave it alone too
function Del.Keep(id)
  DB.keep[id] = true
  DB.items[id], DB.now[id], DB.sell[id] = nil, nil, nil
  clearSlotMarks(id)
  Refresh()
end
-- keep the stack in that slot: if only that stack was marked for sale, only its mark goes ("stack");
-- otherwise the whole item is kept, as before ("all")
function Del.KeepAt(id, bag, slot)
  if bag and not DB.sell[id] and Del.SlotSell(bag, slot, id) then
    ns.char.sellSlots[slotKey(bag, slot)] = nil
    Refresh()
    return "stack"
  end
  if bag and Del.SlotJunk(bag, slot, id) then
    ns.char.junkSlots[slotKey(bag, slot)] = nil
    if not onList(id, bag, slot) then Refresh() return "stack" end -- (still junk some other way: keep the item)
  end
  Del.Keep(id)
  return "all"
end
-- (1.8.2) Sell: sold at a vendor every time, never thrown away (not even when your bags are full)
function Del.AddSell(id, link)
  DB.sell[id] = link or ns.LinkOf(id) or true
  DB.items[id], DB.now[id], DB.keep[id] = nil, nil, nil
  clearSlotMarks(id)
  Refresh()
  if ns.Sell and ns.Sell.Kick then ns.Sell.Kick() end -- (at a vendor: sold right away)
end
function Del.IsSell(id) return DB and DB.sell[id] and true or false end
-- 1 = junk (your list or the rules: sold or thrown away), 2 = sell only, nil = neither
-- (with a bag and slot it also knows a single stack marked for sale)
function Del.JunkKind(id, bag, slot)
  if not DB or ns.KeepItem(id) then return nil end
  if DB.sell[id] then return 2 end
  if Del.SlotSell(bag, slot, id) then return 2 end
  return onList(id, bag, slot) and 1 or nil
end
-- the same for the stack on your cursor
function Del.HeldKind(id)
  local bag, slot = Del.HeldSlot(id)
  return Del.JunkKind(id, bag, slot)
end
function Del.Remove(id)
  DB.items[id], DB.now[id], DB.sell[id] = nil, nil, nil
  clearSlotMarks(id)
  Refresh()
end

---------------------------------------------------------------------------
-- Key catcher: on any key press (out of combat) delete one waiting stack; the key still works
---------------------------------------------------------------------------
local keyCatcher = CreateFrame("Frame", "RucksackDeleteKeyCatcher", UIParent)
keyCatcher:SetAllPoints(UIParent)
keyCatcher:EnableMouse(false)
keyCatcher:EnableKeyboard(false)
local propagateOK = false
local function EnsurePropagate()
  if propagateOK or InCombatLockdown() then return end
  propagateOK = pcall(keyCatcher.SetPropagateKeyboardInput, keyCatcher, true)
  if propagateOK and keyCatcher.GetPropagateKeyboardInput then
    propagateOK = keyCatcher:GetPropagateKeyboardInput() and true or false
  end
end
EnsurePropagate()
keyCatcher:SetScript("OnKeyDown", function() DeleteOne() end)

---------------------------------------------------------------------------
-- The Always / Yes / No dialog
---------------------------------------------------------------------------
local ask = CreateFrame("Frame", "RucksackDeleteAsk", UIParent, ns.BACKDROP_TMPL)
ask:SetSize(480, 150)
ask:SetPoint("TOP", UIParent, "TOP", 0, -135)
ask:SetFrameStrata("FULLSCREEN_DIALOG")
ask:SetToplevel(true)
ask:EnableMouse(true)
ask:SetBackdrop(ns.DIALOG_BACKDROP)
ask:Hide()
tinsert(UISpecialFrames, "RucksackDeleteAsk") -- Esc closes it (counts as No)

local alert = ask:CreateTexture(nil, "ARTWORK")
alert:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
alert:SetSize(48, 48)
alert:SetPoint("LEFT", ask, "LEFT", 22, 14)

local askIcon = CreateFrame("Button", nil, ask)
askIcon:SetSize(36, 36)
askIcon:SetPoint("LEFT", alert, "RIGHT", 10, 0)
askIcon.tex = askIcon:CreateTexture(nil, "ARTWORK")
askIcon.tex:SetAllPoints()
askIcon:SetScript("OnEnter", function(self) if ask.data then ns.ShowItemTooltip(self, ask.data.id, ask.data.link) end end)
askIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)

local askText = ask:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
askText:SetPoint("TOPLEFT", askIcon, "TOPRIGHT", 10, 2)
askText:SetPoint("RIGHT", ask, "RIGHT", -22, 0)
askText:SetJustifyH("LEFT")

local askHint = ask:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
askHint:SetPoint("TOPLEFT", askText, "BOTTOMLEFT", 0, -6)
askHint:SetPoint("RIGHT", ask, "RIGHT", -22, 0)
askHint:SetJustifyH("LEFT")
askHint:SetText("Delete = thrown away when your bags are nearly full, the cheapest first.  Sell = sold at the next vendor, never thrown away.")

local askWarn = ask:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
askWarn:SetPoint("TOPLEFT", askHint, "BOTTOMLEFT", 0, -4)
askWarn:SetText("")

local function MakeButton(parent, text, w)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 110, 24)
  b:SetText(text)
  return b
end
-- (15 Nov) Always delete / Delete N / Sell N / Cancel. N = how many are in the stack you're holding.
-- Always delete: every one of this item. Delete N: only this stack. Both wait for the usual rule
-- (bags nearly full, the cheapest first). Sell N: this stack is sold at a vendor, never thrown away.
local btnAlways = MakeButton(ask, "Always delete", 124)
local btnYes = MakeButton(ask, "Delete", 104)   -- (the Delete N button; the name is from when it said Yes)
local btnSell = MakeButton(ask, "Sell", 104)
local btnNo = MakeButton(ask, "Cancel", 96)
btnAlways:SetPoint("BOTTOMLEFT", ask, "BOTTOMLEFT", 70, 18)
btnYes:SetPoint("LEFT", btnAlways, "RIGHT", 8, 0)
btnSell:SetPoint("LEFT", btnYes, "RIGHT", 8, 0)
btnNo:SetPoint("LEFT", btnSell, "RIGHT", 8, 0)
local function askTip(b, fn)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    for i, l in ipairs(fn()) do
      if i == 1 then GameTooltip:AddLine(l) else GameTooltip:AddLine(l, 1, 1, 1, true) end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
btnSell:GetFontString():SetTextColor(1, 0.82, 0)
if btnSell.SetMotionScriptsWhileDisabled then btnSell:SetMotionScriptsWhileDisabled(true) end -- (its tip still shows when it's greyed out)
askTip(btnSell, function()
  if ask.data and ask.data.cantSell then return { "Can't be sold", "No vendor buys this item." } end
  return { "Sell this stack",
  "Only this stack. It stays in your bags and is sold at the next vendor. It's never thrown away, not even when your bags are full.",
  "Take it back: pick it up and drop it on the green slot in Sell." } end)
btnAlways:GetFontString():SetTextColor(1, 0.35, 0.35)
askTip(btnAlways, function() return { "Always delete this item",
  "Every one of it, also the ones you get later. It stays in your bags for now: a vendor buys it, or it's thrown away when your bags are nearly full, the cheapest thing first.",
  "If your bags are full right now, the cheapest thing on your list goes straight away.",
  "Undo it on the Clean-up page (/ruck)." } end)
askTip(btnYes, function() return { "Delete this stack",
  "Only this stack. It stays in your bags for now: a vendor buys it, or it's thrown away when your bags are nearly full, the cheapest thing first.",
  "If your bags are full right now, the cheapest thing that's waiting goes straight away.",
  "Shift-click: delete it right now instead." } end)

local function HideGamePopup() if ask.which then StaticPopup_Hide(ask.which) end end

local function Decide(action, button)
  local d = ask.data
  if not d then ask:Hide() return end
  if action == "sell" and d.cantSell then return end -- (greyed out)
  local name = d.link or ns.NameOf(d.id)
  -- (17 Nov) the "Are you sure?" box: needed for something? Say what, and ask once more.
  if d.confirm and action ~= "no" then
    action, d.warned, d.now = "delete", "delete", true
  end
  -- (1.7.4) the second step: "... anyway" does what you picked first (Always delete or Delete N)
  if d.warned then
    if action ~= "no" then action = d.warned end
  elseif action == "always" or action == "delete" then
    -- something Rucksack knows is useful (a quest, the Faire, a scroll, your next food, rare and
    -- better): ask once more and say what it's for. (Only before deleting: Sell keeps the item.)
    local uses = ns.UsedFor(d.id, d.link)
    if #uses > 0 then
      d.warned = action
      d.now = action == "delete" and IsShiftKeyDown and IsShiftKeyDown() or false
      askText:SetText((action == "always" and "Do you really want to always delete " or "Do you really want to delete ") .. name .. "?")
      askHint:SetText("It's used for:\n|cffffffff- " .. table.concat(uses, "\n- ") .. "|r")
      askWarn:SetText(d.now and "It's deleted right now." or action == "always" and "Every one goes on your list: thrown away when your bags are nearly full." or "This stack is thrown away when your bags are nearly full.")
      btnAlways:Hide()
      btnSell:Hide()
      btnYes:SetText(d.now and "Delete anyway" or "Add anyway") btnYes:SetWidth(130)
      btnYes:GetFontString():SetTextColor(1, 0.35, 0.35)
      btnNo:SetText("Cancel")
      ask:SetHeight(150 + 14 * #uses)
      return
    end
  end
  ask.decided = true
  local now = action == "delete" and (d.now or (not d.warned and IsShiftKeyDown and IsShiftKeyDown())) or false
  -- the stack you're holding: its slot is locked while it's on your cursor
  local bag, slot = Del.HeldSlot(d.id)
  local count = bag and select(2, SlotInfo(bag, slot)) or d.count
  local xN = count and count > 1 and (" x" .. count) or ""
  if action == "no" then
    ClearCursor()
  elseif action == "delete" and (now or not bag) then
    -- Shift-click (or the stack can't be found in your bags): delete it right now, as Yes used to
    RecordMeta(d.id, d.link, 1, true, "once")
    if CursorItem() == d.id then
      DeleteCursorItem()
    else
      Print("the item is no longer on your cursor, nothing deleted.")
    end
  else
    ClearCursor()
    HideGamePopup()
    ask:Hide()
    if action == "always" then
      -- every one of it goes on your list and waits like the rest. Del.Add looks at the bags right
      -- away, so with full bags the cheapest waiting thing goes now.
      local added = Del.Add(d.id, d.link)
      Print(name .. (added and (d.cantSell and " is on your list: every one is thrown away when your bags are nearly full (cheapest first). Undo it on the Clean-up page: /ruck"
        or " is on your list: every one is sold at a vendor, or thrown away when your bags are nearly full (cheapest first). Undo it on the Clean-up page: /ruck")
        or " is grey: it goes by itself already."))
    elseif action == "delete" then
      Del.JunkStack(bag, slot, d.id)
      Print(name .. xN .. ": this stack is thrown away when your bags are nearly full, the cheapest thing first." .. (d.cantSell and "" or " A vendor buys it before that."))
    elseif action == "sell" then
      if bag then
        Del.SellStack(bag, slot, d.id)
        Print(name .. xN .. ": this stack is sold at the next vendor. It's never thrown away.")
      else
        Del.AskSell(d.id, d.link) -- (the stack can't be found: ask how instead)
      end
    end
    if ns.Changed then ns.Changed() end
    C_Timer.After(0.3, function() Refresh() end)
    return
  end
  HideGamePopup()
  ask:Hide()
  C_Timer.After(0.3, function() Refresh() end)
end
---------------------------------------------------------------------------
-- (15 Nov) The Sell box (a stack dropped on Sell in the bag): Always / Sell all / Sell N / Cancel
---------------------------------------------------------------------------
local sellAsk = CreateFrame("Frame", "RucksackSellAsk", UIParent, ns.BACKDROP_TMPL)
sellAsk:SetSize(480, 128)
sellAsk:SetPoint("TOP", UIParent, "TOP", 0, -135)
sellAsk:SetFrameStrata("FULLSCREEN_DIALOG")
sellAsk:SetToplevel(true)
sellAsk:EnableMouse(true)
sellAsk:SetBackdrop(ns.DIALOG_BACKDROP)
sellAsk:Hide()
tinsert(UISpecialFrames, "RucksackSellAsk") -- Esc closes it (counts as Cancel)
local sellIcon = CreateFrame("Button", nil, sellAsk)
sellIcon:SetSize(36, 36)
sellIcon:SetPoint("TOPLEFT", 24, -22)
sellIcon.tex = sellIcon:CreateTexture(nil, "ARTWORK")
sellIcon.tex:SetAllPoints()
sellIcon:SetScript("OnEnter", function(self) if sellAsk.data then ns.ShowItemTooltip(self, sellAsk.data.id, sellAsk.data.link) end end)
sellIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
local sellText = sellAsk:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sellText:SetPoint("TOPLEFT", sellIcon, "TOPRIGHT", 10, 0)
sellText:SetPoint("RIGHT", sellAsk, "RIGHT", -22, 0)
sellText:SetJustifyH("LEFT")
local sellHint = sellAsk:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
sellHint:SetPoint("TOPLEFT", sellText, "BOTTOMLEFT", 0, -6)
sellHint:SetPoint("RIGHT", sellAsk, "RIGHT", -22, 0)
sellHint:SetJustifyH("LEFT")
sellHint:SetText("Sold at the next vendor, never thrown away. Take it back: pick it up and drop it on the green slot in Sell.")
local sbAlways = MakeButton(sellAsk, "Always", 100)
local sbAll = MakeButton(sellAsk, "Sell all", 100)
local sbStack = MakeButton(sellAsk, "Sell stack", 100)
local sbCancel = MakeButton(sellAsk, "Cancel", 100)
sbAlways:SetPoint("BOTTOMLEFT", sellAsk, "BOTTOMLEFT", 28, 18)
sbAll:SetPoint("LEFT", sbAlways, "RIGHT", 8, 0)
sbStack:SetPoint("LEFT", sbAll, "RIGHT", 8, 0)
sbCancel:SetPoint("LEFT", sbStack, "RIGHT", 8, 0)
sbAlways:GetFontString():SetTextColor(1, 0.82, 0)
local function sellTip(b, title, body)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(body, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
sellTip(sbAlways, "Always sell this item", "Every one of it is sold at every vendor from now on, also the ones you get later.")
sellTip(sbAll, "Sell all you have now", "Every stack of it in your bags right now is sold at the next vendor. What you get after that stays.")
sellTip(sbStack, "Sell this stack", "Only the stack you were holding is sold at the next vendor. Your other stacks stay.")
sellTip(sbCancel, "Cancel", "Nothing is sold.")
local function sellDone(msg)
  local d = sellAsk.data
  sellAsk:Hide()
  if d and msg then Print((d.link or ns.NameOf(d.id)) .. msg) end
  if ns.Changed then ns.Changed() end
  C_Timer.After(0.3, function() Refresh() end)
end
sbAlways:SetScript("OnClick", function()
  local d = sellAsk.data
  if not d then return sellAsk:Hide() end
  Del.AddSell(d.id, d.link)
  sellDone(": every one is sold at every vendor from now on. (Undo it on the Clean-up page: /ruck)")
end)
sbAll:SetScript("OnClick", function()
  local d = sellAsk.data
  if not d then return sellAsk:Hide() end
  local stacks, items = Del.SellAllNow(d.id)
  sellDone((": all %d you have now (%d stack%s) go at the next vendor. What you get later stays."):format(items, stacks, stacks == 1 and "" or "s"))
end)
sbStack:SetScript("OnClick", function()
  local d = sellAsk.data
  if not d then return sellAsk:Hide() end
  -- (the stack must still be where it was)
  if d.bag and SlotInfo(d.bag, d.slot) == d.id and Del.SellStack(d.bag, d.slot, d.id) then
    sellDone(": this stack goes at the next vendor. Your other stacks stay.")
  else
    sellDone(": that stack isn't where it was any more, nothing marked.")
  end
end)
sbCancel:SetScript("OnClick", function() sellAsk:Hide() end)
sellAsk:SetScript("OnHide", function() sellAsk.data = nil end)
-- id, link, and the bag slot the stack came from (nil: "Sell stack" can't be picked)
function Del.AskSell(id, link, bag, slot)
  sellAsk.data = { id = id, link = link, bag = bag, slot = slot }
  sellIcon.tex:SetTexture(ns.GetIcon and ns.GetIcon(id) or nil)
  local have = ns.GetCount and ns.GetCount(id) or 0
  local _, stackCount = nil, nil
  if bag then _, stackCount = SlotInfo(bag, slot) end
  sellText:SetText("Sell " .. (link or ns.NameOf(id) or "this item") .. "?" ..
    (have > 0 and ("  |cff999999(you have " .. have .. (stackCount and stackCount < have and (", this stack is " .. stackCount) or "") .. ")|r") or ""))
  sbStack:SetText(stackCount and ("Sell " .. stackCount) or "Sell stack")
  sbStack:SetEnabled(bag ~= nil)
  sellAsk:Show()
end

btnAlways:SetScript("OnClick", function(self) Decide("always", self) end)
btnSell:SetScript("OnClick", function(self) Decide("sell", self) end)
btnYes:SetScript("OnClick", function(self) Decide("delete", self) end)
btnNo:SetScript("OnClick", function(self) Decide("no", self) end)

ask:SetScript("OnHide", function()
  if not ask.decided and ask.data and CursorItem() == ask.data.id then ClearCursor() end -- Esc = No
  HideGamePopup()
  ask.data, ask.which = nil, nil
end)
-- the item left the cursor some other way (put back in a bag): close quietly
ask:SetScript("OnUpdate", function(self)
  if self.data and CursorItem() ~= self.data.id then
    self.decided = true
    self:Hide()
  end
end)

---------------------------------------------------------------------------
-- (1.7.4) Over the delete limit: Delete it / Keep it / Not now
---------------------------------------------------------------------------
local over = CreateFrame("Frame", "RucksackOverLimit", UIParent, ns.BACKDROP_TMPL)
over:SetSize(420, 140)
over:SetPoint("TOP", UIParent, "TOP", 0, -135)
over:SetFrameStrata("FULLSCREEN_DIALOG")
over:SetToplevel(true)
over:EnableMouse(true)
over:SetBackdrop(ns.DIALOG_BACKDROP)
over:Hide()
tinsert(UISpecialFrames, "RucksackOverLimit")
local overIcon = CreateFrame("Button", nil, over)
overIcon:SetSize(36, 36)
overIcon:SetPoint("TOPLEFT", 24, -24)
overIcon.tex = overIcon:CreateTexture(nil, "ARTWORK")
overIcon.tex:SetAllPoints()
overIcon:SetScript("OnEnter", function(self) local b = Del.blocked if b then ns.ShowItemTooltip(self, b.id, b.link) end end)
overIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
local overText = over:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
overText:SetPoint("TOPLEFT", overIcon, "TOPRIGHT", 10, 0)
overText:SetPoint("RIGHT", over, "RIGHT", -22, 0)
overText:SetJustifyH("LEFT")
local overDel = MakeButton(over, "Delete it")
local overKeep = MakeButton(over, "Keep it")
local overLater = MakeButton(over, "Not now")
overKeep:SetPoint("BOTTOM", over, "BOTTOM", 0, 18)
overDel:SetPoint("RIGHT", overKeep, "LEFT", -10, 0)
overLater:SetPoint("LEFT", overKeep, "RIGHT", 10, 0)
overDel:GetFontString():SetTextColor(1, 0.35, 0.35)
overDel:SetScript("OnClick", function()
  local b = Del.blocked
  over:Hide()
  if b then Del.allowOnce = b.id DeleteOne(true) end
end)
overKeep:SetScript("OnClick", function()
  local b = Del.blocked
  over:Hide()
  if b then
    DB.keep[b.id] = true
    DB.items[b.id], DB.now[b.id] = nil, nil
    Print((b.link or ns.NameOf(b.id)) .. " will be kept. (Undo it on the Clean-up page: /ruck)")
    Del.blocked = nil
    Refresh()
  end
end)
overLater:SetScript("OnClick", function() over:Hide() end)
ShowBlocked = function()
  local b = Del.blocked
  if not b then return end
  overIcon.tex:SetTexture(ns.GetIcon(b.id))
  overText:SetText((b.link or ns.NameOf(b.id)) .. " is next to delete, but it's worth " .. ns.Sell.Money(b.value) ..
    ", more than your " .. ns.Sell.Money(DB.maxValue) .. " limit.\n\n|cff999999Not now: Clean-up waits until you free up a bag slot yourself.|r")
  over:Show()
  over:Raise()
end
Del.ShowBlocked = function() if ShowBlocked then ShowBlocked() end end

-- (17 Nov) the boxes beside the bag: is that where things are put on the lists now?
local function sideBoxes() return ns.Bags and ns.Bags.SideOn and ns.Bags.SideOn() and ns.Bags.DrawSide and true or false end
Del.SideBoxes = sideBoxes
local function ShowAsk(id, link, which, uses)
  local _, _, quality = ns.GetInfo(link or id)
  -- how many are in the stack on your cursor (its slot is locked while you hold it)
  local bag, slot = Del.HeldSlot(id)
  local count = bag and select(2, SlotInfo(bag, slot)) or nil
  local cantSell = Del.CantSell(id)
  ask.data = { id = id, link = link, quality = quality, count = count, cantSell = cantSell }
  ask.which = which
  ask.decided = false
  askIcon.tex:SetTexture(ns.GetIcon(id))
  askText:SetText("What do you want to do with " .. (link or ns.NameOf(id)) .. "?")
  local grey = quality == 0
  askHint:SetText(cantSell and "It stays in your bags for now and is thrown away when your bags are nearly full, the cheapest first. No vendor buys this." or
    grey and "|cff9d9d9dGrey: it's sold or thrown away by itself already.|r" or
    "It stays in your bags for now: sold at the next vendor, or thrown away when your bags are nearly full, the cheapest first.")
  askWarn:SetText("")
  local n = count and (" " .. count) or ""
  btnAlways:SetText("Always delete"); btnYes:SetText("Delete" .. n); btnSell:SetText("Sell" .. n); btnNo:SetText("Cancel")
  btnAlways:SetShown(not grey) btnYes:SetWidth(104)
  -- (15 Nov, later the same day) "only sell" is gone: Always delete / Delete N / Cancel. The Sell
  -- button stays in the code (old saves still have sell-only items) but is never shown.
  btnSell:Hide()
  btnNo:ClearAllPoints()
  btnNo:SetPoint("LEFT", btnYes, "RIGHT", 8, 0)
  btnYes:GetFontString():SetTextColor(1, 0.82, 0)
  ask:SetHeight(150)
  ask:SetWidth(480)
  if uses then
    -- (17 Nov 15:41) one simple question, he: "Just ask Delete Linen Cloth x14 / - its used for quest
    -- this and that / Delete Cancel ... no confirmation after". Delete deletes it right now (it's the
    -- click) and leaves your lists and windows as they are.
    ask.data.confirm = true
    askText:SetText("Delete " .. (link or ns.NameOf(id)) .. (count and count > 1 and (" x" .. count) or "") .. "?")
    askHint:SetText(#uses > 0 and ("|cffffffff- " .. table.concat(uses, "\n- ") .. "|r") or "")
    askWarn:SetText("")
    btnAlways:Hide()
    btnYes:SetText("Delete") btnYes:SetWidth(100)
    btnYes:GetFontString():SetTextColor(1, 0.35, 0.35)
    -- (17 Nov) "too wide": as wide as its text needs, the two buttons in the middle
    local textW = askText:GetStringWidth() or 200
    local hintW = 0
    for _, u in ipairs(uses) do
      askWarn:SetText("- " .. u) -- (measured on a spare line, then cleared)
      hintW = math.max(hintW, (askWarn:GetStringWidth() or 0) * 0.9)
    end
    askWarn:SetText("")
    ask:SetWidth(math.max(300, math.min(480, math.max(textW, hintW) + 160)))
    btnYes:ClearAllPoints()
    btnYes:SetPoint("BOTTOMRIGHT", ask, "BOTTOM", -4, 16)
    btnNo:ClearAllPoints()
    btnNo:SetPoint("LEFT", btnYes, "RIGHT", 8, 0)
    btnNo:SetWidth(100)
    ask:SetHeight(#uses > 0 and (108 + 14 * #uses) or 110)
  else
    btnYes:ClearAllPoints()
    btnYes:SetPoint("LEFT", btnAlways, "RIGHT", 8, 0)
    btnNo:SetWidth(96)
  end
  ask:Show()
  ask:Raise()
end
Del.TestShowAsk = ShowAsk -- (for the test scripts)

-- take over the game's delete confirmation popups
local DELETE_POPUPS = { DELETE_ITEM = true, DELETE_GOOD_ITEM = true, DELETE_QUEST_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
local function FindPopupFrame(which)
  local a, b = StaticPopup_Visible(which)
  if type(b) == "table" then return b end
  if type(a) == "table" then return a end
  if type(a) == "string" then return _G[a] end
end
hooksecurefunc("StaticPopup_Show", function(which)
  if not DB or not DB.enabled or not DELETE_POPUPS[which] then return end
  local id, link = CursorItem()
  if not id then return end
  -- (15 Nov) conjured water, food and the like: no box, it's deleted at once (you make it again
  -- for free). Dropping it is a click, and the game deletes inside a click. If the game refuses,
  -- the item is still on the cursor and the box asks as usual.
  if Del.IsConjured(id, link) then
    local bag, slot = Del.HeldSlot(id)
    local count = bag and select(2, SlotInfo(bag, slot)) or 1
    DeleteCursorItem()
    if CursorItem() ~= id then
      RecordMeta(id, link, count, true, "once")
      DB.deleted = (DB.deleted or 0) + count
      StaticPopup_Hide(which)
      if DB.chat then Print("deleted " .. (link or ns.NameOf(id)) .. (count > 1 and (" x" .. count) or "") .. " (conjured)") end
      C_Timer.After(0.3, function() Refresh() end)
      return
    end
  end
  -- (17 Nov) with the boxes beside the bag, those are where you choose "sell or delete later". An
  -- item dropped outside the bag is a real delete, your lists and windows stay as they are. He: "Always
  -- ask if you sure you want to delete it, and if it is a quest ask him that item is needed for a
  -- quest or darkmoon or anywhere that important to us and then again procede or cancel".
  local uses = sideBoxes() and ns.UsedFor(id, link) or nil
  -- the game's popup stays open (it owns the delete), invisible and out of the way
  local f = FindPopupFrame(which)
  if f then
    f:SetAlpha(0)
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "BOTTOM", 0, -2000)
    local eb = f.editBox or f.EditBox or (f.GetName and f:GetName() and _G[f:GetName() .. "EditBox"])
    if eb and eb.ClearFocus then eb:ClearFocus() end
    if not f.autoDeleteHooked then
      f.autoDeleteHooked = true
      f:HookScript("OnHide", function(self) self:SetAlpha(1) end)
    end
  end
  ShowAsk(id, link, which, uses)
end)

---------------------------------------------------------------------------
-- Trash button on screen: always there (unless turned off); lit when a stack is waiting
---------------------------------------------------------------------------
local pend = CreateFrame("Button", "RucksackDeleteButton", UIParent, ns.BACKDROP_TMPL)
-- (1.7.4) wider: the next item's icon on the left; free slots / your setting, its name, its price
pend:SetSize(184, 48)
pend:SetFrameStrata("MEDIUM")
pend:SetMovable(true)
pend:SetClampedToScreen(true)
pend:RegisterForClicks("LeftButtonUp", "RightButtonUp")
pend:RegisterForDrag("LeftButton")
pend:SetBackdrop(ns.SLOT_BACKDROP)
pend:SetBackdropColor(0.04, 0.04, 0.04, 0.92)
pend:SetBackdropBorderColor(0.4, 0.4, 0.4)
pend:Hide()
pend.frame = pend:CreateTexture(nil, "BORDER")
pend.frame:SetSize(38, 38)
pend.frame:SetPoint("LEFT", 5, 0)
pend.frame:SetColorTexture(0, 0, 0, 1)
pend.icon = pend:CreateTexture(nil, "ARTWORK")
pend.icon:SetPoint("TOPLEFT", pend.frame, 1, -1)
pend.icon:SetPoint("BOTTOMRIGHT", pend.frame, -1, 1)
pend.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
pend.trash = pend:CreateTexture(nil, "OVERLAY")
pend.trash:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
pend.trash:SetSize(16, 16)
pend.trash:SetPoint("TOPRIGHT", pend.frame, "TOPRIGHT", 5, 5)
pend.count = pend:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
pend.count:SetPoint("BOTTOMRIGHT", pend.frame, "BOTTOMRIGHT", -1, 1)
pend.bang = pend:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pend.bang:SetPoint("CENTER", pend, "TOPLEFT", 2, -2)
pend.bang:SetText("|cffff3b30!|r")
pend.l1 = pend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pend.l1:SetPoint("TOPLEFT", pend.frame, "TOPRIGHT", 8, 0)
pend.l1:SetPoint("RIGHT", -8, 0)
pend.l1:SetJustifyH("LEFT")
pend.l2 = pend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pend.l2:SetPoint("LEFT", pend.frame, "RIGHT", 8, 0)
pend.l2:SetPoint("RIGHT", -8, 0)
pend.l2:SetJustifyH("LEFT")
pend.l2:SetWordWrap(false)
pend.l3 = pend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pend.l3:SetPoint("BOTTOMLEFT", pend.frame, "BOTTOMRIGHT", 8, 0)
pend.l3:SetPoint("RIGHT", -8, 0)
pend.l3:SetJustifyH("LEFT")
pend.label = pend.l3 -- (older name)

pend:SetScript("OnClick", function(self, button)
  if button == "RightButton" then Rucksack_Open("del") return end
  Del.Click()
end)
pend:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
pend:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  DB.pendPos = { p, rp, x, y }
end)
pend:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cffff5555Clean-up|r")
  local free, keep = FreeSlots(), DB.minFree or 2
  local it = ScanBags(false)
  Del.TipList()
  if it then
    if Del.blocked then
      GameTooltip:AddLine("Over your delete limit (" .. ns.Sell.Money(DB.maxValue) .. "): Clean-up waits. Click to choose.", 1, 0.82, 0, true)
    elseif not self.waiting then
      -- (said by the list already)
    elseif InCombatLockdown() then
      GameTooltip:AddLine("In combat: deletes after combat.", 1, 0.5, 0.5)
    elseif DB.onKey then
      GameTooltip:AddLine("Deletes on your next key press, or click here.", 0.6, 1, 0.6, true)
    else
      GameTooltip:AddLine("Click to delete it.", 0.6, 1, 0.6)
    end
  end
  GameTooltip:AddLine(it and "Click (or the RuckDelete macro): throw the first one away now. Right-click: the Clean-up page. Shift-drag to move." or "Click: the Clean-up page. Shift-drag to move.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end)
pend:SetScript("OnLeave", function() GameTooltip:Hide() end)

Refresh = function()
  if not DB then return end
  local it, total = ScanBags(true)
  -- (1.7.4) the wait over the limit ends when you free a bag slot, or that item is no longer next
  local b = Del.blocked
  if b and (FreeSlots() > b.free or not it or it.id ~= b.id or not DB.maxValue) then Del.blocked, b = nil, nil end
  pend.waiting = (DB.enabled and it) and true or nil
  -- what would go next (when the bags fill), for the button's lines
  local nx, all, _, value = ScanBags(false)
  local free, keep = FreeSlots(), DB.minFree or 2
  local col = free < keep and "|cffff5a50" or free == keep and "|cffffd100" or "|cff5cd65c"
  pend.l1:SetText(col .. free .. "|r|cff8a8a8a / " .. keep .. " free|r")
  if nx then
    local n = nx.deleteCount or nx.count or 1
    pend.icon:SetTexture(nx.icon or ns.GetIcon(nx.id))
    pend.icon:SetDesaturated(false)
    pend.icon:SetAlpha(1)
    pend.count:SetText((all or 0) > 1 and all or "")
    local q = ns.QualityOf(nx.id, nx.link)
    local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    pend.l2:SetText(((qc and qc.hex) or "|cffffffff") .. ns.NameOf(nx.id, nx.link) .. "|r" .. (n > 1 and (" |cff8a8a8ax" .. n .. "|r") or ""))
    if b then pend.l3:SetText("|cffffd100over " .. ns.Sell.Money(DB.maxValue) .. " limit|r")
    elseif InCombatLockdown() and pend.waiting then pend.l3:SetText("|cffff8080after combat|r")
    else pend.l3:SetText(ns.Sell.Money(value or 0)) end
  else
    pend.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Red")
    pend.icon:SetDesaturated(true)
    pend.icon:SetAlpha(0.7)
    pend.count:SetText("")
    pend.l2:SetText("|cff888888Nothing to delete|r")
    pend.l3:SetText("")
  end
  -- the border: red when deleting is due, gold over the limit, plain otherwise
  if b then pend:SetBackdropBorderColor(1, 0.82, 0)
  elseif pend.waiting then pend:SetBackdropBorderColor(0.9, 0.27, 0.27)
  else pend:SetBackdropBorderColor(0.4, 0.4, 0.4) end
  pend.bang:SetShown(pend.waiting and not b and true or false)
  pend.trash:SetShown(nx ~= nil)
  pend:SetAlpha(InCombatLockdown() and 0.7 or 1)
  pend:SetShown((pend.waiting or DB.alwaysIcon) and DB.enabled and true or false)
  if DB.hideIcon then pend:Hide() end -- (1.7.3: "Show button" unticked)
  if Del.UpdateMacro then Del.UpdateMacro(nx) end
  if not InCombatLockdown() then
    EnsurePropagate()
    keyCatcher:EnableKeyboard((DB.enabled and DB.onKey and it and not b and propagateOK) and true or false)
  end
  ns.Changed()
end
Del.Refresh = function() Refresh() end

table.insert(ns.onLoad, function()
  DB = ns.del
  DB.items = DB.items or {}
  DB.now = DB.now or {}
  DB.keep = DB.keep or {}
  DB.sell = DB.sell or {} -- (1.8.2) sold at a vendor, never thrown away
  DB.once = nil -- (1.8 test builds had "junk once"; gone again)
  DB.meta = DB.meta or {}
  for id, v in pairs(DB.items) do
    RecordMeta(id, type(v) == "string" and v or nil, 0, false)
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
  DB.enabled = true -- (1.7.4: the Pocket's on/off switch is gone; Clean-up is on whenever its module is loaded)
  if DB.onKey == nil then DB.onKey = true end
  if DB.chat == nil then DB.chat = true end
  if DB.minFree == nil then DB.minFree = 2 end
  -- (10 Nov) grey items (trash) go automatically: the quality rule starts at "Trash". Switched on
  -- once for saves from before; a higher setting (Common, Uncommon) already includes trash.
  -- (10 Nov) the delete history starts with what was deleted before (one line per item, its last time)
  if not DB.history then
    DB.history = {}
    for id, m in pairs(DB.meta) do
      if m.lastDeleted then DB.history[#DB.history + 1] = { id = id, link = m.link, t = m.lastDeleted, how = m.lastHow } end
    end
    table.sort(DB.history, function(a, b) return a.t > b.t end)
    while #DB.history > 100 do table.remove(DB.history) end
  end
  -- (1.7.4) the old quality choice is gone (the junk pool rules replace it); a delete limit of 1g
  DB.upTo = nil
  -- (1.7.4) profession tools come off the list (once)
  if not DB.toolsFreed then
    for id in pairs(DB.items) do
      if Del.IsTool(id) then
        DB.items[id], DB.now[id] = nil, nil
        Print((ns.LinkOf(id) or ns.NameOf(id)) .. " is a profession tool: taken off your delete list.")
      end
    end
    DB.toolsFreed = true
  end
  if not DB.limitSet then DB.maxValue = 10000 DB.limitSet = true end
  -- (1.8.2) the limit is a slider now: 10s to 5g in 10s steps (a 10g limit becomes 5g)
  if DB.maxValue then
    if DB.maxValue > 50000 then
      DB.maxValue = 50000
      C_Timer.After(5, function() Print("your delete limit was 10g; the most is 5g now, so it's 5g. (Clean-up page)") end)
    end
    DB.maxValue = math.max(1000, math.floor(DB.maxValue / 1000 + 0.5) * 1000)
    DB.lastLimit = DB.maxValue
  end
  -- (9 Nov) the always-on bag icon is gone (the minimap button opens Rucksack now); the trash
  -- button still shows when something is waiting to be deleted
  if not DB.iconRemoved then DB.alwaysIcon = false DB.iconRemoved = true end
  pend:ClearAllPoints()
  if DB.pendPos then
    local p, rp, x, y = unpack(DB.pendPos)
    pend:SetPoint(p, UIParent, rp, x, y)
  else
    pend:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
  end
end)
table.insert(ns.onLogin, function() Refresh() end)

-- (10 Nov) the RuckDelete macro (shared by all characters): one click on your bars deletes the
-- next waiting item. Made once; if you delete it, it stays deleted.
table.insert(ns.onLogin, function()
  if DB.madeDeleteMacro or InCombatLockdown() or not (GetNumMacros and CreateMacro and GetMacroInfo) then return end
  local nAcc = GetNumMacros() or 0
  for i = 1, nAcc do if GetMacroInfo(i) == "RuckDelete" then DB.madeDeleteMacro = true return end end
  if nAcc < (MAX_ACCOUNT_MACROS or 120) and pcall(CreateMacro, "RuckDelete", "INV_Misc_Bag_10_Red", "/run AutoDelete_DeleteNext()", false) then
    DB.madeDeleteMacro = true
    Print("made the macro |cffffd100RuckDelete|r (/macro, General tab): put it on your bars, one click deletes the next waiting item.")
  end
end)

-- (1.7.4) the macro follows the button: it shows the first item to go (icon and tooltip)
local lastMacro
function Del.UpdateMacro(nx)
  if InCombatLockdown() or not (GetNumMacros and EditMacro and GetMacroInfo) then return end
  local body = (nx and ("#showtooltip item:" .. nx.id .. "\n") or "") .. "/run AutoDelete_DeleteNext()"
  local icon = nx and 134400 or "INV_Misc_Bag_10_Red" -- (the question mark: the game shows the item's icon)
  if body == lastMacro then return end
  local nAcc = GetNumMacros() or 0
  for i = 1, nAcc do
    if GetMacroInfo(i) == "RuckDelete" then pcall(EditMacro, i, "RuckDelete", icon, body) lastMacro = body return end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, e) if e == "QUEST_LOG_UPDATE" then reqAt = -1 end Refresh() end)

-- (1.7.4) no command of its own: /ruck opens Rucksack, Clean-up is in the sidebar
