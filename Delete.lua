-- Rucksack / Clean-up (was AutoDelete)
-- Replaces the game's "Do you want to destroy X?" Yes/No box with Always / Yes / No.
-- "Always" deletes the item now and remembers it. Remembered items are deleted on your next key
-- press (or a click on the trash button) once your bags are nearly full (fewer than minFree empty
-- slots), the cheapest stack first (vendor price x stack). An item set to "as soon as I get it"
-- (its page in the window) doesn't wait for full bags. Never in combat.
-- Why a key press: the game only lets an addon delete an item inside a click or a key press.
local _, ns = ...
local Print, SlotInfo, CursorItem = ns.Print, ns.SlotInfo, ns.CursorItem
local DB

local Del = {}
ns.Del = Del

---------------------------------------------------------------------------
-- Finding remembered items in the bags
---------------------------------------------------------------------------
local function FreeSlots()
  local free = 0
  for bag = 0, ns.NUM_BAGS do
    local n, family = ns.GetFree(bag)
    if n and (family == nil or family == 0) then free = free + n end
  end
  return free
end
Del.FreeSlots = FreeSlots
local function BagsNearlyFull() return FreeSlots() < (DB.minFree or 2) end
Del.BagsNearlyFull = function() return DB and BagsNearlyFull() end
-- all ordinary bag slots (for "6 of 80 free")
function Del.TotalSlots()
  local n = 0
  for bag = 0, ns.NUM_BAGS do
    local _, family = ns.GetFree(bag)
    if family == nil or family == 0 then n = n + (ns.GetNumSlots(bag) or 0) end
  end
  return n
end

local function sellPrice(id) return select(11, ns.GetInfo(id)) or 0 end

-- (9 Nov) "Also delete everything up to" a quality: Trash (grey), Common (white) or Uncommon
-- (green). Those wait for nearly full bags like the rest, cheapest stack first. Never caught:
-- items with no vendor price (hearthstone, quest and key items), items you set to keep, and, from
-- Common up, food and drink, potions, reagents, trade goods, bags, quest and key items.
Del.QUALITIES = { { nil, "Off" }, { 0, "Trash" }, { 1, "Common" }, { 2, "Uncommon" } }
local SAFE_CLASS = { [0] = true, [1] = true, [5] = true, [7] = true, [12] = true, [13] = true }
local function byQuality(id)
  if DB.upTo == nil or DB.keep[id] then return false end
  local name, _, quality, _, _, _, _, _, _, _, sell, classID = ns.GetInfo(id)
  if not name or not quality or quality > DB.upTo then return false end
  if not sell or sell <= 0 then return false end
  if classID == 12 or classID == 13 then return false end
  if quality >= 1 and classID and SAFE_CLASS[classID] then return false end
  return true
end
Del.ByQuality = function(id) return DB and byQuality(id) end
-- (10 Nov) Rations' rules: water on a character that drinks none (as soon as it lands), food and
-- water for below a level (when bags are nearly full). Keep wins over them too.
local function byFood(id)
  if DB.keep[id] or not (ns.Eat and ns.Eat.DeleteReason) then return nil end
  return ns.Eat.DeleteReason(id)
end
Del.ByFood = function(id) if DB then return byFood(id) end end
local function onList(id) return DB.items[id] or byQuality(id) or (byFood(id) and true) end
Del.OnList = function(id) return DB and onList(id) and true or false end
-- why an item goes, in words (for lists and tooltips)
function Del.Reason(id)
  if not DB then return nil end
  if DB.items[id] then return DB.now[id] and "on your list (as soon as you get it)" or "on your list" end
  if byQuality(id) then return "by its quality" end
  local why = byFood(id)
  if why then return why end
end
local function goesNow(id)
  if DB.now[id] then return true end
  local why, now = byFood(id)
  return why and now == "now"
end

