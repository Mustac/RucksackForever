-- Rucksack / Scrolls: the page. Your Comprehension skill, every scroll in your bags (which you can
-- read, what each tier can turn into), and the settings.
local ns = Rucksack
if not ns or not ns.UI then return end
local UI = ns.UI
local Text, Check, Page, GuideButton, ToolHeader, tip = UI.Text, UI.Check, UI.Page, UI.GuideButton, UI.ToolHeader, UI.tip
local S = ns.Scrolls
local GREY, GOLD, GREEN, RED = "|cff999999", "|cffffd100", "|cff66dd66", "|cffff6060"

local p = Page()
UI.pages.scrolls = p
GuideButton(p, "scrolls")
ToolHeader(p, "|cff69ccf0Scrolls|r", function() return S.db and S.db.button ~= false end,
  function(v) S.db.button = v S.Update() end,
  "On: the scroll button on screen. Off: no button (the Decipher macro still works).")
local intro = Text(p, 0, -28, "GameFontHighlightSmall", 640)

-- skill bar
local skillText = Text(p, 0, -60, "GameFontHighlight", 400)
local bar = CreateFrame("StatusBar", nil, p)
bar:SetPoint("TOPLEFT", 0, -80)
bar:SetSize(400, 10)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.4, 0.6, 1)
bar:SetMinMaxValues(0, 1)
local barBg = bar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints()
barBg:SetColorTexture(0, 0, 0, 0.6)

-- settings
local y = -102
p:Add(Check(p, 0, y, "Show the scroll button on screen", "One click reads your next scroll. Shift-drag to move it. It hides when you have no scrolls.",
  function() return S.db.button ~= false end, function(v) S.db.button = v S.Update() end))
p:Add(Check(p, 330, y, "Show it even with no scrolls", "Keep the button on screen all the time.",
  function() return S.db.always end, function(v) S.db.always = v or nil S.Update() end))
y = y - 26
p:Add(Check(p, 0, y, "Keep the Decipher macro up to date", "A macro shared by your characters (General tab of /macro) that does the same as the button. Put it on your bars.",
  function() return S.db.macro ~= false end, function(v) S.db.macro = v S.Update() end))
p:Add(Check(p, 330, y, "Clean-up keeps undeciphered scrolls", "Scrolls sell for a few coppers, so Clean-up would throw them out first. Ticked: they're never deleted or sold.",
  function() return S.db.keep ~= false end, function(v) S.db.keep = v if ns.Del then ns.Del.Refresh() end end))
y = y - 36

-- the list
Text(p, 0, y, "GameFontNormal"):SetText("In your bags")
local listText = Text(p, 0, y - 20, "GameFontHighlightSmall", 660)
listText:SetSpacing(3)
local tierHead = Text(p, 0, -440, "GameFontNormal")
tierHead:SetText("What the tiers can turn into")
local tierText = Text(p, 0, -460, "GameFontDisableSmall", 660)
tierText:SetSpacing(2)
do
  local l = {}
  for _, t in ipairs(S.TIERS) do l[#l + 1] = ("%sneeds %d|r (use at level %d): %s"):format(GOLD, t.skill, t.level, t.results) end
  tierText:SetText(table.concat(l, "\n"))
end

p.updates[#p.updates + 1] = function()
  local mage = S.IsMage()
  local total, readable, nextOne, list = S.Summary()
  if not mage then
    intro:SetText("Only mages can read these scrolls (Comprehend Scroll, learned at level 6). This character keeps them so you can send them to your mage.")
  elseif not S.KnowsSpell() then
    intro:SetText(RED .. "You don't know Comprehend Scroll yet: a mage trainer teaches it at level 6.|r")
  else
    intro:SetText("One click on the scroll button (or the |cffffd100Decipher|r macro) reads your next scroll: the hardest one your skill allows. "
      .. "Reading one above your skill would turn you into a sheep for 8 seconds, so those are skipped.")
  end
  local skill, max = S.Skill()
  if skill then
    skillText:SetText(("Comprehension:  |cffffffff%d|r / %d"):format(skill, max))
    bar:SetValue(max > 0 and skill / max or 0)
    bar:Show()
  else
    skillText:SetText(GREY .. (mage and "Comprehension: couldn't read your skill, so no scroll is held back" or "Comprehension: mages only") .. "|r")
    bar:Hide()
  end
  local lines = {}
  for _, s in ipairs(list) do
    local color = s.ok and "|cffffffff" or GREY
    local need = s.need and ("needs " .. s.need) or "skill unknown"
    local tag = (s == list[1] and s.ok and mage) and (GREEN .. "  < next|r") or (not s.ok and (RED .. "  (skill too low)|r") or "")
    lines[#lines + 1] = ("%s%s|r  x%d   %s%s|r%s"):format(color, s.name, s.count, GREY, need, tag)
  end
  if #lines == 0 then lines[1] = GREY .. "No undeciphered scrolls. They drop from monsters everywhere: their names start with \"Scroll:\" and strange capital letters.|r" end
  if #lines > 14 then local n = #lines - 14 for i = #lines, 15, -1 do lines[i] = nil end lines[15] = GREY .. "... and " .. n .. " more|r" end
  listText:SetText(table.concat(lines, "\n"))
end
