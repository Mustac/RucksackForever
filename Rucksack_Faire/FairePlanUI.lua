-- Rucksack / Darkmoon Faire: the Plan tab (15 Nov).
-- Left: pick the prize, tick the turn-ins you want to use and how many times. Right: what that takes
-- and what you still have to get. The prize card on your screen shows the same as a table.
local RS = Rucksack
if not RS or not RS.Faire or not RS.Faire.UI then return end
local ns = RS.Faire
local D = ns.D
local U = ns.UI
local text, tip, button = U.text, U.tip, U.button
local GOLD, GREY, GREEN, RED = U.GOLD, U.GREY, U.GREEN, U.RED
local P = U.pages.plan
local LIST_W = 372

local function changed()
  if ns.Refresh then ns.Refresh() end
  if ns.PaintScreenButton then ns.PaintScreenButton() end
end

---------------------------------------------------------------------------
-- Top: the prize (the same one the Prizes tab tracks), the total, the buttons
---------------------------------------------------------------------------
local function stepPrize(dir)
  local list, at = D.PRIZES, 0
  for i, p in ipairs(list) do if p.name == ns.char.goal then at = i end end
  at = at + dir
  if at > #list then at = 0 elseif at < 0 then at = #list end -- (0 = no prize)
  ns.char.goal = list[at] and list[at].name or nil
  ns.char.goalReached = nil
  if ns.PaintScreenButton then ns.PaintScreenButton() end
  RS.Changed()
  changed()
end
local prev = button(P, "<", 22, function() stepPrize(-1) end)
prev:SetPoint("TOPLEFT", 0, 2)
local nextB = button(P, ">", 22, function() stepPrize(1) end)
nextB:SetPoint("LEFT", prev, "RIGHT", 2, 0)
tip(prev, { "The prize you're saving for", "Click to go through the prizes. The Prizes tab tracks the same one." })
tip(nextB, { "The prize you're saving for", "Click to go through the prizes. The Prizes tab tracks the same one." })
local prizeIcon = P:CreateTexture(nil, "ARTWORK")
prizeIcon:SetSize(18, 18)
prizeIcon:SetPoint("LEFT", nextB, "RIGHT", 8, 0)
prizeIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local prizeText = P:CreateFontString(nil, "OVERLAY", "GameFontNormal")
prizeText:SetPoint("LEFT", prizeIcon, "RIGHT", 6, 0)

local autoBtn = button(P, "Count for me", 100, function() ns.PlanAuto() changed() end)
autoBtn:SetPoint("TOPRIGHT", 0, 2)
tip(autoBtn, { "Count for me", "Forgets the numbers you set with - and +, and works out the hand-ins itself: the ones that give the most tickets first." })

---------------------------------------------------------------------------
-- Left: the turn-ins. Tick, then - and + for how many times.
---------------------------------------------------------------------------
-- (the page is about 458 high: 21 turn-ins and 4 names have to fit, like on the Turn-ins tab)
local LIST_Y = -24
local hBring = text(P, "GameFontDisableSmall", 40, LIST_Y)
hBring:SetText("Hand in")
local hTk = text(P, "GameFontDisableSmall", 222, LIST_Y)
hTk:SetText("Tickets")
local hLeft = text(P, "GameFontDisableSmall", 270, LIST_Y)
hLeft:SetText("Left")
local hTimes = text(P, "GameFontDisableSmall", 316, LIST_Y)
hTimes:SetText("Times")

local rows, heads = {}, {}
local function small(parent, label, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(14, 14)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.25, 0.2, 0.32, 1)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", 0, 0)
  b.text:SetText(label)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.2)
  b._label = label
  b:SetScript("OnClick", onClick)
  return b