-- Active quest item requirements: lowercase item name -> how many your current quests still want
-- in total (the objective's full amount: the items are handed in at the end). Read from the quest
-- log, with whichever quest API this client has; cached for a moment (bags and the log update a lot).
local reqCache, reqAt = nil, -1
local function GetQuestRequirements()
  local now = GetTime()
  if reqCache and now - reqAt < 0.5 then return reqCache end
  local reqByName = {}
  local seen = 0
  local function addObjective(text, numReq)
    if type(text) ~= "string" or text == "" then return end
    local name, _, r = text:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    if not name then
      local _, r2, name2 = text:match("^%s*(%d+)%s*/%s*(%d+)%s+(.+)$")
      if name2 then name, r = name2, r2 end
    end
    if name then
      name = name:gsub("^%s+", ""):gsub("%s+$", ""):lower()
      local need = tonumber(numReq) or tonumber(r) or 0
      if name ~= "" and need > 0 then
        reqByName[name] = (reqByName[name] or 0) + need
      end
    end
  end
  -- the older quest log (Classic clients): titles and objective lines by index
  if GetNumQuestLogEntries and GetQuestLogTitle and GetQuestLogLeaderBoard then
    local okN, num = pcall(GetNumQuestLogEntries)
    for i = 1, (okN and tonumber(num) or 0) do
      local okT, title, _, _, isHeader = pcall(GetQuestLogTitle, i)
      if okT and title and not isHeader then
        seen = seen + 1
        local nObj = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0
        for j = 1, nObj do
          local okL, text, objType = pcall(GetQuestLogLeaderBoard, j, i)
          if okL and (not objType or objType == "item" or objType == "object") then addObjective(text) end
        end
      end
    end
  end
  -- the newer one, when the older one isn't there (or found nothing)
  if seen == 0 and C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
    local okN, num = pcall(C_QuestLog.GetNumQuestLogEntries)
    for i = 1, (okN and tonumber(num) or 0) do
      local okI, info = pcall(C_QuestLog.GetInfo, i)
      if okI and info and not info.isHeader and info.questID then
        local okO, objs = pcall(C_QuestLog.GetQuestObjectives, info.questID)
        if okO and type(objs) == "table" then
          for _, obj in ipairs(objs) do
            if not obj.type or obj.type == "item" or obj.type == "object" then addObjective(obj.text, obj.numRequired) end
          end
        end
      end
    end
  end
  reqCache, reqAt = reqByName, now
  return reqByName
end

-- How many of item `id` your current quests need (0: none; math.huge: keep them all).
-- By its name in the quest objectives (also "Gnoll Paw" for "Gnoll Paws"). An item that starts a
-- quest you haven't taken yet is kept. Other quest items no current quest asks for may go.
local function QuestNeedForItem(id, link, bag, slot, reqMap)
  reqMap = reqMap or GetQuestRequirements()
  local nm = ns.NameOf(id, link)
  if nm then
    local low = nm:lower()
    local need = reqMap[low]
    if need and need > 0 then return need end
    if #low >= 4 then
      for key, n in pairs(reqMap) do
        if n > 0 and (key == low .. "s" or key == low .. "es" or low == key .. "s") then return n end
      end
    end
  end
  if bag and slot and ns.GetQuestInfo then
    local okQ, qi, qid, active = pcall(ns.GetQuestInfo, bag, slot)
    if okQ and qi then
      if type(qi) == "table" then qid, active = qi.questID, qi.isActive end
      if qid and not active then return math.huge end -- (starts a quest)
    end
  end
  return 0
end
Del.QuestNeed = function(id, link) return QuestNeedForItem(id, link, nil, nil, GetQuestRequirements()) end

-- The cheapest remembered stack (vendor price x count) that may go now, and how many items are
-- waiting in total. Quest items are protected up to the exact required quest amount; only excess
-- above the quest requirement is deleted!
local keptForQuest = {}
function Del.KeptForQuest() return keptForQuest end
local function ScanBags(ready)
  local best, bestValue, total, stacks = nil, nil, 0, 0
  wipe(keptForQuest)
  local full = BagsNearlyFull()
  local reqMap = GetQuestRequirements()
  local byID = {}
  for bag = 0, ns.NUM_BAGS do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, count, link, icon, locked = SlotInfo(bag, slot)
      if id and onList(id) then
        local g = byID[id]
        if not g then
          g = {
            id = id,
            total = 0,
            need = QuestNeedForItem(id, link, bag, slot, reqMap),
            slots = {},
          }
          byID[id] = g
        elseif g.need == 0 then
          local slotNeed = QuestNeedForItem(id, link, bag, slot, reqMap)
          if slotNeed > 0 then g.need = slotNeed end
        end
        g.total = g.total + count
        if not locked then
          g.slots[#g.slots + 1] = { bag = bag, slot = slot, id = id, count = count, link = link, icon = icon }
        end
      end
    end
  end
  for id, g in pairs(byID) do
    local excess = g.total - (g.need or 0)
    if g.need and g.need > 0 then keptForQuest[id] = math.min(g.need, g.total) end
    if excess > 0 and (not ready or full or goesNow(id)) then
      total = total + excess
      stacks = stacks + 1
      -- Prefer a slot whose stack count <= excess (so we can delete a whole small stack first),
      -- otherwise pick the smallest stack and split off `excess` from it!
      table.sort(g.slots, function(a, b) return a.count < b.count end)
      local chosen, delCount
      for _, s in ipairs(g.slots) do
        if s.count <= excess then
          chosen, delCount = s, s.count
          break
        end
      end
      if not chosen and g.slots[1] then
        chosen, delCount = g.slots[1], excess
      end
      if chosen and delCount and delCount > 0 then
        local value = sellPrice(id) * delCount
        if not best or value < bestValue then
          best = {
            bag = chosen.bag,
            slot = chosen.slot,
            id = id,
            count = chosen.count,
            deleteCount = delCount,
            link = chosen.link,
            icon = chosen.icon,
            questNeed = g.need,
          }
          bestValue = value
        end
      end
    end
  end
  return best, total, stacks
end
Del.Scan = function(ready) if DB then return ScanBags(ready) end end

local Refresh -- below

-- Deletes one remembered stack. Must be called from a click or a key press.
-- force = true (trash button / key binding): any remembered stack, full bags or not.
local function RecordMeta(id, link, count, wasDeleted, how)
  if not DB or not id then return end
  DB.meta = DB.meta or {}
  local m = DB.meta[id] or {}
  local l = (type(link) == "string" and link) or (type(DB.items[id]) == "string" and DB.items[id]) or m.link or ns.LinkOf(id)
  if l then m.link = l end
  local nm = ns.NameOf(id, l)
  if nm and not nm:match("^item %d+$") then m.name = nm end
  local ic = ns.GetIcon(id)
  if ic then m.icon = ic end
  local q = ns.QualityOf(id, l)
  if q ~= nil then m.quality = q end
  if wasDeleted then
    m.lastDeleted = time()
    m.deletedCount = (m.deletedCount or 0) + (count or 1)
    if how then m.lastHow = how end
    -- (10 Nov) the delete history: the last 100, newest first
    DB.history = DB.history or {}
    table.insert(DB.history, 1, { id = id, link = l, count = count or 1, t = m.lastDeleted, how = how })
    while #DB.history > 100 do table.remove(DB.history) end
  end
  DB.meta[id] = m
end
Del.RecordMeta = RecordMeta

local function DeleteOne(force)
  if not DB or not DB.enabled then return false end
  if InCombatLockdown() then return false end
  if CursorHasItem() or (SpellIsTargeting and SpellIsTargeting()) then return false end
  local it = ScanBags(not force)
  if not it then return false end
  local delCount = it.deleteCount or it.count
  if delCount < it.count and ns.SplitBagItem then
    ns.SplitBagItem(it.bag, it.slot, delCount)
  else
    delCount = it.count
    ns.PickupBagItem(it.bag, it.slot)
  end
  local id = CursorItem()
  if id == it.id then
    RecordMeta(it.id, it.link, delCount, true, DB.items[it.id] and "always" or byQuality(it.id) and "quality" or "rations")
    DeleteCursorItem()
    DB.deleted = (DB.deleted or 0) + delCount
    if DB.chat then
      local qNote = (it.questNeed and it.questNeed > 0 and it.questNeed < math.huge)
        and (" |cff66dd66(kept " .. it.questNeed .. " for quest)|r") or ""
      Print("deleted " .. (it.link or ns.NameOf(it.id)) .. (delCount > 1 and (" x" .. delCount) or "") .. qNote)
    end
    C_Timer.After(0.3, function() Refresh() end)
    return true
  end
  ClearCursor() -- the slot changed under us: delete nothing
  return false
end
function AutoDelete_DeleteNext() DeleteOne(true) end

function Del.Add(id, link)
  local savedLink = link or ns.LinkOf(id)
  DB.items[id] = savedLink or true
  DB.keep[id] = nil
  RecordMeta(id, savedLink, 0, false, "always")
  Refresh()
end
function Del.Remove(id)
  DB.items[id], DB.now[id] = nil, nil
  Refresh()
end

---------------------------------------------------------------------------
-- Key catcher: on any key press (out of combat) delete one waiting stack; the key still works
---------------------------------------------------------------------------
local keyCatcher = CreateFrame("Frame", "RucksackDeleteKeyCatcher", UIParent)
keyCatcher:SetAllPoints(UIParent)
keyCatcher:EnableMouse(false)
keyCatcher:EnableKeyboard(false)
local propagateOK = false
local function EnsurePropagate()
  if propagateOK or InCombatLockdown() then return end
  propagateOK = pcall(keyCatcher.SetPropagateKeyboardInput, keyCatcher, true)
  if propagateOK and keyCatcher.GetPropagateKeyboardInput then
    propagateOK = keyCatcher:GetPropagateKeyboardInput() and true or false
  end
end
EnsurePropagate()
keyCatcher:SetScript("OnKeyDown", function() DeleteOne() end)

---------------------------------------------------------------------------
-- The Always / Yes / No dialog
---------------------------------------------------------------------------
local ask = CreateFrame("Frame", "RucksackDeleteAsk", UIParent, ns.BACKDROP_TMPL)
ask:SetSize(400, 150)
ask:SetPoint("TOP", UIParent, "TOP", 0, -135)
ask:SetFrameStrata("FULLSCREEN_DIALOG")
ask:SetToplevel(true)
ask:EnableMouse(true)
ask:SetBackdrop(ns.DIALOG_BACKDROP)
ask:Hide()
tinsert(UISpecialFrames, "RucksackDeleteAsk") -- Esc closes it (counts as No)

local alert = ask:CreateTexture(nil, "ARTWORK")
alert:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
alert:SetSize(48, 48)
alert:SetPoint("LEFT", ask, "LEFT", 22, 14)

local askIcon = CreateFrame("Button", nil, ask)
askIcon:SetSize(36, 36)
askIcon:SetPoint("LEFT", alert, "RIGHT", 10, 0)
askIcon.tex = askIcon:CreateTexture(nil, "ARTWORK")
askIcon.tex:SetAllPoints()
askIcon:SetScript("OnEnter", function(self) if ask.data then ns.ShowItemTooltip(self, ask.data.id, ask.data.link) end end)
askIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)

local askText = ask:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
askText:SetPoint("TOPLEFT", askIcon, "TOPRIGHT", 10, 2)
askText:SetPoint("RIGHT", ask, "RIGHT", -22, 0)
askText:SetJustifyH("LEFT")

local askHint = ask:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
askHint:SetPoint("TOPLEFT", askText, "BOTTOMLEFT", 0, -6)
askHint:SetPoint("RIGHT", ask, "RIGHT", -22, 0)
askHint:SetJustifyH("LEFT")
askHint:SetText("Always = delete now and every time you get it.")

local askWarn = ask:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
askWarn:SetPoint("TOPLEFT", askHint, "BOTTOMLEFT", 0, -4)
askWarn:SetText("")

local function MakeButton(parent, text, w)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 110, 24)
  b:SetText(text)
  return b
