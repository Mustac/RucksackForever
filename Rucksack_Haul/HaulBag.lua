-- Rucksack / Haul and the bag (19 Nov).
-- History: first a Haul group and a Haul box filled by themselves; then (19:35) only the pieces you picked
-- up, stack by stack; then (19:47) "remove category Haul from bag"; now (19:52) he: "I would like to have a
-- button the loot we picked up with Haul to be sorted ... in sell (not always sell but only sell) and it
-- will create Haul - Auction house".
--  * While a run is on (and "Keep track of your loot in the bag" is ticked in Haul's Settings), Haul notes
--    which stacks are your loot: only the pieces you picked up. Loot that lands on a stack you had already
--    is split off into a slot of its own (out of a fight, when there's a free slot; with none, it stays in
--    its old stack). Nothing else changes in the bag while you play.
--  * "Sort loot" (Haul's window, and Shift + right-click on the coin button) sorts those stacks, from this
--    run and earlier ones not sorted yet:
--      a vendor pays more than the auction house -> "Sell this stack" (sold at the next vendor, never
--        thrown away: the Sell / delete once box);
--      worth more at the auction house -> the "Haul - Auction house" group in the bag (it goes away once
--        it's empty; its button "Sort into groups" empties it by hand);
--      the rest stays where the bag puts it: what Rucksack keeps (quest items and what quests need,
--        Restock, armour sets, tools, your professions' materials, Darkmoon turn-ins...), food, water and
--        potions, gear better than yours, rare or better, grey items (Clean-up sells those anyway), items
--        you put in a group yourself, and items with no auction price known.
--  * (20:14, he: "when haul is working and have this option checked to automatically put on sale by AH
--    price ... the items that we are getting with Haul") "Sort loot as it comes in" (Haul's Settings, on to
--    start): while a run is on, each loot stack is sorted the same way by itself, a second or so after it
--    lands (once its details and prices are known). The button still sorts what's left.
-- Also here: the button on the screen that opens and closes the Haul window.
local ns = Rucksack
local H = ns and ns.Haul
if not H then return end
local Print = ns.Print

-- per character: ns.char.haulSlots["bag:slot"] = { id, kind = "loot" (not sorted yet) / "ah" (Haul -
-- Auction house) }
local function C()
  local c = ns.char
  if not c then return nil end
  c.haulSlots = c.haulSlots or {}
  for k, m in pairs(c.haulSlots) do if m.kind ~= "loot" and m.kind ~= "ah" then c.haulSlots[k] = nil end end -- (marks from the earlier builds)
  c.haulKind, c.haulSell, c.haulKeep, c.haulWait = nil, nil, nil, nil
  return c
end
local function bagOn() return H.db and H.db.bag ~= false and ns.Has and ns.Has("bags") and ns.Bags and ns.Bags.db and true or false end
local function key(bag, slot) return bag .. ":" .. slot end
local function unkey(k) local b, s = k:match("^(%-?%d+):(%d+)$") return tonumber(b), tonumber(s) end
local function mark(bag, slot)
  local c = bag and slot and ns.char and C()
  return c and c.haulSlots[key(bag, slot)] or nil
end

-- for the bag: this very stack is Haul's (loot not sorted yet, or the Haul - Auction house group)
function ns.HaulSlot(bag, slot) return mark(bag, slot) ~= nil end
-- (19 Nov, 21:29) he: "remove it, but leave that sell at vendor items that are not good for putting to AH":
-- no Haul - Auction house group any more. Sort loot only puts what a vendor pays more for on Sell; the rest
-- stays in its own group (old "ah" marks are dropped at login).
function ns.HaulKeep() return false end
function ns.HaulSell() return false end -- (the Haul box is gone: Sort loot marks stacks "Sell this stack")
function ns.HaulUnsell() end

local function changed()
  if ns.Del and ns.Del.Refresh then pcall(ns.Del.Refresh) end
  ns.Changed()
  if H.UI then H.UI.Refresh(true) end
end
H.Changed = changed

-- left where the bag puts it, whatever the prices say
local function leaveAlone(id, link)
  if ns.KeepItem(id) then return true end
  local b = ns.Bags
  if b and b.db and b.db.assign and b.db.assign[id] then return true end -- (you put it in a group yourself)
  local d = ns.del
  if d and ((d.items and d.items[id]) or (d.sell and d.sell[id]) or (d.keep and d.keep[id])) then return true end -- (on a list already)
  local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  local classID = instant and select(6, instant(id))
  if classID == 12 or classID == 0 then return true end -- (quest items; food, water, potions)
  if ns.Del and ns.Del.QuestNeed then
    local ok, n = pcall(ns.Del.QuestNeed, id, link)
    if ok and n and n > 0 then return true end
  end
  local _, _, quality = ns.GetInfo(link or id)
  if quality and (quality == 0 or quality >= 3) then return true end -- (grey: Clean-up sells it anyway; rare and better: yours to decide)
  if (classID == 2 or classID == 4) and ns.Del and ns.Del.IsUpgrade then
    local ok, up = pcall(ns.Del.IsUpgrade, id, link)
    if ok and up then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- (19 Nov) What the auction house really leaves you. He: "account on that that items placing in AH cost
-- money to place". WoW Forever: a deposit when you post, from the item's vendor price (2 h 5 %, 8 h 20 %,
-- 24 h 60 %; a neutral house 5 times that; at least H.MIN_DEPOSIT a listing), back when it sells, lost when
-- it doesn't; and the house's cut when it sells (5 %, neutral 15 %). The deposit is counted in full (as if
-- the first posting doesn't sell): an item only counts as worth posting when it clearly is.
---------------------------------------------------------------------------
H.MIN_DEPOSIT = 100 -- (1 silver; Blizzard meant to lower it to 1 copper, players still report 1 silver)
local DEPOSIT = { [2] = 0.05, [8] = 0.20, [24] = 0.60 }
-- -> cut share, deposit share of the vendor price, hours, neutral
function H.AHCosts()
  local neutral = H.db and H.db.ahHouse == "neutral" or false
  local hours = H.db and DEPOSIT[H.db.ahHours] and H.db.ahHours or 24
  return neutral and 0.15 or 0.05, DEPOSIT[hours] * (neutral and 5 or 1), hours, neutral
end
-- for one, posted in a stack of n: what's left, the cut, the deposit, whether the deposit was counted (copper)
-- (19 Nov, 20:50) he: Gooey Spider Leg was marked "vendor" while the auction house pays far more. Counting
-- the deposit as lost (plus 1 silver at least a listing) made every cheap item look like a vendor item,
-- but the deposit comes back when it sells. Now it's only counted when "Count the deposit as lost" is
-- ticked in Settings (off to start); the cut always counts.
function H.AHNet(ah, vendor, n)
  n = math.max(1, n or 1)
  local cutP, depP = H.AHCosts()
  local cut = math.floor(ah * cutP + 0.5)
  if H.db and H.db.ahDepositLost then
    local dep = math.max(H.MIN_DEPOSIT, math.floor((vendor or 0) * depP * n + 0.5)) / n
    return ah - cut - dep, cut, dep, true
  end
  return ah - cut, cut, math.floor((vendor or 0) * depP + 0.5), false
end

-- where Sort loot puts an item: "sell", "ah", "stay", or nil while its details aren't known
local function kindOf(id, link, n)
  local name, _, quality, _, _, _, _, _, _, _, sell = ns.GetInfo(link or id)
  if not name or quality == nil then return nil end
  if leaveAlone(id, link) then return "stay" end
  local vendor = tonumber(sell) or 0
  local bind = select(14, ns.GetInfo(link or id))
  if bind == 1 or bind == 4 then return vendor > 0 and "sell" or "stay" end -- (can't go on the auction house)
  local ah = H.AHPrice(id, link)
  if not ah then return "stay" end -- (no auction price known: nothing is decided for you)
  if vendor > 0 and vendor >= H.AHNet(ah, vendor, n) then return "sell" end -- (after the cut and the deposit)
  return "ah"
end
H.KindOf = kindOf

-- (19 Nov) Any item in your bags a vendor pays more for than the auction house leaves you (his: "mark
-- this kind of items with some icon on top left side, and have a button on the bag to sell this kind of
-- items when we interact with vendor"). The same rules as Sort loot: what Haul leaves alone is never
-- marked, nor what can't go on the auction house or has no auction price. -> yes, and the sums.
local vcache = {}
function H.VendorBetter(id, link, n)
  if not id or not H.db or H.db.vendorMark == false then return false end
  n = n or 1
  local k = tostring(link or id) .. "#" .. n
  local now = GetTime()
  local r = vcache[k]
  if r and now - r.t < 20 then return r.yes, r end
  r = { t = now, yes = false }
  local name, _, quality, _, _, _, _, _, _, _, sell = ns.GetInfo(link or id)
  local bind = select(14, ns.GetInfo(link or id))
  local vendor = tonumber(sell) or 0
  if not name or quality == nil then
    r.t = now - 18 -- (details not loaded yet: ask again soon)
  elseif vendor > 0 and not (bind == 1 or bind == 4) and not leaveAlone(id, link) then
    local ah = H.AHPrice(id, link)
    if ah then
      local net, cut, dep, counted = H.AHNet(ah, vendor, n)
      r.ah, r.cut, r.dep, r.net, r.vendor, r.n, r.counted = ah, cut, dep, net, vendor, n, counted
      r.yes = vendor >= net
    end
  end
  vcache[k] = r
  return r.yes, r
end
function ns.VendorBetter(id, link, n) return H.VendorBetter(id, link, n) end
do
  local clear = H.ClearPrices
  H.ClearPrices = function(...) wipe(vcache) if clear then return clear(...) end end
end

---------------------------------------------------------------------------
-- Which pieces are new: the bags as they were (snap), what grew since (recent), what you looted and
-- isn't placed yet (pending). A loot line and the bag change can come in either order.
---------------------------------------------------------------------------
local snap, recent, pending, queue = {}, {}, {}, {}
local LINKS = {}
local function readBags()
  local now = {}
  for bag = 0, ns.LAST_BAG or 4 do
    for slot = 1, (ns.GetNumSlots(bag) or 0) do
      local id, count = ns.SlotInfo(bag, slot)
      if id then now[key(bag, slot)] = { id = id, n = count or 1, bag = bag, slot = slot } end
    end
  end
  return now
end
local function match()
  local c = C()
  if not c then return end
  for i = #recent, 1, -1 do
    local r = recent[i]
    local want = pending[r.id]
    local m = c.haulSlots[key(r.bag, r.slot)]
    if want and want.n > 0 and m and m.id == r.id and m.kind == "loot" then
      -- (it landed on a loot stack of the item: noted already)
      want.n = want.n - math.min(r.inc, want.n)
      table.remove(recent, i)
    elseif want and want.n > 0 and not m then
      local take = math.min(r.inc, want.n)
      want.n = want.n - take
      if r.fresh and take >= r.n then
        c.haulSlots[key(r.bag, r.slot)] = { id = r.id, kind = "loot" } -- (a slot of its own already)
      else
        queue[#queue + 1] = { bag = r.bag, slot = r.slot, id = r.id, n = take } -- (on a stack you had: split off)
      end
      table.remove(recent, i)
    end
  end
  for id, p in pairs(pending) do if p.n <= 0 or GetTime() - p.at > 15 then pending[id] = nil end end
  for i = #recent, 1, -1 do if GetTime() - recent[i].at > 15 then table.remove(recent, i) end end
end
local function bagsChanged()
  local now = readBags()
  local t = GetTime()
  for k, e in pairs(now) do
    local old = snap[k]
    local fresh = not old or old.id ~= e.id
    local inc = fresh and e.n or (e.n - old.n)
    if inc > 0 then recent[#recent + 1] = { id = e.id, bag = e.bag, slot = e.slot, inc = inc, n = e.n, fresh = fresh, at = t } end
  end
  snap = now
  -- (a stack gone or swapped for another item: its mark goes)
  local c = C()
  local gone = false
  if c then for k, m in pairs(c.haulSlots) do local e = now[k] if not e or e.id ~= m.id then c.haulSlots[k] = nil gone = true end end end
  match()
  if gone and H.UI then H.UI.Refresh(true) end
end

function H.OnLoot(id, link, n)
  if not bagOn() then return end
  LINKS[id] = type(link) == "string" and link or LINKS[id]
  local p = pending[id] or { n = 0 }
  p.n, p.at = p.n + (n or 1), GetTime()
  pending[id] = p
  match()
end

-- one split at a time: the new pieces off the old stack, onto a loot stack of the item with room, or into
-- an empty slot of an ordinary bag
local function canMove()
  local B = ns.Bags
  if InCombatLockdown() or CursorHasItem() or (GetCursorInfo and GetCursorInfo()) then return false end
  if SpellIsTargeting and SpellIsTargeting() then return false end
  if B and B.swap then return false end
  return true
end
local function emptySlot()
  local B = ns.Bags
  for bag = 0, ns.NUM_BAGS or 4 do
    if not (B and B.SpecialOf and B.SpecialOf(bag)) then
      for slot = 1, (ns.GetNumSlots(bag) or 0) do
        if not ns.SlotInfo(bag, slot) then return bag, slot end
      end
    end
  end
end
local function splitStep()
  local q = queue[1]
  if not q or not canMove() then return end
  local c = C()
  local id, count, _, _, locked = ns.SlotInfo(q.bag, q.slot)
  if id ~= q.id or not count then table.remove(queue, 1) return end
  if locked then return end
  table.remove(queue, 1)
  if q.n >= count then -- (all of it is new after all)
    c.haulSlots[key(q.bag, q.slot)] = { id = q.id, kind = "loot" }
    return
  end
  local max = tonumber((select(8, ns.GetInfo(q.id)))) or 1
  local tb, ts
  for k, m in pairs(c.haulSlots) do
    if m.id == q.id and m.kind == "loot" then
      local b, s = unkey(k)
      local _, have = ns.SlotInfo(b, s)
      if have and have + q.n <= max then tb, ts = b, s break end
    end
  end
  if not tb then tb, ts = emptySlot() end
  if not tb then return end -- (no room: the pieces stay in their old stack)
  ns.SplitBagItem(q.bag, q.slot, q.n)
  ns.PickupBagItem(tb, ts)
  if CursorHasItem() then ClearCursor() return end
  c.haulSlots[key(tb, ts)] = { id = q.id, kind = "loot" }
end

function H.BagTick()
  if #queue > 0 then splitStep() end
  -- (sorted by itself while a run is on, if ticked)
  if H.db and H.db.autoSort ~= false and H.Running() and H.LootCount() > 0 then H.SortLoot(true) end
end

-- how many of your loot stacks are waiting for Sort loot
function H.LootCount()
  local c = ns.char and C()
  local n = 0
  if c then for _, m in pairs(c.haulSlots) do if m.kind == "loot" then n = n + 1 end end end
  return n
end

-- Sort loot: sell / Haul - Auction house / stay
function H.SortLoot(quiet)
  local c = C()
  if not c then return end
  local sold, ah, stay, wait = 0, 0, 0, 0
  for k, m in pairs(c.haulSlots) do
    if m.kind == "loot" then
      local b, s = unkey(k)
      local id, n, link = ns.SlotInfo(b, s)
      if id ~= m.id then
        c.haulSlots[k] = nil
      else
        local kind = kindOf(id, link, n)
        if kind == "sell" and ns.Del and ns.Del.SellStack then
          pcall(ns.Del.SellStack, b, s, id)
          c.haulSlots[k] = nil
          sold = sold + 1
        elseif kind == "ah" or kind == "stay" or kind == "sell" then
          c.haulSlots[k] = nil
          stay = stay + 1
        else
          wait = wait + 1 -- (its details aren't known yet: it stays for the next Sort loot)
        end
      end
    end
  end
  if quiet then
    if sold + ah + stay > 0 then changed() end
    return
  end
  local parts = {}
  if sold > 0 then parts[#parts + 1] = sold .. (sold == 1 and " stack" or " stacks") .. " to sell" end
  if stay > 0 then parts[#parts + 1] = stay .. " stay in their groups (worth more at the auction house, or kept)" end
  if wait > 0 then parts[#parts + 1] = wait .. " not known yet (try again in a moment)" end
  Print("|cffd9b36cHaul|r: " .. (#parts > 0 and table.concat(parts, ", ") or "nothing to sort: loot something during a run first") .. ".")
  changed()
end

-- Stop: the loot marks stay for Sort loot; only what's waiting to be split goes
function H.OnStop()
  wipe(pending)
  wipe(queue)
  changed()
end

-- the Haul - Auction house group's button: "Sort into groups"
function H.SortOut()
  local c = C()
  if not c then return end
  for k, m in pairs(c.haulSlots) do if m.kind == "ah" then c.haulSlots[k] = nil end end
  changed()
end

local bev = CreateFrame("Frame")
bev:RegisterEvent("BAG_UPDATE_DELAYED")
bev:SetScript("OnEvent", function()
  if not H.cur then return end
  bagsChanged()
  if #queue > 0 then C_Timer.After(0.2, splitStep) end
end)
H.Snap = function() snap = readBags() end
H.BagsChanged = bagsChanged
H.SplitStep = splitStep

---------------------------------------------------------------------------
-- In the bag: the group's button (Bags.lua calls it while drawing the Haul group's name)
---------------------------------------------------------------------------
local sortBtn
local function bagButton(label, nameW)
  local B = ns.Bags
  if not sortBtn then
    sortBtn = CreateFrame("Button", "RucksackHaulSortButton", B.MAIN.frame, ns.BACKDROP_TMPL)
    sortBtn:SetSize(96, 13)
    if sortBtn.SetBackdrop then
      sortBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
      sortBtn:SetBackdropColor(0.12, 0.1, 0.06, 0.95)
      sortBtn:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
    end
    sortBtn.text = sortBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sortBtn.text:SetPoint("CENTER", 0, 0)
    do local fo = sortBtn.text:GetFont() if fo then sortBtn.text:SetFont(fo, 9) end end
    sortBtn.text:SetText("Sort into groups")
    sortBtn:SetScript("OnClick", function() H.SortOut() end)
    sortBtn:SetScript("OnEnter", function(self)
      self:SetBackdropBorderColor(1, 0.82, 0, 1)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Sort into groups")
      GameTooltip:AddLine("Haul - Auction house empties: its items go to their own groups (Trade goods, Armour...). Sort loot fills it again with what you loot next.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    sortBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.62, 0.5, 0.3, 1) GameTooltip:Hide() end)
  end
  if not label then sortBtn:Hide() return end
  sortBtn:SetParent(label)
  sortBtn:ClearAllPoints()
  sortBtn:SetPoint("LEFT", label, "LEFT", (nameW or 30) + 6, 0)
  sortBtn:SetFrameLevel((label:GetFrameLevel() or 1) + 2)
  sortBtn:Show()
end

---------------------------------------------------------------------------
-- The button on the screen: opens and closes the Haul window
---------------------------------------------------------------------------
local btn
local function paintBtn()
  if not btn or not H.cur then return end
  local r, g, b = 0.55, 0.55, 0.55
  if H.Running() then
    if H.cur.paused then r, g, b = 1, 0.55, 0.2 else r, g, b = 0.35, 0.9, 0.35 end
  end
  btn.dot:SetColorTexture(r, g, b, 1)
end
local function makeButton()
  if btn then return end
  btn = CreateFrame("Button", "RucksackHaulButton", UIParent, ns.BACKDROP_TMPL)
  btn:SetSize(34, 34)
  btn:SetFrameStrata("MEDIUM")
  btn:SetMovable(true)
  btn:SetClampedToScreen(true)
  btn:RegisterForDrag("LeftButton")
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  if btn.SetBackdrop and ns.SLOT_BACKDROP then
    btn:SetBackdrop(ns.SLOT_BACKDROP)
    btn:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
    btn:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
  end
  local ic = btn:CreateTexture(nil, "ARTWORK")
  ic:SetPoint("TOPLEFT", 4, -4)
  ic:SetPoint("BOTTOMRIGHT", -4, 4)
  ic:SetTexture("Interface\\Icons\\INV_Misc_Coin_17")
  ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  btn.dot = btn:CreateTexture(nil, "OVERLAY")
  btn.dot:SetSize(6, 6)
  btn.dot:SetPoint("BOTTOMRIGHT", -4, 4)
  local hl = btn:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 4, -4)
  hl:SetPoint("BOTTOMRIGHT", -4, 4)
  hl:SetColorTexture(1, 1, 1, 0.15)
  local pos = H.db.btnPos
  if pos then btn:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else btn:SetPoint("CENTER", UIParent, "CENTER", 260, -180) end
  btn:SetScript("OnDragStart", function(self) self:StartMoving() end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    H.db.btnPos = { p, rp, x, y }
  end)
  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" and IsShiftKeyDown() then H.SortLoot()
    elseif button == "RightButton" then
      if not H.Running() then H.Start() else H.SetPaused(not H.cur.paused) end
    elseif H.UI then H.UI.Toggle() end
    paintBtn()
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Haul  " .. (not H.Running() and "|cff888888stopped|r" or H.cur.paused and "|cffff8040paused|r" or "|cff55dd55running|r"))
    if H.Running() then
      local t = H.Totals(H.cur)
      GameTooltip:AddDoubleLine("This run", H.Money(t.total), 0.85, 0.7, 0.4, 1, 1, 1)
      if t.perHour then GameTooltip:AddDoubleLine("Per hour", H.Money(t.perHour), 0.85, 0.7, 0.4, 1, 1, 1) end
    end
    GameTooltip:AddLine("Click: open or close Haul.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine(not H.Running() and "Right-click: Start." or H.cur.paused and "Right-click: Resume." or "Right-click: Pause.", 0.7, 0.7, 0.7)
    local n = H.LootCount()
    GameTooltip:AddLine("Shift + right-click: Sort loot" .. (n > 0 and (" (" .. n .. (n == 1 and " stack)" or " stacks)")) or "") .. ".", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag: move this button.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  btn:Show()
end

function H.BagInit()
  snap = readBags()
  pcall(H.SortOut) -- (19 Nov: the Haul - Auction house group is gone: its old marks go)
  -- (19 Nov, 21:18) he: "remove haul icon": the coin button on the screen is gone, Haul's button sits in
  -- the bag's tool row now. Only without Rucksack's bag (Bags off) does the coin button still show.
  if not (ns.Has and ns.Has("bags") and ns.Bags and ns.Bags.tools) then makeButton() end
  paintBtn()
  if ns.Bags then ns.Bags.HaulButton = bagButton end
  local old = H.Changed
  H.Changed = function() paintBtn() old() end
  changed()
end

-- (19 Nov) Haul's "Check bag" button: prices read afresh, the coins redrawn, and a chat line with what's found
function H.CheckBag()
  H.ClearPrices()
  if H.db.vendorMark == false then H.Print("the gold coin is off: tick \"Mark items a vendor pays more for\" in Settings.") return end
  local B = ns.Bags
  if not (B and B.VendorList) then H.Print("Check bag needs Rucksack's bag (Bags) turned on.") return end
  local list, items, worth = B.VendorList()
  if ns.Changed then ns.Changed() end
  if #list == 0 then
    H.Print("checked your bags: nothing a vendor pays more for than the auction house.")
  else
    H.Print("checked your bags: " .. items .. (items == 1 and " item is" or " items are") .. " worth more at a vendor (" ..
      H.Money(worth) .. "), marked with a gold coin. At a vendor, the button under your bag sells them.")
  end
end
