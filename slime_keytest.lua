_G.MAIN_LOADED = true

-- ─── Services ─────────────────────────────────────────────────────────────────
local RS          = game:GetService("ReplicatedStorage")
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui     = game:GetService("CoreGui")
local PL = Players.LocalPlayer
local function jitter(base, pct)
    return base * (1 + (math.random() - 0.5) * pct)
end
local _t = 0
while not RS:FindFirstChild("Source") and _t < 7 do task.wait(1) _t = _t + 1 end
if not RS:FindFirstChild("Source") then warn("[SlimeRNG] RS.Source never appeared, loading anyway") end

-- ─── Shared lazy-loaded remotes / services ────────────────────────────────────
local rollRF = nil
task.spawn(function()
    for _ = 1, 40 do
        for _, v in ipairs(RS:GetDescendants()) do
            if v.Name == "RollService" and v:IsA("Folder") then
                local r = v:FindFirstChildOfClass("RemoteFunction")
                if r then rollRF = r return end
            end
        end
        task.wait(0.5)
    end
end)

local zoneSvc = nil
task.spawn(function()
    for _ = 1, 40 do
        pcall(function() if not zoneSvc then zoneSvc = require(RS.Source.Features.Zones.ZonesServiceClient) end end)
        if zoneSvc then break end
        task.wait(0.5)
    end
end)

local gameplaySvc = nil
task.spawn(function()
    for _ = 1, 60 do
        pcall(function() if not gameplaySvc then gameplaySvc = require(RS.Source.Features.Gameplay.GameplayServiceClient) end end)
        if gameplaySvc then break end
        task.wait(0.5)
    end
end)

-- ─── Anti-AFK ─────────────────────────────────────────────────────────────────
pcall(function()
    local m = require(RS.Source.Features.AutoRejoin.AutoRejoinServiceClient)
    m.disable()
    m.enable = function() end
    m.init = function() end
end)
pcall(function()
    for _, connection in pairs(getconnections(PL.Idled)) do
        if connection["Disable"] then connection["Disable"](connection)
        elseif connection["Disconnect"] then connection["Disconnect"](connection) end
    end
end)

-- ─── Save Position ────────────────────────────────────────────────────────────
do
    local savedPos = nil
    local POS_FILE = "slime_rng_pos.txt"
    -- Persist saved position to file, with CoreGui StringValue as fallback
    local function savePosFile()
        if not savedPos then return end
        local str = savedPos.X..","..savedPos.Y..","..savedPos.Z
        local ok = pcall(function() writefile(POS_FILE, str) end)
        if not ok then
            local store = CoreGui:FindFirstChild("_SlimeRNGPos") or Instance.new("StringValue", CoreGui)
            store.Name  = "_SlimeRNGPos"
            store.Value = str
        end
    end
    -- Load saved position from file or CoreGui fallback; populates savedPos
    local function loadPosFile()
        local ok, d = pcall(function() return readfile(POS_FILE) end)
        if not ok or not d then
            local store = CoreGui:FindFirstChild("_SlimeRNGPos")
            if store then d = store.Value ok = true end
        end
        if not ok or not d then return end
        local x, y, z = d:match("^([-%.%d]+),([-%.%d]+),([-%.%d]+)$")
        if x then savedPos = Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
    end
    pcall(loadPosFile)
    -- Capture the player's current HRP position (+1 stud up) and save it
    local function doSave()
        local char = PL.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            savedPos = hrp.Position + Vector3.new(0, 1, 0)
            savePosFile()
            return true
        end
        return false
    end
    _G.SavePosition = {
        save        = function() return doSave() end,
        getPosition = function() return savedPos end,
    }
end

-- ─── Auto Roll ────────────────────────────────────────────────────────────────
do
    local active = false
    local function setActive(val) active = val end
    -- Pause rolling while StackRolls is releasing; otherwise roll as fast as the server allows
    task.spawn(function()
        while true do
            local sr = _G.StackRolls
            if sr and sr.isActive() and sr.isReleasing() then
                task.wait(jitter(1.2, 0.2))
            elseif active and rollRF then
                pcall(function() rollRF:InvokeServer("requestRoll") end)
                task.wait(jitter(0.05, 0.4))
            else
                task.wait(jitter(0.1, 0.3))
            end
        end
    end)
    _G.AutoRoll = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── Legit Roll Speed ─────────────────────────────────────────────────────────
do
    local active = false
    local function setActive(val) active = val end
    -- Read the game's actual roll speed and multiply by 2.97 for a natural pace
    local rollSlice = nil
    task.spawn(function()
        for _ = 1, 40 do
            local ok, mod = pcall(function() return require(RS.Source.Features.Roll.RollSlice) end)
            if ok and mod then rollSlice = mod break end
            task.wait(0.5)
        end
    end)
    local function getLegitDelay()
        if rollSlice then
            local ok, rt = pcall(function() return rollSlice.rollTime() end)
            if ok and rt and rt > 0 then return rt * 2.97 end
        end
        return 2.2 -- fallback
    end
    task.spawn(function()
        while true do
            if active and rollRF then
                pcall(function() rollRF:InvokeServer("requestRoll") end)
                task.wait(jitter(getLegitDelay(), 0.15))
            else
                task.wait(jitter(0.1, 0.3))
            end
        end
    end)
    _G.LegitRollSpeed = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Shoot ───────────────────────────────────────────────────────────────
do
    local active    = false
    local MAX_RANGE = 200
    local goopSvc   = nil
    task.spawn(function()
        for _ = 1, 40 do
            pcall(function() if not goopSvc then goopSvc = require(RS.Source.Features.GoopGun.GoopGunServiceClient) end end)
            if goopSvc then break end
            task.wait(0.5)
        end
    end)
    local target = nil
    local function setActive(val) active = val end
    task.spawn(function()
        while true do
            task.wait(jitter(0.05, 0.4))
            if active and goopSvc then
                pcall(function()
                    local gp = gameplaySvc and gameplaySvc.gameplay
                    if not gp or not gp.enemies then return end
                    if target then
                        local e = gp.enemies[target]
                        if not (e and e.pos) then target = nil end
                    end
                    if not target then
                        local char = PL.Character
                        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                        local origin = hrp and hrp.Position
                        local bestId = nil
                        local bestDist = MAX_RANGE + 1
                        for eid, e in pairs(gp.enemies) do
                            if e and e.pos and origin then
                                local dist = (e.pos - origin).Magnitude
                                if dist < bestDist and dist <= MAX_RANGE then
                                    bestDist = dist
                                    bestId = eid
                                end
                            end
                        end
                        target = bestId
                    end
                    if target then
                        pcall(function() goopSvc.networker:fetch("tryFireSlimeGun", target) end)
                    end
                end)
            end
        end
    end)
    _G.AutoShoot = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Collect ─────────────────────────────────────────────────────────────
do
    local lootSvc     = require(RS.Source.Features.Loot.LootServiceClient)
    local active      = false
    local fruitFilter = {}
    local KNOWN_FRUITS = {lightningFruit=true,iceFruit=true,fireFruit=true,universeFruit=true,magicianFruit=true,swordFruit=true}
    local function setActive(val) active = val end
    task.spawn(function()
        while true do
            task.wait(jitter(0.5, 0.3))
            if not active then continue end
            pcall(function()
                local lootRoot = workspace:FindFirstChild("Loot")
                if not lootRoot then return end
                for _, item in ipairs(lootRoot:GetChildren()) do
                    local uniqueId = item.Name
                    local obj     = lootSvc.lootById and lootSvc.lootById[uniqueId]
                    local lootId  = obj and obj.data and obj.data.lootId
                    local isFruit = lootId and KNOWN_FRUITS[lootId]
                    local allowed = not isFruit or not next(fruitFilter) or fruitFilter[lootId]
                    if allowed then pcall(function() lootSvc:requestCollect(uniqueId) end) end
                end
            end)
        end
    end)
    _G.AutoCollect = {
        enable    = function() setActive(true) end,
        disable   = function() setActive(false) end,
        toggle    = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive  = function() return active end,
        setFilter = function(f) fruitFilter = f or {} end,
        getFilter = function() return fruitFilter end,
    }
end

-- ─── Auto Return ──────────────────────────────────────────────────────────────
do
    local active = false
    -- Read saved position from _G.SavePosition, file, or CoreGui fallback
    local function getSavedPos()
        if _G.SavePosition then return _G.SavePosition.getPosition() end
        local ok, d = pcall(function() return readfile("slime_rng_pos.txt") end)
        if not ok or not d then
            local store = CoreGui:FindFirstChild("_SlimeRNGPos")
            if store then d = store.Value ok = true end
        end
        if not ok or not d then return nil end
        local x, y, z = d:match("^([-%.%d]+),([-%.%d]+),([-%.%d]+)$")
        if x then return Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
    end
    local function setActive(val) active = val end
    -- Teleport back to saved position when the player drifts more than 20 studs away
    task.spawn(function()
        while true do
            task.wait(jitter(1, 0.3))
            if active then
                pcall(function()
                    local savedPos = getSavedPos()
                    if not savedPos then return end
                    local char = PL.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - savedPos).Magnitude > 20 then
                        local off = Vector3.new(math.random()-0.5, 0, math.random()-0.5) * 2
                        PL.Character:PivotTo(CFrame.new(savedPos + off))
                    end
                end)
            end
        end
    end)
    _G.AutoReturn = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── Stack Special Rolls ──────────────────────────────────────────────────────
