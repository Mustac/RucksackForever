-- Rucksack / the Pocket (10 Nov): a small window that can stay on screen. One line each for your
-- bag space, what a vendor would pay right now, your next food, your next water, and what's
-- waiting to be deleted. Click a line to open the right page (shift-click "To delete": delete the
-- next item now). Drag it to move it. Options (lock, size, hide in combat, which lines) are on the
-- Settings page. Show or hide: /ruck pocket, the Home page, or right-click the minimap button.
local _, ns = ...
local Pocket = {}
ns.Pocket = Pocket

local LINES = {
  { key = "bags", name = "Bags" },
  { key = "sell", name = "Vendor" },
  { key = "food", name = "Food" },
  { key = "water", name = "Water" },
  { key = "del", name = "Cheapest item" },
  { key = "faire", name = "Tickets" },
  { key = "scrolls", name = "Scrolls" },
}
Pocket.LINES = LINES

local W, LINE_H, HEAD_H = 236, 24, 26
local f = CreateFrame("Frame", "RucksackPocket", UIParent, ns.BACKDROP_TMPL)
f:SetSize(W, 30)
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

-- (10 Nov) a soft top-to-bottom shade, when the client has gradients
local function shade(tex, r1, g1, b1, a1, r2, g2, b2, a2)
  tex:SetColorTexture(1, 1, 1, 1)
  local ok = CreateColor and pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(r2, g2, b2, a2), CreateColor(r1, g1, b1, a1))
  if not ok then tex:SetColorTexture(r1, g1, b1, (a1 + a2) / 2) end
end

local function P() return ns.db and ns.db.pocket end

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

-- the header: backpack, name, a small x; a warm shade and a thin gold line under it
local head = f:CreateTexture(nil, "BORDER")
head:SetPoint("TOPLEFT", 4, -4)
head:SetPoint("TOPRIGHT", -4, -4)
head:SetHeight(HEAD_H - 4)
shade(head, 0.45, 0.33, 0.15, 0.55, 0.45, 0.33, 0.15, 0.05)
local rule = f:CreateTexture(nil, "ARTWORK")
rule:SetPoint("TOPLEFT", 8, -HEAD_H)
rule:SetPoint("TOPRIGHT", -8, -HEAD_H)
rule:SetHeight(1)
shade(rule, 0.9, 0.72, 0.35, 0.9, 0.9, 0.72, 0.35, 0.9)
local logo = f:CreateTexture(nil, "ARTWORK")
logo:SetSize(16, 16)
logo:SetPoint("TOPLEFT", 9, -6)
logo:SetTexture(ns.ICON)
logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
title:SetText("|cffc8a165Ruck|r|cffffd100sack|r")
local close = CreateFrame("Button", nil, f)
close:SetSize(18, 18)
close:SetPoint("TOPRIGHT", -6, -5)
close.x = close:CreateFontString(nil, "ARTWORK", "GameFontNormal")
close.x:SetPoint("CENTER", 0, 1)
close.x:SetText("x")
close.x:SetTextColor(0.6, 0.55, 0.45)
close:SetScript("OnEnter", function(self) self.x:SetTextColor(1, 0.35, 0.3) end)
close:SetScript("OnLeave", function(self) self.x:SetTextColor(0.6, 0.55, 0.45) end)
close:SetScript("OnClick", function() Pocket.SetShown(false) end)

-- (10 Nov) the Clean-up switch: turn deleting and selling on or off, right here
local sw = CreateFrame("Button", nil, f, ns.BACKDROP_TMPL)
sw:SetSize(90, 17)
sw:SetPoint("RIGHT", close, "LEFT", -3, 0)
if sw.SetBackdrop then
  sw:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
end
sw.dot = sw:CreateTexture(nil, "ARTWORK")
sw.dot:SetSize(7, 7)
sw.dot:SetPoint("LEFT", 7, 0)
sw.text = sw:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sw.text:SetPoint("LEFT", sw.dot, "RIGHT", 5, 0)
local function paintSwitch()
  sw:SetShown(ns.Has("del"))
  local on = ns.del and ns.del.enabled
  sw.dot:SetColorTexture(on and 0.3 or 0.45, on and 0.9 or 0.45, on and 0.35 or 0.45, 1)
  sw.text:SetText(on and "Clean-up |cff66dd66on|r" or "Clean-up |cff999999off|r")
  if sw.SetBackdrop then
    sw:SetBackdropColor(on and 0.08 or 0.1, on and 0.2 or 0.1, on and 0.08 or 0.1, 0.9)
    sw:SetBackdropBorderColor(on and 0.3 or 0.4, on and 0.7 or 0.4, on and 0.3 or 0.4, 1)
  end
