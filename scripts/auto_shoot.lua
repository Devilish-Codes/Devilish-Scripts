local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PL = Players.LocalPlayer

local goopSvc = require(RS.Source.Features.GoopGun.GoopGunServiceClient)
local gameplaySvc = require(RS.Source.Features.Gameplay.GameplayServiceClient)

local MAX_RANGE = 200
local active = false

-- GUI
local toggle
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "AutoShoot"
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
    toggle.Text = "AutoShoot: OFF"
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
        _G.AutoShoot = nil
    end)
end

local function setActive(val)
    active = val
    if not _G.MAIN_LOADED and toggle and toggle.Parent then
        toggle.Text = active and "AutoShoot: ON" or "AutoShoot: OFF"
        toggle.BackgroundColor3 = active and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(50, 120, 50)
    end
end

-- Fire loop: focus one enemy until dead, then immediately switch to next lowest-HP
local target = nil
task.spawn(function()
    while true do
        task.wait(0.05)
        if not active then continue end
        pcall(function()
            local gameplay = gameplaySvc.gameplay
            if not gameplay or not gameplay.enemies then return end

            -- Cull dead target
            if target then
                local e = gameplay.enemies[target]
                if not (e and e.model and e.model.Parent
                    and (e.health == nil or e.health > 0)) then
                    target = nil
                end
            end

            -- Pick lowest-HP alive enemy within range
            if not target then
                local char = PL.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local origin = hrp and hrp.Position
                local bestId, bestHp = nil, math.huge
                for eid, e in pairs(gameplay.enemies) do
                    if e and e.model and e.model.Parent
                        and (e.health == nil or e.health > 0) then
                        local hp = e.health or 0
                        if hp < bestHp then
                            if origin then
                                local ok, epos = pcall(function() return e.model:GetPivot().Position end)
                                if not ok or (epos - origin).Magnitude > MAX_RANGE then continue end
                            end
                            bestHp = hp
                            bestId = eid
                        end
                    end
                end
                target = bestId
            end

            -- Fire at target
            if target then
                pcall(function()
                    goopSvc.networker:fetch("tryFireSlimeGun", target)
                end)
            end
        end)
    end
end)

-- Public API
_G.AutoShoot = {
    enable  = function() setActive(true) end,
    disable = function() setActive(false) end,
    toggle  = function(val)
        if val == nil then setActive(not active)
        else setActive(val) end
    end,
    isActive = function() return active end,
}
