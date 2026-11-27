-- MM2 TRADE HELPER | Standalone UI Prototype
-- Menu-only test build. No trade scanning, values, inventory reads or network calls.
-- Designed for mobile executors (Arceus X / Delta) and desktop testing.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

local old = (gethui and gethui()) or CoreGui
local existing = old:FindFirstChild("MM2TradeHelper_Test")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MM2TradeHelper_Test"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parent = old
pcall(function() gui.Parent = parent end)
if not gui.Parent then
    gui.Parent = player:WaitForChild("PlayerGui")
end

local C = {
    bg = Color3.fromRGB(13, 16, 24),
    panel = Color3.fromRGB(20, 24, 35),
    panel2 = Color3.fromRGB(26, 31, 44),
    panel3 = Color3.fromRGB(32, 38, 53),
    line = Color3.fromRGB(47, 55, 73),
    text = Color3.fromRGB(239, 242, 250),
    muted = Color3.fromRGB(145, 155, 176),
    accent = Color3.fromRGB(126, 104, 255),
    accent2 = Color3.fromRGB(80, 165, 255),
    green = Color3.fromRGB(73, 203, 147),
    red = Color3.fromRGB(244, 103, 119),
    yellow = Color3.fromRGB(240, 190, 87)
}

local function make(class, props, parentObj)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parentObj
    return obj
end

local function corner(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, obj)
end

local function stroke(obj, color, transparency)
    return make("UIStroke", {
        Color = color or C.line,
        Transparency = transparency or 0,
        Thickness = 1
    }, obj)
end

local function label(parentObj, text, size, color, bold)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextSize = size or 13,
        TextColor3 = color or C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 22)
    }, parentObj)
end

local function button(parentObj, text, size, callback, primary)
    local b = make("TextButton", {
        AutoButtonColor = false,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = C.text,
        BackgroundColor3 = primary and C.accent or C.panel3,
        Size = size or UDim2.new(0, 100, 0, 34)
    }, parentObj)
    corner(b, 9)
    if not primary then stroke(b, C.line, 0.25) end
    b.MouseButton1Click:Connect(function()
        if callback then callback(b) end
    end)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundColor3 = primary and Color3.fromRGB(145, 124, 255) or C.panel2
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundColor3 = primary and C.accent or C.panel3
        }):Play()
    end)
    return b
end

local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(740, 360)
local compact = viewport.X < 560
local winW = math.max(300, math.min(620, viewport.X - 24))
local winH = math.max(260, math.min(430, viewport.Y - 24))

local main = make("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(winW, winH),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0
}, gui)
corner(main, 16)
stroke(main, C.line, 0.05)

local top = make("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0
}, main)
corner(top, 16)
make("Frame", {
    Position = UDim2.new(0, 0, 1, -14),
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0
}, top)

local brandMark = make("Frame", {
    Position = UDim2.fromOffset(15, 13),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0
}, top)
corner(brandMark, 9)
make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Text = "T",
    Font = Enum.Font.GothamBlack,
    TextSize = 17,
    TextColor3 = Color3.new(1, 1, 1)
}, brandMark)

local title = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(52, 7),
    Size = UDim2.new(0.55, 0, 0, 22),
    Text = "TRADE HELPER",
    Font = Enum.Font.GothamBlack,
    TextSize = 14,
    TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left
}, top)
local subtitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(52, 28),
    Size = UDim2.new(0.6, 0, 0, 15),
    Text = "MURDER MYSTERY 2  •  UI TEST",
    Font = Enum.Font.GothamMedium,
    TextSize = 9,
    TextColor3 = C.muted,
    TextXAlignment = Enum.TextXAlignment.Left
}, top)

local close = button(top, "×", UDim2.fromOffset(30, 30), function()
    gui:Destroy()
end, false)
close.Position = UDim2.new(1, -42, 0, 12)
close.TextSize = 20
local minimize = button(top, "—", UDim2.fromOffset(30, 30), nil, false)
minimize.Position = UDim2.new(1, -78, 0, 12)
minimize.TextSize = 16

local body = make("Frame", {
    Position = UDim2.fromOffset(0, 54),
    Size = UDim2.new(1, 0, 1, -54),
    BackgroundTransparency = 1
}, main)

local navW = compact and 94 or 142
local nav = make("Frame", {
    Size = UDim2.new(0, navW, 1, 0),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0
}, body)
make("Frame", {
    Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = C.line,
    BorderSizePixel = 0
}, nav)

local navPad = make("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8)
}, nav)
local navList = make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder
}, nav)

