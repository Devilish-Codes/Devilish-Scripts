local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local PL=game:GetService("Players").LocalPlayer
local RunService=game:GetService("RunService")
local TS=game:GetService("TeleportService")

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
local dataRE=nil -- DataService RemoteEvent (found async below)

-- sync rolls state
local ROLL_TYPES={"void","galaxy","golden","diamond"}
local rollProgress={void={r=math.huge},galaxy={r=math.huge},golden={r=math.huge},diamond={r=math.huge}}
local clientPaused={void=false,galaxy=false,golden=false,diamond=false}
local syncReady=false  -- true once all four have dropped under 100
local syncStatusLbl=nil -- assigned after UI is built

local S={gun=false,roll=false,collect=false,tele=false,black=false,syncrolls=false}
local rfs={}
local _allowRejoin=false -- allows the manual rejoin button to bypass the anti-AFK block

local SAVE_FILE="slime_rng_state.txt"
local SKEYS={"gun","roll","collect","tele","black","syncrolls"}
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

local savedPos=nil
local POS_FILE="slime_rng_pos.txt"
local function savePosFile()
    if not savedPos then return end
    local str=savedPos.X..","..savedPos.Y..","..savedPos.Z
    -- try file I/O first, fall back to CoreGui StringValue
    local ok=pcall(writefile,POS_FILE,str)
    if not ok then
        local store=game:GetService("CoreGui"):FindFirstChild("_SlimeRNGPos")
            or Instance.new("StringValue",game:GetService("CoreGui"))
        store.Name="_SlimeRNGPos" store.Value=str
    end
end
local function loadPosFile()
    -- try file first
    local ok,d=pcall(readfile,POS_FILE)
    -- fall back to CoreGui StringValue
    if not ok or not d then
        local store=game:GetService("CoreGui"):FindFirstChild("_SlimeRNGPos")
        if store then d=store.Value ok=true end
    end
    if not ok or not d then return end
    local x,y,z=d:match("^([-%.%d]+),([-%.%d]+),([-%.%d]+)$")
    if x then savedPos=Vector3.new(tonumber(x),tonumber(y),tonumber(z)) end
end
loadPosFile()

local pan -- forward declare so saveUiPos/loadUiPos can close over it
local UI_POS_FILE="slime_rng_uipos.txt"
local function saveUiPos()
    if not pan then return end
    pcall(writefile,UI_POS_FILE,pan.Position.X.Offset..","..pan.Position.Y.Offset)
end
local function loadUiPos()
    if not pan then return end
    local ok,d=pcall(readfile,UI_POS_FILE)
    if not ok or not d then return end
    local x,y=d:match("^(-?%d+),(-?%d+)$")
    if x then pan.Position=UDim2.new(0,tonumber(x),0,tonumber(y)) end
