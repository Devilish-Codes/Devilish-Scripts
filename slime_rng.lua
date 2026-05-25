local _c=string.char
local _wf,_rf,_gh,_sr,_grm,_gnm,_fpp,_fti
pcall(function()
    _wf=writefile _rf=readfile _gh=gethui
    _sr=setreadonly _grm=getrawmetatable _gnm=getnamecallmethod
    _fpp=fireproximityprompt _fti=firetouchinterest
end)
local _r0=game:GetService(_c(82,101,112,108,105,99,97,116,101,100,83,116,111,114,97,103,101))
local _r1=game:GetService(_c(85,115,101,114,73,110,112,117,116,83,101,114,118,105,99,101))
local _r2=game:GetService(_c(80,108,97,121,101,114,115)).LocalPlayer
local _r3=game:GetService(_c(82,117,110,83,101,114,118,105,99,101))
local _r4=game:GetService(_c(84,101,108,101,112,111,114,116,83,101,114,118,105,99,101))
local _v0=nil
task.spawn(function()
    for _=1,20 do
        for _,v in ipairs(_r0:GetDescendants()) do
            if v.Name==_c(82,111,108,108,83,101,114,118,105,99,101) and v:IsA(_c(70,111,108,100,101,114)) then
                local r=v:FindFirstChildOfClass(_c(82,101,109,111,116,101,70,117,110,99,116,105,111,110)) if r then _v0=r return end
            end
        end task.wait(0.5)
    end
end)
local _v1,_v2,_v3=nil,nil,0
local _k0={_c(103,117,110),_c(114,111,108,108),_c(99,111,108,108,101,99,116),_c(116,101,108,101),_c(98,108,97,99,107)}
local _st={[_k0[1]]=false,[_k0[2]]=false,[_k0[3]]=false,[_k0[4]]=false,[_k0[5]]=false}
local _v5={}
local _f0=_c(115,108,105,109,101,95,114,110,103,95,115,116,97,116,101,46,116,120,116)
local function _fn0()
    local p={}
    for _,k in ipairs(_k0) do p[#p+1]=k..(_c(61))..(_st[k] and _c(49) or _c(48)) end
    pcall(_wf,_f0,table.concat(p,_c(59)))
end
local function _fn1()
    local ok,d=pcall(_rf,_f0)
    if not ok or not d then return end
    for pair in d:gmatch(_c(91,94,59,93,43)) do
        local k,v=pair:match(_c(94,40,46,45,41,61,40,46,43,41,36))
        if k and _st[k]~=nil then _st[k]=(v==_c(49)) end
    end
end
_fn1()
local _p0=nil
local _f1=_c(115,108,105,109,101,95,114,110,103,95,112,111,115,46,116,120,116)
local function _fn2()
    if _p0 then pcall(_wf,_f1,_p0.X..(_c(44)).._p0.Y..(_c(44)).._p0.Z) end
end
local function _fn3()
    local ok,d=pcall(_rf,_f1)
    if not ok or not d then return end
    local x,y,z=d:match(_c(94,40,91,45,37,46,37,100,93,43,41,44,40,91,45,37,46,37,100,93,43,41,44,40,91,45,37,46,37,100,93,43,41,36))
    if x then _p0=Vector3.new(tonumber(x),tonumber(y),tonumber(z)) end
end
_fn3()
local _ui0
local _f2=_c(115,108,105,109,101,95,114,110,103,95,117,105,112,111,115,46,116,120,116)
local function _fn4()
    if not _ui0 then return end
    pcall(_wf,_f2,_ui0.Position.X.Offset..(_c(44)).._ui0.Position.Y.Offset)
end
local function _fn5()
    if not _ui0 then return end
    local ok,d=pcall(_rf,_f2)
    if not ok or not d then return end
    local x,y=d:match(_c(94,40,45,63,37,100,43,41,44,40,45,63,37,100,43,41,36))
    if x then _ui0.Position=UDim2.new(0,tonumber(x),0,tonumber(y)) end
end
task.spawn(function()
    task.wait(1)
    local function sc()
        local bn=-1
        for _,v in ipairs(_r0:GetDescendants()) do
            if v:IsA(_c(82,101,109,111,116,101,69,118,101,110,116)) then
                local n=v.Parent and tonumber(v.Parent.Name:match(_c(94,71,97,109,101,112,108,97,121,40,37,100,43,41,36)))
                if n and n>bn then _v1=v bn=n end
            end
            if v:IsA(_c(82,101,109,111,116,101,70,117,110,99,116,105,111,110)) and v.Parent and v.Parent.Name==_c(83,108,105,109,101,71,117,110,83,101,114,118,105,99,101) then
                _v2=v
            end
        end
    end
    while not(_v1 and _v2) do sc() task.wait(3) end
    while true do task.wait(30) sc() end
end)
local _e0={}
task.spawn(function()
    while true do
        local t={}
        for _,v in ipairs(workspace:GetChildren()) do
            if v.Name:match(_c(94,71,97,109,101,112,108,97,121,37,100,43,36)) then
                local ef=v:FindFirstChild(_c(69,110,101,109,105,101,115))
                if ef then
                    for _,e in ipairs(ef:GetChildren()) do
                        local id=tonumber(e.Name) if id then t[#t+1]=id end
                    end
                end
            end
        end
        _e0=t task.wait(0.5)
    end
end)
local _ui1=Instance.new(_c(83,99,114,101,101,110,71,117,105)) _ui1.Name=_c(83,108,105,109,101,71,117,105) _ui1.ResetOnSpawn=false _ui1.DisplayOrder=1
pcall(function()_ui1.Parent=_gh()end)
if not _ui1.Parent then _ui1.Parent=game:GetService(_c(67,111,114,101,71,117,105))end
local _ui2=Instance.new(_c(83,99,114,101,101,110,71,117,105)) _ui2.Name=_c(83,108,105,109,101,66,108,97,99,107) _ui2.ResetOnSpawn=false _ui2.IgnoreGuiInset=true _ui2.DisplayOrder=0
pcall(function()_ui2.Parent=_gh()end)
if not _ui2.Parent then _ui2.Parent=game:GetService(_c(67,111,114,101,71,117,105))end
local _ui3=Instance.new(_c(70,114,97,109,101)) _ui3.Size=UDim2.new(1,0,1,0) _ui3.BackgroundColor3=Color3.fromRGB(0,0,0) _ui3.BorderSizePixel=0 _ui3.Visible=_st[_k0[5]] _ui3.Parent=_ui2
_ui0=Instance.new(_c(70,114,97,109,101)) _ui0.Size=UDim2.new(0,220,0,10) _ui0.Position=UDim2.new(0,12,0,12) _ui0.BackgroundColor3=Color3.fromRGB(20,20,20) _ui0.BorderSizePixel=0 _ui0.Parent=_ui1 Instance.new(_c(85,73,67,111,114,110,101,114),_ui0).CornerRadius=UDim.new(0,8)
local _ui4=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) _ui4.Size=UDim2.new(0,44,0,44) _ui4.Position=UDim2.new(1,-56,0,12) _ui4.BackgroundColor3=Color3.fromRGB(35,35,35) _ui4.TextColor3=Color3.fromRGB(220,220,220) _ui4.Text=_c(83) _ui4.TextSize=16 _ui4.Font=Enum.Font.GothamBold _ui4.BorderSizePixel=0 _ui4.Visible=false _ui4.Parent=_ui1 Instance.new(_c(85,73,67,111,114,110,101,114),_ui4).CornerRadius=UDim.new(1,0)
local _ui5=Instance.new(_c(84,101,120,116,76,97,98,101,108)) _ui5.Size=UDim2.new(1,-68,0,30) _ui5.BackgroundColor3=Color3.fromRGB(35,35,35) _ui5.TextColor3=Color3.fromRGB(220,220,220) _ui5.Text=_c(76,120,99,105,102,101,114,32,83,99,114,105,112,116,115) _ui5.TextSize=13 _ui5.Font=Enum.Font.GothamBold _ui5.BorderSizePixel=0 _ui5.Parent=_ui0 Instance.new(_c(85,73,67,111,114,110,101,114),_ui5).CornerRadius=UDim.new(0,8)
local _ui6=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) _ui6.Size=UDim2.new(0,30,0,30) _ui6.Position=UDim2.new(1,-64,0,0) _ui6.BackgroundColor3=Color3.fromRGB(60,60,60) _ui6.TextColor3=Color3.fromRGB(220,220,220) _ui6.Text=_c(95) _ui6.TextSize=16 _ui6.Font=Enum.Font.GothamBold _ui6.BorderSizePixel=0 _ui6.ZIndex=2 _ui6.Parent=_ui0 Instance.new(_c(85,73,67,111,114,110,101,114),_ui6).CornerRadius=UDim.new(0,6)
local _ui7=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) _ui7.Size=UDim2.new(0,30,0,30) _ui7.Position=UDim2.new(1,-32,0,0) _ui7.BackgroundColor3=Color3.fromRGB(140,30,30) _ui7.TextColor3=Color3.fromRGB(255,255,255) _ui7.Text=_c(88) _ui7.TextSize=14 _ui7.Font=Enum.Font.GothamBold _ui7.BorderSizePixel=0 _ui7.ZIndex=2 _ui7.Parent=_ui0 Instance.new(_c(85,73,67,111,114,110,101,114),_ui7).CornerRadius=UDim.new(0,6)
local _d0,_d1,_d2
_ui5.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then _d0=true _d1=i.Position _d2=_ui0.Position end end)
_r1.InputChanged:Connect(function(i)if _d0 and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-_d1 _ui0.Position=UDim2.new(_d2.X.Scale,_d2.X.Offset+d.X,_d2.Y.Scale,_d2.Y.Offset+d.Y)end end)
_r1.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then if _d0 then _fn4() end _d0=false end end)
_fn5()
_ui6.MouseButton1Click:Connect(function()_ui0.Visible=false _ui4.Visible=true end)
_ui4.MouseButton1Click:Connect(function()_ui4.Visible=false _ui0.Visible=true end)
local function _fn6(lbl,x,w)
    local b=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) b.Size=UDim2.new(0,w,0,24) b.Position=UDim2.new(0,x,0,34) b.BackgroundColor3=Color3.fromRGB(30,30,30) b.TextColor3=Color3.fromRGB(130,130,130) b.TextSize=11 b.Font=Enum.Font.GothamBold b.BorderSizePixel=0 b.Text=lbl b.Parent=_ui0 Instance.new(_c(85,73,67,111,114,110,101,114),b).CornerRadius=UDim.new(0,4) return b
