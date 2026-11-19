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

-- (19 Nov) "What's new" once after an update. He: "can you write me notification when I update in very
-- short what we did and new feature that is on now", then "popup in wow". Shown once per account per
-- WHATSNEW (RucksackDB.whatsNew), 14 s after login, not in a fight, after the bag-addon message above
-- when that one shows too. A new install never sees it. For the next release: change WHATSNEW and TEXT.
local WHATSNEW = "1.9.13"
local SEEN = "1.9.13.7" -- (what's stored as seen; raised when the text changes, so it shows once more)
local G, W = "|cffffd100", "|r"
local TEXT = table.concat({
  G .. "New, and already on:" .. W,
  "- " .. G .. "Haul" .. W .. " shows what your loot is worth and your gold per hour. Open it with the Haul button under Rucksack's icon in your bag. In Haul:",
  "     " .. G .. "Sort loot" .. W .. ": loot a vendor pays more for goes on Sell.",
  "     " .. G .. "Check bag" .. W .. ": marks what's better sold to a vendor.",
  "     " .. G .. "Reset" .. W .. ": starts the count from zero.",
  "     Auction prices come from one of these addons: " .. G .. "Auctionator, auxForever, AHledger, GoldScout, CraftProfit or Hammerprice" .. W .. ". Without one of them, Haul and the gold coin don't work.",
  "- " .. G .. "Gold coin" .. W .. " on items a vendor pays more for than the auction house (after its cut). At a vendor, one button sells them all.",
  "- " .. G .. "Track bars" .. W .. ": keep items on screen with how many you carry, click to use them, drag one off to take it off. Up to 5, from the tool row.",
  "- " .. G .. "Armour sets" .. W .. " from the game's equipment manager: their own group, a red border, never sold, deleted or disenchanted.",
  "- " .. G .. "Quest marks" .. W .. ": ! starts a quest, a gold border means a quest item, !? means a quest of yours needs it.",
  "- " .. G .. "Tool row" .. W .. " under Rucksack's icon: Haul, Track, Restock, Hidden. " .. G .. "Look" .. W .. " goes Rows, Packed, One bag.",
  "- The Once box has sell and delete ticks, like Always.",
  " ",
  G .. "Better:" .. W,
  "- Items no longer jump around while auction house addons scan.",
  "- Drag an item and the others make room; it lands right where you drop it.",
  "- Food, water and potions are together in Consumables.",
  "- Restock and Hidden are simpler.",
  "- Profession tools you don't need can be sold.",
  "- Your other characters' bags and gold are remembered properly.",
  "- Learning a recipe isn't blocked any more.",
}, "\n")

local wbox
local function buildWhatsNew()
  wbox = CreateFrame("Frame", "RucksackWhatsNew", UIParent, ns.BACKDROP_TMPL)
  wbox:SetWidth(460)
  wbox:SetPoint("CENTER", 0, 100)
  wbox:SetFrameStrata("DIALOG")
  wbox:SetToplevel(true)
  wbox:EnableMouse(true)
  wbox:SetMovable(true)
  wbox:RegisterForDrag("LeftButton")
  wbox:SetScript("OnDragStart", wbox.StartMoving)
  wbox:SetScript("OnDragStop", wbox.StopMovingOrSizing)
  wbox:SetClampedToScreen(true)
  if wbox.SetBackdrop then wbox:SetBackdrop(ns.DIALOG_BACKDROP) end
  -- (19 Nov: a solid dark back, so the bag behind it doesn't show through the text)
  local back = wbox:CreateTexture(nil, "BACKGROUND", nil, 1)
  back:SetPoint("TOPLEFT", 11, -12)
  back:SetPoint("BOTTOMRIGHT", -12, 11)
  back:SetColorTexture(0.05, 0.04, 0.03, 0.94)
  local icon = wbox:CreateTexture(nil, "ARTWORK")
  icon:SetSize(40, 40)
  icon:SetPoint("TOPLEFT", 22, -22)
  icon:SetTexture(ns.ICON)
  wbox.title = wbox:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  wbox.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
  wbox.title:SetText("Rucksack " .. WHATSNEW .. ": what's new")
  wbox.text = wbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  wbox.text:SetPoint("TOPLEFT", wbox.title, "BOTTOMLEFT", 0, -10)
  wbox.text:SetWidth(350)
  wbox.text:SetJustifyH("LEFT")
  wbox.text:SetSpacing(2)
  wbox.ok = CreateFrame("Button", nil, wbox, "UIPanelButtonTemplate")
  wbox.ok:SetSize(100, 24)
  wbox.ok:SetPoint("BOTTOMRIGHT", -22, 20)
  wbox.ok:SetText("Close")
  wbox.ok:SetScript("OnClick", function() wbox:Hide() end)
  tinsert(UISpecialFrames, "RucksackWhatsNew") -- (Escape closes it)
  wbox:Hide()
end
local function showWhatsNew()
  if not wbox then buildWhatsNew() end
  RucksackDB.whatsNew = SEEN
  wbox.text:SetText(TEXT)
  wbox:SetHeight(math.max(170, 112 + (wbox.text:GetStringHeight() or 200)))
  wbox:Show()
end
ns.ShowWhatsNew = showWhatsNew -- (for the test scripts)

local wwait
local wev = CreateFrame("Frame")
wev:RegisterEvent("ADDON_LOADED")
local function tryWhatsNew()
  if RucksackDB.whatsNew == SEEN then return end
  if InCombatLockdown() then wwait = true wev:RegisterEvent("PLAYER_REGEN_ENABLED") return end
  local other = rawget(_G, "RucksackNews")
  if other and other:IsShown() then -- (the bag-addon message first; this one after it's closed)
    other:HookScript("OnHide", function() C_Timer.After(1, tryWhatsNew) end)
    return
  end
  showWhatsNew()
end
wev:SetScript("OnEvent", function(self, event, arg)
  if event == "ADDON_LOADED" then
    if arg ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    if ns.newInstall then RucksackDB.whatsNew = SEEN return end
    if RucksackDB.whatsNew == SEEN then return end
    self:RegisterEvent("PLAYER_LOGIN")
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(14, tryWhatsNew)
  elseif event == "PLAYER_REGEN_ENABLED" and wwait then
    wwait = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    C_Timer.After(2, tryWhatsNew)
  end
end)
