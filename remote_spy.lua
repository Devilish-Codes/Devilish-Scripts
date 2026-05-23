-- Remote Spy | Delta Executor
-- Toggle button top-right. Default: OFF.

local IGNORE = { AutoRejoinActivity = true, GainQi = true }
local spyEnabled = false

-- ── GUI ───────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "RemoteSpyGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = gethui() end)
if not gui.Parent then
    gui.Parent = game:GetService("CoreGui")
end

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 140, 0, 36)
btn.Position = UDim2.new(1, -150, 0, 10)
btn.AnchorPoint = Vector2.new(0, 0)
btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
btn.BorderSizePixel = 0
btn.TextColor3 = Color3.fromRGB(255, 80, 80)
btn.TextSize = 15
btn.Font = Enum.Font.GothamBold
btn.Text = "SPY: OFF"
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = btn

local function updateBtn()
    if spyEnabled then
        btn.Text = "SPY: ON"
        btn.TextColor3 = Color3.fromRGB(80, 255, 80)
        btn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
    else
        btn.Text = "SPY: OFF"
        btn.TextColor3 = Color3.fromRGB(255, 80, 80)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end

btn.MouseButton1Click:Connect(function()
    spyEnabled = not spyEnabled
    updateBtn()
    warn("[RemoteSpy] " .. (spyEnabled and "ON" or "OFF"))
end)

-- ── Hook ──────────────────────────────────────────────────────────────────────
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = function(self, ...)
    local method = getnamecallmethod()

    if spyEnabled then
        pcall(function()
            if IGNORE[self.Name] then return end
            local args = {...}
            local parts = {}
            for _, v in ipairs(args) do
                local t = typeof(v)
                if t == "string" or t == "number" or t == "boolean" then
                    table.insert(parts, tostring(v))
                else
                    table.insert(parts, "[" .. t .. "]")
                end
            end
            local line = "[" .. method .. "] " .. self.Name .. "(" .. table.concat(parts, ", ") .. ")"
            if method == "FireServer" or method == "InvokeServer" then
                warn(line)
            end
        end)
    end

    return oldNamecall(self, ...)
end

setreadonly(mt, true)

warn("[RemoteSpy] Loaded — click the button top-right to enable.")
