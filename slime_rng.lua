_G.MAIN_LOADED = true

-- Detect filesystem prefix: autoexec resolves from executor root, workspace resolves from workspace dir
local FS = ""
do
    local ok = pcall(readfile, "anti_afk.lua")
    if not ok then FS = "workspace/" end
end

-- ─── Load sub-scripts ─────────────────────────────────────────────────────────
local SUB_SCRIPTS = {
    "anti_afk.lua", "save_position.lua", "auto_roll.lua", "legit_roll_speed.lua", "auto_shoot.lua",
    "auto_collect.lua", "auto_return.lua", "stack_special_rolls.lua",
    "stats_tracker.lua", "zone_farmer.lua", "auto_buy_zone.lua", "auto_teleport_zone.lua",
    "auto_buy_upgrades.lua", "exploits.lua",
}
local function loadSub(name)
    local ok, data = pcall(readfile, FS .. name)
    if not ok or type(data) ~= "string" then warn("[Main] "..name..": file not found") return end
    local fn, perr = loadstring(data)
    if not fn then warn("[Main] "..name..": "..tostring(perr)) return end
    local ok2, err = pcall(fn)
    if not ok2 then warn("[Main] "..name..": "..tostring(err)) end
end
local RS = game:GetService("ReplicatedStorage")
local _t = 0
while not RS:FindFirstChild("Source") and _t < 7 do task.wait(1) _t = _t + 1 end
if not RS:FindFirstChild("Source") then warn("[Main] RS.Source never appeared, loading anyway") end

for _, name in ipairs(SUB_SCRIPTS) do loadSub(name) end
task.wait()

-- ─── Services / Player ────────────────────────────────────────────────────────
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local Players     = game:GetService("Players")
local PL = Players.LocalPlayer
while not PL do task.wait() PL = Players.LocalPlayer end

-- ─── State persistence ────────────────────────────────────────────────────────
local STATE_FILE = FS .. "slimeRNG_state.json"
local function loadState()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(STATE_FILE))
    end)
    return (ok and type(data) == "table") and data or {}
end
local function saveState(s)
    pcall(function() writefile(STATE_FILE, HttpService:JSONEncode(s)) end)
end

-- ─── Toggle definitions (Auto Return handled separately, paired with Save Pos) ─
local ROLL_DEF  = { label = "Fast Roll",    key = "autoRoll",    getApi = function() return _G.AutoRoll end,          tip = "Rolls as fast as the server allows" }
local LEGIT_DEF = { label = "Legit Roll",   key = "legitRoll",   getApi = function() return _G.LegitRollSpeed end,    tip = "Rolls at a natural pace — 1 roll per 1.4 seconds" }
local AC_DEF    = { label = "Auto Collect", key = "autoCollect", getApi = function() return _G.AutoCollect end,       tip = "Automatically collects loot from the ground" }
local TOGGLE_DEFS = {
    { label = "Auto Shoot",     key = "autoShoot",    getApi = function() return _G.AutoShoot end,          tip = "Focuses fire on the lowest HP enemy within 200 studs — switches when it dies" },
    { label = "Stack Rolls",    key = "stackRolls",   getApi = function() return _G.StackRolls end,         tip = "Pauses special rolls and syncs them to all fire at once" },
    { label = "Auto Buy Zone",     key = "autoBuyZone",     getApi = function() return _G.AutoBuyZone end,        tip = "Automatically purchases zones as coins allow" },
    { label = "Auto Tele Zone",    key = "autoTeleZone",    getApi = function() return _G.AutoTeleportZone end,   tip = "Teleports to your new max zone when it unlocks" },
    { label = "Auto Buy Upgrades", key = "autoBuyUpgrades", getApi = function() return _G.AutoBuyUpgrades end,    tip = "Buys every affordable upgrade automatically, following the dependency chain" },
}
local AR_DEF = { label = "Auto Return", key = "autoReturn", getApi = function() return _G.AutoReturn end, tip = "Teleports back to saved position when you wander too far" }

local EXPLOIT_DEFS = {
    { label = "Slime Snap",  key = "slimeSnap",  getApi = function() return _G.SlimeSnap end,  tip = "Teleports your slimes 5 studs in front of their target enemy every frame" },
    { label = "Enemy Pull",  key = "enemyPull",  getApi = function() return _G.EnemyPull end,  tip = "Arranges enemies in a square grid 10 studs ahead, 2 studs apart. Slimes immediately retarget when an enemy dies" },
    { label = "Walk Speed",  key = "walkSpeed",  getApi = function() return _G.WalkSpeed end,  tip = "Sets WalkSpeed to 50 — re-applies on respawn" },
}

local savedState = loadState()

for _, def in ipairs(TOGGLE_DEFS) do
    if savedState[def.key] then
        local api = def.getApi()
        if api then pcall(function() api.enable() end) end
    end