end
local _tab0=_fn6(_c(67,111,110,116,114,111,108,115),5,70)
local _tab1=_fn6(_c(83,116,97,116,115),78,70)
local _tab2=_fn6(_c(83,101,114,118,101,114),151,69)
local _fr0=Instance.new(_c(70,114,97,109,101)) _fr0.Size=UDim2.new(1,0,0,10) _fr0.Position=UDim2.new(0,0,0,62) _fr0.BackgroundTransparency=1 _fr0.BorderSizePixel=0 _fr0.Parent=_ui0
local _y0=4
local _sp0=Instance.new(_c(70,114,97,109,101)) _sp0.Size=UDim2.new(1,-10,0,1) _sp0.Position=UDim2.new(0,5,0,_y0) _sp0.BackgroundColor3=Color3.fromRGB(55,55,55) _sp0.BorderSizePixel=0 _sp0.Parent=_fr0 _y0=_y0+8
local function _fn7(lbl,key,cb)
    local b=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) b.Size=UDim2.new(1,-10,0,26) b.Position=UDim2.new(0,5,0,_y0) b.BorderSizePixel=0 b.TextSize=12 b.Font=Enum.Font.Gotham b.Parent=_fr0 Instance.new(_c(85,73,67,111,114,110,101,114),b).CornerRadius=UDim.new(0,4)
    local function rf()if _st[key]then b.Text=lbl.._c(32,79,78) b.BackgroundColor3=Color3.fromRGB(25,70,25) b.TextColor3=Color3.fromRGB(80,230,80)else b.Text=lbl.._c(32,79,70,70) b.BackgroundColor3=Color3.fromRGB(70,25,25) b.TextColor3=Color3.fromRGB(230,80,80)end end
    b.MouseButton1Click:Connect(function()_st[key]=not _st[key] rf() _fn0() if cb then cb(_st[key]) end end) rf() if cb then cb(_st[key]) end _y0=_y0+30 table.insert(_v5,rf)
