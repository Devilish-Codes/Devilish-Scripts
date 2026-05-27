local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL = Players.LocalPlayer

local zoneSvc = require(RS.Source.Features.Zones.ZonesServiceClient)

local TEST_DURATION  = 180  -- seconds per zone (3 min)
local ZONES_TO_TEST  = 5
local TELEPORT_WAIT  = 10   -- seconds after teleport before measuring

-- Zone name lookup
local ZONE_NAMES = {}
pcall(function()
    local zones = require(RS.Source.Game.Items.Zones)
    for _, z in ipairs(zones) do
        if z.id and z.name then ZONE_NAMES[z.id] = z.name end
    end
end)
local function zoneName(id)
    return ZONE_NAMES[id] or ("Zone "..id)
end

-- Number formatter
local SFX = {"K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc"}
local function fmt(n)
    if n < 1000 then return tostring(math.floor(n)) end
    local v, i = n, 0
    while v >= 1000 and i < #SFX do v = v / 1000 i = i + 1 end
    return string.format("%.3f%s", v, SFX[i])
end
local function fmtTime(s)
    local m = math.floor(s / 60)
    return string.format("%d:%02d", m, math.floor(s) % 60)
end

-- Goop tracking
local goopCount = 0
local hookedREs = {}
local function hookRE(re)
    if hookedREs[re] then return end
    hookedREs[re] = true
    re.OnClientEvent:Connect(function(a1, a2)
        if a1 == "goopRewarded" and type(a2) == "table" then
            local amt = rawget(a2, "amount")
            if type(amt) == "number" then goopCount = goopCount + amt end
        end
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

-- State
local running   = false
local done      = false
local results   = {}  -- {zoneId, name, goopPerHr}
local statusText = ""
local statusLbl, resultRows, bestLbl
local popupGui, popupStatusLbl, popupResultRows, popupBestLbl, popupResultsFrame
local createPopup, updatePopupResults  -- forward-declared so runTest closure can capture them

local function setStatus(txt)
    statusText = txt
    if not _G.MAIN_LOADED and statusLbl and statusLbl.Parent then
        statusLbl.Text = txt
    end
    if popupStatusLbl and popupStatusLbl.Parent then
        popupStatusLbl.Text = txt
    end
end

-- GUI
if not _G.MAIN_LOADED then
    local W = 260
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "ZoneFarmer"
    g.IgnoreGuiInset = true
    g.Parent = PL.PlayerGui

    local panel = Instance.new("Frame", g)
    panel.Size = UDim2.new(0, W, 0, 10)
    panel.Position = UDim2.new(0.5, -W/2, 0, 12)
    panel.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", panel).Color = Color3.fromRGB(50, 50, 50)

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
    titleLbl.Text = "Zone Farmer"
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
        d.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
        d.BorderSizePixel = 0
        y = y + 1
    end

    -- Start button
    hDiv()
    local startBtn = Instance.new("TextButton", panel)
    startBtn.Size = UDim2.new(1, -10, 0, 32)
    startBtn.Position = UDim2.new(0, 5, 0, y + 4)
    startBtn.BackgroundColor3 = Color3.fromRGB(35, 90, 35)
    startBtn.TextColor3 = Color3.fromRGB(100, 230, 100)
    startBtn.Text = "Start Zone Test"
    startBtn.TextSize = 13
    startBtn.Font = Enum.Font.GothamBold
    startBtn.BorderSizePixel = 0
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 6)
    y = y + 40

    -- Status label
    hDiv()
    statusLbl = Instance.new("TextLabel", panel)
    statusLbl.Size = UDim2.new(1, -10, 0, 32)
    statusLbl.Position = UDim2.new(0, 5, 0, y + 2)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
    statusLbl.Text = "Press Start to begin testing"
    statusLbl.TextSize = 11
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextWrapped = true
    Instance.new("UIPadding", statusLbl).PaddingLeft = UDim.new(0, 4)
    y = y + 36

    -- Results section (hidden until test completes)
    hDiv()
    local resultsFrame = Instance.new("Frame", panel)
    resultsFrame.Size = UDim2.new(1, 0, 0, 0)
    resultsFrame.Position = UDim2.new(0, 0, 0, y)
    resultsFrame.BackgroundTransparency = 1
    resultsFrame.BorderSizePixel = 0
    resultsFrame.Visible = false

    -- Results header
    local rHdr = Instance.new("Frame", resultsFrame)
    rHdr.Size = UDim2.new(1, 0, 0, 22)
    rHdr.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    rHdr.BorderSizePixel = 0

    local function mkHdrCell(txt, xScale, xOff, w)
        local l = Instance.new("TextLabel", rHdr)
        l.Size = UDim2.new(0, w, 1, 0)
        l.Position = UDim2.new(xScale, xOff, 0, 0)
        l.BackgroundTransparency = 1
        l.TextColor3 = Color3.fromRGB(120, 120, 120)
        l.Text = txt
        l.TextSize = 10
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Center
    end
    mkHdrCell("ZONE",     0,   0,  130)
    mkHdrCell("GOOP/HR",  0, 130,  130)

    local ry = 22
    resultRows = {}
    for i = 1, ZONES_TO_TEST do
        local rowBg = (i % 2 == 1) and Color3.fromRGB(26,26,26) or Color3.fromRGB(22,22,22)
        local row = Instance.new("Frame", resultsFrame)
        row.Size = UDim2.new(1, 0, 0, 24)
        row.Position = UDim2.new(0, 0, 0, ry)
        row.BackgroundColor3 = rowBg
        row.BorderSizePixel = 0

        local nLbl = Instance.new("TextLabel", row)
        nLbl.Size = UDim2.new(0, 130, 1, 0)
        nLbl.BackgroundTransparency = 1
        nLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        nLbl.Text = "--"
        nLbl.TextSize = 11
        nLbl.Font = Enum.Font.Gotham
        nLbl.TextXAlignment = Enum.TextXAlignment.Center

        local vLbl = Instance.new("TextLabel", row)
        vLbl.Size = UDim2.new(0, 130, 1, 0)
        vLbl.Position = UDim2.new(0, 130, 0, 0)
        vLbl.BackgroundTransparency = 1
        vLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        vLbl.Text = "--"
        vLbl.TextSize = 11
        vLbl.Font = Enum.Font.Gotham
        vLbl.TextXAlignment = Enum.TextXAlignment.Center

        -- divider
        local dv = Instance.new("Frame", row)
        dv.Size = UDim2.new(0, 1, 1, 0)
        dv.Position = UDim2.new(0, 130, 0, 0)
        dv.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
        dv.BorderSizePixel = 0

        resultRows[i] = {name = nLbl, val = vLbl, row = row}
        ry = ry + 24
    end

    -- Best zone row
    local bestRow = Instance.new("Frame", resultsFrame)
    bestRow.Size = UDim2.new(1, 0, 0, 28)
    bestRow.Position = UDim2.new(0, 0, 0, ry)
    bestRow.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
    bestRow.BorderSizePixel = 0

    bestLbl = Instance.new("TextLabel", bestRow)
    bestLbl.Size = UDim2.new(1, -10, 1, 0)
    bestLbl.Position = UDim2.new(0, 5, 0, 0)
    bestLbl.BackgroundTransparency = 1
    bestLbl.TextColor3 = Color3.fromRGB(80, 230, 80)
    bestLbl.Text = "Best: --"
    bestLbl.TextSize = 12
    bestLbl.Font = Enum.Font.GothamBold
    bestLbl.TextXAlignment = Enum.TextXAlignment.Center
    ry = ry + 28

    resultsFrame.Size = UDim2.new(1, 0, 0, ry)
    y = y + ry

    panel.Size = UDim2.new(0, W, 0, y + 4)

    -- Button events
    startBtn.MouseButton1Click:Connect(function()
        if running then
            running = false
        else
            done = false
            task.spawn(runTest)
        end
    end)

    close.MouseButton1Click:Connect(function()
        running = false
        g:Destroy()
        _G.ZoneFarmer = nil
    end)

    -- runTest references startBtn/resultsFrame/bestLbl/resultRows from this scope
    -- defined below as upvalue-capturing closure
    function runTest()
        running = true
        results = {}
        resultsFrame.Visible = false
        startBtn.Text = "Stop Test"
        startBtn.BackgroundColor3 = Color3.fromRGB(90, 35, 35)
        startBtn.TextColor3 = Color3.fromRGB(230, 100, 100)

        local maxZone = pcall(function() return zoneSvc:getMaxZone() end) and zoneSvc:getMaxZone() or 1
        local count = math.min(ZONES_TO_TEST, maxZone)
        local zoneIds = {}
        for i = maxZone - count + 1, maxZone do
            table.insert(zoneIds, i)
        end

        for idx, zid in ipairs(zoneIds) do
            if not running then break end
            local name = zoneName(zid)

            -- Teleport
            setStatus(string.format("[%d/%d] Teleporting to %s...", idx, count, name))
            pcall(function() zoneSvc:teleportToZone(zid) end)

            -- Wait for zone to load
            for t = TELEPORT_WAIT, 1, -1 do
                if not running then break end
                setStatus(string.format("[%d/%d] Loading %s... %ds", idx, count, name, t))
                task.wait(1)
            end
            if not running then break end

            -- Reset and measure
            goopCount = 0
            local zoneElapsed = 0
            if resultRows[idx] then
                resultRows[idx].name.Text = name
                resultRows[idx].val.Text = "—"
                resultRows[idx].name.TextColor3 = Color3.fromRGB(180, 160, 255)
                resultRows[idx].val.TextColor3 = Color3.fromRGB(180, 160, 255)
            end
            for t = TEST_DURATION, 1, -1 do
                if not running then break end
                zoneElapsed = TEST_DURATION - t + 1
                local liveRate = zoneElapsed > 0 and (goopCount / zoneElapsed) * 3600 or 0
                setStatus(string.format("[%d/%d] Farming %s — %s left", idx, count, name, fmtTime(t)))
                if resultRows[idx] then resultRows[idx].val.Text = fmt(liveRate) end
                task.wait(1)
            end
            if not running then break end

            local goopPerHr = (goopCount / TEST_DURATION) * 3600
            table.insert(results, {zoneId = zid, name = name, goopPerHr = goopPerHr})
            if resultRows[idx] then
                resultRows[idx].name.TextColor3 = Color3.fromRGB(200, 200, 200)
                resultRows[idx].val.TextColor3 = Color3.fromRGB(200, 200, 200)
                resultRows[idx].val.Text = fmt(goopPerHr)
            end
        end

        if not running then
            setStatus("Test stopped.")
            startBtn.Text = "Start Zone Test"
            startBtn.BackgroundColor3 = Color3.fromRGB(35, 90, 35)
            startBtn.TextColor3 = Color3.fromRGB(100, 230, 100)
            return
        end

        -- Sort results best first
        table.sort(results, function(a, b) return a.goopPerHr > b.goopPerHr end)

        -- Populate result rows
        for i, r in ipairs(results) do
            if resultRows[i] then
                resultRows[i].name.Text = r.name
                resultRows[i].val.Text  = fmt(r.goopPerHr)
                -- highlight best
                local c = (i == 1) and Color3.fromRGB(80, 230, 80) or Color3.fromRGB(200, 200, 200)
                resultRows[i].name.TextColor3 = c
                resultRows[i].val.TextColor3  = c
            end
        end
        -- clear unused rows
        for i = #results + 1, ZONES_TO_TEST do
            if resultRows[i] then
                resultRows[i].name.Text = ""
                resultRows[i].val.Text  = ""
            end
        end

        -- Teleport to best
        local best = results[1]
        if best then
            bestLbl.Text = "Best: "..best.name.." ("..fmt(best.goopPerHr).."/hr)"
            setStatus("Teleporting to best zone: "..best.name)
            pcall(function() zoneSvc:teleportToZone(best.zoneId) end)
            task.wait(2)
            setStatus("Done! Farming "..best.name)
        end

        running = false
        done = true
        startBtn.Text = "Start Zone Test"
        startBtn.BackgroundColor3 = Color3.fromRGB(35, 90, 35)
        startBtn.TextColor3 = Color3.fromRGB(100, 230, 100)
    end
