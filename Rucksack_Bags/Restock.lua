-- Rucksack / Bags: Restock (1.8.2). The things you always want on you: water, food, arrows, reagents.
--  * The cart next to your bags opens a small bag, like Hidden. Pull an item in and say how many to
--    carry. The list is in your order: the arrows move an item up or down.
--  * At a vendor that sells something you're short of, Rucksack buys it: by itself when you open
--    the vendor ("Buy by itself"), or when you click Buy now.
--  * "Keep at least N gold": restocking never takes you below that, so with less nothing is bought.
--  * Not enough money for everything: "Some of each" buys a bit of every item in turn; "Top of the
--    list first" fills the first item, then the next, and so on.
-- Clean-up never sells or throws away what's on this list.
local ns = Rucksack
if not ns or not ns.Bags then return end
local B = ns.Bags
local Print = ns.Print
local R = {}
B.Restock = R
local MAXROWS, ROW, WIDTH = 12, 26, 262
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
-- how much money restocking may spend: what you have, less what you keep (in copper)
function R.Budget()
  local d = B.db
  local money = GetMoney and GetMoney() or 0
  return math.max(0, money - (d and tonumber(d.restockKeep) or 0) * 10000), money
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
    local m = at[e.id]
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
  if d and d.restockMode == "order" then
    -- top of the list first: fill one, then the next
    for _, e in ipairs(plan) do
      local n = e.need
      if e.price > 0 then n = math.min(n, math.floor(left / e.price)) end
      e.buy = n
      left = left - n * e.price
    end
  else
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
    local keep = tonumber(B.db.restockKeep) or 0
    Print("nothing restocked: not enough money" .. (keep > 0 and (" (you keep " .. keep .. "g)") or "") .. ".")
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
  if cost < full then Print("not enough money to restock everything" .. ((tonumber(B.db.restockKeep) or 0) > 0 and (" (you keep " .. B.db.restockKeep .. "g)") or "") .. ".") end
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
  L[#L + 1] = { id = id, want = want }
  if B.Changed then B.Changed() end -- (it moves into the Restock group in your bag)
  Print("Restock keeps " .. want .. " " .. (ns.NameOf(id, link) or "of them") .. " on you: change the number in the Restock bag (the cart next to your bags).")
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
  else win:SetPoint("TOPLEFT", bag, "TOPRIGHT", 3, 0) end
end
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
local function arrow(parent, up, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(14, 11)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints()
  b.tex:SetTexture(up and "Interface\\Buttons\\Arrow-Up-Up" or "Interface\\Buttons\\Arrow-Down-Up")
  b.tex:SetVertexColor(TAN[1], TAN[2], TAN[3])
  b:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1, 0.82, 0) end)
  b:SetScript("OnLeave", function(self) self.tex:SetVertexColor(TAN[1], TAN[2], TAN[3]) end)
  b:SetScript("OnClick", onClick)
  return b
