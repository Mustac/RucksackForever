-- Rucksack / Bags (1.8): one bag window instead of the game's separate bags.
--  * Groups (Weapons, Armour, Food and water, Potions, Trade goods, Quest, Everything else, Junk,
--    and groups you make yourself), each on its own row ("Rows"), or side by side ("Packed"), or
--    "One grid" (everything in one grid, a coloured dot per group, chips to filter).
--  * Stacks merged (80 ore as one icon) or separate (the real stacks).
--  * Pick an item up and every group gets a slot at its end (a green +; a red one on Junk): drop it
--    there and that item goes in that group from now on, all its stacks (on Junk: it's junk).
--    Drop it on its own group's slot again and it goes back where Rucksack puts it by itself.
--  * Drag a group by its name: it lifts, the others slide out of the way, it settles where you let go.
--  * Next to the reagent bag: make a group, delete one of yours, and the padlock (locks the layout).
--  * Your other characters' bags and your banks: remembered, shown faded; item tooltips say where
--    else you have an item.
-- The item buttons are the game's own (ContainerFrameItemButtonTemplate, a parent frame carries
-- the bag number), so clicking, dragging, splitting and using items work as always, in a fight too.
local ns = Rucksack
if not ns then return end
local Print = ns.Print
local B = {}
ns.Bags = B
local DB