end
_ui7.MouseButton1Click:Connect(function()
    for k in pairs(_st)do _st[k]=false end for _,rf in ipairs(_v5)do rf()end task.wait(0.1) _ui1:Destroy()
end)
_fn7(_c(65,117,116,111,32,71,117,110),_k0[1]); _fn7(_c(65,117,116,111,32,82,111,108,108),_k0[2]); _fn7(_c(65,117,116,111,32,67,111,108,108,101,99,116),_k0[3]); _fn7(_c(65,117,116,111,32,82,101,116,117,114,110),_k0[4])
_fn7(_c(66,108,97,99,107,32,83,99,114,101,101,110),_k0[5],function(on)_ui3.Visible=on end)
local _ui8=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) _ui8.Size=UDim2.new(1,-10,0,24) _ui8.Position=UDim2.new(0,5,0,_y0) _ui8.BackgroundColor3=Color3.fromRGB(35,55,80) _ui8.TextColor3=Color3.fromRGB(120,180,255) _ui8.Text=_c(83,97,118,101,32,80,111,115,105,116,105,111,110) _ui8.TextSize=12 _ui8.Font=Enum.Font.Gotham _ui8.BorderSizePixel=0 _ui8.Parent=_fr0 Instance.new(_c(85,73,67,111,114,110,101,114),_ui8).CornerRadius=UDim.new(0,4) _y0=_y0+28
local _ui9=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) _ui9.Size=UDim2.new(1,-10,0,24) _ui9.Position=UDim2.new(0,5,0,_y0) _ui9.BackgroundColor3=Color3.fromRGB(50,35,15) _ui9.TextColor3=Color3.fromRGB(255,180,60) _ui9.Text=_c(70,80,83,32,66,111,111,115,116) _ui9.TextSize=12 _ui9.Font=Enum.Font.Gotham _ui9.BorderSizePixel=0 _ui9.Parent=_fr0 Instance.new(_c(85,73,67,111,114,110,101,114),_ui9).CornerRadius=UDim.new(0,4) _y0=_y0+28
_fr0.Size=UDim2.new(1,0,0,_y0+4)
local _fr1=Instance.new(_c(70,114,97,109,101)) _fr1.Size=UDim2.new(1,0,0,10) _fr1.Position=UDim2.new(0,0,0,62) _fr1.BackgroundTransparency=1 _fr1.BorderSizePixel=0 _fr1.Visible=false _fr1.Parent=_ui0
local _y1=4
local function _fn8(txt)
    local l=Instance.new(_c(84,101,120,116,76,97,98,101,108)) l.Size=UDim2.new(1,-10,0,20) l.Position=UDim2.new(0,5,0,_y1) l.BackgroundTransparency=1 l.TextColor3=Color3.fromRGB(255,255,255) l.Text=txt l.TextSize=11 l.Font=Enum.Font.GothamBold l.BorderSizePixel=0 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=_fr1
    local p=Instance.new(_c(85,73,80,97,100,100,105,110,103),l) p.PaddingLeft=UDim.new(0,6)
    local st=Instance.new(_c(85,73,83,116,114,111,107,101),l) st.Color=Color3.fromRGB(0,0,0) st.Thickness=1.5 st.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
    _y1=_y1+23 return l
