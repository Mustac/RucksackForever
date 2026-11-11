-- Rucksack / Rations: its pages (the Rations page and one food item's page)
local ns = Rucksack
if not ns then return end
local UI = ns.UI
local tip, HoverLabel, Text, TipText, Check, Stepper, Choices, List, Page, GuideButton, ToolHeader, ItemHeader =
  UI.tip, UI.HoverLabel, UI.Text, UI.TipText, UI.Check, UI.Stepper, UI.Choices, UI.List, UI.Page, UI.GuideButton, UI.ToolHeader, UI.ItemHeader
local pages = UI.pages
local Print = ns.Print

---------------------------------------------------------------------------
-- Eat & Drink
---------------------------------------------------------------------------
do
  local p = Page()
  pages.eat = p
  GuideButton(p, "eat")
  local E = function() return ns.eat end
  local controls = {}
  ToolHeader(p, "|cff66dd66Rations|r",
    function() return E().showIcon ~= false end, function(v) ns.Eat.SetShown(v) end,
    "Shows or hides the eat button on your screen. Hidden, the EatDrink, Eat and Drink macros still work. (Turn Rations off completely in Settings > Modules.)")
  local next = Text(p, 0, -30, "GameFontHighlightSmall", 440)
  local y = -52
  controls[#controls + 1] = p:Add(Check(p, 0, y, "Keep the macros up to date  |cffaaaaaa(EatDrink, Eat, Drink)|r",
    "Three macros for your action bars, shared by all your characters (/macro, General tab):\n|cffffd100EatDrink|r: same as the eat button (eats and drinks, or what the Eat button choice says).\n|cffffd100Eat|r: food only.\n|cffffd100Drink|r: water only.\nRucksack keeps them up to date with the food and water of the character you're playing. A character's own older EatDrink macro is kept up to date too.",
    function() return E().macro ~= false end, function(v) E().macro = v ns.Eat.Update(v) end))
  y = y - 26
  -- (10 Nov) which food and water go first, and from which levels
  local function changed() ns.Eat.randomFood, ns.Eat.randomDrink = nil, nil ns.Eat.Update(false) end
  p:Add(Choices(p, 0, y, "Use first", {
    { "best", "Strongest first", 104, "The food and water that restore the most." },
    { "conjured", "Conjured first", 100, "Mage food and water before anything else (they vanish anyway), then the strongest." },
    { "saveconj", "Save conjured", 100, "Everything else first; conjured food and water are kept as a backup." },
    { "random", "Random", 64, "Any of them, a new pick after each meal." },
  }, function() return E().order or "best" end, function(v) E().order = v changed() end, "Use first",
    "Which of your food and water the eat button picks first. Hover a choice to see what it does."))
  y = y - 26
  local lvRow = Choices(p, 0, y, "Food level", {
    { "any", "Any level", 80, "Anything you can eat." },
    { "mine", "Only my level", 100, "Only food made for your level: the two strongest kinds you can eat (at level 30: food for level 25 and 15). Weaker food only when there's nothing else." },
    { "old", "Use up old food", 110, "The lowest-level food first, to clear out old stacks. (Not with Random.)" },
  }, function() return E().level or "any" end, function(v) E().level = v changed() end, "Food level",
    "Which levels of food and water the eat button may use. Food that's too high for you is always skipped.")
  lvRow.usable = function(v) return not (v == "old" and E().order == "random") end
  p:Add(lvRow)
  y = y - 26
  local BELOW = { { nil, "Off", 40, "Rations deletes no food or water for its level." },
    { "auto", "Auto", 48, "Follows your level: deletes food and water weaker than the two strongest kinds you can eat (at level 40: everything for below level 25)." } }
  for _, lv in ipairs({ 5, 15, 25, 35, 45, 55 }) do
    BELOW[#BELOW + 1] = { lv, tostring(lv), 34, "Deletes food and water made for below level " .. lv .. "." }
  end
  p:Add(Choices(p, 0, y, "Delete below level", BELOW,
    function() return E().delBelow end, function(v) E().delBelow = v changed() if ns.Del then ns.Del.Refresh() end end, "Delete food and water",
    "Gets rid of old food and water you've outgrown, so it doesn't fill your bags. Clean-up deletes it (or a vendor buys it) when your bags are nearly full. Food set to \"Use this first\" and Keep items are never deleted."))
  y = y - 24
  Text(p, 150, y, "GameFontDisableSmall", 420):SetText("Clean-up deletes them when your bags are nearly full. Never \"Use this first\" or Keep items.")
  y = y - 18
  p:Add(Check(p, 0, y, "Delete all water as soon as I get it  |cffaaaaaa(this character)|r",
    "For characters without mana (warriors, rogues): every plain drink goes. Food that restores health too is kept. Set per character; on by default for warriors and rogues.",
    function() return ns.char.noWater end, function(v) ns.char.noWater = v and true or false changed() if ns.Del then ns.Del.Refresh() end end))
  y = y - 24
  -- (10 Nov) buff food (Well Fed) while the buff is missing
  local buffBox = p:Add(Check(p, 0, y, "Eat buff food when the buff is missing",
    "Food that gives a buff (Well Fed and similar) is normally never eaten. Ticked: while you're not Well Fed, the eat button picks your buff food first. Once the buff is up, it goes back to plain food until the buff wears off.\n\nBuffs are checked outside fights only (you can't eat in one anyway).",
    function() return E().buffFood end, function(v) E().buffFood = v and true or false changed() end))
  p.updates[#p.updates + 1] = function()
    local note = ""
    if E().buffFood then
      local st = ns.Eat.FoodBuffState()
      note = st == true and "  |cff66dd66(Well Fed now)|r" or st == false and "  |cffffd100(not Well Fed: buff food first)|r"
        or (not InCombatLockdown() and "  |cff999999(this server doesn't let addons see your buffs)|r") or ""
    end
    buffBox.label:SetText("Eat buff food when the buff is missing" .. note)
  end
  y = y - 24
  -- (10 Nov) the "don't move" alert while eating buff food
  local alertBox = p:Add(Check(p, 20, y, "Alert me while I eat for the buff",
    "While you eat buff food, big text in the middle of the screen says \"don't move\" with the seconds left (you need to stay seated about 10 seconds). When Well Fed lands it tells you that you can move again.\n\nOnly works with \"Eat buff food when the buff is missing\" ticked.",
    function() return E().buffAlert ~= false end, function(v) E().buffAlert = v and true or false end, "GameFontHighlightSmall"))
  local moveBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  moveBtn:SetSize(130, 20)
  moveBtn:SetPoint("TOPLEFT", 300, y - 2)
  moveBtn:SetText("Move the alert")
  moveBtn:SetScript("OnClick", function(self)
    local moving = ns.Eat.MoveAlert()
    self:SetText(moving and "Lock it here" or "Move the alert")
  end)
  tip(moveBtn, "Move the alert", "Shows the alert so you can drag it where you like. Click again to lock it there (closing Rucksack locks it too).")
  -- (10 Nov) the alert only goes with buff food: greyed out while that's off
  p.updates[#p.updates + 1] = function()
    local on = E().buffFood and true or false
    alertBox:SetEnabled(on)
    alertBox.label:SetFontObject(on and "GameFontHighlightSmall" or "GameFontDisableSmall")
    moveBtn:SetEnabled(on)
    if not on and ns.Eat.AlertMoving and ns.Eat.AlertMoving() then ns.Eat.MoveAlert() end
    moveBtn:SetText((ns.Eat.AlertMoving and ns.Eat.AlertMoving()) and "Lock it here" or "Move the alert")
  end
  ns.LockAlert = function()
    if ns.Eat.AlertMoving and ns.Eat.AlertMoving() then ns.Eat.MoveAlert() end
    moveBtn:SetText("Move the alert")
  end
  y = y - 30
  -- (1.7.4) the macros: drag one onto your bars from here; Create macros makes the missing ones
  do
    local DOES = { EatDrink = "Same as the eat button: eats and drinks (or what the Eat button choice says).",
      Eat = "Eats your best food (food only).", Drink = "Drinks your best water (water only)." }
    local mIcons = {}
    for i, name in ipairs(ns.Eat.MACROS) do
      local b = CreateFrame("Button", nil, p)
      b:SetSize(24, 24)
      b:SetPoint("TOPLEFT", (i - 1) * 118, y + 2)
      b.tex = b:CreateTexture(nil, "ARTWORK")
      b.tex:SetAllPoints()
      b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.2)
      b.name = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      b.name:SetPoint("TOPLEFT", b, "TOPRIGHT", 5, 0)
      b.name:SetText(name)
      b.state = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      b.state:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 5, 0)
      b:RegisterForDrag("LeftButton")
      local function pick() if ns.Eat.HasMacro(name) and not InCombatLockdown() then PickupMacro(name) end end
      b:SetScript("OnDragStart", pick)
      b:SetScript("OnClick", pick)
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(name)
        GameTooltip:AddLine(DOES[name], 1, 1, 1, true)
        GameTooltip:AddLine(ns.Eat.HasMacro(name) and "Drag it onto an action bar." or "Missing: click Create macros.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      mIcons[i] = { b = b, name = name }
    end
    local create = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    create:SetSize(130, 22)
    create:SetPoint("TOPLEFT", 360, y + 1)
    create:SetScript("OnClick", function() ns.Eat.CreateMacros() end)
    tip(create, "Create macros", "Makes the EatDrink, Eat and Drink macros that are missing (shared by all your characters, /macro General tab). The ones you have are left as they are.")
    p.updates[#p.updates + 1] = function()
      local missing = 0
      for _, e in ipairs(mIcons) do
        local has = ns.Eat.HasMacro(e.name)
        if not has then missing = missing + 1 end
        local icon
        if has and GetMacroIndexByName then icon = select(2, GetMacroInfo(GetMacroIndexByName(e.name))) end
        e.b.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        e.b.tex:SetDesaturated(not has)
        e.b.state:SetText(has and "|cff66dd66ready|r  |cff888888drag me|r" or "|cff999999missing|r")
      end
      local fight = InCombatLockdown()
      create:SetText(missing == 0 and "All made" or fight and "After combat" or "Create macros")
      create:SetEnabled(missing > 0 and not fight)
    end
  end
  y = y - 32
  -- (9 Nov) what one click uses: food, water or both, every time. (The "below N% health / mana"
  -- settings are gone: this server hides your current health and mana from addons.)
  -- (10 Nov) and "Separate": food and water as two buttons side by side (the Eat and drink key
  -- and the EatDrink macro still use both then)
  local USE = { { "both", "Food and water" }, { "food", "Food only" }, { "drink", "Water only" }, { "split", "Separate" } }
  local function useNow() return E().split and "split" or (E().use or "both") end
  local useRow = CreateFrame("Frame", nil, p)
  useRow:SetSize(420, 24)
  useRow:SetPoint("TOPLEFT", 0, y)
  local ul = useRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  ul:SetPoint("LEFT", 4, 0)
  ul:SetText("Eat button")
  HoverLabel(useRow, ul, "Eat button", "What the eat button on your screen does. Click the button on the right to go through the choices:\n|cffffd100Food and water|r: one click eats and drinks.\n|cffffd100Food only|r / |cffffd100Water only|r: just that one.\n|cffffd100Separate|r: two buttons side by side, click the food to eat or the water to drink.")
  local ub = CreateFrame("Button", nil, useRow, "UIPanelButtonTemplate")
  ub:SetSize(200, 22)
  ub:SetPoint("LEFT", 240, 0)
  local function useText()
    for _, o in ipairs(USE) do if o[1] == useNow() then return o[2] end end
    return USE[1][2]
  end
  ub:SetScript("OnClick", function()
    local i = 1
    for k, o in ipairs(USE) do if o[1] == useNow() then i = k end end
    local v = USE[i % #USE + 1][1]
    if v == "split" then E().split, E().use = true, "both" else E().split, E().use = false, v end
    ub:SetText(useText())
    ns.Eat.Update(false)
  end)
  tip(ub, "Eat button", "Food and water: one click eats and drinks.\nFood only / Water only: just that one.\nSeparate: two buttons, food and water.\nClick to change. (In a fight it changes after the fight.)")
  useRow.Update = function()
    ub:SetText(useText())
    local on = E().enabled ~= false
    ub:SetEnabled(on)
    ul:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
  end
  p:Add(useRow)
  y = y - 34
  TipText(p, 0, y, "GameFontNormal", "Food and water in your bags",
    "Everything Rations found in your bags, strongest first. Click one to set it to \"Use this first\" or \"Never use this\". The tag on the right says if it's skipped or deleted, and why.")
  Text(p, 230, y, "GameFontDisableSmall", 300):SetText("click one: use it first, or never")
  local list = List(p, y - 18)
  p.updates[#p.updates + 1] = function()
    local on = E().enabled ~= false
    for _, c in ipairs(controls) do
      if c.SetEnabled and c.GetObjectType and c:GetObjectType() == "CheckButton" then
        c:SetEnabled(on)
        c.label:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
      end
    end
    local fd, dr = ns.Eat.food, ns.Eat.drink
    next:SetText(on and ("Next food: " .. (fd and ns.NameOf(fd) or "|cff999999none|r") .. "      Next drink: " .. (dr and ns.NameOf(dr) or "|cff999999none|r"))
      or "|cff999999Turned off: the button and its key do nothing.|r")
    local foods = {}
    for id, fdata in pairs(ns.Eat.found) do foods[#foods + 1] = { id = id, fd = fdata } end
    table.sort(foods, function(a, b)
      if a.fd.usable ~= b.fd.usable then return a.fd.usable end
      return (a.fd.health + a.fd.mana) > (b.fd.health + b.fd.mana)
    end)
    local entries = {}
    for _, e in ipairs(foods) do
      local tag = ""
      if e.id == fd and e.id == dr then tag = "|cffffd100both|r"
      elseif e.id == fd then tag = "|cffffd100eat next|r"
      elseif e.id == dr then tag = "|cffffd100drink next|r"
      elseif e.fd.prefer then tag = "first"
      elseif e.fd.buff and E().buffFood then tag = "|cff66aaffbuff food|r"
      elseif e.fd.buff then tag = "|cff777777buff food: off|r"
      elseif not e.fd.usable then tag = "|cff777777off|r" end
      local why = ns.Del.ByFood and ns.Del.ByFood(e.id)
      if why then tag = "|cffff8080deletes: " .. why .. "|r"
      elseif e.fd.weak and tag == "" then tag = "|cff999999weak for your level|r" end
      entries[#entries + 1] = { key = "food:" .. e.id, icon = ns.GetIcon(e.id), text = ns.NameOf(e.id, e.fd.link) .. "  |cff999999x" .. (ns.GetCount(e.id) or 0) .. "|r",
        tag = tag, itemID = e.id, dim = not e.fd.usable }
    end
    list:Set(entries, "No food or water in your bags.")
  end
end

---------------------------------------------------------------------------
-- One food or water item
---------------------------------------------------------------------------
do
  local p = Page()
  pages.food = p
  ItemHeader(p, "eat", "Rations")
  local stats = Text(p, 0, -54, "GameFontHighlight", 440)
  local status = Text(p, 0, -78, "GameFontHighlight", 440)
  local E = function() return ns.eat end
  local prefer = Check(p, 0, -108, "Use this first", "Picked before any other food or water you have, even better ones.",
    function() return E().prefer[p.id] end,
    function(v) E().prefer[p.id] = v or nil if v then E().never[p.id] = nil end ns.Eat.Update(false) end)
  local never = Check(p, 0, -134, "Never use this", "The eat button and its key skip it.",
    function() return E().never[p.id] end,
    function(v) E().never[p.id] = v or nil if v then E().prefer[p.id] = nil end ns.Eat.Update(false) end)
  p.updates[#p.updates + 1] = function()
    local id = p.id
    local fd = ns.Eat.found[id]
    p.link = fd and fd.link or ns.LinkOf(id)
    p.icon.tex:SetTexture(ns.GetIcon(id))
    p.name:SetText(p.link or ns.NameOf(id))
    p.sub:SetText("You have " .. (ns.GetCount(id) or 0))
    if not fd then
      stats:SetText("Not in your bags any more.")
      status:SetText("")
    else
      local parts = {}
      if fd.health > 0 then parts[#parts + 1] = fd.health .. " health" end
      if fd.mana > 0 then parts[#parts + 1] = fd.mana .. " mana" end
      stats:SetText("Restores " .. table.concat(parts, " and ") .. (fd.conjured and "   (conjured)" or ""))
      local s
      if id == ns.Eat.food and id == ns.Eat.drink then s = "|cffffd100Next to eat and drink.|r"
      elseif id == ns.Eat.food then s = "|cffffd100Next to eat.|r"
      elseif id == ns.Eat.drink then s = "|cffffd100Next to drink.|r"
      elseif fd.buff and E().buffFood then s = "|cff999999Buff food: eaten first while you're not Well Fed.|r"
      elseif fd.buff then s = "|cff999999Not used: it gives a buff (Well Fed or similar). Tick \"Eat buff food when the buff is missing\" on the Rations page to use it.|r"
      elseif fd.tooLow then s = "|cff999999Not used: your level is too low for it.|r"
      elseif fd.deleting then s = "|cffff8080Not used: it's on your Clean-up list.|r"
      elseif fd.never then s = "|cff999999Not used: set to never use.|r"
      else s = (E().order == "random" and "|cff999999Not picked this time (Random).|r") or (E().order == "conjured" and not fd.conjured and "|cff999999Not used now: conjured food or water goes first.|r") or "|cff999999Not used now: you have something better.|r" end
      status:SetText(s)
    end
    prefer.Update() never.Update()
    local usable = fd and (not fd.buff or E().buffFood) and not fd.tooLow and not fd.deleting
    prefer:SetEnabled(usable and true or false)
    prefer.label:SetFontObject(usable and "GameFontHighlight" or "GameFontDisable")
  end
end

