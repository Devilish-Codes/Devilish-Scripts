local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local PL=Players.LocalPlayer
while not PL do task.wait() PL=Players.LocalPlayer end
local active=true local hooked={} local lines={} local MAX=200
local gp=game:GetService("CoreGui")
pcall(function() if gethui then gp=gethui() end end)
local g=Instance.new("ScreenGui") g.Name="PotSpy" g.ResetOnSpawn=false g.IgnoreGuiInset=true
pcall(function()g.Parent=gp end) if not g.Parent then g.Parent=PL.PlayerGui end
local pan=Instance.new("Frame") pan.Size=UDim2.new(0,256,0,36) pan.Position=UDim2.new(0.5,-128,0,12) pan.BackgroundColor3=Color3.fromRGB(20,20,20) pan.BorderSizePixel=0 pan.Parent=g Instance.new("UICorner",pan).CornerRadius=UDim.new(0,8)
local btn=Instance.new("TextButton") btn.Size=UDim2.new(1,-74,1,-8) btn.Position=UDim2.new(0,4,0,4) btn.BackgroundColor3=Color3.fromRGB(25,70,25) btn.TextColor3=Color3.fromRGB(80,230,80) btn.Text="SPY ON" btn.TextSize=13 btn.Font=Enum.Font.GothamBold btn.BorderSizePixel=0 btn.Parent=pan Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
local hBtn=Instance.new("TextButton") hBtn.Size=UDim2.new(0,28,1,-8) hBtn.Position=UDim2.new(1,-68,0,4) hBtn.BackgroundColor3=Color3.fromRGB(40,40,100) hBtn.TextColor3=Color3.fromRGB(180,180,255) hBtn.Text="H" hBtn.TextSize=13 hBtn.Font=Enum.Font.GothamBold hBtn.BorderSizePixel=0 hBtn.Parent=pan Instance.new("UICorner",hBtn).CornerRadius=UDim.new(0,6)
local xBtn=Instance.new("TextButton") xBtn.Size=UDim2.new(0,28,1,-8) xBtn.Position=UDim2.new(1,-32,0,4) xBtn.BackgroundColor3=Color3.fromRGB(140,30,30) xBtn.TextColor3=Color3.fromRGB(255,255,255) xBtn.Text="X" xBtn.TextSize=13 xBtn.Font=Enum.Font.GothamBold xBtn.BorderSizePixel=0 xBtn.Parent=pan Instance.new("UICorner",xBtn).CornerRadius=UDim.new(0,6)
local win=Instance.new("Frame") win.Size=UDim2.new(0.92,0,0.48,0) win.Position=UDim2.new(0.04,0,0,56) win.BackgroundColor3=Color3.fromRGB(15,15,15) win.BorderSizePixel=0 win.Parent=g Instance.new("UICorner",win).CornerRadius=UDim.new(0,6)
local sc=Instance.new("ScrollingFrame") sc.Size=UDim2.new(1,-8,1,-38) sc.Position=UDim2.new(0,4,0,4) sc.BackgroundTransparency=1 sc.BorderSizePixel=0 sc.ScrollBarThickness=4 sc.CanvasSize=UDim2.new(0,0,0,0) sc.ScrollingDirection=Enum.ScrollingDirection.Y sc.Active=false sc.Parent=win
local lay=Instance.new("UIListLayout") lay.SortOrder=Enum.SortOrder.LayoutOrder lay.Padding=UDim.new(0,1) lay.Parent=sc
local cpBtn=Instance.new("TextButton") cpBtn.Size=UDim2.new(0,70,0,24) cpBtn.Position=UDim2.new(1,-78,1,-28) cpBtn.BackgroundColor3=Color3.fromRGB(0,100,180) cpBtn.TextColor3=Color3.fromRGB(255,255,255) cpBtn.Text="Copy All" cpBtn.TextSize=11 cpBtn.Font=Enum.Font.GothamBold cpBtn.BorderSizePixel=0 cpBtn.Parent=win Instance.new("UICorner",cpBtn).CornerRadius=UDim.new(0,4)
local clBtn=Instance.new("TextButton") clBtn.Size=UDim2.new(0,55,0,24) clBtn.Position=UDim2.new(1,-138,1,-28) clBtn.BackgroundColor3=Color3.fromRGB(140,80,0) clBtn.TextColor3=Color3.fromRGB(255,255,255) clBtn.Text="Clear" clBtn.TextSize=11 clBtn.Font=Enum.Font.GothamBold clBtn.BorderSizePixel=0 clBtn.Parent=win Instance.new("UICorner",clBtn).CornerRadius=UDim.new(0,4)
local function log(msg,col)
    lines[#lines+1]=msg if #lines>MAX then table.remove(lines,1) end
    local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-8,0,14) l.BackgroundTransparency=1 l.TextColor3=col or Color3.fromRGB(180,230,180) l.Text=msg l.TextSize=11 l.Font=Enum.Font.Code l.TextXAlignment=Enum.TextXAlignment.Left l.TextTruncate=Enum.TextTruncate.AtEnd l.LayoutOrder=#lines l.Parent=sc
    local cnt=0 for _,c in ipairs(sc:GetChildren()) do if c:IsA("TextLabel") then cnt=cnt+1 end end
    if cnt>MAX then for _,c in ipairs(sc:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() break end end end
    sc.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y)
    sc.CanvasPosition=Vector2.new(0,math.max(0,sc.CanvasSize.Y.Offset-sc.AbsoluteSize.Y))