end
local btnAlways = MakeButton(ask, "Always")
local btnYes = MakeButton(ask, "Yes")
local btnNo = MakeButton(ask, "No")
btnYes:SetPoint("BOTTOM", ask, "BOTTOM", 0, 18)
btnAlways:SetPoint("RIGHT", btnYes, "LEFT", -10, 0)
btnNo:SetPoint("LEFT", btnYes, "RIGHT", 10, 0)
btnAlways:GetFontString():SetTextColor(1, 0.35, 0.35)
btnAlways:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Always delete this item")
  GameTooltip:AddLine("Deletes it now, and from now on every time it lands in your bags.", 1, 1, 1, true)
  GameTooltip:AddLine("Undo it in Clean-up (/cleanup).", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end)
btnAlways:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function HideGamePopup() if ask.which then StaticPopup_Hide(ask.which) end end

local function Decide(action, button)
  local d = ask.data
  if not d then ask:Hide() return end
  -- rare and better items need a second click, like the game's "type DELETE"
  if action ~= "no" and d.quality and d.quality >= 3 and d.armed ~= action then
    d.armed = action
    btnAlways:SetText("Always"); btnYes:SetText("Yes")
    button:SetText("Click again")
    return
  end
  ask.decided = true
  if action == "no" then
    ClearCursor()
  else
    if action == "always" then
      DB.items[d.id] = d.link or true
      DB.keep[d.id] = nil
      RecordMeta(d.id, d.link, 1, true, "always")
      Print((d.link or ns.NameOf(d.id)) .. " will now always be deleted. (/cleanup to undo)")
    else
      RecordMeta(d.id, d.link, 1, true, "once")
    end
    if CursorItem() == d.id then
      DeleteCursorItem()
    else
      Print("the item is no longer on your cursor, nothing deleted.")
    end
  end
  HideGamePopup()
  ask:Hide()
  C_Timer.After(0.3, function() Refresh() end)
