-- Rucksack / Rations (was Eat & Drink)
-- Your plain food and water, eaten and drunk with one click: the on-screen button (food left, water
-- right, with counts) or the "EatDrink" character macro, in the order you pick (strongest, conjured
-- first, save conjured, random) and from the levels you pick. Food with a buff (Well Fed, stats,
-- procs) is never picked, nor anything on your Clean-up list. Per item: Never use it, or Use it first.
-- Its delete rules (water on a character that drinks none, food for below a level) are carried out
-- by Clean-up.
local _, ns = ...
local Print = ns.Print
local DB
local ICON = 134400 -- the question mark: with #showtooltip the macro shows the food's own icon

local Eat = {}
ns.Eat = Eat

-- a bag slot's tooltip lines as text
local scanTip
local function tipLines(bag, slot)
  local out = {}
  if C_TooltipInfo and C_TooltipInfo.GetBagItem then
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if ok and data and data.lines then
      for _, l in ipairs(data.lines) do if l.leftText then out[#out + 1] = l.leftText end end
      return out
    end
  end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "RucksackScanTip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  end
  scanTip:ClearLines()
  scanTip:SetBagItem(bag, slot)
  for i = 1, scanTip:NumLines() do
    local fs = _G["RucksackScanTipTextLeft" .. i]
    local t = fs and fs:GetText()
    if t then out[#out + 1] = t end
  end
  return out
end

local function num(s) return s and tonumber((s:gsub("[,%.]", ""))) end

-- what an item does: health and mana restored while seated; nil for anything else or buff food
-- (second value: why it was skipped, for the window)
local function readItem(bag, slot)
  local low = table.concat(tipLines(bag, slot), "\n"):lower()
  if not (low:find("seated") or low:find("eating") or low:find("drinking")) then return nil end
  local health = num(low:match("restores ([%d,%.]+) health"))
  local mana = num(low:match("restores ([%d,%.]+) mana")) or num(low:match("and ([%d,%.]+) mana"))
  if not health and not mana then return nil end
  local buff = low:find("well fed") or low:find("increase") or low:find("you will become") or low:find("chance")
  return health or 0, mana or 0, low:find("conjured") and true or false, buff and true or false
end

local function minLevelOf(id) return select(5, ns.GetInfo(id)) end

-- (10 Nov) food and water come in level tiers (the level the game asks for to eat it)
local TIERS = { 1, 5, 15, 25, 35, 45, 55, 65, 75 }
Eat.TIERS = TIERS
local function tierOf(minLevel)
  local lv, t = math.max(1, tonumber(minLevel) or 1), 1
  for i, v in ipairs(TIERS) do if lv >= v then t = i end end
  return t
end
Eat.TierOf = tierOf
-- your top tier (the strongest you can eat); "for my level" = it and the one below it
local function myTier() return tierOf(UnitLevel("player")) end
Eat.MyTier = myTier
local function weakFor(f) return f.tier < myTier() - 1 end

-- (10 Nov) what Clean-up deletes from Rations' rules: water on a character set to drink none
-- ("now": as soon as it lands) and food and water for below a level (when bags are nearly full).
-- Never: anything set to "Use this first", or food with a buff. Returns why, and "now" or nil.
function Eat.DeleteReason(id)
  local f = Eat.found[id]
  if not f or not DB or f.prefer or f.buff then return nil end
  if ns.char and ns.char.noWater and f.mana > 0 and f.health == 0 then
    return "water (this character drinks none)", "now"
  end
  local below = DB.delBelow
  if below == "auto" then
    if weakFor(f) then return "below your level" end
  elseif type(below) == "number" and (f.minLevel or 1) < below then
    return "for below level " .. below
  end
  return nil
end

-- everything food- or water-like in your bags, and the best food and drink
-- found[id] = { health, mana, conjured, buff, link, minLevel, tier, tooLow, never, prefer, deleting }
Eat.found = {}
-- (10 Nov) which first: "best" (restores the most), "conjured" (conjured first), "saveconj"
-- (everything else first, conjured kept for later), "random". Food level: "any", "mine" (only the
-- top two tiers you can eat, others only if there's nothing else), "old" (lowest level first).
Eat.ORDERS = { { "best", "Strongest first" }, { "conjured", "Conjured first" }, { "saveconj", "Save conjured" }, { "random", "Random" } }
Eat.LEVELS = { { "any", "Any level" }, { "mine", "Only my level" }, { "old", "Use up old food" } }
function Eat.Pick()
  local found = Eat.found
  wipe(found)
  local order = DB.order or "best"
  local lvMode = DB.level or "any"
  if order == "random" and lvMode == "old" then lvMode = "any" end
  local foods, drinks = {}, {}
  local level = UnitLevel("player")
  for bag = 0, ns.NUM_BAGS + 1 do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, _, link = ns.SlotInfo(bag, slot)
      if id and not found[id] then
        local health, mana, conjured, buff = readItem(bag, slot)
        if health then
          local minLevel = minLevelOf(id)
          local f = {
            health = health, mana = mana, conjured = conjured, buff = buff, link = link,
            minLevel = minLevel, tier = tierOf(minLevel),
            tooLow = minLevel and minLevel > level or false,
            never = DB.never[id] and true or false,
            prefer = DB.prefer[id] and true or false,
            deleting = ns.del and ns.del.items and ns.del.items[id] and true or false,
          }
          found[id] = f
          f.usable = not (f.buff or f.tooLow or f.never or f.deleting)
          if f.usable then
            if health > 0 then foods[#foods + 1] = id end
            if mana > 0 then drinks[#drinks + 1] = id end
          end
        end
      end
    end
  end
  local function better(a, b, key)
    local f, c = found[a], found[b]
    if f.prefer ~= c.prefer then return f.prefer end
    if order == "conjured" and f.conjured ~= c.conjured then return f.conjured end
    if order == "saveconj" and f.conjured ~= c.conjured then return not f.conjured end
    if lvMode == "old" and f.tier ~= c.tier then return f.tier < c.tier end
    if f[key] ~= c[key] then return f[key] > c[key] end
    if order == "saveconj" then return not f.conjured and c.conjured end
    return f.conjured and not c.conjured
  end
  -- "Only my level": weak ones only when there's nothing else ("Use this first" always counts)
  local function narrow(list)
    if lvMode ~= "mine" then return list end
    local ok = {}
    for _, id in ipairs(list) do if found[id].prefer or not weakFor(found[id]) then ok[#ok + 1] = id end end
    if #ok == 0 then return list end
    for _, id in ipairs(list) do found[id].weak = weakFor(found[id]) and not found[id].prefer or nil end
    return ok
  end
  foods, drinks = narrow(foods), narrow(drinks)
  local bestFood, bestDrink
  for _, id in ipairs(foods) do if not bestFood or better(id, bestFood, "health") then bestFood = id end end
  for _, id in ipairs(drinks) do if not bestDrink or better(id, bestDrink, "mana") then bestDrink = id end end
  if order == "random" then
    -- any of them, but "Use this first" still wins
    local function pick(list, cur)
      local pool = {}
      for _, id in ipairs(list) do if found[id].prefer then pool[#pool + 1] = id end end
      if #pool == 0 then pool = list end
      -- keep the last random pick while it's still there (the ticker and every bag change call this)
      for _, id in ipairs(pool) do if id == cur then return cur end end
      return pool[math.random(#pool)]
    end
    bestFood = foods[1] and pick(foods, Eat.randomFood) or nil
    bestDrink = drinks[1] and pick(drinks, Eat.randomDrink) or nil
    Eat.randomFood, Eat.randomDrink = bestFood, bestDrink
  end
  Eat.food, Eat.drink = bestFood, bestDrink
  return bestFood, bestDrink, found
end

---------------------------------------------------------------------------
-- The on-screen button: the big icon is the next food, the small one the next water
---------------------------------------------------------------------------
local btn = CreateFrame("Button", "EatDrinkButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
-- (9 Nov) two small icons side by side: the next food first, the next water second, each with how
-- many you have; one click (or the key) eats and drinks what you need
local SLOT = 28
local LABEL_H = 12 -- (9 Nov) "Food" and "Drink" written over their icons
btn:SetSize(SLOT * 2 + 14, SLOT + 8 + LABEL_H)
btn:SetFrameStrata("MEDIUM")
btn:SetClampedToScreen(true)
btn:SetMovable(true)
btn:RegisterForClicks("AnyDown")
btn:SetAttribute("useOnKeyDown", true) -- (the keybind and the mouse act on the press, once)
btn:RegisterForDrag("LeftButton")
btn:SetAttribute("type", "macro")
btn:SetAttribute("shift-type1", "none") -- (Shift + click is for moving it: eats nothing)
btn:SetAttribute("type2", "none") -- (right-click: does nothing; the Pocket's right-click opens Settings)
btn:SetBackdrop(ns.SLOT_BACKDROP)
btn:SetBackdropColor(0, 0, 0, 0.7)
btn:SetBackdropBorderColor(0.55, 0.55, 0.55) -- (plain: no green or blue, 9 Nov)
local function slot(x, label)
  local t = btn:CreateTexture(nil, "ARTWORK")
  t:SetSize(SLOT, SLOT)
  t:SetPoint("BOTTOMLEFT", x, 4)
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local edge = btn:CreateTexture(nil, "BORDER")
  edge:SetPoint("TOPLEFT", t, "TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 1, -1)
  edge:SetColorTexture(0, 0, 0, 0.9)
  local name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  name:SetPoint("BOTTOM", t, "TOP", 0, 1)
  name:SetText(label)
  t.name = name
  t.edge = edge
  local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  count:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 1, 1)
  t.count = count
  return t, count
end
btn.food, btn.foodCount = slot(5, "Food")
btn.drink, btn.drinkCount = slot(SLOT + 9, "Drink")
local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetPoint("TOPLEFT", 3, -3)
hl:SetPoint("BOTTOMRIGHT", -3, 3)
hl:SetColorTexture(1, 1, 1, 0.15)
btn:Hide()
btn:HookScript("PostClick", function(_, mouse)
  if mouse == "RightButton" then return end
  Eat.randomFood, Eat.randomDrink = nil, nil -- (Random: something else next time)
end)
btn:SetScript("OnDragStart", function(self)
  if IsShiftKeyDown() and not InCombatLockdown() then self.moving = true self:StartMoving() end
end)
btn:SetScript("OnDragStop", function(self)
  if not self.moving then return end
  self.moving = nil
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  DB.pos = { p, rp, x, y }
end)
-- (10 Nov) food only and water only: two more buttons. "Separate": they cover the two halves of
-- the eat button, so clicking the food eats and clicking the water drinks. "Together": hidden, the
-- whole button eats and drinks. Their keys (and the Eat and Drink macros) work either way.
local function half(name, left, kind)
  local b = CreateFrame("Button", name, btn, "SecureActionButtonTemplate, BackdropTemplate")
  if b.SetBackdrop then
    b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    b:SetBackdropBorderColor(0.55, 0.55, 0.55)
  end
  -- its dark background is drawn on the main button, under the icon
  b.bg = btn:CreateTexture(nil, "BACKGROUND")
  b.bg:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  b.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  b.bg:SetColorTexture(0, 0, 0, 0.7)
  b.bg:Hide()
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("useOnKeyDown", true)
  b:SetAttribute("type", "macro")
  b:SetAttribute("shift-type1", "none")
  b:SetAttribute("type2", "none")
  b:SetPoint(left and "TOPLEFT" or "TOPRIGHT", btn, left and "TOPLEFT" or "TOPRIGHT")
  b:SetSize(SLOT + 10, SLOT + 8 + LABEL_H)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 3, -3)
  hl:SetPoint("BOTTOMRIGHT", -3, 3)
  hl:SetColorTexture(1, 1, 1, 0.15)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function() btn:GetScript("OnDragStart")(btn) end)
  b:SetScript("OnDragStop", function() btn:GetScript("OnDragStop")(btn) end)
  b:HookScript("PostClick", function(_, mouse)
    if mouse ~= "RightButton" then Eat.randomFood, Eat.randomDrink = nil, nil end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local id = kind == "food" and btn.foodID or btn.drinkID
    if id and GameTooltip.SetItemByID then GameTooltip:SetItemByID(id)
    else GameTooltip:AddLine(kind == "food" and "No plain food in your bags" or "No plain water in your bags") end
    GameTooltip:AddLine(kind == "food" and "Click: eat (food only)." or "Click: drink (water only).", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift-drag to move.  Together or separate: /rations.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:Hide()
  return b
end
local foodBtn = half("RucksackFoodButton", true, "food")
local drinkBtn = half("RucksackDrinkButton", false, "drink")
Eat.FoodButton, Eat.DrinkButton = foodBtn, drinkBtn

btn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cff66dd66Rations|r")
  local function line(label, id)
    if id then
      GameTooltip:AddDoubleLine(label, ns.NameOf(id) .. " x" .. (ns.GetCount(id) or 0), 1, 1, 1, 1, 1, 1)
    else
      GameTooltip:AddDoubleLine(label, "none", 1, 1, 1, 0.6, 0.6, 0.6)
    end
  end
  line("Next food", self.foodID)
  line("Next water", self.drinkID)
  local use = DB.use or "both"
  GameTooltip:AddDoubleLine("One click uses", use == "food" and "food only" or use == "drink" and "water only" or "food and water",
    0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddLine("Click: eat and drink. Shift-drag to move. Settings: /rations.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function placeButton()
  btn:ClearAllPoints()
  local p = DB.pos
  if p then btn:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else btn:SetPoint("CENTER", UIParent, "CENTER", 200, -180) end
end

local function setCounts()
  btn.foodCount:SetText(btn.foodID and (ns.GetCount(btn.foodID) or 0) or "")
  btn.drinkCount:SetText(btn.drinkID and (ns.GetCount(btn.drinkID) or 0) or "")
end

-- each slot: its item's icon, grey when it won't be used (set to food or water only), an empty
-- dark slot with a question mark when you have none. (10 Nov) In a fight both go grey: the game
-- doesn't let you eat or drink in combat. (Only the look changes, so it's allowed in combat.)
local inFight = false
local function setSlot(tex, id, want)
  tex:SetTexture(id and ns.GetIcon(id) or ICON)
  tex:SetDesaturated(not id or not want or inFight)
  tex:SetAlpha(not id and 0.35 or inFight and 0.55 or 1)
  if inFight then tex.name:SetTextColor(0.5, 0.5, 0.5) else tex.name:SetTextColor(1, 0.82, 0) end
end
local function paintFight(on)
  inFight = on
  setSlot(btn.food, btn.foodID, Eat.wantF or DB.split)
  setSlot(btn.drink, btn.drinkID, Eat.wantD or DB.split)
end
-- (10 Nov) the button shows what a click uses: Together + "Food only" = just the food slot,
-- "Water only" = just the water slot, "Food and water" = both. Separate: always both halves.
-- (Out of combat only: the button's size can't change in a fight.)
local function showSlot(t, on)
  t:SetShown(on) t.edge:SetShown(on) t.name:SetShown(on) t.count:SetShown(on)
end
local GAP = 6
local function arrange()
  local use = DB.use or "both"
  local only = not DB.split and use ~= "both" and (use == "food" and btn.food or btn.drink) or nil
  local split = DB.split and true or false
  -- Separate: two framed buttons with a gap; the main button itself shows no frame and takes no clicks
  btn:SetBackdropColor(0, 0, 0, split and 0 or 0.7)
  btn:SetBackdropBorderColor(0.55, 0.55, 0.55, split and 0 or 1)
  btn:EnableMouse(not split)
  foodBtn.bg:SetShown(split)
  drinkBtn.bg:SetShown(split)
  if split then
    btn:SetWidth((SLOT + 10) * 2 + GAP)
    showSlot(btn.food, true)
    showSlot(btn.drink, true)
    btn.food:ClearAllPoints()
    btn.food:SetPoint("BOTTOMLEFT", 5, 4)
    btn.drink:ClearAllPoints()
    btn.drink:SetPoint("BOTTOMLEFT", SLOT + 10 + GAP + 5, 4)
  elseif only then
    btn:SetWidth(SLOT + 10)
    showSlot(btn.food, only == btn.food)
    showSlot(btn.drink, only == btn.drink)
    only:ClearAllPoints()
    only:SetPoint("BOTTOMLEFT", 5, 4)
  else
    btn:SetWidth(SLOT * 2 + 14)
    showSlot(btn.food, true)
    showSlot(btn.drink, true)
    btn.food:ClearAllPoints()
    btn.food:SetPoint("BOTTOMLEFT", 5, 4)
    btn.drink:ClearAllPoints()
    btn.drink:SetPoint("BOTTOMLEFT", SLOT + 9, 4)
  end
end

local function setButton(food, drink, macrotext, foodText, drinkText)
  arrange()
  btn.foodID, btn.drinkID = food, drink
  setSlot(btn.food, food, Eat.wantF or DB.split)
  setSlot(btn.drink, drink, Eat.wantD or DB.split)
  setCounts()
  btn:SetAttribute("macrotext", macrotext)
  foodBtn:SetAttribute("macrotext", foodText)
  drinkBtn:SetAttribute("macrotext", drinkText)
  foodBtn:SetShown(DB.split and true or false)
  drinkBtn:SetShown(DB.split and true or false)
  btn:SetShown(DB.showIcon ~= false and DB.enabled ~= false)
end

---------------------------------------------------------------------------
-- What one click uses (9 Nov): food, water or both, every time. The "below N% health / mana"
-- settings are gone: this server hides your current health and mana from addons (the Debug
-- window shows HIDDEN), so no addon can tell whether you're hurt.
---------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end
-- (for the Debug window) the % and, when it can't be read, why: "hidden" or "unknown"
local function pct(cur, max)
  if issecret(cur) or issecret(max) then return nil, "hidden" end
  if not cur or not max or max <= 0 then return nil, "unknown" end
  return cur / max * 100
end
Eat.Pct = pct
function Eat.WantFood()
  return (DB.use or "both") ~= "drink"
end
function Eat.WantDrink()
  local max = UnitPowerMax("player", 0)
  if not issecret(max) and max and max <= 0 then return false end -- (no mana at all: never drinks)
  return (DB.use or "both") ~= "food"
end
Eat.Button = btn -- (the Debug window reads what the button would do)

---------------------------------------------------------------------------
-- Keeping the button and the macro up to date (out of combat: neither can change in a fight)
---------------------------------------------------------------------------
local pending = false

-- (10 Nov) three macros shared by all your characters (General tab of /macro), kept up to date
-- with the food and water of whoever you're playing: EatDrink (like the button), Eat (food only),
-- Drink (water only). A character's own old EatDrink macro is kept up to date too, so a bar that
-- has it keeps working. Made once; if you delete one, it stays deleted (until you tick the box again).
local MACROS = { "EatDrink", "Eat", "Drink" }
Eat.MACROS = MACROS
local lastBodies = {}
local function macroIndexes(name)
  local out = {}
  local nAcc, nChar = GetNumMacros()
  local maxAcc = MAX_ACCOUNT_MACROS or 120
  for i = 1, nAcc or 0 do if GetMacroInfo(i) == name then out[#out + 1] = i end end
  for i = maxAcc + 1, maxAcc + (nChar or 0) do if GetMacroInfo(i) == name then out[#out + 1] = i end end
  return out
end
local function hasGlobal(name)
  local nAcc = GetNumMacros()
  for i = 1, nAcc or 0 do if GetMacroInfo(i) == name then return true end end
  return false
end
-- texts = { both, food only, water only }; first = the item the EatDrink macro shows;
-- ids = { food, water } for the other two
function Eat.UpdateMacros(texts, first, ids, loud, noCreate)
  DB.madeMacros = DB.madeMacros or {}
  local made = {}
  for i, name in ipairs(MACROS) do
    local show = (i == 1 and first) or (ids and ids[i - 1])
    local body = (show and ("#showtooltip item:" .. show .. "\n") or "") .. texts[i]
    if not noCreate and not hasGlobal(name) and (not DB.madeMacros[name] or loud) then
      local nAcc = GetNumMacros()
      if (nAcc or 0) < (MAX_ACCOUNT_MACROS or 120) and pcall(CreateMacro, name, ICON, body, false) and hasGlobal(name) then
        DB.madeMacros[name] = true
        made[#made + 1] = "|cffffd100" .. name .. "|r"
        lastBodies[name] = nil
      elseif loud then
        Print("couldn't make the macro " .. name .. ": the shared (General) macros are full.")
      end
    end
    if body ~= lastBodies[name] then
      -- (indexes move when a macro is made or renamed: look them up each time)
      for _, index in ipairs(macroIndexes(name)) do EditMacro(index, name, ICON, body) end
      lastBodies[name] = body
    end
  end
  if #made > 0 then
    Print("made the macro" .. (#made > 1 and "s " or " ") .. table.concat(made, ", ") ..
      " for all your characters (/macro, General tab): eat and drink, food only, water only.")
  end
end

function Eat.Update(loud)
  if not DB then return end
  if InCombatLockdown() then pending = true return end
  pending = false
  -- (9 Nov) Eat & Drink turned off on its page: nothing is eaten, the button goes away
  if DB.enabled == false then
    btn:SetAttribute("type", nil)
    foodBtn:SetAttribute("type", nil)
    drinkBtn:SetAttribute("type", nil)
    btn:Hide()
    local off = "/run print(\"Rucksack: Rations is turned off (/rations)\")"
    if DB.macro ~= false then Eat.UpdateMacros({ off, off, off }, nil, nil, false, true) end
    Eat.Pick()
    ns.Changed()
    return
  end
  btn:SetAttribute("type", "macro")
  foodBtn:SetAttribute("type", "macro")
  drinkBtn:SetAttribute("type", "macro")
  local food, drink = Eat.Pick()
  local wantF, wantD = Eat.WantFood(), Eat.WantDrink()
  Eat.wantF, Eat.wantD = wantF, wantD
  local uses = {}
  if food and wantF then uses[#uses + 1] = "/use item:" .. food end
  -- (food that gives mana too counts as the drink when it's both)
  if drink and wantD and not (drink == food and wantF) then uses[#uses + 1] = "/use item:" .. drink end
  if #uses == 0 then
    local what = (DB.use == "food" and "food") or (DB.use == "drink" and "water") or "food or water"
    uses[1] = "/run print(\"Rucksack: no plain " .. what .. " in your bags\")"
  end
  local macrotext = table.concat(uses, "\n")
  -- (10 Nov) food only, water only
  local foodText = food and ("/use item:" .. food) or "/run print(\"Rucksack: no plain food in your bags\")"
  local drinkText = drink and ("/use item:" .. drink) or "/run print(\"Rucksack: no plain water in your bags\")"
  setButton(food, drink, macrotext, foodText, drinkText)
  if ns.Del and ns.Del.Refresh and (ns.char and ns.char.noWater or DB.delBelow) then ns.Del.Refresh() end

  if DB.macro ~= false then
    local first = (wantF and food) or (wantD and drink) or food or drink
    Eat.UpdateMacros({ macrotext, foodText, drinkText }, first, { food, drink }, loud)
  end
  ns.Changed()
  if loud then
    Print("next food: " .. (food and ns.NameOf(food) or "none") .. ",  next water: " .. (drink and ns.NameOf(drink) or "none"))
  end
end
function Eat.SetShown(on)
  DB.showIcon = on
  if not InCombatLockdown() then btn:SetShown(on and DB.enabled ~= false) end
end

table.insert(ns.onLoad, function()
  DB = ns.eat
  DB.never = DB.never or {}
  DB.prefer = DB.prefer or {}
  if DB.showIcon == nil then DB.showIcon = true end
  if DB.enabled == nil then DB.enabled = true end
  if DB.macro == nil then DB.macro = true end
  DB.use = DB.use or "both" -- (9 Nov) "both", "food" or "drink": what one click uses
  if DB.split == nil then DB.split = false end -- (10 Nov) the eat button: together or separate
  DB.madeMacros = DB.madeMacros or {}
  -- (the old "below N%" settings: gone, the server hides health and mana from addons)
  DB.eatBelow, DB.drinkBelow, DB.eatAlways, DB.drinkAlways = nil, nil, nil, nil
end)
table.insert(ns.onLogin, function() placeButton() Eat.Update(false) if InCombatLockdown() then paintFight(true) end end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED" }) do
  ev:RegisterEvent(e)
end
local soon = false
local unitEv = CreateFrame("Frame")
unitEv:RegisterUnitEvent("UNIT_HEALTH", "player")
unitEv:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
unitEv:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
unitEv:RegisterUnitEvent("UNIT_MAXPOWER", "player")
unitEv:SetScript("OnEvent", function()
  if not DB or InCombatLockdown() then return end
  if Eat.WantFood() ~= Eat.wantF or Eat.WantDrink() ~= Eat.wantD then
    if soon then return end
    soon = true
    C_Timer.After(0.2, function() soon = false Eat.Update(false) end)
  end
end)
ev:SetScript("OnEvent", function(_, e)
  if not DB then return end
  if e == "BAG_UPDATE" then setCounts() return end -- (a fight: only the counts can change)
  if e == "PLAYER_REGEN_DISABLED" then paintFight(true) return end
  if e == "PLAYER_REGEN_ENABLED" then paintFight(false) if not pending then return end end
  if soon then return end
  soon = true
  C_Timer.After(0.3, function() soon = false Eat.Update(false) end) -- (bag changes come in bursts)
end)

-- (9 Nov fix) health and mana don't send an event while they sit at full, so a decision made at
-- login (or before a reload settled) could stay "eat and drink" forever: look again every second,
-- out of combat, and change the button only when eat / drink flips
C_Timer.NewTicker(1, function()
  if not DB or InCombatLockdown() or soon then return end
  if Eat.WantFood() ~= Eat.wantF or Eat.WantDrink() ~= Eat.wantD then Eat.Update(false) end
end)

-- /ed why: what the button sees right now
local function why()
  local h, hm = UnitHealth("player"), UnitHealthMax("player")
  local p, pm = UnitPower("player", 0), UnitPowerMax("player", 0)
  local function show(v) if issecret(v) then return "|cffff6060hidden|r" end return tostring(v) end
  Print(("health %s / %s, mana %s / %s"):format(show(h), show(hm), show(p), show(pm)))
  Print("one click uses: " .. (DB.use == "food" and "food only" or DB.use == "drink" and "water only" or "food and water"))
  Print(("eats now: %s, drinks now: %s"):format(Eat.WantFood() and "yes" or "no", Eat.WantDrink() and "yes" or "no"))
  local m = btn:GetAttribute("macrotext")
  Print("the button does: " .. ((m and m ~= "") and m:gsub("\n", "  |  ") or "nothing"))
end

-- /rations (/eatdrink): Rucksack on the Rations page; /rations icon: hide or show the button
SLASH_RUCKSACKEAT1 = "/rations"
SLASH_RUCKSACKEAT2 = "/eatdrink"
SlashCmdList.RUCKSACKEAT = function(msg)
  if (msg or ""):lower() == "why" then why() return end
  if (msg or ""):lower() == "icon" then
    if InCombatLockdown() then Print("after the fight, please.") return end
    Eat.SetShown(DB.showIcon == false)
    Print(DB.showIcon and "eat button shown. Shift-drag to move it." or "eat button hidden. /rations icon to show it.")
    return
  end
  Rucksack_Open("eat")
end
