-- Rucksack / Bags: the column on the right of the bag (15 Nov)
-- Three boxes, one under the other. Each shows the items in your bags that belong to it (your
-- bags' own buttons, so they work as always) and takes an item you drop on it:
--   Always sell / delete : every one of that item, also later (Clean-up's list, and what its rules pick)
--   Sell / delete once   : only the stack you dropped (a mark on that bag slot)
--   Send to bank         : only the stacks you put there, moved into your bank by itself when you open
--                          the bank; never sold or thrown away. Alt + left-click an item in the bag sends
--                          that stack; Alt + right-click takes it back (marks on bag slots, per character)
-- Under the first box's name: "Do not sell above", 0 to 2g in 10s steps (Clean-up never sells an
-- item worth more than that). Every box and the slider have a "?" that says what it does.
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
-- the box an item in your bags shows in ("always", "once", "bank"), or nil: it stays in the bag
function B.SideOf(e)
  local db = DB()
  if not db or not e or not e.id or e.empty then return nil end
  if B.BankSlot(e.bag, e.slot, e.id) then return "bank" end
  if not hasClean() then return nil end
  if e.cat == "junk" then
    return ns.Del.SlotJunk and ns.Del.SlotJunk(e.bag, e.slot, e.id) and "once" or "always"
  elseif e.cat == "sell" then -- ("only sell" from before 15 Nov)
    return (not ns.del.sell[e.id]) and ns.Del.SlotSell and ns.Del.SlotSell(e.bag, e.slot, e.id) and "once" or "always"
  end
  return nil
end
-- an item's extra tooltip lines when it sits in a box
function B.SideTip(e)
  local out = {}
  local over = hasClean() and ns.Sell.OverLimit and ns.Sell.OverLimit(e.id)
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
  if over and e.side ~= "bank" then out[#out + 1] = "|cffffd100Not sold:|r one is worth more than your \"Do not sell above\" (" .. money(ns.Sell.Limit()) .. ")." end
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
      "Grey items and gear you can't use land here by themselves." } },
  { key = "once", name = "Sell / delete once", color = { 1, 0.72, 0.45 }, clean = true,
    tip = { "Only the stacks you put here.",
      "A vendor buys them when you visit one. If your bags fill up first, the cheapest is thrown away.",
      "The next ones you get are left alone." } },
  { key = "bank", name = "Send to bank", color = { 0.5, 0.83, 1 },
    tip = { "The stacks you put here go into your bank when you open it.",
      "Rucksack never sells them or throws them away.",
      "Alt + left-click an item in your bag: that stack goes here (at the bank: straight in). Alt + right-click it: back in your bag." } },
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

-- "Do not sell above": under the first box's name
local limit = CreateFrame("Frame", nil, boxes.always)
limit:SetSize(W, SLIDER_H)
limit:SetPoint("TOPLEFT", 1, -HDR - 3)
limit.label = limit:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
limit.label:SetPoint("TOPLEFT", 0, 0)
limit.label:SetJustifyH("LEFT")
limit.label:SetText("Do not sell above")
local LIMIT_TIP = { "Rucksack never sells an item worth more than this. It counts the price of one, not the whole stack.",
  "At 0 nothing is sold.", "Drag it, or turn the mouse wheel over it: 10 silver a step, up to 2 gold." }
limit.q = qmark(boxes.always, function(self) tipOn(self, "Do not sell above", LIMIT_TIP) end)
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
local fill = slider:CreateTexture(nil, "ARTWORK")
fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
fill:SetVertexColor(0.85, 0.65, 0.12)
fill:SetPoint("TOPLEFT", SL_IN, -SL_IN)
fill:SetPoint("BOTTOMLEFT", SL_IN, SL_IN)
fill:SetWidth(1)
local shadeTop = slider:CreateTexture(nil, "ARTWORK", nil, 2)
shadeTop:SetColorTexture(0, 0, 0, 0.55)
shadeTop:SetPoint("TOPLEFT", SL_IN, -SL_IN)
shadeTop:SetPoint("TOPRIGHT", -SL_IN, -SL_IN)
shadeTop:SetHeight(3)
local shadeTop2 = slider:CreateTexture(nil, "ARTWORK", nil, 2)
shadeTop2:SetColorTexture(0, 0, 0, 0.25)
shadeTop2:SetPoint("TOPLEFT", shadeTop, "BOTTOMLEFT")
shadeTop2:SetPoint("TOPRIGHT", shadeTop, "BOTTOMRIGHT")
shadeTop2:SetHeight(2)
local shadeBottom = slider:CreateTexture(nil, "ARTWORK", nil, 2)
shadeBottom:SetColorTexture(0, 0, 0, 0.4)
shadeBottom:SetPoint("BOTTOMLEFT", SL_IN, SL_IN)
shadeBottom:SetPoint("BOTTOMRIGHT", -SL_IN, SL_IN)
shadeBottom:SetHeight(2)
for _, t in ipairs({ shadeTop, shadeTop2, shadeBottom }) do t:SetBlendMode("BLEND") end
local function paintFill()
  local v = ns.Sell and ns.Sell.Limit and ns.Sell.Limit() or 0
  local inner = (slider:GetWidth() or (W - 66)) - SL_IN * 2
  local wv = math.floor(inner * math.max(0, math.min(1, v / (ns.Sell.MAX or 20000))) + 0.5)
  fill:SetWidth(math.max(1, wv))
  fill:SetTexCoord(0, math.max(0.01, wv / math.max(1, inner)), 0, 1)
  fill:SetShown(wv > 0)