end
btnAlways:SetScript("OnClick", function(self) Decide("always", self) end)
btnYes:SetScript("OnClick", function(self) Decide("yes", self) end)
btnNo:SetScript("OnClick", function(self) Decide("no", self) end)

ask:SetScript("OnHide", function()
  if not ask.decided and ask.data and CursorItem() == ask.data.id then ClearCursor() end -- Esc = No
  HideGamePopup()
  ask.data, ask.which = nil, nil
end)
-- the item left the cursor some other way (put back in a bag): close quietly
ask:SetScript("OnUpdate", function(self)
  if self.data and CursorItem() ~= self.data.id then
    self.decided = true
    self:Hide()
  end
end)

local function ShowAsk(id, link, which)
  local _, _, quality = ns.GetInfo(link or id)
  ask.data = { id = id, link = link, quality = quality }
  ask.which = which
  ask.decided = false
  askIcon.tex:SetTexture(ns.GetIcon(id))
  askText:SetText("Do you want to destroy " .. (link or ns.NameOf(id)) .. "?")
  askWarn:SetText(quality and quality >= 3 and "This is a rare or better item. Click twice to confirm." or "")
  btnAlways:SetText("Always"); btnYes:SetText("Yes"); btnNo:SetText("No")
  ask:Show()
  ask:Raise()
