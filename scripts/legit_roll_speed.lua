local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL = Players.LocalPlayer

local active = false
local rollRF = nil

task.spawn(function()
    for _ = 1, 40 do
        for _, v in ipairs(RS:GetDescendants()) do
            if v.Name == "RollService" and v:IsA("Folder") then
                local r = v:FindFirstChildOfClass("RemoteFunction")
                if r then rollRF = r return end
            end
        end
        task.wait(0.5)
    end
end)

local toggle
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "LegitRollSpeed"
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
    toggle.Text = "Legit Roll Speed: OFF"
    toggle.TextSize = 12
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
        _G.LegitRollSpeed = nil
    end)
end

local function setActive(val)
    active = val
    if not _G.MAIN_LOADED and toggle and toggle.Parent then
        toggle.Text = active and "Legit Roll Speed: ON" or "Legit Roll Speed: OFF"
        toggle.BackgroundColor3 = active and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(50, 120, 50)
    end
end

task.spawn(function()
    while true do
        if active and rollRF then
            pcall(function() rollRF:InvokeServer("requestRoll") end)
            task.wait(1.4)
        else
            task.wait(0.1)
        end
    end
end)

_G.LegitRollSpeed = {
    enable   = function() setActive(true) end,
    disable  = function() setActive(false) end,
    toggle   = function(val)
        if val == nil then setActive(not active)
        else setActive(val) end
    end,
    isActive = function() return active end,
}
