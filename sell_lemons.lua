-- ─── Sell Lemons Automation ───────────────────────────────────────────────────
-- Devilish Scripts | Sell Lemons
-- Targets Potassium executor

if _G.SellLemonsMain then return end
_G.SellLemonsMain = true
print("[Sell Lemons] Loading...")

-- ─── Services ─────────────────────────────────────────────────────────────────
local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local CS            = game:GetService("CollectionService")
local UIS           = game:GetService("UserInputService")
local HttpService   = game:GetService("HttpService")
local VirtualUser   = game:GetService("VirtualUser")
local PL            = Players.LocalPlayer

-- ─── Utilities ────────────────────────────────────────────────────────────────
local function jitter(base, pct) return base * (1 + (math.random() - 0.5) * pct) end

-- ─── State persistence ────────────────────────────────────────────────────────
local STATE_FILE = "sellLemons_state.json"
local function loadState()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(STATE_FILE))
    end)
    return (ok and type(data) == "table") and data or {}
end
local function saveState(s)
    pcall(function() writefile(STATE_FILE, HttpService:JSONEncode(s)) end)
end
local savedState = loadState()

-- ─── Tycoon discovery ─────────────────────────────────────────────────────────
local myTycoon, remotes
for _ = 1, 60 do
    for _, tycoon in CS:GetTagged("Tycoon") do
        local owner = tycoon:FindFirstChild("Owner")
        if owner and owner:IsA("ObjectValue") and owner.Value == PL then
            myTycoon = tycoon
            break
        end
    end
    if myTycoon then break end
    task.wait(0.5)
end
if not myTycoon then
    print("[Sell Lemons] Could not find your tycoon after 30s.")
    _G.SellLemonsMain = nil
    return
end
print("[Sell Lemons] Tycoon found: " .. myTycoon:GetFullName())

