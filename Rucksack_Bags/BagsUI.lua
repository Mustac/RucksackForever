-- Rucksack / Bags: the settings page
local ns = Rucksack
if not ns or not ns.UI then return end
local UI = ns.UI
local Text, Check, Page, GuideButton, tip, HoverLabel = UI.Text, UI.Check, UI.Page, UI.GuideButton, UI.tip, UI.HoverLabel
local B = ns.Bags
local function D() return B.db end

local p = Page()
UI.pages.bags = p
GuideButton(p, "bags")
Text(p, 0, -2, "GameFontNormalLarge"):SetText("|cffd9a35aBags|r")
Text(p, 0, -28, "GameFontHighlightSmall", 640):SetText("One bag window instead of the game's bags. Pick an item up and every group gets a slot at its end: drop it there and it goes in that group from now on. The boxes on the right of the bag take what you want sold, thrown away or sent to your bank. Make your own groups with the + next to your bags; the padlock beside it locks the layout.")
local open = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
open:SetSize(110, 22)
open:SetPoint("TOPRIGHT", -34, 0)
open:SetText("Open my bags")
open:SetScript("OnClick", function() B.Toggle() end)

local y = -64
p:Add(Check(p, 0, y, "Bags row open", "The row under the bag's header: your four bags and the reagent bag (free slots, hover one to see its slots, drop a bag on a bag to swap), then New group, Delete group and the padlock. Hover Rucksack in the bag's corner: the arrow opens and closes it too.",
  function() return D().barOpen end, function(v) if (v and true or false) ~= (D().barOpen and true or false) then B.ToggleBar() end end, "GameFontHighlightSmall"))
p:Add(Check(p, 165, y, "Every empty slot", "On: each empty slot is shown, so you can drop an item on any of them. Off: one cell with the number of free slots (a smaller bag).",
  function() return D().emptyAll ~= false end, function(v) D().emptyAll = v and true or false B.Draw() end, "GameFontHighlightSmall"))
p:Add(Check(p, 470, y, "Bag sounds", "The game's own sound when the bag opens and closes.",
  function() return D().sound ~= false end, function(v) D().sound = v and true or false end, "GameFontHighlightSmall"))
p:Add(Check(p, 330, y, "\"New\" group", "Items you just got sit in a New group at the front, with a gold frame, until you've pointed at them or closed the bag.",
  function() return D().showNew ~= false end, function(v) D().showNew = v and true or false B.Draw() end, "GameFontHighlightSmall"))
y = y - 24
p:Add(Check(p, 0, y, "Reagents into the reagent bag", "A reagent lying in one of your ordinary bags is moved into your reagent bag by itself when there's room there (onto a half-full stack of it first, then an empty slot). Only in Groups: in One bag nothing moves by itself. Never in a fight, never while you hold an item.",
  function() return D().reagentHome ~= false end, function(v) D().reagentHome = v and true or false if v then B.ReagentsHome() end end, "GameFontHighlightSmall"))
-- (19 Nov: "Restock by itself at vendors" is gone: each item on the Restock list has its own tick)
p:Add(Check(p, 330, y, "Item bar", "A small bar that stays on screen, bag open or not. Drop an item on it (a green + slot opens where your mouse is): it shows how many you carry in all your bags together. Drag \"Track\" on top to move it, click it for its settings: clickable (click an item to use it) or click-through, row or column, lock, remove items.",
  function() return B.ItemBar and B.ItemBar.DB() and B.ItemBar.DB().on end, function(v) if B.ItemBar then B.ItemBar.Set(v) end end, "GameFontHighlightSmall"))
-- (19 Nov) the game's bag bar (bottom right) hidden
p:Add(Check(p, 470, y, "Hide the game's bag buttons", "The game's backpack and bag slots at the bottom right are hidden: Rucksack's bags row (the arrow next to Rucksack in the bag's corner) has the same slots. On to start. Unticked, they come back right away.",
  function() return D().hideBagBar ~= false end, function(v)
    D().hideBagBar = v and true or false
    if B.ApplyBagBar then pcall(B.ApplyBagBar) end
  end, "GameFontHighlightSmall"))
y = y - 24
-- (1.9) the quiver
p:Add(Check(p, 0, y, "Quiver beside the bag", "While you wear a quiver or ammo pouch, it gets its own window beside the bag, under Send to bank: your arrows slot by slot and how many you have.",
  function() return D().showQuiver ~= false end, function(v) D().showQuiver = v and true or false B.Changed() end, "GameFontHighlightSmall"))