do
    local rollSvc = nil
    pcall(function() rollSvc = require(RS.Source.Features.Roll.RollServiceClient) end)
    if not rollSvc then pcall(function() rollSvc = require(RS.Source.Features.Roll.RollService) end) end
    local ROLL_TYPES = {"void", "galaxy", "golden", "diamond"}
    local cycleLen   = {golden = 10, diamond = 100, void = 1000, galaxy = 5000}
    local RELEASE_COOLDOWN = 4
    local progress   = {void=999999, galaxy=999999, golden=999999, diamond=999999}
    local paused     = {void=false, galaxy=false, golden=false, diamond=false}
    local active     = false
    local releasedAt = 0

    -- Pause or unpause a roll type via the roll service
    local function setPaused(rt, state)
        local ok = pcall(function() rollSvc:setSpecialRollPaused(rt, state) end)
        if not ok then pcall(function() rollSvc.networker:fetch("setSpecialRollPaused", rt, state) end) end
        paused[rt] = state
    end
    -- Unpause all roll types and clear their progress counters
    local function reset()
        for _, rt in ipairs(ROLL_TYPES) do
            if paused[rt] then setPaused(rt, false) end
            progress[rt] = 999999
        end
    end
    -- Pause each roll type when it reaches ≤1 cycle left; release all together when all are ready
    local function handleProgression()
        if not active then return end
        if os.clock() - releasedAt < RELEASE_COOLDOWN then return end
        for _, rt in ipairs(ROLL_TYPES) do
            if progress[rt] <= 1 and not paused[rt] then
                local shouldPause
                if rt == "galaxy" then shouldPause = true
                else
                    local G = progress.galaxy
                    shouldPause = G < 999999 and (G - 1) < cycleLen[rt]
                end
                if shouldPause then setPaused(rt, true) end
            end
        end
        local allReady = true
        for _, rt in ipairs(ROLL_TYPES) do
            if not paused[rt] or progress[rt] > 1 then allReady = false break end
        end
        if allReady then
            releasedAt = os.clock()
            for _, rt in ipairs(ROLL_TYPES) do setPaused(rt, false) progress[rt] = 999999 end
        end
    end
    -- Parse specialRollProgression events and update per-type progress counters
    local function onRollEvent(a1, a2, a3)
        local evName, data
        if type(a1) == "string" then evName, data = a1, a2
        elseif type(a2) == "string" then evName, data = a2, a3 end
        if evName ~= "specialRollProgression" or type(data) ~= "table" then return end
        for _, rt in ipairs(ROLL_TYPES) do
            local d = data[rt]
            if d then
                local newVal = d.rollsUntilNext or 999999
                if not paused[rt] and progress[rt] <= 1 and newVal > 5 and newVal < 999999 then
                    cycleLen[rt] = newVal
                end
                progress[rt] = newVal
            end
        end
        handleProgression()
    end
    local hookedREs = {}
    -- Hook a RemoteEvent once to forward all events to onRollEvent
    local function hookSRRE(re)
        if hookedREs[re] then return end
        hookedREs[re] = true
        re.OnClientEvent:Connect(onRollEvent)
    end
    -- Hook all existing and future RemoteEvents in ReplicatedStorage
    task.spawn(function()
        for _, d in ipairs(RS:GetDescendants()) do
            if d:IsA("RemoteEvent") then hookSRRE(d) end
        end
        RS.DescendantAdded:Connect(function(d)
            if d:IsA("RemoteEvent") then hookSRRE(d) end
        end)
    end)
    local function setActive(val)
        active = val
        if not active then reset() end
    end
    _G.StackRolls = {
        enable      = function() setActive(true) end,
        disable     = function() setActive(false) end,
        toggle      = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive    = function() return active end,
        isReleasing = function() return os.clock() - releasedAt < RELEASE_COOLDOWN end,
    }
end

