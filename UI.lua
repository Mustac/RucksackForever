local _, ns = ...
-- Rucksack / the window (/ruck). Left: Home, Rations, Clean-up (each with on/off) and Settings at the
-- bottom. Right: Home is a dashboard (bag space, what you eat next, what's waiting to go, what a vendor
-- would pay); a tool's page has its settings and its list of items; click an item for its own settings.
local Print = ns.Print

local W, H, SIDE_W = 960, 640, 190
local f = CreateFrame("Frame", "RucksackFrame", UIParent, ns.BACKDROP_TMPL)
f:SetSize(W, H)
f:SetPoint("CENTER")
f:SetFrameStrata("HIGH")
f:SetToplevel(true)
f:EnableMouse(true)
f:SetMovable(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetBackdrop(ns.DIALOG_BACKDROP)
local fill = f:CreateTexture(nil, "BACKGROUND", nil, -8)
fill:SetPoint("TOPLEFT", 11, -12)
fill:SetPoint("BOTTOMRIGHT", -12, 11)
fill:SetColorTexture(0.05, 0.05, 0.05, 0.92)
f:Hide()
tinsert(UISpecialFrames, "RucksackFrame")
-- (10 Nov) closing Rucksack locks the eating alert if it was being moved
f:HookScript("OnHide", function() if ns.LockAlert then ns.LockAlert() end end)

local logo = f:CreateTexture(nil, "ARTWORK")
logo:SetSize(22, 22)
logo:SetPoint("TOP", -88, -16)
logo:SetTexture(ns.ICON)
local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
title:SetText("|cffc8a165Ruck|r|cffffd100sack|r")
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local side = CreateFrame("Frame", nil, f, ns.BACKDROP_TMPL)
side:SetPoint("TOPLEFT", 18, -46)
side:SetPoint("BOTTOMLEFT", 18, 18)
side:SetWidth(SIDE_W)
side:SetBackdrop(ns.SLOT_BACKDROP)
side:SetBackdropColor(0, 0, 0, 0.6)
side:SetBackdropBorderColor(0.5, 0.5, 0.5)

local right = CreateFrame("Frame", nil, f, ns.BACKDROP_TMPL)
right:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, 0)
right:SetPoint("BOTTOMRIGHT", -18, 18)
right:SetBackdrop(ns.SLOT_BACKDROP)
right:SetBackdropColor(0, 0, 0, 0.35)
right:SetBackdropBorderColor(0.5, 0.5, 0.5)

---------------------------------------------------------------------------
-- small widgets
---------------------------------------------------------------------------
local function tip(frame, title, text)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- (10 Nov) hovering a label shows what it means; the label lights up gold while you do
local function HoverLabel(owner, fs, title, text)
  if not text then return end
  local h = CreateFrame("Frame", nil, owner)
  h:SetPoint("TOPLEFT", fs, "TOPLEFT", -3, 4)
  h:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 3, -4)
  h:EnableMouse(true)
  h:SetScript("OnEnter", function(self)
    self.r, self.g, self.b = fs:GetTextColor()
    fs:SetTextColor(1, 0.82, 0)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  h:SetScript("OnLeave", function(self)
    if self.r then fs:SetTextColor(self.r, self.g, self.b) end
    GameTooltip:Hide()
  end)
  return h
end

local function Text(parent, x, y, font, width)
  local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  if width then fs:SetWidth(width) end
  return fs
end

-- a label with an explanation on hover
local function TipText(parent, x, y, font, text, tipText)
  local fs = Text(parent, x, y, font)
  fs:SetText(text)
  HoverLabel(parent, fs, (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(":$", "")), tipText)
  return fs
end

local function Check(parent, x, y, label, tipText, get, set, font)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  local fs = cb:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  fs:SetText(label)
  cb.label = fs
  -- (10 Nov) the label counts as part of the box: hovering it explains, clicking it ticks
  cb:SetHitRectInsets(0, -math.min(420, (fs:GetStringWidth() or 0) + 6), 0, 0)
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  if tipText then tip(cb, label, tipText) end
  cb.Update = function() cb:SetChecked(get() and true or false) end
  return cb
end

-- label  [-] value [+]
local function Stepper(parent, x, y, label, min, max, step, fmt, get, set, tipText)
  local s = CreateFrame("Frame", nil, parent)
  s:SetSize(420, 24)
  s:SetPoint("TOPLEFT", x, y)
  s.label = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  s.label:SetPoint("LEFT", 4, 0)
  s.label:SetText(label)
  local minus = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
  minus:SetSize(24, 20)
  minus:SetPoint("LEFT", 240, 0)
  minus:SetText("-")
  s.value = s:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  s.value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
  s.value:SetWidth(90)
  HoverLabel(s, s.label, label, tipText)
  local plus = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
  plus:SetSize(24, 20)
  plus:SetPoint("LEFT", s.value, "RIGHT", 4, 0)
  plus:SetText("+")
  local function show() s.value:SetText(fmt:format(get())) end
  local function change(d) set(math.max(min, math.min(max, get() + d))) show() end
  minus:SetScript("OnClick", function() change(IsShiftKeyDown() and -step * 5 or -step) end)
  plus:SetScript("OnClick", function() change(IsShiftKeyDown() and step * 5 or step) end)
  s.Update = show
  s.SetEnabled = function(_, on)
    minus:SetEnabled(on) plus:SetEnabled(on)
    s.label:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
    s.value:SetFontObject(on and "GameFontNormal" or "GameFontDisable")
  end
  return s
end

-- (10 Nov) "Label  [A] [B] [C]": a row of choices, one lit. opts = { { value, text, width, tip }, ... }
local function Choices(parent, x, y, label, opts, get, set, tipTitle, labelTip)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(560, 22)
  row:SetPoint("TOPLEFT", x, y)
  row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.label:SetPoint("LEFT", 4, 0)
  row.label:SetText(label)
  HoverLabel(row, row.label, label, labelTip)
  local bx = 150
  row.btns = {}
  for _, o in ipairs(opts) do
    local b = CreateFrame("Button", nil, row, ns.BACKDROP_TMPL)
    b:SetSize(o[3] or 80, 20)
    b:SetPoint("LEFT", bx, 0)
    bx = bx + (o[3] or 80) + 3
    b:SetBackdrop(ns.SLOT_BACKDROP)
    b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(o[2])
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3) hl:SetPoint("BOTTOMRIGHT", -3, 3)
    hl:SetColorTexture(1, 1, 1, 0.08)
    b:SetScript("OnClick", function(self) if self.usable ~= false then set(o[1]) row.Update() end end)
    if o[4] then tip(b, (tipTitle and (tipTitle .. ": ") or "") .. o[2], o[4]) end
    b.value = o[1]
    row.btns[#row.btns + 1] = b
  end
  -- usable(value): false greys that choice out (it stays visible, its tooltip says why)
  row.Update = function()
    local cur = get()
    for _, b in ipairs(row.btns) do
      local on = b.value == cur
      local ok = not row.usable or row.usable(b.value)
      b.usable = ok
      b:SetBackdropColor(on and 0.32 or 0.06, on and 0.24 or 0.06, on and 0.02 or 0.06, 0.95)
      b:SetBackdropBorderColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.3)
      b.text:SetFontObject(ok and "GameFontHighlightSmall" or "GameFontDisableSmall")
    end
  end
  return row
