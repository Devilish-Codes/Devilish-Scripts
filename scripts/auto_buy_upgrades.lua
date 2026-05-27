local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL      = Players.LocalPlayer
while not PL do task.wait() PL = Players.LocalPlayer end
while not RS:FindFirstChild("Source") do task.wait(0.5) end

-- ── Services ───────────────────────────────────────────────────────────────────
local upgSvc, dataClient, upgradeTree

task.spawn(function()
    for _ = 1, 60 do
        pcall(function()
            if not upgSvc      then upgSvc      = require(RS.Source.Features.Upgrades.UpgradeServiceClient) end
            if not dataClient  then dataClient  = require(RS.Packages.DataService).client end
            if not upgradeTree then upgradeTree = require(RS.Source.Features.Upgrades.UpgradeTree) end
        end)
        if upgSvc and dataClient and upgradeTree then break end
        task.wait(0.5)
    end
end)

-- ── State ──────────────────────────────────────────────────────────────────────
local active = false
local ORIGIN = "origin"  -- UpgradeServiceUtils.enums.originDependency

-- ── Buy logic ─────────────────────────────────────────────────────────────────
local function getBalance(currency)
    local ok, v = pcall(function() return dataClient:get(currency) end)
    return (ok and type(v) == "number") and v or 0
end

local function tryBuyAll()
    if not (upgSvc and upgSvc.networker and dataClient and upgradeTree) then return end

    -- Keep buying until a full pass yields nothing new
    local bought = true
    while bought do
        bought = false
        local owned = dataClient:get("upgrades") or {}

        for _, tree in pairs(upgradeTree) do
            for id, node in pairs(tree) do
                if not node.cost then continue end
                if owned[id] then continue end

                -- dependency must be satisfied
                local dep = node.dependency
                if dep ~= ORIGIN and not owned[dep] then continue end

                -- must be able to afford it
                if getBalance(node.cost.currency) < node.cost.amount then continue end

                -- attempt purchase
                local ok, result = pcall(function()
                    return upgSvc.networker:fetch("requestUnlock", id)
                end)
                if ok and result then
                    bought = true
                end
                task.wait(0.15)
            end
        end
    end
end

-- ── Loop ──────────────────────────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(2)
        if not active then continue end
        pcall(tryBuyAll)
    end
end)

-- ── GUI ───────────────────────────────────────────────────────────────────────
local toggle
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "AutoBuyUpgrades"
    g.IgnoreGuiInset = true
    g.Parent = PL.PlayerGui

    local panel = Instance.new("Frame", g)
    panel.Size = UDim2.new(0, 220, 0, 40)
    panel.Position = UDim2.new(0.5, -110, 0, 12)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)

    toggle = Instance.new("TextButton", panel)
    toggle.Size = UDim2.new(0, 170, 1, 0)
    toggle.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.Text = "Auto Buy Upgrades: OFF"
    toggle.TextSize = 13
    toggle.Font = Enum.Font.GothamBold
    toggle.BorderSizePixel = 0
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)

    local close = Instance.new("TextButton", panel)
    close.Size = UDim2.new(0, 46, 1, 0)
    close.Position = UDim2.new(1, -46, 0, 0)
    close.BackgroundColor3 = Color3.fromRGB(140, 30, 30)
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Text = "X"
    close.TextSize = 14
    close.Font = Enum.Font.GothamBold
    close.BorderSizePixel = 0
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

    toggle.MouseButton1Click:Connect(function() setActive(not active) end)
    close.MouseButton1Click:Connect(function()
        active = false
        g:Destroy()
        _G.AutoBuyUpgrades = nil
    end)
end

local function setActive(val)
    active = val
    if not _G.MAIN_LOADED and toggle and toggle.Parent then
        toggle.Text = active and "Auto Buy Upgrades: ON" or "Auto Buy Upgrades: OFF"
        toggle.BackgroundColor3 = active and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(50, 120, 50)
    end
end

-- ── Public API ─────────────────────────────────────────────────────────────────
_G.AutoBuyUpgrades = {
    enable   = function() setActive(true) end,
    disable  = function() setActive(false) end,
    toggle   = function(val)
        if val == nil then setActive(not active) else setActive(val) end
    end,
    isActive = function() return active end,
}