-- ─── Stats Tracker ────────────────────────────────────────────────────────────
do
    local coinTotal, goopTotal = 0, 0
    local sessionStart = tick()
    local hookedREs  = {}
    -- Accumulate goop and coin rewards received from GameplayN RemoteEvents
    local function hookSTRE(re)
        if hookedREs[re] then return end
        hookedREs[re] = true
        re.OnClientEvent:Connect(function(a1, a2)
            if type(a2) ~= "table" then return end
            local amt = rawget(a2, "amount")
            if type(amt) ~= "number" then return end
            if a1 == "goopRewarded" then goopTotal = goopTotal + amt
            elseif a1 == "coinRewarded" then coinTotal = coinTotal + amt end
        end)
    end
    -- Hook all existing and future Gameplay RemoteEvents
    task.spawn(function()
        for _, v in ipairs(RS:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:match("^Gameplay%d+$") then hookSTRE(v) end
        end
        RS.DescendantAdded:Connect(function(v)
            if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:match("^Gameplay%d+$") then hookSTRE(v) end
        end)
    end)
    _G.StatsTracker = {
        reset      = function() coinTotal, goopTotal, sessionStart = 0, 0, tick() end,
        getCoins   = function() return coinTotal end,
        getGoop    = function() return goopTotal end,
        getElapsed = function() return math.max(tick() - sessionStart, 1) end,
        getRates   = function()
            local el = math.max(tick() - sessionStart, 1)
            return {
                coinMin = coinTotal/el*60,   coinHr = coinTotal/el*3600,   coinDay = coinTotal/el*86400,
                goopMin = goopTotal/el*60,   goopHr = goopTotal/el*3600,   goopDay = goopTotal/el*86400,
            }
        end,
    }
end

-- ─── Utilities ────────────────────────────────────────────────────────────────
local SFX = {"K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc"}
local function fmt(n)
    if n < 1000 then return tostring(math.floor(n)) end
    local v, i = n, 0
    while v >= 1000 and i < #SFX do v = v/1000 i = i+1 end
    return string.format("%.3f%s", v, SFX[i])
end
local function fmtTime(s)
    local h = math.floor(s/3600)
    local m = math.floor(s/60) % 60
    local sc = math.floor(s) % 60
    return h > 0 and string.format("%d:%02d:%02d",h,m,sc) or string.format("%d:%02d",m,sc)
end

-- ─── Zone Benchmark ──────────────────────────────────────────────────────────────
do
    local TEST_DURATION = 180
    local ZONES_TO_TEST = 5
    local TELEPORT_WAIT = 10

    -- Cache zone display names from the Zones module for use in status messages
    local ZONE_NAMES = {}
    pcall(function()
        local zones = require(RS.Source.Game.Items.Zones)
        for _, z in ipairs(zones) do
            if z.id and z.name then ZONE_NAMES[z.id] = z.name end
        end
    end)
    local function zoneName(id) return ZONE_NAMES[id] or ("Zone "..id) end

    -- Count goop earned during each benchmark by hooking Gameplay RemoteEvents
    local goopCount = 0
    local hookedREs = {}
    local function hookZFRE(re)
        if hookedREs[re] then return end
        hookedREs[re] = true
        re.OnClientEvent:Connect(function(a1, a2)
            if a1 == "goopRewarded" and type(a2) == "table" then
                local amt = rawget(a2, "amount")
                if type(amt) == "number" then goopCount = goopCount + amt end
            end
        end)
    end
    task.spawn(function()
        for _, v in ipairs(RS:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:match("^Gameplay%d+$") then hookZFRE(v) end
        end
        RS.DescendantAdded:Connect(function(v)
            if v:IsA("RemoteEvent") and v.Parent and v.Parent.Name:match("^Gameplay%d+$") then hookZFRE(v) end
        end)
    end)

    local running    = false
    local done       = false
    local results    = {}
    local statusText = ""
    local popupGui, popupStatusLbl, popupResultRows, popupBestLbl, popupResultsFrame
    local createPopup, updatePopupResults, runTest

    local function setStatus(txt)
        statusText = txt
        if popupStatusLbl and popupStatusLbl.Parent then popupStatusLbl.Text = txt end
    end

    -- Teleport to and benchmark each zone, then move to the best goop/hr zone
    runTest = function()
        running = true
        results = {}
        createPopup()
        local maxZone = pcall(function() return zoneSvc:getMaxZone() end) and zoneSvc:getMaxZone() or 1
        local count   = math.min(ZONES_TO_TEST, maxZone)
        local zoneIds = {}
        for i = maxZone - count + 1, maxZone do table.insert(zoneIds, i) end

        for idx, zid in ipairs(zoneIds) do
            if not running then break end
            local name = zoneName(zid)
            setStatus(string.format("[%d/%d] Teleporting to %s...", idx, count, name))
            pcall(function() zoneSvc:teleportToZone(zid) end)
            for t = TELEPORT_WAIT, 1, -1 do
                if not running then break end
                setStatus(string.format("[%d/%d] Loading %s... %ds", idx, count, name, t))
                task.wait(1)
            end
            if not running then break end
            goopCount = 0
            if popupResultRows and popupResultRows[idx] then
                popupResultRows[idx].name.Text = name
                popupResultRows[idx].val.Text  = "—"
                popupResultRows[idx].name.TextColor3 = Color3.fromRGB(180,160,255)
                popupResultRows[idx].val.TextColor3  = Color3.fromRGB(180,160,255)
            end
            for t = TEST_DURATION, 1, -1 do
                if not running then break end
                local ze = TEST_DURATION - t + 1
                local liveRate = ze > 0 and (goopCount/ze)*3600 or 0
                setStatus(string.format("[%d/%d] Farming %s — %s left", idx, count, name, fmtTime(t)))
                if popupResultRows and popupResultRows[idx] then
                    popupResultRows[idx].val.Text = fmt(liveRate)
                end
                task.wait(1)
            end
            if not running then break end
            local goopPerHr = (goopCount/TEST_DURATION)*3600
            table.insert(results, {zoneId=zid, name=name, goopPerHr=goopPerHr})
            if popupResultRows and popupResultRows[idx] then
                popupResultRows[idx].name.TextColor3 = Color3.fromRGB(200,200,200)
                popupResultRows[idx].val.TextColor3  = Color3.fromRGB(200,200,200)
                popupResultRows[idx].val.Text = fmt(goopPerHr)
            end
        end

        if not running then setStatus("Test stopped.") return end
        table.sort(results, function(a, b) return a.goopPerHr > b.goopPerHr end)
        local best = results[1]
        local lastTestedZone = zoneIds[#zoneIds]
        if best then
            if best.zoneId ~= lastTestedZone then
                setStatus("Teleporting to best zone: "..best.name)
                pcall(function() zoneSvc:teleportToZone(best.zoneId) end)
                task.wait(2)
            end
            setStatus("Done! Farming "..best.name)
        end
        updatePopupResults()
        running = false
        done = true
    end

    -- Build the draggable floating benchmark results popup
    local PW = 280
    createPopup = function()
        if popupGui and popupGui.Parent then return end
        popupGui = Instance.new("ScreenGui")
        popupGui.ResetOnSpawn = false
        popupGui.Name = "ZoneFarmerPopup"
        popupGui.IgnoreGuiInset = true
        popupGui.Parent = PL.PlayerGui
        local panel = Instance.new("Frame", popupGui)
        panel.BackgroundColor3 = Color3.fromRGB(22, 8, 40)
        panel.BorderSizePixel = 0
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
        local ps = Instance.new("UIStroke", panel)
        ps.Color = Color3.fromRGB(75, 22, 115)
        ps.Thickness = 1.5
        ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        local titleBar = Instance.new("Frame", panel)
        titleBar.Size = UDim2.new(1, 0, 0, 28)
        titleBar.BackgroundColor3 = Color3.fromRGB(32, 10, 58)
        titleBar.BorderSizePixel = 0
        Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
        local tl = Instance.new("TextLabel", titleBar)
        tl.Size = UDim2.new(1, -36, 1, 0)
        tl.Position = UDim2.new(0, 10, 0, 0)
        tl.BackgroundTransparency = 1
        tl.TextColor3 = Color3.new(1, 1, 1)
        tl.Text = "Zone Benchmark"
        tl.TextSize = 13
        tl.Font = Enum.Font.GothamBold
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.TextStrokeTransparency = 1
        local xBtn = Instance.new("TextButton", titleBar)
        xBtn.Size = UDim2.new(0, 24, 0, 20)
        xBtn.Position = UDim2.new(1, -28, 0, 4)
        xBtn.BackgroundColor3 = Color3.fromRGB(140, 18, 35)
        xBtn.TextColor3 = Color3.new(1, 1, 1)
        xBtn.Text = "X"
        xBtn.TextSize = 12
        xBtn.Font = Enum.Font.GothamBold
        xBtn.BorderSizePixel = 0
        xBtn.TextStrokeTransparency = 1
        Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 4)
        xBtn.MouseButton1Click:Connect(function()
            popupGui:Destroy()
            popupGui = nil popupStatusLbl = nil popupResultRows = nil
            popupBestLbl = nil popupResultsFrame = nil
        end)
        local drag, ds, dp = false, nil, nil
        titleBar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                drag = true ds = UIS:GetMouseLocation() dp = panel.AbsolutePosition
            end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
        end)
        UIS.InputChanged:Connect(function(i)
            if not drag or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local cur = UIS:GetMouseLocation()
            panel.Position = UDim2.new(0, dp.X+(cur.X-ds.X), 0, dp.Y+(cur.Y-ds.Y))
        end)
        local y = 28
        local function mkDiv()
            local d = Instance.new("Frame", panel)
            d.Size = UDim2.new(1, -12, 0, 1)
            d.Position = UDim2.new(0, 6, 0, y)
            d.BackgroundColor3 = Color3.fromRGB(60, 18, 95)
            d.BorderSizePixel = 0
            y = y + 1
        end
        mkDiv() y = y + 4
        popupStatusLbl = Instance.new("TextLabel", panel)
        popupStatusLbl.Size = UDim2.new(1, -16, 0, 44)
        popupStatusLbl.Position = UDim2.new(0, 8, 0, y)
        popupStatusLbl.BackgroundTransparency = 1
        popupStatusLbl.TextColor3 = Color3.fromRGB(210, 185, 255)
        popupStatusLbl.Text = statusText ~= "" and statusText or "Starting..."
        popupStatusLbl.TextSize = 11
        popupStatusLbl.Font = Enum.Font.Gotham
        popupStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
        popupStatusLbl.TextWrapped = true
        popupStatusLbl.TextStrokeTransparency = 1
        y = y + 48
        mkDiv()
        popupResultsFrame = Instance.new("Frame", panel)
        popupResultsFrame.Position = UDim2.new(0, 0, 0, y)
        popupResultsFrame.BackgroundTransparency = 1
        popupResultsFrame.BorderSizePixel = 0
        local rHdr = Instance.new("Frame", popupResultsFrame)
        rHdr.Size = UDim2.new(1, 0, 0, 22)
        rHdr.BackgroundColor3 = Color3.fromRGB(32, 10, 58)
        rHdr.BorderSizePixel = 0
        local LCOL, RCOL = PW-130, 130
        local function mkCell(parent, txt, xOff, w, isHdr)
            local l = Instance.new("TextLabel", parent)
            l.Size = UDim2.new(0, w, 1, 0)
            l.Position = UDim2.new(0, xOff, 0, 0)
            l.BackgroundTransparency = 1
            l.TextColor3 = isHdr and Color3.fromRGB(120,90,160) or Color3.fromRGB(200,200,200)
            l.Text = txt
            l.TextSize = isHdr and 10 or 11
            l.Font = isHdr and Enum.Font.GothamBold or Enum.Font.Gotham
            l.TextXAlignment = Enum.TextXAlignment.Center
            l.TextStrokeTransparency = 1
            return l
        end
        local function mkColDiv(parent)
            local d = Instance.new("Frame", parent)
            d.Size = UDim2.new(0, 1, 1, 0)
            d.Position = UDim2.new(0, LCOL, 0, 0)
            d.BackgroundColor3 = Color3.fromRGB(60,18,95)
            d.BorderSizePixel = 0
        end
        mkCell(rHdr, "ZONE", 0, LCOL, true)
        mkCell(rHdr, "GOOP/HR", LCOL, RCOL, true)
        mkColDiv(rHdr)
        local ry = 22
        popupResultRows = {}
        for i = 1, ZONES_TO_TEST do
            local row = Instance.new("Frame", popupResultsFrame)
            row.Size = UDim2.new(1, 0, 0, 24)
            row.Position = UDim2.new(0, 0, 0, ry)
            row.BackgroundColor3 = (i%2==1) and Color3.fromRGB(28,10,50) or Color3.fromRGB(22,8,40)
            row.BorderSizePixel = 0
            local nLbl = mkCell(row, "--", 0, LCOL, false)
            local vLbl = mkCell(row, "--", LCOL, RCOL, false)
            mkColDiv(row)
            popupResultRows[i] = {name=nLbl, val=vLbl}
            ry = ry + 24
        end
        local bestRow = Instance.new("Frame", popupResultsFrame)
        bestRow.Size = UDim2.new(1, 0, 0, 28)
        bestRow.Position = UDim2.new(0, 0, 0, ry)
        bestRow.BackgroundColor3 = Color3.fromRGB(15, 35, 15)
        bestRow.BorderSizePixel = 0
        popupBestLbl = Instance.new("TextLabel", bestRow)
        popupBestLbl.Size = UDim2.new(1, -10, 1, 0)
        popupBestLbl.Position = UDim2.new(0, 5, 0, 0)
        popupBestLbl.BackgroundTransparency = 1
        popupBestLbl.TextColor3 = Color3.fromRGB(80, 230, 80)
        popupBestLbl.Text = "Best: --"
        popupBestLbl.TextSize = 12
        popupBestLbl.Font = Enum.Font.GothamBold
        popupBestLbl.TextXAlignment = Enum.TextXAlignment.Center
        popupBestLbl.TextStrokeTransparency = 1
        ry = ry + 28
        popupResultsFrame.Size = UDim2.new(1, 0, 0, ry)
        popupResultsFrame.Visible = true
        panel.Size = UDim2.new(0, PW, 0, y+4+ry)
        panel.Position = UDim2.new(0.5, -PW/2, 0, 60)
    end

    -- Refresh popup result rows with final sorted data and highlight the best zone
    updatePopupResults = function()
        if not popupResultRows or not popupResultsFrame then return end
        for i, r in ipairs(results) do
            if popupResultRows[i] then
                popupResultRows[i].name.Text = r.name
                popupResultRows[i].val.Text  = fmt(r.goopPerHr)
                local c = i==1 and Color3.fromRGB(80,230,80) or Color3.fromRGB(200,200,200)
                popupResultRows[i].name.TextColor3 = c
                popupResultRows[i].val.TextColor3  = c
            end
        end
        for i = #results+1, ZONES_TO_TEST do
            if popupResultRows[i] then
                popupResultRows[i].name.Text = ""
                popupResultRows[i].val.Text  = ""
            end
        end
        if popupBestLbl and results[1] then
            popupBestLbl.Text = "Best: "..results[1].name.." ("..fmt(results[1].goopPerHr).."/hr)"
        end
        popupResultsFrame.Visible = true
    end

    _G.ZoneFarmer = {
        start      = function() if not running then task.spawn(runTest) end end,
        stop       = function() running = false end,
        isActive   = function() return running end,
        isDone     = function() return done end,
        getResults = function() return results end,
        getStatus  = function() return statusText end,
    }
end

-- ─── Auto Claim Index ─────────────────────────────────────────────────────────
do
    local active = false
    local indexSvc = nil
    local indexRewards = nil
    local dataClient = nil
    task.spawn(function()
        for _ = 1, 60 do
            pcall(function()
                if not indexSvc     then indexSvc     = require(RS.Source.Features.Index.IndexServiceClient) end
                if not indexRewards then indexRewards = require(RS.Source.Features.Index.IndexRewards) end
                if not dataClient   then dataClient   = require(RS.Packages.DataService).client end
            end)
            if indexSvc and indexRewards and dataClient then break end
            task.wait(0.5)
        end
    end)
    local CATEGORIES = {"basic", "big", "huge", "shiny", "inverted"}
    local function isClaimable(indexData, category)
        if type(indexData) ~= "table" then return false end
        local cats = indexData.categories
        if type(cats) ~= "table" then return false end
        local catData = cats[category]
        if type(catData) ~= "table" then return false end
        local unlocked = catData.unlocked or {}
        local claimed  = catData.claimedRewards or {}
        local count = 0
        for _, v in pairs(unlocked) do if v == true then count = count + 1 end end
        local rewards = indexRewards[category] or {}
        for _, r in ipairs(rewards) do
            if r.key and r.key ~= "" and not claimed[r.key] and count >= r.req then
                return true
            end
        end
        return false
    end
    task.spawn(function()
        while true do
            task.wait(jitter(10, 0.2))
            if not active or not (indexSvc and indexRewards and dataClient) then continue end
            pcall(function()
                local indexData = dataClient:get("index")
                for _, cat in ipairs(CATEGORIES) do
                    if isClaimable(indexData, cat) then
                        pcall(function() indexSvc.networker:fetch("requestClaimReward", cat) end)
                    end
                end
            end)
        end
    end)
    local function setActive(val) active = val end
    _G.AutoClaimIndex = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Equip Best ──────────────────────────────────────────────────────────
do
    local active = false
    local invSvc = nil
    task.spawn(function()
        for _ = 1, 60 do
            pcall(function()
                if not invSvc then invSvc = require(RS.Source.Features.Inventory.InventoryServiceClient) end
            end)
            if invSvc then break end
            task.wait(0.5)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(jitter(5, 0.2))
            if not active or not invSvc then continue end
            pcall(function() invSvc.networker:fetch("requestEquipBest") end)
        end
    end)
    local function setActive(val) active = val end
    _G.AutoEquipBest = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Zone (Buy + Teleport) ───────────────────────────────────────────────
do
    local active       = false
    local lastServerTP = 0
    local zonesModule, dataClient, zonesRF
    local dataReady    = false

    -- Load modules/remotes for buy logic
    task.spawn(function()
        for _ = 1, 60 do
            pcall(function()
                if not zonesModule then zonesModule = require(RS.Source.Game.Items.Zones) end
                if not dataClient  then dataClient  = require(RS.Packages.DataService).client end
                if not zonesRF     then zonesRF     = RS.Packages._Index["leifstout_networker@0.3.1"].networker._remotes.ZonesService.RemoteFunction end
            end)
            if zonesModule and dataClient and zonesRF then dataReady = true break end
            task.wait(0.5)
        end
    end)

    -- Dynamic zone position lookup (handles new zones without code changes)
    local function getZonePos(zoneId)
        local ok, pos = pcall(function()
            local zone = workspace.Zones:FindFirstChild(tostring(zoneId))
            if not zone or not zone:FindFirstChild("POI") then return nil end
            local part = zone.POI:FindFirstChild("Baseplate") or zone.POI:FindFirstChild("Hitbox")
            if part then return part.Position + Vector3.new(0, 3, 0) end
            return nil
        end)
        return ok and pos or nil
    end

    -- Buy the next zone when affordable; teleport to the current max zone dynamically
    task.spawn(function()
        while true do
            task.wait(jitter(1, 0.3))
            if not active or not dataReady then continue end
            pcall(function()
                local currentZone = math.max(dataClient:get("maxZone") or 1, 1)
                local nextZoneData = zonesModule.getZone(currentZone + 1)
                if nextZoneData and dataClient:get("coins") >= nextZoneData.price then
                    zonesRF:InvokeServer("requestPurchaseZone")
                end
                local pos = getZonePos(currentZone)
                if pos then
                    local char = PL.Character
                    if char and (char:GetPivot().Position - pos).Magnitude > 20 then
                        local off = Vector3.new(math.random()-0.5, 0, math.random()-0.5) * 2
                        char:PivotTo(CFrame.new(pos + off))
                    end
                elseif zoneSvc and currentZone ~= lastServerTP then
                    zoneSvc:teleportToZone(currentZone)
                    lastServerTP = currentZone
                end
            end)
        end
    end)

    _G.AutoZone = {
        enable   = function() active = true lastServerTP = 0 end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Buy Upgrades ────────────────────────────────────────────────────────
do
    local upgSvc, dataClient, upgradeTree
    task.spawn(function()
        for _ = 1, 60 do
            pcall(function()
                if not upgSvc      then upgSvc      = require(RS.Source.Features.Upgrades.UpgradeServiceClient) end
                if not dataClient  then dataClient  = require(RS.Packages.DataService).client end
                if not upgradeTree then upgradeTree = require(RS.Source.Features.Upgrades.UpgradeTree) end
            end)
            if upgSvc and dataClient and upgradeTree then break end
            task.wait(0.5)
        end
    end)
    local active = false
    local ORIGIN = "origin"
    -- Return the player's current balance for the given currency key
    local function getBalance(currency)
        local ok, v = pcall(function() return dataClient:get(currency) end)
        return (ok and type(v) == "number") and v or 0
    end
    -- Walk the upgrade tree and purchase every affordable, dependency-satisfied upgrade
    local function tryBuyAll()
        if not (upgSvc and upgSvc.networker and dataClient and upgradeTree) then return end
        local bought = true
        while bought do
            bought = false
            local owned = dataClient:get("upgrades") or {}
            for _, tree in pairs(upgradeTree) do
                for id, node in pairs(tree) do
                    if not node.cost then continue end
                    if owned[id] then continue end
                    local dep = node.dependency
                    if dep ~= ORIGIN and not owned[dep] then continue end
                    if getBalance(node.cost.currency) < node.cost.amount then continue end
                    local ok, result = pcall(function() return upgSvc.networker:fetch("requestUnlock", id) end)
                    if ok and result then bought = true end
                    task.wait(jitter(0.15, 0.3))
                end
            end
        end
    end
    task.spawn(function()
        while true do
            task.wait(jitter(2, 0.3))
            if not active then continue end
            pcall(tryBuyAll)
        end
    end)
    local function setActive(val) active = val end
    _G.AutoBuyUpgrades = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── UFO Teleport ────────────────────────────────────────────────────────────
do
    local active       = false
    local activeZoneId = nil
    local ufoRF, ufoRE
    local conn

    task.spawn(function()
        for _ = 1, 60 do
            pcall(function()
                if not ufoRF then
                    local nw = RS.Packages._Index["leifstout_networker@0.3.1"].networker._remotes.UfoEventService
                    ufoRF = nw.RemoteFunction
                    ufoRE = nw.RemoteEvent
                end
            end)
            if ufoRF and ufoRE then break end
            task.wait(0.5)
        end
    end)

    local function onState(state)
        if not active or not state then return end
        local phase  = state.phase or "idle"
        local zoneId = state.zoneId

        if phase ~= "idle" then
            if activeZoneId == nil then
                pcall(function()
                    if _G.SavePosition then _G.SavePosition.save() end
                end)
            end
            if zoneId and zoneId ~= activeZoneId then
                local maxZone = 1
                pcall(function() maxZone = zoneSvc:getMaxZone() or 1 end)
                if zoneId <= maxZone then
                    activeZoneId = zoneId
                    pcall(function() zoneSvc:teleportToZone(zoneId) end)
                end
            end
        elseif activeZoneId ~= nil then
            activeZoneId = nil
            pcall(function()
                if _G.SavePosition then
                    local pos = _G.SavePosition.getPosition()
                    if pos then
                        local char = PL.Character
                        if char then
                            local off = Vector3.new(math.random()-0.5, 0, math.random()-0.5) * 2
                            char:PivotTo(CFrame.new(pos + off))
                        end
                    end
                end
            end)
        end
    end

    local function setActive(val)
        active = val
        if active then
            activeZoneId = nil
            pcall(function()
                if ufoRF then
                    local state = ufoRF:InvokeServer("getState")
                    if state then
                        if (state.phase or "idle") ~= "idle" then
                            activeZoneId = state.zoneId
                        end
                    end
                end
            end)
            if ufoRE and not conn then
                conn = ufoRE.OnClientEvent:Connect(function(...)
                    local args = {...}
                    if type(args[1]) == "string" and args[1] == "setState" and type(args[2]) == "table" then
                        onState(args[2])
                    elseif type(args[1]) == "table" and args[1].phase then
                        onState(args[1])
                    end
                end)
            end
        else
            activeZoneId = nil
            if conn then conn:Disconnect() conn = nil end
        end
    end

    task.spawn(function()
        while true do
            task.wait(jitter(5, 0.2))
            if not active or not ufoRF then continue end
            pcall(function()
                local state = ufoRF:InvokeServer("getState")
                onState(state)
            end)
        end
    end)

    _G.UfoTP = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── Exploits ─────────────────────────────────────────────────────────────────
do
    local slimeSnapActive = false
    local enemyPullActive = false
    local walkSpeedActive = false
    local WALK_SPEED = 50

    -- Slime Snap: teleport each slime 5 studs in front of its target enemy every frame
    RunService.Heartbeat:Connect(function()
        if not slimeSnapActive then return end
        local gp = gameplaySvc and gameplaySvc.gameplay
        if not gp then return end
        local char = PL.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local playerPos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
        pcall(function()
            for _, slime in pairs(gp.slimes) do
                local targetId = slime.targetUniqueId
                if targetId then
                    local enemy = gp.enemies[targetId]
                    if enemy then
                        local toPlayer = playerPos - enemy.pos
                        local offset   = toPlayer.Magnitude > 0 and toPlayer.Unit * 5 or Vector3.zero
                        slime.pos      = enemy.pos + offset
                        slime.velocity = Vector3.new(0, 0, 0)
                    end
                end
            end
        end)
    end)

    -- Enemy Pull: arrange all enemies in a square grid 10 studs ahead of the player
    RunService.Heartbeat:Connect(function()
        if not enemyPullActive then return end
        local gp = gameplaySvc and gameplaySvc.gameplay
        if not gp then return end
        local char = PL.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local fwd   = hrp.CFrame.LookVector
        local right = hrp.CFrame.RightVector
        local base  = Vector3.new(hrp.Position.X+fwd.X*10, 0, hrp.Position.Z+fwd.Z*10)
        pcall(function()
            local list = {}
            for id, enemy in pairs(gp.enemies) do list[#list+1] = {id=id, enemy=enemy} end
            table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
            local n = #list
            local cols = math.max(1, math.ceil(math.sqrt(n)))
            local rows = math.ceil(n/cols)
            for i, entry in ipairs(list) do
                local idx = i-1
                local c   = idx%cols
                local r   = math.floor(idx/cols)
                local ox  = (c-(cols-1)/2)*2
                local oz  = (r-(rows-1)/2)*2
                entry.enemy.pos = Vector3.new(
                    base.X+right.X*ox+fwd.X*oz, 0,
                    base.Z+right.Z*ox+fwd.Z*oz)
                entry.enemy.velocity = Vector3.new(0,0,0)
            end
        end)
        pcall(function()
            local newId = next(gp.enemies)
            if newId then
                for _, slime in pairs(gp.slimes) do
                    if not slime.targetUniqueId or not gp.enemies[slime.targetUniqueId] then
                        slime.targetUniqueId = newId
                    end
                end
            end
        end)
    end)

    local slimeHpHooked = false
    -- Hook setState on the SlimeClient metatable to redirect idle slimes to targeting while Enemy Pull is active
    local function hookSlimeSetState(gp)
        if not gp or slimeHpHooked then return end
        local _, anySl = next(gp.slimes)
        if not anySl then return end
        local mt = getmetatable(anySl)
        if not mt or not mt.setState then return end
        local orig = mt.setState
        mt.setState = function(self, state, targetId)
            if enemyPullActive and state == 1 then
                local cur = gameplaySvc and gameplaySvc.gameplay
                if cur then
                    local newId = next(cur.enemies)
                    if newId then return orig(self, 2, newId) end
                end
            end
            return orig(self, state, targetId)
        end
        slimeHpHooked = true
    end
    task.spawn(function()
        while true do
            task.wait(jitter(1, 0.3))
            local gp = gameplaySvc and gameplaySvc.gameplay
            if gp and not slimeHpHooked then pcall(hookSlimeSetState, gp) end
        end
    end)

    -- Apply or reset WalkSpeed on the local humanoid
    local function applyWalkSpeed(on)
        pcall(function()
            local char = PL.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = on and WALK_SPEED or 16 end
        end)
    end
    -- Re-apply WalkSpeed after each character respawn
    PL.CharacterAdded:Connect(function()
        if not walkSpeedActive then return end
        task.wait(0.5)
        applyWalkSpeed(true)
    end)

    _G.SlimeSnap = {
        enable   = function() slimeSnapActive = true end,
        disable  = function() slimeSnapActive = false end,
        toggle   = function(v) slimeSnapActive = v==nil and not slimeSnapActive or v end,
        isActive = function() return slimeSnapActive end,
    }
    _G.EnemyPull = {
        enable   = function() enemyPullActive = true end,
        disable  = function() enemyPullActive = false end,
        toggle   = function(v) enemyPullActive = v==nil and not enemyPullActive or v end,
        isActive = function() return enemyPullActive end,
    }
    _G.WalkSpeed = {
        enable   = function() walkSpeedActive = true  applyWalkSpeed(true) end,
        disable  = function() walkSpeedActive = false applyWalkSpeed(false) end,
        toggle   = function(v)
            walkSpeedActive = v==nil and not walkSpeedActive or v
            applyWalkSpeed(walkSpeedActive)
        end,
        isActive = function() return walkSpeedActive end,
    }
end

-- ─── Memory Cleanup (every 5 min) ───────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(300)
        pcall(function()
            local vfx = workspace:FindFirstChild("vfxDebris")
            if vfx then
                for _, c in ipairs(vfx:GetChildren()) do pcall(function() c:Destroy() end) end
            end
        end)
        pcall(function()
            local cache = RS:FindFirstChild("Source")
                and RS.Source:FindFirstChild("Features")
                and RS.Source.Features:FindFirstChild("Gameplay")
                and RS.Source.Features.Gameplay:FindFirstChild("AttackVFXService")
                and RS.Source.Features.Gameplay.AttackVFXService:FindFirstChild("cache")
            if cache then
                for _, c in ipairs(cache:GetChildren()) do pcall(function() c:Destroy() end) end
            end
        end)
        pcall(function() collectgarbage("collect") end)
    end
end)

-- ─── Rejoin / Server Hop ─────────────────────────────────────────────────────
local TPS = game:GetService("TeleportService")
local function rejoinServer()
    pcall(function() TPS:TeleportToPlaceInstance(game.PlaceId, game.JobId, PL) end)
end
local function serverHop()
    pcall(function() TPS:Teleport(game.PlaceId, PL) end)
end
_G.Rejoin = { fire = rejoinServer }
_G.ServerHop = { fire = serverHop }

-- ─── State persistence ────────────────────────────────────────────────────────
local STATE_FILE = "slimeRNG_state.json"
-- Read JSON state from disk; returns an empty table on any failure
local function loadState()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(STATE_FILE))
    end)
    return (ok and type(data) == "table") and data or {}