-- Wait for Remotes folder (may not exist immediately)
local ok, result = pcall(function()
    return myTycoon:WaitForChild("Remotes", 10)
end)
remotes = ok and result or nil
if remotes then
    print("[Sell Lemons] Remotes folder found (" .. #remotes:GetChildren() .. " children)")
else
    print("[Sell Lemons] WARNING: Remotes folder not found after 10s")
end

-- Wait for entities to finish replicating (tags, remotes)
task.wait(3)

-- ─── Balance module (for price sorting) ──────────────────────────────────────
local Balance
pcall(function() Balance = require(RS:WaitForChild("Balance", 5)) end)
if Balance and Balance.PurchasePrices then
    local count = 0
    for _ in pairs(Balance.PurchasePrices) do count = count + 1 end
    print("[Sell Lemons] Balance loaded (" .. count .. " prices)")
else
    print("[Sell Lemons] WARNING: Balance not loaded — purchases will NOT be sorted by price")
end

-- ─── CashDrop remote discovery ────────────────────────────────────────────────
local cashDropNew, cashDropRedeem
pcall(function()
    for _, v in RS:GetDescendants() do
        if v.Name == "CashDropService.New" and v:IsA("RemoteEvent") then
            cashDropNew = v
        elseif v.Name == "CashDropService.Redeem" and v:IsA("RemoteFunction") then
            cashDropRedeem = v
        end
        if cashDropNew and cashDropRedeem then break end
    end
end)
if cashDropNew then
    print("[Sell Lemons] CashDrop remotes found")
else
    print("[Sell Lemons] CashDrop remotes not found (feature will be unavailable)")
end

-- ─── Tycoon value reader ─────────────────────────────────────────────────────
local function getTycoonValue(name)
    local vals = myTycoon:FindFirstChild("Values")
    if not vals then return nil end
    local inst = vals:FindFirstChild(name)
    return inst and inst.Value or nil
end

-- ─── Remote finder (checks IsA to avoid non-remote children with same name) ──
local function findRemoteFunction(parent, name)
    for _, child in parent:GetChildren() do
        if child.Name == name and child:IsA("RemoteFunction") then
            return child
        end
    end
    return nil
end

-- ─── Suppress purchase animations (prevents lag spikes) ─────────────────────
local function suppressAnimations(inst)
    if inst:IsDescendantOf(myTycoon) then
        pcall(function() inst:SetAttribute("DisableReveal", true) end)
    end
end
for _, item in CS:GetTagged("Tycoon.Purchase") do suppressAnimations(item) end
for _, item in CS:GetTagged("Tycoon.Purchasable") do suppressAnimations(item) end
CS:GetInstanceAddedSignal("Tycoon.Purchase"):Connect(suppressAnimations)
CS:GetInstanceAddedSignal("Tycoon.Purchasable"):Connect(suppressAnimations)

-- ═══════════════════════════════════════════════════════════════════════════════
-- Feature Modules — batch every 0.5s, sequential calls (no coroutine flood)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── Price helper (cheapest first) ───────────────────────────────────────────
local function getPrice(name)
    if Balance and Balance.PurchasePrices then
        local p = Balance.PurchasePrices[name]
        if p then return p end
        p = Balance.PurchasePrices[name:gsub(" ", "")]
        if p then return p end
    end
    return 999999
end

-- ─── Auto Purchase (both tags, sorted cheapest first, 10 per tick) ──────────
do
    local active = false
    local debugOnce = true
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active then continue end
            pcall(function()
                local seen = {}
                local items = {}
                for _, tag in ipairs({"Tycoon.Purchase", "Tycoon.Purchasable"}) do
                    for _, item in CS:GetTagged(tag) do
                        if item:IsDescendantOf(myTycoon)
                            and not item:GetAttribute("Purchased")
                            and not seen[item] then
                            seen[item] = true
                            local rf = findRemoteFunction(item, "Purchase")
                            if rf then
                                table.insert(items, {rf = rf, price = getPrice(item.Name), name = item.Name})
                            end
                        end
                    end
                end
                table.sort(items, function(a, b) return a.price < b.price end)
                -- Debug: print first batch of sorted items once
                if debugOnce and #items > 0 then
                    debugOnce = false
                    print("[AutoPurchase] " .. #items .. " unpurchased items found. Top 10:")
                    for idx = 1, math.min(10, #items) do
                        print("  " .. idx .. ". " .. items[idx].name .. " (price=" .. tostring(items[idx].price) .. ")")
                    end
                end
                for idx, entry in ipairs(items) do
                    if idx > 10 then break end
                    pcall(entry.rf.InvokeServer, entry.rf, false)
                end
            end)
        end
    end)
    _G.SL_AutoPurchase = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Upgrade ─────────────────────────────────────────────────────────────
local ALL_BUILDINGS = {"LemonStand","LemonDash","LemonDepot","LemonTrading","LemonLabs","LemonRobotics","LemonRepublic","LemonX"}
local BUILDING_LABELS = {
    LemonStand="Lemon Stand", LemonDash="Lemon Dash", LemonDepot="Lemon Depot",
    LemonTrading="Lemon Trading", LemonLabs="Lemon Labs", LemonRobotics="Lemon Robotics",
    LemonRepublic="Lemon Republic", LemonX="Lemon X",
}
do
    local active = false
    local upgradeCount = 1
    local enabledBuildings = {}
    for _, name in ipairs(ALL_BUILDINGS) do enabledBuildings[name] = true end

    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active then continue end
            pcall(function()
                for _, earner in CS:GetTagged("Tycoon.Earner") do
                    if earner:IsDescendantOf(myTycoon) then
                        local eName = earner.Name:gsub("[^%w]", "")
                        if not enabledBuildings[eName] then continue end
                        local rf = findRemoteFunction(earner, "Upgrade")
                        if rf then pcall(rf.InvokeServer, rf, upgradeCount) end
                    end
                end
            end)
        end
    end)
    _G.SL_AutoUpgrade = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
        setCount = function(n) upgradeCount = n end,
        getCount = function() return upgradeCount end,
        setBuilding = function(name, val) enabledBuildings[name] = val end,
        getBuildings = function() return enabledBuildings end,
    }
end