end
sw:SetScript("OnClick", function(self)
  if not ns.del then return end
  ns.del.enabled = not ns.del.enabled
  ns.Print(ns.del.enabled and "Clean-up is |cff66dd66on|r: your list is deleted when your bags fill up, and sold at vendors."
    or "Clean-up is |cff999999off|r: nothing is deleted or sold until you turn it back on. Your list stays.")
  ns.Del.Refresh()
  ns.Changed()
  if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
end)
-- (10 Nov) what the Pocket shows: a small list to tick, right here (same as Settings > Lines)
local eye = CreateFrame("Button", nil, f)
eye:SetSize(16, 16)
eye:SetPoint("RIGHT", sw, "LEFT", -4, 0)
eye.icon = eye:CreateTexture(nil, "ARTWORK")
eye.icon:SetAllPoints()
eye.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
eye.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
eye.icon:SetVertexColor(0.85, 0.8, 0.7)
local pick = CreateFrame("Frame", nil, f, ns.BACKDROP_TMPL)
pick:SetSize(130, 10)
pick:SetPoint("TOPRIGHT", eye, "BOTTOMRIGHT", 30, -4)
pick:SetFrameStrata("DIALOG")
pick:EnableMouse(true)
if pick.SetBackdrop then
  pick:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  pick:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
  pick:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
end
pick:Hide()
local pickHead = pick:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
pickHead:SetPoint("TOPLEFT", 8, -7)
pickHead:SetText("Show on the Pocket")
local pickBoxes = {}
for i, l in ipairs(LINES) do
  local cb = CreateFrame("CheckButton", nil, pick, "UICheckButtonTemplate")
  cb:SetSize(20, 20)
  cb:SetPoint("TOPLEFT", 4, -20 - (i - 1) * 19)
  local t = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  t:SetPoint("LEFT", cb, "RIGHT", 1, 1)
  t:SetText(l.name)
  cb:SetHitRectInsets(0, -90, 0, 0)
  cb:SetScript("OnClick", function(self)
    local o = P()
    if not o then return end
    o.lines[l.key] = self:GetChecked() and true or false
    Pocket.Update()
    ns.Changed()
  end)
  pickBoxes[i] = { cb = cb, key = l.key }
