local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL = Players.LocalPlayer

local zoneSvc = require(RS.Source.Features.Zones.ZonesServiceClient)

local active  = false
local lastMax = 0

-- GUI
local toggle
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "AutoTeleportZone"
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
    toggle.Text = "Auto Tele Zone: OFF"
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
        _G.AutoTeleportZone = nil
    end)
end

local function setActive(val)
    active = val
    if not _G.MAIN_LOADED and toggle and toggle.Parent then
        toggle.Text = active and "Auto Tele Zone: ON" or "Auto Tele Zone: OFF"
        toggle.BackgroundColor3 = active and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(50, 120, 50)
    end
    if active then
        -- seed lastMax so we don't immediately teleport on enable
        pcall(function() lastMax = zoneSvc:getMaxZone() end)
    end
end

-- Poll for new zones every 2s, teleport when maxZone increases
task.spawn(function()
    while true do
        task.wait(2)
        if active then
            pcall(function()
                local max = zoneSvc:getMaxZone()
                if max > lastMax then
                    lastMax = max
                    zoneSvc:teleportToZone(max)
                end
            end)
        end
    end
end)

_G.AutoTeleportZone = {
    enable   = function() setActive(true) end,
    disable  = function() setActive(false) end,
    toggle   = function(val)
        if val == nil then setActive(not active) else setActive(val) end
    end,
    isActive = function() return active end,
}