p:Add(Check(p, 330, y, "Sort into special bags", "An item that fits one of your special bags (arrows in the quiver, shards in the soul bag, herbs in the herb bag, ore in the mining bag...) moves there by itself when there's room: onto a half-full stack first, then an empty slot. Special bags come before the reagent bag. Never in a fight, never while you hold an item.",
  function() return D().specialHome ~= false end, function(v) D().specialHome = v and true or false if v then B.SpecialHome() end end, "GameFontHighlightSmall"))
-- (18 Nov) soul shards your soul bag has no room for are deleted. Everyone sees it; greyed out
-- without a soul bag (he: "show that to all people but have it grayed out if no soul bag equipped")
do
  local cb = Check(p, 520, y, "Delete extra soul shards", "While you wear a soul bag and it's full, a Soul Shard that lands in another bag is deleted at once (on your next key press). While the soul bag has room, shards move into it instead. Shards a quest needs stay.\n\nOn to start. Greyed out and unticked while you're not wearing a soul bag.",
    function() return D().shardTrim ~= false end, function(v) D().shardTrim = v and true or false if ns.Del and ns.Del.Refresh then ns.Del.Refresh() end B.Changed() end, "GameFontHighlightSmall")
  local plain = cb.Update
  cb.Update = function()
    plain()
    local soul = B.HasSpecial and B.HasSpecial("soul") and true or false -- (any slot, the reagent slot too)
    -- (he: "uncheck if you remove soul bag, its automatically on") on to start; without a soul bag it shows
    -- unticked and greyed out, and your choice comes back with the bag
    if soul then cb:Enable() cb.label:SetTextColor(1, 1, 1) else cb:SetChecked(false) cb:Disable() cb.label:SetTextColor(0.5, 0.5, 0.5) end
  end
  p:Add(cb)
end
y = y - 32