end
pick:SetHeight(26 + #LINES * 19)
pick:SetScript("OnShow", function()
  local o = P()
  for _, b in ipairs(pickBoxes) do b.cb:SetChecked(not o or o.lines[b.key] ~= false) end
end)
eye:SetScript("OnClick", function() pick:SetShown(not pick:IsShown()) end)
eye:SetScript("OnEnter", function(self)
  self.icon:SetVertexColor(1, 1, 1)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("What the Pocket shows")
  GameTooltip:AddLine("Tick the lines you want: Bags, Vendor, Food, Water, Cheapest item.", 1, 1, 1, true)
  GameTooltip:Show()
end)
eye:SetScript("OnLeave", function(self) self.icon:SetVertexColor(0.85, 0.8, 0.7) GameTooltip:Hide() end)
f:HookScript("OnHide", function() pick:Hide() end)
Pocket.Picker = pick

sw:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  if not ns.del then return end
  GameTooltip:AddLine("Clean-up: " .. (ns.del.enabled and "|cff66dd66on|r" or "|cff999999off|r"))
  GameTooltip:AddLine("Click to turn it " .. (ns.del.enabled and "off" or "on") .. ".", 1, 1, 1)
  GameTooltip:AddLine("On: items on your list are deleted when your bags are nearly full, and sold when you visit a vendor.", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine("Off: nothing is deleted or sold, and the game's normal delete box is back. Your list stays as it is, ready for when you turn it on again.", 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end)
sw:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- one line: [framed icon] name ............ number
local rows = {}
local function Row(key)
  local r = CreateFrame("Button", nil, f)
  r:SetHeight(LINE_H)
  r:SetPoint("LEFT", 5, 0)
  r:SetPoint("RIGHT", -5, 0)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:RegisterForDrag("LeftButton")
  r:SetScript("OnDragStart", startMove)
  r:SetScript("OnDragStop", stopMove)
  r.stripe = r:CreateTexture(nil, "BACKGROUND")
  r.stripe:SetAllPoints()
  r.stripe:SetColorTexture(1, 1, 1, 0.035)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  shade(hl, 1, 0.82, 0.3, 0.16, 1, 0.82, 0.3, 0.04)
  r.edge = r:CreateTexture(nil, "BORDER")
  r.edge:SetSize(20, 20)
  r.edge:SetPoint("LEFT", 4, 0)
  r.edge:SetColorTexture(0, 0, 0, 1)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetPoint("TOPLEFT", r.edge, 1, -1)
  r.icon:SetPoint("BOTTOMRIGHT", r.edge, -1, 1)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.value = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.value:SetPoint("RIGHT", -6, 0)
  r.value:SetJustifyH("RIGHT")
  r.value:SetWordWrap(false)
  r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.text:SetPoint("LEFT", r.edge, "RIGHT", 7, 0)
  r.text:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
  r.text:SetJustifyH("LEFT")
  r.text:SetWordWrap(false)
  r.key = key
  rows[key] = r
  return r
end
for _, l in ipairs(LINES) do Row(l.key) end

-- the bag line's thin fill bar, under its text
do
  local r = rows.bags
  r.barBg = r:CreateTexture(nil, "ARTWORK")
  r.barBg:SetPoint("BOTTOMLEFT", r.edge, "BOTTOMRIGHT", 7, 0)
  r.barBg:SetPoint("RIGHT", -6, 0)
  r.barBg:SetHeight(3)
  r.barBg:SetColorTexture(1, 1, 1, 0.08)
  r.bar = r:CreateTexture(nil, "OVERLAY")
  r.bar:SetPoint("TOPLEFT", r.barBg)
  r.bar:SetPoint("BOTTOMLEFT", r.barBg)
  r.bar:SetColorTexture(1, 1, 1, 1)
  r.text:ClearAllPoints()
  r.text:SetPoint("LEFT", r.edge, "RIGHT", 7, 3)
  r.text:SetPoint("RIGHT", r.value, "LEFT", -8, 3)
  r.value:ClearAllPoints()
  r.value:SetPoint("RIGHT", -6, 3)
end

-- money with the game's coin icons
local function coins(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local out = {}
  local function add(n, file, col) out[#out + 1] = col .. n .. "|r|T" .. file .. ":0:0:1:0|t" end
  if g > 0 then add(g, "Interface\\MoneyFrame\\UI-GoldIcon", "|cffffffff") end
  if s > 0 or g > 0 then add(s, "Interface\\MoneyFrame\\UI-SilverIcon", "|cffffffff") end
  if g == 0 then add(c, "Interface\\MoneyFrame\\UI-CopperIcon", "|cffffffff") end
  return table.concat(out, " ")
end
Pocket.Coins = coins

local function qualityHex(id, link)
  local q = ns.QualityOf(id, link)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c and c.hex then return c.hex end
  return "|cffffffff"
end

local S -- the last summary (tooltips read it)

-- where each line goes
rows.bags:SetScript("OnClick", function() Rucksack_Open("home") end)
rows.sell:SetScript("OnClick", function() Rucksack_Open("del") end)
rows.food:SetScript("OnClick", function() Rucksack_Open("eat") end)
rows.faire:SetScript("OnClick", function() if ns.Faire and ns.Faire.Open then ns.Faire.Open() end end)
rows.scrolls:SetScript("OnClick", function() Rucksack_Open("scrolls") end)
rows.water:SetScript("OnClick", function() Rucksack_Open("eat") end)
rows.del:SetScript("OnClick", function()
  if IsShiftKeyDown() then AutoDelete_DeleteNext() else Rucksack_Open("del") end
end)

-- (10 Nov) right-click anywhere on the Pocket: Rucksack's Settings (the Pocket's options are there)
local function openSettings() Rucksack_Open("general") end
for _, r in pairs(rows) do
  local click = r:GetScript("OnClick")
  r:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then openSettings() elseif click then click(self, mouse) end
  end)
end
f:SetScript("OnMouseUp", function(_, mouse) if mouse == "RightButton" then openSettings() end end)
local RIGHT_HINT = "Right-click: Settings."

local function tipLines(self, fn)
  self:SetScript("OnEnter", function()
    if not S then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    fn(S)
    GameTooltip:AddLine(RIGHT_HINT, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  self:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
tipLines(rows.bags, function(S)
  GameTooltip:AddLine("Bags")
  GameTooltip:AddLine(("%d of %d free. Clean-up deletes when fewer than %d are free."):format(S.free, S.total, S.minFree), 1, 1, 1, true)
  GameTooltip:AddLine("Click: Rucksack's Home page.", 0.7, 0.7, 0.7)
end)
tipLines(rows.sell, function(S)
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
  GameTooltip:AddDoubleLine("Sold so far", coins(ns.del.soldGold or 0), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Click: the Clean-up page.", 0.7, 0.7, 0.7)
end)
-- (item tooltips need SetItemByID, not AddLine)
local function itemTip(self, getID, what)
  self:SetScript("OnEnter", function()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local id = getID()
    if id and GameTooltip.SetItemByID then GameTooltip:SetItemByID(id) else GameTooltip:AddLine(what .. (id and "" or ": none in your bags")) end
    GameTooltip:AddLine("Click: the Rations page.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine(RIGHT_HINT, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  self:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
itemTip(rows.food, function() return S and S.food end, "Next food")
itemTip(rows.water, function() return S and S.drink end, "Next water")
tipLines(rows.del, function(S)
  GameTooltip:AddLine("Cheapest item")
  if S.nextDel then
    GameTooltip:AddLine(("%d %s waiting. Next: %s"):format(S.waitStacks, S.waitStacks == 1 and "stack" or "stacks",
      (S.nextDel.link or ns.NameOf(S.nextDel.id)) .. ((S.nextDel.deleteCount or S.nextDel.count or 1) > 1 and (" x" .. (S.nextDel.deleteCount or S.nextDel.count)) or "")), 1, 1, 1, true)
    GameTooltip:AddLine("Click: the Clean-up page.  Shift-click: delete it now.", 0.7, 0.7, 0.7, true)
  else
    GameTooltip:AddLine(ns.del.enabled and "Nothing on your list is in your bags." or "Clean-up is off.", 1, 1, 1, true)
    GameTooltip:AddLine("Click: the Clean-up page.", 0.7, 0.7, 0.7)
  end
end)

local Q = "Interface\\Icons\\INV_Misc_QuestionMark"
local DIM = "|cff8a8a8a"
local function icon(r, tex, on)
  r.icon:SetTexture(tex)
  r.icon:SetDesaturated(not on)
  r.icon:SetAlpha(on and 1 or 0.5)
end
-- (10 Nov) Darkmoon tickets: the prize you track (37/50), or your tickets and what's ready
local function fillFaire()
  local F, r = ns.Faire, rows.faire
  if not (F and F.db and F.On()) then return end
  local have = F.Tickets()
  local count, waiting = F.ReadyNow()
  local goal = F.Goal and F.Goal()
  if goal then
    icon(r, F.PrizeIcon(goal), true)
    r.text:SetText(goal.name)
    r.value:SetText((have >= goal.cost and "|cff66dd66" or "|cffffd100") .. have .. "|r" .. DIM .. "/" .. goal.cost .. "|r")
  else
    icon(r, F.TicketIcon and F.TicketIcon() or Q, true)
    r.text:SetText("Tickets" .. (count > 0 and ("  |cff66dd66" .. count .. " ready|r") or ""))
    r.value:SetText("|cffffd100" .. have .. "|r" .. (waiting > 0 and ("|cff66dd66 +" .. waiting .. "|r") or ""))
  end
end

-- (1.7) mage scrolls: how many, and how many you can read now
local function fillScrolls()
  local Sc, r = ns.Scrolls, rows.scrolls
  if not (Sc and Sc.db) then return end
  local total, readable, nextOne = Sc.Summary()
  Sc.lastTotal = total
  icon(r, nextOne and ns.GetIcon(nextOne.id) or Sc.ICON, total > 0)
  r.text:SetText("Scrolls" .. (readable > 0 and ("  |cff66dd66" .. readable .. " to read|r") or ""))
  r.value:SetText("|cffffd100" .. total .. "|r")
end

local function fill()
  S = ns.Summary()
  pcall(fillFaire)
  pcall(fillScrolls)
  -- bags: free of total, and a bar that fills as they do
  local r = rows.bags
  icon(r, "Interface\\Icons\\INV_Misc_Bag_08", true)
  local used = S.total > 0 and (S.total - S.free) / S.total or 0
  local cr, cg, cb = 0.35, 0.8, 0.4
  if S.free < S.minFree then cr, cg, cb = 0.95, 0.3, 0.25 elseif S.free < S.minFree + 4 then cr, cg, cb = 1, 0.75, 0.2 end
  r.text:SetText("Bags")
  local hex = ("%02x%02x%02x"):format(math.floor(cr * 255), math.floor(cg * 255), math.floor(cb * 255))
  r.value:SetText(("|cff%s%d|r %s/ %d free|r"):format(hex, S.free, DIM, S.total))
  r.bar:SetWidth(math.max(1, (W - 47) * used)) -- (the bar's full width: the line minus its icon and edges)
  r.bar:SetColorTexture(cr, cg, cb, 0.9)
  -- what a vendor would pay
  paintSwitch()
  local cleanOn = ns.del and ns.del.enabled and true or false
  r = rows.sell
  icon(r, "Interface\\Icons\\INV_Misc_Coin_02", S.sellCount > 0)
  r.text:SetText("Vendor" .. (S.sellCount > 0 and (DIM .. "  " .. S.sellCount .. (S.sellCount == 1 and " item" or " items") .. "|r") or ""))
  r.value:SetText(S.sellCount > 0 and coins(S.sellValue) or (DIM .. ((cleanOn and (ns.del.sellGrey or ns.del.sellList)) and "nothing" or "off") .. "|r"))
  -- food and water
  r = rows.food
  icon(r, S.food and ns.GetIcon(S.food) or Q, S.food ~= nil)
  r.text:SetText(S.food and ns.NameOf(S.food) or (DIM .. "No food|r"))
  r.value:SetText(S.food and ("|cffffd100" .. S.foodCount .. "|r") or "")
  r = rows.water
  icon(r, S.drink and ns.GetIcon(S.drink) or Q, S.drink ~= nil)
  r.text:SetText(S.drink and ns.NameOf(S.drink) or (DIM .. "No water|r"))
  r.value:SetText(S.drink and ("|cffffd100" .. S.drinkCount .. "|r") or "")
  -- what's waiting to be deleted: the next item, in its quality colour
  r = rows.del
  local nx = S.nextDel
  icon(r, nx and (nx.icon or ns.GetIcon(nx.id)) or "Interface\\Icons\\INV_Misc_Bag_10_Red", nx ~= nil)
  if not cleanOn then
    r.text:SetText(DIM .. "Clean-up is off|r")
    r.value:SetText("")
  elseif S.waitStacks > 0 and nx then
    r.text:SetText(qualityHex(nx.id, nx.link) .. ns.NameOf(nx.id, nx.link) .. "|r")
    r.value:SetText("|cffff5a50" .. S.waitStacks .. "|r" .. DIM .. " to delete|r")
  else
    r.text:SetText(DIM .. "Nothing to delete|r")
    r.value:SetText("")
  end
end

-- which lines show, and the window's height
local function layout()
  local o = P()
  local y, n = -(HEAD_H + 3), 0
  for _, l in ipairs(LINES) do
    local r = rows[l.key]
    local on = not o or o.lines[l.key] ~= false
    -- (1.7) lines of modules that aren't loaded don't show
    if l.key == "food" or l.key == "water" then on = on and ns.Has("eat") and ns.eat.enabled ~= false end
    if l.key == "sell" or l.key == "del" then on = on and ns.Has("del") end
    if l.key == "scrolls" then on = on and ns.Has("scrolls") and (ns.Scrolls.Summary()) > 0 end
    if l.key == "faire" then on = on and ns.Faire and ns.Faire.On and ns.Faire.On() end
    r:SetShown(on)
    if on then
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 5, y)
      r:SetPoint("RIGHT", -5, 0)
      n = n + 1
      r.stripe:SetShown(n % 2 == 0)
      y = y - LINE_H
    end
  end
  f:SetHeight(HEAD_H + 9 + n * LINE_H)
end

function Pocket.Update()
  if not f:IsShown() then return end
  layout()
  fill()
end

-- bag changes come in bursts: redraw at most a few times a second
local queued
local function queue()
  if not f:IsShown() or queued then return end
  queued = true
  C_Timer.After(0.3, function() queued = nil Pocket.Update() end)
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