local content = make("Frame", {
    Position = UDim2.new(0, navW, 0, 0),
    Size = UDim2.new(1, -navW, 1, 0),
    BackgroundTransparency = 1
}, body)

local pageHost = make("Frame", {
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1
}, content)

local pages = {}
local navButtons = {}
local activePage = "Dashboard"

local function sectionHeader(parentObj, heading, desc)
    local wrap = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, desc and 52 or 30)
    }, parentObj)
    label(wrap, heading, 18, C.text, true).Size = UDim2.new(1, 0, 0, 26)
    if desc then
        local d = label(wrap, desc, 10, C.muted, false)
        d.Position = UDim2.fromOffset(0, 27)
        d.Size = UDim2.new(1, 0, 0, 18)
    end
    return wrap
end

local function card(parentObj, height)
    local f = make("Frame", {
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 82)
    }, parentObj)
    corner(f, 12)
    stroke(f, C.line, 0.35)
    return f
end

local function addPage(name, icon, order)
    local page = make("ScrollingFrame", {
        Name = name,
        Visible = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, pageHost)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 16),
        PaddingLeft = UDim.new(0, 15),
        PaddingRight = UDim.new(0, 15),
        PaddingBottom = UDim.new(0, 16)
    }, page)
    make("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, page)

    local navBtn = make("TextButton", {
        Name = name .. "Button",
        AutoButtonColor = false,
        BackgroundColor3 = C.panel,
        Text = "",
        Size = UDim2.new(1, 0, 0, 38),
        LayoutOrder = order
    }, nav)
    corner(navBtn, 9)
    local mark = make("Frame", {
        Position = UDim2.fromOffset(0, 7),
        Size = UDim2.fromOffset(3, 24),
        BackgroundColor3 = C.accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, navBtn)
    corner(mark, 3)
    local navText = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(1, -14, 1, 0),
        Text = compact and icon or (icon .. "   " .. name),
        Font = Enum.Font.GothamBold,
        TextSize = compact and 10 or 11,
        TextColor3 = C.muted,
        TextXAlignment = Enum.TextXAlignment.Left
    }, navBtn)

    navButtons[name] = {button = navBtn, mark = mark, text = navText}
    pages[name] = page
    navBtn.MouseButton1Click:Connect(function()
        for pageName, frame in pairs(pages) do
            frame.Visible = pageName == name
            local item = navButtons[pageName]
            item.button.BackgroundColor3 = pageName == name and C.panel3 or C.panel
            item.mark.BackgroundTransparency = pageName == name and 0 or 1
            item.text.TextColor3 = pageName == name and C.text or C.muted
        end
        activePage = name
    end)
    return page
end

local dashboard = addPage("Dashboard", "⌂", 1)
sectionHeader(dashboard, "Dashboard", "Your MM2 trading workspace")
local hero = card(dashboard, 104)
hero.BackgroundColor3 = Color3.fromRGB(35, 36, 68)
local heroTitle = label(hero, "MAKE EVERY TRADE COUNT", 15, C.text, true)
heroTitle.Position = UDim2.fromOffset(15, 13)
heroTitle.Size = UDim2.new(1, -30, 0, 24)
local heroDesc = label(hero, "A single place for values, trade tools and inventory.", 10, Color3.fromRGB(202, 205, 230), false)
heroDesc.Position = UDim2.fromOffset(15, 40)
heroDesc.Size = UDim2.new(1, -30, 0, 30)
local prototypeBadge = make("TextLabel", {
    Position = UDim2.fromOffset(15, 75),
    Size = UDim2.fromOffset(104, 19),
    BackgroundColor3 = Color3.fromRGB(67, 59, 126),
    Text = "MENU PROTOTYPE",
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    TextColor3 = C.text
}, hero)
corner(prototypeBadge, 6)

local statusCard = card(dashboard, 72)
local statusTitle = label(statusCard, "SYSTEM STATUS", 10, C.muted, true)
statusTitle.Position = UDim2.fromOffset(13, 9)
local statusMain = label(statusCard, "Interface loaded", 14, C.green, true)
statusMain.Position = UDim2.fromOffset(13, 28)
local statusNote = label(statusCard, "Gameplay modules are not connected in this test.", 9, C.muted, false)
statusNote.Position = UDim2.fromOffset(13, 49)

