-- Rucksack / Clean-up: selling at a vendor (10 Nov)
-- When you open a vendor: grey items (if set), and the items Clean-up would delete (if set to
-- "sell instead of deleting") are sold for gold. Never: amounts your quests still need, items you
-- set to Keep, items with no vendor price, blue and better unless you put them on your list.
-- A few at a time (the game drops sales sent too fast); only whole stacks (a stack partly needed
-- for a quest waits for Clean-up).
local ns = Rucksack
if not ns then return end
local Print = ns.Print
local Sell = {}
ns.Sell = Sell
local DB
local atVendorNow -- (below)
-- (17 Nov, 1.9) selling has no limit any more: the slider in the bag is the delete limit now (he:
-- "if the item is there and worth 1 gold we would not want to delete it but only sell"). DB.sellMax
-- from 1.8.6 is left unused in old saves.
function Sell.OverLimit() return false end

local function useItem(bag, slot)
  local C = C_Container
  if C and C.UseContainerItem then return C.UseContainerItem(bag, slot) end
  if UseContainerItem then return UseContainerItem(bag, slot) end
end
-- (16 Nov) the other way to sell: pick the stack up and hand it to the vendor
local function sellByCursor(bag, slot)
  if not SellCursorItem then return false end
  local C = C_Container
  if C and C.PickupContainerItem then C.PickupContainerItem(bag, slot) elseif PickupContainerItem then PickupContainerItem(bag, slot) end
  if not CursorHasItem() then return false end
  SellCursorItem()
  return true -- (whether it went is checked a second later)
end
-- (16 Nov) items a vendor wouldn't take this session (he: "that one refuses to sell, all other
-- sold"): what the game said. Not tried again until you log in again.
Sell.refused = {}
Sell.forced = {} -- (19 Nov) "bag:slot" the vendor button asked to sell, even with Once's sell tick off (till the vendor closes)