end

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
local GUN_RANGE=500
task.spawn(function()
    while true do
        local char=PL.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        local hrpPos=hrp and hrp.Position
        local candidates={}
        for _,v in ipairs(workspace:GetChildren()) do
            if v.Name:match("^Gameplay%d+$") then
                local ef=v:FindFirstChild("Enemies")
                if ef then
                    for _,e in ipairs(ef:GetChildren()) do
                        local id=tonumber(e.Name)
                        if id then
                            local ep=e.PrimaryPart or e:FindFirstChildOfClass("BasePart")
                            local dist=hrpPos and ep and (ep.Position-hrpPos).Magnitude or 0
                            if not hrpPos or not ep or dist<=GUN_RANGE then
                                local hum=e:FindFirstChildOfClass("Humanoid")
                                local hp=hum and hum.Health or math.huge
                                candidates[#candidates+1]={id=id,hp=hp,dist=dist}
                            end
                        end
                    end
                end
            end
        end
        table.sort(candidates,function(a,b)
            if a.hp~=b.hp then return a.hp<b.hp end
            return a.dist<b.dist
        end)
        local t={}
        for _,c in ipairs(candidates) do t[#t+1]=c.id end
        eids=t task.wait(0.5)
    end
end)


local _iconUrl=""
pcall(function() _iconUrl=getcustomasset("pfp_bg7_p03_scarlet.png") end)

local g=Instance.new("ScreenGui") g.Name="SlimeGui" g.ResetOnSpawn=false g.DisplayOrder=1
pcall(function()g.Parent=gethui()end)
if not g.Parent then g.Parent=game:GetService("CoreGui")end

-- black screen overlay in its own ScreenGui with IgnoreGuiInset for full coverage
local blackGui=Instance.new("ScreenGui") blackGui.Name="SlimeBlack" blackGui.ResetOnSpawn=false blackGui.IgnoreGuiInset=true blackGui.DisplayOrder=0
pcall(function()blackGui.Parent=gethui()end)
if not blackGui.Parent then blackGui.Parent=game:GetService("CoreGui")end
local blackScreen=Instance.new("Frame") blackScreen.Size=UDim2.new(1,0,1,0) blackScreen.BackgroundColor3=Color3.fromRGB(0,0,0) blackScreen.BorderSizePixel=0 blackScreen.Visible=S.black blackScreen.Parent=blackGui

pan=Instance.new("Frame") pan.Size=UDim2.new(0,220,0,10) pan.Position=UDim2.new(0,12,0,12) pan.BackgroundColor3=Color3.fromRGB(20,20,20) pan.BorderSizePixel=0 pan.Parent=g Instance.new("UICorner",pan).CornerRadius=UDim.new(0,8)
local bubble=Instance.new("ImageButton") bubble.Size=UDim2.new(0,44,0,44) bubble.Position=UDim2.new(1,-56,0,12) bubble.BackgroundColor3=Color3.fromRGB(35,35,35) bubble.Image=_iconUrl bubble.ScaleType=Enum.ScaleType.Fit bubble.BorderSizePixel=0 bubble.Visible=false bubble.Parent=g Instance.new("UICorner",bubble).CornerRadius=UDim.new(1,0)
local ttl=Instance.new("TextLabel") ttl.Size=UDim2.new(1,-68,0,30) ttl.BackgroundColor3=Color3.fromRGB(35,35,35) ttl.TextColor3=Color3.fromRGB(220,220,220) ttl.Text="Lxcifer Scripts" ttl.TextSize=13 ttl.Font=Enum.Font.GothamBold ttl.BorderSizePixel=0 ttl.Parent=pan Instance.new("UICorner",ttl).CornerRadius=UDim.new(0,8)
local minBtn=Instance.new("TextButton") minBtn.Size=UDim2.new(0,30,0,30) minBtn.Position=UDim2.new(1,-64,0,0) minBtn.BackgroundColor3=Color3.fromRGB(60,60,60) minBtn.TextColor3=Color3.fromRGB(220,220,220) minBtn.Text="_" minBtn.TextSize=16 minBtn.Font=Enum.Font.GothamBold minBtn.BorderSizePixel=0 minBtn.ZIndex=2 minBtn.Parent=pan Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,6)
local stopBtn=Instance.new("TextButton") stopBtn.Size=UDim2.new(0,30,0,30) stopBtn.Position=UDim2.new(1,-32,0,0) stopBtn.BackgroundColor3=Color3.fromRGB(140,30,30) stopBtn.TextColor3=Color3.fromRGB(255,255,255) stopBtn.Text="X" stopBtn.TextSize=14 stopBtn.Font=Enum.Font.GothamBold stopBtn.BorderSizePixel=0 stopBtn.ZIndex=2 stopBtn.Parent=pan Instance.new("UICorner",stopBtn).CornerRadius=UDim.new(0,6)

local dr,ds,ps
ttl.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true ds=i.Position ps=pan.Position end end)
UIS.InputChanged:Connect(function(i)if dr and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds pan.Position=UDim2.new(ps.X.Scale,ps.X.Offset+d.X,ps.Y.Scale,ps.Y.Offset+d.Y)end end)
UIS.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then if dr then saveUiPos() end dr=false end end)
loadUiPos()
minBtn.MouseButton1Click:Connect(function()pan.Visible=false bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function()bubble.Visible=false pan.Visible=true end)