end
local function _fn9(tL,tR)
    local function mk(txt,xs,xo)
        local l=Instance.new(_c(84,101,120,116,76,97,98,101,108)) l.Size=UDim2.new(0.5,-7,0,20) l.Position=UDim2.new(xs,xo,0,_y1) l.BackgroundTransparency=1 l.TextColor3=Color3.fromRGB(255,255,255) l.Text=txt l.TextSize=11 l.Font=Enum.Font.GothamBold l.BorderSizePixel=0 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=_fr1
        Instance.new(_c(85,73,80,97,100,100,105,110,103),l).PaddingLeft=UDim.new(0,5)
        local st=Instance.new(_c(85,73,83,116,114,111,107,101),l) st.Color=Color3.fromRGB(0,0,0) st.Thickness=1.5 st.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
        return l
    end
    local lL=mk(tL,0,5) local lR=mk(tR,0.5,2) _y1=_y1+23 return lL,lR
end
local _lb0,_lb1=_fn9(_c(67,111,105,110,58,32,45,45),_c(71,111,111,112,58,32,45,45))
local _lb2,_lb3=_fn9(_c(47,109,105,110,32,45,45),_c(47,109,105,110,32,45,45))
local _lb4,_lb5=_fn9(_c(47,104,114,32,32,45,45),_c(47,104,114,32,32,45,45))
local _lb6,_lb7=_fn9(_c(47,100,97,121,32,45,45),_c(47,100,97,121,32,45,45))
local _lb8=_fn8(_c(83,101,115,115,105,111,110,58,32,32,48,58,48,48))
local _lb9=_fn8(_c(70,80,83,58,32,32,32,32,32,32,45,45))
local _ui10=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) _ui10.Size=UDim2.new(1,-10,0,22) _ui10.Position=UDim2.new(0,5,0,_y1) _ui10.BackgroundTransparency=1 _ui10.TextColor3=Color3.fromRGB(255,255,255) _ui10.Text=_c(82,101,115,101,116,32,83,101,115,115,105,111,110) _ui10.TextSize=11 _ui10.Font=Enum.Font.GothamBold _ui10.BorderSizePixel=0 _ui10.Parent=_fr1 Instance.new(_c(85,73,67,111,114,110,101,114),_ui10).CornerRadius=UDim.new(0,4)
local _rst=Instance.new(_c(85,73,83,116,114,111,107,101),_ui10) _rst.Color=Color3.fromRGB(0,0,0) _rst.Thickness=1.5 _rst.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
_y1=_y1+26
_fr1.Size=UDim2.new(1,0,0,_y1+4)
local _fr2=Instance.new(_c(70,114,97,109,101)) _fr2.Size=UDim2.new(1,0,0,58) _fr2.Position=UDim2.new(0,0,0,62) _fr2.BackgroundTransparency=1 _fr2.BorderSizePixel=0 _fr2.Visible=false _fr2.Parent=_ui0
local _ui11=Instance.new(_c(84,101,120,116,66,117,116,116,111,110)) _ui11.Size=UDim2.new(1,-10,0,34) _ui11.Position=UDim2.new(0,5,0,12) _ui11.BackgroundColor3=Color3.fromRGB(35,40,70) _ui11.TextColor3=Color3.fromRGB(160,180,255) _ui11.Text=_c(82,101,106,111,105,110,32,83,101,114,118,101,114) _ui11.TextSize=13 _ui11.Font=Enum.Font.GothamBold _ui11.BorderSizePixel=0 _ui11.Parent=_fr2 Instance.new(_c(85,73,67,111,114,110,101,114),_ui11).CornerRadius=UDim.new(0,6)
local function _fn10()
    for _,v in ipairs(_r0:GetDescendants())do
        if v:IsA(_c(82,101,109,111,116,101,69,118,101,110,116)) and v.Parent and v.Parent.Name==_c(65,117,116,111,82,101,106,111,105,110,83,101,114,118,105,99,101) then return v end
    end