end
local function row(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", "RucksackRestockRow" .. i, win)
  r:SetSize(WIDTH - 16, ROW - 2)
  r.up = arrow(r, true, function() R.Move(r.id, -1) end)
  r.up:SetPoint("TOPLEFT", 0, -1)
  r.down = arrow(r, false, function() R.Move(r.id, 1) end)
  r.down:SetPoint("BOTTOMLEFT", 0, 1)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", 18, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.x = CreateFrame("Button", nil, r)
  r.x:SetSize(14, 14)
  r.x:SetPoint("RIGHT", 0, 0)
  r.x.text = r.x:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  r.x.text:SetPoint("CENTER")
  r.x.text:SetText("|cffff6b5ex|r")
  r.x:SetScript("OnClick", function() R.Remove(r.id) end)
  r.x:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Take it off the list")
    GameTooltip:Show()
  end)
  r.x:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
  rows[i] = r
  return r
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
  close:SetSize(22, 22)
  close:SetPoint("TOPRIGHT", -2, -3)
  local help = CreateFrame("Button", nil, win)
  help:SetSize(16, 16)
  help:SetPoint("RIGHT", close, "LEFT", -2, 0)
  help.text = help:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  help.text:SetPoint("CENTER")
  help.text:SetText("|cffffd100?|r")
  help:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Restock")
    GameTooltip:AddLine("The things you always want on you: water, food, arrows, reagents. Pull an item in here and type how many to carry. A vendor that sells it tops you up, by itself or when you click Buy now.", 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("The arrows move an item up or down the list. The order matters when money is short: see the choice at the bottom.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Clean-up never sells or throws away what's on this list.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  help:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
  -- the settings at the bottom
  local foot = CreateFrame("Frame", nil, win)
  foot:SetSize(WIDTH - 16, 96)
  win.foot = foot
  local line = foot:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(TAN[1], TAN[2], TAN[3], 0.25)
  line:SetPoint("TOPLEFT", 0, 0)
  line:SetPoint("TOPRIGHT", 0, 0)
  line:SetHeight(1)
  local auto = CreateFrame("CheckButton", "RucksackRestockAuto", foot, "UICheckButtonTemplate")
  auto:SetSize(22, 22)
  auto:SetPoint("TOPLEFT", -2, -4)
  auto.label = foot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  auto.label:SetPoint("LEFT", auto, "RIGHT", 2, 0)
  auto.label:SetText("Buy by itself at vendors")
  auto:SetScript("OnClick", function(self)
    B.db.restockAuto = self:GetChecked() and true or false
    ns.Changed()
  end)
  foot.auto = auto
  local kl = foot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  kl:SetPoint("TOPLEFT", 2, -32)
  kl:SetText("Keep at least")
  local keep = numberBox(foot, 40, 5)
  keep:SetPoint("LEFT", kl, "RIGHT", 10, 0)
  keep.commit = function(n)
    n = math.floor(tonumber(n) or 0)
    if n < 0 then n = 0 end
    B.db.restockKeep = n
    R.Draw()
  end
  foot.keep = keep
  local kg = foot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  kg:SetPoint("LEFT", keep, "RIGHT", 6, 0)
  kg:SetText("gold")
  local kh = CreateFrame("Frame", nil, foot)
  kh:SetPoint("TOPLEFT", kl, "TOPLEFT", -2, 3)
  kh:SetPoint("BOTTOMRIGHT", kl, "BOTTOMRIGHT", 2, -3) -- (over the words only: the number box stays clickable)
  kh:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Keep at least")
    GameTooltip:AddLine("Restocking never takes you below this much gold. With less than this in your purse, nothing is bought. 0: spend whatever it takes.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  kh:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local ml = foot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  ml:SetPoint("TOPLEFT", 2, -56)
  ml:SetText("Money short:")
  foot.modes = {}
  local MODES = { { "each", "Some of each", 78, "Not enough money for everything: buys one lot of every item in turn, round and round, until the money is gone. You end up with a bit of everything." },
    { "order", "Top of list first", 92, "Not enough money for everything: fills the first item on the list, then the next, and so on. Put what matters most at the top (the arrows move items)." } }
  local x = 72
  for _, m in ipairs(MODES) do
    local b = CreateFrame("Button", "RucksackRestockMode_" .. m[1], foot, ns.BACKDROP_TMPL)
    b:SetSize(m[3], 20)
    b:SetPoint("TOPLEFT", x, -52)
    x = x + m[3] + 4
    if b.SetBackdrop then b:SetBackdrop(ns.SLOT_BACKDROP) end
    b.label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b.label:SetText(m[2])
    b:SetScript("OnClick", function() B.db.restockMode = m[1] R.Draw() end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(m[2])
      GameTooltip:AddLine(m[4], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    foot.modes[m[1]] = b
  end
  foot.info = foot:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  foot.info:SetPoint("TOPLEFT", 2, -78)
  foot.info:SetWidth(WIDTH - 16 - 76)
  foot.info:SetJustifyH("LEFT")
  foot.info:SetWordWrap(false)
  local buy = CreateFrame("Button", "RucksackRestockBuy", foot, "UIPanelButtonTemplate")
  buy:SetSize(70, 20)
  buy:SetPoint("TOPRIGHT", 0, -75)
  buy:SetText("Buy now")
  buy:SetScript("OnClick", function()
    if R.boughtAt and GetTime() - R.boughtAt < 1.5 then return end -- (a double click isn't two orders)
    R.Buy(true)
  end)
  foot.buy = buy
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
  for i, e in ipairs(L) do
    local r = row(i)
    r.id = e.id
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 8, -(76 + (i - 1) * ROW))
    r.icon:SetTexture(ns.GetIcon(e.id))
    r.name:SetText(ns.NameOf(e.id) or ("item " .. e.id))
    local h = have(e.id)
    r.have:SetText((h >= e.want and "|cff5cd65c" or h > 0 and "|cffffd100" or "|cffff6b5e") .. h .. "|r")
    if not r.want:HasFocus() then r.want:SetText(tostring(e.want)) end
    r.up:SetShown(i > 1)
    r.down:SetShown(i < #L)
    r:Show()
  end
  for i = #L + 1, #rows do rows[i]:Hide() end
  win.head:ClearAllPoints()
  win.head:SetPoint("TOPRIGHT", -26, -62)
  win.head:SetShown(#L > 0)
  win.drop.text:SetText(#L == 0 and "Pull an item in here to keep it stocked" or "Pull another item in here")
  local top = 76 + #L * ROW + 4
  if #L == 0 then top = 64 end
  local foot = win.foot
  foot:ClearAllPoints()
  foot:SetPoint("TOPLEFT", 8, -top)
  foot.auto:SetChecked(B.db.restockAuto ~= false)
  if not foot.keep:HasFocus() then foot.keep:SetText(tostring(tonumber(B.db.restockKeep) or 0)) end
  local mode = B.db.restockMode == "order" and "order" or "each"
  for k, b in pairs(foot.modes) do
    local on = k == mode
    if b.SetBackdropColor then
      b:SetBackdropColor(on and 0.32 or 0.06, on and 0.24 or 0.06, on and 0.02 or 0.06, 0.95)
      b:SetBackdropBorderColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.3)
    end
    b.label:SetTextColor(on and 1 or 0.85, on and 0.82 or 0.85, on and 0 or 0.85)
  end
  -- what would happen at this vendor, or what you're short of
  local can = false
  if R.atVendor then
    local plan, cost, full = R.Plan(R.Budget())
    if #plan == 0 then foot.info:SetText("Nothing to buy from this vendor.")
    elseif cost == 0 and full > 0 then foot.info:SetText("|cffff6b5eNot enough money (you keep " .. (tonumber(B.db.restockKeep) or 0) .. "g).|r")
    else
      can = true
      foot.info:SetText((cost < full and "|cffffd100Part of it: |r" or "This vendor: ") .. coins(cost))
    end
  else
    local n, line = R.Short()
    foot.info:SetText(#L == 0 and "" or n > 0 and ("Short of: " .. line) or "|cff5cd65cAll stocked.|r")
  end
  foot.buy:SetEnabled(can)
  win:SetHeight(top + 96 + 6)
end
function R.Toggle()
  if not B.db then return end
  build()
  if win:IsShown() then win:Hide() else win:Show() place() R.Draw() end
  if B.restockBtn and B.LightUp then B.LightUp(B.restockBtn, win:IsShown()) end
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
    if B.db and B.db.restockAuto ~= false and #(list() or {}) > 0 then
      -- (a moment later: the vendor's list isn't always there the instant the window opens)
      C_Timer.After(0.4, function() if R.atVendor then R.Buy(false) end end)
    end
  elseif e == "MERCHANT_CLOSED" then
    R.atVendor = nil
  elseif e == "ADDON_ACTION_FORBIDDEN" then
    -- (if this game won't let an addon buy by itself: stop trying, say so once)
    if type(a) == "string" and a:find("^Rucksack") and type(b) == "string" and b:find("BuyMerchantItem") and B.db then
      B.db.restockAuto = false
      Print("this game doesn't let Rucksack buy by itself. Restock is switched to by hand: open the Restock bag at a vendor and click Buy now.")
    end
    return
  end
  if win and win:IsShown() then R.Draw() end
end)