-- tab buttons
local function mkTab(lbl,x,w)
    local b=Instance.new("TextButton") b.Size=UDim2.new(0,w,0,24) b.Position=UDim2.new(0,x,0,34) b.BackgroundColor3=Color3.fromRGB(30,30,30) b.TextColor3=Color3.fromRGB(130,130,130) b.TextSize=11 b.Font=Enum.Font.GothamBold b.BorderSizePixel=0 b.Text=lbl b.Parent=pan Instance.new("UICorner",b).CornerRadius=UDim.new(0,4) return b
end
local tabCtrl=mkTab("Controls",5,70)
local tabStats=mkTab("Stats",78,70)
local tabServer=mkTab("Server",151,69)

-- controls frame (tab 1)
local ctrlFrame=Instance.new("Frame") ctrlFrame.Size=UDim2.new(1,0,0,10) ctrlFrame.Position=UDim2.new(0,0,0,62) ctrlFrame.BackgroundTransparency=1 ctrlFrame.BorderSizePixel=0 ctrlFrame.Parent=pan
local yC=4
local sep=Instance.new("Frame") sep.Size=UDim2.new(1,-10,0,1) sep.Position=UDim2.new(0,5,0,yC) sep.BackgroundColor3=Color3.fromRGB(55,55,55) sep.BorderSizePixel=0 sep.Parent=ctrlFrame yC=yC+8
local function T(lbl,key,cb)
    local b=Instance.new("TextButton") b.Size=UDim2.new(1,-10,0,26) b.Position=UDim2.new(0,5,0,yC) b.BorderSizePixel=0 b.TextSize=12 b.Font=Enum.Font.Gotham b.Parent=ctrlFrame Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
    local function rf()if S[key]then b.Text=lbl.." ON" b.BackgroundColor3=Color3.fromRGB(25,70,25) b.TextColor3=Color3.fromRGB(80,230,80)else b.Text=lbl.." OFF" b.BackgroundColor3=Color3.fromRGB(70,25,25) b.TextColor3=Color3.fromRGB(230,80,80)end end
    b.MouseButton1Click:Connect(function()S[key]=not S[key] rf() saveState() if cb then cb(S[key]) end end) rf() if cb then cb(S[key]) end yC=yC+30 table.insert(rfs,rf)
end
stopBtn.MouseButton1Click:Connect(function()
    for k in pairs(S)do S[k]=false end for _,rf in ipairs(rfs)do rf()end task.wait(0.1) g:Destroy()
end)
T("Auto Gun","gun"); T("Auto Roll","roll"); T("Auto Collect","collect"); T("Auto Return","tele")
T("Black Screen","black",function(on)blackScreen.Visible=on end)
T("Sync Rolls","syncrolls",function(on)
    if on then
        if syncStatusLbl then syncStatusLbl.Visible=true end
    else
        syncReady=false
        for _,rt in ipairs(ROLL_TYPES) do
            if clientPaused[rt] then
                if dataRE then pcall(function()
                    -- VERIFY: update this call name if it doesn't work
                    dataRE:FireServer("pauseSpecialRoll",rt,false)
                end) end
                clientPaused[rt]=false
            end
        end
        if syncStatusLbl then syncStatusLbl.Visible=false end
    end
end)
-- roll count display: only visible when sync rolls is ON
local _ssl=Instance.new("TextLabel") _ssl.Size=UDim2.new(1,-10,0,12) _ssl.Position=UDim2.new(0,5,0,yC) _ssl.BackgroundTransparency=1 _ssl.TextColor3=Color3.fromRGB(100,100,100) _ssl.Text="G:-- D:-- V:-- X:--" _ssl.TextSize=9 _ssl.Font=Enum.Font.Code _ssl.TextXAlignment=Enum.TextXAlignment.Left _ssl.Visible=false _ssl.Parent=ctrlFrame
syncStatusLbl=_ssl yC=yC+14
local savePosBtn=Instance.new("TextButton") savePosBtn.Size=UDim2.new(1,-10,0,24) savePosBtn.Position=UDim2.new(0,5,0,yC) savePosBtn.BackgroundColor3=Color3.fromRGB(35,55,80) savePosBtn.TextColor3=Color3.fromRGB(120,180,255) savePosBtn.Text="Save Position" savePosBtn.TextSize=12 savePosBtn.Font=Enum.Font.Gotham savePosBtn.BorderSizePixel=0 savePosBtn.Parent=ctrlFrame Instance.new("UICorner",savePosBtn).CornerRadius=UDim.new(0,4) yC=yC+28
local fpsBtn=Instance.new("TextButton") fpsBtn.Size=UDim2.new(1,-10,0,24) fpsBtn.Position=UDim2.new(0,5,0,yC) fpsBtn.BackgroundColor3=Color3.fromRGB(50,35,15) fpsBtn.TextColor3=Color3.fromRGB(255,180,60) fpsBtn.Text="FPS Boost" fpsBtn.TextSize=12 fpsBtn.Font=Enum.Font.Gotham fpsBtn.BorderSizePixel=0 fpsBtn.Parent=ctrlFrame Instance.new("UICorner",fpsBtn).CornerRadius=UDim.new(0,4) yC=yC+28
ctrlFrame.Size=UDim2.new(1,0,0,yC+4)

