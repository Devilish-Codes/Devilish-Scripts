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

local yP=34
local function mkStat(txt)
    local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-10,0,20) l.Position=UDim2.new(0,5,0,yP) l.BackgroundColor3=Color3.fromRGB(28,28,28) l.TextColor3=Color3.fromRGB(160,220,160) l.Text=txt l.TextSize=11 l.Font=Enum.Font.Gotham l.BorderSizePixel=0 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=pan
    local p=Instance.new("UIPadding",l) p.PaddingLeft=UDim.new(0,6) Instance.new("UICorner",l).CornerRadius=UDim.new(0,4) yP=yP+23 return l
end
local sep=Instance.new("Frame") sep.Size=UDim2.new(1,-10,0,1) sep.Position=UDim2.new(0,5,0,yP+3) sep.BackgroundColor3=Color3.fromRGB(55,55,55) sep.BorderSizePixel=0 sep.Parent=pan yP=yP+10

local function T(lbl,key)
    local b=Instance.new("TextButton") b.Size=UDim2.new(1,-10,0,26) b.Position=UDim2.new(0,5,0,yP) b.BorderSizePixel=0 b.TextSize=12 b.Font=Enum.Font.Gotham b.Parent=pan Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
    local function rf()if S[key]then b.Text=lbl.." ON" b.BackgroundColor3=Color3.fromRGB(25,70,25) b.TextColor3=Color3.fromRGB(80,230,80)else b.Text=lbl.." OFF" b.BackgroundColor3=Color3.fromRGB(70,25,25) b.TextColor3=Color3.fromRGB(230,80,80)end end
    b.MouseButton1Click:Connect(function()S[key]=not S[key] rf() saveState()end) rf() yP=yP+30 table.insert(rfs,rf)
end
stopBtn.MouseButton1Click:Connect(function()
    for k in pairs(S)do S[k]=false end for _,rf in ipairs(rfs)do rf()end task.wait(0.1) g:Destroy()
end)
T("Auto Gun","gun"); T("Auto Roll","roll"); T("Auto Collect","collect"); T("Anti-AFK","afk")

local sep2=Instance.new("Frame") sep2.Size=UDim2.new(1,-10,0,1) sep2.Position=UDim2.new(0,5,0,yP+3) sep2.BackgroundColor3=Color3.fromRGB(55,55,55) sep2.BorderSizePixel=0 sep2.Parent=pan yP=yP+10
local lGoopKills=mkStat("Goop kills: --")
local lGoopX2=mkStat("x2 rolls:   --")
local lGoopMin=mkStat("Goop/min:   --")
local lCoinMin=mkStat("Coin/min:   --")
pan.Size=UDim2.new(0,220,0,yP+6)

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
local hookedREs={}
local function hookRE(re)
    if hookedREs[re] then return end
    hookedREs[re]=true
    re.OnClientEvent:Connect(function(a1,a2,a3,a4)
        local function s(v) if v==nil then return "nil" end return typeof(v)..":"..tostring(v) end
        local isGoop=a1=="goopRewarded" or a2=="goop" or (type(a1)=="string" and a1:lower():find("goop"))
        local isCoin=a1=="coinRewarded" or (type(a1)=="string" and a1:lower():find("coin"))
        if isGoop or isCoin then
            lGoopKills.Text="a1="..s(a1)
            if type(a2)=="table" then
                local keys={"amount","Amount","goop","Goop","value","Value","reward","Reward","count","Count","currency","Currency","quantity","Quantity"}
                local parts={}
                for _,k in ipairs(keys) do
                    local ok,v=pcall(function()return rawget(a2,k)end)
                    if ok and v~=nil then parts[#parts+1]=k.."="..tostring(v) end
                end
                for i=1,6 do
                    local ok,v=pcall(function()return rawget(a2,i)end)
                    if ok and v~=nil then parts[#parts+1]="["..i.."]="..tostring(v) end
                end
                lGoopX2.Text=#parts>0 and table.concat(parts," | ") or "no readable keys"
                lGoopMin.Text="(table above)"
            else
                lGoopX2.Text="a2="..s(a2).." a3="..s(a3)
                lGoopMin.Text="a4="..s(a4)
            end
        end
        if a1=="goopRewarded" then
            if type(a2)=="number" then goopTotal=goopTotal+a2
            elseif type(a3)=="number" then goopTotal=goopTotal+a3
            elseif type(a4)=="number" then goopTotal=goopTotal+a4 end
        elseif a1=="coinRewarded" then
            if type(a2)=="number" then coinTotal=coinTotal+a2
            elseif type(a3)=="number" then coinTotal=coinTotal+a3
            elseif type(a4)=="number" then coinTotal=coinTotal+a4 end
        elseif type(a1)=="number" and a2=="goop" then
            goopTotal=goopTotal+a1
        elseif type(a2)=="number" and a3=="goop" then
            goopTotal=goopTotal+a2
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
    local function fmt(n)
        if n>=1e9 then return string.format("%.1fB",n/1e9)
        elseif n>=1e6 then return string.format("%.1fM",n/1e6)
        elseif n>=1e3 then return string.format("%.1fK",n/1e3)
        else return tostring(math.floor(n)) end
    end
    while true do
        task.wait(1)
        local el=math.max(tick()-rewardStart,1)
        lGoopKills.Text="Goop: "..fmt(goopTotal)
        lGoopX2.Text="Coin: "..fmt(coinTotal)
        lGoopMin.Text="Goop/min: "..fmt(goopTotal/el*60)
        lCoinMin.Text="Coin/min: "..fmt(coinTotal/el*60)
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


