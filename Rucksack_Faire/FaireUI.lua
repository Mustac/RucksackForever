-- Rucksack / Darkmoon Faire: the window: Turn-ins (what you can hand in, and where to get the items: click a
-- place to pin it on the map), Prizes (your goal and the reward log), Decks, and Faire (dates, Sayge,
-- settings). Plus the minimap button.
local RS = Rucksack
if not RS then return end
RS.Faire = RS.Faire or {}
local ns = RS.Faire -- (the Faire keeps its own little namespace inside Rucksack)
local D = ns.D

local GOLD, GREY, GREEN, RED, PURPLE = "|cffffd100", "|cff999999", "|cff66dd66", "|cffff6060", "|cffb48cff"

local function ticketIcon()
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, D.TICKET_CURRENCY)
    if ok and type(info) == "table" and info.iconFileID then return info.iconFileID end
  end
  return ns.ItemIcon(D.TICKET_ITEM)
end
ns.TicketIcon = ticketIcon

---------------------------------------------------------------------------
-- The Faire page inside Rucksack's window (UI.lua made it, with the title and Enable box)
---------------------------------------------------------------------------
-- (1.7) the page and its top line, built with the core's widgets
local Page, GuideButton, ToolHeader, pages = RS.UI.Page, RS.UI.GuideButton, RS.UI.ToolHeader, RS.UI.pages
---------------------------------------------------------------------------
-- Darkmoon Faire (10 Nov): the page's top line here; the tabs and everything else are FaireUI.lua
---------------------------------------------------------------------------
do
  local p = Page()
  pages.faire = p
  GuideButton(p, "faire")
  ToolHeader(p, "|cffb48cffDarkmoon Faire|r", function() return RS.Faire.On() end, function(v) RS.Faire.SetOn(v) end,
    "On: ticket turn-in help at the Faire, item tooltips, the on-screen ticket button and quick turn-ins. Off: all of that stops (Clean-up still keeps turn-in items if that box is ticked).")
  p.updates[#p.updates + 1] = function() if RS.Faire.Refresh then RS.Faire.Refresh() end end
  RS.FairePage = p
end


local f = RS.FairePage

-- summary line: tickets, ready to hand in, the Faire, reputation
local tIcon = f:CreateTexture(nil, "OVERLAY")
tIcon:SetSize(16, 16)
tIcon:SetPoint("TOPLEFT", 0, -34)
local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
summary:SetPoint("LEFT", tIcon, "RIGHT", 5, 0)
summary:SetPoint("RIGHT", f, "RIGHT", 0, 0)
summary:SetJustifyH("LEFT")
local faireLine = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
faireLine:SetPoint("TOPLEFT", 0, -54)
faireLine:SetPoint("RIGHT", f, "RIGHT", 0, 0)
faireLine:SetJustifyH("LEFT")

-- tabs
local pages, tabs, current = {}, {}, nil
local function showPage(key)
  current = key
  for k, p in pairs(pages) do p:SetShown(k == key) end
  for k, t in pairs(tabs) do
    t.bg:SetColorTexture(k == key and 0.42 or 0.16, k == key and 0.3 or 0.13, k == key and 0.55 or 0.2, 1)
    t.text:SetTextColor(k == key and 1 or 0.75, k == key and 0.82 or 0.75, k == key and 0 or 0.75)
  end
  if ns.Refresh then ns.Refresh() end
end
local tabOrder = { { "turnins", "Turn-ins" }, { "prizes", "Prizes" }, { "decks", "Decks" }, { "faire", "Faire & Sayge" } }
local prevTab
for _, t in ipairs(tabOrder) do
  local b = CreateFrame("Button", nil, f)
  b:SetSize(t[1] == "faire" and 110 or 90, 22)
  if prevTab then b:SetPoint("LEFT", prevTab, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 0, -72) end
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.text:SetPoint("CENTER")
  b.text:SetText(t[2])
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  b:SetScript("OnClick", function() showPage(t[1]) end)
  b._label = t[2]
  tabs[t[1]] = b
  prevTab = b
  local p = CreateFrame("Frame", nil, f)
  p:SetPoint("TOPLEFT", 0, -100)
  p:SetPoint("BOTTOMRIGHT", 0, 0)
  p:Hide()
  pages[t[1]] = p
end

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------
local function text(parent, font, x, y, w)
  local s = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  s:SetPoint("TOPLEFT", x, y)
  if w then s:SetWidth(w) end
  s:SetJustifyH("LEFT")
  s:SetWordWrap(true)
  return s
end
local function tip(owner, lines)
  owner:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local l = type(lines) == "function" and lines(self) or lines
    for i, s in ipairs(l or {}) do
      if i == 1 then GameTooltip:AddLine(s) else GameTooltip:AddLine(s, 1, 1, 1, true) end
    end
    GameTooltip:Show()
  end)
  owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local function button(parent, label, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 110, 22)
  b:SetText(label)
  b._label = label
  b:SetScript("OnClick", onClick)
  return b
end
local function check(parent, label, get, set, help)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  local t = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t:SetPoint("LEFT", c, "RIGHT", 2, 1)
  t:SetText(label)
  c._label = label
  c:SetScript("OnShow", function(self) self:SetChecked(get()) end)
  c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) if ns.Refresh then ns.Refresh() end end)
  if help then tip(c, { label, help }) end
  return c
end