end
-- Write JSON state to disk; silently fails if writefile is unavailable
local function saveState(s)
    pcall(function() writefile(STATE_FILE, HttpService:JSONEncode(s)) end)
end

-- ─── Toggle definitions ───────────────────────────────────────────────────────
local ROLL_DEF  = { label = "Fast Roll",    key = "autoRoll",    getApi = function() return _G.AutoRoll end,       tip = "Rolls as fast as the server allows" }
local LEGIT_DEF = { label = "Legit Roll",   key = "legitRoll",   getApi = function() return _G.LegitRollSpeed end, tip = "Simulates Legit Roll Speed" }
local AC_DEF    = { label = "Auto Collect", key = "autoCollect", getApi = function() return _G.AutoCollect end,    tip = "Automatically collects loot from the ground" }
local TOGGLE_DEFS = {
    { label = "Auto Shoot",        key = "autoShoot",       getApi = function() return _G.AutoShoot end,        tip = "Focuses fire on the lowest HP enemy within 200 studs — switches when it dies" },
    { label = "Stack Rolls",       key = "stackRolls",      getApi = function() return _G.StackRolls end,        tip = "Pauses special rolls and syncs them to all fire at once" },
    { label = "Auto Claim Index",  key = "autoClaimIndex",  getApi = function() return _G.AutoClaimIndex end,    tip = "Automatically claims available Index rewards" },
    { label = "Auto Equip Best",   key = "autoEquipBest",   getApi = function() return _G.AutoEquipBest end,     tip = "Equips your highest damage slimes if they are not already on the team" },
    { label = "Auto Buy/TP Zone",  key = "autoZone",        getApi = function() return _G.AutoZone end,          tip = "Buys next zone when affordable, then teleports to it" },
    { label = "Auto Buy Upgrades", key = "autoBuyUpgrades", getApi = function() return _G.AutoBuyUpgrades end,  tip = "Buys every affordable upgrade automatically, following the dependency chain" },
}
local AR_DEF = { label = "Auto Return", key = "autoReturn", getApi = function() return _G.AutoReturn end, tip = "Teleports back to saved position when you wander too far" }
local UFO_DEF = { label = "TP UFO", key = "tpUfo", getApi = function() return _G.UfoTP end, tip = "Teleports to UFO zone when it arrives, returns when it leaves" }
local EXPLOIT_DEFS = {
    { label = "Slime Snap", key = "slimeSnap", getApi = function() return _G.SlimeSnap end, tip = "Teleports your slimes 5 studs in front of their target enemy every frame" },
    { label = "Enemy Pull", key = "enemyPull", getApi = function() return _G.EnemyPull end, tip = "Arranges enemies in a square grid 10 studs ahead, 2 studs apart. Slimes immediately retarget when an enemy dies" },
    { label = "Walk Speed", key = "walkSpeed", getApi = function() return _G.WalkSpeed end, tip = "Sets WalkSpeed to 50 — re-applies on respawn" },
}

