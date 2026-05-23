-- Remote Spy | Paste directly into Delta
-- Play the game normally for 30-60 seconds, then check clipboard for captured calls

local log = {}
local RS = game:GetService("ReplicatedStorage")
local remoteFolder = RS:FindFirstChild("RemoteEvents")
if not remoteFolder then
    warn("[RemoteSpy] Could not find RemoteEvents folder")
    return
end

local function serialize(val)
    local t = typeof(val)
    if t == "string"  then return '"' .. val .. '"' end
    if t == "number"  then return tostring(val) end
    if t == "boolean" then return tostring(val) end
    if t == "nil"     then return "nil" end
    if t == "table"   then
        local parts = {}
        for k, v in pairs(val) do
            table.insert(parts, tostring(k) .. "=" .. serialize(v))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return "[" .. t .. "]"
end

local hooked = 0

for _, remote in ipairs(remoteFolder:GetChildren()) do
    if remote:IsA("RemoteEvent") then
        local name = remote.Name
        local orig = remote.FireServer
        remote.FireServer = function(self, ...)
            local args = {...}
            local parts = {}
            for _, v in ipairs(args) do
                table.insert(parts, serialize(v))
            end
            local line = name .. "(" .. table.concat(parts, ", ") .. ")"
            table.insert(log, line)
            print("[Spy] " .. line)
            return orig(self, ...)
        end
        hooked = hooked + 1
    elseif remote:IsA("RemoteFunction") then
        local name = remote.Name
        local orig = remote.InvokeServer
        remote.InvokeServer = function(self, ...)
            local args = {...}
            local parts = {}
            for _, v in ipairs(args) do
                table.insert(parts, serialize(v))
            end
            local line = name .. ":Invoke(" .. table.concat(parts, ", ") .. ")"
            table.insert(log, line)
            print("[Spy] " .. line)
            return orig(self, ...)
        end
        hooked = hooked + 1
    end
end

print("[RemoteSpy] Hooked " .. hooked .. " remotes. Play normally, then press the copy button.")

-- GUI: simple copy button in corner
local guiParent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")

local old = guiParent:FindFirstChild("RemoteSpy")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "RemoteSpy"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = guiParent

local btn = Instance.new("TextButton")
btn.Size             = UDim2.new(0, 160, 0, 36)
btn.Position         = UDim2.new(0, 10, 0, 10)
btn.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
btn.BorderSizePixel  = 0
btn.TextColor3       = Color3.fromRGB(255, 255, 255)
btn.Text             = "Copy Log (" .. #log .. " calls)"
btn.Font             = Enum.Font.GothamBold
btn.TextSize         = 13
btn.Parent           = gui

Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

-- update button label every second
task.spawn(function()
    while gui.Parent do
        btn.Text = "Copy Log (" .. #log .. " calls)"
        task.wait(1)
    end
end)

btn.MouseButton1Click:Connect(function()
    if #log == 0 then
        btn.Text = "No calls yet!"
    else
        setclipboard(table.concat(log, "\n"))
        btn.Text = "Copied " .. #log .. " calls!"
    end
    task.delay(2, function()
        btn.Text = "Copy Log (" .. #log .. " calls)"
    end)
end)
