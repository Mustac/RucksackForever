-- Rucksack / the Pocket: a small window that can stay on screen. One entry each for your bag space,
-- what a vendor would pay right now, your next food and water, what's waiting to be deleted, the
-- Darkmoon prize you track and your mage scrolls.
-- (1.7.4) Four styles to pick in Settings: Rows, Tiles, Strip, Ledger. No buttons on it: drag it to
-- move it, click an entry to open its page (shift-click "next to delete": delete it now), right-click
-- anywhere for Settings. Show or hide: the box on Home or Settings, or right-click the minimap button.
local _, ns = ...
local Pocket = {}
ns.Pocket = Pocket

local LINES = {
  { key = "bags", name = "Bags" },
  { key = "sell", name = "Vendor" },
  { key = "food", name = "Food" },
  { key = "water", name = "Water" },
  { key = "del", name = "Next to delete" },
  { key = "faire", name = "Prize / tickets" },
  { key = "scrolls", name = "Scrolls" },
}
Pocket.LINES = LINES
Pocket.STYLES = { { "rows", "Rows" }, { "tiles", "Tiles" }, { "strip", "Strip" }, { "ledger", "Ledger" } }

local Q = "Interface\\Icons\\INV_Misc_QuestionMark"
local DIM = "|cff8a8a8a"
local GOLD = { 1, 0.82, 0 }
local f = CreateFrame("Frame", "RucksackPocket", UIParent, ns.BACKDROP_TMPL)
f:SetSize(236, 30)
f:SetPoint("CENTER", UIParent, "CENTER", 300, 120)
f:SetFrameStrata("MEDIUM")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
if f.SetBackdrop then
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.03, 0.03, 0.04, 0.93)
  f:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
end
f:Hide()

-- a soft top-to-bottom shade, when the client has gradients
local function shade(tex, r1, g1, b1, a1, r2, g2, b2, a2)
  tex:SetColorTexture(1, 1, 1, 1)
  local ok = CreateColor and pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(r2, g2, b2, a2), CreateColor(r1, g1, b1, a1))
  if not ok then tex:SetColorTexture(r1, g1, b1, (a1 + a2) / 2) end
end

local function P() return ns.db and ns.db.pocket end
local function style() local o = P() return o and o.style or "rows" end

local function startMove() local o = P() if o and not o.locked then f:StartMoving() end end
local function stopMove()
  f:StopMovingOrSizing()
  local o = P()
  if not o then return end
  local point, _, rel, x, y = f:GetPoint()
  o.point, o.rel, o.x, o.y = point, rel, x, y