-- Restore toggle states from the last saved session
local savedState = loadState()
for _, def in ipairs(TOGGLE_DEFS) do
    if savedState[def.key] then
        local api = def.getApi()
        if api then pcall(function() api.enable() end) end
    end
end
if savedState[AR_DEF.key] then
    local api = AR_DEF.getApi()
    if api then pcall(function() api.enable() end) end
end
for _, def in ipairs({ROLL_DEF, LEGIT_DEF, AC_DEF}) do
    if savedState[def.key] then
        local api = def.getApi()
        if api then pcall(function() api.enable() end) end
    end
end
for _, def in ipairs(EXPLOIT_DEFS) do
    if savedState[def.key] then
        local api = def.getApi()
        if api then pcall(function() api.enable() end) end
    end
end
if savedState[UFO_DEF.key] then
    local api = UFO_DEF.getApi()
    if api then pcall(function() api.enable() end) end
end

-- ─── Layout constants ─────────────────────────────────────────────────────────
local W        = 299
local LBL_W    = 44
local VAL_W    = 104
local ROW_H    = 26
local SCROLL_H = 160
local TAB_W    = math.floor(W / 5)
local HALF_W   = 141

local SX = {
    lbl1 = 0,
    val1 = LBL_W + 1,
    lbl2 = LBL_W + 1 + VAL_W + 1,
    val2 = LBL_W + 1 + VAL_W + 1 + LBL_W + 1,
}

-- ─── Theme ────────────────────────────────────────────────────────────────────
local C_BG       = Color3.fromRGB(8,  3,  18)
local C_BG2      = Color3.fromRGB(22, 6,  42)
local C_TITLE    = Color3.fromRGB(32, 10, 58)
local C_TITLE2   = Color3.fromRGB(14, 4,  28)
local C_TABS     = Color3.fromRGB(12, 4,  24)
local C_DIV      = Color3.fromRGB(75, 22, 115)
local C_TAB_ON   = Color3.fromRGB(55, 18, 90)
local C_TAB_OFF  = Color3.fromRGB(16, 5,  30)
local C_TXT_ON   = Color3.new(1, 1, 1)
local C_TXT_OFF  = Color3.fromRGB(235, 205, 255)
local C_BTN_ON   = Color3.fromRGB(85,  15, 140)
local C_BTN_OFF  = Color3.fromRGB(90,  10, 10)
local C_BTXT_ON  = Color3.fromRGB(55,  185, 85)
local C_BTXT_OFF = Color3.fromRGB(205, 85,  85)
local C_STROKE   = Color3.fromRGB(105, 32, 160)
local C_BSTR_ON  = Color3.fromRGB(130, 60, 200)
local C_BSTR_OFF = Color3.fromRGB(180, 30, 30)

-- ─── Style helpers ────────────────────────────────────────────────────────────
local function mkGrad(parent, c1, c2, rot)
    local g = Instance.new("UIGradient", parent)
    g.Color    = ColorSequence.new(c1, c2)
    g.Rotation = rot or 90
    return g
end
local function mkStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color           = color
    s.Thickness       = thickness or 1
    s.Transparency    = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

-- ─── Root ScreenGui ───────────────────────────────────────────────────────────
local g = Instance.new("ScreenGui")
g.ResetOnSpawn  = false
g.Name          = "SlimeRNGMain"
g.IgnoreGuiInset = true
g.Parent        = PL.PlayerGui

-- ─── Panel ────────────────────────────────────────────────────────────────────
local panel = Instance.new("Frame", g)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local panelBg = Instance.new("Frame", panel)
panelBg.Size = UDim2.new(1, 0, 1, 0)
panelBg.BackgroundColor3 = C_BG
panelBg.BorderSizePixel  = 0
Instance.new("UICorner", panelBg).CornerRadius = UDim.new(0, 8)
mkGrad(panelBg, C_BG, C_BG2, 120)
mkStroke(panelBg, C_STROKE, 1.5, 0)

