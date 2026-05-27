local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL      = Players.LocalPlayer

local rollSvc = require(RS.Source.Features.Roll.RollServiceClient)

-- ── Configuration ─────────────────────────────────────────────────────────────
local ROLL_TYPES = {"void", "galaxy", "golden", "diamond"}

-- Default cycle lengths — auto-updated when a die resets after firing
local cycleLen = {golden = 10, diamond = 100, void = 1000, galaxy = 5000}

local RELEASE_COOLDOWN = 4  -- seconds to ignore new ≤1 hits after release

-- ── State ─────────────────────────────────────────────────────────────────────
local progress   = {void=math.huge, galaxy=math.huge, golden=math.huge, diamond=math.huge}
local paused     = {void=false,     galaxy=false,     golden=false,     diamond=false}
local active     = false
local releasedAt = 0

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function setPaused(rt, state)
    local ok = pcall(function() rollSvc:setSpecialRollPaused(rt, state) end)
    if not ok then pcall(function() rollSvc.networker:fetch("setSpecialRollPaused", rt, state) end) end
    paused[rt] = state
end

local function reset()
    for _, rt in ipairs(ROLL_TYPES) do
        if paused[rt] then setPaused(rt, false) end
        progress[rt] = math.huge
    end
end

-- ── Core logic ────────────────────────────────────────────────────────────────
--
-- Greedy alignment strategy:
--   Galaxy is the anchor (longest cycle). For every other die, when it reaches 1,
--   check: would galaxy fire before this die could complete another full cycle?
--     YES  →  pause now (this is the last ≤1 window before galaxy fires)
--     NO   →  let it fire; it will get another chance next cycle
--   Galaxy itself is always paused at 1.
--   Once all 4 are paused at ≤1, release simultaneously.
--
local function handleProgression()
    if not active then return end
    if os.clock() - releasedAt < RELEASE_COOLDOWN then return end

    -- Decide whether to hold each die that is currently at ≤1
    for _, rt in ipairs(ROLL_TYPES) do
        if progress[rt] <= 1 and not paused[rt] then
            local shouldPause
            if rt == "galaxy" then
                -- Galaxy is the anchor — always hold at 1
                shouldPause = true
            else
                -- Hold only if galaxy will fire before this die could finish another cycle.
                -- That means waiting one more cycle would overshoot galaxy's next fire.
                local G = progress.galaxy
                shouldPause = G < math.huge and (G - 1) < cycleLen[rt]
            end
            if shouldPause then
                setPaused(rt, true)
            end
        end
    end

    -- All four held at ≤1 → release simultaneously
    local allReady = true
    for _, rt in ipairs(ROLL_TYPES) do
        if not paused[rt] or progress[rt] > 1 then allReady = false break end
    end
    if allReady then
        releasedAt = os.clock()
        for _, rt in ipairs(ROLL_TYPES) do
            setPaused(rt, false)
            progress[rt] = math.huge
        end
    end
end

