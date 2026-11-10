-- Rucksack / Clean-up: selling at a vendor (10 Nov)
-- When you open a vendor: grey items (if set), and the items Clean-up would delete (if set to
-- "sell instead of deleting") are sold for gold. Never: amounts your quests still need, items you
-- set to Keep, items with no vendor price, blue and better unless you put them on your list.
-- A few at a time (the game drops sales sent too fast); only whole stacks (a stack partly needed
-- for a quest waits for Clean-up).
local _, ns = ...
local Print = ns.Print
local Sell = {}
ns.Sell = Sell
local DB

local function useItem(bag, slot)
  local C = C_Container
  if C and C.UseContainerItem then return C.UseContainerItem(bag, slot) end
  if UseContainerItem then return UseContainerItem(bag, slot) end
end

-- what would be sold at a vendor right now: a list of { bag, slot, id, count, price, link },
-- and its value in copper
function Sell.Items()
  local out, value = {}, 0
  if not DB or not DB.enabled or not (DB.sellGrey or DB.sellList) then return out, 0 end
  local byID, order = {}, {}
  for bag = 0, ns.NUM_BAGS do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, count, link, _, locked = ns.SlotInfo(bag, slot)
      if id and not DB.keep[id] then
        local _, _, quality, _, _, _, _, _, _, _, price = ns.GetInfo(link or id)
        price = price or 0
        if price > 0 then
          local grey = DB.sellGrey and quality == 0
          local listed = DB.sellList and ns.Del.OnList(id) and (DB.items[id] or (quality or 0) < 3)
          if grey or listed then
            local g = byID[id]
            if not g then
              g = { id = id, price = price, total = 0, slots = {}, need = ns.Del.QuestNeed(id, link) }
              byID[id] = g
              order[#order + 1] = g
            end
            g.total = g.total + count
            if not locked then g.slots[#g.slots + 1] = { bag = bag, slot = slot, id = id, count = count, price = price, link = link } end
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
  -- (10 Nov) selling your Clean-up items is the default: they'd be deleted anyway, a vendor pays
  -- for them, and a sale can be bought back. Switched on once for saves from before this change.
  if not DB.sellListDefault then DB.sellList, DB.sellListDefault = true, true end
end)