end
if savedState[AR_DEF.key] then
    local api = AR_DEF.getApi()
    if api then pcall(function() api.enable() end) end
end
for _, def in ipairs({ROLL_DEF, LEGIT_DEF, AC_DEF}) do
    if savedState[def.key] then
        local api = def.getApi()
        if api then pcall(function() api.enable() end) end
    end
end
for _, def in ipairs(EXPLOIT_DEFS) do
    if savedState[def.key] then
        local api = def.getApi()
        if api then pcall(function() api.enable() end) end
    end
end

-- ─── Utilities ────────────────────────────────────────────────────────────────
local SFX = {"K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc"}
local function fmt(n)
    if n < 1000 then return tostring(math.floor(n)) end
    local v, i = n, 0
    while v >= 1000 and i < #SFX do v = v/1000 i = i+1 end
    return string.format("%.3f%s", v, SFX[i])
end
local function fmtTime(s)
    local h = math.floor(s/3600)
    local m = math.floor(s/60) % 60
    local sc = math.floor(s) % 60
    return h > 0 and string.format("%d:%02d:%02d",h,m,sc) or string.format("%d:%02d",m,sc)
end

-- ─── Layout constants ─────────────────────────────────────────────────────────
local W        = 299
local LBL_W    = 44
local VAL_W    = 104
local ROW_H    = 26
local SCROLL_H = 160
local TAB_W    = math.floor(W / 4)
local HALF_W   = 141   -- for 2-col rows: (299 - 6 - 5 - 6) / 2, each col 141px

local SX = {
    lbl1 = 0,
    val1 = LBL_W + 1,
    lbl2 = LBL_W + 1 + VAL_W + 1,
    val2 = LBL_W + 1 + VAL_W + 1 + LBL_W + 1,
}

-- ─── Theme: Black / Purple / Red ──────────────────────────────────────────────
local C_BG          = Color3.fromRGB(8,  3,  18)     -- deep black-purple
local C_BG2         = Color3.fromRGB(22, 6,  42)     -- panel gradient end
local C_TITLE       = Color3.fromRGB(32, 10, 58)     -- title top
local C_TITLE2      = Color3.fromRGB(14, 4,  28)     -- title gradient end
local C_TABS        = Color3.fromRGB(12, 4,  24)
local C_DIV         = Color3.fromRGB(75, 22, 115)    -- purple divider
local C_TAB_ON      = Color3.fromRGB(55, 18, 90)
local C_TAB_OFF     = Color3.fromRGB(16, 5,  30)
local C_TXT_ON      = Color3.new(1, 1, 1)
local C_TXT_OFF     = Color3.fromRGB(235, 205, 255)
local C_BTN_ON      = Color3.fromRGB(85,  15, 140)  -- ON: solid purple
local C_BTN_OFF     = Color3.fromRGB(90,  10, 10)   -- OFF: solid dark red
local C_BTXT_ON     = Color3.fromRGB(55,  185, 85)  -- ON text: green
local C_BTXT_OFF    = Color3.fromRGB(205, 85,  85)  -- OFF text: red
local C_STROKE      = Color3.fromRGB(105, 32, 160)  -- panel border
local C_BSTR_ON     = Color3.fromRGB(130, 60, 200)  -- ON button border: purple
local C_BSTR_OFF    = Color3.fromRGB(180, 30, 30)   -- OFF button border: red
local C_POS_BASE    = Color3.fromRGB(40,  12, 95)   -- position group base
local C_POS_BASE2   = Color3.fromRGB(75,  20, 145)  -- position group accent
local C_POS_TXT     = Color3.new(1, 1, 1)
local C_ZF_BASE     = Color3.fromRGB(80,  15, 30)   -- zone farmer: red-black
local C_ZF_BASE2    = Color3.fromRGB(140, 22, 58)   -- zone farmer accent
local C_ZF_TXT      = Color3.new(1, 1, 1)

-- ─── Style helpers ────────────────────────────────────────────────────────────
local function mkGrad(parent, c1, c2, rot)
    local g = Instance.new("UIGradient", parent)
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot or 90
    return g
end
local function mkStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end
local function mkGloss(parent)
    local g = Instance.new("UIGradient", parent)
    g.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    0.80),
        NumberSequenceKeypoint.new(0.45, 0.93),
        NumberSequenceKeypoint.new(1,    0.98),
    })
    g.Rotation = 90
end

-- ─── Root ScreenGui ───────────────────────────────────────────────────────────
local g = Instance.new("ScreenGui")
g.ResetOnSpawn = false
g.Name = "SlimeRNGMain"
g.IgnoreGuiInset = true
g.Parent = PL.PlayerGui

-- ─── Panel ────────────────────────────────────────────────────────────────────
local panel = Instance.new("Frame", g)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

