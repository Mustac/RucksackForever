-- Rucksack / Bags: the Track bars (19 Nov). He: "in settings let me enable a bar and it acts like a mini
-- bag that is all the time on screen, we can pull item into her and this item we can see on the bar /
-- compressed state total pieces of it in inventory", and "have a option when we go to mini popup settings
-- menu on this bars and select clickable or click through".
--  * The "Item bar" tick on the Bags page (on to start). A small bar that stays on screen, bag open or not.
--  * Pull an item onto it: one icon per item with how many you carry in all your bags together.
--  * Its own little menu (click "Track" on top): Clickable (click an item to use it) or Click-through
--    (clicks go through to the world), Lock position, Row or Column, items you have none of faded or
--    hidden, and Remove for each item. Shift + right-click an item takes it off too.
--  * The item buttons are the game's secure ones (so a click can use an item, also in a fight); the game
--    lets an addon change them only out of a fight, so adding, removing and settings wait for the end of one.
-- (19 Nov, 21:08) a "Track" strip across the top (drag it to move the bar, click it for the menu), no grip
-- on the left; the bar keeps its top-left corner (it grows right, or down as a column).
-- (19 Nov, 21:18) he: "remove extra icon, it should act same like category in bag, same animation": the
-- bag's green + slot shows only while you hold an item (or the bar is empty); held over the bar, the items
-- slide apart where the mouse is and the + slot moves into the space; drop the item there.
-- (19 Nov, 21:23) he: "put add track bar, we can open up to 5 of them": a button in the bag's tool row opens
-- another bar, up to 5. Bar 1's settings stay in B.db.ibar (with "on" for all of them); bars 2..5 in
-- B.db.ibar.more[i]. Each extra bar's menu has "Close this bar".
local ns = Rucksack
if not ns or not ns.Bags then return end
local B = ns.Bags
local Print = ns.Print
local IB = {}
B.ItemBar = IB
local CELL, GAP, TITLE, MAX, BARS = 37, 3, 14, 12, 5
local TAN = { 0.85, 0.78, 0.6 }

local function fill(c)
  if type(c.items) ~= "table" then c.items = {} end
  if c.click == nil then c.click = true end
  if c.zero == nil then c.zero = "fade" end
  return c
end
local function D()
  local d = B.db
  if not d then return nil end
  if type(d.ibar) ~= "table" then d.ibar = {} end
  local c = d.ibar
  if c.on == nil then c.on = true end -- (19 Nov: on to start; the tick on the Bags page turns it off)
  if type(c.more) ~= "table" then c.more = {} end
  return fill(c)
end
IB.DB = D
-- a bar's settings: 1 = B.db.ibar, 2..5 = B.db.ibar.more[i] (nil: that bar isn't open)
local function cfg(i)
  local c = D()
  if not c then return nil end
  if i == 1 then return c end
  local m = c.more[i]
  return m and fill(m) or nil
end
IB.Cfg = cfg
local function count(id)
  local ok, n = pcall(ns.GetCount, id)
  return ok and tonumber(n) or 0
end
local fight = function() return InCombatLockdown and InCombatLockdown() end
local function paintItem(b, id, n)
  SetItemButtonTexture(b, ns.GetIcon(id))
  SetItemButtonCount(b, n > 1 and n or 0)
  b.zero:SetShown(n == 0)
  local q = ns.QualityOf and ns.QualityOf(id) or nil
  if b.SetItemButtonQuality then pcall(b.SetItemButtonQuality, b, q, id, true)
  elseif SetItemButtonQuality then pcall(SetItemButtonQuality, b, q, id) end
  SetItemButtonDesaturated(b, n == 0)
  b:SetAlpha(n == 0 and 0.55 or 1)
end

