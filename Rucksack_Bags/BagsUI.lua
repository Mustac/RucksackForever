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
Text(p, 0, -28, "GameFontHighlightSmall", 640):SetText("One bag window instead of the game's bags. Pick an item up and every group gets a slot at its end: drop it there and it goes in that group from now on (on Junk: it's junk). Make your own groups with the + next to your bags; the padlock beside it locks the layout.")
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
p:Add(Check(p, 330, y, "\"New\" group", "Items you just got sit in a New group at the front, with a gold frame, until you've pointed at them or closed the bag.",
  function() return D().showNew ~= false end, function(v) D().showNew = v and true or false B.Draw() end, "GameFontHighlightSmall"))
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
  { "groups", "Groups", 96, "Your items in labelled groups: Weapons, Armour, Food and water, Trade goods, your own groups..." },
  { "grid", "One bag", 96, "No groups: everything in one bag, sorted (see Sort): new items first, the empty slots last. Under it, Junk, a fixed group. Holding an item: a red + on Junk makes it junk; a junk item gets a green + on the bag to keep it." },
}, function() return D().style end, function(v) D().style = v end)
choice("Sort", "Sort", "How One bag sorts your items.", {
  { "kind", "Kind", 96, "Weapons, armour, food and water, potions, trade goods, quest items, the rest; in each, the best quality first, then by name." },
  { "quality", "Quality", 96, "The best quality first (epic, rare, uncommon...), then by name." },
  { "name", "Name", 96, "A to Z." },
}, function() return D().sortBy end, function(v) D().sortBy = v end)
choice("Groups", "Groups", "With the Groups look: each group on its own row, or side by side.", {
  { "rows", "Rows", 96, "Each group starts on a new row. Easy to read, and to move a group up or down." },
  { "packed", "Packed", 96, "Small groups side by side: a smaller bag." },
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