-- panelBg: first child so it renders behind all siblings
local panelBg = Instance.new("Frame", panel)
panelBg.Size = UDim2.new(1, 0, 1, 0)
panelBg.BackgroundColor3 = C_BG
panelBg.BorderSizePixel = 0
Instance.new("UICorner", panelBg).CornerRadius = UDim.new(0, 8)
mkGrad(panelBg, C_BG, C_BG2, 120)
mkStroke(panelBg, C_STROKE, 1.5, 0)

if savedState.guiX and workspace.CurrentCamera then
    local vp = workspace.CurrentCamera.ViewportSize
    local clampedX = math.clamp(savedState.guiX, 0, math.max(0, vp.X - W))
    local clampedY = math.clamp(savedState.guiY, 0, math.max(0, vp.Y - 50))
    panel.Position = UDim2.new(0, clampedX, 0, clampedY)
else
    panel.Position = UDim2.new(0.5, -math.floor(W/2), 0, 12)
end

-- ─── Bubble (pfp, top-right alongside Roblox UI buttons) ──────────────────────
local pfpImage = ""
if getcustomasset then
    local ok, url = pcall(getcustomasset, "pfp_bg7_p03_scarlet.png")
    if ok then pfpImage = url end
end

local bubble = Instance.new("ImageButton", g)
bubble.Size = UDim2.new(0, 44, 0, 44)
bubble.Position = UDim2.new(1, -57, 0, 64)
bubble.BackgroundTransparency = 1
bubble.BorderSizePixel = 0
bubble.Image = pfpImage
bubble.Visible = false
Instance.new("UICorner", bubble).CornerRadius = UDim.new(0.5, 0)
mkStroke(bubble, C_STROKE, 2, 0.15)
bubble.MouseButton1Click:Connect(function()
    bubble.Visible = false
    panel.Visible = true
end)

-- ─── Tooltip ──────────────────────────────────────────────────────────────────
local ttFrame = Instance.new("Frame", g)
ttFrame.BackgroundColor3 = Color3.fromRGB(14, 4, 28)
ttFrame.BorderSizePixel = 0
ttFrame.AutomaticSize = Enum.AutomaticSize.XY
ttFrame.Visible = false
ttFrame.ZIndex = 20
Instance.new("UICorner", ttFrame).CornerRadius = UDim.new(0, 5)
mkStroke(ttFrame, C_DIV, 1, 0.3)
local ttPad = Instance.new("UIPadding", ttFrame)
ttPad.PaddingTop = UDim.new(0, 4) ttPad.PaddingBottom = UDim.new(0, 4)
ttPad.PaddingLeft = UDim.new(0, 8) ttPad.PaddingRight = UDim.new(0, 8)
local ttLbl = Instance.new("TextLabel", ttFrame)
ttLbl.BackgroundTransparency = 1
ttLbl.TextColor3 = Color3.fromRGB(215, 190, 255)
ttLbl.TextSize = 10
ttLbl.Font = Enum.Font.Gotham
ttLbl.AutomaticSize = Enum.AutomaticSize.XY
ttLbl.TextStrokeTransparency = 1
ttLbl.ZIndex = 20

local function setTooltip(btn, text)
    if not text or text == "" then return end
    btn.MouseEnter:Connect(function()
        ttLbl.Text = text
        local ap = btn.AbsolutePosition
        local as = btn.AbsoluteSize
        local vp = workspace.CurrentCamera.ViewportSize
        local tx = math.clamp(ap.X, 4, vp.X - 185)
        local ty = ap.Y + as.Y + 4
        if ty + 30 > vp.Y then ty = ap.Y - 34 end
        ttFrame.Position = UDim2.new(0, tx, 0, ty)
        ttFrame.Visible = true
    end)
    btn.MouseLeave:Connect(function() ttFrame.Visible = false end)
end

-- ─── Title bar ────────────────────────────────────────────────────────────────
local titleBar = Instance.new("Frame", panel)
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = C_TITLE
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
mkGrad(titleBar, C_TITLE, C_TITLE2, 135)

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1, -74, 1, 0)
titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = Color3.new(1, 1, 1)
titleLbl.TextStrokeTransparency = 1
titleLbl.Text = "Lxcifer Scripts"
titleLbl.TextSize = 13
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size = UDim2.new(0, 28, 0, 24)
minBtn.Position = UDim2.new(1, -64, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(38, 12, 65)
minBtn.TextColor3 = Color3.fromRGB(235, 210, 255)
minBtn.Text = "-"
minBtn.TextSize = 18
minBtn.Font = Enum.Font.GothamBold
minBtn.BorderSizePixel = 0
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)
mkStroke(minBtn, C_DIV, 1, 0.25)
minBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
    bubble.Visible = true