-- ─── Auto Wake ────────────────────────────────────────────────────────────────
do
    local active = false
    local debugOnce = true
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active or not remotes then continue end
            pcall(function()
                local wakeRF = findRemoteFunction(remotes, "WakeIncomeStream")
                if not wakeRF then
                    if debugOnce then debugOnce = false; print("[AutoWake] WakeIncomeStream RF not found") end
                    return
                end
                -- Build set of earners with active managers
                local managed = {}
                for _, item in CS:GetTagged("Tycoon.Purchase") do
                    if item:IsDescendantOf(myTycoon) and item:GetAttribute("Purchased") then
                        local autos = item:GetAttribute("Automatics")
                        if autos and type(autos) == "string" then
                            for name in autos:gmatch("[^,]+") do
                                managed[name:match("^%s*(.-)%s*$"):lower()] = true
                            end
                        end
                    end
                end
                if debugOnce then
                    debugOnce = false
                    local managedList = {}
                    for k in pairs(managed) do table.insert(managedList, k) end
                    print("[AutoWake] Managed earners: " .. (next(managed) and table.concat(managedList, ", ") or "none"))
                    local earnerNames = {}
                    for _, earner in CS:GetTagged("Tycoon.Earner") do
                        if earner:IsDescendantOf(myTycoon) then
                            local skip = managed[earner.Name:lower()] and " (SKIPPED-managed)" or ""
                            table.insert(earnerNames, earner.Name .. skip)
                        end
                    end
                    print("[AutoWake] Earners found: " .. table.concat(earnerNames, ", "))
                end
                for _, earner in CS:GetTagged("Tycoon.Earner") do
                    if earner:IsDescendantOf(myTycoon) and not managed[earner.Name:lower()] then
                        pcall(wakeRF.InvokeServer, wakeRF, earner.Name)
                        -- Also try without spaces (server may use CamelCase key)
                        local noSpaces = earner.Name:gsub(" ", "")
                        if noSpaces ~= earner.Name then
                            pcall(wakeRF.InvokeServer, wakeRF, noSpaces)
                        end
                    end
                end
            end)
        end
    end)
    _G.SL_AutoWake = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ─── Auto CashVine ────────────────────────────────────────────────────────────
do
    local active = false
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active then continue end
            pcall(function()
                for _, vine in CS:GetTagged("CashVine") do
                    local rf = findRemoteFunction(vine, "Use")
                    if rf then pcall(rf.InvokeServer, rf) end
                end
            end)
        end
    end)
    _G.SL_AutoCashVine = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Cash Drops (TP to each drop, touch to collect, TP back) ───────────
do
    local active = false
    local conn
    local pendingDrops = {}

    -- Hook the New event to capture drop positions as they arrive
    local function tryHook()
        if conn then return end
        if not cashDropNew then
            pcall(function()
                for _, v in RS:GetDescendants() do
                    if v.Name == "CashDropService.New" and v:IsA("RemoteEvent") then
                        cashDropNew = v; break
                    end
                end
            end)
        end
        if cashDropNew then
            conn = cashDropNew.OnClientEvent:Connect(function(dropId, lifetime, pos)
                if active and pos then
                    table.insert(pendingDrops, pos)
                end
            end)
            print("[Sell Lemons] CashDrop event hooked")
        end
    end

    -- Scan workspace for all CashDrop parts
    local function findDropParts()
        local positions = {}
        local seen = {}
        pcall(function()
            for _, desc in workspace:GetDescendants() do
                -- Match by name "CashDrop" with a "Bag" child
                if desc.Name == "CashDrop" and desc:IsA("BasePart") and not seen[desc] then
                    seen[desc] = true
                    local bag = desc:FindFirstChild("Bag")
                    if bag then
                        table.insert(positions, bag.Position)
                    else
                        table.insert(positions, desc.Position)
                    end
                -- Also match any Bag part inside CharactersOnly collision group
                elseif desc.Name == "Bag" and desc:IsA("BasePart")
                    and desc.Parent and not seen[desc.Parent] then
                    seen[desc.Parent] = true
                    table.insert(positions, desc.Position)
                end
            end
        end)
        return positions
    end

    -- TP to drops, collect via touch, TP back
    local function collectDrops()
        local char = PL.Character
        if not char then return end
        local pivot = char:GetPivot()
        local homePos = pivot.Position

        -- Merge pending event positions + scanned workspace positions
        local drops = findDropParts()
        for _, pos in ipairs(pendingDrops) do
            table.insert(drops, pos)
        end
        pendingDrops = {}

        if #drops == 0 then return end
        print("[AutoDrop] Collecting " .. #drops .. " drops")

        for _, pos in ipairs(drops) do
            char = PL.Character
            if not char then break end
            char:PivotTo(CFrame.new(pos))
            task.wait() -- one frame for Touched to fire
        end

        -- TP back home
        char = PL.Character
        if char then
            char:PivotTo(CFrame.new(homePos))
        end
    end

    local function setActive(val)
        active = val
        if active then tryHook() end
        if not active and conn then
            conn:Disconnect()
            conn = nil
        end
    end

    -- Collect every 30 seconds
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(30)
            if not active then continue end
            if not conn then tryHook() end
            pcall(collectDrops)
        end
    end)

    _G.SL_AutoCashDrops = {
        enable   = function() setActive(true) end,
        disable  = function() setActive(false) end,
        toggle   = function(val) if val == nil then setActive(not active) else setActive(val) end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Phone ───────────────────────────────────────────────────────────────
do
    local active = false
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active or not remotes then continue end
            pcall(function()
                local re = remotes:FindFirstChild("PhoneOffer")
                if re and re:IsA("RemoteEvent") then
                    re:FireServer("Accept")
                end
            end)
        end
    end)
    _G.SL_AutoPhone = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Powers ──────────────────────────────────────────────────────────────