end
_ui11.MouseButton1Click:Connect(function()
    _ui11.Text=_c(82,101,106,111,105,110,105,110,103,46,46,46)
    local re=_fn10()
    if re then pcall(function()re:FireServer(_c(97,117,116,111,82,101,106,111,105,110))end)
    else pcall(function()_r4:TeleportToPlaceInstance(game.PlaceId,game.JobId,_r2)end) end
end)
local function _fn11(t)
    local frames={[_c(99,116,114,108)]=_fr0,[_c(115,116,97,116,115)]=_fr1,[_c(115,101,114,118,101,114)]=_fr2}
    local tabs={[_c(99,116,114,108)]=_tab0,[_c(115,116,97,116,115)]=_tab1,[_c(115,101,114,118,101,114)]=_tab2}
    for k,f in pairs(frames) do f.Visible=(k==t) end
    for k,tb in pairs(tabs) do
        tb.BackgroundColor3=(k==t) and Color3.fromRGB(50,50,70) or Color3.fromRGB(30,30,30)
        tb.TextColor3=(k==t) and Color3.fromRGB(220,220,220) or Color3.fromRGB(130,130,130)
    end
    local isSt=(t==_c(115,116,97,116,115))
    _ui0.BackgroundTransparency=isSt and 0.85 or 0
    _ui5.BackgroundTransparency=isSt and 0.85 or 0
    _ui0.Size=UDim2.new(0,220,0,62+frames[t].Size.Y.Offset+6)