-- ── Remote event hooks ────────────────────────────────────────────────────────
local function onRollEvent(a1, a2, a3)
    local evName, data
    if type(a1) == "string" then evName, data = a1, a2
    elseif type(a2) == "string" then evName, data = a2, a3 end
    if evName ~= "specialRollProgression" or type(data) ~= "table" then return end

    for _, rt in ipairs(ROLL_TYPES) do
        local d = data[rt]
        if d then
            local newVal = d.rollsUntilNext or math.huge
            -- When a die actually fires and resets (was ≤1, now reappears > 5),
            -- record the new value as the observed cycle length for that die.
            if not paused[rt] and progress[rt] <= 1 and newVal > 5 and newVal < math.huge then
                cycleLen[rt] = newVal
            end
            progress[rt] = newVal
        end
    end

    handleProgression()

    if not _G.MAIN_LOADED and statusLbl and statusLbl.Parent then
        local function f(v) return v >= math.huge and "--" or tostring(v) end
        local row1 = string.format("G:%-4s D:%-4s V:%-4s X:%-4s",
            f(progress.golden), f(progress.diamond), f(progress.void), f(progress.galaxy))

        local ABBR = {golden="G", diamond="D", void="V", galaxy="X"}
        local held, cycling = {}, {}
        for _, rt in ipairs(ROLL_TYPES) do
            local a = ABBR[rt]
            if paused[rt] then held[#held+1] = a
            elseif progress[rt] < math.huge then cycling[#cycling+1] = a end
        end

        local row2
        if #held == 4 then
            row2 = "▶ releasing all"
        elseif #held > 0 then
            local waitPart = #cycling > 0 and ("  cycling:" .. table.concat(cycling, " ")) or ""
            row2 = "◆ held:" .. table.concat(held, " ") .. waitPart
        else
            local G = progress.galaxy
            row2 = G < math.huge
                and string.format("X has %d  (cycle ~%d)", G, cycleLen.galaxy)
                or  "waiting for data..."
        end
        statusLbl.Text = row1 .. "\n" .. row2
    end
end

local hookedREs = {}
local function hookRE(re)
    if hookedREs[re] then return end
    hookedREs[re] = true
    re.OnClientEvent:Connect(onRollEvent)
end

task.spawn(function()
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") then hookRE(d) end
    end
    RS.DescendantAdded:Connect(function(d)
        if d:IsA("RemoteEvent") then hookRE(d) end
    end)
end)

-- ── GUI (standalone only) ─────────────────────────────────────────────────────
local toggle, statusLbl
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "StackRolls"
    g.IgnoreGuiInset = true
    g.Parent = PL.PlayerGui

    local panel = Instance.new("Frame", g)
    panel.Size = UDim2.new(0, 280, 0, 88)
    panel.Position = UDim2.new(0.5, -140, 0, 12)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)

    toggle = Instance.new("TextButton", panel)
    toggle.Size = UDim2.new(0, 230, 0, 34)
    toggle.Position = UDim2.new(0, 0, 0, 0)
    toggle.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.Text = "Stack Rolls: OFF"
    toggle.TextSize = 14
    toggle.Font = Enum.Font.GothamBold
    toggle.BorderSizePixel = 0
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)

    local close = Instance.new("TextButton", panel)
    close.Size = UDim2.new(0, 46, 0, 34)
    close.Position = UDim2.new(1, -46, 0, 0)
    close.BackgroundColor3 = Color3.fromRGB(140, 30, 30)
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Text = "X"
    close.TextSize = 14
    close.Font = Enum.Font.GothamBold
    close.BorderSizePixel = 0
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

    statusLbl = Instance.new("TextLabel", panel)
    statusLbl.Size = UDim2.new(1, -10, 0, 42)
    statusLbl.Position = UDim2.new(0, 5, 0, 42)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
    statusLbl.Text = "G:--   D:--   V:--   X:--\nwaiting for data..."
    statusLbl.TextSize = 11
    statusLbl.Font = Enum.Font.Code
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextWrapped = true

    toggle.MouseButton1Click:Connect(function() setActive(not active) end)
    close.MouseButton1Click:Connect(function()
        if active then reset() end
        g:Destroy()
        _G.StackRolls = nil
    end)
end

-- ── Active state ──────────────────────────────────────────────────────────────
local function setActive(val)
    active = val
    if not _G.MAIN_LOADED and toggle and toggle.Parent then
        toggle.Text = active and "Stack Rolls: ON" or "Stack Rolls: OFF"
        toggle.BackgroundColor3 = active and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(50, 120, 50)
        statusLbl.TextColor3 = active and Color3.fromRGB(80, 180, 255) or Color3.fromRGB(160, 160, 160)
    end
    if not active then reset() end
end

-- ── Public API ────────────────────────────────────────────────────────────────
_G.StackRolls = {
    enable      = function() setActive(true) end,
    disable     = function() setActive(false) end,
    toggle      = function(val)
        if val == nil then setActive(not active) else setActive(val) end
    end,
    isActive    = function() return active end,
    isReleasing = function() return os.clock() - releasedAt < RELEASE_COOLDOWN end,
}
