-- Rucksack / Auto open (15 Nov). Settings: "Open clams and pouches by itself".
-- Things in your bags that say "Right Click to Open" and open at once (clams, pouches, bags of
-- loot) are opened one at a time, as soon as it's safe. Not locked boxes, not things with a cast.
-- Bags full: it waits for a free slot. Clean-up frees one the usual way (the cheapest junk, on your
-- next key press), then the rest is opened.
-- NEVER at a vendor, bank, mailbox, trade or auction house: there the same call that opens an item
-- would sell it, bank it, mail it or trade it. Both the events and the game's frames are checked.
-- If the game won't let an addon open things without a click, an Open button shows up instead.
local ns = Rucksack
if not ns then return end
local Print = ns.Print

local A = {}
ns.AutoOpen = A

local C = C_Container
local function useItem(bag, slot)
  if C and C.UseContainerItem then return C.UseContainerItem(bag, slot) end
  if UseContainerItem then return UseContainerItem(bag, slot) end
end

-- windows that change what a right-click on an item does
local OPENERS = { MERCHANT_SHOW = "MERCHANT_CLOSED", MAIL_SHOW = "MAIL_CLOSED", BANKFRAME_OPENED = "BANKFRAME_CLOSED",
  AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED", TRADE_SHOW = "TRADE_CLOSED" }
local CLOSERS = {}
for o, c in pairs(OPENERS) do CLOSERS[c] = o end
local away = {}            -- [opener event] = true while that window is open
local lootOpen, lootMine = false, false
local opening              -- { id, at } the item we just used
local lastAt = 0
local tries, gaveUp = {}, {}
local bagsMoved = true     -- something in the bags changed since our last try (so the try did something)
local blocked = false      -- the game refused: only the button from now on
local pending = false
local run

-- (16 Nov: on unless you switch it off; he had never found the switch and thought it was broken)
local function on() return ns.db and ns.db.autoOpen ~= false end
function A.On() return on() end
function A.Blocked() return blocked end

local function frameUp(name) local f = _G[name] return f and f.IsShown and f:IsShown() and (not f.GetAlpha or f:GetAlpha() > 0.01) end
local function canAct()
  if InCombatLockdown() or next(away) or lootOpen then return false end
  if frameUp("MerchantFrame") or frameUp("TradeFrame") or frameUp("MailFrame") or frameUp("AuctionHouseFrame") or frameUp("AuctionFrame") then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
  if (UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player")) then return false end
  if (CursorHasItem and CursorHasItem()) or (SpellIsTargeting and SpellIsTargeting()) then return false end
  if UnitOnTaxi and UnitOnTaxi("player") then return false end
  return true
end

local function freeSlots()
  local n = 0
  for bag = 0, ns.NUM_BAGS do
    local free, family = ns.GetFree(bag)
    if (family or 0) == 0 then n = n + (free or 0) end
  end
  return n
end

-- a locked lockbox says "Locked" in its tooltip
local scanTip
local function isLocked(bag, slot)
  local word = LOCKED or "Locked"
  if C_TooltipInfo and C_TooltipInfo.GetBagItem then
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if ok and data and data.lines then
      for _, l in ipairs(data.lines) do if l.leftText == word then return true end end
      return false
    end
  end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "RucksackOpenScanTip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
  end
  scanTip:ClearLines()
  local ok = pcall(scanTip.SetBagItem, scanTip, bag, slot)
  if not ok then return false end
  for i = 2, scanTip:NumLines() do
    local fs = _G["RucksackOpenScanTipTextLeft" .. i]
    if fs and fs:GetText() == word then return true end
  end
  return false
end
-- does using it take a cast? (only things that open at once are opened by itself)
local function hasCast(id)
  local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  if not getSpell then return false end
  local ok, _, spellID = pcall(getSpell, id)
  if not ok or not spellID then return false end
  local castTime
  if C_Spell and C_Spell.GetSpellInfo then
    local ok2, info = pcall(C_Spell.GetSpellInfo, spellID)
    castTime = ok2 and info and info.castTime
  elseif GetSpellInfo then
    castTime = select(4, GetSpellInfo(spellID))
  end
  return (castTime or 0) > 0
end
-- the slot's item if it can be opened by itself
local function openable(bag, slot)
  local id, lootable, slotLocked, link
  if C and C.GetContainerItemInfo then
    local i = C.GetContainerItemInfo(bag, slot)
    if not i then return nil end
    id, lootable, slotLocked, link = i.itemID, i.hasLoot, i.isLocked, i.hyperlink
  elseif GetContainerItemInfo then
    local _, _, locked, _, _, loot, l, _, _, itemID = GetContainerItemInfo(bag, slot)
    id, lootable, slotLocked, link = itemID, loot, locked, l
  end
  if not id or not lootable or slotLocked or gaveUp[id] then return nil end
  if ns.db.noOpen and ns.db.noOpen[id] then return nil end
  if hasCast(id) or isLocked(bag, slot) then return nil end
  return id, link
end
-- the first one in the bags, and how many there are
local function findNext()
  local fb, fs, fid, flink, n = nil, nil, nil, nil, 0
  for bag = 0, ns.NUM_BAGS do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, link = openable(bag, slot)
      if id then
        n = n + 1
        if not fb then fb, fs, fid, flink = bag, slot, id, link end
      end
    end
  end
  return fb, fs, fid, flink, n
end
A.FindNext = findNext
-- (16 Nov) this slot will be opened by itself: Clean-up doesn't sell it or throw it away meanwhile
local willCache = {}
function A.WillOpen(bag, slot)
  if not on() or not bag or not slot or not C or not C.GetContainerItemInfo then return false end
  local i = C.GetContainerItemInfo(bag, slot)
  if not i or not i.hasLoot or not i.itemID or gaveUp[i.itemID] then return false end
  if ns.db.noOpen and ns.db.noOpen[i.itemID] then return false end
  if willCache[i.itemID] == nil then willCache[i.itemID] = not hasCast(i.itemID) end
  return willCache[i.itemID] and not isLocked(bag, slot)
end

local function schedule(sec)
  if pending then return end
  pending = true
  C_Timer.After(sec or 0.5, function() pending = false run() end)
end

---------------------------------------------------------------------------
-- If the game refuses: a button. One click opens the next one.
---------------------------------------------------------------------------
local btn
local function makeButton()
  if btn then return btn end
  btn = CreateFrame("Button", "RucksackOpenButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
  btn:SetSize(40, 40)
  btn:SetFrameStrata("MEDIUM")
  btn:SetClampedToScreen(true)
  btn:SetMovable(true)
  btn:RegisterForClicks("AnyDown")
  btn:RegisterForDrag("LeftButton")
  if btn.SetBackdrop then
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btn:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
    btn:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
  end
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetPoint("TOPLEFT", 3, -3)
  btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  btn.count:SetPoint("BOTTOMRIGHT", -2, 2)
  local hl = btn:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(btn.icon)
  hl:SetColorTexture(1, 1, 1, 0.15)
  btn:SetAttribute("type", "macro")
  btn:SetScript("OnDragStart", function(self) if IsShiftKeyDown() and not InCombatLockdown() then self:StartMoving() end end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.openPos = { p, rp, x, y }
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Open  |cff999999(Rucksack)|r")
    GameTooltip:AddLine("Click: opens the next clam, pouch or bag of loot in your bags. The game doesn't let Rucksack do it without a click here.", 1, 1, 1, true)
    GameTooltip:AddLine("Shift-drag to move.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  btn:Hide()
  return btn
end
local function paintButton()
  if InCombatLockdown() then return end -- (a secure button only changes out of combat)
  if not (blocked and on()) then if btn then btn:Hide() end return end
  local bag, slot, id, _, n = findNext()
  local b = makeButton()
  if not bag or freeSlots() < 1 then b:Hide() return end
  b:SetAttribute("macrotext", "/use " .. bag .. " " .. slot)
  b.icon:SetTexture(ns.GetIcon and ns.GetIcon(id) or "Interface\\Icons\\INV_Misc_Bag_10")
  b.count:SetText(n > 1 and n or "")
  if not b:IsShown() then
    b:ClearAllPoints()
    local pos = ns.db.openPos
    if pos then b:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else b:SetPoint("CENTER", UIParent, "CENTER", 180, -120) end
    b:Show()
  end
end

---------------------------------------------------------------------------
-- The loop: one item, then wait for the loot to land
---------------------------------------------------------------------------
run = function()
  if not on() then if btn and not InCombatLockdown() then btn:Hide() end return end
  if blocked then paintButton() return end
  local bag, slot, id, link = findNext()
  if not bag then return end
  if not canAct() then schedule(2) return end           -- (something's in the way: look again soon)
  local now = GetTime()
  if now - lastAt < 0.7 then schedule(0.7) return end
  local free = freeSlots()
  if free < 1 then return end                           -- (full: a bag update brings us back once there's room)
  -- three tries in a row that changed nothing in the bags: it isn't opening (or nothing in it can be
  -- taken). Also a hard stop at 25 tries without the item getting fewer, whatever else moved.
  local count = ns.GetCount and ns.GetCount(id) or 0
  local t = tries[id]
  if not t or count < t.count then t = { n = 0, total = 0 } tries[id] = t end
  t.n = bagsMoved and 1 or t.n + 1
  t.total = t.total + 1
  t.count = count
  bagsMoved = false
  if t.n > 3 or t.total > 25 then
    gaveUp[id] = true
    Print((link or ns.NameOf(id) or "an item") .. " doesn't open by itself. Rucksack leaves it alone until you log in again.")
    schedule(0.3)
    return
  end
  lastAt = now
  opening = { id = id, at = now }
  useItem(bag, slot)
  schedule(1.2) -- (nothing happened, or there's more: come back)
end
function A.Kick(sec) if on() then schedule(sec or 0.5) end end
function A.Set(v)
  ns.db.autoOpen = v and true or false
  wipe(tries)
  if v then A.Kick(0.2) elseif btn and not InCombatLockdown() then btn:Hide() end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "LOOT_OPENED", "LOOT_CLOSED",
  "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED",
  "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "TRADE_SHOW", "TRADE_CLOSED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, a1, a2)
  if OPENERS[e] then away[e] = true return end
  if CLOSERS[e] then away[CLOSERS[e]] = nil A.Kick(1.5) return end
  if e == "LOOT_OPENED" then
    lootOpen = true
    lootMine = opening and (GetTime() - opening.at) < 2 or false
    if lootMine and on() then
      -- auto loot off: take everything ourselves. What doesn't fit stays in the item for the next round.
      local auto = a1 == true or a1 == 1 or (GetCVarBool and GetCVarBool("autoLootDefault"))
      if not auto and GetNumLootItems and LootSlot then
        for i = GetNumLootItems(), 1, -1 do pcall(LootSlot, i) end
      end
      C_Timer.After(1.5, function() if lootOpen and lootMine and CloseLoot then pcall(CloseLoot) end end)
    end
    return
  end
  if e == "LOOT_CLOSED" then lootOpen, lootMine = false, false A.Kick(0.6) return end
  if e == "ADDON_ACTION_FORBIDDEN" or e == "ADDON_ACTION_BLOCKED" then
    -- the game stopped our "use item": no more tries, the button takes over
    if type(a1) == "string" and a1 == "Rucksack" and opening and (GetTime() - opening.at) < 1 and not blocked then
      blocked = true
      Print("the game doesn't let an addon open things without a click here. An Open button shows up when there's something to open: one click each.")
      C_Timer.After(0.1, function() paintButton() end)
    end
    return
  end
  if e == "PLAYER_ENTERING_WORLD" then wipe(away) A.Kick(3) return end
  if e == "BAG_UPDATE_DELAYED" then bagsMoved = true end
  if blocked then C_Timer.After(0.1, function() paintButton() end) return end
  A.Kick(0.5) -- BAG_UPDATE_DELAYED, PLAYER_REGEN_ENABLED
end)