-- stats frame (tab 2)
local statsFrame=Instance.new("Frame") statsFrame.Size=UDim2.new(1,0,0,10) statsFrame.Position=UDim2.new(0,0,0,62) statsFrame.BackgroundTransparency=1 statsFrame.BorderSizePixel=0 statsFrame.Visible=false statsFrame.Parent=pan
local yS=4
local function mkStat(txt)
    local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-10,0,20) l.Position=UDim2.new(0,5,0,yS) l.BackgroundTransparency=1 l.TextColor3=Color3.fromRGB(255,255,255) l.Text=txt l.TextSize=11 l.Font=Enum.Font.GothamBold l.BorderSizePixel=0 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=statsFrame
    local p=Instance.new("UIPadding",l) p.PaddingLeft=UDim.new(0,6)
    local st=Instance.new("UIStroke",l) st.Color=Color3.fromRGB(0,0,0) st.Thickness=1.5 st.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
    yS=yS+23 return l
end
local function mkPair(tL,tR)
    local function mk(txt,xs,xo)
        local l=Instance.new("TextLabel") l.Size=UDim2.new(0.5,-7,0,20) l.Position=UDim2.new(xs,xo,0,yS) l.BackgroundTransparency=1 l.TextColor3=Color3.fromRGB(255,255,255) l.Text=txt l.TextSize=11 l.Font=Enum.Font.GothamBold l.BorderSizePixel=0 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=statsFrame
        Instance.new("UIPadding",l).PaddingLeft=UDim.new(0,5)
        local st=Instance.new("UIStroke",l) st.Color=Color3.fromRGB(0,0,0) st.Thickness=1.5 st.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
        return l
    end
    local lL=mk(tL,0,5) local lR=mk(tR,0.5,2) yS=yS+23 return lL,lR
end
local lCoin,lGoop=mkPair("Coin: --","Goop: --")
local lCoinMin,lGoopMin=mkPair("/min --","/min --")
local lCoinHr,lGoopHr=mkPair("/hr  --","/hr  --")
local lCoinDay,lGoopDay=mkPair("/day --","/day --")
local lSession=mkStat("Session:  0:00")
local lFps=mkStat("FPS:      --")
local resetBtn=Instance.new("TextButton") resetBtn.Size=UDim2.new(1,-10,0,22) resetBtn.Position=UDim2.new(0,5,0,yS) resetBtn.BackgroundTransparency=1 resetBtn.TextColor3=Color3.fromRGB(255,255,255) resetBtn.Text="Reset Session" resetBtn.TextSize=11 resetBtn.Font=Enum.Font.GothamBold resetBtn.BorderSizePixel=0 resetBtn.Parent=statsFrame Instance.new("UICorner",resetBtn).CornerRadius=UDim.new(0,4)
local rst=Instance.new("UIStroke",resetBtn) rst.Color=Color3.fromRGB(0,0,0) rst.Thickness=1.5 rst.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
yS=yS+26
statsFrame.Size=UDim2.new(1,0,0,yS+4)