end
_tab0.MouseButton1Click:Connect(function()_fn11(_c(99,116,114,108))end)
_tab1.MouseButton1Click:Connect(function()_fn11(_c(115,116,97,116,115))end)
_tab2.MouseButton1Click:Connect(function()_fn11(_c(115,101,114,118,101,114))end)
_fn11(_c(99,116,114,108))
task.spawn(function()
    while true do
        local char=_r2.Character
        if char then
            local gun=char:FindFirstChild(_c(83,108,105,109,101,71,117,110)) or _r2[_c(66,97,99,107,112,97,99,107)]:FindFirstChild(_c(83,108,105,109,101,71,117,110))
            if gun and gun.Parent~=char then gun.Parent=char end
        end
        task.wait(0.1)
    end
end)
local _eft={[_c(80,97,114,116,105,99,108,101,69,109,105,116,116,101,114)]=true,[_c(84,114,97,105,108)]=true,[_c(66,101,97,109)]=true,[_c(83,109,111,107,101)]=true,[_c(70,105,114,101)]=true,[_c(83,112,97,114,107,108,101,115)]=true,[_c(68,101,99,97,108)]=true,[_c(84,101,120,116,117,114,101)]=true,[_c(80,111,105,110,116,76,105,103,104,116)]=true,[_c(83,112,111,116,76,105,103,104,116)]=true,[_c(83,117,114,102,97,99,101,76,105,103,104,116)]=true,[_c(66,105,108,108,98,111,97,114,100,71,117,105)]=true,[_c(83,117,114,102,97,99,101,71,117,105)]=true,[_c(83,101,108,101,99,116,105,111,110,66,111,120)]=true,[_c(83,101,108,101,99,116,105,111,110,83,112,104,101,114,101)]=true}
local _fps=false
_ui9.MouseButton1Click:Connect(function()
    _fps=true
    local Lt=game:GetService(_c(76,105,103,104,116,105,110,103))
    pcall(function()Lt[_c(71,108,111,98,97,108,83,104,97,100,111,119,115)]=false Lt[_c(70,111,103,69,110,100)]=1e6 end)
    for _,v in ipairs(Lt:GetChildren()) do
        if v:IsA(_c(80,111,115,116,69,102,102,101,99,116)) or v:IsA(_c(83,107,121)) then pcall(v.Destroy,v) end
    end
    local char=_r2.Character
    local hrp=char and char:FindFirstChild(_c(72,117,109,97,110,111,105,100,82,111,111,116,80,97,114,116))
    local origin=hrp and hrp.Position or Vector3.new(0,0,0)
    local removed=0
    for _,v in ipairs(workspace:GetDescendants()) do
        if _eft[v.ClassName] then
            pcall(v.Destroy,v) removed=removed+1
        elseif v:IsA(_c(66,97,115,101,80,97,114,116)) and v[_c(65,110,99,104,111,114,101,100)] then
            if not v[_c(67,97,110,67,111,108,108,105,100,101)] then
                pcall(v.Destroy,v) removed=removed+1
            elseif (v.Position-origin).Magnitude>300 then
                pcall(function()v[_c(84,114,97,110,115,112,97,114,101,110,99,121)]=1 v[_c(67,97,115,116,83,104,97,100,111,119)]=false end) removed=removed+1
            end
        end
    end
    _ui9.Text=_c(67,108,101,97,114,101,100,32)..removed
    task.delay(2,function()if _ui9 and _ui9.Parent then _ui9.Text=_c(70,80,83,32,66,111,111,115,116) end end)
end)
workspace.DescendantAdded:Connect(function(v)
    if _fps and _eft[v.ClassName] then pcall(v.Destroy,v) end
end)
_ui8.MouseButton1Click:Connect(function()
    local char=_r2.Character
    local hrp=char and char:FindFirstChild(_c(72,117,109,97,110,111,105,100,82,111,111,116,80,97,114,116))
    if hrp then
        _p0=hrp.Position+Vector3.new(0,1,0)
        _fn2()
        _ui8.Text=_c(83,97,118,101,100,33)
        task.delay(1.5,function()_ui8.Text=_c(83,97,118,101,32,80,111,115,105,116,105,111,110)end)
    end
end)
task.spawn(function()
    while true do
        task.wait(1)
        if _st[_k0[4]] and _p0 then
            local char=_r2.Character
            local hrp=char and char:FindFirstChild(_c(72,117,109,97,110,111,105,100,82,111,111,116,80,97,114,116))
            if hrp and (hrp.Position-_p0).Magnitude>20 then pcall(function()hrp.CFrame=CFrame.new(_p0)end) end
        end
    end
end)
local _g0,_c0,_t0=0,0,tick()
_ui10.MouseButton1Click:Connect(function()
    _g0=0 _c0=0 _t0=tick()
end)
local _hr0={}
local function _fn12(re)
    if _hr0[re] then return end
    _hr0[re]=true
    re.OnClientEvent:Connect(function(a1,a2)
        if a1==_c(103,111,111,112,82,101,119,97,114,100,101,100) and type(a2)==_c(116,97,98,108,101) then
            local amt=rawget(a2,_c(97,109,111,117,110,116))
            if type(amt)==_c(110,117,109,98,101,114) then _g0=_g0+amt end
        elseif a1==_c(99,111,105,110,82,101,119,97,114,100,101,100) and type(a2)==_c(116,97,98,108,101) then
            local amt=rawget(a2,_c(97,109,111,117,110,116))
            if type(amt)==_c(110,117,109,98,101,114) then _c0=_c0+amt end
        end
    end)