else
    -- Headless runTest: popup GUI handles display
    function runTest()
        running = true
        results = {}
        createPopup()

        local maxZone = pcall(function() return zoneSvc:getMaxZone() end) and zoneSvc:getMaxZone() or 1
        local count = math.min(ZONES_TO_TEST, maxZone)
        local zoneIds = {}
        for i = maxZone - count + 1, maxZone do
            table.insert(zoneIds, i)
        end

        for idx, zid in ipairs(zoneIds) do
            if not running then break end
            local name = zoneName(zid)

            setStatus(string.format("[%d/%d] Teleporting to %s...", idx, count, name))
            pcall(function() zoneSvc:teleportToZone(zid) end)

            for t = TELEPORT_WAIT, 1, -1 do
                if not running then break end
                setStatus(string.format("[%d/%d] Loading %s... %ds", idx, count, name, t))
                task.wait(1)
            end
            if not running then break end

            goopCount = 0
            local zoneElapsed = 0
            if popupResultRows and popupResultRows[idx] then
                popupResultRows[idx].name.Text = name
                popupResultRows[idx].val.Text = "—"
                popupResultRows[idx].name.TextColor3 = Color3.fromRGB(180, 160, 255)
                popupResultRows[idx].val.TextColor3 = Color3.fromRGB(180, 160, 255)
            end
            for t = TEST_DURATION, 1, -1 do
                if not running then break end
                zoneElapsed = TEST_DURATION - t + 1
                local liveRate = zoneElapsed > 0 and (goopCount / zoneElapsed) * 3600 or 0
                setStatus(string.format("[%d/%d] Farming %s — %s left", idx, count, name, fmtTime(t)))
                if popupResultRows and popupResultRows[idx] then
                    popupResultRows[idx].val.Text = fmt(liveRate)
                end
                task.wait(1)
            end
            if not running then break end

            local goopPerHr = (goopCount / TEST_DURATION) * 3600
            table.insert(results, {zoneId = zid, name = name, goopPerHr = goopPerHr})
            if popupResultRows and popupResultRows[idx] then
                popupResultRows[idx].name.TextColor3 = Color3.fromRGB(200, 200, 200)
                popupResultRows[idx].val.TextColor3 = Color3.fromRGB(200, 200, 200)
                popupResultRows[idx].val.Text = fmt(goopPerHr)
            end
        end

        if not running then
            setStatus("Test stopped.")
            return
        end

        table.sort(results, function(a, b) return a.goopPerHr > b.goopPerHr end)

        local best = results[1]
        if best then
            setStatus("Teleporting to best zone: "..best.name)
            pcall(function() zoneSvc:teleportToZone(best.zoneId) end)
            task.wait(2)
            setStatus("Done! Farming "..best.name)
        end

        updatePopupResults()
        running = false
        done = true
    end
