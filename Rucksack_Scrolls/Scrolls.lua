-- Rucksack / Scrolls: one click deciphers your next mage scroll (WoW Forever's Comprehend Scroll).
-- Undeciphered scrolls are named "Scroll: " + strange words in capitals (Scroll: UPDOG). Each needs
-- some Comprehension skill (1, 15, 50 or 175, shown on the scroll); reading one above your skill
-- fails and turns you into a sheep for 8 seconds, so only ones you can read are picked.
-- The button (and the Decipher macro) casts Comprehend Scroll on that scroll.
local ns = Rucksack
if not ns then return end
local Print = ns.Print

local S = {}
ns.Scrolls = S
local DB

S.SPELL = "Comprehend Scroll"
S.SKILL = "Comprehension"
S.ICON = "Interface\\Icons\\INV_Scroll_03"
S.MACRO = "Decipher"

-- the four tiers: skill needed, the scrolls' names, level to use what comes out, and what can come out
-- (from the WoW Forever guides; the game's own "Requires Comprehension (N)" line wins when there is one)
S.TIERS = {
  { skill = 1, level = 5, names = { "KWYJIBO", "CWAL", "CHAP BALK WELLES", "LOWER PING WHOMEVER" },
    results = "Imbue Lesser Flame, Imbue Chillknife, Rat Familiar, Minor Evocation, Comprehension" },
  { skill = 15, level = 16, names = { "WUBBA WUBBA", "VOCE WELL", "OMIT KESA", "STHENIC LUNATE" },
    results = "Imbue Frost, Imbue Striking, Imbue Baleflame, Imbue Iceknife, Imbue Spark, Frog Familiar, Confuse Beast, Cryoblast, The Saber" },
  { skill = 50, level = 25, names = { "UPDOG", "TOPAZ YORAK", "PEATCHY ATTAX", "SHOOBEEDOOP", "THAW WORDS" },
    results = "Imbue Accuracy, Imbue Quickening, Imbue Balefrost, Imbue Flame, Imbue Manablade, Khadgar's Unlocking, Cat Familiar, Rebuke Elemental, The Blade" },
  { skill = 175, level = 46, names = { "DOST OREM", "FORGOT HOOF THUD", "KEEP CLEF FOCI", "RARE SERVICHI RADAR" },
    results = "Greater Cryoblast, Imbue Greater Flame, Imbue Greater Frost, Imbue Precision" },
}
local TIER_OF = {}
for _, t in ipairs(S.TIERS) do for _, n in ipairs(t.names) do TIER_OF[n] = t end end

function S.IsMage() return select(2, UnitClass("player")) == "MAGE" end

-- an undeciphered scroll: "Scroll: " (or "Spell Notes: ") and then no small letters at all
function S.IsUndeciphered(name)
  if type(name) ~= "string" then return false end
  local rest = name:match("^Scroll: (.+)$") or name:match("^Spell Notes: (.+)$")
  return rest ~= nil and not rest:find("%l") and rest:find("%u") ~= nil
end
function S.TierOfName(name)
  local rest = name and (name:match("^Scroll: (.+)$") or name:match("^Spell Notes: (.+)$"))
  return rest and TIER_OF[rest]
end

-- your Comprehension skill: rank (with buffs like the Scroll of Comprehension's +15) and cap.
-- (1.7.2) The skill list hides skills under a folded header ("Secondary Skills"), so folded
-- headers are opened for the look and folded again. Not found at all: nil (then nothing is held back).
local function findSkill()
  for i = 1, GetNumSkillLines() do
    local name, header, _, rank, temp, mod, max = GetSkillLineInfo(i)
    if not header and type(name) == "string" and name:find("Comprehen") then
      return (rank or 0) + (mod or 0) + (temp or 0), max or 0, rank or 0
    end
  end
end
local skillAt, skillA, skillB, skillC = -10
function S.Skill()
  if not (GetNumSkillLines and GetSkillLineInfo) then return nil end
  local a, b, c = findSkill()
  if a or not ExpandSkillHeader then return a, b, c end
  -- (opening folded headers fires a skill-list event: do it at most every few seconds)
  if GetTime() - skillAt < 3 then return skillA, skillB, skillC end
  skillAt = GetTime()
  S.expandedAt = skillAt
  local folded = {}
  for i = GetNumSkillLines(), 1, -1 do
    local name, header, expanded = GetSkillLineInfo(i)
    if header and not expanded then folded[#folded + 1] = name ExpandSkillHeader(i) end
  end
  if #folded == 0 then return nil end
  a, b, c = findSkill()
  -- fold them back as they were
  local again = {}
  for _, n in ipairs(folded) do again[n] = true end
  for i = GetNumSkillLines(), 1, -1 do
    local name, header = GetSkillLineInfo(i)
    if header and again[name] and CollapseSkillHeader then CollapseSkillHeader(i) end
  end
  skillA, skillB, skillC = a, b, c
  return a, b, c
end
function S.KnowsSpell()
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, S.SPELL)
    if ok and info then return true end
  end
  if GetSpellInfo then return GetSpellInfo(S.SPELL) ~= nil end
  return false
end

-- the skill a scroll needs, from its tooltip ("Requires Comprehension (15)"), else from its name
local tipCache = {}
local scanTip
local function needFromTooltip(bag, slot, id)
  if tipCache[id] ~= nil then return tipCache[id] or nil end
  local need
  local function look(text)
    local n = type(text) == "string" and text:match(S.SKILL .. " %((%d+)%)")
    if n then need = tonumber(n) end
  end
  if C_TooltipInfo and C_TooltipInfo.GetBagItem then
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if ok and type(data) == "table" and type(data.lines) == "table" then
      for _, l in ipairs(data.lines) do look(l.leftText) end
    end
  end
  if not need and CreateFrame then
    if not scanTip then
      scanTip = CreateFrame("GameTooltip", "RucksackScrollScanTip", UIParent, "GameTooltipTemplate")
      scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    scanTip:ClearLines()
    if pcall(scanTip.SetBagItem, scanTip, bag, slot) then
      for i = 1, scanTip:NumLines() or 0 do
        local fs = _G["RucksackScrollScanTipTextLeft" .. i]
        if fs then look(fs:GetText()) end
      end
    end
  end
  tipCache[id] = need or false
  return need
end

-- every undeciphered scroll in your bags: { bag, slot, id, name, count, need, tier, ok }
function S.Scan()
  local list = {}
  local skill = S.Skill()
  for bag = 0, ns.NUM_BAGS do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, count, link = ns.SlotInfo(bag, slot)
      if id then
        local name = ns.ItemName(link) or ns.NameOf(id)
        if S.IsUndeciphered(name) then
          local tier = S.TierOfName(name)
          local need = needFromTooltip(bag, slot, id) or (tier and tier.skill)
          list[#list + 1] = { bag = bag, slot = slot, id = id, name = name, count = count or 1,
            need = need, tier = tier, ok = need == nil or skill == nil or skill >= need }
        end
      end
    end
  end
  -- readable ones first, the hardest you can read first (the likeliest to raise your skill);
  -- skill unknown: the easiest first
  table.sort(list, function(a, b)
    if a.ok ~= b.ok then return a.ok end
    if (a.need or 0) ~= (b.need or 0) then
      if a.ok and skill then return (a.need or 0) > (b.need or 0) end
      return (a.need or 0) < (b.need or 0)
    end
    return a.name < b.name
  end)
  return list, skill
end
function S.Summary()
  local list = S.Scan()
  local total, readable = 0, 0
  for _, s in ipairs(list) do total = total + s.count if s.ok then readable = readable + s.count end end
  return total, readable, list[1] and list[1].ok and list[1] or nil, list
end

-- (1.7.4) deleting one by hand warns you
table.insert(ns.uses, function(id)
  local name = ns.GetInfo(id) or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
  if S.IsUndeciphered(name) then return "Scrolls: an unread scroll (Comprehend Scroll)" end
end)
-- Clean-up keeps undeciphered scrolls (they're worth almost nothing, so they'd go first)
table.insert(ns.keepers, function(id)
  if DB and DB.keep == false then return false end
  local name = ns.GetInfo(id) or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
  return S.IsUndeciphered(name)
end)

---------------------------------------------------------------------------
-- The button and the Decipher macro (secure: only changed out of combat)
---------------------------------------------------------------------------
local btn = CreateFrame("Button", "RucksackScrollButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
btn:SetSize(40, 40)
btn:SetFrameStrata("MEDIUM")
btn:SetClampedToScreen(true)
btn:SetMovable(true)
btn:RegisterForClicks("AnyDown")
btn:RegisterForDrag("LeftButton")
if btn.SetBackdrop then
  btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  btn:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
  btn:SetBackdropBorderColor(0.4, 0.6, 1, 1)
end
btn.icon = btn:CreateTexture(nil, "ARTWORK")
btn.icon:SetPoint("TOPLEFT", 3, -3)
btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
btn.icon:SetTexture(S.ICON)
btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
btn.count:SetPoint("BOTTOMRIGHT", -2, 2)
local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints(btn.icon)
hl:SetColorTexture(1, 1, 1, 0.15)
btn:SetAttribute("type", "macro")
btn:SetAttribute("type2", "none") -- (1.7.4: right-click reads nothing; it opens the Scrolls page)
btn:HookScript("PostClick", function(_, mouse) if mouse == "RightButton" then Rucksack_Open("scrolls") end end)
btn:SetScript("OnDragStart", function(self) if IsShiftKeyDown() and not InCombatLockdown() then self:StartMoving() end end)
btn:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  if DB then DB.pos = { p, rp, x, y } end
end)
btn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cff69ccf0Decipher|r  " .. "|cff999999(Rucksack)|r")
  local total, readable, nextOne = S.Summary()
  local skill, max = S.Skill()
  if skill then GameTooltip:AddDoubleLine(S.SKILL, skill .. " / " .. max, 1, 1, 1, 1, 0.82, 0) end
  if nextOne then
    GameTooltip:AddLine("Next: " .. nextOne.name .. (nextOne.need and (" (needs " .. nextOne.need .. ")") or ""), 1, 1, 1)
    GameTooltip:AddLine("Click to read it (5 seconds, stand still).", 0.6, 0.85, 1, true)
  elseif total > 0 then
    GameTooltip:AddLine(total .. " scroll(s), but your skill is too low for all of them.", 1, 0.5, 0.5, true)
  else
    GameTooltip:AddLine("No undeciphered scrolls in your bags.", 0.7, 0.7, 0.7)
  end
  if InCombatLockdown() then GameTooltip:AddLine("Not in combat: a failed read turns you into a sheep.", 1, 0.5, 0.5, true) end
  GameTooltip:AddLine("Right-click: the Scrolls page.  Shift-drag: move.", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
btn:Hide()

local function placeButton()
  btn:ClearAllPoints()
  local p = DB and DB.pos
  if p then btn:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else btn:SetPoint("CENTER", UIParent, "CENTER", 250, -180) end
end

local lastBody
local function macroText(s)
  if not s then return '/run print("Rucksack: no scroll you can read right now")' end
  return ("/cast %s\n/use %d %d"):format(S.SPELL, s.bag, s.slot)
end
local function updateMacro(body, s)
  if not DB or DB.macro == false or not (GetNumMacros and CreateMacro and EditMacro and GetMacroInfo) then return end
  local full = (s and ("#showtooltip item:" .. s.id .. "\n") or "#showtooltip\n") .. body
  local nAcc = GetNumMacros() or 0
  local idx
  for i = 1, nAcc do if GetMacroInfo(i) == S.MACRO then idx = i end end
  if not idx and not DB.madeMacro and nAcc < (MAX_ACCOUNT_MACROS or 120) then
    if pcall(CreateMacro, S.MACRO, "INV_Scroll_03", full, false) then
      DB.madeMacro = true
      Print("made the macro |cffffd100Decipher|r (/macro, General tab): one click reads your next scroll.")
      lastBody = full
      return
    end
  end
  if idx and full ~= lastBody then EditMacro(idx, S.MACRO, "INV_Scroll_03", full) lastBody = full end
end

local inFight = false
function S.Update()
  if not DB then return end
  local total, readable, nextOne = S.Summary()
  -- the look (allowed in combat)
  btn.count:SetText(total > 0 and total or "")
  btn.icon:SetTexture(nextOne and ns.GetIcon(nextOne.id) or S.ICON)
  local usable = nextOne and not inFight
  btn.icon:SetDesaturated(not usable)
  btn.icon:SetAlpha(usable and 1 or 0.5)
  if InCombatLockdown() then S.pending = true return end
  S.pending = false
  local mage = S.IsMage() and S.KnowsSpell()
  local body = macroText(nextOne)
  if mage then btn:SetAttribute("macrotext", body) updateMacro(body, nextOne) end
  local show = mage and DB.button ~= false and (DB.always or total > 0)
  btn:SetShown(show and true or false)
  ns.Changed()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_REGEN_DISABLED" then inFight = true
  elseif e == "PLAYER_REGEN_ENABLED" then inFight = false end
  -- (our own peek at folded skill headers fires this too: ignore those)
  if e == "SKILL_LINES_CHANGED" and S.expandedAt and GetTime() - S.expandedAt < 1 then return end
  if e == "BAG_UPDATE_DELAYED" or e == "SKILL_LINES_CHANGED" then wipe(tipCache) end
  if e == "PLAYER_REGEN_DISABLED" or (e == "PLAYER_REGEN_ENABLED" and not S.pending) then
    -- only the look changes
    local _, _, nextOne = S.Summary()
    btn.icon:SetDesaturated(inFight or not nextOne)
    btn.icon:SetAlpha((inFight or not nextOne) and 0.5 or 1)
    if e == "PLAYER_REGEN_DISABLED" then return end
  end
  S.Update()
end)

ns.Module("scrolls", (...), function()
  RucksackScrollsDB = RucksackScrollsDB or {}
  DB = RucksackScrollsDB
  S.db = DB
  if DB.button == nil then DB.button = true end
  if DB.macro == nil then DB.macro = true end
  if DB.keep == nil then DB.keep = true end
end)
table.insert(ns.onLogin, function()
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
  placeButton()
  S.Update()
end)

-- (1.7.4) no command of its own: /ruck opens Rucksack, Scrolls is in the sidebar
