-- Rucksack / Bags: the column on the right of the bag (15 Nov)
-- Three boxes, one under the other. Each shows the items in your bags that belong to it (your
-- bags' own buttons, so they work as always) and takes an item you drop on it:
--   Always sell / delete : every one of that item, also later (Clean-up's list, and what its rules pick)
--   Sell / delete once   : only the stack you dropped (a mark on that bag slot)
--   Send to bank         : only the stacks you put there, moved into your bank by itself when you open
--                          the bank; never sold or thrown away. Alt + left-click an item in the bag sends
--                          that stack; Alt + right-click takes it back (marks on bag slots, per character)
-- Under the first box's name (1.9): "Delete only items worth up to", the delete limit (10s to 5g in
-- 10s steps, the same setting as on the Clean-up page): worth more, it's only sold, never thrown
-- away by itself. Every box and the slider have a "?" that says what it does.
-- The first two boxes and the slider need Clean-up; without it only the bank box shows.
-- Each is its own small bag window: a name, the items, and while you hold an item one empty slot
-- at the end to drop it on (like the slot every group in the bag gets then).
-- These boxes replace the Junk and Sell groups in the bag. "Only sell" is gone: items still on that
-- list from before stay as they were (sold, never thrown away) and show in the first box.
local ns = Rucksack
if not ns or not ns.Bags or not ns.Bags.MAIN then return end
local B = ns.Bags
local Print = ns.Print
local f = B.MAIN.frame

local CELL, GAP = 37, 3
local PITCH = CELL + GAP
local COLS = 4
local W = COLS * PITCH - GAP
local PAD, HDR, BOXGAP = 8, 12, 4 -- (HDR: a group's name, as high as in the bag; BOXGAP: between the windows)
local SLIDER_H = 36
local TAN = { 0.85, 0.78, 0.6 }

local function DB() return B.db end
local function hasClean() return ns.Has("del") and ns.Del and ns.del and ns.Del.JunkKind and ns.Sell and true or false end
local function shown(id, link) return link or ns.NameOf(id) or "That item" end
local function money(c) return ns.Sell and ns.Sell.Money and ns.Sell.Money(c) or tostring(c) end

---------------------------------------------------------------------------
-- What goes where
---------------------------------------------------------------------------
function B.SideOn() return DB() and true or false end
-- (15 Nov) Send to bank goes stack by stack: a mark on the bag slot, this character's
-- (RucksackCharDB.bankSlots["bag:slot"] = item id). A mark is good while that slot holds that item.
local function slotKey(bag, slot) return bag .. ":" .. slot end
local function bankMarks()
  if not ns.char then return nil end
  ns.char.bankSlots = ns.char.bankSlots or {}
  return ns.char.bankSlots
end
function B.BankSlot(bag, slot, id)
  local m = ns.char and ns.char.bankSlots
  if not m or not bag or not slot then return false end
  local want = m[slotKey(bag, slot)]
  if not want then return false end
  if id == nil then id = ns.SlotInfo(bag, slot) end
  if want ~= id then m[slotKey(bag, slot)] = nil return false end
  return true
end
function B.MarkBank(bag, slot, id) local m = bankMarks() if m and bag and slot then m[slotKey(bag, slot)] = id end end
function B.UnmarkBank(bag, slot) local m = ns.char and ns.char.bankSlots if m and bag and slot then m[slotKey(bag, slot)] = nil end end
local function anyBank()
  local m = ns.char and ns.char.bankSlots
  return m and next(m) ~= nil
end
-- the stack on your cursor: the game locks its slot while you hold it
function B.HeldSlot(id)
  if not id then return nil end
  for bag in pairs(B.IS_BAG) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local it = C_Container.GetContainerItemInfo(bag, slot)
      if it and it.itemID == id and it.isLocked then return bag, slot end
    end
  end
end
-- (the first try, earlier the same day, sent every one of an item: those become marks on the
-- stacks in your bags now, once)
local function oldBankList()
  local db = DB()
  if not db or type(db.bank) ~= "table" or not next(db.bank) then return end
  for bag in pairs(B.IS_BAG) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local it = C_Container.GetContainerItemInfo(bag, slot)
      if it and it.itemID and db.bank[it.itemID] then B.MarkBank(bag, slot, it.itemID) end
    end
  end
  db.bank = nil
end
-- marks whose slot holds something else now are dropped
local sweep = CreateFrame("Frame")
pcall(sweep.RegisterEvent, sweep, "BAG_UPDATE_DELAYED")
sweep:SetScript("OnEvent", function()
  local m = ns.char and ns.char.bankSlots
  if not m then return end
  for k, want in pairs(m) do
    local bag, slot = k:match("^(-?%d+):(%d+)$")
    if not bag or ns.SlotInfo(tonumber(bag), tonumber(slot)) ~= want then m[k] = nil end
  end
end)
-- (1.9) the quiver window: only while you wear a quiver or ammo pouch, and "Quiver beside the bag" is on
function B.QuiverShown()
  local db = DB()
  if not db or db.showQuiver == false or not B.QuiverBag then return nil end
  return (B.QuiverBag())
end
-- the box an item in your bags shows in ("always", "once", "bank", "quiver"), or nil: it stays in the bag
function B.SideOf(e)
  local db = DB()
  if not db or not e or not e.id or e.empty then return nil end
  local q = B.QuiverShown()
  if q and e.bag == q then return "quiver" end
  if B.BankSlot(e.bag, e.slot, e.id) then return "bank" end
  if not hasClean() then return nil end
  if e.cat == "junk" then
    if ns.Del.SlotJunk and ns.Del.SlotJunk(e.bag, e.slot, e.id) then return "once" end
    if ns.HaulSell and ns.HaulSell(e.id, e.bag, e.slot) and not (ns.del.items and ns.del.items[e.id]) then return "haul" end -- (19 Nov)
    return "always"
  elseif e.cat == "sell" then -- ("only sell" from before 15 Nov)
    return (not ns.del.sell[e.id]) and ns.Del.SlotSell and ns.Del.SlotSell(e.bag, e.slot, e.id) and "once" or "always"
  end
  return nil
end
-- an item's extra tooltip lines when it sits in a box
function B.SideTip(e)
  local out = {}
  if e.side == "bank" then
    out[1] = "|cff7fd4ffSend to bank:|r this stack goes in your bank when you open it."
    out[2] = "|cff999999Alt + right-click: back in your bag.|r"
    return out
  elseif e.cat == "sell" then
    out[1] = "|cffffd100Only sold|r at a vendor, never thrown away (from before the boxes)."
  else
    local why = ns.Del.Reason and ns.Del.Reason(e.id)
    out[1] = (e.side == "once" and "|cffff8a8aSell / delete once|r: only this stack." or ("|cffff8a8aAlways sell / delete|r" .. (why and (": " .. why) or ""))) ..
      (e.first and "  |cffffd100first to go|r" or "")
  end
  local whyNot = ns.Sell.WhyNot and ns.Sell.WhyNot(e.id, e.link, e.bag, e.slot)
  if whyNot then out[#out + 1] = "|cffffd100Not sold:|r " .. whyNot end
  out[#out + 1] = "|cff999999Alt + right-click: back in your bag. (Or pick it up and drop it on the green slot in its box.)|r"
  return out
end
-- (Clean-up never sells or throws away a stack on its way to the bank: it asks B.BankSlot)

---------------------------------------------------------------------------
-- The column
---------------------------------------------------------------------------
-- (the column holds the three windows; it has no frame of its own)
local sf = CreateFrame("Frame", "RucksackBagsSide", f)
sf:SetPoint("TOPLEFT", f, "TOPRIGHT", 3, 0)
sf:SetSize(W + PAD * 2, 200)
local function window()
  local w = CreateFrame("Frame", nil, sf, ns.BACKDROP_TMPL)
  w:EnableMouse(true)
  if w.SetBackdrop then
    w:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    w:SetBackdropColor(0.04, 0.035, 0.03, 0.95)
    w:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
  end
  return w
end
local sbody = CreateFrame("Frame", nil, sf)
sbody:SetPoint("TOPLEFT", PAD, -PAD)
sbody:SetSize(W, 10)
local SIDE = { body = sbody, labels = {}, hints = {}, ghosts = {}, ghostN = 0, frame = sf, static = true }
B.SIDE = SIDE

local BOXES = {
  { key = "always", name = "Always sell / delete", color = { 1, 0.54, 0.54 }, clean = true,
    tip = { "Every one of these items, also the ones you get later.",
      "A vendor buys them when you visit one. If your bags fill up first, the cheapest is thrown away.",
      "Grey items and gear you can't use land here by themselves.",
      "The ticks next to the name: sell = a vendor buys them, delete = the cheapest is thrown away when your bags fill up. Untick one and Rucksack doesn't do that." } },
  { key = "once", name = "Sell / delete once", color = { 1, 0.72, 0.45 }, clean = true,
    tip = { "Only the stacks you put here.",
      "A vendor buys them when you visit one. If your bags fill up first, the cheapest is thrown away.",
      "The next ones you get are left alone." } },
  -- (19 Nov: a "Haul" box was here for an evening; Haul's "Sort loot" now marks stacks "Sell this stack" instead)
  { key = "bank", name = "Send to bank", color = { 0.5, 0.83, 1 },
    tip = { "The stacks you put here go into your bank when you open it.",
      "Rucksack never sells them or throws them away.",
      "Alt + left-click an item in your bag: that stack goes here (at the bank: straight in). Alt + right-click it: back in your bag." } },
  { key = "quiver", name = "Quiver", color = { 0.72, 0.88, 0.5 }, quiver = true,
    tip = { "The quiver or ammo pouch you wear, slot by slot.",
      "Arrows and bullets in your other bags move in here by themselves when there's room (\"Sort into special bags\" on the Bags page).",
      "Drop ammo on this window to put it in." } },
}
local HOWTO = "Drop an item on the box to put it here. To take it out: Alt + right-click it, or pick it up and drop it on the green slot that shows up in the box."

local function tipOn(owner, title, lines, last)
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  GameTooltip:AddLine(title)
  for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
  if last then GameTooltip:AddLine(last, 0.7, 0.7, 0.7, true) end
  GameTooltip:Show()
end
local function qmark(parent, onEnter)
  local q = CreateFrame("Button", nil, parent)
  q:SetSize(15, 15)
  q.text = q:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  q.text:SetPoint("CENTER")
  q.text:SetText("|cffffd100?|r")
  q:SetScript("OnEnter", onEnter)
  q:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return q
end

local drop -- (below)
local boxes = {}
-- (the empty slots are the game's bag buttons: like the bag's own, they sit in a frame that carries a bag number)
local slotHome = CreateFrame("Frame", nil, sbody)
slotHome:SetAllPoints(sbody)
slotHome:SetID(0)
for i, def in ipairs(BOXES) do
  local box = CreateFrame("Button", "RucksackBagsSide_" .. def.key, sf)
  box.def, box.key = def, def.key
  box.win = window() -- (its own small bag window, behind it)
  box.win:SetFrameLevel(math.max(0, (sf:GetFrameLevel() or 1)))
  box:SetFrameLevel((box.win:GetFrameLevel() or 0) + 2)
  box.empty = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  box.empty:SetJustifyH("LEFT")
  box.empty:SetText("pick an item up and drop it here")
  -- (no frame of its own: it looks like a group in the bag. The whole area still takes a drop.)
  box.title = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  box.title:SetPoint("TOPLEFT", 1, 0)
  box.title:SetHeight(HDR)
  box.title:SetJustifyH("LEFT")
  box.title:SetAlpha(0.85)
  box.title:SetText(("|cff%02x%02x%02x%s|r"):format(math.floor(def.color[1] * 255), math.floor(def.color[2] * 255), math.floor(def.color[3] * 255), def.name))
  box.q = qmark(box, function(self) tipOn(self, def.name, def.tip, HOWTO) end)
  box.q:SetPoint("TOPRIGHT", 0, 2)
  box:RegisterForClicks("LeftButtonUp")
  box:SetScript("OnReceiveDrag", function(self) drop(self.key) end)
  box:SetScript("OnClick", function(self) drop(self.key) end)
  -- the empty slot at the end: one of the game's own bag buttons, so it looks like any empty slot.
  -- It belongs to no real slot (slot 0) and every click on it is ours: it only takes a drop.
  local name = "RucksackBagsSideSlot_" .. def.key
  local ok, slot = pcall(CreateFrame, "ItemButton", name, slotHome, "ContainerFrameItemButtonTemplate")
  if not ok or not slot then ok, slot = pcall(CreateFrame, "Button", name, slotHome, "ContainerFrameItemButtonTemplate") end
  if not ok or not slot then
    slot = CreateFrame("Button", name, slotHome, ns.BACKDROP_TMPL)
    if slot.SetBackdrop and ns.SLOT_BACKDROP then
      slot:SetBackdrop(ns.SLOT_BACKDROP)
      slot:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
      slot:SetBackdropBorderColor(0.4, 0.36, 0.28)
    end
    slot.plain = true
  end
  if slot.SetID then slot:SetID(0) end
  slot:SetSize(CELL, CELL)
  slot.key = def.key
  for _, h in ipairs({ "OnDragStart", "PreClick", "PostClick", "OnEvent", "OnUpdate" }) do pcall(slot.SetScript, slot, h, nil) end
  slot:RegisterForClicks("LeftButtonUp")
  slot:SetScript("OnReceiveDrag", function(self) drop(self.key) end)
  slot:SetScript("OnClick", function(self) drop(self.key) end)
  slot:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Drop an item here")
    GameTooltip:AddLine("It goes in \"" .. def.name .. "\".", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
  slot:Hide()
  box.slot = slot
  boxes[def.key] = box
end

-- (1.9) the delete limit: under the first box's name
local limit = CreateFrame("Frame", nil, boxes.always)
limit:SetSize(W, SLIDER_H)
limit:SetPoint("TOPLEFT", 1, -HDR - 3)
limit.label = limit:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
limit.label:SetPoint("TOPLEFT", 0, 0)
limit.label:SetJustifyH("LEFT")
limit.label:SetText("Delete items worth up to")
local LIMIT_NAME = "Delete items worth up to"
local LIMIT_TIP = { "When your bags are nearly full, Rucksack only throws away a stack worth up to this much at a vendor (the whole stack).",
  "Worth more? It stays in your bag and is sold at the next vendor.",
  "Dragging an item out of your bag still deletes it, whatever it's worth.",
  "Drag the slider, or turn the mouse wheel over it: 10 silver a step, up to 5 gold. All the way right: no limit. The same setting as the delete limit on the Clean-up page." }
limit.q = qmark(boxes.always, function(self) tipOn(self, LIMIT_NAME, LIMIT_TIP) end)
limit.q:SetPoint("TOPRIGHT", boxes.always, "TOPRIGHT", 0, -HDR - 1)
local slider = CreateFrame("Slider", "RucksackSellLimitSlider", limit, ns.BACKDROP_TMPL)
slider:SetOrientation("HORIZONTAL")
slider:SetSize(W - 66, 14)
slider:SetPoint("TOPLEFT", 0, -16)
limit.value = limit:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
limit.value:SetPoint("LEFT", slider, "RIGHT", 6, 0)
limit.value:SetJustifyH("LEFT")
if slider.SetBackdrop then
  slider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  slider:SetBackdropColor(0.08, 0.07, 0.05, 0.95)
  slider:SetBackdropBorderColor(0.45, 0.4, 0.3)
end
-- (15 Nov) filled like a health bar up to the handle, with a shadow inside
local SL_IN = 3 -- (inside the edge)
local fill = slider:CreateTexture(nil, "ARTWORK", nil, -2) -- (under the handle)
fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
fill:SetVertexColor(0.85, 0.65, 0.12)
fill:SetPoint("TOPLEFT", SL_IN, -SL_IN)
fill:SetPoint("BOTTOMLEFT", SL_IN, SL_IN)
fill:SetWidth(1) -- (until the handle exists: then it reaches the handle)
local shadeTop = slider:CreateTexture(nil, "ARTWORK", nil, -1)
shadeTop:SetColorTexture(0, 0, 0, 0.55)
shadeTop:SetPoint("TOPLEFT", SL_IN, -SL_IN)
shadeTop:SetPoint("TOPRIGHT", -SL_IN, -SL_IN)
shadeTop:SetHeight(3)
local shadeTop2 = slider:CreateTexture(nil, "ARTWORK", nil, -1)
shadeTop2:SetColorTexture(0, 0, 0, 0.25)
shadeTop2:SetPoint("TOPLEFT", shadeTop, "BOTTOMLEFT")
shadeTop2:SetPoint("TOPRIGHT", shadeTop, "BOTTOMRIGHT")
shadeTop2:SetHeight(2)
local shadeBottom = slider:CreateTexture(nil, "ARTWORK", nil, -1)
shadeBottom:SetColorTexture(0, 0, 0, 0.4)
shadeBottom:SetPoint("BOTTOMLEFT", SL_IN, SL_IN)
shadeBottom:SetPoint("BOTTOMRIGHT", -SL_IN, SL_IN)
shadeBottom:SetHeight(2)
for _, t in ipairs({ shadeTop, shadeTop2, shadeBottom }) do t:SetBlendMode("BLEND") end
-- (16 Nov) the fill ends at the middle of the handle, wherever the game draws it (it ran short before)
local function paintFill() fill:Show() end
-- (1.9) slider steps: 1..50 = 10s..5g, 51 = no limit
local NOLIMIT = 51
local function curStep()
  local Del = ns.Del
  local v = Del and Del.Limit and Del.Limit()
  if not v then return NOLIMIT end
  return math.max(1, math.min(50, math.floor(v / 1000 + 0.5)))
end
slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
do
  local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
  if thumb then
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", slider, "TOPLEFT", SL_IN, -SL_IN)
    fill:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", SL_IN, SL_IN)
    fill:SetPoint("RIGHT", thumb, "CENTER", 0, 0)
  end
end
slider:SetMinMaxValues(1, NOLIMIT)
slider:SetValueStep(1)
if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
slider:EnableMouseWheel(true)
local function limitText()
  local st = curStep()
  limit.value:SetText(st == NOLIMIT and "|cffff8a8ano limit|r" or money(st * 1000))
  paintFill()
end
local function setLimit(steps)
  steps = math.max(1, math.min(NOLIMIT, math.floor(steps + 0.5)))
  if curStep() == steps then return end
  ns.Del.SetLimit(steps < NOLIMIT and steps * 1000 or nil)
  limitText()
  B.Changed()
end
B.SetDeleteLimit = setLimit -- (steps of 10s: 1..50, 51 = no limit)
-- (19 Nov) two ticks on the first box's name line, he: "on the line always sell checkmark delete
-- checkmark addon will do just that": "Always  [x] sell  [x] delete". Unticked, Rucksack doesn't do
-- that to what's in the box (Clean-up: ns.del.alwaysSell / alwaysDel, on unless false). Stacks in
-- "Sell / delete once" are not affected.
-- (19 Nov) the same two ticks on "Sell / delete once", he: "put on sell delete once to be able to put
-- checkmark": "Once  [x] sell  [x] delete" (ns.del.onceSell / onceDel, on unless false). Unticked sell:
-- the stacks in Once stay in your bag at a vendor (the vendor button under the bag still sells what you
-- click it for); unticked delete: none of them is thrown away by itself.
do
  local function colored(box, word)
    local c = box.def.color
    box.title:SetText(("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), word))
  end
  local function check(box, prefix, word, field, onTip, offTip)
    local cb = CreateFrame("CheckButton", prefix .. field, box, "UICheckButtonTemplate")
    cb:SetSize(16, 16)
    cb.word = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cb.word:SetPoint("LEFT", cb, "RIGHT", -1, 0)
    cb.word:SetText(word)
    cb:SetHitRectInsets(0, -((cb.word:GetStringWidth() or 20) + 2), 0, 0)
    cb:SetScript("OnClick", function(self)
      local db = ns.del
      if not db then return end
      db[field] = self:GetChecked() and true or false
      if B.SideChecks then B.SideChecks() end
      B.Changed()
      if (field == "alwaysSell" or field == "onceSell") and db[field] and ns.Sell and ns.Sell.Kick then pcall(ns.Sell.Kick) end
      if field == "onceDel" and db[field] and ns.Del and ns.Del.CheckNow then pcall(ns.Del.CheckNow) end
    end)
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine((self:GetChecked() and "On: " or "Off: ") .. word)
      GameTooltip:AddLine(self:GetChecked() and onTip or offTip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return cb
  end
  local function pair(box, prefix, word, sellF, delF, sellOn, sellOff, delOn, delOff)
    colored(box, word)
    local sc = check(box, prefix, "sell", sellF, sellOn, sellOff)
    sc:SetPoint("LEFT", box.title, "RIGHT", 4, 0)
    local dc = check(box, prefix, "delete", delF, delOn, delOff)
    dc:SetPoint("LEFT", sc.word, "RIGHT", 6, 0)
    return sc, dc
  end
  local sellC, delC = pair(boxes.always, "RucksackAlways_", "Always", "alwaysSell", "alwaysDel",
    "A vendor buys what's in this box when you visit one. Untick: they stay in your bag at the vendor.",
    "Nothing in this box is sold. Tick it to sell them at the next vendor.",
    "When your bags fill up, the cheapest item in this box is thrown away (up to the delete limit below). Untick: nothing here is thrown away by itself.",
    "Nothing in this box is thrown away by itself. Tick it to let Rucksack make room with them.")
  local oSellC, oDelC
  if boxes.once then
    oSellC, oDelC = pair(boxes.once, "RucksackOnce_", "Once", "onceSell", "onceDel",
      "The stacks in this box are sold when you visit a vendor. Untick: they stay in your bag at the vendor.",
      "Nothing in this box is sold at a vendor. Tick it to sell them at the next one.",
      "When your bags fill up, the cheapest stack marked \"delete once\" here is thrown away. Untick: nothing here is thrown away by itself.",
      "Nothing in this box is thrown away by itself. Tick it to let Rucksack make room with them.")
  end
  function B.SideChecks()
    local db = ns.del
    local on = hasClean() and db and true or false
    for _, cb in ipairs({ sellC, delC, oSellC, oDelC }) do cb:SetShown(on) end
    if not on then return end
    sellC:SetChecked(db.alwaysSell ~= false)
    delC:SetChecked(db.alwaysDel ~= false)
    if oSellC then oSellC:SetChecked(db.onceSell ~= false) oDelC:SetChecked(db.onceDel ~= false) end
    limit:SetAlpha(db.alwaysDel ~= false and 1 or 0.4) -- (the delete limit means nothing with delete off)
  end
  B.SideChecks()
end
slider:SetScript("OnValueChanged", function(self, v)
  if self.quiet or not hasClean() then return end
  setLimit(v)
end)
slider:SetScript("OnMouseWheel", function(self, delta)
  if not hasClean() then return end
  setLimit(curStep() + (delta > 0 and 1 or -1))
  self.quiet = true
  self:SetValue(curStep())
  self.quiet = nil
end)
slider:SetScript("OnEnter", function(self) tipOn(self, LIMIT_NAME, LIMIT_TIP) end)
slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- the bank box: a button to put them in now (shows at the bank while some are still in your bags)
local putBtn = CreateFrame("Button", "RucksackBagsSidePut", boxes.bank, "UIPanelButtonTemplate")
putBtn:SetSize(W, 20)
putBtn:SetText("Put in bank now")
putBtn:Hide()
putBtn:SetScript("OnClick", function() B.BankDeposit(true) end)
putBtn:SetScript("OnEnter", function(self)
  tipOn(self, "Put in bank now", { "Moves the stacks in this box into your bank. It happens by itself when you open the bank; this does it again, for example after you made room." })
end)
putBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Dropping an item on a box
---------------------------------------------------------------------------
StaticPopupDialogs["RUCKSACK_SIDE_SURE"] = {
  text = "%s", button1 = "Yes", button2 = "No",
  OnAccept = function(_, data) if data and data.fn then data.fn() end end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
local function heldSlot(id) return B.HeldSlot(id) end
drop = function(key)
  local db = DB()
  local id, link = ns.CursorItem()
  if not db or not id then return end
  local bag, slot = heldSlot(id) -- (noted before the cursor lets go of it)
  ClearCursor()
  if B.Sets and B.Sets.Of(id) and B.SetRefuse then return B.SetRefuse(id, link) end -- (19 Nov: set items stay put)
  local name = shown(id, link)
  if db.hidden and db.hidden[id] then db.hidden[id] = nil end
  if key == "haul" then key = "once" end -- (19 Nov: dropped on the Haul box: like Once)
  if key == "bank" then return B.SendStack(bag, slot, id, link) end
  if key == "quiver" then return B.IntoQuiver(bag, slot, id, link) end
  if not hasClean() then return end
  local wasBank = bag and B.BankSlot(bag, slot, id)
  if wasBank then B.UnmarkBank(bag, slot) end
  if ns.KeepItem(id, true) then
    local uses = ns.UsedFor(id, link)
    Print(name .. " is always kept" .. (uses[1] and (" (" .. uses[1] .. ")") or "") .. ".")
    return B.Changed()
  end
  local function go()
    if key == "always" then
      if db.assign then db.assign[id] = nil end
      local added = ns.Del.Add(id, link)
      Print(name .. (added and ": every one is sold at a vendor, or thrown away when your bags are nearly full (cheapest first)."
        or " is grey: it's sold or thrown away by itself already."))
    else
      if not bag then
        Print("pick " .. name .. " up from your bag and drop that stack here.")
      elseif ns.Del.SlotJunk(bag, slot, id) then
        Print(name .. ": that stack is marked already.")
      else
        local _, count = ns.SlotInfo(bag, slot)
        ns.Del.JunkStack(bag, slot, id)
        Print(name .. (count and count > 1 and (" x" .. count) or "") .. ": this stack is sold at the next vendor, or thrown away when your bags are nearly full (cheapest first).")
      end
    end
    B.Changed()
  end
  local uses = ns.UsedFor(id, link)
  if #uses > 0 then
    local dlg = StaticPopup_Show("RUCKSACK_SIDE_SURE", "Put " .. name .. " in \"" .. boxes[key].def.name .. "\"?\n\nIt's used for:\n- " .. table.concat(uses, "\n- "))
    if dlg then dlg.data = { fn = go } else go() end
    if wasBank then B.Changed() end
    return
  end
  go()
end
B.SideDrop = function(key) return drop(key) end
-- (1.9) a stack dropped on the quiver window: onto a half-full stack of it there, or an empty slot
function B.IntoQuiver(bag, slot, id, link)
  local q, kind = B.QuiverBag()
  local name = shown(id, link)
  if not q then return end
  if not B.FitsQuiver(id, kind) then
    Print(name .. " doesn't go in " .. (kind == 2 and "an ammo pouch" or "a quiver") .. ": only " .. (kind == 2 and "bullets" or "arrows") .. " do.")
    return
  end
  if not bag or bag == q then return end
  local to
  for s2 = 1, C_Container.GetContainerNumSlots(q) or 0 do
    local it = C_Container.GetContainerItemInfo(q, s2)
    if it and it.itemID == id then
      local max = select(8, ns.GetInfo(it.hyperlink or id))
      if max and (it.stackCount or 1) < max then to = s2 break end
    elseif not it and not to then
      to = to or -s2
    end
  end
  if to and to < 0 then to = -to end
  if not to then Print("your " .. (kind == 2 and "ammo pouch" or "quiver") .. " is full.") return end
  C_Container.PickupContainerItem(bag, slot)
  C_Container.PickupContainerItem(q, to)
  if CursorHasItem() then ClearCursor() end
end
-- one stack to the bank (dropped on the box, or Alt + left-click)
-- (15 Nov) an item from one of the boxes, dropped on an empty slot of your bag: it's out of its box
-- (called after the game has put it there)
function B.DroppedOn(e)
  local h = B.sideHeld
  if not h or not e or not e.empty or not e.bag or not B.IS_BAG[e.bag] then return end
  if CursorHasItem() then return end -- (the game didn't take it)
  B.sideHeld = nil
  local name = shown(h.id)
  if h.box == "bank" then
    if h.bag then B.UnmarkBank(h.bag, h.slot) end
    Print(name .. " stays in your bag: it's no longer sent to your bank.")
  elseif h.box == "once" then
    -- (the mark was on the slot it left: nothing to do)
    Print(name .. " stays in your bag: this stack is no longer sold or thrown away.")
  elseif h.box == "always" and hasClean() then
    ns.Del.Keep(h.id)
    Print(name .. " stays in your bag: it's no longer sold or thrown away (every one of it).")
  end
  B.Changed()
end
function B.SendStack(bag, slot, id, link)
  local name = shown(id, link)
  if not bag then Print("pick " .. name .. " up from your bag and drop that stack here.") return end
  local _, count = ns.SlotInfo(bag, slot)
  local xN = count and count > 1 and (" x" .. count) or ""
  if B.BankSlot(bag, slot, id) then
    if B.BankOpen() then B.BankDeposit(true) else Print(name .. xN .. " goes to your bank already.") end
    return
  end
  B.MarkBank(bag, slot, id)
  Print(name .. xN .. (B.BankOpen() and ": into your bank." or ": this stack goes in your bank when you open it."))
  if B.BankOpen() then B.BankDeposit(true) end
  B.Changed()
end
-- (15 Nov) Alt-clicks on an item in your bag (and in the boxes): left = send this stack to the
-- bank, right = take it back. The game's button does nothing of its own on Alt-click; if it picked
-- the item up anyway, it's put back.
function B.AltClick(e, button)
  if not e or e.empty or e.ghost or not e.id or not e.bag or not B.IS_BAG[e.bag] then return end
  if ns.CursorItem() == e.id then ClearCursor() end
  if button == "RightButton" then
    -- out of whichever box it's in, back where it was in the bag
    local _, count = ns.SlotInfo(e.bag, e.slot)
    local name = shown(e.id, e.link) .. (count and count > 1 and (" x" .. count) or "")
    if B.BankSlot(e.bag, e.slot, e.id) then
      B.UnmarkBank(e.bag, e.slot)
      Print(name .. " stays in your bag: it's no longer sent to your bank.")
      B.Changed()
    elseif (e.side == "always" or e.side == "once" or e.side == "haul") and hasClean() and ns.Del.KeepAt then
      local how = ns.Del.KeepAt(e.id, e.bag, e.slot)
      Print(how == "stack" and (name .. " stays in your bag: this stack is no longer sold or thrown away.")
        or (shown(e.id, e.link) .. " stays in your bag: it's no longer sold or thrown away (every one of it)."))
      B.Changed()
    end
  elseif button == "LeftButton" then
    B.SendStack(e.bag, e.slot, e.id, e.link)
  end
end

---------------------------------------------------------------------------
-- Drawing (called from B.Draw, with what buildCells put aside in st.side)
---------------------------------------------------------------------------
local function screenRight()
  local r, s = UIParent:GetRight(), UIParent:GetEffectiveScale()
  return r and s and r * s or nil
end
-- the box the stack on your cursor sits in ("always", "once", "bank" or nil), and its bag slot
function B.HeldBox(id)
  if not id then return nil end
  local hb, hs = B.HeldSlot(id)
  if hb and B.BankSlot(hb, hs, id) then return "bank", hb, hs end
  if hasClean() then
    local ok, kind = pcall(ns.Del.JunkKind, id, hb, hs)
    if ok and kind then
      if kind == 1 then
        if hb and ns.Del.SlotJunk(hb, hs, id) then return "once", hb, hs end
        if ns.HaulSell and ns.HaulSell(id, hb, hs) and not (ns.del.items and ns.del.items[id]) then return "haul", hb, hs end
        return "always", hb, hs
      end
      return ((not ns.del.sell[id]) and hb and ns.Del.SlotSell(hb, hs, id)) and "once" or "always", hb, hs
    end
  end
  return nil, hb, hs
end
function B.DrawSide(st, text)
  if B.SideChecks then B.SideChecks() end
  oldBankList()
  local side = st and st.side
  if not side then
    sf:Hide()
    B.sideRightW, B.sideLeftW = 0, 0
    if B.PlaceRestock then B.PlaceRestock() end
    return
  end
  local clean = hasClean()
  local held = B.Held and B.Held()
  local heldIn, hb, hs -- the box the item on your cursor sits in, and its slot
  if held then heldIn, hb, hs = B.HeldBox(held) end
  -- (15 Nov) remembered for a drop on an empty slot in the bag: that takes it out of its box
  B.sideHeld = held and heldIn and { id = held, bag = hb, slot = hs, box = heldIn } or nil
  local y = 0
  local qbag, qkind
  if B.QuiverShown() then qbag, qkind = B.QuiverBag() end
  for _, def in ipairs(BOXES) do
    local box = boxes[def.key]
    if (def.clean and not clean) or (def.quiver and not qbag) or (def.haul and #(side.haul or {}) == 0) then
      box:Hide()
      box.win:Hide()
      box.slot:Hide()
    else
      local list = side[def.key] or {}
      local top = y
      local extra = def.key == "always" and SLIDER_H or 0
      local cells = {}
      -- (One bag has no Empty group: there the slot to take it out is in its own box)
      if heldIn == def.key and DB().style == "grid" then cells[1] = { drop = "keep", cat = "keep" } end
      for _, e in ipairs(list) do cells[#cells + 1] = e end
      local n = #cells
      -- (15 Nov) the empty slot only while you hold an item, in every box but the one it's in already
      -- (that one has the green slot to take it out)
      local slotOn = held and heldIn ~= def.key and (def.key == "bank" or clean) or false
      if n == 0 then slotOn = true end -- (an empty box always shows one empty slot, so it never looks bare)
      if def.haul then slotOn = false end -- (19 Nov: Haul fills it by itself)
      if def.quiver then
        -- (its own empty slots show already; the title counts the ammo)
        slotOn = n == 0
        local ammo = 0
        for _, e in ipairs(list) do if not e.empty then ammo = ammo + (e.total or e.count or 0) end end
        local c = B.SpecialColor and B.SpecialColor(qkind == 2 and "ammo" or "quiver") or def.color
        box.title:SetText(("|cff%02x%02x%02x%s|r  |cffffffff%d|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255),
          qkind == 2 and "Ammo pouch" or "Quiver", ammo))
      end
      local total = n + (slotOn and 1 or 0)
      local rows = math.ceil(total / COLS)
      local iy = top + HDR + extra
      for i, e in ipairs(cells) do
        B.ShowIn(SIDE, e, ((i - 1) % COLS) * PITCH, iy + math.floor((i - 1) / COLS) * PITCH, text)
        if e.drop and B.PlusSlot then
          local b = B.PlusSlot(e.drop)
          if b and b.SetFrameLevel then b:SetFrameLevel((box:GetFrameLevel() or 1) + 3) end
        end
      end
      -- the empty slot: right after the last item (on a new row when the row is full)
      local slot = box.slot
      if slotOn then
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", sbody, "TOPLEFT", (n % COLS) * PITCH, -(iy + math.floor(n / COLS) * PITCH))
        if not slot.plain and B.PaintEmpty then B.PaintEmpty(slot) end
        slot:Show()
      else
        slot:Hide()
      end
      local h = HDR + extra + (rows > 0 and (rows * PITCH - GAP) or 14)
      box.empty:ClearAllPoints()
      box.empty:SetPoint("TOPLEFT", sbody, "TOPLEFT", 1, -(iy + 1))
      box.empty:Hide()
      local putOn = def.key == "bank" and B.BankOpen() and #list > 0
      if def.key == "bank" then
        putBtn:SetShown(putOn and true or false)
        if putOn then
          putBtn:ClearAllPoints()
          putBtn:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -(h + 4))
          h = h + 26
        end
      end
      box:ClearAllPoints()
      box:SetPoint("TOPLEFT", sbody, "TOPLEFT", 0, -top)
      box:SetSize(W, h)
      box:Show()
      -- its window: the box with a margin all round
      box.win:ClearAllPoints()
      box.win:SetPoint("TOPLEFT", box, "TOPLEFT", -PAD, PAD)
      box.win:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", PAD, -PAD)
      box.win:Show()
      y = top + h + PAD * 2 + BOXGAP
    end
  end
  if clean then
    limit:Show() limit.q:Show()
    slider.quiet = true
    slider:SetValue(curStep())
    slider.quiet = nil
    limitText()
  end
  local height = math.max(10, y - BOXGAP - PAD * 2)
  sbody:SetHeight(height)
  sf:SetHeight(height + PAD * 2)
  -- (15 Nov) where: the Bags page picks top right (the default), bottom right, top left or bottom
  -- left of the bag. When the screen ends on that side, they go on the other side.
  local pos = DB().sidePos or "tr"
  local top = pos:sub(1, 1) ~= "b"
  local onRight = pos:sub(2, 2) ~= "l"
  local sw = W + PAD * 2
  local fl, fr, fs, sr = f:GetLeft(), f:GetRight(), f:GetEffectiveScale(), screenRight()
  if onRight and fr and fs and sr and (fr + 3 + sw) * fs > sr + 1 then onRight = false
  elseif not onRight and fl and fs and (fl - 3 - sw) * fs < -1 then onRight = true end
  sf:ClearAllPoints()
  local v = top and "TOP" or "BOTTOM"
  if onRight then sf:SetPoint(v .. "LEFT", f, v .. "RIGHT", 3, 0) else sf:SetPoint(v .. "RIGHT", f, v .. "LEFT", -3, 0) end
  B.sideOnRight = onRight
  B.sideLeftW = (not onRight) and (sw + 3) or 0 -- (the bank window, opened on the bag's left, moves past them)
  -- Hidden and Restock sit on the bag's right. (18 Nov) he: "if there are no bags top right then hidden
  -- and restock should hug the bag": they move past the windows only when those are at the top right,
  -- or at the bottom right and too tall to leave room above them.
  local hf, rw = RucksackBagsHidden, RucksackBagsRestock
  local shift = 0
  if onRight then
    if top then
      shift = sw + 3
    else
      local need = ((hf and hf:IsShown()) and ((hf:GetHeight() or 0) + 3) or 0) + ((rw and rw:IsShown()) and ((rw:GetHeight() or 0) + 3) or 0)
      local room = (f:GetHeight() or 0) - (sf:GetHeight() or 0) - 3
      if need > room then shift = sw + 3 end
    end
  end
  B.sideRightW = shift -- (Restock.lua: past the windows only when they'd be in the way)
  if hf and hf.ClearAllPoints then
    hf:ClearAllPoints()
    hf:SetPoint("TOPLEFT", f, "TOPRIGHT", 3 + shift, 0)
  end
  sf:Show()
  if B.PlaceRestock then B.PlaceRestock() end
end

---------------------------------------------------------------------------
-- Send to bank: when the bank opens, what's in the box is moved in, one stack at a time (onto a
-- half-full stack of it when the whole stack fits, else an empty slot). Never in a fight, never
-- while you hold something. A stack the bank won't take is left alone for this visit.
---------------------------------------------------------------------------
local C = C_Container
local run -- { moved, tries, no = {}, full, said }
local function bankStep()
  local db = DB()
  if not run or not db or not anyBank() or not B.BankOpen() then run = nil return end
  if InCombatLockdown() then run = nil return end
  if CursorHasItem() or (GetCursorInfo and GetCursorInfo()) then -- (you hold something: wait a little)
    run.waits = (run.waits or 0) + 1
    if run.waits > 20 then run = nil return end
    return C_Timer.After(0.5, bankStep)
  end
  -- the items of the stacks marked for the bank
  local want = {}
  for bag in pairs(B.IS_BAG) do
    for slot = 1, C.GetContainerNumSlots(bag) or 0 do
      local it = C.GetContainerItemInfo(bag, slot)
      if it and it.itemID and B.BankSlot(bag, slot, it.itemID) then want[it.itemID] = true end
    end
  end
  local empty, partial, busy = {}, {}, false
  for _, bag in ipairs(B.BankIDs()) do
    for slot = 1, C.GetContainerNumSlots(bag) or 0 do
      local it = C.GetContainerItemInfo(bag, slot)
      if it and it.itemID then
        if it.isLocked then busy = true
        elseif want[it.itemID] and not partial[it.itemID] then
          local max = select(8, ns.GetInfo(it.hyperlink or it.itemID))
          if max and (it.stackCount or 1) < max then partial[it.itemID] = { bag = bag, slot = slot, room = max - (it.stackCount or 1) } end
        end
      elseif not (B.IsLockedSlot and B.IsLockedSlot(bag, slot)) then
        empty[#empty + 1] = { bag = bag, slot = slot }
      end
    end
  end
  if busy then -- (a move is still on its way)
    run.tries = run.tries + 1
    if run.tries > 200 then run = nil return end
    return C_Timer.After(0.3, bankStep)
  end
  local left = 0
  for bag in pairs(B.IS_BAG) do
    for slot = 1, C.GetContainerNumSlots(bag) or 0 do
      local it = C.GetContainerItemInfo(bag, slot)
      if it and it.itemID and B.BankSlot(bag, slot, it.itemID) and not it.isLocked then
        local count = it.stackCount or 1
        local to = partial[it.itemID]
        if to and (to.room < count or run.no[it.itemID .. ">" .. to.bag]) then to = nil end
        if not to then
          for _, e in ipairs(empty) do
            if not run.no[it.itemID .. ">" .. e.bag] then to = e break end
          end
        end
        if to then
          local sig = bag .. ":" .. slot .. ":" .. it.itemID .. ":" .. count .. ">" .. to.bag .. ":" .. to.slot
          run.tries = run.tries + 1
          if run.tries > 200 then run = nil return end
          if sig == run.last then
            -- (asked for exactly this a moment ago and nothing happened: the game won't do it)
            run.no[it.itemID .. ">" .. to.bag] = true
            run.last = nil
            run.refused = (run.refused or 0) + 1
          else
            run.last = sig
            C.PickupContainerItem(bag, slot)
            C.PickupContainerItem(to.bag, to.slot)
            if CursorHasItem() then
              -- (that bank bag wouldn't take it: back where it was, not tried there again)
              ClearCursor()
              run.no[it.itemID .. ">" .. to.bag] = true
            else
              run.moved = run.moved + 1
            end
          end
          return C_Timer.After(0.3, bankStep)
        end
        left = left + 1
      end
    end
  end
  -- nothing more to move
  local moved = math.max(0, run.moved - (run.refused or 0))
  if moved > 0 then Print(("put %d stack%s in your bank."):format(moved, moved == 1 and "" or "s")) end
  if left > 0 then
    Print((run.refused or 0) > 0 and moved == 0 and "the game didn't let Rucksack move items into your bank. Please tell the author; for now, right-click them at the banker."
      or (left .. (left == 1 and " stack" or " stacks") .. " didn't fit in your bank and " .. (left == 1 and "stays" or "stay") .. " in your bags."))
  elseif run.byHand and moved == 0 then
    Print("nothing to put in your bank right now.")
  end
  run = nil
  B.Changed()
end
-- byHand: the button, or an item just dropped on the box (says so when there's nothing to do)
function B.BankDeposit(byHand)
  local db = DB()
  oldBankList()
  if not db or not anyBank() then if byHand and B.BankOpen() then Print("nothing to put in your bank right now.") end return end
  if not B.BankOpen() then if byHand then Print("open your bank first.") end return end
  if InCombatLockdown() then if byHand then Print("not in a fight.") end return end
  if run then return end
  run = { moved = 0, tries = 0, no = {}, byHand = byHand }
  C_Timer.After(byHand and 0.1 or 0.8, bankStep)
end
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "BANKFRAME_OPENED")
pcall(ev.RegisterEvent, ev, "BANKFRAME_CLOSED")
ev:SetScript("OnEvent", function(_, e)
  if e == "BANKFRAME_OPENED" then
    -- (a moment later: Bags notes that the bank is open on the same event)
    C_Timer.After(0.1, function() B.BankDeposit(false) end)
  elseif e == "BANKFRAME_CLOSED" then
    run = nil
  end
end)