if savedState.guiX and workspace.CurrentCamera then
    local vp = workspace.CurrentCamera.ViewportSize
    local clampedX = math.clamp(savedState.guiX, 0, math.max(0, vp.X - W))
    local clampedY = math.clamp(savedState.guiY, 0, math.max(0, vp.Y - 50))
    panel.Position = UDim2.new(0, clampedX, 0, clampedY)
else
    panel.Position = UDim2.new(0.5, -math.floor(W/2), 0, 12)
end

-- ─── Bubble ───────────────────────────────────────────────────────────────────
local bubble = Instance.new("ImageButton", g)
bubble.Size = UDim2.new(0, 44, 0, 44)
bubble.Position = UDim2.new(1, -57, 0, 64)
bubble.BackgroundTransparency = 1
bubble.BorderSizePixel = 0
bubble.Visible = false
-- Fetch pfp from GitHub, save locally, load via getcustomasset
task.spawn(function()
    local PFP_FILE = "pfp_bg7_p03_scarlet.png"
    local PFP_URL  = "https://raw.githubusercontent.com/iMzTee/Immortality-Scripts/main/pfp_bg7_p03_scarlet.png"
    pcall(function()
        local data = game:HttpGet(PFP_URL, true)
        if data and #data > 0 then writefile(PFP_FILE, data) end
    end)
    if getcustomasset then
        local ok, url = pcall(getcustomasset, PFP_FILE)
        if ok and type(url) == "string" and url ~= "" then bubble.Image = url end
    end
end)
Instance.new("UICorner", bubble).CornerRadius = UDim.new(0.5, 0)
mkStroke(bubble, C_STROKE, 2, 0.15)
bubble.MouseButton1Click:Connect(function()
    bubble.Visible = false
    panel.Visible  = true
end)

-- ─── Tooltip ──────────────────────────────────────────────────────────────────
local ttFrame = Instance.new("Frame", g)
ttFrame.BackgroundColor3 = Color3.fromRGB(14, 4, 28)
ttFrame.BorderSizePixel  = 0
ttFrame.AutomaticSize    = Enum.AutomaticSize.XY
ttFrame.Visible          = false
ttFrame.ZIndex           = 20
Instance.new("UICorner", ttFrame).CornerRadius = UDim.new(0, 5)
mkStroke(ttFrame, C_DIV, 1, 0.3)
local ttPad = Instance.new("UIPadding", ttFrame)
ttPad.PaddingTop = UDim.new(0, 4) ttPad.PaddingBottom = UDim.new(0, 4)
ttPad.PaddingLeft = UDim.new(0, 8) ttPad.PaddingRight = UDim.new(0, 8)
local ttLbl = Instance.new("TextLabel", ttFrame)
ttLbl.BackgroundTransparency = 1
ttLbl.TextColor3 = Color3.fromRGB(215, 190, 255)
ttLbl.TextSize   = 10
ttLbl.Font       = Enum.Font.Gotham
ttLbl.AutomaticSize = Enum.AutomaticSize.XY
ttLbl.TextStrokeTransparency = 1
ttLbl.ZIndex = 20

local function setTooltip(btn, text)
    if not text or text == "" then return end
    btn.MouseEnter:Connect(function()
        ttLbl.Text = text
        local ap = btn.AbsolutePosition
        local as = btn.AbsoluteSize
        local vp = workspace.CurrentCamera.ViewportSize
        local tx = math.clamp(ap.X, 4, vp.X - 185)
        local ty = ap.Y + as.Y + 4
        if ty + 30 > vp.Y then ty = ap.Y - 34 end
        ttFrame.Position = UDim2.new(0, tx, 0, ty)
        ttFrame.Visible  = true
    end)
    btn.MouseLeave:Connect(function() ttFrame.Visible = false end)
end

-- ─── Title bar ────────────────────────────────────────────────────────────────
local titleBar = Instance.new("Frame", panel)
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = C_TITLE
titleBar.BorderSizePixel  = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
mkGrad(titleBar, C_TITLE, C_TITLE2, 135)

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1, -74, 1, 0)
titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = Color3.new(1, 1, 1)
titleLbl.TextStrokeTransparency = 1
titleLbl.Text     = "Devilish Scripts"
titleLbl.TextSize = 13
titleLbl.Font     = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size = UDim2.new(0, 28, 0, 24)
minBtn.Position = UDim2.new(1, -64, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(38, 12, 65)
minBtn.TextColor3 = Color3.fromRGB(235, 210, 255)
minBtn.Text = "-"
minBtn.TextSize = 18
minBtn.Font = Enum.Font.GothamBold
minBtn.BorderSizePixel = 0
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)
mkStroke(minBtn, C_DIV, 1, 0.25)
minBtn.MouseButton1Click:Connect(function()
    panel.Visible  = false
    bubble.Visible = true
end)
setTooltip(minBtn, "Minimize to bubble icon")

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 28, 0, 24)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(140, 18, 35)
closeBtn.TextColor3 = Color3.fromRGB(255, 155, 165)
closeBtn.Text = "X"
closeBtn.TextSize = 13
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
mkGrad(closeBtn, Color3.fromRGB(160, 22, 45), Color3.fromRGB(95, 8, 75), 90)
mkStroke(closeBtn, Color3.fromRGB(225, 55, 80), 1, 0.15)
closeBtn.MouseButton1Click:Connect(function()
    for _, def in ipairs(TOGGLE_DEFS) do
        local api = def.getApi()
        if api then pcall(function() api.disable() end) end
    end
    for _, def in ipairs({AR_DEF, ROLL_DEF, LEGIT_DEF, AC_DEF, UFO_DEF}) do
        local api = def.getApi()
        if api then pcall(function() api.disable() end) end
    end
    for _, def in ipairs(EXPLOIT_DEFS) do
        local api = def.getApi()
        if api then pcall(function() api.disable() end) end
    end
    g:Destroy()
    _G.SlimeRNGMain = nil
end)
setTooltip(closeBtn, "Close panel and disable all active scripts")

-- ─── Drag ─────────────────────────────────────────────────────────────────────
local dragging = false
local dragStart, panStart
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = input.Position
        panStart  = panel.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local d = input.Position - dragStart
    panel.Position = UDim2.new(panStart.X.Scale, panStart.X.Offset + d.X, panStart.Y.Scale, panStart.Y.Offset + d.Y)
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if dragging then
            dragging = false
            local ap = panel.AbsolutePosition
            local state = loadState()
            state.guiX = ap.X
            state.guiY = ap.Y
            saveState(state)
        end
    end
end)

-- ─── Tab bar ──────────────────────────────────────────────────────────────────
local tabBar = Instance.new("Frame", panel)
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.Position = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = C_TABS
tabBar.BorderSizePixel  = 0
mkGrad(tabBar, Color3.fromRGB(14, 5, 28), Color3.fromRGB(10, 3, 20), 90)

local tabControls = Instance.new("TextButton", tabBar)
tabControls.Size = UDim2.new(0, TAB_W, 1, 0)
tabControls.BackgroundColor3 = C_TAB_ON
tabControls.TextColor3 = C_TXT_ON
tabControls.Text = "Controls"
tabControls.TextSize = 10
tabControls.Font = Enum.Font.GothamBold
tabControls.BorderSizePixel = 0
Instance.new("UICorner", tabControls).CornerRadius = UDim.new(0, 5)

local tabStats = Instance.new("TextButton", tabBar)
tabStats.Size = UDim2.new(0, TAB_W, 1, 0)
tabStats.Position = UDim2.new(0, TAB_W, 0, 0)
tabStats.BackgroundColor3 = C_TAB_OFF
tabStats.TextColor3 = C_TXT_OFF
tabStats.Text = "Stats"
tabStats.TextSize = 10
tabStats.Font = Enum.Font.GothamBold
tabStats.BorderSizePixel = 0
Instance.new("UICorner", tabStats).CornerRadius = UDim.new(0, 5)

local tabCollect = Instance.new("TextButton", tabBar)
tabCollect.Size = UDim2.new(0, TAB_W, 1, 0)
tabCollect.Position = UDim2.new(0, TAB_W * 2, 0, 0)
tabCollect.BackgroundColor3 = C_TAB_OFF
tabCollect.TextColor3 = C_TXT_OFF
tabCollect.Text = "Collect"
tabCollect.TextSize = 10
tabCollect.Font = Enum.Font.GothamBold
tabCollect.BorderSizePixel = 0
Instance.new("UICorner", tabCollect).CornerRadius = UDim.new(0, 5)

local tabUfo = Instance.new("TextButton", tabBar)
tabUfo.Size = UDim2.new(0, TAB_W, 1, 0)
tabUfo.Position = UDim2.new(0, TAB_W * 3, 0, 0)
tabUfo.BackgroundColor3 = C_TAB_OFF
tabUfo.TextColor3 = C_TXT_OFF
tabUfo.Text = "UFO"
tabUfo.TextSize = 10
tabUfo.Font = Enum.Font.GothamBold
tabUfo.BorderSizePixel = 0
Instance.new("UICorner", tabUfo).CornerRadius = UDim.new(0, 5)

local tabExploits = Instance.new("TextButton", tabBar)
tabExploits.Size = UDim2.new(0, W - TAB_W * 4, 1, 0)
tabExploits.Position = UDim2.new(0, TAB_W * 4, 0, 0)
tabExploits.BackgroundColor3 = C_TAB_OFF
tabExploits.TextColor3 = C_TXT_OFF
tabExploits.Text = "Exploits"
tabExploits.TextSize = 10
tabExploits.Font = Enum.Font.GothamBold
tabExploits.BorderSizePixel = 0
Instance.new("UICorner", tabExploits).CornerRadius = UDim.new(0, 5)

local tabDiv = Instance.new("Frame", panel)
tabDiv.Size = UDim2.new(1, 0, 0, 1)
tabDiv.Position = UDim2.new(0, 0, 0, 60)
tabDiv.BackgroundColor3 = C_DIV
tabDiv.BorderSizePixel  = 0
mkGrad(tabDiv, C_DIV, Color3.fromRGB(150, 20, 55), 0)

-- ─── Content frames ───────────────────────────────────────────────────────────
local controlsFrame = Instance.new("Frame", panel)
controlsFrame.Position = UDim2.new(0, 0, 0, 61)
controlsFrame.BackgroundTransparency = 1
controlsFrame.BorderSizePixel = 0

local statsFrame = Instance.new("Frame", panel)
statsFrame.Position = UDim2.new(0, 0, 0, 61)
statsFrame.BackgroundTransparency = 1
statsFrame.BorderSizePixel = 0
statsFrame.Visible = false

