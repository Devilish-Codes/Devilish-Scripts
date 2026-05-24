local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local PL=game:GetService("Players").LocalPlayer
local rem=RS:WaitForChild("RemoteEvents",10)
if not rem then return end
local function F(n,...)local r=rem:FindFirstChild(n)if r and r:IsA("RemoteEvent")then r:FireServer(...)end end
local S={up=false,bs=false,mf=false,gm=false,afk=false,tm=false,ta=false,tn=false,tb=false}
local g=Instance.new("ScreenGui")
g.Name="AutoGui" g.ResetOnSpawn=false
pcall(function()g.Parent=gethui()end)
if not g.Parent then g.Parent=game:GetService("CoreGui")end
local pan=Instance.new("Frame")
pan.Size=UDim2.new(0,200,0,10) pan.Position=UDim2.new(0,12,0,12)
pan.BackgroundColor3=Color3.fromRGB(20,20,20) pan.BorderSizePixel=0 pan.Parent=g
Instance.new("UICorner",pan).CornerRadius=UDim.new(0,8)
local ttl=Instance.new("TextLabel")
ttl.Size=UDim2.new(1,0,0,30) ttl.BackgroundColor3=Color3.fromRGB(35,35,35)
ttl.TextColor3=Color3.fromRGB(220,220,220) ttl.Text="[ AUTOMATION ]"
ttl.TextSize=14 ttl.Font=Enum.Font.GothamBold ttl.BorderSizePixel=0 ttl.Parent=pan
Instance.new("UICorner",ttl).CornerRadius=UDim.new(0,8)
local dr,ds,ps
ttl.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true ds=i.Position ps=pan.Position end end)
UIS.InputChanged:Connect(function(i)if dr and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds pan.Position=UDim2.new(ps.X.Scale,ps.X.Offset+d.X,ps.Y.Scale,ps.Y.Offset+d.Y)end end)
UIS.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end end)
local yP=34
local function T(lbl,key)
local b=Instance.new("TextButton")
b.Size=UDim2.new(1,-10,0,26) b.Position=UDim2.new(0,5,0,yP)
b.BorderSizePixel=0 b.TextSize=12 b.Font=Enum.Font.Gotham b.Parent=pan
Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
local function rf()if S[key]then b.Text=lbl.." ON" b.BackgroundColor3=Color3.fromRGB(25,70,25) b.TextColor3=Color3.fromRGB(80,230,80)else b.Text=lbl.." OFF" b.BackgroundColor3=Color3.fromRGB(70,25,25) b.TextColor3=Color3.fromRGB(230,80,80)end end
b.MouseButton1Click:Connect(function()S[key]=not S[key] rf()end)
rf() yP=yP+30
end
T("Upgrades","up"); T("Beast Stage","bs"); T("Mark Fire","mf"); T("Gain Miasma","gm"); T("Anti-AFK","afk")
local sep=Instance.new("Frame") sep.Size=UDim2.new(1,-10,0,1) sep.Position=UDim2.new(0,5,0,yP+3) sep.BackgroundColor3=Color3.fromRGB(55,55,55) sep.BorderSizePixel=0 sep.Parent=pan yP=yP+10
T("TP Miasma","tm"); T("TP Ash","ta"); T("TP Manual","tn"); T("TP Beast","tb")
pan.Size=UDim2.new(0,200,0,yP+6)
local UP={"MiasmaMiasmaMultiplier","MiasmaLuckMultiplier","MiasmaQiMultiplier"}
task.spawn(function()while true do if S.up then for _,id in ipairs(UP)do F("PurchaseUpgrade",id,true) task.wait(0.05)end end task.wait(1)end end)
task.spawn(function()while true do if S.bs then F("SetBeastStage",200)end task.wait(5)end end)
task.spawn(function()while true do if S.mf then F("MiasmaMarkPress") F("AshMarkPress") F("CultivationManualRerollPulse")end task.wait(0.5)end end)
task.spawn(function()while true do if S.gm then F("GainMiasma")end task.wait()end end)
task.spawn(function()while true do task.wait(60) if S.afk then local h=PL.Character and PL.Character:FindFirstChildOfClass("Humanoid") if h then h.Jump=true end end end end)
local ch=PL.Character or PL.CharacterAdded:Wait()
local hr=ch:WaitForChild("HumanoidRootPart")
local TP={{k="tm",p=Vector3.new(402.5,10.5,549),d=6},{k="ta",p=Vector3.new(488,10.5,532.3),d=6},{k="tn",p=Vector3.new(390.6,12,598.2),d=6},{k="tb",p=Vector3.new(172.1,18.5,-31.3),d=15}}
task.spawn(function()local i=1 while true do local t=TP[i] if S[t.k]then hr.CFrame=CFrame.new(t.p) task.wait(t.d)else task.wait(0.1)end i=i%#TP+1 end end)
warn("[Auto] Ready.")