end
f:SetScript("OnDragStart", startMove)
f:SetScript("OnDragStop", stopMove)
-- right-click anywhere: Settings (the Pocket's options are there)
local function openSettings() Rucksack_Open("general") end
f:SetScript("OnMouseUp", function(_, mouse) if mouse == "RightButton" then openSettings() end end)

-- the header (Rows, Tiles, Ledger): backpack and name; Tiles also has bag space on the right
local head = f:CreateTexture(nil, "BORDER")
head:SetPoint("TOPLEFT", 4, -4)
head:SetPoint("TOPRIGHT", -4, -4)
head:SetHeight(22)
shade(head, 0.45, 0.33, 0.15, 0.55, 0.45, 0.33, 0.15, 0.05)
local rule = f:CreateTexture(nil, "ARTWORK")
rule:SetHeight(1)
shade(rule, 0.9, 0.72, 0.35, 0.9, 0.9, 0.72, 0.35, 0.9)
local logo = f:CreateTexture(nil, "ARTWORK")
logo:SetSize(16, 16)
logo:SetPoint("TOPLEFT", 9, -6)
logo:SetTexture(ns.ICON)
logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetText("|cffc8a165Ruck|r|cffffd100sack|r")
local headValue = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
headValue:SetPoint("TOPRIGHT", -10, -9)
local headBarBg = f:CreateTexture(nil, "ARTWORK")
headBarBg:SetHeight(4)
headBarBg:SetColorTexture(1, 1, 1, 0.08)
local headBar = f:CreateTexture(nil, "OVERLAY")
headBar:SetPoint("TOPLEFT", headBarBg)
headBar:SetPoint("BOTTOMLEFT", headBarBg)

-- money with the game's coin icons
local function coins(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local out = {}
  local function add(n, file) out[#out + 1] = "|cffffffff" .. n .. "|r|T" .. file .. ":0:0:1:0|t" end
  if g > 0 then add(g, "Interface\\MoneyFrame\\UI-GoldIcon") end
  if s > 0 or g > 0 then add(s, "Interface\\MoneyFrame\\UI-SilverIcon") end
  if g == 0 then add(c, "Interface\\MoneyFrame\\UI-CopperIcon") end
  return table.concat(out, " ")
end
Pocket.Coins = coins
local function qualityHex(id, link)
  local q = ns.QualityOf(id, link)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c and c.hex then return c.hex end
  return "|cffffffff"
end
local function hexOf(c) return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255)) end

---------------------------------------------------------------------------
-- What each entry shows: one model per line, the same for every style
--   icon, on (lit or dim), name (left, in Rows), caption (small, grey), value (right),
--   short (Strip), label / text (Ledger), bar (0-1) and barColor, edge ("red" / "green")
---------------------------------------------------------------------------
local S -- the last summary (tooltips read it)
local M = {}
local function build()
  S = ns.Summary()
  wipe(M)
  -- bags
  do
    local used = S.total > 0 and (S.total - S.free) / S.total or 0
    local c = { 0.35, 0.8, 0.4 }
    if S.free < S.minFree then c = { 0.95, 0.3, 0.25 } elseif S.free < S.minFree + 4 then c = { 1, 0.75, 0.2 } end
    local tight = S.free <= S.minFree
    M.bags = { icon = "Interface\\Icons\\INV_Misc_Bag_08", on = true, name = "Bags",
      value = hexOf(c) .. S.free .. (tight and ("/" .. S.minFree) or "") .. " free|r",
      short = hexOf(c) .. S.free .. (tight and ("/" .. S.minFree) or "") .. "|r", word = tight and ("free · need " .. S.minFree) or "free",
      label = "Free slots", text = hexOf(c) .. S.free .. "|r" .. DIM .. " of " .. S.total .. (tight and (", you keep " .. S.minFree) or "") .. "|r",
      bar = used, barColor = c, edge = S.free < S.minFree and "red" or nil }
  end
  -- vendor
  if ns.Has("del") then
    local n = S.sellCount
    M.sell = { icon = "Interface\\Icons\\INV_Misc_Coin_02", on = n > 0, name = "Vendor",
      sub = n > 0 and (n .. (n == 1 and " item" or " items")) or nil,
      value = n > 0 and coins(S.sellValue) or (DIM .. "nothing|r"), short = n > 0 and coins(S.sellValue) or (DIM .. "0|r"),
      caption = "vendor" .. (n > 0 and (" · " .. n .. (n == 1 and " item" or " items")) or ""), word = "vendor",
      label = "Vendor pays", text = n > 0 and coins(S.sellValue) or (DIM .. "nothing|r") }
    -- next to delete
    local nx = S.nextDel
    local blocked = ns.Del and ns.Del.Blocked and ns.Del.Blocked()
    if not (ns.del and ns.del.enabled) then
      M.del = { icon = "Interface\\Icons\\INV_Misc_Bag_10_Red", on = false, name = DIM .. "Clean-up is paused|r", value = "",
        short = DIM .. "off|r", caption = "Clean-up paused", word = "paused", label = "First to go", text = DIM .. "paused|r", trash = true }
    elseif nx and S.waitStacks > 0 then
      -- (1.7.4) plain words: "4 can go", the first to go; red only when it really goes on your next key press
      local due = S.free < S.minFree
      local nm = qualityHex(nx.id, nx.link) .. ns.NameOf(nx.id, nx.link) .. "|r"
      local n = S.waitStacks
      M.del = { icon = nx.icon or ns.GetIcon(nx.id), on = true, name = DIM .. "first to go:|r " .. nm,
        value = blocked and "|cffffd100over limit|r" or ((due and "|cffff5a50" or DIM) .. n .. " can go|r"),
        short = blocked and "|cffffd100!|r" or ((due and "|cffff6b6b" or "|cffbbbbbb") .. n .. "|r"),
        word = blocked and "over limit" or due and "|cffff9b9bgoes next|r" or "can go",
        caption = (due and "goes next · " or "first to go · ") .. ns.NameOf(nx.id, nx.link), label = due and "Goes next" or "First to go",
        text = nm .. ((nx.deleteCount or nx.count or 1) > 1 and (" x" .. (nx.deleteCount or nx.count)) or "") .. DIM .. "  (" .. n .. " can go)|r",
        edge = (due or blocked) and "red" or nil, trash = true }
    else
      M.del = { icon = "Interface\\Icons\\INV_Misc_Bag_10_Red", on = false, name = DIM .. "Nothing can go|r", value = "",
        short = DIM .. "0|r", caption = "nothing can go", word = "can go", label = "First to go", text = DIM .. "nothing|r", trash = true }
    end
  end
  -- food and water
  if ns.Has("eat") and ns.eat and ns.eat.enabled ~= false then
    -- (1.7.4) with buff food on: Well Fed or not
    local buffOn = ns.eat.buffFood and true or false
    local fed = buffOn and ns.Eat.FoodBuffState and ns.Eat.FoodBuffState()
    local bstate = buffOn and (fed == true and "|cff66dd66Well Fed|r" or fed == false and "|cffff6060no buff|r" or nil) or nil
    M.food = S.food and { icon = ns.GetIcon(S.food), on = true, name = ns.NameOf(S.food), value = "|cffffd100x" .. S.foodCount .. "|r",
      short = "|cffffd100" .. S.foodCount .. "|r", caption = "food · " .. ns.NameOf(S.food), word = "food", label = "Food",
      text = ns.NameOf(S.food) .. DIM .. " x" .. S.foodCount .. "|r" }
      or { icon = Q, on = false, name = DIM .. "No food|r", value = "", short = DIM .. "0|r", caption = "food · none", label = "Food", text = DIM .. "none|r" }
    M.food.tick, M.food.buffOn = true, buffOn
    if bstate then
      M.food.value = bstate .. "  " .. (M.food.value or "")
      M.food.caption = (fed == false and "no buff · " or "Well Fed · ") .. (S.food and ns.NameOf(S.food) or "")
      M.food.word = fed == false and "|cffff9b9bno buff|r" or "|cff66dd66fed|r"
      M.food.text = (M.food.text or "") .. "  " .. bstate
      if fed == false then M.food.edge = "red" end
    end
    M.water = S.drink and { icon = ns.GetIcon(S.drink), on = true, name = ns.NameOf(S.drink), value = "|cffffd100x" .. S.drinkCount .. "|r",
      short = "|cffffd100" .. S.drinkCount .. "|r", caption = "water · " .. ns.NameOf(S.drink), word = "water", label = "Water",
      text = ns.NameOf(S.drink) .. DIM .. " x" .. S.drinkCount .. "|r" }
      or { icon = Q, on = false, name = DIM .. "No water|r", value = "", short = DIM .. "0|r", caption = "water · none", label = "Water", text = DIM .. "none|r" }
  end
  -- the Darkmoon prize you track, or your tickets
  local F = ns.Faire
  if F and F.db and F.On and F.On() then
    pcall(function()
      local have = F.Tickets()
      local count, waiting = F.ReadyNow()
      local goal = F.Goal and F.Goal()
      if goal then
        local done = have >= goal.cost
        local c = done and "|cff66dd66" or "|cffffd100"
        M.faire = { icon = F.PrizeIcon(goal), on = true, name = goal.name, value = c .. have .. "|r" .. DIM .. " / " .. goal.cost .. "|r",
          short = c .. have .. "|r" .. DIM .. "/" .. goal.cost .. "|r", caption = goal.name, word = "prize", label = "Prize",
          text = c .. have .. "|r" .. DIM .. "/" .. goal.cost .. "|r " .. goal.name,
          bar = math.min(1, have / math.max(1, goal.cost)), barColor = done and { 0.36, 0.84, 0.36 } or GOLD, edge = done and "green" or nil }
      else
        M.faire = { icon = F.TicketIcon and F.TicketIcon() or Q, on = true, name = "Tickets" .. (count > 0 and ("  |cff66dd66" .. count .. " ready|r") or ""),
          value = "|cffffd100" .. have .. "|r" .. (waiting > 0 and ("|cff66dd66 +" .. waiting .. "|r") or ""),
          short = "|cffffd100" .. have .. "|r", caption = "tickets" .. (count > 0 and (" · " .. count .. " ready") or ""), word = "tickets", label = "Tickets",
          text = "|cffffd100" .. have .. "|r" .. (waiting > 0 and ("|cff66dd66 +" .. waiting .. "|r") or ""), edge = count > 0 and "green" or nil }
      end
    end)
  end
  -- mage scrolls
  local Sc = ns.Scrolls
  if ns.Has("scrolls") and Sc and Sc.db then
    pcall(function()
      local total, readable, nextOne = Sc.Summary()
      Sc.lastTotal = total
      if total > 0 then
        M.scrolls = { icon = nextOne and ns.GetIcon(nextOne.id) or Sc.ICON, on = true,
          name = "Scrolls" .. (readable > 0 and ("  |cff66dd66" .. readable .. " to read|r") or ""), value = "|cffffd100" .. total .. "|r",
          short = "|cffffd100" .. total .. "|r", caption = "scrolls" .. (readable > 0 and (" · " .. readable .. " to read") or ""), word = "scrolls",
          label = "Scrolls", text = "|cffffd100" .. total .. "|r" .. (readable > 0 and (DIM .. ", " .. readable .. " to read|r") or ""),
          edge = readable > 0 and "green" or nil }
      end
    end)
  end
end

---------------------------------------------------------------------------
-- Clicks and tooltips (every style)
---------------------------------------------------------------------------
local CLICK = {
  bags = function() Rucksack_Open("home") end,
  sell = function() Rucksack_Open("del") end,
  food = function() Rucksack_Open("eat") end,
  water = function() Rucksack_Open("eat") end,
  faire = function() if ns.Faire and ns.Faire.Open then ns.Faire.Open() end end,
  scrolls = function() Rucksack_Open("scrolls") end,
  del = function()
    if IsShiftKeyDown() then AutoDelete_DeleteNext() else Rucksack_Open("del") end
  end,
}
local TIP = {}
TIP.bags = function()
  GameTooltip:AddLine("Bags")
  GameTooltip:AddLine(("%d of %d slots free. Clean-up deletes when fewer than %d are free."):format(S.free, S.total, S.minFree), 1, 1, 1, true)
  GameTooltip:AddLine("Click: Rucksack's Home page.", 0.7, 0.7, 0.7)
end
TIP.sell = function()
  GameTooltip:AddLine("Vendor")
  if S.sellCount == 0 then
    GameTooltip:AddLine((ns.del.sellGrey or ns.del.sellList) and "Nothing to sell right now." or "Selling is off (Clean-up page).", 1, 1, 1, true)
  else
    for i, it in ipairs(S.sellList) do
      if i > 12 then GameTooltip:AddLine(("... and %d more"):format(#S.sellList - 12), 0.7, 0.7, 0.7) break end
      GameTooltip:AddDoubleLine((it.link or ns.NameOf(it.id)) .. (it.count > 1 and (" x" .. it.count) or "") .. (it.why and ("  |cff999999" .. it.why .. "|r") or ""), coins(it.price * it.count), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Total", coins(S.sellValue), 1, 0.82, 0, 1, 1, 1)
  end
  GameTooltip:AddLine("Sold by itself when you open a vendor.", 0.7, 0.7, 0.7)
  GameTooltip:AddDoubleLine("Sold so far", coins(ns.del.soldGold or 0), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Click: the Clean-up page.", 0.7, 0.7, 0.7)
end
local function itemTip(id, what)
  if id and GameTooltip.SetItemByID then GameTooltip:SetItemByID(id) else GameTooltip:AddLine(what .. (id and "" or ": none in your bags")) end
  GameTooltip:AddLine(what .. ", what the eat button uses next. Click: the Rations page.", 0.7, 0.7, 0.7, true)
end
TIP.food = function() itemTip(S.food, "Next food") end
TIP.water = function() itemTip(S.drink, "Next water") end
TIP.del = function()
  GameTooltip:AddLine("|cffff5555Clean-up|r")
  local b = ns.Del and ns.Del.Blocked and ns.Del.Blocked()
  if ns.Del and ns.Del.TipList then ns.Del.TipList() end
  if b then GameTooltip:AddLine("Over your delete limit: Clean-up waits. Click the trash button to choose.", 1, 0.82, 0, true) end
  GameTooltip:AddLine(S.nextDel and "Click: the Clean-up page.  Shift-click: throw the first one away now." or "Click: the Clean-up page.", 0.7, 0.7, 0.7, true)
end
TIP.faire = function()
  local F = ns.Faire
  local goal = F and F.Goal and F.Goal()
  if goal then
    GameTooltip:AddLine("Darkmoon prize: " .. goal.name)
    local have = F.Tickets()
    if have >= goal.cost then GameTooltip:AddLine("You have enough tickets!", 0.4, 0.87, 0.4)
    else GameTooltip:AddLine((goal.cost - have) .. " more tickets to go.", 1, 1, 1) end
  else
    GameTooltip:AddLine("Darkmoon tickets")
    GameTooltip:AddLine("Track a prize on the Faire's Prizes tab to see it here.", 1, 1, 1, true)
  end
  GameTooltip:AddLine("Click: the Darkmoon Faire page.", 0.7, 0.7, 0.7)
end
TIP.scrolls = function()
  GameTooltip:AddLine("Scrolls")
  GameTooltip:AddLine("Undeciphered scrolls in your bags, and how many your skill can read now.", 1, 1, 1, true)
  GameTooltip:AddLine("Click: the Scrolls page.", 0.7, 0.7, 0.7)
end

---------------------------------------------------------------------------
-- The entries: one pool of buttons, placed and filled by the style
---------------------------------------------------------------------------
local items = {}
local function Item(i)
  if items[i] then return items[i] end
  local b = CreateFrame("Button", nil, f, ns.BACKDROP_TMPL)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", startMove)
  b:SetScript("OnDragStop", stopMove)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  shade(hl, 1, 0.82, 0.3, 0.16, 1, 0.82, 0.3, 0.04)
  b.edge = b:CreateTexture(nil, "BORDER")
  b.edge:SetWidth(3)
  b.edge:SetPoint("TOPLEFT")
  b.edge:SetPoint("BOTTOMLEFT")
  b.frame = b:CreateTexture(nil, "BORDER")
  b.frame:SetColorTexture(0, 0, 0, 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b.frame, 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", b.frame, -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.name = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  b.name:SetJustifyH("LEFT")
  b.name:SetWordWrap(false)
  b.sub = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  b.value = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  b.value:SetJustifyH("RIGHT")
  b.value:SetWordWrap(false)
  b.big = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  b.big:SetWordWrap(false)
  b.cap = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  b.cap:SetJustifyH("LEFT")
  b.cap:SetWordWrap(false)
  -- (1.7.4) the buff food tick (food only)
  b.tick = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
  b.tick:SetSize(14, 14)
  b.tick:SetPoint("CENTER", b.frame, "TOPLEFT", 1, -1)
  b.tick:SetFrameLevel(b:GetFrameLevel() + 5)
  b.tick:SetScript("OnClick", function(self) if ns.Eat and ns.Eat.SetBuffFood then ns.Eat.SetBuffFood(self:GetChecked()) end end)
  b.tick:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Buff food: " .. ((ns.eat and ns.eat.buffFood) and "|cff66dd66on|r" or "|cff999999off|r"))
    GameTooltip:AddLine("Ticked: while you're not Well Fed, the eat button eats your buff food first.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b.tick:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b.tick:Hide()
  b.trash = b:CreateTexture(nil, "OVERLAY")
  b.trash:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  b.trash:SetSize(12, 12)
  b.trash:SetPoint("TOPRIGHT", b.frame, "TOPRIGHT", 5, 5)
  b.trash:Hide()
  b.barBg = b:CreateTexture(nil, "ARTWORK")
  b.barBg:SetHeight(3)
  b.barBg:SetColorTexture(1, 1, 1, 0.08)
  b.bar = b:CreateTexture(nil, "OVERLAY")
  b.bar:SetPoint("TOPLEFT", b.barBg)
  b.bar:SetPoint("BOTTOMLEFT", b.barBg)
  b:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then openSettings() return end
    local fn = CLICK[self.key]
    if fn then fn() end
  end)
  b:SetScript("OnEnter", function(self)
    if not S or not TIP[self.key] then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    TIP[self.key]()
    GameTooltip:AddLine("Right-click: Settings (the Pocket's style and lines).", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  items[i] = b
  return b
end
-- hide every part, so each style shows only what it uses
local function reset(b)
  b:ClearAllPoints()
  if b.SetBackdrop then b:SetBackdrop(nil) end
  b.value:SetJustifyH("RIGHT")
  b.bg:SetColorTexture(0, 0, 0, 0)
  b.trash:Hide()
  b.tick:Hide()
  b.cap:SetJustifyH("LEFT")
  for _, k in ipairs({ "edge", "frame", "icon", "name", "sub", "value", "big", "cap", "barBg", "bar" }) do
    b[k]:Hide()
    if b[k].ClearAllPoints and k ~= "edge" and k ~= "bar" and k ~= "icon" then b[k]:ClearAllPoints() end
  end
end
local function edgeColor(b, m)
  if m.edge == "red" then b.edge:SetColorTexture(0.9, 0.3, 0.3, 1) b.edge:Show()
  elseif m.edge == "green" then b.edge:SetColorTexture(0.36, 0.84, 0.36, 1) b.edge:Show() end
end
local function setIcon(b, m, size, x, y)
  b.frame:SetSize(size, size)
  b.frame:SetPoint("LEFT", x, y or 0)
  b.frame:Show()
  b.icon:SetTexture(m.icon or Q)
  b.icon:SetDesaturated(not m.on)
  b.icon:SetAlpha(m.on and 1 or 0.5)
  b.icon:Show()
end
local function setBar(b, frac, color, left, right, bottom)
  b.barBg:SetPoint("BOTTOMLEFT", left, bottom)
  b.barBg:SetPoint("BOTTOMRIGHT", -right, bottom)
  b.barBg:Show()
  b.bar:SetWidth(math.max(1, (b:GetWidth() - left - right) * (frac or 0)))
  b.bar:SetColorTexture(color[1], color[2], color[3], 0.9)
  b.bar:Show()
end
local function header(width, centered)
  head:Show() rule:Show() title:Show()
  rule:ClearAllPoints()
  rule:SetPoint("TOPLEFT", 8, -26)
  rule:SetPoint("TOPRIGHT", -8, -26)
  title:ClearAllPoints()
  if centered then
    logo:Hide()
    title:SetPoint("TOP", 0, -9)
  else
    logo:Show()
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  end
end

---------------------------------------------------------------------------
-- The four styles. Each gets the visible keys in order and sizes the window.
---------------------------------------------------------------------------
local STYLE = {}
-- 1. Rows: [icon] name ......... value, a bar under bags and the prize
STYLE.rows = function(keys)
  local W = 236
  header(W)
  local y = -29
  for i, key in ipairs(keys) do
    local m, b = M[key], Item(i)
    b.key = key
    local h = m.bar and 30 or 24
    b:SetSize(W - 10, h)
    b:SetPoint("TOPLEFT", 5, y)
    if i % 2 == 0 then b.bg:SetColorTexture(1, 1, 1, 0.035) end
    edgeColor(b, m)
    setIcon(b, m, 20, 6, m.bar and 2 or 0)
    b.trash:SetShown(m.trash and true or false)
    b.value:SetPoint("RIGHT", -6, m.bar and 2 or 0)
    b.value:SetText(m.value or "")
    b.value:Show()
    b.name:SetPoint("LEFT", b.frame, "RIGHT", 7, 0)
    b.name:SetPoint("RIGHT", b.value, "LEFT", -6, 0)
    b.name:SetText((m.name or "") .. (m.sub and (DIM .. "  " .. m.sub .. "|r") or ""))
    b.name:Show()
    if m.bar then setBar(b, m.bar, m.barColor, 33, 6, 4) end
    y = y - h
  end
  return W, -y + 6
end
-- 2. Tiles: bag space in the header, a grid of tiles with big numbers, the prize as a strip
STYLE.tiles = function(keys)
  local W = 246
  header(W)
  local y = -30
  if M.bags and keys.bags then
    headValue:SetText(M.bags.value) headValue:Show()
    headBarBg:ClearAllPoints()
    headBarBg:SetPoint("TOPLEFT", 9, -30)
    headBarBg:SetPoint("TOPRIGHT", -9, -30)
    headBarBg:Show()
    headBar:SetWidth(math.max(1, (W - 18) * M.bags.bar))
    headBar:SetColorTexture(M.bags.barColor[1], M.bags.barColor[2], M.bags.barColor[3], 0.9)
    headBar:Show()
    y = -40
  end
  local TW, TH, GAP = (W - 18 - 6) / 2, 38, 6
  local n, i = 0, 0
  local strip
  for _, key in ipairs(keys) do
    if key == "faire" and M.faire and M.faire.bar then strip = key
    elseif key ~= "bags" then
      i = i + 1
      local m, b = M[key], Item(i)
    b.key = key
      local col, row = n % 2, math.floor(n / 2)
      b:SetSize(TW, TH)
      b:SetPoint("TOPLEFT", 9 + col * (TW + GAP), y - row * (TH + GAP))
      if b.SetBackdrop then b:SetBackdrop(ns.SLOT_BACKDROP) end
      b:SetBackdropColor(0.08, 0.07, 0.06, 0.95)
      if m.edge == "red" then b:SetBackdropBorderColor(0.8, 0.3, 0.3)
      elseif m.edge == "green" then b:SetBackdropBorderColor(0.36, 0.84, 0.36)
      else b:SetBackdropBorderColor(0.3, 0.28, 0.24) end
      b.frame:SetSize(16, 16)
      b.frame:SetPoint("TOPLEFT", 7, -6)
      b.frame:Show()
      b.icon:SetTexture(m.icon or Q) b.icon:SetDesaturated(not m.on) b.icon:SetAlpha(m.on and 1 or 0.5) b.icon:Show()
      b.trash:SetShown(m.trash and true or false)
      b.big:SetPoint("LEFT", b.frame, "RIGHT", 6, 0)
      b.big:SetPoint("RIGHT", -6, 0)
      b.big:SetJustifyH("LEFT")
      b.big:SetText(m.short or "")
      b.big:Show()
      b.cap:SetPoint("BOTTOMLEFT", 7, 5)
      b.cap:SetPoint("RIGHT", -6, 0)
      b.cap:SetText(m.caption or "")
      b.cap:Show()
      n = n + 1
    end
  end
  y = y - math.ceil(n / 2) * (TH + GAP)
  if strip then
    i = i + 1
    local m, b = M[strip], Item(i)
    b.key = strip
    b:SetSize(W - 18, 30)
    b:SetPoint("TOPLEFT", 9, y)
    if b.SetBackdrop then b:SetBackdrop(ns.SLOT_BACKDROP) end
    b:SetBackdropColor(0.09, 0.07, 0.16, 0.95)
    b:SetBackdropBorderColor(m.edge == "green" and 0.36 or 0.3, m.edge == "green" and 0.84 or 0.26, m.edge == "green" and 0.36 or 0.4)
    setIcon(b, m, 16, 7, 3)
    b.value:SetPoint("RIGHT", -7, 3) b.value:SetText(m.value or "") b.value:Show()
    b.name:SetPoint("LEFT", b.frame, "RIGHT", 6, 0)
    b.name:SetPoint("RIGHT", b.value, "LEFT", -6, 0)
    b.name:SetText("|cffffd100" .. (m.name or "") .. "|r") b.name:Show()
    setBar(b, m.bar, m.barColor, 7, 7, 5)
    y = y - 30 - GAP
  end
  return W, -y + 4, i
end
-- 3. Strip: no title, icons with a number under each. Across (rows) or down (columns), and how
-- many in each row or column (Settings)
STYLE.strip = function(keys)
  local o = P() or {}
  local words = o.stripWords ~= false
  local CW, CH = words and 56 or 50, words and 54 or 42
  local per = math.max(1, math.min(7, o.stripPer or 7))
  local down = o.stripDir == "down"
  local cols, rows = 0, 0
  for i, key in ipairs(keys) do
    local m, b = M[key], Item(i)
    b.key = key
    b:SetSize(CW, CH)
    local a, c = (i - 1) % per, math.floor((i - 1) / per)
    local col, row = a, c
    if down then col, row = c, a end
    cols, rows = math.max(cols, col + 1), math.max(rows, row + 1)
    b:SetPoint("TOPLEFT", 4 + col * CW, -4 - row * CH)
    if m.edge == "red" then b.bg:SetColorTexture(0.45, 0.08, 0.08, 0.5)
    elseif m.edge == "green" then b.bg:SetColorTexture(0.1, 0.4, 0.1, 0.45)
    elseif i % 2 == 0 then b.bg:SetColorTexture(1, 1, 1, 0.035) end
    b.frame:SetSize(20, 20)
    b.frame:SetPoint("TOP", 0, -4)
    b.frame:Show()
    b.icon:SetTexture(m.icon or Q) b.icon:SetDesaturated(not m.on) b.icon:SetAlpha(m.on and 1 or 0.5) b.icon:Show()
    b.trash:SetShown(m.trash and true or false)
    b.value:SetJustifyH("CENTER")
    b.value:SetText(m.short or "")
    b.value:Show()
    if words then
      b.value:SetPoint("TOP", b.frame, "BOTTOM", 0, -2)
      b.cap:SetPoint("BOTTOM", 0, 3)
      b.cap:SetJustifyH("CENTER")
      b.cap:SetText(m.word or "")
      b.cap:Show()
    else
      b.value:SetPoint("BOTTOM", 0, 4)
    end
    if m.bar and key ~= "bags" then setBar(b, m.bar, m.barColor, 4, 4, 1) end
  end
  return math.max(58, cols * CW + 8), math.max(1, rows) * CH + 8
end
-- 4. Ledger: text only, a label on the left and its value on the right
STYLE.ledger = function(keys)
  local W = 236
  header(W, true)
  local y = -30
  for i, key in ipairs(keys) do
    local m, b = M[key], Item(i)
    b.key = key
    b:SetSize(W - 10, 18)
    b:SetPoint("TOPLEFT", 5, y)
    edgeColor(b, m)
    b.name:SetPoint("LEFT", 8, 0)
    b.name:SetText("|cffa89f8c" .. (m.label or "") .. "|r")
    b.name:Show()
    b.value:SetPoint("RIGHT", -6, 0)
    b.value:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
    b.value:SetText(m.text or m.value or "")
    b.value:Show()
    y = y - 18
  end
  return W, -y + 8
end

---------------------------------------------------------------------------
-- Draw: which entries show (ticked in Settings, their module loaded), in the chosen style
---------------------------------------------------------------------------
local function draw()
  build()
  local o = P()
  local keys = {}
  for _, l in ipairs(LINES) do
    if M[l.key] and (not o or o.lines[l.key] ~= false) then
      keys[#keys + 1] = l.key
      keys[l.key] = true
    end
  end
  head:Hide() rule:Hide() title:Hide() logo:Hide() headValue:Hide() headBarBg:Hide() headBar:Hide()
  for _, b in ipairs(items) do reset(b) b:Hide() end
  local fn = STYLE[style()] or STYLE.rows
  local ok, w, h, used = pcall(fn, keys)
  if not ok then geterrorhandler()(w) w, h, used = 236, 30, 0 end
  for i = 1, used or #keys do
    local b = items[i]
    if b then
      b:Show()
      local m = M[b.key]
      if m and m.tick and b.frame:IsShown() then
        b.tick:ClearAllPoints()
        b.tick:SetPoint("CENTER", b.frame, "TOPLEFT", 1, -1)
        b.tick:SetChecked(m.buffOn)
        b.tick:Show()
      end
    end
  end
  f:SetSize(w, h)
end
function Pocket.Update()
  if not f:IsShown() then return end
  draw()
end

-- bag changes (and Rucksack's own changes) come in bursts: redraw at most a few times a second
local queued
local function queue()
  if not f:IsShown() or queued then return end
  queued = true
  C_Timer.After(0.2, function() queued = nil Pocket.Update() end)
end
Pocket.Queue = queue

local inFight
local function apply()
  local o = P()
  if not o then return end
  f:SetScale(o.scale or 1)
  local show = o.shown and not (inFight and o.hideInCombat)
  f:SetShown(show and true or false)
  if show then Pocket.Update() end
end
Pocket.Apply = apply

function Pocket.SetShown(on)
  local o = P()
  if not o then return end
  o.shown = on and true or false
  apply()
  ns.Changed()
end
function Pocket.Toggle() local o = P() if o then Pocket.SetShown(not o.shown) end end
function Pocket.IsShown() return f:IsShown() end
function Pocket.SetStyle(name)
  local o = P()
  if not o then return end
  o.style = name
  apply()
  ns.Changed()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_REGEN_DISABLED" then inFight = true apply()
  elseif e == "PLAYER_REGEN_ENABLED" then inFight = false apply()
  else queue() end
end)

table.insert(ns.listeners, queue)
table.insert(ns.onLoad, function()
  local db = ns.db
  db.pocket = db.pocket or {}
  local o = db.pocket
  if o.scale == nil then o.scale = 1 end
  if o.hideInCombat == nil then o.hideInCombat = false end
  if o.style == nil then o.style = "rows" end
  if o.stripDir == nil then o.stripDir = "across" end
  if o.stripPer == nil then o.stripPer = 7 end
  if o.stripWords == nil then o.stripWords = true end
  o.lines = o.lines or {}
  for _, l in ipairs(LINES) do if o.lines[l.key] == nil then o.lines[l.key] = true end end
  if o.point then
    f:ClearAllPoints()
    f:SetPoint(o.point, UIParent, o.rel or o.point, o.x or 0, o.y or 0)
  end
end)
table.insert(ns.onLogin, function()
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "PLAYER_MONEY",
    "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "QUEST_LOG_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  apply()
end)
