local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL = Players.LocalPlayer

local coinTotal, goopTotal = 0, 0
local sessionStart = tick()

local SFX = {"K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc"}
local function fmt(n)
    if n < 1000 then return tostring(math.floor(n)) end
    local v, i = n, 0
    while v >= 1000 and i < #SFX do
        v = v / 1000
        i = i + 1
    end
    return string.format("%.3f%s", v, SFX[i])
end
local function fmtTime(s)
    local h = math.floor(s / 3600)
    local m = math.floor(s / 60) % 60
    local sc = math.floor(s) % 60
    return h > 0 and string.format("%d:%02d:%02d", h, m, sc)
                  or string.format("%d:%02d", m, sc)
end

-- Hook GameplayN RemoteEvents
local hookedREs = {}
local function hookRE(re)
    if hookedREs[re] then return end
    hookedREs[re] = true
    re.OnClientEvent:Connect(function(a1, a2)
        if type(a2) ~= "table" then return end
        local amt = rawget(a2, "amount")
        if type(amt) ~= "number" then return end
        if a1 == "goopRewarded" then goopTotal = goopTotal + amt
        elseif a1 == "coinRewarded" then coinTotal = coinTotal + amt end
    end)
end
task.spawn(function()
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:match("^Gameplay%d+$") then hookRE(v) end
    end
    RS.DescendantAdded:Connect(function(v)
        if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:match("^Gameplay%d+$") then hookRE(v) end
    end)
end)

