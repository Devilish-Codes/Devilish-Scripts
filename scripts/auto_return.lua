local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local PL = Players.LocalPlayer

local active = false
local POS_FILE = "slime_rng_pos.txt"

local function loadPosFile()
    local ok, d = pcall(readfile, POS_FILE)
    if not ok or not d then
        local store = CoreGui:FindFirstChild("_SlimeRNGPos")
        if store then d = store.Value ok = true end
    end
    if not ok or not d then return nil end
    local x, y, z = d:match("^([-%.%d]+),([-%.%d]+),([-%.%d]+)$")
    if x then return Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
end

local function getSavedPos()
    if _G.SavePosition then return _G.SavePosition.getPosition() end
    return loadPosFile()
end

-- GUI
local toggle
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "AutoReturn"
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
    toggle.Text = "AutoReturn: OFF"
    toggle.TextSize = 14
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
        _G.AutoReturn = nil
    end)
end

local function setActive(val)
    active = val
    if not _G.MAIN_LOADED and toggle and toggle.Parent then
        toggle.Text = active and "AutoReturn: ON" or "AutoReturn: OFF"
        toggle.BackgroundColor3 = active and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(50, 120, 50)
    end
end

-- Return loop
task.spawn(function()
    while true do
        task.wait(1)
        if active then
            pcall(function()
                local savedPos = getSavedPos()
                if not savedPos then return end
                local char = PL.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - savedPos).Magnitude > 20 then
                    PL.Character:PivotTo(CFrame.new(savedPos))
                end
            end)
        end
    end
end)

-- Public API
_G.AutoReturn = {
    enable   = function() setActive(true) end,
    disable  = function() setActive(false) end,
    toggle   = function(val)
        if val == nil then setActive(not active)
        else setActive(val) end
    end,
    isActive = function() return active end,
}
