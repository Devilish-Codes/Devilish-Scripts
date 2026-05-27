local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL = Players.LocalPlayer

local active     = false
local zonesTable = {}
local zonesModule, dataClient, zonesRF
local dataReady  = false

-- Build zone teleport positions
task.spawn(function()
    local zonesFolder = workspace:WaitForChild("Zones", 30)
    if not zonesFolder then return end
    for _, zone in ipairs(zonesFolder:GetChildren()) do
        if zone:FindFirstChild("POI") and zone.POI:FindFirstChild("Baseplate") then
            zonesTable[tonumber(zone.Name)] = zone.POI.Baseplate.Position + Vector3.new(0, 3, 0)
        end
    end
end)

-- Load modules/remotes
task.spawn(function()
    for _ = 1, 60 do
        pcall(function()
            if not zonesModule then zonesModule = require(RS.Source.Game.Items.Zones) end
            if not dataClient  then dataClient  = require(RS.Packages.DataService).client end
            if not zonesRF     then zonesRF     = RS.Packages._Index["leifstout_networker@0.3.1"].networker._remotes.ZonesService.RemoteFunction end
        end)
        if zonesModule and dataClient and zonesRF then dataReady = true break end
        task.wait(0.5)
    end
end)

-- GUI
local toggle
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "AutoBuyZone"
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
    toggle.Text = "Auto Buy Zone: OFF"
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
        _G.AutoBuyZone = nil
    end)
end

local function setActive(val)
    active = val
    if not _G.MAIN_LOADED and toggle and toggle.Parent then
        toggle.Text = active and "Auto Buy Zone: ON" or "Auto Buy Zone: OFF"
        toggle.BackgroundColor3 = active and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(50, 120, 50)
    end
end

-- Buy loop: only purchase when player can afford the next zone
task.spawn(function()
    while true do
        task.wait(1)
        if not active or not dataReady then continue end
        pcall(function()
            local currentZone = math.max(dataClient:get("maxZone") or 1, 1)
            local nextZoneData = zonesModule.getZone(currentZone + 1)
            if nextZoneData and dataClient:get("coins") >= nextZoneData.price then
                zonesRF:InvokeServer("requestPurchaseZone")
            end
            local pos = zonesTable[currentZone]
            if pos then
                local char = PL.Character
                if char and (char:GetPivot().Position - pos).Magnitude > 20 then
                    char:PivotTo(CFrame.new(pos))
                end
            end
        end)
    end
end)

_G.AutoBuyZone = {
    enable   = function() setActive(true) end,
    disable  = function() setActive(false) end,
    toggle   = function(val)
        if val == nil then setActive(not active) else setActive(val) end
    end,
    isActive = function() return active end,
}