local quick = card(dashboard, 94)
label(quick, "QUICK ACCESS", 10, C.muted, true).Position = UDim2.fromOffset(13, 8)
local q1 = button(quick, "Trade Helper", UDim2.new(0.48, -5, 0, 34), function()
    navButtons["Trade Helper"].button:Activate()
    pages["Dashboard"].Visible = false
    pages["Trade Helper"].Visible = true
    activePage = "Trade Helper"
end, true)
q1.Position = UDim2.fromOffset(12, 42)
local q2 = button(quick, "Settings", UDim2.new(0.48, -5, 0, 34), function()
    pages["Dashboard"].Visible = false
    pages["Settings"].Visible = true
    for n, item in pairs(navButtons) do
        item.button.BackgroundColor3 = n == "Settings" and C.panel3 or C.panel
        item.mark.BackgroundTransparency = n == "Settings" and 0 or 1
        item.text.TextColor3 = n == "Settings" and C.text or C.muted
    end
end, false)
q2.Position = UDim2.new(0.52, 0, 0, 42)

local helper = addPage("Trade Helper", "⇄", 2)
sectionHeader(helper, "Trade Helper", "Configure how your trade workspace behaves")
local helperInfo = card(helper, 68)
label(helperInfo, "TRADE ASSISTANT", 10, C.muted, true).Position = UDim2.fromOffset(13, 8)
local helperDesc = label(helperInfo, "Trade tools will be connected after the UI test.", 11, C.text, false)
helperDesc.Position = UDim2.fromOffset(13, 29)
helperDesc.Size = UDim2.new(1, -26, 0, 28)

local function toggleRow(parentObj, titleText, description, initial)
    local row = card(parentObj, 62)
    local t = label(row, titleText, 12, C.text, true)
    t.Position = UDim2.fromOffset(13, 8)
    local d = label(row, description, 9, C.muted, false)
    d.Position = UDim2.fromOffset(13, 31)
    d.Size = UDim2.new(1, -78, 0, 20)
    local state = initial
    local switch = make("TextButton", {
        AutoButtonColor = false,
        Position = UDim2.new(1, -54, 0.5, -12),
        Size = UDim2.fromOffset(40, 24),
        BackgroundColor3 = state and C.accent or C.panel3,
        Text = "",
        BorderSizePixel = 0
    }, row)
    corner(switch, 12)
    local dot = make("Frame", {
        Position = state and UDim2.new(1, -21, 0, 3) or UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0
    }, switch)
    corner(dot, 9)
    switch.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(switch, TweenInfo.new(0.16), {
            BackgroundColor3 = state and C.accent or C.panel3
        }):Play()
        TweenService:Create(dot, TweenInfo.new(0.16), {
            Position = state and UDim2.new(1, -21, 0, 3) or UDim2.fromOffset(3, 3)
        }):Play()
    end)
    return function() return state end
end

toggleRow(helper, "Trade notifications", "Show a notice when a trade changes", true)
toggleRow(helper, "Confirm before actions", "Ask before running helper actions", true)
toggleRow(helper, "Compact item rows", "Use denser item cards in trade views", false)

local currency = addPage("Currencies", "◈", 3)
sectionHeader(currency, "Currencies", "Choose the value systems for your trades")
local currencyInfo = card(currency, 64)
label(currencyInfo, "VALUE SOURCES", 10, C.muted, true).Position = UDim2.fromOffset(13, 8)
local currencyDesc = label(currencyInfo, "Currency selection is a UI preview. No prices are loaded yet.", 10, C.text, false)
currencyDesc.Position = UDim2.fromOffset(13, 29)
currencyDesc.Size = UDim2.new(1, -26, 0, 26)
toggleRow(currency, "Supreme Values", "Primary value source (integration planned)", true)
toggleRow(currency, "Community values", "Optional secondary value source", false)
toggleRow(currency, "Show item demand", "Display demand beside item values", true)
toggleRow(currency, "Show item rarity", "Display rarity labels in item cards", true)

local calculator = addPage("Calculator", "＋", 4)
sectionHeader(calculator, "Calculator", "A clean space for quick trade math")
local calcCard = card(calculator, 154)
label(calcCard, "TRADE TOTAL PREVIEW", 10, C.muted, true).Position = UDim2.fromOffset(13, 9)
local function numberField(parentObj, placeholder, pos)
    local box = make("TextBox", {
        Position = pos,
        Size = UDim2.new(0.44, 0, 0, 34),
        BackgroundColor3 = C.panel3,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = C.muted,
        TextColor3 = C.text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        ClearTextOnFocus = false
    }, parentObj)
    corner(box, 8)
    stroke(box, C.line, 0.3)
    return box