---------------------------------------------------------------------------
-- Turn-ins page: the list on the left, the selected item on the right
---------------------------------------------------------------------------
local P = pages.turnins
local selected -- the turn-in shown on the right
local rows, heads = {}, {}
local LIST_W = 372

local colHead = text(P, "GameFontDisableSmall", 22, 0)
colHead:SetText("Bring")
local colHave = text(P, "GameFontDisableSmall", 210, 0)
colHave:SetText("Have")
local colT = text(P, "GameFontDisableSmall", 262, 0)
colT:SetText("Tickets")
local colS = text(P, "GameFontDisableSmall", 312, 0)
colS:SetText("Status")

local function makeRow(i)
  local r = CreateFrame("Button", nil, P)
  r:SetSize(LIST_W, 16)
  r.sel = r:CreateTexture(nil, "BACKGROUND")
  r.sel:SetAllPoints()
  r.sel:SetColorTexture(0.42, 0.3, 0.55, 0.45)
  r.sel:Hide()
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.07)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(14, 14)
  r.icon:SetPoint("LEFT", 2, 0)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.name:SetPoint("LEFT", 20, 0)
  r.name:SetWidth(186)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.have = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.have:SetPoint("LEFT", 208, 0)
  r.tk = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.tk:SetPoint("LEFT", 266, 0)
  r.st = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.st:SetPoint("LEFT", 310, 0)
  r:SetScript("OnClick", function(self) selected = self.t if ns.Refresh then ns.Refresh() end end)
  tip(r, function(self)
    local t = self.t
    if not t then return {} end
    local st = ns.TurninState(t)
    local l = { ns.ItemName(st.item) .. " x" .. st.n, ("%s: \"%s\", %d ticket%s, from level %d"):format(t.npc, t.title, st.tickets, st.tickets == 1 and "" or "s", t.lv) }
    l[#l + 1] = "Click to see where to get it."
    return l
  end)
  rows[i] = r
  return r
end
local function makeHead(i)
  local h = P:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h:SetJustifyH("LEFT")
  heads[i] = h
  return h
end

-- right side
local R = CreateFrame("Frame", nil, P)
R:SetPoint("TOPLEFT", LIST_W + 14, 0)
R:SetPoint("BOTTOMRIGHT")
local rbg = R:CreateTexture(nil, "BACKGROUND")
rbg:SetAllPoints()
rbg:SetColorTexture(1, 1, 1, 0.04)
local rIcon = R:CreateTexture(nil, "ARTWORK")
rIcon:SetSize(32, 32)
rIcon:SetPoint("TOPLEFT", 8, -8)
local rName = text(R, "GameFontNormal", 46, -8, 220)
local rSub = text(R, "GameFontHighlightSmall", 46, -26, 220)
local rStatus = text(R, "GameFontHighlightSmall", 8, -48, 254)
local rHow = text(R, "GameFontNormalSmall", 8, -74, 254)
local spotBtns = {}
local rFoot = text(R, "GameFontDisableSmall", 8, -300, 254)

local function spotButton(i)
  local b = CreateFrame("Button", nil, R)
  b:SetSize(254, 30)
  b:SetPoint("TOPLEFT", 8, -92 - (i - 1) * 32)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.16, 0.13, 0.2, 0.9)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0, 0.18)
  b.pin = b:CreateTexture(nil, "ARTWORK")
  b.pin:SetSize(14, 14)
  b.pin:SetPoint("LEFT", 5, 0)
  b.pin:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
  b.a = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.a:SetPoint("TOPLEFT", 24, -3)
  b.a:SetWidth(226)
  b.a:SetJustifyH("LEFT")
  b.b = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  b.b:SetPoint("TOPLEFT", 24, -16)
  b.b:SetWidth(226)
  b.b:SetJustifyH("LEFT")
  b:SetScript("OnClick", function(self)
    local s = self.spot
    if not s then return end
    if IsShiftKeyDown() and self.all then
      for k, o in ipairs(self.all) do
        ns.Map.Pin({ map = o.map, x = o.x, y = o.y, zone = o.zone, label = o.mob .. " (" .. self.itemName .. ")" }, k > 1, k > 1)
      end
    else
      ns.Map.Pin({ map = s.map, x = s.x, y = s.y, zone = s.zone, label = s.mob .. " (" .. self.itemName .. ")" })
    end
  end)
  tip(b, function(self)
    local s = self.spot
    return { s.mob .. " (level " .. s.lv[1] .. (s.lv[2] ~= s.lv[1] and ("-" .. s.lv[2]) or "") .. ")",
      ("%s, around %.0f, %.0f. About %d%% of them drop it."):format(s.zone, s.x, s.y, s.pct),
      "Click: pin it on the map.  Shift-click: pin every place for this item." }
  end)
  spotBtns[i] = b
  return b
end