local bars = {}
IB.bars = bars
local menu -- (one menu, for whichever bar's "Track" was clicked; made below)

---------------------------------------------------------------------------
-- one bar
---------------------------------------------------------------------------
local function makeBar(idx)
  local X = { idx = idx }
  local name = "RucksackItemBar" .. (idx == 1 and "" or idx)
  local function C() return cfg(idx) end
  local bar = CreateFrame("Frame", name, UIParent, ns.BACKDROP_TMPL)
  X.frame = bar
  bar:SetSize(CELL + 12, TITLE + CELL + 11)
  bar:SetPoint("CENTER", UIParent, "CENTER", 0, -180 - (idx - 1) * 70)
  bar:SetMovable(true)
  bar:SetClampedToScreen(true)
  bar:SetFrameStrata("MEDIUM")
  if bar.SetBackdrop then
    bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    bar:SetBackdropColor(0.04, 0.035, 0.03, 0.95) -- (the bag window's own look)
    bar:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
  end
  bar:Hide()

  -- the "Track" strip on top: always takes the mouse (also with click-through): drag to move, click for the menu
  local grip = CreateFrame("Button", name .. "Grip", bar)
  X.grip = grip
  grip:SetHeight(TITLE)
  grip:SetPoint("TOPLEFT", 4, -3)
  grip:SetPoint("TOPRIGHT", -4, -3)
  grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  grip:RegisterForDrag("LeftButton")
  grip.text = grip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  grip.text:SetPoint("LEFT", 3, 0)
  grip.text:SetText("Track")
  grip.text:SetTextColor(TAN[1], TAN[2], TAN[3])
  do local fo = grip.text:GetFont() if fo then grip.text:SetFont(fo, 10) end end
  for i = 0, 2 do -- (three dots on the right: there's a menu)
    local t = grip:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(TAN[1], TAN[2], TAN[3], 0.7)
    t:SetSize(2, 2)
    t:SetPoint("RIGHT", -3 - i * 4, 0)
  end
  do
    local ghl = grip:CreateTexture(nil, "HIGHLIGHT")
    ghl:SetAllPoints()
    ghl:SetColorTexture(1, 1, 1, 0.08)
  end
  -- the bar keeps its top-left corner (so it only grows right, or down)
  local function savePos()
    local c = C()
    if not c then return end
    local l, t = bar:GetLeft(), bar:GetTop()
    if l and t then c.pos = { "TOPLEFT", "BOTTOMLEFT", l, t } end
  end
  X.SavePos = savePos
  grip:SetScript("OnDragStart", function() local c = C() if c and not c.locked then bar:StartMoving() end end)
  grip:SetScript("OnDragStop", function() bar:StopMovingOrSizing() savePos() end)

  -- the place to drop on: the bag's green + slot
  local drop = CreateFrame("Button", name .. "Drop", bar)
  X.drop = drop
  drop:SetSize(CELL, CELL)
  drop.bg = drop:CreateTexture(nil, "BACKGROUND")
  drop.bg:SetAllPoints()
  drop.bg:SetColorTexture(0.07, 0.2, 0.07, 0.45)
  do
    local seg = 4
    for k = 0, 5 do
      local pos = math.floor(k * (CELL - seg) / 5 + 0.5)
      for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = drop:CreateTexture(nil, "BORDER")
        if side == "TOP" then t:SetSize(seg, 1) t:SetPoint("TOPLEFT", pos, 0)
        elseif side == "BOTTOM" then t:SetSize(seg, 1) t:SetPoint("BOTTOMLEFT", pos, 0)
        elseif side == "LEFT" then t:SetSize(1, seg) t:SetPoint("TOPLEFT", 0, -pos)
        else t:SetSize(1, seg) t:SetPoint("TOPRIGHT", 0, -pos) end
        t:SetColorTexture(0.35, 1, 0.35, 0.45)
      end
    end
  end
  drop.plus = drop:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  drop.plus:SetPoint("CENTER", 0, 1)
  drop.plus:SetText("+")
  drop.plus:SetTextColor(0.35, 1, 0.35, 0.7)
  do
    local hl = drop:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
  end
  drop:RegisterForClicks("LeftButtonUp")
  drop:Hide()

  -- the item buttons
  local btns = {}
  X.btns = btns
  local function button(i)
    if btns[i] then return btns[i] end
    -- (the game's item button: the bag's slot, frame and quality border, with the secure "use")
    local bname = name .. "Button" .. i
    local ok, b = pcall(CreateFrame, "ItemButton", bname, bar, "SecureActionButtonTemplate")
    if not ok or not b then ok, b = pcall(CreateFrame, "Button", bname, bar, "SecureActionButtonTemplate, ItemButtonTemplate") end
    if not ok or not b then b = CreateFrame("Button", bname, bar, "SecureActionButtonTemplate") end
    b:SetSize(CELL, CELL)
    -- (19 Nov, 21:30) he: "we should also be able to use items from tracked bars": a "/use item:ID" macro
    -- (like Rations' buttons, which work on this client); any mouse button uses it, Shift + right-click
    -- takes it off the bar instead. It acts when you let go of the button, so a drag never uses it.
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("shift-type2", "none")
    -- (19 Nov, 21:30) he: "and pull them out and put them out to remove them": drag an item off the bar
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) X.StartDrag(self) end)
    b:SetScript("OnDragStop", function(self) X.StopDrag(self) end)
    b.zero = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.zero:SetPoint("BOTTOMRIGHT", -5, 2)
    b.zero:SetText("|cff8080800|r")
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints()
    b:SetScript("OnEnter", function(self)
      if not self.id then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("You carry " .. count(self.id) .. ".", 0.7, 0.7, 0.7)
      local c = C()
      GameTooltip:AddLine((c and c.click and "Click: use it.  " or "") .. "Drag it off the bar to take it off; drag it along the bar to move it.", 0.7, 0.7, 0.7, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- (a drop on an item adds the held one; Shift + right-click takes this one off)
    b:SetScript("OnReceiveDrag", function() X.AddHeld() end)
    b:HookScript("OnClick", function(self, mouse)
      if ns.CursorItem() then X.AddHeld() return end
      if mouse == "RightButton" and IsShiftKeyDown() and self.id then X.Remove(self.id) end
    end)
    btns[i] = b
    return b
  end

  -- layout: each button and the + slot slide toward their place, the bar's size too
  local shown, insertAt, holding = {}, nil, false
  X.shown = shown
  local anim = CreateFrame("Frame", nil, bar)
  anim:Hide()
  local function at(i) -- (i from 0): a cell's place in the bar
    local c = C()
    if c and c.vertical then return 6, -(TITLE + 5 + i * (CELL + GAP)) end
    return 6 + i * (CELL + GAP), -(TITLE + 5)
  end
  -- where a held item would go: the cell under the mouse (0 = first), the end when the mouse isn't on the bar
  local function cellUnderMouse()
    local n = #shown
    if not bar:IsMouseOver() or not GetCursorPosition then return n end
    local c = C()
    local x, y = GetCursorPosition()
    local sc = bar:GetEffectiveScale()
    local l, t = bar:GetLeft(), bar:GetTop()
    if not (l and t and x and sc and sc > 0) then return n end
    local pos = c and c.vertical and ((t - y / sc) - TITLE - 5) or (x / sc - l - 6)
    return math.max(0, math.min(n, math.floor(pos / (CELL + GAP) + 0.5)))
  end
  local function goal()
    local c = C()
    local n = #shown
    local k = holding and insertAt or nil
    local list = {}
    for i = 1, n do list[#list + 1] = { f = btns[i], slot = (k and i - 1 >= k) and i or i - 1 } end
    if k then list[#list + 1] = { f = drop, slot = k } end
    local cells = math.max(1, n + (k and 1 or 0))
    local w, h
    if c and c.vertical then w, h = CELL + 12, TITLE + 5 + cells * (CELL + GAP) - GAP + 6
    else w, h = math.max(CELL + 12, 6 + cells * (CELL + GAP) - GAP + 6), TITLE + 5 + CELL + 6 end
    return list, w, h
  end
  local function step(dt, now)
    local list, w, h = goal()
    local moving = false
    local t = now and 1 or math.min(1, (dt or 0.016) * 14)
    for _, it in ipairs(list) do
      local tx, ty = at(it.slot)
      local fr = it.f
      local cx, cy = fr._x or tx, fr._y or ty
      cx, cy = cx + (tx - cx) * t, cy + (ty - cy) * t
      if math.abs(tx - cx) < 0.5 and math.abs(ty - cy) < 0.5 then cx, cy = tx, ty else moving = true end
      fr._x, fr._y = cx, cy
      fr:ClearAllPoints()
      fr:SetPoint("TOPLEFT", bar, "TOPLEFT", cx, cy)
    end
    local bw, bh = bar:GetWidth() or w, bar:GetHeight() or h
    bw, bh = bw + (w - bw) * t, bh + (h - bh) * t
    if math.abs(w - bw) < 0.5 and math.abs(h - bh) < 0.5 then bw, bh = w, h else moving = true end
    bar:SetSize(bw, bh)
    return moving
  end
  local since = 0
  anim:SetScript("OnUpdate", function(self, dt)
    if fight() then self:Hide() return end
    since = since + (dt or 0)
    if holding and since > 0.05 then
      since = 0
      insertAt = cellUnderMouse()
    end
    if not step(dt) and not holding then self:Hide() end
  end)

  function X.Draw()
    local c = C()
    local all = D()
    if not c or not all or not all.on then
      if fight() then X.pending = true return end
      bar:Hide()
      return
    end
    local held = ns.CursorItem()
    -- (secure buttons: the layout only out of a fight; in one, only the numbers change)
    if fight() then
      X.pending = true
      for _, b in ipairs(btns) do
        if b:IsShown() and b.id then pcall(paintItem, b, b.id, count(b.id)) end
      end
      return
    end
    X.pending = nil
    if c.pos then
      bar:ClearAllPoints()
      bar:SetPoint(c.pos[1], UIParent, c.pos[2], c.pos[3], c.pos[4])
      if c.pos[1] ~= "TOPLEFT" or c.pos[2] ~= "BOTTOMLEFT" then savePos() end -- (a place saved the old way)
    end
    wipe(shown)
    for _, id in ipairs(c.items) do
      if (c.zero ~= "hide" or count(id) > 0) and id ~= X.dragID then shown[#shown + 1] = id end
    end
    held = held or X.dragID
    local first = not bar:IsShown()
    for i, id in ipairs(shown) do
      local b = button(i)
      b.id = id
      local use = c.click and not held -- (holding an item: a click drops it here instead)
      b:SetAttribute("type1", nil)
      b:SetAttribute("item", nil)
      b:SetAttribute("type", use and "macro" or nil)
      b:SetAttribute("macrotext", use and ("/use item:" .. id) or nil)
      b:EnableMouse(c.click or held ~= nil)
      pcall(paintItem, b, id, count(id))
      local s, dur = 0, 0
      if C_Container and C_Container.GetItemCooldown then s, dur = C_Container.GetItemCooldown(id)
      elseif GetItemCooldown then s, dur = GetItemCooldown(id) end
      if s and dur and dur > 0 then b.cd:SetCooldown(s, dur) else b.cd:Clear() end
      b:Show()
    end
    for i = #shown + 1, #btns do btns[i]:Hide() btns[i].id = nil btns[i]._x = nil end
    -- the + slot: while you hold an item (room left), or always while the bar is empty
    local wasHolding = holding
    holding = (held ~= nil and (#c.items < MAX or X.dragID ~= nil)) or #c.items == 0
    if holding then
      if not wasHolding then insertAt = #shown drop._x, drop._y = at(#shown) end
      insertAt = math.min(insertAt or #shown, #shown)
      drop:Show()
    else
      insertAt = nil
      drop:Hide()
    end
    -- click-through: the bar takes no clicks (only the "Track" strip does), unless you hold an item to drop on it
    bar:EnableMouse(c.click or held ~= nil)
    bar:Show()
    if first then step(0, true) else anim:Show() end
  end

  -- at: put it before the k-th shown item (0 = first), nil = at the end
  function X.Add(id, link, k)
    local c = C()
    if not c or not id then return end
    if fight() then Print("the Track bar takes items after the fight.") return end
    for _, x in ipairs(c.items) do if x == id then Print((ns.NameOf(id, link) or "that") .. " is on this Track bar already.") return end end
    if #c.items >= MAX then Print("this Track bar is full (" .. MAX .. " items): take one off first (Shift + right-click it).") return end
    local pos = #c.items + 1
    local before = k and shown[k + 1]
    if before then for i, x in ipairs(c.items) do if x == before then pos = i break end end end
    table.insert(c.items, pos, id)
    -- (the item lands where the + slot was: the buttons from there on keep their slid places)
    if before and k then
      local stay = {}
      for i, b in ipairs(btns) do stay[i] = { b._x, b._y } end
      for i = #btns, k + 2, -1 do btns[i]._x, btns[i]._y = stay[i - 1][1], stay[i - 1][2] end
      if btns[k + 1] then btns[k + 1]._x, btns[k + 1]._y = drop._x, drop._y end
    elseif btns[#c.items] then
      btns[#c.items]._x, btns[#c.items]._y = drop._x, drop._y
    end
    X.Draw()
  end
  function X.AddHeld()
    local id, link = ns.CursorItem()
    if not id then return end
    if fight() then Print("the Track bar takes items after the fight.") return end
    local k = holding and insertAt or nil
    ClearCursor()
    X.Add(id, link, k)
  end
  -- dragging an item of the bar: it's lifted out (the others close up), a picture of it follows the mouse,
  -- the + slot opens where the mouse is over the bar. Let go over the bar: it moves to that place; let go
  -- anywhere else: it's off the bar.
  local ghost
  function X.StartDrag(b)
    if fight() or not b.id or ns.CursorItem() then return end
    if not ghost then
      ghost = CreateFrame("Frame", nil, UIParent)
      ghost:SetSize(CELL, CELL)
      ghost:SetFrameStrata("TOOLTIP")
      ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
      ghost.icon:SetAllPoints()
      ghost:SetAlpha(0.8)
      ghost:SetScript("OnUpdate", function(self)
        if not GetCursorPosition then return end
        local x, y = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / sc, y / sc)
      end)
    end
    ghost.icon:SetTexture(ns.GetIcon(b.id))
    ghost:Show()
    -- (the buttons after it show the next items now: they keep their places, then slide up)
    local j
    for i, x in ipairs(btns) do if x == b then j = i end end
    if j then
      for i = j, #btns - 1 do btns[i]._x, btns[i]._y = btns[i + 1]._x, btns[i + 1]._y end
    end
    X.dragID = b.id
    -- (the button you dragged may be hidden now that the others closed up: letting go is caught here too)
    if not X.up then
      X.up = CreateFrame("Frame")
      X.up:SetScript("OnEvent", function(self) self:UnregisterAllEvents() X.StopDrag() end)
    end
    pcall(X.up.RegisterEvent, X.up, "GLOBAL_MOUSE_UP")
    X.Draw()
  end
  function X.StopDrag()
    local id = X.dragID
    if not id then return end
    if ghost then ghost:Hide() end
    local k = holding and insertAt or nil
    X.dragID = nil
    local c = C()
    if fight() or not c then X.Draw() return end
    if bar:IsMouseOver() then
      for i, x in ipairs(c.items) do if x == id then table.remove(c.items, i) break end end
      local pos = #c.items + 1
      local before = k and shown[k + 1]
      if before then for i, x in ipairs(c.items) do if x == before then pos = i break end end end
      table.insert(c.items, pos, id)
      if k then
        local stay = {}
        for i, x in ipairs(btns) do stay[i] = { x._x, x._y } end
        for i = #btns, k + 2, -1 do btns[i]._x, btns[i]._y = stay[i - 1][1], stay[i - 1][2] end
        if btns[k + 1] then btns[k + 1]._x, btns[k + 1]._y = drop._x, drop._y end
      end
      X.Draw()
    else
      for i, x in ipairs(c.items) do if x == id then table.remove(c.items, i) break end end
      Print((ns.NameOf(id) or "That item") .. " is off the Track bar.")
      X.Draw()
    end
  end
  function X.Remove(id)
    local c = C()
    if not c then return end
    if fight() then Print("the Track bar changes after the fight.") return end
    for i, x in ipairs(c.items) do if x == id then table.remove(c.items, i) break end end
    X.Draw()
  end
  bar:SetScript("OnReceiveDrag", function() X.AddHeld() end)
  bar:SetScript("OnMouseUp", function() if ns.CursorItem() then X.AddHeld() end end)
  drop:SetScript("OnReceiveDrag", function() X.AddHeld() end)
  drop:SetScript("OnClick", function() X.AddHeld() end)
  drop:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Track")
    GameTooltip:AddLine("Drop an item here: the bar shows how many you carry in all your bags.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  drop:SetScript("OnLeave", function() GameTooltip:Hide() end)
  grip:SetScript("OnClick", function(_, mouse)
    if ns.CursorItem() then X.AddHeld() return end
    if mouse == "RightButton" or not (menu:IsShown() and menu.bar == X) then IB.Menu(X) else menu:Hide() end
  end)
  grip:SetScript("OnReceiveDrag", function() X.AddHeld() end)
  grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Track" .. (idx > 1 and (" " .. idx) or ""))
    GameTooltip:AddLine("Drag: move the bar. Click: its settings (clickable or click-through, row or column, remove items). Pick an item up and drop it on the bar to track it.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return X
end

-- bar i (made the first time it's needed)
local function barAt(i)
  if not bars[i] then bars[i] = makeBar(i) end
  return bars[i]
end
bars[1] = makeBar(1)

---------------------------------------------------------------------------
-- all bars
---------------------------------------------------------------------------
function IB.Draw()
  local c = D()
  if not c then return end
  for i = 1, BARS do
    if cfg(i) then barAt(i).Draw()
    elseif bars[i] and not fight() then bars[i].frame:Hide() end
  end
end
-- bar 1 (the first one; tests and older code use these)
function IB.Add(id, link, k) return bars[1].Add(id, link, k) end
function IB.AddHeld() return bars[1].AddHeld() end
function IB.Remove(id) return bars[1].Remove(id) end
function IB.Set(on)
  local c = D()
  if not c then return end
  c.on = on and true or false
  IB.Draw()
end
-- how many bars are open
function IB.Count()
  local c = D()
  if not c or not c.on then return 0 end
  local n = 1
  for i = 2, BARS do if c.more[i] then n = n + 1 end end
  return n
end
-- the tool row's button: another bar (the bars turned off: bar 1 comes back first)
function IB.Open()
  local c = D()
  if not c then return end
  if fight() then Print("a new Track bar opens after the fight.") return end
  if not c.on then c.on = true IB.Draw() if B.SettingsChanged then B.SettingsChanged() end return 1 end
  for i = 2, BARS do
    if not c.more[i] then
      -- (under the last open bar)
      local last = 1
      for j = 2, BARS do if c.more[j] then last = j end end
      local lf = barAt(last).frame
      local l, t = lf:GetLeft(), lf:GetBottom()
      c.more[i] = { pos = (l and t) and { "TOPLEFT", "BOTTOMLEFT", l, t - 6 } or nil }
      IB.Draw()
      Print("Track bar " .. i .. " is open: pick an item up and drop it on it. Click \"Track\" on it for its settings.")
      return i
    end
  end
  Print("you have " .. BARS .. " Track bars open already: that's the most.")
end
function IB.Close(i)
  local c = D()
  if not c or i == 1 then return end
  if fight() then Print("the Track bar closes after the fight.") return end
  c.more[i] = nil
  if bars[i] then bars[i].frame:Hide() end
end

---------------------------------------------------------------------------
-- the menu (click "Track" on a bar)
---------------------------------------------------------------------------
menu = CreateFrame("Frame", "RucksackItemBarMenu", UIParent, ns.BACKDROP_TMPL)
menu:SetFrameStrata("DIALOG")
menu:EnableMouse(true)
if menu.SetBackdrop then
  menu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  menu:SetBackdropColor(0.04, 0.035, 0.03, 0.97)
  menu:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
end
menu:Hide()
menu:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
menu:SetScript("OnHide", function(self) pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
menu:SetScript("OnEvent", function(self)
  if not self:IsMouseOver() and not (self.bar and self.bar.grip:IsMouseOver()) then self:Hide() end
end)
local mrows = {}
local function mrow(i)
  if mrows[i] then return mrows[i] end
  local r = CreateFrame("Button", nil, menu)
  r:SetHeight(18)
  r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.text:SetPoint("LEFT", 4, 0)
  r.text:SetJustifyH("LEFT")
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.1)
  r:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
  mrows[i] = r
  return r
end
local function tick(on) return on and "|cff66dd66\226\128\162|r " or "|cff555555\226\128\162|r " end
function IB.Menu(X)
  X = X or bars[1]
  local c = cfg(X.idx)
  if not c then return end
  menu.bar = X
  local list = {
    { head = "Track" .. (X.idx > 1 and (" " .. X.idx) or "") },
    { text = tick(c.click) .. "Clickable: click an item to use it", fn = function() c.click = true end },
    { text = tick(not c.click) .. "Click-through: clicks go through it", fn = function() c.click = false end },
    { text = tick(c.locked) .. "Lock position", fn = function() c.locked = not c.locked end },
    { text = tick(not c.vertical) .. "Row", fn = function() c.vertical = false end },
    { text = tick(c.vertical) .. "Column", fn = function() c.vertical = true end },
    { text = tick(c.zero ~= "hide") .. "None left: faded with 0", fn = function() c.zero = "fade" end },
    { text = tick(c.zero == "hide") .. "None left: hidden", fn = function() c.zero = "hide" end },
  }
  for _, id in ipairs(c.items) do
    list[#list + 1] = { text = "|cffff6b5ex|r Remove " .. (ns.NameOf(id) or ("item " .. id)), fn = function() X.Remove(id) end }
  end
  if IB.Count() < BARS then list[#list + 1] = { text = "|cff66dd66+|r Open another Track bar", fn = function() IB.Open() end } end
  if X.idx == 1 then
    list[#list + 1] = { text = "|cff999999Turn the Track bars off|r", fn = function() D().on = false end }
  else
    list[#list + 1] = { text = "|cff999999Close this bar|r", fn = function() IB.Close(X.idx) end }
  end
  local y, w = -6, 120
  for _, r in ipairs(mrows) do r:Hide() end
  if not menu.head then
    menu.head = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    menu.head:SetPoint("TOPLEFT", 10, -7)
  end
  local i = 0
  for _, e in ipairs(list) do
    if e.head then
      menu.head:SetText(e.head)
      y = y - 16
    else
      i = i + 1
      local r = mrow(i)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 6, y)
      r:SetPoint("RIGHT", -6, 0)
      r.text:SetText(e.text)
      r.fn = function()
        if fight() then Print("the Track bar changes after the fight.") menu:Hide() return end
        e.fn()
        menu:Hide()
        IB.Draw()
        if B.SettingsChanged then B.SettingsChanged() end
      end
      r:Show()
      w = math.max(w, (r.text:GetStringWidth() or 0) + 20)
      y = y - 18
    end
  end
  menu:SetSize(w + 12, -y + 6)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", X.grip, "BOTTOMLEFT", 0, -4)
  menu:Show()
end

---------------------------------------------------------------------------
-- events: counts, cooldowns, the item on your cursor, the end of a fight
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "CURSOR_CHANGED", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, a)
  local c = D()
  if not c then return end
  if e == "GET_ITEM_INFO_RECEIVED" then
    -- (only for an item on a bar whose icon wasn't known yet)
    local mine = false
    for i = 1, BARS do
      local ci = cfg(i)
      if ci then for _, id in ipairs(ci.items) do if id == a then mine = true end end end
    end
    if not mine then return end
  end
  if e == "PLAYER_REGEN_ENABLED" then
    local any = false
    for _, X in pairs(bars) do if X.pending then any = true end end
    if not any then return end
  end
  if not c.on and e ~= "PLAYER_LOGIN" then return end
  IB.Draw()
end)
table.insert(ns.onLogin, function() IB.Draw() end)
