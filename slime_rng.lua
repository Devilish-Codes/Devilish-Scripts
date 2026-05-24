local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local PL=game:GetService("Players").LocalPlayer

local rollRF=nil
task.spawn(function()
    for _=1,20 do
        for _,v in ipairs(RS:GetDescendants()) do
            if v.Name=="RollService" and v:IsA("Folder") then
                local r=v:FindFirstChildOfClass("RemoteFunction") if r then rollRF=r return end
            end
        end task.wait(0.5)
    end
end)

local hitRE,gunRF,shotCount=nil,nil,0
local S={gun=false,roll=false,afk=false,collect=false}
local rfs={}

local SAVE_FILE="slime_rng_state.txt"
local SKEYS={"gun","roll","afk","collect"}
local function saveState()
    local parts={}
    for _,k in ipairs(SKEYS) do parts[#parts+1]=k.."="..(S[k] and "1" or "0") end
    pcall(writefile,SAVE_FILE,table.concat(parts,";"))
end
local function loadState()
    local ok,data=pcall(readfile,SAVE_FILE)
    if not ok or not data then return end
    for pair in data:gmatch("[^;]+") do
        local k,v=pair:match("^(.-)=(.+)$")
        if k and S[k]~=nil then S[k]=(v=="1") end
    end
end
loadState()

task.spawn(function()
    task.wait(1)
    local function scan()
        local bestN=-1
        for _,v in ipairs(RS:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local n=v.Parent and tonumber(v.Parent.Name:match("^Gameplay(%d+)$"))
                if n and n>bestN then hitRE=v bestN=n end
            end
            if v:IsA("RemoteFunction") and v.Parent and v.Parent.Name=="SlimeGunService" then
                gunRF=v
            end
        end
    end
    -- scan until both found, then every 30s to handle server changes
    while not (hitRE and gunRF) do scan() task.wait(3) end
    while true do task.wait(30) scan() end
end)

local eids={}
task.spawn(function()
    while true do
        local t={}
        for _,v in ipairs(workspace:GetChildren()) do
            if v.Name:match("^Gameplay%d+$") then
                local ef=v:FindFirstChild("Enemies")
                if ef then
                    for _,e in ipairs(ef:GetChildren()) do
                        local id=tonumber(e.Name) if id then t[#t+1]=id end
                    end
                end
            end
        end
        eids=t task.wait(0.5)
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

-- tab buttons
local tabCtrl=Instance.new("TextButton") tabCtrl.Size=UDim2.new(0.5,-7,0,24) tabCtrl.Position=UDim2.new(0,5,0,34) tabCtrl.TextSize=11 tabCtrl.Font=Enum.Font.GothamBold tabCtrl.BorderSizePixel=0 tabCtrl.Text="Controls" tabCtrl.Parent=pan Instance.new("UICorner",tabCtrl).CornerRadius=UDim.new(0,4)
local tabStats=Instance.new("TextButton") tabStats.Size=UDim2.new(0.5,-7,0,24) tabStats.Position=UDim2.new(0.5,2,0,34) tabStats.TextSize=11 tabStats.Font=Enum.Font.GothamBold tabStats.BorderSizePixel=0 tabStats.Text="Stats" tabStats.Parent=pan Instance.new("UICorner",tabStats).CornerRadius=UDim.new(0,4)

-- controls frame (tab 1)
local ctrlFrame=Instance.new("Frame") ctrlFrame.Size=UDim2.new(1,0,0,10) ctrlFrame.Position=UDim2.new(0,0,0,62) ctrlFrame.BackgroundTransparency=1 ctrlFrame.BorderSizePixel=0 ctrlFrame.Parent=pan
local yC=4
local sep=Instance.new("Frame") sep.Size=UDim2.new(1,-10,0,1) sep.Position=UDim2.new(0,5,0,yC) sep.BackgroundColor3=Color3.fromRGB(55,55,55) sep.BorderSizePixel=0 sep.Parent=ctrlFrame yC=yC+8
local function T(lbl,key)
    local b=Instance.new("TextButton") b.Size=UDim2.new(1,-10,0,26) b.Position=UDim2.new(0,5,0,yC) b.BorderSizePixel=0 b.TextSize=12 b.Font=Enum.Font.Gotham b.Parent=ctrlFrame Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
    local function rf()if S[key]then b.Text=lbl.." ON" b.BackgroundColor3=Color3.fromRGB(25,70,25) b.TextColor3=Color3.fromRGB(80,230,80)else b.Text=lbl.." OFF" b.BackgroundColor3=Color3.fromRGB(70,25,25) b.TextColor3=Color3.fromRGB(230,80,80)end end
    b.MouseButton1Click:Connect(function()S[key]=not S[key] rf() saveState()end) rf() yC=yC+30 table.insert(rfs,rf)
end
stopBtn.MouseButton1Click:Connect(function()
    for k in pairs(S)do S[k]=false end for _,rf in ipairs(rfs)do rf()end task.wait(0.1) g:Destroy()
end)
T("Auto Gun","gun"); T("Auto Roll","roll"); T("Auto Collect","collect"); T("Anti-AFK","afk")
ctrlFrame.Size=UDim2.new(1,0,0,yC+4)

-- stats frame (tab 2)
local statsFrame=Instance.new("Frame") statsFrame.Size=UDim2.new(1,0,0,10) statsFrame.Position=UDim2.new(0,0,0,62) statsFrame.BackgroundTransparency=1 statsFrame.BorderSizePixel=0 statsFrame.Visible=false statsFrame.Parent=pan
local yS=4
local function mkStat(txt)
    local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-10,0,20) l.Position=UDim2.new(0,5,0,yS) l.BackgroundColor3=Color3.fromRGB(28,28,28) l.TextColor3=Color3.fromRGB(160,220,160) l.Text=txt l.TextSize=11 l.Font=Enum.Font.Gotham l.BorderSizePixel=0 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=statsFrame
    local p=Instance.new("UIPadding",l) p.PaddingLeft=UDim.new(0,6) Instance.new("UICorner",l).CornerRadius=UDim.new(0,4) yS=yS+23 return l
end
local function mkPair(tL,tR)
    local function mk(txt,xs,xo)
        local l=Instance.new("TextLabel") l.Size=UDim2.new(0.5,-7,0,20) l.Position=UDim2.new(xs,xo,0,yS) l.BackgroundColor3=Color3.fromRGB(28,28,28) l.TextColor3=Color3.fromRGB(160,220,160) l.Text=txt l.TextSize=11 l.Font=Enum.Font.Gotham l.BorderSizePixel=0 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=statsFrame
        Instance.new("UIPadding",l).PaddingLeft=UDim.new(0,5) Instance.new("UICorner",l).CornerRadius=UDim.new(0,4) return l
    end
    local lL=mk(tL,0,5) local lR=mk(tR,0.5,2) yS=yS+23 return lL,lR
end
local lCoin,lGoop=mkPair("Coin: --","Goop: --")
local lCoinMin,lGoopMin=mkPair("/min --","/min --")
local lCoinHr,lGoopHr=mkPair("/hr  --","/hr  --")
local lCoinDay,lGoopDay=mkPair("/day --","/day --")
local lSession=mkStat("Session:  0:00")
local resetBtn=Instance.new("TextButton") resetBtn.Size=UDim2.new(1,-10,0,22) resetBtn.Position=UDim2.new(0,5,0,yS) resetBtn.BackgroundColor3=Color3.fromRGB(40,40,80) resetBtn.TextColor3=Color3.fromRGB(150,150,255) resetBtn.Text="Reset Session" resetBtn.TextSize=11 resetBtn.Font=Enum.Font.Gotham resetBtn.BorderSizePixel=0 resetBtn.Parent=statsFrame Instance.new("UICorner",resetBtn).CornerRadius=UDim.new(0,4) yS=yS+26
statsFrame.Size=UDim2.new(1,0,0,yS+4)

-- tab switching
local function switchTab(t)
    local onCtrl=(t=="ctrl")
    ctrlFrame.Visible=onCtrl statsFrame.Visible=not onCtrl
    tabCtrl.BackgroundColor3=onCtrl and Color3.fromRGB(50,50,70) or Color3.fromRGB(30,30,30)
    tabCtrl.TextColor3=onCtrl and Color3.fromRGB(220,220,220) or Color3.fromRGB(130,130,130)
    tabStats.BackgroundColor3=(not onCtrl) and Color3.fromRGB(50,50,70) or Color3.fromRGB(30,30,30)
    tabStats.TextColor3=(not onCtrl) and Color3.fromRGB(220,220,220) or Color3.fromRGB(130,130,130)
    pan.Size=UDim2.new(0,220,0,62+(onCtrl and ctrlFrame or statsFrame).Size.Y.Offset+6)
end
tabCtrl.MouseButton1Click:Connect(function()switchTab("ctrl")end)
tabStats.MouseButton1Click:Connect(function()switchTab("stats")end)
switchTab("ctrl")

-- equip loop
task.spawn(function()
    while true do
        local char=PL.Character
        if char then
            local gun=char:FindFirstChild("SlimeGun") or PL.Backpack:FindFirstChild("SlimeGun")
            if gun and gun.Parent~=char then gun.Parent=char end
        end
        task.wait(0.1)
    end
end)

-- reward tracker: hook ALL Gameplay+N RemoteEvents (rewards on @0.2.1, gun on @0.3.1)
local goopTotal,coinTotal,rewardStart=0,0,tick()
resetBtn.MouseButton1Click:Connect(function()
    goopTotal=0 coinTotal=0 rewardStart=tick()
end)
local hookedREs={}
local function hookRE(re)
    if hookedREs[re] then return end
    hookedREs[re]=true
    re.OnClientEvent:Connect(function(a1,a2)
        if a1=="goopRewarded" and type(a2)=="table" then
            local amt=rawget(a2,"amount")
            if type(amt)=="number" then goopTotal=goopTotal+amt end
        elseif a1=="coinRewarded" and type(a2)=="table" then
            local amt=rawget(a2,"amount")
            if type(amt)=="number" then coinTotal=coinTotal+amt end
        end
    end)
end
task.spawn(function()
    -- hook all existing Gameplay+N RemoteEvents
    for _,v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:match("^Gameplay%d+$") then
            hookRE(v)
        end
    end
    -- also hook any added later
    RS.DescendantAdded:Connect(function(v)
        if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:match("^Gameplay%d+$") then
            hookRE(v)
        end
    end)
end)
task.spawn(function()
    local sfx={"K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc"}
    local function fmt(n)
        if n<1000 then return tostring(math.floor(n)) end
        local i=math.floor(math.log(n)/math.log(1000))
        if i<1 then i=1 end
        if i<=#sfx then return string.format("%.2f%s",n/1000^i,sfx[i]) end
        local e=math.floor(math.log10(n))
        return string.format("%.2fe+%d",n/10^e,e)
    end
    local function fmtTime(s)
        local h=math.floor(s/3600) local m=math.floor(s/60)%60 local sc=math.floor(s)%60
        if h>0 then return string.format("%d:%02d:%02d",h,m,sc) else return string.format("%d:%02d",m,sc) end
    end
    while true do
        task.wait(1)
        local el=math.max(tick()-rewardStart,1)
        lCoin.Text="Coin: "..fmt(coinTotal)
        lGoop.Text="Goop: "..fmt(goopTotal)
        lCoinMin.Text="/min "..fmt(coinTotal/el*60)
        lGoopMin.Text="/min "..fmt(goopTotal/el*60)
        lCoinHr.Text="/hr  "..fmt(coinTotal/el*3600)
        lGoopHr.Text="/hr  "..fmt(goopTotal/el*3600)
        lCoinDay.Text="/day "..fmt(coinTotal/el*86400)
        lGoopDay.Text="/day "..fmt(goopTotal/el*86400)
        lSession.Text="Session:  "..fmtTime(el)
    end
end)

-- gun: focus one target until dead, then immediately next; keep firing at last target if eids empty
local gunTarget=nil
task.spawn(function()
    while true do
        if hitRE and S.gun then
            if #eids>0 then
                local alive=false
                for _,id in ipairs(eids) do if id==gunTarget then alive=true break end end
                if not alive then gunTarget=eids[1] end
            end
            if gunTarget then
                if gunRF then pcall(function()gunRF:InvokeServer("tryFireSlimeGun",gunTarget)end) end
                shotCount=shotCount+1 hitRE:FireServer("confirmHit",shotCount,gunTarget)
            end
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while true do
        if S.roll and rollRF then pcall(function()rollRF:InvokeServer("requestRoll")end)
        else task.wait(0.1)end
    end
end)

-- anti-AFK: real click at screen center every 30 seconds
local VU=game:GetService("VirtualUser")
task.spawn(function()
    while true do task.wait(30)
        if S.afk then pcall(function()
            local c=workspace.CurrentCamera.ViewportSize/2
            VU:Button1Down(c,workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VU:Button1Up(c,workspace.CurrentCamera.CFrame)
        end) end
    end
end)

-- auto collect: live ProximityPrompt cache via events (no GetDescendants polling)
local ppCache={}
local function ppAdd(v)
    if v:IsA("ProximityPrompt") then
        local a=v.ActionText:lower()
        if a=="" or a:find("pick") or a:find("collect") or a:find("take") or a:find("grab") then
            ppCache[v]=true
        end
    end
end
local function ppRemove(v) ppCache[v]=nil end
workspace.DescendantAdded:Connect(ppAdd)
workspace.DescendantRemoving:Connect(ppRemove)
for _,v in ipairs(workspace:GetDescendants()) do ppAdd(v) end

task.spawn(function()
    local DROP_FOLDERS={"Drops","Fruits","Items","Pickups","Collectibles","GoopDrops","WorldItems"}
    while true do
        if S.collect then
            local char=PL.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for pp in pairs(ppCache) do
                    if pp and pp.Enabled then pcall(fireproximityprompt,pp) end
                end
                for _,fname in ipairs(DROP_FOLDERS) do
                    local f=workspace:FindFirstChild(fname)
                    if f then
                        for _,item in ipairs(f:GetChildren()) do
                            local part=item:IsA("BasePart") and item or item:FindFirstChildOfClass("BasePart")
                            if part then pcall(firetouchinterest,part,hrp,0) end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)