-- server frame (tab 3)
local serverFrame=Instance.new("Frame") serverFrame.Size=UDim2.new(1,0,0,58) serverFrame.Position=UDim2.new(0,0,0,62) serverFrame.BackgroundTransparency=1 serverFrame.BorderSizePixel=0 serverFrame.Visible=false serverFrame.Parent=pan
local rejoinBtn=Instance.new("TextButton") rejoinBtn.Size=UDim2.new(1,-10,0,34) rejoinBtn.Position=UDim2.new(0,5,0,12) rejoinBtn.BackgroundColor3=Color3.fromRGB(35,40,70) rejoinBtn.TextColor3=Color3.fromRGB(160,180,255) rejoinBtn.Text="Rejoin Server" rejoinBtn.TextSize=13 rejoinBtn.Font=Enum.Font.GothamBold rejoinBtn.BorderSizePixel=0 rejoinBtn.Parent=serverFrame Instance.new("UICorner",rejoinBtn).CornerRadius=UDim.new(0,6)
rejoinBtn.MouseButton1Click:Connect(function()
    rejoinBtn.Text="Rejoining..."
    local re=RS:FindFirstChild("AutoRejoinService") and RS.AutoRejoinService:FindFirstChildOfClass("RemoteEvent")
    if re then _allowRejoin=true pcall(function()re:autoRejoin()end) _allowRejoin=false
    else pcall(function()TS:TeleportToPlaceInstance(game.PlaceId,game.JobId,PL)end) end
end)

-- tab switching
local function switchTab(t)
    local frames={ctrl=ctrlFrame,stats=statsFrame,server=serverFrame}
    local tabs={ctrl=tabCtrl,stats=tabStats,server=tabServer}
    for k,f in pairs(frames) do f.Visible=(k==t) end
    for k,tb in pairs(tabs) do
        tb.BackgroundColor3=(k==t) and Color3.fromRGB(50,50,70) or Color3.fromRGB(30,30,30)
        tb.TextColor3=(k==t) and Color3.fromRGB(220,220,220) or Color3.fromRGB(130,130,130)
    end
    local isStats=(t=="stats")
    pan.BackgroundTransparency=isStats and 0.85 or 0
    ttl.BackgroundTransparency=isStats and 0.85 or 0
    pan.Size=UDim2.new(0,220,0,62+frames[t].Size.Y.Offset+6)
end
tabCtrl.MouseButton1Click:Connect(function()switchTab("ctrl")end)
tabStats.MouseButton1Click:Connect(function()switchTab("stats")end)
tabServer.MouseButton1Click:Connect(function()switchTab("server")end)
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

