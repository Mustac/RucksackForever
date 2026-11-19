-- Rucksack / Bags: Armour sets (19 Nov)
-- He: "implement a Armor Sets Category where its sorted by equipment manager starting from item in
-- first set, then another, those items are locked and cant be sold, unless I unlock that category,
-- right from the category is a lock and it makes red overlay on items, transparent red overlay so we
-- cant touch them, if there is no item in inventory that belongs in any set then category is not
-- present in bag, as soon as its from some set then it appears".
-- Sets come from the game's equipment manager (C_EquipmentSet, if this client has it) and from
-- ItemRack's sets (names starting with "~" are ItemRack's own, skipped). Order: the game's sets in
-- its order, then ItemRack's by name; inside a set by equipment slot. An item in two sets counts
-- for the first.
-- Locked (as it comes, RucksackBagsDB.setsLock ~= false): Clean-up never sells or throws them away
-- (ns.keepers), and each one in your bags has a see-through red cover that takes the mouse, so it
-- can't be clicked, dragged or equipped by accident. The padlock right of the group's name
-- unlocks them (or locks them again).
local ns = Rucksack
if not ns or not ns.Bags or not ns.Bags.MAIN then return end
local B = ns.Bags
local S = {}
B.Sets = S

local cache, cacheAt, cacheSig = {}, -10, nil
S.names = {}

local function irID(s)
  if type(s) ~= "string" then return nil end
  local id = tonumber(s:match("^(%-?%d+)"))
  return id and id > 0 and id or nil
end

-- itemID -> { set = order, slot = equipment slot, name = set name }
function S.Read(force)
  local now = GetTime and GetTime() or 0
  if not force and now - cacheAt < 2 then return cache end
  cacheAt = now
  local of, names, n = {}, {}, 0
  local function add(name, slotIDs)
    n = n + 1
    names[n] = name
    for slot = 0, 19 do
      local id = slotIDs[slot]
      if id and id > 1 and not of[id] then of[id] = { set = n, slot = slot, name = name } end
    end
  end
  local ES = C_EquipmentSet
  if ES and ES.GetEquipmentSetIDs then
    local ok, ids = pcall(ES.GetEquipmentSetIDs)
    for _, setID in ipairs(ok and ids or {}) do
      local okN, name = pcall(ES.GetEquipmentSetInfo, setID)
      local okI, items = pcall(ES.GetItemIDs, setID)
      if okI and type(items) == "table" then add(okN and name or ("Set " .. setID), items) end
    end
  end
  local IR = rawget(_G, "ItemRackUser")
  if type(IR) == "table" and type(IR.Sets) == "table" then
    local list = {}
    for name, set in pairs(IR.Sets) do
      if type(name) == "string" and name:sub(1, 1) ~= "~" and type(set) == "table" and type(set.equip) == "table" then list[#list + 1] = name end
    end
    table.sort(list)
    for _, name in ipairs(list) do
      local slots = {}
      for slot, s in pairs(IR.Sets[name].equip) do
        local k = tonumber(slot)
        if k then slots[k] = irID(s) end
      end
      add(name, slots)
    end
  end
  cache, S.names = of, names
  local sig = {}
  for id, r in pairs(of) do sig[#sig + 1] = id .. ":" .. r.set .. ":" .. r.slot end
  table.sort(sig)
  sig = table.concat(sig, ",")
  if cacheSig and sig ~= cacheSig and B.Changed then C_Timer.After(0, B.Changed) end
  cacheSig = sig
  return of
end

function S.Of(id)
  if not id then return nil end
  return S.Read()[id]
end
-- for sorting: first set first, then the equipment slot
function S.Order(id)
  local r = S.Of(id)
  return r and (r.set * 100 + r.slot) or nil
end
-- (19 Nov, 21:02) he: "I should be able to drag and drop locked items onto my character but I should not be
-- able to delete or disenchant or sell that item unless that item is outside Equipment manager set,
-- remove lock this is default behaviours". So: no padlock, always kept; the slot is tinted red
-- (Bags.lua show); the item works like any other (click, drag, equip) except at a vendor and while a
-- spell waits for an item (Disenchant and the like): then an invisible cover over it takes the click.
-- At a vendor a left-click or a drag still picks it up (to put it on); a right-click (sell) is refused.
-- Deleting it (dropping it outside the bag) is refused in Delete.lua.
function S.Locked() return true end
function S.SetLocked() end

-- Clean-up keeps them
table.insert(ns.keepers, function(id) return S.Of(id) ~= nil end)

local covers = setmetatable({}, { __mode = "k" })
local function vendorOpen() return MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() and true or false end
local function targeting() return SpellIsTargeting and SpellIsTargeting() and true or false end
local function guarding() return vendorOpen() or targeting() end
local function name(e) return (e and (e.link or ns.NameOf(e.id))) or "That item" end
local function coverTip(self)
  local e = self.e
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if e and e.bag and e.slot and GameTooltip.SetBagItem then
    pcall(GameTooltip.SetBagItem, GameTooltip, e.bag, e.slot)
  elseif e and e.link then
    pcall(GameTooltip.SetHyperlink, GameTooltip, e.link)
  end
  local r = e and S.Of(e.id)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cffff6060In your set|r \"" .. (r and r.name or "?") .. "\": it can't be sold, deleted or disenchanted.", 1, 1, 1, true)
  if vendorOpen() then GameTooltip:AddLine("Drag it onto your character to wear it.", 0.75, 0.75, 0.75, true) end
  GameTooltip:Show()
end
local function pickup(self)
  local e = self.e
  if not e or not e.bag or not e.slot or InCombatLockdown() then return end
  local C = C_Container
  local fn = C and C.PickupContainerItem or PickupContainerItem
  if fn then pcall(fn, e.bag, e.slot) end
end
function S.Cover(b, e, on)
  if InCombatLockdown() then return end
  local c = covers[b]
  if not on then
    if c then c:Hide() c.e = nil end
    return
  end
  if not c then
    c = CreateFrame("Button", nil, b)
    c:SetAllPoints(b)
    c:EnableMouse(true)
    c:RegisterForClicks("AnyUp")
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnClick", function(self, button)
      if targeting() then
        ns.Print(name(self.e) .. " is in one of your equipment sets: it isn't used for that. Right-click to stop the spell.")
      elseif button == "LeftButton" then
        pickup(self)
      else
        ns.Print(name(self.e) .. " is in one of your equipment sets: it isn't sold. Take it out of the set first.")
      end
    end)
    c:SetScript("OnDragStart", function(self) if not targeting() then pickup(self) end end)
    c:SetScript("OnReceiveDrag", function() ClearCursor() end)
    c:SetScript("OnEnter", coverTip)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    covers[b] = c
  end
  c.e = e
  c:SetFrameLevel((b:GetFrameLevel() or 1) + 6)
  c.wanted = true
  c:SetShown(guarding())
end
-- the vendor opened or closed, a spell started or stopped waiting for an item: covers on or off
function S.Guard()
  if InCombatLockdown() then return end
  local on = guarding()
  for _, c in pairs(covers) do if c.e then c:SetShown(on) end end
end
function S.LockButton() end -- (the padlock is gone)

do
  local gev = CreateFrame("Frame")
  for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "CURRENT_SPELL_CAST_CHANGED", "CURSOR_CHANGED", "SPELLCAST_STOP" }) do pcall(gev.RegisterEvent, gev, e) end
  gev:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then C_Timer.After(0, S.Guard) else S.Guard() end
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function() S.Read(true) end)