end
local function ser(v)
    local t=typeof(v)
    if t=="string" then return'"'..v..'"' end if t=="number" or t=="boolean" then return tostring(v) end
    if t=="table" then local p={} for k,val in pairs(v) do p[#p+1]=tostring(k).."="..ser(val) end return"{"..table.concat(p,",").."}" end
    if t=="Instance" then return"["..v.ClassName..":"..v.Name.."]" end
    if t=="Vector3" then return string.format("V3(%.1f,%.1f,%.1f)",v.X,v.Y,v.Z) end
    if t=="CFrame" then return string.format("CF(%.1f,%.1f,%.1f)",v.X,v.Y,v.Z) end
    return"["..t.."]"
end
btn.MouseButton1Click:Connect(function() active=not active if active then btn.Text="SPY ON" btn.BackgroundColor3=Color3.fromRGB(25,70,25) btn.TextColor3=Color3.fromRGB(80,230,80) win.Visible=true else btn.Text="SPY OFF" btn.BackgroundColor3=Color3.fromRGB(70,25,25) btn.TextColor3=Color3.fromRGB(230,80,80) win.Visible=false end end)
hBtn.MouseButton1Click:Connect(function() win.Visible=not win.Visible hBtn.BackgroundColor3=win.Visible and Color3.fromRGB(40,40,100) or Color3.fromRGB(80,60,20) hBtn.TextColor3=win.Visible and Color3.fromRGB(180,180,255) or Color3.fromRGB(255,200,80) end)
xBtn.MouseButton1Click:Connect(function() active=false g:Destroy() end)
cpBtn.MouseButton1Click:Connect(function() pcall(setclipboard,table.concat(lines,"\n")) cpBtn.Text="Copied!" task.delay(1.5,function()if cpBtn and cpBtn.Parent then cpBtn.Text="Copy All" end end) end)
clBtn.MouseButton1Click:Connect(function() lines={} for _,c in ipairs(sc:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end sc.CanvasSize=UDim2.new(0,0,0,0) end)
log("GUI ready. Setting up hooks...")
task.spawn(function()
    local ncOk=pcall(function()
        local mt=getrawmetatable(game)
        if setreadonly then setreadonly(mt,false) end
        local old=mt.__namecall
        mt.__namecall=function(self,...)
            local m=(getnamecallmethod and getnamecallmethod()) or ({...})[1]
            if active and(m=="FireServer" or m=="InvokeServer") then
                pcall(function()
                    local ok1,isRE=pcall(function()return self:IsA("RemoteEvent")end)
                    local ok2,isRF=pcall(function()return self:IsA("RemoteFunction")end)
                    if(ok1 and isRE)or(ok2 and isRF)then
                        local path=(self.Parent and self.Parent.Name or"?").."."..self.Name
                        local args={...} local p={} local start=(getnamecallmethod and getnamecallmethod())and 1 or 2
                        for i=start,#args do p[#p+1]=ser(args[i]) end
                        log(((ok2 and isRF)and"[RF->] "or"[->] ")..path.." | "..table.concat(p,", "),Color3.fromRGB(255,220,80))
                    end
                end)
            end
            return old(self,...)
        end
        if setreadonly then setreadonly(mt,true) end
    end)
    log("__namecall: "..(ncOk and"OK"or"FAILED"))
    local function hookRE(re)
        if hooked[re] then return end hooked[re]=true
        local path=(re.Parent and re.Parent.Name or"?").."."..re.Name
        re.OnClientEvent:Connect(function(...) if not active then return end local args={...} local p={} for i,v in ipairs(args) do p[i]=ser(v) end log("[RE] "..path.." | "..table.concat(p,", ")) end)
    end
    local function hookAll(root) pcall(function() for _,v in ipairs(root:GetDescendants()) do if v:IsA("RemoteEvent") then hookRE(v) end end root.DescendantAdded:Connect(function(v) if v:IsA("RemoteEvent") then hookRE(v) end end) end) end
    hookAll(RS) hookAll(workspace)
    local cnt=0 for _ in pairs(hooked) do cnt=cnt+1 end
    log("Hooked "..cnt.." RemoteEvents | Yellow=outgoing  Green=incoming")
end)