do
    local active = false
    local POWERS = {"Manage", "WalkSpeed", "UpgradeStack", "BuyNext", "ClickFruitValue"}
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active or not remotes then continue end
            pcall(function()
                local rf = findRemoteFunction(remotes, "UpgradePowerLevel")
                if not rf then return end
                for _, name in ipairs(POWERS) do
                    pcall(rf.InvokeServer, rf, name)
                end
            end)
        end
    end)
    _G.SL_AutoPowers = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ─── Anti-AFK (always on) ────────────────────────────────────────────────────
PL.Idled:Connect(function()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ─── Auto Rebirth (WIP: server handler unresponsive) ─────────────────────────
do
    local active = false
    local inFlight = false
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active or not remotes or inFlight then continue end
            local rf = findRemoteFunction(remotes, "Rebirth")
            if not rf then continue end
            inFlight = true
            task.spawn(function()
                pcall(rf.InvokeServer, rf)
                inFlight = false
            end)
        end
    end)
    _G.SL_AutoRebirth = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Evolve (WIP: server handler unresponsive) ──────────────────────────
do
    local active = false
    local inFlight = false
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active or not remotes or inFlight then continue end
            local rf = findRemoteFunction(remotes, "Evolve")
            if not rf then continue end
            inFlight = true
            task.spawn(function()
                pcall(rf.InvokeServer, rf)
                inFlight = false
            end)
        end
    end)
    _G.SL_AutoEvolve = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ─── Auto Ascend (WIP: server handler unresponsive) ──────────────────────────
do
    local active = false
    local inFlight = false
    task.spawn(function()
        while _G.SellLemonsMain do
            task.wait(0.5)
            if not active or not remotes or inFlight then continue end
            local rf = findRemoteFunction(remotes, "Ascend")
            if not rf then continue end
            inFlight = true
            task.spawn(function()
                pcall(rf.InvokeServer, rf)
                inFlight = false
            end)
        end
    end)
    _G.SL_AutoAscend = {
        enable   = function() active = true end,
        disable  = function() active = false end,
        toggle   = function(val) if val == nil then active = not active else active = val end end,
        isActive = function() return active end,
    }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- ─── Layout constants ─────────────────────────────────────────────────────────
local W      = 299
local HALF_W = 141
local TAB_W  = math.floor(W / 2)
local PANEL_H_CONTROLS = 253
local PANEL_H_PRESTIGE = 211

-- ─── Style helpers ────────────────────────────────────────────────────────────
local function mkGrad(parent, c1, c2, rot)
    local g2 = Instance.new("UIGradient", parent)
    g2.Color    = ColorSequence.new(c1, c2)
    g2.Rotation = rot or 90
    return g2
end
local function mkStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color           = color
    s.Thickness       = thickness or 1
    s.Transparency    = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end
local function hLine(parent, y)
    local d = Instance.new("Frame", parent)
    d.Size = UDim2.new(0, W - 12, 0, 1)
    d.Position = UDim2.new(0, 6, 0, y)
    d.BackgroundColor3 = C_DIV
    d.BorderSizePixel  = 0
    mkGrad(d, C_DIV, Color3.fromRGB(140, 18, 50), 0)
end

-- ─── Root ScreenGui ───────────────────────────────────────────────────────────
local g = Instance.new("ScreenGui")
g.ResetOnSpawn   = false
g.Name           = "SellLemonsMain"
g.IgnoreGuiInset = true
g.Parent         = PL.PlayerGui

-- ─── Panel ────────────────────────────────────────────────────────────────────
local panel = Instance.new("Frame", g)
panel.Size = UDim2.new(0, W, 0, PANEL_H_CONTROLS)
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
    panel.Position = UDim2.new(0.5, -math.floor(W / 2), 0, 12)
end