end)
setTooltip(minBtn, "Minimize to bubble icon")

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 28, 0, 24)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(140, 18, 35)
closeBtn.TextColor3 = Color3.fromRGB(255, 155, 165)
closeBtn.Text = "X"
closeBtn.TextSize = 13
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
mkGrad(closeBtn, Color3.fromRGB(160, 22, 45), Color3.fromRGB(95, 8, 75), 90)
mkStroke(closeBtn, Color3.fromRGB(225, 55, 80), 1, 0.15)
closeBtn.MouseButton1Click:Connect(function()
    for _, def in ipairs(TOGGLE_DEFS) do
        local api = def.getApi()
        if api then pcall(function() api.disable() end) end
    end
    for _, def in ipairs({AR_DEF, ROLL_DEF, LEGIT_DEF, AC_DEF}) do
        local api = def.getApi()
        if api then pcall(function() api.disable() end) end
    end
    for _, def in ipairs(EXPLOIT_DEFS) do
        local api = def.getApi()
        if api then pcall(function() api.disable() end) end
    end
    g:Destroy()
    _G.SlimeRNGMain = nil
end)
setTooltip(closeBtn, "Close panel and disable all active scripts")

-- ─── Drag ─────────────────────────────────────────────────────────────────────
local dragging = false
local dragStart, panStart
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        panStart  = panel.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local d = input.Position - dragStart
    panel.Position = UDim2.new(panStart.X.Scale, panStart.X.Offset + d.X, panStart.Y.Scale, panStart.Y.Offset + d.Y)
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if dragging then
            dragging = false
            local ap = panel.AbsolutePosition
            local state = loadState()
            state.guiX = ap.X
            state.guiY = ap.Y
            saveState(state)
        end
    end
end)

-- ─── Tab bar ──────────────────────────────────────────────────────────────────
local tabBar = Instance.new("Frame", panel)
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.Position = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = C_TABS
tabBar.BorderSizePixel = 0
mkGrad(tabBar, Color3.fromRGB(14, 5, 28), Color3.fromRGB(10, 3, 20), 90)

local tabControls = Instance.new("TextButton", tabBar)
tabControls.Size = UDim2.new(0, TAB_W, 1, 0)
tabControls.BackgroundColor3 = C_TAB_ON
tabControls.TextColor3 = C_TXT_ON
tabControls.Text = "Controls"
tabControls.TextSize = 12
tabControls.Font = Enum.Font.GothamBold
tabControls.BorderSizePixel = 0
Instance.new("UICorner", tabControls).CornerRadius = UDim.new(0, 5)

local tabStats = Instance.new("TextButton", tabBar)
tabStats.Size = UDim2.new(0, TAB_W, 1, 0)
tabStats.Position = UDim2.new(0, TAB_W, 0, 0)
tabStats.BackgroundColor3 = C_TAB_OFF
tabStats.TextColor3 = C_TXT_OFF
tabStats.Text = "Stats"
tabStats.TextSize = 12
tabStats.Font = Enum.Font.GothamBold
tabStats.BorderSizePixel = 0
Instance.new("UICorner", tabStats).CornerRadius = UDim.new(0, 5)

local tabCollect = Instance.new("TextButton", tabBar)
tabCollect.Size = UDim2.new(0, TAB_W, 1, 0)
tabCollect.Position = UDim2.new(0, TAB_W * 2, 0, 0)
tabCollect.BackgroundColor3 = C_TAB_OFF
tabCollect.TextColor3 = C_TXT_OFF
tabCollect.Text = "Collect"
tabCollect.TextSize = 12
tabCollect.Font = Enum.Font.GothamBold
tabCollect.BorderSizePixel = 0
Instance.new("UICorner", tabCollect).CornerRadius = UDim.new(0, 5)

local tabExploits = Instance.new("TextButton", tabBar)
tabExploits.Size = UDim2.new(0, W - TAB_W * 3, 1, 0)
tabExploits.Position = UDim2.new(0, TAB_W * 3, 0, 0)
tabExploits.BackgroundColor3 = C_TAB_OFF
tabExploits.TextColor3 = C_TXT_OFF
tabExploits.Text = "Exploits"
tabExploits.TextSize = 12
tabExploits.Font = Enum.Font.GothamBold
tabExploits.BorderSizePixel = 0
Instance.new("UICorner", tabExploits).CornerRadius = UDim.new(0, 5)

local tabDiv = Instance.new("Frame", panel)
tabDiv.Size = UDim2.new(1, 0, 0, 1)
tabDiv.Position = UDim2.new(0, 0, 0, 60)
tabDiv.BackgroundColor3 = C_DIV
tabDiv.BorderSizePixel = 0
mkGrad(tabDiv, C_DIV, Color3.fromRGB(150, 20, 55), 0)