---------------------------------------------------------------------------
-- (10 Nov) Soulbound gear this character can't use: sold at a vendor, never deleted.
-- Weapons, shields and relics go by what the class can ever use in WoW Forever (the weapon
-- trainers' list: a skill not trained yet still counts as usable). Armor types are picked by hand,
-- per character (Cloth / Leather / Mail / Plate). Cloaks, shirts, rings and the like are never sold.
-- Epic and better: never. Bind on equip that isn't bound yet: kept (the Auction House).
---------------------------------------------------------------------------
-- weapon subclasses (Enum.ItemWeaponSubclass): 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace,
-- 5 2H mace, 6 polearm, 7 1H sword, 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown,
-- 18 crossbow, 19 wand
local WEAPONS = {
  WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 },
  PALADIN = { 0, 4, 7, 5, 8, 6 },
  HUNTER  = { 2, 18, 3, 16, 15, 13, 6, 10, 0, 7, 1, 8 },
  ROGUE   = { 2, 18, 3, 16, 15, 13, 0, 4, 7 },
  DRUID   = { 15, 13, 6, 10, 4, 5 },
  SHAMAN  = { 15, 13, 10, 0, 4, 1, 5 },
  PRIEST  = { 15, 10, 4, 19 },
  MAGE    = { 15, 10, 7, 19 },
  WARLOCK = { 15, 10, 7, 19 },
}
-- anyone can use these (or they don't exist here): never sold as "can't use"
local ANY_WEAPON = { [9] = true, [11] = true, [12] = true, [14] = true, [17] = true, [20] = true }
local SHIELD_CLASSES = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local RELIC_FOR = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" } -- libram, idol, totem
local ARMOR = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate" }
Sell.ARMOR = ARMOR
local usable -- this class's weapons, as a set
local function myClass() return select(2, UnitClass("player")) end

-- why this kind of item is of no use to this character (by its type alone), or nil
function Sell.CantUseType(id)
  local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  if not info then return nil end
  local _, _, subName, equipLoc, _, classID, sub = info(id)
  local class = myClass()
  if classID == 2 then
    if ANY_WEAPON[sub] or not WEAPONS[class] then return nil end
    if not usable then
      usable = {}
      for _, v in ipairs(WEAPONS[class]) do usable[v] = true end
    end
    if not usable[sub] then return "can't use: " .. (subName ~= "" and subName or "this weapon") end
  elseif classID == 4 then
    if equipLoc == "INVTYPE_CLOAK" then return nil end
    if ARMOR[sub] then
      local pick = ns.char and ns.char.sellArmor
      if pick and pick[sub] then return "sell armor: " .. ARMOR[sub] end
    elseif sub == 6 then
      if not SHIELD_CLASSES[class] then return "can't use: Shield" end
    elseif RELIC_FOR[sub] and RELIC_FOR[sub] ~= class then
      return "can't use: " .. (subName ~= "" and subName or "relic")
    end
  end
  return nil
end

local function soulbound(bag, slot)
  if C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
    local ok, bound = pcall(C_Item.IsBound, ItemLocation:CreateFromBagAndSlot(bag, slot))
    if ok and bound ~= nil then return bound end
  end
  if C_TooltipInfo and C_TooltipInfo.GetBagItem then
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if ok and data and data.lines then
      for _, l in ipairs(data.lines) do
        if l.leftText == (ITEM_SOULBOUND or "Soulbound") then return true end
      end
    end
  end
  return false
end

Sell.Soulbound = soulbound
-- sold as gear this character can't use: the reason, or nil
function Sell.CantUse(bag, slot, id, quality)
  if not DB or not DB.sellGear then return nil end
  if not quality or quality < 1 then return nil end -- (grey goes anyway; 1.7.4: any quality, if bound)
  local why = Sell.CantUseType(id)
  if why and soulbound(bag, slot) then return why end
  return nil
end

-- what would be sold at a vendor right now: a list of { bag, slot, id, count, price, link, why },
-- and its value in copper
function Sell.Items()
  local out, value = {}, 0
  if not DB or not DB.enabled or not (DB.sellGrey or DB.sellList or DB.sellGear) then return out, 0 end
  local byID, order = {}, {}
  for bag = 0, ns.LAST_BAG do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, count, link, _, locked = ns.SlotInfo(bag, slot)
      local marked = ns.Del.SlotSell and ns.Del.SlotSell(bag, slot, id) -- (15 Nov: this very stack is marked for sale)
      -- (15 Nov) a stack marked by hand (Sell N or Delete N) goes even when the item is set to Keep:
      -- the mark is newer and only for this stack (he kept Healing Potions and marked 3 of them)
      local byHand = marked or (ns.Del.SlotJunk and ns.Del.SlotJunk(bag, slot, id))
      local toBank = id and ns.Bags and ns.Bags.BankSlot and ns.Bags.BankSlot(bag, slot, id) -- (15 Nov: on its way to the bank)
      -- (19 Nov) "Always [ ] sell" unticked: only the stacks marked once are sold
      -- (19 Nov) "Once [ ] sell" unticked: the once-marked stacks stay, unless the vendor button asked for them
      local onceOff = byHand and DB.onceSell == false and not Sell.forced[bag .. ":" .. slot]
      if id and not toBank and not Sell.refused[id] and not onceOff and (byHand or not DB.keep[id]) and not ns.KeepItem(id) and (byHand or DB.alwaysSell ~= false) then
        local _, _, quality, _, _, _, _, _, _, _, price = ns.GetInfo(link or id)
        price = price or 0
        if price > 0 then
          local grey = DB.sellGrey and quality == 0
          local listed = DB.sellList and ns.Del.OnList(id, bag, slot) and (DB.items[id] or (quality or 0) < 3 or ns.Del.ByRule(id, bag, slot) or (ns.Del.SlotJunk and ns.Del.SlotJunk(bag, slot, id)))
          -- (1.8.2) Sell: always sold here (never thrown away)
          if not listed and ((DB.sell and DB.sell[id]) or marked) and not ns.KeepItem(id) then listed = true end
          local gear = not grey and not listed and Sell.CantUse(bag, slot, id, quality)
          if grey or listed or gear then
            local g = byID[id]
            if not g then
              g = { id = id, price = price, total = 0, slots = {}, need = ns.Del.QuestNeed(id, link) }
              byID[id] = g
              order[#order + 1] = g
            end
            g.total = g.total + count
            if not locked then g.slots[#g.slots + 1] = { bag = bag, slot = slot, id = id, count = count, price = price, link = link, why = gear or nil } end
          end
        end
      end
    end
  end
  for _, g in ipairs(order) do
    local spare = g.total - (g.need or 0)
    if spare > 0 then
      table.sort(g.slots, function(a, b) return a.count < b.count end)
      for _, s in ipairs(g.slots) do
        if s.count <= spare then
          out[#out + 1] = s
          value = value + s.price * s.count
          spare = spare - s.count
        end
      end
    end
  end
  return out, value
end

-- (15 Nov) why a vendor won't buy this item (or this stack, with bag and slot) from you right
-- now, in words (nil: it's sold). The same checks as Sell.Items, in the same order.
function Sell.WhyNot(id, link, bag, slot)
  if not DB or not id then return nil end
  if not DB.enabled then return "Clean-up is switched off." end
  if Sell.refused[id] then
    local msg = Sell.refused[id]
    return "the vendor wouldn't take it when Rucksack tried" .. (type(msg) == "string" and msg ~= "" and (" (the game said: " .. msg .. ")") or "") .. ". It's tried again after you log in again."
  end
  if bag and ns.Bags and ns.Bags.BankSlot and ns.Bags.BankSlot(bag, slot, id) then return "it's on its way to your bank." end
  local byHand = bag and ((ns.Del.SlotSell and ns.Del.SlotSell(bag, slot, id)) or (ns.Del.SlotJunk and ns.Del.SlotJunk(bag, slot, id)))
  if DB.keep[id] and not byHand then return "it's set to Keep on the Clean-up page." end
  if ns.KeepItem(id) then
    if ns.Bags and ns.Bags.Sets and ns.Bags.Sets.Locked() and ns.Bags.Sets.Of(id) then return "it's in one of your equipment sets." end
    local uses = ns.UsedFor and ns.UsedFor(id, link) or {}
    return "it's always kept" .. (uses[1] and (" (" .. uses[1] .. ")") or "") .. "."
  end
  if DB.alwaysSell == false and not byHand then return "selling is switched off for Always (the \"sell\" tick next to its name)." end
  if DB.onceSell == false and byHand then return "selling is switched off for Once (the \"sell\" tick next to its name)." end
  local name, _, _, _, _, _, _, _, _, _, price = ns.GetInfo(link or id)
  if not name then return "the game hasn't sent this item's details yet. Close the vendor and open it again." end
  price = price or 0
  if price <= 0 then return "no vendor buys it." end
  if not DB.sellList and not (DB.sell and DB.sell[id]) then return "selling your list is switched off on the Clean-up page." end
  local need = ns.Del.QuestNeed and ns.Del.QuestNeed(id, link) or 0
  if need > 0 then
    local nm = ns.NameOf(id, link)
    local titles = nm and ns.Del.questTitles and ns.Del.questTitles[nm:lower()]
    local q = titles and titles[1] and (" (\"" .. titles[1] .. "\")") or ""
    if need == math.huge then return "it starts a quest, so it's kept." end
    return "a quest you have" .. q .. " needs " .. need .. ". Only what's over that is sold."
  end
  if bag then
    local it = C_Container.GetContainerItemInfo(bag, slot)
    if it and it.isLocked then return "the stack is locked right now (picked up or being moved)." end
  end
  return nil
end

-- (16 Nov) at a vendor: everything in "Always sell / delete" or "Sell / delete once" that wasn't
-- sold says why in chat, once per item and visit (at most 6 lines)
local told
function Sell.Report()
  if not DB or not DB.enabled or not atVendorNow() then return end
  told = told or {}
  local selling = {}
  for _, s in ipairs((Sell.Items())) do selling[s.bag .. ":" .. s.slot] = true end
  local lines = 0
  for bag = 0, ns.LAST_BAG do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, count, link = ns.SlotInfo(bag, slot)
      if id and not told[id] and not selling[bag .. ":" .. slot] then
        local ok, kind = pcall(ns.Del.JunkKind, id, bag, slot)
        if ok and kind and lines < 6 then
          told[id] = true
          lines = lines + 1
          local why = Sell.WhyNot(id, link, bag, slot)
          Print("not sold: " .. (link or ns.NameOf(id) or "?") .. ((count or 1) > 1 and (" x" .. count) or "") .. ": " ..
            (why or "Rucksack can't tell why. Please send the author a screenshot of this line."))
        end
      end
    end
  end
end

-- money as "1g 23s 40c" in the game's coin colours
function Sell.Money(copper)
  copper = math.floor(copper or 0)
  if GetCoinTextureString then return GetCoinTextureString(copper) end
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local out = {}
  if g > 0 then out[#out + 1] = "|cffffd700" .. g .. "g|r" end
  if s > 0 or g > 0 then out[#out + 1] = "|cffc7c7cf" .. s .. "s|r" end
  out[#out + 1] = "|cffeda55f" .. c .. "c|r"
  return table.concat(out, " ")
end

-- selling, a few at a time while the vendor is open
local queue, atVendor, soldNow, soldValue = nil, false, 0, 0
local tried, lastError -- (16 Nov: what this run tried to sell; the game's last red error text)
atVendorNow = function() return atVendor end
local ticker = CreateFrame("Frame")
ticker:Hide()
local acc = 0
ticker:SetScript("OnUpdate", function(self, el)
  acc = acc + el
  if acc < 0.2 then return end
  acc = 0
  if not atVendor or not queue or #queue == 0 then
    self:Hide()
    queue = nil
    -- (16 Nov) a moment later: did every stack really go? Only those count as sold.
    local list = tried
    tried = nil
    if list then C_Timer.After(1, function() Sell.Check(list) end)
    elseif atVendor then C_Timer.After(0.5, Sell.Report) end
    return
  end
  local s = table.remove(queue, 1)
  local id, count = ns.SlotInfo(s.bag, s.slot)
  -- (only if that slot still holds the same item, the same amount)
  if id == s.id and count == s.count and not CursorHasItem() then
    useItem(s.bag, s.slot)
    tried = tried or {}
    tried[#tried + 1] = s
  end
end)
-- (16 Nov) after a run: what's gone was sold; a stack still there gets one more try the other way,
-- and if it's still there after that, the vendor won't take it: chat says what the game said
function Sell.Check(list, second)
  if not DB then return end
  if second and CursorHasItem() then ClearCursor() end -- (a stack the vendor didn't take goes back)
  local again = {}
  for _, s in ipairs(list or {}) do
    local id, count = ns.SlotInfo(s.bag, s.slot)
    if id == s.id and count == s.count then
      if not second and atVendor and not CursorHasItem() and sellByCursor(s.bag, s.slot) then
        again[#again + 1] = s
      else
        Sell.refused[s.id] = lastError or true
        told = told or {}
        told[s.id] = true -- (said here: not again in the list after it)
        if atVendor or second then
          Print("the vendor wouldn't take " .. (s.link or ns.NameOf(s.id) or "?") .. (s.count > 1 and (" x" .. s.count) or "") ..
            (lastError and (": the game said \"" .. lastError .. "\"") or "") .. ". Rucksack won't try it again until you log in again.")
        end
      end
    else
      soldNow = soldNow + s.count
      soldValue = soldValue + s.price * s.count
      if ns.Del.RecordMeta then ns.Del.RecordMeta(s.id, s.link, 0, false) end
    end
  end
  if #again > 0 then return C_Timer.After(1, function() Sell.Check(again, true) end) end
  if soldNow > 0 then
    DB.soldGold = (DB.soldGold or 0) + soldValue
    DB.soldCount = (DB.soldCount or 0) + soldNow
    Print(("sold %d item%s for %s."):format(soldNow, soldNow == 1 and "" or "s", Sell.Money(soldValue)))
  end
  soldNow, soldValue, lastError = 0, 0, nil
  ns.Changed()
  if atVendor then C_Timer.After(0.5, Sell.Report) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
pcall(ev.RegisterEvent, ev, "UI_ERROR_MESSAGE")
ev:SetScript("OnEvent", function(_, e, a1, a2)
  if not DB then return end
  if e == "UI_ERROR_MESSAGE" then
    if atVendor then lastError = type(a2) == "string" and a2 or (type(a1) == "string" and a1) or lastError end
    return
  end
  if e == "MERCHANT_CLOSED" then atVendor = false wipe(Sell.forced) return end
  if e ~= "MERCHANT_SHOW" then return end
  atVendor = true
  told = nil -- (a new visit: say again what isn't sold)
  if IsShiftKeyDown() then return end -- (Shift while opening the vendor: sell nothing this time)
  local items = Sell.Items()
  if #items == 0 then C_Timer.After(0.5, Sell.Report) return end
  queue, soldNow, soldValue, acc, tried, lastError = items, 0, 0, 0, nil, nil
  ticker:Show()
end)
function Sell.AtVendor() return atVendor end
-- (15 Nov) something was just marked while the vendor is open: sell it now, don't wait for the
-- next visit. (A moment later: the stack you held is still locked right after the click.)
function Sell.Kick()
  if not DB or not atVendor then return false end
  C_Timer.After(0.3, function()
    if not atVendor or (queue and #queue > 0) then return end
    local items = Sell.Items()
    if #items == 0 then return end
    queue, soldNow, soldValue, acc, tried, lastError = items, 0, 0, 0, nil, nil
    ticker:Show()
  end)
  return true
end

table.insert(ns.onLoad, function()
  DB = ns.del
  if DB.sellGrey == nil then DB.sellGrey = false end
  if DB.sellGear == nil then DB.sellGear = true end -- (10 Nov) gear this character can't use
  if ns.char then
    ns.char.sellArmor = ns.char.sellArmor or {}
    -- (1.7.4) once per character: the armour types its class can never wear count as "can't use"
    -- (only when nothing was picked by hand yet)
    if not ns.char.sellArmorDefault then
      if not next(ns.char.sellArmor) then
        local NEVER = { MAGE = { 2, 3, 4 }, PRIEST = { 2, 3, 4 }, WARLOCK = { 2, 3, 4 }, ROGUE = { 3, 4 }, DRUID = { 3, 4 }, HUNTER = { 4 }, SHAMAN = { 4 } }
        for _, t in ipairs(NEVER[myClass()] or {}) do ns.char.sellArmor[t] = true end
      end
      ns.char.sellArmorDefault = true
    end
  end
  -- (10 Nov) selling your Clean-up items is the default: they'd be deleted anyway, a vendor pays
  -- for them, and a sale can be bought back. Switched on once for saves from before this change.
  if not DB.sellListDefault then DB.sellList, DB.sellListDefault = true, true end
end)
