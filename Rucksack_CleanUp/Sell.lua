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

local function useItem(bag, slot)
  local C = C_Container
  if C and C.UseContainerItem then return C.UseContainerItem(bag, slot) end
  if UseContainerItem then return UseContainerItem(bag, slot) end
end

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

-- sold as gear this character can't use: the reason, or nil
function Sell.CantUse(bag, slot, id, quality)
  if not DB or not DB.sellGear then return nil end
  if not quality or quality < 1 or quality > 3 then return nil end -- (grey goes anyway; epic never)
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
  for bag = 0, ns.NUM_BAGS do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, count, link, _, locked = ns.SlotInfo(bag, slot)
      if id and not DB.keep[id] and not ns.KeepItem(id) then
        local _, _, quality, _, _, _, _, _, _, _, price = ns.GetInfo(link or id)
        price = price or 0
        if price > 0 then
          local grey = DB.sellGrey and quality == 0
          local listed = DB.sellList and ns.Del.OnList(id) and (DB.items[id] or (quality or 0) < 3)
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
local ticker = CreateFrame("Frame")
ticker:Hide()
local acc = 0
ticker:SetScript("OnUpdate", function(self, el)
  acc = acc + el
  if acc < 0.2 then return end
  acc = 0
  if not atVendor or not queue or #queue == 0 then
    self:Hide()
    if soldNow > 0 then
      DB.soldGold = (DB.soldGold or 0) + soldValue
      DB.soldCount = (DB.soldCount or 0) + soldNow
      Print(("sold %d item%s for %s."):format(soldNow, soldNow == 1 and "" or "s", Sell.Money(soldValue)))
    end
    soldNow, soldValue, queue = 0, 0, nil
    ns.Changed()
    return
  end
  local s = table.remove(queue, 1)
  local id, count = ns.SlotInfo(s.bag, s.slot)
  -- (only if that slot still holds the same item, the same amount)
  if id == s.id and count == s.count and not CursorHasItem() then
    useItem(s.bag, s.slot)
    soldNow = soldNow + s.count
    soldValue = soldValue + s.price * s.count
    if ns.Del.RecordMeta then ns.Del.RecordMeta(s.id, s.link, 0, false) end
  end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:SetScript("OnEvent", function(_, e)
  if not DB then return end
  if e == "MERCHANT_CLOSED" then atVendor = false return end
  atVendor = true
  if IsShiftKeyDown() then return end -- (Shift while opening the vendor: sell nothing this time)
  local items = Sell.Items()
  if #items == 0 then return end
  queue, soldNow, soldValue, acc = items, 0, 0, 0
  ticker:Show()
end)
function Sell.AtVendor() return atVendor end

table.insert(ns.onLoad, function()
  DB = ns.del
  if DB.sellGrey == nil then DB.sellGrey = false end
  if DB.sellGear == nil then DB.sellGear = true end -- (10 Nov) gear this character can't use
  if ns.char then ns.char.sellArmor = ns.char.sellArmor or {} end
  -- (10 Nov) selling your Clean-up items is the default: they'd be deleted anyway, a vendor pays
  -- for them, and a sale can be bought back. Switched on once for saves from before this change.
  if not DB.sellListDefault then DB.sellList, DB.sellListDefault = true, true end
end)