local CELL, GAP, LABEL = 37, 3, 12
local PITCH = CELL + GAP
local GROUP_GAP = 6
-- your bags: the backpack, the four bag slots, and (WoW Forever) the reagent bag
-- (a reagent bag only if this game has one: in Classic-style games container 5 is the first bank bag)
local IC = Constants and Constants.InventoryConstants
local REAGENT = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
if not (IC and (IC.NumReagentBagSlots or 0) > 0) then REAGENT = nil end
local BAGS, BAR, IS_BAG = { 0, 1, 2, 3, 4 }, { 1, 2, 3, 4 }, {}
if REAGENT then BAGS[#BAGS + 1] = REAGENT BAR[#BAR + 1] = REAGENT end
for _, b in ipairs(BAGS) do IS_BAG[b] = true end
B.IS_BAG = IS_BAG
-- your bank: the bank itself and its bag slots (you buy the slots and put bags in them). At a banker:
-- only what's really there; away from it: the ones seen last.
--  * Classic style: the bank is container -1, its bag slots come right after your bags.
--  * WoW Forever: the bank is kept the newer way, in "bank tabs". The bank itself is the first tab
--    (container 6, 48 slots); each bag slot you buy is the next tab (7, 8 ... 14) and is as big as
--    the bag you put in it. Container -1 is the keyring there, not the bank.
do
  local EB = Enum and Enum.BagIndex
  local tab1 = EB and EB.CharacterBankTab_1
  local main = BANK_CONTAINER or (EB and EB.Bank)
  local tabbed = (not main) and tab1 and C_Bank and C_Bank.FetchNumPurchasedBankTabs and true or false
  B.BANK = { main = tabbed and tab1 or main or -1, tabbed = tabbed, type = (Enum and Enum.BankType and Enum.BankType.Character) or 0 }
end
local function bankBagCount()
  if B.BANK.tabbed then
    local ok, n = pcall(C_Bank.FetchMaxNumBankTabs, B.BANK.type)
    n = ok and tonumber(n) or 9
    return math.max(0, math.min(12, n - 1))
  end
  -- (the game's bank window knows how many bag slots it has: count them; else the game's number)
  local n = 0
  for i = 1, 16 do
    if _G["BankFrameBag" .. i] or (BankSlotsFrame and BankSlotsFrame["Bag" .. i]) or _G["BankSlotsFrameBag" .. i] then n = i end
  end
  if n == 0 and BankSlotsFrame and BankSlotsFrame.GetChildren then
    for _, c in ipairs({ BankSlotsFrame:GetChildren() }) do
      local nm = c.GetName and c:GetName() or ""
      if nm:find("Bag") then n = n + 1 end
    end
  end
  return math.max(n, NUM_BANKBAGSLOTS or (IC and IC.NumBankBagSlots) or 7)
end
local function bankBagIDs()
  local first = (NUM_BAG_SLOTS or 4) + 1 + (REAGENT and 1 or 0)
  if B.BANK.tabbed then first = B.BANK.main + 1 end
  local n = bankBagCount()
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = first + i end
  return t
end
B.BankBagIDs = bankBagIDs
local lastBank
local function bankIDs()
  local main = B.BANK.main
  if B.BankOpen and B.BankOpen() then
    local out = {}
    local E = Enum and Enum.BagIndex
    if not B.BANK.tabbed and (C_Container.GetContainerNumSlots(main) or 0) == 0 and E and E.CharacterBankTab_1 then
      for i = 1, 9 do local id = E["CharacterBankTab_" .. i] if id and (C_Container.GetContainerNumSlots(id) or 0) > 0 then out[#out + 1] = id end end
    else
      out[1] = main
      for _, id in ipairs(bankBagIDs()) do if (C_Container.GetContainerNumSlots(id) or 0) > 0 then out[#out + 1] = id end end
    end
    lastBank = out
    return out
  end
  if lastBank then return lastBank end
  local out = { main }
  for _, id in ipairs(bankBagIDs()) do out[#out + 1] = id end
  return out
end
B.BankIDs = bankIDs

B.CATS = {
  { key = "new", name = "New", color = { 1, 0.82, 0 } },
  { key = "sets", name = "Armour sets", color = { 0.92, 0.72, 0.38 } }, -- (19 Nov: items in your equipment sets, Sets.lua)
  -- (19 Nov: what Haul's "Sort loot" says is worth more at the auction house, Rucksack_Haul/HaulBag.lua)
  { key = "weapon", name = "Weapons", color = { 0.88, 0.42, 0.35 } },
  { key = "armor", name = "Armour", color = { 0.42, 0.61, 0.88 } },
  -- (19 Nov) food and water are in Consumables now, with the potions: one group, it doesn't split
  { key = "consumable", name = "Consumables", color = { 0.69, 0.48, 0.88 } },
  { key = "restock", name = "Restock", color = { 0.4, 0.8, 0.85 } }, -- (1.8.2: what's on your Restock list)
  { key = "trade", name = "Trade goods", color = { 0.55, 0.7, 0.45 } },
  { key = "quest", name = "Quest", color = { 1, 0.89, 0.36 } },
  { key = "other", name = "Everything else", color = { 0.6, 0.6, 0.6 } },
  { key = "sell", name = "Sell", color = { 1, 0.82, 0.25 } },
  { key = "empty", name = "Empty", color = { 0.35, 0.35, 0.35 } },
  { key = "emptyS", name = "Empty · special bag", color = { 0.3, 0.38, 0.45 } },
  { key = "junk", name = "Junk", color = { 0.9, 0.3, 0.3 } }, -- (1.8.2: Junk is under everything unless you drag it)
}
-- (1.9.1) the kinds of special bag: name and default colour (bit = the game's bag family)
B.SPECIAL = {
  { bit = 1, key = "quiver", name = "Quiver", color = { 0.80, 0.63, 0.40 } },
  { bit = 2, key = "ammo", name = "Ammo pouch", color = { 0.68, 0.68, 0.74 } },
  { bit = 4, key = "soul", name = "Soul bag", color = { 0.66, 0.38, 0.95 } },
  { bit = 32, key = "herb", name = "Herb bag", color = { 0.35, 0.82, 0.38 } },
  { bit = 64, key = "enchant", name = "Enchanting bag", color = { 0.38, 0.58, 1 } },
  { bit = 1024, key = "mining", name = "Mining bag", color = { 0.86, 0.52, 0.30 } },
  { bit = 8, key = "leather", name = "Leatherworking bag", color = { 0.62, 0.44, 0.27 } },
  { bit = 128, key = "engineer", name = "Engineering bag", color = { 1, 0.58, 0.18 } },
  { bit = 512, key = "gem", name = "Gem bag", color = { 0.32, 0.86, 0.90 } },
  { bit = 16, key = "inscribe", name = "Inscription bag", color = { 0.90, 0.84, 0.58 } },
}
-- each special bag is its own group, named after it ("Soul bag"): what's in it, then its empty slots
-- (18 Nov, he: "soul shards should be in soul bag")
do
  local at
  for i, c in ipairs(B.CATS) do if c.key == "emptyS" then at = i end end
  for n, sp in ipairs(B.SPECIAL) do
    table.insert(B.CATS, at + n, { key = "emptyS_" .. sp.key, name = sp.name, color = sp.color, spec = sp.key })
  end
end
-- colours for your own groups
B.PALETTE = { { 0.75, 0.54, 0.94 }, { 0.37, 0.78, 0.94 }, { 0.94, 0.63, 0.31 }, { 0.91, 0.44, 0.69 },
  { 0.48, 0.84, 0.48 }, { 0.95, 0.85, 0.35 }, { 0.45, 0.6, 1 }, { 0.85, 0.85, 0.85 } }
-- all groups (yours go just before Empty), and by key
local CAT, ALL = {}, {}
local function rebuild()
  wipe(CAT) wipe(ALL)
  for _, c in ipairs(B.CATS) do
    if c.key == "empty" then
      for _, g in ipairs(DB and DB.groups or {}) do
        local cc = { key = g.key, name = g.name, color = g.color, custom = true }
        ALL[#ALL + 1] = cc
        CAT[g.key] = cc
      end
    end
    if c.spec then c.color = B.SpecialColor and B.SpecialColor(c.spec) or c.color end
    ALL[#ALL + 1] = c
    CAT[c.key] = c
  end
end
B.RebuildCats = function() rebuild() end
rebuild()
B.CAT = CAT
local held -- the item on your cursor (groups get a slot to drop it on)
-- groups you can put an item in by hand (not Empty, not New)
local function placeable(key) return CAT[key] and key ~= "new" and key ~= "haulah" and key ~= "sets" and not key:find("^empty") and true or false end -- (19 Nov: Haul and Armour sets fill themselves)
B.Placeable = placeable
-- where a new group goes in a list of keys: above the Empty groups and Junk that close the list
function B.TailStart(keys)
  local at = #keys + 1
  for i = #keys, 1, -1 do
    local k = keys[i]
    if k == "junk" or (type(k) == "string" and k:find("^empty")) then at = i else break end
  end
  return at
end
-- the groups in your order (DB.order: keys; a group it doesn't know yet, like one that came with an
-- update, goes above the Empty groups and Junk at the bottom, never under Junk)
function B.Ordered()
  local list, seen, keys = {}, {}, {}
  for _, k in ipairs(DB and DB.order or {}) do
    if CAT[k] and not seen[k] then seen[k] = true list[#list + 1] = CAT[k] keys[#keys + 1] = k end
  end
  if #list == 0 then
    for _, c in ipairs(ALL) do list[#list + 1] = c end
    return list
  end
  for _, c in ipairs(ALL) do
    if not seen[c.key] then
      local at = (c.key == "junk" or c.key:find("^empty")) and (#keys + 1) or B.TailStart(keys)
      if c.key == "sets" or c.key == "haulah" then -- (19 Nov: Armour sets at the top, after New; Haul - Auction house after them)
        at = 1
        for i, k in ipairs(keys) do if k == "new" or (c.key == "haulah" and k == "sets") then at = i + 1 end end
      end
      if c.spec then -- (1.9.1: a special bag's empty group goes right after "Empty · special bag")
        for i = #keys, 1, -1 do if keys[i] == "emptyS" or keys[i]:find("^emptyS_") then at = i + 1 break end end
      end
      table.insert(list, at, c)
      table.insert(keys, at, c.key)
    end
  end
  return list
end
-- move a group to just before another one (or to the end); redraw unless told not to
local function setOrder(key, before)
  if key == before then return end
  local keys = {}
  for _, c in ipairs(B.Ordered()) do if c.key ~= key then keys[#keys + 1] = c.key end end
  local at = #keys + 1
  for i, k in ipairs(keys) do if k == before then at = i break end end
  table.insert(keys, at, key)
  DB.order = keys
end
function B.MoveGroup(key, before) setOrder(key, before) B.Changed() end
function B.ResetOrder() if DB then DB.order = nil B.Changed() end end

-- your own groups
function B.NewGroup(name, id, link)
  if not DB then return end
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then name = "My group" end
  DB.groups = DB.groups or {}
  DB.nextGroup = (DB.nextGroup or 0) + 1
  local key = "my" .. DB.nextGroup
  local c = B.PALETTE[(DB.nextGroup - 1) % #B.PALETTE + 1]
  table.insert(DB.groups, { key = key, name = name, color = { c[1], c[2], c[3] } })
  if DB.order then table.insert(DB.order, B.TailStart(DB.order), key) end
  rebuild()
  if id then
    if ns.Has("del") and ns.Del and ns.Del.JunkKind and ns.Del.JunkKind(id) then ns.Del.Keep(id) end
    DB.assign[id] = key
    B.newIDs[id] = nil
  end
  Print("new group: " .. name .. (id and (", with " .. (link or ns.NameOf(id) or "that item") .. " in it.") or ". Pick an item up and drop it on it."))
  B.Changed()
  return key
end
local function myGroup(key)
  for i, g in ipairs(DB and DB.groups or {}) do if g.key == key then return g, i end end
end
function B.RenameGroup(key, name)
  local g = myGroup(key)
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if not g or name == "" then return end
  g.name = name
  rebuild()
  B.Changed()
end
function B.ColorGroup(key, c)
  local g = myGroup(key)
  if not g then return end
  g.color = { c[1], c[2], c[3] }
  rebuild()
  B.Changed()
end
function B.DeleteGroup(key)
  local g, i = myGroup(key)
  if not g then return end
  table.remove(DB.groups, i)
  for id, k in pairs(DB.assign) do if k == key then DB.assign[id] = nil end end
  if DB.order then for j = #DB.order, 1, -1 do if DB.order[j] == key then table.remove(DB.order, j) end end end
  rebuild()
  Print(g.name .. " is deleted: its items go back where Rucksack puts them.")
  B.Changed()
end

---------------------------------------------------------------------------
-- Which group an item goes in
---------------------------------------------------------------------------
local instant = function(id)
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if f then return f(id) end
end
local function hasClean() return ns.Has("del") and ns.Del and ns.del and ns.Del.JunkKind and true or false end
local function junkKind(id, bag, slot)
  if not hasClean() then return nil end
  local ok, k = pcall(ns.Del.JunkKind, id, bag, slot)
  return ok and k or nil
end
-- (15 Nov) the same for the stack on your cursor: a single stack can be marked for sale, so it
-- matters which slot it came from
local function kindOfHeld(id)
  if not id or not hasClean() then return nil end
  if ns.Del.HeldKind then
    local ok, k = pcall(ns.Del.HeldKind, id)
    return ok and k or nil
  end
  return junkKind(id)
end
-- take a stack off Sell or Junk (from = { bag, slot } it came from, when known)
local function keepStack(id, from)
  if ns.Del.KeepAt then return ns.Del.KeepAt(id, from and from[1], from and from[2]) end
  ns.Del.Keep(id)
  return "all"
end
-- where Rucksack puts an item by itself (noYours) or with your choice (DB.assign: id -> group)
function B.Category(id, link, bag, slot, noYours)
  -- (19 Nov) in one of your equipment sets: Armour sets (locked: never junk)
  local inSet = B.Sets and B.Sets.Of(id)
  if inSet and B.Sets.Locked() then return "sets" end
  local jk = junkKind(id, bag, slot)
  if jk == 1 then return "junk" elseif jk == 2 then return "sell" end
  if inSet then return "sets" end
  local yours = not noYours and DB and DB.assign and DB.assign[id]
  if yours and placeable(yours) and yours ~= "junk" and yours ~= "sell" then return yours end
  -- (what's on your Restock list sits in its own group, if that group is ticked on the Bags page;
  -- unticked, those items stay in the groups they'd be in anyway)
  if DB and DB.cats and DB.cats.restock ~= false and B.Restock and B.Restock.Wants and DB.restock and B.Restock.Wants(id) then return "restock" end
  local _, _, _, _, _, classID = instant(id)
  local _, _, _, _, _, _, _, _, _, _, _, c2 = ns.GetInfo(link or id)
  classID = classID or c2
  -- quest: quest items, and what a quest or the Faire still needs
  if classID == 12 then return "quest" end
  if ns.Has("del") and ns.Del and ns.Del.QuestNeed then
    local ok, need = pcall(ns.Del.QuestNeed, id, link)
    if ok and need and need > 0 then return "quest" end
  end
  if ns.FaireKeep and ns.FaireKeep(id) then return "quest" end
  if classID == 7 or classID == 9 then return "trade" end
  if classID == 2 then return "weapon" end
  if classID == 4 then return "armor" end
  if classID == 0 then return "consumable" end
  return "other"
end
local function catShown(key)
  if key == "new" then return DB.showNew ~= false end
  if CAT[key] and CAT[key].custom then return true end
  return key == "junk" or key == "sell" or key:find("^empty") or key == "other" or DB.cats[key] ~= false
end

---------------------------------------------------------------------------
-- Your characters: what's in their bags and banks (remembered; the bank when you open it)
---------------------------------------------------------------------------
local bankOpen = false
local function meKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
B.MeKey = meKey
local function myRec()
  DB.chars = DB.chars or {}
  local k = meKey()
  DB.chars[k] = DB.chars[k] or {}
  local r = DB.chars[k]
  r.name, r.realm = UnitName("player"), GetRealmName and GetRealmName() or ""
  r.class = select(2, UnitClass("player"))
  return r
end
local function countIn(ids)
  local t = {}
  for _, bag in ipairs(ids) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local it = C_Container.GetContainerItemInfo(bag, slot)
      if it and it.itemID then t[it.itemID] = (t[it.itemID] or 0) + (it.stackCount or 1) end
    end
  end
  return t
end
-- (19 Nov) he looked at Zyxx from another character: "Nothing here yet", 0 copper, though he'd just played
-- Zyxx. Every character's saved bags were empty and their money 0: at logout (and /reload) the game has
-- already emptied the bags when Rucksack saved. Now nothing is saved while you leave the world
-- (B.leaving, from PLAYER_LEAVING_WORLD till PLAYER_ENTERING_WORLD), not at PLAYER_LOGOUT, and a read
-- that finds no items and no money never replaces one that had them.
function B.SaveBags()
  if not DB or B.leaving then return end
  local r = myRec()
  local t = countIn(BAGS)
  local money = GetMoney and GetMoney() or 0
  if next(t) == nil and money == 0 and r.bags and (next(r.bags) ~= nil or (r.money or 0) > 0) then return end
  r.bags = t
  r.money = money
  r.seen = time()
end
function B.SaveBank()
  if not DB or not bankOpen or B.leaving then return end
  local r = myRec()
  r.bank = countIn(bankIDs())
  r.bankSeen = time()
end
function B.Forget(key)
  if DB and DB.chars and key ~= meKey() then
    local r = DB.chars[key]
    DB.chars[key] = nil
    if B.view2 and B.view2.who == key and B.CloseView then B.CloseView() end
    Print((r and r.name or key) .. " is forgotten.")
    B.Changed()
  end
end
local function classColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return ("|cff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) end
  return "|cffffffff"
end
B.ClassColor = classColor
local function ago(t)
  if not t then return "never" end
  local d = time() - t
  if d < 120 then return "just now" end
  if d < 3600 then return math.floor(d / 60) .. " min ago" end
  if d < 86400 then local h = math.floor(d / 3600) return h .. (h == 1 and " hour ago" or " hours ago") end
  if d < 172800 then return "yesterday" end
  return math.floor(d / 86400) .. " days ago"
end
B.Ago = ago
-- where else you have an item: "Bank 12", "Zyxon 5", "Zyxon bank 20" (not this character's bags)
function B.Where(id)
  local out = {}
  if not DB or not DB.chars or not id then return out end
  local me = meKey()
  local mine = DB.chars[me]
  if mine and mine.bank and mine.bank[id] then out[#out + 1] = "Bank " .. mine.bank[id] end
  local keys = {}
  for k in pairs(DB.chars) do if k ~= me then keys[#keys + 1] = k end end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local r = DB.chars[k]
    local n = r.name or k
    if r.bags and r.bags[id] then out[#out + 1] = n .. " " .. r.bags[id] end
    if r.bank and r.bank[id] then out[#out + 1] = n .. " bank " .. r.bank[id] end
  end
  return out
end
local function addWhere(tt, id)
  if not DB or not id or not tt or not tt.AddLine then return end
  if B.VendorTip then pcall(B.VendorTip, tt, id) end -- (19 Nov) why the coin: the vendor and auction sums
  -- (18 Nov) why an item with "!?" is kept: the quest that needs it (he: "say reason why it does not
  -- sell, maybe like part of quest this and that")
  local Del = ns.Del
  if Del and Del.QuestNeed then
    local ok, need = pcall(Del.QuestNeed, id)
    if ok and need and need > 0 then
      local nm = ns.NameOf(id)
      local titles = nm and Del.questTitles and Del.questTitles[nm:lower()]
      if need == math.huge then
        tt:AddLine("Rucksack: it starts a quest, so it's kept.", 1, 0.82, 0, true)
      else
        tt:AddLine("Rucksack: kept for " .. (titles and titles[1] and ("the quest \"" .. table.concat(titles, "\", \"") .. "\"") or "a quest you have") ..
          " (needs " .. need .. "). Only what's over that is sold.", 1, 0.82, 0, true)
      end
    end
  end
  if DB.tipWhere == false then return end
  local parts = B.Where(id)
  if #parts == 0 then return end
  tt:AddLine("Also: " .. table.concat(parts, " · "), 0.5, 0.83, 1, true)
end
local tipHooked
local function hookTooltips()
  if tipHooked then return end
  tipHooked = true
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      if tt == GameTooltip or tt == ItemRefTooltip then pcall(addWhere, tt, data and data.id) end
    end)
  else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
      if tt and tt.HookScript then
        tt:HookScript("OnTooltipSetItem", function(self)
          local _, link = self:GetItem()
          pcall(addWhere, self, link and tonumber(link:match("item:(%d+)")))
        end)
      end
    end
  end
end
-- a view: whose (who: nil = you) and which (kind: "bags" or "bank"); live = the real thing.
-- The bag window always shows your bags; the second window a bank or another character.
local MAINVIEW = { kind = "bags" }
B.MAINVIEW = MAINVIEW
local function viewWho(v)
  local me = meKey()
  local who = v.who or me
  return who, who == me
end
local function vLiveBags(v) local _, mine = viewWho(v) return mine and v.kind == "bags" end
local function vLiveBank(v) local _, mine = viewWho(v) return mine and v.kind == "bank" and bankOpen end
local function vLive(v) return vLiveBags(v) or vLiveBank(v) end
B.IsLive = function(v) return vLive(v or MAINVIEW) end
function B.BankOpen() return bankOpen end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local f = CreateFrame("Frame", "RucksackBagsFrame", UIParent, ns.BACKDROP_TMPL)
f:SetSize(420, 300)
f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
f:SetFrameStrata("HIGH") -- (17 Nov) above Questie's tracker and other addons' windows; menus and tooltips stay on top
f:SetToplevel(true)
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
if f.SetBackdrop then
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f:SetBackdropColor(0.04, 0.035, 0.03, 0.95)
  f:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
end
f:Hide()
tinsert(UISpecialFrames, "RucksackBagsFrame")
-- (17 Nov) the pin on the left of the bags row keeps the window where it is (DB.pinned)
f:SetScript("OnDragStart", function(self) if DB and DB.pinned then return end self:StartMoving() end)
-- (kept by its top left corner, so the bags row opens downwards)
local function pinTopLeft()
  local l, t = f:GetLeft(), f:GetTop()
  if not l or not t then return end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  if DB then DB.pos = { "TOPLEFT", "BOTTOMLEFT", l, t } end
end
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  pinTopLeft()
end)

-- the icons (Rucksack_Bags\Icons): white, coloured in the game
local ICONS = "Interface\\AddOns\\Rucksack_Bags\\Icons\\"
local TAN, GOLD = { 0.85, 0.78, 0.6 }, { 1, 0.82, 0 }
-- a square icon button: one picture, coloured tan (gold when hovered or on)
local function iconButton(parent, size, file, tipTitle, tipText, onClick, name)
  local b = CreateFrame("Button", name, parent, ns.BACKDROP_TMPL)
  b:SetSize(size, size)
  if b.SetBackdrop then
    b:SetBackdrop(ns.SLOT_BACKDROP)
    b:SetBackdropColor(0.09, 0.08, 0.06, 0.95)
    b:SetBackdropBorderColor(0.4, 0.36, 0.28)
  end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  local pad = math.floor(size * 0.2 + 0.5)
  b.icon:SetPoint("TOPLEFT", pad, -pad)
  b.icon:SetPoint("BOTTOMRIGHT", -pad, pad)
  b.icon:SetTexture(ICONS .. file)
  b.color = TAN
  b.icon:SetVertexColor(TAN[1], TAN[2], TAN[3])
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  if onClick then b:SetScript("OnClick", onClick) end
  -- (19 Nov) he: "when I click Look groups and do not move my mouse it wont say Look One bag untill i
  -- rehover, fix buttons like that": after a click the tooltip is written again
  b:SetScript("PostClick", function(self)
    if GameTooltip:IsOwned(self) and self:IsMouseOver() then local fn = self:GetScript("OnEnter") if fn then fn(self) end end
  end)
  b:SetScript("OnEnter", function(self)
    if self.SetBackdropBorderColor and not self.lit then self:SetBackdropBorderColor(1, 0.82, 0) end
    if not self.lit then self.icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(type(tipTitle) == "function" and tipTitle() or tipTitle)
    local t = self.tipFn and self.tipFn() or (type(tipText) == "function" and tipText() or tipText)
    if t then GameTooltip:AddLine(t, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    if self.SetBackdropBorderColor and not self.lit then self:SetBackdropBorderColor(0.4, 0.36, 0.28) end
    if not self.lit then local c = self.color self.icon:SetVertexColor(c[1], c[2], c[3]) end
    GameTooltip:Hide()
  end)
  return b
end
-- lit: a gold frame and a gold picture (a switch that's on)
local function lightUp(b, on)
  b.lit = on and true or nil
  if b.SetBackdropBorderColor then
    if on then b:SetBackdropBorderColor(1, 0.82, 0) else b:SetBackdropBorderColor(0.4, 0.36, 0.28) end
  end
  local c = on and GOLD or b.color
  b.icon:SetVertexColor(c[1], c[2], c[3])
end
local function setIcon(b, file) b.icon:SetTexture(ICONS .. file) end

-- the header, one row: Rucksack (hover it: the arrow opens or closes your bags row), search, your
-- other characters, the bank, Tidy, Stacks, Look, settings, close
local HEAD, BAR_H = 32, 38
local logo = CreateFrame("Button", nil, f, ns.BACKDROP_TMPL)
logo:SetSize(22, 22)
logo:SetPoint("TOPLEFT", 7, -6)
if logo.SetBackdrop then logo:SetBackdrop(ns.SLOT_BACKDROP) logo:SetBackdropColor(0.09, 0.08, 0.06, 0.95) logo:SetBackdropBorderColor(0.4, 0.36, 0.28) end
logo.tex = logo:CreateTexture(nil, "ARTWORK")
logo.tex:SetPoint("TOPLEFT", 3, -3)
logo.tex:SetPoint("BOTTOMRIGHT", -3, 3)
logo.tex:SetTexture(ns.ICON)
logo.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local chev = iconButton(f, 20, "down", function() return DB and DB.barOpen and "Close your bags row" or "Open your bags row" end,
  "Your four bags and the reagent bag (free slots, swap a bag by dropping one on it), and next to them: New group, Delete group and the padlock.",
  function() B.ToggleBar() end, "RucksackBagsRowButton")
chev:SetPoint("LEFT", logo, "RIGHT", 3, 0)
-- (19 Nov) he: "put button arrow down always visible, and have it light up when hovering, clicking
-- on rucksack icon opens bag settings, clicking arrow opens menu on bottom". The arrow is always
-- there (the iconButton lights up gold under the mouse); Rucksack's icon opens the Bags settings.
logo:SetScript("OnEnter", function(self)
  if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1, 0.82, 0) end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Rucksack")
  GameTooltip:AddLine("Click: the Bags settings. The arrow next to it opens or closes your bags row.", 1, 1, 1, true)
  GameTooltip:Show()
end)
logo:SetScript("OnLeave", function(self)
  if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.4, 0.36, 0.28) end
  GameTooltip:Hide()
end)
logo:SetScript("OnClick", function() Rucksack_Open("bags") end)
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", -2, -4)
local optBtn = iconButton(f, 22, "gear", "Settings", "Columns, size, Rows or Packed, which groups show, and more.",
  function() Rucksack_Open("bags") end)
optBtn:SetPoint("RIGHT", close, "LEFT", -1, 0)
-- (19 Nov, 21:06) he: "give ability to sort bag with each row one category, stacked like now, one bag":
-- the Look button goes Rows -> Packed -> One bag -> Rows (right-click: the other way)
local lookBtn = iconButton(f, 22, "groups", function()
  return DB and (DB.style == "grid" and "Look: One bag" or DB.layout == "packed" and "Look: Packed" or "Look: Rows") or "Look"
end, function()
  if DB and DB.style == "grid" then return "No groups: your items as they really sit in your bags. Nothing moves by itself; click Tidy to sort them once.\n\nClick: Rows. Right-click: Packed." end
  if DB and DB.layout == "packed" then return "Groups side by side, filling each line: the bag stays small.\n\nClick: One bag. Right-click: Rows." end
  return "Each group on a line of its own.\n\nClick: Packed. Right-click: One bag."
end, function(_, button)
  local order = { "rows", "packed", "grid" }
  local cur = DB.style == "grid" and 3 or DB.layout == "packed" and 2 or 1
  local nx = button == "RightButton" and (cur + 1) % 3 + 1 or cur % 3 + 1
  if order[nx] == "grid" then DB.style = "grid" else DB.style = "groups" DB.layout = order[nx] end
  B.Changed()
end)
lookBtn:SetPoint("RIGHT", optBtn, "LEFT", -3, 0)
local stackBtn = iconButton(f, 22, "merged", function() return DB and DB.merged and "Stacks: Merged" or "Stacks: Separate" end, function()
  return DB and DB.merged and "All of one item as one icon: 80 ore shows as 80.\n\nClick: Separate (the real stacks)." or
    "The real stacks: 20, 20, 20, 20. Use this to split a stack or pick up an exact one.\n\nClick: Merged (one icon per item)."
end, function() DB.merged = not DB.merged B.Changed() end)
stackBtn:SetPoint("RIGHT", lookBtn, "LEFT", -3, 0)
local tidyBtn = iconButton(f, 22, "tidy", "Tidy", function()
    if DB and DB.style == "grid" then
      return "Sorts your bags once and puts half-full stacks together (the game's own sort: the items really move). After that they stay where they are again. Not in a fight."
    end
    return "Puts half-full stacks of the same item together (7 + 13 ore becomes one stack of 20), which frees bag slots. Not in a fight."
  end,
  function() B.Tidy() end)
tidyBtn:SetPoint("RIGHT", stackBtn, "LEFT", -3, 0)
-- (1.8.4) One bag had two ways, Tidy (always shown sorted) and Free. (18 Nov) Only Free now, no switch
-- (he: "when we are in one bag its unorganized until we click to tidy it up", "its not toggle just one
-- click", "remove button to toggle it"): every item sits in its real slot; Tidy sorts once with the
-- game's own sort. Groups stays sorted for you (it never moves anything in your real bags).
function B.FreeNow(v) return DB and DB.style == "grid" and (v == nil or v == B.MAINVIEW) and true or false end
local bankBtn = iconButton(f, 22, "bank", "Your bank", function()
  return (bankOpen and "Your bank is open: in its own window it's live, drag items between it and your bags." or
    "Opens your bank in its own window, as it was when you last opened it. At a banker it opens by itself, live.") ..
    "\n\nClick again: close it."
end, function() B.ShowView(nil, "bank") end)
bankBtn:SetPoint("RIGHT", tidyBtn, "LEFT", -3, 0)
local whoBtn = iconButton(f, 22, "chars", "Your characters",
  "Click: your characters (each one you've played with Bags on). Point at one, then pick Inventory or Bank: it opens in its own window. Other characters' are faded: you can look, not use.",
  function(self) B.WhoMenu(self) end)
whoBtn:SetPoint("RIGHT", bankBtn, "LEFT", -3, 0)
local search = CreateFrame("EditBox", "RucksackBagsSearch", f, "InputBoxTemplate")
search:SetHeight(18)
search:SetAutoFocus(false)
search:SetPoint("LEFT", logo, "RIGHT", 34, 0)
search:SetPoint("RIGHT", whoBtn, "LEFT", -7, 0)
search:SetFontObject(GameFontHighlightSmall)
search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
search:SetScript("OnTextChanged", function() B.Draw() end)
local searchHint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
searchHint:SetPoint("LEFT", 2, 0)
searchHint:SetText("Search")

-- the item area and the footer; a line saying whose / which bank, when it isn't your bags
local chips = CreateFrame("Frame", nil, f) -- (One grid had chips; One bag has none)
chips:Hide()
local body = CreateFrame("Frame", nil, f)
local foot = CreateFrame("Frame", nil, f)
foot:SetHeight(16)
foot.free = foot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
foot.free:SetPoint("LEFT", 2, 0)
foot.money = foot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
foot.money:SetPoint("RIGHT", -2, 0)
foot.junk = foot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
foot.junk:SetPoint("RIGHT", foot.money, "LEFT", -12, 0)
local nothing = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
nothing:SetJustifyH("LEFT")

---------------------------------------------------------------------------
-- The bags row (opens and closes under the header): your four bags and the reagent bag (free
-- slots; hover one and only its slots stay bright; drop a bag on one to swap, click to pick it up);
-- then New group, Delete group, the padlock
---------------------------------------------------------------------------
local bar = CreateFrame("Frame", nil, f)
bar:SetHeight(1)
if bar.SetClipsChildren then bar:SetClipsChildren(true) end
local barIn = CreateFrame("Frame", nil, bar)
barIn:SetPoint("TOPLEFT", 0, 0)
barIn:SetPoint("TOPRIGHT", 0, 0)
barIn:SetHeight(BAR_H)
bar.info = barIn:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
bar.info:SetPoint("LEFT", 2, 0)
bar.info:SetJustifyH("LEFT")
local function invSlot(bag)
  if C_Container.ContainerIDToInventoryID then
    local ok, id = pcall(C_Container.ContainerIDToInventoryID, bag)
    if ok then return id end
  end
end
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local barBtns = {}
for i, bag in ipairs(BAR) do
  local b = CreateFrame("Button", "RucksackBagSlot" .. bag, barIn, ns.BACKDROP_TMPL)
  b:SetSize(30, 30)
  b:SetPoint("LEFT", 36 + (i - 1) * 33 + (bag == REAGENT and 10 or 0), -2) -- (36: the pin is first)
  if b.SetBackdrop then
    b:SetBackdrop(ns.SLOT_BACKDROP)
    b:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
    b:SetBackdropBorderColor(0.42, 0.35, 0.21)
  end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  if bag == REAGENT then
    b.leaf = b:CreateTexture(nil, "OVERLAY")
    b.leaf:SetSize(11, 11)
    b.leaf:SetPoint("TOPLEFT", 1, -1)
    b.leaf:SetTexture("Interface\\Icons\\INV_Misc_Herb_07")
  end
  b.bag = bag
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  local function fight() if InCombatLockdown() then Print("bags can't be changed in a fight.") return true end end
  local function put()
    local inv = invSlot(bag)
    if not inv or fight() then return end
    if B.TrySwap and B.TrySwap(bag, inv) then return end -- (18 Nov: the old bag still has items)
    PutItemInBag(inv)
  end
  local function take()
    local inv = invSlot(bag)
    if not inv or not b.has or fight() then return end
    if B.TryTakeOut and B.TryTakeOut(bag, inv) then return end -- (18 Nov: it still has items)
    PickupBagFromSlot(inv)
  end
  b:SetScript("OnClick", function() if CursorHasItem() then put() else take() end end)
  b:SetScript("OnReceiveDrag", put)
  b:SetScript("OnDragStart", take)
  b:SetScript("OnEnter", function(self)
    if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1, 0.82, 0) end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local inv = invSlot(bag)
    if self.has and inv and GameTooltip.SetInventoryItem then
      GameTooltip:SetInventoryItem("player", inv)
      GameTooltip:AddLine(" ")
      local sp = B.SpecialOf and B.SpecialOf(bag)
      GameTooltip:AddLine((self.free or 0) .. " of " .. (self.size or 0) .. " slots free" .. (sp and (" (" .. sp.name .. ")") or (bag == REAGENT and " (reagents only)") or ""), 1, 1, 1)
      GameTooltip:AddLine("Drop another bag on it to swap, or click it to take it out: its items are moved into your other bags first.", 0.7, 0.7, 0.7, true)
    else
      GameTooltip:AddLine(bag == REAGENT and "Empty reagent bag slot" or "Empty bag slot")
      GameTooltip:AddLine(bag == REAGENT and "Drop a reagent bag here." or "Drop a bag here.", 1, 1, 1)
    end
    GameTooltip:Show()
    if self.has then B.hoverBag = bag B.Draw() end
  end)
  b:SetScript("OnLeave", function(self)
    if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.42, 0.35, 0.21) end
    GameTooltip:Hide()
    if B.hoverBag then B.hoverBag = nil B.Draw() end
  end)
  barBtns[i] = b
end
local function drawBar(st)
  for _, b in ipairs(barBtns) do
    local inv = invSlot(b.bag)
    local tex = inv and GetInventoryItemTexture and GetInventoryItemTexture("player", inv)
    b.has = tex and true or false
    b.icon:SetTexture(tex or EMPTY_BAG)
    b.icon:SetAlpha(tex and 1 or 0.5)
    b.free, b.size = st.bagFree[b.bag] or 0, st.bagSize[b.bag] or 0
    b.count:SetText(tex and ((b.free == 0 and "|cffff5a50" or "|cffffffff") .. b.free .. "|r") or "")
  end
end
-- (17 Nov) the pin, first on the left of the row: keeps the bag window where it is (he: "place a lock on
-- leftest side, it cant be standard lock because we already have that, it needs to be about locking a
-- position of window of the bag"). A pushpin, so it doesn't look like the group padlock.
B.pinBtn = iconButton(barIn, 30, "unpinned", function() return DB and DB.pinned and "Window pinned" or "Window not pinned" end, function()
  return DB and DB.pinned and "The bag window stays where it is: dragging it does nothing.\n\nClick to let it move again." or
    "Drag the bag window anywhere by its edge or empty space.\n\nClick to pin it where it is, so it can't be moved by accident."
end, function(self)
  if not DB then return end
  DB.pinned = not DB.pinned or nil
  B.Draw()
  if GameTooltip:IsOwned(self) and self:GetScript("OnEnter") then self:GetScript("OnEnter")(self) end
end, "RucksackBagsPin")
B.pinBtn:SetPoint("LEFT", 0, -2)
-- the three tools on the right of the row: the same size as the bags, pictures centred
local lockBtn = iconButton(barIn, 30, "unlocked", function() return DB and DB.locked and "Locked" or "Unlocked" end, function()
  return DB and DB.locked and "Groups stay where they are: no moving, making or deleting groups. You can still move items from one group to another.\n\nClick to unlock." or
    "Click to lock the groups, so none moves by accident. You can still move items from one group to another."
end, nil, "RucksackBagsLock")
lockBtn:SetPoint("RIGHT", 0, -2)
local trashBtn = iconButton(barIn, 30, "delete", "Delete a group", nil, nil, "RucksackBagsDeleteGroup")
trashBtn:SetPoint("RIGHT", lockBtn, "LEFT", -3, 0)
trashBtn.color = { 1, 0.42, 0.42 }
trashBtn.icon:SetVertexColor(1, 0.42, 0.42)
local newBtn = iconButton(barIn, 30, "plus", "New group", nil, nil, "RucksackBagsNewGroup")
newBtn:SetPoint("RIGHT", trashBtn, "LEFT", -3, 0)
newBtn.color = { 0.4, 0.87, 0.4 }
newBtn.icon:SetVertexColor(0.4, 0.87, 0.4)
local hiddenBtn = iconButton(barIn, 30, "hidden", "Hidden items", function()
  local n = 0
  for _ in pairs(DB and DB.hidden or {}) do n = n + 1 end
  return "Opens a small bag next to this one with the items you've hidden" .. (n > 0 and (" (" .. n .. ")") or "") ..
    ". Pull an item into it and the bag stops showing it: tools, your Hearthstone, things you never need to look at."
end, function() B.ToggleHidden() end, "RucksackBagsHiddenButton")
hiddenBtn:SetPoint("RIGHT", newBtn, "LEFT", -8, 0)
-- (1.8.2) Restock: the things you always want on you; a vendor that sells them tops you up (Restock.lua)
B.restockBtn = iconButton(barIn, 30, "restock", "Restock", function()
  return B.Restock and B.Restock.Tip and B.Restock.Tip() or "Things you always want on you, bought at vendors."
end, function() if B.Restock and B.Restock.Toggle then B.Restock.Toggle() end end, "RucksackBagsRestockButton")
B.restockBtn:SetPoint("RIGHT", hiddenBtn, "LEFT", -3, 0)
-- (15 Nov) where the sell / delete / bank boxes sit: each click moves them to the next corner
local SIDE_ORDER = { tr = "br", br = "bl", bl = "tl", tl = "tr" }
local SIDE_NAME = { tr = "top right", br = "bottom right", bl = "bottom left", tl = "top left" }
B.sideBtn = iconButton(barIn, 30, "side_tr", "Boxes", function()
  local v = DB and DB.sidePos or "tr"
  -- (25 Nov) he: "make left click hide or show boxes, right click to move them around. if they are hidden
  -- then they still work just its not displayed on the screen"
  local hid = DB and DB.sideHidden
  return "The Always sell / delete, Sell / delete once and Send to bank windows" ..
    (hid and " are hidden. They still work: Rucksack sells, deletes and banks as before (turn that off in Settings)." or (" sit " .. SIDE_NAME[v] .. " of the bag.")) ..
    "\n\nClick: " .. (hid and "show them." or "hide them.") .. "\nRight-click: move them to the " .. SIDE_NAME[SIDE_ORDER[v]] .. "."
end, function(self, button)
  if not DB then return end
  if button == "RightButton" then
    local v = SIDE_ORDER[DB.sidePos or "tr"] or "tr"
    DB.sidePos = v
    DB.sideHidden = nil -- (moving them shows them)
    setIcon(self, "side_" .. v)
  else
    DB.sideHidden = (not DB.sideHidden) or nil
  end
  B.Draw()
  if ns.Changed then ns.Changed() end
  if GameTooltip:IsOwned(self) and self:GetScript("OnEnter") then self:GetScript("OnEnter")(self) end
end, "RucksackBagsSideButton")
B.sideBtn:SetPoint("RIGHT", B.restockBtn, "LEFT", -3, 0)
-- (19 Nov) automatic sorting on / off, he: "put toggle icon on top left of boxes with automatic
-- sorting icon we can turn on or off and it will stop any sorting, it will still put item in proper
-- categories". Off: nothing moves by itself (special bags, quiver, reagent bag) and the groups keep
-- their order (new items go at the end); Tidy still sorts when clicked. DB.autoSort ~= false.
B.autoBtn = iconButton(barIn, 30, "autosort", function() return DB and DB.autoSort == false and "Automatic sorting: off" or "Automatic sorting: on" end, function()
  if DB and DB.autoSort == false then
    return "Nothing moves by itself and nothing is re-sorted: your items stay where they are, in their groups (new ones go at the end). Tidy still sorts when you click it.\n\nClick: on."
  end
  return "Herbs, shards, ore, arrows and reagents move into their bags by themselves, and the groups are sorted each time you open the bag.\n\nClick: off (nothing moves or re-sorts by itself)."
end, function(self)
  if not DB then return end
  DB.autoSort = DB.autoSort == false and true or false
  Print(DB.autoSort and "automatic sorting on." or "automatic sorting off: nothing moves or re-sorts by itself. Tidy still sorts when you click it.")
  if DB.autoSort then B.rank = nil B.SpecialHome() B.ReagentsHome() end
  B.Draw()
  if GameTooltip:IsOwned(self) and self:GetScript("OnEnter") then self:GetScript("OnEnter")(self) end
end, "RucksackBagsAutoSort")
B.autoBtn:SetPoint("RIGHT", B.sideBtn, "LEFT", -3, 0)
B.LightUp = lightUp
B.toolBtns = { lockBtn, trashBtn, newBtn } -- (19 Nov: Hidden, Restock, Boxes went to the tool row; Auto-sort is gone)
B.hiddenBtn = hiddenBtn

---------------------------------------------------------------------------
-- The game's item buttons: one per bag slot, under a frame that carries the bag number
---------------------------------------------------------------------------
local bagFrames, buttons, deco = {}, {}, {}
-- the window being drawn now: the bag (MAIN) or the second window (VIEW, made further down)
local MAIN = { body = body, labels = {}, hints = {}, ghosts = {}, ghostN = 0, frame = f }
local PANE = MAIN
B.MAIN = MAIN
local function bagFrame(bag)
  if not bagFrames[bag] then
    -- (your bags' buttons live in the bag window, your bank's in the second window)
    local parent = IS_BAG[bag] and MAIN.body or (B.VIEW and B.VIEW.body) or MAIN.body
    local bf = CreateFrame("Frame", nil, parent)
    bf:SetAllPoints(parent)
    bf:SetID(bag)
    bagFrames[bag] = bf
  end
  return bagFrames[bag]
end
local function decorate(b)
  local d = {}
  d.edge = b:CreateTexture(nil, "OVERLAY")       -- a coloured frame (first to go, next food)
  d.edge:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  d.edge:SetBlendMode("ADD")
  d.edge:SetPoint("CENTER")
  d.edge:SetSize(CELL * 1.7, CELL * 1.7)
  d.dot = b:CreateTexture(nil, "OVERLAY")        -- the group (One grid)
  d.dot:SetSize(7, 7)
  d.dot:SetPoint("TOPLEFT", 2, -2)
  d.coin = b:CreateTexture(nil, "OVERLAY")       -- sell
  d.coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  d.coin:SetSize(12, 12)
  d.coin:SetPoint("TOPRIGHT", -2, -2)
  d.mark = b:CreateTexture(nil, "OVERLAY")       -- junk
  d.mark:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  d.mark:SetSize(14, 14)
  d.mark:SetPoint("TOPRIGHT", 3, 3)
  d.arrow = b:CreateTexture(nil, "OVERLAY")      -- better than what you wear
  d.arrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
  d.arrow:SetTexCoord(0, 1, 1, 0)
  d.arrow:SetSize(16, 16)
  d.arrow:SetPoint("TOPRIGHT", 2, 2)
  d.quest = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  d.quest:SetPoint("TOPRIGHT", -1, -1)
  d.quest:SetText("|cffffe45c!|r")
  d.needed = b:CreateTexture(nil, "OVERLAY", nil, 6) -- (16 Nov) a quest you have needs it: kept, not sold
  d.needed:SetTexture(ICONS .. "questbang") -- (17 Nov: our own big "!", no yellow square)
  d.needed:SetSize(20, 20)
  d.needed:SetPoint("TOPRIGHT", 3, 2)
  -- (18 Nov) a real quest item: the game's own gold quest border round the slot; an item a quest of
  -- yours needs: how many it still needs, under its "!?"
  d.qborder = b:CreateTexture(nil, "OVERLAY", nil, 5)
  d.qborder:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBorder")
  d.qborder:SetAllPoints()
  d.qborder:Hide()
  d.qnum = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  d.qnum:SetPoint("TOPRIGHT", -2, -17)
  do local f = d.qnum:GetFont() if f then d.qnum:SetFont(f, 10, "OUTLINE") end end
  d.qnum:SetTextColor(1, 0.85, 0.2)
  d.tag = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") -- "BoE", "open"
  d.tag:SetPoint("TOPLEFT", 1, -1)
  local font = d.tag:GetFont()
  if font then d.tag:SetFont(font, 9, "OUTLINE") end
  -- (1.9.1) a special bag's slot: tinted in that bag's colour, with a thin border of it
  d.tint = b:CreateTexture(nil, "OVERLAY", nil, -2)
  d.tint:SetAllPoints()
  d.tint:Hide()
  d.lines = {}
  for i = 1, 4 do
    local t = b:CreateTexture(nil, "OVERLAY", nil, -1)
    if i == 1 then t:SetPoint("TOPLEFT") t:SetPoint("TOPRIGHT") t:SetHeight(1)
    elseif i == 2 then t:SetPoint("BOTTOMLEFT") t:SetPoint("BOTTOMRIGHT") t:SetHeight(1)
    elseif i == 3 then t:SetPoint("TOPLEFT") t:SetPoint("BOTTOMLEFT") t:SetWidth(1)
    else t:SetPoint("TOPRIGHT") t:SetPoint("BOTTOMRIGHT") t:SetWidth(1) end
    t:Hide()
    d.lines[i] = t
  end
  d.dim = b:CreateTexture(nil, "OVERLAY", nil, 7) -- search and filter: everything else goes dark
  d.dim:SetAllPoints()
  d.dim:SetColorTexture(0, 0, 0, 0.75)
  deco[b] = d
  return d
end
local info = {} -- button -> what it shows now (kept off the button itself)
local function extraTip(self)
  local e = info[self]
  if not e or not e.id or not GameTooltip:IsOwned(self) then return end
  local lines = {}
  if e.side and B.SideTip then
    -- (15 Nov) in one of the boxes on the right: the box says what happens to it
    for _, l in ipairs(B.SideTip(e)) do lines[#lines + 1] = l end
  elseif e.cat == "sell" then
    lines[#lines + 1] = "|cffffd100Sell:|r sold at a vendor, never thrown away."
    lines[#lines + 1] = "|cff999999To keep it: pick it up and drop it on the green slot that shows up first in Sell.|r"
  elseif e.cat == "junk" then
    local why = ns.Del.Reason and ns.Del.Reason(e.id)
    lines[#lines + 1] = "|cffff6b6bJunk|r" .. (why and (": " .. why) or "") .. (e.first and "  |cffffd100first to go|r" or "")
    lines[#lines + 1] = "|cff999999To keep it: drop it on another group's slot, or on Junk's slot again.|r"
  else
    local yours = DB.assign and DB.assign[e.id]
    if yours and CAT[yours] and e.cat == yours then
      lines[#lines + 1] = "|cff66dd66You put this in " .. CAT[yours].name .. ".|r |cff999999Drop it on its slot there again to undo.|r"
    end
    if e.isNew then lines[#lines + 1] = "|cffffd100New.|r" end
    if e.boe then lines[#lines + 1] = "|cff7fd4ffNot bound yet: you can still sell it or send it to another character.|r" end
    if e.open then lines[#lines + 1] = "|cffffd100Right-click to open it.|r" end
    if e.upgrade then lines[#lines + 1] = "|cff66dd66Better than what you wear.|r" end
    if e.next then lines[#lines + 1] = "|cff66dd66Rations: " .. e.next .. "|r" end
    for _, u in ipairs(ns.UsedFor and ns.UsedFor(e.id, e.link) or {}) do
      if u ~= "a rare or better item" and not u:find("^Rations") then lines[#lines + 1] = "|cffffe45c" .. u .. "|r" end
    end
    if e.total and e.total > (e.count or 0) then lines[#lines + 1] = "|cff999999" .. e.total .. " in your bags|r" end
  end
  if #lines == 0 then return end
  GameTooltip:AddLine(" ")
  for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
  GameTooltip:Show()
end
local function getButton(bag, slot)
  buttons[bag] = buttons[bag] or {}
  local b = buttons[bag][slot]
  if b then return b end
  local name = "RucksackBag" .. (bag < 0 and ("M" .. -bag) or bag) .. "Slot" .. slot
  local ok
  ok, b = pcall(CreateFrame, "ItemButton", name, bagFrame(bag), "ContainerFrameItemButtonTemplate")
  if not ok or not b then b = CreateFrame("Button", name, bagFrame(bag), "ContainerFrameItemButtonTemplate") end
  b:SetID(slot)
  b:SetSize(CELL, CELL)
  decorate(b)
  b:HookScript("OnEnter", extraTip)
  -- (15 Nov) Alt + left-click: this stack goes to the bank; Alt + right-click: it stays (Side.lua)
  b:HookScript("OnClick", function(self, button)
    if B.AltClick and IsAltKeyDown and IsAltKeyDown() then B.AltClick(info[self], button)
    elseif B.DroppedOn then B.DroppedOn(info[self]) end -- (an item from a box put on an empty slot)
  end)
  b:HookScript("OnReceiveDrag", function(self) if B.DroppedOn then B.DroppedOn(info[self]) end end)
  b:HookScript("OnLeave", function(self)
    local e = info[self]
    if e and e.isNew and B.newIDs[e.id] then B.newIDs[e.id] = nil B.Changed() end
  end)
  buttons[bag][slot] = b
  return b
end
local function hideExtras(b)
  for _, k in ipairs({ "NewItemTexture", "BattlepayItemTexture", "JunkIcon", "UpgradeIcon", "ItemContextOverlay" }) do
    local r = b[k]
    if type(r) == "table" and r.Hide then r:Hide() end
  end
  for _, k in ipairs({ "flashAnim", "newitemglowAnim" }) do
    local a = b[k]
    if type(a) == "table" and a.Stop then a:Stop() end
  end
end
local function cooldown(b, bag, slot)
  local cd = b.Cooldown
  if type(cd) ~= "table" then cd = b.GetName and _G[(b:GetName() or "") .. "Cooldown"] end
  if type(cd) ~= "table" then return end
  local start, duration, enable
  if C_Container.GetContainerItemCooldown then start, duration, enable = C_Container.GetContainerItemCooldown(bag, slot) end
  if start and duration and duration > 0 and enable ~= 0 then
    if CooldownFrame_Set then CooldownFrame_Set(cd, start, duration, enable) elseif cd.SetCooldown then cd:SetCooldown(start, duration) end
  elseif cd.Hide then cd:Hide() end
end
-- paint a button with an item (or as an empty slot)
local function paint(b, e, count)
  if ClearItemButtonOverlay then ClearItemButtonOverlay(b) end
  if b.SetHasItem then b:SetHasItem(e.icon) end
  SetItemButtonTexture(b, e.icon)
  if b.SetItemButtonQuality then b:SetItemButtonQuality(e.quality, e.link, true)
  elseif SetItemButtonQuality then SetItemButtonQuality(b, e.quality, e.link) end
  SetItemButtonCount(b, count or 0)
  SetItemButtonDesaturated(b, e.locked and true or false)
  if b.UpdateExtended then b:UpdateExtended() end
  if b.SetReadable then b:SetReadable(e.readable) else b.readable = e.readable end
  if b.SetMatchesSearch then b:SetMatchesSearch(true) end
  hideExtras(b)
  cooldown(b, e.bag, e.slot)
end

-- items you can only look at (another character, or the bank when you're not at it): plain buttons
local function qColor(q)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return 0.4, 0.36, 0.28
end
local function ghostButton(i)
  local ghosts = PANE.ghosts
  if ghosts[i] then return ghosts[i] end
  local g = CreateFrame("Button", nil, PANE.body, ns.BACKDROP_TMPL)
  g:SetSize(CELL, CELL)
  if g.SetBackdrop then g:SetBackdrop(ns.SLOT_BACKDROP) g:SetBackdropColor(0.06, 0.05, 0.04, 0.95) end
  g.icon = g:CreateTexture(nil, "ARTWORK")
  g.icon:SetPoint("TOPLEFT", 3, -3)
  g.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  g.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  g.count = g:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  g.count:SetPoint("BOTTOMRIGHT", -2, 2)
  g.mark = g:CreateTexture(nil, "OVERLAY")
  g.mark:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  g.mark:SetSize(14, 14)
  g.mark:SetPoint("TOPRIGHT", 3, 3)
  g.coin = g:CreateTexture(nil, "OVERLAY")
  g.coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  g.coin:SetSize(12, 12)
  g.coin:SetPoint("TOPRIGHT", -2, -2)
  g.dot = g:CreateTexture(nil, "OVERLAY")
  g.dot:SetSize(7, 7)
  g.dot:SetPoint("TOPLEFT", 3, -3)
  g:SetScript("OnEnter", function(self)
    if not self.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self.where or "", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ghosts[i] = g
  return g
end

---------------------------------------------------------------------------
-- Reading the bags (or the bank)
---------------------------------------------------------------------------
local function sellPrice(id) return (select(11, ns.GetInfo(id))) or 0 end
local function bagKind(bag)
  if IS_BAG[bag] and B.SpecialOf and B.SpecialOf(bag) then return "S" end -- (18 Nov: a soul bag in the reagent slot is a soul bag)
  if bag == REAGENT then return "R" end
  local family = 0
  if IS_BAG[bag] and bag ~= 0 and C_Container.GetContainerNumFreeSlots then family = select(2, C_Container.GetContainerNumFreeSlots(bag)) or 0 end
  return family ~= 0 and "S" or ""
end
-- everything in those containers; free slots by kind ("" any item, "R" reagents only, "S" a special bag)
-- slots the game shows with a padlock (bank slots not unlocked yet): left out, they aren't yours yet
do
local LOCKKEYS = { "LockIcon", "Lock", "Locked", "LockedIcon", "SlotLock", "LockOverlay", "LockTexture", "lockIcon" }
local function lockTex(r)
  if not r or not r.IsShown or not r:IsShown() or not r.GetObjectType or r:GetObjectType() ~= "Texture" then return false end
  local a = r.GetAtlas and r:GetAtlas()
  if type(a) == "string" and a:lower():find("lock") then return true end
  local t = r:GetTexture()
  if type(t) == "string" and t:lower():find("lock") then return true end
  local p = r.GetTextureFilePath and r:GetTextureFilePath()
  if type(p) == "string" and p:lower():find("lock") then return true end
  return false
end
local function padlocked(b)
  if not b then return false end
  for _, k in ipairs(LOCKKEYS) do
    local v = rawget(b, k)
    if type(v) == "table" and v.IsShown and v:IsShown() then return true end
  end
  for _, r in ipairs({ b:GetRegions() }) do if lockTex(r) then return true end end
  for _, c in ipairs({ b:GetChildren() }) do
    for _, r in ipairs({ c:GetRegions() }) do if lockTex(r) then return true end end
  end
  return false
end
B.Padlocked = padlocked
-- (remembered once seen, until the next visit to the bank: a hidden button may not keep its padlock)
local lockedSeen = {}
function B.IsLockedSlot(bag, slot)
  if lockedSeen[bag .. ":" .. slot] then return true end
  local b = buttons[bag] and buttons[bag][slot]
  if b and padlocked(b) then lockedSeen[bag .. ":" .. slot] = true return true end
  return false
end
function B.ForgetLocked() wipe(lockedSeen) end
end
-- how many slots a container has (bank slots the game shows with a padlock are left out one by one, in readBags)
local function numSlots(bag)
  return C_Container.GetContainerNumSlots(bag) or 0
end
B.NumSlots = numSlots
local function readBags(ids)
  local items = {}
  local st = { free = 0, total = 0, rFree = 0, rTotal = 0, empties = { [""] = {}, R = {}, S = {} }, bagFree = {}, bagSize = {} }
  for _, bag in ipairs(ids) do
    local n = numSlots(bag)
    local kind = bagKind(bag)
    st.bagSize[bag], st.bagFree[bag] = n, 0
    for slot = 1, n do
      local it = C_Container.GetContainerItemInfo(bag, slot)
      if it and it.itemID then
        items[#items + 1] = { bag = bag, slot = slot, id = it.itemID, link = it.hyperlink, count = it.stackCount or 1,
          quality = it.quality, locked = it.isLocked, icon = it.iconFileID or ns.GetIcon(it.itemID), readable = it.isReadable,
          bound = it.isBound, open = it.hasLoot and true or nil }
      elseif not IS_BAG[bag] and B.IsLockedSlot(bag, slot) then
        -- (a bank slot the game shows locked: not counted, not shown)
        st.locked = (st.locked or 0) + 1
      else
        st.bagFree[bag] = st.bagFree[bag] + 1
        table.insert(st.empties[kind], { bag = bag, slot = slot })
        if kind == "" then st.free = st.free + 1 elseif kind == "R" then st.rFree = st.rFree + 1 end
      end
      if kind == "" then st.total = st.total + 1 elseif kind == "R" then st.rTotal = st.rTotal + 1 end
    end
  end
  return items, st
end
-- new items: an item you have more of than a moment ago (until you've looked at it, or closed the bag)
B.newIDs = {}
local lastCounts
local function trackNew()
  local now = countIn(BAGS)
  if lastCounts then
    for id, c in pairs(now) do if c > (lastCounts[id] or 0) then B.newIDs[id] = true end end
  end
  lastCounts = now
end
-- (19 Nov) he: "the sorting the bag like that is too much, its jumping all around, we have to stop
-- it". While the bag is open every item keeps the place it had (B.rank: id -> place, given out in
-- the order they were first drawn); something new goes after them. Closing the bag, or Tidy, sorts
-- again. And a name, once known, is kept (B.names): while the game drops item details (an auction
-- house scan) a nameless item no longer jumps to the front.
B.names = {}
function B.NameKey(id, link)
  local n = ns.NameOf(id, link)
  if n and n ~= "" then B.names[id] = n return n end
  return B.names[id] or ""
end
-- (B.sortRank: the ranks for the list being sorted, or nil. B fields: Lua's 200-local limit)
local function sortItems(a, b)
  if a.setOrd and b.setOrd and a.setOrd ~= b.setOrd then return a.setOrd < b.setOrd end -- (19 Nov: first set first)
  local curRank = B.sortRank
  if curRank then
    local ra, rb = curRank[a.id], curRank[b.id]
    if ra and rb then if ra ~= rb then return ra < rb end
    elseif ra then return true
    elseif rb then return false end
  end
  if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
  local na, nb = B.NameKey(a.id, a.link), B.NameKey(b.id, b.link)
  if na ~= nb then return na < nb end
  if a.count ~= b.count then return a.count > b.count end
  if (a.bag or 0) ~= (b.bag or 0) then return (a.bag or 0) < (b.bag or 0) end
  return (a.slot or 0) < (b.slot or 0)
end
-- what the window shows now: the cells by group; merged = one cell per item (its first stack carries the total)
local function buildCells(v, text)
  v = v or MAINVIEW
  text = text or ""
  local items, st
  local live = vLive(v)
  local who, mine = viewWho(v)
  local liveBags = function() return vLiveBags(v) end
  if vLiveBags(v) then
    items, st = readBags(BAGS)
    if v == MAINVIEW and B.LiftOut then items = B.LiftOut(items) end
  elseif vLiveBank(v) then
    items, st = readBags(bankIDs())
  else
    items = {}
    st = { free = 0, total = 0, rFree = 0, rTotal = 0, empties = { [""] = {}, R = {}, S = {} }, bagFree = {}, bagSize = {} }
    local r = DB.chars and DB.chars[who]
    local data = r and r[v.kind == "bank" and "bank" or "bags"]
    st.rec, st.data = r, data
    for id, c in pairs(data or {}) do
      items[#items + 1] = { id = id, count = c, ghost = true, icon = ns.GetIcon(id), quality = ns.QualityOf(id) }
    end
  end
  -- hidden items stay out of the bag (a search still finds them)
  if DB.hidden and next(DB.hidden) then
    local keep = {}
    for _, e in ipairs(items) do
      if not DB.hidden[e.id] or (text ~= "" and (ns.NameOf(e.id, e.link) or ""):lower():find(text, 1, true)) then keep[#keep + 1] = e end
    end
    items = keep
  end
  local byCat = {}
  local nextFood, nextDrink = ns.Eat and ns.Eat.food, ns.Eat and ns.Eat.drink
  local firstOut
  if liveBags() and ns.Has("del") and ns.Del and ns.Del.Scan then
    local ok, it = pcall(ns.Del.Scan, false)
    firstOut = ok and it and it.id or nil
  end
  for _, e in ipairs(items) do
    local ok, cat = pcall(B.Category, e.id, e.link, e.bag, e.slot)
    e.cat = ok and cat or "other"
    -- (19 Nov) while an auction house scan runs the game can drop an item's details for a moment:
    -- then the item keeps the group it had, instead of jumping to another one and back
    if e.id and live then
      B.lastCat = B.lastCat or {}
      if ok and ns.GetInfo(e.link or e.id) then B.lastCat[e.id] = e.cat
      elseif B.lastCat[e.id] then e.cat = B.lastCat[e.id] end
    end
    if not catShown(e.cat) then e.cat = "other" end
    if e.cat == "sets" then e.setOrd = B.Sets.Order(e.id) end
    if e.cat == "junk" then
      e.first = e.id == firstOut
    elseif live then
      local gear = e.cat == "weapon" or e.cat == "armor"
      -- (19 Nov) an item's tags (BoE, the upgrade arrow) are worked out once and kept until your bags
      -- or the gear you wear really change: during an auction scan the game hands out half-filled
      -- item details and the tags blinked on and off (he: "BoE on item its disappearing and appearing")
      B.visCache = B.visCache or {}
      local vk = gear and (e.link or e.id)
      local vc = vk and B.visCache[vk]
      if vc and (e.bound == nil or vc.bound == e.bound) then
        e.upgrade, e.boe = vc.up, vc.boe
      elseif gear then
        local sure = e.bound ~= nil
        if ns.Has("del") and ns.Del.IsUpgrade then
          local ok2, up = pcall(ns.Del.IsUpgrade, e.id, e.link)
          e.upgrade = ok2 and up or false
          sure = sure and ok2
        end
        local bind = select(14, ns.GetInfo(e.link or e.id))
        if e.bound == false and bind == 2 then e.boe = true end
        if bind == nil then sure = false end
        if sure then B.visCache[vk] = { up = e.upgrade, boe = e.boe, bound = e.bound } end
      end
      if liveBags() then
        if e.id == nextFood then e.next = "your next food" elseif e.id == nextDrink then e.next = "your next water" end
        if B.newIDs[e.id] and catShown("new") and e.cat ~= "sets" and e.cat ~= "haulah" then e.isNew = true e.cat = "new" end
      end
    end
  end
  -- (19 Nov) your bags, while open: places kept (see sortItems)
  B.sortRank = nil
  if v == MAINVIEW and live then
    B.rank = B.rank or { n = 0 }
    B.sortRank = B.rank
  end
  table.sort(items, sortItems)
  local rk = B.sortRank
  if rk then
    for _, e in ipairs(items) do
      if e.id and not rk[e.id] then rk.n = rk.n + 1 rk[e.id] = rk.n end
    end
  end
  B.sortRank = nil
  local seen = {}
  local free = B.FreeNow(v) and vLiveBags(v)
  st.freeMode = free
  local merge = (DB.merged and not free) or not live
  -- (15 Nov) the boxes on the right of the bag (Side.lua): what's on your list, what's marked once
  -- and what goes to the bank show there, not in the bag's groups
  local side = v == MAINVIEW and vLiveBags(v) and B.SideOn and B.SideOn() and { always = {}, once = {}, bank = {}, quiver = {}, haul = {} } or nil
  st.side = side
  local liveMain = v == MAINVIEW and vLiveBags(v)
  for _, e in ipairs(items) do
    if side then
      local ok, where = pcall(B.SideOf, e)
      e.side = ok and where and side[where] and where or nil
    end
    -- (18 Nov) in a special bag: it shows in that bag's own group, one tile per item with the total
    -- (he: "everything grouped up showing how many shards it has in that bag from how much max like 12/16")
    local sp = not e.side and liveMain and e.bag and B.SpecialOf and B.SpecialOf(e.bag)
    if sp then e.cat, e.inSpecial = "emptyS_" .. sp.key, B.SpecialGrouped(sp.key) and "one" or "slots" end
    local group = e.side and ("side:" .. e.side) or e.cat
    local list
    if e.side then list = side[e.side] else byCat[e.cat] = byCat[e.cat] or {} list = byCat[e.cat] end
    local key = group .. ":" .. e.id
    local together = (merge and e.inSpecial ~= "slots") or e.inSpecial == "one"
    if together and seen[key] and e.side ~= "quiver" then
      seen[key].total = seen[key].total + e.count
      if e.bag then seen[key].inBags[e.bag] = true end
    else
      e.total = e.count
      e.inBags = e.bag and { [e.bag] = true } or {}
      list[#list + 1] = e
      if together then seen[key] = e end
    end
  end
  -- junk: the cheapest first, like Clean-up throws it away; and its value
  local value = 0
  local function cheapest(a, b)
    if a.first ~= b.first then return a.first and true or false end
    local va, vb = sellPrice(a.id) * a.total, sellPrice(b.id) * b.total
    if va ~= vb then return va < vb end
    return sortItems(a, b)
  end
  if byCat.junk then
    table.sort(byCat.junk, cheapest)
    for _, e in ipairs(byCat.junk) do value = value + sellPrice(e.id) * e.total end
  end
  if byCat.sell then
    table.sort(byCat.sell, sortItems)
    for _, e in ipairs(byCat.sell) do value = value + sellPrice(e.id) * e.total end
  end
  if side then
    for _, k in ipairs({ "always", "once", "haul" }) do table.sort(side[k], cheapest) end
    table.sort(side.bank, sortItems)
    -- (15 Nov) what a vendor really pays: Clean-up's own list of what it sells (the limit, quest needs...)
    if hasClean() and ns.Sell and ns.Sell.Items then
      local ok, _, v = pcall(ns.Sell.Items)
      if ok and v then value = v end
    end
  end
  st.junkValue = value
  -- your own groups show even when empty (so you can find them)
  for _, c in ipairs(ALL) do if c.custom then byCat[c.key] = byCat[c.key] or {} end end
  -- (15 Nov) holding something that's on Sell or Junk: that group starts with a green slot. Drop it
  -- there and it's kept (not sold, not thrown away). Works with the padlock on too.
  if held and v == MAINVIEW and DB.style ~= "grid" and hasClean() and not side then
    local kind = kindOfHeld(held)
    local list = (kind == 2 and byCat.sell) or (kind == 1 and byCat.junk)
    if list then table.insert(list, 1, { drop = "keep", cat = kind == 2 and "sell" or "junk" }) end
  end
  -- holding an item: every group you can put it in ends in a slot to drop it on (Junk shows up for it too)
  -- (the bag window only)
  -- (15 Nov) an item from one of the boxes beside the bag: no group slots (it would land in that group
  -- for good); it comes out on the slot at the start of Empty, at the bottom
  -- (16 Nov) with the padlock open the groups take it too: it leaves its box and goes in that group
  local heldBox = side and held and B.HeldBox and B.HeldBox(held) or nil
  if held and v == MAINVIEW and not B.heldSet then -- (19 Nov: the padlock only holds the groups; items still move between them)
    if hasClean() and not side then byCat.junk = byCat.junk or {} byCat.sell = byCat.sell or {} end
    -- (One grid has no groups to drop on: there you drop it on a chip)
    for key, list in pairs(byCat) do
      if DB.style ~= "grid" and placeable(key) and ((key ~= "junk" and key ~= "sell") or (hasClean() and not side)) then list[#list + 1] = { drop = key, cat = key } end
    end
  end
  -- (1.9) the quiver window beside the bag: its empty slots show there, in slot order with its arrows
  local qbag = side and B.QuiverShown and B.QuiverShown() or nil
  if qbag and live then
    local keep = {}
    for _, sl in ipairs(st.empties.S) do
      if sl.bag == qbag then
        side.quiver[#side.quiver + 1] = { bag = sl.bag, slot = sl.slot, cat = "emptyS", empty = true, inBags = { [sl.bag] = true } }
      else
        keep[#keep + 1] = sl
      end
    end
    st.empties.S = keep
    table.sort(side.quiver, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
  end
  -- empty slots (live only): every one (you can drop an item on any), or one cell with the number
  if live then
    -- (1.9.1) a special bag's empty slots: in that bag's own group ("Soul bag"), after its items
    local bySpec = {}
    for _, sl in ipairs(st.empties.S) do
      local sp = B.SpecialOf(sl.bag)
      local k = sp and ("S_" .. sp.key) or "S"
      bySpec[k] = bySpec[k] or {}
      table.insert(bySpec[k], sl)
    end
    -- (19 Nov) the reagent bag's empty slots are in Empty too, after the others, in green
    -- (he: "empty reagents only remove, color the slots green and place it on empty")
    local kinds = { [""] = "empty" }
    -- (18 Nov) a special bag's group shows no empty slots: its title says how full it is ("Soul bag 12/16")
    if liveMain then
      B.specSpace = {}
      for _, bag in ipairs(BAR) do
        local sp = B.SpecialOf(bag)
        if sp then
          local cat = "emptyS_" .. sp.key
          local n = C_Container.GetContainerNumSlots(bag) or 0
          local free = C_Container.GetContainerNumFreeSlots(bag) or 0
          local r = B.specSpace[cat] or { used = 0, size = 0 }
          r.used, r.size = r.used + (n - free), r.size + n
          B.specSpace[cat] = r
          byCat[cat] = byCat[cat] or {}
        end
      end
      -- (grouped kinds: no empty cells; slot by slot: their empty slots follow the items)
      for k in pairs(bySpec) do if k ~= "S" and B.SpecialGrouped(k:sub(3)) then bySpec[k] = nil end end
    end
    for k, list in pairs(bySpec) do st.empties[k] = list kinds[k] = "empty" .. k end
    local kindList = {}
    for kind in pairs(kinds) do kindList[#kindList + 1] = kind end
    table.sort(kindList)
    if #st.empties.R > 0 then kindList[#kindList + 1] = "R" kinds.R = "empty" end
    for _, kind in ipairs(kindList) do
      local cat = kinds[kind]
      local list = st.empties[kind]
      if #list > 0 then
        byCat[cat] = byCat[cat] or {} -- (a special bag's group already holds its items)
        if DB.emptyAll ~= false or st.freeMode then
          for _, sl in ipairs(list) do
            table.insert(byCat[cat], { bag = sl.bag, slot = sl.slot, cat = cat, empty = true, inBags = { [sl.bag] = true } })
          end
        else
          local inBags = {}
          for _, sl in ipairs(list) do inBags[sl.bag] = true end
          table.insert(byCat[cat], { bag = list[1].bag, slot = list[1].slot, cat = cat, total = #list, empty = true, inBags = inBags })
        end
      end
    end
  end
  if heldBox and DB.style ~= "grid" then
    byCat.empty = byCat.empty or {}
    table.insert(byCat.empty, 1, { drop = "keep", cat = "empty" })
  end
  return byCat, st
end
B.BuildCells = function(v, text) return buildCells(v, text) end -- (for the test scripts)

---------------------------------------------------------------------------
-- Putting an item in a group: pick it up, drop it on the slot at a group's end (or on its name)
---------------------------------------------------------------------------
local function shown(id, link) return link or ns.NameOf(id) or "That item" end
local function lockedSay() Print("the bag is locked: click the padlock (next to your bags) to change groups.") end
local function makeJunk(id, link)
  if DB.assign then DB.assign[id] = nil end
  local added = ns.Del.Add(id, link)
  Print(shown(id, link) .. (added and " is junk now: sold at a vendor, or thrown away when your bags fill up." or " is junk again (grey items always are)."))
  B.Changed()
end
StaticPopupDialogs["RUCKSACK_BAGS_JUNK"] = {
  text = "%s", button1 = "Yes", button2 = "No",
  OnAccept = function(_, data) if data then makeJunk(data.id, data.link) end end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
function B.PlaceIn(key, id, link)
  if not id or not placeable(key) then return end
  DB.assign = DB.assign or {}
  B.newIDs[id] = nil
  local from = B.heldFrom -- (the slot the stack came from: placeHeld notes it)
  B.heldFrom = nil
  local kind = junkKind(id, from and from[1], from and from[2])
  local isJunk = kind -- (junk or sell: out of either, it's kept)
  if key == "sell" then
    if not hasClean() then return end
    if kind == 2 then -- (its own slot again: keep it)
      local how = keepStack(id, from)
      Print(shown(id, link) .. (how == "stack" and ": this stack is kept, it's no longer sold." or " is kept: it's no longer sold by itself."))
      return B.Changed()
    end
    if ns.KeepItem(id, true) then
      local uses = ns.UsedFor(id, link)
      Print(shown(id, link) .. " is always kept" .. (uses[1] and (" (" .. uses[1] .. ")") or "") .. ".")
      return
    end
    -- (15 Nov) no vendor buys it: nothing to set
    if ns.Del.CantSell and ns.Del.CantSell(id) then
      Print(shown(id, link) .. " can't be sold: no vendor buys it.")
      return
    end
    if DB.assign then DB.assign[id] = nil end
    -- (15 Nov) a box asks how: always, all you have now, or just this stack
    if ns.Del.AskSell then
      ns.Del.AskSell(id, link, from and from[1], from and from[2])
    else
      ns.Del.AddSell(id, link)
      Print(shown(id, link) .. " is sold at every vendor from now on, and never thrown away.")
    end
    return B.Changed()
  end
  if key == "junk" then
    if not hasClean() then return end
    if kind == 1 then -- (its own slot again: keep it)
      ns.Del.Keep(id)
      Print(shown(id, link) .. " is kept: Clean-up leaves it alone.")
      return B.Changed()
    end
    if ns.KeepItem(id, true) then
      local uses = ns.UsedFor(id, link)
      Print(shown(id, link) .. " is always kept" .. (uses[1] and (" (" .. uses[1] .. ")") or "") .. ".")
      return
    end
    local uses = ns.UsedFor(id, link)
    if #uses > 0 then
      local dlg = StaticPopup_Show("RUCKSACK_BAGS_JUNK", "Make " .. shown(id, link) .. " junk?\n\nIt's used for:\n- " .. table.concat(uses, "\n- "))
      if dlg then dlg.data = { id = id, link = link } end
      return
    end
    return makeJunk(id, link)
  end
  local name = CAT[key].name
  if isJunk then keepStack(id, from) end -- (out of Junk: kept, so a grey one doesn't slide back)
  if not isJunk and DB.assign[id] == key then
    DB.assign[id] = nil
    local back = B.Category(id, link, nil, nil, true)
    Print(shown(id, link) .. " goes back where Rucksack puts it" .. (CAT[back] and (": " .. CAT[back].name) or "") .. ".")
  elseif not isJunk and not DB.assign[id] and B.Category(id, link, nil, nil, true) == key then
    Print(shown(id, link) .. " is in " .. name .. " already.")
  else
    DB.assign[id] = key
    Print(shown(id, link) .. (isJunk and " is kept, and" or "") .. " goes in " .. name .. " from now on.")
  end
  B.Changed()
end
local function placeHeld(key)
  local id, link = ns.CursorItem()
  if not id then return end
  if B.Sets and B.Sets.Of(id) then ClearCursor() return B.SetRefuse(id, link) end
  -- (the padlock is for arranging groups: taking something off Sell or Junk still works with it on)
  local heldWas = kindOfHeld(id)
  -- (15 Nov) a stack on its way to the bank: dropping it anywhere in the bag takes it back
  local bankFrom = B.HeldSlot and { B.HeldSlot(id) } or nil
  local wasBank = bankFrom and bankFrom[1] and B.BankSlot(bankFrom[1], bankFrom[2], id)
  -- (the slot it came from, noted before the cursor lets go of it)
  local from = hasClean() and ns.Del.HeldSlot and { ns.Del.HeldSlot(id) } or nil
  if from and not from[1] then from = nil end
  ClearCursor()
  local wasHidden = DB.hidden and DB.hidden[id]
  if wasHidden then
    DB.hidden[id] = nil
    Print(shown(id, link) .. " shows in your bag again.")
  end
  if wasBank then
    B.UnmarkBank(bankFrom[1], bankFrom[2])
    Print(shown(id, link) .. ": this stack stays in your bags, it's no longer sent to your bank.")
  end
  if key == "keep" then -- (One bag: a hidden or junk item dropped on the bag)
    local kind = heldWas
    if kind then
      local how = keepStack(id, from)
      Print(shown(id, link) .. (how == "stack" and ": this stack is kept, it's no longer sold." or kind == 2 and " is kept: it's no longer sold by itself." or " is kept: Clean-up leaves it alone."))
    end
    return B.Changed()
  end
  local gp = B.gap and B.gap.key == key and B.gap -- (19 Nov: dropped into the open space)
  -- (19 Nov) dropped into the space: the bag is drawn right away and the item snaps into it (he: "when
  -- I release it it should just snap on that place", not first back in its old place, then over)
  local function landNow()
    if InCombatLockdown() then return B.Changed() end
    B.snapID = id
    if B.HeldChanged then pcall(B.HeldChanged, nil) end -- (it's no longer lifted out: it's drawn at its new place)
    held = false -- (drawn as nothing held: no + slots; the bag's watcher still sees the change and tidies up)
    local ok = pcall(B.Draw)
    B.snapID = nil
    if not ok then B.Changed() end
  end
  if gp then
    B.RankAt(gp.g, gp.k, id)
    -- (already in that group: only its place changes)
    local okC, now = pcall(B.Category, id, link, from and from[1], from and from[2])
    if okC and now == key and not wasHidden then return landNow() end
  end
  if wasHidden and B.Category(id, link, nil, nil, true) == key and not DB.assign[id] then return B.Changed() end
  B.heldFrom = from
  B.PlaceIn(key, id, link)
  if gp then landNow() end
end

-- popups: name a new group, rename one, delete one, forget a character
local function editBoxOf(self) return self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox()) end
StaticPopupDialogs["RUCKSACK_BAGS_NEWGROUP"] = {
  text = "%s", button1 = "Make it", button2 = "Cancel", hasEditBox = true, maxLetters = 24,
  OnShow = function(self) local eb = editBoxOf(self) if eb then eb:SetText("") eb:SetFocus() end end,
  OnAccept = function(self, data) local eb = editBoxOf(self) B.NewGroup(eb and eb:GetText() or "", data and data.id, data and data.link) end,
  EditBoxOnEnterPressed = function(self)
    local p = self:GetParent()
    local data = p.data
    B.NewGroup(self:GetText() or "", data and data.id, data and data.link)
    p:Hide()
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["RUCKSACK_BAGS_RENAME"] = {
  text = "%s", button1 = "Rename", button2 = "Cancel", hasEditBox = true, maxLetters = 24,
  OnShow = function(self) local eb = editBoxOf(self) if eb and self.data then eb:SetText(CAT[self.data] and CAT[self.data].name or "") eb:SetFocus() eb:HighlightText() end end,
  OnAccept = function(self, key) local eb = editBoxOf(self) if eb then B.RenameGroup(key, eb:GetText()) end end,
  EditBoxOnEnterPressed = function(self) local p = self:GetParent() B.RenameGroup(p.data, self:GetText()) p:Hide() end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["RUCKSACK_BAGS_DELGROUP"] = {
  text = "%s", button1 = "Delete", button2 = "Keep it",
  OnAccept = function(_, key) B.DeleteGroup(key) end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["RUCKSACK_BAGS_FORGET"] = {
  text = "%s", button1 = "Forget", button2 = "Cancel",
  OnAccept = function(_, key) B.Forget(key) end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
function B.AskNewGroup(id, link)
  if DB.locked then return lockedSay() end
  local dlg = StaticPopup_Show("RUCKSACK_BAGS_NEWGROUP", id and ("A new group, with " .. shown(id, link) .. " in it. Its name:") or "A new group. Its name:")
  if dlg then dlg.data = id and { id = id, link = link } or nil end
end
function B.AskDelete(key)
  local c = CAT[key]
  if not c or not c.custom then return end
  if DB.locked then return lockedSay() end
  local dlg = StaticPopup_Show("RUCKSACK_BAGS_DELGROUP", "Delete the group \"" .. c.name .. "\"?\n\nIts items go back where Rucksack puts them.")
  if dlg then dlg.data = key end
end

-- a small menu (a group's right-click, and whose bags)
local menu = CreateFrame("Frame", "RucksackBagsMenu", f, ns.BACKDROP_TMPL)
menu:SetFrameStrata("DIALOG")
menu:EnableMouse(true)
if menu.SetBackdrop then
  menu:SetBackdrop(ns.SLOT_BACKDROP)
  menu:SetBackdropColor(0.07, 0.06, 0.04, 0.98)
  menu:SetBackdropBorderColor(0.62, 0.5, 0.3)
end
menu:Hide()
menu.rows, menu.dots = {}, {}
-- (18 Nov) a second, small menu to the right of a row with ">" (a character: Inventory / Bank). Its own
-- frame, not a child of the menu, so a click in it still lands when the menu closes.
B.subMenu = CreateFrame("Frame", "RucksackBagsSubMenu", f, ns.BACKDROP_TMPL)
B.subMenu:SetFrameStrata("DIALOG")
B.subMenu:SetFrameLevel(menu:GetFrameLevel() + 20)
B.subMenu:EnableMouse(true)
if B.subMenu.SetBackdrop then
  B.subMenu:SetBackdrop(ns.SLOT_BACKDROP)
  B.subMenu:SetBackdropColor(0.07, 0.06, 0.04, 0.98)
  B.subMenu:SetBackdropBorderColor(0.62, 0.5, 0.3)
end
B.subMenu:Hide()
B.subMenu.rows = {}
menu:SetScript("OnEvent", function(self) if not self:IsMouseOver() and not B.subMenu:IsMouseOver() then self:Hide() end end)
menu:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
menu:SetScript("OnHide", function(self) pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN") B.subMenu:Hide() end)
function B.ShowSubMenu(row, subs)
  local sm = B.subMenu
  for _, r in ipairs(sm.rows) do r:Hide() end
  local y, w = -6, 90
  for i, e in ipairs(subs) do
    local r = sm.rows[i]
    if not r then
      r = CreateFrame("Button", nil, sm)
      r:SetHeight(18)
      r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      r.text:SetPoint("LEFT", 2, 0)
      r.sub = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      r.sub:SetPoint("RIGHT", -2, 0)
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.08)
      r:SetScript("OnClick", function(self) menu:Hide() B.subMenu:Hide() if self.onClick then self.onClick() end end)
      sm.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 6, y)
    r:SetPoint("RIGHT", -6, 0)
    r.text:SetText(e.text or "")
    r.sub:SetText(e.sub or "")
    r.onClick = e.onClick
    r:Show()
    w = math.max(w, (r.text:GetStringWidth() or 0) + (r.sub:GetStringWidth() or 0) + 30)
    y = y - 18
  end
  sm:SetSize(w, -y + 6)
  sm:ClearAllPoints()
  sm:SetPoint("TOPLEFT", row, "TOPRIGHT", 8, 6)
  sm:Show()
end
local function menuRow(i)
  if menu.rows[i] then return menu.rows[i] end
  local r = CreateFrame("Button", nil, menu)
  r:SetHeight(18)
  r:SetPoint("LEFT", 6, 0)
  r:SetPoint("RIGHT", -6, 0)
  r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.text:SetPoint("LEFT", 2, 0)
  r.text:SetJustifyH("LEFT")
  r.sub = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  r.sub:SetPoint("RIGHT", -2, 0)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:SetScript("OnClick", function(self, button)
    if button == "RightButton" then if self.onRight then menu:Hide() self.onRight() end return end
    if self.subs then B.ShowSubMenu(self, self.subs) return end
    if self.onClick then menu:Hide() self.onClick() end
  end)
  r:SetScript("OnEnter", function(self)
    if self.subs then B.ShowSubMenu(self, self.subs) else B.subMenu:Hide() end
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.tip, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  menu.rows[i] = r
  return r
end
-- entries: { text, sub, onClick, onRight, tip } or { dots = function(color) }
function B.ShowMenu(anchor, entries)
  for _, r in ipairs(menu.rows) do r:Hide() end
  for _, d in ipairs(menu.dots) do d:Hide() end
  local y, w = -6, 120
  for i, e in ipairs(entries) do
    if e.dots then
      for j, c in ipairs(B.PALETTE) do
        local d = menu.dots[j]
        if not d then
          d = CreateFrame("Button", nil, menu)
          d:SetSize(12, 12)
          d.tex = d:CreateTexture(nil, "ARTWORK")
          d.tex:SetAllPoints()
          menu.dots[j] = d
        end
        d.tex:SetColorTexture(c[1], c[2], c[3], 1)
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", 8 + (j - 1) * 15, y - 3)
        d:SetScript("OnClick", function() menu:Hide() e.dots(c) end)
        d:Show()
      end
      y = y - 18
    else
      local r = menuRow(i)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 6, y)
      r:SetPoint("RIGHT", -6, 0)
      r.text:SetText(e.text or "")
      r.sub:SetText(e.sub or "")
      r.onClick, r.onRight, r.tip, r.subs = e.onClick, e.onRight, e.tip, e.subs
      if e.subs then r.sub:SetText((e.sub and e.sub ~= "" and (e.sub .. "  ") or "") .. "|cffffd100>|r") end
      r:Show()
      w = math.max(w, (r.text:GetStringWidth() or 0) + (r.sub:GetStringWidth() or 0) + 30)
      y = y - 18
    end
  end
  menu:SetSize(math.max(w, #B.PALETTE * 15 + 16), -y + 6)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menu:Show()
end
local function groupMenu(label)
  local c = CAT[label.key]
  if not c or not c.custom then return end
  if DB.locked then return lockedSay() end
  B.ShowMenu(label, {
    { text = "|cffffd100" .. c.name .. "|r" },
    { text = "Rename", onClick = function() local dlg = StaticPopup_Show("RUCKSACK_BAGS_RENAME", "New name for \"" .. c.name .. "\":") if dlg then dlg.data = c.key end end },
    { dots = function(col) B.ColorGroup(c.key, col) end },
    { text = "|cffff6b6bDelete group|r", onClick = function() B.AskDelete(c.key) end },
  })
end
-- whose bags: you first, then your other characters (right-click one to forget it)
function B.WhoMenu(anchor)
  local me = meKey()
  local keys = {}
  for k in pairs(DB.chars or {}) do if k ~= me then keys[#keys + 1] = k end end
  table.sort(keys)
  local mine = DB.chars and DB.chars[me]
  -- (18 Nov) he: "button your characters should show characters then it shows > and we can choose
  -- inventory or bank". You first, then the others; each opens a small menu: Inventory / Bank.
  local myName = (mine and mine.name) or UnitName("player") or "You"
  local _, myClass = UnitClass("player")
  local entries = { { text = classColor(myClass) .. myName .. "|r |cff8a8a8a(you)|r",
    subs = { { text = "Inventory", onClick = function() B.Open() end },
             { text = "Bank", sub = mine and mine.bankSeen and ago(mine.bankSeen) or "", onClick = function() B.ShowView(nil, "bank") end } } } }
  for _, k in ipairs(keys) do
    local r = DB.chars[k]
    entries[#entries + 1] = { text = classColor(r.class) .. (r.name or k) .. "|r" .. ((r.realm and mine and r.realm ~= mine.realm) and ("|cff8a8a8a-" .. r.realm .. "|r") or ""),
      sub = ago(r.seen), tip = "Pick Inventory or Bank: it opens in its own window, faded (you can look, not use).\nRight-click: forget this character.",
      subs = { { text = "Inventory", onClick = function() B.ShowView(k, "bags") end },
               { text = "Bank", sub = r.bankSeen and ago(r.bankSeen) or "", onClick = function() B.ShowView(k, "bank") end } },
      onRight = function() local dlg = StaticPopup_Show("RUCKSACK_BAGS_FORGET", "Forget " .. (r.name or k) .. "? Rucksack learns them again when you log in with them.") if dlg then dlg.data = k end end }
  end
  if #keys == 0 then entries[#entries + 1] = { text = "|cff8a8a8aLog in with your other characters once and they show here.|r" } end
  B.ShowMenu(anchor, entries)
end

-- the slot at a group's end while you hold an item: a green + (a red one on Junk)
local plusSlots, hoverKey = {}, nil
local function stylePlus(b)
  local hot = hoverKey == b.key
  local junk = b.key == "junk"
  local c = junk and { 1, 0.35, 0.3 } or b.key == "sell" and { 1, 0.82, 0.25 } or { 0.35, 1, 0.35 }
  b.plus:SetTextColor(c[1], c[2], c[3], hot and 1 or 0.6)
  for _, t in ipairs(b.dashes) do t:SetColorTexture(c[1], c[2], c[3], hot and 1 or 0.45) end
  b.bg:SetColorTexture(c[1] * 0.2, c[2] * 0.2, c[3] * 0.2, hot and 0.8 or 0.45)
end
local function plusSlot(key)
  if plusSlots[key] then return plusSlots[key] end
  local b = CreateFrame("Button", "RucksackBagsPlus_" .. key, body)
  b:SetSize(CELL, CELL)
  b.key = key
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.dashes = {}
  local seg = 4
  for k = 0, 5 do
    local pos = math.floor(k * (CELL - seg) / 5 + 0.5)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local t = b:CreateTexture(nil, "BORDER")
      if side == "TOP" then t:SetSize(seg, 1) t:SetPoint("TOPLEFT", pos, 0)
      elseif side == "BOTTOM" then t:SetSize(seg, 1) t:SetPoint("BOTTOMLEFT", pos, 0)
      elseif side == "LEFT" then t:SetSize(1, seg) t:SetPoint("TOPLEFT", 0, -pos)
      else t:SetSize(1, seg) t:SetPoint("TOPRIGHT", 0, -pos) end
      b.dashes[#b.dashes + 1] = t
    end
  end
  b.plus = b:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  b.plus:SetPoint("CENTER", 0, 1)
  b.plus:SetText("+")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.15)
  b:RegisterForClicks("LeftButtonUp")
  b:SetScript("OnReceiveDrag", function(self) placeHeld(self.key) end)
  b:SetScript("OnClick", function(self) placeHeld(self.key) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local name = CAT[self.key] and CAT[self.key].name or ""
    if self.key == "keep" then
      local hid = held and DB.hidden and DB.hidden[held]
      local onSell = held and kindOfHeld(held) == 2
      local hb, hs
      if held and B.HeldSlot then hb, hs = B.HeldSlot(held) end
      local toBank = hb and B.BankSlot(hb, hs, held)
      local box = held and B.HeldBox and B.HeldBox(held)
      GameTooltip:AddLine(hid and "|cff66dd66Show it again|r" or (toBank or box) and "|cff66dd66Take it out|r" or "|cff66dd66Keep it|r")
      GameTooltip:AddLine(hid and "It's hidden now: drop it here and the bag shows it again." or
        toBank and "It goes to your bank now: drop it here and it stays in your bags." or
        box == "once" and "Drop it here and this stack stays in your bag: no longer sold or thrown away." or
        box == "always" and "Drop it here and it stays in your bag: no longer sold or thrown away (all its stacks)." or
        onSell and "It's on Sell now: drop it here and it isn't sold any more (all its stacks)." or
        "It's junk now: drop it here and Clean-up leaves it alone (all its stacks).", 1, 1, 1, true)
    elseif self.key == "sell" then
      local again = held and kindOfHeld(held) == 2
      GameTooltip:AddLine("|cffffd100Sell|r")
      GameTooltip:AddLine(again and "It's on Sell now: drop it here to keep it." or
        "Drop it here and it's sold at every vendor (all its stacks), and never thrown away, not even when your bags are full.", 1, 1, 1, true)
    elseif self.key == "junk" then
      local again = held and kindOfHeld(held)
      GameTooltip:AddLine("|cffff8a8aJunk|r")
      GameTooltip:AddLine(again and "It's junk now: drop it here to keep it." or
        "Drop it here and it's junk: sold at a vendor, or thrown away when your bags fill up. All its stacks.", 1, 1, 1, true)
    else
      local again = held and DB.assign and DB.assign[held] == self.key
      GameTooltip:AddLine("|cff66dd66" .. name .. "|r")
      GameTooltip:AddLine(again and "You put it here: drop it again and it goes back where Rucksack puts it." or
        "Drop it here and it goes in " .. name .. " from now on, all its stacks.", 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  stylePlus(b)
  plusSlots[key] = b
  return b
end
B.PlusSlot = plusSlot -- (for Side.lua: the green slot in a box)

---------------------------------------------------------------------------
-- Moving groups: drag a group by its name. Out of a fight it lifts and follows the mouse, the
-- others slide out of the way, and it settles where you let go. (One grid, or in a fight: a gold
-- line shows where it lands, and the bag redraws after.)
---------------------------------------------------------------------------
local used = {}
local drawn, rects = {}, {} -- the groups as drawn (for moving), and their boxes (for hovering)
local moving, drag = nil, nil
local pendingDraw
local function cursorIn(frame)
  local x, y = GetCursorPosition()
  local s = frame:GetEffectiveScale() or 1
  return x / s - (frame:GetLeft() or 0), (frame:GetTop() or 0) - y / s
end
-- where groups go: each on its own row (Rows), or side by side (Packed)
local function layoutOf(list, W)
  local pos = {}
  local packed = DB.layout == "packed"
  local x, y, lineH = 0, 0, 0
  for i, g in ipairs(list) do
    if not packed then
      pos[i] = { x = 0, y = y }
      y = y + g.h + GROUP_GAP
    else
      if x > 0 and x + g.w > W then x, y, lineH = 0, y + lineH, 0 end
      pos[i] = { x = x, y = y }
      lineH = math.max(lineH, g.h + GROUP_GAP)
      x = x + g.w + 9
      if g.rows > 1 then x, y, lineH = 0, y + lineH, 0 end
    end
  end
  local total = packed and (y + lineH) or y
  return pos, math.max(PITCH, total - GROUP_GAP)
end
B.LayoutOf = layoutOf
local function placeGroup(g)
  for _, it in ipairs(g.frames) do
    it.f:ClearAllPoints()
    it.f:SetPoint("TOPLEFT", body, "TOPLEFT", it.x + g.dx, -(it.y + g.dy))
    it.f._rx, it.f._ry, it.f._tx, it.f._ty = it.x + g.dx, it.y + g.dy, it.x + g.dx, it.y + g.dy -- (19 Nov: the slide starts from here)
  end
end
local function box(r, g, b, a)
  local x = CreateFrame("Frame", nil, body, ns.BACKDROP_TMPL)
  if x.SetBackdrop then
    x:SetBackdrop(ns.SLOT_BACKDROP)
    x:SetBackdropColor(r * 0.25, g * 0.25, b * 0.25, a)
    x:SetBackdropBorderColor(r, g, b, 1)
  end
  x:Hide()
  return x
end
local liftBox, gapBox = box(1, 0.82, 0, 0.55), box(1, 0.82, 0, 0.12)
local anim = CreateFrame("Frame", nil, f)
anim:Hide()
local function resetCursor() if ResetCursor then ResetCursor() end end
local function finishDrag()
  drag, moving = nil, nil
  resetCursor()
  anim:Hide()
  liftBox:Hide()
  gapBox:Hide()
  B.Draw()
end
anim:SetScript("OnUpdate", function(self, dt)
  if not drag then self:Hide() return end
  if not drag.released then pcall(SetCursor, "UI_MOVE_CURSOR") end
  if InCombatLockdown() then return finishDrag() end -- (the game's buttons can't move in a fight)
  local g, W = drag.g, B.curW or 400
  if not drag.released then
    local cx, cy = cursorIn(body)
    local rest = {}
    for _, d in ipairs(drawn) do if d ~= g then rest[#rest + 1] = d end end
    local rpos = layoutOf(rest, W)
    local idx = #rest + 1
    if DB.layout ~= "packed" then
      for i, d in ipairs(rest) do if cy < rpos[i].y + d.h / 2 then idx = i break end end
    else
      local found
      for i, d in ipairs(rest) do
        if cy >= rpos[i].y - 4 and cy <= rpos[i].y + d.h + 4 then
          found = true
          if cx < rpos[i].x + d.w / 2 then idx = i break end
          idx = i + 1
        end
      end
      if not found then for i in ipairs(rest) do if cy < rpos[i].y then idx = i break end end end
    end
    if idx ~= drag.idx then
      drag.idx = idx
      local final = {}
      for _, d in ipairs(rest) do final[#final + 1] = d end
      table.insert(final, idx, g)
      local fpos = layoutOf(final, W)
      for i, d in ipairs(final) do d.tx, d.ty = fpos[i].x - d.x, fpos[i].y - d.y end
      drag.final = final
      gapBox:ClearAllPoints()
      gapBox:SetPoint("TOPLEFT", body, "TOPLEFT", fpos[idx].x - 3, -(fpos[idx].y - 3))
      gapBox:SetSize(g.w + 6, g.h + 6)
      gapBox:Show()
    end
    -- the group you hold follows the mouse
    local ny = cy - drag.oy - g.y
    ny = math.max(-g.y - LABEL, math.min((B.curH or 0) - g.y - g.h + LABEL, ny))
    g.dx, g.dy = DB.layout == "packed" and (cx - drag.ox - g.x) or 0, ny
    placeGroup(g)
  end
  -- the others (and, once you let go, that one too) slide to where they go
  local k = math.min(1, (dt or 0.016) * 16)
  local busy = false
  for _, d in ipairs(drawn) do
    if d ~= g or drag.released then
      local nx, ny = d.dx + (d.tx - d.dx) * k, d.dy + (d.ty - d.dy) * k
      if math.abs(d.tx - nx) < 0.6 then nx = d.tx end
      if math.abs(d.ty - ny) < 0.6 then ny = d.ty end
      if nx ~= d.dx or ny ~= d.dy then d.dx, d.dy = nx, ny placeGroup(d) busy = true end
    end
  end
  liftBox:ClearAllPoints()
  liftBox:SetPoint("TOPLEFT", body, "TOPLEFT", g.x + g.dx - 3, -(g.y + g.dy - 3))
  liftBox:SetSize(g.w + 6, g.h + 6)
  liftBox:Show()
  if drag.released and not busy then finishDrag() end
end)

-- the gold line (One grid, or in a fight)
local moveLine = f:CreateTexture(nil, "OVERLAY", nil, 7)
moveLine:SetColorTexture(1, 0.82, 0, 1)
moveLine:Hide()
-- where the group would go: the key it goes before (nil = the end), the group the line is drawn at, and which side
local function moveTarget()
  if #rects == 0 then return end
  local cx, cy = cursorIn(rects[1].parent)
  local best, bestD
  for i, r in ipairs(rects) do
    if cy >= r.y - 4 and cy <= r.y + r.h + 4 then
      local d = cx < r.x and r.x - cx or cx > r.x + r.w and cx - r.x - r.w or 0
      if not bestD or d < bestD then best, bestD = i, d end
    end
  end
  if not best then
    if cy < rects[1].y then return rects[1].key, rects[1], true end
    return nil, rects[#rects], false
  end
  local r = rects[best]
  if r.parent == body and DB.layout ~= "packed" and DB.style ~= "grid" then -- (Rows: above or below)
    if cy < r.y + r.h / 2 then return r.key, r, true, true end
    local nxt = rects[best + 1]
    return nxt and nxt.key or nil, r, false, true
  end
  if cx < r.x + r.w / 2 then return r.key, r, true end
  local nxt = rects[best + 1]
  return nxt and nxt.key or nil, r, false
end
local mover = CreateFrame("Frame", nil, f)
mover:Hide()
mover:SetScript("OnUpdate", function()
  local _, r, first, rows = moveTarget()
  if not r then moveLine:Hide() return end
  moveLine:ClearAllPoints()
  if rows then
    moveLine:SetPoint("TOPLEFT", r.parent, "TOPLEFT", r.x, -(first and (r.y - 3) or (r.y + r.h + 2)))
    moveLine:SetSize(r.w, 2)
  else
    moveLine:SetPoint("TOPLEFT", r.parent, "TOPLEFT", first and (r.x - r.gap / 2 - 1) or (r.x + r.w + r.gap / 2 - 1), -r.y)
    moveLine:SetSize(2, r.h)
  end
  moveLine:Show()
end)
local function startMove(self)
  if not self.key or ns.CursorItem() then return end
  if DB.locked then return lockedSay() end
  menu:Hide()
  GameTooltip:Hide()
  moving = self.key
  if DB.style ~= "grid" and not InCombatLockdown() then
    for _, d in ipairs(drawn) do
      if d.key == self.key then
        local cx, cy = cursorIn(body)
        drag = { g = d, ox = cx - d.x, oy = cy - d.y }
        liftBox:SetFrameLevel(body:GetFrameLevel())
        gapBox:SetFrameLevel(body:GetFrameLevel())
        anim:Show()
        return
      end
    end
  end
  mover:Show()
end
local function stopMove()
  local key = moving
  if drag then
    local g = drag.g
    drag.released = true
    resetCursor()
    if trashBtn:IsMouseOver() and CAT[g.key] and CAT[g.key].custom then -- (dropped on Delete group)
      for _, d in ipairs(drawn) do d.tx, d.ty = 0, 0 end
      B.AskDelete(g.key)
      return
    end
    if drag.final and drag.idx then
      local nxt = drag.final[drag.idx + 1]
      setOrder(g.key, nxt and nxt.key or nil)
      local fpos = layoutOf(drag.final, B.curW or 400)
      g.tx, g.ty = fpos[drag.idx].x - g.x, fpos[drag.idx].y - g.y
    else
      g.tx, g.ty = 0, 0
    end
    return
  end
  moving = nil
  mover:Hide()
  moveLine:Hide()
  resetCursor()
  if not key then return end
  if trashBtn:IsMouseOver() and CAT[key] and CAT[key].custom then return B.AskDelete(key) end
  if not f:IsMouseOver() then return end
  local before, r = moveTarget()
  if not r then return end
  if InCombatLockdown() then Print("the new order shows after the fight.") end
  B.MoveGroup(key, before)
end

-- the move cursor while you can grab a group (and while you drag one)
local function moveCursor() pcall(SetCursor, "UI_MOVE_CURSOR") end
local function canGrab(l)
  return not l.pane.static and not l.fixed and not DB.locked and not held and DB.style ~= "grid" and l.key and true or false
end
-- group names: drag to move; drop an item on one to put it there; right-click your own for its menu
local function label(i)
  local labels = PANE.labels
  if not labels[i] then
    local l = CreateFrame("Button", nil, PANE.body)
    l.pane = PANE
    l:SetHeight(LABEL)
    l.text = l:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    l.text:SetPoint("LEFT", 0, 0)
    l.text:SetJustifyH("LEFT")
    l.text:SetWordWrap(false)
    l.text:SetAlpha(0.85)
    -- (hover: a grip next to the name and the move cursor, so you can tell it can be grabbed)
    l.grip = l:CreateTexture(nil, "OVERLAY")
    l.grip:SetSize(9, 11)
    l.grip:SetTexture(ICONS .. "grip")
    l.grip:SetVertexColor(1, 0.82, 0)
    l.grip:Hide()
    l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    l:RegisterForDrag("LeftButton")
    l:SetScript("OnReceiveDrag", function(self) if not self.pane.static then placeHeld(self.key) end end)
    l:SetScript("OnClick", function(self, button)
      if self.pane.static then return end
      if button == "RightButton" then return groupMenu(self) end
      if ns.CursorItem() then return placeHeld(self.key) end
      if B.deleting and CAT[self.key] and CAT[self.key].custom then
        B.deleting = false
        B.AskDelete(self.key)
        B.Changed()
      end
    end)
    l:SetScript("OnDragStart", function(self) if not self.pane.static and not self.fixed then startMove(self) end end)
    l:SetScript("OnDragStop", function(self) if not self.pane.static and not self.fixed then stopMove(self) end end)
    l:SetScript("OnEnter", function(self)
      if moving or self.pane.static then return end
      local c = CAT[self.key]
      local grab = canGrab(self)
      if grab then
        self.text:SetAlpha(1)
        self.grip:ClearAllPoints()
        self.grip:SetPoint("LEFT", self, "LEFT", math.min((self.text:GetStringWidth() or 0) + 5, (self:GetWidth() or 100) - 10), 0)
        self.grip:Show()
        moveCursor()
      end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(c and c.name or "")
      if grab and not held then GameTooltip:AddLine("Drag to move this group", 1, 1, 1) end
      if held and placeable(self.key) then
        GameTooltip:AddLine(self.key == "junk" and "Drop the item here to make it junk." or self.key == "sell" and "Drop the item here: sold at vendors, never thrown away." or
          "Drop the item here and it goes in this group.", 0.6, 1, 0.6, true)
      end
      if DB.locked and not held then
        GameTooltip:AddLine("Locked: click the padlock to change groups.", 0.7, 0.7, 0.7, true)
      elseif self.fixed then
        GameTooltip:AddLine("In One bag, Junk always stays at the bottom.", 0.7, 0.7, 0.7, true)
      else
        if B.deleting and c and c.custom then GameTooltip:AddLine("Click to delete this group.", 1, 0.4, 0.4, true) end
        if c and c.custom then GameTooltip:AddLine("Right-click: rename, colour, delete.", 0.7, 0.7, 0.7, true) end
      end
      GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
      self.grip:Hide()
      self.text:SetAlpha(0.85)
      if not moving then resetCursor() end
    end)
    labels[i] = l
  end
  return labels[i]
end
local function hint(i)
  local hints = PANE.hints
  if not hints[i] then hints[i] = PANE.body:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall") end
  return hints[i]
end
local function matches(e, text)
  if B.hoverBag and not (e.inBags and e.inBags[B.hoverBag]) then return false end
  if e.empty then return text == "" and not B.filter end
  if B.filter and e.cat ~= B.filter then return false end
  if text == "" then return true end
  local name = (ns.NameOf(e.id, e.link) or ""):lower()
  return name:find(text, 1, true) ~= nil
end

-- putting a cell on screen (and, in Groups, remembering it as part of its group, for moving)
local cur, dropUsed, whereText = nil, {}, ""
-- (19 Nov) he: "make me move items in bag be smooth, animated, icons opening space in between".
-- Everything the bag places slides from where it was to where it goes (only when it was on show in
-- the last drawing too, out of a fight, not while a group is being dragged). DB.slide ~= false.
do
  local active = {}
  local driver = CreateFrame("Frame", nil, f)
  driver:Hide()
  local function put(fr) fr:ClearAllPoints() fr:SetPoint("TOPLEFT", fr._rbody, "TOPLEFT", fr._rx, -fr._ry) end
  driver:SetScript("OnUpdate", function(self, dt)
    local k = math.min(1, (dt or 0.016) * 14)
    local busy = false
    for fr in pairs(active) do
      if InCombatLockdown() or drag then
        fr._rx, fr._ry = fr._tx, fr._ty
      else
        fr._rx = fr._rx + (fr._tx - fr._rx) * k
        fr._ry = fr._ry + (fr._ty - fr._ry) * k
        if math.abs(fr._tx - fr._rx) < 0.5 then fr._rx = fr._tx end
        if math.abs(fr._ty - fr._ry) < 0.5 then fr._ry = fr._ty end
      end
      if not InCombatLockdown() then put(fr) end
      if fr._rx == fr._tx and fr._ry == fr._ty then active[fr] = nil else busy = true end
    end
    if not busy then self:Hide() end
  end)
  B.drawN = 0
  -- place fr at (x, y) in body: sliding there, or at once
  function B.SlideTo(fr, body, x, y)
    local was = fr._rdraw == B.drawN - 1 or fr._rdraw == B.drawN
    local slide = was and fr._rbody == body and fr._rx and DB and DB.slide ~= false and not drag and not InCombatLockdown()
      and f:IsShown() and (math.abs(fr._rx - x) + math.abs(fr._ry - y)) < 900
    -- (19 Nov) the item you just dropped into an open space lands there at once, no slide
    local ie = B.snapID and info[fr]
    if ie and ie.id == B.snapID and not ie.empty then slide = false end
    fr._rbody, fr._tx, fr._ty, fr._rdraw = body, x, y, B.drawN
    if slide then
      if fr._rx ~= x or fr._ry ~= y then active[fr] = true driver:Show() end
    else
      active[fr] = nil
      fr._rx, fr._ry = x, y
      put(fr)
    end
  end
  -- a frame moved somewhere else in the same drawing (the gap below): slide there
  function B.SlideMore(fr, x, y)
    if not fr._rbody or InCombatLockdown() then return end
    if fr._tx == x and fr._ty == y then return end
    fr._tx, fr._ty = x, y
    if DB and DB.slide == false then fr._rx, fr._ry = x, y put(fr) return end
    active[fr] = true
    driver:Show()
  end
  function B.SlideStop() for fr in pairs(active) do fr._rx, fr._ry = fr._tx, fr._ty put(fr) end wipe(active) driver:Hide() end
end
-- (19 Nov) the reagent bag's slots: the button's own textures tinted green ("empty": all of them, the
-- slot picture too; "item": only its frame), nil: back to normal. Rucksack's own extras are left alone.
function B.GreenSlot(b, d, how, cr, cg, cb) -- (19 Nov: cr, cg, cb another colour: red for armour set items)
  if d.greened then
    for _, t in ipairs(d.greened) do t:SetVertexColor(1, 1, 1) end
    d.greened = nil
  end
  if not how or not b.GetRegions then return end
  local mine = {}
  for _, v in pairs(d) do if type(v) == "table" then mine[v] = true if rawget(v, 1) then for _, t in ipairs(v) do mine[t] = true end end end end
  local keep = { [b.IconBorder or 0] = true, [b.IconOverlay or 0] = true, [b.IconOverlay2 or 0] = true }
  local list = {}
  local normal = b.GetNormalTexture and b:GetNormalTexture()
  if how == "item" then
    if normal then list[1] = normal end
  else
    for _, r in ipairs({ b:GetRegions() }) do
      if r.SetVertexColor and r.GetObjectType and r:GetObjectType() == "Texture" and not mine[r] and not keep[r] then list[#list + 1] = r end
    end
    if normal then local seen = false for _, t in ipairs(list) do if t == normal then seen = true end end if not seen then list[#list + 1] = normal end end
  end
  for _, t in ipairs(list) do t:SetVertexColor(cr or 0.45, cg or 1, cb or 0.45) end
  d.greened = list
end
local function addFrame(fr, x, y)
  B.SlideTo(fr, PANE.body, x, y)
  if cur then cur.frames[#cur.frames + 1] = { f = fr, x = x, y = y } end
end
-- (19 Nov) holding an item over one of the groups: its icons slide apart to open a space under the
-- mouse, and the group's + slot moves into it. Dropping it there puts the item at that place (its
-- rank in B.rank, between its new neighbours).
do
  local function cellXY(g, p, cols)
    return g.x + ((p - 1) % cols) * PITCH, g.y + LABEL + math.floor((p - 1) / cols) * PITCH
  end
  local function close()
    local gp = B.gap
    B.gap = nil
    if not gp then return end
    for _, it in ipairs(gp.g.frames) do B.SlideMore(it.f, it.x, it.y) end
  end
  B.CloseGap = close
  function B.GapTick(key)
    local g
    if key and key ~= "keep" and key ~= "junk" and key ~= "sell" and plusSlots[key] then
      for _, d in ipairs(drawn) do if d.key == key then g = d break end end
    end
    -- the cells: the group's frames after its name; the last one must be its + slot
    local cells = {}
    if g and g.frames then for i = 2, #g.frames do cells[#cells + 1] = g.frames[i] end end
    if not g or #cells < 2 or cells[#cells].f ~= plusSlots[key] then return close() end
    local cols = B.curCols or 10
    local n = #cells - 1
    local cx, cy = cursorIn(PANE.body)
    local col = math.max(0, math.min(cols - 1, math.floor((cx - g.x) / PITCH)))
    local row = math.max(0, math.floor((cy - g.y - LABEL) / PITCH))
    local k = math.max(1, math.min(n + 1, row * cols + col + 1))
    local old = B.gap
    if old and old.g == g and old.k == k then return end
    if old and old.g ~= g then close() end
    for j = 1, n do
      local p = j < k and j or j + 1
      B.SlideMore(cells[j].f, cellXY(g, p, cols))
    end
    B.SlideMore(cells[#cells].f, cellXY(g, k, cols))
    B.gap = { key = key, k = k, g = g }
  end
  -- the dropped item's place: between the items left and right of the gap
  function B.RankAt(g, k, id)
    B.rank = B.rank or { n = 0 }
    local R = B.rank
    local list = {}
    for _, e in ipairs(g.items or {}) do if e.id and not e.drop then list[#list + 1] = e end end
    local before, after = list[k - 1], list[k]
    if before and before.id == id then before = list[k - 2] end
    if after and after.id == id then after = list[k + 1] end
    local a, b = before and R[before.id], after and R[after.id]
    R[id] = (a and b and (a + b) / 2) or (a and a + 0.5) or (b and b - 0.5) or (R.n + 1)
  end
end
local function show(e, x, y, text, withDot)
  if e.drop then
    local b = plusSlot(e.drop)
    dropUsed[b] = true
    addFrame(b, x, y)
    stylePlus(b)
    b:Show()
    return
  end
  if e.ghost then
    PANE.ghostN = PANE.ghostN + 1
    local g = ghostButton(PANE.ghostN)
    g.id, g.where = e.id, whereText
    g.icon:SetTexture(e.icon)
    g.count:SetText(e.total and e.total > 1 and e.total or "")
    if g.SetBackdropBorderColor then g:SetBackdropBorderColor(qColor(e.quality)) end
    g.mark:SetShown(e.cat == "junk")
    g.coin:SetShown(e.cat == "sell")
    local c = withDot and CAT[e.cat]
    if c then g.dot:SetColorTexture(c.color[1], c.color[2], c.color[3], 1) g.dot:Show() else g.dot:Hide() end
    g:SetAlpha(matches(e, text) and 0.6 or 0.15)
    addFrame(g, x, y)
    g:Show()
    return
  end
  local b = getButton(e.bag, e.slot)
  used[b] = true
  info[b] = e
  addFrame(b, x, y)
  b:Show()
  local d = deco[b]
  -- (19 Nov) a locked set item: a see-through red cover that takes the mouse (Sets.lua)
  if B.Sets then B.Sets.Cover(b, e, not e.empty and e.id and B.Sets.Of(e.id) and true or false) end
  -- (the game's own button code differs between clients: if a step fails, say so once and carry on)
  local ok, err = pcall(paint, b, e.empty and { bag = e.bag, slot = e.slot } or e, e.total)
  if not ok and not B.paintError then
    B.paintError = err
    Print("Bags: a button couldn't be drawn fully (" .. tostring(err) .. "). Please tell the author.")
  end
  -- (16 Nov) a current quest needs it (he: "if it is current quest item place yellow circle ! in top
  -- right corner on top"): that's why it isn't sold or thrown away. Not on the Quest group's own items.
  -- (17 Nov) he: "remove that yellow square, make ! bigger to see easily quest item, and make !? sign
  -- for a item that we use in the quest but its not specified as quest item". So: "!" on a quest item
  -- (the game calls it one), "!?" on an ordinary item a quest you have needs (it's kept for it).
  -- (18 Nov) three marks, he: "different markings for quest item that start quest, quest item that is
  -- originally quest item and items that sometimes can be quest items, like spider legs": "start" = a
  -- big yellow "!" (only while that quest isn't taken), "quest" = the game's gold quest border, no
  -- letter, "maybe" = "!?" with how many your quests still need.
  local needed, left = false, nil
  if not e.empty then needed, left = B.QuestMark(e.id, e.link, e.bag, e.slot) needed = needed or false end
  local letter = needed == "start" or needed == "maybe"
  if letter and d.neededKind ~= needed then
    d.neededKind = needed
    d.needed:SetTexture(ICONS .. (needed == "start" and "questbang" or "questmaybe"))
    if needed == "start" then d.needed:SetSize(20, 20) else d.needed:SetSize(26, 26) end
  end
  d.needed:SetShown(letter)
  d.qborder:SetShown(needed == "quest")
  d.qnum:SetText(needed == "maybe" and left and left > 0 and left < 1000 and tostring(left) or "")
  d.mark:SetShown(e.cat == "junk" and not needed)
  d.coin:SetShown(e.cat == "sell" and not needed)
  d.arrow:SetShown(e.upgrade and true or false)
  d.quest:SetShown(e.cat == "quest" and withDot ~= true and not needed)
  if e.first then d.edge:SetVertexColor(1, 0.25, 0.25) d.edge:Show()
  elseif e.next then d.edge:SetVertexColor(0.3, 1, 0.3) d.edge:Show()
  elseif e.isNew then d.edge:SetVertexColor(1, 0.82, 0) d.edge:Show()
  else d.edge:Hide() end
  d.tag:SetText(e.boe and "|cff7fd4ffBoE|r" or e.open and "|cffffd100open|r" or "")
  local c = withDot and CAT[e.cat]
  if c and not e.empty then d.dot:SetColorTexture(c.color[1], c.color[2], c.color[3], 1) d.dot:Show() else d.dot:Hide() end
  if B.VendorMark then pcall(B.VendorMark, b, d, e) end -- (19 Nov) a vendor pays more: a coin top left
  d.dim:SetShown(not matches(e, text))
  -- (1.9.1) in a special bag: its colour
  local sp = e.bag and B.SpecialOf and B.SpecialOf(e.bag)
  B.GreenSlot(b, d, nil)
  if sp and DB.specialTint ~= false then
    local sc = B.SpecialColor(sp.key)
    d.tint:SetColorTexture(sc[1], sc[2], sc[3], e.empty and 0.28 or 0.14)
    d.tint:Show()
    if d.thick then d.thick = nil for i, t in ipairs(d.lines) do if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end end end
    for _, t in ipairs(d.lines) do t:SetColorTexture(sc[1], sc[2], sc[3], 0.9) t:Show() end
  elseif REAGENT and e.bag == REAGENT and (DB.style == "grid" or e.empty) then
    -- (18 Nov) the reagent bag's slots in green (he: "mark reagent bag slots green"); 19 Nov: a green
    -- border only, no see-through fill (he: "border should be green not just simple overlay")
    -- 19 Nov, again: no drawn border either; the slot itself is tinted green (he: "like original slot
    -- but with green ... tint"): an empty slot all of it, a slot with an item its frame
    d.tint:Hide()
    for _, t in ipairs(d.lines) do t:Hide() end
    B.GreenSlot(b, d, e.empty and "empty" or "item")
  else
    d.tint:Hide()
    for _, t in ipairs(d.lines) do t:Hide() end
    -- (19 Nov) an item in one of your equipment sets: a red border round its slot (he: "slot should be
    -- red like some kind a red border, that armor cant be moved from there")
    if not e.empty and e.id and B.Sets and B.Sets.Of(e.id) then
      d.thick = true
      for i, t in ipairs(d.lines) do
        if i <= 2 then t:SetHeight(2) else t:SetWidth(2) end
        t:SetColorTexture(1, 0.18, 0.15, 0.95)
        t:Show()
      end
    end
  end
end

-- (18 Nov) "start": it starts a quest you haven't taken yet; "quest": a quest item (the game calls it
-- one); "maybe": an ordinary item a quest you have needs (2nd value: how many it still needs, by what
-- your bags hold); nil: none of these. (17 Nov's "bang" is now "start" or "quest".)
function B.QuestMark(id, link, bag, slot)
  if not id then return nil end
  local isQuest
  if bag and slot and ns.GetQuestInfo then
    local ok, qi, qid, active = pcall(ns.GetQuestInfo, bag, slot)
    if ok and type(qi) == "table" then isQuest, qid, active = qi.isQuestItem, qi.questID, qi.isActive
    elseif ok then isQuest = qi end
    if qid and not active then return "start" end
  end
  local classID = C_Item and C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(id))
  if classID == nil and GetItemInfoInstant then classID = select(6, GetItemInfoInstant(id)) end
  if classID == 12 or isQuest == true then return "quest" end
  if hasClean() and ns.Del and ns.Del.QuestNeed then
    local ok, n = pcall(ns.Del.QuestNeed, id, link)
    if ok and n and n > 0 then
      if n == math.huge then return "start" end
      local have = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0
      return "maybe", n - (tonumber(have) or 0)
    end
  end
end
-- (15 Nov) for Side.lua: a button painted like an empty bag slot (the slot you drop items on)
function B.PaintEmpty(b) return pcall(paint, b, { bag = 0, slot = 0 }) end
-- (15 Nov) for Side.lua: put a cell in another pane (the column on the right of the bag)
function B.ShowIn(P, e, x, y, text)
  PANE = P
  local ok, err = pcall(show, e, x, y, text)
  PANE = MAIN
  if not ok and not B.sideError then B.sideError = err Print("Bags: the boxes couldn't be drawn fully (" .. tostring(err) .. "). Please tell the author.") end
end
function B.Held() return held end
-- in a fight the game's item buttons may not be moved: refresh them where they are, and lay out after the fight
local function fightLock()
  if not InCombatLockdown() then return false end
  for _, row in pairs(buttons) do
    for _, b in pairs(row) do if b.IsProtected and b:IsProtected() then return true end end
  end
  return false
end
local function repaintInPlace(text)
  for b, e in pairs(info) do
    if not e.empty and e.bag then
      local it = C_Container.GetContainerItemInfo(e.bag, e.slot)
      pcall(function()
        if not it then SetItemButtonTexture(b, nil) SetItemButtonCount(b, 0)
        else
          SetItemButtonDesaturated(b, it.isLocked and true or false)
          if not DB.merged then SetItemButtonCount(b, it.stackCount or 1) end
        end
        cooldown(b, e.bag, e.slot)
      end)
      if deco[b] then deco[b].dim:SetShown(not matches(e, text)) end
    end
  end
end

local function measure(l, s)
  l.text:SetWidth(0)
  l.text:SetText(s)
  return math.ceil(l.text:GetStringWidth() or 0)
end
-- the header icons and the bags row, as things are now
local function drawTop(st)
  local oneBag = DB.style == "grid"
  setIcon(lookBtn, oneBag and "onebag" or DB.layout == "packed" and "groups" or "rows")
  setIcon(stackBtn, DB.merged and "merged" or "separate")
  stackBtn:SetAlpha(oneBag and 0.35 or 1) -- (One bag shows the real stacks)
  bankBtn:ClearAllPoints()
  bankBtn:SetPoint("RIGHT", tidyBtn, "LEFT", -3, 0)
  local v2 = B.view2
  lightUp(bankBtn, v2 and v2.kind == "bank" and not v2.who and B.VIEW.frame:IsShown() or false)
  lightUp(whoBtn, v2 and v2.who and B.VIEW.frame:IsShown() or false)
  drawBar(st)
  setIcon(lockBtn, DB.locked and "locked" or "unlocked")
  setIcon(B.pinBtn, DB.pinned and "pinned" or "unpinned")
  lightUp(B.pinBtn, DB.pinned)
  setIcon(B.sideBtn, "side_" .. (DB.sidePos or "tr"))
  B.sideBtn:SetAlpha(DB.sideHidden and 0.45 or 1) -- (25 Nov: dim while the boxes are hidden)
  lightUp(lockBtn, DB.locked)
  lightUp(B.autoBtn, DB.autoSort ~= false) -- (19 Nov: gold while automatic sorting is on)
  local off = DB.locked or oneBag
  newBtn:SetAlpha(off and 0.35 or 1)
  trashBtn:SetAlpha(off and 0.35 or 1)
  lightUp(trashBtn, B.deleting and not off)
  chev.icon:SetTexCoord(0, 1, DB.barOpen and 1 or 0, DB.barOpen and 0 or 1)
end
-- One bag: no groups. On top the bag, sorted (by kind, quality or name), new first, then the empty
-- slots; at the bottom Junk, a fixed group. Holding an item: a red + on Junk (make it junk), and a
-- green + on the bag when it's junk already (keep it).
local KIND = { weapon = 1, armor = 2, food = 3, consumable = 4, trade = 5, quest = 6, other = 7 }
local EMPTY_ORDER = { empty = 1, emptyS = 3 }
for n, sp in ipairs(B.SPECIAL) do EMPTY_ORDER["emptyS_" .. sp.key] = 3 + n end
local function drawOneBag(byCat, text, cols, W, st, canDrop)
  local items, junk, sell, empties = {}, {}, {}, {}
  for _, list in pairs(byCat) do
    for _, e in ipairs(list) do
      if e.empty then empties[#empties + 1] = e
      elseif e.drop then -- (One bag puts its own)
      elseif e.cat == "junk" then junk[#junk + 1] = e
      elseif e.cat == "sell" then sell[#sell + 1] = e
      else items[#items + 1] = e end
    end
  end
  table.sort(sell, sortItems)
  table.sort(junk, function(a, b) -- (cheapest first, the first to go in front)
    if (a.first and true or false) ~= (b.first and true or false) then return a.first and true or false end
    local va, vb = sellPrice(a.id) * (a.total or 1), sellPrice(b.id) * (b.total or 1)
    if va ~= vb then return va < vb end
    return sortItems(a, b)
  end)
  local by = DB.sortBy or "kind"
  if st and st.freeMode then
    -- Free: no sorting. Items and empty slots together, in the order of your real bag slots
    by = "slot"
    for _, e in ipairs(empties) do items[#items + 1] = e end
    wipe(empties)
    if not B.bagRank then B.bagRank = {} for i, b in ipairs(BAGS) do B.bagRank[b] = i end end
  end
  for _, e in ipairs(items) do
    if e.id then -- (18 Nov: in Free mode the empty slots are in this list too; they have no item)
      if not e.kind then local ok, k = pcall(B.Category, e.id, e.link, e.bag, e.slot, true) e.kind = ok and k or "other" end
      e.sortName = e.sortName or ns.NameOf(e.id, e.link) or ""
    else
      e.kind, e.sortName = e.kind or "other", e.sortName or ""
    end
  end
  table.sort(items, function(a, b)
    if by == "slot" then
      local ra, rb = B.bagRank[a.bag or 0] or 99, B.bagRank[b.bag or 0] or 99
      if ra ~= rb then return ra < rb end
      return (a.slot or 0) < (b.slot or 0)
    end
    if (a.isNew and true or false) ~= (b.isNew and true or false) then return a.isNew and true or false end
    if by == "kind" then
      local ka, kb = KIND[a.kind] or 7, KIND[b.kind] or 7
      if ka ~= kb then return ka < kb end
    end
    if by ~= "name" and (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
    if a.sortName ~= b.sortName then return a.sortName < b.sortName end
    if (a.total or 0) ~= (b.total or 0) then return (a.total or 0) > (b.total or 0) end
    return ((a.bag or 0) * 100 + (a.slot or 0)) < ((b.bag or 0) * 100 + (b.slot or 0))
  end)
  local sideOn = st and st.side and true or false -- (15 Nov: Junk and Sell are boxes on the right)
  local drop = canDrop and held and (hasClean() or (DB.hidden and DB.hidden[held]))
  -- (15 Nov) a Sell or Junk item on your cursor: the green "keep" slot is the first one of that
  -- group below (padlock on or off); a hidden item still gets it on the bag
  local keepKind = not sideOn and canDrop and held and kindOfHeld(held)
  if canDrop and held and not keepKind and DB.hidden and DB.hidden[held] then items[#items + 1] = { drop = "keep", cat = "keep" } end
  table.sort(empties, function(a, b)
    if a.cat ~= b.cat then return (EMPTY_ORDER[a.cat] or 9) < (EMPTY_ORDER[b.cat] or 9) end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
  end)
  for _, e in ipairs(empties) do items[#items + 1] = e end
  for i, e in ipairs(items) do show(e, ((i - 1) % cols) * PITCH, math.floor((i - 1) / cols) * PITCH, text) end
  local height = math.max(1, math.ceil(#items / cols)) * PITCH - GAP
  if not PANE.static then rects[#rects + 1] = { key = "keep", parent = PANE.body, x = 0, y = 0, w = W, h = height, gap = 0 } end
  -- at the bottom: Sell, then Junk (fixed groups); holding an item, each gets its +
  local heldKind = drop and kindOfHeld(held)
  local canMark = drop and hasClean() and not sideOn and not (DB.hidden and DB.hidden[held])
  local li = 0
  local function fixedGroup(key, list, title, value)
    local plus = canMark and heldKind ~= (key == "sell" and 2 or 1)
    if keepKind == (key == "sell" and 2 or 1) then table.insert(list, 1, { drop = "keep", cat = key }) end
    if #list == 0 and not plus then return end
    if plus then list[#list + 1] = { drop = key, cat = key } end
    local y = height + GROUP_GAP + 2
    li = li + 1
    local l = label(li)
    l.key, l.fixed = key, true
    l:SetWidth(W)
    l.text:SetWidth(W)
    l.text:SetText(title .. (value > 0 and ("   |cff8a8a8a" .. ns.Pocket.Coins(value) .. "|r") or ""))
    addFrame(l, 1, y)
    l:Show()
    for i, e in ipairs(list) do show(e, ((i - 1) % cols) * PITCH, y + LABEL + math.floor((i - 1) / cols) * PITCH, text) end
    local gh = LABEL + math.ceil(#list / cols) * PITCH - GAP
    if not PANE.static then rects[#rects + 1] = { key = key, parent = PANE.body, x = 0, y = y, w = W, h = gh, gap = 0 } end
    height = y + gh
  end
  local function worth(list) local v = 0 for _, e in ipairs(list) do if e.id then v = v + sellPrice(e.id) * (e.total or 1) end end return v end
  fixedGroup("sell", sell, "|cffffd100Sell|r", worth(sell))
  fixedGroup("junk", junk, "|cffff8a8aJunk|r", worth(junk))
  return height, #items + #junk + #sell
end
-- the groups (Rows or Packed), each remembered with its frames so it can be moved
local function drawGroups(byCat, order, text, cols, W)
  local list, li, total = {}, 0, 0
  for _, c in ipairs(order) do
    local items = byCat[c.key]
    local space = c.spec and PANE == MAIN and B.specSpace and B.specSpace[c.key]
    if items and (#items > 0 or (c.custom and not PANE.static) or space) then
      li = li + 1
      local l = label(li)
      local n = #items
      total = total + n
      local name = c.name
      if space then name = name .. "  |cffffffff" .. space.used .. "/" .. space.size .. "|r" end -- (18 Nov: "Soul bag 12/16")
      local col = (c.custom or space) and ("|cff%02x%02x%02x"):format(math.floor(c.color[1] * 255), math.floor(c.color[2] * 255), math.floor(c.color[3] * 255))
        or c.key == "junk" and "|cffff8a8a" or c.key == "sell" and "|cffffd100" or "|cffa8946a"
      if B.deleting and c.custom and not DB.locked then name = "|cffff5050x|r " .. name .. "  |cffff6b6bclick to delete|r" end
      local nameW = measure(l, col .. name .. "|r")
      local rows = math.ceil(n / cols)
      local gw = n > 0 and (math.min(n, cols) * PITCH - GAP) or 0
      local extra = (c.key == "sets" and 18) or (c.key == "haulah" and B.HaulButton and 104) or 0 -- (19 Nov: the padlock, Haul's button)
      local w = math.min(W, math.max(gw, nameW + 2 + extra, n == 0 and 190 or 0))
      local h = LABEL + (n > 0 and (rows * PITCH - GAP) or 14)
      list[#list + 1] = { key = c.key, c = c, items = items, n = n, w = w, h = h, rows = rows, l = l, nameW = nameW }
    end
  end
  local pos, height = layoutOf(list, W)
  if B.Sets and PANE == MAIN then B.Sets.LockButton(nil) end
  if B.HaulButton and PANE == MAIN then B.HaulButton(nil) end
  for i, g in ipairs(list) do
    g.x, g.y, g.dx, g.dy, g.tx, g.ty, g.frames = pos[i].x, pos[i].y, 0, 0, 0, 0, {}
    cur = g
    local l = g.l
    l.key, l.fixed = g.key, nil
    l:SetWidth(g.w)
    l.text:SetWidth(g.w)
    addFrame(l, g.x + 1, g.y)
    l:Show()
    -- (19 Nov: the padlock is gone, set items are always kept)
    if g.key == "haulah" and B.HaulButton and PANE == MAIN then B.HaulButton(l, g.nameW) end -- (19 Nov: "Sort into groups")
    for j, e in ipairs(g.items) do
      show(e, g.x + ((j - 1) % cols) * PITCH, g.y + LABEL + math.floor((j - 1) / cols) * PITCH, text)
    end
    if g.n == 0 then
      local h = hint(i)
      h:SetText(g.c.spec and "empty" or "pick an item up and drop it here")
      addFrame(h, g.x + 2, g.y + LABEL + 2)
      h:Show()
    end
    cur = nil
    if not PANE.static then
      drawn[#drawn + 1] = g
      rects[#rects + 1] = { key = g.key, parent = PANE.body, x = g.x, y = g.y, w = g.w, h = g.h, gap = 9 }
    end
  end
  return height, total
end
-- footer: free slots, what the junk is worth, money (or, for a look at another character or the bank, what's there)
local function drawFoot(foot, st, rec, v, W)
  foot:SetWidth(W)
  local clean = hasClean()
  foot.junk:Hide()
  if vLiveBags(v) then
    local free = st.free
    local keep = clean and (ns.del.minFree or 2) or nil
    local col = keep and free < keep and "|cffff5a50" or keep and free == keep and "|cffffd100" or "|cff5cd65c"
    foot.free:SetText(col .. free .. "|r|cff8a8a8a / " .. st.total .. " free" .. (keep and ("   keep " .. keep) or "") .. "|r" ..
      (st.rTotal > 0 and ("   |cff7bd66areagents " .. st.rFree .. "/" .. st.rTotal .. "|r") or ""))
    foot.money:SetText(ns.Pocket.Coins(GetMoney and GetMoney() or 0))
    if clean and (st.junkValue or 0) > 0 and DB.style ~= "grid" then
      local atVendor = MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()
      foot.junk:SetText((atVendor and "|cff66dd66sells here|r " or "|cff8a8a8asells for|r ") .. ns.Pocket.Coins(st.junkValue))
      local fits = (foot.free:GetStringWidth() or 0) + (foot.junk:GetStringWidth() or 0) + (foot.money:GetStringWidth() or 0) + 28 <= W
      foot.junk:SetShown(fits)
    end
  elseif vLiveBank(v) then
    foot.free:SetText("|cff5cd65c" .. st.free .. "|r|cff8a8a8a / " .. st.total .. " free in the bank|r")
    foot.money:SetText("")
  else
    local n = 0
    for _ in pairs(st.data or {}) do n = n + 1 end
    foot.free:SetText("|cff8a8a8a" .. n .. (n == 1 and " kind of item" or " kinds of items") .. "|r")
    foot.money:SetText(v.kind == "bags" and rec and rec.money and ns.Pocket.Coins(rec.money) or "")
  end
end
-- draw one window's items (the pane P), for the view v; returns the height and how many cells
local function drawItems(P, v, text, cols, W)
  PANE = P
  P.ghostN = 0
  for _, l in ipairs(P.labels) do l:Hide() end
  for _, h in pairs(P.hints) do h:Hide() end -- (pairs: the list has gaps, one hint per empty group)
  local byCat, st = buildCells(v, text)
  local height, total
  if DB.style == "grid" then
    height, total = drawOneBag(byCat, text, cols, W, st, not P.static)
  else
    height, total = drawGroups(byCat, B.Ordered(), text, cols, W)
  end
  for i = P.ghostN + 1, #P.ghosts do P.ghosts[i]:Hide() P.ghosts[i].id = nil end
  PANE = MAIN
  return height, total, st
end
-- the game's buttons nobody showed this time: hidden (your bags' in the bag, your bank's in the second window)
local function hideUnused(bags)
  for bag, row in pairs(buttons) do
    if (IS_BAG[bag] and true or false) == bags then
      for _, b in pairs(row) do if not used[b] then b:Hide() info[b] = nil end end
    end
  end
end

-- the bags row opens and closes with a slide: barH is how far it's open now
local barH = 0
local function placeParts()
  local m = B.metrics
  if not m then return end
  local top = HEAD + barH
  if B.tools then -- (19 Nov) the tool row, under the bags row (which slides in between)
    B.tools:ClearAllPoints()
    B.tools:SetPoint("TOPLEFT", 8, -(HEAD + barH))
    B.tools:SetWidth(m.W)
    top = top + B.TOOL_H
  end
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", 8, -HEAD)
  bar:SetWidth(m.W)
  bar:SetHeight(math.max(1, barH))
  bar:SetAlpha(math.min(1, barH / BAR_H))
  bar:SetShown(barH > 1)
  body:ClearAllPoints()
  body:SetPoint("TOPLEFT", 8, -top)
  local y = top + m.height + 6
  foot:ClearAllPoints()
  foot:SetPoint("TOPLEFT", 8, -y)
  f:SetSize(m.W + 16, y + 24)
end
local barAnim = CreateFrame("Frame", nil, f)
barAnim:Hide()
barAnim:SetScript("OnUpdate", function(self, dt)
  local target = DB.barOpen and BAR_H or 0
  if fightLock() then self:Hide() pendingDraw = true return end
  barH = barH + (target - barH) * math.min(1, (dt or 0.016) * 14)
  if math.abs(target - barH) < 0.5 then barH = target self:Hide() end
  placeParts()
end)
function B.ToggleBar()
  if not DB then return end
  DB.barOpen = not DB.barOpen
  chev.icon:SetTexCoord(0, 1, DB.barOpen and 1 or 0, DB.barOpen and 0 or 1)
  local target = DB.barOpen and BAR_H or 0
  if not f:IsShown() then barH = target
  elseif fightLock() then barH = target pendingDraw = true Print("the bags row " .. (DB.barOpen and "opens" or "closes") .. " after the fight.")
  else barAnim:Show() end
  GameTooltip:Hide()
end
---------------------------------------------------------------------------
-- Hidden: a small bag at the top right of the bag. Pull an item into it and the bag stops showing
-- it (all its stacks); it's still in your bags, still usable from here. Drag it back onto the bag
-- (a group's +, or the green + in One bag) to see it there again. Suggestions: profession tools and
-- the Hearthstone.
---------------------------------------------------------------------------
local hf, drawHidden
do
local HCOLS = 5
hf = CreateFrame("Frame", "RucksackBagsHidden", f, ns.BACKDROP_TMPL)
hf:SetPoint("TOPLEFT", f, "TOPRIGHT", 3, 0)
hf:SetSize(HCOLS * PITCH - GAP + 16, 120)
hf:EnableMouse(true)
if hf.SetBackdrop then
  hf:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  hf:SetBackdropColor(0.04, 0.035, 0.03, 0.97)
  hf:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
end
hf:Hide()
-- (19 Nov) it looks like the boxes on the right of the bag (he: "make Hidden look like bag category on
-- side"): a small coloured name and a ?, the items, then an empty slot to drop on. The eye next to your
-- bags opens and closes it.
local htitle = hf:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
htitle:SetPoint("TOPLEFT", 9, -8)
htitle:SetHeight(12)
htitle:SetAlpha(0.85)
htitle:SetText("|cffd9c79aHidden|r")
-- (19 Nov) an X to close it, inside the border and level with the name
local hclose = CreateFrame("Button", nil, hf, "UIPanelCloseButton")
hclose:SetSize(18, 18)
hclose:SetPoint("TOPRIGHT", -6, -5)
local hhelp = CreateFrame("Button", nil, hf)
hhelp:SetSize(15, 15)
hhelp:SetPoint("RIGHT", hclose, "LEFT", -3, 0)
hhelp.text = hhelp:CreateFontString(nil, "ARTWORK", "GameFontNormal")
hhelp.text:SetPoint("CENTER")
hhelp.text:SetText("|cffffd100?|r")
hhelp:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Hidden")
  GameTooltip:AddLine("Things you carry but never need to look at, like a Skinning Knife, a Mining Pick or your Hearthstone. They stay in your bags and still take a slot; the bag just doesn't show them.", 1, 1, 1, true)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Drop an item on the empty slot to hide it (all its stacks). Use hidden items from here as always. To see one in the bag again, drag it back onto the bag: a group's +, or the green + in One bag.", 0.7, 0.7, 0.7, true)
  GameTooltip:AddLine("A search in the bag still finds them. Clean-up never sells or throws them away.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end)
hhelp:SetScript("OnLeave", function() GameTooltip:Hide() end)
local hbody = CreateFrame("Frame", nil, hf)
hbody:SetPoint("TOPLEFT", 8, -22)
hbody:SetSize(HCOLS * PITCH - GAP, PITCH)
local HIDE = { body = hbody, labels = {}, hints = {}, ghosts = {}, ghostN = 0, frame = hf, static = true }
-- the empty slot to drop on: one of the game's own bag buttons (slot 0 of a frame with bag number 0),
-- so it looks like any empty slot; every click on it is ours
local hdrop
do
  local home = CreateFrame("Frame", nil, hbody)
  home:SetAllPoints(hbody)
  home:SetID(0)
  local ok
  ok, hdrop = pcall(CreateFrame, "ItemButton", "RucksackBagsHiddenDrop", home, "ContainerFrameItemButtonTemplate")
  if not ok or not hdrop then ok, hdrop = pcall(CreateFrame, "Button", "RucksackBagsHiddenDrop", home, "ContainerFrameItemButtonTemplate") end
  if not ok or not hdrop then
    hdrop = CreateFrame("Button", "RucksackBagsHiddenDrop", home, ns.BACKDROP_TMPL)
    if hdrop.SetBackdrop and ns.SLOT_BACKDROP then hdrop:SetBackdrop(ns.SLOT_BACKDROP) hdrop:SetBackdropColor(0.06, 0.06, 0.06, 0.95) hdrop:SetBackdropBorderColor(0.4, 0.36, 0.28) end
    hdrop.plain = true
  end
  if hdrop.SetID then hdrop:SetID(0) end
  hdrop:SetSize(CELL, CELL)
  for _, h in ipairs({ "OnDragStart", "PreClick", "PostClick", "OnEvent", "OnUpdate" }) do pcall(hdrop.SetScript, hdrop, h, nil) end
  hdrop:RegisterForClicks("LeftButtonUp")
  hdrop:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Drop an item here")
    GameTooltip:AddLine("It's hidden from your bag (all its stacks).", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  hdrop:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
-- suggestions: profession tools you carry, and your Hearthstone (never potions, food or other things you use up)
local sugBtns = {}
local TOOLS = { [7005] = true, [2901] = true, [5956] = true, [6219] = true, [10498] = true, [9149] = true, [6218] = true,
  [6339] = true, [11130] = true, [11145] = true, [16207] = true, [6256] = true, [6365] = true, [6366] = true, [6367] = true }
-- profession tools by name too (WoW Forever may have its own versions), and the Hearthstone
local TOOL_WORDS = { "skinning knife", "mining pick", "blacksmith hammer", "arclight spanner", "gyromatic micro%-adjustor",
  "philosopher's stone", "copper rod", "silver rod", "golden rod", "truesilver rod", "arcanite rod", "fishing pole",
  "skinner", "army knife", "pick$" }
local function isTool(id)
  if TOOLS[id] or (ns.Del and ns.Del.IsTool and ns.Del.IsTool(id)) then return true end
  local name = (ns.NameOf(id) or ""):lower()
  for _, w in ipairs(TOOL_WORDS) do if name:find(w) then return true end end
  return false
end
local function isHearth(id) return id == 6948 or (ns.NameOf(id) or ""):lower() == "hearthstone" end
B.IsTool = isTool
local function hideIt(id, link)
  if not id then return end
  DB.hidden = DB.hidden or {}
  DB.hidden[id] = true
  B.newIDs[id] = nil
  Print(shown(id, link) .. " is hidden: it's in the Hidden bag now (the eye next to your bags).")
  B.Changed()
end
local function hideHeld()
  local id, link = ns.CursorItem()
  if not id then return end
  ClearCursor()
  if B.Sets and B.Sets.Of(id) then return B.SetRefuse(id, link) end
  hideIt(id, link)
end
B.HideItem = hideIt
hf:SetScript("OnReceiveDrag", hideHeld)
hf:SetScript("OnMouseUp", function() if ns.CursorItem() then hideHeld() end end)
hdrop:SetScript("OnReceiveDrag", hideHeld)
hdrop:SetScript("OnClick", hideHeld)
local function sugButton(i)
  if sugBtns[i] then return sugBtns[i] end
  local b = CreateFrame("Button", nil, hbody, ns.BACKDROP_TMPL)
  b:SetSize(CELL, CELL)
  b:SetAlpha(0.45) -- (faded: only a suggestion)
  if b.SetBackdrop then b:SetBackdrop(ns.SLOT_BACKDROP) b:SetBackdropColor(0.06, 0.05, 0.04, 0.95) b:SetBackdropBorderColor(0.4, 0.36, 0.28) end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b:SetScript("OnClick", function(self) hideIt(self.id) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self.why .. " Click to hide it.", 0.6, 1, 0.6, true)
    GameTooltip:Show()
    self:SetAlpha(0.9)
  end)
  b:SetScript("OnLeave", function(self) GameTooltip:Hide() self:SetAlpha(0.45) end)
  sugBtns[i] = b
  return b
end
-- the hidden items (your bags' own buttons, so they work as always), the drop place, suggestions
function drawHidden(text)
  if not hf:IsShown() then return end
  local items = readBags(BAGS)
  local seen, list, sug, sugSeen = {}, {}, {}, {}
  for _, e in ipairs(items) do
    if DB.hidden and DB.hidden[e.id] then
      if seen[e.id] then seen[e.id].total = seen[e.id].total + e.count
      elseif not used[getButton(e.bag, e.slot)] then
        e.total, e.cat = e.count, "hidden"
        seen[e.id] = e
        list[#list + 1] = e
      end
    elseif not sugSeen[e.id] then
      sugSeen[e.id] = true
      if isTool(e.id) then sug[#sug + 1] = { id = e.id, icon = e.icon, why = "A profession tool.", tool = true }
      elseif isHearth(e.id) then sug[#sug + 1] = { id = e.id, icon = e.icon, why = "Your Hearthstone: you use it from a bar or a key, not from the bag." } end
    end
  end
  table.sort(sug, function(a, b) if a.tool ~= b.tool then return a.tool and true or false end return a.id < b.id end)
  table.sort(list, sortItems)
  PANE = HIDE
  local function at(i) return ((i - 1) % HCOLS) * PITCH, math.floor((i - 1) / HCOLS) * PITCH end
  for i, e in ipairs(list) do show(e, ((i - 1) % HCOLS) * PITCH, math.floor((i - 1) / HCOLS) * PITCH, text) end
  PANE = MAIN
  -- the empty slot right after the items: like the boxes beside the bag, only while you hold an item
  -- (or when nothing is hidden yet, so the box isn't bare). 19 Nov, he: "remove empty slot, slot appears
  -- same like other categories"
  local n = #list
  if held or n == 0 then
    n = n + 1
    local x, yy = at(n)
    hdrop:ClearAllPoints()
    hdrop:SetPoint("TOPLEFT", hbody, "TOPLEFT", x, -yy)
    if not hdrop.plain then pcall(paint, hdrop, { bag = 0, slot = 0 }) end
    hdrop:Show()
  else
    hdrop:Hide()
  end
  -- (19 Nov: no suggestions any more, he: "remove suggestion from hidden")
  for _, b in ipairs(sugBtns) do b:Hide() end
  local cells = n
  local rows = math.ceil(cells / HCOLS)
  local h = rows * PITCH - GAP
  hbody:SetHeight(math.max(1, h))
  local y = 22 + h
  hf:SetHeight(y + 8)
end
end
function B.ToggleHidden()
  if not DB then return end
  if hf:IsShown() then hf:Hide() else hf:Show() end
  B.Draw()
end
-- (its items are your bags' own buttons, children of the bag: closing the small bag must hide them)
hf:SetScript("OnHide", function()
  if hiddenBtn then lightUp(hiddenBtn, false) end
  if fightLock() then pendingDraw = true return end
  for b, e in pairs(info) do
    if e.cat == "hidden" then b:Hide() info[b] = nil used[b] = nil end
  end
  if f:IsShown() then B.Draw() end
end)
-- Clean-up never sells or throws away a hidden item
table.insert(ns.keepers, function(id) return DB and DB.hidden and DB.hidden[id] and true or false end)

function B.Draw()
  if DB and B.VIEW and B.VIEW.frame:IsShown() then B.DrawView() end
  if not DB or not f:IsShown() then return end
  if drag then pendingDraw = true return end
  local text = (search:GetText() or ""):lower()
  if fightLock() then
    pendingDraw = true
    repaintInPlace(text)
    return
  end
  pendingDraw = nil
  B.drawN = (B.drawN or 0) + 1
  B.gap = nil -- (19 Nov: the gap opens again on the next look at the mouse)
  local cols = math.max(8, math.min(16, DB.cols or 10))
  B.curCols = cols
  local W = cols * PITCH - GAP
  B.curW = W
  -- (a narrow bag: the tools on the right of the bags row shrink a little so they don't cover the bags)
  -- (15 Nov: six tools now; they shrink just enough to leave the bags room: 5 bags + the gap = 179)
  local toolScale = math.max(0.5, math.min(1, (W - 215) / (#B.toolBtns * 33 + 8))) -- (215: the pin is on the left now; 19 Nov: 3 tools left)
  for _, tb in ipairs(B.toolBtns) do tb:SetScale(toolScale) end
  searchHint:SetShown(text == "" and not search:HasFocus())
  wipe(used)
  wipe(dropUsed)
  wipe(rects)
  wipe(drawn)
  whereText = "Your bags"
  local height, _, st = drawItems(MAIN, MAINVIEW, text, cols, W)
  if B.DrawSide then
    local ok, err = pcall(B.DrawSide, st, text, height)
    if not ok and not B.sideError then B.sideError = err Print("Bags: the boxes couldn't be drawn fully (" .. tostring(err) .. "). Please tell the author.") end
  end
  drawHidden(text)
  lightUp(hiddenBtn, hf:IsShown())
  drawTop(st)
  B.curH = height
  body:SetSize(W, height)
  hideUnused(true)
  for _, b in pairs(plusSlots) do if not dropUsed[b] then b:Hide() end end
  nothing:Hide()
  if not barAnim:IsShown() then barH = DB.barOpen and BAR_H or 0 end
  B.metrics = { W = W, height = height }
  drawFoot(foot, st, nil, MAINVIEW, W)
  placeParts()
  f:SetScale(DB.scale or 1)
end

---------------------------------------------------------------------------
-- The second window: your bank, or another character (bags or bank). Look only, except your own
-- bank at a banker: then it's live, and items go between it and your bags as always.
---------------------------------------------------------------------------
local vf = CreateFrame("Frame", "RucksackBagsView", UIParent, ns.BACKDROP_TMPL)
vf:SetSize(340, 200)
vf:SetFrameStrata("HIGH")
vf:SetToplevel(true)
vf:SetClampedToScreen(true)
vf:SetMovable(true)
vf:EnableMouse(true)
vf:RegisterForDrag("LeftButton")
if vf.SetBackdrop then
  vf:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  vf:SetBackdropColor(0.04, 0.035, 0.03, 0.95)
  vf:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
end
vf:Hide()
tinsert(UISpecialFrames, "RucksackBagsView")
vf:SetScript("OnDragStart", function(self) self:StartMoving() end)
vf:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local l, t = self:GetLeft(), self:GetTop()
  if l and t then
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    DB.viewPos = { l, t }
  end
end)
local vtitle = vf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
vtitle:SetPoint("TOPLEFT", 12, -11)
vtitle:SetJustifyH("LEFT")
vtitle:SetWordWrap(false)
local vclose = CreateFrame("Button", nil, vf, "UIPanelCloseButton")
vclose:SetSize(24, 24)
vclose:SetPoint("TOPRIGHT", -2, -4)
-- (another character: switch between their bags and their bank. Your own bank: show or hide the row
-- of the bank's bag slots)
local vkind = iconButton(vf, 22, "bank", function()
    if B.view2 and not B.view2.who then return "The bank's bag slots" end
    return B.view2 and B.view2.kind == "bank" and "Showing the bank" or "Showing the bags"
  end,
  function()
    if B.view2 and not B.view2.who then
      if not (B.BankOpen and B.BankOpen()) then return "At a banker: click to show or hide the bank's bag slots." end
      return "Click: " .. (DB and DB.bankBarOpen == false and "show" or "hide") .. " the bank's bag slots (buy slots and put bags in them there)."
    end
    return "Click: " .. (B.view2 and B.view2.kind == "bank" and "the bags." or "the bank.")
  end,
  function()
    if not B.view2 then return end
    if not B.view2.who then
      if fightLock() then Print("the bank's bag slots show or hide after the fight.") return end
      DB.bankBarOpen = DB.bankBarOpen == false
      B.DrawView()
      return
    end
    B.view2.kind = B.view2.kind == "bank" and "bags" or "bank"
    B.DrawView()
  end)
vkind:SetPoint("RIGHT", vclose, "LEFT", -1, 0)
B.viewKindBtn = vkind
local vsearch = CreateFrame("EditBox", "RucksackBagsViewSearch", vf, "InputBoxTemplate")
vsearch:SetHeight(18)
vsearch:SetWidth(110)
vsearch:SetAutoFocus(false)
vsearch:SetPoint("RIGHT", vkind, "LEFT", -7, 0)
vsearch:SetFontObject(GameFontHighlightSmall)
vsearch:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
vsearch:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
vsearch:SetScript("OnTextChanged", function() B.DrawView() end)
local vhint = vsearch:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
vhint:SetPoint("LEFT", 2, 0)
vhint:SetText("Search")
vtitle:SetPoint("RIGHT", vsearch, "LEFT", -8, 0)
local vbody = CreateFrame("Frame", nil, vf)
vbody:SetPoint("TOPLEFT", 8, -HEAD)
-- your bank's bag slots (at a banker), top left like your own bag bar: drop a bag on one, click one to
-- pick its bag up. The next slot you haven't bought: click it to buy it (it asks once).
local bankBar = CreateFrame("Frame", nil, vf)
bankBar:SetPoint("TOPLEFT", 8, -HEAD + 2)
bankBar:SetSize(300, 32)
bankBar:Hide()
local bankBtns, buyArmed, buyAt = {}, nil, 0
function B.BuyOff() buyArmed = nil end
local function bought()
  if B.BANK.tabbed then
    -- (the first "tab" is the bank itself)
    local ok, n = pcall(C_Bank.FetchNumPurchasedBankTabs, B.BANK.type)
    return math.max(0, (ok and tonumber(n) or 1) - 1)
  end
  local n = GetNumBankSlots and GetNumBankSlots()
  return n or 0
end
local function coins(c) return GetCoinTextureString and GetCoinTextureString(c) or (math.floor(c / 10000) .. "g " .. math.floor(c / 100) % 100 .. "s " .. c % 100 .. "c") end
local function slotCost()
  if B.BANK.tabbed then
    local ok, d = pcall(C_Bank.FetchNextPurchasableBankTabData, B.BANK.type)
    return ok and type(d) == "table" and tonumber(d.tabCost) or nil
  end
  local ok, c = pcall(GetBankSlotCost, bought())
  return ok and c or nil
end
for i = 1, 12 do
  local b = CreateFrame("Button", "RucksackBankBagSlot" .. i, bankBar, ns.BACKDROP_TMPL)
  b:SetSize(30, 30)
  b:SetPoint("LEFT", (i - 1) * 33, 0)
  if b.SetBackdrop then
    b:SetBackdrop(ns.SLOT_BACKDROP)
    b:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
    b:SetBackdropBorderColor(0.42, 0.35, 0.21)
  end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.lock = b:CreateTexture(nil, "OVERLAY")
  b.lock:SetSize(16, 19)
  b.lock:SetPoint("CENTER", 0, 0)
  b.lock:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
  b.lock:SetTexCoord(0, 0.71875, 0, 0.875) -- (the padlock sits in the top left of its picture)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  b.i = i
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  local function fight() if InCombatLockdown() then Print("bags can't be changed in a fight.") return true end end
  local function put() local inv = b.bag and invSlot(b.bag) if inv and b.owned and not fight() then PutItemInBag(inv) end end
  local function take() local inv = b.bag and invSlot(b.bag) if inv and b.owned and b.has and not fight() then PickupBagFromSlot(inv) end end
  b:SetScript("OnClick", function(self)
    if B.Debug then B.Debug.Log("RUCKSACK bank bag slot " .. self.i .. " clicked: owned " .. tostring(self.owned) .. ", bought " .. tostring(bought()) .. ", bag " .. tostring(self.bag)) end
    if self.owned then if CursorHasItem() then put() else take() end return end
    if self.i ~= bought() + 1 then Print("buy the bank's bag slots in order: the first locked one next.") return end
    local cost = slotCost()
    local buy = PurchaseSlot or (C_Bank and C_Bank.PurchaseSlot)
    if not buy then
      -- (this game only lets its own bank window buy slots: open it, there's a Purchase button)
      if B.ShowGameBank then B.ShowGameBank() end
      return
    end
    if buyArmed ~= self.i or GetTime() - buyAt > 5 then
      buyArmed, buyAt = self.i, GetTime()
      self.count:SetText("|cffffd100Buy?|r")
      Print("click the slot again to buy it" .. (cost and (" for " .. coins(cost)) or "") .. ".")
      return
    end
    buyArmed = nil
    self.count:SetText("")
    if cost and GetMoney() < cost then Print("not enough money: the slot costs " .. coins(cost) .. ".") return end
    local ok, err = pcall(buy)
    if not ok then Print("the game didn't let Rucksack buy the slot (" .. tostring(err) .. ").") end
  end)
  b:SetScript("OnReceiveDrag", put)
  b:SetScript("OnDragStart", take)
  b:SetScript("OnEnter", function(self)
    if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1, 0.82, 0) end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local inv = self.bag and invSlot(self.bag)
    if self.owned and self.has and inv and GameTooltip.SetInventoryItem then
      GameTooltip:SetInventoryItem("player", inv)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine((self.free or 0) .. " of " .. (self.size or 0) .. " slots free", 1, 1, 1)
      GameTooltip:AddLine("Drop another bag on it to swap. Click to pick it up.", 0.7, 0.7, 0.7, true)
    elseif self.owned then
      GameTooltip:AddLine("Empty bank bag slot")
      GameTooltip:AddLine("Drop a bag here (from your bags or one you're holding).", 1, 1, 1, true)
    elseif self.i == bought() + 1 then
      local cost = slotCost()
      GameTooltip:AddLine("Buy this bank bag slot")
      if B.buySlot == self then
        GameTooltip:AddLine((cost and ("Costs " .. coins(cost) .. ". ") or "") .. "Click: the game asks once, then it's yours. Put a bag in it after.", 1, 1, 1, true)
      elseif PurchaseSlot or (C_Bank and C_Bank.PurchaseSlot) then
        GameTooltip:AddLine("Costs " .. (cost and coins(cost) or "?") .. ". Click, then click again to buy it.", 1, 1, 1, true)
      else
        GameTooltip:AddLine((cost and ("Costs " .. coins(cost) .. ". ") or "") .. "Click: the game's own bank window comes up, buy it there with Purchase.", 1, 1, 1, true)
      end
    else
      GameTooltip:AddLine("Locked bank bag slot")
      GameTooltip:AddLine("Buy the ones before it first.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    if self.SetBackdropBorderColor then self:SetBackdropBorderColor(self.next and 0.9 or 0.42, self.next and 0.7 or 0.35, self.next and 0.2 or 0.21) end
    GameTooltip:Hide()
  end)
  b:Hide()
  bankBtns[i] = b
end
-- Buying a bank bag slot. The game only lets its own Purchase button do that, so Rucksack lays an
-- unseen button over the next slot you can buy that hands your click to the game's button (the game's
-- own "click" action: nothing of Rucksack's runs in between, so the game trusts it). The game then
-- asks "Do you want to purchase a bank slot?" as always.
function B.GameBuyButton()
  local p = BankPanel
  if type(p) ~= "table" then return nil end
  if p.PurchaseButton then return p.PurchaseButton end
  local t = p.PurchasePrompt and p.PurchasePrompt.TabCostFrame
  return t and t.PurchaseButton or nil
end
function B.BuyProxy()
  if B.buyProxy then return B.buyProxy end
  if InCombatLockdown() then return nil end
  local target = B.GameBuyButton()
  if not target then return nil end
  local p = CreateFrame("Button", "RucksackBankBuy", bankBar, "SecureActionButtonTemplate")
  p:SetSize(30, 30)
  p:RegisterForClicks("AnyDown")
  p:SetAttribute("useOnKeyDown", true)
  p:SetAttribute("type", "click")
  p:SetAttribute("clickbutton", target)
  p:HookScript("OnEnter", function() local b = B.buySlot local fn = b and b:GetScript("OnEnter") if fn then fn(b) end end)
  p:HookScript("OnLeave", function() local b = B.buySlot local fn = b and b:GetScript("OnLeave") if fn then fn(b) end end)
  p:HookScript("PreClick", function()
    if B.Debug then B.Debug.Log("RUCKSACK buy: the click goes to the game's Purchase button (bought " .. tostring(bought()) .. ")") end
  end)
  p:Hide()
  B.buyProxy = p
  return p
end
local function drawBankBar(st)
  local ids = bankBagIDs()
  local have = bought()
  -- (the buy button: over the next slot, only at the banker and out of a fight)
  if not InCombatLockdown() then
    local p = B.BANK.tabbed and B.BuyProxy()
    local nb = p and have < #ids and bankBtns[have + 1]
    if nb then
      p:ClearAllPoints()
      p:SetAllPoints(nb)
      p:SetFrameLevel((nb:GetFrameLevel() or 1) + 3)
      p:Show()
      B.buySlot = nb
    else
      if p then p:Hide() end
      B.buySlot = nil
    end
  end
  for i, b in ipairs(bankBtns) do
    local bag = ids[i]
    b.bag = bag
    if not bag then b:Hide() else
      b:Show()
      b.owned = i <= have
      b.next = i == have + 1
      local inv = b.owned and invSlot(bag)
      local tex = inv and GetInventoryItemTexture and GetInventoryItemTexture("player", inv)
      b.has = tex and true or false
      b.icon:SetTexture(tex or EMPTY_BAG)
      b.icon:SetAlpha(tex and 1 or 0.5)
      b.icon:SetShown(b.owned)
      b.lock:SetShown(not b.owned)
      b.lock:SetAlpha(b.next and 1 or 0.5)
      b.free, b.size = st and st.bagFree[bag] or 0, st and st.bagSize[bag] or 0
      if buyArmed == i and GetTime() - buyAt <= 5 then b.count:SetText("|cffffd100Buy?|r")
      else b.count:SetText(tex and ((b.free == 0 and "|cffff5a50" or "|cffffffff") .. b.free .. "|r") or "") end
      if b.SetBackdropBorderColor then b:SetBackdropBorderColor(b.next and 0.9 or 0.42, b.next and 0.7 or 0.35, b.next and 0.2 or 0.21) end
    end
  end
  bankBar:SetWidth(#ids * 33)
end
local vfoot = CreateFrame("Frame", nil, vf)
vfoot:SetHeight(16)
vfoot.free = vfoot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
vfoot.free:SetPoint("LEFT", 2, 0)
vfoot.money = vfoot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
vfoot.money:SetPoint("RIGHT", -2, 0)
vfoot.junk = vfoot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
vfoot.junk:Hide()
local vnothing = vbody:CreateFontString(nil, "ARTWORK", "GameFontDisable")
vnothing:SetPoint("TOPLEFT", 2, -4)
vnothing:SetJustifyH("LEFT")
B.VIEW = { body = vbody, labels = {}, hints = {}, ghosts = {}, ghostN = 0, frame = vf, static = true }
-- (your bank's buttons, made before this window existed, move into it)
for bag, bf in pairs(bagFrames) do
  if not IS_BAG[bag] then bf:SetParent(vbody) bf:ClearAllPoints() bf:SetAllPoints(vbody) end
end
function B.DrawView()
  local v = B.view2
  if not DB or not v or not vf:IsShown() then return end
  -- (your own bags: only in the bag window. Their buttons are the real ones: shown here they'd be pulled
  -- out of the bag window and left lying over the bank)
  if select(2, viewWho(v)) and v.kind ~= "bank" then v.kind = "bank" end
  if fightLock() then pendingDraw = true return end
  local cols = math.max(8, math.min(16, DB.cols or 10))
  local W = cols * PITCH - GAP
  local text = (vsearch:GetText() or ""):lower()
  vhint:SetShown(text == "" and not vsearch:HasFocus())
  local who, mine = viewWho(v)
  local rec = DB.chars and DB.chars[who]
  local name = mine and "Your" or ((rec and rec.name or "?") .. "'s")
  local seen = v.kind == "bank" and (vLiveBank(v) and "|cff66dd66open now|r" or (rec and rec.bankSeen) and ("seen " .. ago(rec.bankSeen)) or "not seen yet")
    or ("seen " .. ago(rec and rec.seen))
  vtitle:SetText(classColor(rec and rec.class or (mine and select(2, UnitClass("player")))) .. name .. " " .. v.kind .. "|r  |cff8a8a8a" .. seen .. "|r")
  setIcon(vkind, (v.kind == "bank" and v.who) and "bank" or "onebag")
  local saveUsed = {}
  for b in pairs(used) do saveUsed[b] = true end
  wipe(used)
  whereText = name .. " " .. v.kind
  local barH = 0
  if vLiveBank(v) and not v.who and DB.bankBarOpen ~= false then barH = 36 bankBar:Show() else bankBar:Hide() end
  lightUp(vkind, barH > 0)
  vbody:ClearAllPoints()
  vbody:SetPoint("TOPLEFT", 8, -(HEAD + barH))
  local height, total, st = drawItems(B.VIEW, v, text, cols, W)
  if barH > 0 then drawBankBar(st) end
  -- (new buttons get their padlock from the game a moment after they're made: look again)
  if barH > 0 and (B.lockCheck or 0) > 0 then
    B.lockCheck = B.lockCheck - 1
    C_Timer.After(0.3, function() B.DrawView() end)
  end
  hideUnused(false)
  for b in pairs(saveUsed) do used[b] = true end
  if total == 0 then
    vnothing:SetWidth(W - 4)
    vnothing:SetText(v.kind == "bank" and ("Nothing here yet: open " .. (mine and "your" or "their") .. " bank at a banker once, and Rucksack remembers it.") or
      ("Nothing here yet: log in with " .. (rec and rec.name or "them") .. " once."))
    vnothing:Show()
    height = math.max(height, 30)
  else
    vnothing:Hide()
  end
  vbody:SetSize(W, height)
  local y = HEAD + barH + height + 6
  vfoot:ClearAllPoints()
  vfoot:SetPoint("TOPLEFT", 8, -y)
  drawFoot(vfoot, st, rec, v, W)
  vf:SetSize(W + 16, y + 24)
  vf:SetScale(DB.scale or 1)
end
-- open the second window on a view: who (nil = you), kind ("bags" or "bank")
function B.ShowView(who, kind, auto)
  if not DB then return end
  if who == meKey() then who = nil end
  if not who and kind ~= "bank" then B.Open() return end
  local v = B.view2
  if v and vf:IsShown() and v.who == who and v.kind == kind and not auto then B.CloseView() return end
  B.view2 = { who = who, kind = kind }
  B.viewAuto = auto
  if not vf:IsShown() then
    vf:ClearAllPoints()
    if DB.viewPos then vf:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DB.viewPos[1], DB.viewPos[2])
    elseif f:IsShown() then vf:SetPoint("TOPRIGHT", f, "TOPLEFT", -6 - (B.sideLeftW or 0), 0)
    else vf:SetPoint("CENTER", UIParent, "CENTER", -200, 60) end
    vf:Show()
  end
  B.DrawView()
  if f:IsShown() then lightUp(bankBtn, kind == "bank" and not who) lightUp(whoBtn, who and true or false) end
end
function B.CloseView() vf:Hide() end
vf:SetScript("OnHide", function()
  B.viewAuto = nil
  -- (your bank closed at a banker: the visit ends, as closing the game's bank would)
  if bankOpen and DB and DB.replace and B.view2 and B.view2.kind == "bank" and not B.view2.who then
    bankOpen = false
    local close = (C_Bank and C_Bank.CloseBankFrame) or CloseBankFrame
    if close then pcall(close) end
  end
  if f:IsShown() and DB then lightUp(bankBtn, false) lightUp(whoBtn, false) end
end)

-- changes come in bursts: redraw at most a few times a second
local queued
function B.Changed()
  if (not f:IsShown() and not (B.VIEW and B.VIEW.frame:IsShown())) or queued then return end
  queued = true
  C_Timer.After(0.1, function() queued = nil B.Draw() end)
end

-- the three tools next to your bags
local function oneBagSay() Print("One bag has no groups: switch to Groups (the icon next to the gear) to make or delete groups.") end
local function newGroupClick()
  if DB.style == "grid" then return oneBagSay() end
  local id, link = ns.CursorItem()
  if id then ClearCursor() end
  B.AskNewGroup(id, link)
end
newBtn:SetScript("OnClick", newGroupClick)
newBtn:SetScript("OnReceiveDrag", newGroupClick)
newBtn.tipFn = function()
  return DB and DB.locked and "Locked: click the padlock first." or DB and DB.style == "grid" and "One bag has no groups: switch to Groups to make one." or
    "Click to make a group of your own and name it. Or drop an item here: the new group starts with it (all its stacks)."
end
trashBtn:SetScript("OnClick", function()
  if DB.locked then return lockedSay() end
  if DB.style == "grid" then return oneBagSay() end
  if not DB.groups or #DB.groups == 0 then Print("you have no groups of your own to delete. (Rucksack's own groups can't be deleted.)") return end
  B.deleting = not B.deleting
  if B.deleting then Print("click the name of one of your groups to delete it. (Or drag a group onto this button.)") end
  B.Draw()
end)
trashBtn.tipFn = function()
  return DB and DB.locked and "Locked: click the padlock first." or DB and DB.style == "grid" and "One bag has no groups: switch to Groups to delete one." or
    "Click, then click the name of one of your own groups to delete it. Or drag a group's name onto this button. Its items go back where Rucksack puts them."
end
lockBtn:SetScript("OnClick", function()
  DB.locked = not DB.locked
  B.deleting = false
  Print(DB.locked and "bag locked: groups stay where they are. You can still move items from one group to another." or "bag unlocked: you can move, make and delete groups again.")
  B.Draw()
end)

-- watch the cursor while the bag is open: pick an item up and the groups get their slots; the group
-- under the mouse lights up
local hoverBox = f:CreateTexture(nil, "ARTWORK")
hoverBox:Hide()
local function rectUnder()
  for _, r in ipairs(rects) do
    local cx, cy = cursorIn(r.parent)
    if cx >= r.x - 4 and cx <= r.x + r.w + 4 and cy >= r.y - 3 and cy <= r.y + r.h + 3 then return r end
  end
end
local since = 0
f:SetScript("OnUpdate", function(_, dt)
  since = since + (dt or 0)
  if since < 0.05 then return end
  since = 0
  local id = ns.CursorItem()
  if id ~= held then
    held = id
    -- (19 Nov, 21:16) an item of one of your equipment sets stays where it is: picked up, it can only go
    -- onto your character (no group slots, no space opening, not lifted out, the boxes and Hidden refuse it)
    B.heldSet = id and B.Sets and B.Sets.Of(id) and true or nil
    if B.HeldChanged then pcall(B.HeldChanged, id) end
    hoverKey = nil
    hoverBox:Hide()
    if newBtn.SetBackdropBorderColor and not newBtn.lit then
      if held and not DB.locked and DB.style ~= "grid" then newBtn:SetBackdropBorderColor(0.35, 1, 0.35) else newBtn:SetBackdropBorderColor(0.4, 0.36, 0.28) end
    end
    B.Draw()
  end
  local key, r
  if held and not moving and f:IsMouseOver() and not B.heldSet then
    r = rectUnder()
    if r and placeable(r.key) and ((r.key ~= "junk" and r.key ~= "sell") or hasClean()) then key = r.key end
    if r and r.key == "keep" and ((kindOfHeld(held)) or (DB.hidden and DB.hidden[held])) then key = "keep" end
  end
  -- (19 Nov) the space opening under the mouse
  if B.GapTick then pcall(B.GapTick, held and not moving and DB.style ~= "grid" and not InCombatLockdown() and key or nil) end
  if key ~= hoverKey then
    hoverKey = key
    if key then
      local junk = key == "junk"
      local sellK = key == "sell"
      hoverBox:ClearAllPoints()
      hoverBox:SetPoint("TOPLEFT", r.parent, "TOPLEFT", r.x - 3, -(r.y - 2))
      hoverBox:SetSize(r.w + 6, r.h + 4)
      if sellK then hoverBox:SetColorTexture(1, 0.82, 0.25, 0.12)
      else hoverBox:SetColorTexture(junk and 1 or 0.3, junk and 0.3 or 1, 0.3, 0.12) end
      hoverBox:Show()
    else
      hoverBox:Hide()
    end
    for _, b in pairs(plusSlots) do stylePlus(b) end
  end
end)

---------------------------------------------------------------------------
-- Opening and closing: instead of the game's bags (B, the bag buttons, vendors, mail...)
---------------------------------------------------------------------------
-- (1.8.2) the game's own bag sounds when the bag opens and closes (a setting)
local function bagSound(open)
  if not DB or DB.sound == false or not PlaySound then return end
  local id = SOUNDKIT and (open and SOUNDKIT.IG_BACKPACK_OPEN or SOUNDKIT.IG_BACKPACK_CLOSE) or (open and 862 or 863)
  pcall(PlaySound, id)
end
function B.Open()
  if not DB then return end
  if DB.replace and B.HideGameBags then B.HideGameBags(true) end
  if not f:IsShown() then bagSound(true) end
  f:Show()
  B.Draw()
  if not B.pinned then B.pinned = true pinTopLeft() end
end
function B.Close() f:Hide() end
f:SetScript("OnHide", function()
  bagSound(false)
  wipe(B.newIDs)
  if DB and DB.autoSort ~= false then B.rank = nil end -- (19 Nov: sorted afresh the next time it opens; automatic sorting off: kept)
  B.visCache = nil -- (19 Nov: tags worked out afresh next time)
  B.hoverBag = nil
  B.deleting = false
  menu:Hide()
  if drag then drag, moving = nil, nil anim:Hide() liftBox:Hide() gapBox:Hide() end
end)

-- Tidy: put half-full stacks of the same item together, a few moves at a time
local tidying
local function tidyStep()
  if InCombatLockdown() or CursorHasItem() or B.swap then tidying = nil return end
  local parts = {}
  for _, bag in ipairs(BAGS) do
    local kind = bagKind(bag)
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local it = C_Container.GetContainerItemInfo(bag, slot)
      if it and it.itemID and not it.isLocked then
        local max = select(8, ns.GetInfo(it.hyperlink or it.itemID))
        if max and max > 1 and (it.stackCount or 1) < max then
          local key = it.itemID .. kind
          parts[key] = parts[key] or {}
          table.insert(parts[key], { bag = bag, slot = slot, count = it.stackCount or 1 })
        end
      end
    end
  end
  local moved = 0
  for _, list in pairs(parts) do
    if #list >= 2 then
      table.sort(list, function(a, b) return a.count < b.count end)
      local from, to = list[1], list[#list]
      C_Container.PickupContainerItem(from.bag, from.slot)
      C_Container.PickupContainerItem(to.bag, to.slot)
      moved = moved + 1
    end
  end
  if moved > 0 and tidying < 25 then
    tidying = tidying + 1
    C_Timer.After(0.4, tidyStep)
  else
    Print(tidying > 0 and "bags tidied: half-full stacks put together." or "nothing to tidy: no half-full stacks of the same item.")
    tidying = nil
    B.Changed()
  end
end
function B.Tidy()
  if tidying then return end
  if InCombatLockdown() then Print("not in a fight.") return end
  if CursorHasItem() then Print("put the item on your cursor down first.") return end
  B.rank = nil -- (19 Nov: Tidy sorts the groups again too)
  B.Changed()
  -- (One bag, Free: sort for real, once, with the game's own sort; it puts stacks together too)
  if B.FreeNow() and C_Container.SortBags then
    local ok = pcall(C_Container.SortBags)
    if ok then Print("bags sorted. They stay as they are until you move things or tidy again.") return end
  end
  tidying = 0
  tidyStep()
end
-- Reagents live in the reagent bag: one lying in an ordinary bag is moved there when there's room
-- (onto a half-full stack of it first, then an empty reagent slot). One move at a time, never in a
-- fight, never while you hold something. What counts as a reagent: the game says so, or it has been
-- seen in the reagent bag. If the game won't take an item there, it's left alone from then on.
B.reagentSeen, B.reagentNo = {}, {}
function B.IsReagent(id)
  if B.reagentNo[id] then return false end
  if B.reagentSeen[id] then return true end
  local ok, r = pcall(function() return (select(17, ns.GetInfo(id))) end)
  return ok and r and true or false
end
function B.ReagentsHome()
  if not DB or DB.reagentHome == false or not REAGENT then return end
  if B.reagentWait and GetTime() - B.reagentWait < 2 then return end -- (a look is already on its way)
  B.reagentWait = GetTime()
  C_Timer.After(0.5, B.ReagentStep)
end
function B.ReagentStep()
  B.reagentWait = nil
  if DB and DB.autoSort == false then return end -- (19 Nov: automatic sorting off)
  if B.swap then return end -- (18 Nov: a bag swap is moving things)
  if not DB or DB.reagentHome == false or not REAGENT then return end
  if DB.style == "grid" then return end -- (18 Nov: One bag moves nothing by itself, reagents neither)
  if B.SpecialOf and B.SpecialOf(REAGENT) then return end -- (18 Nov: a soul bag sits in the reagent slot: no reagents go there)
  if tidying or InCombatLockdown() or CursorHasItem() or (GetCursorInfo and GetCursorInfo()) then return end
  if SpellIsTargeting and SpellIsTargeting() then return end
  local n = C_Container.GetContainerNumSlots(REAGENT) or 0
  if n == 0 then return end
  local empty, partial, busy = nil, {}, false
  for slot = 1, n do
    local it = C_Container.GetContainerItemInfo(REAGENT, slot)
    if it and it.itemID then
      B.reagentSeen[it.itemID] = true
      if it.isLocked then
        busy = true
      else
        local max = select(8, ns.GetInfo(it.hyperlink or it.itemID))
        if max and (it.stackCount or 1) < max and not partial[it.itemID] and not (ns.HaulSlot and ns.HaulSlot(REAGENT, slot)) then partial[it.itemID] = slot end
      end
    elseif not empty then
      empty = slot
    end
  end
  if busy then return B.ReagentsHome() end -- (a move is still on its way)
  if not empty and not next(partial) then return end
  for _, bag in ipairs(BAGS) do
    if bag ~= REAGENT and not (B.SpecialOf and B.SpecialOf(bag)) then
      for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
        local it = C_Container.GetContainerItemInfo(bag, slot)
        if it and it.itemID and not it.isLocked and B.IsReagent(it.itemID)
          and not (ns.HaulSlot and ns.HaulSlot(bag, slot)) -- (19 Nov: a Haul stack stays where it is)
          and not (B.SpecialRoomFor and B.SpecialRoomFor(it.itemID)) then -- (1.9.1: special bags first)
          local to = partial[it.itemID] or empty
          if to then
            local sig = bag .. ":" .. slot .. ":" .. it.itemID .. ":" .. (it.stackCount or 1) .. ">" .. to
            if sig == B.reagentLast and GetTime() - (B.reagentLastAt or 0) < 5 then
              -- (asked for exactly this a moment ago and nothing happened: the game won't do it)
              B.reagentNo[it.itemID], B.reagentLast = true, nil
            else
              B.reagentLast, B.reagentLastAt = sig, GetTime()
              C_Container.PickupContainerItem(bag, slot)
              C_Container.PickupContainerItem(REAGENT, to)
              if CursorHasItem() then
                -- (the reagent bag wouldn't take it: back where it was, and not tried again)
                ClearCursor()
                B.reagentNo[it.itemID] = true
              end
            end
            return B.ReagentsHome()
          end
        end
      end
    end
  end
end
-- (1.9.1, 17 Nov) special bags (he: "special bags, name of the bag to be correct like Herb bag as
-- category, tint of action slots and border of slot, and items prefer those, actually sorting in real
-- time if it has place item will go to those bags, make it as setting. And let us change colors
-- inside settings"). Each kind has a name and a colour (yours, from the Bags page, or the default).
-- An item that fits one goes there by itself when there's room: onto a half-full stack of it first,
-- then an empty slot, one stack at a time, before the reagent bag. Never in a fight or while you hold
-- something; stacks marked for a window stay put.
do -- (in a block: the file has nearly as many top-level names as Lua allows)
local function hasBit(v, b) return v and v > 0 and math.floor(v / b) % 2 == 1 or false end
B.hasBit = hasBit
local byKey = {}
for _, sp in ipairs(B.SPECIAL) do byKey[sp.key] = sp end
B.SpecialByKey = byKey
-- your colour for a kind, or its own
function B.SpecialColor(key)
  local mine = DB and DB.specColors and DB.specColors[key]
  return mine or (byKey[key] and byKey[key].color) or { 0.5, 0.5, 0.5 }
end
-- what kind of special bag this bag is (nil: an ordinary bag, the backpack or the reagent bag)
-- (18 Nov) the bag item's own kind, for when the game reports no family for the bag (his friend's soul
-- bag: "the option ... is disabled for him"). Container subclasses and quiver subclasses.
B.SUBKIND = { [1] = { [1] = "soul", [2] = "herb", [3] = "enchant", [4] = "engineer", [5] = "gem", [6] = "mining", [7] = "leather", [8] = "inscribe" },
  [11] = { [2] = "quiver", [3] = "ammo" } }
function B.KindOfBagItem(bag)
  local toInv = C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID
  if not toInv then return nil end
  local ok, inv = pcall(toInv, bag)
  local itemID = ok and inv and GetInventoryItemID("player", inv)
  if not itemID then return nil end
  local inst = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not inst then return nil end
  local classID, subID = select(6, inst(itemID))
  local key = B.SUBKIND[classID] and B.SUBKIND[classID][subID]
  return key and byKey[key] or nil
end
-- (18 Nov) on Forever a warlock can put the soul bag in the reagent slot (his friend's was there, and
-- Rucksack thought it was a reagent bag: it even tried to put reagents in it, "only soul shards can go
-- in that"). The reagent slot counts as special only for a soul bag.
B.SOULBAGS = { [22243] = true, [22244] = true, [21340] = true, [21341] = true, [21342] = true, [21872] = true }
function B.SoulByItem(bag)
  local toInv = C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID
  if not toInv then return nil end
  local ok, inv = pcall(toInv, bag)
  local itemID = ok and inv and GetInventoryItemID("player", inv)
  if not itemID then return nil end
  if B.SOULBAGS[itemID] then return byKey.soul end
  local name = GetItemInfo and GetItemInfo(itemID)
  if name and (name:find("Soul") or name:find("Felcloth") or name:find("Shadowbag")) then return byKey.soul end
end
function B.SpecialOf(bag)
  if not bag or bag == 0 then return nil end
  if not C_Container.GetContainerNumFreeSlots or (C_Container.GetContainerNumSlots(bag) or 0) == 0 then return nil end
  local fam = select(2, C_Container.GetContainerNumFreeSlots(bag)) or 0
  if bag == REAGENT then
    if hasBit(fam, 4) then return byKey.soul end
    local k = B.KindOfBagItem(bag)
    if k and k.key == "soul" then return k end
    return B.SoulByItem(bag)
  end
  if fam ~= 0 then
    for _, sp in ipairs(B.SPECIAL) do if hasBit(fam, sp.bit) then return sp end end
  end
  return B.KindOfBagItem(bag) or B.SoulByItem(bag)
end
-- (18 Nov) each kind: one tile per item with the total (the default), or slot by slot with its empty
-- slots (he: "we can choose in settings to group it up or not separate for each special bag")
function B.SpecialGrouped(key) return not (DB and DB.specUngroup and DB.specUngroup[key]) end
-- do you wear a special bag of this kind (any bag slot, the reagent slot too)?
function B.HasSpecial(key)
  for _, bag in ipairs(BAR) do
    local sp = B.SpecialOf(bag)
    if sp and sp.key == key then return bag end
  end
end
local function itemFamily(id)
  local getFamily = (C_Item and C_Item.GetItemFamily) or GetItemFamily
  if not getFamily or not id then return 0 end
  -- (18 Nov) a bag itself (a spare soul pouch, a quiver...) reports the kind it holds, not where it
  -- goes: the game said "only soul shards can go in that". Bags never move into special bags.
  local inst = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local classID = inst and select(6, inst(id))
  if classID == 1 or classID == 11 then return 0 end
  local ok, fam = pcall(getFamily, id)
  return ok and fam or 0
end
-- the ammo bag you wear: its bag number and kind (1 = quiver/arrows, 2 = ammo pouch/bullets)
function B.QuiverBag()
  for _, bag in ipairs(BAR) do
    local sp = B.SpecialOf(bag)
    if sp and (sp.bit == 1 or sp.bit == 2) then return bag, sp.bit end
  end
end
-- does this item go in that ammo bag?
function B.FitsQuiver(id, kind) return id and kind and hasBit(itemFamily(id), kind) or false end
-- your special bags right now: for each, the half-full stacks (by item) and the first empty slot
local function specialRoom()
  local out, busy = {}, false
  for _, bag in ipairs(BAR) do
    local sp = B.SpecialOf(bag)
    if sp then
      local r = { bag = bag, sp = sp, partial = {} }
      for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
        local it = C_Container.GetContainerItemInfo(bag, slot)
        if it and it.itemID then
          if it.isLocked then busy = true
          else
            local max = select(8, ns.GetInfo(it.hyperlink or it.itemID))
            if max and (it.stackCount or 1) < max and not r.partial[it.itemID] then r.partial[it.itemID] = slot end
          end
        elseif not r.empty then
          r.empty = slot
        end
      end
      out[#out + 1] = r
    end
  end
  return out, busy
end
-- where this item would go: the bag and slot in one of your special bags, or nil
local SHARD = 6265
local function placeFor(rooms, id)
  local fam = itemFamily(id)
  if fam == 0 and id ~= SHARD then return nil end
  for _, r in ipairs(rooms) do
    if hasBit(fam, r.sp.bit) or (id == SHARD and r.sp.key == "soul") then -- (a shard always fits a soul bag)
      local to = r.partial[id] or r.empty
      if to then return r.bag, to end
    end
  end
end
-- (for the reagent bag: an item with room in a special bag goes there instead)
function B.SpecialRoomFor(id, evenIfOff) -- (evenIfOff: is there room at all, sorting on or not)
  if not DB or (DB.specialHome == false and not evenIfOff) then return false end
  local rooms = specialRoom()
  return placeFor(rooms, id) ~= nil
end
B.specialNo = {}
function B.SpecialHome()
  if not DB or DB.specialHome == false then return end
  if B.specialWait and GetTime() - B.specialWait < 2 then return end
  B.specialWait = GetTime()
  C_Timer.After(0.6, B.SpecialStep)
end
B.AmmoHome = B.SpecialHome -- (1.9 name)
-- (18 Nov) if the game refuses a move ("only soul shards can go in that"...), that item is never tried again
do
  local guard = CreateFrame("Frame")
  guard:RegisterEvent("UI_ERROR_MESSAGE")
  guard:SetScript("OnEvent", function()
    if B.specialMoving and GetTime() - (B.specialMovingAt or 0) < 1 then
      B.specialNo[B.specialMoving] = true
      B.specialMoving = nil
    end
  end)
end
function B.SpecialStep()
  B.specialWait = nil
  if DB and DB.autoSort == false then return end -- (19 Nov: automatic sorting off)
  if B.swap then return end -- (18 Nov: a bag swap is moving things)
  if not DB or DB.specialHome == false then return end
  if tidying or InCombatLockdown() or CursorHasItem() or (GetCursorInfo and GetCursorInfo()) then return end
  if SpellIsTargeting and SpellIsTargeting() then return end
  local rooms, busy = specialRoom()
  if #rooms == 0 then return end
  if busy then return B.SpecialHome() end
  for _, bag in ipairs(BAGS) do
    if not B.SpecialOf(bag) then -- (ordinary bags and the reagent bag)
      for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
        local it = C_Container.GetContainerItemInfo(bag, slot)
        local id = it and it.itemID
        if id and not it.isLocked and not B.specialNo[id]
          and not (B.BankSlot and B.BankSlot(bag, slot, id))
          and not (ns.HaulSlot and ns.HaulSlot(bag, slot)) -- (19 Nov: a Haul stack stays where it is)
          and not (ns.Del and ns.Del.SlotJunk and ns.Del.SlotJunk(bag, slot, id)) then
          local tb, to = placeFor(rooms, id)
          if tb then
            local sig = bag .. ":" .. slot .. ":" .. id .. ":" .. (it.stackCount or 1) .. ">" .. tb .. ":" .. to
            if sig == B.specialLast and GetTime() - (B.specialLastAt or 0) < 5 then
              B.specialNo[id], B.specialLast = true, nil -- (the game won't do it: not tried again)
            else
              B.specialLast, B.specialLastAt = sig, GetTime()
              B.specialMoving, B.specialMovingAt = id, GetTime()
              C_Container.PickupContainerItem(bag, slot)
              C_Container.PickupContainerItem(tb, to)
              if CursorHasItem() then ClearCursor() B.specialNo[id] = true end
            end
            return B.SpecialHome()
          end
        end
      end
    end
  end
end
end
function B.Toggle() if f:IsShown() then B.Close() else B.Open() end end
function B.IsShown() return f:IsShown() end
local hooked = false
-- The game's own bank window while Rucksack does your bags: the game opens it as always (it has to
-- think the bank is open: buying a bag slot and right-click "put it in the bank" go through it), but
-- under a frame that is see-through and a thousandth of its size, so you never see or touch it.
-- Rucksack never opens, shows or fills that window itself: an addon doing that makes the game stop
-- trusting clicks on your items ("tried to call a protected function") until a /reload.
function B.HideGameBank(on)
  local bf = BankFrame
  if type(bf) ~= "table" or not bf.SetParent then return false end
  if InCombatLockdown() then return false end
  if not B.gameBankHome then
    local h = CreateFrame("Frame", nil, UIParent)
    h:SetSize(1, 1)
    h:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    h:SetAlpha(0)
    h:SetScale(0.001)
    B.gameBankHome = h
  end
  if on then
    if bf:GetParent() ~= B.gameBankHome then
      B.gameBankParent = bf:GetParent() or UIParent
      B.gameBankStrata = bf.GetFrameStrata and bf:GetFrameStrata() or nil
      pcall(bf.SetParent, bf, B.gameBankHome)
    end
  elseif B.gameBankParent then
    pcall(bf.SetParent, bf, B.gameBankParent)
    if B.gameBankStrata and bf.SetFrameStrata then pcall(bf.SetFrameStrata, bf, B.gameBankStrata) end
    B.gameBankParent = nil
  end
  return true
end
-- the game's own bank window on request (if Rucksack's buy button can't be used): seen until this visit ends
function B.ShowGameBank()
  if not BankFrame then return end
  if not B.HideGameBank(false) then Print("not in a fight: try again after it.") return end
  B.gameBankOn = true
  Print("the game's own bank window is up too until you leave the banker. Buy the bag slot there with Purchase.")
end
-- Your bag key and everything else that opens bags: Rucksack opens instead of the game's bags.
-- The game's own functions (ToggleAllBags, OpenAllBags...) are left exactly as they are and Rucksack
-- acts after them (hooksecurefunc). Replacing them, as Rucksack did before 1.8.2, made the game
-- distrust everything its own code did after calling one: buying a bank slot and using an item at
-- the bank failed with "tried to call a protected function". The game's bag windows still open when
-- the game says so, but under a hidden frame, so you never see them.
function B.HideGameBags(on)
  if not B.gameBagsHome then B.gameBagsHome = CreateFrame("Frame") B.gameBagsHome:Hide() B.gameBagParents = {} end
  local gameBagsHome, gameBagParents = B.gameBagsHome, B.gameBagParents
  local list = {}
  if ContainerFrameCombinedBags then list[#list + 1] = ContainerFrameCombinedBags end
  for i = 1, 20 do local c = _G["ContainerFrame" .. i] if c then list[#list + 1] = c end end
  for _, c in ipairs(list) do
    if on then
      if c:GetParent() ~= gameBagsHome then
        gameBagParents[c] = c:GetParent() or UIParent
        pcall(c.SetParent, c, gameBagsHome)
      end
    elseif gameBagParents[c] then
      pcall(c.SetParent, c, gameBagParents[c])
      gameBagParents[c] = nil
    end
  end
end
-- what the game just asked for: "toggle", true (open) or false (close). The game's functions call each
-- other (ToggleAllBags calls OpenBackpack...), and the outer one is heard last: so within one moment
-- every call starts again from how the bag was before the first, and the last one heard decides.
function B.Asked(want)
  if not DB or not DB.replace then return end
  local now = GetTime()
  if now ~= B.askedAt then B.askedAt, B.wasOpen = now, (f:IsShown() and true or false) end
  local open = want
  if want == "toggle" then open = not B.wasOpen end
  if open then
    if not f:IsShown() then B.Open() end
  elseif f:IsShown() then
    B.Close()
  end
end
local function takeOver()
  local asked = B.Asked
  if hooked then return end
  hooked = true
  if DB and DB.replace then B.HideGameBank(true) B.HideGameBags(true) end
  local function after(name, fn) if type(_G[name]) == "function" then pcall(hooksecurefunc, name, fn) end end
  after("ToggleAllBags", function() asked("toggle") end)
  after("OpenAllBags", function() asked(true) end)
  after("CloseAllBags", function() asked(false) end)
  after("ToggleBackpack", function() asked("toggle") end)
  after("OpenBackpack", function() asked(true) end)
  after("CloseBackpack", function() asked(false) end)
  after("ToggleBag", function(id) if IS_BAG[id] then asked("toggle") end end)
end

---------------------------------------------------------------------------
-- opens with a vendor, the mail, the bank, the auction house and a trade; closes with them again
-- (only if that's what opened it). The bank is remembered while it's open.
local OPENERS = { MERCHANT_SHOW = "MERCHANT_CLOSED", MAIL_SHOW = "MAIL_CLOSED", BANKFRAME_OPENED = "BANKFRAME_CLOSED",
  AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED", TRADE_SHOW = "TRADE_CLOSED" }
local CLOSERS, autoOpened = {}, false
for o, c in pairs(OPENERS) do CLOSERS[c] = true end
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, e)
  if e == "BANKFRAME_OPENED" then
    bankOpen = true
    B.ForgetLocked()
    B.lockCheck = 2
    if DB and DB.replace and not B.gameBankOn then B.HideGameBank(true) end
    pcall(B.SaveBank)
    if DB and DB.replace then B.ShowView(nil, "bank", true) end
  end
  if e == "BANKFRAME_CLOSED" then
    bankOpen = false
    if B.gameBankOn then
      B.gameBankOn = nil
      if DB and DB.replace then B.HideGameBank(true) end
    end
    if B.BuyOff then B.BuyOff() end
    if B.viewAuto then B.CloseView() end
  end
  if e == "PLAYER_LEAVING_WORLD" then B.leaving = true return end
  if e == "PLAYER_ENTERING_WORLD" then B.leaving = nil return end
  if e == "PLAYER_LOGOUT" then return end -- (19 Nov: the bags are empty by now; saved as they change instead)
  if e == "PLAYERBANKSLOTS_CHANGED" then pcall(B.SaveBank) end
  if e == "PLAYERBANKBAGSLOTS_CHANGED" or e == "BANK_TABS_CHANGED" then B.ForgetLocked() B.lockCheck = 2 end
  if e == "PLAYER_REGEN_ENABLED" then B.ReagentsHome() B.SpecialHome() if pendingDraw then B.Changed() end return end
  if OPENERS[e] then
    if DB and DB.replace and not f:IsShown() then autoOpened = true B.Open() else B.Changed() end
  elseif CLOSERS[e] then
    if autoOpened then autoOpened = false B.Close() else B.Changed() end
  else
    if e == "BAG_UPDATE_DELAYED" or e == "PLAYER_EQUIPMENT_CHANGED" or e == "PLAYER_LEVEL_UP" then B.visCache = nil end
    if e == "BAG_UPDATE_DELAYED" then
      pcall(trackNew)
      pcall(B.SaveBags)
      if bankOpen then pcall(B.SaveBank) end
      B.SpecialHome()
      B.ReagentsHome()
    elseif e == "PLAYER_MONEY" then
      pcall(B.SaveBags)
    end
    B.Changed()
  end
end)
table.insert(ns.listeners, function() B.Changed() end)

ns.Module("bags", (...), function()
  RucksackBagsDB = RucksackBagsDB or {}
  DB = RucksackBagsDB
  B.db = DB
  -- (24 Nov) Restock and Hidden are each character's own (see ns.PerChar in Core.lua)
  if ns.PerChar then
    ns.PerChar(DB, "restock", "bags")
    ns.PerChar(DB, "hidden", "bags")
  end
  if DB.style == nil then DB.style = "groups" end
  -- (19 Nov) groups side by side to start (he: "side by side categories and out of bounds new row");
  -- once for everyone who had Rows. Rows is still on the Bags page.
  if DB.layout == nil or not DB.packedOnce then DB.layout = "packed" DB.packedOnce = true end
  if DB.merged == nil then DB.merged = true end
  if DB.cols == nil then DB.cols = 10 end
  if DB.scale == nil then DB.scale = 1 end
  DB.replace = true -- (1.8: with the module on, it's always your bag; to use another bag addon, turn Bags off)
  if DB.barOpen == nil then DB.barOpen = false end -- (the bags row: opened with the arrow on Rucksack)
  -- (1.8.2) Junk is under everything now. A saved order that still has Junk where it used to start
  -- (just above the Empty groups) is put right once; an order where you moved Junk yourself is left.
  if not DB.junkLast then
    DB.junkLast = true
    if DB.order then
      local at
      for i, k in ipairs(DB.order) do if k == "junk" then at = i end end
      local old = at ~= nil
      for i = (at or 0) + 1, #DB.order do if not tostring(DB.order[i]):find("^empty") then old = false end end
      if old and at < #DB.order then table.remove(DB.order, at) DB.order[#DB.order + 1] = "junk" end
    end
  end
  if DB.sortBy == nil then DB.sortBy = "kind" end
  if DB.emptyAll == nil then DB.emptyAll = true end
  if DB.showNew == nil then DB.showNew = true end
  if DB.cols < 8 then DB.cols = 8 end
  DB.cats = DB.cats or {}
  DB.assign = DB.assign or {} -- items you put in a group yourself: id -> group
  DB.groups = DB.groups or {} -- your own groups: { key, name, color }
  DB.chars = DB.chars or {}   -- your characters: bags, bank, money, class
  DB.reagents = nil           -- (1.8 test builds: professions, gone again)
  for id, k in pairs(DB.assign) do if k == "prof" then DB.assign[id] = nil end end
  rebuild()
  hookTooltips()
  if DB.pos then
    f:ClearAllPoints()
    f:SetPoint(DB.pos[1], UIParent, DB.pos[2], DB.pos[3], DB.pos[4])
  end
end)
table.insert(ns.onLogin, function()
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "PLAYER_MONEY", "BAG_UPDATE_COOLDOWN", "QUEST_LOG_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE", "BAG_CONTAINER_UPDATE", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "PLAYER_LOGOUT", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BANK_TABS_CHANGED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "TRADE_SHOW", "TRADE_CLOSED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  pcall(trackNew)
  pcall(B.SaveBags)
  takeOver()
  B.SpecialHome()
  B.ReagentsHome()
  -- (the Junk group shows what the trash button shows: hide that button once; "Show button" on the
  -- Clean-up page brings it back)
  if ns.del and not DB.trashHidden then
    DB.trashHidden = true
    ns.del.hideIcon = true
    if ns.Del and ns.Del.Refresh then ns.Del.Refresh() end
  end
  local other = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)
  for _, name in ipairs({ "Baganator", "Bagnon", "AdiBags", "ArkInventory" }) do
    if other and other(name) and DB.replace and not DB.warned then
      DB.warned = true
      Print("Bags is on and " .. name .. " is too: both open on B. Turn one off (for Rucksack: Settings > Modules, the Clean-up card: Clean-up only).")
    end
  end
end)

-- /ruckbank: what this game says about your bank (at a banker): every container, its slots and items
SLASH_RUCKBANK1 = "/ruckbank"
SlashCmdList.RUCKBANK = function()
  local function say(t) print("|cff66ddffRucksack bank:|r " .. t) end
  local E = Enum and Enum.BagIndex
  if E then
    local t = {}
    for k, v in pairs(E) do t[#t + 1] = k .. "=" .. tostring(v) end
    table.sort(t)
    say("game's list: " .. table.concat(t, ", "))
  end
  local IC = Constants and Constants.InventoryConstants
  say(("bag slots %s, bank bag slots %s, reagent bag slots %s, bought bank bags %s, bank open %s"):format(tostring(NUM_BAG_SLOTS), tostring(NUM_BANKBAGSLOTS),
    tostring(IC and IC.NumReagentBagSlots), tostring(GetNumBankSlots and GetNumBankSlots()), tostring(B.BankOpen and B.BankOpen())))
  local rows = {}
  for id = -3, 20 do
    local n = C_Container.GetContainerNumSlots(id) or 0
    if n > 0 then
      local items = 0
      for s = 1, n do local it = C_Container.GetContainerItemInfo(id, s) if it and it.itemID then items = items + 1 end end
      local name = C_Container.GetBagName and C_Container.GetBagName(id)
      rows[#rows + 1] = id .. ": " .. n .. " slots, " .. items .. " items" .. (name and (" (" .. name .. ")") or "")
    end
  end
  say("containers: " .. (#rows > 0 and table.concat(rows, " | ") or "none"))
  say("Rucksack uses: bags " .. table.concat(BAGS, ",") .. "  bank " .. table.concat(bankIDs(), ","))
  say("game's numbers: bank slots " .. tostring(NUM_BANKGENERIC_SLOTS) .. ", bank bag slots counted " .. #bankBagIDs())
  do -- every bank slot in order: I an item, . empty, L shown with a padlock, ? no button yet
    local main0 = B.BANK.main
    local map = {}
    for s = 1, C_Container.GetContainerNumSlots(main0) or 0 do
      local it = C_Container.GetContainerItemInfo(main0, s)
      local b = buttons[main0] and buttons[main0][s]
      map[#map + 1] = (it and it.itemID) and "I" or (not b and "?") or (B.Padlocked(b) and "L") or "."
      if s % 8 == 0 then map[#map + 1] = " " end
    end
    say("bank slots: " .. table.concat(map))
  end
  -- what the game puts on the last bank slot (to find its padlock)
  local main = B.BANK.main
  local n = C_Container.GetContainerNumSlots(main) or 0
  local b = buttons[main] and buttons[main][n]
  if b then
    local parts = {}
    for k, v in pairs(b) do
      if type(v) == "table" and v.GetObjectType and v:GetObjectType() == "Texture" and v:IsShown() then
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(v.GetAtlas and v:GetAtlas() or v:GetTexture())
      end
    end
    for _, r in ipairs({ b:GetRegions() }) do
      if r.GetObjectType and r:GetObjectType() == "Texture" and r:IsShown() then
        parts[#parts + 1] = "region " .. tostring(r:GetDrawLayer()) .. "=" .. tostring(r.GetAtlas and r:GetAtlas() or r:GetTexture())
      end
    end
    say("bank slot " .. n .. " shows: " .. table.concat(parts, ", ") .. "  padlocked: " .. tostring(B.Padlocked(b)))
  end
  local api = {}
  for _, tn in ipairs({ "C_Container", "C_Bank" }) do
    local t = _G[tn]
    if type(t) == "table" then for k in pairs(t) do if k:find("Lock") or k:find("Purchase") or k:find("Slot") or k:find("Unlock") then api[#api + 1] = tn .. "." .. k end end end
  end
  for k, v in pairs(_G) do if type(v) == "function" and type(k) == "string" and k:find("Bank") and (k:find("Purchase") or k:find("Slot") or k:find("Lock")) then api[#api + 1] = k end end
  table.sort(api)
  say("game's bank functions: " .. table.concat(api, ", "))
end

---------------------------------------------------------------------------
-- (18 Nov) Swapping a bag that still has items in it. He: "I need to change a bag and sometimes it
-- wont let me if I dont have enough slots, can it still be done?" The game only takes a new bag on a
-- slot whose bag is empty. Drop the new bag on that slot in the bags row: Rucksack moves the old
-- bag's items into your other bags (and the bank while it's open), a few at a time, then puts the new
-- bag in; the old bag lands where the new one was. Without room it says how many slots are missing
-- and offers: delete junk, or put the new bag in an empty bag slot.
---------------------------------------------------------------------------
-- (in a function of its own: the file is at Lua's limit of 200 locals)
;(function()
  local function slotsOf(bag) return C_Container.GetContainerNumSlots(bag) or 0 end
  local function isBagItem(id)
    if not id or not C_Item or not C_Item.GetItemInfoInstant then return false end
    local ok, _, _, _, _, _, class = pcall(C_Item.GetItemInfoInstant, id)
    return ok and (class == 1 or class == 11) or false
  end
  local function maxStack(id, link)
    local ok, m = pcall(function() return (select(8, ns.GetInfo(link or id))) end)
    return ok and m or 1
  end
  -- can this item go into that bag? (special bags only take their own kind: left alone here)
  local function takes(bag, id)
    if B.SpecialOf and B.SpecialOf(bag) then return false end
    if bag == REAGENT then return B.IsReagent(id) and true or false end
    return true
  end
  local function dests(target)
    local list = {}
    for _, bag in ipairs(BAGS) do if bag ~= target then list[#list + 1] = bag end end
    if bankOpen then for _, bag in ipairs(bankIDs()) do list[#list + 1] = bag end end
    return list
  end
  -- where each item in the old bag would go: the moves, how many have nowhere to go, how many items
  local function plan(target)
    local spots, partial = {}, {}
    for _, bag in ipairs(dests(target)) do
      for slot = 1, slotsOf(bag) do
        local it = C_Container.GetContainerItemInfo(bag, slot)
        if not it or not it.itemID then
          if not B.IsLockedSlot(bag, slot) then spots[#spots + 1] = { bag = bag, slot = slot } end
        elseif not it.isLocked then
          local room = maxStack(it.itemID, it.hyperlink) - (it.stackCount or 1)
          if room > 0 then partial[#partial + 1] = { bag = bag, slot = slot, id = it.itemID, room = room } end
        end
      end
    end
    local moves, missing, count = {}, 0, 0
    for slot = 1, slotsOf(target) do
      local it = C_Container.GetContainerItemInfo(target, slot)
      if it and it.itemID then
        count = count + 1
        local n, to = it.stackCount or 1, nil
        for _, p in ipairs(partial) do
          if p.id == it.itemID and p.room >= n and takes(p.bag, it.itemID) then to = p p.room = p.room - n break end
        end
        if not to then
          for i, sp in ipairs(spots) do
            if takes(sp.bag, it.itemID) then to = table.remove(spots, i) break end
          end
        end
        if to then
          moves[#moves + 1] = { from = slot, id = it.itemID, link = it.hyperlink, bag = to.bag, slot = to.slot, locked = it.isLocked }
        else
          missing = missing + 1
        end
      end
    end
    return moves, missing, count, spots
  end
  B.SwapPlan = plan
  -- (18 Nov, taking a bag out) a free slot left for the bag itself, and how many slots are missing
  local function bagSpot(target, spots)
    local id = GetInventoryItemID("player", invSlot(target) or 0)
    for _, sp in ipairs(spots or {}) do if takes(sp.bag, id) then return sp end end
  end
  local function outNeed(target)
    local _, missing, count, spots = plan(target)
    return missing + (bagSpot(target, spots) and 0 or 1), count
  end
  -- a stack's sell / delete-once / bank mark goes with it
  local function carryMarks(fromKey, toKey, id)
    local c = ns.char
    if not c then return end
    for _, k in ipairs({ "bankSlots", "sellSlots", "junkSlots" }) do
      local m = c[k]
      if type(m) == "table" and m[fromKey] == id then m[fromKey] = nil m[toKey] = id end
    end
  end
  local S -- the swap on its way
  local function finish(msg)
    if S and S.ticker then S.ticker:Cancel() end
    S, B.swap = nil, nil
    if msg then Print(msg) end
    B.Changed()
  end
  -- where the new bag is now
  local function findNew(st)
    if st.fromBag and st.fromBag ~= st.target then
      local it = C_Container.GetContainerItemInfo(st.fromBag, st.fromSlot)
      if it and it.itemID == st.id then return st.fromBag, st.fromSlot end
    end
    for _, bag in ipairs(dests(st.target)) do
      for slot = 1, slotsOf(bag) do
        local it = C_Container.GetContainerItemInfo(bag, slot)
        if it and it.itemID == st.id then return bag, slot end
      end
    end
  end
  B.SwapFindNew = findNew
  local function step()
    if not S then return end
    S.tries = S.tries + 1
    if S.putAt and S.mode == "out" then -- the bag was put in a free slot: did it go?
      if not GetInventoryItemID("player", S.inv) and not CursorHasItem() then
        return finish("bag taken out: " .. (ns.NameOf(S.id) or "it") .. " is in your bags now.")
      end
      if GetTime() - S.putAt > 1.5 then
        if CursorHasItem() then ClearCursor() end
        return finish("the game didn't let the bag out. Its items are out of it now, so try again.")
      end
      return
    end
    if S.putAt then -- the new bag was put in: did it go?
      if GetInventoryItemID("player", S.inv) == S.id then
        local name = ns.NameOf(S.id) or "the new bag"
        return finish("bag swapped: " .. name .. " is in.")
      end
      if GetTime() - S.putAt > 1.5 then
        if CursorHasItem() then ClearCursor() end
        return finish("the game didn't take the new bag. Your items are out of the old one, so try dropping it again.")
      end
      return
    end
    if InCombatLockdown() then return finish(S.word .. " stopped: you're in a fight. Try again after it.") end
    if S.tries > 240 then return finish(S.word .. " stopped: it took too long.") end
    if CursorHasItem() or (GetCursorInfo and GetCursorInfo()) then return end
    if S.movedAt and GetTime() - S.movedAt < 0.3 then return end
    local moves, missing, count, spots = plan(S.target)
    if count == 0 and S.mode == "out" then
      -- the bag is empty: out it comes, into a free slot
      local sp = bagSpot(S.target, spots)
      if not sp then return finish("taking the bag out stopped: no free slot left for the bag itself.") end
      PickupBagFromSlot(S.inv)
      if not CursorHasItem() then return end -- (still on its way: next time)
      C_Container.PickupContainerItem(sp.bag, sp.slot)
      S.putAt = GetTime()
      return
    end
    if count == 0 then
      -- the old bag is empty: in goes the new one
      local b, sl = findNew(S)
      if not b then return finish("bag swap stopped: the new bag isn't in your bags any more.") end
      C_Container.PickupContainerItem(b, sl)
      if not CursorHasItem() then return end -- (still on its way: next time)
      PutItemInBag(S.inv)
      S.putAt = GetTime()
      return
    end
    local m
    for _, x in ipairs(moves) do if not x.locked then m = x break end end
    if not m then
      if missing > 0 and #moves == 0 then
        local st = S
        finish(nil)
        if st.mode == "out" then return B.SwapAsk(st.target, st.inv, nil, nil, nil, nil, "out") end
        return B.SwapAsk(st.target, st.inv, st.id, missing, st.fromBag, st.fromSlot)
      end
      return -- (a move is still on its way)
    end
    local sig = m.from .. ">" .. m.bag .. ":" .. m.slot .. ":" .. m.id
    if sig == S.last then
      S.fails = S.fails + 1
      if S.fails > 3 then return finish(S.word .. " stopped: the game wouldn't move " .. (m.link or ns.NameOf(m.id) or "an item") .. ".") end
    end
    S.last = sig
    C_Container.PickupContainerItem(S.target, m.from)
    C_Container.PickupContainerItem(m.bag, m.slot)
    if CursorHasItem() then
      ClearCursor()
      S.fails = S.fails + 1
    else
      carryMarks(S.target .. ":" .. m.from, m.bag .. ":" .. m.slot, m.id)
    end
    S.movedAt = GetTime()
  end
  function B.StartSwap(target, inv, id, fromBag, fromSlot)
    if InCombatLockdown() then Print("bags can't be changed in a fight.") return end
    if S then return end
    local _, _, count = plan(target)
    S = { target = target, inv = inv, id = id, fromBag = fromBag, fromSlot = fromSlot, tries = 0, fails = 0, word = "bag swap" }
    B.swap = S
    S.ticker = C_Timer.NewTicker(0.25, step)
    if count > 0 then Print("swapping bags: moving " .. count .. (count == 1 and " item" or " items") .. " out of the old bag first.") end
    step()
  end
  -- (18 Nov) take a bag with items out: he "let me be able to pluck any bag out if there is space and
  -- place it in inventory". Its items go into your other bags (and the bank while it's open) first,
  -- then the bag goes into a free slot. Called when a bag in the bags row is clicked or dragged.
  function B.StartTakeOut(target, inv)
    if InCombatLockdown() then Print("bags can't be changed in a fight.") return end
    if S then return end
    local _, _, count = plan(target)
    S = { target = target, inv = inv, id = GetInventoryItemID("player", inv), tries = 0, fails = 0, mode = "out", word = "taking the bag out" }
    B.swap = S
    S.ticker = C_Timer.NewTicker(0.25, step)
    if count > 0 then Print("taking the bag out: moving " .. count .. (count == 1 and " item" or " items") .. " out of it first.") end
    step()
  end
  function B.TryTakeOut(bag, inv)
    if not IS_BAG[bag] or not GetInventoryItemID("player", inv) then return false end
    local need, count = outNeed(bag)
    if count == 0 then return false end -- (empty: the game picks it up)
    if S then Print("a bag change is already on its way.") return true end
    if need > 0 then B.SwapAsk(bag, inv, nil, nil, nil, nil, "out") return true end
    B.StartTakeOut(bag, inv)
    return true
  end
  -- called when a bag is dropped on a bag slot in the bags row. true = Rucksack takes care of it.
  function B.TrySwap(bag, inv)
    if not IS_BAG[bag] or not GetCursorInfo then return false end
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not isBagItem(id) then return false end
    if not GetInventoryItemID("player", inv) then return false end -- (an empty slot: the game does it)
    local _, missing, count = plan(bag)
    if count == 0 then return false end -- (the old bag is empty: the game swaps them)
    if S then Print("a bag swap is already on its way.") return true end
    local fb, fs = B.HeldSlot(id)
    if missing > 0 then
      -- no room: maybe the game moves the items over itself (a bigger bag); if not, say what's missing
      PutItemInBag(inv)
      C_Timer.After(0.6, function()
        if GetInventoryItemID("player", inv) == id then return end
        if CursorHasItem() then ClearCursor() end
        local _, miss = plan(bag)
        B.SwapAsk(bag, inv, id, miss, fb, fs)
      end)
      return true
    end
    ClearCursor()
    B.StartSwap(bag, inv, id, fb, fs)
    return true
  end

  -- the box when there's no room
  local box = CreateFrame("Frame", "RucksackBagSwapAsk", UIParent, ns.BACKDROP_TMPL)
  box:SetSize(400, 140)
  box:SetPoint("TOP", UIParent, "TOP", 0, -135)
  box:SetFrameStrata("FULLSCREEN_DIALOG")
  box:SetToplevel(true)
  box:EnableMouse(true)
  if box.SetBackdrop then box:SetBackdrop(ns.DIALOG_BACKDROP) end
  box:Hide()
  tinsert(UISpecialFrames, "RucksackBagSwapAsk")
  local title = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", 0, -20)
  title:SetText("Not enough room to swap bags")
  local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOP", title, "BOTTOM", 0, -10)
  text:SetWidth(350)
  local function button(label, w)
    local b = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    b:SetSize(w, 24)
    b:SetText(label)
    return b
  end
  local junkBtn, slotBtn, swapBtn, cancelBtn = button("Delete junk", 110), button("Use the empty slot", 140), button("Swap now", 110), button("Cancel", 90)
  B.swapBox = { frame = box, text = text, junk = junkBtn, slot = slotBtn, swap = swapBtn, cancel = cancelBtn }
  local function emptyBagSlot()
    for _, bag in ipairs(BAR) do
      if bag ~= REAGENT then
        local inv = invSlot(bag)
        if inv and not GetInventoryItemID("player", inv) then return bag, inv end
      end
    end
  end
  local function refresh()
    local d = box.data
    if not d then return end
    local list = {}
    if d.mode == "out" then
      local need, count = outNeed(d.target)
      title:SetText("Not enough room to take the bag out")
      if need > 0 then
        text:SetText("The bag has " .. count .. (count == 1 and " item" or " items") .. ". Free " .. need .. " more " ..
          (need == 1 and "slot" or "slots") .. " (one is for the bag itself)" .. (bankOpen and "." or ", or open your bank: its items can go there."))
        if ns.Del and ns.Del.HasJunk and ns.Del.HasJunk() then list[#list + 1] = junkBtn end
      else
        text:SetText("There's room now.")
        list[#list + 1] = swapBtn
      end
    end
    local _, missing, count = plan(d.target)
    d.missing = missing
    if d.mode == "out" then
      -- (done above)
    elseif missing > 0 then
      title:SetText("Not enough room to swap bags")
      text:SetText("The old bag has " .. count .. (count == 1 and " item" or " items") .. ", and " .. missing ..
        (missing == 1 and " has" or " have") .. " nowhere to go. Free " .. missing .. " more " .. (missing == 1 and "slot" or "slots") ..
        (bankOpen and "." or ", or open your bank: they can go there."))
      if ns.Del and ns.Del.HasJunk and ns.Del.HasJunk() then list[#list + 1] = junkBtn end
      if d.id and emptyBagSlot() then list[#list + 1] = slotBtn end
    else
      title:SetText("Not enough room to swap bags")
      text:SetText("There's room now.")
      if d.id then list[#list + 1] = swapBtn end
    end
    swapBtn:SetText(d.mode == "out" and "Take it out" or "Swap now")
    list[#list + 1] = cancelBtn
    for _, b in ipairs({ junkBtn, slotBtn, swapBtn, cancelBtn }) do b:Hide() b:ClearAllPoints() end
    local w = 0
    for _, b in ipairs(list) do w = w + b:GetWidth() end
    w = w + 8 * (#list - 1)
    local x = -w / 2
    for _, b in ipairs(list) do
      b:SetPoint("BOTTOMLEFT", box, "BOTTOM", x, 18)
      b:Show()
      x = x + b:GetWidth() + 8
    end
    box:SetHeight(math.max(130, (text:GetStringHeight() or 30) + 100))
  end
  B.SwapRefresh = refresh
  function B.SwapAsk(target, inv, id, missing, fromBag, fromSlot, mode)
    if not target then return end
    box.data = { target = target, inv = inv or invSlot(target), id = id, missing = missing, fromBag = fromBag, fromSlot = fromSlot, mode = mode }
    refresh()
    box:Show()
  end
  junkBtn:SetScript("OnClick", function()
    if ns.Del and ns.Del.Click then ns.Del.Click() end -- (a click: the game lets an addon delete only then)
    C_Timer.After(0.5, refresh)
  end)
  slotBtn:SetScript("OnClick", function()
    local d = box.data
    box:Hide()
    if not d or InCombatLockdown() then return end
    local _, inv = emptyBagSlot()
    local b, sl = findNew(d)
    if not inv or not b then return end
    C_Container.PickupContainerItem(b, sl)
    if CursorHasItem() then PutItemInBag(inv) end
  end)
  swapBtn:SetScript("OnClick", function()
    local d = box.data
    box:Hide()
    if d and d.mode == "out" then B.StartTakeOut(d.target, d.inv)
    elseif d and d.id then B.StartSwap(d.target, d.inv, d.id, d.fromBag, d.fromSlot) end
  end)
  cancelBtn:SetScript("OnClick", function() box:Hide() end)
  box:SetScript("OnHide", function() box.data = nil end)
  box:RegisterEvent("BAG_UPDATE_DELAYED")
  box:RegisterEvent("BANKFRAME_OPENED")
  box:SetScript("OnEvent", function() if box:IsShown() then C_Timer.After(0.1, refresh) end end)
end)()

-- (19 Nov) he: "once we pluck item out with drag, the item disappears from that place right away, if we
-- right click the item returns to original location, but if we drop to the place we aim it just goes
-- there". In Groups the stack on your cursor is left out of the bag while you hold it (the others close
-- up); a right-click anywhere puts it back where it was. (Your item buttons answer the left button only
-- meanwhile, so that right-click doesn't use the item it lands on.) Not in a fight, not in One bag.
;(function()
  local lifting -- the stack lifted out: { bag, slot, id }
  local function liftOn()
    return DB and DB.style ~= "grid" and not InCombatLockdown() and f:IsShown()
  end
  function B.LiftOut(items)
    if not lifting then return items end
    local out = {}
    for _, e in ipairs(items) do
      if not (e.bag == lifting[1] and e.slot == lifting[2] and e.id == lifting[3]) then out[#out + 1] = e end
    end
    return out
  end
  local rightOnly
  local function clicks(leftOnly)
    if InCombatLockdown() then return end
    if (rightOnly and true or false) == (leftOnly and true or false) then return end
    rightOnly = leftOnly
    for _, bag in ipairs(BAGS) do
      for _, b in pairs(buttons[bag] or {}) do
        if leftOnly then pcall(b.RegisterForClicks, b, "LeftButtonUp")
        else pcall(b.RegisterForClicks, b, "LeftButtonUp", "RightButtonUp") end
      end
    end
  end
  local catch = CreateFrame("Frame")
  -- (19 Nov) drag and drop: hiding the stack you started dragging ends the game's drag, so letting go
  -- over the open space wouldn't count as a drop. The bag watches the button itself: let go over a
  -- group's + slot and it's dropped there, the same as a click on it.
  catch:SetScript("OnEvent", function(_, ev, button)
    if not (lifting and ns.CursorItem()) then return end
    if ev == "GLOBAL_MOUSE_DOWN" and button == "RightButton" then ClearCursor() return end
    if ev == "GLOBAL_MOUSE_UP" and button == "LeftButton" then
      for key, b in pairs(plusSlots) do
        if b:IsShown() and b:IsVisible() and b:IsMouseOver() then placeHeld(key) return end
      end
    end
  end)
  function B.HeldChanged(id)
    local bag, slot
    if id and liftOn() and B.HeldSlot and not B.heldSet then bag, slot = B.HeldSlot(id) end
    if bag then
      lifting = { bag, slot, id }
      clicks(true)
      pcall(catch.RegisterEvent, catch, "GLOBAL_MOUSE_DOWN")
      pcall(catch.RegisterEvent, catch, "GLOBAL_MOUSE_UP")
    else
      lifting = nil
      clicks(false)
      pcall(catch.UnregisterEvent, catch, "GLOBAL_MOUSE_DOWN")
      pcall(catch.UnregisterEvent, catch, "GLOBAL_MOUSE_UP")
    end
  end
end)()

-- (19 Nov) he: "also remove bags from blizzard UI". The game's bag bar (backpack and the bag slots at the
-- bottom right) is made invisible while Bags is on: Rucksack's own bags row has the same slots. A tick on
-- the Bags page ("Hide the game's bag buttons", on to start) turns it back on.
-- (19 Nov, fix) It was hidden with :Hide() first. That ran the game's own hide code from Rucksack, which
-- marked the bar and the menu buttons next to it as touched by an addon; learning a recipe (a new spell
-- lights up those buttons) was then blocked ("Rucksack_Bags has been blocked from an action only
-- available to the Blizzard UI"). Now it never calls Hide or Show on it: only alpha 0 and mouse off on the
-- bar and its buttons, which runs none of the game's code. The bar keeps its place, just invisible.
;(function()
  local hooked, faded
  local function want() return DB and DB.hideBagBar ~= false end
  local function fade(bar, off)
    pcall(bar.SetAlpha, bar, off and 0 or 1)
    for _, c in ipairs({ bar:GetChildren() }) do
      if c.EnableMouse and not (c.IsProtected and c:IsProtected()) then pcall(c.EnableMouse, c, not off) end
    end
    faded = off
  end
  function B.ApplyBagBar()
    local bar = rawget(_G, "BagsBar")
    if not bar or InCombatLockdown() then return end
    if not hooked and bar.HookScript then
      hooked = true
      bar:HookScript("OnShow", function(self) if want() and not InCombatLockdown() then fade(self, true) end end)
    end
    if want() then fade(bar, true) elseif faded then fade(bar, false) end
  end
  table.insert(ns.onLogin, function() pcall(B.ApplyBagBar) end)
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function() if want() then pcall(B.ApplyBagBar) end end)
end)()

-- (19 Nov) Worth more at a vendor. He: "this item in AH cost very low and it also cost to put it in AH,
-- so its better to sell it on vendor, can we mark this kind of items with some icon on top left side, and
-- have a button on the bag to sell this kind of items when we interact with vendor". Haul decides
-- (ns.VendorBetter: the vendor pays at least what the auction house leaves after its cut and the deposit;
-- Haul's own rules leave quest items, food, upgrades, rare and better, kept items alone). Here: a small
-- gold coin at the top left of such an item in your own bags (a "BoE" tag moves to the bottom left), a
-- tooltip line with the sums, and at an open vendor a button under the bag that sells all of them (each
-- stack goes on Sell once, Del.SellStack, which sells at once at a vendor).
;(function()
  local MONEY = function(c) return ns.Pocket and ns.Pocket.Coins and ns.Pocket.Coins(math.floor((c or 0) + 0.5)) or tostring(c) end
  -- e: a cell of the bag; only your own bags as they are now, not bound, not sent to the bank
  function B.VendorCheck(e)
    if not ns.VendorBetter or not e or e.empty or not e.id or not e.bag or not e.slot or e.bound then return false end
    if e.bag < 0 or e.bag > (ns.LAST_BAG or 4) then return false end
    local sid, n, link = ns.SlotInfo(e.bag, e.slot)
    if sid ~= e.id then return false end
    if B.BankSlot and B.BankSlot(e.bag, e.slot) then return false end
    local yes, r = ns.VendorBetter(e.id, link or e.link, n)
    return yes, r
  end
  function B.VendorMark(b, d, e)
    if not d.vcoin then
      d.vcoin = b:CreateTexture(nil, "OVERLAY", nil, 5)
      d.vcoin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
      d.vcoin:SetSize(12, 12)
    end
    local yes = B.VendorCheck(e) and true or false
    d.vcoin:ClearAllPoints()
    d.vcoin:SetPoint("TOPLEFT", d.dot:IsShown() and 10 or 2, -2)
    d.vcoin:SetShown(yes)
    if d.vmoved ~= yes then
      d.vmoved = yes
      d.tag:ClearAllPoints()
      if yes then d.tag:SetPoint("BOTTOMLEFT", 1, 1) else d.tag:SetPoint("TOPLEFT", 1, -1) end
    end
  end
  function B.VendorTip(tt, id)
    local owner = tt.GetOwner and tt:GetOwner()
    local e = owner and info[owner]
    local yes, r
    if e and e.id == id then yes, r = B.VendorCheck(e) elseif ns.VendorBetter then yes, r = ns.VendorBetter(id, nil, 1) end
    if not yes or not r or not r.ah then return end
    if r.counted then
      tt:AddLine("Rucksack: better at a vendor: " .. MONEY(r.vendor) .. ". The auction house leaves " .. MONEY(math.max(0, r.net)) ..
        " (" .. MONEY(r.ah) .. " - " .. MONEY(r.cut) .. " cut - " .. MONEY(r.dep) .. " deposit" .. ((r.n or 1) > 1 and ", each" or "") .. ").", 1, 0.82, 0, true)
    else
      tt:AddLine("Rucksack: better at a vendor: " .. MONEY(r.vendor) .. ". The auction house leaves " .. MONEY(math.max(0, r.net)) ..
        " (" .. MONEY(r.ah) .. " - " .. MONEY(r.cut) .. " cut).", 1, 0.82, 0, true)
    end
  end

  -- every stack in your bags a vendor pays more for -> list of { bag, slot, id, n }, items, copper
  function B.VendorList()
    local out, items, worth = {}, 0, 0
    if not ns.VendorBetter then return out, 0, 0 end
    local C = C_Container
    for bag = 0, ns.LAST_BAG or 4 do
      for slot = 1, (ns.GetNumSlots(bag) or 0) do
        local i = C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
        if i and i.itemID and not i.isBound and not i.isLocked and not (B.BankSlot and B.BankSlot(bag, slot)) then
          local n = i.stackCount or 1
          local yes, r = ns.VendorBetter(i.itemID, i.hyperlink, n)
          if yes then
            out[#out + 1] = { bag = bag, slot = slot, id = i.itemID, n = n }
            items = items + n
            worth = worth + (r.vendor or 0) * n
          end
        end
      end
    end
    return out, items, worth
  end

  local btn, ticker
  local function atVendor() return MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() and true or false end
  local function make()
    btn = CreateFrame("Button", "RucksackBagsVendorSell", f, ns.BACKDROP_TMPL)
    btn:SetHeight(20)
    if btn.SetBackdrop then
      btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
      btn:SetBackdropColor(0.12, 0.1, 0.06, 0.95)
      btn:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
    end
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    btn.icon:SetSize(12, 12)
    btn.icon:SetPoint("LEFT", 8, 0)
    btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 5, 0)
    btn:SetScript("OnClick", function()
      local list, items, worth = B.VendorList()
      if #list == 0 or not (ns.Del and ns.Del.SellStack) then return end
      for _, s in ipairs(list) do
        if ns.Sell and ns.Sell.forced then ns.Sell.forced[s.bag .. ":" .. s.slot] = true end -- (sold even with Once's sell tick off)
        pcall(ns.Del.SellStack, s.bag, s.slot, s.id)
      end
      Print("selling " .. items .. (items == 1 and " item" or " items") .. " a vendor pays more for: " .. MONEY(worth) .. ".")
      btn:Hide()
    end)
    btn:SetScript("OnEnter", function(self)
      self:SetBackdropBorderColor(1, 0.82, 0, 1)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Sell to the vendor")
      GameTooltip:AddLine("Sells every item with the gold coin: a vendor pays more for it than the auction house leaves you after its cut and the deposit. Only these stacks, nothing else.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.62, 0.5, 0.3, 1) GameTooltip:Hide() end)
  end
  function B.VendorButton()
    if not atVendor() or not (ns.Del and ns.Del.SellStack) or not f:IsShown() then if btn then btn:Hide() end return end
    local list, items, worth = B.VendorList()
    if #list == 0 then if btn then btn:Hide() end return end
    if not btn then make() end
    btn.text:SetText("Sell " .. items .. (items == 1 and " item" or " items") .. " to the vendor (" .. MONEY(worth) .. ")")
    btn:SetWidth(math.floor((btn.text:GetStringWidth() or 120) + 33))
    btn:ClearAllPoints()
    local bottom = f:GetBottom()
    if bottom and bottom < 26 then btn:SetPoint("BOTTOM", f, "TOP", 0, 2) else btn:SetPoint("TOP", f, "BOTTOM", 0, -2) end
    btn:Show()
  end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("MERCHANT_SHOW")
  ev:RegisterEvent("MERCHANT_CLOSED")
  ev:SetScript("OnEvent", function(_, event)
    if ticker then ticker:Cancel() ticker = nil end
    if event == "MERCHANT_SHOW" then
      ticker = C_Timer.NewTicker and C_Timer.NewTicker(1, function() pcall(B.VendorButton) end)
      C_Timer.After(0.3, function() pcall(B.VendorButton) end)
    elseif btn then btn:Hide() end
  end)
  f:HookScript("OnShow", function() pcall(B.VendorButton) end)
end)()

-- (19 Nov, 21:06) The tool row. He: "take this icons out of bag row and put it below rucksack icon and bag
-- row goes in between them when we open them on leftest put Haul icon then the rest". Always shown, under
-- the header (and under the bags row while that's open): Haul, Boxes corner, Restock, Hidden. The
-- Auto-sort button is gone (he wasn't sure it made sense): sorting by itself is always on in Groups.
;(function()
  B.TOOL_H = 26
  local tools = CreateFrame("Frame", "RucksackBagsTools", f)
  tools:SetHeight(B.TOOL_H)
  B.tools = tools
  local S = 22 / 30
  local haul = iconButton(tools, 30, "haul", function()
    local H = ns.Haul
    if not H or not H.cur then return "Haul" end
    return "Haul  " .. (not H.Running() and "|cff888888stopped|r" or H.cur.paused and "|cffff8040paused|r" or "|cff55dd55running|r")
  end, function()
    local H = ns.Haul
    if not H then return "What your loot is worth and your gold per hour. Turn Haul on on Rucksack's Modules page." end
    return "Click: open or close Haul.\nRight-click: " .. (not H.Running() and "Start." or H.cur.paused and "Resume." or "Pause.")
  end, function(self, button)
    local H = ns.Haul
    if not H then Rucksack_Open("general") return end
    if button == "RightButton" then
      if not H.Running() then H.Start() else H.SetPaused(not H.cur.paused) end
    elseif H.UI then H.UI.Toggle() end
    B.PaintTools()
  end, "RucksackBagsHaulButton")
  -- (19 Nov, 21:23) he: "put add track bar, we can open up to 5 of them"
  local track = iconButton(tools, 30, "track", "Add a Track bar", function()
    local IB = B.ItemBar
    local n = IB and IB.Count and IB.Count() or 0
    return "A small bar that stays on screen and shows how many of an item you carry. Click: open " ..
      (n == 0 and "the Track bar." or "another one (" .. n .. " of 5 open).") .. "\nClick \"Track\" on a bar for its settings, or to close it."
  end, function() if B.ItemBar and B.ItemBar.Open then B.ItemBar.Open() end end, "RucksackBagsTrackButton")
  -- (19 Nov, 21:31) he: "put add track bar right from haul and put boxes on top": Haul, Track, Restock,
  -- Hidden; the Boxes button goes into the header, left of Your characters
  local list = { haul, track, B.restockBtn, hiddenBtn }
  B.sideBtn:SetParent(f)
  B.sideBtn:SetScale(S)
  B.sideBtn:ClearAllPoints()
  B.sideBtn:SetPoint("RIGHT", whoBtn, "LEFT", -3 / S, 0)
  search:SetPoint("RIGHT", B.sideBtn, "LEFT", -7 * S, 0)
  for i, b in ipairs(list) do
    b:SetParent(tools)
    b:SetScale(S)
    b:ClearAllPoints()
    b:SetPoint("LEFT", tools, "LEFT", ((i - 1) * 25) / S, 0)
  end
  B.haulBtn = haul
  B.autoBtn:Hide()
  B.autoBtn:SetParent(tools)
  function B.PaintTools()
    local H = ns.Haul
    lightUp(haul, H and H.Running and H.Running() and not (H.cur and H.cur.paused) or false)
  end
  local draw = B.Draw
  B.Draw = function(...)
    local r = draw(...)
    pcall(B.PaintTools)
    return r
  end
  table.insert(ns.onLogin, function() if B.db then B.db.autoSort = nil end pcall(B.PaintTools) end)
end)()

-- (19 Nov) a set item dropped somewhere it can't go: it goes back, and chat says why
function B.SetRefuse(id, link)
  local r = B.Sets and B.Sets.Of(id)
  Print((link or ns.NameOf(id) or "That item") .. " is in your equipment set \"" .. (r and r.name or "?") ..
    "\": it stays where it is (you can put it on). Take it out of the set to move, sell or delete it.")
end
