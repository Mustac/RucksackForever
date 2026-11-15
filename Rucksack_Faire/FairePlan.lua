-- Rucksack / Darkmoon Faire: the plan (15 Nov). You pick a prize and tick the turn-ins you want to
-- use; this works out how many times to hand each one in, how many items that is, and what you still
-- have to get: the items themselves, or the materials to make them.
local RS = Rucksack
if not RS or not RS.Faire then return end
local ns = RS.Faire
local D = ns.D

local function today() return date("%Y-%m-%d") end

---------------------------------------------------------------------------
-- What a turn-in item is made of. Your own profession window first, then the built-in list.
-- -> { makes = n, mats = { { id =, name =, n = } }, seen = true if it came from your profession window }
---------------------------------------------------------------------------
local NAME_ID -- (older saved recipes only have the material's name)
local function idForName(name)
  if not NAME_ID then
    NAME_ID = {}
    for id, n in pairs(D.ITEM_NAMES) do NAME_ID[n] = id end
  end
  return NAME_ID[name]
end
function ns.Recipe(item)
  local r = ns.db and ns.db.recipes and ns.db.recipes[item]
  local b = D.RECIPES[item]
  if r and type(r.mats) == "table" and #r.mats > 0 then
    local mats = {}
    for _, m in ipairs(r.mats) do
      local id = m.id or (m.name and idForName(m.name))
      mats[#mats + 1] = { id = id, name = m.name or (id and ns.ItemName(id)) or "?", n = m.n or 1 }
    end
    return { mats = mats, makes = r.makes or (b and b.makes) or 1, seen = true, by = r.by }
  end
  if b then
    local mats = {}
    for _, m in ipairs(b.mats) do mats[#mats + 1] = { id = m[1], name = ns.ItemName(m[1]), n = m[2] } end
    return { mats = mats, makes = b.makes or 1 }
  end
end

---------------------------------------------------------------------------
-- How many more times can this turn-in be handed in?
-- -> nil (no limit), or a number; and why: "rep" (your reputation closes it) or "npc" (not offered today)
---------------------------------------------------------------------------
function ns.RepPer() return (ns.db and tonumber(ns.db.repPer)) or D.REP_PER end
function ns.Left(t)
  if ns.char and ns.char.closed and ns.char.closed[t.q] == today() then return 0, "npc" end
  local cap = D.TIER_CAP[t.tier]
  if not cap then return nil end
  local standing, into = ns.Rep()
  if standing > cap[1] or (standing == cap[1] and into >= cap[2]) then
    if ns.OfferedNow(t.q) then return nil end -- (the NPC still offers it: our limit is wrong, so no number)
    return 0, "rep"
  end
  if standing < cap[1] then return nil end
  return math.max(1, math.ceil((cap[2] - into) / ns.RepPer())), "rep"
end
-- handed in today (from the Faire log)
function ns.DoneToday(t)
  local n, day = 0, today()
  for _, e in ipairs(ns.char and ns.char.history or {}) do
    if e.got and e.what == t.title and type(e.when) == "string" and e.when:sub(1, 10) == day then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------
-- The plan
---------------------------------------------------------------------------
function ns.PlanPick(q, on)
  ns.char.plan.picks[q] = on and true or nil
  if not on then ns.char.plan.times[q] = nil end
end
function ns.PlanSetTimes(q, n) ns.char.plan.times[q] = n and math.max(0, math.floor(n)) or nil end
function ns.PlanAuto() wipe(ns.char.plan.times) end

-- everything the Plan tab and the tracker show
-- rows: every turn-in, in the page's order: { t, st, left, why, open, picked, times, manual, tickets,
--   items, have, missing, done, recipe, crafts, mats = { { id, name, need, have } } }
function ns.PlanCalc()
  local plan = ns.char.plan
  local have = ns.Tickets()
  local goal = ns.Goal and ns.Goal()
  local need = goal and math.max(0, goal.cost - have) or 0
  local rows, picked = {}, {}
  for _, t in ipairs(ns.AllTurnins()) do
    local st = ns.TurninState(t)
    local left, why = ns.Left(t)
    local open = st.state ~= "level" and st.state ~= "rep" and left ~= 0
    local r = { t = t, st = st, left = left, why = why, open = open, picked = open and plan.picks[t.q] and true or false,
      times = 0, tickets = st.tickets, done = ns.DoneToday(t) }
    rows[#rows + 1] = r
    if r.picked then picked[#picked + 1] = r end
  end
  -- how many times each: what you typed, or by itself: the biggest ticket turn-ins first, as far as
  -- your reputation lets them go. (Every hand-in gives reputation, so a lower one's "left" is shared
  -- with everything at its level or below.)
  table.sort(picked, function(a, b)
    if a.tickets ~= b.tickets then return a.tickets > b.tickets end
    return a.t.q < b.t.q
  end)
  local used = { 0, 0, 0, 0, 0 } -- hand-ins planned, by tier
  local remaining = need
  for _, r in ipairs(picked) do
    local room -- how many this one can still take
    for k = r.t.tier, 4 do
      local cap = D.TIER_CAP[k]
      if cap and not (k == r.t.tier and r.left == nil) then
        local standing, into = ns.Rep()
        local lk = (standing == cap[1]) and math.max(0, math.ceil((cap[2] - into) / ns.RepPer())) or (standing > cap[1] and 0 or nil)
        if lk then
          local below = 0
          for j = 1, k do below = below + used[j] end
          room = math.min(room or math.huge, lk - below)
        end
      end
    end
    if r.t.tier < 5 and r.left then room = math.min(room or math.huge, r.left) end
    local manual = plan.times[r.t.q]
    local want = manual or (goal and math.ceil(math.max(0, remaining) / r.tickets)) or 1
    r.manual = manual ~= nil
    r.room = room
    r.times = math.max(0, math.min(want, room or want))
    used[r.t.tier] = used[r.t.tier] + r.times
    remaining = remaining - r.times * r.tickets
  end
  -- what each needs. What you have is shared out in the page's order, so nothing is counted twice.
  local pool = {}
  local function take(key, n)
    if pool[key] == nil then pool[key] = select(2, ns.Count(key)) or 0 end
    local got = math.min(pool[key], n)
    pool[key] = pool[key] - got
    return got
  end
  local total, mixed, lowest = 0, false, nil
  for _, r in ipairs(rows) do
    if r.picked and r.times > 0 then
      total = total + r.times * r.tickets
      if lowest and lowest ~= r.t.tier then mixed = true end
      lowest = lowest or r.t.tier
      r.items = r.times * r.st.n
      r.have = take(r.st.item, r.items)
      r.missing = r.items - r.have
      r.recipe = D.CRAFTED[r.st.item] and ns.Recipe(r.st.item) or nil
      if r.missing > 0 and r.recipe then
        r.crafts = math.ceil(r.missing / (r.recipe.makes or 1))
        r.mats = {}
        for _, m in ipairs(r.recipe.mats) do
          local n = r.crafts * m.n
          r.mats[#r.mats + 1] = { id = m.id, name = m.name, need = n, have = take(m.id or m.name, n) }
        end
      end
    end
  end
  return { goal = goal, have = have, need = need, rows = rows, total = total, after = have + total,
    short = goal and math.max(0, goal.cost - have - total) or 0, mixed = mixed, any = total > 0 }
end

---------------------------------------------------------------------------
-- The plan as lines of text (the Plan tab's right side and the tracker on screen)
---------------------------------------------------------------------------
local GOLD, GREY, GREEN, WHITE = "|cffffd100", "|cff999999", "|cff66dd66", "|cffffffff"
local function frac(have, need) return (have >= need and GREEN or WHITE) .. have .. "/" .. need .. "|r" end
function ns.PlanLines(c, short)
  local lines = {}
  for _, r in ipairs(c.rows) do
    if r.picked and r.times > 0 then
      local name = ns.ItemName(r.st.item)
      lines[#lines + 1] = (r.missing == 0 and GREEN or GOLD) .. name .. "|r  " .. frac(r.have, r.items)
        .. GREY .. (short and ("  x%d"):format(r.times) or ("  %d hand-in%s, +%d"):format(r.times, r.times == 1 and "" or "s", r.times * r.tickets)) .. "|r"
      if r.missing > 0 then
        if r.mats then
          if not short then
            lines[#lines + 1] = GREY .. ("   make %d%s:"):format(r.missing, (r.recipe.makes or 1) > 1 and (" (%d crafts)"):format(r.crafts) or "") .. "|r"
          end
          for _, m in ipairs(r.mats) do lines[#lines + 1] = "     " .. m.name .. "  " .. frac(m.have, m.need) end
        elseif not short then
          lines[#lines + 1] = GREY .. ("   %d more to find%s"):format(r.missing, D.CRAFTED[r.st.item] and (" or make (" .. D.CRAFTED[r.st.item] .. ")") or "") .. "|r"
        end
      elseif not short then
        lines[#lines + 1] = GREEN .. "   all here|r"
      end
    end
  end
  return lines
end
-- (15 Nov) the same as a table, for the card on your screen: what you ticked (with what's missing
-- under it), then anything else in your bags or bank that a turn-in takes, then the total.
-- -> rows { name, have, tk, left, indent, span }
function ns.PlanTable(c)
  local out, extra = {}, {}
  local function leftText(r) return r.left and tostring(r.left) or (GREY .. "any|r") end
  for _, r in ipairs(c.rows) do
    if r.picked and r.times > 0 then
      out[#out + 1] = { name = (r.missing == 0 and GREEN or GOLD) .. ns.ItemName(r.st.item) .. "|r", have = frac(r.have, r.items),
        tk = GOLD .. "+" .. (r.times * r.tickets) .. "|r", left = leftText(r) }
      if r.missing > 0 and r.mats then
        for _, m in ipairs(r.mats) do out[#out + 1] = { name = m.name, have = frac(m.have, m.need), indent = true } end
      end
    elseif r.open and r.st.all > 0 then
      local times = math.floor(r.st.all / r.st.n)
      extra[#extra + 1] = { name = ns.ItemName(r.st.item), have = frac(r.st.all, r.st.n * math.max(1, times)),
        tk = times > 0 and (GREEN .. "+" .. (times * r.tickets) .. "|r") or (GREY .. r.tickets .. "|r"), left = leftText(r) }
    end
  end
  if #extra > 0 then
    if #out > 0 then out[#out + 1] = { span = GREY .. "Also in your bags|r" } end
    for _, e in ipairs(extra) do out[#out + 1] = e end
  end
  local MAX = 14
  if #out > MAX then
    local more = #out - MAX + 1
    for i = #out, MAX, -1 do out[i] = nil end
    out[#out + 1] = { span = GREY .. ("...and %d more lines: see the Plan tab|r"):format(more) }
  end
  if c.any then
    local s = "With your plan: "
    if c.goal then
      s = s .. (c.short == 0 and GREEN or WHITE) .. c.after .. " / " .. c.goal.cost .. "|r" .. (c.short > 0 and (GREY .. ("  (%d short)"):format(c.short) .. "|r") or "")
    else
      s = s .. WHITE .. c.after .. " tickets|r"
    end
    out[#out + 1] = { span = s }
  end
  return out
end
-- one line: 12 now + 40 = 52 / 50
function ns.PlanSum(c)
  local s = ("%s%d|r now + %s%d|r planned = "):format(GOLD, c.have, GREEN, c.total)
  if c.goal then
    s = s .. (c.short == 0 and GREEN or WHITE) .. c.after .. " / " .. c.goal.cost .. "|r"
    if c.short > 0 then s = s .. GREY .. ("  (%d short)"):format(c.short) .. "|r" end
  else
    s = s .. WHITE .. c.after .. "|r"
  end
  return s
end
