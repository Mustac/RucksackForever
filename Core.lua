-- Rucksack 1.7: the core (window, Home, Settings, Guide, Pocket, minimap button) and modules,
-- each its own folder that only loads when it's ticked in Settings > Modules:
--   Rucksack_Rations  eat and drink        Rucksack_CleanUp  delete and sell
--   Rucksack_Faire    the Darkmoon Faire
-- The modules are "load on demand": the game never loads them by itself, the core loads the
-- ticked ones. An unticked module isn't loaded at all (no code, no events, no memory).
-- All of them share one table, the global Rucksack (this file's namespace).
local ADDON, ns = ...
Rucksack = ns

-- the modules: each registers itself (key, name, folder) when it loads
ns.MODULES = {
  { key = "eat", folder = "Rucksack_Rations", name = "Rations", what = "eat and drink with one click" },
  { key = "del", folder = "Rucksack_CleanUp", name = "Clean-up", what = "delete or sell what you don't need" },
  { key = "faire", folder = "Rucksack_Faire", name = "Darkmoon Faire", what = "tickets, turn-ins and prizes" },
  { key = "scrolls", folder = "Rucksack_Scrolls", name = "Scrolls", what = "mages: one click deciphers a scroll" },
}
ns.loaded = {}   -- key -> true once that module's files ran
function ns.Has(key) return ns.loaded[key] and true or false end
-- a module calls this first: when its saved settings arrive (its ADDON_LOADED), init() sets them up,
-- then its own ns.onLoad functions run, the same moment they always did
-- Done once per module, whichever comes first: its own ADDON_LOADED, LoadAddOn returning, or the
-- login (the game can hold a load-on-demand addon's ADDON_LOADED back until after login).
ns.pending = {}
local function finish(m)
  if m.done then return end
  m.done = true
  if m.init then m.init() end
  ns.loaded[m.key] = true -- (counts as loaded once its settings are in place)
  for i = m.first, m.lastLoad or #ns.onLoad do ns.onLoad[i]() end
  -- ticked while playing (after login): run its login setup now too
  if ns.loggedIn then
    for i = m.firstLogin, m.lastLogin or #ns.onLogin do pcall(ns.onLogin[i]) end
    ns.Changed()
  end
end
function ns.FinishModules() for _, m in pairs(ns.pending) do finish(m) end end
function ns.Module(key, addon, init)
  local m = { key = key, addon = addon, init = init, first = #ns.onLoad + 1, firstLogin = #ns.onLogin + 1 }
  ns.pending[addon] = m
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:SetScript("OnEvent", function(self, _, name)
    if name ~= addon then return end
    self:UnregisterAllEvents()
    finish(m)
  end)
end

-- (1.7.4) which modules to load: ticked in Settings > Modules, always per character.
-- New: everything on, except Scrolls, which is on for mages only.
function ns.ModuleWanted(key)
  local mods = ns.char and ns.char.modules
  if mods and mods[key] ~= nil then return mods[key] end
  if key == "scrolls" then
    local _, class = UnitClass("player")
    return class == "MAGE"
  end
  return true
end
function ns.SetModuleWanted(key, on)
  ns.char.modules = ns.char.modules or {}
  ns.char.modules[key] = on and true or false
end
-- (1.7.4) once per character: take over the old choices (this character's own, or the account's),
-- and decide Scrolls by class
local function moduleChoicesOnce()
  local c = ns.char
  if c.modulesPerChar then return end
  local src = (c.ownModules and c.modules) or (ns.db and ns.db.modules) or {}
  local mods = {}
  for _, m in ipairs(ns.MODULES) do
    if m.key ~= "scrolls" and src[m.key] ~= nil then mods[m.key] = src[m.key] and true or false end
  end
  local _, class = UnitClass("player")
  if class then mods.scrolls = (class == "MAGE") end
  c.modules, c.ownModules, c.modulesPerChar = mods, nil, true
end
-- load a module now; returns true, or false and why ("DISABLED" = unticked in the game's AddOns list)
local loadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
function ns.LoadModule(m)
  if ns.Has(m.key) then return true end
  if not loadAddOn then return false, "MISSING" end
  local ok, loaded, reason = pcall(loadAddOn, m.folder)
  if not ok then return false, "ERROR" end
  if not loaded then m.why = reason return false, reason end
  m.why = nil
  -- its files and saved settings are in now: set it up right away
  local p = ns.pending[m.folder]
  if p then
    p.lastLoad, p.lastLogin = p.lastLoad or #ns.onLoad, p.lastLogin or #ns.onLogin
    finish(p)
  end
  return true
end

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

-- free and total ordinary bag slots (core: Home and the Pocket need them without Clean-up)
function ns.FreeSlots()
  local free = 0
  for bag = 0, ns.NUM_BAGS do
    local n, family = ns.GetFree(bag)
    if n and (family == nil or family == 0) then free = free + n end
  end
  return free
end
function ns.TotalSlots()
  local n = 0
  for bag = 0, ns.NUM_BAGS do
    local _, family = ns.GetFree(bag)
    if family == nil or family == 0 then n = n + (ns.GetNumSlots(bag) or 0) end
  end
  return n
end

-- (1.7) modules can ask Clean-up to keep items (Faire turn-in items, undeciphered scrolls...):
-- each adds a function(id) to ns.keepers that says true for items to keep
ns.keepers = {}
function ns.KeepItem(id)
  if not id then return false end
  for _, fn in ipairs(ns.keepers) do
    local ok, keep = pcall(fn, id)
    if ok and keep then return true end
  end
  return false
end

-- (1.7.4) what an item is used for, in words, so deleting it by hand warns you first. Each module
-- adds a function(id, link) to ns.uses that returns a line (or nil); a module that isn't loaded
-- adds nothing.
ns.uses = {}
function ns.UsedFor(id, link)
  local out = {}
  if not id then return out end
  for _, fn in ipairs(ns.uses) do
    local ok, line = pcall(fn, id, link)
    if ok and type(line) == "string" then out[#out + 1] = line end
  end
  local q = select(3, ns.GetInfo(link or id))
  if q and q >= 3 then out[#out + 1] = "a rare or better item" end
  return out
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
    -- the core's own settings; each module keeps its own
    RucksackDB = RucksackDB or {}
    ns.db = RucksackDB
    -- (1.7) settings from 1.x lived in this addon's saved file; the modules take them over the
    -- first time they load (after that they're saved in the module's own file)
    ns.legacy = { eat = RucksackEatDB, del = RucksackDeleteDB, faire = RucksackFaireDB, faireChar = RucksackFaireCharDB }
    -- (10 Nov) this character's own settings: warriors and rogues drink nothing, so their water goes
    RucksackCharDB = RucksackCharDB or {}
    ns.char = RucksackCharDB
    if ns.char.noWater == nil then
      local _, class = UnitClass("player")
      ns.char.noWater = (class == "WARRIOR" or class == "ROGUE") and true or false
    end
    -- (the core's own; each module runs its own when it loads, see ns.Module)
    for _, fn in ipairs(ns.onLoad) do fn() end
    self:UnregisterEvent("ADDON_LOADED")
    moduleChoicesOnce()
    -- (1.7) now load the ticked modules
    for _, m in ipairs(ns.MODULES) do
      if ns.ModuleWanted(m.key) then ns.LoadModule(m) end
    end
  else
    ns.FinishModules() -- (any module still waiting for its setup)
    for _, fn in ipairs(ns.onLogin) do fn() end
    ns.loggedIn = true
  end
end)

-- (1.7.4) the only commands: /ruck and /rucksack open and close the window (anything after them is ignored)
SLASH_RUCKSACK1 = "/ruck"
SLASH_RUCKSACK2 = "/rucksack"
SlashCmdList.RUCKSACK = function() Rucksack_Toggle() end

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
  S.free = ns.FreeSlots()
  S.total = ns.TotalSlots()
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
