-- Rucksack / Bags: Restock (1.8.2). The things you always want on you: water, food, arrows, reagents.
--  * The cart next to your bags opens a small bag, like Hidden. Pull an item in and say how many to
--    carry. The list is in your order: the arrows move an item up or down.
--  * (19 Nov, simpler) the tick on the left of an item: ticked, a vendor that sells it tops you up by
--    itself when you open it; unticked, it's only on the list (Clean-up keeps it, nothing is bought).
--    Not enough money for everything: a bit of every item in turn. The list shows 4 rows; with more it
--    scrolls. (Gone: "Buy by itself", "Keep at least N gold", "Money short", "Buy now".)
-- Clean-up never sells or throws away what's on this list.
local ns = Rucksack
if not ns or not ns.Bags then return end
local B = ns.Bags
local Print = ns.Print
local R = {}
B.Restock = R
local MAXROWS, ROW, WIDTH, SHOWN = 40, 26, 262, 4
local ICONS = "Interface\\AddOns\\Rucksack_Bags\\Icons\\"
local TAN = { 0.85, 0.78, 0.6 }
local win, rows = nil, {}

-- the list: { { id = 159, want = 20 }, ... } in your order
local function list()
  local d = B.db
  if not d then return nil end
  if type(d.restock) ~= "table" then d.restock = {} end
  return d.restock
end
R.List = list
local function have(id)
  local ok, n = pcall(ns.GetCount, id)
  return ok and tonumber(n) or 0
end
local function coins(c) return ns.Pocket and ns.Pocket.Coins and ns.Pocket.Coins(c) or (tostring(c) .. "c") end
local function stackOf(id)
  local ok, n = pcall(function() return (select(8, ns.GetInfo(id))) end)
  return ok and tonumber(n) or 1
end
local function find(id)
  for i, e in ipairs(list() or {}) do if e.id == id then return i, e end end
end
function R.Wants(id) return (find(id)) ~= nil end
-- (19 Nov) ticked: bought by itself at vendors (a list from before the ticks follows the old switch)
function R.Auto(e)
  if e.auto ~= nil then return e.auto and true or false end
  return not (B.db and B.db.restockAuto == false)
end
-- how much money restocking may spend: what you have, less what you keep (in copper)
function R.Budget()
  local d = B.db
  local money = GetMoney and GetMoney() or 0
  return money, money -- (19 Nov: "Keep at least N gold" is gone)
end

---------------------------------------------------------------------------
-- at a vendor
---------------------------------------------------------------------------
local function merchantItem(i)
  local id = GetMerchantItemID and GetMerchantItemID(i)
  if not id and GetMerchantItemLink then
    local link = GetMerchantItemLink(i)
    id = link and tonumber(link:match("item:(%d+)"))
  end
  if not id then return nil end
  local price, stack, avail, extended
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local ok, t = pcall(C_MerchantFrame.GetItemInfo, i)
    if ok and type(t) == "table" then price, stack, avail, extended = t.price, t.stackCount, t.numAvailable, t.hasExtendedCost end
  end
  if price == nil and GetMerchantItemInfo then
    local _, _, p, q, n, _, _, ext = GetMerchantItemInfo(i)
    price, stack, avail, extended = p, q, n, ext
  end
  return id, tonumber(price) or 0, math.max(1, tonumber(stack) or 1), tonumber(avail) or -1, extended and true or false