-- ─── Bubble ───────────────────────────────────────────────────────────────────
local bubble = Instance.new("ImageButton", g)
bubble.Size = UDim2.new(0, 44, 0, 44)
bubble.Position = UDim2.new(1, -57, 0, 64)
bubble.BackgroundTransparency = 1
bubble.BorderSizePixel = 0
bubble.Visible = false
task.spawn(function()
    local PFP_FILE = "pfp_bg7_p03_scarlet.png"
    local PFP_URL  = "https://raw.githubusercontent.com/iMzTee/Immortality-Scripts/main/pfp_bg7_p03_scarlet.png"
    pcall(function()
        local data = game:HttpGet(PFP_URL, true)
        if data and #data > 0 then writefile(PFP_FILE, data) end
    end)
    if getcustomasset then
        local ok3, url = pcall(getcustomasset, PFP_FILE)
        if ok3 and type(url) == "string" and url ~= "" then bubble.Image = url end
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
ttPad.PaddingTop    = UDim.new(0, 4)
ttPad.PaddingBottom = UDim.new(0, 4)
ttPad.PaddingLeft   = UDim.new(0, 8)
ttPad.PaddingRight  = UDim.new(0, 8)
local ttLbl = Instance.new("TextLabel", ttFrame)
ttLbl.BackgroundTransparency = 1
ttLbl.TextColor3    = Color3.fromRGB(215, 190, 255)
ttLbl.TextSize      = 10
ttLbl.Font          = Enum.Font.Gotham
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
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = Color3.new(1, 1, 1)
titleLbl.TextStrokeTransparency = 1
titleLbl.Text     = "Devilish Scripts | Sell Lemons"
titleLbl.TextSize = 12
titleLbl.Font     = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ─── Minimize button ──────────────────────────────────────────────────────────
local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size = UDim2.new(0, 28, 0, 24)
minBtn.Position = UDim2.new(1, -64, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(38, 12, 65)
minBtn.TextColor3 = Color3.fromRGB(235, 210, 255)
minBtn.Text     = "-"
minBtn.TextSize = 18
minBtn.Font     = Enum.Font.GothamBold
minBtn.BorderSizePixel = 0
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)
mkStroke(minBtn, C_DIV, 1, 0.25)
minBtn.MouseButton1Click:Connect(function()
    panel.Visible  = false
    bubble.Visible = true
end)
setTooltip(minBtn, "Minimize to bubble icon")

-- ─── Close button ─────────────────────────────────────────────────────────────
local CTRL_DEFS, PRESTIGE_DEFS -- forward declarations for close handler

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 28, 0, 24)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(140, 18, 35)
closeBtn.TextColor3 = Color3.fromRGB(255, 155, 165)
closeBtn.Text     = "X"
closeBtn.TextSize = 13
closeBtn.Font     = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
mkGrad(closeBtn, Color3.fromRGB(160, 22, 45), Color3.fromRGB(95, 8, 75), 90)
mkStroke(closeBtn, Color3.fromRGB(225, 55, 80), 1, 0.15)
closeBtn.MouseButton1Click:Connect(function()
    for _, defs in ipairs({CTRL_DEFS, PRESTIGE_DEFS}) do
        for _, def in ipairs(defs) do
            local api = def.getApi()
            if api then pcall(function() api.disable() end) end
        end
    end
    g:Destroy()
    _G.SellLemonsMain = nil
end)
setTooltip(closeBtn, "Close panel and disable all scripts")

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
            local state = loadState()
            state.guiX = panel.Position.X.Offset
            state.guiY = panel.Position.Y.Offset
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
tabControls.Text     = "Controls"
tabControls.TextSize = 10
tabControls.Font     = Enum.Font.GothamBold
tabControls.BorderSizePixel = 0
Instance.new("UICorner", tabControls).CornerRadius = UDim.new(0, 5)

local tabPrestige = Instance.new("TextButton", tabBar)
tabPrestige.Size = UDim2.new(0, W - TAB_W, 1, 0)
tabPrestige.Position = UDim2.new(0, TAB_W, 0, 0)
tabPrestige.BackgroundColor3 = C_TAB_OFF
tabPrestige.TextColor3 = C_TXT_OFF
tabPrestige.Text     = "Prestige"
tabPrestige.TextSize = 10
tabPrestige.Font     = Enum.Font.GothamBold
tabPrestige.BorderSizePixel = 0
Instance.new("UICorner", tabPrestige).CornerRadius = UDim.new(0, 5)