end
local function makeRow(i)
  local r = CreateFrame("Button", nil, P)
  r:SetSize(LIST_W, 16)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.07)
  -- click the item: the Turn-ins tab opens on it (where it comes from, farm spots, map pins)
  r:SetScript("OnClick", function(self) if self.t and ns.ShowTurnin then ns.ShowTurnin(self.t) end end)
  r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  r.check:SetSize(18, 18)
  r.check:SetPoint("LEFT", 0, 0)
  r.check:SetScript("OnClick", function(self)
    local row = self:GetParent()
    if row.t then ns.PlanPick(row.t.q, self:GetChecked() and true or false) changed() end
  end)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(14, 14)
  r.icon:SetPoint("LEFT", 22, 0)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.name:SetPoint("LEFT", 40, 0)
  r.name:SetWidth(180)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.tk = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.tk:SetPoint("LEFT", 226, 0)
  r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.left:SetPoint("LEFT", 270, 0)
  r.minus = small(r, "-", function(self)
    local row = self:GetParent()
    if row.t and row.shown then ns.PlanSetTimes(row.t.q, math.max(0, row.shown - 1)) changed() end
  end)
  r.minus:SetPoint("LEFT", 308, 0)
  r.n = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.n:SetPoint("LEFT", 324, 0)
  r.n:SetWidth(24)
  r.n:SetJustifyH("CENTER")
  r.plus = small(r, "+", function(self)
    local row = self:GetParent()
    if row.t and row.shown then ns.PlanSetTimes(row.t.q, row.shown + 1) changed() end
  end)
  r.plus:SetPoint("LEFT", 350, 0)
  tip(r, function(self)
    local t, c = self.t, self.calc
    if not t or not c then return {} end
    local l = { ns.ItemName(c.st.item) .. " x" .. c.st.n,
      ("%s: \"%s\", %d ticket%s a hand-in."):format(t.npc, t.title, c.tickets, c.tickets == 1 and "" or "s") }
    if c.st.state == "level" then l[#l + 1] = "Opens at level " .. t.lv .. "."
    elseif c.why == "npc" and c.left == 0 then l[#l + 1] = t.npc .. " didn't offer it when you last spoke today: you've hit its limit. It's checked again every time you talk."
    elseif c.left == 0 then l[#l + 1] = "Closed: your Faire reputation is past it."
    elseif c.left then l[#l + 1] = ("About %d more hand-in%s before your reputation closes it (%d reputation each%s). Every hand-in counts, so do the cheap ones first."):format(
      c.left, c.left == 1 and "" or "s", ns.RepPer(), ns.db.repPer and "" or ", not measured yet")
    else l[#l + 1] = "No limit: it stays open." end
    if c.done > 0 then l[#l + 1] = ("Handed in today: %d."):format(c.done) end
    local rec = D.CRAFTED[c.st.item] and ns.Recipe(c.st.item)
    if rec then
      local m = {}
      for _, x in ipairs(rec.mats) do m[#m + 1] = x.n .. " " .. x.name end
      l[#l + 1] = D.CRAFTED[c.st.item] .. ": " .. table.concat(m, ", ") .. ((rec.makes or 1) > 1 and (" (makes " .. rec.makes .. ")") or "") .. "."
      l[#l + 1] = rec.seen and ("Read from " .. (rec.by or "your") .. "'s profession window.") or "From the recipe list. Open the profession window once and Rucksack uses what it shows."
    end
    l[#l + 1] = "|cff99d9ffClick: where to get it (who makes it, or where it drops, with map pins).|r"
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

---------------------------------------------------------------------------
-- Right: what it takes
---------------------------------------------------------------------------
local R = CreateFrame("Frame", nil, P)
R:SetPoint("TOPLEFT", LIST_W + 14, LIST_Y)
R:SetPoint("BOTTOMRIGHT")
local rbg = R:CreateTexture(nil, "BACKGROUND")
rbg:SetAllPoints()
rbg:SetColorTexture(0.09, 0.07, 0.12, 0.6)
-- the total and a hint on top, then the list; each sits under the one before, however many lines it takes
local sumText = text(R, "GameFontHighlight", 8, -8, 250)
local function under(prev, font, gap)
  local s = R:CreateFontString(nil, "OVERLAY", font)
  s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -(gap or 6))
  s:SetWidth(250)
  s:SetJustifyH("LEFT")
  s:SetWordWrap(true)
  return s
end
local hintText = under(sumText, "GameFontHighlightSmall", 6)
local needHead = under(hintText, "GameFontNormal", 12)
needHead:SetText("What you need")
local needText = under(needHead, "GameFontHighlightSmall", 6)
local needFoot = R:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
needFoot:SetPoint("BOTTOMLEFT", 8, 8)
needFoot:SetWidth(250)
needFoot:SetJustifyH("LEFT")
needFoot:SetWordWrap(true)

function ns.DrawPlan()
  local c = ns.PlanCalc()
  local byQ = {}
  for _, r in ipairs(c.rows) do byQ[r.t.q] = r end
  -- top
  if c.goal then
    prizeIcon:SetTexture(ns.PrizeIcon(c.goal))
    prizeText:SetText(GOLD .. c.goal.name .. "|r  " .. GREY .. c.goal.cost .. " tickets|r")
  else
    prizeIcon:SetTexture(ns.TicketIcon())
    prizeText:SetText(GREY .. "No prize picked: just counting tickets|r")
  end
  sumText:SetText(ns.PlanSum(c))
  local hint
  if not c.any then
    if c.goal and c.need == 0 then hint = GREEN .. "You have enough tickets for it already. Go see Gelvas Grimegate.|r"
    else hint = GREY .. "Tick what you want to hand in. Rucksack works out how many times.|r" end
  elseif c.goal and c.short > 0 then
    hint = "|cffffb040Not enough yet: tick another one, or raise a number with +.|r"
  elseif c.mixed then
    hint = GREY .. "Hand in the cheap ones first: every hand-in raises your reputation, and that closes them.|r"
  else
    hint = GREY .. "- and + set a number yourself. \"Count for me\" works them out again.|r"
  end
  hintText:SetText(hint)
  -- the list
  local y, ri, hi = LIST_Y - 16, 0, 0
  for _, g in ipairs(D.TURNINS) do
    hi = hi + 1
    local h = heads[hi] or makeHead(hi)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 2, y - 1)
    h:SetText(g.npc .. "  " .. GREY .. g.what .. "|r")
    h:Show()
    y = y - 16
    for _, t in ipairs(g.list) do
      ri = ri + 1
      local r = rows[ri] or makeRow(ri)
      local e = byQ[t.q]
      r.t, r.calc = t, e
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, y)
      r.icon:SetTexture(ns.ItemIcon(e.st.item))
      r.icon:SetDesaturated(not e.open)
      r.name:SetText((e.open and "" or GREY) .. ns.ItemName(e.st.item) .. " x" .. e.st.n .. (e.open and "" or "|r"))
      r.tk:SetText((e.open and GOLD or GREY) .. e.tickets .. "|r")
      if e.st.state == "level" then r.left:SetText(GREY .. "lvl " .. t.lv .. "|r")
      elseif not e.open then r.left:SetText(GREY .. "closed|r")
      elseif e.left then r.left:SetText((e.left <= 2 and "|cffffb040" or "") .. e.left .. (e.left <= 2 and "|r" or ""))
      else r.left:SetText(GREY .. "any|r") end
      r.check:SetChecked(e.picked)
      r.check:SetShown(e.open)
      r.shown = e.picked and e.times or nil
      r.minus:SetShown(e.picked)
      r.plus:SetShown(e.picked)
      r.n:SetText(e.picked and ((e.manual and "|cffffffff" or GREEN) .. e.times .. "|r") or "")
      r:Show()
      y = y - 16
    end
    y = y - 2
  end
  for i = ri + 1, #rows do rows[i]:Hide() end
  for i = hi + 1, #heads do heads[i]:Hide() end
  -- the right side
  local lines = ns.PlanLines(c)
  if #lines > 22 then lines = ns.PlanLines(c, true) end -- (a long list: the short form, so it fits)
  if #lines == 0 then lines[1] = GREY .. "Nothing ticked yet.|r" end
  needText:SetText(table.concat(lines, "\n"))
  needFoot:SetText("White: still to get. Green: you have it (bags and bank). Materials are one step deep: bars, not ore.\nTick \"Show button\" at the top and this list stays on your screen.")
end

-- (15 Nov, later) no tracker of its own any more: the prize card on your screen ("Show button", top
-- of the page) shows the plan as a table under the prize (FaireUI.lua). Whoever had the old tracker
-- on gets the card.
table.insert(ns.onLogin, function()
  local plan = ns.char and ns.char.plan
  if plan and plan.tracker then
    plan.tracker, plan.pos = nil, nil
    ns.db.screenButton = true
    if ns.UpdateScreenButton then ns.UpdateScreenButton() end
  end
end)
