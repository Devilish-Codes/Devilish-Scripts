-- delta_fireserver_spy.lua
-- Captures outgoing FireServer/InvokeServer + incoming OnClientEvent.

local RS = game:GetService("ReplicatedStorage")
local PL = game:GetService("Players").LocalPlayer
local active = true
local hooked = {}
local lines = {}
local MAX_LINES = 200

-- GUI parent: try gethui -> CoreGui -> PlayerGui
local guiParent = PL:WaitForChild("PlayerGui")
pcall(function() guiParent = game:GetService("CoreGui") end)
pcall(function() if gethui then guiParent = gethui() end end)

local g = Instance.new("ScreenGui")
g.Name = "DeltaSpyGui"
g.ResetOnSpawn = false
g.IgnoreGuiInset = true
local ok = pcall(function() g.Parent = guiParent end)
if not ok then
    g.Parent = PL:WaitForChild("PlayerGui")
end

-- top bar
local pan = Instance.new("Frame")
pan.Size = UDim2.new(0,256,0,36)
pan.Position = UDim2.new(0.5,-128,0,12)
pan.BackgroundColor3 = Color3.fromRGB(20,20,20)
pan.BorderSizePixel = 0
pan.Parent = g
Instance.new("UICorner", pan).CornerRadius = UDim.new(0,8)

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1,-74,1,-8)
btn.Position = UDim2.new(0,4,0,4)
btn.BackgroundColor3 = Color3.fromRGB(25,70,25)
btn.TextColor3 = Color3.fromRGB(80,230,80)
btn.Text = "SPY ON"
btn.TextSize = 13
btn.Font = Enum.Font.GothamBold
btn.BorderSizePixel = 0
btn.Parent = pan
Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0,28,1,-8)
hideBtn.Position = UDim2.new(1,-68,0,4)
hideBtn.BackgroundColor3 = Color3.fromRGB(40,40,100)
hideBtn.TextColor3 = Color3.fromRGB(180,180,255)
hideBtn.Text = "H"
hideBtn.TextSize = 13
hideBtn.Font = Enum.Font.GothamBold
hideBtn.BorderSizePixel = 0
hideBtn.Parent = pan
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0,6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,28,1,-8)
closeBtn.Position = UDim2.new(1,-32,0,4)
closeBtn.BackgroundColor3 = Color3.fromRGB(140,30,30)
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Text = "X"
closeBtn.TextSize = 13
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = pan
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

-- output window (scale-based)
local win = Instance.new("Frame")
win.Size = UDim2.new(0.92,0,0.48,0)
win.Position = UDim2.new(0.04,0,0,56)
win.BackgroundColor3 = Color3.fromRGB(15,15,15)
win.BorderSizePixel = 0
win.Parent = g
Instance.new("UICorner", win).CornerRadius = UDim.new(0,6)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-8,1,-38)
scroll.Position = UDim2.new(0,4,0,4)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Active = false
scroll.Parent = win

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0,1)
layout.Parent = scroll

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0,70,0,24)
copyBtn.Position = UDim2.new(1,-78,1,-28)
copyBtn.BackgroundColor3 = Color3.fromRGB(0,100,180)
copyBtn.TextColor3 = Color3.fromRGB(255,255,255)
copyBtn.Text = "Copy All"
copyBtn.TextSize = 11
copyBtn.Font = Enum.Font.GothamBold
copyBtn.BorderSizePixel = 0
copyBtn.Parent = win
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0,4)

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0,55,0,24)
clearBtn.Position = UDim2.new(1,-138,1,-28)
clearBtn.BackgroundColor3 = Color3.fromRGB(140,80,0)
clearBtn.TextColor3 = Color3.fromRGB(255,255,255)
clearBtn.Text = "Clear"
clearBtn.TextSize = 11
clearBtn.Font = Enum.Font.GothamBold
clearBtn.BorderSizePixel = 0
clearBtn.Parent = win
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0,4)

-- log
local function log(msg, color)
    lines[#lines+1] = msg
    if #lines > MAX_LINES then
        table.remove(lines, 1)
    end
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-8,0,14)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color or Color3.fromRGB(180,230,180)
    lbl.Text = msg
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Code
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.LayoutOrder = #lines
    lbl.Parent = scroll
    local cnt = 0
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then
            cnt = cnt + 1
        end
    end
    if cnt > MAX_LINES then
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextLabel") then
                c:Destroy()
                break
            end
        end
    end
    scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y)
    scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y))
end