-- GUI
if not _G.MAIN_LOADED then
    -- Layout: 4 columns [LBL|VAL|LBL|VAL] + 3 dividers (1px each)
    -- All values are integers so grid lines stay pixel-perfect
    -- W = LBL_W*2 + VAL_W*2 + 3  →  299 = 44*2 + 104*2 + 3
    local W      = 299
    local LBL_W  = 44
    local VAL_W  = 104
    local ROW_H  = 26

    local C_BG       = Color3.fromRGB(22, 22, 22)
    local C_HDR      = Color3.fromRGB(32, 32, 32)
    local C_ROW_A    = Color3.fromRGB(26, 26, 26)
    local C_ROW_B    = Color3.fromRGB(22, 22, 22)
    local C_DIV      = Color3.fromRGB(50, 50, 50)
    local C_TXT_HDR  = Color3.fromRGB(130, 130, 130)
    local C_TXT_VAL  = Color3.fromRGB(230, 230, 230)
    local C_TXT_LBL  = Color3.fromRGB(100, 100, 100)

    -- Column x offsets (left edge of each column)
    -- [0 .. LBL_W-1] | div | [LBL_W+1 .. LBL_W+VAL_W] | div | [LBL_W+VAL_W+2 .. LBL_W+VAL_W+2+LBL_W-1] | div | [...]
    local X = {
        lbl1 = 0,
        val1 = LBL_W + 1,
        lbl2 = LBL_W + 1 + VAL_W + 1,
        val2 = LBL_W + 1 + VAL_W + 1 + LBL_W + 1,
    }

    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "StatsTracker"
    g.IgnoreGuiInset = true
    g.Parent = PL.PlayerGui

    local panel = Instance.new("Frame", g)
    panel.Size = UDim2.new(0, W, 0, 10)
    panel.Position = UDim2.new(0.5, -W/2, 0, 12)
    panel.BackgroundColor3 = C_BG
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", panel).Color = C_DIV

    local y = 0

    -- Title bar
    local titleBar = Instance.new("Frame", panel)
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

    local titleLbl = Instance.new("TextLabel", titleBar)
    titleLbl.Size = UDim2.new(1, -40, 1, 0)
    titleLbl.Position = UDim2.new(0, 10, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    titleLbl.Text = "Stats Tracker"
    titleLbl.TextSize = 13
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local close = Instance.new("TextButton", titleBar)
    close.Size = UDim2.new(0, 28, 0, 28)
    close.Position = UDim2.new(1, -32, 0, 2)
    close.BackgroundColor3 = Color3.fromRGB(140, 30, 30)
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Text = "X"
    close.TextSize = 13
    close.Font = Enum.Font.GothamBold
    close.BorderSizePixel = 0
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 4)
    y = y + 32

    local function hDiv()
        local d = Instance.new("Frame", panel)
        d.Size = UDim2.new(1, 0, 0, 1)
        d.Position = UDim2.new(0, 0, 0, y)
        d.BackgroundColor3 = C_DIV
        d.BorderSizePixel = 0
        y = y + 1
    end

    local function vDiv(parent, xOff)
        local d = Instance.new("Frame", parent)
        d.Size = UDim2.new(0, 1, 1, 0)
        d.Position = UDim2.new(0, xOff, 0, 0)
        d.BackgroundColor3 = C_DIV
        d.BorderSizePixel = 0
    end

    local function mkCell(parent, txt, xOff, w, color, size, align, bold)
        local l = Instance.new("TextLabel", parent)
        l.Size = UDim2.new(0, w, 1, 0)
        l.Position = UDim2.new(0, xOff, 0, 0)
        l.BackgroundTransparency = 1
        l.TextColor3 = color
        l.Text = txt
        l.TextSize = size or 11
        l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextXAlignment = align or Enum.TextXAlignment.Center
        l.BorderSizePixel = 0
        return l
    end

    -- Column header row: [blank|COIN|blank|GOOP]
    hDiv()
    local hdrRow = Instance.new("Frame", panel)
    hdrRow.Size = UDim2.new(1, 0, 0, 22)
    hdrRow.Position = UDim2.new(0, 0, 0, y)
    hdrRow.BackgroundColor3 = C_HDR
    hdrRow.BorderSizePixel = 0
    mkCell(hdrRow, "",      X.lbl1, LBL_W, C_TXT_HDR, 11, Enum.TextXAlignment.Center, true)
    vDiv(hdrRow, X.val1 - 1)
    mkCell(hdrRow, "COIN",  X.val1, VAL_W, C_TXT_HDR, 11, Enum.TextXAlignment.Center, true)
    vDiv(hdrRow, X.lbl2 - 1)
    mkCell(hdrRow, "",      X.lbl2, LBL_W, C_TXT_HDR, 11, Enum.TextXAlignment.Center, true)
    vDiv(hdrRow, X.val2 - 1)
    mkCell(hdrRow, "GOOP",  X.val2, VAL_W, C_TXT_HDR, 11, Enum.TextXAlignment.Center, true)
    y = y + 22
    hDiv()

    -- Data rows
    local rows = {}
    local ROW_DEFS = {
        {lbl = "Total", key = "total"},
        {lbl = "/min",  key = "min"},
        {lbl = "/hr",   key = "hr"},
        {lbl = "/day",  key = "day"},
    }

    for i, def in ipairs(ROW_DEFS) do
        local row = Instance.new("Frame", panel)
        row.Size = UDim2.new(1, 0, 0, ROW_H)
        row.Position = UDim2.new(0, 0, 0, y)
        row.BackgroundColor3 = (i % 2 == 1) and C_ROW_A or C_ROW_B
        row.BorderSizePixel = 0

        mkCell(row, def.lbl, X.lbl1, LBL_W, C_TXT_LBL, 11, Enum.TextXAlignment.Center, true)
        vDiv(row, X.val1 - 1)
        local coinLbl = mkCell(row, "--", X.val1, VAL_W, C_TXT_VAL, 12, Enum.TextXAlignment.Center, true)
        vDiv(row, X.lbl2 - 1)
        mkCell(row, def.lbl, X.lbl2, LBL_W, C_TXT_LBL, 11, Enum.TextXAlignment.Center, true)
        vDiv(row, X.val2 - 1)
        local goopLbl = mkCell(row, "--", X.val2, VAL_W, C_TXT_VAL, 12, Enum.TextXAlignment.Center, true)

        rows[def.key] = {coin = coinLbl, goop = goopLbl}
        y = y + ROW_H
        hDiv()
    end

    -- Footer
    local footer = Instance.new("Frame", panel)
    footer.Size = UDim2.new(1, 0, 0, 30)
    footer.Position = UDim2.new(0, 0, 0, y)
    footer.BackgroundColor3 = C_HDR
    footer.BorderSizePixel = 0

    local sessionLbl = Instance.new("TextLabel", footer)
    sessionLbl.Size = UDim2.new(1, -80, 1, 0)
    sessionLbl.Position = UDim2.new(0, 8, 0, 0)
    sessionLbl.BackgroundTransparency = 1
    sessionLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    sessionLbl.Text = "Session: 0:00"
    sessionLbl.TextSize = 11
    sessionLbl.Font = Enum.Font.Gotham
    sessionLbl.TextXAlignment = Enum.TextXAlignment.Left

    local resetBtn = Instance.new("TextButton", footer)
    resetBtn.Size = UDim2.new(0, 64, 0, 22)
    resetBtn.Position = UDim2.new(1, -68, 0.5, -11)
    resetBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    resetBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    resetBtn.Text = "Reset"
    resetBtn.TextSize = 11
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.BorderSizePixel = 0
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 4)
    y = y + 30

    panel.Size = UDim2.new(0, W, 0, y)

    -- Events
    close.MouseButton1Click:Connect(function()
        g:Destroy()
        _G.StatsTracker = nil
    end)
    resetBtn.MouseButton1Click:Connect(function()
        coinTotal, goopTotal, sessionStart = 0, 0, tick()
    end)

    -- Update loop
    task.spawn(function()
        while g.Parent do
            task.wait(1)
            local el = math.max(tick() - sessionStart, 1)
            rows.total.coin.Text = fmt(coinTotal)
            rows.total.goop.Text = fmt(goopTotal)
            rows.min.coin.Text   = fmt(coinTotal / el * 60)
            rows.min.goop.Text   = fmt(goopTotal / el * 60)
            rows.hr.coin.Text    = fmt(coinTotal / el * 3600)
            rows.hr.goop.Text    = fmt(goopTotal / el * 3600)
            rows.day.coin.Text   = fmt(coinTotal / el * 86400)
            rows.day.goop.Text   = fmt(goopTotal / el * 86400)
            sessionLbl.Text = "Session: " .. fmtTime(el)
        end
    end)
end

_G.StatsTracker = {
    reset      = function() coinTotal, goopTotal, sessionStart = 0, 0, tick() end,
    getCoins   = function() return coinTotal end,
    getGoop    = function() return goopTotal end,
    getElapsed = function() return math.max(tick() - sessionStart, 1) end,
    getRates   = function()
        local el = math.max(tick() - sessionStart, 1)
        return {
            coinMin  = coinTotal / el * 60,
            coinHr   = coinTotal / el * 3600,
            coinDay  = coinTotal / el * 86400,
            goopMin  = goopTotal / el * 60,
            goopHr   = goopTotal / el * 3600,
            goopDay  = goopTotal / el * 86400,
        }
    end,
}