-- ─── Content frames ───────────────────────────────────────────────────────────
local controlsFrame = Instance.new("Frame", panel)
controlsFrame.Position = UDim2.new(0, 0, 0, 61)
controlsFrame.BackgroundTransparency = 1
controlsFrame.BorderSizePixel = 0

local statsFrame = Instance.new("Frame", panel)
statsFrame.Position = UDim2.new(0, 0, 0, 61)
statsFrame.BackgroundTransparency = 1
statsFrame.BorderSizePixel = 0
statsFrame.Visible = false

local collectFrame = Instance.new("Frame", panel)
collectFrame.Position = UDim2.new(0, 0, 0, 61)
collectFrame.BackgroundTransparency = 1
collectFrame.BorderSizePixel = 0
collectFrame.Visible = false

local exploitsFrame = Instance.new("Frame", panel)
exploitsFrame.Position = UDim2.new(0, 0, 0, 61)
exploitsFrame.BackgroundTransparency = 1
exploitsFrame.BorderSizePixel = 0
exploitsFrame.Visible = false

-- ─── Controls Tab ─────────────────────────────────────────────────────────────
local scrollFrame = Instance.new("ScrollingFrame", controlsFrame)
scrollFrame.Size = UDim2.new(1, 0, 0, SCROLL_H)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 28, 140)
scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
scrollFrame.ElasticBehavior = Enum.ElasticBehavior.Never

local refreshFns = {}
local cy = 4

local function hLine(parent, y)
    local d = Instance.new("Frame", parent)
    d.Size = UDim2.new(1, -12, 0, 1)
    d.Position = UDim2.new(0, 6, 0, y)
    d.BackgroundColor3 = C_DIV
    d.BorderSizePixel = 0
    mkGrad(d, C_DIV, Color3.fromRGB(140, 18, 50), 0)
end

-- ─── Main feature toggles ─────────────────────────────────────────────────────
local function makeToggleBtn(parent, def, xPos, width, yPos)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0, width, 0, 28)
    btn.Position = UDim2.new(0, xPos, 0, yPos)
    btn.BackgroundColor3 = C_BTN_OFF
    btn.TextColor3 = C_BTXT_OFF
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.TextStrokeTransparency = 1
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local btnStroke = mkStroke(btn, C_BSTR_OFF, 1.5, 0.2)

    local function refresh()
        local api = def.getApi()
        local on = api and api.isActive()
        btn.Text = def.label .. ": " .. (on and "ON" or "OFF")
        if on then
            btn.BackgroundColor3 = C_BTN_ON
            btn.TextColor3 = C_BTXT_ON
            btnStroke.Color = C_BSTR_ON
            btnStroke.Transparency = 0.1
        else
            btn.BackgroundColor3 = C_BTN_OFF
            btn.TextColor3 = C_BTXT_OFF
            btnStroke.Color = C_BSTR_OFF
            btnStroke.Transparency = 0.2
        end
    end

    btn.MouseButton1Click:Connect(function()
        local api = def.getApi()
        if api then pcall(function() api.toggle() end) end
        refresh()
        local state = loadState()
        local a = def.getApi()
        state[def.key] = a and a.isActive() or false
        saveState(state)
    end)

    refresh()
    table.insert(refreshFns, refresh)
    if def.tip then setTooltip(btn, def.tip) end
    return btn
end

do
    local b1 = makeToggleBtn(scrollFrame, ROLL_DEF, 6, HALF_W, cy)
    b1.TextSize = 11
    local b2 = makeToggleBtn(scrollFrame, LEGIT_DEF, 6 + HALF_W + 5, HALF_W, cy)
    b2.TextSize = 11
    cy = cy + 32
end
for _, def in ipairs(TOGGLE_DEFS) do
    makeToggleBtn(scrollFrame, def, 6, W - 16, cy)
    cy = cy + 32
end

hLine(scrollFrame, cy) cy = cy + 8

-- ─── Position group: Auto Return (toggle) + Save Position (button) ────────────
makeToggleBtn(scrollFrame, AR_DEF, 6, HALF_W, cy)

local savePosBtn = Instance.new("TextButton", scrollFrame)
savePosBtn.Size = UDim2.new(0, HALF_W, 0, 28)
savePosBtn.Position = UDim2.new(0, 6 + HALF_W + 5, 0, cy)
savePosBtn.BackgroundColor3 = C_BTN_ON
savePosBtn.TextColor3 = Color3.new(1, 1, 1)
savePosBtn.Text = "Save Position"
savePosBtn.TextSize = 11
savePosBtn.Font = Enum.Font.GothamBold
savePosBtn.BorderSizePixel = 0
savePosBtn.TextStrokeTransparency = 1
Instance.new("UICorner", savePosBtn).CornerRadius = UDim.new(0, 6)
mkStroke(savePosBtn, C_BSTR_ON, 1.5, 0.2)
savePosBtn.MouseButton1Click:Connect(function()
    if _G.SavePosition then _G.SavePosition.save() end
end)
setTooltip(savePosBtn, "Save your current location for Auto Return")
cy = cy + 32

