local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local PL=game:GetService("Players").LocalPlayer
local rollRF=RS:WaitForChild("RollService"):WaitForChild("RemoteFunction")
local hitRE,shotCount=nil,0
local S={gun=false,roll=false,afk=false}
local rfs={}

local mt=getrawmetatable(game) local oldNC=mt.__namecall
setreadonly(mt,false)
mt.__namecall=function(self,...)
    local args={...}
    if getnamecallmethod()=="FireServer" and not hitRE and args[1]=="confirmHit" then
        hitRE=self shotCount=(args[2] or 0)+1
        setreadonly(mt,false) mt.__namecall=oldNC setreadonly(mt,true)
    end
    return oldNC(self,...)
end
setreadonly(mt,true)

local eids={}
task.spawn(function()
    while true do
        local zones=workspace:FindFirstChild("Zones") local t={}
        if zones then
            for _,z in ipairs(zones:GetChildren()) do
                local ef=z:FindFirstChild("Enemies")
                if ef then for _,e in ipairs(ef:GetChildren()) do local id=tonumber(e.Name) if id then t[#t+1]=id end end end
            end
        end
        eids=t task.wait(2)
    end
end)

local goopLbl=nil
task.spawn(function()
    task.wait(3)
    local pg=PL:WaitForChild("PlayerGui")
    for att=1,15 do
        for _,v in ipairs(pg:GetDescendants()) do
            if v.Name=="CounterRow" and v:IsA("Frame") then
                local cam=workspace.CurrentCamera
                if cam and v.AbsolutePosition.X<cam.ViewportSize.X*0.5 then
                    local amt=v:FindFirstChild("Amount")
                    if amt then local l=amt:FindFirstChildOfClass("TextLabel") if l then goopLbl=l end end
                end
            end
        end
        if goopLbl then break end task.wait(2)
    end
end)

local g=Instance.new("ScreenGui") g.Name="SlimeGui" g.ResetOnSpawn=false
pcall(function()g.Parent=gethui()end)
if not g.Parent then g.Parent=game:GetService("CoreGui")end

local pan=Instance.new("Frame") pan.Size=UDim2.new(0,220,0,10) pan.Position=UDim2.new(0,12,0,12) pan.BackgroundColor3=Color3.fromRGB(20,20,20) pan.BorderSizePixel=0 pan.Parent=g Instance.new("UICorner",pan).CornerRadius=UDim.new(0,8)
local bubble=Instance.new("TextButton") bubble.Size=UDim2.new(0,44,0,44) bubble.Position=UDim2.new(1,-56,0,12) bubble.BackgroundColor3=Color3.fromRGB(35,35,35) bubble.TextColor3=Color3.fromRGB(220,220,220) bubble.Text="S" bubble.TextSize=16 bubble.Font=Enum.Font.GothamBold bubble.BorderSizePixel=0 bubble.Visible=false bubble.Parent=g Instance.new("UICorner",bubble).CornerRadius=UDim.new(1,0)
local ttl=Instance.new("TextLabel") ttl.Size=UDim2.new(1,-68,0,30) ttl.BackgroundColor3=Color3.fromRGB(35,35,35) ttl.TextColor3=Color3.fromRGB(220,220,220) ttl.Text="[ SLIME RNG ]" ttl.TextSize=13 ttl.Font=Enum.Font.GothamBold ttl.BorderSizePixel=0 ttl.Parent=pan Instance.new("UICorner",ttl).CornerRadius=UDim.new(0,8)
local minBtn=Instance.new("TextButton") minBtn.Size=UDim2.new(0,30,0,30) minBtn.Position=UDim2.new(1,-64,0,0) minBtn.BackgroundColor3=Color3.fromRGB(60,60,60) minBtn.TextColor3=Color3.fromRGB(220,220,220) minBtn.Text="_" minBtn.TextSize=16 minBtn.Font=Enum.Font.GothamBold minBtn.BorderSizePixel=0 minBtn.ZIndex=2 minBtn.Parent=pan Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,6)
local stopBtn=Instance.new("TextButton") stopBtn.Size=UDim2.new(0,30,0,30) stopBtn.Position=UDim2.new(1,-32,0,0) stopBtn.BackgroundColor3=Color3.fromRGB(140,30,30) stopBtn.TextColor3=Color3.fromRGB(255,255,255) stopBtn.Text="X" stopBtn.TextSize=14 stopBtn.Font=Enum.Font.GothamBold stopBtn.BorderSizePixel=0 stopBtn.ZIndex=2 stopBtn.Parent=pan Instance.new("UICorner",stopBtn).CornerRadius=UDim.new(0,6)