-- serialize
local function ser(v)
    local t = typeof(v)
    if t == "string"  then return '"'..v..'"' end
    if t == "number"  then return tostring(v) end
    if t == "boolean" then return tostring(v) end
    if t == "table" then
        local p = {}
        for k,val in pairs(v) do
            p[#p+1] = tostring(k).."="..ser(val)
        end
        return "{"..table.concat(p,",").."}"
    end
    if t == "Instance" then return "["..v.ClassName..":"..v.Name.."]" end
    if t == "Vector3"  then return string.format("V3(%.1f,%.1f,%.1f)",v.X,v.Y,v.Z) end
    if t == "CFrame"   then return string.format("CF(%.1f,%.1f,%.1f)",v.X,v.Y,v.Z) end
    return "["..t.."]"
end

-- button handlers (connected before hooks so UI is live immediately)
btn.MouseButton1Click:Connect(function()
    active = not active
    if active then
        btn.Text = "SPY ON"
        btn.BackgroundColor3 = Color3.fromRGB(25,70,25)
        btn.TextColor3 = Color3.fromRGB(80,230,80)
        win.Visible = true
    else
        btn.Text = "SPY OFF"
        btn.BackgroundColor3 = Color3.fromRGB(70,25,25)
        btn.TextColor3 = Color3.fromRGB(230,80,80)
        win.Visible = false
    end
end)

hideBtn.MouseButton1Click:Connect(function()
    win.Visible = not win.Visible
    hideBtn.BackgroundColor3 = win.Visible and Color3.fromRGB(40,40,100) or Color3.fromRGB(80,60,20)
    hideBtn.TextColor3 = win.Visible and Color3.fromRGB(180,180,255) or Color3.fromRGB(255,200,80)
end)

closeBtn.MouseButton1Click:Connect(function()
    active = false
    g:Destroy()
end)

copyBtn.MouseButton1Click:Connect(function()
    pcall(setclipboard, table.concat(lines,"\n"))
    copyBtn.Text = "Copied!"
    task.delay(1.5, function()
        if copyBtn and copyBtn.Parent then
            copyBtn.Text = "Copy All"
        end
    end)
end)

clearBtn.MouseButton1Click:Connect(function()
    lines = {}
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then
            c:Destroy()
        end
    end
    scroll.CanvasSize = UDim2.new(0,0,0,0)
end)

log("GUI ready. Setting up hooks...")

-- everything below runs in background so UI is never blocked
task.spawn(function()

    -- outgoing: __namecall hook
    local _inHook = false
    local ncOk = pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local oldNC = mt.__namecall
        mt.__namecall = function(self, ...)
            if not _inHook then
                _inHook = true
                local args = {...}
                pcall(function()
                    local method = getnamecallmethod()
                    if active and (method == "FireServer" or method == "InvokeServer") then
                        local _, isRE = pcall(function() return self:IsA("RemoteEvent") end)
                        local _, isRF = pcall(function() return self:IsA("RemoteFunction") end)
                        if isRE or isRF then
                            local path = (self.Parent and self.Parent.Name or "?").."."..self.Name
                            local p = {}
                            for i,v in ipairs(args) do
                                p[i] = ser(v)
                            end
                            log("[->] "..path.." | "..table.concat(p,", "), Color3.fromRGB(255,220,80))
                        end
                    end
                end)
                _inHook = false
            end
            return oldNC(self, ...)
        end
        setreadonly(mt, true)
    end)
    log("__namecall: "..(ncOk and "OK - outgoing calls captured" or "FAILED - outgoing only"))

    -- incoming: hook all RemoteEvents
    local function hookRE(re)
        if hooked[re] then return end
        hooked[re] = true
        local path = (re.Parent and re.Parent.Name or "?").."."..re.Name
        re.OnClientEvent:Connect(function(...)
            if not active then return end
            local args = {...}
            local p = {}
            for i,v in ipairs(args) do
                p[i] = ser(v)
            end
            log("[RE] "..path.." | "..table.concat(p,", "))
        end)
    end

    local function hookAll(root)
        pcall(function()
            for _,v in ipairs(root:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    hookRE(v)
                end
            end
            root.DescendantAdded:Connect(function(v)
                if v:IsA("RemoteEvent") then
                    hookRE(v)
                end
            end)
        end)
    end

    hookAll(RS)
    hookAll(workspace)

    local cnt = 0
    for _ in pairs(hooked) do
        cnt = cnt + 1
    end
    log("Hooked "..cnt.." RemoteEvents | Yellow=outgoing  Green=incoming")
end)