hLine(scrollFrame, cy) cy = cy + 8

-- ─── Zone Farmer ──────────────────────────────────────────────────────────────
local zfBtn = Instance.new("TextButton", scrollFrame)
zfBtn.Size = UDim2.new(1, -16, 0, 28)
zfBtn.Position = UDim2.new(0, 6, 0, cy)
zfBtn.BackgroundColor3 = C_BTN_OFF
zfBtn.TextColor3 = C_BTXT_OFF
zfBtn.Text = "Zone Farmer: Start"
zfBtn.TextSize = 12
zfBtn.Font = Enum.Font.GothamBold
zfBtn.BorderSizePixel = 0
zfBtn.TextStrokeTransparency = 1
Instance.new("UICorner", zfBtn).CornerRadius = UDim.new(0, 6)
local zfStroke = mkStroke(zfBtn, C_BSTR_OFF, 1.5, 0.2)
zfBtn.MouseButton1Click:Connect(function()
    local zf = _G.ZoneFarmer
    if not zf then return end
    if zf.isActive() then
        zf.stop()
    elseif not (zf.isDone and zf.isDone()) then
        zf.start()
    end
end)
setTooltip(zfBtn, "Tests top 5 zones for 3 min each, then farms the best one")
cy = cy + 32

scrollFrame.CanvasSize = UDim2.new(0, 0, 0, cy + 4)

local CTRL_CONTENT_H = SCROLL_H + 4
controlsFrame.Size = UDim2.new(1, 0, 0, CTRL_CONTENT_H)
local PANEL_H_CONTROLS = 61 + CTRL_CONTENT_H

-- ─── Stats Tab (transparent overlay, purple/red tinted text) ──────────────────
local sy = 0

local function shDiv()
    local d = Instance.new("Frame", statsFrame)
    d.Size = UDim2.new(1, 0, 0, 1)
    d.Position = UDim2.new(0, 0, 0, sy)
    d.BackgroundColor3 = C_DIV
    d.BackgroundTransparency = 0.2
    d.BorderSizePixel = 0
    mkGrad(d, C_DIV, Color3.fromRGB(155, 25, 55), 0)
    sy = sy + 1
end


local function smkCell(parent, txt, xOff, w, isLabel)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(0, w, 1, 0)
    l.Position = UDim2.new(0, xOff, 0, 0)
    l.BackgroundTransparency = 1
    l.TextColor3 = isLabel and Color3.fromRGB(240, 210, 255) or Color3.new(1, 1, 1)
    l.TextStrokeTransparency = 1
    l.Text = txt
    l.TextSize = 12
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.BorderSizePixel = 0
    return l
end

shDiv()
local sHdrRow = Instance.new("Frame", statsFrame)
sHdrRow.Size = UDim2.new(1, 0, 0, 20)
sHdrRow.Position = UDim2.new(0, 0, 0, sy)
sHdrRow.BackgroundTransparency = 1
sHdrRow.BorderSizePixel = 0
local hc = smkCell(sHdrRow, "COIN", SX.val1, VAL_W, false)
hc.TextColor3 = Color3.fromRGB(255, 205, 95)
hc.TextStrokeTransparency = 1
local hg = smkCell(sHdrRow, "GOOP", SX.val2, VAL_W, false)
hg.TextColor3 = Color3.fromRGB(135, 215, 255)
hg.TextStrokeTransparency = 1
sy = sy + 20
shDiv()

local sRows = {}
local SROW_DEFS = {
    { lbl = "Total", key = "total" },
    { lbl = "/min",  key = "min"   },
    { lbl = "/hr",   key = "hr"    },
    { lbl = "/day",  key = "day"   },
}
for _, def in ipairs(SROW_DEFS) do
    local row = Instance.new("Frame", statsFrame)
    row.Size = UDim2.new(1, 0, 0, ROW_H)
    row.Position = UDim2.new(0, 0, 0, sy)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    smkCell(row, def.lbl, SX.lbl1, LBL_W, true)
    local coinLbl = smkCell(row, "--", SX.val1, VAL_W, false)
    coinLbl.TextColor3 = Color3.fromRGB(255, 205, 95)
    smkCell(row, def.lbl, SX.lbl2, LBL_W, true)
    local goopLbl = smkCell(row, "--", SX.val2, VAL_W, false)
    goopLbl.TextColor3 = Color3.fromRGB(135, 215, 255)
    sRows[def.key] = { coin = coinLbl, goop = goopLbl }
    sy = sy + ROW_H
end
shDiv()