end

-- take over the game's delete confirmation popups
local DELETE_POPUPS = { DELETE_ITEM = true, DELETE_GOOD_ITEM = true, DELETE_QUEST_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
local function FindPopupFrame(which)
  local a, b = StaticPopup_Visible(which)
  if type(b) == "table" then return b end
  if type(a) == "table" then return a end
  if type(a) == "string" then return _G[a] end
end
hooksecurefunc("StaticPopup_Show", function(which)
  if not DB or not DB.enabled or not DELETE_POPUPS[which] then return end
  local id, link = CursorItem()
  if not id then return end
  -- the game's popup stays open (it owns the delete), invisible and out of the way
  local f = FindPopupFrame(which)
  if f then
    f:SetAlpha(0)
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "BOTTOM", 0, -2000)
    local eb = f.editBox or f.EditBox or (f.GetName and f:GetName() and _G[f:GetName() .. "EditBox"])
    if eb and eb.ClearFocus then eb:ClearFocus() end
    if not f.autoDeleteHooked then
      f.autoDeleteHooked = true
      f:HookScript("OnHide", function(self) self:SetAlpha(1) end)
    end
  end
  ShowAsk(id, link, which)
end)

---------------------------------------------------------------------------
-- Trash button on screen: always there (unless turned off); lit when a stack is waiting
---------------------------------------------------------------------------
local pend = CreateFrame("Button", "RucksackDeleteButton", UIParent, ns.BACKDROP_TMPL)
pend:SetSize(44, 44)
pend:SetFrameStrata("MEDIUM")
pend:SetMovable(true)
pend:SetClampedToScreen(true)
pend:RegisterForClicks("LeftButtonUp", "RightButtonUp")
pend:RegisterForDrag("LeftButton")
pend:SetBackdrop(ns.SLOT_BACKDROP)
pend:SetBackdropBorderColor(1, 0.3, 0.3)
pend:Hide()
pend.icon = pend:CreateTexture(nil, "ARTWORK")
pend.icon:SetPoint("TOPLEFT", 5, -5)
pend.icon:SetPoint("BOTTOMRIGHT", -5, 5)
pend.trash = pend:CreateTexture(nil, "OVERLAY")
pend.trash:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
pend.trash:SetSize(18, 18)
pend.trash:SetPoint("TOPRIGHT", 4, 4)
pend.count = pend:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
pend.count:SetPoint("BOTTOMRIGHT", -4, 4)
pend.label = pend:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pend.label:SetPoint("TOP", pend, "BOTTOM", 0, -2)

