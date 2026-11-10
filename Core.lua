-- Rucksack: Rations (eat and drink) and Clean-up (delete and sell) in one addon.
--   Core.lua   shared helpers, saved settings, slash commands
--   Delete.lua AutoDelete: the Always / Yes / No box, the remembered items, deleted history, the trash button
--   Eat.lua    EatDrink: best plain food and water, the macro and the on-screen button
--   UI.lua     the window: items on the left, the chosen item's settings on the right
local ADDON, ns = ...

ns.PREFIX = "|cffc8a165Ruck|r|cffffd100sack|r: "
function ns.Print(msg) DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. msg) end

local C = C_Container
ns.GetNumSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
ns.PickupBagItem = (C and C.PickupContainerItem) or PickupContainerItem
ns.SplitBagItem = (C and C.SplitContainerItem) or SplitContainerItem
ns.GetQuestInfo = (C and C.GetContainerItemQuestInfo) or GetContainerItemQuestInfo
ns.GetFree = (C and C.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
ns.GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
ns.GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
ns.GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount
ns.NUM_BAGS = NUM_BAG_SLOTS or 4

function ns.SlotInfo(bag, slot)
  if C and C.GetContainerItemInfo then
    local i = C.GetContainerItemInfo(bag, slot)
    if i then return i.itemID, i.stackCount or 1, i.hyperlink, i.iconFileID, i.isLocked end
    return nil
  end
  local icon, count, locked, _, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
  return id, count or 1, link, icon, locked
end

function ns.ItemName(link) return link and link:match("%[(.-)%]") or nil end
function ns.QualityOf(id, link)
  local _, _, q = ns.GetInfo(link or id)
  if q ~= nil then return q end
  if type(link) == "string" then
    local iq = link:match("|cnIQ(%d):")
    if iq then return tonumber(iq) end
    local hex = link:match("|cff(%x%x%x%x%x%x)")
    if hex then
      hex = hex:lower()
      if hex == "9d9d9d" then return 0
      elseif hex == "ffffff" then return 1
      elseif hex == "1eff00" then return 2
      elseif hex == "0070dd" then return 3
      elseif hex == "a335ee" then return 4
      elseif hex == "ff8000" then return 5 end
    end
  end
  return nil
end
function ns.NameOf(id, link)
  local fromLink = type(link) == "string" and ns.ItemName(link) or nil
  if fromLink and fromLink ~= "" then return fromLink end
  local meta = ns.del and ns.del.meta and ns.del.meta[id]
  if meta and meta.name and meta.name ~= "" then return meta.name end
  local name = ns.GetInfo(id)
  return name or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item " .. tostring(id))
end
function ns.LinkOf(id, fallbackLink)
  local _, link = ns.GetInfo(id)
  if link then return link end
  if type(fallbackLink) == "string" then return fallbackLink end
  local meta = ns.del and ns.del.meta and ns.del.meta[id]
  if meta and type(meta.link) == "string" then return meta.link end
  return nil
end

function ns.CursorItem()
  local t, id, link = GetCursorInfo()
  if t == "item" and id then return id, link end
end

-- Rucksack's own icon: custom leather backpack (minimap button, window title, General, AddOn list)
ns.ICON = "Interface\\AddOns\\Rucksack\\Icon"

ns.BACKDROP_TMPL = BackdropTemplateMixin and "BackdropTemplate" or nil
ns.DIALOG_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
ns.SLOT_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function ns.ShowItemTooltip(owner, id, link, anchor)
  GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
  local h = (type(link) == "string" and link:match("|H(item:[^|]+)|h")) or ("item:" .. id)
  pcall(GameTooltip.SetHyperlink, GameTooltip, h)
  GameTooltip:Show()
end

-- run when the saved settings are loaded, and on login
ns.onLoad, ns.onLogin = {}, {}
-- anything that shows items (the window) asks to be told when they change
ns.listeners = {}
function ns.Changed() for _, fn in ipairs(ns.listeners) do pcall(fn) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    -- (10 Nov) AutoDelete and Eat & Drink keep their settings under Rucksack's own names now
    -- (other addons use AutoDeleteDB / EatDrinkDB too). Settings from earlier Rucksack versions
    -- move over once: only when Rucksack has run here before, so another addon's are never taken.
    local before = RucksackDB ~= nil
    RucksackDB = RucksackDB or {}
    if RucksackDeleteDB == nil and before and type(AutoDeleteDB) == "table" and type(AutoDeleteDB.items) == "table" then
      RucksackDeleteDB = AutoDeleteDB
    end
    if RucksackEatDB == nil and before and type(EatDrinkDB) == "table" then RucksackEatDB = EatDrinkDB end
    RucksackDeleteDB = RucksackDeleteDB or {}
    RucksackEatDB = RucksackEatDB or {}
    ns.db, ns.del, ns.eat = RucksackDB, RucksackDeleteDB, RucksackEatDB
    -- (10 Nov) this character's own settings: warriors and rogues drink nothing, so their water goes
    RucksackCharDB = RucksackCharDB or {}
    ns.char = RucksackCharDB
    if ns.char.noWater == nil then
      local _, class = UnitClass("player")
      ns.char.noWater = (class == "WARRIOR" or class == "ROGUE") and true or false
    end
    for _, fn in ipairs(ns.onLoad) do fn() end
    self:UnregisterEvent("ADDON_LOADED")
  else
    for _, fn in ipairs(ns.onLogin) do fn() end
  end
end)

