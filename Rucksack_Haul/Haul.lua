-- Rucksack / Haul (19 Nov): what you loot, what it's worth, and how much you earn. His own Haul addon
-- (1.2.0) built into Rucksack as a module (he: "implement Haul addon in Rucksack and make it as module
-- that is on by default"). New here: a run (Start / Pause / Stop: Stop saves it to History), a button
-- on the screen, and the bag (HaulBag.lua). Prices: the newest auction price among the price addons
-- you tick, and the vendor price from the game. Sessions are kept in RucksackHaulDB.history.
local ns = Rucksack
if not ns then return end

local H = {}
ns.Haul = H
RucksackHaul = H

H.CALLER = "Haul"
H.BACKDROP_TMPL = BackdropTemplateMixin and "BackdropTemplate" or nil
H.HISTORY_MAX = 300   -- sessions kept
H.TOP_KEEP = 20       -- most valuable items kept with a saved session
H.BREAK = 2 * 3600    -- logged out this long: the old session is saved and a new one starts
H.CACHE_SECS = 20
H.CALM = 10           -- a pull ends this long after combat (or the last loot after combat)
H.PULLS_KEEP = 400    -- pulls kept with a saved session

local DEFAULTS = {
  valueBy = "best",   -- "best" (higher of auction and vendor), "ah", "vendor"
  sort = "value",     -- "value", "new"
  shown = false,      -- (19 Nov: the button on the screen opens it)
  autoNew = true,
  edge = "grey",      -- "grey", "bronze", "black"
  alpha = 0.7,
  scale = 1,
  locked = false,
  list = "items",     -- the view: "items" (by value, one line per item) or "pulls"
  bag = true,         -- (19 Nov) Haul notes which stacks are your loot while a run is on (for Sort loot)
  autoSort = true,    -- (19 Nov) and sorts them by itself as they come in (sell / Haul - Auction house)
  ahHouse = "faction", -- (19 Nov) the auction house you post at: "faction" (5 % cut) or "neutral" (15 %, 5x deposit)
  ahHours = 24,       -- (19 Nov) how long you post for: 2, 8 or 24 hours (the deposit grows with it)
  ahDepositLost = false, -- (19 Nov) count the deposit as lost (as if it doesn't sell); off: it comes back when it sells
  vendorMark = true,  -- (19 Nov) a coin on items in the bag a vendor pays more for, and a sell button at vendors
}

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local floor, max, min = math.floor, math.max, math.min

function H.Print(msg)
  ns.Print("|cffd9b36cHaul|r: " .. msg)
end

---------------------------------------------------------------------------
-- Money and time text
---------------------------------------------------------------------------
local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

-- 12g 34s (copper left out once there is gold)
function H.Money(c)
  c = floor((c or 0) + 0.5)
  local g, s, cp = floor(c / 10000), floor(c / 100) % 100, c % 100
  local out = {}
  if g > 0 then
    local gs = tostring(g)
    if g >= 1000 then gs = gs:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") end
    out[#out + 1] = gs .. GOLD
  end
  if s > 0 then out[#out + 1] = s .. SILVER end
  if g == 0 and (cp > 0 or s == 0) then out[#out + 1] = cp .. COPPER end
  return table.concat(out, " ")
end

-- 37g / 4s / 9c, for small spots
function H.Short(c)
  c = floor((c or 0) + 0.5)
  if c >= 10000 then return floor(c / 10000) .. "g" end
  if c >= 100 then return floor(c / 100) .. "s" end
  return c .. "c"
end

function H.Clock(secs)
  secs = floor(secs or 0)
  return string.format("%d:%02d:%02d", floor(secs / 3600), floor(secs / 60) % 60, secs % 60)
end

function H.Span(secs)
  secs = floor(secs or 0)
  local h, m = floor(secs / 3600), floor(secs / 60) % 60
  if h > 0 then return h .. "h " .. m .. "m" end
  return max(m, secs > 0 and 1 or 0) .. "m"
end

function H.Age(secs)
  if not secs then return "age unknown" end
  if secs < 3600 then return max(1, floor(secs / 60)) .. " min old" end
  if secs < 86400 then return floor(secs / 3600) .. " h old" end
  return floor(secs / 86400) .. " days old"
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
function H.IdOf(link)
  return tonumber(type(link) == "string" and link:match("item:(%d+)") or nil)
end

-- Items with a random suffix ("of the Wolf") are kept apart: they are worth different amounts.
function H.KeyOf(link, id)
  local suffix = link:match("item:%d+:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:|]*)")
  if suffix and suffix ~= "" and suffix ~= "0" then return id .. ":" .. suffix end
  return id
end

-- name, quality, icon, vendor price (one), bind type
function H.Info(id, link)
  local name, _, quality, icon, sell, bind
  if link then
    local ok, n, _, q, _, _, _, _, _, _, ic, sp, _, _, b = pcall(GetItemInfo, link)
    if ok and n then name, quality, icon, sell, bind = n, q, ic, sp, b end
  end
  if not name and id then
    local ok, n, _, q, _, _, _, _, _, _, ic, sp, _, _, b = pcall(GetItemInfo, id)
    if ok and n then name, quality, icon, sell, bind = n, q, ic, sp, b end
  end
  if not icon and id then
    icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
  end
  if not name and link then name = link:match("%[(.-)%]") end
  return name, quality, icon, sell, bind
end

---------------------------------------------------------------------------
-- Prices
---------------------------------------------------------------------------
local cache = {}

function H.ClearPrices() wipe(cache) end

-- Price addons Haul can read. Each: key, name, Has() (installed and loaded), Get(id, link) -> copper for one,
-- age in seconds (nil when the addon doesn't say). Prices are the lowest buyout where the addon has one.
-- The player ticks which ones to use (HaulDB.settings.src[key] = false turns one off); the newest price wins.
local DAY = 86400
local function num(p) return type(p) == "number" and p > 0 and p or nil end

H.SOURCES = {
  {
    key = "auctionator", name = "Auctionator", note = "your own scans (Full Scan in its tab)",
    Has = function()
      local api = Auctionator and Auctionator.API and Auctionator.API.v1
      return api and api.GetAuctionPriceByItemID and true or false
    end,
    Get = function(id, link)
      local api = Auctionator.API.v1
      local ok, p
      if link and api.GetAuctionPriceByItemLink then ok, p = pcall(api.GetAuctionPriceByItemLink, H.CALLER, link) end
      if not (ok and num(p)) then ok, p = pcall(api.GetAuctionPriceByItemID, H.CALLER, id) end
      if not (ok and num(p)) then return nil end
      local f, arg = api.GetAuctionAgeByItemID, id
      if link and api.GetAuctionAgeByItemLink then f, arg = api.GetAuctionAgeByItemLink, link end
      local age
      if f then
        local ok2, days = pcall(f, H.CALLER, arg)
        -- whole days only: a "today" scan counts as half a day old, so an hourly price can beat it
        if ok2 and type(days) == "number" then age = days * DAY + DAY / 2 end
      end
      return p, age
    end,
  },
  {
    key = "goldscout", name = "GoldScout", note = "its Companion app (hourly) or your scans",
    Has = function()
      return type(rawget(_G, "GoldScoutPricesData")) == "table" or type(rawget(_G, "GoldScoutDB")) == "table"
    end,
    Get = function(id)
      local key = H.MarketKey()
      local best, bestAge
      local gs = rawget(_G, "GoldScoutDB")
      local m = type(gs) == "table" and type(gs.markets) == "table" and gs.markets[key]
      local e = type(m) == "table" and type(m.items) == "table" and m.items[id]
      if type(e) == "table" and num(e.p) then best, bestAge = e.p, e.t and (time() - e.t) or nil end
      local pd = rawget(_G, "GoldScoutPricesData")
      local pm = type(pd) == "table" and type(pd.markets) == "table" and pd.markets[key]
      if type(pm) == "table" and type(pm.items) == "table" and type(pm.snapshot) == "number" and time() - pm.snapshot < 30 * DAY then
        local it = pm.items[id]
        local p = num(type(it) == "table" and (it.price or it[1]) or it)
        local age = time() - pm.snapshot
        if p and (not best or not bestAge or age < bestAge) then best, bestAge = p, age end
      end
      return best, bestAge
    end,
  },
  {
    key = "craftprofit", name = "CraftProfit", note = "its own auction house scan",
    Has = function()
      local CP = rawget(_G, "CraftProfit")
      return type(CP) == "table" and CP.Sources and CP.Sources.byKey and CP.Sources.byKey.craftprofit and true or false
    end,
    Get = function(id)
      local def = CraftProfit.Sources.byKey.craftprofit
      local ok, p = pcall(def.GetSalePrice, def, id)
      if not (ok and num(p)) then return nil end
      local age
      if def.GetAge then
        local ok2, a = pcall(def.GetAge, def, id)
        if ok2 and type(a) == "number" then age = a end
      end
      return p, age
    end,
  },
  {
    key = "ahledger", name = "AHledger", note = "shared prices, its sync app every 30 min",
    credit = "Prices from AHledger (ahledger.com)",
    Has = function()
      local api = rawget(_G, "AHledgerAPI")
      return type(api) == "table" and api.GetPrice and true or false
    end,
    Get = function(id, link)
      local p = AHledgerAPI.GetPrice(link or id) -- (never raises, says AHledger)
      if type(p) ~= "table" then return nil end
      local v = num(p.minBuyout) or num(p.median)
      if not v then return nil end
      return v, type(p.updated) == "number" and max(0, time() - p.updated) or nil
    end,
  },
  {
    key = "aux", name = "auxForever", note = "your own scans and searches",
    Has = function()
      local api = rawget(_G, "AuxForeverAPI")
      return type(api) == "table" and api.GetLatestPrice and true or false
    end,
    Get = function(id, link)
      local api = AuxForeverAPI
      if api.IsReady then
        local okR, r = pcall(api.IsReady)
        if not (okR and r) then return nil end
      end
      local ok, p, days = pcall(api.GetLatestPrice, link or id)
      if not (ok and num(p)) then return nil end
      return p, type(days) == "number" and (days * DAY + DAY / 2) or nil
    end,
  },
  {
    key = "hammerprice", name = "Hammerprice", note = "your scans or its desktop app (age unknown)",
    Has = function()
      local hp = rawget(_G, "Hammerprice")
      return type(hp) == "table" and type(hp.GetPrice) == "function"
    end,
    Get = function(id, link)
      local ok, p = pcall(Hammerprice.GetPrice, link or id, "minBuyout")
      if not (ok and num(p)) then ok, p = pcall(Hammerprice.GetPrice, link or id, "market") end
      if ok and num(p) then return p, nil end
    end,
  },
  -- (19 Nov, release 1.9.13) Life on Azeroth is left out: it has no public way for other addons to read
  -- its prices (he: "Leave it out")
}
H.SOURCE_BY = {}
for _, s in ipairs(H.SOURCES) do H.SOURCE_BY[s.key] = s end

function H.MarketKey()
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "Unknown"
  return realm .. "-" .. (UnitFactionGroup("player") or "Neutral")
end

function H.SourceOn(key)
  local t = H.db and H.db.src
  return not (type(t) == "table" and t[key] == false)
end

function H.SetSourceOn(key, on)
  H.db.src = H.db.src or {}
  if on then H.db.src[key] = nil else H.db.src[key] = false end
  H.ClearPrices()
end

-- Names of the price addons in use (installed and ticked).
function H.Sources()
  local list = {}
  for _, s in ipairs(H.SOURCES) do
    local okH, has = pcall(s.Has)
    if okH and has and H.SourceOn(s.key) then list[#list + 1] = s.name end
  end
  return list
end

-- Auction price for one: the newest of the ticked sources. Returns copper, source name, age in seconds, source key.
-- A source that doesn't say how old its price is only wins when no other has one.
function H.AHPrice(id, link)
  local best, bestAge, bestSrc, bestRealAge, bestKey
  for _, s in ipairs(H.SOURCES) do
    if H.SourceOn(s.key) then
      local okH, has = pcall(s.Has)
      if okH and has then
        local ok, p, age = pcall(s.Get, id, link)
        if ok and num(p) then
          local a = type(age) == "number" and age or 1e12
          if not best or a < bestAge then best, bestAge, bestSrc, bestRealAge, bestKey = p, a, s.name, age, s.key end
        end
      end
    end
  end
  return best, bestSrc, bestRealAge, bestKey
end

-- What one is worth: value (copper), "ah" / "vendor" / nil, auction price, vendor price, source, age.
-- Grey, soulbound and quest items can't go on the auction house: vendor only.
function H.Value(id, link)
  local key = link or id
  local now = GetTime()
  local c = cache[key]
  if not c or now - c.t > H.CACHE_SECS then
    local name, quality, _, sell, bind = H.Info(id, link)
    local vendor = (type(sell) == "number" and sell > 0) and sell or nil
    local ah, src, age, skey
    if not (quality == 0 or bind == 1 or bind == 4) then ah, src, age, skey = H.AHPrice(id, link) end
    c = { t = now, ah = ah, vendor = vendor, src = src, age = age, skey = skey, known = name ~= nil and sell ~= nil }
    if not c.known then c.t = now - H.CACHE_SECS + 2 end -- item details not loaded yet: ask again soon
    cache[key] = c
  end
  local ah, vendor, by = c.ah, c.vendor, H.db and H.db.valueBy or "best"
  if by == "vendor" or (by == "best" and (not ah or (vendor and vendor > ah))) or (by == "ah" and not ah) then
    return vendor or 0, vendor and "vendor" or nil, ah, vendor, c.src, c.age, c.skey
  end
  return ah, "ah", ah, vendor, c.src, c.age, c.skey
end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------
local function charKey()
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?"
  return (UnitName("player") or "?") .. "-" .. realm
end

function H.NewSession()
  return {
    char = UnitName("player"), class = select(2, UnitClass("player")),
    start = time(), seen = time(), active = 0, gold = 0, items = {}, seq = 0,
  }
end
-- (19 Nov) counting: only while a run is on (Start) and not paused
function H.Running() return H.cur and H.cur.running and true or false end
function H.Counting() return H.cur and H.cur.running and not H.cur.paused and true or false end

function H.HasData(s)
  return s and ((s.gold or 0) > 0 or next(s.items or {}) ~= nil)
end

-- The session's items with their values, sorted ("value" or "new").
function H.ItemList(s, sort)
  local list = {}
  for key, e in pairs(s.items) do
    local unit, kind, ah, vendor, src, age = H.Value(e.id, e.link)
    list[#list + 1] = { key = key, id = e.id, link = e.link, n = e.n, unit = unit, total = unit * e.n, kind = kind,
      ah = ah, vendor = vendor, src = src, age = age, at = e.at, seq = e.seq or 0 }
  end
  if sort == "new" then
    table.sort(list, function(a, b) return a.seq > b.seq end)
  else
    table.sort(list, function(a, b)
      if a.total ~= b.total then return a.total > b.total end
      return a.seq > b.seq
    end)
  end
  return list
end

function H.Totals(s)
  local t = { gold = s.gold or 0, worth = 0, vendor = 0, ah = 0, count = 0, kinds = 0 }
  for _, e in pairs(s.items) do
    local unit, _, ah, vendor = H.Value(e.id, e.link)
    t.worth = t.worth + unit * e.n
    t.vendor = t.vendor + (vendor or 0) * e.n
    if ah then t.ah = t.ah + ah * e.n end
    t.count = t.count + e.n
    t.kinds = t.kinds + 1
  end
  t.total = t.gold + t.worth
  t.active = s.active or 0
  if t.active >= 60 then t.perHour = t.total * 3600 / t.active end
  return t
end

---------------------------------------------------------------------------
-- Pulls: combat starts a pull; it ends H.CALM seconds after combat ends. Fighting again
-- inside that time, or looting (each loot restarts the wait), keeps the same pull.
-- Loot outside any pull opens a "no fight" pull (herbs, ore, chests).
-- s.pulls is oldest first; the open one is the last, with p.open set.
---------------------------------------------------------------------------
function H.CurPull()
  local ps = H.cur and H.cur.pulls
  local p = ps and ps[#ps]
  if p and p.open then return p end
end

function H.LastPull()
  local ps = H.cur and H.cur.pulls
  return ps and ps[#ps]
end

function H.PullOpen(fight)
  local s = H.cur
  s.pulls = s.pulls or {}
  local p = H.CurPull()
  if not p then
    p = { start = time(), open = true, ft = 0, gold = 0, items = {}, seq = 0 }
    s.pulls[#s.pulls + 1] = p
  end
  if fight then p.fight = true end
  return p
end

function H.FightTime(p)
  return (p.ft or 0) + (p.cs and (time() - p.cs) or 0)
end

function H.PullClose(p)
  local s = H.cur
  if p.cs then p.ft = (p.ft or 0) + time() - p.cs end
  p.open, p.cs, p.calm = nil, nil, nil
  p.stop = time()
  if (p.gold or 0) == 0 and not next(p.items) then
    for i = #s.pulls, 1, -1 do
      if s.pulls[i] == p then table.remove(s.pulls, i) break end
    end
  end
  while #s.pulls > H.PULLS_KEEP do table.remove(s.pulls, 1) end
  if H.UI then H.UI.Refresh() end
end

function H.CombatStart()
  H.inCombat = true
  if not H.Counting() then return end
  local p = H.PullOpen(true)
  p.cs = p.cs or time()
  p.calm = nil
  if H.UI then H.UI.Refresh() end
end

function H.CombatEnd()
  H.inCombat = false
  local p = H.CurPull()
  if not p then return end
  if p.cs then p.ft = (p.ft or 0) + time() - p.cs; p.cs = nil end
  p.calm = time()
  if H.UI then H.UI.Refresh() end
end

-- Every second: close the pull once the calm time is over.
function H.PullTick()
  local p = H.CurPull()
  if not p or H.inCombat then return end
  if p.cs then p.ft = (p.ft or 0) + time() - p.cs; p.cs = nil end -- (after a reload out of combat)
  p.calm = p.calm or time()
  if time() - p.calm >= H.CALM then H.PullClose(p) end
end

-- The pull's items with values, most valuable first.
function H.PullItems(p)
  local list = {}
  for key, e in pairs(p.items) do
    local unit, kind = H.Value(e.id, e.link)
    list[#list + 1] = { key = key, id = e.id, link = e.link, n = e.n, total = unit * e.n, kind = kind, seq = e.seq or 0 }
  end
  table.sort(list, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.seq > b.seq
  end)
  return list
end

local function pullLoot(key, id, link, n)
  local p = H.PullOpen(false)
  local e = p.items[key]
  if not e then
    e = { id = id, link = link, n = 0 }
    p.items[key] = e
  end
  e.n = e.n + n
  p.seq = (p.seq or 0) + 1
  e.seq = p.seq
  p.last = time()
  if not H.inCombat then p.calm = time() end
end

-- Puts the current session into the history (if anything was looted) and starts a new one.
function H.Reset()
  local s = H.cur
  local p = H.CurPull()
  if p then H.PullClose(p) end
  if H.HasData(s) then
    local t = H.Totals(s)
    local top = {}
    for i, r in ipairs(H.ItemList(s, "value")) do
      if i > H.TOP_KEEP then break end
      top[i] = { id = r.id, link = r.link, n = r.n, v = r.total, kind = r.kind }
    end
    local pulls = {}
    for i = #(s.pulls or {}), 1, -1 do -- newest first
      local q = s.pulls[i]
      local fp = { start = q.start, stop = q.stop, fight = q.fight, ft = floor(q.ft or 0), gold = q.gold or 0, worth = 0, items = {} }
      for _, it in ipairs(H.PullItems(q)) do
        fp.items[#fp.items + 1] = { id = it.id, link = it.link, n = it.n, v = it.total, kind = it.kind }
        fp.worth = fp.worth + it.total
      end
      pulls[#pulls + 1] = fp
      if #pulls >= H.PULLS_KEEP then break end
    end
    table.insert(H.DB.history, 1, {
      char = s.char, class = s.class, start = s.start, stop = s.seen or time(), active = floor(s.active or 0),
      gold = t.gold, worth = t.worth, vendor = t.vendor, ah = t.ah, count = t.count, kinds = t.kinds, top = top,
      pulls = pulls,
    })
    while #H.DB.history > H.HISTORY_MAX do table.remove(H.DB.history) end
  end
  local paused, running = s and s.paused, s and s.running
  H.cur = H.NewSession()
  H.cur.paused, H.cur.running = paused, running
  H.DB.cur[charKey()] = H.cur
  H.last = nil
  if H.inCombat then H.CombatStart() end
  if H.UI then H.UI.Refresh() end
end

function H.SetPaused(on)
  H.cur.paused = on and true or nil
  if H.UI then H.UI.Refresh() end
  if H.Changed then H.Changed() end
end
-- (19 Nov) Start: a run begins (a fresh session); Stop: it's saved to History and counting stops
function H.Start()
  if H.Running() then
    if H.cur.paused then H.SetPaused(false) end
    return
  end
  if H.HasData(H.cur) then H.Reset() end -- (anything left from before goes to History first)
  H.cur.running, H.cur.paused = true, nil
  H.cur.start, H.cur.active = time(), 0
  if H.inCombat then H.CombatStart() end
  H.Print("started: your loot counts now.")
  if H.UI then H.UI.Refresh() end
  if H.Changed then H.Changed() end
end
function H.Stop()
  if not H.Running() then return end
  local had = H.HasData(H.cur)
  H.Reset()
  H.cur.running, H.cur.paused = nil, nil
  H.Print(had and "stopped: this run is saved in History." or "stopped.")
  if H.OnStop then pcall(H.OnStop) end
  if H.UI then H.UI.Refresh() end
  if H.Changed then H.Changed() end
end

function H.AddLoot(link, n)
  local s = H.cur
  if not H.Counting() then return end
  local id = H.IdOf(link)
  if not id then return end
  local key = H.KeyOf(link, id)
  local e = s.items[key]
  if not e then
    e = { id = id, link = link, n = 0 }
    s.items[key] = e
  end
  e.n = e.n + (n or 1)
  s.seq = (s.seq or 0) + 1
  e.seq, e.at = s.seq, time()
  pullLoot(key, id, link, n or 1)
  H.last = { link = link, id = id, n = n or 1, at = time() }
  if H.OnLoot then pcall(H.OnLoot, id, link, n or 1) end -- (the bag: HaulBag.lua)
  if H.UI then H.UI.Refresh() end
end

function H.AddGold(c)
  local s = H.cur
  if not H.Counting() or c <= 0 then return end
  s.gold = (s.gold or 0) + c
  H.lastGold = { c = c, at = time() }
  local p = H.PullOpen(false)
  p.gold = (p.gold or 0) + c
  p.last = time()
  if not H.inCombat then p.calm = time() end
  if H.UI then H.UI.Refresh() end
end

---------------------------------------------------------------------------
-- Reading the loot lines
---------------------------------------------------------------------------
-- "You receive loot: %sx%d." -> "^You receive loot: (.-)x(%d+)%.$"
function H.Pattern(fmt)
  if type(fmt) ~= "string" then return nil end
  fmt = fmt:gsub("%%%d%$([sd])", "%%%1")
  fmt = fmt:gsub("%%([sd])", "\001%1")
  fmt = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  fmt = fmt:gsub("\001s", "(.-)"):gsub("\001d", "(%%d+)")
  return "^" .. fmt .. "$"
end

local lootPats
local function buildPatterns()
  lootPats = {}
  local function add(multi, single)
    local p = H.Pattern(multi)
    if p then lootPats[#lootPats + 1] = { p, true } end
    p = H.Pattern(single)
    if p then lootPats[#lootPats + 1] = { p, false } end
  end
  add(LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_SELF or "You receive loot: %s.")
end

function H.OnLootText(text)
  if type(text) ~= "string" then return end
  if issecretvalue and issecretvalue(text) then return end
  if not lootPats then buildPatterns() end
  for _, p in ipairs(lootPats) do
    local link, n = text:match(p[1])
    if link then
      if p[2] then n = tonumber(n) else n = 1 end
      if H.IdOf(link) then H.AddLoot(link, n or 1) end
      return true
    end
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
H.ev = ev
local looting, closeToken, lastMoney = false, 0, nil

-- (19 Nov) the old Haul addon's saved sessions come over once; the old addon is turned off for the next
-- reload (both at once would count every loot twice), and this time its window and counting stop
local function importOld()
  local old = rawget(_G, "HaulDB")
  if not H.DB.imported and type(old) == "table" then
    H.DB.imported = true
    local n = 0
    if type(old.history) == "table" then
      for i = #old.history, 1, -1 do table.insert(H.DB.history, 1, old.history[i]) n = n + 1 end
      while #H.DB.history > H.HISTORY_MAX do table.remove(H.DB.history) end
    end
    if type(old.settings) == "table" then
      for k, v in pairs(old.settings) do if k ~= "shown" and k ~= "pos" then H.DB.settings[k] = v end end
    end
    -- the session it was on: kept as a saved one (if anything was looted)
    if type(old.cur) == "table" then
      for _, s in pairs(old.cur) do
        if type(s) == "table" and H.HasData(s) then
          local keep = H.cur
          H.cur = s
          s.items = s.items or {}
          H.Reset()
          H.cur = keep
          n = n + 1
        end
      end
      H.DB.cur[charKey()] = H.cur -- (Reset put a fresh session there: this character's own goes back)
    end
    if n > 0 then H.Print(n .. " sessions from your Haul addon are in History now.") end
  end
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Haul")
  if loaded then
    local oldH = rawget(_G, "Haul")
    if type(oldH) == "table" and oldH ~= H and oldH.ev and oldH.ev.UnregisterAllEvents then pcall(oldH.ev.UnregisterAllEvents, oldH.ev) end
    local frame = rawget(_G, "HaulFrame")
    if frame and frame.Hide then frame:Hide() end
    if C_AddOns.DisableAddOn then pcall(C_AddOns.DisableAddOn, "Haul") end
    H.Print("Haul is part of Rucksack now: your old Haul addon is turned off (from the next reload).")
  end
end

local function onLogin()
  local D = RucksackHaulDB
  D.settings = D.settings or {}
  D.history = D.history or {}
  D.cur = D.cur or {}
  H.DB = D
  for k, v in pairs(DEFAULTS) do
    if D.settings[k] == nil then D.settings[k] = v end
  end
  H.db = D.settings

  H.inCombat = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
  local key = charKey()
  local s = D.cur[key]
  if s then
    s.items = s.items or {}
    H.cur = s
    if H.db.autoNew and H.HasData(s) and s.seen and time() - s.seen > H.BREAK then
      H.Reset()
      H.Print("your last session (" .. H.Span(D.history[1].active) .. ") was saved to History. A new one has started.")
    end
  else
    H.cur = H.NewSession()
    D.cur[key] = H.cur
  end
  H.cur.seen = time()
  lastMoney = GetMoney()
  pcall(importOld)

  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.RegisterForDBUpdate then
    pcall(api.RegisterForDBUpdate, H.CALLER, function() H.ClearPrices(); if H.UI then H.UI.Refresh() end end)
  end

  if H.UI then H.UI.Init() end
  if H.BagInit then pcall(H.BagInit) end

  local lastTick = GetTime()
  C_Timer.NewTicker(1, function()
    local now = GetTime()
    local dt = min(now - lastTick, 5)
    lastTick = now
    local cur = H.cur
    if cur.running and not cur.paused then cur.active = (cur.active or 0) + dt end
    cur.seen = time()
    H.PullTick()
    if H.UI then H.UI.Tick() end
    if H.BagTick then pcall(H.BagTick) end
  end)
end
H.OnLogin = onLogin

ev:SetScript("OnEvent", function(_, event, ...)
  if not H.cur then
    return
  elseif event == "CHAT_MSG_LOOT" then
    H.OnLootText((...))
  elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
    looting = true
    closeToken = closeToken + 1
  elseif event == "LOOT_CLOSED" then
    closeToken = closeToken + 1
    local token = closeToken
    C_Timer.After(1, function() if token == closeToken then looting = false end end)
  elseif event == "PLAYER_MONEY" then
    local m = GetMoney()
    if lastMoney and looting and m > lastMoney then H.AddGold(m - lastMoney) end
    lastMoney = m
  elseif event == "PLAYER_REGEN_DISABLED" then
    H.CombatStart()
  elseif event == "PLAYER_REGEN_ENABLED" then
    H.CombatEnd()
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    if H.UI then H.UI.Refresh(true) end
  end
end)
for _, e in ipairs({ "CHAT_MSG_LOOT", "LOOT_OPENED", "LOOT_READY", "LOOT_CLOSED", "PLAYER_MONEY",
  "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
  pcall(ev.RegisterEvent, ev, e)
end

---------------------------------------------------------------------------
-- /haul
---------------------------------------------------------------------------
function RucksackHaul_Toggle()
  if H.UI then H.UI.Toggle() end
end

SLASH_RUCKSACKHAUL1 = "/haul"
SlashCmdList.RUCKSACKHAUL = function(msg)
  if not H.cur then return end
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "" then
    RucksackHaul_Toggle()
  elseif cmd == "start" then
    H.Start()
  elseif cmd == "stop" or cmd == "reset" then
    H.Stop()
  elseif cmd == "history" then
    H.UI.Show("history")
  elseif cmd == "options" or cmd == "settings" then
    H.UI.Show("options")
  elseif cmd == "pause" then
    if H.Running() then H.SetPaused(not H.cur.paused) end
  elseif cmd == "edge" and (arg == "grey" or arg == "bronze" or arg == "black") then
    H.db.edge = arg
    H.UI.Restyle()
  elseif cmd == "alpha" and tonumber(arg) then
    H.db.alpha = max(0, min(100, tonumber(arg))) / 100
    H.UI.Restyle()
  elseif cmd == "scale" and tonumber(arg) then
    H.db.scale = max(0.5, min(2, tonumber(arg)))
    H.UI.Restyle()
  elseif cmd == "lock" then
    H.db.locked = not H.db.locked
    H.Print(H.db.locked and "window locked." or "window unlocked.")
  elseif cmd == "newsession" then
    H.db.autoNew = not H.db.autoNew
    H.Print(H.db.autoNew and "a new session starts after 2 hours logged out." or "sessions only end when you press Stop.")
  else
    H.Print("/haul (show/hide), /haul start, /haul pause, /haul stop, /haul history, /haul options, /haul lock, /haul edge grey|bronze|black, /haul alpha 0-100, /haul scale 0.5-2, /haul newsession (on/off)")
  end
end

-- the module: its saved settings arrive, then the login part runs (now, or at login)
ns.Module("haul", "Rucksack_Haul", function()
  RucksackHaulDB = RucksackHaulDB or {}
end)
table.insert(ns.onLogin, function() onLogin() end)