-- fps boost
local EFFECT_TYPES={ParticleEmitter=true,Trail=true,Beam=true,Smoke=true,Fire=true,Sparkles=true,Decal=true,Texture=true,PointLight=true,SpotLight=true,SurfaceLight=true,BillboardGui=true,SurfaceGui=true,SelectionBox=true,SelectionSphere=true}
local fpsActive=false
local _VFX_DISABLE={ParticleEmitter=true,Trail=true,Beam=true,Smoke=true,Fire=true,Sparkles=true}
workspace.DescendantAdded:Connect(function(v)
    if fpsActive and _VFX_DISABLE[v.ClassName] then
        pcall(function() v.Enabled=false end)
    end
end)
fpsBtn.MouseButton1Click:Connect(function()
    fpsActive=true
    local Lighting=game:GetService("Lighting")
    pcall(function()Lighting.GlobalShadows=false Lighting.FogEnd=1e6 end)
    for _,v in ipairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("Sky") then pcall(v.Destroy,v) end
    end
    local char=PL.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local origin=hrp and hrp.Position or Vector3.new(0,0,0)
    local removed=0
    for _,v in ipairs(workspace:GetDescendants()) do
        if EFFECT_TYPES[v.ClassName] then
            pcall(v.Destroy,v) removed=removed+1
        elseif v:IsA("BasePart") and v.Anchored then
            if not v.CanCollide then
                pcall(v.Destroy,v) removed=removed+1
            elseif (v.Position-origin).Magnitude>300 then
                pcall(function()v.Transparency=1 v.CastShadow=false end) removed=removed+1
            end
        end
    end
    fpsBtn.Text="Cleared "..removed
    task.delay(2,function()if fpsBtn and fpsBtn.Parent then fpsBtn.Text="FPS Boost" end end)
end)

-- save position button
savePosBtn.MouseButton1Click:Connect(function()
    local char=PL.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        savedPos=hrp.Position+Vector3.new(0,1,0)
        savePosFile()
        savePosBtn.Text="Saved!"
        task.delay(1.5,function()savePosBtn.Text="Save Position"end)
    end
end)


-- auto return loop
task.spawn(function()
    while true do
        task.wait(1)
        if S.tele and savedPos then
            local char=PL.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position-savedPos).Magnitude>20 then pcall(function()PL.Character:PivotTo(CFrame.new(savedPos))end) end
        end
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
local frameCount=0
RunService.Heartbeat:Connect(function() frameCount=frameCount+1 end)

-- sync rolls: pause each special roll at 1 remaining, fire all simultaneously
local function syncPause(rt,sp)
    if not dataRE then return end
    -- VERIFY: capture this call on Synapse/Fluxus by clicking the in-game pause button
    -- Common alternatives: "setSpecialRollPaused", "toggleSpecialRollPause", "updateSpecialRoll"
    pcall(function() dataRE:FireServer("pauseSpecialRoll",rt,sp) end)
end
local function handleSyncRolls()
    if not S.syncrolls then return end
    -- Phase 1: wait until all four are under 100
    if not syncReady then
        for _,rt in ipairs(ROLL_TYPES) do
            if rollProgress[rt].r>100 then return end
        end
        syncReady=true
    end
    -- Phase 2: pause each as it hits ≤1
    for _,rt in ipairs(ROLL_TYPES) do
        if rollProgress[rt].r<=1 and not clientPaused[rt] then
            syncPause(rt,true) clientPaused[rt]=true
        end
    end
    -- Phase 3: all four paused at ≤1 → fire simultaneously
    local allReady=true
    for _,rt in ipairs(ROLL_TYPES) do
        if not clientPaused[rt] or rollProgress[rt].r>1 then allReady=false break end
    end
    if allReady then
        for _,rt in ipairs(ROLL_TYPES) do syncPause(rt,false) clientPaused[rt]=false end
        syncReady=false
    end
    -- update status label
    if syncStatusLbl then
        local r=rollProgress
        local function f(v) return v>=math.huge and "--" or tostring(v) end
        syncStatusLbl.Text=string.format("G:%-4s D:%-4s V:%-4s X:%-4s",f(r.golden.r),f(r.diamond.r),f(r.void.r),f(r.galaxy.r))
        syncStatusLbl.TextColor3=syncReady and Color3.fromRGB(80,180,255) or Color3.fromRGB(200,160,40)
    end
end
task.spawn(function()
    for _=1,30 do
        local ds=RS:FindFirstChild("DataService")
        if ds then
            local re=ds:FindFirstChildOfClass("RemoteEvent")
            if re then
                dataRE=re
                re.OnClientEvent:Connect(function(_,evName,data)
                    if evName=="specialRollProgression" and type(data)=="table" then
                        for _,rt in ipairs(ROLL_TYPES) do
                            local d=data[rt]
                            if d then rollProgress[rt].r=d.rollsUntilNext or math.huge end
                        end
                        handleSyncRolls()
                    end
                end)
                return
            end
        end
        task.wait(0.5)
    end
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
        lFps.Text="FPS:      "..frameCount frameCount=0
    end
end)