local collectFrame = Instance.new("Frame", panel)
collectFrame.Position = UDim2.new(0, 0, 0, 61)
collectFrame.BackgroundTransparency = 1
collectFrame.BorderSizePixel = 0
collectFrame.Visible = false

local ufoFrame = Instance.new("Frame", panel)
ufoFrame.Position = UDim2.new(0, 0, 0, 61)
ufoFrame.BackgroundTransparency = 1
ufoFrame.BorderSizePixel = 0
ufoFrame.Visible = false

local exploitsFrame = Instance.new("Frame", panel)
exploitsFrame.Position = UDim2.new(0, 0, 0, 61)
exploitsFrame.BackgroundTransparency = 1
exploitsFrame.BorderSizePixel = 0
exploitsFrame.Visible = false

-- ─── Controls Tab ─────────────────────────────────────────────────────────────
local scrollFrame = Instance.new("ScrollingFrame", controlsFrame)
scrollFrame.Size = UDim2.new(1, 0, 0, SCROLL_H)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 28, 140)
scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
scrollFrame.ElasticBehavior = Enum.ElasticBehavior.Never

local refreshFns = {}
local cy = 4

local function hLine(parent, y)
    local d = Instance.new("Frame", parent)
    d.Size = UDim2.new(1, -12, 0, 1)
    d.Position = UDim2.new(0, 6, 0, y)
    d.BackgroundColor3 = C_DIV
    d.BorderSizePixel  = 0
    mkGrad(d, C_DIV, Color3.fromRGB(140, 18, 50), 0)
end

-- Create a toggle button for the given feature definition; registers a refresh callback
local function makeToggleBtn(parent, def, xPos, width, yPos)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0, width, 0, 28)
    btn.Position = UDim2.new(0, xPos, 0, yPos)
    btn.BackgroundColor3 = C_BTN_OFF
    btn.TextColor3 = C_BTXT_OFF
    btn.TextSize   = 13
    btn.Font       = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.TextStrokeTransparency = 1
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local btnStroke = mkStroke(btn, C_BSTR_OFF, 1.5, 0.2)

    -- Sync button color and label to the current ON/OFF state
    local function refresh()
        local api = def.getApi()
        local on  = api and api.isActive()
        btn.Text = def.label .. ": " .. (on and "ON" or "OFF")
        if on then
            btn.BackgroundColor3 = C_BTN_ON
            btn.TextColor3       = C_BTXT_ON
            btnStroke.Color       = C_BSTR_ON
            btnStroke.Transparency = 0.1
        else
            btn.BackgroundColor3 = C_BTN_OFF
            btn.TextColor3       = C_BTXT_OFF
            btnStroke.Color       = C_BSTR_OFF
            btnStroke.Transparency = 0.2
        end
    end

    btn.MouseButton1Click:Connect(function()
        local api = def.getApi()
        if api then pcall(function() api.toggle() end) end
        refresh()
        local state = loadState()
        local a = def.getApi()
        state[def.key] = a and a.isActive() or false
        saveState(state)
    end)

    refresh()
    table.insert(refreshFns, refresh)
    if def.tip then setTooltip(btn, def.tip) end
    return btn
end

-- Fast Roll and Legit Roll side-by-side in one row
do
    local b1 = makeToggleBtn(scrollFrame, ROLL_DEF, 6, HALF_W, cy)
    b1.TextSize = 11
    local b2 = makeToggleBtn(scrollFrame, LEGIT_DEF, 6 + HALF_W + 5, HALF_W, cy)
    b2.TextSize = 11
    cy = cy + 32
end
-- Main feature toggle buttons (full width)
for _, def in ipairs(TOGGLE_DEFS) do
    makeToggleBtn(scrollFrame, def, 6, W - 16, cy)
    cy = cy + 32
end

hLine(scrollFrame, cy) cy = cy + 8

-- Auto Return and Save Position side-by-side in one row
makeToggleBtn(scrollFrame, AR_DEF, 6, HALF_W, cy)

local savePosBtn = Instance.new("TextButton", scrollFrame)
savePosBtn.Size = UDim2.new(0, HALF_W, 0, 28)
savePosBtn.Position = UDim2.new(0, 6 + HALF_W + 5, 0, cy)
savePosBtn.BackgroundColor3 = C_BTN_ON
savePosBtn.TextColor3 = Color3.new(1, 1, 1)
savePosBtn.Text = "Save Position"
savePosBtn.TextSize = 11
savePosBtn.Font = Enum.Font.GothamBold
savePosBtn.BorderSizePixel = 0
savePosBtn.TextStrokeTransparency = 1
Instance.new("UICorner", savePosBtn).CornerRadius = UDim.new(0, 6)
mkStroke(savePosBtn, C_BSTR_ON, 1.5, 0.2)
savePosBtn.MouseButton1Click:Connect(function()
    if _G.SavePosition then _G.SavePosition.save() end
end)
setTooltip(savePosBtn, "Save your current location for Auto Return")
cy = cy + 32

hLine(scrollFrame, cy) cy = cy + 8

-- Zone Benchmark start/stop button (state updates in the update loop)
local zfBtn = Instance.new("TextButton", scrollFrame)
zfBtn.Size = UDim2.new(1, -16, 0, 28)
zfBtn.Position = UDim2.new(0, 6, 0, cy)
zfBtn.BackgroundColor3 = C_BTN_OFF
zfBtn.TextColor3 = C_BTXT_OFF
zfBtn.Text = "Zone Benchmark: Start"
zfBtn.TextSize = 12
zfBtn.Font = Enum.Font.GothamBold
zfBtn.BorderSizePixel = 0
zfBtn.TextStrokeTransparency = 1
Instance.new("UICorner", zfBtn).CornerRadius = UDim.new(0, 6)
local zfStroke = mkStroke(zfBtn, C_BSTR_OFF, 1.5, 0.2)
zfBtn.MouseButton1Click:Connect(function()
    local zf = _G.ZoneFarmer
    if not zf then return end
    if zf.isActive() then
        zf.stop()
    elseif not (zf.isDone and zf.isDone()) then
        zf.start()
    end
end)
setTooltip(zfBtn, "Tests top 5 zones for 3 min each, then farms the best one")
cy = cy + 32

scrollFrame.CanvasSize = UDim2.new(0, 0, 0, cy + 4)

local CTRL_CONTENT_H = SCROLL_H + 4
controlsFrame.Size = UDim2.new(1, 0, 0, CTRL_CONTENT_H)
local PANEL_H_CONTROLS = 61 + CTRL_CONTENT_H

-- ─── Stats Tab ────────────────────────────────────────────────────────────────
local sy = 0

local function shDiv()
    local d = Instance.new("Frame", statsFrame)
    d.Size = UDim2.new(1, 0, 0, 1)
    d.Position = UDim2.new(0, 0, 0, sy)
    d.BackgroundColor3 = C_DIV
    d.BackgroundTransparency = 0.2
    d.BorderSizePixel = 0
    mkGrad(d, C_DIV, Color3.fromRGB(155, 25, 55), 0)
    sy = sy + 1
end

local function smkCell(parent, txt, xOff, w, isLabel)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(0, w, 1, 0)
    l.Position = UDim2.new(0, xOff, 0, 0)
    l.BackgroundTransparency = 1
    l.TextColor3 = isLabel and Color3.fromRGB(240, 210, 255) or Color3.new(1, 1, 1)
    l.TextStrokeTransparency = 0.3
    l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    l.Text = txt
    l.TextSize = 12
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.BorderSizePixel = 0
    return l
end

shDiv()
local sHdrRow = Instance.new("Frame", statsFrame)
sHdrRow.Size = UDim2.new(1, 0, 0, 20)
sHdrRow.Position = UDim2.new(0, 0, 0, sy)
sHdrRow.BackgroundTransparency = 1
sHdrRow.BorderSizePixel = 0
local hc = smkCell(sHdrRow, "COIN", SX.val1, VAL_W, false)
hc.TextColor3 = Color3.fromRGB(255, 205, 95)
local hg = smkCell(sHdrRow, "GOOP", SX.val2, VAL_W, false)
hg.TextColor3 = Color3.fromRGB(135, 215, 255)
sy = sy + 20
shDiv()

local sRows = {}
local SROW_DEFS = {
    { lbl = "Total", key = "total" },
    { lbl = "/min",  key = "min"   },
    { lbl = "/hr",   key = "hr"    },
    { lbl = "/day",  key = "day"   },
}
for _, def in ipairs(SROW_DEFS) do
    local row = Instance.new("Frame", statsFrame)
    row.Size = UDim2.new(1, 0, 0, ROW_H)
    row.Position = UDim2.new(0, 0, 0, sy)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    smkCell(row, def.lbl, SX.lbl1, LBL_W, true)
    local coinLbl = smkCell(row, "--", SX.val1, VAL_W, false)
    coinLbl.TextColor3 = Color3.fromRGB(255, 205, 95)
    smkCell(row, def.lbl, SX.lbl2, LBL_W, true)
    local goopLbl = smkCell(row, "--", SX.val2, VAL_W, false)
    goopLbl.TextColor3 = Color3.fromRGB(135, 215, 255)
    sRows[def.key] = { coin = coinLbl, goop = goopLbl }
    sy = sy + ROW_H
end
shDiv()

local sFooter = Instance.new("Frame", statsFrame)
sFooter.Size = UDim2.new(1, 0, 0, 28)
sFooter.Position = UDim2.new(0, 0, 0, sy)
sFooter.BackgroundTransparency = 1
sFooter.BorderSizePixel = 0

local sSessionLbl = Instance.new("TextLabel", sFooter)
sSessionLbl.Size = UDim2.new(1, -76, 1, 0)
sSessionLbl.Position = UDim2.new(0, 8, 0, 0)
sSessionLbl.BackgroundTransparency = 1
sSessionLbl.TextColor3 = Color3.new(1, 1, 1)
sSessionLbl.TextStrokeTransparency = 0.3
sSessionLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
sSessionLbl.Text = "Session: 0:00"
sSessionLbl.TextSize = 11
sSessionLbl.Font = Enum.Font.GothamBold
sSessionLbl.TextXAlignment = Enum.TextXAlignment.Left

