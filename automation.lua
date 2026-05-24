local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local PL=game:GetService("Players").LocalPlayer
local VU=game:GetService("VirtualUser")
local TS=game:GetService("TeleportService")
local rem=RS:WaitForChild("RemoteEvents",10)
if not rem then return end
local function F(n,...)local r=rem:FindFirstChild(n)if r and r:IsA("RemoteEvent")then r:FireServer(...)end end

local S={ua=false,gm=false,tm=false,ta=false,tn=false,tb=false,black=false,tele=false}
local SKEYS={"ua","gm","tm","ta","tn","tb","black","tele"}
local SAVE_FILE="immortality_state.txt"
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
local POS_FILE="immortality_pos.txt"
local function savePosFile()
    if savedPos then pcall(writefile,POS_FILE,savedPos.X..","..savedPos.Y..","..savedPos.Z) end
end
local function loadPosFile()
    local ok,d=pcall(readfile,POS_FILE)
    if not ok or not d then return end
    local x,y,z=d:match("^([-%.%d]+),([-%.%d]+),([-%.%d]+)$")
    if x then savedPos=Vector3.new(tonumber(x),tonumber(y),tonumber(z)) end
end
loadPosFile()

local g=Instance.new("ScreenGui")
g.Name="AutoGui" g.ResetOnSpawn=false
pcall(function()g.Parent=gethui()end)
if not g.Parent then g.Parent=game:GetService("CoreGui")end

local blackScreen=Instance.new("Frame") blackScreen.Size=UDim2.new(1,0,1,0) blackScreen.BackgroundColor3=Color3.fromRGB(0,0,0) blackScreen.BorderSizePixel=0 blackScreen.Visible=S.black blackScreen.Parent=g

local pan=Instance.new("Frame")
pan.Size=UDim2.new(0,200,0,10) pan.Position=UDim2.new(0,12,0,12)
pan.BackgroundColor3=Color3.fromRGB(20,20,20) pan.BorderSizePixel=0 pan.Parent=g
Instance.new("UICorner",pan).CornerRadius=UDim.new(0,8)

local bubble=Instance.new("TextButton")
bubble.Size=UDim2.new(0,44,0,44) bubble.Position=UDim2.new(1,-56,0,12)
bubble.BackgroundColor3=Color3.fromRGB(35,35,35) bubble.TextColor3=Color3.fromRGB(220,220,220)
bubble.Text="A" bubble.TextSize=16 bubble.Font=Enum.Font.GothamBold
bubble.BorderSizePixel=0 bubble.Visible=false bubble.Parent=g
Instance.new("UICorner",bubble).CornerRadius=UDim.new(1,0)

local ttl=Instance.new("TextLabel")
ttl.Size=UDim2.new(1,-68,0,30) ttl.BackgroundColor3=Color3.fromRGB(35,35,35)
ttl.TextColor3=Color3.fromRGB(220,220,220) ttl.Text="[ AUTOMATION ]"
ttl.TextSize=13 ttl.Font=Enum.Font.GothamBold ttl.BorderSizePixel=0 ttl.Parent=pan
Instance.new("UICorner",ttl).CornerRadius=UDim.new(0,8)

local minBtn=Instance.new("TextButton")
minBtn.Size=UDim2.new(0,30,0,30) minBtn.Position=UDim2.new(1,-64,0,0)
minBtn.BackgroundColor3=Color3.fromRGB(60,60,60) minBtn.TextColor3=Color3.fromRGB(220,220,220)
minBtn.Text="_" minBtn.TextSize=16 minBtn.Font=Enum.Font.GothamBold
minBtn.BorderSizePixel=0 minBtn.ZIndex=2 minBtn.Parent=pan
Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,6)

local stopBtn=Instance.new("TextButton")
stopBtn.Size=UDim2.new(0,30,0,30) stopBtn.Position=UDim2.new(1,-32,0,0)
stopBtn.BackgroundColor3=Color3.fromRGB(140,30,30) stopBtn.TextColor3=Color3.fromRGB(255,255,255)
stopBtn.Text="X" stopBtn.TextSize=14 stopBtn.Font=Enum.Font.GothamBold
stopBtn.BorderSizePixel=0 stopBtn.ZIndex=2 stopBtn.Parent=pan
Instance.new("UICorner",stopBtn).CornerRadius=UDim.new(0,6)