local tabDiv = Instance.new("Frame", panel)
tabDiv.Size = UDim2.new(1, 0, 0, 1)
tabDiv.Position = UDim2.new(0, 0, 0, 60)
tabDiv.BackgroundColor3 = C_DIV
tabDiv.BorderSizePixel  = 0
mkGrad(tabDiv, C_DIV, Color3.fromRGB(150, 20, 55), 0)

-- ─── Content frames (explicit sizes for child layout) ────────────────────────
local controlsFrame = Instance.new("Frame", panel)
controlsFrame.Size = UDim2.new(0, W, 0, 192)
controlsFrame.Position = UDim2.new(0, 0, 0, 61)
controlsFrame.BackgroundTransparency = 1
controlsFrame.BorderSizePixel = 0

local prestigeFrame = Instance.new("Frame", panel)
prestigeFrame.Size = UDim2.new(0, W, 0, PANEL_H_PRESTIGE - 61)
prestigeFrame.Position = UDim2.new(0, 0, 0, 61)
prestigeFrame.BackgroundTransparency = 1
prestigeFrame.BorderSizePixel = 0
prestigeFrame.Visible = false

-- ─── Toggle definitions ──────────────────────────────────────────────────────
CTRL_DEFS = {
    {key = "autoPurchase", label = "Auto Purchase", getApi = function() return _G.SL_AutoPurchase end, tip = "Buys next affordable building"},
    {key = "autoUpgrade",  label = "Auto Upgrade",  getApi = function() return _G.SL_AutoUpgrade end,  tip = "Upgrades earners to max level"},
    {key = "autoWake",     label = "Auto Wake",     getApi = function() return _G.SL_AutoWake end,     tip = "Collects income from idle earners"},
    {key = "autoCashVine", label = "Auto CashVine", getApi = function() return _G.SL_AutoCashVine end, tip = "Collects cash vine when ready"},
    {key = "autoCashDrops",label = "Auto Drops",    getApi = function() return _G.SL_AutoCashDrops end,tip = "Auto-redeems cash drops"},
    {key = "autoPhone",    label = "Auto Phone",    getApi = function() return _G.SL_AutoPhone end,    tip = "Accepts phone offers automatically"},
    {key = "autoPowers",   label = "Auto Powers",   getApi = function() return _G.SL_AutoPowers end,   tip = "Buys affordable power upgrades"},
}

PRESTIGE_DEFS = {
    {key = "autoRebirth", label = "Auto Rebirth", getApi = function() return _G.SL_AutoRebirth end, tip = "Rebirths when requirements met"},
    {key = "autoEvolve",  label = "Auto Evolve",  getApi = function() return _G.SL_AutoEvolve end,  tip = "Evolves to next fruit when ready"},
    {key = "autoAscend",  label = "Auto Ascend",  getApi = function() return _G.SL_AutoAscend end,  tip = "Ascends when requirements met"},
}

-- ─── makeToggleBtn ────────────────────────────────────────────────────────────
local refreshFns = {}

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

    local function refresh()
        local api = def.getApi()
        local on  = api and api.isActive()
        btn.Text = def.label .. ": " .. (on and "ON" or "OFF")
        if on then
            btn.BackgroundColor3   = C_BTN_ON
            btn.TextColor3         = C_BTXT_ON
            btnStroke.Color        = C_BSTR_ON
            btnStroke.Transparency = 0.1
        else
            btn.BackgroundColor3   = C_BTN_OFF
            btn.TextColor3         = C_BTXT_OFF
            btnStroke.Color        = C_BSTR_OFF
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

-- ─── Controls tab: 8 toggles + upgrade qty selector ──────────────────────────
-- Row 0: Auto Purchase, Auto Upgrade
makeToggleBtn(controlsFrame, CTRL_DEFS[1], 8,   HALF_W, 6)
makeToggleBtn(controlsFrame, CTRL_DEFS[2], 150, HALF_W, 6)

-- Upgrade quantity selector row (y=36)
local UPG_OPTIONS = {
    {label = "1",   value = 1},
    {label = "5",   value = 5},
    {label = "10",  value = 10},
    {label = "25",  value = 25},
    {label = "100", value = 100},
}
local upgBtns = {}
local upgSelected = savedState.upgradeQty or 1

local function refreshUpgBtns()
    for _, info in ipairs(upgBtns) do
        local on = (info.value == upgSelected)
        info.btn.BackgroundColor3 = on and C_TAB_ON or C_TAB_OFF
        info.btn.TextColor3 = on and C_TXT_ON or C_TXT_OFF
        info.stroke.Color = on and C_BSTR_ON or C_DIV
        info.stroke.Transparency = on and 0.15 or 0.5
    end