end
task.spawn(function()
    for _,v in ipairs(_r0:GetDescendants()) do
        if v:IsA(_c(82,101,109,111,116,101,69,118,101,110,116)) and v.Parent and v.Parent.Name:match(_c(94,71,97,109,101,112,108,97,121,37,100,43,36)) then
            _fn12(v)
        end
    end
    _r0.DescendantAdded:Connect(function(v)
        if v:IsA(_c(82,101,109,111,116,101,69,118,101,110,116)) and v.Parent and v.Parent.Name:match(_c(94,71,97,109,101,112,108,97,121,37,100,43,36)) then
            _fn12(v)
        end
    end)
end)
local _fc0=0
_r3.Heartbeat:Connect(function() _fc0=_fc0+1 end)
task.spawn(function()
    local sfx={_c(75),_c(77),_c(66),_c(84),_c(81,97),_c(81,105),_c(83,120),_c(83,112),_c(79,99),_c(78,111),_c(68,99)}
    local function fmt(n)
        if n<1000 then return tostring(math.floor(n)) end
        local i=math.floor(math.log(n)/math.log(1000))
        if i<1 then i=1 end
        if i<=#sfx then return string.format(_c(37,46,50,102,37,115),n/1000^i,sfx[i]) end
        local e=math.floor(math.log10(n))
        return string.format(_c(37,46,50,102,101,43,37,100),n/10^e,e)
    end
    local function fmtT(s)
        local h=math.floor(s/3600) local m=math.floor(s/60)%60 local sc=math.floor(s)%60
        if h>0 then return string.format(_c(37,100,58,37,48,50,100,58,37,48,50,100),h,m,sc) else return string.format(_c(37,100,58,37,48,50,100),m,sc) end
    end
    while true do
        task.wait(1)
        local el=math.max(tick()-_t0,1)
        _lb0.Text=_c(67,111,105,110,58,32)..fmt(_c0)
        _lb1.Text=_c(71,111,111,112,58,32)..fmt(_g0)
        _lb2.Text=_c(47,109,105,110,32)..fmt(_c0/el*60)
        _lb3.Text=_c(47,109,105,110,32)..fmt(_g0/el*60)
        _lb4.Text=_c(47,104,114,32,32)..fmt(_c0/el*3600)
        _lb5.Text=_c(47,104,114,32,32)..fmt(_g0/el*3600)
        _lb6.Text=_c(47,100,97,121,32)..fmt(_c0/el*86400)
        _lb7.Text=_c(47,100,97,121,32)..fmt(_g0/el*86400)
        _lb8.Text=_c(83,101,115,115,105,111,110,58,32,32)..fmtT(el)
        _lb9.Text=_c(70,80,83,58,32,32,32,32,32,32).._fc0 _fc0=0
    end
end)
local _gnt=nil
task.spawn(function()
    while true do
        if _v1 and _st[_k0[1]] then
            if #_e0>0 then
                local alive=false
                for _,id in ipairs(_e0) do if id==_gnt then alive=true break end end
                if not alive then _gnt=_e0[1] end
            end
            if _gnt then
                if _v2 then pcall(function()_v2:InvokeServer(_c(116,114,121,70,105,114,101,83,108,105,109,101,71,117,110),_gnt)end) end
                _v3=_v3+1 _v1:FireServer(_c(99,111,110,102,105,114,109,72,105,116),_v3,_gnt)
            end
        end
        task.wait(0.05)
    end
end)
task.spawn(function()
    while true do
        if _st[_k0[2]] and _v0 then pcall(function()_v0:InvokeServer(_c(114,101,113,117,101,115,116,82,111,108,108))end)
        else task.wait(0.1)end
    end
end)
local _vu0=game:GetService(_c(86,105,114,116,117,97,108,85,115,101,114))
_r2.Idled:Connect(function()
    pcall(function()
        _vu0:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
        task.wait(1)
        _vu0:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    end)
end)
local _mt0=_grm(game)
local _nc0=_mt0.__namecall
_sr(_mt0,false)
_mt0.__namecall=function(self,...)
    local m=_gnm()
    if m==_c(70,105,114,101,83,101,114,118,101,114) then
        local args={...}
        if args[1]==_c(97,117,116,111,82,101,106,111,105,110) and self.Parent and self.Parent.Name==_c(65,117,116,111,82,101,106,111,105,110,83,101,114,118,105,99,101) then
            return
        end
    end
    return _nc0(self,...)