local dr,ds,ps
ttl.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true ds=i.Position ps=pan.Position end end)
UIS.InputChanged:Connect(function(i)if dr and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds pan.Position=UDim2.new(ps.X.Scale,ps.X.Offset+d.X,ps.Y.Scale,ps.Y.Offset+d.Y)end end)
UIS.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end end)
minBtn.MouseButton1Click:Connect(function()pan.Visible=false bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function()bubble.Visible=false pan.Visible=true end)

-- tab buttons (panel is 200px: 5 + 90 + 3 + 90 + 7 = 195... close enough)
local tabCtrl=Instance.new("TextButton") tabCtrl.Size=UDim2.new(0,90,0,24) tabCtrl.Position=UDim2.new(0,5,0,34) tabCtrl.TextSize=11 tabCtrl.Font=Enum.Font.GothamBold tabCtrl.BorderSizePixel=0 tabCtrl.Text="Controls" tabCtrl.Parent=pan Instance.new("UICorner",tabCtrl).CornerRadius=UDim.new(0,4)
local tabServer=Instance.new("TextButton") tabServer.Size=UDim2.new(0,90,0,24) tabServer.Position=UDim2.new(0,98,0,34) tabServer.TextSize=11 tabServer.Font=Enum.Font.GothamBold tabServer.BorderSizePixel=0 tabServer.Text="Server" tabServer.Parent=pan Instance.new("UICorner",tabServer).CornerRadius=UDim.new(0,4)

-- controls frame
local ctrlFrame=Instance.new("Frame") ctrlFrame.Size=UDim2.new(1,0,0,10) ctrlFrame.Position=UDim2.new(0,0,0,62) ctrlFrame.BackgroundTransparency=1 ctrlFrame.BorderSizePixel=0 ctrlFrame.Parent=pan
local yC=4
local sep=Instance.new("Frame") sep.Size=UDim2.new(1,-10,0,1) sep.Position=UDim2.new(0,5,0,yC) sep.BackgroundColor3=Color3.fromRGB(55,55,55) sep.BorderSizePixel=0 sep.Parent=ctrlFrame yC=yC+8

local rfs={}
local function T(lbl,key,cb)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,-10,0,26) b.Position=UDim2.new(0,5,0,yC)
    b.BorderSizePixel=0 b.TextSize=12 b.Font=Enum.Font.Gotham b.Parent=ctrlFrame
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
    local function rf()if S[key]then b.Text=lbl.." ON" b.BackgroundColor3=Color3.fromRGB(25,70,25) b.TextColor3=Color3.fromRGB(80,230,80)else b.Text=lbl.." OFF" b.BackgroundColor3=Color3.fromRGB(70,25,25) b.TextColor3=Color3.fromRGB(230,80,80)end end
    b.MouseButton1Click:Connect(function()S[key]=not S[key] rf() saveState() if cb then cb(S[key]) end end)
    rf() if cb then cb(S[key]) end yC=yC+30 table.insert(rfs,rf)
end

stopBtn.MouseButton1Click:Connect(function()
    for k in pairs(S)do S[k]=false end
    for _,rf in ipairs(rfs)do rf()end
    task.wait(0.1) g:Destroy()
end)

T("Ash Upgrades","ua")
T("Gain Miasma","gm")
T("Black Screen","black",function(on)blackScreen.Visible=on end)
local sep2=Instance.new("Frame") sep2.Size=UDim2.new(1,-10,0,1) sep2.Position=UDim2.new(0,5,0,yC+3) sep2.BackgroundColor3=Color3.fromRGB(55,55,55) sep2.BorderSizePixel=0 sep2.Parent=ctrlFrame yC=yC+10
T("TP Miasma","tm"); T("TP Ash","ta"); T("TP Manual","tn"); T("TP Beast","tb")
T("Auto Return","tele")
local savePosBtn=Instance.new("TextButton") savePosBtn.Size=UDim2.new(1,-10,0,24) savePosBtn.Position=UDim2.new(0,5,0,yC) savePosBtn.BackgroundColor3=Color3.fromRGB(35,55,80) savePosBtn.TextColor3=Color3.fromRGB(120,180,255) savePosBtn.Text="Save Position" savePosBtn.TextSize=12 savePosBtn.Font=Enum.Font.Gotham savePosBtn.BorderSizePixel=0 savePosBtn.Parent=ctrlFrame Instance.new("UICorner",savePosBtn).CornerRadius=UDim.new(0,4) yC=yC+28
ctrlFrame.Size=UDim2.new(1,0,0,yC+4)

