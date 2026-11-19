-- Rucksack / Haul window: Halo's look (the bevel edge on a dark see-through background).
-- (19 Nov) Start / Pause / Stop / History / Settings at the top; at the bottom Value and the view:
-- by value (one line per item, most valuable first) or by pulls (each pull, its items by value).
local ns = Rucksack
local H = ns and ns.Haul
if not H then return end
local UI = {}
H.UI = UI

local TMPL = H.BACKDROP_TMPL
local WHITE = "Interface\\Buttons\\WHITE8X8"
local EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local ROW = 18
local BROW = 16       -- rows in the pull box
local BOX_ROWS = 5
local LINE = 15
local SUM_TOP = -30
local EDGES = { grey = { 0.55, 0.55, 0.58 }, bronze = { 0.82, 0.68, 0.45 }, black = { 0.12, 0.12, 0.12 } }
local floor, max, min = math.floor, math.max, math.min

local f
local styled = {}
UI.view = "now"
UI.offset = 0

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------
local function edgeColor()
  local c = EDGES[H.db.edge] or EDGES.grey
  return c[1], c[2], c[3]
end

local function paint(fr)
  if not fr.SetBackdrop then return end
  if fr.isMain then
    fr:SetBackdrop({ bgFile = WHITE, edgeFile = EDGE, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    fr:SetBackdropColor(0.04, 0.04, 0.06, H.db.alpha)
  else
    fr:SetBackdrop({ bgFile = WHITE, edgeFile = EDGE, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    if fr.hover then fr:SetBackdropColor(0.2, 0.2, 0.24, 0.95) else fr:SetBackdropColor(0.08, 0.08, 0.1, 0.8) end
  end
  fr:SetBackdropBorderColor(edgeColor())
end

function UI.Restyle()
  if not f then return end
  for _, fr in ipairs(styled) do paint(fr) end
  if UI.thumb then UI.thumb:SetColorTexture(edgeColor()) end
  f:SetScale(H.db.scale or 1)
end

local function tip(owner, lines)
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  for i, l in ipairs(lines) do
    if type(l) == "table" then
      GameTooltip:AddDoubleLine(l[1], l[2], 1, 0.82, 0, 1, 1, 1)
    elseif i == 1 then
      GameTooltip:AddLine(l, 1, 1, 1)
    else
      GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true)
    end
  end
  GameTooltip:Show()
end

local function Button(text, w, onClick, tipLines)
  local b = CreateFrame("Button", nil, f, TMPL)
  b:SetSize(w, 18)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", 0, 0)
  b.text:SetText(text)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", onClick)
  b:SetScript("PostClick", function(self) -- (19 Nov) the tooltip written again after a click
    if GameTooltip:IsOwned(self) and self:IsMouseOver() then local fn = self:GetScript("OnEnter") if fn then fn(self) end end
  end)
  b:SetScript("OnEnter", function(self)
    self.hover = true
    paint(self)
    local t = type(tipLines) == "function" and tipLines() or tipLines
    if t then tip(self, t) end
  end)
  b:SetScript("OnLeave", function(self)
    self.hover = nil
    paint(self)
    GameTooltip:Hide()
  end)
  styled[#styled + 1] = b
  paint(b)
  return b
end

---------------------------------------------------------------------------
-- Text helpers
---------------------------------------------------------------------------
local function qualityColor(q)
  if q and C_Item and C_Item.GetItemQualityColor then
    local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
    if ok and r then return r, g, b end
  end
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local function classHex(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c and c.colorStr then return "|c" .. c.colorStr end
  return "|cffffffff"
end

local function mmss(secs)
  secs = floor(secs or 0)
  return string.format("%d:%02d", floor(secs / 60), secs % 60)
end

local function ago(t)
  local d = time() - (t or time())
  if d < 60 then return d .. " s ago" end
  if d < 3600 then return floor(d / 60) .. " min ago" end
  return floor(d / 3600) .. " h ago"
end

local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

local function insertLink(link)
  local fn = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
  if fn then pcall(fn, link) end
end

---------------------------------------------------------------------------
-- Rows (shared by the list and the pull box)
---------------------------------------------------------------------------
local rows, boxRows = {}, {}
local data = {}

local function pullTip(r, d)
  local p = d.p
  local lines = { (d.live and p.open) and "This pull" or "Pull at " .. date("%H:%M:%S", p.start) }
  lines[#lines + 1] = { "Fight", p.fight and mmss(d.live and H.FightTime(p) or p.ft) or "no fight" }
  lines[#lines + 1] = { "Coins", H.Money(p.gold or 0) }
  lines[#lines + 1] = { "Items (" .. (d.count or 0) .. ")", H.Money(d.worth or 0) }
  lines[#lines + 1] = { "Total", H.Money((p.gold or 0) + (d.worth or 0)) }
  tip(r, lines)
end

local function rowEnter(r)
  local d = r.d
  if not d then return end
  if d.kind == "item" then
    GameTooltip:SetOwner(r, "ANCHOR_LEFT")
    if not (d.link and pcall(GameTooltip.SetHyperlink, GameTooltip, d.link)) then
      pcall(GameTooltip.SetItemByID, GameTooltip, d.id)
    end
    GameTooltip:AddLine(" ")
    if d.frozen then
      GameTooltip:AddDoubleLine("Looted x" .. d.n, H.Money(d.total), 0.85, 0.7, 0.4, 1, 1, 1)
      GameTooltip:AddLine(d.vkind == "ah" and "Valued at the auction price when saved." or "Valued at the vendor price when saved.", 0.6, 0.6, 0.6)
    else
      local _, quality, _, _, bind = H.Info(d.id, d.link)
      local _, _, ah, vendor, src, age, skey = H.Value(d.id, d.link)
      if ah then
        GameTooltip:AddDoubleLine("Auction, each", H.Money(ah), 0.85, 0.7, 0.4, 1, 1, 1)
        GameTooltip:AddLine((src or "?") .. ", " .. (age and H.Age(age) or "age unknown"), 0.6, 0.6, 0.6)
        local def = skey and H.SOURCE_BY[skey]
        if def and def.credit then GameTooltip:AddLine(def.credit, 0.6, 0.6, 0.6) end
      elseif quality == 0 or bind == 1 or bind == 4 then
        GameTooltip:AddDoubleLine("Auction", "can't be sold there", 0.85, 0.7, 0.4, 0.6, 0.6, 0.6)
      else
        GameTooltip:AddDoubleLine("Auction", "no price yet", 0.85, 0.7, 0.4, 0.6, 0.6, 0.6)
      end
      GameTooltip:AddDoubleLine("Vendor, each", vendor and H.Money(vendor) or "can't be sold", 0.85, 0.7, 0.4, 1, 1, 1)
      GameTooltip:AddDoubleLine("Looted x" .. d.n, H.Money(d.total), 0.85, 0.7, 0.4, 1, 1, 1)
    end
    GameTooltip:Show()
  elseif d.kind == "pull" then
    pullTip(r, d)
  elseif d.kind == "session" then
    local s = d.s
    tip(r, {
      date("%A %d %B, %H:%M", s.start) .. " - " .. date("%H:%M", s.stop or s.start),
      { "Character", s.char or "?" },
      { "Time", H.Span(s.active) },
      { "Pulls", s.pulls and #s.pulls or "-" },
      { "Gold looted", H.Money(s.gold) },
      { "Items (" .. (s.count or 0) .. ")", H.Money(s.worth) },
      { "Total", H.Money((s.gold or 0) + (s.worth or 0)) },
      "Click to see the items and pulls. Right-click twice to delete.",
    })
  end
end

local function rowClick(r, button)
  local d = r.d
  if not d then return end
  if d.kind == "item" then
    if IsModifiedClick and IsModifiedClick("CHATLINK") and d.link then insertLink(d.link) end
  elseif d.kind == "session" then
    if button == "RightButton" then
      if UI.armed == d.s and time() - (UI.armedAt or 0) <= 4 then
        for i, s in ipairs(H.DB.history) do
          if s == d.s then table.remove(H.DB.history, i) break end
        end
        UI.armed = nil
      else
        UI.armed, UI.armedAt = d.s, time()
      end
      UI.Draw()
    else
      UI.sel = d.s
      UI.Show("detail")
    end
  end
end

local function newRow(parent, h)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(h)
  r.flash = r:CreateTexture(nil, "BACKGROUND")
  r.flash:SetAllPoints()
  r.flash:SetColorTexture(0.3, 0.9, 0.35, 0)
  r.hl = r:CreateTexture(nil, "HIGHLIGHT")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.07)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(h - 3, h - 3)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.right:SetPoint("RIGHT", -2, 0)
  r.right:SetJustifyH("RIGHT")
  r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.tag:SetPoint("RIGHT", r.right, "LEFT", -5, 0)
  r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.left:SetJustifyH("LEFT")
  if r.left.SetWordWrap then r.left:SetWordWrap(false) end
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:SetScript("OnEnter", rowEnter)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:SetScript("OnClick", rowClick)
  return r
end

local function listRow(i)
  if rows[i] then return rows[i] end
  local r = newRow(UI.list, ROW)
  r:SetPoint("TOPLEFT", UI.list, "TOPLEFT", 0, -(i - 1) * ROW)
  r:SetPoint("RIGHT", UI.list, "RIGHT", -6, 0)
  rows[i] = r
  return r
end

local function boxRow(i)
  if boxRows[i] then return boxRows[i] end
  local r = newRow(UI.box, BROW)
  r:SetPoint("TOPLEFT", UI.box, "TOPLEFT", 0, -BROW - (i - 1) * BROW)
  r:SetPoint("RIGHT", UI.box, "RIGHT", 0, 0)
  boxRows[i] = r
  return r
end

local function pullLeft(p, live)
  local fight = p.fight and ("|cffff8040fight|r " .. mmss(live and H.FightTime(p) or p.ft)) or "|cff999999no fight|r"
  return date("%H:%M", p.start) .. "   " .. fight
end

local function fillRow(r, d)
  r.d = d
  r.left:ClearAllPoints()
  r.left:SetPoint("RIGHT", r.tag, "LEFT", -5, 0)
  r.icon:ClearAllPoints()
  r.icon:SetPoint("LEFT", r, "LEFT", d.indent and 14 or 2, 0)
  r.flash:SetColorTexture(0.3, 0.9, 0.35, 0)
  r.left:SetTextColor(1, 1, 1)
  if d.kind == "day" or d.kind == "pull" then
    r.icon:Hide()
    r.left:SetPoint("LEFT", r, "LEFT", 2, 0)
    if d.kind == "day" then
      r.left:SetText(d.text)
      r.left:SetTextColor(1, 0.82, 0)
      r.tag:SetText(d.tag)
      r.right:SetText(d.right)
      r.flash:SetColorTexture(1, 1, 1, 0.06)
    else
      r.left:SetText(pullLeft(d.p, d.live))
      r.tag:SetText(d.count > 0 and plural(d.count, "item") or "")
      r.right:SetText(H.Money((d.p.gold or 0) + d.worth))
      r.flash:SetColorTexture(1, 1, 1, 0.04)
    end
    return
  end
  r.icon:Show()
  r.left:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
  if d.kind == "coins" then
    r.icon:SetTexture(COIN_ICON)
    r.left:SetText("Coins")
    r.left:SetTextColor(1, 0.82, 0)
    r.tag:SetText("")
    r.right:SetText(H.Money(d.total))
  elseif d.kind == "item" then
    local name, quality, icon = H.Info(d.id, d.link)
    r.icon:SetTexture(icon or 134400)
    r.left:SetText((name or "?") .. (d.n > 1 and ("|cffaaaaaa x" .. d.n .. "|r") or ""))
    r.left:SetTextColor(qualityColor(quality))
    if d.vkind == "ah" then r.tag:SetText("|cff7fb8e6AH|r") elseif d.vkind == "vendor" then r.tag:SetText("vendor") else r.tag:SetText("") end
    r.right:SetText(d.total > 0 and H.Money(d.total) or "|cff777777-|r")
    if d.at then
      local a = 1 - (time() - d.at) / 5
      if a > 0 then r.flash:SetColorTexture(0.3, 0.9, 0.35, 0.3 * a) end
    end
  else -- session
    local s = d.s
    local top = s.top and s.top[1]
    local _, _, icon = top and H.Info(top.id, top.link)
    r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Coin_17")
    r.left:SetText(date("%H:%M", s.start) .. "  |cffaaaaaa" .. H.Span(s.active) .. "|r  " .. classHex(s.class) .. (s.char or "?") .. "|r")
    if UI.armed == s and time() - (UI.armedAt or 0) <= 4 then
      r.tag:SetText("")
      r.right:SetText("|cffff5555right-click again to delete|r")
    else
      r.tag:SetText((s.active or 0) >= 60 and (H.Short(((s.gold or 0) + (s.worth or 0)) * 3600 / s.active) .. "/h") or "")
      r.right:SetText(H.Money((s.gold or 0) + (s.worth or 0)))
    end
  end
end

---------------------------------------------------------------------------
-- What the list shows
---------------------------------------------------------------------------
-- A live pull and its rows: header (+ coins + items, indented when indent).
local function livePull(p, out, indent, at)
  local items = H.PullItems(p)
  local worth, count = 0, 0
  for _, it in ipairs(items) do worth, count = worth + it.total, count + it.n end
  local head = { kind = "pull", p = p, live = true, worth = worth, count = count }
  if out then
    out[#out + 1] = head
    if (p.gold or 0) > 0 then out[#out + 1] = { kind = "coins", total = p.gold, indent = indent } end
    for _, it in ipairs(items) do
      out[#out + 1] = { kind = "item", id = it.id, link = it.link, n = it.n, total = it.total, vkind = it.kind, indent = indent,
        at = at and H.cur.items[it.key] and H.cur.items[it.key].at or nil }
    end
  end
  return head, items
end

local function buildNow()
  wipe(data)
  if H.db.list == "pulls" then
    local ps = H.cur.pulls or {}
    for i = #ps, 1, -1 do livePull(ps[i], data, true) end
    return
  end
  for _, it in ipairs(H.ItemList(H.cur, "value")) do
    data[#data + 1] = { kind = "item", id = it.id, link = it.link, n = it.n, total = it.total, vkind = it.kind, at = it.at }
  end
end

local function buildHistory()
  wipe(data)
  local day, head
  for _, s in ipairs(H.DB.history) do
    local d = date("%Y-%m-%d", s.start)
    if d ~= day then
      day = d
      head = { kind = "day", text = date("%A %d %B", s.start), sum = 0, n = 0 }
      data[#data + 1] = head
    end
    head.sum = head.sum + (s.gold or 0) + (s.worth or 0)
    head.n = head.n + 1
    head.right = H.Money(head.sum)
    head.tag = plural(head.n, "session")
    data[#data + 1] = { kind = "session", s = s }
  end
end

local function buildDetail()
  wipe(data)
  local s = UI.sel
  if not s then return end
  if H.db.list == "pulls" then
    for _, p in ipairs(s.pulls or {}) do
      local count = 0
      for _, it in ipairs(p.items) do count = count + it.n end
      data[#data + 1] = { kind = "pull", p = p, worth = p.worth or 0, count = count }
      if (p.gold or 0) > 0 then data[#data + 1] = { kind = "coins", total = p.gold, indent = true } end
      for _, it in ipairs(p.items) do
        data[#data + 1] = { kind = "item", frozen = true, indent = true, id = it.id, link = it.link, n = it.n, total = it.v or 0, vkind = it.kind }
      end
    end
    return
  end
  for _, it in ipairs(s.top or {}) do
    data[#data + 1] = { kind = "item", frozen = true, id = it.id, link = it.link, n = it.n, total = it.v or 0, vkind = it.kind }
  end
end

---------------------------------------------------------------------------
-- Summary (top block) and the pull box
---------------------------------------------------------------------------
local sum = {}

local function setSummary(t, paused)
  sum[1].value:SetText(H.Clock(t.active) .. (paused and "  |cffff8040paused|r" or ""))
  sum[2].value:SetText(H.Money(t.gold))
  sum[3].label:SetText("Items (" .. (t.count or 0) .. ")")
  sum[3].value:SetText(H.Money(t.worth))
  sum[4].value:SetText("|cffffd100" .. H.Money(t.total) .. "|r")
  sum[5].value:SetText(t.perHour and (H.Money(t.perHour) .. " |cffaaaaaaan hour|r") or "|cff777777after 1 minute|r")
  UI.lastTotals = t
end

local function updateSummary()
  if UI.view == "now" then
    setSummary(H.Totals(H.cur), H.cur.paused)
  elseif UI.view == "detail" and UI.sel then
    local s = UI.sel
    local total = (s.gold or 0) + (s.worth or 0)
    setSummary({ active = s.active or 0, gold = s.gold or 0, worth = s.worth or 0, count = s.count, total = total,
      vendor = s.vendor, ah = s.ah, perHour = (s.active or 0) >= 60 and total * 3600 / s.active or nil })
  end
end

-- Fills the "This pull / Last pull" box; returns its height.
local function drawBox()
  local p = H.LastPull()
  local hd = UI.boxHead
  local list = {}
  if not p then
    hd.left:SetText("|cffffd100Last pull|r")
    hd.tag:SetText("")
    hd.right:SetText(H.cur.paused and "|cff777777paused|r" or "|cff777777nothing yet|r")
    hd.d = nil
  else
    local head = livePull(p, list, false, true)
    table.remove(list, 1)
    local status
    if p.open and H.inCombat then status = "|cffff4040fighting|r"
    elseif p.open then status = "|cffffd100looting|r"
    else status = "|cff888888" .. ago(p.stop) .. "|r" end
    hd.left:SetText("|cffffd100" .. (p.open and "This pull" or "Last pull") .. "|r  " .. status)
    local tagText = p.fight and ("fight " .. mmss(H.FightTime(p))) or "no fight"
    if #list > BOX_ROWS then tagText = tagText .. "  +" .. (#list - BOX_ROWS + 1) .. " more" end
    hd.tag:SetText(tagText)
    hd.right:SetText(H.Money((p.gold or 0) + head.worth))
    hd.d = head
  end
  local shown = min(#list, BOX_ROWS)
  if #list > BOX_ROWS then shown = BOX_ROWS - 1 end
  for i = 1, max(shown, #boxRows) do
    local r = boxRow(i)
    if i <= shown then
      fillRow(r, list[i])
      r:Show()
      if GameTooltip:IsOwned(r) then rowEnter(r) end
    else
      r.d = nil
      r:Hide()
    end
  end
  if p and #list == 0 then
    UI.boxEmpty:SetText(p.open and "nothing looted yet" or "nothing looted")
    UI.boxEmpty:Show()
    return BROW * 2
  end
  UI.boxEmpty:Hide()
  return BROW * (1 + shown)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function layoutButtons(list)
  local x = -7
  for _, b in ipairs(UI.headButtons) do b:Hide() end
  for _, b in ipairs(list) do
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", x, -7)
    b:Show()
    x = x - b:GetWidth() - 3
  end
  UI.title:SetPoint("RIGHT", f, "TOPRIGHT", x - 4, -16)
end

-- (19 Nov) row2: a second row of buttons under the first (Check bag, Reset)
local function layoutFooter(list, row2)
  for _, b in ipairs(UI.footButtons) do b:Hide() end
  local up = (row2 and #row2 > 0) and 22 or 0
  local prev
  for _, b in ipairs(list) do
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) else b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 7, 7 + up) end
    b:Show()
    prev = b
  end
  local p2
  for _, b in ipairs(row2 or {}) do
    b:ClearAllPoints()
    if p2 then b:SetPoint("LEFT", p2, "RIGHT", 3, 0) else b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 7, 7) end
    b:Show()
    p2 = b
  end
  UI.footUp = up
  UI.foot:ClearAllPoints()
  if prev then UI.foot:SetPoint("LEFT", prev, "RIGHT", 6, 0) else UI.foot:SetPoint("LEFT", f, "BOTTOMLEFT", 10, 16 + up) end
  UI.foot:SetPoint("RIGHT", f, "BOTTOMRIGHT", -22, 16 + up)
end

function UI.Draw()
  if not f or not f:IsShown() then return end
  local v = UI.view
  local pulls = H.db.list == "pulls"
  local opts = v == "options"
  UI.opt:SetShown(opts)
  UI.list:SetShown(not opts)
  if opts then
    layoutButtons({ UI.closeB, UI.backB })
    UI.title:SetText("Haul  |cffaaaaaaSettings|r")
    for _, l in ipairs(sum) do l:Hide() end
    UI.box:Hide()
    UI.divider:Hide()
    UI.thumb:Hide()
    layoutFooter({})
    UI.foot:SetText("")
    UI.DrawOptions()
    return
  end
  if v == "now" then
    -- (19 Nov) stopped: Start; running: Pause and Stop; paused: Resume and Stop
    if H.Running() then layoutButtons({ UI.closeB, UI.optB, UI.histB, UI.stopB, UI.pauseB })
    else layoutButtons({ UI.closeB, UI.optB, UI.histB, UI.startB }) end
    local n = H.LootCount and H.LootCount() or 0
    UI.sortLootB.text:SetText(n > 0 and ("|cffffd100Sort loot|r " .. n) or "|cff888888Sort loot|r")
    UI.pauseB.text:SetText(H.cur.paused and "Resume" or "Pause")
    UI.title:SetText("Haul  " .. (not H.Running() and "|cff888888stopped|r" or H.cur.paused and "|cffff8040paused|r" or "|cff55dd55running|r"))
    buildNow()
  elseif v == "history" then
    layoutButtons({ UI.closeB, UI.backB })
    UI.title:SetText("Haul  |cffaaaaaaHistory|r")
    buildHistory()
  else
    layoutButtons({ UI.closeB, UI.backB })
    local s = UI.sel
    UI.title:SetText(s and ("|cffaaaaaa" .. date("%d %b %H:%M", s.start) .. "|r  " .. classHex(s.class) .. (s.char or "") .. "|r") or "")
    buildDetail()
  end

  local showSum = v ~= "history"
  for _, l in ipairs(sum) do l:SetShown(showSum) end
  if showSum then updateSummary() end
  local top = SUM_TOP
  if v == "now" then
    UI.box:Show()
    local bh = drawBox()
    UI.box:SetHeight(bh)
    top = SUM_TOP - 5 * LINE - 6 - bh - 8
  else
    UI.box:Hide()
    if showSum then top = SUM_TOP - 5 * LINE - 8 end
  end
  UI.divider:SetShown(showSum)
  UI.list:ClearAllPoints()
  UI.list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, top)
  UI.list:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, v == "now" and 52 or 30) -- (19 Nov: "now" has a second row of buttons)
  UI.divider:ClearAllPoints()
  UI.divider:SetPoint("BOTTOMLEFT", UI.list, "TOPLEFT", 0, 4)
  UI.divider:SetPoint("BOTTOMRIGHT", UI.list, "TOPRIGHT", 0, 4)

  UI.valueB.text:SetText(({ best = "Value: best", ah = "Value: auction", vendor = "Value: vendor" })[H.db.valueBy] or "Value: best")
  UI.listB.text:SetText(pulls and "By pulls" or "By value")
  if v == "now" then
    layoutFooter({ UI.valueB, UI.listB, UI.sortLootB }, { UI.checkB, UI.resetB })
    UI.foot:SetText(pulls and plural(#(H.cur.pulls or {}), "pull") or "")
  elseif v == "detail" then
    layoutFooter({ UI.listB })
    local s = UI.sel
    if pulls then
      UI.foot:SetText(s and s.pulls and plural(#s.pulls, "pull") or "")
    else
      UI.foot:SetText("most valuable items")
    end
  else
    layoutFooter({})
    UI.foot:SetText(plural(#H.DB.history, "saved session"))
  end

  local visible = max(1, floor((UI.list:GetHeight() or 0) / ROW))
  UI.offset = max(0, min(UI.offset, #data - visible))
  for i = 1, max(visible, #rows) do
    local r = listRow(i)
    local d = i <= visible and data[i + UI.offset]
    if d then
      fillRow(r, d)
      r:Show()
      if GameTooltip:IsOwned(r) then rowEnter(r) end
    else
      r.d = nil
      r:Hide()
    end
  end

  if #data > visible then
    local h = UI.list:GetHeight()
    local th = max(12, h * visible / #data)
    UI.thumb:SetHeight(th)
    UI.thumb:ClearAllPoints()
    UI.thumb:SetPoint("TOPRIGHT", UI.list, "TOPRIGHT", 0, -(h - th) * UI.offset / (#data - visible))
    UI.thumb:Show()
  else
    UI.thumb:Hide()
  end

  if #data == 0 then
    local text
    if v == "now" then
      text = not H.Running() and "Press Start to count your loot." or H.cur.paused and "Paused. Press Resume to count loot again." or "Nothing looted yet. Go kill something."
    elseif v == "history" then
      text = "No saved runs yet.\nPress Stop to save the one you're on."
    elseif pulls then
      text = UI.sel and UI.sel.pulls and "No pulls in this session." or "This session was saved before pulls were counted."
    else
      text = "No items in this session."
    end
    UI.empty:SetText(text)
    UI.empty:Show()
  else
    UI.empty:Hide()
  end
end

local pending
function UI.Refresh(soft)
  if not f or not f:IsShown() then return end
  if soft then
    if pending then return end
    pending = true
    C_Timer.After(0.3, function() pending = nil; UI.Draw() end)
  else
    UI.Draw()
  end
end

function UI.Tick()
  if f and f:IsShown() then UI.Draw() end
end

function UI.Show(view)
  if view then
    if view ~= UI.view then UI.offset = 0 end
    UI.view = view
  end
  H.db.shown = true
  f:Show()
  UI.Draw()
end

function UI.Toggle()
  if f:IsShown() then
    f:Hide()
    H.db.shown = false
  else
    UI.Show()
  end
end

---------------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------------
local function savePos()
  local p, _, rp, x, y = f:GetPoint()
  H.db.pos = { p, rp, x, y }
  H.db.w, H.db.h = floor(f:GetWidth() + 0.5), floor(f:GetHeight() + 0.5)
end

function UI.Init()
  if f then return end
  f = CreateFrame("Frame", "RucksackHaulFrame", UIParent, TMPL)
  f.isMain = true
  styled[#styled + 1] = f
  f:SetSize(max(300, H.db.w or 310), H.db.h or 470)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(300, 300, 700, 1000) elseif f.SetMinResize then f:SetMinResize(300, 300) end
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not H.db.locked then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePos() end)
  local pos = H.db.pos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", UIParent, "CENTER", 350, 0) end

  UI.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  UI.title:SetPoint("LEFT", f, "TOPLEFT", 11, -16)
  UI.title:SetJustifyH("LEFT")
  if UI.title.SetWordWrap then UI.title:SetWordWrap(false) end

  UI.closeB = Button("x", 18, function() UI.Toggle() end)
  UI.startB = Button("|cff55dd55Start|r", 48, function() H.Start() end,
    { "Start", "Starts a run: your loot and coins count from now, and Haul notes which stacks in your bag are your loot (for Sort loot)." })
  UI.sortLootB = Button("Sort loot", 70, function() if H.SortLoot then H.SortLoot() end end,
    { "Sort loot", "Sorts what you picked up during your runs (only those pieces, never stacks you had before):", "a vendor pays more: \"Sell this stack\" (sold at the next vendor, never thrown away);", "worth more at the auction house: it stays in its own group in your bag;", "never touched: quest items, food, water and potions, your professions' materials, gear better than yours, rare or better, and items with no auction price yet." })
  UI.stopB = Button("Stop", 42, function() H.Stop() end,
    { "Stop", "Ends the run and saves it to History. Your loot not sorted yet stays noted: Sort loot still works after Stop." })
  UI.pauseB = Button("Pause", 52, function() H.SetPaused(not H.cur.paused) end,
    { "Pause", "Stops the clock and stops counting loot until you press Resume." })
  UI.histB = Button("History", 54, function() UI.Show("history") end,
    { "History", "Your saved runs, day by day." })
  UI.backB = Button("Back", 44, function() UI.Show(UI.view == "detail" and "history" or "now") end)
  UI.optB = Button("Settings", 58, function() UI.Show("options") end,
    { "Settings", "Where auction prices come from, how items are valued, the bag, the look." })
  UI.headButtons = { UI.closeB, UI.startB, UI.stopB, UI.pauseB, UI.histB, UI.optB, UI.backB }

  local labels = { "Time", "Gold looted", "Items", "Total", "Per hour" }
  local tips = {
    { "Time", "Counts while you're logged in and not paused." },
    { "Gold looted", "Coins picked up from loot." },
    function()
      local t = UI.lastTotals or {}
      return { "Items", { "Vendor value", H.Money(t.vendor) }, { "Auction value", H.Money(t.ah) },
        "Each item counts at the value picked at the bottom (best of the two by default). Grey, soulbound and quest items count at the vendor price." }
    end,
    { "Total", "Gold looted plus what the items are worth." },
    { "Per hour", "Total divided by the time above." },
  }
  for i, text in ipairs(labels) do
    local l = CreateFrame("Frame", nil, f)
    l:SetHeight(LINE)
    l:SetPoint("TOPLEFT", f, "TOPLEFT", 10, SUM_TOP - (i - 1) * LINE)
    l:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, SUM_TOP - (i - 1) * LINE)
    l.label = l:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l.label:SetPoint("LEFT")
    l.label:SetText(text)
    l.value = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.value:SetPoint("RIGHT")
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
      local t = tips[i]
      tip(self, type(t) == "function" and t() or t)
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    sum[i] = l
  end

  -- the pull box: this pull while it runs, else the last one
  UI.box = CreateFrame("Frame", nil, f)
  UI.box:SetPoint("TOPLEFT", f, "TOPLEFT", 8, SUM_TOP - 5 * LINE - 6)
  UI.box:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  UI.box:SetHeight(BROW)
  UI.boxLine = UI.box:CreateTexture(nil, "ARTWORK")
  UI.boxLine:SetHeight(1)
  UI.boxLine:SetColorTexture(1, 1, 1, 0.12)
  UI.boxLine:SetPoint("BOTTOMLEFT", UI.box, "TOPLEFT", 0, 2)
  UI.boxLine:SetPoint("BOTTOMRIGHT", UI.box, "TOPRIGHT", 0, 2)
  local hd = newRow(UI.box, BROW)
  hd:SetPoint("TOPLEFT", UI.box, "TOPLEFT", 0, 0)
  hd:SetPoint("RIGHT", UI.box, "RIGHT", 0, 0)
  hd.icon:Hide()
  hd.left:SetPoint("LEFT", hd, "LEFT", 2, 0)
  hd.left:SetPoint("RIGHT", hd.tag, "LEFT", -5, 0)
  hd:SetScript("OnEnter", function(self) if self.d then pullTip(self, self.d) end end)
  UI.boxHead = hd
  UI.boxEmpty = UI.box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  UI.boxEmpty:SetPoint("TOPLEFT", UI.box, "TOPLEFT", 14, -BROW - 2)

  UI.divider = f:CreateTexture(nil, "ARTWORK")
  UI.divider:SetHeight(1)
  UI.divider:SetColorTexture(1, 1, 1, 0.12)

  UI.list = CreateFrame("Frame", nil, f)
  UI.list:EnableMouseWheel(true)
  UI.list:SetScript("OnMouseWheel", function(_, delta)
    UI.offset = UI.offset - delta * 3
    UI.Draw()
  end)
  UI.thumb = UI.list:CreateTexture(nil, "OVERLAY")
  UI.thumb:SetWidth(3)
  UI.thumb:SetColorTexture(edgeColor())
  UI.empty = UI.list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  UI.empty:SetPoint("TOP", UI.list, "TOP", 0, -14)
  UI.empty:SetWidth(220)

  UI.valueB = Button("Value: best", 92, function(_, button)
    local order = { "best", "ah", "vendor" }
    local i = 1
    for k, v in ipairs(order) do if v == H.db.valueBy then i = k end end
    i = button == "RightButton" and (i + 1) % 3 + 1 or i % 3 + 1
    H.db.valueBy = order[i]
    H.ClearPrices()
    UI.Draw()
  end, function()
    local src = H.Sources()
    return { "Value", "best: the higher of the auction price and the vendor price.",
      "auction: the auction price (vendor price when there is none).", "vendor: what a vendor pays.",
      { "Auction prices from", #src > 0 and table.concat(src, ", ") or "none loaded" } }
  end)
  UI.listB = Button("By value", 70, function()
    H.db.list = H.db.list == "pulls" and "items" or "pulls"
    UI.offset = 0
    UI.Draw()
  end, { "View", "By value: everything looted together, one line per item, the most valuable first.", "By pulls: each fight with what it dropped, newest first, its items by value." })
  -- (19 Nov) he: "Have haul reset, also have a button to calculate if it is worth selling in AH or Vendor
  -- on him and mark items with coin"
  UI.checkB = Button("Check bag", 70, function() if H.CheckBag then H.CheckBag() end end,
    { "Check bag", "Reads the auction prices afresh and marks every item in your bags that a vendor pays more for than the auction house leaves you (after its cut) with a gold coin. Chat says how many and what they're worth.", "At a vendor, the button under your bag sells them." })
  UI.resetB = Button("Reset", 46, function() H.Reset() H.Print("reset: the run so far is saved in History, counting starts again from zero.") UI.Draw() end,
    { "Reset", "Starts the count again from zero: time, coins, items, pulls. What you had so far is saved in History. A run that's on keeps going." })
  UI.footButtons = { UI.valueB, UI.listB, UI.sortLootB, UI.checkB, UI.resetB }

  UI.foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  UI.foot:SetJustifyH("RIGHT")
  if UI.foot.SetWordWrap then UI.foot:SetWordWrap(false) end

  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", -4, 4)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() if not H.db.locked then f:StartSizing("BOTTOMRIGHT") end end)
  grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); savePos(); UI.Draw() end)
  f:SetScript("OnSizeChanged", function() UI.Draw() end)

  UI.BuildOptions()
  UI.Restyle()
  if H.db.shown then f:Show() else f:Hide() end
  UI.Draw()
end

---------------------------------------------------------------------------
-- Options page
---------------------------------------------------------------------------
local optRows = {}

local function checkBox(parent)
  local c = CreateFrame("Frame", nil, parent, TMPL)
  c:SetSize(14, 14)
  styled[#styled + 1] = c
  paint(c)
  c.mark = c:CreateTexture(nil, "OVERLAY")
  c.mark:SetPoint("CENTER", 1, 0)
  c.mark:SetSize(18, 18)
  c.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  return c
end

-- a clickable line: box, label, right text; get() says if it's ticked, click() changes it
local function optLine(parent, y, label, get, click, tipFn)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(18)
  r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
  r:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  r.hl = r:CreateTexture(nil, "HIGHLIGHT")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.07)
  r.box = checkBox(r)
  r.box:SetPoint("LEFT", 4, 0)
  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.label:SetPoint("LEFT", r.box, "RIGHT", 6, 0)
  r.label:SetText(label)
  r.right = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.right:SetPoint("RIGHT", -4, 0)
  r.get = get
  r:SetScript("OnClick", function() click() H.ClearPrices() UI.Draw() end)
  if tipFn then
    r:SetScript("OnEnter", function(self) tip(self, tipFn()) end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  optRows[#optRows + 1] = r
  return r
end

local function heading(parent, y, text)
  local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  h:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, y)
  h:SetText(text)
  return h
end

function UI.BuildOptions()
  local p = CreateFrame("Frame", nil, f)
  UI.opt = p
  p:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
  p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
  if p.SetClipsChildren then p:SetClipsChildren(true) end
  p:Hide()
  -- (19 Nov) the page scrolls with the mouse wheel: it got longer than the window (auction house costs)
  local outer = p
  p = CreateFrame("Frame", nil, outer)
  p:SetPoint("TOPLEFT", outer, "TOPLEFT", 0, 0)
  p:SetPoint("RIGHT", outer, "RIGHT", 0, 0)
  UI.optScroll = 0
  outer:EnableMouseWheel(true)
  outer:SetScript("OnMouseWheel", function(_, delta)
    local most = math.max(0, (p:GetHeight() or 0) - (outer:GetHeight() or 0))
    UI.optScroll = math.min(most, math.max(0, UI.optScroll - delta * 36))
    p:SetPoint("TOPLEFT", outer, "TOPLEFT", 0, UI.optScroll)
  end)
  local y = 0
  heading(p, y, "Auction prices from")
  y = y - 14
  local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", p, "TOPLEFT", 2, y)
  hint:SetPoint("RIGHT", p, "RIGHT", -2, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText("Tick the ones to use. When several have a price for an item, the newest one counts.")
  y = y - 28
  for _, s in ipairs(H.SOURCES) do
    local r = optLine(p, y, s.name, function() return H.SourceOn(s.key) end,
      function() H.SetSourceOn(s.key, not H.SourceOn(s.key)) end,
      function()
        local okH, has = pcall(s.Has)
        local lines = { s.name, "Prices from " .. s.note .. "." }
        if not (okH and has) then lines[#lines + 1] = "Not installed or not loaded. Install it, then restart the game." end
        if s.credit then lines[#lines + 1] = s.credit end
        return lines
      end)
    r.src = s
    y = y - 18
  end
  UI.credit = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  UI.credit:SetPoint("TOPLEFT", p, "TOPLEFT", 24, y - 2)
  UI.credit:SetText(H.SOURCE_BY.ahledger.credit)
  y = y - 22

  heading(p, y, "Value items at")
  y = y - 16
  for _, o in ipairs({ { "best", "The higher of auction and vendor price" }, { "ah", "Auction price (vendor when there is none)" }, { "vendor", "Vendor price" } }) do
    optLine(p, y, o[2], function() return H.db.valueBy == o[1] end, function() H.db.valueBy = o[1] end)
    y = y - 18
  end
  y = y - 6

  heading(p, y, "Look")
  y = y - 18
  local bl = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bl:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 3)
  bl:SetText("Border")
  UI.edgeB = {}
  local x = 80
  for _, e in ipairs({ { "grey", "Grey" }, { "bronze", "Bronze" }, { "black", "Black" } }) do
    local b = Button(e[2], 54, function() H.db.edge = e[1] UI.Restyle() UI.Draw() end)
    b:SetParent(p)
    b:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
    b.key = e[1]
    UI.edgeB[#UI.edgeB + 1] = b
    x = x + 57
  end
  y = y - 22
  local al = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  al:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 3)
  al:SetText("Background")
  local minus = Button("-", 22, function() H.db.alpha = max(0, (H.db.alpha or 0.7) - 0.1) UI.Restyle() UI.Draw() end)
  minus:SetParent(p)
  minus:SetPoint("TOPLEFT", p, "TOPLEFT", 80, y)
  UI.alphaText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  UI.alphaText:SetPoint("LEFT", minus, "RIGHT", 6, 0)
  UI.alphaText:SetWidth(40)
  local plus = Button("+", 22, function() H.db.alpha = min(1, (H.db.alpha or 0.7) + 0.1) UI.Restyle() UI.Draw() end)
  plus:SetParent(p)
  plus:SetPoint("LEFT", UI.alphaText, "RIGHT", 6, 0)
  y = y - 28

  heading(p, y, "Bag")
  y = y - 16
  optLine(p, y, "Keep track of your loot in the bag (for Sort loot)", function() return H.db.bag end, function() H.db.bag = not H.db.bag if H.Changed then H.Changed() end end,
    function() return { "Haul in your bag", "While a run is on, Haul notes which stacks in your bag are your loot: only the pieces you picked up (loot that lands on a stack you had is split off into its own slot, out of a fight). Then Sort loot puts what a vendor pays more for (after the auction house's cut and deposit) on Sell (that stack only); what's worth more at the auction house stays in its own group.",
      "Never moved or sold: quest items, food, water and potions, gear better than yours, rare or better, what Rucksack keeps (Restock, armour sets, your professions' materials...), and items with no auction price known." } end)
  optLine(p, y - 18, "Sort loot as it comes in (while a run is on)", function() return H.db.autoSort ~= false end, function() H.db.autoSort = H.db.autoSort == false end,
    function() return { "Sort loot as it comes in", "While a run is on, each stack you loot is sorted by itself a second or so after it lands: a vendor pays more -> Sell (that stack only, never thrown away); worth more at the auction house -> it stays in its own group. The same rules as the Sort loot button." } end)
  optLine(p, y - 36, "Mark items a vendor pays more for (gold coin)", function() return H.db.vendorMark ~= false end,
    function() H.db.vendorMark = H.db.vendorMark == false if ns.Changed then ns.Changed() end end,
    function() return { "Worth more at a vendor", "Any item in your bags that a vendor pays more for than the auction house leaves you (after its cut and the deposit) gets a small gold coin at its top left. Its tooltip shows the sums. At a vendor, a button under the bag sells all of them.",
      "Never marked: soulbound items, quest items, food, water and potions, gear better than yours, rare or better, what Rucksack keeps, and items with no auction price known." } end)
  y = y - 60

  -- (19 Nov) what posting costs, for Sort loot and the gold coin
  heading(p, y, "Auction house costs")
  y = y - 18
  local function row(label, opts, key)
    local l = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 3)
    l:SetText(label)
    local x = 80
    for _, o in ipairs(opts) do
      local b = Button(o[2], o[3], function() H.db[key] = o[1] H.ClearPrices() if ns.Changed then ns.Changed() end UI.Draw() end, o[4])
      b:SetParent(p)
      b:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
      b.key, b.dbKey = o[1], key
      UI.costB[#UI.costB + 1] = b
      x = x + o[3] + 3
    end
    y = y - 22
  end
  UI.costB = {}
  row("House", {
    { "faction", "Faction (5 %)", 84, { "Your faction's auction house", "Stormwind, Ironforge, Orgrimmar...: the house keeps 5 % of the sale. The deposit is 5 / 20 / 60 % of the vendor price (2 / 8 / 24 hours)." } },
    { "neutral", "Neutral (15 %)", 88, { "A neutral auction house", "Gadgetzan, Booty Bay, Everlook: the house keeps 15 % of the sale and the deposit is 5 times higher." } } }, "ahHouse")
  row("Length", {
    { 2, "2 h", 40, { "2 hours", "Deposit: 5 % of the vendor price (neutral: 25 %)." } },
    { 8, "8 h", 40, { "8 hours", "Deposit: 20 % of the vendor price (neutral: 100 %)." } },
    { 24, "24 h", 40, { "24 hours", "Deposit: 60 % of the vendor price (neutral: 300 %)." } } }, "ahHours")
  optLine(p, y, "Count the deposit as lost", function() return H.db.ahDepositLost end, function() H.db.ahDepositLost = not H.db.ahDepositLost if ns.Changed then ns.Changed() end end,
    function() return { "Count the deposit as lost", "Off (to start): the deposit comes back when the item sells, so only the house's cut is taken off the auction price.", "Ticked: the deposit is taken off too (at least 1 silver a listing), as if it doesn't sell the first time. Safer, but cheap items then nearly always go to the vendor. The length above only matters when this is ticked." } end)
  y = y - 20
  local note = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", p, "TOPLEFT", 2, y)
  note:SetPoint("RIGHT", p, "RIGHT", -2, 0)
  note:SetJustifyH("LEFT")
  note:SetText("Counted for Sort loot and the gold coin: the auction price minus the house's cut (and the deposit, when ticked).")
  y = y - 34

  heading(p, y, "Sessions")
  y = y - 16
  optLine(p, y, "New session after 2 hours logged out", function() return H.db.autoNew end, function() H.db.autoNew = not H.db.autoNew end,
    function() return { "New session after a break", "When you log in after 2 hours or more, the last session goes to History and a new one starts." } end)
  optLine(p, y - 18, "Lock the window", function() return H.db.locked end, function() H.db.locked = not H.db.locked end)
  p:SetHeight(-(y - 40))
end

function UI.DrawOptions()
  for _, r in ipairs(optRows) do
    local on = r.get() and true or false
    r.box.mark:SetShown(on)
    if r.src then
      local okH, has = pcall(r.src.Has)
      if not (okH and has) then
        r.label:SetTextColor(0.5, 0.5, 0.5)
        r.right:SetText("not installed")
      elseif on then
        r.label:SetTextColor(1, 1, 1)
        r.right:SetText("|cff55dd55in use|r")
      else
        r.label:SetTextColor(0.7, 0.7, 0.7)
        r.right:SetText("off")
      end
    end
  end
  local okA, hasA = pcall(H.SOURCE_BY.ahledger.Has)
  UI.credit:SetShown(okA and hasA and H.SourceOn("ahledger") or false)
  for _, b in ipairs(UI.costB or {}) do
    local cur = H.db[b.dbKey] or (b.dbKey == "ahHours" and 24 or "faction")
    if b.key == cur then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(1, 1, 1) end
  end
  for _, b in ipairs(UI.edgeB) do
    if b.key == H.db.edge then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(1, 1, 1) end
  end
  UI.alphaText:SetText(floor((H.db.alpha or 0.7) * 100 + 0.5) .. " %")
end
