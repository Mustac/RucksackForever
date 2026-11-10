-- Rucksack / Darkmoon Faire: map pins: click a farm spot and it's marked on your world map (and the game's own
-- waypoint, and TomTom if you have it). Shift-click pins every spot for that item.
local RS = Rucksack
if not RS then return end
RS.Faire = RS.Faire or {}
local ns = RS.Faire -- (the Faire keeps its own little namespace inside Rucksack)
local Map = {}
ns.Map = Map

local pins = {}   -- { map, x, y, label }
local marks = {}  -- the little pin frames on the world map

local function canvas()
  local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
  return sc and sc.Child
end

local function draw()
  for _, m in ipairs(marks) do m:Hide() end
  local child = canvas()
  if not child or not WorldMapFrame:IsShown() then return end
  local shown = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local w, h = child:GetWidth(), child:GetHeight()
  local scale = child:GetScale() or 1 -- (the map canvas is scaled when you zoom; pins stay one size)
  local i = 0
  for _, p in ipairs(pins) do
    if p.map == shown then
      i = i + 1
      local m = marks[i]
      if not m then
        m = CreateFrame("Frame", nil, child)
        m:SetSize(26, 26)
        m.tex = m:CreateTexture(nil, "OVERLAY")
        m.tex:SetAllPoints()
        m.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1") -- (the yellow star)
        m.ring = m:CreateTexture(nil, "ARTWORK")
        m.ring:SetPoint("CENTER")
        m.ring:SetSize(34, 34)
        m.ring:SetTexture("Interface\\Minimap\\Ping\\ping5")
        m:EnableMouse(true)
        m:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:AddLine(self.label or "Darkmoon Faire")
          GameTooltip:AddLine("Rucksack pin.  /faire clear removes the pins.", 0.7, 0.7, 0.7, true)
          GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        marks[i] = m
      end
      m:SetFrameLevel(child:GetFrameLevel() + 2000)
      m:SetScale(1 / math.max(scale, 0.01))
      m:ClearAllPoints()
      m:SetPoint("CENTER", child, "TOPLEFT", (p.x / 100) * w * scale, -(p.y / 100) * h * scale)
      m.label = p.label
      m:Show()
    end
  end
end
Map.Draw = draw

local hooked = false
local function hook()
  if hooked or not WorldMapFrame then return end
  hooked = true
  if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", draw) end
  WorldMapFrame:HookScript("OnShow", draw)
  if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.HookScript then
    WorldMapFrame.ScrollContainer:HookScript("OnMouseWheel", function() C_Timer.After(0, draw) end)
  end
end

local function blizzWaypoint(p)
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(p.map, p.x / 100, p.y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  return ok
end
local function tomtom(p)
  if not (TomTom and TomTom.AddWaypoint) then return end
  local ok, uid = pcall(TomTom.AddWaypoint, TomTom, p.map, p.x / 100, p.y / 100, { title = p.label, persistent = false })
  if ok and uid then p.tomtom = uid end
end

-- add a pin; keep = add to the ones already there (shift-click)
function Map.Pin(p, keep, quiet)
  hook()
  if not keep then Map.Clear(true) end
  pins[#pins + 1] = p
  blizzWaypoint(p)
  tomtom(p)
  if not quiet then
    ns.Print(("pinned |cffffd100%s|r  %s %.1f, %.1f"):format(p.label or "?", p.zone or "", p.x, p.y))
  end
  if not InCombatLockdown() then
    if not WorldMapFrame:IsShown() then
      if OpenWorldMap then pcall(OpenWorldMap, p.map) else ShowUIPanel(WorldMapFrame) end
    end
    if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, p.map) end
  end
  C_Timer.After(0, draw)
end

function Map.Clear(quiet)
  for _, p in ipairs(pins) do
    if p.tomtom and TomTom and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, p.tomtom) end
  end
  wipe(pins)
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
  draw()
  if not quiet then ns.Print("pins cleared.") end
end
function Map.Count() return #pins end
