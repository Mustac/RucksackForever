-- Rucksack: the one-time message for 1.9 (17 Nov): Rucksack is a bag addon now.
-- He: "if someone has just a filter turned on without bag make a one time pop up saying that
-- Rucksack is moving from filter bag addon to exclusivly bag addon and ask people to try it and
-- enjoy full expirience by disabling other bag addons". Once per account, for players who had
-- Rucksack before (a new install never sees it). Not in a fight. Whoever had Clean-up or Bags on
-- already has the bag (Core.lua turned it on); someone who had both off gets a button to try it.
-- If another bag addon is running, a button turns it off and reloads.
local ADDON, ns = ...

local OTHERS = { "Bagnon", "Baganator", "AdiBags", "ArkInventory", "BetterBags", "Combuctor", "Inventorian",
  "LiteBag", "Sorted", "OneBag3", "cargBags_Nivaya", "BaudBag", "TBag", "Bagshui" }
local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn

local function othersRunning()
  local out = {}
  for _, name in ipairs(OTHERS) do
    local ok, on = pcall(isLoaded, name)
    if ok and on then out[#out + 1] = name end
  end
  return out
end
local function names(list)
  if #list <= 1 then return list[1] or "" end
  return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

local box
local function build()
  box = CreateFrame("Frame", "RucksackNews", UIParent, ns.BACKDROP_TMPL)
  box:SetSize(440, 200)
  box:SetPoint("CENTER", 0, 120)
  box:SetFrameStrata("DIALOG")
  box:SetToplevel(true)
  box:EnableMouse(true)
  box:SetClampedToScreen(true)
  if box.SetBackdrop then box:SetBackdrop(ns.DIALOG_BACKDROP) end
  local icon = box:CreateTexture(nil, "ARTWORK")
  icon:SetSize(40, 40)
  icon:SetPoint("TOPLEFT", 22, -22)
  icon:SetTexture(ns.ICON)
  box.title = box:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  box.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
  box.title:SetText("Rucksack is now a bag addon")
  box.text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  box.text:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -10)
  box.text:SetWidth(330)
  box.text:SetJustifyH("LEFT")
  box.text:SetSpacing(2)
  box.yes = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
  box.yes:SetHeight(24)
  box.no = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
  box.no:SetSize(100, 24)
  box.no:SetPoint("BOTTOMRIGHT", -22, 20)
  box.no:SetScript("OnClick", function() box:Hide() end)
  box.yes:SetPoint("RIGHT", box.no, "LEFT", -8, 0)
  box:Hide()
end

local function show()
  if not box then build() end
  local others = othersRunning()
  local bagOn = ns.ModuleWanted("bags")
  local lines = {}
  lines[1] = "Selling, deleting and sending to the bank are now part of Rucksack's own bag, with a window for each beside it."
  if bagOn then
    lines[2] = "Your bag is on. Give it a try: press B."
  else
    lines[2] = "Want to try it? It's one click."
  end
  if #others > 0 then
    lines[3] = "For the full experience, turn off your other bag addon" .. (#others > 1 and "s" or "") .. ": |cffffd100" .. names(others) .. "|r."
  end
  box.text:SetText(table.concat(lines, "\n\n"))
  local yes, act
  if not bagOn and #others > 0 then
    yes = "Turn on the bag, turn off " .. names(others)
    act = "both"
  elseif not bagOn then
    yes = "Turn on the bag"
    act = "bag"
  elseif #others > 0 then
    yes = "Turn off " .. names(others) .. " and reload"
    act = "others"
  end
  if yes then
    box.yes:SetText(yes)
    box.yes:SetWidth(math.max(140, (box.yes:GetFontString() and box.yes:GetFontString():GetStringWidth() or 200) + 30))
    box.yes:Show()
    box.no:SetText(bagOn and "Later" or "Not now")
  else
    box.yes:Hide()
    box.no:SetText("OK")
  end
  box.yes:SetScript("OnClick", function()
    box:Hide()
    if act == "bag" or act == "both" then
      ns.SetModuleWanted("bags", true)
      if act == "bag" and not InCombatLockdown() then
        for _, m in ipairs(ns.MODULES) do
          if (m.key == "del" or m.key == "bags") then ns.LoadModule(m) end
        end
        ns.Print("your bag is on. Press B to open it.")
        if ns.Changed then ns.Changed() end
        return
      end
    end
    if act == "others" or act == "both" then
      for _, name in ipairs(others) do pcall(disable, name) end
    end
    ReloadUI()
  end)
  box:SetHeight(math.max(170, 104 + (box.text:GetStringHeight() or 60)))
  box:Show()
end
ns.ShowNews = show -- (for the test scripts)

local waiting
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg)
  if event == "ADDON_LOADED" then
    if arg ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    -- (Core.lua made RucksackDB already: ns.newInstall says whether it was empty)
    if ns.newInstall then RucksackDB.bagAddonNews = true return end
    if RucksackDB.bagAddonNews then return end
    self:RegisterEvent("PLAYER_LOGIN")
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(12, function()
      if RucksackDB.bagAddonNews then return end
      if InCombatLockdown() then waiting = true self:RegisterEvent("PLAYER_REGEN_ENABLED") return end
      RucksackDB.bagAddonNews = true
      show()
    end)
  elseif event == "PLAYER_REGEN_ENABLED" and waiting then
    waiting = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    C_Timer.After(2, function()
      if RucksackDB.bagAddonNews or InCombatLockdown() then return end
      RucksackDB.bagAddonNews = true
      show()
    end)
  end
end)
