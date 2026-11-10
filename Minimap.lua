-- Rucksack / the minimap button: a leather backpack on the minimap's edge, in the same round
-- trim as the game's own minimap buttons. Left-click: open Rucksack. Right-click: show or hide the
-- Pocket. Drag: move it around the edge. Off: Settings page, or /ruck minimap.
local _, ns = ...

local b = CreateFrame("Button", "RucksackMinimapButton", Minimap)
b:SetSize(31, 31)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = b:CreateTexture(nil, "BACKGROUND")
bg:SetSize(24, 24)
bg:SetPoint("CENTER", 0, 1)
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
local icon = b:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
icon:SetTexture(ns.ICON)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
b.icon = icon
-- a round mask, when the client has one, so the square icon sits in the ring like Blizzard's
if b.CreateMaskTexture then
  local mask = b:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(icon)
  icon:AddMaskTexture(mask)
end
local border = b:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function place()
  local angle = math.rad(ns.db.minimapAngle or 200)
  local r = (Minimap:GetWidth() / 2) + 5
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

b:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", 1, 0) end) -- (pressed in a little)
b:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", 0, 1) end)
b:SetScript("OnClick", function(_, mouse)
  if mouse == "RightButton" then if ns.Pocket then ns.Pocket.Toggle() end else Rucksack_Toggle() end
end)
b:SetScript("OnDragStart", function(self)
  self:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    ns.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
    place()
  end)
end)
b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) icon:SetPoint("CENTER", 0, 1) end)
b:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cffc8a165Ruck|r|cffffd100sack|r")
  local fd, dr = ns.Eat.food, ns.Eat.drink
  if ns.eat.enabled ~= false then
    GameTooltip:AddDoubleLine("Next food", fd and ns.NameOf(fd) .. " x" .. (ns.GetCount(fd) or 0) or "none", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Next water", dr and ns.NameOf(dr) .. " x" .. (ns.GetCount(dr) or 0) or "none", 1, 1, 1, 1, 1, 1)
  end
  local _, waiting = ns.Del.Scan(false)
  if ns.del.enabled and waiting and waiting > 0 then
    GameTooltip:AddDoubleLine("To delete", waiting .. " item(s)", 1, 1, 1, 1, 0.4, 0.4)
  end
  GameTooltip:AddLine("Left-click: open.  Right-click: the Pocket.  Drag: move.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end)
b:SetScript("OnLeave", function() GameTooltip:Hide() end)
b:Hide()

function ns.UpdateMinimapButton()
  if ns.db.minimapHidden then b:Hide() else place() b:Show() end
end
table.insert(ns.onLogin, function() ns.UpdateMinimapButton() end)