end

for i, opt in ipairs(UPG_OPTIONS) do
    local bw = 53
    local bx = 8 + (i - 1) * 56
    if i == #UPG_OPTIONS then bw = W - 8 - bx end
    local btn = Instance.new("TextButton", controlsFrame)
    btn.Size = UDim2.new(0, bw, 0, 20)
    btn.Position = UDim2.new(0, bx, 0, 36)
    btn.BackgroundColor3 = C_TAB_OFF
    btn.TextColor3 = C_TXT_OFF
    btn.Text = opt.label
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local st = mkStroke(btn, C_DIV, 1, 0.5)
    table.insert(upgBtns, {btn = btn, value = opt.value, stroke = st})
    btn.MouseButton1Click:Connect(function()
        upgSelected = opt.value
        refreshUpgBtns()
        local api = _G.SL_AutoUpgrade
        if api then api.setCount(opt.value) end
        local state = loadState()
        state.upgradeQty = opt.value
        saveState(state)
    end)
    setTooltip(btn, "Upgrade " .. opt.label .. " level(s) per cycle")
end
refreshUpgBtns()
-- Apply saved count to feature
if _G.SL_AutoUpgrade then _G.SL_AutoUpgrade.setCount(upgSelected) end

-- Buildings multi-select dropdown (y=58)
local bldgDropBtn = Instance.new("TextButton", controlsFrame)
bldgDropBtn.Size = UDim2.new(0, W - 16, 0, 20)
bldgDropBtn.Position = UDim2.new(0, 8, 0, 58)
bldgDropBtn.BackgroundColor3 = C_TAB_OFF
bldgDropBtn.TextColor3 = C_TXT_OFF
bldgDropBtn.Text = "Buildings: " .. #ALL_BUILDINGS .. "/" .. #ALL_BUILDINGS .. " v"
bldgDropBtn.TextSize = 10
bldgDropBtn.Font = Enum.Font.GothamBold
bldgDropBtn.BorderSizePixel = 0
Instance.new("UICorner", bldgDropBtn).CornerRadius = UDim.new(0, 4)
mkStroke(bldgDropBtn, C_DIV, 1, 0.5)
setTooltip(bldgDropBtn, "Select which buildings to auto-upgrade")

