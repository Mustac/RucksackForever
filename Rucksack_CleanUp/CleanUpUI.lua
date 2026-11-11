-- Rucksack / Clean-up: its pages (the Clean-up page and one listed item's page)
local ns = Rucksack
if not ns then return end
local UI = ns.UI
local tip, HoverLabel, Text, TipText, Check, Stepper, Choices, List, Page, GuideButton, ToolHeader, ItemHeader =
  UI.tip, UI.HoverLabel, UI.Text, UI.TipText, UI.Check, UI.Stepper, UI.Choices, UI.List, UI.Page, UI.GuideButton, UI.ToolHeader, UI.ItemHeader
local pages = UI.pages
local Print = ns.Print

---------------------------------------------------------------------------
-- AutoDelete (with Fuzzy Search, Filters, and Deleted Item History)
---------------------------------------------------------------------------
do
  local p = Page()
  pages.del = p
  GuideButton(p, "del")
  local D = function() return ns.del end
  local function set(key) return function(v) D()[key] = v ns.Del.Refresh() end end
  ToolHeader(p, "|cffff5555Clean-up|r", function() return not D().hideIcon end, function(v) D().hideIcon = not v or nil ns.Del.Refresh() end,
    "Shows or hides the trash button on your screen. Hidden, Clean-up still deletes and sells (and the RuckDelete macro works). To pause Clean-up, use its switch on the Pocket; to turn it off completely, Settings > Modules.")
  local info = Text(p, 0, -28, "GameFontHighlightSmall", 440)
  local y = -48
  p:Add(Check(p, 0, y, "Delete on any key press", "When a remembered item may go, it's deleted on your next key press (outside combat). Off: only with the trash button or its key.",
    function() return D().onKey end, set("onKey")))
  p:Add(Check(p, 235, y, "Chat message when deleting", "Writes a line in chat each time Clean-up deletes something: which item and how many.", function() return D().chat end, set("chat")))
  y = y - 24
  p:Add(Check(p, 0, y, "Always show the trash button", "Off: it only shows when something is waiting to be deleted. Shift-drag to move it.",
    function() return D().alwaysIcon end, set("alwaysIcon")))
  -- (10 Nov) selling at vendors
  local greyBox = p:Add(Check(p, 235, y, "Sell grey items at vendors",
    "When you open a vendor, every grey item with a price is sold. Hold Shift while opening the vendor to sell nothing that time. Only the last 12 items can be bought back.",
    function() return D().sellGrey end, set("sellGrey")))
  y = y - 24
  p:Add(Check(p, 0, y, "At a vendor: sell my Clean-up items for gold  |cffaaaaaa(instead of deleting them later)|r",
    "Everything Clean-up would delete (your list, the quality rule, Rations' rules) is sold when you open a vendor, if it has a price. If your bags fill up before you reach one, they're still deleted. Never sold: amounts your quests need, Keep items, blue and better unless on your list.",
    function() return D().sellList end, set("sellList")))
  y = y - 24
  -- (10 Nov) soulbound gear this character can't use: sold, never deleted
  p:Add(Check(p, 0, y, "Sell soulbound gear I can't use  |cffaaaaaa(weapons, shields, relics)|r",
    "At a vendor, soulbound weapons your class can never use in WoW Forever are sold, and shields and relics your class can't use. Weapons you can learn but haven't trained yet are kept.\n\nOnly ever sold, never deleted, even with full bags. Up to blue: epics are never sold. Bind on equip that isn't bound yet is kept (for the Auction House). Keep items are never sold.",
    function() return D().sellGear end, set("sellGear")))
  y = y - 24
  local armorLbl = Text(p, 26, y - 4, "GameFontHighlightSmall")
  armorLbl:SetText("Also sell soulbound armor:")
  HoverLabel(p, armorLbl, "Armor to sell (this character)", "Tick the armor types this character never wears: soulbound pieces of those types are sold at a vendor (never deleted). Cloaks are never sold. Set for each character.")
  local ax = 190
  for i = 1, 4 do
    local name = ns.Sell.ARMOR[i]
    p:Add(Check(p, ax, y, name, "Sell soulbound " .. name:lower() .. " armor at vendors (this character). Cloaks never.",
      function() return ns.char.sellArmor and ns.char.sellArmor[i] end,
      function(v) ns.char.sellArmor = ns.char.sellArmor or {} ns.char.sellArmor[i] = v or nil ns.Changed() end, "GameFontHighlightSmall"))
    ax = ax + 82
  end
  y = y - 28
  p:Add(Stepper(p, 0, y, "Keep empty slots", 0, 30, 1, "%d free slots",
    function() return D().minFree or 2 end, function(v) D().minFree = v ns.Del.Refresh() end,
    "How many free bag slots Clean-up keeps for you. Say 3: while you have 3 or more free, nothing is touched. Drop to 2, and it throws out your cheapest junk first (the stuff worth the least), one stack per key press, until you're back to 3 free.\n\n" ..
    "Items set to \"As soon as I get it\" don't wait for this. At 0, Clean-up only deletes when you click the trash button or press its key.\n\n" ..
    "Shift-click - or + to change it by 5."))
  y = y - 28
  local QCOL = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee" }
  -- (1.7.4) what goes by itself (fixed rules), and the delete limit
  do
    local lbl = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 4, y - 4)
    lbl:SetWidth(640)
    lbl:SetJustifyH("LEFT")
    lbl:SetText("Goes by itself: |cff9d9d9dgrey|r items, |cffffffffwhite|r weapons and armour you can't wear or that are worse than what you wear, and soulbound gear you can't use. Profession tools always stay. Everything else only once you delete it yourself.")
    HoverLabel(p, lbl, "What goes by itself", "Sold at a vendor, or deleted when your bags are nearly full (cheapest first):\n\n- grey items (grey gear that's better than what you wear stays)\n- white weapons and armour your class can't wear, or that are worse than what you wear in that slot (less armour; weapons: less damage per second). Better gear and gear for an empty slot stay.\n- soulbound gear of any quality your class can't use\n\nAlways kept: profession tools (Skinning Knife, Mining Pick, fishing poles, enchanting rods...), reagents, trade goods, recipes, food and water, potions, bags, shirts and tabards, quest items and what your quests need, items with no vendor price, Darkmoon turn-in items, unread scrolls, and anything you set to Keep.")
    y = y - 34
    local lim = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lim:SetPoint("TOPLEFT", 4, y - 4)
    lim:SetText("Don't delete anything worth more than")
    HoverLabel(p, lim, "Delete limit", "Clean-up never deletes a stack worth more than this at a vendor. When the next one is, it stops and tells you; click the trash button to choose (Delete it, Keep it, Not now). It goes on by itself once you free up a bag slot.\n\nSelling at a vendor isn't limited.")
    local LIMITS = { { false, "No limit" }, { 1000, "10s" }, { 5000, "50s" }, { 10000, "1g" }, { 50000, "5g" }, { 100000, "10g" } }
    local lBtns = {}
    local lx = 270
    for i, l in ipairs(LIMITS) do
      local b = CreateFrame("Button", nil, p, ns.BACKDROP_TMPL)
      b:SetSize(l[1] and 46 or 68, 22)
      b:SetPoint("TOPLEFT", lx, y)
      lx = lx + b:GetWidth() + 3
      b:SetBackdrop(ns.SLOT_BACKDROP)
      b.label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      b.label:SetPoint("CENTER")
      b.label:SetText(l[2])
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetPoint("TOPLEFT", 3, -3) hl:SetPoint("BOTTOMRIGHT", -3, 3)
      hl:SetColorTexture(1, 1, 1, 0.08)
      b:SetScript("OnClick", function() D().maxValue = l[1] or nil ns.Del.Refresh() end)
      tip(b, l[1] and ("Up to " .. l[2]) or "No limit", l[1] and ("A stack worth more than " .. l[2] .. " isn't deleted: Clean-up waits and asks you.") or "Clean-up deletes the cheapest stack, whatever it's worth.")
      lBtns[i] = { b = b, v = l[1] or nil }
    end
    local waitFs = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    waitFs:SetPoint("TOPLEFT", 4, y - 30)
    local choose = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    choose:SetSize(80, 20)
    choose:SetPoint("LEFT", waitFs, "RIGHT", 8, 0)
    choose:SetText("Choose")
    choose:SetScript("OnClick", function() ns.Del.ShowBlocked() end)
    p.updates[#p.updates + 1] = function()
      for _, e in ipairs(lBtns) do
        local on = e.v == D().maxValue
        e.b:SetBackdropColor(on and 0.32 or 0.06, on and 0.24 or 0.06, on and 0.02 or 0.06, 0.95)
        e.b:SetBackdropBorderColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.3)
      end
      local b = ns.Del.Blocked and ns.Del.Blocked()
      waitFs:SetText(b and ("Waiting: " .. (b.link or ns.NameOf(b.id)) .. " (" .. ns.Sell.Money(b.value) .. ") is over your limit.") or "")
      choose:SetShown(b and true or false)
    end
    y = y - 24
  end
  y = y - 28
  Text(p, 0, y + 2, "GameFontDisableSmall", 560):SetText("To delete the next item with one click, drag the |cffffd100RuckDelete|r macro onto your bars (Esc > Macros > General tab).")
  y = y - 24
  local drop = CreateFrame("Button", nil, p, ns.BACKDROP_TMPL)
  drop:SetHeight(28)
  drop:SetPoint("TOPLEFT", 0, y)
  drop:SetPoint("RIGHT", 0, 0)
  drop:SetBackdrop(ns.SLOT_BACKDROP)
  drop:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
  drop:SetBackdropBorderColor(0.6, 0.6, 0.6)
  local dt = drop:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  dt:SetPoint("CENTER")
  dt:SetText("Drop an item here to always delete it")
  local function addFromCursor()
    local id, link = ns.CursorItem()
    if not id then return end
    ClearCursor()
    if ns.Del.Add(id, link) then
      Print((link or ns.NameOf(id)) .. " added: it will always be deleted.")
    else
      Print("grey items are already on the list: " .. (link or ns.NameOf(id)) .. " goes by itself.")
    end
  end
  drop:SetScript("OnReceiveDrag", addFromCursor)
  drop:SetScript("OnClick", addFromCursor)
  drop:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(1, 0.82, 0)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Add an item to your list")
    GameTooltip:AddLine("Pick an item up from your bags and drop it here (or click here while holding it). It goes on your list without being deleted now, and is deleted from then on when your bags are nearly full.", 1, 1, 1, true)
    GameTooltip:AddLine("Grey items don't need it: they're on the list already and go by themselves.", 0.62, 0.62, 0.62, true)
    GameTooltip:Show()
  end)
  drop:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.6, 0.6, 0.6) GameTooltip:Hide() end)

  -- Search + Filters header (search bar on the left side)
  y = y - 34
  TipText(p, 0, y - 3, "GameFontNormal", "Search:", "Type part of an item's name to find it in the list below. Small typos are fine: close matches are found too, best match first.")
  local searchBox = CreateFrame("EditBox", nil, p, ns.BACKDROP_TMPL)
  searchBox:SetSize(250, 22)
  searchBox:SetPoint("TOPLEFT", 58, y)
  searchBox:SetAutoFocus(false)
  searchBox:SetFontObject("ChatFontNormal")
  searchBox:SetTextInsets(8, 22, 0, 0)
  searchBox:SetBackdrop(ns.SLOT_BACKDROP)
  searchBox:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
  searchBox:SetBackdropBorderColor(0.5, 0.5, 0.5)
  local searchPh = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  searchPh:SetPoint("LEFT", 8, 0)
  searchPh:SetText("Search")
  local clearBtn = CreateFrame("Button", nil, searchBox)
  clearBtn:SetSize(16, 16)
  clearBtn:SetPoint("RIGHT", -4, 0)
  local clearFs = clearBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  clearFs:SetPoint("CENTER")
  clearFs:SetText("|cffaaaaaax|r")
  clearBtn:Hide()

  local searchQuery = ""
  local srcFilter = "all" -- "all", "always", "bags", "deleted" (the history)
  local qualFilter = nil  -- nil (any), 0 (trash), 1 (common), 2 (uncommon+)
  local refreshList

  clearBtn:SetScript("OnClick", function()
    searchBox:SetText("")
    searchBox:ClearFocus()
  end)
  searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  searchBox:SetScript("OnTextChanged", function(self)
    local txt = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    searchQuery = txt:lower()
    searchPh:SetShown(txt == "")
    clearBtn:SetShown(txt ~= "")
    if refreshList then refreshList() end
  end)

  -- Filter pills row
  y = y - 24
  -- (10 Nov) what the list shows: clear names, how many each has, and one line saying what it is
  local SRC_FILTERS = {
    { "all", "Everything", 92, "Your list, and what the rules (quality, Rations) catch in your bags." },
    { "always", "My list", 82, "The items you chose to always delete: white and better (grey trash goes by itself). Remove takes one off your list." },
    { "bags", "In my bags", 96, "Items on your list or caught by the quality rule that are in your bags now: these get deleted when your bags are nearly full." },
    { "deleted", "Deleted", 82, "The last 100 items deleted, newest first: how many, when, and why." },
  }
  local QUAL_FILTERS = {
    { nil, "Any", 46 },
    { 0, "|cff9d9d9dGrey|r", 52 },
    { 1, "|cffffffffWhite|r", 56 },
    { 2, "|cff1eff00Green +|r", 70 },
  }
  local function Pill(w, h, x, py)
    local b = CreateFrame("Button", nil, p, ns.BACKDROP_TMPL)
    b:SetSize(w, h)
    b:SetPoint("TOPLEFT", x, py)
    b:SetBackdrop(ns.SLOT_BACKDROP)
    b.label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3) hl:SetPoint("BOTTOMRIGHT", -3, 3)
    hl:SetColorTexture(1, 1, 1, 0.08)
    return b
  end
  local srcBtns, qualBtns = {}, {}
  TipText(p, 0, y - 4, "GameFontNormalSmall", "Show:", "Which items the list shows. Hover each button for what it means; the number is how many items it has.")
  local fx = 52
  for i, sf in ipairs(SRC_FILTERS) do
    local b = Pill(sf[3], 20, fx, y)
    fx = fx + sf[3] + 3
    b.name = sf[2]
    b.label:SetText(sf[2])
    b:SetScript("OnClick", function() srcFilter = sf[1] if refreshList then refreshList() end end)
    tip(b, sf[2], sf[4])
    srcBtns[i] = { b = b, v = sf[1], tip = sf[4] }
  end
  y = y - 22
  TipText(p, 0, y - 4, "GameFontNormalSmall", "Quality:", "Show only items of this quality: grey (junk), white (common), or green and better. Any: all of them.")
  local qfx = 52
  for i, qf in ipairs(QUAL_FILTERS) do
    local b = Pill(qf[3], 19, qfx, y)
    qfx = qfx + qf[3] + 3
    b.label:SetText(qf[2])
    b:SetScript("OnClick", function() qualFilter = qf[1] if refreshList then refreshList() end end)
    qualBtns[i] = { b = b, v = qf[1] }
  end
  local showing = Text(p, qfx + 10, y - 4, "GameFontDisableSmall", 440 - qfx)
  showing:SetWordWrap(false)

  -- Fuzzy match helper: returns a numeric score (>0 matches, nil does not match)
  local function fuzzyScore(q, name, id)
    if not q or q == "" then return 1 end
    local s = (name or ""):lower()
    local idStr = tostring(id or "")
    if idStr:find(q, 1, true) then return 200 end
    local pos = s:find(q, 1, true)
    if pos then return 150 - math.min(40, pos) end
    -- Multi-word check: every space-separated token matched as substring
    if q:find(" ", 1, true) then
      local allWords = true
      for w in q:gmatch("%S+") do
        if not s:find(w, 1, true) then allWords = false break end
      end
      if allWords then return 100 end
    end
    -- Initials check (e.g. "icm" -> "Ice Cold Milk")
    local initials = ""
    for w in s:gmatch("%w+") do initials = initials .. w:sub(1, 1) end
    local qClean = q:gsub("%s+", "")
    if initials:find(qClean, 1, true) then return 90 end
    -- Subsequence fuzzy match (all characters of qClean appear in order in s)
    local qi, lenQ, lenS, gaps = 1, #qClean, #s, 0
    for si = 1, lenS do
      if s:sub(si, si) == qClean:sub(qi, qi) then
        qi = qi + 1
        if qi > lenQ then return math.max(10, 70 - gaps) end
      elseif qi > 1 then
        gaps = gaps + 1
      end
    end
    return nil
  end

  local list = List(p, y - 22)
  refreshList = function()
    for _, e in ipairs(srcBtns) do
      local on = e.v == srcFilter
      e.b:SetBackdropColor(on and 0.32 or 0.06, on and 0.24 or 0.06, on and 0.02 or 0.06, 0.95)
      e.b:SetBackdropBorderColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.3)
    end
    for _, e in ipairs(qualBtns) do
      local on = e.v == qualFilter
      e.b:SetBackdropColor(on and 0.32 or 0.06, on and 0.24 or 0.06, on and 0.02 or 0.06, 0.95)
      e.b:SetBackdropBorderColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.3)
    end

    local n = 0
    for id, v in pairs(D().items) do
      local q = ns.QualityOf(id, type(v) == "string" and v or nil)
      if q ~= 0 then n = n + 1 end
    end
    info:SetText(D().enabled and ("%d on your list,  %d deleted so far,  %d free bag slots"):format(n, D().deleted or 0, ns.Del.FreeSlots())
      or "|cff999999Turned off: nothing is deleted or sold.|r")

    local meta = D().meta or {}
    local rowsData = {}
    local seenID = {}

    local function srcOK(fl, which)
      if which == "always" then return fl.always end
      if which == "deleted" then return fl.count <= 0 end
      if which == "bags" then return fl.count > 0 end
      if which == "quality" then return fl.quality end
      return true
    end
    local function passesFilters(isAlways, isQuality, count, q)
      if qualFilter ~= nil then
        if q == nil then return false end
        if qualFilter == 2 then
          if q < 2 then return false end
        elseif q ~= qualFilter then
          return false
        end
      end
      return true
    end

    -- 1. All items on the Always Delete list (including items already deleted with 0 in bags!)
    for id, linkVal in pairs(D().items) do
      seenID[id] = true
      local m = meta[id]
      local l = (type(linkVal) == "string" and linkVal) or (m and m.link) or ns.LinkOf(id)
      local nm = ns.NameOf(id, l)
      local q = ns.QualityOf(id, l) or (m and m.quality)
      local count = ns.GetCount(id) or 0
      local qNeed = ns.Del.QuestNeed and ns.Del.QuestNeed(id, l) or 0
      local score = fuzzyScore(searchQuery, nm, id)
      -- (10 Nov) trash goes by the quality rule anyway: grey items show under "By rule", and
      -- "My list" is what you put there yourself, white and better
      local greyRule = q == 0
      if score and passesFilters(true, false, count, q) then
        local fl = { always = not greyRule, quality = greyRule, count = count }
        local colored = l or ((q and QCOL[q] and (QCOL[q] .. "[" .. nm .. "]|r")) or nm)
        local itemID = id
        local itemLabel = l or nm
        local qTag = (qNeed > 0 and qNeed < math.huge and ("|cff66dd66quest " .. count .. "/" .. qNeed .. "|r  "))
          or (qNeed >= math.huge and "|cff66dd66quest item|r  ") or ""
        rowsData[#rowsData + 1] = {
          score = score,
          fl = fl,
          sortGroup = 1,
          name = nm,
          entry = {
            key = "del:" .. itemID,
            icon = ns.GetIcon(itemID) or (m and m.icon) or "Interface\\Icons\\INV_Misc_QuestionMark",
            text = colored,
            tag = qTag .. (greyRule and "|cff9d9d9dtrash: goes by itself|r  " or D().now[itemID] and "|cffff5555now|r  " or "|cffff8080always|r  ")
              .. (count > 0 and ("|cffffffffx" .. count .. " in bags|r") or "|cff888888deleted (0 in bags)|r"),
            itemID = itemID,
            dim = false,
            removeLabel = "Remove",
            onRemove = function()
              Print(itemLabel .. " removed from the Always Delete list.")
              ns.Del.Remove(itemID)
            end,
          },
        }
      end
    end

    -- 2. Items in bags caught by the quality rule or Rations' rules (or marked Keep)
    do
      for bag = 0, ns.NUM_BAGS do
        for slot = 1, (ns.GetNumSlots(bag) or 0) do
          local id, _, link = ns.SlotInfo(bag, slot)
          if id and not seenID[id] then
            local _, _, q = ns.GetInfo(id)
            q = q or ns.QualityOf(id, link)
            local kept = D().keep[id]
            local why = ns.Del.Reason(id)
            if (why and not D().items[id]) or (kept and ((q and q <= 1) or (ns.Eat and ns.Eat.found[id]))) then
              seenID[id] = true
              local nm = ns.NameOf(id, link)
              local count = ns.GetCount(id) or 0
              local score = fuzzyScore(searchQuery, nm, id)
              if score and passesFilters(false, true, count, q) then
                local fl = { always = false, quality = true, count = count }
                local itemID = id
                local isKept = kept
                rowsData[#rowsData + 1] = {
                  score = score,
                  fl = fl,
                  sortGroup = 2,
                  name = nm,
                  entry = {
                    key = "delq:" .. itemID,
                    icon = ns.GetIcon(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark",
                    text = link or nm,
                    tag = (isKept and "|cff66dd66kept|r  " or ("|cffaaaaaa" .. (why or "") .. "|r  ")) .. "x" .. count,
                    itemID = itemID,
                    dim = isKept,
                    removeLabel = isKept and "Allow" or "Keep",
                    onRemove = function()
                      D().keep[itemID] = not isKept or nil
                      Print((link or nm) .. (D().keep[itemID] and " will now be kept." or " can be deleted again."))
                      ns.Del.Refresh()
                    end,
                  },
                }
              end
            end
          end
        end
      end
    end

    -- 3. Recently deleted items from history (deleted by quality rule or Yes, not currently on Always list)
    for id, m in pairs(meta) do
      if not seenID[id] and D().keep[id] then -- (10 Nov: what was deleted is in the history now)
        seenID[id] = true
        local l = m.link or ns.LinkOf(id)
        local nm = m.name or ns.NameOf(id, l)
        local q = m.quality or ns.QualityOf(id, l)
        local count = ns.GetCount(id) or 0
        local isKept = D().keep[id]
        local score = fuzzyScore(searchQuery, nm, id)
        if score and passesFilters(false, true, count, q) then
          -- (deleted with Yes before: "by quality" only if the rule catches it, or it's kept)
          local fl = { always = false, quality = (isKept or (ns.Del.ByQuality and ns.Del.ByQuality(id))) and true or false, count = count }
          local colored = l or ((q and QCOL[q] and (QCOL[q] .. "[" .. nm .. "]|r")) or nm)
          local itemID = id
          rowsData[#rowsData + 1] = {
            score = score,
            fl = fl,
            sortGroup = 3,
            name = nm,
            entry = {
              key = "delq:" .. itemID,
              icon = ns.GetIcon(itemID) or m.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
              text = colored,
              tag = (isKept and "|cff66dd66kept|r  " or "|cff888888deleted history|r  ")
                .. (count > 0 and ("x" .. count) or "(0 in bags)"),
              itemID = itemID,
              dim = isKept,
              removeLabel = isKept and "Allow" or "Keep",
              onRemove = function()
                D().keep[itemID] = not isKept or nil
                Print(colored .. (D().keep[itemID] and " marked to KEEP (won't be auto-deleted)." or " allowed to be deleted again."))
                ns.Del.Refresh()
              end,
            },
          }
        end
      end
    end

    table.sort(rowsData, function(a, b)
      if searchQuery ~= "" and a.score ~= b.score then return a.score > b.score end
      if a.sortGroup ~= b.sortGroup then return a.sortGroup < b.sortGroup end
      return a.name < b.name
    end)

    -- (10 Nov) Deleted: the history, newest first
    local hist = {}
    local fmt = date or (os and os.date)
    local HOW = { always = "on your list", quality = "by quality", rations = "Rations rule", once = "Yes, once" }
    local today = fmt and fmt("%d.%m.%Y")
    for i, h in ipairs(D().history or {}) do
      local l = h.link or ns.LinkOf(h.id)
      local nm = ns.NameOf(h.id, l)
      local q = ns.QualityOf(h.id, l)
      local score = fuzzyScore(searchQuery, nm, h.id)
      if score and passesFilters(false, false, 0, q) then
        local when = ""
        if fmt and h.t then
          when = (fmt("%d.%m.%Y", h.t) == today) and fmt("%H:%M", h.t) or fmt("%d.%m.  %H:%M", h.t)
        end
        hist[#hist + 1] = {
          key = D().items[h.id] and ("del:" .. h.id) or nil,
          icon = ns.GetIcon(h.id) or "Interface\\Icons\\INV_Misc_QuestionMark",
          text = l or ((q and QCOL[q] and (QCOL[q] .. "[" .. nm .. "]|r")) or nm),
          tag = (h.count and h.count > 1 and ("|cffffffffx" .. h.count .. "|r   ") or "")
            .. "|cff888888" .. when .. "|r   " .. "|cffff8080" .. (HOW[h.how] or "deleted") .. "|r",
          itemID = h.id,
        }
      end
    end

    local entries = {}
    if srcFilter == "deleted" then entries = hist
    else for _, r in ipairs(rowsData) do if srcOK(r.fl, srcFilter) then entries[#entries + 1] = r.entry end end end
    for _, e in ipairs(srcBtns) do
      local n = 0
      if e.v == "deleted" then n = #hist
      else for _, r in ipairs(rowsData) do if srcOK(r.fl, e.v) then n = n + 1 end end end
      e.b.label:SetText(e.b.name .. "  |cffaaaaaa" .. n .. "|r")
      if e.v == srcFilter then showing:SetText(e.tip) end
    end
    local EMPTY = { all = "Nothing here yet: delete an item and click Always, or drop one in the box above.",
      always = "Your list is empty: delete an item and click Always, or drop one in the box above.",
      bags = "Nothing in your bags is waiting to be deleted.", deleted = "Nothing deleted yet.",
 }
    list:Set(entries, searchQuery ~= "" and ("No items matching \"" .. searchQuery .. "\".")
      or EMPTY[srcFilter] or "Nothing here.")
  end
  p.updates[#p.updates + 1] = refreshList
end

---------------------------------------------------------------------------
-- One remembered (always delete) item
---------------------------------------------------------------------------
do
  local p = Page()
  pages.delItem = p
  ItemHeader(p, "del", "Clean-up")
  local price = Text(p, 0, -54, "GameFontHighlight", 440)
  TipText(p, 0, -84, "GameFontNormal", "When to delete it", "Most items wait until your bags are nearly full (set on the Clean-up page). Pick \"As soon as I get it\" for things you never want to carry, even with empty bags.")
  local D = function() return ns.del end
  local wait = Check(p, 0, -104, "When my bags are nearly full", "Waits until you have fewer free bag slots than set on the Clean-up page (the cheapest stack goes first).",
    function() return not D().now[p.id] end, function() D().now[p.id] = nil ns.Del.Refresh() end)
  local now = Check(p, 0, -130, "As soon as I get it", "Deleted on your next key press after it lands in your bags, full bags or not.",
    function() return D().now[p.id] end, function() D().now[p.id] = true ns.Del.Refresh() end)
  local stop = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  stop:SetSize(160, 24)
  stop:SetPoint("TOPLEFT", 0, -172)
  stop:SetText("Stop deleting it")
  stop:SetScript("OnClick", function()
    local id = p.id
    Print((type(ns.del.items[id]) == "string" and ns.del.items[id] or ns.NameOf(id)) .. " removed from the delete list.")
    ns.Del.Remove(id)
    Rucksack_Open("del")
  end)
  p.updates[#p.updates + 1] = function()
    local id = p.id
    local saved = ns.del.items[id]
    p.link = type(saved) == "string" and saved or ns.LinkOf(id)
    p.icon.tex:SetTexture(ns.GetIcon(id))
    p.name:SetText(p.link or ns.NameOf(id))
    p.sub:SetText("In your bags: " .. (ns.GetCount(id) or 0))
    local sell = select(11, ns.GetInfo(id))
    price:SetText("Vendor price: " .. ((sell and sell > 0) and GetCoinTextureString(sell) or "none"))
    wait.Update() now.Update()
  end
end

