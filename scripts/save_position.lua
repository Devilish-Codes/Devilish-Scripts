local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local PL = Players.LocalPlayer

local savedPos = nil
local POS_FILE = "slime_rng_pos.txt"

local function savePosFile()
    if not savedPos then return end
    local str = savedPos.X..","..savedPos.Y..","..savedPos.Z
    local ok = pcall(writefile, POS_FILE, str)
    if not ok then
        local store = CoreGui:FindFirstChild("_SlimeRNGPos")
            or Instance.new("StringValue", CoreGui)
        store.Name = "_SlimeRNGPos"
        store.Value = str
    end
end

local function loadPosFile()
    local ok, d = pcall(readfile, POS_FILE)
    if not ok or not d then
        local store = CoreGui:FindFirstChild("_SlimeRNGPos")
        if store then d = store.Value ok = true end
    end
    if not ok or not d then return end
    local x, y, z = d:match("^([-%.%d]+),([-%.%d]+),([-%.%d]+)$")
    if x then savedPos = Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
end
loadPosFile()

local function doSave()
    local char = PL.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        savedPos = hrp.Position + Vector3.new(0, 1, 0)
        savePosFile()
        return true
    end
    return false
end

-- GUI
if not _G.MAIN_LOADED then
    local g = Instance.new("ScreenGui")
    g.ResetOnSpawn = false
    g.Name = "SavePosition"
    g.IgnoreGuiInset = true
    g.Parent = PL.PlayerGui

    local panel = Instance.new("Frame", g)
    panel.Size = UDim2.new(0, 220, 0, 40)
    panel.Position = UDim2.new(0.5, -110, 0, 12)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)

    local saveBtn = Instance.new("TextButton", panel)
    saveBtn.Size = UDim2.new(0, 170, 1, 0)
    saveBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 80)
    saveBtn.TextColor3 = Color3.fromRGB(120, 180, 255)
    saveBtn.Text = savedPos and "Position Loaded" or "Save Position"
    saveBtn.TextSize = 14
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.BorderSizePixel = 0
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 6)

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

    saveBtn.MouseButton1Click:Connect(function()
        if doSave() then
            saveBtn.Text = "Saved!"
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then saveBtn.Text = "Save Position" end
            end)
        end
    end)

    close.MouseButton1Click:Connect(function()
        g:Destroy()
        _G.SavePosition = nil
    end)
end

-- Public API
_G.SavePosition = {
    save        = function() return doSave() end,
    getPosition = function() return savedPos end,
}
