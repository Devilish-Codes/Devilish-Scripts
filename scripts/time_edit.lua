local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local PL      = Players.LocalPlayer
while not PL do task.wait() PL = Players.LocalPlayer end

-- ─── Number system ────────────────────────────────────────────────────────────
local SFXS = {
    {"Dc",1e33},{"No",1e30},{"O",1e27},{"Sp",1e24},{"Sx",1e21},
    {"Qn",1e18},{"Qd",1e15},{"T",1e12},{"B",1e9},{"M",1e6},{"K",1e3},
}
local function parseNum(txt)
    txt = txt:gsub(",",""):gsub("%s","")
    for _,p in ipairs(SFXS) do
        local n = txt:lower():match("^([%d%.]+)"..p[1]:lower().."$")
        if n then return tonumber(n)*p[2] end
    end
    return tonumber(txt) or 0
end
local function fmtNum(n, prec)
    if n < 0 then n = 0 end
    prec = prec or 2
    for _,p in ipairs(SFXS) do
        if n >= p[2] then
            local r = n/p[2]
            if prec < 0 then
                return string.format("%."..((-prec)).."g", r)..p[1]
            end
            return (string.format("%."..(prec).."f", r):gsub("%.?0+$",""))..p[1]
        end
    end
    return tostring(math.floor(n+0.5))
end

-- ─── Stat finder ──────────────────────────────────────────────────────────────
local cache = {}
local function findValueNear(nameObj)
    local containers = {nameObj.Parent}
    if nameObj.Parent and nameObj.Parent.Parent then
        containers[2] = nameObj.Parent.Parent
    end
    for _,c in ipairs(containers) do
        for _,child in ipairs(c:GetDescendants()) do
            if child:IsA("TextLabel") and child ~= nameObj
                and child.Text:match("^%s*%d") then return child end
        end
        for _,child in ipairs(c:GetDescendants()) do
            if child:IsA("TextLabel") and child ~= nameObj
                and child.Text ~= "" and child.Text ~= nameObj.Text then return child end
        end
    end
