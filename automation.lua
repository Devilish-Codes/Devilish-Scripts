-- Immortality Incremental | Automation Script
-- Paste directly into Delta

-- ── CONFIG ────────────────────────────────────────────────────────────────────
local AUTO_QI       = true   -- Auto gain Qi
local AUTO_MARKS    = true   -- Auto press all mark boards
local AUTO_REALM    = true   -- Auto advance realm
local AUTO_UPGRADE  = true   -- Auto click upgrade buttons on all boards
local AUTO_BEAST    = true   -- Auto fight beast

local QI_INTERVAL      = 0.05  -- seconds between Qi fires
local MARK_INTERVAL    = 0.3   -- seconds between each mark press cycle
local UPGRADE_INTERVAL = 0.5   -- seconds between upgrade click cycles
local BEAST_INTERVAL   = 0.5   -- seconds between beast attacks
-- ──────────────────────────────────────────────────────────────────────────────

local RS      = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("RemoteEvents", 10)
if not remotes then
    warn("[Auto] RemoteEvents folder not found — are you in the right game?")
    return
end

local function fire(name, ...)
    local r = remotes:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then
        r:FireServer(...)
        return true
    end
    return false
end

local MARK_EVENTS = {
    "InsightMarkPress",
    "EssenceMarkPress",
    "SoulfireMarkPress",
    "KarmaMarkPress",
    "NebulaMarkPress",
    "QuasarMarkPress",
    "MiasmaMarkPress",
    "AshMarkPress",
    "StarsMarkPress",
    "RealmPress",
}

local UPGRADE_BUTTON_NAMES = {
    "MaxPurchaseButton",
    "PurchaseButton1",
    "PurchaseButton2",
    "PurchaseButton3",
    "PurchaseButton4",
    "PurchaseButton5",
    "PurchaseButton6",
    "SinglePurchaseButton",
    "UpgradeButton",
}

-- ── Auto Qi ───────────────────────────────────────────────────────────────────
if AUTO_QI then
    task.spawn(function()
        while task.wait(QI_INTERVAL) do
            fire("GainQi")
        end
    end)
    print("[Auto] Qi: ON")
end

-- ── Auto Marks ────────────────────────────────────────────────────────────────
if AUTO_MARKS then
    task.spawn(function()
        while true do
            for _, name in ipairs(MARK_EVENTS) do
                fire(name)
                task.wait(0.05)
            end
            task.wait(MARK_INTERVAL)
        end
    end)
    print("[Auto] Marks: ON")
end

-- ── Auto Realm ────────────────────────────────────────────────────────────────
if AUTO_REALM then
    task.spawn(function()
        while task.wait(MARK_INTERVAL) do
            fire("RealmPress")
        end
    end)
    print("[Auto] Realm: ON")
end

-- ── Auto Upgrade ──────────────────────────────────────────────────────────────
if AUTO_UPGRADE then
    task.spawn(function()
        while true do
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("TextButton") then
                    for _, bname in ipairs(UPGRADE_BUTTON_NAMES) do
                        if obj.Name == bname then
                            pcall(function()
                                if firesignal then
                                    firesignal(obj.MouseButton1Click)
                                else
                                    obj.MouseButton1Click:Fire()
                                end
                            end)
                            break
                        end
                    end
                end
            end
            task.wait(UPGRADE_INTERVAL)
        end
    end)
    print("[Auto] Upgrades: ON")
end

-- ── Auto Beast ────────────────────────────────────────────────────────────────
if AUTO_BEAST then
    task.spawn(function()
        while task.wait(BEAST_INTERVAL) do
            -- Find beast stage from the BeastStageGui label
            local stageNum = nil
            local bsg = workspace:FindFirstChild("BeastStageGui", true)
            if bsg then
                for _, v in ipairs(bsg:GetDescendants()) do
                    if v:IsA("TextLabel") then
                        local n = tonumber(v.Text:match("(%d+)"))
                        if n and n > 0 then
                            stageNum = n
                            break
                        end
                    end
                end
            end

            -- Also try clicking any beast attack buttons in workspace
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("TextButton") and (
                    obj.Name:lower():find("attack") or
                    obj.Name:lower():find("fight") or
                    obj.Name:lower():find("beast") or
                    obj.Name:lower():find("hunt")
                ) then
                    pcall(function()
                        if firesignal then
                            firesignal(obj.MouseButton1Click)
                        else
                            obj.MouseButton1Click:Fire()
                        end
                    end)
                end
            end

            if stageNum then
                fire("SetBeastStage", stageNum)
            else
                -- Try firing with no args as fallback
                fire("SetBeastStage")
            end
        end
    end)
    print("[Auto] Beast: ON")
end

print("[Auto] Automation running. Set AUTO_X = false at the top to disable modules.")