local sFooter = Instance.new("Frame", statsFrame)
sFooter.Size = UDim2.new(1, 0, 0, 28)
sFooter.Position = UDim2.new(0, 0, 0, sy)
sFooter.BackgroundTransparency = 1
sFooter.BorderSizePixel = 0

local sSessionLbl = Instance.new("TextLabel", sFooter)
sSessionLbl.Size = UDim2.new(1, -76, 1, 0)
sSessionLbl.Position = UDim2.new(0, 8, 0, 0)
sSessionLbl.BackgroundTransparency = 1
sSessionLbl.TextColor3 = Color3.new(1, 1, 1)
sSessionLbl.TextStrokeTransparency = 1
sSessionLbl.Text = "Session: 0:00"
sSessionLbl.TextSize = 11
sSessionLbl.Font = Enum.Font.GothamBold
sSessionLbl.TextXAlignment = Enum.TextXAlignment.Left

local sResetBtn = Instance.new("TextButton", sFooter)
sResetBtn.Size = UDim2.new(0, 60, 0, 22)
sResetBtn.Position = UDim2.new(1, -64, 0.5, -11)
sResetBtn.BackgroundColor3 = C_BTN_OFF
sResetBtn.TextColor3 = Color3.new(1, 1, 1)
sResetBtn.Text = "Reset"
sResetBtn.TextSize = 11
sResetBtn.Font = Enum.Font.GothamBold
sResetBtn.BorderSizePixel = 0
sResetBtn.TextStrokeTransparency = 1
Instance.new("UICorner", sResetBtn).CornerRadius = UDim.new(0, 4)
mkStroke(sResetBtn, C_BSTR_OFF, 1.5, 0.2)
sResetBtn.MouseButton1Click:Connect(function()
    if _G.StatsTracker then _G.StatsTracker.reset() end
end)
setTooltip(sResetBtn, "Reset session coin and goop counters to zero")
sy = sy + 28

statsFrame.Size = UDim2.new(1, 0, 0, sy)
local PANEL_H_STATS = 61 + sy

-- ─── Collect Tab ──────────────────────────────────────────────────────────────
local FRUIT_DEFS = {
    { name = "Magician Fruit",  id = "magicianFruit",  tip = "Only collect Magician Fruit" },
    { name = "Sword Fruit",     id = "swordFruit",     tip = "Only collect Sword Fruit" },
    { name = "Universe Fruit",  id = "universeFruit",  tip = "Only collect Universe Fruit" },
    { name = "Lightning Fruit", id = "lightningFruit", tip = "Only collect Lightning Fruit" },
    { name = "Fire Fruit",      id = "fireFruit",      tip = "Only collect Fire Fruit" },
    { name = "Ice Fruit",       id = "iceFruit",       tip = "Only collect Ice Fruit" },
}
local fruitSelected = {}
for _, fd in ipairs(FRUIT_DEFS) do
    fruitSelected[fd.id] = savedState["fruit_" .. fd.id] == true
end
local function applyFruitFilter()
    local ac = _G.AutoCollect
    if not (ac and ac.setFilter) then return end
    local filter, hasAny = {}, false
    for id, sel in pairs(fruitSelected) do
        if sel then filter[id] = true hasAny = true end
    end
    ac.setFilter(hasAny and filter or {})
end

local cy_c = 4
makeToggleBtn(collectFrame, AC_DEF, 6, W - 16, cy_c)
cy_c = cy_c + 32

hLine(collectFrame, cy_c) cy_c = cy_c + 5

local filterLbl = Instance.new("TextLabel", collectFrame)
filterLbl.Size = UDim2.new(1, -12, 0, 16)
filterLbl.Position = UDim2.new(0, 6, 0, cy_c)
filterLbl.BackgroundTransparency = 1
filterLbl.TextColor3 = Color3.fromRGB(190, 150, 255)
filterLbl.Text = "Fruit Filter  (none selected = collect all)"
filterLbl.TextSize = 10
filterLbl.Font = Enum.Font.GothamBold
filterLbl.TextXAlignment = Enum.TextXAlignment.Left
filterLbl.TextStrokeTransparency = 1
filterLbl.BorderSizePixel = 0
cy_c = cy_c + 20

for i, fd in ipairs(FRUIT_DEFS) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local xPos = col == 0 and 6 or (6 + HALF_W + 5)
    local yPos = cy_c + row * 32
    local btn = Instance.new("TextButton", collectFrame)
    btn.Size = UDim2.new(0, HALF_W, 0, 28)
    btn.Position = UDim2.new(0, xPos, 0, yPos)
    btn.BorderSizePixel = 0
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold
    btn.TextStrokeTransparency = 1
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local bStroke = mkStroke(btn, C_BSTR_OFF, 1.5, 0.2)
    local function refreshFruit()
        local on = fruitSelected[fd.id]
        btn.Text = fd.name .. (on and ": ON" or ": OFF")
        btn.BackgroundColor3 = on and C_BTN_ON or C_BTN_OFF
        btn.TextColor3 = on and C_BTXT_ON or C_BTXT_OFF
        bStroke.Color = on and C_BSTR_ON or C_BSTR_OFF
        bStroke.Transparency = on and 0.1 or 0.2
    end
    btn.MouseButton1Click:Connect(function()
        fruitSelected[fd.id] = not fruitSelected[fd.id]
        refreshFruit()
        local state = loadState()
        state["fruit_" .. fd.id] = fruitSelected[fd.id]
        saveState(state)
        applyFruitFilter()
    end)
    refreshFruit()
    setTooltip(btn, fd.tip)