-- a row of small buttons, the one in use lit gold
local function choice(label, tipTitle, tipText, opts, get, set, x0)
  local l = Text(p, 0, y - 3, "GameFontHighlight")
  l:SetText(label)
  HoverLabel(p, l, tipTitle, tipText)
  local btns, x = {}, x0 or 130
  for _, o in ipairs(opts) do
    local b = CreateFrame("Button", nil, p, ns.BACKDROP_TMPL)
    b:SetSize(o[3] or 96, 22)
    b:SetPoint("TOPLEFT", x, y)
    x = x + (o[3] or 96) + 4
    b:SetBackdrop(ns.SLOT_BACKDROP)
    b.label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b.label:SetText(o[2])
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3) hl:SetPoint("BOTTOMRIGHT", -3, 3)
    hl:SetColorTexture(1, 1, 1, 0.08)
    b:SetScript("OnClick", function() set(o[1]) B.Draw() ns.Changed() end)
    if o[4] then tip(b, o[2], o[4]) end
    btns[#btns + 1] = { b = b, v = o[1] }
  end
  p.updates[#p.updates + 1] = function()
    for _, e in ipairs(btns) do
      local on = e.v == get()
      e.b:SetBackdropColor(on and 0.32 or 0.06, on and 0.24 or 0.06, on and 0.02 or 0.06, 0.95)
      e.b:SetBackdropBorderColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.3)
    end
  end
  y = y - 30
end
choice("Look", "Look", "How the bag is laid out.", {
  { "groups", "Groups", 96, "Your items in labelled groups: Weapons, Armour, Consumables, Trade goods, your own groups..." },
  { "grid", "One bag", 96, "No groups: your items where they really are. Nothing moves by itself; the Tidy button at the top sorts them once. The boxes on the right stay the same." },
}, function() return D().style end, function(v) D().style = v end)
choice("Groups", "Groups", "With the Groups look: each group on its own row, or side by side.", {
  { "rows", "Rows", 96, "Each group starts on a new row. Easy to read, and to move a group up or down." },
  { "packed", "Packed", 96, "Groups side by side; one that doesn't fit goes to the next row. A smaller bag." },
}, function() return D().layout end, function(v) D().layout = v end)
choice("Stacks", "Stacks", "How several stacks of one item are shown.", {
  { true, "Merged", 96, "All of one item as one icon: 80 ore shows as 80." },
  { false, "Separate", 96, "The real stacks: 20, 20, 20, 20. Use this to split a stack or pick up an exact one." },
}, function() return D().merged end, function(v) D().merged = v end)
local colOpts = {}
for _, n in ipairs({ 8, 10, 12, 14, 16 }) do colOpts[#colOpts + 1] = { n, tostring(n), 40 } end
choice("Columns", "Columns", "How many items wide the bag is.", colOpts, function() return D().cols end, function(v) D().cols = v end)
choice("Size", "Size", "How big the bag is on screen.", {
  { 0.8, "80%", 52 }, { 0.9, "90%", 52 }, { 1, "100%", 52 }, { 1.1, "110%", 52 }, { 1.25, "125%", 52 },
}, function() return D().scale end, function(v) D().scale = v end)
choice("Boxes", "Boxes", "Where the Always sell / delete, Sell / delete once, Send to bank and Quiver windows sit, next to the bag. If the screen ends on that side, they go on the other side.", {
  { "tr", "Top right", 96 }, { "br", "Bottom right", 96 }, { "tl", "Top left", 96 }, { "bl", "Bottom left", 96 },
}, function() return D().sidePos or "tr" end, function(v) D().sidePos = v end)

-- group order: dragged in the bag itself; this puts it back
do
  local l = Text(p, 0, y - 3, "GameFontHighlight")
  l:SetText("Order")
  HoverLabel(p, l, "Order", "Drag a group by its name in the bag to put it where you like: it lifts, and the others slide out of the way. The order is the same for all your characters.")
  Text(p, 130, y - 5, "GameFontDisableSmall", 300):SetText("drag a group by its name in the bag")
  local reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  reset:SetSize(100, 22)
  reset:SetPoint("TOPLEFT", 340, y)
  reset:SetText("Reset order")
  reset:SetScript("OnClick", function() B.ResetOrder() ns.Changed() end)
  tip(reset, "Reset order", "Puts the groups back in the order they came in.")
  -- items you put in a group yourself: all back where Rucksack puts them
  local back = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  back:SetSize(130, 22)
  back:SetPoint("TOPLEFT", 448, y)
  back:SetText("Put items back")
  back:SetScript("OnClick", function()
    local n = 0
    for _ in pairs(D().assign or {}) do n = n + 1 end
    D().assign = {}
    ns.Print(n == 1 and "1 item goes back where Rucksack puts it." or (n .. " items go back where Rucksack puts them."))
    B.Changed()
    ns.Changed()
  end)
  tip(back, "Put items back", "Items you dropped into a group yourself go back where Rucksack puts them by itself. (Junk stays junk: that's Clean-up's list.)")
  y = y - 30
end

-- item tooltips: where else you have it
p:Add(Check(p, 0, y, "Item tooltips: where else you have it  |cff999999(your bank, your other characters)|r",
  "Adds a line to item tooltips, like: Also: Bank 12 · Zyxon 5 · Zyxon bank 20. Rucksack remembers your characters' bags when you play them, and a bank each time you open it.",
  function() return D().tipWhere ~= false end, function(v) D().tipWhere = v and true or false end))
y = y - 30

-- which groups show (the others' items go to Everything else)
local sl = Text(p, 0, y, "GameFontNormal")
sl:SetText("Groups shown")
Text(p, 110, y - 1, "GameFontDisableSmall", 520):SetText("unticked: those items go to Everything else")
y = y - 22
local n = 0
for _, c in ipairs(B.CATS) do
  if c.key ~= "other" and c.key ~= "new" and c.key ~= "junk" and not c.key:find("^empty") then
    p:Add(Check(p, (n % 4) * 165, y - math.floor(n / 4) * 24, c.name, nil,
      function() return D().cats[c.key] ~= false end,
      function(v) D().cats[c.key] = v and true or false B.Draw() end, "GameFontHighlightSmall"))
    n = n + 1
  end
end

-- (1.9.1) special bag colours: a square per kind; click it for a small palette (the game's own colour
-- picker is a game window, and Rucksack never opens those)
y = y - math.ceil(n / 4) * 24 - 6
local cl = Text(p, 0, y, "GameFontNormal")
cl:SetText("Special bags")
Text(p, 150, y - 1, "GameFontDisableSmall", 480):SetText("click a colour: its colour, one tile per item or slot by slot")
p:Add(Check(p, 470, y + 3, "Colour their slots", "Slots in a special bag get a light tint and a thin border in its colour, so you see at a glance which bag they're in.",
  function() return D().specialTint ~= false end, function(v) D().specialTint = v and true or false B.Draw() end, "GameFontHighlightSmall"))
y = y - 21
local PICK = { { 0.35, 0.82, 0.38 }, { 0.20, 0.60, 0.25 }, { 0.66, 0.38, 0.95 }, { 0.85, 0.40, 0.85 },
  { 0.38, 0.58, 1 }, { 0.32, 0.86, 0.90 }, { 0.20, 0.40, 0.80 }, { 1, 0.82, 0.25 },
  { 1, 0.58, 0.18 }, { 0.86, 0.52, 0.30 }, { 0.62, 0.44, 0.27 }, { 0.80, 0.63, 0.40 },
  { 0.95, 0.35, 0.35 }, { 0.90, 0.84, 0.58 }, { 0.68, 0.68, 0.74 }, { 0.95, 0.95, 0.95 } }
local palette
local swatches = {}
local function paintSwatches()
  for _, w in ipairs(swatches) do local c = B.SpecialColor(w.key) w.fill:SetColorTexture(c[1], c[2], c[3], 1) end
end
local function setColor(key, c)
  local db = D()
  db.specColors = db.specColors or {}
  db.specColors[key] = c and { c[1], c[2], c[3] } or nil
  if B.RebuildCats then B.RebuildCats() end
  paintSwatches()
  B.Changed()
end
local function openPalette(w)
  if not palette then
    palette = CreateFrame("Frame", "RucksackSpecialPalette", p, ns.BACKDROP_TMPL)
    palette:SetFrameStrata("DIALOG")
    palette:SetSize(8 * 22 + 16, 2 * 22 + 72)
    if palette.SetBackdrop then palette:SetBackdrop(ns.DIALOG_BACKDROP or { bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }) end
    palette:EnableMouse(true)
    palette.cells = {}
    for i, c in ipairs(PICK) do
      local b = CreateFrame("Button", nil, palette)
      b:SetSize(18, 18)
      b:SetPoint("TOPLEFT", 8 + ((i - 1) % 8) * 22, -8 - math.floor((i - 1) / 8) * 22)
      local t = b:CreateTexture(nil, "ARTWORK") t:SetAllPoints() t:SetColorTexture(c[1], c[2], c[3], 1)
      b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      b:SetScript("OnClick", function() setColor(palette.key, c) palette:Hide() end)
    end
    -- (18 Nov) group it up or not, for this kind of bag
    local g = CreateFrame("CheckButton", nil, palette, "UICheckButtonTemplate")
    g:SetSize(22, 22)
    g:SetPoint("BOTTOMLEFT", 6, 32)
    g.text = g:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    g.text:SetPoint("LEFT", g, "RIGHT", 2, 1)
    g.text:SetText("One tile per item")
    g:SetHitRectInsets(0, -110, 0, 0)
    g:SetScript("OnClick", function(self)
      local db = D()
      db.specUngroup = db.specUngroup or {}
      db.specUngroup[palette.key] = (not self:GetChecked()) or nil
      B.Changed()
    end)
    g:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("One tile per item")
      GameTooltip:AddLine("Ticked: everything in this bag shows as one tile per item with the total, and the group's title says how full the bag is (12/16).", 1, 1, 1, true)
      GameTooltip:AddLine("Not ticked: slot by slot, with its empty slots.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    g:SetScript("OnLeave", function() GameTooltip:Hide() end)
    palette.group = g
    local def = CreateFrame("Button", nil, palette, "UIPanelButtonTemplate")
    def:SetSize(80, 20) def:SetPoint("BOTTOMLEFT", 8, 8) def:SetText("Default")
    def:SetScript("OnClick", function() setColor(palette.key, nil) palette:Hide() end)
    local close = CreateFrame("Button", nil, palette, "UIPanelButtonTemplate")
    close:SetSize(70, 20) close:SetPoint("BOTTOMRIGHT", -8, 8) close:SetText("Close")
    close:SetScript("OnClick", function() palette:Hide() end)
  end
  palette.key = w.key
  palette.group:SetChecked(B.SpecialGrouped(w.key))
  palette:ClearAllPoints()
  palette:SetPoint("TOPLEFT", w, "BOTTOMLEFT", 0, -4)
  palette:Show()
end
for i, sp in ipairs(B.SPECIAL) do
  local x, yy = ((i - 1) % 5) * 138, y - math.floor((i - 1) / 5) * 22
  local w = CreateFrame("Button", nil, p)
  w:SetSize(16, 16)
  w:SetPoint("TOPLEFT", p, "TOPLEFT", x, yy)
  w.key = sp.key
  local edge = w:CreateTexture(nil, "BACKGROUND") edge:SetAllPoints() edge:SetColorTexture(0, 0, 0, 1)
  w.fill = w:CreateTexture(nil, "ARTWORK") w.fill:SetPoint("TOPLEFT", 1, -1) w.fill:SetPoint("BOTTOMRIGHT", -1, 1)
  w:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  w:SetScript("OnClick", function(self) if palette and palette:IsShown() and palette.key == self.key then palette:Hide() else openPalette(self) end end)
  tip(w, sp.name, "Click: its colour, and whether its items show as one tile per item or slot by slot.")
  local label = Text(p, x + 22, yy - 1, "GameFontHighlightSmall")
  label:SetText(sp.name)
  swatches[#swatches + 1] = w
end
paintSwatches()
p:HookScript("OnShow", paintSwatches)
B.uiBottom = y - 22 - 16 -- (for the test scripts: the page must end above -552)