local sResetBtn = Instance.new("TextButton", sFooter)
sResetBtn.Size = UDim2.new(0, 60, 0, 22)
sResetBtn.Position = UDim2.new(1, -64, 0.5, -11)
sResetBtn.BackgroundColor3 = C_BTN_OFF
sResetBtn.TextColor3 = Color3.new(1, 1, 1)
sResetBtn.Text = "Reset"
sResetBtn.TextSize = 11
sResetBtn.Font = Enum.Font.GothamBold
sResetBtn.BorderSizePixel = 0
sResetBtn.TextStrokeTransparency = 1
Instance.new("UICorner", sResetBtn).CornerRadius = UDim.new(0, 4)
mkStroke(sResetBtn, C_BSTR_OFF, 1.5, 0.2)
sResetBtn.MouseButton1Click:Connect(function()
    if _G.StatsTracker then _G.StatsTracker.reset() end
end)
setTooltip(sResetBtn, "Reset session coin and goop counters to zero")
sy = sy + 28

statsFrame.Size = UDim2.new(1, 0, 0, sy)
local PANEL_H_STATS = 61 + sy

-- ─── Collect Tab ──────────────────────────────────────────────────────────────
local FRUIT_DEFS = {
    { name = "Magician Fruit",  id = "magicianFruit",  tip = "Only collect Magician Fruit" },
    { name = "Sword Fruit",     id = "swordFruit",     tip = "Only collect Sword Fruit" },
    { name = "Universe Fruit",  id = "universeFruit",  tip = "Only collect Universe Fruit" },
    { name = "Lightning Fruit", id = "lightningFruit", tip = "Only collect Lightning Fruit" },
    { name = "Fire Fruit",      id = "fireFruit",      tip = "Only collect Fire Fruit" },
    { name = "Ice Fruit",       id = "iceFruit",       tip = "Only collect Ice Fruit" },
}
local fruitSelected = {}
for _, fd in ipairs(FRUIT_DEFS) do
    fruitSelected[fd.id] = savedState["fruit_" .. fd.id] == true
end
local function applyFruitFilter()
    local ac = _G.AutoCollect
    if not (ac and ac.setFilter) then return end
    local filter, hasAny = {}, false
    for id, sel in pairs(fruitSelected) do
        if sel then filter[id] = true hasAny = true end
    end
    ac.setFilter(hasAny and filter or {})
end

local cy_c = 4
makeToggleBtn(collectFrame, AC_DEF, 6, W - 16, cy_c)
cy_c = cy_c + 32

hLine(collectFrame, cy_c) cy_c = cy_c + 5

local filterLbl = Instance.new("TextLabel", collectFrame)
filterLbl.Size = UDim2.new(1, -12, 0, 16)
filterLbl.Position = UDim2.new(0, 6, 0, cy_c)
filterLbl.BackgroundTransparency = 1
filterLbl.TextColor3 = Color3.fromRGB(190, 150, 255)
filterLbl.Text = "Fruit Filter  (none selected = collect all)"
filterLbl.TextSize = 10
filterLbl.Font = Enum.Font.GothamBold
filterLbl.TextXAlignment = Enum.TextXAlignment.Left
filterLbl.TextStrokeTransparency = 1
filterLbl.BorderSizePixel = 0
cy_c = cy_c + 20

for i, fd in ipairs(FRUIT_DEFS) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local xPos = col == 0 and 6 or (6 + HALF_W + 5)
    local yPos = cy_c + row * 32
    local btn = Instance.new("TextButton", collectFrame)
    btn.Size = UDim2.new(0, HALF_W, 0, 28)
    btn.Position = UDim2.new(0, xPos, 0, yPos)
    btn.BorderSizePixel = 0
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold
    btn.TextStrokeTransparency = 1
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local bStroke = mkStroke(btn, C_BSTR_OFF, 1.5, 0.2)
    local function refreshFruit()
        local on = fruitSelected[fd.id]
        btn.Text = fd.name .. (on and ": ON" or ": OFF")
        btn.BackgroundColor3 = on and C_BTN_ON or C_BTN_OFF
        btn.TextColor3 = on and C_BTXT_ON or C_BTXT_OFF
        bStroke.Color = on and C_BSTR_ON or C_BSTR_OFF
        bStroke.Transparency = on and 0.1 or 0.2
    end
    btn.MouseButton1Click:Connect(function()
        fruitSelected[fd.id] = not fruitSelected[fd.id]
        refreshFruit()
        local state = loadState()
        state["fruit_" .. fd.id] = fruitSelected[fd.id]
        saveState(state)
        applyFruitFilter()
    end)
    refreshFruit()
    setTooltip(btn, fd.tip)
end

cy_c = cy_c + 3 * 32
collectFrame.Size = UDim2.new(1, 0, 0, cy_c + 4)
local PANEL_H_COLLECT = 61 + cy_c + 4
applyFruitFilter()

-- ─── Exploits Tab ─────────────────────────────────────────────────────────────
local cy_e = 6
for _, def in ipairs(EXPLOIT_DEFS) do
    makeToggleBtn(exploitsFrame, def, 6, W - 16, cy_e)
    cy_e = cy_e + 32
end

-- Rejoin button
do
    local rejoinBtn = Instance.new("TextButton", exploitsFrame)
    rejoinBtn.Size = UDim2.new(0, W - 16, 0, 28)
    rejoinBtn.Position = UDim2.new(0, 6, 0, cy_e)
    rejoinBtn.BackgroundColor3 = C_BTN_OFF
    rejoinBtn.TextColor3 = C_TXT_ON
    rejoinBtn.TextSize = 13
    rejoinBtn.Font = Enum.Font.GothamBold
    rejoinBtn.BorderSizePixel = 0
    rejoinBtn.Text = "Rejoin Server"
    Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 6)
    mkStroke(rejoinBtn, C_BSTR_OFF, 1.5, 0.2)
    setTooltip(rejoinBtn, "Teleports back into the same server (works in private servers)")
    rejoinBtn.MouseButton1Click:Connect(function()
        if _G.Rejoin then _G.Rejoin.fire() end
    end)
    cy_e = cy_e + 32
end

exploitsFrame.Size = UDim2.new(1, 0, 0, cy_e + 4)
local PANEL_H_EXPLOITS = 61 + cy_e + 4

-- ─── UFO Tab ─────────────────────────────────────────────────────────────────
local cy_u = 6
makeToggleBtn(ufoFrame, UFO_DEF, 6, W - 16, cy_u)
cy_u = cy_u + 32
ufoFrame.Size = UDim2.new(1, 0, 0, cy_u + 4)
local PANEL_H_UFO = 61 + cy_u + 4

-- ─── Tab switching ────────────────────────────────────────────────────────────
local function showTab(name)
    controlsFrame.Visible = (name == "controls")
    statsFrame.Visible    = (name == "stats")
    collectFrame.Visible  = (name == "collect")
    ufoFrame.Visible      = (name == "ufo")
    exploitsFrame.Visible = (name == "exploits")
    local function setTab(btn, on)
        btn.BackgroundColor3 = on and C_TAB_ON or C_TAB_OFF
        btn.TextColor3 = on and C_TXT_ON or C_TXT_OFF
    end
    setTab(tabControls, name == "controls")
    setTab(tabStats,    name == "stats")
    setTab(tabCollect,  name == "collect")
    setTab(tabUfo,      name == "ufo")
    setTab(tabExploits, name == "exploits")
    panelBg.Visible = (name ~= "stats")
    if name == "controls" then
        panel.Size = UDim2.new(0, W, 0, PANEL_H_CONTROLS)
    elseif name == "stats" then
        panel.Size = UDim2.new(0, W, 0, PANEL_H_STATS)
    elseif name == "collect" then
        panel.Size = UDim2.new(0, W, 0, PANEL_H_COLLECT)
    elseif name == "ufo" then
        panel.Size = UDim2.new(0, W, 0, PANEL_H_UFO)
    else
        panel.Size = UDim2.new(0, W, 0, PANEL_H_EXPLOITS)
    end
end

tabControls.MouseButton1Click:Connect(function() showTab("controls") end)
tabStats.MouseButton1Click:Connect(function() showTab("stats") end)
tabCollect.MouseButton1Click:Connect(function() showTab("collect") end)
tabUfo.MouseButton1Click:Connect(function() showTab("ufo") end)
tabExploits.MouseButton1Click:Connect(function() showTab("exploits") end)
showTab("controls")

-- ─── Update loop ──────────────────────────────────────────────────────────────
-- Refresh all toggle button states, Zone Benchmark button, and stats display every second
task.spawn(function()
    while g.Parent do
        task.wait(1)
        for _, r in ipairs(refreshFns) do r() end

        local zf = _G.ZoneFarmer
        if zf then
            if zf.isActive() then
                zfBtn.Text = "Zone Benchmark: Stop"
                zfBtn.BackgroundColor3 = C_BTN_ON
                zfBtn.TextColor3 = C_BTXT_ON
                zfStroke.Color = C_BSTR_ON
            elseif zf.isDone and zf.isDone() then
                zfBtn.Text = "Zone Benchmark: Done"
                zfBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
                zfBtn.TextColor3 = Color3.fromRGB(110, 110, 140)
                zfStroke.Color = Color3.fromRGB(55, 55, 80)
            else
                zfBtn.Text = "Zone Benchmark: Start"
                zfBtn.BackgroundColor3 = C_BTN_OFF
                zfBtn.TextColor3 = C_BTXT_OFF
                zfStroke.Color = C_BSTR_OFF
            end
        end

        local st = _G.StatsTracker
        if st then
            local r = st.getRates()
            sRows.total.coin.Text = fmt(st.getCoins())
            sRows.total.goop.Text = fmt(st.getGoop())
            sRows.min.coin.Text   = fmt(r.coinMin)
            sRows.min.goop.Text   = fmt(r.goopMin)
            sRows.hr.coin.Text    = fmt(r.coinHr)
            sRows.hr.goop.Text    = fmt(r.goopHr)
            sRows.day.coin.Text   = fmt(r.coinDay)
            sRows.day.goop.Text   = fmt(r.goopDay)
            sSessionLbl.Text = "Session: " .. fmtTime(st.getElapsed())
        end
    end
end)

-- ─── Public API ───────────────────────────────────────────────────────────────
_G.SlimeRNGMain = {
    close = function() g:Destroy() _G.SlimeRNGMain = nil end,
}
