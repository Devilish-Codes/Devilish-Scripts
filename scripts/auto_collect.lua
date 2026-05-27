local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL = Players.LocalPlayer

local lootSvc = require(RS.Source.Features.Loot.LootServiceClient)

local active = false

-- GUI
local toggle
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "AutoCollect"
    g.IgnoreGuiInset = true
    g.Parent = PL.PlayerGui

    local panel = Instance.new("Frame", g)
    panel.Size = UDim2.new(0, 220, 0, 40)
    panel.Position = UDim2.new(0.5, -110, 0, 108)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)

    toggle = Instance.new("TextButton", panel)
    toggle.Size = UDim2.new(0, 170, 1, 0)
    toggle.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.Text = "AutoCollect: OFF"
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
        _G.AutoCollect = nil
    end)
end

local function setActive(val)
    active = val
    if not _G.MAIN_LOADED and toggle and toggle.Parent then
        toggle.Text = active and "AutoCollect: ON" or "AutoCollect: OFF"
        toggle.BackgroundColor3 = active and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(50, 120, 50)
    end
end

local fruitFilter = {}  -- set of fruit IDs to allow; empty = collect all
local KNOWN_FRUITS = {lightningFruit=true,iceFruit=true,fireFruit=true,universeFruit=true,magicianFruit=true,swordFruit=true}

-- Collect loop: sweep all loot every 0.5s, no per-item threads
task.spawn(function()
    while true do
        task.wait(0.5)
        if not active then continue end
        pcall(function()
            local lootRoot = workspace:FindFirstChild("Loot")
            if not lootRoot then return end
            for _, item in ipairs(lootRoot:GetChildren()) do
                local uniqueId = item.Name
                local obj     = lootSvc.lootById and lootSvc.lootById[uniqueId]
                local lootId  = obj and obj.data and obj.data.lootId  -- e.g. "iceFruit"
                local isFruit = lootId and KNOWN_FRUITS[lootId]
                local allowed = not isFruit or not next(fruitFilter) or fruitFilter[lootId]
                if allowed then pcall(function() lootSvc:requestCollect(uniqueId) end) end
            end
        end)
    end
end)

-- Public API
_G.AutoCollect = {
    enable    = function() setActive(true) end,
    disable   = function() setActive(false) end,
    toggle    = function(val)
        if val == nil then setActive(not active)
        else setActive(val) end
    end,
    isActive  = function() return active end,
    setFilter = function(f) fruitFilter = f or {} end,
    getFilter = function() return fruitFilter end,
}