end
slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
slider:SetMinMaxValues(0, 20)
slider:SetValueStep(1)
if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
slider:EnableMouseWheel(true)
local function limitText()
  local v = ns.Sell.Limit()
  limit.value:SetText(v > 0 and money(v) or "|cffff8a8anothing|r")
  paintFill()
end
local function setLimit(steps)
  steps = math.max(0, math.min(20, math.floor(steps + 0.5)))
  if ns.Sell.Limit() == steps * ns.Sell.STEP then return end
  ns.Sell.SetLimit(steps * ns.Sell.STEP)
  limitText()
  B.Changed()
end
B.SetSellLimit = setLimit -- (steps of 10s: 0..20)
slider:SetScript("OnValueChanged", function(self, v)
  if self.quiet or not hasClean() then return end
  setLimit(v)
end)
slider:SetScript("OnMouseWheel", function(self, delta)
  if not hasClean() then return end
  setLimit(ns.Sell.Limit() / ns.Sell.STEP + (delta > 0 and 1 or -1))
  self.quiet = true
  self:SetValue(ns.Sell.Limit() / ns.Sell.STEP)
  self.quiet = nil
end)
slider:SetScript("OnEnter", function(self) tipOn(self, "Do not sell above", LIMIT_TIP) end)
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
  local name = shown(id, link)
  if db.hidden and db.hidden[id] then db.hidden[id] = nil end
  if key == "bank" then return B.SendStack(bag, slot, id, link) end
  if not hasClean() then return end
  local wasBank = bag and B.BankSlot(bag, slot, id)
  if wasBank then B.UnmarkBank(bag, slot) end
  if ns.KeepItem(id) then
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
-- one stack to the bank (dropped on the box, or Alt + left-click)
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
    elseif (e.side == "always" or e.side == "once") and hasClean() and ns.Del.KeepAt then
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
function B.DrawSide(st, text)
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
  local heldIn -- the box the item on your cursor sits in
  if held then
    local db = DB()
    local hb, hs = B.HeldSlot(held)
    if hb and B.BankSlot(hb, hs, held) then heldIn = "bank"
    elseif clean then
      local bag, slot = heldSlot(held)
      local ok, kind = pcall(ns.Del.JunkKind, held, bag, slot)
      if ok and kind then
        if kind == 1 then heldIn = bag and ns.Del.SlotJunk(bag, slot, held) and "once" or "always"
        else heldIn = (not ns.del.sell[held]) and bag and ns.Del.SlotSell(bag, slot, held) and "once" or "always" end
      end
    end
  end
  local y = 0
  for _, def in ipairs(BOXES) do
    local box = boxes[def.key]
    if def.clean and not clean then
      box:Hide()
      box.win:Hide()
      box.slot:Hide()
    else
      local list = side[def.key] or {}
      local top = y
      local extra = def.key == "always" and SLIDER_H or 0
      local cells = {}
      if heldIn == def.key then cells[1] = { drop = "keep", cat = "keep" } end
      for _, e in ipairs(list) do cells[#cells + 1] = e end
      local n = #cells
      -- (15 Nov) the empty slot only while you hold an item, in every box but the one it's in already
      -- (that one has the green slot to take it out)
      local slotOn = held and heldIn ~= def.key and (def.key == "bank" or clean) or false
      if n == 0 then slotOn = true end -- (an empty box always shows one empty slot, so it never looks bare)
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
    slider:SetValue(ns.Sell.Limit() / ns.Sell.STEP)
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
  B.sideRightW = onRight and (sw + 3) or 0       -- (the Restock window, on the bag's right, too)
  local hf = RucksackBagsHidden
  if hf and hf.ClearAllPoints then
    hf:ClearAllPoints()
    hf:SetPoint("TOPLEFT", f, "TOPRIGHT", onRight and (3 + sw + 3) or 3, 0)
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