end
local function findStat(kw)
    if cache[kw] and cache[kw].Parent then return cache[kw] end
    for _,obj in ipairs(PL.PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Text:lower():find(kw,1,true) then
            local v = findValueNear(obj)
            if v then cache[kw]=v return v end
        end
    end
end
local function findAny(keys)
    for _,k in ipairs(keys) do
        local r = findStat(k) if r then return r end
    end
end

-- ─── Notify ───────────────────────────────────────────────────────────────────
local notifyLbl, notifyThread
local function notify(msg, err)
    if not notifyLbl or not notifyLbl.Parent then return end
    notifyLbl.Text = msg
    notifyLbl.TextColor3 = err and Color3.fromRGB(255,100,100) or Color3.fromRGB(100,255,130)
    if notifyThread then task.cancel(notifyThread) end
    notifyThread = task.delay(3, function()
        if notifyLbl and notifyLbl.Parent then notifyLbl.Text = "" end
    end)
end

-- ─── Actions ──────────────────────────────────────────────────────────────────
local timeFrozen, frozenText, freezeConn = false, nil, nil

local function parseTime(t)
    return tonumber(t:match("(%d+)%s*d")) or 0,
           tonumber(t:match("(%d+)%s*h")) or 0,
           tonumber(t:match("(%d+)%s*m")) or 0
end
local function fmtTime(d,h,m)
    local p={}
    if d>0 then p[#p+1]=d.."d" end
    if h>0 then p[#p+1]=h.."h" end
    if m>0 or #p==0 then p[#p+1]=m.."m" end
    return table.concat(p," ")
end
local function setFrozen(txt)
    frozenText = txt
    if timeFrozen and not freezeConn then
        freezeConn = task.spawn(function()
            while timeFrozen do
                local l=findStat("time played") if l then l.Text=frozenText end
                task.wait(0.05)
            end
            freezeConn=nil
        end)
    end
end
local function shiftTime(dd,dh,dm)
    local lbl=findStat("time played")
    if not lbl then notify("Not found: Time Played",true) return end
    local d,h,m=parseTime(timeFrozen and frozenText or lbl.Text)
    local tm=m+dm  local th=h+dh+math.floor(tm/60)
    m=tm%60  h=th%24  d=math.max(0,d+dd+math.floor(th/24))
    local txt=fmtTime(d,h,m)
    lbl.Text=txt  if timeFrozen then frozenText=txt end
end
local function addTo(keys, label, delta, prec)
    local lbl=findAny(keys)
    if not lbl then
        for _,k in ipairs(keys) do cache[k]=nil end
        notify("Not found: "..label, true) return
    end
    lbl.Text=fmtNum(parseNum(lbl.Text)+delta, prec)
    notify((delta>=0 and "+" or "")..fmtNum(math.abs(delta)).." "..label.." \u{2713}",false)
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
local BG        = Color3.fromRGB(22, 8, 40)
local BDIV      = Color3.fromRGB(60, 18, 95)
local CADD      = Color3.fromRGB(38, 110, 38)
local CSUB      = Color3.fromRGB(110, 28, 28)
local CTAB_ON   = Color3.fromRGB(55, 18, 90)
local CTAB_OFF  = Color3.fromRGB(16,  5, 30)
local CFREEZE   = Color3.fromRGB(38, 110, 38)
local CUNFREEZE = Color3.fromRGB(110, 60, 10)
local PANEL_W   = 264

-- ─── UI helpers ───────────────────────────────────────────────────────────────
local function mkBtn(parent, text, bg, x, y, w, h)
    local b = Instance.new("TextButton", parent)
    b.Size=UDim2.new(0,w,0,h) b.Position=UDim2.new(0,x,0,y)
    b.BackgroundColor3=bg b.TextColor3=Color3.new(1,1,1)
    b.Text=text b.TextSize=11 b.Font=Enum.Font.GothamBold
    b.BorderSizePixel=0 b.TextStrokeTransparency=1
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    return b
end
local function mkLbl(parent, text, x, y, w, h)
    local l=Instance.new("TextLabel",parent)
    l.Size=UDim2.new(0,w,0,h) l.Position=UDim2.new(0,x,0,y)
    l.BackgroundTransparency=1 l.TextColor3=Color3.fromRGB(210,185,255)
    l.Text=text l.TextSize=12 l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left l.TextStrokeTransparency=1
    return l
end
local function mkDiv(parent, y)
    local d=Instance.new("Frame",parent)
    d.Size=UDim2.new(1,-12,0,1) d.Position=UDim2.new(0,6,0,y)
    d.BackgroundColor3=BDIV d.BorderSizePixel=0
end
-- Row of +/- button pairs. tiers = {{label,delta}, ...}
local function mkRow(parent, keys, label, tiers, y, prec)
    local PAD=8  local GAP=3
    local bw = math.floor((PANEL_W - PAD*2 - GAP*(#tiers-1)) / #tiers)
    for i,t in ipairs(tiers) do
        local bx = PAD + (i-1)*(bw+GAP)
        local b  = mkBtn(parent, t[1], t[2]>=0 and CADD or CSUB, bx, y, bw, 26)
        local kk,ll,dd,pp = keys,label,t[2],prec
        b.MouseButton1Click:Connect(function() addTo(kk,ll,dd,pp) end)
    end
end

-- ─── Root GUI ────────────────────────────────────────────────────────────────
local g = Instance.new("ScreenGui")
g.ResetOnSpawn=false g.Name="StatEditor" g.IgnoreGuiInset=true g.Parent=PL.PlayerGui

local panel = Instance.new("Frame",g)
panel.BackgroundColor3=BG panel.BorderSizePixel=0
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,8)
local ps=Instance.new("UIStroke",panel)
ps.Color=BDIV ps.Thickness=1.5 ps.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

-- Title
local titleBar=Instance.new("Frame",panel)
titleBar.Size=UDim2.new(1,0,0,28) titleBar.BackgroundColor3=Color3.fromRGB(32,10,58) titleBar.BorderSizePixel=0
Instance.new("UICorner",titleBar).CornerRadius=UDim.new(0,8)
local tl=mkLbl(titleBar,"Stat Editor",10,0,PANEL_W-40,28) tl.TextSize=13 tl.TextColor3=Color3.new(1,1,1)
local xb=mkBtn(titleBar,"X",Color3.fromRGB(140,18,35),PANEL_W-28,4,24,20)
xb.MouseButton1Click:Connect(function() timeFrozen=false g:Destroy() end)

-- Drag
local drag,ds,dp=false,nil,nil
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true ds=UIS:GetMouseLocation() dp=panel.AbsolutePosition
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)
UIS.InputChanged:Connect(function(i)
    if not drag or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local cur=UIS:GetMouseLocation()
    panel.Position=UDim2.new(0,dp.X+(cur.X-ds.X),0,dp.Y+(cur.Y-ds.Y))
end)

-- Tab bar
local TAB_W=math.floor(PANEL_W/4)
local tabBar=Instance.new("Frame",panel)
tabBar.Size=UDim2.new(1,0,0,26) tabBar.Position=UDim2.new(0,0,0,28)
tabBar.BackgroundColor3=Color3.fromRGB(12,4,24) tabBar.BorderSizePixel=0

local CONTENT_Y = 54
local tabBtns, tabFrames, tabHeights = {}, {}, {}

for i,name in ipairs({"Main","Rarest","Daily","Coins"}) do
    local tb=mkBtn(tabBar,name,i==1 and CTAB_ON or CTAB_OFF,(i-1)*TAB_W,0,TAB_W,26)
    tb.TextSize=12 tabBtns[i]=tb
    local f=Instance.new("Frame",panel)
    f.Position=UDim2.new(0,0,0,CONTENT_Y) f.BackgroundTransparency=1
    f.BorderSizePixel=0 f.Visible=i==1
    tabFrames[i]=f
end

-- Notify label (always at bottom of panel)
local notifyBar=Instance.new("Frame",panel)
notifyBar.BackgroundTransparency=1 notifyBar.BorderSizePixel=0
notifyLbl=mkLbl(notifyBar,"",8,0,PANEL_W-16,20)
notifyLbl.TextSize=11

local function setPanel(tabIdx)
    for i,tb in ipairs(tabBtns) do
        tb.BackgroundColor3=i==tabIdx and CTAB_ON or CTAB_OFF
        tabFrames[i].Visible=i==tabIdx
    end
    local h=tabHeights[tabIdx] or 0
    notifyBar.Position=UDim2.new(0,0,0,CONTENT_Y+h+2)
    notifyBar.Size=UDim2.new(1,0,0,20)
    panel.Size=UDim2.new(0,PANEL_W,0,CONTENT_Y+h+26)
end
for i,tb in ipairs(tabBtns) do
    local idx=i tb.MouseButton1Click:Connect(function() setPanel(idx) end)
end

-- ─── Tab 1: Main ─────────────────────────────────────────────────────────────
do
    local f=tabFrames[1]  local cy=0
    mkDiv(f,cy) cy=cy+6

    -- Time Played header + freeze
    mkLbl(f,"Time Played",8,cy+2,80,22)
    local fb=mkBtn(f,"Freeze",CFREEZE,PANEL_W-64,cy,56,26)
    fb.MouseButton1Click:Connect(function()
        timeFrozen=not timeFrozen
        if timeFrozen then
            local l=findStat("time played") setFrozen(l and l.Text or "0m")
            fb.Text="Unfreeze" fb.BackgroundColor3=CUNFREEZE notify("Time frozen",false)
        else
            timeFrozen=false frozenText=nil
            fb.Text="Freeze" fb.BackgroundColor3=CFREEZE notify("Time unfrozen",false)
        end
    end)
    cy=cy+30

    -- +/- day/hour/min
    local BW=38 local steps={{"+1d",1,0,0},{"-1d",-1,0,0},{"+1h",0,1,0},{"-1h",0,-1,0},{"+1m",0,0,1},{"-1m",0,0,-1}}
    local sp=math.floor((PANEL_W-16-#steps*BW)/(#steps-1))
    for i,s in ipairs(steps) do
        local bx=8+(i-1)*(BW+sp)
        local bg=(s[2]+s[3]+s[4])>0 and CADD or CSUB
        local b=mkBtn(f,s[1],bg,bx,cy,BW,24)
        local sv=s b.MouseButton1Click:Connect(function() shiftTime(sv[2],sv[3],sv[4]) end)
    end
    cy=cy+28

    mkDiv(f,cy) cy=cy+6

    -- Rolls
    mkLbl(f,"Rolls",8,cy,PANEL_W-16,22) cy=cy+24
    mkRow(f,{"number of roll","rolls"},"Rolls",
        {{"+100K",100e3},{"-100K",-100e3},{"+10K",10e3},{"-10K",-10e3}},cy)
    cy=cy+30

    mkDiv(f,cy) cy=cy+6
    mkLbl(f,"Enemies Killed",8,cy,PANEL_W-16,22) cy=cy+24
    local EKEYS={"enemies killed","killed","enemies"}
    mkRow(f,EKEYS,"Enemies",{{"+1M",1e6},{"+100K",100e3},{"+10K",10e3}},cy) cy=cy+30
    mkRow(f,EKEYS,"Enemies",{{"-1M",-1e6},{"-100K",-100e3},{"-10K",-10e3}},cy) cy=cy+28

    f.Size=UDim2.new(1,0,0,cy) tabHeights[1]=cy
end

-- ─── Tab 2: Rarest Roll ───────────────────────────────────────────────────────
do
    local f=tabFrames[2]  local cy=0
    local KEYS={"rarest roll","rarest"}
    mkDiv(f,cy) cy=cy+6
    mkLbl(f,"Rarest Roll",8,cy,PANEL_W-16,22) cy=cy+26

    local rows={
        {{"+10Dc",10e33},{"-10Dc",-10e33},{"+1Dc",1e33},{"-1Dc",-1e33}},
        {{"+10No",10e30},{"-10No",-10e30},{"+1No",1e30},{"-1No",-1e30}},
        {{"+10O",10e27},{"-10O",-10e27},{"+1O",1e27},{"-1O",-1e27}},
        {{"+10Sp",10e24},{"-10Sp",-10e24},{"+1Sp",1e24},{"-1Sp",-1e24}},
        {{"+10Sx",10e21},{"-10Sx",-10e21},{"+1Sx",1e21},{"-1Sx",-1e21}},
        {{"+10Qn",10e18},{"-10Qn",-10e18},{"+1Qn",1e18},{"-1Qn",-1e18}},
        {{"+100Qd",100e15},{"-100Qd",-100e15},{"+10Qd",10e15},{"-10Qd",-10e15}},
        {{"+1Qd",1e15},{"-1Qd",-1e15}},
    }
    for _,row in ipairs(rows) do mkRow(f,KEYS,"Rarest",row,cy,-4) cy=cy+30 end

    f.Size=UDim2.new(1,0,0,cy) tabHeights[2]=cy
end

-- ─── Tab 3: Daily Rarest ──────────────────────────────────────────────────────
do
    local f=tabFrames[3]  local cy=0
    local KEYS={"daily rarest roll","daily rarest","daily"}
    mkDiv(f,cy) cy=cy+6
    mkLbl(f,"Daily Rarest Roll",8,cy,PANEL_W-16,22) cy=cy+26

    local rows={
        {{"+10Dc",10e33},{"-10Dc",-10e33},{"+1Dc",1e33},{"-1Dc",-1e33}},
        {{"+10No",10e30},{"-10No",-10e30},{"+1No",1e30},{"-1No",-1e30}},
        {{"+10O",10e27},{"-10O",-10e27},{"+1O",1e27},{"-1O",-1e27}},
        {{"+10Sp",10e24},{"-10Sp",-10e24},{"+1Sp",1e24},{"-1Sp",-1e24}},
        {{"+10Sx",10e21},{"-10Sx",-10e21},{"+1Sx",1e21},{"-1Sx",-1e21}},
        {{"+10Qn",10e18},{"-10Qn",-10e18},{"+1Qn",1e18},{"-1Qn",-1e18}},
        {{"+100Qd",100e15},{"-100Qd",-100e15},{"+10Qd",10e15},{"-10Qd",-10e15}},
        {{"+1Qd",1e15},{"-1Qd",-1e15},{"+100T",100e12},{"-100T",-100e12}},
        {{"+10T",10e12},{"-10T",-10e12},{"+1T",1e12},{"-1T",-1e12}},
    }
    for _,row in ipairs(rows) do mkRow(f,KEYS,"Daily",row,cy,-4) cy=cy+30 end

    f.Size=UDim2.new(1,0,0,cy) tabHeights[3]=cy
end

-- ─── Tab 4: Coins ─────────────────────────────────────────────────────────────
do
    local f=tabFrames[4]  local cy=0
    local KEYS={"total coins earned","coins earned","coins"}
    mkDiv(f,cy) cy=cy+6
    mkLbl(f,"Total Coins Earned",8,cy,PANEL_W-16,22) cy=cy+26
    local rows={
        {{"+100Sp",100e24},{"-100Sp",-100e24},{"+10Sp",10e24},{"-10Sp",-10e24}},
        {{"+1Sp",1e24},{"-1Sp",-1e24},{"+100Sx",100e21},{"-100Sx",-100e21}},
        {{"+10Sx",10e21},{"-10Sx",-10e21}},
    }
    for _,row in ipairs(rows) do mkRow(f,KEYS,"Coins",row,cy,-5) cy=cy+30 end
    f.Size=UDim2.new(1,0,0,cy) tabHeights[4]=cy
end

-- Initial panel size
setPanel(1)
panel.Position=UDim2.new(0.5,-math.floor(PANEL_W/2),0,12)