end

cy_c = cy_c + 3 * 32
collectFrame.Size = UDim2.new(1, 0, 0, cy_c + 4)
local PANEL_H_COLLECT = 61 + cy_c + 4
applyFruitFilter()

-- ─── Exploits Tab ─────────────────────────────────────────────────────────────
local cy_e = 6
for _, def in ipairs(EXPLOIT_DEFS) do
    makeToggleBtn(exploitsFrame, def, 6, W - 16, cy_e)
    cy_e = cy_e + 32
end
exploitsFrame.Size = UDim2.new(1, 0, 0, cy_e + 4)
local PANEL_H_EXPLOITS = 61 + cy_e + 4

-- ─── Tab switching ────────────────────────────────────────────────────────────
local function showTab(name)
    controlsFrame.Visible = (name == "controls")
    statsFrame.Visible    = (name == "stats")
    collectFrame.Visible  = (name == "collect")
    exploitsFrame.Visible = (name == "exploits")
    local function setTab(btn, on)
        btn.BackgroundColor3 = on and C_TAB_ON or C_TAB_OFF
        btn.TextColor3 = on and C_TXT_ON or C_TXT_OFF
    end
    setTab(tabControls, name == "controls")
    setTab(tabStats,    name == "stats")
    setTab(tabCollect,  name == "collect")
    setTab(tabExploits, name == "exploits")
    panelBg.Visible = (name ~= "stats")
    if name == "controls" then
        panel.Size = UDim2.new(0, W, 0, PANEL_H_CONTROLS)
    elseif name == "stats" then
        panel.Size = UDim2.new(0, W, 0, PANEL_H_STATS)
    elseif name == "collect" then
        panel.Size = UDim2.new(0, W, 0, PANEL_H_COLLECT)
    else
        panel.Size = UDim2.new(0, W, 0, PANEL_H_EXPLOITS)
    end
end

tabControls.MouseButton1Click:Connect(function() showTab("controls") end)
tabStats.MouseButton1Click:Connect(function() showTab("stats") end)
tabCollect.MouseButton1Click:Connect(function() showTab("collect") end)
tabExploits.MouseButton1Click:Connect(function() showTab("exploits") end)
showTab("controls")

-- ─── Update loop ──────────────────────────────────────────────────────────────
task.spawn(function()
    while g.Parent do
        task.wait(1)

        for _, r in ipairs(refreshFns) do r() end
        applyFruitFilter()

        local zf = _G.ZoneFarmer
        if zf then
            if zf.isActive() then
                zfBtn.Text = "Zone Farmer: Stop"
                zfBtn.BackgroundColor3 = C_BTN_ON
                zfBtn.TextColor3 = C_BTXT_ON
                zfStroke.Color = C_BSTR_ON
            elseif zf.isDone and zf.isDone() then
                zfBtn.Text = "Zone Farmer: Done"
                zfBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
                zfBtn.TextColor3 = Color3.fromRGB(110, 110, 140)
                zfStroke.Color = Color3.fromRGB(55, 55, 80)
            else
                zfBtn.Text = "Zone Farmer: Start"
                zfBtn.BackgroundColor3 = C_BTN_OFF
                zfBtn.TextColor3 = C_BTXT_OFF
                zfStroke.Color = C_BSTR_OFF
            end
        end

        local st = _G.StatsTracker
        if st then
            local r = st.getRates()
            sRows.total.coin.Text = fmt(st.getCoins())
            sRows.total.goop.Text = fmt(st.getGoop())
            sRows.min.coin.Text   = fmt(r.coinMin)
            sRows.min.goop.Text   = fmt(r.goopMin)
            sRows.hr.coin.Text    = fmt(r.coinHr)
            sRows.hr.goop.Text    = fmt(r.goopHr)
            sRows.day.coin.Text   = fmt(r.coinDay)
            sRows.day.goop.Text   = fmt(r.goopDay)
            sSessionLbl.Text = "Session: " .. fmtTime(st.getElapsed())
        end
    end
end)

-- ─── Public API ───────────────────────────────────────────────────────────────
_G.SlimeRNGMain = {
    close = function() g:Destroy() _G.SlimeRNGMain = nil end,
}