pend:SetScript("OnClick", function(self, button)
  if button == "RightButton" or not self.waiting then Rucksack_Open("del") return end
  if InCombatLockdown() then Print("waiting until combat ends.") return end
  DeleteOne(true)
end)
pend:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
pend:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  DB.pendPos = { p, rp, x, y }
end)
pend:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cffff5555Clean-up|r")
  local it, total = ScanBags(false)
  if not it then
    GameTooltip:AddLine("Nothing waiting to be deleted.", 1, 1, 1)
  else
    GameTooltip:AddLine("Next: " .. (it.link or "?") .. (it.count > 1 and (" x" .. it.count) or ""), 1, 1, 1)
    GameTooltip:AddLine(total .. " item(s) on your list in your bags.", 1, 1, 1)
    if not self.waiting then
      GameTooltip:AddLine("Waits until your bags are nearly full.", 0.7, 0.7, 0.7, true)
    elseif InCombatLockdown() then
      GameTooltip:AddLine("In combat: deletes after combat.", 1, 0.5, 0.5)
    elseif DB.onKey then
      GameTooltip:AddLine("Deletes on your next key press, or click here.", 0.6, 1, 0.6, true)
    else
      GameTooltip:AddLine("Click to delete.", 0.6, 1, 0.6)
    end
  end
  GameTooltip:AddLine(self.waiting and "Right-click: Clean-up settings. Shift-drag to move." or "Click: Clean-up settings. Shift-drag to move.", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
pend:SetScript("OnLeave", function() GameTooltip:Hide() end)

Refresh = function()
  if not DB then return end
  local it, total = ScanBags(true)
  if DB.enabled and it then
    pend.waiting = true
    pend.icon:SetTexture(it.icon or ns.GetIcon(it.id))
    pend.icon:SetDesaturated(false)
    pend.icon:SetAlpha(1)
    pend:SetBackdropBorderColor(1, 0.3, 0.3)
    pend.count:SetText(total > 1 and total or "")
    pend.label:SetText(InCombatLockdown() and "|cffff8080after combat|r" or "")
    pend:Show()
  elseif DB.alwaysIcon then
    -- nothing waiting: a quiet grey bag with the red X; a click opens Rucksack
    pend.waiting = nil
    pend.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Red")
    pend.icon:SetDesaturated(true)
    pend.icon:SetAlpha(0.8)
    pend:SetBackdropBorderColor(0.5, 0.5, 0.5)
    pend.count:SetText("")
    pend.label:SetText("")
    pend:Show()
  else
    pend.waiting = nil
    pend:Hide()
  end
  if not InCombatLockdown() then
    EnsurePropagate()
    keyCatcher:EnableKeyboard((DB.enabled and DB.onKey and it and propagateOK) and true or false)
  end
  ns.Changed()
end
Del.Refresh = function() Refresh() end

table.insert(ns.onLoad, function()
  DB = ns.del
  DB.items = DB.items or {}
  DB.now = DB.now or {}
  DB.keep = DB.keep or {}
  DB.meta = DB.meta or {}
  for id, v in pairs(DB.items) do
    RecordMeta(id, type(v) == "string" and v or nil, 0, false)
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
  if DB.enabled == nil then DB.enabled = true end
  if DB.onKey == nil then DB.onKey = true end
  if DB.chat == nil then DB.chat = true end
  if DB.minFree == nil then DB.minFree = 2 end
  -- (10 Nov) grey items (trash) go automatically: the quality rule starts at "Trash". Switched on
  -- once for saves from before; a higher setting (Common, Uncommon) already includes trash.
  -- (10 Nov) the delete history starts with what was deleted before (one line per item, its last time)
  if not DB.history then
    DB.history = {}
    for id, m in pairs(DB.meta) do
      if m.lastDeleted then DB.history[#DB.history + 1] = { id = id, link = m.link, t = m.lastDeleted, how = m.lastHow } end
    end
    table.sort(DB.history, function(a, b) return a.t > b.t end)
    while #DB.history > 100 do table.remove(DB.history) end
  end
  if not DB.greyDefault then
    if DB.upTo == nil then DB.upTo = 0 end
    DB.greyDefault = true
  end
  -- (9 Nov) the always-on bag icon is gone (the minimap button opens Rucksack now); the trash
  -- button still shows when something is waiting to be deleted
  if not DB.iconRemoved then DB.alwaysIcon = false DB.iconRemoved = true end
  pend:ClearAllPoints()
  if DB.pendPos then
    local p, rp, x, y = unpack(DB.pendPos)
    pend:SetPoint(p, UIParent, rp, x, y)
  else
    pend:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
  end
end)
table.insert(ns.onLogin, function() Refresh() end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, e) if e == "QUEST_LOG_UPDATE" then reqAt = -1 end Refresh() end)

-- /cleanup (/adel): Rucksack on the Clean-up page; /cleanup icon: the trash button always on screen or not
SLASH_RUCKSACKDEL1 = "/cleanup"
SLASH_RUCKSACKDEL2 = "/adel"
SlashCmdList.RUCKSACKDEL = function(msg)
  if (msg or ""):lower() == "icon" then
    DB.alwaysIcon = not DB.alwaysIcon
    Print(DB.alwaysIcon and "trash icon always on screen." or "trash icon only when items are waiting.")
    Refresh()
    return
  end
  Rucksack_Open("del")
end
