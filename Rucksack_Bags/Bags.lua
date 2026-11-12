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
local REAGENT = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
local BAGS, BAR, IS_BAG = { 0, 1, 2, 3, 4, REAGENT }, { 1, 2, 3, 4, REAGENT }, {}
for _, b in ipairs(BAGS) do IS_BAG[b] = true end
-- your bank: WoW Forever has bank tabs; older clients the bank and its bag slots
local function bankIDs()
  local out = {}
  local E = Enum and Enum.BagIndex
  if E and E.CharacterBankTab_1 then
    for i = 1, 9 do local id = E["CharacterBankTab_" .. i] if id then out[#out + 1] = id end end
  else
    out[1] = BANK_CONTAINER or -1
    local first = (NUM_BAG_SLOTS or 4) + 1
    for i = 0, (NUM_BANKBAGSLOTS or 6) - 1 do if first + i ~= REAGENT then out[#out + 1] = first + i end end
  end
  return out
end
B.BankIDs = bankIDs

B.CATS = {
  { key = "new", name = "New", color = { 1, 0.82, 0 } },
  { key = "weapon", name = "Weapons", color = { 0.88, 0.42, 0.35 } },
  { key = "armor", name = "Armour", color = { 0.42, 0.61, 0.88 } },
  { key = "food", name = "Food and water", color = { 0.88, 0.64, 0.35 } },
  { key = "consumable", name = "Potions and consumables", color = { 0.69, 0.48, 0.88 } },
  { key = "trade", name = "Trade goods", color = { 0.55, 0.7, 0.45 } },
  { key = "quest", name = "Quest", color = { 1, 0.89, 0.36 } },
  { key = "other", name = "Everything else", color = { 0.6, 0.6, 0.6 } },
  { key = "junk", name = "Junk", color = { 0.9, 0.3, 0.3 } },
  { key = "empty", name = "Empty", color = { 0.35, 0.35, 0.35 } },
  { key = "emptyR", name = "Empty · reagents only", color = { 0.3, 0.45, 0.3 } },
  { key = "emptyS", name = "Empty · special bag", color = { 0.3, 0.38, 0.45 } },
}
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
    ALL[#ALL + 1] = c
    CAT[c.key] = c
  end
end
rebuild()
B.CAT = CAT
local held -- the item on your cursor (groups get a slot to drop it on)
-- groups you can put an item in by hand (not Empty, not New)
local function placeable(key) return CAT[key] and key ~= "new" and not key:find("^empty") and true or false end
B.Placeable = placeable
-- the groups in your order (DB.order: keys; groups it doesn't know yet go at the end)
function B.Ordered()
  local list, seen = {}, {}
  for _, k in ipairs(DB and DB.order or {}) do
    if CAT[k] and not seen[k] then seen[k] = true list[#list + 1] = CAT[k] end
  end
  for _, c in ipairs(ALL) do if not seen[c.key] then list[#list + 1] = c end end
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
  if DB.order then
    local at = #DB.order + 1
    for i, k in ipairs(DB.order) do if k == "empty" then at = i break end end
    table.insert(DB.order, at, key)
  end
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
-- where Rucksack puts an item by itself (noYours) or with your choice (DB.assign: id -> group)
function B.Category(id, link, bag, slot, noYours)
  if junkKind(id, bag, slot) then return "junk" end
  local yours = not noYours and DB and DB.assign and DB.assign[id]
  if yours and placeable(yours) and yours ~= "junk" then return yours end
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
  if ns.Has("eat") and ns.Eat and ns.Eat.found and ns.Eat.found[id] then return "food" end
  if classID == 7 or classID == 9 then return "trade" end
  if classID == 2 then return "weapon" end
  if classID == 4 then return "armor" end
  if classID == 0 then return "consumable" end
  return "other"
end
local function catShown(key)
  if key == "new" then return DB.showNew ~= false end
  if CAT[key] and CAT[key].custom then return true end
  return key == "junk" or key:find("^empty") or key == "other" or DB.cats[key] ~= false
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
function B.SaveBags()
  if not DB then return end
  local r = myRec()
  r.bags = countIn(BAGS)
  r.money = GetMoney and GetMoney() or r.money
  r.seen = time()
end
function B.SaveBank()
  if not DB or not bankOpen then return end
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
  if not DB or DB.tipWhere == false or not id or not tt or not tt.AddLine then return end
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
f:SetFrameStrata("MEDIUM")
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
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
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
chev:Hide()
-- the arrow shows while the mouse is on Rucksack (or the arrow), and stays while the row is open
local function chevCheck()
  if DB and DB.barOpen then chev:Show() return end
  if logo:IsMouseOver() or chev:IsMouseOver() then chev:Show() else chev:Hide() end
end
logo:SetScript("OnEnter", function(self)
  chev:Show()
  if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1, 0.82, 0) end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Rucksack")
  GameTooltip:AddLine("The arrow next to it opens or closes your bags row. Click here: the same.", 1, 1, 1, true)
  GameTooltip:Show()
end)
logo:SetScript("OnLeave", function(self)
  if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.4, 0.36, 0.28) end
  GameTooltip:Hide()
  C_Timer.After(0.25, chevCheck)
end)
logo:SetScript("OnClick", function() B.ToggleBar() end)
chev:HookScript("OnLeave", function() C_Timer.After(0.25, chevCheck) end)
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", -2, -4)
local optBtn = iconButton(f, 22, "gear", "Settings", "Columns, size, Rows or Packed, how One bag sorts, which groups show, and more.",
  function() Rucksack_Open("bags") end)
optBtn:SetPoint("RIGHT", close, "LEFT", -1, 0)
local lookBtn = iconButton(f, 22, "groups", function() return DB and DB.style == "grid" and "Look: One bag" or "Look: Groups" end, function()
  return DB and DB.style == "grid" and "No groups: everything in one bag, sorted (by kind, quality or name: see Settings). Junk sits under it, at the bottom.\n\nClick: Groups." or
    "Your items in labelled groups (Weapons, Armour, Food and water... and your own), each on its own row or side by side.\n\nClick: One bag (no groups, just sorted)."
end, function() DB.style = DB.style == "grid" and "groups" or "grid" B.Changed() end)
lookBtn:SetPoint("RIGHT", optBtn, "LEFT", -3, 0)
local stackBtn = iconButton(f, 22, "merged", function() return DB and DB.merged and "Stacks: Merged" or "Stacks: Separate" end, function()
  return DB and DB.merged and "All of one item as one icon: 80 ore shows as 80.\n\nClick: Separate (the real stacks)." or
    "The real stacks: 20, 20, 20, 20. Use this to split a stack or pick up an exact one.\n\nClick: Merged (one icon per item)."
end, function() DB.merged = not DB.merged B.Changed() end)
stackBtn:SetPoint("RIGHT", lookBtn, "LEFT", -3, 0)
local tidyBtn = iconButton(f, 22, "tidy", "Tidy",
  "Puts half-full stacks of the same item together (7 + 13 ore becomes one stack of 20), which frees bag slots. Not in a fight.",
  function() B.Tidy() end)
tidyBtn:SetPoint("RIGHT", stackBtn, "LEFT", -3, 0)
local bankBtn = iconButton(f, 22, "bank", "Your bank", function()
  return (bankOpen and "Your bank is open: in its own window it's live, drag items between it and your bags." or
    "Opens your bank in its own window, as it was when you last opened it. At a banker it opens by itself, live.") ..
    "\n\nClick again: close it."
end, function() B.ShowView(nil, "bank") end)
bankBtn:SetPoint("RIGHT", tidyBtn, "LEFT", -3, 0)
local whoBtn = iconButton(f, 22, "chars", "Your characters",
  "Click: pick one of your other characters (each one you've played with Bags on). Their bags and bank open in their own window, faded: you can look, not use.",
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
  b:SetPoint("LEFT", (i - 1) * 33 + (bag == REAGENT and 10 or 0), -2)
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
  local function put() local inv = invSlot(bag) if inv and not fight() then PutItemInBag(inv) end end
  local function take() local inv = invSlot(bag) if inv and not fight() and b.has then PickupBagFromSlot(inv) end end
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
      GameTooltip:AddLine((self.free or 0) .. " of " .. (self.size or 0) .. " slots free" .. (bag == REAGENT and " (reagents only)" or ""), 1, 1, 1)
      GameTooltip:AddLine("Drop another bag on it to swap. Click to pick it up.", 0.7, 0.7, 0.7, true)
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
-- the three tools on the right of the row: the same size as the bags, pictures centred
local lockBtn = iconButton(barIn, 30, "unlocked", function() return DB and DB.locked and "Locked" or "Unlocked" end, function()
  return DB and DB.locked and "Groups stay where they are: no moving them, no + slots, no new groups. Your items work as always.\n\nClick to unlock." or
    "Click to lock the layout, so nothing moves by accident. Your items still work as always."
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
  d.tag = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") -- "BoE", "open"
  d.tag:SetPoint("TOPLEFT", 1, -1)
  local font = d.tag:GetFont()
  if font then d.tag:SetFont(font, 9, "OUTLINE") end
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
  if e.cat == "junk" then
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
  if bag == REAGENT then return "R" end
  local family = 0
  if IS_BAG[bag] and bag ~= 0 and C_Container.GetContainerNumFreeSlots then family = select(2, C_Container.GetContainerNumFreeSlots(bag)) or 0 end
  return family ~= 0 and "S" or ""
end
-- everything in those containers; free slots by kind ("" any item, "R" reagents only, "S" a special bag)
local function readBags(ids)
  local items = {}
  local st = { free = 0, total = 0, rFree = 0, rTotal = 0, empties = { [""] = {}, R = {}, S = {} }, bagFree = {}, bagSize = {} }
  for _, bag in ipairs(ids) do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    local kind = bagKind(bag)
    st.bagSize[bag], st.bagFree[bag] = n, 0
    for slot = 1, n do
      local it = C_Container.GetContainerItemInfo(bag, slot)
      if it and it.itemID then
        items[#items + 1] = { bag = bag, slot = slot, id = it.itemID, link = it.hyperlink, count = it.stackCount or 1,
          quality = it.quality, locked = it.isLocked, icon = it.iconFileID or ns.GetIcon(it.itemID), readable = it.isReadable,
          bound = it.isBound, open = it.hasLoot and true or nil }
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
local function sortItems(a, b)
  if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
  local na, nb = ns.NameOf(a.id, a.link) or "", ns.NameOf(b.id, b.link) or ""
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
    if not catShown(e.cat) then e.cat = "other" end
    if e.cat == "junk" then
      e.first = e.id == firstOut
    elseif live then
      local gear = e.cat == "weapon" or e.cat == "armor"
      if gear and ns.Has("del") and ns.Del.IsUpgrade then
        local ok2, up = pcall(ns.Del.IsUpgrade, e.id, e.link)
        e.upgrade = ok2 and up or false
      end
      if gear and e.bound == false and select(14, ns.GetInfo(e.link or e.id)) == 2 then e.boe = true end
      if liveBags() then
        if e.id == nextFood then e.next = "your next food" elseif e.id == nextDrink then e.next = "your next water" end
        if B.newIDs[e.id] and catShown("new") then e.isNew = true e.cat = "new" end
      end
    end
  end
  table.sort(items, sortItems)
  local seen = {}
  local merge = DB.merged or not live
  for _, e in ipairs(items) do
    byCat[e.cat] = byCat[e.cat] or {}
    local list = byCat[e.cat]
    local key = e.cat .. ":" .. e.id
    if merge and seen[key] then
      seen[key].total = seen[key].total + e.count
      if e.bag then seen[key].inBags[e.bag] = true end
    else
      e.total = e.count
      e.inBags = e.bag and { [e.bag] = true } or {}
      list[#list + 1] = e
      if merge then seen[key] = e end
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
  st.junkValue = value
  -- your own groups show even when empty (so you can find them)
  for _, c in ipairs(ALL) do if c.custom then byCat[c.key] = byCat[c.key] or {} end end
  -- holding an item: every group you can put it in ends in a slot to drop it on (Junk shows up for it too)
  -- (the bag window only)
  if held and not DB.locked and v == MAINVIEW then
    if hasClean() then byCat.junk = byCat.junk or {} end
    -- (One grid has no groups to drop on: there you drop it on a chip)
    for key, list in pairs(byCat) do
      if DB.style ~= "grid" and placeable(key) and (key ~= "junk" or hasClean()) then list[#list + 1] = { drop = key, cat = key } end
    end
  end
  -- empty slots (live only): every one (you can drop an item on any), or one cell with the number
  if live then
    for kind, cat in pairs({ [""] = "empty", R = "emptyR", S = "emptyS" }) do
      local list = st.empties[kind]
      if #list > 0 then
        byCat[cat] = {}
        if DB.emptyAll ~= false then
          for _, sl in ipairs(list) do
            table.insert(byCat[cat], { bag = sl.bag, slot = sl.slot, cat = cat, empty = true, inBags = { [sl.bag] = true } })
          end
        else
          local inBags = {}
          for _, sl in ipairs(list) do inBags[sl.bag] = true end
          byCat[cat][1] = { bag = list[1].bag, slot = list[1].slot, cat = cat, total = #list, empty = true, inBags = inBags }
        end
      end
    end
  end
  return byCat, st
end

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
  if DB.locked then return lockedSay() end
  DB.assign = DB.assign or {}
  B.newIDs[id] = nil
  local isJunk = hasClean() and ns.Del.JunkKind(id)
  if key == "junk" then
    if not hasClean() then return end
    if isJunk then -- (its own slot again: keep it)
      ns.Del.Keep(id)
      Print(shown(id, link) .. " is kept: Clean-up leaves it alone.")
      return B.Changed()
    end
    if ns.KeepItem(id) then
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
  if isJunk then ns.Del.Keep(id) end -- (out of Junk: kept, so a grey one doesn't slide back)
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
  if DB.locked then return lockedSay() end
  ClearCursor()
  local wasHidden = DB.hidden and DB.hidden[id]
  if wasHidden then
    DB.hidden[id] = nil
    Print(shown(id, link) .. " shows in your bag again.")
  end
  if key == "keep" then -- (One bag: a hidden or junk item dropped on the bag)
    if hasClean() and ns.Del.JunkKind(id) then
      ns.Del.Keep(id)
      Print(shown(id, link) .. " is kept: Clean-up leaves it alone.")
    end
    return B.Changed()
  end
  if wasHidden and B.Category(id, link, nil, nil, true) == key and not DB.assign[id] then return B.Changed() end
  B.PlaceIn(key, id, link)
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
menu:SetScript("OnEvent", function(self) if not self:IsMouseOver() then self:Hide() end end)
menu:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
menu:SetScript("OnHide", function(self) pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
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
    if self.onClick then menu:Hide() self.onClick() end
  end)
  r:SetScript("OnEnter", function(self)
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
      r.onClick, r.onRight, r.tip = e.onClick, e.onRight, e.tip
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
  local entries = { { text = "|cffffd100Your bank|r", sub = mine and mine.bankSeen and ago(mine.bankSeen) or "", onClick = function() B.ShowView(nil, "bank") end } }
  for _, k in ipairs(keys) do
    local r = DB.chars[k]
    entries[#entries + 1] = { text = classColor(r.class) .. (r.name or k) .. "|r" .. ((r.realm and mine and r.realm ~= mine.realm) and ("|cff8a8a8a-" .. r.realm .. "|r") or ""),
      sub = ago(r.seen), tip = "Click: " .. (r.name or k) .. "'s bags in their own window (the bank icon there switches to their bank).\nRight-click: forget this character.",
      onClick = function() B.ShowView(k, "bags") end,
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
  local c = junk and { 1, 0.35, 0.3 } or { 0.35, 1, 0.35 }
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
      GameTooltip:AddLine(hid and "|cff66dd66Show it again|r" or "|cff66dd66Keep it|r")
      GameTooltip:AddLine(hid and "It's hidden now: drop it here and the bag shows it again." or
        "It's junk now: drop it here and Clean-up leaves it alone (all its stacks).", 1, 1, 1, true)
    elseif self.key == "junk" then
      local again = held and hasClean() and ns.Del.JunkKind(held)
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
local function finishDrag()
  drag, moving = nil, nil
  anim:Hide()
  liftBox:Hide()
  gapBox:Hide()
  B.Draw()
end
anim:SetScript("OnUpdate", function(self, dt)
  if not drag then self:Hide() return end
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
  if not key then return end
  if trashBtn:IsMouseOver() and CAT[key] and CAT[key].custom then return B.AskDelete(key) end
  if not f:IsMouseOver() then return end
  local before, r = moveTarget()
  if not r then return end
  if InCombatLockdown() then Print("the new order shows after the fight.") end
  B.MoveGroup(key, before)
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
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(c and c.name or "")
      if held and placeable(self.key) and not DB.locked then
        GameTooltip:AddLine(self.key == "junk" and "Drop the item here to make it junk." or "Drop the item here and it goes in this group.", 0.6, 1, 0.6, true)
      end
      if DB.locked then
        GameTooltip:AddLine("Locked: click the padlock to change groups.", 0.7, 0.7, 0.7, true)
      elseif self.fixed then
        GameTooltip:AddLine("In One bag, Junk always stays at the bottom.", 0.7, 0.7, 0.7, true)
      else
        if B.deleting and c and c.custom then GameTooltip:AddLine("Click to delete this group.", 1, 0.4, 0.4, true) end
        GameTooltip:AddLine("Drag the name to move this group.", 0.7, 0.7, 0.7, true)
        if c and c.custom then GameTooltip:AddLine("Right-click: rename, colour, delete.", 0.7, 0.7, 0.7, true) end
      end
      GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
local function addFrame(fr, x, y)
  fr:ClearAllPoints()
  fr:SetPoint("TOPLEFT", PANE.body, "TOPLEFT", x, -y)
  if cur then cur.frames[#cur.frames + 1] = { f = fr, x = x, y = y } end
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
  -- (the game's own button code differs between clients: if a step fails, say so once and carry on)
  local ok, err = pcall(paint, b, e.empty and { bag = e.bag, slot = e.slot } or e, e.total)
  if not ok and not B.paintError then
    B.paintError = err
    Print("Bags: a button couldn't be drawn fully (" .. tostring(err) .. "). Please tell the author.")
  end
  d.mark:SetShown(e.cat == "junk")
  d.arrow:SetShown(e.upgrade and true or false)
  d.quest:SetShown(e.cat == "quest" and withDot ~= true)
  if e.first then d.edge:SetVertexColor(1, 0.25, 0.25) d.edge:Show()
  elseif e.next then d.edge:SetVertexColor(0.3, 1, 0.3) d.edge:Show()
  elseif e.isNew then d.edge:SetVertexColor(1, 0.82, 0) d.edge:Show()
  else d.edge:Hide() end
  d.tag:SetText(e.boe and "|cff7fd4ffBoE|r" or e.open and "|cffffd100open|r" or "")
  local c = withDot and CAT[e.cat]
  if c and not e.empty then d.dot:SetColorTexture(c.color[1], c.color[2], c.color[3], 1) d.dot:Show() else d.dot:Hide() end
  d.dim:SetShown(not matches(e, text))
end

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
  setIcon(lookBtn, oneBag and "onebag" or "groups")
  setIcon(stackBtn, DB.merged and "merged" or "separate")
  local v2 = B.view2
  lightUp(bankBtn, v2 and v2.kind == "bank" and not v2.who and B.VIEW.frame:IsShown() or false)
  lightUp(whoBtn, v2 and v2.who and B.VIEW.frame:IsShown() or false)
  drawBar(st)
  setIcon(lockBtn, DB.locked and "locked" or "unlocked")
  lightUp(lockBtn, DB.locked)
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
local EMPTY_ORDER = { empty = 1, emptyR = 2, emptyS = 3 }
local function drawOneBag(byCat, text, cols, W, st, canDrop)
  local items, junk, empties = {}, {}, {}
  for _, list in pairs(byCat) do
    for _, e in ipairs(list) do
      if e.empty then empties[#empties + 1] = e
      elseif e.drop then -- (One bag puts its own)
      elseif e.cat == "junk" then junk[#junk + 1] = e
      else items[#items + 1] = e end
    end
  end
  local by = DB.sortBy or "kind"
  for _, e in ipairs(items) do
    if not e.kind then local ok, k = pcall(B.Category, e.id, e.link, e.bag, e.slot, true) e.kind = ok and k or "other" end
    e.sortName = e.sortName or ns.NameOf(e.id, e.link) or ""
  end
  table.sort(items, function(a, b)
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
  local drop = canDrop and held and not DB.locked and (hasClean() or (DB.hidden and DB.hidden[held]))
  local heldJunk = drop and ns.Del.JunkKind(held)
  if canDrop and held and not DB.locked and DB.hidden and DB.hidden[held] then heldJunk = true end
  if heldJunk then items[#items + 1] = { drop = "keep", cat = "keep" } end
  table.sort(empties, function(a, b)
    if a.cat ~= b.cat then return (EMPTY_ORDER[a.cat] or 9) < (EMPTY_ORDER[b.cat] or 9) end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
  end)
  for _, e in ipairs(empties) do items[#items + 1] = e end
  for i, e in ipairs(items) do show(e, ((i - 1) % cols) * PITCH, math.floor((i - 1) / cols) * PITCH, text) end
  local height = math.max(1, math.ceil(#items / cols)) * PITCH - GAP
  if not PANE.static then rects[#rects + 1] = { key = "keep", parent = PANE.body, x = 0, y = 0, w = W, h = height, gap = 0 } end
  -- Junk, at the bottom (junk sorted cheapest first already)
  local junkDrop = drop and not heldJunk and hasClean()
  if #junk > 0 or junkDrop then
    if junkDrop then junk[#junk + 1] = { drop = "junk", cat = "junk" } end
    local y = height + GROUP_GAP + 2
    local l = label(1)
    l.key, l.fixed = "junk", true
    l:SetWidth(W)
    l.text:SetWidth(W)
    l.text:SetText("|cffff8a8aJunk|r" .. ((st.junkValue or 0) > 0 and ("   |cff8a8a8a" .. ns.Pocket.Coins(st.junkValue) .. "|r") or ""))
    addFrame(l, 1, y)
    l:Show()
    for i, e in ipairs(junk) do show(e, ((i - 1) % cols) * PITCH, y + LABEL + math.floor((i - 1) / cols) * PITCH, text) end
    local jh = LABEL + math.ceil(#junk / cols) * PITCH - GAP
    if not PANE.static then rects[#rects + 1] = { key = "junk", parent = PANE.body, x = 0, y = y, w = W, h = jh, gap = 0 } end
    height = y + jh
  end
  return height, #items + #junk
end
-- the groups (Rows or Packed), each remembered with its frames so it can be moved
local function drawGroups(byCat, order, text, cols, W)
  local list, li, total = {}, 0, 0
  for _, c in ipairs(order) do
    local items = byCat[c.key]
    if items and (#items > 0 or (c.custom and not PANE.static)) then
      li = li + 1
      local l = label(li)
      local n = #items
      total = total + n
      local name = c.name
      local col = c.custom and ("|cff%02x%02x%02x"):format(math.floor(c.color[1] * 255), math.floor(c.color[2] * 255), math.floor(c.color[3] * 255))
        or c.key == "junk" and "|cffff8a8a" or "|cffa8946a"
      if B.deleting and c.custom and not DB.locked then name = "|cffff5050x|r " .. name .. "  |cffff6b6bclick to delete|r" end
      local nameW = measure(l, col .. name .. "|r")
      local rows = math.ceil(n / cols)
      local gw = n > 0 and (math.min(n, cols) * PITCH - GAP) or 0
      local w = math.min(W, math.max(gw, nameW + 2, n == 0 and 190 or 0))
      local h = LABEL + (n > 0 and (rows * PITCH - GAP) or 14)
      list[#list + 1] = { key = c.key, c = c, items = items, n = n, w = w, h = h, rows = rows, l = l }
    end
  end
  local pos, height = layoutOf(list, W)
  for i, g in ipairs(list) do
    g.x, g.y, g.dx, g.dy, g.tx, g.ty, g.frames = pos[i].x, pos[i].y, 0, 0, 0, 0, {}
    cur = g
    local l = g.l
    l.key, l.fixed = g.key, nil
    l:SetWidth(g.w)
    l.text:SetWidth(g.w)
    addFrame(l, g.x + 1, g.y)
    l:Show()
    for j, e in ipairs(g.items) do
      show(e, g.x + ((j - 1) % cols) * PITCH, g.y + LABEL + math.floor((j - 1) / cols) * PITCH, text)
    end
    if g.n == 0 then
      local h = hint(i)
      h:SetText(DB.locked and "empty" or "pick an item up and drop it here")
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
      foot.junk:SetText((atVendor and "|cff66dd66sells here|r " or "|cff8a8a8ajunk|r ") .. ns.Pocket.Coins(st.junkValue))
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
  for _, h in ipairs(P.hints) do h:Hide() end
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
  chevCheck()
  GameTooltip:Hide()
end
---------------------------------------------------------------------------
-- Hidden: a small bag at the top right of the bag. Pull an item into it and the bag stops showing
-- it (all its stacks); it's still in your bags, still usable from here. Drag it back onto the bag
-- (a group's +, or the green + in One bag) to see it there again. Suggestions: profession tools and
-- the Hearthstone.
---------------------------------------------------------------------------
local HCOLS = 5
local hf = CreateFrame("Frame", "RucksackBagsHidden", f, ns.BACKDROP_TMPL)
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
local heye = hf:CreateTexture(nil, "ARTWORK")
heye:SetSize(16, 16)
heye:SetPoint("TOPLEFT", 9, -9)
heye:SetTexture(ICONS .. "hidden")
heye:SetVertexColor(TAN[1], TAN[2], TAN[3])
local htitle = hf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
htitle:SetPoint("LEFT", heye, "RIGHT", 5, 0)
htitle:SetText("Hidden")
local hclose = CreateFrame("Button", nil, hf, "UIPanelCloseButton")
hclose:SetSize(22, 22)
hclose:SetPoint("TOPRIGHT", -2, -3)
local hhelp = CreateFrame("Button", nil, hf)
hhelp:SetSize(16, 16)
hhelp:SetPoint("RIGHT", hclose, "LEFT", -2, 0)
hhelp.text = hhelp:CreateFontString(nil, "ARTWORK", "GameFontNormal")
hhelp.text:SetPoint("CENTER")
hhelp.text:SetText("|cffffd100?|r")
hhelp:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Hidden items")
  GameTooltip:AddLine("Things you carry but never need to look at, like a Skinning Knife, a Mining Pick or your Hearthstone. They stay in your bags and still take a slot; the bag just doesn't show them.", 1, 1, 1, true)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Pull an item in here to hide it (all its stacks). Use them from here as always. To see one in the bag again, drag it back onto the bag: a group's +, or the green + in One bag.", 0.7, 0.7, 0.7, true)
  GameTooltip:AddLine("A search in the bag still finds them. Clean-up never sells or throws them away.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end)
hhelp:SetScript("OnLeave", function() GameTooltip:Hide() end)
local hbody = CreateFrame("Frame", nil, hf)
hbody:SetPoint("TOPLEFT", 8, -30)
hbody:SetSize(HCOLS * PITCH - GAP, PITCH)
local HIDE = { body = hbody, labels = {}, hints = {}, ghosts = {}, ghostN = 0, frame = hf, static = true }
-- the place to pull items into
local hdrop = CreateFrame("Button", "RucksackBagsHiddenDrop", hf)
hdrop:SetHeight(34)
hdrop.dashes = {}
for i = 0, 15 do
  for _, side in ipairs({ "TOP", "BOTTOM" }) do
    local t = hdrop:CreateTexture(nil, "BORDER")
    t:SetColorTexture(TAN[1], TAN[2], TAN[3], 0.5)
    t:SetSize(6, 1)
    t:SetPoint(side .. "LEFT", i * 12, 0)
    hdrop.dashes[#hdrop.dashes + 1] = t
  end
end
hdrop.text = hdrop:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hdrop.text:SetPoint("LEFT", 4, 0)
hdrop.text:SetPoint("RIGHT", -4, 0)
hdrop.text:SetText("Pull items inside to hide them from your bag")
local hl = hdrop:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints()
hl:SetColorTexture(1, 1, 1, 0.06)
-- suggestions: profession tools you carry, and your Hearthstone (never potions, food or other things you use up)
local hsug = hf:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hsug:SetText("Suggested (click to hide):")
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
  if DB.locked then return lockedSay() end
  DB.hidden = DB.hidden or {}
  DB.hidden[id] = true
  B.newIDs[id] = nil
  Print(shown(id, link) .. " is hidden: it's in the Hidden bag now (the eye next to your bags).")
  B.Changed()
end
local function hideHeld()
  local id, link = ns.CursorItem()
  if not id then return end
  if DB.locked then return lockedSay() end
  ClearCursor()
  hideIt(id, link)
end
B.HideItem = hideIt
hf:SetScript("OnReceiveDrag", hideHeld)
hf:SetScript("OnMouseUp", function() if ns.CursorItem() then hideHeld() end end)
hdrop:SetScript("OnReceiveDrag", hideHeld)
hdrop:SetScript("OnClick", hideHeld)
local function sugButton(i)
  if sugBtns[i] then return sugBtns[i] end
  local b = CreateFrame("Button", nil, hf, ns.BACKDROP_TMPL)
  b:SetSize(26, 26)
  if b.SetBackdrop then b:SetBackdrop(ns.SLOT_BACKDROP) b:SetBackdropColor(0.06, 0.05, 0.04, 0.95) b:SetBackdropBorderColor(0.4, 0.36, 0.28) end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.icon:SetAlpha(0.75)
  b:SetScript("OnClick", function(self) hideIt(self.id) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self.why .. " Click to hide it.", 0.6, 1, 0.6, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  sugBtns[i] = b
  return b
end
-- the hidden items (your bags' own buttons, so they work as always), the drop place, suggestions
local function drawHidden(text)
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
  for i, e in ipairs(list) do show(e, ((i - 1) % HCOLS) * PITCH, math.floor((i - 1) / HCOLS) * PITCH, text) end
  PANE = MAIN
  local rows = math.ceil(#list / HCOLS)
  local h = rows > 0 and (rows * PITCH - GAP) or 0
  hbody:SetHeight(math.max(1, h))
  local y = 30 + h + (rows > 0 and 6 or 0)
  hdrop:ClearAllPoints()
  hdrop:SetPoint("TOPLEFT", 8, -y)
  hdrop:SetWidth(HCOLS * PITCH - GAP)
  hdrop.text:SetText(DB.locked and "Locked: click the padlock to hide or show items" or "Pull items inside to hide them from your bag")
  y = y + 34 + 6
  for _, b in ipairs(sugBtns) do b:Hide() end
  if #sug > 0 then
    hsug:ClearAllPoints()
    hsug:SetPoint("TOPLEFT", 10, -y)
    hsug:Show()
    y = y + 14
    for i, e in ipairs(sug) do
      if i > HCOLS + 1 then break end
      local b = sugButton(i)
      b.id, b.why = e.id, e.why
      b.icon:SetTexture(e.icon)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 8 + (i - 1) * 30, -y)
      b:Show()
    end
    y = y + 30
  else
    hsug:Hide()
  end
  hf:SetHeight(y + 8)
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
  local cols = math.max(8, math.min(16, DB.cols or 10))
  local W = cols * PITCH - GAP
  B.curW = W
  searchHint:SetShown(text == "" and not search:HasFocus())
  wipe(used)
  wipe(dropUsed)
  wipe(rects)
  wipe(drawn)
  whereText = "Your bags"
  local height, _, st = drawItems(MAIN, MAINVIEW, text, cols, W)
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
  if not DB.barOpen then chevCheck() end
  f:SetScale(DB.scale or 1)
end

---------------------------------------------------------------------------
-- The second window: your bank, or another character (bags or bank). Look only, except your own
-- bank at a banker: then it's live, and items go between it and your bags as always.
---------------------------------------------------------------------------
local vf = CreateFrame("Frame", "RucksackBagsView", UIParent, ns.BACKDROP_TMPL)
vf:SetSize(340, 200)
vf:SetFrameStrata("MEDIUM")
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
local vkind = iconButton(vf, 22, "bank", function() return B.view2 and B.view2.kind == "bank" and "Showing the bank" or "Showing the bags" end,
  function() return "Click: " .. (B.view2 and B.view2.kind == "bank" and "the bags." or "the bank.") end,
  function() if B.view2 then B.view2.kind = B.view2.kind == "bank" and "bags" or "bank" B.DrawView() end end)
vkind:SetPoint("RIGHT", vclose, "LEFT", -1, 0)
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
  setIcon(vkind, v.kind == "bank" and "bank" or "onebag")
  local saveUsed = {}
  for b in pairs(used) do saveUsed[b] = true end
  wipe(used)
  whereText = name .. " " .. v.kind
  local height, total, st = drawItems(B.VIEW, v, text, cols, W)
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
  local y = HEAD + height + 6
  vfoot:ClearAllPoints()
  vfoot:SetPoint("TOPLEFT", 8, -y)
  drawFoot(vfoot, st, rec, v, W)
  vf:SetSize(W + 16, y + 24)
  vf:SetScale(DB.scale or 1)
end
-- open the second window on a view: who (nil = you), kind ("bags" or "bank")
function B.ShowView(who, kind, auto)
  if not DB then return end
  local v = B.view2
  if v and vf:IsShown() and v.who == who and v.kind == kind and not auto then B.CloseView() return end
  B.view2 = { who = who, kind = kind }
  B.viewAuto = auto
  if not vf:IsShown() then
    vf:ClearAllPoints()
    if DB.viewPos then vf:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DB.viewPos[1], DB.viewPos[2])
    elseif f:IsShown() then vf:SetPoint("TOPRIGHT", f, "TOPLEFT", -6, 0)
    else vf:SetPoint("CENTER", UIParent, "CENTER", -200, 60) end
    vf:Show()
  end
  B.DrawView()
  if f:IsShown() then lightUp(bankBtn, kind == "bank" and not who) lightUp(whoBtn, who and true or false) end
end
function B.CloseView() vf:Hide() end
vf:SetScript("OnHide", function()
  B.viewAuto = nil
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
  Print(DB.locked and "bag locked: groups stay where they are. Your items work as always." or "bag unlocked: drag groups and items again.")
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
    hoverKey = nil
    hoverBox:Hide()
    if newBtn.SetBackdropBorderColor and not newBtn.lit then
      if held and not DB.locked and DB.style ~= "grid" then newBtn:SetBackdropBorderColor(0.35, 1, 0.35) else newBtn:SetBackdropBorderColor(0.4, 0.36, 0.28) end
    end
    B.Draw()
  end
  local key, r
  if held and not moving and not DB.locked and f:IsMouseOver() then
    r = rectUnder()
    if r and placeable(r.key) and (r.key ~= "junk" or hasClean()) then key = r.key end
    if r and r.key == "keep" and ((hasClean() and ns.Del.JunkKind(held)) or (DB.hidden and DB.hidden[held])) then key = "keep" end
  end
  if key ~= hoverKey then
    hoverKey = key
    if key then
      local junk = key == "junk"
      hoverBox:ClearAllPoints()
      hoverBox:SetPoint("TOPLEFT", r.parent, "TOPLEFT", r.x - 3, -(r.y - 2))
      hoverBox:SetSize(r.w + 6, r.h + 4)
      hoverBox:SetColorTexture(junk and 1 or 0.3, junk and 0.3 or 1, 0.3, 0.12)
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
function B.Open()
  if not DB then return end
  f:Show()
  B.Draw()
  if not B.pinned then B.pinned = true pinTopLeft() end
end
function B.Close() f:Hide() end
f:SetScript("OnHide", function()
  wipe(B.newIDs)
  B.hoverBag = nil
  B.deleting = false
  menu:Hide()
  if drag then drag, moving = nil, nil anim:Hide() liftBox:Hide() gapBox:Hide() end
end)

-- Tidy: put half-full stacks of the same item together, a few moves at a time
local tidying
local function tidyStep()
  if InCombatLockdown() or CursorHasItem() then tidying = nil return end
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
  tidying = 0
  tidyStep()
end
function B.Toggle() if f:IsShown() then B.Close() else B.Open() end end
function B.IsShown() return f:IsShown() end
local orig, hooked = {}, false
local function takeOver()
  if hooked then return end
  hooked = true
  for _, n in ipairs({ "ToggleAllBags", "OpenAllBags", "CloseAllBags", "ToggleBackpack", "OpenBackpack", "CloseBackpack", "ToggleBag" }) do orig[n] = _G[n] end
  local function wrap(name, mine, alsoGame)
    _G[name] = function(...)
      if not DB or not DB.replace then if orig[name] then return orig[name](...) end return end
      mine()
      if alsoGame and orig[name] then return orig[name](...) end
    end
  end
  wrap("ToggleAllBags", B.Toggle)
  wrap("OpenAllBags", B.Open)
  wrap("CloseAllBags", B.Close, true) -- (the game still closes its own: bank bags)
  wrap("ToggleBackpack", B.Toggle)
  wrap("OpenBackpack", B.Open)
  wrap("CloseBackpack", B.Close)
  local toggleBag = orig.ToggleBag
  ToggleBag = function(id, ...)
    if DB and DB.replace and IS_BAG[id] then return B.Toggle() end
    if toggleBag then return toggleBag(id, ...) end
  end
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
    pcall(B.SaveBank)
    if DB and DB.replace then B.ShowView(nil, "bank", true) end
  end
  if e == "BANKFRAME_CLOSED" then
    bankOpen = false
    if B.viewAuto then B.CloseView() end
  end
  if e == "PLAYER_LOGOUT" then pcall(B.SaveBags) return end
  if e == "PLAYERBANKSLOTS_CHANGED" then pcall(B.SaveBank) end
  if e == "PLAYER_REGEN_ENABLED" then if pendingDraw then B.Changed() end return end
  if OPENERS[e] then
    if DB and DB.replace and not f:IsShown() then autoOpened = true B.Open() else B.Changed() end
  elseif CLOSERS[e] then
    if autoOpened then autoOpened = false B.Close() else B.Changed() end
  else
    if e == "BAG_UPDATE_DELAYED" then
      pcall(trackNew)
      pcall(B.SaveBags)
      if bankOpen then pcall(B.SaveBank) end
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
  if DB.style == nil then DB.style = "groups" end
  if DB.layout == nil then DB.layout = "rows" end
  if DB.merged == nil then DB.merged = true end
  if DB.cols == nil then DB.cols = 10 end
  if DB.scale == nil then DB.scale = 1 end
  DB.replace = true -- (1.8: with the module on, it's always your bag; to use another bag addon, turn Bags off)
  if DB.barOpen == nil then DB.barOpen = false end -- (the bags row: opened with the arrow on Rucksack)
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
    "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE", "BAG_CONTAINER_UPDATE", "PLAYERBANKSLOTS_CHANGED", "PLAYER_LOGOUT",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "TRADE_SHOW", "TRADE_CLOSED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  pcall(trackNew)
  pcall(B.SaveBags)
  takeOver()
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