-- /ruck opens the window; /adel on AutoDelete, /eatdrink on EatDrink
SLASH_RUCKSACK1 = "/ruck"
SLASH_RUCKSACK2 = "/rucksack"
SlashCmdList.RUCKSACK = function(msg)
  local m = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if m == "minimap" then
    ns.db.minimapHidden = not ns.db.minimapHidden or nil
    ns.UpdateMinimapButton()
    return
  end
  if m == "undokey" then if ns.UndoKey then ns.UndoKey() end return end
  if m == "del" or m == "delete" or m == "cleanup" or m == "clean" then Rucksack_Open("del") return end
  if m == "eat" or m == "drink" or m == "rations" then Rucksack_Open("eat") return end
  if m == "pocket" then if ns.Pocket then ns.Pocket.Toggle() end return end
  if m == "settings" then Rucksack_Open("general") return end
  if m == "" then Rucksack_Toggle() return end
  ns.Print("|cffffd100/ruck|r opens the window.  |cffffd100/rations|r, |cffffd100/cleanup|r: those pages.  |cffffd100/ruck pocket|r: the small info window.  |cffffd100/ruck minimap|r: the minimap button.")
end

BINDING_HEADER_RUCKSACK = "Rucksack"
BINDING_NAME_AUTODELETE_NOW = "Clean-up: delete the next item"
BINDING_NAME_AUTODELETE_TOGGLE = "Open Rucksack"
_G["BINDING_NAME_CLICK EatDrinkButton:LeftButton"] = "Rations: eat and drink"
_G["BINDING_NAME_CLICK RucksackFoodButton:LeftButton"] = "Rations: food only"
_G["BINDING_NAME_CLICK RucksackDrinkButton:LeftButton"] = "Rations: water only"

-- The numbers Home and the Pocket show (10 Nov). Cheap enough to build on every bag change.
function ns.Summary()
  local S = { notes = {} }
  local Del, Eat, Sell, D, E = ns.Del, ns.Eat, ns.Sell, ns.del or {}, ns.eat or {}
  S.free = Del and Del.FreeSlots() or 0
  S.total = Del and Del.TotalSlots() or 0
  S.minFree = D.minFree or 2
  -- Rations
  if Eat and Eat.Pick and E.enabled ~= false then pcall(Eat.Pick) end
  S.food, S.drink = Eat and Eat.food, Eat and Eat.drink
  S.foodCount = S.food and (ns.GetCount(S.food) or 0) or 0
  S.drinkCount = S.drink and (ns.GetCount(S.drink) or 0) or 0
  local rules = {}
  if ns.char and ns.char.noWater then rules[#rules + 1] = "all water" end
  if E.delBelow == "auto" then rules[#rules + 1] = "food weak for your level"
  elseif type(E.delBelow) == "number" then rules[#rules + 1] = "food below level " .. E.delBelow end
  S.eatRules = #rules > 0 and table.concat(rules, ", ") or "|cff999999nothing|r"
  -- Clean-up
  S.waitStacks, S.waitItems = 0, 0
  if Del and D.enabled then
    local any, items, stacks = Del.Scan(false)
    S.waitAny, S.waitItems, S.waitStacks = any, items or 0, stacks or 0
    S.nextDel = Del.Scan(true) or any
  end
  S.sellValue, S.sellCount = 0, 0
  if Sell then
    local list, value = Sell.Items()
    S.sellList, S.sellValue, S.sellCount = list, value or 0, #list
  end
  -- what Rucksack is doing on its own
  if S.total > 0 and S.free < S.minFree then
    S.notes[#S.notes + 1] = ("|cffff6060Your bags are nearly full|r (%d free): Clean-up deletes what's on your list as you loot."):format(S.free)
  end
  local kept, names = 0, {}
  for id, n in pairs(Del and Del.KeptForQuest() or {}) do
    kept = kept + 1
    if #names < 4 then names[#names + 1] = ns.NameOf(id) .. " x" .. n end
  end
  if kept > 0 then
    S.notes[#S.notes + 1] = "Kept for your quests: " .. table.concat(names, ", ") .. (kept > 4 and (" and " .. (kept - 4) .. " more") or "") .. "."
  end
  if ns.char and ns.char.noWater then
    S.notes[#S.notes + 1] = "This character deletes water as soon as it gets it (Rations page)."
  end
  if E.delBelow == "auto" then
    S.notes[#S.notes + 1] = "Food and water too weak for your level go when your bags fill up."
  elseif type(E.delBelow) == "number" then
    S.notes[#S.notes + 1] = ("Food and water for below level %d go when your bags fill up."):format(E.delBelow)
  end
  if D.sellList then
    S.notes[#S.notes + 1] = "At a vendor, your Clean-up items are sold instead of deleted."
  end
  return S
end
