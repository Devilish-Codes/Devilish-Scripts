local IGNORE = {AutoRejoinService=true}
local active = true

-- toggle button
local g=Instance.new("ScreenGui") g.Name="SpyGui" g.ResetOnSpawn=false
pcall(function()g.Parent=gethui()end)
if not g.Parent then g.Parent=game:GetService("CoreGui")end
local btn=Instance.new("TextButton") btn.Size=UDim2.new(0,120,0,32) btn.Position=UDim2.new(1,-132,0,12) btn.BackgroundColor3=Color3.fromRGB(25,70,25) btn.TextColor3=Color3.fromRGB(80,230,80) btn.Text="SPY ON" btn.TextSize=13 btn.Font=Enum.Font.GothamBold btn.BorderSizePixel=0 btn.Parent=g Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
btn.MouseButton1Click:Connect(function()
    active=not active
    if active then btn.Text="SPY ON" btn.BackgroundColor3=Color3.fromRGB(25,70,25) btn.TextColor3=Color3.fromRGB(80,230,80)
    else btn.Text="SPY OFF" btn.BackgroundColor3=Color3.fromRGB(70,25,25) btn.TextColor3=Color3.fromRGB(230,80,80) end
end)

local mt = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)
mt.__namecall = function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if active and (method=="FireServer" or method=="InvokeServer") and not IGNORE[self.Parent and self.Parent.Name or ""] then
        local parts = {}
        for _, v in ipairs(args) do
            local t = typeof(v)
            if t=="string" or t=="number" or t=="boolean" then
                parts[#parts+1] = tostring(v)
            elseif t=="Instance" then
                parts[#parts+1] = "[Instance:"..v.ClassName..":"..v.Name.."]"
            else
                parts[#parts+1] = "["..t.."]"
            end
        end
        local svc = (self.Parent and self.Parent.Name or "?") .. "." .. self.Name
        print("["..method.."] "..svc.."("..table.concat(parts,", ")..")")
    end
    return old(self, ...)
end
setreadonly(mt, true)
print("Slime Spy ON")
