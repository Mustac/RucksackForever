local _, ns = ...
-- Rucksack / Website and Report a bug: two small buttons at the top of the window (1.8.3).
-- The game doesn't let an addon open a browser or put text on your clipboard, so each button opens
-- a box with the link already selected (Ctrl+C copies it). "Report a bug" also has a ready-made
-- report to copy: your Rucksack and game version, the modules that are on, and the last thing the
-- game blocked Rucksack from doing, if anything. You paste it on the website's report page.
local f = RucksackFrame
if not f then return end
local SITE = "https://mustac.github.io/RucksackForever/"
local REPORT = SITE .. "report.html"
ns.SITE, ns.REPORT_URL = SITE, REPORT

-- the last thing the game blocked Rucksack from doing (kept for the report)
local lastBlock
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "ADDON_ACTION_FORBIDDEN")
pcall(ev.RegisterEvent, ev, "ADDON_ACTION_BLOCKED")
ev:SetScript("OnEvent", function(_, e, addon, what)
  if type(addon) == "string" and addon:find("^Rucksack") then
    lastBlock = (date and date("%H:%M") or "") .. " " .. (e == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked") .. ": " .. tostring(addon) .. " " .. tostring(what)
  end
end)
function ns.ReportText()
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ok, ver = pcall(meta, "Rucksack", "Version")
  local gv, build, _, toc = "?", "?", nil, "?"
  if GetBuildInfo then gv, build, _, toc = GetBuildInfo() end
  local mods = {}
  for _, m in ipairs(ns.MODULES or {}) do if ns.Has(m.key) then mods[#mods + 1] = m.name end end
  local _, class = UnitClass("player")
  local lines = {
    "Rucksack " .. tostring(ok and ver or "?") .. ", game " .. tostring(gv) .. " (" .. tostring(build) .. "), interface " .. tostring(toc),
    "Modules on: " .. (#mods > 0 and table.concat(mods, ", ") or "none"),
    "Character: " .. tostring(class or "?") .. " level " .. tostring(UnitLevel and UnitLevel("player") or "?"),
    "Last thing the game blocked: " .. (lastBlock or "nothing"),
  }
  return table.concat(lines, "\n")
end

local pop
local function copyBox(parent, multi)
  local e = CreateFrame("EditBox", nil, parent, multi and ns.BACKDROP_TMPL or "InputBoxTemplate")
  e:SetAutoFocus(false)
  e:SetFontObject(GameFontHighlightSmall)
  if multi then
    e:SetMultiLine(true)
    if e.SetBackdrop then
      e:SetBackdrop(ns.SLOT_BACKDROP)
      e:SetBackdropColor(0, 0, 0, 0.6)
      e:SetBackdropBorderColor(0.4, 0.4, 0.4)
    end
    e:SetTextInsets(6, 6, 6, 6)
  end
  -- (it's for copying: whatever you type is put back)
  e:SetScript("OnTextChanged", function(self, user) if user and self.full then self:SetText(self.full) self:HighlightText() end end)
  e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  e:SetScript("OnMouseUp", function(self) self:SetFocus() self:HighlightText() end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() if pop then pop:Hide() end end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return e
end
local function build()
  if pop then return pop end
  pop = CreateFrame("Frame", "RucksackLinkBox", f, ns.BACKDROP_TMPL)
  pop:SetSize(430, 250)
  pop:SetPoint("TOP", f, "TOP", 0, -44)
  pop:SetFrameStrata("DIALOG")
  pop:EnableMouse(true)
  pop:SetBackdrop(ns.DIALOG_BACKDROP)
  local fill = pop:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetPoint("TOPLEFT", 11, -12)
  fill:SetPoint("BOTTOMRIGHT", -12, 11)
  fill:SetColorTexture(0.04, 0.04, 0.04, 0.97)
  pop.title = pop:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  pop.title:SetPoint("TOPLEFT", 22, -20)
  local close = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  pop.l1 = pop:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  pop.l1:SetPoint("TOPLEFT", 22, -48)
  pop.l1:SetWidth(386)
  pop.l1:SetJustifyH("LEFT")
  pop.link = copyBox(pop, false)
  pop.link:SetSize(380, 20)
  pop.link:SetPoint("TOPLEFT", 26, -82)
  pop.l2 = pop:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  pop.l2:SetPoint("TOPLEFT", 22, -112)
  pop.l2:SetWidth(386)
  pop.l2:SetJustifyH("LEFT")
  pop.l2:SetText("2. Click in this box, press |cffffd100Ctrl+C|r, and paste it into the report on the website:")
  pop.report = copyBox(pop, true)
  pop.report:SetSize(386, 84)
  pop.report:SetPoint("TOPLEFT", 22, -142)
  pop:Hide()
  return pop
end
function ns.ShowLink(bug)
  build()
  if pop:IsShown() and pop.bug == (bug and true or false) then pop:Hide() return end
  pop.bug = bug and true or false
  pop.title:SetText(bug and "Report a bug or send feedback" or "Rucksack's website")
  pop.l1:SetText(bug and "1. The link is selected: press |cffffd100Ctrl+C|r, then paste it in your browser. Anyone can send a report, no account needed."
    or "The link is selected: press |cffffd100Ctrl+C|r, then paste it in your browser. What Rucksack does, what's new, and where to send feedback.")
  pop.link.full = bug and REPORT or SITE
  pop.link:SetText(pop.link.full)
  pop.l2:SetShown(pop.bug)
  pop.report:SetShown(pop.bug)
  if bug then
    pop.report.full = ns.ReportText()
    pop.report:SetText(pop.report.full)
  end
  pop:SetHeight(bug and 250 or 124)
  pop:Show()
  pop.link:SetFocus()
  pop.link:HighlightText()
end

local function headBtn(name, label, w, x, bug, tipText)
  local b = CreateFrame("Button", name, f, "UIPanelButtonTemplate")
  b:SetSize(w, 20)
  b:SetPoint("TOPRIGHT", x, -14)
  b:SetText(label)
  b:SetScript("OnClick", function() ns.ShowLink(bug) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(label)
    GameTooltip:AddLine(tipText, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end
headBtn("RucksackReportButton", "Report a bug", 104, -40, true, "Something broken, or an idea? This gives you the link to the report page and a ready-made report to paste there.")
headBtn("RucksackWebsiteButton", "Website", 74, -148, false, "The link to Rucksack's website: what it does and what's new.")
f:HookScript("OnHide", function() if pop then pop:Hide() end end)