local bldgDropdown = Instance.new("Frame", controlsFrame)
bldgDropdown.Size = UDim2.new(0, W - 16, 0, #ALL_BUILDINGS * 22 + 4)
bldgDropdown.Position = UDim2.new(0, 8, 0, 80)
bldgDropdown.BackgroundColor3 = Color3.fromRGB(12, 4, 24)
bldgDropdown.BorderSizePixel = 0
bldgDropdown.ZIndex = 10
bldgDropdown.Visible = false
Instance.new("UICorner", bldgDropdown).CornerRadius = UDim.new(0, 4)
mkStroke(bldgDropdown, C_STROKE, 1, 0.2)

local bldgRows = {}
local function refreshBldgBtn()
    local api = _G.SL_AutoUpgrade
    if not api then return end
    local buildings = api.getBuildings()
    local count = 0
    for _, name in ipairs(ALL_BUILDINGS) do
        if buildings[name] then count = count + 1 end
    end
    bldgDropBtn.Text = "Buildings: " .. count .. "/" .. #ALL_BUILDINGS .. " v"
end

for idx, name in ipairs(ALL_BUILDINGS) do
    local bldgRow = Instance.new("TextButton", bldgDropdown)
    bldgRow.Size = UDim2.new(1, -8, 0, 20)
    bldgRow.Position = UDim2.new(0, 4, 0, 2 + (idx - 1) * 22)
    bldgRow.BackgroundColor3 = C_TAB_ON
    bldgRow.TextColor3 = C_BTXT_ON
    bldgRow.Text = BUILDING_LABELS[name] or name
    bldgRow.TextSize = 10
    bldgRow.Font = Enum.Font.GothamBold
    bldgRow.BorderSizePixel = 0
    bldgRow.ZIndex = 11
    Instance.new("UICorner", bldgRow).CornerRadius = UDim.new(0, 3)
    bldgRows[name] = bldgRow

    bldgRow.MouseButton1Click:Connect(function()
        local api = _G.SL_AutoUpgrade
        if not api then return end
        local buildings = api.getBuildings()
        api.setBuilding(name, not buildings[name])
        local on = api.getBuildings()[name]
        bldgRow.BackgroundColor3 = on and C_TAB_ON or C_TAB_OFF
        bldgRow.TextColor3 = on and C_BTXT_ON or Color3.fromRGB(150, 120, 170)
        refreshBldgBtn()
        local state = loadState()
        state.buildings = {}
        for _, bn in ipairs(ALL_BUILDINGS) do
            state.buildings[bn] = api.getBuildings()[bn]
        end
        saveState(state)
    end)
end

bldgDropBtn.MouseButton1Click:Connect(function()
    bldgDropdown.Visible = not bldgDropdown.Visible
end)

-- Rows 1-3 shifted down for selector + buildings rows
for i = 3, #CTRL_DEFS do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local x = col == 0 and 8 or 150
    local y = 6 + row * 32 + 48
    makeToggleBtn(controlsFrame, CTRL_DEFS[i], x, HALF_W, y)
end

-- ─── Prestige tab: 3 toggles + status ────────────────────────────────────────
for i, def in ipairs(PRESTIGE_DEFS) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local x = col == 0 and 8 or 150
    local y = 6 + row * 32
    makeToggleBtn(prestigeFrame, def, x, HALF_W, y)
end

hLine(prestigeFrame, 72)

local function mkStatusLabel(parent, text, y)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(0, W - 16, 0, 18)
    lbl.Position = UDim2.new(0, 8, 0, y)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(215, 190, 255)
    lbl.TextSize   = 11
    lbl.Font       = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    return lbl
end

local lblRebirths  = mkStatusLabel(prestigeFrame, "Rebirths: --",  80)
local lblEvolution = mkStatusLabel(prestigeFrame, "Evolution: --", 100)
local lblAscension = mkStatusLabel(prestigeFrame, "Ascension: --", 120)

-- ─── State restoration ───────────────────────────────────────────────────────
for _, def in ipairs(CTRL_DEFS) do
    if savedState[def.key] then
        local api = def.getApi()
        if api then pcall(function() api.enable() end) end
    end
end
for _, def in ipairs(PRESTIGE_DEFS) do
    if savedState[def.key] then
        local api = def.getApi()
        if api then pcall(function() api.enable() end) end
    end
end
-- Restore building selections
if savedState.buildings and _G.SL_AutoUpgrade then
    for _, name in ipairs(ALL_BUILDINGS) do
        if savedState.buildings[name] ~= nil then
            _G.SL_AutoUpgrade.setBuilding(name, savedState.buildings[name])
        end
    end
    for name, row in pairs(bldgRows) do
        local api = _G.SL_AutoUpgrade
        local on = api and api.getBuildings()[name]
        row.BackgroundColor3 = on and C_TAB_ON or C_TAB_OFF
        row.TextColor3 = on and C_BTXT_ON or Color3.fromRGB(150, 120, 170)
    end
    refreshBldgBtn()
end
-- Refresh all buttons after state restore
for _, fn in ipairs(refreshFns) do pcall(fn) end

-- ─── Tab switching ────────────────────────────────────────────────────────────
local function showTab(name)
    if bldgDropdown then bldgDropdown.Visible = false end
    controlsFrame.Visible = (name == "controls")
    prestigeFrame.Visible = (name == "prestige")
    local function setTab(btn, on)
        btn.BackgroundColor3 = on and C_TAB_ON or C_TAB_OFF
        btn.TextColor3       = on and C_TXT_ON or C_TXT_OFF
    end
    setTab(tabControls, name == "controls")
    setTab(tabPrestige, name == "prestige")
    panel.Size = UDim2.new(0, W, 0, name == "controls" and PANEL_H_CONTROLS or PANEL_H_PRESTIGE)
end

tabControls.MouseButton1Click:Connect(function() showTab("controls") end)
tabPrestige.MouseButton1Click:Connect(function() showTab("prestige") end)
showTab("controls")

-- ─── Periodic refresh ─────────────────────────────────────────────────────────
task.spawn(function()
    while _G.SellLemonsMain do
        task.wait(1)
        for _, fn in ipairs(refreshFns) do pcall(fn) end
        pcall(function()
            lblRebirths.Text  = "Rebirths: "  .. tostring(getTycoonValue("Rebirths") or 0)
            lblEvolution.Text = "Evolution: " .. tostring(getTycoonValue("Evolution") or 0)
            lblAscension.Text = "Ascension: " .. tostring(getTycoonValue("Ascension") or 0)
        end)
    end
end)

print("[Sell Lemons] Loaded successfully.")