local dr,ds,ps
ttl.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true ds=i.Position ps=pan.Position end end)
UIS.InputChanged:Connect(function(i)if dr and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds pan.Position=UDim2.new(ps.X.Scale,ps.X.Offset+d.X,ps.Y.Scale,ps.Y.Offset+d.Y)end end)
UIS.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end end)
minBtn.MouseButton1Click:Connect(function()pan.Visible=false bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function()bubble.Visible=false pan.Visible=true end)

local yP=34
local function mkStat(txt)
    local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-10,0,20) l.Position=UDim2.new(0,5,0,yP) l.BackgroundColor3=Color3.fromRGB(28,28,28) l.TextColor3=Color3.fromRGB(160,220,160) l.Text=txt l.TextSize=11 l.Font=Enum.Font.Gotham l.BorderSizePixel=0 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=pan
    local p=Instance.new("UIPadding",l) p.PaddingLeft=UDim.new(0,6) Instance.new("UICorner",l).CornerRadius=UDim.new(0,4) yP=yP+23 return l
end
local lpm=mkStat("Goop/min:  --")
local lph=mkStat("Goop/hr:   --")
local lpd=mkStat("Goop/day:  --")
local lgun=mkStat("Gun: fire once to init")
local sep=Instance.new("Frame") sep.Size=UDim2.new(1,-10,0,1) sep.Position=UDim2.new(0,5,0,yP+3) sep.BackgroundColor3=Color3.fromRGB(55,55,55) sep.BorderSizePixel=0 sep.Parent=pan yP=yP+10

local function T(lbl,key)
    local b=Instance.new("TextButton") b.Size=UDim2.new(1,-10,0,26) b.Position=UDim2.new(0,5,0,yP) b.BorderSizePixel=0 b.TextSize=12 b.Font=Enum.Font.Gotham b.Parent=pan Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
    local function rf()if S[key]then b.Text=lbl.." ON" b.BackgroundColor3=Color3.fromRGB(25,70,25) b.TextColor3=Color3.fromRGB(80,230,80)else b.Text=lbl.." OFF" b.BackgroundColor3=Color3.fromRGB(70,25,25) b.TextColor3=Color3.fromRGB(230,80,80)end end
    b.MouseButton1Click:Connect(function()S[key]=not S[key] rf()end) rf() yP=yP+30 table.insert(rfs,rf)
end
stopBtn.MouseButton1Click:Connect(function()
    for k in pairs(S)do S[k]=false end for _,rf in ipairs(rfs)do rf()end task.wait(0.1) g:Destroy()
end)
T("Auto Gun","gun"); T("Auto Roll","roll"); T("Anti-AFK","afk")
pan.Size=UDim2.new(0,220,0,yP+6)

task.spawn(function()
    while true do
        if S.gun then
            if hitRE then
                for _,id in ipairs(eids) do shotCount=shotCount+1 hitRE:FireServer("confirmHit",shotCount,id) end
                lgun.Text="Gun: ACTIVE ("..#eids.." targets)" lgun.TextColor3=Color3.fromRGB(80,230,80)
            else lgun.Text="Gun: fire once to init" lgun.TextColor3=Color3.fromRGB(230,180,80) end
        end
        task.wait()
    end
end)

task.spawn(function()
    while true do
        if S.roll then pcall(function()rollRF:InvokeServer("requestRoll")end)
        else task.wait(0.1)end
    end
end)

task.spawn(function()
    while true do task.wait(60)
        if S.afk then local h=PL.Character and PL.Character:FindFirstChildOfClass("Humanoid") if h then h.Jump=true end end
    end
end)

task.spawn(function()
    local function fmt(n)
        if n>=1e9 then return string.format("%.1fB",n/1e9) elseif n>=1e6 then return string.format("%.1fM",n/1e6) elseif n>=1e3 then return string.format("%.1fK",n/1e3) else return tostring(math.floor(n))end
    end
    local function pg(t)return tonumber((t:gsub("[^%d]+","")))or 0 end
    local tries=0 while not goopLbl and tries<30 do task.wait(1) tries=tries+1 end
    if not goopLbl then return end
    local base=pg(goopLbl.Text) local t0=tick()
    while goopLbl and goopLbl.Parent do
        task.wait(1)
        local cur=pg(goopLbl.Text) local el=tick()-t0
        if el>=10 then
            local ps=(cur-base)/el
            lpm.Text="Goop/min:  "..fmt(ps*60)
            lph.Text="Goop/hr:   "..fmt(ps*3600)
            lpd.Text="Goop/day:  "..fmt(ps*86400)
        end
    end
end)
warn("[Slime Auto] Ready.")