local function spotsFor(id)
  local list = D.SPOTS[id]
  if not list then return nil end
  local lvl = UnitLevel("player")
  local sorted = {}
  for _, s in ipairs(list) do sorted[#sorted + 1] = s end
  -- the ones you can handle first (closest to your level), too-high ones last
  table.sort(sorted, function(a, b)
    local ah, bh = a.lv[1] > lvl + 2, b.lv[1] > lvl + 2
    if ah ~= bh then return bh end
    if ah then return a.lv[1] < b.lv[1] end
    return math.abs(lvl - a.lv[2]) < math.abs(lvl - b.lv[2])
  end)
  return sorted
end

local function drawDetail()
  for _, b in ipairs(spotBtns) do b:Hide() end
  local t = selected
  if not t then
    rIcon:SetTexture(nil)
    rName:SetText("Pick a turn-in on the left")
    rSub:SetText("")
    rStatus:SetText(GREY .. "You'll see how many you need, how many you have, and where to get them. Farm spots can be pinned on your map with one click.|r")
    rHow:SetText("") rFoot:SetText("")
    return
  end
  local st = ns.TurninState(t)
  local name = ns.ItemName(st.item)
  rIcon:SetTexture(ns.ItemIcon(st.item))
  rName:SetText(name .. "  x" .. st.n)
  rSub:SetText(("%s, %d ticket%s.  From level %d."):format(t.npc, st.tickets, st.tickets == 1 and "" or "s", t.lv))
  local s
  if st.state == "ready" then s = GREEN .. ("Ready: you can hand this in %d time%s now."):format(st.times, st.times == 1 and "" or "s") .. "|r"
  elseif st.state == "level" then s = GREY .. "You need level " .. t.lv .. " for this one.|r"
  elseif st.state == "rep" then s = GREY .. "Closed: your Faire reputation is past this one's limit. Bring higher ones instead.|r"
  else s = ("You have %d, need %d more."):format(st.bags, st.need) end
  if st.all > st.bags then s = s .. ("  " .. GOLD .. "+%d in your bank.|r"):format(st.all - st.bags) end
  rStatus:SetText(s)

  local spots = spotsFor(st.item)
  local foot = {}
  if spots then
    rHow:SetText("Where to get it  " .. GREY .. "(click to pin on the map)|r")
    local lvl = UnitLevel("player")
    for i, sp in ipairs(spots) do
      if i > 6 then break end
      local b = spotBtns[i] or spotButton(i)
      b.spot, b.all, b.itemName = sp, spots, name
      local hi = sp.lv[1] > lvl + 2
      local lvText = sp.lv[1] .. (sp.lv[2] ~= sp.lv[1] and ("-" .. sp.lv[2]) or "")
      b.a:SetText((hi and RED or "|cffffffff") .. sp.mob .. "|r  " .. GREY .. "level " .. lvText .. "|r")
      b.b:SetText(("%s  %.0f, %.0f   %d%% drop"):format(sp.zone, sp.x, sp.y, sp.pct))
      b.bg:SetColorTexture(hi and 0.2 or 0.16, hi and 0.1 or 0.13, hi and 0.1 or 0.2, 0.9)
      b:Show()
    end
    foot[#foot + 1] = "Red = higher than you. Or buy them on the Auction House."
  else
    local prof = D.CRAFTED[st.item]
    local how = {}
    how[#how + 1] = "Made with " .. GOLD .. (prof or "a profession") .. "|r."
    local rec = ns.db.recipes[st.item]
    if ns.char.canMake[st.item] then how[#how + 1] = GREEN .. "You know this recipe.|r" end
    if rec and rec.mats and #rec.mats > 0 then
      how[#how + 1] = "Each one takes:"
      for _, m in ipairs(rec.mats) do how[#how + 1] = ("  %d x %s"):format(m.n, m.name) end
      if not ns.char.canMake[st.item] and rec.by then how[#how + 1] = GREY .. "(" .. rec.by .. " knows it)|r" end
    else
      how[#how + 1] = GREY .. "Open the profession window on a character that knows it, and the materials show up here.|r"
    end
    how[#how + 1] = ""
    how[#how + 1] = "Or buy them on the Auction House: crafters make plenty of these for the Faire."
    rHow:SetText(table.concat(how, "\n"))
  end
  -- other characters
  local me = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
  for who, items in pairs(ns.db.alts) do
    if who ~= me and items[st.item] then foot[#foot + 1] = ("%s has %d."):format(who:match("^[^-]+"), items[st.item]) end
  end
  rFoot:ClearAllPoints()
  rFoot:SetPoint("BOTTOMLEFT", 8, 8)
  rFoot:SetWidth(254)
  rFoot:SetText(table.concat(foot, "\n"))
end

local function drawTurnins()
  local y, ri, hi = -16, 0, 0
  for _, g in ipairs(D.TURNINS) do
    hi = hi + 1
    local h = heads[hi] or makeHead(hi)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 2, y - 3)
    h:SetText(g.npc .. "  " .. GREY .. g.what .. "|r")
    h:Show()
    y = y - 20
    for _, t in ipairs(g.list) do
      ri = ri + 1
      local r = rows[ri] or makeRow(ri)
      local st = ns.TurninState(t)
      r.t = t
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, y)
      r.icon:SetTexture(ns.ItemIcon(st.item))
      local dim = st.state == "level" or st.state == "rep"
      r.name:SetText((dim and GREY or "") .. ns.ItemName(st.item) .. " x" .. st.n .. (dim and "|r" or ""))
      r.have:SetText((st.bags >= st.n and GREEN or (st.bags > 0 and "|cffffffff" or GREY)) .. st.bags .. "|r"
        .. (st.all > st.bags and (GOLD .. "+" .. (st.all - st.bags) .. "|r") or ""))
      r.tk:SetText((dim and GREY or GOLD) .. st.tickets .. "|r")
      if st.state == "ready" then r.st:SetText(GREEN .. "ready x" .. st.times .. "|r")
      elseif st.state == "level" then r.st:SetText(GREY .. "level " .. t.lv .. "|r")
      elseif st.state == "rep" then r.st:SetText(GREY .. "closed|r")
      else r.st:SetText("need " .. st.need) end
      r.sel:SetShown(selected == t)
      r:Show()
      y = y - 16
    end
    y = y - 4
  end
  for i = ri + 1, #rows do rows[i]:Hide() end
  for i = hi + 1, #heads do heads[i]:Hide() end
  drawDetail()
end

---------------------------------------------------------------------------
-- Prizes page: pick a goal, see how far you are, and the log
---------------------------------------------------------------------------
local Q = pages.prizes

-- the tracked prize, its icon, and how to get there (shared with the on-screen tracker)
function ns.Goal()
  for _, p in ipairs(D.PRIZES) do if p.name == ns.char.goal then return p end end
end
function ns.PrizeIcon(p)
  if p.item then return ns.ItemIcon(p.item) end
  return "Interface\\Icons\\INV_Scroll_04"
end
function ns.GoalRoute(goal, have, waiting)
  local left = goal.cost - have - (waiting or 0)
  if have >= goal.cost then return GREEN .. "You have enough! Go see Gelvas Grimegate.|r" end
  if left <= 0 then return GREEN .. "Hand in what's in your bags and you'll have enough.|r" end
  local best
  for _, t in ipairs(ns.AllTurnins()) do
    local st = ns.TurninState(t)
    if (st.state == "ready" or st.state == "short") and (not best or st.tickets > best.st.tickets) then best = { t = t, st = st } end
  end
  local s = ("%d more tickets to go."):format(left)
  if best then
    s = s .. ("  About %d x %s (%d %s each, %d tickets)."):format(math.ceil(left / best.st.tickets), best.t.title,
      best.st.n, ns.ItemName(best.st.item), best.st.tickets)
  end
  return s
end

-- top: the tracked prize, big
local goalIcon = Q:CreateTexture(nil, "ARTWORK")
goalIcon:SetSize(38, 38)
goalIcon:SetPoint("TOPLEFT", 0, 0)
local goalText = text(Q, "GameFontNormalLarge", 46, -1, 600)
local barBg = Q:CreateTexture(nil, "ARTWORK")
barBg:SetPoint("TOPLEFT", 46, -22)
barBg:SetSize(594, 16)
barBg:SetColorTexture(0.15, 0.12, 0.2, 1)
local barWait = Q:CreateTexture(nil, "ARTWORK", nil, 1)
barWait:SetPoint("TOPLEFT", barBg, "TOPLEFT")
barWait:SetHeight(16)
barWait:SetColorTexture(0.62, 0.42, 0.85, 0.35)
local bar = Q:CreateTexture(nil, "OVERLAY")
bar:SetPoint("TOPLEFT", barBg, "TOPLEFT")
bar:SetHeight(16)
bar:SetColorTexture(0.62, 0.42, 0.85, 1)
local barText = Q:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
barText:SetPoint("CENTER", barBg)
local routeText = text(Q, "GameFontHighlightSmall", 46, -44, 594)

-- the prizes as tiles: icon, name, cost. Click to track.
local tiles = {}
local TW, TH = 128, 58
for i, p in ipairs(D.PRIZES) do
  local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
  local t = CreateFrame("Button", nil, Q, ns.BACKDROP_TMPL)
  t:SetSize(TW, TH)
  t:SetPoint("TOPLEFT", col * (TW + 6), -74 - row * (TH + 6))
  if t.SetBackdrop then t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }) end
  local hl = t:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.06)
  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetSize(34, 34)
  t.icon:SetPoint("TOPLEFT", 6, -6)
  t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  t.name = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t.name:SetPoint("TOPLEFT", 46, -6)
  t.name:SetWidth(TW - 50)
  t.name:SetJustifyH("LEFT")
  t.name:SetWordWrap(true)
  t.tIcon = t:CreateTexture(nil, "OVERLAY")
  t.tIcon:SetSize(12, 12)
  t.tIcon:SetPoint("BOTTOMLEFT", 46, 6)
  t.cost = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t.cost:SetPoint("LEFT", t.tIcon, "RIGHT", 3, 0)
  t.tag = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t.tag:SetPoint("BOTTOMRIGHT", -5, 6)
  t.p = p
  t._label = p.name
  t:SetScript("OnClick", function(self)
    ns.char.goal = (ns.char.goal ~= self.p.name) and self.p.name or nil
    ns.char.goalReached = nil
    ns.Refresh()
    if ns.PaintScreenButton then ns.PaintScreenButton() end
  end)
  t:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.p.item and GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.p.item) else GameTooltip:AddLine(self.p.name) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(PURPLE .. "Faire:|r " .. self.p.cost .. " tickets at Gelvas Grimegate, from level " .. self.p.lv .. ".", 1, 1, 1, true)
    GameTooltip:AddLine(self.p.note .. ".", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(ns.char.goal == self.p.name and "Click to stop tracking it." or "Click to track it on screen.", 0.6, 0.85, 1, true)
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tiles[i] = t
end
local histHead = text(Q, "GameFontNormal", 412, -74, 228)
histHead:SetText("Your Faire log")
local histText = text(Q, "GameFontHighlightSmall", 412, -94, 228)

local function drawPrizes()
  local have = ns.Tickets()
  local _, waiting = ns.ReadyNow()
  local goal = ns.Goal()
  local lvl = UnitLevel("player")
  local tex = ticketIcon()
  for _, t in ipairs(tiles) do
    local p = t.p
    local tracked, afford, low = goal == p, have >= p.cost, lvl < p.lv
    t.icon:SetTexture(ns.PrizeIcon(p))
    t.icon:SetDesaturated(low)
    t.tIcon:SetTexture(tex)
    t.name:SetText((low and GREY or "") .. p.name .. (low and "|r" or ""))
    t.cost:SetText((afford and GREEN or GOLD) .. p.cost .. "|r")
    t.tag:SetText(tracked and (GOLD .. "Tracking|r") or (low and (GREY .. "level " .. p.lv .. "|r")) or "")
    if t.SetBackdrop then
      t:SetBackdropColor(tracked and 0.2 or 0.09, tracked and 0.15 or 0.07, tracked and 0.05 or 0.12, 0.95)
      if tracked then t:SetBackdropBorderColor(1, 0.82, 0, 1)
      elseif afford and not low then t:SetBackdropBorderColor(0.3, 0.8, 0.35, 1)
      else t:SetBackdropBorderColor(0.3, 0.24, 0.38, 1) end
    end
  end
  if goal then
    goalIcon:SetTexture(ns.PrizeIcon(goal))
    goalIcon:Show()
    goalText:SetText(GOLD .. goal.name .. "|r  " .. GREY .. goal.cost .. " tickets|r")
    bar:SetWidth(math.max(1, 594 * math.min(1, have / goal.cost)))
    barWait:SetWidth(math.max(1, 594 * math.min(1, (have + waiting) / goal.cost)))
    barWait:SetShown(waiting > 0)
    barText:SetText(("%d / %d%s"):format(have, goal.cost, waiting > 0 and ("   (+%d in bags)"):format(waiting) or ""))
    routeText:SetText(ns.GoalRoute(goal, have, waiting))
  else
    goalIcon:SetTexture(ticketIcon())
    goalText:SetText("Pick a prize to track it")
    bar:SetWidth(1)
    barWait:Hide()
    barText:SetText(("%d tickets%s"):format(have, waiting > 0 and ("   +%d waiting in your bags"):format(waiting) or ""))
    routeText:SetText(GREY .. "Click a prize below: it shows on screen with how many tickets you have and need.|r")
  end
  -- log: this Faire's totals, then the latest lines
  local h = ns.char.history
  local _, _, _, s = ns.FaireStatus()
  local week = s and ("%d-%02d-%02d"):format(s[1], s[2], s[3])
  local got, spent = 0, 0
  for _, e in ipairs(h) do if e.week == week then got, spent = got + (e.got or 0), spent + (e.spent or 0) end end
  local lines = { ("This Faire: %s+%d|r earned, %s%d|r spent"):format(GREEN, got, GOLD, spent), "" }
  for i = #h, math.max(1, #h - 16), -1 do
    local e = h[i]
    lines[#lines + 1] = GREY .. e.when:sub(6) .. "|r  " .. (e.got and (GREEN .. "+" .. e.got .. "|r ") or (GOLD .. "-" .. e.spent .. "|r ")) .. e.what
  end
  if #h == 0 then lines[#lines + 1] = GREY .. "Nothing yet. Hand-ins and prizes show up here.|r" end
  histText:SetText(table.concat(lines, "\n"))
end

---------------------------------------------------------------------------
-- Decks page
---------------------------------------------------------------------------
local K = pages.decks
local deckIntro = text(K, "GameFontHighlightSmall", 0, 0, 640)
deckIntro:SetText("Darkmoon cards drop at random in the world. Get all eight of one kind (Ace to Eight), right-click a card to make the deck, "
  .. "and hand the deck in at the Faire for its trinket. Cards in your bank count once you've opened the bank.")
local deckCols = {}
for i, deck in ipairs(D.DECKS) do
  local x = (i - 1) * 160
  local h = text(K, "GameFontNormal", x, -40, 150)
  h:SetText(deck)
  local sub = text(K, "GameFontDisableSmall", x, -56, 150)
  sub:SetText(D.DECK_TRINKET[deck]:gsub("Darkmoon Card: ", ""))
  local lines = {}
  for j, card in ipairs(D.CARDS) do lines[j] = text(K, "GameFontHighlightSmall", x + 4, -74 - (j - 1) * 16, 146) end
  local done = text(K, "GameFontHighlightSmall", x, -74 - 8 * 16 - 6, 150)
  deckCols[i] = { deck = deck, lines = lines, done = done }
end
local function drawDecks()
  for _, c in ipairs(deckCols) do
    local n = 0
    for j, card in ipairs(D.CARDS) do
      local where = ns.HasCard(c.deck, card)
      if where then n = n + 1 end
      c.lines[j]:SetText((where == "bags" and (GREEN .. "+ ") or where == "bank" and (GOLD .. "+ ") or (GREY .. "- "))
        .. card .. " of " .. c.deck .. (where == "bank" and "  (bank)" or "") .. "|r")
    end
    local deck = ns.HasCard(c.deck, "deck")
    if deck then c.done:SetText(GREEN .. "Deck made! Hand it in at the Faire.|r")
    elseif n == 8 then c.done:SetText(GREEN .. "All 8: right-click a card to make the deck.|r")
    else c.done:SetText(("%d of 8"):format(n)) end
  end
end

---------------------------------------------------------------------------
-- Faire & Sayge page
---------------------------------------------------------------------------
local F = pages.faire
local whenText = text(F, "GameFontNormal", 0, 0, 640)
local schedText = text(F, "GameFontHighlightSmall", 0, -22, 300)
local pinFaire = button(F, "Pin the Faire", 120, function()
  local open, where = ns.FaireStatus()
  local spot = D.FAIRE_SPOT[where or "Elwynn"]
  ns.Map.Pin({ map = spot.map, x = spot.x, y = spot.y, zone = spot.zone, label = "Darkmoon Faire" })
end)
pinFaire:SetPoint("TOPLEFT", 0, -140)
local clearPins = button(F, "Clear map pins", 120, function() ns.Map.Clear() end)
clearPins:SetPoint("LEFT", pinFaire, "RIGHT", 8, 0)

local saygeHead = text(F, "GameFontNormal", 330, -22, 300)
saygeHead:SetText("Sayge's fortune  " .. GREY .. "(a 2-hour buff)|r")
local saygeText = text(F, "GameFontHighlightSmall", 330, -42, 300)
do
  local l = { GREY .. "Talk to Sayge, pick answer 1 / 2 / 3 / 4, then the next answer:|r" }
  for _, s in ipairs(D.SAYGE) do l[#l + 1] = ("  %s then %s:  %s"):format(s[1], s[2], (s[1] == "1" and s[2] == "1") and (GOLD .. s[3] .. "|r") or s[3]) end
  saygeText:SetText(table.concat(l, "\n"))
end

local optHead = text(F, "GameFontNormal", 0, -184, 300)
optHead:SetText("Settings")
local c1 = check(F, "Quick turn-ins", function() return ns.db.quick ~= false end, function(v) ns.db.quick = v end,
  "Talk to Yebb, Kerri, Rinling or Chronos and the ticket quests you have the items for are accepted and handed in for you. "
  .. "Hold Shift while talking to do it yourself. It never spends tickets on prizes.")
c1:SetPoint("TOPLEFT", 0, -204)
local c2 = check(F, "Item tooltips", function() return ns.db.tooltips ~= false end, function(v) ns.db.tooltips = v end,
  "Adds a line to turn-in items: who wants them, how many tickets, how many you have.")
c2:SetPoint("TOPLEFT", 0, -230)
local c3 = check(F, "Keep Darkmoon turn-in items", function() return ns.db.keepItems ~= false end, function(v)
  ns.db.keepItems = v
  if RS.Del and RS.Del.Refresh then RS.Del.Refresh() end
end, "Clean-up never deletes or sells the items the Faire NPCs want (Small Furry Paws, Torn Bear Pelts, Thorium Widgets...), even the grey ones.")
c3:SetPoint("TOPLEFT", 0, -256)
local c4 = check(F, "Note in chat at login during the Faire", function() return ns.db.loginNote ~= false end, function(v) ns.db.loginNote = v end)
c4:SetPoint("TOPLEFT", 0, -282)
local c5 = check(F, "Button on screen", function() return ns.db.screenButton ~= false end, function(v)
  ns.db.screenButton = v
  if ns.UpdateScreenButton then ns.UpdateScreenButton() end
end, "A small ticket button you can drag anywhere. Left-click opens the Faire page, right-click the prizes. /faire button turns it on or off.")
c5:SetPoint("TOPLEFT", 0, -308)
local c6 = check(F, "Only while the Faire is open", function() return ns.db.screenButtonFaireOnly end, function(v)
  ns.db.screenButtonFaireOnly = v or nil
  if ns.UpdateScreenButton then ns.UpdateScreenButton() end
end, "Hide the on-screen button in the weeks there's no Faire.")
c6:SetPoint("TOPLEFT", 20, -334)
local c7 = check(F, "Prize tracker on screen", function() return ns.db.tracker ~= false end, function(v)
  ns.db.tracker = v
  if ns.PaintScreenButton then ns.PaintScreenButton() end
end, "When you track a prize (Prizes tab), the on-screen button shows its icon, your tickets out of what it costs, and a bar. /faire track turns it on or off.")
c7:SetPoint("TOPLEFT", 20, -360)

local function drawFaire()
  whenText:SetText(ns.FaireLine())
  local l = {}
  local open, where, _, cur = ns.FaireStatus()
  for _, s in ipairs(D.SCHEDULE) do
    local spot = D.FAIRE_SPOT[s[4]]
    local line = ("%d-%02d-%02d  %s  " .. GREY .. "(%s)|r"):format(s[1], s[2], s[3], spot.zone, spot.near)
    if s == cur then line = (open and GREEN or GOLD) .. "> |r" .. line else line = "   " .. line end
    l[#l + 1] = line
  end
  l[#l + 1] = GREY .. "Each one runs a week, Monday 04:00 to Monday 04:00 realm time.|r"
  schedText:SetText(table.concat(l, "\n"))
end

---------------------------------------------------------------------------
function ns.Refresh()
  if not f:IsShown() or not ns.db then return end
  tIcon:SetTexture(ticketIcon())
  local tickets = ns.Tickets()
  local count, waiting = ns.ReadyNow()
  local _, into, size, sname = ns.Rep()
  summary:SetText(("%s%d|r tickets     %s     Faire rep: %s %d/%d"):format(GOLD, tickets,
    count > 0 and (GREEN .. ("Ready to hand in: %d (+%d tickets)"):format(count, waiting) .. "|r") or (GREY .. "nothing ready to hand in|r"),
    sname, into, size))
  faireLine:SetText(ns.FaireLine())
  if current == "turnins" then drawTurnins()
  elseif current == "prizes" then drawPrizes()
  elseif current == "decks" then drawDecks()
  elseif current == "faire" then drawFaire() end
end
f:HookScript("OnShow", function() if not current then showPage("turnins") else ns.Refresh() end end)

-- open Rucksack on the Faire page (and a tab: turnins, prizes, decks, faire)
function ns.Open(tab)
  local shown = RucksackFrame and RucksackFrame:IsShown() and f:IsShown()
  if not tab and shown then RucksackFrame:Hide() return end
  Rucksack_Open("faire")
  if tab and pages[tab] then showPage(tab) elseif not current then showPage("turnins") end
end

local function quickTip(self, how)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(PURPLE .. "Darkmoon Faire|r")
  GameTooltip:AddLine(ns.FaireLine(), 1, 1, 1)
  local count, waiting = ns.ReadyNow()
  GameTooltip:AddDoubleLine("Tickets", tostring(ns.Tickets()), 1, 1, 1, 1, 0.82, 0)
  if count > 0 then GameTooltip:AddDoubleLine("Ready to hand in", ("%d (+%d tickets)"):format(count, waiting), 1, 1, 1, 0.4, 0.87, 0.4) end
  if ns.char.goal then GameTooltip:AddDoubleLine("Goal", ns.char.goal, 1, 1, 1, 1, 1, 1) end
  GameTooltip:AddLine(how, 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end


---------------------------------------------------------------------------
-- (10 Nov) the on-screen button. No prize tracked: a ticket icon with your ticket count (a green
-- number = turn-ins ready). Tracking a prize: a little card with the prize's icon filling up with
-- colour, "37 / 50" and a bar; gold with a glow once you have enough.
-- Left-click: open. Right-click: prizes. Drag: move.
---------------------------------------------------------------------------
local sb = CreateFrame("Button", "RucksackFaireButton", UIParent, ns.BACKDROP_TMPL)
sb:SetSize(40, 40)
sb:SetFrameStrata("MEDIUM")
sb:SetClampedToScreen(true)
sb:SetMovable(true)
sb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
sb:RegisterForDrag("LeftButton")
if sb.SetBackdrop then
  sb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
end
local function edge(r, g, b) if sb.SetBackdrop then sb:SetBackdropColor(0.05, 0.04, 0.07, 0.92) sb:SetBackdropBorderColor(r, g, b, 1) end end
edge(0.62, 0.42, 0.85)

-- the icon: grey underneath, the coloured copy on top shows only the part you've earned
local sbIcon = sb:CreateTexture(nil, "ARTWORK")
sbIcon:SetSize(34, 34)
sbIcon:SetPoint("TOPLEFT", 3, -3)
sbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local sbFill = sb:CreateTexture(nil, "ARTWORK", nil, 1)
sbFill:SetPoint("BOTTOMLEFT", sbIcon, "BOTTOMLEFT")
sbFill:SetWidth(34)
local sbHl = sb:CreateTexture(nil, "HIGHLIGHT")
sbHl:SetAllPoints()
sbHl:SetColorTexture(1, 1, 1, 0.08)
local sbCount = sb:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
sbCount:SetPoint("BOTTOMRIGHT", sbIcon, "BOTTOMRIGHT", 1, 1)
local sbBadge = sb:CreateTexture(nil, "OVERLAY")
sbBadge:SetSize(16, 16)
sbBadge:SetPoint("TOPRIGHT", sbIcon, "TOPRIGHT", 5, 5)
sbBadge:SetColorTexture(0.15, 0.55, 0.15, 1)
local sbReady = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sbReady:SetPoint("CENTER", sbBadge, "CENTER", 0, 0)

-- card parts (tracking a prize)
local cName = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cName:SetPoint("TOPLEFT", sbIcon, "TOPRIGHT", 7, -1)
cName:SetWidth(128)
cName:SetJustifyH("LEFT")
cName:SetWordWrap(false)
local cNum = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
cNum:SetPoint("TOPLEFT", cName, "BOTTOMLEFT", 0, -1)
local cMore = sb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
cMore:SetPoint("LEFT", cNum, "RIGHT", 6, -1)
local cBarBg = sb:CreateTexture(nil, "ARTWORK")
cBarBg:SetPoint("BOTTOMLEFT", sbIcon, "BOTTOMRIGHT", 7, 0)
cBarBg:SetSize(128, 5)
cBarBg:SetColorTexture(0.15, 0.12, 0.2, 1)
local cBarWait = sb:CreateTexture(nil, "ARTWORK", nil, 1)
cBarWait:SetPoint("TOPLEFT", cBarBg)
cBarWait:SetHeight(5)
cBarWait:SetColorTexture(0.62, 0.42, 0.85, 0.35)
local cBar = sb:CreateTexture(nil, "ARTWORK", nil, 2)
cBar:SetPoint("TOPLEFT", cBarBg)
cBar:SetHeight(5)
-- the glow when you have enough
local glow = sb:CreateTexture(nil, "BACKGROUND", nil, -1)
glow:SetPoint("TOPLEFT", -8, 8)
glow:SetPoint("BOTTOMRIGHT", 8, -8)
glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
glow:SetBlendMode("ADD")
glow:SetVertexColor(1, 0.82, 0, 1)
glow:Hide()
local pulse = sb:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(0.25)
fade:SetToAlpha(1)
fade:SetDuration(0.9)

local CARD = { cName, cNum, cMore, cBarBg, cBarWait, cBar }
local function setCard(on)
  for _, r in ipairs(CARD) do r:SetShown(on) end
  sb:SetSize(on and 184 or 40, 40)
end

sb:SetScript("OnClick", function(_, mouse)
  if mouse == "RightButton" then ns.Open("prizes") else ns.Open() end
end)
sb:SetScript("OnDragStart", function(self) self:StartMoving() end)
sb:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  ns.db.screenPos = { p, rp, x, y }
end)
sb:SetScript("OnEnter", function(self)
  local goal = ns.char and ns.Goal()
  if goal then
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(PURPLE .. "Darkmoon Faire|r: " .. GOLD .. goal.name .. "|r")
    local have = ns.Tickets()
    local _, waiting = ns.ReadyNow()
    GameTooltip:AddDoubleLine("Tickets", ("%d / %d"):format(have, goal.cost), 1, 1, 1, 1, 0.82, 0)
    if waiting > 0 then GameTooltip:AddDoubleLine("Waiting in your bags", "+" .. waiting, 1, 1, 1, 0.4, 0.87, 0.4) end
    GameTooltip:AddLine(ns.GoalRoute(goal, have, waiting), 1, 1, 1, true)
    GameTooltip:AddLine(ns.FaireLine(), 1, 1, 1, true)
    GameTooltip:AddLine("Left-click: open.  Right-click: prizes.  Drag: move.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  else
    quickTip(self, "Left-click: open.  Right-click: prizes (pick one to track).  Drag: move.")
  end
end)
sb:SetScript("OnLeave", function() GameTooltip:Hide() end)
sb:Hide()

function ns.PaintScreenButton()
  if not sb:IsShown() or not ns.char then return end
  local have = ns.Tickets()
  local count, waiting = ns.ReadyNow()
  local goal = ns.db.tracker ~= false and ns.Goal()
  if not goal then
    setCard(false)
    edge(0.62, 0.42, 0.85)
    sbIcon:SetTexture(ticketIcon())
    sbIcon:SetDesaturated(false)
    sbIcon:SetVertexColor(1, 1, 1)
    sbFill:Hide()
    sbCount:SetText(tostring(have))
    sbBadge:SetShown(count > 0)
    sbReady:SetShown(count > 0)
    sbReady:SetText(count)
    glow:Hide()
    pulse:Stop()
    return
  end
  setCard(true)
  sbCount:SetText("")
  sbBadge:Hide()
  sbReady:Hide()
  local icon = ns.PrizeIcon(goal)
  local frac = math.min(1, have / goal.cost)
  sbIcon:SetTexture(icon)
  sbIcon:SetDesaturated(true)
  sbIcon:SetVertexColor(0.6, 0.6, 0.6)
  -- the coloured part grows from the bottom
  if frac > 0 then
    sbFill:SetTexture(icon)
    sbFill:SetHeight(math.max(0.5, 34 * frac))
    sbFill:SetTexCoord(0.08, 0.92, 0.92 - 0.84 * frac, 0.92)
    sbFill:Show()
  else
    sbFill:Hide()
  end
  local done = have >= goal.cost
  cName:SetText(goal.name)
  cNum:SetText((done and GREEN or "|cffffffff") .. have .. "|r" .. GREY .. " / " .. goal.cost .. "|r")
  cMore:SetText(done and "" or (waiting > 0 and (GREEN .. "+" .. waiting .. " in bags|r")) or "")
  cBar:SetWidth(math.max(1, 128 * frac))
  cBar:SetColorTexture(done and 1 or 0.62, done and 0.82 or 0.42, done and 0 or 0.85, 1)
  cBarWait:SetWidth(math.max(1, 128 * math.min(1, (have + waiting) / goal.cost)))
  cBarWait:SetShown(waiting > 0 and not done)
  if done then
    edge(1, 0.82, 0)
    cName:SetText(GOLD .. "Ready! See Gelvas Grimegate|r")
    glow:Show()
    if not pulse:IsPlaying() then pulse:Play() end
    if not ns.char.goalReached then
      ns.char.goalReached = true
      ns.Print(("you have %d tickets: enough for |cffffd100%s|r! Go see Gelvas Grimegate."):format(have, goal.name))
    end
  else
    edge(0.62, 0.42, 0.85)
    glow:Hide()
    pulse:Stop()
    ns.char.goalReached = nil
  end
end
function ns.UpdateScreenButton()
  local db = ns.db
  if not db then return end
  local show = ns.On() and db.screenButton ~= false
  if show and db.screenButtonFaireOnly then show = ns.FaireStatus() == true end
  if show then
    sb:ClearAllPoints()
    local pos = db.screenPos
    if pos then sb:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else sb:SetPoint("RIGHT", UIParent, "RIGHT", -220, 60) end
    sb:Show()
    ns.PaintScreenButton()
  else
    sb:Hide()
  end
end
table.insert(ns.onLogin, function() ns.UpdateScreenButton() end)