end

-- ─── Popup GUI (shown when running via main.lua) ──────────────────────────────
local PW = 280
createPopup = function()
    if not _G.MAIN_LOADED then return end
    if popupGui and popupGui.Parent then return end
    local UIS = game:GetService("UserInputService")

    popupGui = Instance.new("ScreenGui")
    popupGui.ResetOnSpawn = false
    popupGui.Name = "ZoneFarmerPopup"
    popupGui.IgnoreGuiInset = true
    popupGui.Parent = PL.PlayerGui

    local panel = Instance.new("Frame", popupGui)
    panel.BackgroundColor3 = Color3.fromRGB(22, 8, 40)
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
    local ps = Instance.new("UIStroke", panel)
    ps.Color = Color3.fromRGB(75, 22, 115)
    ps.Thickness = 1.5
    ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    -- Title bar
    local titleBar = Instance.new("Frame", panel)
    titleBar.Size = UDim2.new(1, 0, 0, 28)
    titleBar.BackgroundColor3 = Color3.fromRGB(32, 10, 58)
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

    local tl = Instance.new("TextLabel", titleBar)
    tl.Size = UDim2.new(1, -36, 1, 0)
    tl.Position = UDim2.new(0, 10, 0, 0)
    tl.BackgroundTransparency = 1
    tl.TextColor3 = Color3.new(1, 1, 1)
    tl.Text = "Zone Farmer"
    tl.TextSize = 13
    tl.Font = Enum.Font.GothamBold
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.TextStrokeTransparency = 1

    local xBtn = Instance.new("TextButton", titleBar)
    xBtn.Size = UDim2.new(0, 24, 0, 20)
    xBtn.Position = UDim2.new(1, -28, 0, 4)
    xBtn.BackgroundColor3 = Color3.fromRGB(140, 18, 35)
    xBtn.TextColor3 = Color3.new(1, 1, 1)
    xBtn.Text = "X"
    xBtn.TextSize = 12
    xBtn.Font = Enum.Font.GothamBold
    xBtn.BorderSizePixel = 0
    xBtn.TextStrokeTransparency = 1
    Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 4)
    xBtn.MouseButton1Click:Connect(function()
        popupGui:Destroy()
        popupGui = nil
        popupStatusLbl = nil
        popupResultRows = nil
        popupBestLbl = nil
        popupResultsFrame = nil
    end)

    -- Drag
    local drag, ds, dp = false, nil, nil
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            ds = UIS:GetMouseLocation()
            dp = panel.AbsolutePosition
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local cur = UIS:GetMouseLocation()
        panel.Position = UDim2.new(0, dp.X + (cur.X - ds.X), 0, dp.Y + (cur.Y - ds.Y))
    end)

    local y = 28
    local function mkDiv()
        local d = Instance.new("Frame", panel)
        d.Size = UDim2.new(1, -12, 0, 1)
        d.Position = UDim2.new(0, 6, 0, y)
        d.BackgroundColor3 = Color3.fromRGB(60, 18, 95)
        d.BorderSizePixel = 0
        y = y + 1
    end

    -- Status label
    mkDiv() y = y + 4
    popupStatusLbl = Instance.new("TextLabel", panel)
    popupStatusLbl.Size = UDim2.new(1, -16, 0, 44)
    popupStatusLbl.Position = UDim2.new(0, 8, 0, y)
    popupStatusLbl.BackgroundTransparency = 1
    popupStatusLbl.TextColor3 = Color3.fromRGB(210, 185, 255)
    popupStatusLbl.Text = statusText ~= "" and statusText or "Starting..."
    popupStatusLbl.TextSize = 11
    popupStatusLbl.Font = Enum.Font.Gotham
    popupStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    popupStatusLbl.TextWrapped = true
    popupStatusLbl.TextStrokeTransparency = 1
    y = y + 48

    -- Results section (hidden until done)
    mkDiv()
    popupResultsFrame = Instance.new("Frame", panel)
    popupResultsFrame.Position = UDim2.new(0, 0, 0, y)
    popupResultsFrame.BackgroundTransparency = 1
    popupResultsFrame.BorderSizePixel = 0

    local rHdr = Instance.new("Frame", popupResultsFrame)
    rHdr.Size = UDim2.new(1, 0, 0, 22)
    rHdr.BackgroundColor3 = Color3.fromRGB(32, 10, 58)
    rHdr.BorderSizePixel = 0

    local LCOL, RCOL = PW - 130, 130
    local function mkCell(parent, txt, xOff, w, isHdr)
        local l = Instance.new("TextLabel", parent)
        l.Size = UDim2.new(0, w, 1, 0)
        l.Position = UDim2.new(0, xOff, 0, 0)
        l.BackgroundTransparency = 1
        l.TextColor3 = isHdr and Color3.fromRGB(120, 90, 160) or Color3.fromRGB(200, 200, 200)
        l.Text = txt
        l.TextSize = isHdr and 10 or 11
        l.Font = isHdr and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.TextStrokeTransparency = 1
        return l
    end
    mkCell(rHdr, "ZONE", 0, LCOL, true)
    mkCell(rHdr, "GOOP/HR", LCOL, RCOL, true)
    local function mkColDiv(parent)
        local d = Instance.new("Frame", parent)
        d.Size = UDim2.new(0, 1, 1, 0)
        d.Position = UDim2.new(0, LCOL, 0, 0)
        d.BackgroundColor3 = Color3.fromRGB(60, 18, 95)
        d.BorderSizePixel = 0
    end
    mkColDiv(rHdr)

    local ry = 22
    popupResultRows = {}
    for i = 1, ZONES_TO_TEST do
        local row = Instance.new("Frame", popupResultsFrame)
        row.Size = UDim2.new(1, 0, 0, 24)
        row.Position = UDim2.new(0, 0, 0, ry)
        row.BackgroundColor3 = (i%2==1) and Color3.fromRGB(28,10,50) or Color3.fromRGB(22,8,40)
        row.BorderSizePixel = 0
        local nLbl = mkCell(row, "--", 0, LCOL, false)
        local vLbl = mkCell(row, "--", LCOL, RCOL, false)
        mkColDiv(row)
        popupResultRows[i] = {name=nLbl, val=vLbl}
        ry = ry + 24
    end

    local bestRow = Instance.new("Frame", popupResultsFrame)
    bestRow.Size = UDim2.new(1, 0, 0, 28)
    bestRow.Position = UDim2.new(0, 0, 0, ry)
    bestRow.BackgroundColor3 = Color3.fromRGB(15, 35, 15)
    bestRow.BorderSizePixel = 0
    popupBestLbl = Instance.new("TextLabel", bestRow)
    popupBestLbl.Size = UDim2.new(1, -10, 1, 0)
    popupBestLbl.Position = UDim2.new(0, 5, 0, 0)
    popupBestLbl.BackgroundTransparency = 1
    popupBestLbl.TextColor3 = Color3.fromRGB(80, 230, 80)
    popupBestLbl.Text = "Best: --"
    popupBestLbl.TextSize = 12
    popupBestLbl.Font = Enum.Font.GothamBold
    popupBestLbl.TextXAlignment = Enum.TextXAlignment.Center
    popupBestLbl.TextStrokeTransparency = 1
    ry = ry + 28
    popupResultsFrame.Size = UDim2.new(1, 0, 0, ry)

    local baseH = y + 4
    popupResultsFrame.Visible = true
    panel.Size = UDim2.new(0, PW, 0, baseH + ry)
    panel.Position = UDim2.new(0.5, -PW/2, 0, 60)
end

updatePopupResults = function()
    if not popupResultRows or not popupResultsFrame then return end
    for i, r in ipairs(results) do
        if popupResultRows[i] then
            popupResultRows[i].name.Text = r.name
            popupResultRows[i].val.Text  = fmt(r.goopPerHr)
            local c = i==1 and Color3.fromRGB(80,230,80) or Color3.fromRGB(200,200,200)
            popupResultRows[i].name.TextColor3 = c
            popupResultRows[i].val.TextColor3  = c
        end
    end
    for i = #results+1, ZONES_TO_TEST do
        if popupResultRows[i] then
            popupResultRows[i].name.Text = ""
            popupResultRows[i].val.Text  = ""
        end
    end
    if popupBestLbl and results[1] then
        popupBestLbl.Text = "Best: "..results[1].name.." ("..fmt(results[1].goopPerHr).."/hr)"
    end
    popupResultsFrame.Visible = true
end

-- Public API
_G.ZoneFarmer = {
    start      = function() if not running then task.spawn(runTest) end end,
    stop       = function() running = false end,
    isActive   = function() return running end,
    isDone     = function() return done end,
    getResults = function() return results end,
    getStatus  = function() return statusText end,
}