end
local giveBox = numberField(calcCard, "You give", UDim2.fromOffset(13, 39))
local getBox = numberField(calcCard, "You get", UDim2.new(0.52, 0, 0, 39))
local result = label(calcCard, "Difference: —", 13, C.text, true)
result.Position = UDim2.fromOffset(13, 83)
local calcBtn = button(calcCard, "Calculate", UDim2.new(1, -26, 0, 32), function()
    local a, b = tonumber(giveBox.Text), tonumber(getBox.Text)
    if not a or not b then
        result.Text = "Enter two numbers first"
        result.TextColor3 = C.yellow
        return
    end
    local diff = b - a
    result.Text = string.format("Difference: %s%.2f", diff > 0 and "+" or "", diff)
    result.TextColor3 = diff > 0 and C.green or (diff < 0 and C.red or C.text)
end, true)
calcBtn.Position = UDim2.fromOffset(13, 115)

local inventory = addPage("Inventory", "▤", 5)
sectionHeader(inventory, "Inventory", "Your items will appear here")
local invCard = card(inventory, 92)
label(invCard, "INVENTORY CONNECTION", 10, C.muted, true).Position = UDim2.fromOffset(13, 10)
local invText = label(invCard, "Not connected in the standalone menu test.", 12, C.text, true)
invText.Position = UDim2.fromOffset(13, 34)
invText.Size = UDim2.new(1, -26, 0, 38)

local history = addPage("History", "◷", 6)
sectionHeader(history, "Trade History", "Review previous exchanges")
local histCard = card(history, 92)
label(histCard, "NO TRADE RECORDS", 11, C.muted, true).Position = UDim2.fromOffset(13, 12)
local histText = label(histCard, "History will populate after the trade system is integrated.", 10, C.text, false)
histText.Position = UDim2.fromOffset(13, 37)
histText.Size = UDim2.new(1, -26, 0, 36)

local settings = addPage("Settings", "⚙", 7)
sectionHeader(settings, "Settings", "Personalize the Trade Helper")
toggleRow(settings, "Remember last tab", "Restore the last opened section", true)
toggleRow(settings, "Show tooltips", "Display short hints on controls", true)
toggleRow(settings, "Reduce animations", "Use simpler transitions", false)
local themeCard = card(settings, 88)
label(themeCard, "ACCENT COLOR", 10, C.muted, true).Position = UDim2.fromOffset(13, 8)
local colors = {
    {name = "Violet", color = Color3.fromRGB(126, 104, 255)},
    {name = "Blue", color = Color3.fromRGB(80, 165, 255)},
    {name = "Green", color = Color3.fromRGB(73, 203, 147)},
    {name = "Rose", color = Color3.fromRGB(235, 105, 145)}
}
for i, item in ipairs(colors) do
    local swatch = make("TextButton", {
        AutoButtonColor = false,
        Text = "",
        Position = UDim2.fromOffset(13 + (i - 1) * 42, 38),
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = item.color
    }, themeCard)
    corner(swatch, 9)
    swatch.MouseButton1Click:Connect(function()
        C.accent = item.color
        brandMark.BackgroundColor3 = item.color
        for _, entry in pairs(navButtons) do
            entry.mark.BackgroundColor3 = item.color
        end
        calcBtn.BackgroundColor3 = item.color
        statusMain.Text = "Accent: " .. item.name
    end)
end

-- Navigation defaults and page state.
for name, frame in pairs(pages) do
    frame.Visible = name == "Dashboard"
    local item = navButtons[name]
    item.button.BackgroundColor3 = name == "Dashboard" and C.panel3 or C.panel
    item.mark.BackgroundTransparency = name == "Dashboard" and 0 or 1
    item.text.TextColor3 = name == "Dashboard" and C.text or C.muted
end

-- Dragging from the title area only, so controls remain easy to tap.
local dragging, dragInput, dragStart, startPos
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
top.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local mini = make("TextButton", {
    Visible = false,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.82),
    Size = UDim2.fromOffset(54, 54),
    BackgroundColor3 = C.accent,
    Text = "TH",
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextColor3 = C.text,
    AutoButtonColor = false
}, gui)
corner(mini, 16)
stroke(mini, C.line, 0.1)
minimize.MouseButton1Click:Connect(function()
    main.Visible = false
    mini.Visible = true
end)
mini.MouseButton1Click:Connect(function()
    mini.Visible = false
    main.Visible = true
end)

-- Keep the window inside the visible screen when orientation changes.
local function resize()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local v = cam.ViewportSize
    local w = math.max(300, math.min(620, v.X - 24))
    local h = math.max(260, math.min(430, v.Y - 24))
    main.Size = UDim2.fromOffset(w, h)
end
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
end

print("[MM2 Trade Helper] Standalone UI prototype loaded. Backend intentionally disconnected.")