end

-- "Key:  [ F ]": click it, press a key (with Shift / Ctrl / Alt if you like) and it's bound;
-- Esc cancels, right-click clears. The game's own keybindings show the same key.
local IGNORE = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }
local listening -- the key button waiting for a key
-- Setting a key, carefully: click the button, press the key, then say Yes to
-- "Put <this> on <key>? <key> now does <that>". Nothing changes before that Yes.
-- Waiting for a key stops by itself after 8 seconds, on Escape, or on any click elsewhere.
-- /ruck undokey puts back what the last change replaced.
local function bindingName(act)
  if not act or act == "" or act == "NONE" then return nil end
  local n = _G["BINDING_NAME_" .. act]
  if n then return n end
  local bar, num = act:match("^(%u+)BUTTON(%d+)$")
  local BARS = { ACTION = "Action bar", MULTIACTIONBAR1 = "Bottom left bar", MULTIACTIONBAR2 = "Bottom right bar",
    MULTIACTIONBAR3 = "Right bar", MULTIACTIONBAR4 = "Right bar 2" }
  if bar and BARS[bar] then return BARS[bar] .. " button " .. num end
  return act
end
StaticPopupDialogs["RUCKSACK_BIND"] = {
  text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
  showAlert = true, preferredIndex = 3,
  OnAccept = function(self, data) if data and data.fn then data.fn() end end,
}
local lastKeyChange
function ns.UndoKey()
  local u = lastKeyChange
  if not u then Print("no key change to undo.") return end
  if InCombatLockdown() then Print("keys can't be changed in combat.") return end
  for _, k in ipairs({ GetBindingKey(u.action) }) do SetBinding(k) end
  for _, k in ipairs(u.oldKeys) do SetBinding(k, u.action) end
  if u.key and u.replaced then SetBinding(u.key, u.replaced) end
  SaveBindings(GetCurrentBindingSet())
  lastKeyChange = nil
  Print("key change undone" .. (u.key and u.replaced and (": |cffffd100" .. GetBindingText(u.key) .. "|r is " .. bindingName(u.replaced) .. " again.") or "."))
end
local listenEnd = CreateFrame("Frame")
local function KeyButton(parent, x, y, label, action, tipText)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(420, 24)
  holder:SetPoint("TOPLEFT", x, y)
  local fs = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("LEFT", 4, 0)
  fs:SetText(label)
  HoverLabel(holder, fs, label, tipText and (tipText .. "\n\nClick the button, press the key you want, then say Yes. Right-click the button: take the key off.") or nil)
  local b = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
  b:SetSize(160, 22)
  b:SetPoint("LEFT", 240, 0)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local function show()
    if listening == b then b:SetText("|cffffd100Press a key|r (Esc: no)") return end
    local key = GetBindingKey(action)
    b:SetText(key and GetBindingText(key) or "|cff999999Set key|r")
  end
  local function stop()
    if listening == b then
      listening = nil
      listenEnd:UnregisterAllEvents()
      listenEnd:SetScript("OnEvent", nil)
    end
    b:EnableKeyboard(false)
    show()
  end
  b.stopListening = stop
  local function apply(key)
    if InCombatLockdown() then Print("keys can't be changed in combat.") return end
    local change = { action = action, key = key, oldKeys = { GetBindingKey(action) } }
    if key then
      local was = GetBindingAction(key)
      if was and was ~= "" and was ~= action then change.replaced = was end
    end
    for _, k in ipairs(change.oldKeys) do SetBinding(k) end
    if key then SetBinding(key, action) end
    SaveBindings(GetCurrentBindingSet())
    lastKeyChange = change
    if key then
      Print(label .. " is now on |cffffd100" .. GetBindingText(key) .. "|r." ..
        (change.replaced and (" (It was " .. bindingName(change.replaced) .. ": |cffffd100/ruck undokey|r puts it back.)") or ""))
    else
      Print(label .. " has no key now. |cffffd100/ruck undokey|r puts it back.")
    end
    show()
  end
  local function ask(key)
    local text
    if key then
      local was = GetBindingAction(key)
      local wasName = (was ~= action) and bindingName(was)
      text = ("Put |cffffd100%s|r on the key |cffffd100%s|r?"):format(label, GetBindingText(key)) ..
        (wasName and ("\n\n|cffff8080%s now does: %s|r\nThat will stop working."):format(GetBindingText(key), wasName) or "")
    else
      local k = GetBindingKey(action)
      if not k then return end
      text = ("Take the key |cffffd100%s|r off %s?"):format(GetBindingText(k), label)
    end
    StaticPopup_Show("RUCKSACK_BIND", text, nil, { fn = function() apply(key) end })
  end
  b:SetScript("OnClick", function(self, mouse)
    if listening and listening ~= self and listening.stopListening then listening.stopListening() end
    if mouse == "RightButton" then stop() ask(nil) return end
    if listening == self then stop() return end -- (a second click: never mind)
    listening = self
    self:EnableKeyboard(true)
    if self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, false) end
    show()
    -- stop waiting by itself: after 8 seconds, or on a click anywhere else
    local mine = {}
    self.listenToken = mine
    C_Timer.After(8, function() if listening == self and self.listenToken == mine then stop() end end)
    listenEnd:RegisterEvent("GLOBAL_MOUSE_DOWN")
    listenEnd:SetScript("OnEvent", function()
      if listening == self and not self:IsMouseOver() then stop() end
    end)
  end)
  b:SetScript("OnKeyDown", function(self, key)
    if listening ~= self then return end
    if IGNORE[key] then return end
    if key == "ESCAPE" then stop() return end
    local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    stop()
    ask(combo)
  end)
  b:SetScript("OnHide", function() stop() end)
  tip(b, label, (tipText or "") .. "\nClick, press a key, then say Yes. Nothing changes before the Yes.\nRight-click: take the key off (asks first). |cffffd100/ruck undokey|r undoes the last change.")
  holder.Update = show
  return holder