end
-- What this vendor sells that you're short of, in your list's order, and how much of it to buy with
-- the money there is. Each entry: index (the vendor's), id, stack (items per purchase), price (per
-- purchase), need (purchases to be full), buy (purchases to make now).
function R.Plan(budget)
  local L = list()
  local plan = {}
  if not L or not GetMerchantNumItems then return plan, 0, 0 end
  local at = {}
  for i = 1, GetMerchantNumItems() or 0 do
    local id, price, stack, avail, ext = merchantItem(i)
    if id and not at[id] and not ext then at[id] = { index = i, price = price, stack = stack, avail = avail } end
  end
  local full = 0
  for _, e in ipairs(L) do
    local m = R.Auto(e) and at[e.id]
    local missing = (tonumber(e.want) or 0) - have(e.id)
    if m and missing > 0 then
      local need = math.min(60, math.ceil(missing / m.stack)) -- (never a runaway number of purchases)
      if m.avail >= 0 then need = math.min(need, m.avail) end
      if need > 0 then
        plan[#plan + 1] = { index = m.index, id = e.id, stack = m.stack, price = m.price, need = need, buy = 0 }
        full = full + need * m.price
      end
    end
  end
  local left = budget or math.huge
  local d = B.db
  -- some of each: one purchase of every item in turn, round and round, while the money lasts
  local moved = true
  while moved do
    moved = false
    for _, e in ipairs(plan) do
      if e.buy < e.need and (e.price == 0 or left >= e.price) then
        e.buy = e.buy + 1
        left = left - e.price
        moved = true
      end
    end
  end
  local cost = 0
  for _, e in ipairs(plan) do cost = cost + e.buy * e.price end
  return plan, cost, full
end
function R.Buy(byHand)
  if not B.db or not BuyMerchantItem then return end
  if not R.atVendor then
    if byHand then Print("open a vendor first: Restock buys from the vendor you're talking to.") end
    return
  end
  local plan, cost, full = R.Plan((R.Budget()))
  if #plan == 0 then
    if byHand then Print("this vendor sells nothing you're short of.") end
    return
  end
  if cost == 0 and full > 0 then
    Print("nothing restocked: not enough money.")
    return
  end
  local got = {}
  for _, e in ipairs(plan) do
    if e.buy > 0 then
      if e.stack > 1 then
        -- (sold in lots: one purchase is one lot)
        for _ = 1, e.buy do BuyMerchantItem(e.index) end
      else
        local max = GetMerchantItemMaxStack and tonumber(GetMerchantItemMaxStack(e.index)) or 1
        if max < 1 then max = 1 end
        local left = e.buy
        while left > 0 do
          local q = math.min(left, max)
          BuyMerchantItem(e.index, q)
          left = left - q
        end
      end
      got[#got + 1] = (e.buy * e.stack) .. " " .. (ns.NameOf(e.id) or "?")
    end
  end
  if #got > 0 then Print("restocked: " .. table.concat(got, ", ") .. " for " .. coins(cost) .. ".") end
  if cost < full then Print("not enough money to restock everything.") end
  R.boughtAt = GetTime()
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------
function R.Add(id, link)
  local L = list()
  if not L or not id then return end
  if find(id) then Print((ns.NameOf(id, link) or "that") .. " is already on your Restock list.") return end
  if #L >= MAXROWS then Print("the Restock list is full (" .. MAXROWS .. " items): take one off first.") return end
  local want = math.max(stackOf(id), 1)
  L[#L + 1] = { id = id, want = want, auto = true }
  if B.Changed then B.Changed() end -- (it moves into the Restock group in your bag)
  Print("Restock keeps " .. want .. " " .. (ns.NameOf(id, link) or "of them") .. " on you: change the number in the Restock bag (the cart next to your bags).")
  R.scroll = math.max(0, #L - SHOWN) -- (show the new one at the bottom)
  R.Draw()
end
function R.Remove(id)
  local L = list()
  local i = find(id)
  if L and i then table.remove(L, i) R.Draw() if B.Changed then B.Changed() end end
end
function R.Move(id, by)
  local L = list()
  local i = find(id)
  if not L or not i then return end
  local j = i + by
  if j < 1 or j > #L then return end
  L[i], L[j] = L[j], L[i]
  R.Draw()
end
function R.SetWant(id, n)
  local _, e = find(id)
  if not e then return end
  n = math.floor(tonumber(n) or 0)
  if n < 1 then n = 1 elseif n > 9999 then n = 9999 end
  e.want = n
  R.Draw()
end
local function addHeld()
  local id, link = ns.CursorItem()
  if not id then return end
  ClearCursor()
  R.Add(id, link)
end
-- what you're short of right now, as a short line
function R.Short()
  local parts, n = {}, 0
  for _, e in ipairs(list() or {}) do
    local missing = (tonumber(e.want) or 0) - have(e.id)
    if missing > 0 then
      n = n + 1
      if #parts < 3 then parts[#parts + 1] = missing .. " " .. (ns.NameOf(e.id) or "?") end
    end
  end
  return n, table.concat(parts, ", ") .. (n > 3 and (" and " .. (n - 3) .. " more") or "")
end
function R.Tip()
  local L = list() or {}
  local t = "Opens a small bag next to this one with the things you always want on you: water, food, arrows, reagents. Pull an item in and say how many to carry. A vendor that sells it tops you up."
  if #L > 0 then
    local n, line = R.Short()
    t = t .. "\n\n" .. #L .. (#L == 1 and " item" or " items") .. " on the list. " .. (n > 0 and ("Short of: " .. line .. ".") or "All stocked.")
  end
  return t
end

---------------------------------------------------------------------------
-- the small bag
---------------------------------------------------------------------------
local function place()
  if not win then return end
  local bag, hidden = RucksackBagsFrame, RucksackBagsHidden
  win:ClearAllPoints()
  if hidden and hidden:IsShown() then win:SetPoint("TOPLEFT", hidden, "BOTTOMLEFT", 0, -3)
  else win:SetPoint("TOPLEFT", bag, "TOPRIGHT", 3 + (B.sideRightW or 0), 0) end -- (15 Nov: past the boxes on the bag's right)
end
B.PlaceRestock = place
local function numberBox(parent, w, letters)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(w, 18)
  e:SetAutoFocus(false)
  e:SetMaxLetters(letters)
  if e.SetNumeric then e:SetNumeric(true) end
  e:SetFontObject(GameFontHighlightSmall)
  e:SetJustifyH("CENTER")
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEscapePressed", function(self) self.cancel = true self:ClearFocus() end)
  e:SetScript("OnEditFocusLost", function(self)
    local cancel = self.cancel
    self.cancel = nil
    if not cancel and self.commit then self.commit(tonumber(self:GetText())) else R.Draw() end
  end)
  return e
end
local function tip(owner, title, text)
  owner:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local function row(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", "RucksackRestockRow" .. i, win.list)
  r:SetSize(WIDTH - 16, ROW - 2)
  -- (19 Nov) the tick: bought by itself at vendors
  r.auto = CreateFrame("CheckButton", "RucksackRestockAuto" .. i, r, "UICheckButtonTemplate")
  r.auto:SetSize(22, 22)
  r.auto:SetPoint("LEFT", -3, 0)
  r.auto:SetScript("OnClick", function(self)
    local _, e = find(r.id)
    if e then e.auto = self:GetChecked() and true or false end
    if R.atVendor and e and e.auto then R.Buy(false) end
    R.Draw()
  end)
  tip(r.auto, "Buy by itself", "Ticked: a vendor that sells it tops you up as soon as you open the vendor. Unticked: it only stays on the list (Clean-up never sells or throws it away), nothing is bought.")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", 21, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.x = CreateFrame("Button", nil, r)
  r.x:SetSize(14, 14)
  r.x:SetPoint("RIGHT", 0, 0)
  r.x.text = r.x:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  r.x.text:SetPoint("CENTER")
  r.x.text:SetText("|cffff6b5ex|r")
  r.x:SetScript("OnClick", function() R.Remove(r.id) end)
  tip(r.x, "Take it off the list", "It goes back where Rucksack puts it in your bag.")
  r.want = numberBox(r, 36, 4)
  r.want:SetPoint("RIGHT", r.x, "LEFT", -6, 0)
  r.want.commit = function(n) R.SetWant(r.id, n) end
  r.have = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.have:SetPoint("RIGHT", r.want, "LEFT", -8, 0)
  r.have:SetJustifyH("RIGHT")
  r.name = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
  r.name:SetPoint("RIGHT", r.have, "LEFT", -4, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r:SetScript("OnEnter", function(self)
    if not self.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:AddLine(ns.NameOf(self.id) or "?") end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("You carry " .. have(self.id) .. ". Restock fills it up to the number in the box.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:SetScript("OnReceiveDrag", addHeld)
  r:EnableMouseWheel(true)
  r:SetScript("OnMouseWheel", function(_, d) R.Scroll(-d) end)
  rows[i] = r
  return r
end
function R.Scroll(by)
  local L = list() or {}
  local most = math.max(0, #L - SHOWN)
  R.scroll = math.max(0, math.min(most, (R.scroll or 0) + by))
  R.Draw()
end
local function build()
  if win then return win end
  win = CreateFrame("Frame", "RucksackBagsRestock", RucksackBagsFrame, ns.BACKDROP_TMPL)
  win:SetSize(WIDTH, 200)
  win:EnableMouse(true)
  if win.SetBackdrop then
    win:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    win:SetBackdropColor(0.04, 0.035, 0.03, 0.97)
    win:SetBackdropBorderColor(0.62, 0.5, 0.3, 1)
  end
  win:Hide()
  local ic = win:CreateTexture(nil, "ARTWORK")
  ic:SetSize(16, 16)
  ic:SetPoint("TOPLEFT", 9, -9)
  ic:SetTexture(ICONS .. "restock")
  ic:SetVertexColor(TAN[1], TAN[2], TAN[3])
  local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("LEFT", ic, "RIGHT", 5, 0)
  title:SetText("Restock")
  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
  close:SetSize(18, 18) -- (19 Nov: inside the border, level with the title)
  close:SetPoint("TOPRIGHT", -6, -8)
  local help = CreateFrame("Button", nil, win)
  help:SetSize(16, 16)
  help:SetPoint("RIGHT", close, "LEFT", -2, 0)
  help.text = help:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  help.text:SetPoint("CENTER")
  help.text:SetText("|cffffd100?|r")
  tip(help, "Restock", "The things you always want on you: water, food, arrows, reagents. Pull an item in here and type how many to carry. Ticked items are bought by itself when you open a vendor that sells them; with too little money, a bit of each. Clean-up never sells or throws away what's on this list. More than 4 items: scroll the list.")
  -- the place to pull items into
  local drop = CreateFrame("Button", "RucksackBagsRestockDrop", win)
  drop:SetPoint("TOPLEFT", 8, -30)
  drop:SetSize(WIDTH - 16, 28)
  for i = 0, 20 do
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
      local t = drop:CreateTexture(nil, "BORDER")
      t:SetColorTexture(TAN[1], TAN[2], TAN[3], 0.5)
      t:SetSize(6, 1)
      t:SetPoint(side .. "LEFT", i * 12, 0)
    end
  end
  drop.text = drop:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  drop.text:SetPoint("LEFT", 4, 0)
  drop.text:SetPoint("RIGHT", -4, 0)
  drop.text:SetText("Pull an item in here to keep it stocked")
  local hl = drop:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.06)
  drop:SetScript("OnReceiveDrag", addHeld)
  drop:SetScript("OnClick", addHeld)
  win:SetScript("OnReceiveDrag", addHeld)
  win:SetScript("OnMouseUp", addHeld)
  win.drop = drop
  win.head = win:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  win.head:SetJustifyH("RIGHT")
  win.head:SetText("have     carry")
  -- (19 Nov) the list: 4 rows, more scroll (mouse wheel)
  win.list = CreateFrame("Frame", "RucksackBagsRestockList", win)
  win.list:SetPoint("TOPLEFT", 8, -76)
  win.list:SetSize(WIDTH - 16, SHOWN * ROW)
  win.list:EnableMouseWheel(true)
  win.list:SetScript("OnMouseWheel", function(_, d) R.Scroll(-d) end)
  win.bar = win:CreateTexture(nil, "ARTWORK") -- where you are in a long list
  win.bar:SetColorTexture(TAN[1], TAN[2], TAN[3], 0.45)
  win.bar:SetWidth(2)
  win:SetScript("OnShow", function() place() if B.restockBtn and B.LightUp then B.LightUp(B.restockBtn, true) end end)
  win:SetScript("OnHide", function() if B.restockBtn and B.LightUp then B.LightUp(B.restockBtn, false) end end)
  if RucksackBagsHidden and RucksackBagsHidden.HookScript then
    RucksackBagsHidden:HookScript("OnShow", place)
    RucksackBagsHidden:HookScript("OnHide", place)
  end
  return win
end
function R.Draw()
  if not win or not win:IsShown() or not B.db then return end
  local L = list()
  local most = math.max(0, #L - SHOWN)
  R.scroll = math.max(0, math.min(most, R.scroll or 0))
  local first = R.scroll
  for i = 1, math.min(SHOWN, #L) do
    local e = L[first + i]
    local r = row(i)
    r.id = e.id
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -((i - 1) * ROW))
    r.auto:SetChecked(R.Auto(e))
    r.icon:SetTexture(ns.GetIcon(e.id))
    r.name:SetText(ns.NameOf(e.id) or ("item " .. e.id))
    local h = have(e.id)
    r.have:SetText((h >= e.want and "|cff5cd65c" or h > 0 and "|cffffd100" or "|cffff6b5e") .. h .. "|r")
    if not r.want:HasFocus() then r.want:SetText(tostring(e.want)) end
    r:Show()
  end
  for i = math.min(SHOWN, #L) + 1, #rows do rows[i]:Hide() end
  win.head:ClearAllPoints()
  win.head:SetPoint("TOPRIGHT", -26, -62)
  win.head:SetShown(#L > 0)
  win.drop.text:SetText(#L == 0 and "Pull an item in here to keep it stocked" or "Pull another item in here")
  -- the scroll mark on the right edge
  win.bar:ClearAllPoints()
  if most > 0 then
    local H = SHOWN * ROW
    local h = math.max(12, H * SHOWN / #L)
    win.bar:SetHeight(h)
    win.bar:SetPoint("TOPRIGHT", -4, -(76 + (H - h) * first / most))
    win.bar:Show()
  else
    win.bar:Hide()
  end
  local shown = math.min(SHOWN, #L)
  win:SetHeight(#L == 0 and 66 or (76 + shown * ROW + 6))
end
function R.Toggle()
  if not B.db then return end
  build()
  if win:IsShown() then win:Hide() else win:Show() place() R.Draw() end
  if B.restockBtn and B.LightUp then B.LightUp(B.restockBtn, win:IsShown()) end
  if B.Draw then B.Draw() end -- (18 Nov: the side windows decide again whether Restock fits beside the bag)
end
function R.IsShown() return win and win:IsShown() and true or false end

-- Clean-up never sells or throws away what you restock
if ns.keepers then table.insert(ns.keepers, function(id) return B.db and B.db.restock and R.Wants(id) or false end) end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "ADDON_ACTION_FORBIDDEN" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, a, b)
  if e == "MERCHANT_SHOW" then
    R.atVendor = true
    local any = false
    for _, e in ipairs(list() or {}) do if R.Auto(e) then any = true end end
    if B.db and any and not B.db.restockForbidden then
      -- (a moment later: the vendor's list isn't always there the instant the window opens)
      C_Timer.After(0.4, function() if R.atVendor then R.Buy(false) end end)
    end
  elseif e == "MERCHANT_CLOSED" then
    R.atVendor = nil
  elseif e == "ADDON_ACTION_FORBIDDEN" then
    -- (if this game won't let an addon buy by itself: stop trying, say so once)
    if type(a) == "string" and a:find("^Rucksack") and type(b) == "string" and b:find("BuyMerchantItem") and B.db then
      B.db.restockForbidden = true
      Print("this game doesn't let Rucksack buy by itself, so Restock can't buy for you. The list still keeps your items from being sold.")
    end
    return
  end
  if win and win:IsShown() then R.Draw() end
end)