-- server frame
local serverFrame=Instance.new("Frame") serverFrame.Size=UDim2.new(1,0,0,58) serverFrame.Position=UDim2.new(0,0,0,62) serverFrame.BackgroundTransparency=1 serverFrame.BorderSizePixel=0 serverFrame.Visible=false serverFrame.Parent=pan
local rejoinBtn=Instance.new("TextButton") rejoinBtn.Size=UDim2.new(1,-10,0,34) rejoinBtn.Position=UDim2.new(0,5,0,12) rejoinBtn.BackgroundColor3=Color3.fromRGB(35,40,70) rejoinBtn.TextColor3=Color3.fromRGB(160,180,255) rejoinBtn.Text="Rejoin Server" rejoinBtn.TextSize=13 rejoinBtn.Font=Enum.Font.GothamBold rejoinBtn.BorderSizePixel=0 rejoinBtn.Parent=serverFrame Instance.new("UICorner",rejoinBtn).CornerRadius=UDim.new(0,6)
rejoinBtn.MouseButton1Click:Connect(function()
    rejoinBtn.Text="Rejoining..."
    pcall(function()TS:TeleportToPlaceInstance(game.PlaceId,game.JobId,PL)end)
end)

-- tab switching
local function switchTab(t)
    local frames={ctrl=ctrlFrame,server=serverFrame}
    local tabs={ctrl=tabCtrl,server=tabServer}
    for k,f in pairs(frames) do f.Visible=(k==t) end
    for k,tb in pairs(tabs) do
        tb.BackgroundColor3=(k==t) and Color3.fromRGB(50,50,70) or Color3.fromRGB(30,30,30)
        tb.TextColor3=(k==t) and Color3.fromRGB(220,220,220) or Color3.fromRGB(130,130,130)
    end
    pan.Size=UDim2.new(0,200,0,62+frames[t].Size.Y.Offset+6)
end
tabCtrl.MouseButton1Click:Connect(function()switchTab("ctrl")end)
tabServer.MouseButton1Click:Connect(function()switchTab("server")end)
switchTab("ctrl")

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

-- anti-AFK: right-click via VirtualUser on Idled event
PL.Idled:Connect(function()
    VU:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    task.wait(1)
    VU:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)

-- auto return loop
task.spawn(function()
    while true do
        task.wait(1)
        if S.tele and savedPos then
            local char=PL.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position-savedPos).Magnitude>20 then
                pcall(function()hrp.CFrame=CFrame.new(savedPos)end)
            end
        end
    end
end)

local AS={"AshAshMultiplier","AshLuckMultiplier","AshQiMultiplier"}
task.spawn(function()while true do if S.ua then for _,id in ipairs(AS)do F("PurchaseUpgrade",id,false) task.wait(0.1)end else task.wait(0.5)end end end)
task.spawn(function()while true do if S.gm then F("GainMiasma")end task.wait()end end)
local ch=PL.Character or PL.CharacterAdded:Wait()
local hr=ch:WaitForChild("HumanoidRootPart")
local TP={{k="tm",p=Vector3.new(402.5,10.5,549),d=6},{k="ta",p=Vector3.new(488,10.5,532.3),d=6},{k="tn",p=Vector3.new(390.6,12,598.2),d=6},{k="tb",p=Vector3.new(172.1,18.5,-31.3),d=15}}
task.spawn(function()local i=1 while true do local t=TP[i] if S[t.k]then hr.CFrame=CFrame.new(t.p) task.wait(t.d)else task.wait(0.1)end i=i%#TP+1 end end)
warn("[Auto] Ready.")