-- gun: always target lowest-hp enemy, fallback closest; list pre-sorted by enemy scan
local gunTarget=nil
task.spawn(function()
    while true do
        if hitRE and S.gun then
            if #eids>0 then gunTarget=eids[1] end
            if gunTarget then
                if gunRF then pcall(function()gunRF:InvokeServer("tryFireSlimeGun",gunTarget)end) end
                shotCount=shotCount+1 pcall(function()hitRE:FireServer("confirmHit",shotCount,gunTarget)end)
                shotCount=shotCount+1 pcall(function()hitRE:FireServer("confirmHit",shotCount,gunTarget)end)
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

-- anti-AFK: block the game's AutoRejoinService from firing autoRejoin to the server
local VU=game:GetService("VirtualUser")
PL.Idled:Connect(function()
    pcall(function()
        VU:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
        task.wait(1)
        VU:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    end)
end)
local _mt=getrawmetatable(game)
local _old=_mt.__namecall
if setreadonly then setreadonly(_mt,false) end
_mt.__namecall=function(self,...)
    local method=(getnamecallmethod and getnamecallmethod()) or ({...})[1]
    if method=="autoRejoin" and self.Parent and self.Parent.Name=="AutoRejoinService" and not _allowRejoin then
        return -- block the game's AFK rejoin
    end
    return _old(self,...)
end
if setreadonly then setreadonly(_mt,true) end

-- fruit inventory cap: skip collecting a fruit if already at/above this count
local FRUIT_CAP=200
local CAPPED_FRUITS={lightningFruit=true,iceFruit=true,fireFruit=true,universeFruit=true,magicianFruit=true,swordFruit=true}
local _fruitIdMap=nil
local function getFruitIdMap()
    if _fruitIdMap then return _fruitIdMap end
    local ok,Fr=pcall(require,RS.Source.Game.Items.Fruits)
    if not ok then _fruitIdMap={} return _fruitIdMap end
    local map={}
    for _,f in ipairs(Fr.getSortedFruits()) do
        if f.id then
            map[f.id:lower()]=f.id
            if f.name then map[f.name:lower()]=f.id end
            if f.treeId then map[f.treeId:lower()]=f.id end
        end
    end
    _fruitIdMap=map return map
end
local _invUtils=nil
local function getInvUtils()
    if _invUtils then return _invUtils end
    local ok,m=pcall(require,RS.Source.InventoryItemUtils)
    if ok and m then _invUtils=m end
    return _invUtils
end
local function getFruitCount(itemName)
    if not itemName or itemName=="" then return 0 end
    local id=getFruitIdMap()[itemName:lower()] or itemName
    if not CAPPED_FRUITS[id] then return 0 end
    local utils=getInvUtils()
    if not utils then return 0 end
    local ok,n=pcall(utils.getAmountOwned,id)
    return (ok and type(n)=="number") and n or 0
end
local function fruitModel(inst)
    local m=inst while m and not m:IsA("Model") do m=m.Parent end return m
end

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
                    if pp and pp.Enabled then
                        local m=fruitModel(pp)
                        if not m or getFruitCount(m.Name)<FRUIT_CAP then
                            if fireproximityprompt then pcall(fireproximityprompt,pp) end
                        end
                    end
                end
                for _,fname in ipairs(DROP_FOLDERS) do
                    local f=workspace:FindFirstChild(fname)
                    if f then
                        for _,item in ipairs(f:GetChildren()) do
                            if getFruitCount(item.Name)<FRUIT_CAP then
                                local part=item:IsA("BasePart") and item or item:FindFirstChildOfClass("BasePart")
                                if part and firetouchinterest then pcall(firetouchinterest,part,hrp,0) end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)


