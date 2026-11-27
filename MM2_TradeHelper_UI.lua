-- MM2TH BOOT DIAGNOSTICS WRAPPER
-- Captures runtime failures and displays them in PlayerGui when possible.
local __MM2TH_BOOT_OK, __MM2TH_BOOT_ERR = xpcall(function()
    --[[
        MM2 TRADE HELPER  ·  UI PROTOTYPE v0.1
        Standalone Luau file for executors (Arceus X / Delta). No Studio, no Rojo.
        Run:  loadstring(game:HttpGet("<raw url>"))()   or paste the file directly.
    
        WHAT IS REAL IN THIS BUILD
          * the whole shell: window, drag, minimize to floating button, sidebar, tab transitions
          * Calculator, Trade Checker math (WIN / FAIR / LOSE), Inventory / Database search + sort + filters
          * Settings: theme, accent, UI scale, transparency, animations, notifications, currency, sidebar mode
            (saved to MM2TradeHelper_config.json if the executor supports writefile)
    
        WHAT IS DEMO
          * all item values, inventory, trade history and "trade in progress" are SAMPLE DATA
          * anything not connected to game logic carries a DEMO / SAMPLE badge (can be hidden in Settings)
    
        HOW TO CONNECT REAL LOGIC LATER (no UI changes needed)
          Everything reads data through the `Bridge` table below (also exposed as getgenv().MM2TH.Bridge):
            Bridge.GetItemDB()      -> array of {name, cat, rarity, value, demand, trend, trendG, origin}
            Bridge.GetInventory()   -> array of {itemName, qty}
            Bridge.GetHistory()     -> array of {date, give={{name,qty}}, get={{name,qty}}, giveV, getV}
            Bridge.GetSample(i)     -> {theirs={{name,qty}}, mine={{name,qty}}}   (Trade Checker slot)
            Bridge.UpdateDatabase(done)  -> refresh prices, then call done(true)
          After changing data call getgenv().MM2TH.Bus.fire("values") (or "inventory") to re-render pages.
        PC: RightShift hides / shows the window.
    ]]
    
    local VERSION = "v0.1"
    
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer
    
    local genv = (getgenv and getgenv()) or _G
    if genv.MM2TH and genv.MM2TH.Destroy then pcall(genv.MM2TH.Destroy) end
    
    ------------------------------------------------------------------------ constants
    local F = { B = Enum.Font.GothamBold, M = Enum.Font.GothamMedium, R = Enum.Font.Gotham }
    local XA, YA, NA = Enum.AutomaticSize.X, Enum.AutomaticSize.Y, Enum.AutomaticSize.None
    local LEFT, CENTER, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
    local HORZ = Enum.FillDirection.Horizontal
    local AT_END = Enum.TextTruncate.AtEnd
    local WHITE = Color3.new(1, 1, 1)
    
    local function deepCopy(t)
    	local r = {}
    	for k, v in pairs(t) do r[k] = (type(v) == "table") and deepCopy(v) or v end
    	return r
    end
    
    local function merge(dst, src)
    	for k, v in pairs(src) do
    		if type(dst[k]) == type(v) then
    			if type(v) == "table" then merge(dst[k], v) else dst[k] = v end
    		end
    	end
    end
    
    local function wipe(t) for i = #t, 1, -1 do t[i] = nil end end
    
    ------------------------------------------------------------------------ settings
    local DEFAULTS = {
    	theme = "Abyss", accent = "Violet", scale = 0.9, transparency = 0,
    	animations = true, notifications = true, sidebar = "Auto",
    	currency = "Value", numFormat = "Short", system = "Pure Value", showDemo = true,
    	notifTrade = true, notifItems = true, notifResult = true,
    	showValue = true, showTrend = true, showRarity = false, showDupes = true, displayMode = "Badge",
    	warn = true, warnPct = 15, fairPct = 5, diffMode = "Both",
    	sources = { ["Supreme Value"] = true, ["MM2Values"] = false, ["Community Avg"] = false, ["Manual"] = false },
    	modules = { helper = true, checker = true, inventory = true, autoprice = false, warnings = true },
    }
    local S = deepCopy(DEFAULTS)
    
    local CONFIG = "MM2TradeHelper_config.json"
    pcall(function()
    	if isfile and readfile and isfile(CONFIG) then merge(S, HttpService:JSONDecode(readfile(CONFIG))) end
    end)
    S.scale = math.clamp(tonumber(S.scale) or 0.9, 0.78, 1.05)
    
    local saveTok = 0
    local function save()
    	if not writefile then return end
    	saveTok = saveTok + 1
    	local mine = saveTok
    	task.delay(0.6, function()
    		if mine == saveTok then pcall(function() writefile(CONFIG, HttpService:JSONEncode(S)) end) end
    	end)
    end
    
    ------------------------------------------------------------------------ palettes
    local Themes = {
    	Midnight = { bg = Color3.fromRGB(15, 19, 30), panel = Color3.fromRGB(21, 27, 41), card = Color3.fromRGB(29, 38, 56), card2 = Color3.fromRGB(39, 51, 72), stroke = Color3.fromRGB(57, 73, 99), text = Color3.fromRGB(240, 245, 255), sub = Color3.fromRGB(155, 171, 198) },
    	Obsidian = { bg = Color3.fromRGB(10, 10, 11), panel = Color3.fromRGB(15, 15, 17), card = Color3.fromRGB(22, 22, 25), card2 = Color3.fromRGB(31, 31, 35), stroke = Color3.fromRGB(46, 46, 52), text = Color3.fromRGB(238, 238, 241), sub = Color3.fromRGB(143, 143, 152) },
    	Abyss = { bg = Color3.fromRGB(13, 22, 36), panel = Color3.fromRGB(19, 31, 49), card = Color3.fromRGB(28, 44, 66), card2 = Color3.fromRGB(39, 59, 84), stroke = Color3.fromRGB(58, 82, 112), text = Color3.fromRGB(238, 247, 255), sub = Color3.fromRGB(151, 177, 205) },
    	Graphite = { bg = Color3.fromRGB(16, 14, 15), panel = Color3.fromRGB(22, 19, 21), card = Color3.fromRGB(31, 27, 30), card2 = Color3.fromRGB(41, 36, 40), stroke = Color3.fromRGB(60, 53, 58), text = Color3.fromRGB(245, 239, 241), sub = Color3.fromRGB(160, 148, 154) },
    }
    local ThemeOrder = { "Midnight", "Obsidian", "Abyss", "Graphite" }
    local Accents = {
    	Violet = Color3.fromRGB(151, 111, 255), Sky = Color3.fromRGB(64, 210, 245), Emerald = Color3.fromRGB(52, 211, 153),
    	Rose = Color3.fromRGB(251, 113, 133), Amber = Color3.fromRGB(251, 191, 36), Orchid = Color3.fromRGB(217, 70, 239),
    }
    local AccentOrder = { "Violet", "Sky", "Emerald", "Rose", "Amber", "Orchid" }
    local SEM = { good = Color3.fromRGB(74, 222, 128), warn = Color3.fromRGB(251, 191, 36), bad = Color3.fromRGB(248, 113, 113) }
    
    local function getColor(key)
    	if key == "accent" then return Accents[S.accent] or Accents.Violet end
    	if key == "accentSoft" then return getColor("accent"):Lerp(getColor("card"), 0.84) end
    	if SEM[key] then return SEM[key] end
    	return (Themes[S.theme] or Themes.Midnight)[key]
    end
    
    ------------------------------------------------------------------------ demo data  (PLACEHOLDER VALUES)
    local RAW = {
    	{ "Batwing", "Godlies", "Godly", 28 }, { "Seer", "Godlies", "Godly", 35 }, { "Luger", "Godlies", "Godly", 22 },
    	{ "Heat", "Godlies", "Godly", 26 }, { "Blossom", "Godlies", "Godly", 30 }, { "Nebula", "Godlies", "Godly", 18 },
    	{ "Eternal", "Godlies", "Godly", 60 }, { "Ice Dragon", "Godlies", "Godly", 45 }, { "Gingerblade", "Godlies", "Godly", 40 },
    	{ "Icepiercer", "Godlies", "Godly", 32 },
    	{ "Harvester", "Ancients", "Ancient", 250 }, { "Elderwood Scythe", "Ancients", "Ancient", 420 },
    	{ "Elderwood Revolver", "Ancients", "Ancient", 380 }, { "Icebreaker", "Ancients", "Ancient", 210 },
    	{ "Vampire's Edge", "Ancients", "Ancient", 160 },
    	{ "Chroma Luger", "Chromas", "Chroma", 140 }, { "Chroma Seer", "Chromas", "Chroma", 165 },
    	{ "Chroma Heat", "Chromas", "Chroma", 120 }, { "Chroma Fang", "Chromas", "Chroma", 95 },
    	{ "Chroma Lightbringer", "Chromas", "Chroma", 300 }, { "Chroma Slasher", "Chromas", "Chroma", 85 },
    	{ "Corrupt", "Vintage", "Vintage", 520 }, { "Prince", "Vintage", "Vintage", 340 },
    	{ "Flames", "Vintage", "Vintage", 270 }, { "Splitter", "Vintage", "Vintage", 190 },
    	{ "Pet Dragon", "Pets", "Legendary", 24 }, { "Pet Panda", "Pets", "Legendary", 12 },
    	{ "Pet Fox", "Pets", "Rare", 6 }, { "Pet Cat", "Pets", "Rare", 5 }, { "Pet Bunny", "Pets", "Uncommon", 2 },
    	{ "Gold Knife", "Uniques", "Unique", 75 }, { "Gem Gun", "Uniques", "Unique", 55 }, { "Candy Cane", "Uniques", "Unique", 38 },
    }
    local Cats = { "Godlies", "Ancients", "Chromas", "Vintage", "Pets", "Uniques" }
    local RarityColor = {
    	Uncommon = Color3.fromRGB(120, 200, 120), Rare = Color3.fromRGB(96, 165, 250), Legendary = Color3.fromRGB(167, 139, 250),
    	Unique = Color3.fromRGB(248, 113, 113), Godly = Color3.fromRGB(251, 146, 60), Chroma = Color3.fromRGB(34, 211, 238),
    	Ancient = Color3.fromRGB(244, 114, 182), Vintage = Color3.fromRGB(250, 204, 21),
    }
    local RarityRank = { Uncommon = 1, Rare = 2, Legendary = 3, Unique = 4, Godly = 5, Chroma = 6, Ancient = 7, Vintage = 8 }
    local Boost = { Godly = 0.04, Ancient = 0.08, Chroma = 0.06, Vintage = 0.10, Unique = 0.05 }
    local Origins = { Godlies = "Crates / trading", Ancients = "Limited events", Chromas = "Chroma crates", Vintage = "Legacy items", Pets = "Pet crates", Uniques = "Seasonal" }
    local Demand = { "Low", "Medium", "High" }
    local TrendG = { "▲", "▬", "▼" }
    local TrendT = { "rising", "stable", "falling" }
    
    local DB, DBIndex = {}, {}
    for i, r in ipairs(RAW) do
    	local it = {
    		name = r[1], cat = r[2], rarity = r[3], value = r[4],
    		demand = Demand[(i % 3) + 1], trendG = TrendG[((i * 7) % 3) + 1], trendT = TrendT[((i * 7) % 3) + 1], origin = Origins[r[2]],
    	}
    	DB[i] = it
    	DBIndex[it.name] = it
    end
    
    local DemoInventory = {
    	{ "Harvester", 1 }, { "Chroma Luger", 1 }, { "Chroma Slasher", 1 }, { "Eternal", 1 }, { "Seer", 2 }, { "Batwing", 3 },
    	{ "Heat", 1 }, { "Luger", 2 }, { "Icepiercer", 1 }, { "Ice Dragon", 1 }, { "Blossom", 1 }, { "Nebula", 2 },
    	{ "Pet Panda", 1 }, { "Pet Dragon", 1 }, { "Gold Knife", 1 },
    }
    local DemoTrades = {
    	{ theirs = { { "Chroma Seer", 1 }, { "Batwing", 2 } }, mine = { { "Harvester", 1 }, { "Heat", 1 } } },
    	{ theirs = { { "Chroma Luger", 1 }, { "Eternal", 1 }, { "Nebula", 2 } }, mine = { { "Chroma Heat", 1 }, { "Ice Dragon", 2 } } },
    	{ theirs = { { "Icebreaker", 1 }, { "Seer", 1 } }, mine = { { "Harvester", 1 } } },
    }
    local DemoHistory = {
    	{ date = "Today · 14:32", give = { { "Heat", 1 }, { "Luger", 1 } }, get = { { "Eternal", 1 } } },
    	{ date = "Today · 11:05", give = { { "Seer", 1 } }, get = { { "Batwing", 1 }, { "Nebula", 1 } } },
    	{ date = "Yesterday · 21:40", give = { { "Chroma Heat", 1 } }, get = { { "Chroma Fang", 1 } } },
    	{ date = "Yesterday · 18:12", give = { { "Ice Dragon", 1 } }, get = { { "Gingerblade", 1 } } },
    	{ date = "Mon · 20:15", give = { { "Pet Panda", 1 } }, get = { { "Pet Dragon", 1 } } },
    	{ date = "Mon · 09:48", give = { { "Batwing", 2 } }, get = { { "Chroma Slasher", 1 } } },
    	{ date = "Sun · 16:20", give = { { "Gold Knife", 1 } }, get = { { "Gem Gun", 1 }, { "Pet Cat", 1 } } },
    }
    for _, h in ipairs(DemoHistory) do -- snapshot totals at the time of the trade
    	local gv, tv = 0, 0
    	for _, e in ipairs(h.give) do gv = gv + DBIndex[e[1]].value * e[2] end
    	for _, e in ipairs(h.get) do tv = tv + DBIndex[e[1]].value * e[2] end
    	h.giveV, h.getV = gv, tv
    end
    
    local Currencies = {
    	Value = { rate = 1, pre = "", suf = " V" },
    	USD = { rate = 0.12, pre = "$", suf = "" },     -- demo rate
    	Robux = { rate = 15, pre = "", suf = " R$" },   -- demo rate
    }
    local CurrencyOrder = { "Value", "USD", "Robux" }
    local Systems = { "Pure Value", "Rarity Weighted", "Supreme Value (soon)" }
    local SourceOrder = { "Supreme Value", "MM2Values", "Community Avg", "Manual" }
    
    ------------------------------------------------------------------------ bus + bridge
    local Bus = { l = {} }
    function Bus.on(ev, fn) Bus.l[ev] = Bus.l[ev] or {}; table.insert(Bus.l[ev], fn) end
    function Bus.fire(ev)
    	for _, fn in ipairs(Bus.l[ev] or {}) do
    		local ok, e = pcall(fn)
    		if not ok then warn("[MM2TH] " .. tostring(e)) end
    	end
    end
    function Bus.clear() Bus.l = {} end
    
    local Bridge = {
    	GetItemDB = function() return DB end,
    	GetInventory = function() return DemoInventory end,
    	GetHistory = function() return DemoHistory end,
    	GetSample = function(i) return DemoTrades[i] end,
    	UpdateDatabase = function(done) -- DEMO: simulates a refresh with small random price movement
    		task.delay(1.4, function()
    			for _, it in ipairs(DB) do
    				it.value = math.max(1, math.floor(it.value * (0.95 + math.random() * 0.1) * 2 + 0.5) / 2)
    			end
    			done(true)
    		end)
    	end,
    }
    
    ------------------------------------------------------------------------ value helpers
    local function groupDigits(n)
    	local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,")
    	out = out:reverse()
    	if out:sub(1, 1) == "," then out = out:sub(2) end
    	return out
    end
    
    local function fmt(v, cur)
    	local c = Currencies[cur or S.currency] or Currencies.Value
    	local x = v * c.rate
    	local neg = x < 0
    	x = math.abs(x)
    	local s
    	if S.numFormat == "Short" and x >= 10000 then
    		s = string.format("%.1fK", x / 1000)
    	elseif x >= 100 then
    		s = groupDigits(math.floor(x + 0.5))
    	else
    		s = string.format("%.1f", x)
    		if s:sub(-2) == ".0" then s = s:sub(1, -3) end
    	end
    	return (neg and "-" or "") .. c.pre .. s .. c.suf
    end
    local function sfmt(v, cur) return ((v > 0) and "+" or "") .. fmt(v, cur) end
    
    local function unitValue(name)
    	local it = DBIndex[name]
    	if not it then return 0 end
    	local v = it.value
    	if S.system == "Rarity Weighted" then v = v * (1 + (Boost[it.rarity] or 0)) end
    	return v
    end
    local function sumList(list)
    	local t = 0
    	for _, e in ipairs(list) do t = t + unitValue(e[1]) * e[2] end
    	return t
    end
    local function mergeList(list)
    	local out, idx = {}, {}
    	for _, e in ipairs(list) do
    		if idx[e[1]] then
    			local o = out[idx[e[1]]]
    			o[2] = o[2] + e[2]
    		else
    			out[#out + 1] = { e[1], e[2] }
    			idx[e[1]] = #out
    		end
    	end
    	return out
    end
    local function names(list)
    	local t = {}
    	for _, e in ipairs(mergeList(list)) do t[#t + 1] = e[1] .. ((e[2] > 1) and (" ×" .. e[2]) or "") end
    	return table.concat(t, ", ")
    end
    
    local VColor = { WIN = "good", FAIR = "warn", LOSE = "bad" }
    local function verdict(give, get)
    	local diff = get - give
    	local base = math.max(give, get)
    	if base <= 0 then return "FAIR", 0, 0 end
    	local pct = (give > 0) and (diff / give * 100) or 100
    	if math.abs(diff) <= base * S.fairPct / 100 then return "FAIR", diff, pct end
    	return (diff > 0) and "WIN" or "LOSE", diff, pct
    end
    local function diffText(diff, pct, cur)
    	local p = string.format("%s%.1f%%", (pct > 0) and "+" or "", pct)
    	if S.diffMode == "Absolute" then return sfmt(diff, cur) end
    	if S.diffMode == "Percent" then return p end
    	return sfmt(diff, cur) .. "  (" .. p .. ")"
    end
    
    ------------------------------------------------------------------------ ui toolkit
    local U = {}
    local conns, themeHooks, demoBadges, grids, splits = {}, {}, {}, {}, {}
    local gui, win, uiScale, overlay, toastHolder, side, main
    local contentW = 480
    local Nav = {}
    
    local function connect(sig, fn)
    	local c = sig:Connect(fn)
    	conns[#conns + 1] = c
    	return c
    end
    
    local function new(class, props, parent)
    	local o = Instance.new(class)
    	if props then for k, v in pairs(props) do o[k] = v end end
    	if parent then o.Parent = parent end
    	return o
    end
    
    local function reg(inst, fn)
    	themeHooks[#themeHooks + 1] = { inst, fn }
    	fn()
    	if #themeHooks > 5000 then U.applyTheme() end -- prunes hooks of destroyed instances
    end
    local function bind(inst, prop, key)
    	reg(inst, function() inst[prop] = getColor(key) end)
    end
    function U.applyTheme()
    	local dead
    	for i, h in ipairs(themeHooks) do
    		if gui and h[1]:IsDescendantOf(gui) then
    			pcall(h[2])
    		else
    			dead = dead or {}
    			dead[#dead + 1] = i
    		end
    	end
    	if dead then for j = #dead, 1, -1 do table.remove(themeHooks, dead[j]) end end
    end
    
    local function tween(o, props, t, style, dir)
    	if not S.animations then
    		for k, v in pairs(props) do o[k] = v end
    		return
    	end
    	local tw = TweenService:Create(o, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    	tw:Play()
    	return tw
    end
    
    local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
    local function stroke(o, key, th, tr)
    	local s = new("UIStroke", { Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
    	bind(s, "Color", key or "stroke")
    	return s
    end
    local function pad(o, l, t, r, b)
    	t = t or l; r = r or l; b = b or t
    	return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b) }, o)
    end
    local function vlist(o, gap)
    	return new("UIListLayout", { Padding = UDim.new(0, gap or 8), SortOrder = Enum.SortOrder.LayoutOrder }, o)
    end
    local function hlist(o, gap)
    	return new("UIListLayout", { Padding = UDim.new(0, gap or 8), FillDirection = HORZ, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, o)
    end
    local function box(p, size, props)
    	local f = new("Frame", { Size = size or UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0 }, nil)
    	if props then for k, v in pairs(props) do f[k] = v end end
    	f.Parent = p
    	return f
    end
    local function label(p, text, size, key, font, props)
    	local o = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, Font = font or F.R, TextXAlignment = LEFT, TextWrapped = true }, nil)
    	if not (props and props.Size) then o.Size = UDim2.new(1, 0, 0, 0); o.AutomaticSize = YA end
    	if props then for k, v in pairs(props) do o[k] = v end end
    	if typeof(key) == "Color3" then o.TextColor3 = key else bind(o, "TextColor3", key or "text") end
    	o.Parent = p
    	return o
    end
    local function clear(c)
    	for _, ch in ipairs(c:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
    end
    local function rightAnchor(o)
    	o.AnchorPoint = Vector2.new(1, 0.5); o.Position = UDim2.new(1, 0, 0.5, 0)
    	return o
    end
    U.new, U.reg, U.bind, U.label, U.box, U.corner, U.stroke, U.pad, U.vlist, U.hlist, U.clear, U.tween =
    	new, reg, bind, label, box, corner, stroke, pad, vlist, hlist, clear, tween
    
    -- containers -----------------------------------------------------------------
    function U.card(p, padv)
    	local c = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BorderSizePixel = 0 }, p)
    	corner(c, 12); bind(c, "BackgroundColor3", "card"); stroke(c, "stroke", 1, 0.35)
    	pad(c, padv or 12); vlist(c, 8)
    	return c
    end
    
    function U.grid(p, minW, cellH, gap)
    	gap = gap or 8
    	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BackgroundTransparency = 1 }, p)
    	local g = new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, CellPadding = UDim2.fromOffset(gap, gap) }, f)
    	local rec = {}
    	rec.apply = function()
    		local n = math.max(1, math.floor((contentW + gap) / (minW + gap)))
    		g.CellSize = UDim2.new(1 / n, -math.ceil(gap * (n - 1) / n), 0, cellH)
    	end
    	grids[#grids + 1] = rec
    	rec.apply()
    	return f, rec
    end
    
    function U.split(p) -- two columns when wide, stacked when narrow
    	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BackgroundTransparency = 1 }, p)
    	local l = new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, f)
    	local rec = {}
    	rec.apply = function()
    		local wide = contentW >= 500
    		l.FillDirection = wide and HORZ or Enum.FillDirection.Vertical
    		for _, c in ipairs(f:GetChildren()) do
    			if c:IsA("GuiObject") then c.Size = wide and UDim2.new(0.5, -4, 0, 0) or UDim2.new(1, 0, 0, 0) end
    		end
    	end
    	splits[#splits + 1] = rec
    	return f, rec
    end
    
    function U.title(p, text, tag)
    	local h = box(p, UDim2.new(1, 0, 0, 18))
    	hlist(h, 8)
    	label(h, string.upper(text), 11, "sub", F.B, { AutomaticSize = XA, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false })
    	if tag then U.demoBadge(h, tag) end
    	return h
    end
    
    function U.row(p, title, desc, rw)
    	rw = rw or 50
    	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BackgroundTransparency = 1 }, p)
    	pad(r, 0, 3, 0, 3)
    	local left = box(r, UDim2.new(1, -(rw + 10), 0, 0), { AutomaticSize = YA })
    	vlist(left, 1)
    	label(left, title, 13, "text", F.M)
    	if desc then label(left, desc, 11, "sub", F.R) end
    	return box(r, UDim2.fromOffset(rw, 28), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
    end
    
    -- badges / buttons --------------------------------------------------------------
    function U.badge(p, text, key)
    	local f = new("Frame", { AutomaticSize = XA, Size = UDim2.fromOffset(0, 16), BorderSizePixel = 0 }, p)
    	corner(f, 8); pad(f, 7, 0, 7, 0)
    	local t = new("TextLabel", { AutomaticSize = XA, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextSize = 9, Font = F.B }, f)
    	reg(f, function()
    		local c = getColor(key or "warn")
    		f.BackgroundColor3 = c:Lerp(getColor("card"), 0.8)
    		t.TextColor3 = c
    	end)
    	return f
    end
    function U.demoBadge(p, text)
    	local b = U.badge(p, text or "DEMO", "warn")
    	demoBadges[#demoBadges + 1] = b
    	b.Visible = S.showDemo
    	return b
    end
    
    function U.button(p, text, kind, cb, size)
    	kind = kind or "ghost"
    	local b = new("TextButton", { AutoButtonColor = false, Text = text, Font = F.B, TextSize = 12, Size = size or UDim2.fromOffset(110, 32), BorderSizePixel = 0 }, p)
    	corner(b, 9)
    	local bg, hov = WHITE, WHITE
    	reg(b, function()
    		local c, t
    		if kind == "primary" then c, t = getColor("accent"), WHITE
    		elseif kind == "soft" then c, t = getColor("accentSoft"), getColor("accent")
    		elseif kind == "danger" then c, t = getColor("bad"):Lerp(getColor("card"), 0.8), getColor("bad")
    		else c, t = getColor("card2"), getColor("text") end
    		bg = c; hov = c:Lerp(WHITE, 0.09)
    		b.BackgroundColor3 = c; b.TextColor3 = t
    	end)
    	if kind == "ghost" then stroke(b, "stroke", 1) end
    	b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = hov }, 0.12) end)
    	b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = bg }, 0.12) end)
    	b.Activated:Connect(function()
    		if cb then cb(b) end
    		tween(b, { BackgroundColor3 = bg }, 0.2)
    	end)
    	return b
    end
    function U.demoButton(p, text, kind, size)
    	local b = U.button(p, text, kind, function() U.toast("Demo only — this function isn't connected yet", "warn", true) end, size)
    	local t = U.badge(b, "DEMO", "warn")
    	t.AnchorPoint = Vector2.new(1, 0.5); t.Position = UDim2.new(1, -4, 0, 0)
    	demoBadges[#demoBadges + 1] = t
    	t.Visible = S.showDemo
    	return b
    end
    
    function U.chip(p, text, active, cb)
    	local c = new("TextButton", { AutoButtonColor = false, Text = text, Font = F.M, TextSize = 11, AutomaticSize = XA, Size = UDim2.fromOffset(0, 26), BorderSizePixel = 0 }, p)
    	corner(c, 13); pad(c, 12, 0, 12, 0)
    	local st = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, c)
    	local on = active
    	local function paint()
    		c.BackgroundColor3 = on and getColor("accentSoft") or getColor("card2")
    		c.TextColor3 = on and getColor("accent") or getColor("sub")
    		st.Color = on and getColor("accent") or getColor("stroke")
    	end
    	reg(c, paint)
    	c.Activated:Connect(function() cb() end)
    	return c, function(v) on = v; paint() end
    end
    function U.chipRow(p) -- horizontally scrolling strip
    	local s = new("ScrollingFrame", {
    		Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
    		ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = XA, CanvasSize = UDim2.new(),
    	}, p)
    	hlist(s, 6)
    	return s
    end
    
    function U.search(p, placeholder, cb)
    	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BorderSizePixel = 0 }, p)
    	corner(f, 10); bind(f, "BackgroundColor3", "card2"); stroke(f, "stroke", 1)
    	local tb = new("TextBox", {
    		BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), Text = "",
    		PlaceholderText = placeholder, ClearTextOnFocus = false, Font = F.M, TextSize = 13, TextXAlignment = LEFT,
    	}, f)
    	bind(tb, "TextColor3", "text"); bind(tb, "PlaceholderColor3", "sub")
    	tb:GetPropertyChangedSignal("Text"):Connect(function() cb(tb.Text) end)
    	return f, tb
    end
    
    function U.toggle(p, init, cb)
    	local on = init
    	local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(42, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), BorderSizePixel = 0 }, p)
    	corner(b, 12)
    	local k = new("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, b)
    	corner(k, 9)
    	local function paint(anim)
    		local pos = on and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    		local col = on and getColor("accent") or getColor("stroke")
    		if anim then
    			tween(b, { BackgroundColor3 = col }, 0.18); tween(k, { Position = pos }, 0.18)
    		else
    			b.BackgroundColor3 = col; k.Position = pos
    		end
    	end
    	reg(b, function() paint(false) end)
    	b.Activated:Connect(function() on = not on; paint(true); cb(on) end)
    	return b, function(v) on = v; paint(false) end
    end
    
    function U.slider(p, min, max, init, step, cb, o)
    	o = o or {}
    	local fmtv = o.fmt or tostring
    	local val = init
    	local h = box(p, UDim2.fromOffset(o.w or 170, 24), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
    	local track = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, -50, 0, 6), BorderSizePixel = 0 }, h)
    	corner(track, 3); bind(track, "BackgroundColor3", "stroke")
    	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, track)
    	corner(fill, 3); bind(fill, "BackgroundColor3", "accent")
    	local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, track)
    	corner(knob, 7)
    	local txt = label(h, fmtv(val), 11, "text", F.M, { Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT })
    	local function visual()
    		local r = (val - min) / (max - min)
    		fill.Size = UDim2.new(r, 0, 1, 0); knob.Position = UDim2.new(r, 0, 0.5, 0); txt.Text = fmtv(val)
    	end
    	visual()
    	local dragging, active, scroller = false, nil, nil
    	local function setX(x)
    		local r = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
    		local v = math.clamp(math.floor((min + r * (max - min)) / step + 0.5) * step, min, max)
    		if v ~= val then
    			val = v; visual()
    			if not o.onEnd then cb(val) end
    		end
    	end
    	track.InputBegan:Connect(function(i)
    		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
    			dragging = true; active = i
    			scroller = p:FindFirstAncestorOfClass("ScrollingFrame")
    			if scroller then scroller.ScrollingEnabled = false end
    			setX(i.Position.X)
    		end
    	end)
    	connect(UserInputService.InputChanged, function(i)
    		if dragging and (i == active or i.UserInputType == Enum.UserInputType.MouseMovement) then setX(i.Position.X) end
    	end)
    	connect(UserInputService.InputEnded, function(i)
    		if dragging and (i == active or i.UserInputType == Enum.UserInputType.MouseButton1) then
    			dragging = false
    			if scroller then scroller.ScrollingEnabled = true end
    			if o.onEnd then cb(val) end
    		end
    	end)
    	return h
    end
    
    local openCatcher
    function U.closeDD()
    	if openCatcher then openCatcher:Destroy(); openCatcher = nil end
    end
    function U.dropdown(p, options, current, cb, width)
    	width = width or 130
    	local b = new("TextButton", { AutoButtonColor = false, Text = "", Size = UDim2.fromOffset(width, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), BorderSizePixel = 0 }, p)
    	corner(b, 8); bind(b, "BackgroundColor3", "card2"); stroke(b, "stroke", 1)
    	local txt = label(b, current, 12, "text", F.M, { Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(10, 0), TextTruncate = AT_END, TextWrapped = false })
    	label(b, "▾", 11, "sub", F.B, { Size = UDim2.fromOffset(18, 28), Position = UDim2.new(1, -20, 0, 0), TextXAlignment = CENTER })
    	local obj = {}
    	function obj.set(v) current = v; txt.Text = v end
    	b.Activated:Connect(function()
    		U.closeDD()
    		local catcher = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, overlay)
    		openCatcher = catcher
    		catcher.Activated:Connect(U.closeDD)
    		local sc = uiScale.Scale
    		local ww, wh = win.Size.X.Offset, win.Size.Y.Offset
    		local w = math.min(math.max(width, 150), ww - 12)
    		local h = math.min(#options * 28 + 8, 196)
    		local rel = (b.AbsolutePosition - win.AbsolutePosition) / sc
    		local x = math.clamp(rel.X + width - w, 6, ww - w - 6)
    		local y = rel.Y + 28 + 4
    		if y + h > wh - 6 then y = rel.Y - h - 4 end
    		y = math.max(y, 6)
    		local pop = new("ScrollingFrame", {
    			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0, ScrollBarThickness = 2,
    			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundColor3 = getColor("card2"),
    			ScrollBarImageColor3 = getColor("stroke"),
    		}, catcher)
    		corner(pop, 10); pad(pop, 4); vlist(pop, 0)
    		new("UIStroke", { Color = getColor("stroke"), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pop)
    		for _, opt in ipairs(options) do
    			local sel = (opt == current)
    			local ob = new("TextButton", {
    				Text = opt, AutoButtonColor = false, Font = sel and F.B or F.M, TextSize = 12, Size = UDim2.new(1, 0, 0, 28),
    				BorderSizePixel = 0, BackgroundTransparency = 1, TextXAlignment = LEFT, TextColor3 = sel and getColor("accent") or getColor("text"),
    			}, pop)
    			pad(ob, 10, 0, 6, 0)
    			ob.Activated:Connect(function()
    				obj.set(opt); U.closeDD(); cb(opt)
    			end)
    		end
    		if S.animations then
    			pop.Position = UDim2.fromOffset(x, y - 6)
    			tween(pop, { Position = UDim2.fromOffset(x, y) }, 0.15)
    		end
    	end)
    	obj.frame = b
    	return obj
    end
    
    -- toast -----------------------------------------------------------------------------
    function U.toast(text, kind, force)
    	if (not S.notifications and not force) or not toastHolder then return end
    	local key = (kind == "good" or kind == "bad" or kind == "warn") and kind or "accent"
    	local kids = toastHolder:GetChildren()
    	local n = 0
    	for _, k in ipairs(kids) do if k:IsA("Frame") then n = n + 1 end end
    	if n >= 3 then for _, k in ipairs(kids) do if k:IsA("Frame") then k:Destroy(); break end end end
    	local t = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BorderSizePixel = 0, BackgroundTransparency = 1 }, toastHolder)
    	corner(t, 12); pad(t, 12, 10)
    	bind(t, "BackgroundColor3", "card")
    	local st = stroke(t, key, 1, 1)
    	local l = label(t, text, 12, "text", F.M, { TextTransparency = 1 })
    	local ti = S.animations and 0.2 or 0
    	tween(t, { BackgroundTransparency = 0 }, ti); tween(st, { Transparency = 0.2 }, ti); tween(l, { TextTransparency = 0 }, ti)
    	task.delay(2.8, function()
    		if not t.Parent then return end
    		tween(t, { BackgroundTransparency = 1 }, 0.25); tween(st, { Transparency = 1 }, 0.25); tween(l, { TextTransparency = 1 }, 0.25)
    		task.delay(S.animations and 0.27 or 0, function() if t.Parent then t:Destroy() end end)
    	end)
    end
    
    -- item visuals ----------------------------------------------------------------------
    function U.monogram(p, it, size)
    	local c = RarityColor[it.rarity] or WHITE
    	local m = new("Frame", { Size = UDim2.fromOffset(size, size), BorderSizePixel = 0 }, p)
    	corner(m, math.floor(size * 0.28))
    	reg(m, function() m.BackgroundColor3 = c:Lerp(getColor("card"), 0.78) end)
    	local a, b = it.name:match("^(%a)%a*%s*(%a?)")
    	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = (a or "?") .. (b or ""), Font = F.B, TextSize = math.floor(size * 0.36), TextColor3 = c }, m)
    	return m
    end
    
    function U.itemCard(p, it, qty)
    	local c = new("Frame", { BorderSizePixel = 0 }, p)
    	corner(c, 10); bind(c, "BackgroundColor3", "card"); stroke(c, "stroke", 1, 0.35)
    	U.monogram(c, it, 44).Position = UDim2.fromOffset(10, 13)
    	label(c, it.name, 12, "text", F.B, { Size = UDim2.new(1, -74, 0, 16), Position = UDim2.fromOffset(62, 10), TextTruncate = AT_END, TextWrapped = false })
    	label(c, it.rarity .. " · " .. it.cat, 10, RarityColor[it.rarity] or WHITE, F.M, { Size = UDim2.new(1, -74, 0, 14), Position = UDim2.fromOffset(62, 28), TextTruncate = AT_END, TextWrapped = false })
    	label(c, fmt(unitValue(it.name)), 12, "accent", F.B, { Size = UDim2.new(1, -74, 0, 16), Position = UDim2.fromOffset(62, 45), TextWrapped = false })
    	if qty and qty > 1 then
    		label(c, "×" .. qty, 11, "sub", F.B, { Size = UDim2.fromOffset(34, 14), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT })
    	end
    	return c
    end
    
    function U.lineRow(p, name, qty, opt)
    	opt = opt or {}
    	local it = DBIndex[name]
    	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BorderSizePixel = 0 }, p)
    	corner(f, 9); bind(f, "BackgroundColor3", "card2")
    	if it then U.monogram(f, it, 32).Position = UDim2.fromOffset(8, 9) end
    	local u = unitValue(name)
    	label(f, name, 12, "text", F.B, { Size = UDim2.new(1, -124, 0, 16), Position = UDim2.fromOffset(48, 7), TextTruncate = AT_END, TextWrapped = false })
    	label(f, (it and it.rarity or "?") .. " · " .. fmt(u, opt.cur), 10, "sub", F.R, { Size = UDim2.new(1, -124, 0, 14), Position = UDim2.fromOffset(48, 27), TextTruncate = AT_END, TextWrapped = false })
    	label(f, fmt(u * qty, opt.cur), 12, "accent", F.B, { Size = UDim2.fromOffset(72, 16), Position = UDim2.new(1, -8, 0, 7), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT, TextWrapped = false })
    	if opt.edit then
    		local st = box(f, UDim2.fromOffset(98, 20), { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -5) })
    		hlist(st, 2)
    		U.button(st, "−", "ghost", function() opt.onQty(-1) end, UDim2.fromOffset(20, 20))
    		label(st, tostring(qty), 12, "text", F.B, { Size = UDim2.fromOffset(24, 20), TextXAlignment = CENTER })
    		U.button(st, "+", "ghost", function() opt.onQty(1) end, UDim2.fromOffset(20, 20))
    		U.button(st, "✕", "danger", function() opt.onRemove() end, UDim2.fromOffset(20, 20))
    	elseif qty > 1 then
    		label(f, "×" .. qty, 11, "sub", F.B, { Size = UDim2.fromOffset(40, 14), Position = UDim2.new(1, -8, 1, -19), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT })
    	end
    	return f
    end
    
    function U.historyRow(p, h)
    	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BorderSizePixel = 0 }, p)
    	corner(f, 10); bind(f, "BackgroundColor3", "card"); stroke(f, "stroke", 1, 0.35); pad(f, 10)
    	local profit = h.getV - h.giveV
    	local pct = (h.giveV > 0) and (profit / h.giveV * 100) or 0
    	local col = (profit > 0) and "good" or ((profit < 0) and "bad" or "warn")
    	local left = box(f, UDim2.new(1, -88, 0, 0), { AutomaticSize = YA })
    	vlist(left, 3)
    	label(left, h.date, 10, "sub", F.M)
    	label(left, "Gave  " .. names(h.give), 11, "text", F.M)
    	label(left, "Got  " .. names(h.get), 11, "text", F.M)
    	label(f, sfmt(profit), 14, col, F.B, { Size = UDim2.fromOffset(84, 18), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT, TextWrapped = false })
    	label(f, string.format("%s%.1f%%", (pct > 0) and "+" or "", pct), 10, "sub", F.M, { Size = UDim2.fromOffset(84, 14), Position = UDim2.new(1, 0, 0, 20), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT })
    	return f
    end
    
    function U.stat(p, title, glyph)
    	local c = new("Frame", { BorderSizePixel = 0 }, p)
    	corner(c, 12); bind(c, "BackgroundColor3", "card"); stroke(c, "stroke", 1, 0.35); pad(c, 12, 10)
    	label(c, title, 10, "sub", F.B, { Size = UDim2.new(1, -22, 0, 14), TextWrapped = false })
    	label(c, glyph, 13, "accent", F.B, { Size = UDim2.fromOffset(18, 14), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT })
    	local v = label(c, "-", 19, WHITE, F.B, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 22), TextTruncate = AT_END, TextWrapped = false })
    	local curKey = "text"
    	reg(v, function() v.TextColor3 = getColor(curKey) end)
    	return function(text, key)
    		v.Text = text
    		curKey = key or "text"
    		v.TextColor3 = getColor(curKey)
    	end
    end
    
    ------------------------------------------------------------------------ window / shell
    local function mount(g)
    	local cands = {
    		function() return gethui and gethui() end,
    		function() return game:GetService("CoreGui") end,
    		function() return LocalPlayer:WaitForChild("PlayerGui") end,
    	}
    	for _, f in ipairs(cands) do
    		local ok, parent = pcall(f)
    		if ok and parent then
    			local ok2 = pcall(function() g.Parent = parent end)
    			if ok2 and g.Parent == parent then return end
    		end
    	end
    end
    
    gui = new("ScreenGui", { Name = "MM2TradeHelper", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    mount(gui)
    
    win = new("Frame", { Name = "Window", Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 380), BorderSizePixel = 0 }, gui)
    corner(win, 16); bind(win, "BackgroundColor3", "panel"); stroke(win, "stroke", 1)
    uiScale = new("UIScale", { Scale = S.scale }, win)
    
    side = new("Frame", { Active = true, Size = UDim2.new(0, 148, 1, 0), BackgroundTransparency = 1 }, win)
    main = new("Frame", { Active = true, Position = UDim2.new(0, 148, 0, 6), Size = UDim2.new(1, -154, 1, -12), BorderSizePixel = 0, ClipsDescendants = true }, win)
    corner(main, 12); bind(main, "BackgroundColor3", "bg")
    
    overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50 }, win)
    
    toastHolder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(270, 0), AutomaticSize = YA, BackgroundTransparency = 1, ZIndex = 100 }, gui)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, toastHolder)
    
    -- sidebar header ------------------------------------------------------------------------
    local logo = box(side, UDim2.new(1, 0, 0, 54), { Active = true })
    local mark = new("Frame", { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), BorderSizePixel = 0 }, logo)
    corner(mark, 9); bind(mark, "BackgroundColor3", "accent")
    new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "⇄", Font = F.B, TextSize = 16, TextColor3 = WHITE }, mark)
    local logoText = label(logo, "MM2 TRADE\nHELPER", 11, "text", F.B, { Size = UDim2.new(1, -54, 1, 0), Position = UDim2.fromOffset(50, 0) })
    
    local navList = new("ScrollingFrame", {
    	Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), BackgroundTransparency = 1, BorderSizePixel = 0,
    	ScrollBarThickness = 0, AutomaticCanvasSize = YA, CanvasSize = UDim2.new(),
    }, side)
    pad(navList, 8, 2, 8, 8); vlist(navList, 4)
    
    -- top bar --------------------------------------------------------------------------------
    local topbar = new("Frame", { Active = true, Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1 }, main)
    local pageTitle = label(topbar, "", 15, "text", F.B, { Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(14, 6), TextTruncate = AT_END, TextWrapped = false })
    local pageSub = label(topbar, "", 10, "sub", F.M, { Size = UDim2.new(1, -150, 0, 14), Position = UDim2.fromOffset(14, 26), TextTruncate = AT_END, TextWrapped = false })
    local tools = box(topbar, UDim2.fromOffset(0, 28), { AutomaticSize = XA, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) })
    hlist(tools, 6)
    local protoBadge = U.badge(tools, "PROTOTYPE " .. VERSION, "accent")
    local minBtn = U.button(tools, "–", "ghost", function() end, UDim2.fromOffset(28, 28))
    local closeBtn = U.button(tools, "✕", "danger", function() end, UDim2.fromOffset(28, 28))
    
    local pagesHost = box(main, UDim2.new(1, 0, 1, -46), { Position = UDim2.fromOffset(0, 46) })
    
    -- floating button -----------------------------------------------------------------------------
    local fab = new("TextButton", {
    	Text = "⇄", Font = F.B, TextSize = 20, TextColor3 = WHITE, AutoButtonColor = false, Visible = false, BorderSizePixel = 0,
    	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 40, 0.35, 0), Size = UDim2.fromOffset(46, 46), ZIndex = 90,
    }, gui)
    corner(fab, 23); bind(fab, "BackgroundColor3", "accent"); stroke(fab, "text", 1, 0.75)
    
    ------------------------------------------------------------------------ drag + open/close
    local function clampOnScreen(target, margin)
    	local cam = workspace.CurrentCamera
    	if not cam then return end
    	local vp = cam.ViewportSize
    	local p, sz = target.AbsolutePosition, target.AbsoluteSize
    	local maxX = math.max(margin, vp.X - margin - sz.X)
    	local maxY = math.max(margin, vp.Y - margin - sz.Y)
    	local x = math.clamp(p.X, margin, maxX)
    	local y = math.clamp(p.Y, margin, maxY)
    	local dx, dy = x - p.X, y - p.Y
    	if dx ~= 0 or dy ~= 0 then target.Position = target.Position + UDim2.fromOffset(dx, dy) end
    end
    
    local function makeDraggable(handle, target, onTap)
    	-- One drag controller per handle. The window shell is moved in screen pixels;
    	-- do not attach controllers to nested title/label objects (that causes double movement).
    	local dragging, moved, startIn, startPos, active, mouseDown = false, false, nil, nil, nil, false
    	connect(handle.InputBegan, function(i)
    		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
    			dragging = true
    			moved = false
    			active = i
    			mouseDown = i.UserInputType == Enum.UserInputType.MouseButton1
    			startIn = i.Position
    			startPos = target.Position
    		end
    	end)
    	connect(UserInputService.InputChanged, function(i)
    		local isMove = (mouseDown and i.UserInputType == Enum.UserInputType.MouseMovement)
    			or (active and i == active)
    		if not dragging or not isMove then return end
    		local d = i.Position - startIn
    		if d.Magnitude > 3 then moved = true end
    		if moved then
    			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    			-- Keep the complete window visible, but allow its top edge to reach y=0.
    			clampOnScreen(target, 0)
    		end
    	end)
    	connect(UserInputService.InputEnded, function(i)
    		local ended = (active and i == active)
    			or (mouseDown and i.UserInputType == Enum.UserInputType.MouseButton1)
    			or (active and active.UserInputType == Enum.UserInputType.Touch and i.UserInputType == Enum.UserInputType.Touch)
    		if dragging and ended then
    			dragging = false
    			mouseDown = false
    			active = nil
    			if not moved and onTap then onTap() end
    		end
    	end)
    end
    
    local minimized = false
    local function setOpen(open)
    	if open then
    		minimized = false
    		fab.Visible = false
    		win.Visible = true
    		if S.animations then
    			uiScale.Scale = S.scale * 0.9
    			tween(uiScale, { Scale = S.scale }, 0.22, Enum.EasingStyle.Back)
    		end
    	else
    		U.closeDD()
    		minimized = true
    		tween(uiScale, { Scale = S.scale * 0.92 }, 0.15)
    		task.delay(S.animations and 0.15 or 0, function()
    			if not minimized then return end
    			win.Visible = false
    			uiScale.Scale = S.scale
    			fab.Visible = true
    			if S.animations then
    				fab.Size = UDim2.fromOffset(0, 0)
    				tween(fab, { Size = UDim2.fromOffset(46, 46) }, 0.25, Enum.EasingStyle.Back)
    			end
    		end)
    	end
    end
    
    -- topbar and sidebar logo are the only window drag zones; nested labels are not
    -- registered separately, preventing two or more touch handlers moving the same window.
    makeDraggable(topbar, win)
    makeDraggable(logo, win)
    makeDraggable(fab, fab, function() setOpen(true) end)
    minBtn.Activated:Connect(function() setOpen(false) end)
    connect(UserInputService.InputBegan, function(i, gp)
    	if not gp and i.KeyCode == Enum.KeyCode.RightShift then setOpen(minimized) end
    end)
    
    function U.destroy()
    	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    	wipe(conns)
    	if gui then gui:Destroy() end
    	genv.MM2TH = nil
    end
    local armed = false
    closeBtn.Activated:Connect(function()
    	if armed then U.destroy(); return end
    	armed = true
    	U.toast("Tap ✕ again to close the UI", "warn", true)
    	task.delay(2.5, function() armed = false end)
    end)
    
    ------------------------------------------------------------------------ pages
    local function mkRowsTitle(c, left, rightText)
    	local r = box(c, UDim2.new(1, 0, 0, 18))
    	label(r, left, 11, "sub", F.B, { Size = UDim2.new(0.5, 0, 1, 0), TextWrapped = false })
    	return label(r, rightText or "", 12, "accent", F.B, { Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(0.5, 0), TextXAlignment = RIGHT, TextWrapped = false })
    end
    
    local currencyDDs = {}
    local function setCurrency(v, skipSave)
    	S.currency = v
    	for _, d in ipairs(currencyDDs) do if d.frame.Parent then d.set(v) end end
    	if not skipSave then save() end
    	Bus.fire("values")
    end
    
    ------------------------------------------------ Dashboard
    local function buildDashboard(sc)
    	local card, title, row, toggle, grid = U.card, U.title, U.row, U.toggle, U.grid
    	local hero = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BackgroundColor3 = WHITE, BorderSizePixel = 0 }, sc)
    	corner(hero, 14); stroke(hero, "stroke", 1, 0.3); pad(hero, 14); vlist(hero, 6)
    	local g = new("UIGradient", { Rotation = 25 }, hero)
    	reg(hero, function() g.Color = ColorSequence.new(getColor("accent"):Lerp(getColor("card"), 0.7), getColor("card")) end)
    	local st = box(hero, UDim2.new(1, 0, 0, 16))
    	hlist(st, 6)
    	local dot = new("Frame", { Size = UDim2.fromOffset(8, 8), BackgroundColor3 = SEM.good, BorderSizePixel = 0 }, st)
    	corner(dot, 4)
    	label(st, "SYSTEM READY", 10, SEM.good, F.B, { AutomaticSize = XA, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false })
    	label(hero, "MM2 Trade Helper", 20, "text", F.B)
    	label(hero, "Interface prototype · sample data · game logic not attached yet", 11, "sub", F.M)
    	local tags = box(hero, UDim2.new(1, 0, 0, 18))
    	hlist(tags, 6)
    	U.badge(tags, "UI " .. VERSION, "accent"); U.demoBadge(tags, "SAMPLE DATA")
    
    	local gs = grid(sc, 125, 70, 8)
    	local sItems = U.stat(gs, "ITEMS", "▤")
    	local sValue = U.stat(gs, "INVENTORY VALUE", "◆")
    	local sMods = U.stat(gs, "ACTIVE MODULES", "⚙")
    	local sTrades = U.stat(gs, "RECENT TRADES", "↻")
    
    	title(sc, "Quick actions")
    	local qa = grid(sc, 130, 42, 8)
    	for _, q in ipairs({ { "⇄  Trade Checker", "Trade Checker" }, { "∑  Calculator", "Calculator" }, { "▤  Inventory", "Inventory" }, { "☰  Item Database", "Item Database" } }) do
    		U.button(qa, q[1], "soft", function() Nav.go(q[2]) end)
    	end
    
    	title(sc, "Modules", "UI ONLY")
    	local mc = card(sc, 12)
    	local mods = {
    		{ "helper", "Trade Helper overlay", "Item info and notifications in trades" },
    		{ "checker", "Trade Checker", "WIN / FAIR / LOSE evaluation" },
    		{ "inventory", "Inventory values", "Prices on your inventory items" },
    		{ "autoprice", "Auto price update", "Refresh values in background" },
    		{ "warnings", "Unfair trade warnings", "Alert when a trade is bad for you" },
    	}
    	for _, m in ipairs(mods) do
    		local r = row(mc, m[2], m[3], 50)
    		toggle(r, S.modules[m[1]], function(v) S.modules[m[1]] = v; save(); Bus.fire("modules") end)
    	end
    
    	title(sc, "Recent trades", "SAMPLE")
    	local rc = box(sc, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA })
    	vlist(rc, 6)
    
    	local function refresh()
    		local n, tot = 0, 0
    		for _, e in ipairs(Bridge.GetInventory()) do n = n + e[2]; tot = tot + unitValue(e[1]) * e[2] end
    		sItems(tostring(n)); sValue(fmt(tot))
    		local act, all = 0, 0
    		for _, v in pairs(S.modules) do all = all + 1; if v then act = act + 1 end end
    		sMods(act .. " / " .. all)
    		local hist = Bridge.GetHistory()
    		sTrades(tostring(#hist))
    		clear(rc)
    		for i = 1, math.min(3, #hist) do U.historyRow(rc, hist[i]) end
    	end
    	Bus.on("values", refresh); Bus.on("modules", refresh); Bus.on("inventory", refresh)
    	refresh()
    end
    
    ------------------------------------------------ Trade Helper
    local function buildHelper(sc)
    	local card, title, row, toggle, dropdown, slider = U.card, U.title, U.row, U.toggle, U.dropdown, U.slider
    
    	title(sc, "Live preview", "SAMPLE")
    	local pv = card(sc, 12)
    	local cap = label(pv, "", 10, "sub", F.M)
    	local ov = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BorderSizePixel = 0 }, pv)
    	corner(ov, 10); bind(ov, "BackgroundColor3", "card2"); pad(ov, 10); vlist(ov, 4)
    	label(ov, "TRADE WITH  Player123", 10, "sub", F.B)
    	local lines = {}
    	for i = 1, 3 do lines[i] = label(ov, "", 12, "text", F.M, { Size = UDim2.new(1, 0, 0, 16), TextTruncate = AT_END, TextWrapped = false }) end
    	local sum = label(ov, "", 13, SEM.warn, F.B)
    	local warnL = label(ov, "", 11, SEM.bad, F.B)
    
    	local function refresh()
    		local t = Bridge.GetSample(1)
    		cap.Text = "Style: " .. S.displayMode .. "   ·   Currency: " .. S.currency .. "   ·   Format: " .. S.numFormat
    		local m = mergeList(t.theirs)
    		for i = 1, 3 do
    			local e = m[i]
    			if e then
    				local it, s = DBIndex[e[1]], e[1]
    				if S.showDupes and e[2] > 1 then s = s .. " ×" .. e[2] end
    				if S.showRarity and it then s = s .. "  [" .. it.rarity .. "]" end
    				if S.showValue then s = s .. "  ·  " .. fmt(unitValue(e[1]) * e[2]) end
    				if S.showTrend and it then s = s .. "  " .. it.trendG end
    				lines[i].Text = s
    			else
    				lines[i].Text = ""
    			end
    		end
    		local give, get = sumList(t.mine), sumList(t.theirs)
    		local v, diff, pct = verdict(give, get)
    		sum.Text = v .. "   " .. diffText(diff, pct)
    		sum.TextColor3 = getColor(VColor[v])
    		if S.warn and v == "LOSE" and -pct >= S.warnPct then
    			warnL.Visible = true
    			warnL.Text = "⚠  Unfair trade — you lose " .. string.format("%.0f%%", -pct)
    		else
    			warnL.Visible = false
    		end
    	end
    	Bus.on("values", refresh)
    
    	local function setting(key, v) S[key] = v; save(); refresh() end
    
    	title(sc, "Notifications")
    	local c1 = card(sc, 12)
    	toggle(row(c1, "Trade requests", "Alert when someone sends a trade", 50), S.notifTrade, function(v) setting("notifTrade", v) end)
    	toggle(row(c1, "Item changes", "Alert when items are added or removed", 50), S.notifItems, function(v) setting("notifItems", v) end)
    	toggle(row(c1, "Trade result", "Alert when a trade is accepted or declined", 50), S.notifResult, function(v) setting("notifResult", v) end)
    	rightAnchor(U.button(row(c1, "Test notification", nil, 84), "Test", "soft", function() U.toast("Test notification — alerts are working", "good", true) end, UDim2.fromOffset(84, 28)))
    
    	title(sc, "Item information")
    	local c2 = card(sc, 12)
    	toggle(row(c2, "Show value", "Price next to each item", 50), S.showValue, function(v) setting("showValue", v) end)
    	toggle(row(c2, "Show trend", "Rising / stable / falling arrow", 50), S.showTrend, function(v) setting("showTrend", v) end)
    	toggle(row(c2, "Show rarity tag", nil, 50), S.showRarity, function(v) setting("showRarity", v) end)
    	toggle(row(c2, "Show duplicates", "Count of identical items", 50), S.showDupes, function(v) setting("showDupes", v) end)
    	dropdown(row(c2, "Display style", nil, 140), { "Badge", "Compact tag", "Side panel" }, S.displayMode, function(v) setting("displayMode", v) end, 140)
    
    	title(sc, "Value display")
    	local c3 = card(sc, 12)
    	local cd = dropdown(row(c3, "Currency", nil, 130), CurrencyOrder, S.currency, function(v) setCurrency(v) end, 130)
    	currencyDDs[#currencyDDs + 1] = cd
    	dropdown(row(c3, "Number format", "Short = 12.5K · Full = 12,500", 130), { "Short", "Full" }, S.numFormat, function(v) S.numFormat = v; save(); Bus.fire("values") end, 130)
    	dropdown(row(c3, "Difference", "How the gap between sides is shown", 130), { "Absolute", "Percent", "Both" }, S.diffMode, function(v) S.diffMode = v; save(); Bus.fire("values") end, 130)
    	label(c3, "Price sources", 13, "text", F.M)
    	local strip = U.chipRow(c3)
    	local setters = {}
    	for _, name in ipairs(SourceOrder) do
    		local _, set = U.chip(strip, name, S.sources[name], function()
    			local count = 0
    			for _, v in pairs(S.sources) do if v then count = count + 1 end end
    			if S.sources[name] and count <= 1 then U.toast("Keep at least one price source enabled", "warn", true); return end
    			S.sources[name] = not S.sources[name]
    			setters[name](S.sources[name]); save()
    		end)
    		setters[name] = set
    	end
    	label(c3, "Sources are labels for now — real price fetching plugs in through Bridge.", 10, "sub", F.R)
    
    	title(sc, "Warnings")
    	local c4 = card(sc, 12)
    	toggle(row(c4, "Warn on unfair trades", nil, 50), S.warn, function(v) setting("warn", v) end)
    	slider(row(c4, "Warn when losing over", nil, 170), 0, 50, S.warnPct, 1, function(v) setting("warnPct", v) end, { fmt = function(v) return v .. "%" end })
    	slider(row(c4, "Fair range ±", "Within this gap = FAIR", 170), 0, 15, S.fairPct, 1, function(v) S.fairPct = v; save(); Bus.fire("values") end, { fmt = function(v) return v .. "%" end })
    	refresh()
    end
    
    ------------------------------------------------ Trade Checker
    local function buildChecker(sc)
    	local card, title = U.card, U.title
    	local idx = 1
    	local trade = deepCopy(Bridge.GetSample(1))
    
    	local vc = card(sc, 14)
    	local top = box(vc, UDim2.new(1, 0, 0, 56))
    	local vL = label(top, "FAIR", 30, SEM.warn, F.B, { Size = UDim2.new(0.55, 0, 0, 36), TextWrapped = false })
    	local vD = label(top, "", 12, "sub", F.M, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 38), TextWrapped = false })
    	local sysDD = U.dropdown(top, Systems, S.system, function(v)
    		S.system = v; save()
    		if v:find("soon") then U.toast("Supreme Value isn't connected yet — using Pure Value", "warn", true) end
    		Bus.fire("values")
    	end, 150)
    	sysDD.frame.Position = UDim2.new(1, 0, 0, 14)
    	local tot = label(vc, "", 11, "sub", F.M)
    
    	local btns = box(sc, UDim2.new(1, 0, 0, 32))
    	hlist(btns, 8)
    	local render
    	U.button(btns, "Next sample", "soft", function()
    		idx = (idx % #DemoTrades) + 1
    		trade = deepCopy(Bridge.GetSample(idx)); render()
    	end, UDim2.fromOffset(104, 30))
    	U.button(btns, "Clear", "ghost", function() trade = { theirs = {}, mine = {} }; render() end, UDim2.fromOffset(70, 30))
    	U.demoButton(btns, "Auto-detect", "ghost", UDim2.fromOffset(104, 30))
    
    	local sp, spRec = U.split(sc)
    	local function side(titleText)
    		local c = card(sp, 12)
    		local total = mkRowsTitle(c, titleText, "")
    		local list = box(c, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA })
    		vlist(list, 5)
    		return list, total
    	end
    	local giveList, giveTot = side("YOU GIVE")
    	local getList, getTot = side("YOU GET")
    	spRec.apply()
    
    	local function fill(container, totalLbl, list)
    		clear(container)
    		local m = mergeList(list)
    		if #m == 0 then label(container, "No items", 11, "sub", F.M) end
    		for _, e in ipairs(m) do U.lineRow(container, e[1], e[2]) end
    		totalLbl.Text = fmt(sumList(list))
    	end
    	render = function()
    		fill(giveList, giveTot, trade.mine); fill(getList, getTot, trade.theirs)
    		local give, get = sumList(trade.mine), sumList(trade.theirs)
    		local v, diff, pct = verdict(give, get)
    		vL.Text = v; vL.TextColor3 = getColor(VColor[v])
    		vD.Text = diffText(diff, pct)
    		tot.Text = "Give " .. fmt(give) .. "   ·   Get " .. fmt(get) .. "   ·   " .. S.system
    	end
    	Bus.on("values", function() sysDD.set(S.system); render() end)
    
    	title(sc, "Integration point", "SLOT")
    	local slot = card(sc, 12)
    	local st = new("UIStroke", { Thickness = 1, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, slot)
    	bind(st, "Color", "accent")
    	label(slot, "Supreme Trade Checker plugs in here", 12, "text", F.B)
    	label(slot, "Feed the real trade through Bridge.GetSample(): { theirs = {{name, qty}}, mine = {{name, qty}} }, then fire Bus 'values'. Totals, duplicates and the verdict update automatically.", 11, "sub", F.R)
    	render()
    end
    
    ------------------------------------------------ Inventory
    local function buildInventory(sc)
    	local card = U.card
    	local q, cat, sort = "", "All", "Value ↓"
    
    	local sum = card(sc, 14)
    	local sTop = box(sum, UDim2.new(1, 0, 0, 44))
    	local big = label(sTop, "", 24, "text", F.B, { Size = UDim2.new(1, -96, 0, 30), TextWrapped = false })
    	local sub = label(sTop, "", 11, "sub", F.M, { Size = UDim2.new(1, -96, 0, 14), Position = UDim2.fromOffset(0, 30), TextWrapped = false })
    	rightAnchor(U.demoButton(sTop, "Refresh", "ghost", UDim2.fromOffset(84, 28)))
    
    	U.search(sc, "Search inventory…", function(t) q = t:lower(); Bus.fire("invfilter") end)
    	local srow = box(sc, UDim2.new(1, 0, 0, 28))
    	label(srow, "Sort by", 12, "sub", F.M, { Size = UDim2.new(0.5, 0, 1, 0) })
    	U.dropdown(srow, { "Value ↓", "Name A–Z", "Rarity" }, sort, function(v) sort = v; Bus.fire("invfilter") end, 130)
    
    	local strip = U.chipRow(sc)
    	local setters = {}
    	local function addChip(name)
    		local _, set = U.chip(strip, name, name == cat, function()
    			cat = name
    			for n, s in pairs(setters) do s(n == cat) end
    			Bus.fire("invfilter")
    		end)
    		setters[name] = set
    	end
    	addChip("All")
    	for _, c in ipairs(Cats) do addChip(c) end
    
    	local gridF = U.grid(sc, 150, 70, 8)
    	local function render()
    		clear(gridF)
    		local list, n, total, uniq = {}, 0, 0, 0
    		for _, e in ipairs(Bridge.GetInventory()) do
    			local it = DBIndex[e[1]]
    			n = n + e[2]; uniq = uniq + 1; total = total + unitValue(e[1]) * e[2]
    			if it and (cat == "All" or it.cat == cat) and (q == "" or it.name:lower():find(q, 1, true)) then list[#list + 1] = { it, e[2] } end
    		end
    		table.sort(list, function(a, b)
    			if sort == "Name A–Z" then return a[1].name < b[1].name end
    			if sort == "Rarity" then
    				local ra, rb = RarityRank[a[1].rarity] or 0, RarityRank[b[1].rarity] or 0
    				if ra ~= rb then return ra > rb end
    			elseif unitValue(a[1].name) ~= unitValue(b[1].name) then
    				return unitValue(a[1].name) > unitValue(b[1].name)
    			end
    			return a[1].name < b[1].name
    		end)
    		big.Text = fmt(total)
    		sub.Text = n .. " items  ·  " .. uniq .. " unique  ·  showing " .. #list
    		for _, e in ipairs(list) do U.itemCard(gridF, e[1], e[2]) end
    	end
    	Bus.on("invfilter", render); Bus.on("values", render); Bus.on("inventory", render)
    	render()
    end
    
    ------------------------------------------------ Calculator
    local function buildCalc(sc)
    	local card, title = U.card, U.title
    	local calc = { give = {}, get = {} }
    	local cur = S.currency
    
    	local rc = card(sc, 14)
    	local top = box(rc, UDim2.new(1, 0, 0, 56))
    	local vL = label(top, "FAIR", 30, SEM.warn, F.B, { Size = UDim2.new(0.55, 0, 0, 36), TextWrapped = false })
    	local vD = label(top, "", 12, "sub", F.M, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 38), TextWrapped = false })
    	local curDD = U.dropdown(top, CurrencyOrder, cur, function(v) cur = v; Bus.fire("calc") end, 110)
    	curDD.frame.Position = UDim2.new(1, 0, 0, 14)
    	local tot = label(rc, "", 11, "sub", F.M)
    
    	local btns = box(sc, UDim2.new(1, 0, 0, 32))
    	hlist(btns, 8)
    	local render
    	U.button(btns, "⇅  Swap sides", "soft", function() calc.give, calc.get = calc.get, calc.give; render() end, UDim2.fromOffset(112, 30))
    	U.button(btns, "Reset", "ghost", function() calc.give, calc.get = {}, {}; render() end, UDim2.fromOffset(70, 30))
    
    	local sp, spRec = U.split(sc)
    	local function side(titleText)
    		local c = card(sp, 12)
    		local total = mkRowsTitle(c, titleText, "")
    		local list = box(c, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA })
    		vlist(list, 5)
    		return list, total
    	end
    	local giveList, giveTot = side("YOU GIVE")
    	local getList, getTot = side("YOU GET")
    	spRec.apply()
    
    	local function fill(container, totalLbl, key)
    		clear(container)
    		local list = calc[key]
    		if #list == 0 then label(container, "Add items below", 11, "sub", F.M) end
    		for i, e in ipairs(list) do
    			U.lineRow(container, e[1], e[2], {
    				edit = true, cur = cur,
    				onQty = function(d) e[2] = e[2] + d; if e[2] < 1 then table.remove(list, i) end; render() end,
    				onRemove = function() table.remove(list, i); render() end,
    			})
    		end
    		totalLbl.Text = fmt(sumList(list), cur)
    	end
    	render = function()
    		fill(giveList, giveTot, "give"); fill(getList, getTot, "get")
    		local give, get = sumList(calc.give), sumList(calc.get)
    		local v, diff, pct = verdict(give, get)
    		vL.Text = v; vL.TextColor3 = getColor(VColor[v])
    		vD.Text = diffText(diff, pct, cur)
    		tot.Text = "Give " .. fmt(give, cur) .. "   ·   Get " .. fmt(get, cur) .. "   ·   " .. S.system
    	end
    
    	title(sc, "Add items")
    	local pk = card(sc, 12)
    	local results = box(pk, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA })
    	vlist(results, 4)
    	local query = ""
    	local function add(key, name)
    		for _, e in ipairs(calc[key]) do if e[1] == name then e[2] = e[2] + 1; render(); return end end
    		table.insert(calc[key], { name, 1 }); render()
    	end
    	local function renderPicker()
    		clear(results)
    		local found = {}
    		for _, it in ipairs(DB) do
    			if query == "" or it.name:lower():find(query, 1, true) then found[#found + 1] = it end
    		end
    		table.sort(found, function(a, b) return a.value > b.value end)
    		for i = 1, math.min(6, #found) do
    			local it = found[i]
    			local r = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0 }, results)
    			corner(r, 9); bind(r, "BackgroundColor3", "card2")
    			U.monogram(r, it, 28).Position = UDim2.fromOffset(6, 6)
    			label(r, it.name, 12, "text", F.B, { Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(40, 5), TextTruncate = AT_END, TextWrapped = false })
    			label(r, fmt(unitValue(it.name), cur), 10, "accent", F.M, { Size = UDim2.new(1, -150, 0, 14), Position = UDim2.fromOffset(40, 21), TextWrapped = false })
    			local bb = box(r, UDim2.fromOffset(100, 24), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0) })
    			hlist(bb, 4)
    			U.button(bb, "Give", "ghost", function() add("give", it.name) end, UDim2.fromOffset(48, 24))
    			U.button(bb, "Get", "soft", function() add("get", it.name) end, UDim2.fromOffset(48, 24))
    		end
    		if #found == 0 then label(results, "No matches", 11, "sub", F.M) end
    	end
    	local sb = U.search(pk, "Search item to add…", function(t) query = t:lower(); renderPicker() end)
    	sb.LayoutOrder = -1
    	renderPicker()
    	Bus.on("calc", function() renderPicker(); render() end)
    	Bus.on("values", function() renderPicker(); render() end)
    	render()
    end
    
    ------------------------------------------------ Item Database
    local function buildDatabase(sc)
    	local card = U.card
    	local q, cat = "", "All"
    
    	local hc = card(sc, 12)
    	local ht = box(hc, UDim2.new(1, 0, 0, 36))
    	local count = label(ht, "", 13, "text", F.B, { Size = UDim2.new(1, -120, 0, 18), TextWrapped = false })
    	local stamp = label(ht, "Sample data · not live", 10, "sub", F.M, { Size = UDim2.new(1, -120, 0, 14), Position = UDim2.fromOffset(0, 20), TextWrapped = false })
    	local upd = rightAnchor(U.button(ht, "Update", "primary", nil, UDim2.fromOffset(100, 30)))
    	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0 }, hc)
    	corner(bar, 2); bind(bar, "BackgroundColor3", "card2")
    	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, bar)
    	corner(fill, 2); bind(fill, "BackgroundColor3", "accent")
    	local busy = false
    	upd.Activated:Connect(function()
    		if busy then return end
    		busy = true; upd.Text = "Updating…"
    		fill.Size = UDim2.new(0, 0, 1, 0)
    		tween(fill, { Size = UDim2.new(1, 0, 1, 0) }, 1.4, Enum.EasingStyle.Sine)
    		Bridge.UpdateDatabase(function(ok)
    			busy = false; upd.Text = "Update"
    			stamp.Text = "Simulated update · just now"
    			Bus.fire("values")
    			U.toast(ok and "Database refreshed (demo prices moved slightly)" or "Update failed", ok and "good" or "bad", true)
    		end)
    	end)
    
    	U.search(sc, "Search all items…", function(t) q = t:lower(); Bus.fire("dbfilter") end)
    	local strip = U.chipRow(sc)
    	local setters = {}
    	local function addChip(name)
    		local _, set = U.chip(strip, name, name == cat, function()
    			cat = name
    			for n, s in pairs(setters) do s(n == cat) end
    			Bus.fire("dbfilter")
    		end)
    		setters[name] = set
    	end
    	addChip("All")
    	for _, c in ipairs(Cats) do addChip(c) end
    
    	local list = box(sc, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA })
    	vlist(list, 5)
    	local function render()
    		clear(list)
    		local n = 0
    		for _, it in ipairs(Bridge.GetItemDB()) do
    			if (cat == "All" or it.cat == cat) and (q == "" or it.name:lower():find(q, 1, true)) then
    				n = n + 1
    				local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = YA, BorderSizePixel = 0 }, list)
    				corner(f, 10); bind(f, "BackgroundColor3", "card"); stroke(f, "stroke", 1, 0.35); vlist(f, 0)
    				local head = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) }, f)
    				U.monogram(head, it, 32).Position = UDim2.fromOffset(8, 8)
    				label(head, it.name, 12, "text", F.B, { Size = UDim2.new(1, -140, 0, 16), Position = UDim2.fromOffset(48, 8), TextTruncate = AT_END, TextWrapped = false })
    				label(head, it.rarity .. " · " .. it.cat, 10, RarityColor[it.rarity] or WHITE, F.M, { Size = UDim2.new(1, -140, 0, 14), Position = UDim2.fromOffset(48, 26), TextTruncate = AT_END, TextWrapped = false })
    				label(head, fmt(unitValue(it.name)), 12, "accent", F.B, { Size = UDim2.fromOffset(80, 16), Position = UDim2.new(1, -26, 0, 8), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT, TextWrapped = false })
    				label(head, it.trendG .. " " .. it.trendT, 10, "sub", F.M, { Size = UDim2.fromOffset(80, 14), Position = UDim2.new(1, -26, 0, 26), AnchorPoint = Vector2.new(1, 0), TextXAlignment = RIGHT, TextWrapped = false })
    				local chev = label(head, "›", 16, "sub", F.B, { Size = UDim2.fromOffset(16, 48), Position = UDim2.new(1, -4, 0, 0), AnchorPoint = Vector2.new(1, 0), TextXAlignment = CENTER })
    				local det = box(f, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA, Visible = false })
    				pad(det, 12, 0, 12, 10); vlist(det, 2)
    				label(det, "Demand: " .. it.demand .. "   ·   Trend: " .. it.trendG .. " " .. it.trendT, 11, "sub", F.M)
    				label(det, "Obtained: " .. it.origin, 11, "sub", F.M)
    				label(det, "Base value: " .. fmt(it.value, "Value") .. "   ≈ " .. fmt(it.value, "USD") .. " / " .. fmt(it.value, "Robux"), 11, "sub", F.M)
    				head.Activated:Connect(function()
    					det.Visible = not det.Visible
    					chev.Text = det.Visible and "⌄" or "›"
    				end)
    			end
    		end
    		count.Text = n .. " items"
    		if n == 0 then label(list, "Nothing found", 12, "sub", F.M, { TextXAlignment = CENTER }) end
    	end
    	Bus.on("dbfilter", render); Bus.on("values", render)
    	render()
    end
    
    ------------------------------------------------ Trade History
    local function buildHistory(sc)
    	local card, title = U.card, U.title
    	local sg = U.grid(sc, 125, 70, 8)
    	local sPL = U.stat(sg, "NET PROFIT", "◆")
    	local sCnt = U.stat(sg, "TRADES", "↻")
    	local sWin = U.stat(sg, "WIN RATE", "▲")
    
    	local bar = U.title(sc, "Sample history", "SAMPLE")
    	U.demoButton(bar, "Export", "ghost", UDim2.fromOffset(70, 22))
    	local list = box(sc, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA })
    	vlist(list, 6)
    
    	local function render()
    		clear(list)
    		local hist = Bridge.GetHistory()
    		local pl, wins = 0, 0
    		for _, h in ipairs(hist) do
    			local p = h.getV - h.giveV
    			pl = pl + p
    			if p > 0 then wins = wins + 1 end
    			U.historyRow(list, h)
    		end
    		sPL(sfmt(pl), (pl > 0) and "good" or ((pl < 0) and "bad" or nil))
    		sCnt(tostring(#hist))
    		sWin(#hist > 0 and string.format("%d%%", math.floor(wins / #hist * 100 + 0.5)) or "–")
    	end
    	Bus.on("values", render)
    	render()
    end
    
    ------------------------------------------------ Statistics
    local function buildStats(sc)
    	local card, title = U.card, U.title
    	local sg = U.grid(sc, 125, 70, 8)
    	local sPL = U.stat(sg, "NET PROFIT", "◆")
    	local sCnt = U.stat(sg, "TRADES", "↻")
    	local sAvg = U.stat(sg, "AVG / TRADE", "∑")
    	local sBest = U.stat(sg, "BEST TRADE", "▲")
    
    	title(sc, "Inventory value · 7 days", "SAMPLE")
    	local ch = card(sc, 14)
    	local delta = label(ch, "", 12, SEM.good, F.B)
    	local area = box(ch, UDim2.new(1, 0, 0, 130))
    	local days = { "Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Today" }
    	local n = #days
    	local bars = {}
    	for i = 1, n do
    		local col = box(area, UDim2.new(1 / n, 0, 1, -16), { Position = UDim2.new((i - 1) / n, 0, 0, 0) })
    		local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0.56, 0, 0, 0), BorderSizePixel = 0 }, col)
    		corner(b, 5); bind(b, "BackgroundColor3", (i == n) and "accent" or "stroke")
    		bars[i] = b
    		label(area, days[i], 9, "sub", F.M, { Size = UDim2.new(1 / n, 0, 0, 14), Position = UDim2.new((i - 1) / n, 0, 1, -14), TextXAlignment = CENTER, TextWrapped = false })
    	end
    
    	title(sc, "Win / Fair / Lose", "SAMPLE")
    	local wc = card(sc, 12)
    	local seg = box(wc, UDim2.new(1, 0, 0, 10))
    	local segs = {}
    	for i, key in ipairs({ "good", "warn", "bad" }) do
    		local f = new("Frame", { BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = SEM[key] }, seg)
    		corner(f, 3); segs[i] = f
    	end
    	local wl = label(wc, "", 11, "sub", F.M)
    
    	title(sc, "Most valuable items")
    	local tc = card(sc, 12)
    	local tops = box(tc, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA })
    	vlist(tops, 8)
    
    	local series = { 1210, 1260, 1245, 1330, 1310, 1405, 0 }
    	local function render()
    		local hist = Bridge.GetHistory()
    		local pl, best, w, fa, lo = 0, -1e9, 0, 0, 0
    		for _, h in ipairs(hist) do
    			local p = h.getV - h.giveV
    			pl = pl + p; best = math.max(best, p)
    			local v = verdict(h.giveV, h.getV)
    			if v == "WIN" then w = w + 1 elseif v == "FAIR" then fa = fa + 1 else lo = lo + 1 end
    		end
    		sPL(sfmt(pl), (pl > 0) and "good" or ((pl < 0) and "bad" or nil))
    		sCnt(tostring(#hist)); sAvg(#hist > 0 and sfmt(pl / #hist) or "–"); sBest(sfmt(best), "good")
    		local tot = math.max(#hist, 1)
    		segs[1].Size = UDim2.new(w / tot, -2, 1, 0)
    		segs[2].Position = UDim2.new(w / tot, 0, 0, 0); segs[2].Size = UDim2.new(fa / tot, -2, 1, 0)
    		segs[3].Position = UDim2.new((w + fa) / tot, 0, 0, 0); segs[3].Size = UDim2.new(lo / tot, 0, 1, 0)
    		wl.Text = w .. " wins  ·  " .. fa .. " fair  ·  " .. lo .. " losses"
    
    		local inv, items = 0, {}
    		for _, e in ipairs(Bridge.GetInventory()) do
    			local lv = unitValue(e[1]) * e[2]
    			inv = inv + lv
    			items[#items + 1] = { e[1], lv }
    		end
    		series[n] = inv
    		local d = series[n] - series[n - 1]
    		delta.Text = ((d >= 0) and "▲ " or "▼ ") .. sfmt(d) .. " vs yesterday"
    		delta.TextColor3 = getColor((d >= 0) and "good" or "bad")
    
    		clear(tops)
    		table.sort(items, function(a, b) return a[2] > b[2] end)
    		local mx = items[1] and items[1][2] or 1
    		for i = 1, math.min(5, #items) do
    			local r = box(tops, UDim2.new(1, 0, 0, 20))
    			label(r, items[i][1], 11, "text", F.M, { Size = UDim2.new(0.36, 0, 1, 0), TextTruncate = AT_END, TextWrapped = false })
    			local tr = new("Frame", { Position = UDim2.new(0.38, 0, 0.5, -3), Size = UDim2.new(0.38, 0, 0, 6), BorderSizePixel = 0 }, r)
    			corner(tr, 3); bind(tr, "BackgroundColor3", "card2")
    			local fl = new("Frame", { Size = UDim2.new(items[i][2] / mx, 0, 1, 0), BorderSizePixel = 0 }, tr)
    			corner(fl, 3); bind(fl, "BackgroundColor3", "accent")
    			label(r, fmt(items[i][2]), 11, "accent", F.B, { Size = UDim2.new(0.22, 0, 1, 0), Position = UDim2.fromScale(0.78, 0), TextXAlignment = RIGHT, TextWrapped = false })
    		end
    	end
    	Bus.on("values", render)
    	render()
    
    	return function() -- onShow: replay bar animation
    		local lo, hi = 1e9, 0
    		for _, v in ipairs(series) do lo = math.min(lo, v); hi = math.max(hi, v) end
    		lo = lo * 0.85
    		for i, b in ipairs(bars) do
    			local target = math.clamp((series[i] - lo) / math.max(hi - lo, 1), 0.05, 1)
    			b.Size = UDim2.new(0.56, 0, 0, 0)
    			task.delay(i * 0.04, function()
    				if b.Parent then tween(b, { Size = UDim2.new(0.56, 0, target, 0) }, 0.45, Enum.EasingStyle.Quint) end
    			end)
    		end
    	end
    end
    
    ------------------------------------------------ Settings
    local function applyTransparency()
    	local t = (S.transparency or 0) / 100
    	win.BackgroundTransparency = t
    	main.BackgroundTransparency = t
    end
    
    local layout -- forward declaration
    
    local function buildSettings(sc)
    	local card, title, row, toggle, dropdown, slider = U.card, U.title, U.row, U.toggle, U.dropdown, U.slider
    
    	title(sc, "Appearance")
    	local c1 = card(sc, 12)
    	dropdown(row(c1, "Theme", nil, 130), ThemeOrder, S.theme, function(v) S.theme = v; U.applyTheme(); save() end, 130)
    	label(c1, "Accent color", 13, "text", F.M)
    	local sw = box(c1, UDim2.new(1, 0, 0, 0), { AutomaticSize = YA })
    	new("UIListLayout", { FillDirection = HORZ, Padding = UDim.new(0, 10), Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder }, sw)
    	local rings = {}
    	for _, name in ipairs(AccentOrder) do
    		local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Accents[name], BorderSizePixel = 0 }, sw)
    		corner(b, 14)
    		rings[name] = new("UIStroke", { Thickness = 2, Color = WHITE, Transparency = (S.accent == name) and 0 or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
    		b.Activated:Connect(function()
    			S.accent = name
    			for n, r in pairs(rings) do r.Transparency = (n == name) and 0 or 1 end
    			U.applyTheme(); save()
    		end)
    	end
    	slider(row(c1, "UI scale", "Applies when you release the slider", 170), 0.7, 1.25, S.scale, 0.05, function(v) S.scale = v; save(); layout() end, { onEnd = true, fmt = function(v) return string.format("%.2f×", v) end })
    	slider(row(c1, "Transparency", nil, 170), 0, 40, S.transparency, 2, function(v) S.transparency = v; save(); applyTransparency() end, { fmt = function(v) return v .. "%" end })
    	dropdown(row(c1, "Sidebar", "Auto collapses on narrow screens", 130), { "Auto", "Icons only", "Expanded" }, S.sidebar, function(v) S.sidebar = v; save(); layout() end, 130)
    
    	title(sc, "Behavior")
    	local c2 = card(sc, 12)
    	toggle(row(c2, "Animations", "Tab transitions and tweens", 50), S.animations, function(v) S.animations = v; save() end)
    	toggle(row(c2, "Notifications", "Toast messages inside the UI", 50), S.notifications, function(v) S.notifications = v; save() end)
    	toggle(row(c2, "Show DEMO badges", "Mark non-connected elements", 50), S.showDemo, function(v)
    		S.showDemo = v; save()
    		for _, b in ipairs(demoBadges) do if b.Parent then b.Visible = v end end
    	end)
    
    	title(sc, "Data")
    	local c3 = card(sc, 12)
    	local cd = dropdown(row(c3, "Default currency", nil, 130), CurrencyOrder, S.currency, function(v) setCurrency(v) end, 130)
    	currencyDDs[#currencyDDs + 1] = cd
    	dropdown(row(c3, "Valuation system", "Used by Calculator and Checker", 150), Systems, S.system, function(v) S.system = v; save(); Bus.fire("values") end, 150)
    	label(c3, "Price sources are configured in Trade Helper.", 10, "sub", F.R)
    
    	title(sc, "About")
    	local c4 = card(sc, 12)
    	label(c4, "MM2 Trade Helper · UI prototype " .. VERSION, 12, "text", F.B)
    	label(c4, "All values, inventory and history are sample data. PC: press RightShift to hide or show the window.", 11, "sub", F.R)
    	local br = box(c4, UDim2.new(1, 0, 0, 32))
    	hlist(br, 8)
    	U.button(br, "Reset settings", "ghost", function() U.resetAll() end, UDim2.fromOffset(110, 30))
    	U.button(br, "Close UI", "danger", function() U.destroy() end, UDim2.fromOffset(90, 30))
    end
    
    ------------------------------------------------------------------------ navigation
    local PageDefs = {
    	{ id = "Dashboard", icon = "▣", title = "Dashboard", sub = "Status, inventory value and quick actions", build = buildDashboard },
    	{ id = "Trade Helper", icon = "⇄", title = "Trade Helper", sub = "Alerts, item info, warnings and value display", build = buildHelper },
    	{ id = "Trade Checker", icon = "✔", title = "Trade Checker", sub = "Both sides valued · WIN / FAIR / LOSE", build = buildChecker },
    	{ id = "Inventory", icon = "▤", title = "Inventory", sub = "Your items with search, filters and prices", build = buildInventory },
    	{ id = "Calculator", icon = "∑", title = "Calculator", sub = "Build a trade manually and evaluate it", build = buildCalc },
    	{ id = "Item Database", icon = "☰", title = "Item Database", sub = "Every item with value and details", build = buildDatabase },
    	{ id = "Trade History", icon = "↻", title = "Trade History", sub = "Past trades with profit and loss", build = buildHistory },
    	{ id = "Statistics", icon = "▲", title = "Statistics", sub = "Profit, activity and value over time", build = buildStats },
    	{ id = "Settings", icon = "⚙", title = "Settings", sub = "Theme, behavior and data", build = buildSettings },
    }
    local PageByID = {}
    for _, d in ipairs(PageDefs) do PageByID[d.id] = d end
    
    local pages, current, navToken = {}, nil, 0
    local navItems, navPaints = {}, {}
    
    local function ensurePage(def)
    	if pages[def.id] then return pages[def.id] end
    	local cg = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1 }, pagesHost)
    	local sc = new("ScrollingFrame", {
    		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    		AutomaticCanvasSize = YA, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never,
    	}, cg)
    	bind(sc, "ScrollBarImageColor3", "stroke")
    	pad(sc, 12, 4, 12, 16); vlist(sc, 12)
    	local entry = { cg = cg, scroll = sc }
    	local ok, res = pcall(def.build, sc)
    	if not ok then
    		warn("[MM2TH] page '" .. def.id .. "' failed: " .. tostring(res))
    		label(sc, "This page failed to build:\n" .. tostring(res), 11, SEM.bad, F.M)
    	elseif type(res) == "function" then
    		entry.onShow = res
    	end
    	pages[def.id] = entry
    	return entry
    end
    
    function Nav.go(id)
    	local def = PageByID[id]
    	if not def then return end
    	U.closeDD()
    	local old = current and pages[current]
    	current = id
    	local e = ensurePage(def)
    	pageTitle.Text = def.title
    	pageSub.Text = def.sub
    	for _, f in ipairs(navPaints) do f() end
    	navToken = navToken + 1
    	if old and old ~= e then
    		tween(old.cg, { GroupTransparency = 1 }, 0.12)
    		task.delay(S.animations and 0.13 or 0, function()
    			if pages[current] ~= old then old.cg.Visible = false end
    		end)
    	end
    	e.scroll.CanvasPosition = Vector2.zero
    	e.cg.Visible = true
    	e.cg.GroupTransparency = S.animations and 1 or 0
    	e.cg.Position = UDim2.fromOffset(0, S.animations and 14 or 0)
    	tween(e.cg, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.22)
    	if e.onShow then pcall(e.onShow) end
    end
    
    for _, def in ipairs(PageDefs) do
    	local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 38), BorderSizePixel = 0 }, navList)
    	corner(b, 10)
    	local ind = new("Frame", { Size = UDim2.fromOffset(3, 18), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BorderSizePixel = 0 }, b)
    	corner(ind, 2)
    	local ic = new("TextLabel", { BackgroundTransparency = 1, Text = def.icon, Font = F.B, TextSize = 16, Size = UDim2.fromOffset(30, 38) }, b)
    	local nm = label(b, def.title, 12, "sub", F.M, { Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(38, 0), TextTruncate = AT_END, TextWrapped = false })
    	local function paint()
    		local a = (current == def.id)
    		b.BackgroundColor3 = getColor("accentSoft")
    		b.BackgroundTransparency = a and 0 or 1
    		local c = a and getColor("accent") or getColor("sub")
    		ic.TextColor3 = c; nm.TextColor3 = c
    		ind.BackgroundColor3 = getColor("accent"); ind.Visible = a
    	end
    	reg(b, paint)
    	navPaints[#navPaints + 1] = paint
    	navItems[#navItems + 1] = { ic = ic, nm = nm }
    	b.Activated:Connect(function() Nav.go(def.id) end)
    end
    
    ------------------------------------------------------------------------ layout
    layout = function()
    	local cam = workspace.CurrentCamera
    	local vp = cam and cam.ViewportSize or Vector2.new(900, 420)
    	local sc = S.scale
    	if not minimized then uiScale.Scale = sc end
    	local aw, ah = vp.X / sc, vp.Y / sc
    	local w, h
    	if vp.Y > vp.X then
    		w = math.min(aw * 0.97, 440); h = math.min(ah * 0.74, 640)
    	else
    		w = math.min(aw * 0.86, 700); h = math.min(ah * 0.84, 430)
    	end
    	w = math.max(math.min(w, aw - 8), 280)
    	h = math.max(math.min(h, ah - 8), 220)
    	win.Size = UDim2.fromOffset(w, h)
    	local expanded = (S.sidebar == "Expanded") or (S.sidebar == "Auto" and w >= 560)
    	local sideW = expanded and 148 or 54
    	side.Size = UDim2.new(0, sideW, 1, 0)
    	main.Position = UDim2.new(0, sideW, 0, 6)
    	main.Size = UDim2.new(1, -(sideW + 6), 1, -12)
    	contentW = w - sideW - 6 - 24
    	logoText.Visible = expanded
    	mark.AnchorPoint = expanded and Vector2.new(0, 0.5) or Vector2.new(0.5, 0.5)
    	mark.Position = expanded and UDim2.new(0, 12, 0.5, 0) or UDim2.new(0.5, 0, 0.5, 0)
    	for _, it in ipairs(navItems) do
    		it.nm.Visible = expanded
    		it.ic.AnchorPoint = expanded and Vector2.new(0, 0) or Vector2.new(0.5, 0)
    		it.ic.Position = expanded and UDim2.fromOffset(4, 0) or UDim2.new(0.5, 0, 0, 0)
    	end
    	protoBadge.Visible = w >= 540
    	for _, g in ipairs(grids) do g.apply() end
    	for _, s in ipairs(splits) do s.apply() end
    	clampOnScreen(win, 80)
    end
    
    local function applyAll()
    	U.applyTheme(); applyTransparency(); layout()
    	for _, d in ipairs(currencyDDs) do if d.frame.Parent then d.set(S.currency) end end
    end
    
    function U.resetAll()
    	U.closeDD()
    	S = deepCopy(DEFAULTS)
    	if genv.MM2TH then genv.MM2TH.State = S end
    	save()
    	for _, e in pairs(pages) do e.cg:Destroy() end
    	pages = {}
    	Bus.clear(); wipe(grids); wipe(splits); wipe(demoBadges); wipe(currencyDDs)
    	local id = current or "Dashboard"
    	current = nil
    	applyAll()
    	Nav.go(id)
    	U.toast("Settings reset to defaults", "good", true)
    end
    
    local camConn
    local function hookCamera()
    	if camConn then camConn:Disconnect() end
    	local cam = workspace.CurrentCamera
    	if cam then camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
    end
    hookCamera()
    connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function() hookCamera(); layout() end)
    
    ------------------------------------------------------------------------ start
    genv.MM2TH = { Bridge = Bridge, Bus = Bus, State = S, Notify = U.toast, Destroy = U.destroy, Version = VERSION }
    applyTransparency()
    layout()
    Nav.go("Dashboard")
    setOpen(true)
    print("[MM2 Trade Helper] UI " .. VERSION .. " loaded")
end, function(err)
    local trace = tostring(err)
    pcall(function()
        if debug and debug.traceback then trace = debug.traceback(tostring(err), 2) end
    end)
    return trace
end)

if not __MM2TH_BOOT_OK then
    local report = "[MM2TH BOOT ERROR]\n" .. tostring(__MM2TH_BOOT_ERR)
    pcall(function() warn(report) end)
    pcall(function() print(report) end)
    pcall(function()
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8)
        if not playerGui then error("PlayerGui unavailable; cannot show diagnostic panel") end
        local old = playerGui:FindFirstChild("MM2TH_BootError")
        if old then old:Destroy() end
        local sg = Instance.new("ScreenGui")
        sg.Name = "MM2TH_BootError"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 1000000
        sg.Parent = playerGui
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.88, 0, 0, 230)
        frame.Position = UDim2.new(0.06, 0, 0.5, -115)
        frame.BackgroundColor3 = Color3.fromRGB(28, 12, 18)
        frame.BorderSizePixel = 0
        frame.Parent = sg
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = frame
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 32)
        title.Position = UDim2.fromOffset(10, 8)
        title.BackgroundTransparency = 1
        title.Text = "MM2 Trade Helper — ошибка запуска"
        title.TextColor3 = Color3.fromRGB(255, 110, 130)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 15
        title.Parent = frame
        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -20, 1, -84)
        body.Position = UDim2.fromOffset(10, 44)
        body.BackgroundTransparency = 1
        body.Text = tostring(__MM2TH_BOOT_ERR)
        body.TextColor3 = Color3.fromRGB(245, 235, 238)
        body.Font = Enum.Font.Code
        body.TextSize = 12
        body.TextWrapped = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.Parent = frame
        local close = Instance.new("TextButton")
        close.Size = UDim2.new(1, -20, 0, 28)
        close.Position = UDim2.new(0, 10, 1, -36)
        close.BackgroundColor3 = Color3.fromRGB(120, 35, 55)
        close.Text = "Закрыть"
        close.TextColor3 = Color3.new(1, 1, 1)
        close.Font = Enum.Font.GothamBold
        close.TextSize = 13
        close.Parent = frame
        close.Activated:Connect(function() sg:Destroy() end)
    end)
end