end

-- a scrolling list of items inside a page; click one to open its settings
local ROW_H = 24
local function List(parent, y)
  local box = CreateFrame("Frame", nil, parent, ns.BACKDROP_TMPL)
  box:SetPoint("TOPLEFT", 0, y)
  box:SetPoint("BOTTOMRIGHT", 0, 0)
  box:SetBackdrop(ns.SLOT_BACKDROP)
  box:SetBackdropColor(0, 0, 0, 0.5)
  box:SetBackdropBorderColor(0.4, 0.4, 0.4)
  local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 5, -5)
  scroll:SetPoint("BOTTOMRIGHT", -27, 5)
  if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local v = self:GetVerticalScroll() - delta * ROW_H * 3
    self:SetVerticalScroll(math.max(0, math.min(v, self:GetVerticalScrollRange())))
  end)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, 1)
  scroll:SetScrollChild(child)
  local rows = {}
  local empty = child:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 6, -6)
  empty:SetWidth(360)
  empty:SetJustifyH("LEFT")
  local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, child)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 2, 0)
    r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", -120, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.delBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
    r.delBtn:SetSize(56, 18)
    r.delBtn:SetPoint("RIGHT", -4, 0)
    r.delBtn:SetText("Remove")
    r.delBtn:SetScript("OnClick", function()
      if r.onRemove then r.onRemove() end
    end)
    r.delBtn:Hide()
    r.tag = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    r.tag:SetPoint("RIGHT", -4, 0)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, btn)
      if btn == "RightButton" and self.onRemove then
        self.onRemove()
      elseif self.key then
        Rucksack_Open(self.key)
      end
    end)
    r:SetScript("OnEnter", function(self) if self.itemID then ns.ShowItemTooltip(self, self.itemID) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
  end
  function box:Set(entries, emptyText)
    child:SetWidth(scroll:GetWidth() > 0 and scroll:GetWidth() or 360)
    for i, e in ipairs(entries) do
      local r = row(i)
      r.key, r.itemID, r.onRemove = e.key, e.itemID, e.onRemove
      r.icon:SetTexture(e.icon)
      r.icon:SetDesaturated(e.dim and true or false)
      r.text:SetFontObject(e.dim and "GameFontDisableSmall" or "GameFontHighlightSmall")
      r.text:SetText(e.text)
      r.tag:SetText(e.tag or "")
      if e.onRemove then
        r.delBtn:SetText(e.removeLabel or "Remove")
        r.delBtn:Show()
        r.tag:SetPoint("RIGHT", r.delBtn, "LEFT", -6, 0)
      else
        r.delBtn:Hide()
        r.tag:SetPoint("RIGHT", -4, 0)
      end
      r:Show()
    end
    for i = #entries + 1, #rows do rows[i]:Hide() end
    empty:SetText(#entries == 0 and emptyText or "")
    child:SetHeight(math.max(1, #entries * ROW_H))
  end
  return box
end

local function Page()
  local p = CreateFrame("Frame", nil, right)
  p:SetPoint("TOPLEFT", 12, -12)
  p:SetPoint("BOTTOMRIGHT", -12, 12)
  p:Hide()
  p.updates = {}
  function p:Add(w) self.updates[#self.updates + 1] = w.Update return w end
  return p
end
-- (10 Nov) "?": opens the Guide at this page's section
local function GuideButton(p, section)
  local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  b:SetSize(24, 22)
  b:SetPoint("TOPRIGHT", 0, 0)
  b:SetText("?")
  b:SetScript("OnClick", function() Rucksack_Open("guide", section) end)
  tip(b, "Guide", "What everything on this page does.")
  return b
end
-- a tool page's top line: its name, and its Enable box on the right
local function ToolHeader(p, name, get, set, tipText)
  Text(p, 0, -2, "GameFontNormalLarge"):SetText(name)
  local cb = Check(p, 300, 0, "Enable", tipText, get, set, "GameFontNormal")
  p:Add(cb)
  return cb
end
local function ItemHeader(p, backKey, backLabel)
  local icon = CreateFrame("Button", nil, p)
  icon:SetSize(40, 40)
  icon:SetPoint("TOPLEFT", 0, 0)
  icon.tex = icon:CreateTexture(nil, "ARTWORK")
  icon.tex:SetAllPoints()
  icon:SetScript("OnEnter", function(self) if p.id then ns.ShowItemTooltip(self, p.id, p.link) end end)
  icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  p.icon = icon
  p.name = Text(p, 50, -2, "GameFontNormalLarge", 300)
  p.sub = Text(p, 50, -24, "GameFontDisableSmall", 300)
  local back = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  back:SetSize(110, 22)
  back:SetPoint("TOPRIGHT", 0, 0)
  back:SetText("< " .. backLabel)
  back:SetScript("OnClick", function() Rucksack_Open(backKey) end)
end

local pages = {}
local current -- "general", "eat", "del", "food:<id>", "del:<id>"

-- (1.7) the widgets, for the modules' own pages
ns.UI = {
  tip = tip, HoverLabel = HoverLabel, Text = Text, TipText = TipText, Check = Check, Stepper = Stepper,
  Choices = Choices, KeyButton = KeyButton, List = List, Page = Page, GuideButton = GuideButton,
  ToolHeader = ToolHeader, ItemHeader = ItemHeader, pages = pages,
}

-- (1.7) ticking a module loads it now; unticking needs a reload (the game can't unload code)
StaticPopupDialogs["RUCKSACK_RELOAD"] = {
  text = "%s\n\nReload now?",
  button1 = "Reload", button2 = "Later",
  OnAccept = function() ReloadUI() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
local WHY = {
  DISABLED = "it's unticked in the game's AddOns list (character select): tick it there",
  MISSING = "its folder isn't installed",
  DEP_MISSING = "Rucksack itself is missing",
  INTERFACE_VERSION = "it's marked out of date: tick \"Load out of date AddOns\"",
}
function ns.WhyNot(m) return WHY[m.why or ""] or (m.why and ("the game says: " .. tostring(m.why))) or nil end
function ns.SetModule(m, on)
  ns.SetModuleWanted(m.key, on)
  if on then
    if ns.Has(m.key) then return end
    if InCombatLockdown() then Print(m.name .. " loads after this fight (or on your next reload).") return end
    local ok = ns.LoadModule(m)
    if ok then Print(m.name .. " is loaded.")
    else Print(m.name .. " couldn't load: " .. (ns.WhyNot(m) or "unknown reason") .. ".") end
    ns.Changed()
  elseif ns.Has(m.key) then
    StaticPopup_Show("RUCKSACK_RELOAD", m.name .. " is turned off. It stops loading after a reload; until then it keeps running.")
  end
  ns.Changed()
end
-- a page for a module that isn't loaded
do
  local p = Page()
  pages.missing = p
  p.title = Text(p, 0, -2, "GameFontNormalLarge")
  p.body = Text(p, 0, -34, "GameFontHighlight", 600)
  local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  b:SetSize(160, 24)
  b:SetPoint("TOPLEFT", 0, -90)
  b:SetText("Turn it on")
  b:SetScript("OnClick", function() if p.mod then ns.SetModule(p.mod, true) end end)
  p.updates[#p.updates + 1] = function()
    local m = p.mod
    if not m then return end
    p.title:SetText(m.name .. "  |cff999999off|r")
    local why = ns.ModuleWanted(m.key) and ns.WhyNot(m)
    p.body:SetText(m.name .. " (" .. m.what .. ") is a module you can turn on or off in Settings. It's off right now, so it isn't loaded and uses nothing." ..
      (why and ("\n\n|cffff8080It's ticked but couldn't load: " .. why .. ".|r") or "\n\nClick below to turn it on: it loads right away, no reload needed."))
  end
end

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
do
  local p = Page()
  pages.general = p
  GuideButton(p, "general")
  Text(p, 0, -2, "GameFontNormalLarge"):SetText("Settings")
  Text(p, 0, -28, "GameFontHighlightSmall", 440):SetText("The minimap button, the key that opens Rucksack, the tools on or off, and the Pocket.")
  local y = -62
  p:Add(Check(p, 0, y, "Show the minimap button", "Left-click: open Rucksack. Drag it around the minimap.",
    function() return not ns.db.minimapHidden end,
    function(v) ns.db.minimapHidden = not v or nil ns.UpdateMinimapButton() end))
  y = y - 34
  p:Add(KeyButton(p, 0, y, "Open Rucksack", "AUTODELETE_TOGGLE", "A key that opens and closes this window."))
  y = y - 44
  -- (1.7) modules: tick the parts you want. Unticked = not loaded at all.
  local mh = Text(p, 0, y, "GameFontNormal")
  mh:SetText("Modules")
  HoverLabel(p, mh, "Modules", "Rucksack comes with all its parts, but only loads the ones ticked here. An unticked part isn't loaded at all: no memory, no work.\n\nTicking one loads it right away. Unticking one needs a reload.")
  Text(p, 100, y - 1, "GameFontDisableSmall", 500):SetText("only ticked parts are loaded  ·  ticking loads it now, unticking needs a reload")
  y = y - 22
  for _, m in ipairs(ns.MODULES) do
    local cb = p:Add(Check(p, 0, y, m.name .. "  |cff999999" .. m.what .. "|r", nil,
      function() return ns.ModuleWanted(m.key) end, function(v) ns.SetModule(m, v) end))
    local state = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    state:SetPoint("LEFT", cb, "LEFT", 380, 1)
    tip(cb, m.name, m.what .. ". Ticked: loaded. Unticked: not loaded at all (after a reload).")
    p.updates[#p.updates + 1] = function()
      local has, want = ns.Has(m.key), ns.ModuleWanted(m.key)
      if has and want then state:SetText("|cff66dd66loaded|r")
      elseif has then state:SetText("|cffffd100off after reload|r")
      elseif want then state:SetText("|cffff8080couldn't load|r")
      else state:SetText("|cff999999not loaded|r") end
    end
    y = y - 24
  end
  p:Add(Check(p, 0, y, "Just for this character  |cff999999(otherwise the same on all your characters)|r",
    "Ticked: this character has its own module choices (say, the Faire only on your main).",
    function() return ns.char.ownModules end, function(v)
      ns.char.ownModules = v or nil
      if v then
        ns.char.modules = ns.char.modules or {}
        for _, m in ipairs(ns.MODULES) do if ns.char.modules[m.key] == nil then ns.char.modules[m.key] = ns.db.modules == nil or ns.db.modules[m.key] ~= false end end
      end
      ns.Changed()
    end, "GameFontHighlightSmall"))
  y = y - 10
  -- the Pocket
  y = y - 44
  Text(p, 0, y, "GameFontNormal"):SetText("The Pocket")
  Text(p, 100, y - 1, "GameFontDisableSmall", 500):SetText("a small window that stays on screen  ·  /ruck pocket  ·  right-click the minimap button")
  y = y - 22
  local O = function() return ns.db.pocket end
  local function apply() if ns.Pocket then ns.Pocket.Apply() end end
  p:Add(Check(p, 0, y, "Show the Pocket", "Bag space, what a vendor would pay, your next food and water, and what's waiting to be deleted. Click a line to open its page.",
    function() return O().shown end, function(v) ns.Pocket.SetShown(v) end))
  p:Add(Check(p, 230, y, "Lock it in place", "Locked: it can't be dragged by accident.",
    function() return O().locked end, function(v) O().locked = v end))
  y = y - 26
  p:Add(Check(p, 0, y, "Hide it in combat", "Out of the way while you fight; back when the fight ends.",
    function() return O().hideInCombat end, function(v) O().hideInCombat = v apply() end))
  y = y - 30
  p:Add(Stepper(p, 0, y, "Size", 60, 160, 10, "%d%%",
    function() return math.floor((O().scale or 1) * 100 + 0.5) end, function(v) O().scale = v / 100 apply() end,
    "How big the Pocket is: 100% is normal. Shift-click - or + to change it faster."))
  y = y - 32
  local POCKET_TIPS = {
    bags = "Free bag slots out of all you have, with a bar that fills up as your bags do.",
    sell = "What a vendor would pay you right now for what Rucksack sells (hover the line for the list).",
    food = "The food the eat button uses next, and how many you have.",
    water = "The water the eat button uses next, and how many you have.",
    del = "How many stacks are waiting to be deleted, and which one goes next.",
    faire = "Your Darkmoon tickets, or the prize you track (37/50). Only while the Faire tool is on.",
    scrolls = "Undeciphered mage scrolls in your bags, and how many you can read now.",
  }
  local linesLabel = Text(p, 0, y, "GameFontHighlight")
  linesLabel:SetText("Lines")
  HoverLabel(p, linesLabel, "Lines", "Which lines the Pocket shows. Untick the ones you don't need.")
  local x = 60
  for _, l in ipairs(ns.Pocket.LINES) do
    p:Add(Check(p, x, y + 5, l.name, POCKET_TIPS[l.key],
      function() return O().lines[l.key] ~= false end, function(v) O().lines[l.key] = v apply() end, "GameFontHighlightSmall"))
    x = x + 105
  end
end

---------------------------------------------------------------------------
-- Home (10 Nov): everything at a glance; a card opens its tool
---------------------------------------------------------------------------
do
  local p = Page()
  pages.home = p
  GuideButton(p, "home")
  Text(p, 0, -2, "GameFontNormalLarge"):SetText("|cffc8a165Ruck|r|cffffd100sack|r")
  Text(p, 0, -24, "GameFontDisableSmall", 600):SetText("Rations eats and drinks for you; Clean-up deletes or sells what you don't need; the Faire tracks your Darkmoon tickets. Click a card to open it, or ? for the Guide.")
  -- bag space
  local bagText = Text(p, 0, -54, "GameFontHighlight", 400)
  local bar = CreateFrame("StatusBar", nil, p)
  bar:SetPoint("TOPLEFT", 0, -74)
  bar:SetPoint("RIGHT", -4, 0)
  bar:SetHeight(12)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetMinMaxValues(0, 1)
  local barBg = bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetColorTexture(0, 0, 0, 0.6)
  local bagWarn = Text(p, 0, -90, "GameFontNormalSmall", 600)
  -- a card: a framed box that opens its tool
  local function Card(x, key, titleText, explain)
    local c = CreateFrame("Button", nil, p, ns.BACKDROP_TMPL)
    c:SetPoint("TOPLEFT", x, -114)
    c:SetSize(330, 206)
    c:SetBackdrop(ns.SLOT_BACKDROP)
    c:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    c:SetBackdropBorderColor(0.45, 0.45, 0.45)
    c:SetScript("OnEnter", function(self)
      self:SetBackdropBorderColor(1, 0.82, 0)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(titleText)
      for _, l in ipairs(explain) do GameTooltip:AddDoubleLine(l[1], l[2], 1, 0.82, 0, 1, 1, 1) end
      GameTooltip:AddLine("Click to open it.", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.45, 0.45, 0.45) GameTooltip:Hide() end)
    c:SetScript("OnClick", function() Rucksack_Open(key) end)
    local t = c:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 12, -10)
    t:SetText(titleText)
    c.state = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    c.state:SetPoint("TOPRIGHT", -12, -14)
    c.rows = {}
    function c:Row(i)
      local r = self.rows[i]
      if r then return r end
      r = {}
      r.icon = self:CreateTexture(nil, "ARTWORK")
      r.icon:SetSize(18, 18)
      r.icon:SetPoint("TOPLEFT", 12, -40 - (i - 1) * 26)
      r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      r.label = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      r.label:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      r.value = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      r.value:SetPoint("RIGHT", self, "TOPRIGHT", -12, -49 - (i - 1) * 26)
      r.value:SetPoint("LEFT", r.icon, "RIGHT", 100, 0)
      r.value:SetJustifyH("RIGHT")
      r.value:SetWordWrap(false)
      self.rows[i] = r
      return r
    end
    function c:Set(i, icon, label, value)
      local r = self:Row(i)
      r.icon:SetTexture(icon)
      r.icon:SetShown(icon ~= nil)
      r.label:SetText(label)
      r.value:SetText(value or "")
    end
    return c
  end
  local eatCard = Card(0, "eat", "|cff66dd66Rations|r", {
    { "Next food / water", "what the eat button uses next, and how many" },
    { "Use first", "which food and water it picks first" },
    { "Food level", "which levels it may use" },
    { "Deletes", "the food and water Rations has Clean-up delete" },
  })
  local delCard = Card(340, "del", "|cffff5555Clean-up|r", {
    { "Waiting", "stacks on your list in your bags, and the next one" },
    { "At a vendor", "what a vendor would pay you right now" },
    { "Sold so far", "gold Rucksack has made you by selling" },
    { "Deleted so far", "items Clean-up has deleted" },
  })
  local delNext = CreateFrame("Button", nil, delCard, "UIPanelButtonTemplate")
  delNext:SetSize(120, 22)
  delNext:SetPoint("BOTTOMRIGHT", -10, 10)
  delNext:SetText("Delete next")
  delNext:SetScript("OnClick", function() AutoDelete_DeleteNext() end)
  tip(delNext, "Delete next", "Deletes the next item waiting to go now, full bags or not. (Its key: Clean-up page.)")
  local eatKey = eatCard:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  eatKey:SetPoint("BOTTOMLEFT", 12, 14)
  eatKey:SetWidth(306)
  eatKey:SetJustifyH("LEFT")
  -- notes: what Rucksack is doing on its own
  -- (10 Nov) the Darkmoon Faire: a strip under the cards
  local fc = CreateFrame("Button", nil, p, ns.BACKDROP_TMPL)
  fc:SetPoint("TOPLEFT", 0, -328)
  fc:SetSize(670, 64)
  fc:SetBackdrop(ns.SLOT_BACKDROP)
  fc:SetBackdropColor(0.08, 0.06, 0.1, 0.9)
  fc:SetBackdropBorderColor(0.45, 0.45, 0.45)
  fc:SetScript("OnClick", function() Rucksack_Open("faire") end)
  fc:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(1, 0.82, 0)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("|cffb48cffDarkmoon Faire|r")
    GameTooltip:AddLine("Your tickets, turn-ins you can hand in now, the prize you're saving for, and when the Faire is open. Click to open it.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  fc:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.45, 0.45, 0.45) GameTooltip:Hide() end)
  local fcTitle = fc:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  fcTitle:SetPoint("TOPLEFT", 12, -10)
  fcTitle:SetText("|cffb48cffDarkmoon Faire|r")
  local fcState = fc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fcState:SetPoint("LEFT", fcTitle, "RIGHT", 10, 0)
  local fcLine1 = Text(fc, 12, -34, "GameFontHighlightSmall", 380)
  local fcLine2 = Text(fc, 12, -48, "GameFontDisableSmall", 380)
  local fcIcon = fc:CreateTexture(nil, "ARTWORK")
  fcIcon:SetSize(40, 40)
  fcIcon:SetPoint("TOPLEFT", 420, -12)
  fcIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local fcGoal = Text(fc, 468, -14, "GameFontNormalSmall", 190)
  local fcNum = Text(fc, 468, -30, "GameFontHighlight", 190)
  local fcBarBg = fc:CreateTexture(nil, "ARTWORK")
  fcBarBg:SetPoint("TOPLEFT", 468, -48)
  fcBarBg:SetSize(190, 5)
  fcBarBg:SetColorTexture(0.15, 0.12, 0.2, 1)
  local fcBar = fc:CreateTexture(nil, "OVERLAY")
  fcBar:SetPoint("TOPLEFT", fcBarBg)
  fcBar:SetHeight(5)
  p.updates[#p.updates + 1] = function()
    local F = ns.Faire
    fc:SetShown(ns.Has("faire"))
    if not (F and F.db) then return end
    local on = F.On()
    fcState:SetText(on and "|cff66dd66on|r" or "|cff999999off|r")
    fcLine1:SetText(F.FaireLine())
    local count, waiting = F.ReadyNow()
    fcLine2:SetText(("|cffffd100%d|r tickets"):format(F.Tickets()) .. (count > 0 and ("   |cff66dd66%d ready to hand in (+%d)|r"):format(count, waiting) or "   nothing ready to hand in"))
    local goal = F.Goal and F.Goal()
    if goal then
      local have = F.Tickets()
      fcIcon:SetTexture(F.PrizeIcon(goal))
      fcGoal:SetText(goal.name)
      fcNum:SetText((have >= goal.cost and "|cff66dd66" or "|cffffffff") .. have .. "|r |cff999999/ " .. goal.cost .. "|r")
      fcBar:SetWidth(math.max(1, 190 * math.min(1, have / goal.cost)))
      fcBar:SetColorTexture(have >= goal.cost and 1 or 0.62, have >= goal.cost and 0.82 or 0.42, have >= goal.cost and 0 or 0.85, 1)
      fcBar:Show()
    else
      fcIcon:SetTexture(F.TicketIcon and F.TicketIcon() or nil)
      fcGoal:SetText("No prize tracked")
      fcNum:SetText("|cff999999pick one on the Prizes tab|r")
      fcBar:Hide()
    end
  end
  Text(p, 0, -402, "GameFontNormal"):SetText("Right now")
  local notes = Text(p, 0, -420, "GameFontHighlightSmall", 670)
  notes:SetSpacing(4)
  p:Add(Check(p, 0, -500, "Show the Pocket  |cffaaaaaa(a small window with these numbers, always on screen)|r",
    "Bag space, what a vendor would pay, your next food and water, and what's waiting to be deleted. Drag it where you like; its options are in Settings. Also: /ruck pocket.",
    function() return ns.db.pocket and ns.db.pocket.shown end, function(v) if ns.Pocket then ns.Pocket.SetShown(v) end end))
  p.updates[#p.updates + 1] = function()
    local S = ns.Summary()
    bagText:SetText(("Bag space:  |cffffffff%d|r of %d free"):format(S.free, S.total))
    local used = S.total > 0 and (S.total - S.free) / S.total or 0
    bar:SetValue(used)
    if S.free < S.minFree then bar:SetStatusBarColor(0.9, 0.25, 0.2)
    elseif S.free < S.minFree + 4 then bar:SetStatusBarColor(0.95, 0.75, 0.15)
    else bar:SetStatusBarColor(0.3, 0.75, 0.35) end
    bagWarn:SetText(S.free < S.minFree and ("|cffff6060Nearly full: Clean-up deletes when fewer than %d are free.|r"):format(S.minFree)
      or ("|cff999999Clean-up starts deleting when fewer than %d are free.|r"):format(S.minFree))
    -- (1.7) a card for a module that isn't loaded says so
    local function notLoaded(c, n)
      c.state:SetText("|cff666666not loaded|r")
      for i = 1, n do c:Set(i, nil, i == 1 and "|cff999999Turned off in Settings > Modules: not loaded, uses nothing.|r" or "", "") end
    end
    -- Rations
    local E = ns.eat
    if not ns.Has("eat") then notLoaded(eatCard, 5) eatKey:SetText("") end
    if ns.Has("eat") then
    eatCard.state:SetText(E.enabled ~= false and "|cff66dd66on|r" or "|cff999999off|r")
    local Q = "Interface\\Icons\\INV_Misc_QuestionMark"
    eatCard:Set(1, S.food and ns.GetIcon(S.food) or Q, "Next food", S.food and (ns.NameOf(S.food) .. "  x" .. S.foodCount) or "|cff999999none|r")
    eatCard:Set(2, S.drink and ns.GetIcon(S.drink) or Q, "Next water", S.drink and (ns.NameOf(S.drink) .. "  x" .. S.drinkCount) or "|cff999999none|r")
    local function nameIn(list, v) for _, o in ipairs(list) do if o[1] == v then return o[2] end end return "" end
    eatCard:Set(3, "Interface\\Icons\\INV_Misc_Food_15", "Use first", nameIn(ns.Eat.ORDERS, E.order or "best"))
    eatCard:Set(4, "Interface\\Icons\\INV_Misc_Note_01", "Food level", nameIn(ns.Eat.LEVELS, E.level or "any"))
    eatCard:Set(5, "Interface\\Icons\\INV_Drink_07", "Deletes", S.eatRules)
    eatKey:SetText("Eat and drink: click the on-screen button, or put the |cffffd100EatDrink|r macro on your bars.")
    end
    -- Clean-up
    local D = ns.del
    delNext:SetShown(ns.Has("del"))
    if not ns.Has("del") then notLoaded(delCard, 4) end
    if ns.Has("del") then
    delCard.state:SetText(D.enabled and "|cff66dd66on|r" or "|cff999999off|r")
    delCard:Set(1, S.nextDel and (S.nextDel.icon or ns.GetIcon(S.nextDel.id)) or "Interface\\Icons\\INV_Misc_Bag_10_Red", "Waiting",
      S.waitStacks > 0 and (S.waitStacks .. (S.waitStacks == 1 and " stack" or " stacks") .. (S.nextDel and ("  ·  next: " .. ns.NameOf(S.nextDel.id)) or "")) or "|cff999999nothing|r")
    delCard:Set(2, "Interface\\Icons\\INV_Misc_Coin_02", "At a vendor", S.sellCount > 0 and (ns.Sell.Money(S.sellValue) .. "  (" .. S.sellCount .. " items)")
      or ((D.sellGrey or D.sellList) and "|cff999999nothing to sell|r" or "|cff999999selling is off|r"))
    delCard:Set(3, "Interface\\Icons\\INV_Misc_Coin_01", "Sold so far", ns.Sell.Money(D.soldGold or 0))
    delCard:Set(4, "Interface\\Icons\\Ability_Rogue_Disembowel", "Deleted so far", (D.deleted or 0) .. " items")
    delNext:SetEnabled(S.waitAny and true or false)
    end
    notes:SetText(#S.notes > 0 and ("·  " .. table.concat(S.notes, "\n·  ")) or "|cff999999Nothing special: your bags have room and nothing is being kept back.|r")
  end
end

---------------------------------------------------------------------------
-- Guide (10 Nov): what every part does (the text is in Guide.lua)
---------------------------------------------------------------------------
do
  local p = Page()
  pages.guide = p
  Text(p, 0, -2, "GameFontNormalLarge"):SetText("Guide")
  Text(p, 70, -6, "GameFontDisableSmall", 560):SetText("What every part of Rucksack does. Hover an option in the window for a short tip too.")
  local box = CreateFrame("Frame", nil, p, ns.BACKDROP_TMPL)
  box:SetPoint("TOPLEFT", 0, -60)
  box:SetPoint("BOTTOMRIGHT", 0, 0)
  box:SetBackdrop(ns.SLOT_BACKDROP)
  box:SetBackdropColor(0, 0, 0, 0.5)
  box:SetBackdropBorderColor(0.4, 0.4, 0.4)
  local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local v = self:GetVerticalScroll() - delta * 60
    self:SetVerticalScroll(math.max(0, math.min(v, self:GetVerticalScrollRange() or 0)))
  end)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(630, 100)
  scroll:SetScrollChild(child)
  local parts, prev = {}, nil
  for _, sec in ipairs(ns.GUIDE) do
    local h = child:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    if prev then h:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -22) else h:SetPoint("TOPLEFT", 4, -4) end
    h:SetJustifyH("LEFT")
    h:SetText(sec.title)
    local b = child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    b:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8)
    b:SetWidth(620)
    b:SetJustifyH("LEFT")
    b:SetSpacing(3)
    b:SetText(sec.text)
    parts[#parts + 1] = { key = sec.key, head = h, body = b }
    prev = b
  end
  -- each section's distance from the top (from the text's own height: works before it's drawn)
  local function layout()
    local y, at = 4, {}
    for _, pt in ipairs(parts) do
      at[pt.key] = y
      y = y + (pt.head:GetStringHeight() or 18) + 8 + (pt.body:GetStringHeight() or 0) + 22
    end
    child:SetHeight(y)
    return at
  end
  -- buttons that jump to a section
  local jumps = { { "home", "Home" }, { "eat", "Rations" }, { "del", "Clean-up" }, { "sell", "Selling" }, { "pocket", "Pocket" }, { "general", "Commands" } }
  local function jump(key)
    local at = layout()
    local function go()
      local y = at[key] or 0
      scroll:SetVerticalScroll(math.max(0, math.min(y - 4, scroll:GetVerticalScrollRange() or y)))
    end
    go()
    C_Timer.After(0, go) -- (again once the scroll range knows the new height)
  end
  local x = 0
  for _, j in ipairs(jumps) do
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(96, 22)
    b:SetPoint("TOPLEFT", x, -30)
    b:SetText(j[2])
    b:SetScript("OnClick", function() jump(j[1]) end)
    x = x + 100
  end
  p.updates[#p.updates + 1] = function()
    local key = p.jumpTo or "home"
    p.jumpTo = nil
    jump(key)
  end
end

---------------------------------------------------------------------------
-- The sidebar: Home and the tools; Settings at the bottom
---------------------------------------------------------------------------
local TOOLS = {
  { key = "home", icon = ns.ICON, name = "Home" },
  { key = "eat", icon = "Interface\\Icons\\INV_Misc_Food_15", name = "Rations", on = function() return ns.eat and ns.eat.enabled ~= false end },
  { key = "del", icon = "Interface\\Icons\\INV_Misc_Bag_10_Red", name = "Clean-up", on = function() return ns.del and ns.del.enabled end },
  { key = "faire", icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(19182)) or "Interface\\Icons\\INV_Misc_Coin_01",
    name = "Faire", on = function() return ns.Faire and ns.Faire.On and ns.Faire.On() end },
  { key = "scrolls", icon = "Interface\\Icons\\INV_Scroll_03", name = "Scrolls", on = function() return ns.Scrolls and ns.Scrolls.db and ns.Scrolls.db.button ~= false end },
  { key = "guide", icon = "Interface\\Icons\\INV_Misc_Book_09", name = "Guide", bottom = 2 },
  { key = "general", icon = "Interface\\Icons\\INV_Misc_Gear_01", name = "Settings", bottom = 1 },
}
local sideRows = {}
for i, t in ipairs(TOOLS) do
  local r = CreateFrame("Button", nil, side)
  r:SetHeight(34)
  if t.bottom then r:SetPoint("BOTTOMLEFT", 6, 6 + (t.bottom - 1) * 36) else r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 36) end
  r:SetPoint("RIGHT", -6, 0)
  r.sel = r:CreateTexture(nil, "BACKGROUND")
  r.sel:SetAllPoints()
  r.sel:SetColorTexture(1, 0.82, 0, 0.18)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(26, 26)
  r.icon:SetPoint("LEFT", 4, 0)
  r.icon:SetTexture(t.icon)
  r.text = r:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
  r.text:SetText(t.name)
  r.tag = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.tag:SetPoint("RIGHT", -6, 0)
  r:SetScript("OnClick", function() Rucksack_Open(t.key) end)
  r.tool = t
  sideRows[i] = r
end
local function buildSide()
  local kind = (current or ""):match("^(%a+):")
  local lit = kind == "food" and "eat" or (kind == "del" or kind == "delq") and "del" or current
  for _, r in ipairs(sideRows) do
    r.sel:SetShown(r.tool.key == lit)
    if r.tool.on and not ns.Has(r.tool.key) then
      -- (1.7) a module that isn't loaded
      r.tag:SetText("|cff666666not loaded|r")
      r.icon:SetDesaturated(true)
      r.text:SetTextColor(0.5, 0.5, 0.5)
    elseif r.tool.on then
      local on = r.tool.on()
      r.tag:SetText(on and "|cff66dd66on|r" or "|cff999999off|r")
      r.icon:SetDesaturated(not on)
      r.text:SetTextColor(1, 0.82, 0)
    end
  end
end

local function showPage()
  for _, p in pairs(pages) do p:Hide() end
  local kind, id = (current or ""):match("^(%a+):(%d+)$")
  local p
  -- (1.7) a module's page when that module isn't loaded
  local mod
  for _, m in ipairs(ns.MODULES) do
    if (current == m.key or (m.key == "eat" and kind == "food") or (m.key == "del" and (kind == "del" or kind == "delq"))) and not ns.Has(m.key) then mod = m end
  end
  if mod then
    p = pages.missing p.mod = mod
  elseif kind == "food" then
    p = pages.food p.id = tonumber(id)
  elseif kind == "del" then
    p = pages.delItem p.id = tonumber(id)
    if not ns.del.items[p.id] then current = "del" p = pages.del end
  elseif kind == "delq" then
    local n = tonumber(id)
    ns.del.keep[n] = (not ns.del.keep[n]) or nil
    Print(ns.NameOf(n) .. (ns.del.keep[n] and " will be kept." or " goes again with its quality."))
    current = "del"
    p = pages.del
  else
    p = pages[current] or pages.home
  end
  for _, fn in ipairs(p.updates) do fn() end
  p:Show()
end

local function refresh()
  if not f:IsShown() then return end
  buildSide()
  showPage()
end
table.insert(ns.listeners, refresh)

function Rucksack_Open(key, section)
  current = key or current or "home"
  if current == "guide" and pages.guide then pages.guide.jumpTo = section end
  if not f:IsShown() then
    if ns.Eat then ns.Eat.Update(false) end
    f:Show()
  end
  refresh()
end
function Rucksack_Toggle()
  if f:IsShown() then f:Hide() else Rucksack_Open() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:SetScript("OnEvent", function() refresh() end)