end
_sr(_mt0,true)
local _cap=384
local _cpf={[_c(108,105,103,104,116,110,105,110,103,70,114,117,105,116)]=true,[_c(105,99,101,70,114,117,105,116)]=true,[_c(102,105,114,101,70,114,117,105,116)]=true,[_c(117,110,105,118,101,114,115,101,70,114,117,105,116)]=true,[_c(109,97,103,105,99,105,97,110,70,114,117,105,116)]=true,[_c(115,119,111,114,100,70,114,117,105,116)]=true}
local _fim=nil
local function _fn13()
    if _fim then return _fim end
    local ok,Fr=pcall(require,_r0[_c(83,111,117,114,99,101)][_c(71,97,109,101)][_c(73,116,101,109,115)][_c(70,114,117,105,116,115)])
    if not ok then _fim={} return _fim end
    local map={}
    for _,f in ipairs(Fr[_c(103,101,116,83,111,114,116,101,100,70,114,117,105,116,115)]()) do
        if f[_c(105,100)] then
            map[f[_c(105,100)]:lower()]=f[_c(105,100)]
            if f[_c(110,97,109,101)] then map[f[_c(110,97,109,101)]:lower()]=f[_c(105,100)] end
            if f[_c(116,114,101,101,73,100)] then map[f[_c(116,114,101,101,73,100)]:lower()]=f[_c(105,100)] end
        end
    end
    _fim=map return map
end
local _clp={_c(80,108,97,121,101,114,71,117,105),_c(82,111,111,116),_c(73,110,118,101,110,116,111,114,121),_c(80,97,103,101,73,116,101,109,115,67,111,110,116,101,110,116),_c(73,116,101,109,115,73,110,118,101,110,116,111,114,121,80,97,103,101),_c(68,101,102,97,117,108,116,73,116,101,109,115,86,105,101,119),_c(67,111,110,115,117,109,97,98,108,101,115,80,97,110,101,108),_c(67,111,110,115,117,109,97,98,108,101,115,76,105,115,116)}
local function _fn14(itemName)
    if not itemName or itemName=="" then return 0 end
    local id=_fn13()[itemName:lower()] or itemName
    if not _cpf[id] then return 0 end
    local node=_r2
    for _,n in ipairs(_clp) do node=node:FindFirstChild(n) if not node then return 0 end end
    local btn=node:FindFirstChild(id.._c(73,116,101,109,66,117,116,116,111,110))
    if not btn then return 0 end
    for _,ch in ipairs(btn:GetChildren()) do
        if ch:IsA(_c(84,101,120,116,76,97,98,101,108)) then
            local n=tonumber(ch.Text:match(_c(94,120,40,37,100,43,41,36)))
            if n then return n end
        end
    end
    return 0
end
local function _fn15(inst)
    local m=inst while m and not m:IsA(_c(77,111,100,101,108)) do m=m.Parent end return m
end
local _ppc={}
local function _fn16(v)
    if v:IsA(_c(80,114,111,120,105,109,105,116,121,80,114,111,109,112,116)) then
        local a=v[_c(65,99,116,105,111,110,84,101,120,116)]:lower()
        if a=="" or a:find(_c(112,105,99,107)) or a:find(_c(99,111,108,108,101,99,116)) or a:find(_c(116,97,107,101)) or a:find(_c(103,114,97,98)) then
            _ppc[v]=true
        end
    end
end
local function _fn17(v) _ppc[v]=nil end
workspace.DescendantAdded:Connect(_fn16)
workspace.DescendantRemoving:Connect(_fn17)
for _,v in ipairs(workspace:GetDescendants()) do _fn16(v) end
task.spawn(function()
    local _df={_c(68,114,111,112,115),_c(70,114,117,105,116,115),_c(73,116,101,109,115),_c(80,105,99,107,117,112,115),_c(67,111,108,108,101,99,116,105,98,108,101,115),_c(71,111,111,112,68,114,111,112,115),_c(87,111,114,108,100,73,116,101,109,115)}
    while true do
        if _st[_k0[3]] then
            local char=_r2.Character
            local hrp=char and char:FindFirstChild(_c(72,117,109,97,110,111,105,100,82,111,111,116,80,97,114,116))
            if hrp then
                for pp in pairs(_ppc) do
                    if pp and pp.Enabled then
                        local m=_fn15(pp)
                        if not m or _fn14(m.Name)<_cap then
                            pcall(_fpp,pp)
                        end
                    end
                end
                for _,fname in ipairs(_df) do
                    local f=workspace:FindFirstChild(fname)
                    if f then
                        for _,item in ipairs(f:GetChildren()) do
                            if _fn14(item.Name)<_cap then
                                local part=item:IsA(_c(66,97,115,101,80,97,114,116)) and item or item:FindFirstChildOfClass(_c(66,97,115,101,80,97,114,116))
                                if part then pcall(_fti,part,hrp,0) end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)
