-- Devilish Scripts — Universal Hub
-- Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/Devilish-Codes/Devilish-Scripts/main/hub.lua"))()

-- ── Config ───────────────────────────────────────────────────────────────────
-- PLACEHOLDER: Replace with your deployed Cloudflare Worker URL
local WORKER_URL = "https://devilish-keys.devilish-codes.workers.dev"
local KEY_PAGE   = "https://devilish-keys.devilish-codes.workers.dev/key"

local KEY_FILE = "devilish_key.json"

local GAMES = {
    [92416421522960]  = { name = "Slime RNG",    file = "slime_rng.lua" },
    [79268393072444]  = { name = "Sell Lemons",   file = "sell_lemons.lua" },
    [110947318876182] = { name = "Dropper RNG",   file = "dropper_rng.lua" },
}

-- ── Services ─────────────────────────────────────────────────────────────────
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TPS         = game:GetService("TeleportService")
local CoreGui     = game:GetService("CoreGui")
local PL          = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end
local userId      = tostring(PL.UserId)

-- ── Colors (match game script theme) ─────────────────────────────────────────
local C_BG     = Color3.fromRGB(8, 3, 18)
local C_BG2    = Color3.fromRGB(22, 6, 42)
local C_TITLE  = Color3.fromRGB(32, 10, 58)
local C_TITLE2 = Color3.fromRGB(14, 4, 28)
local C_STROKE = Color3.fromRGB(105, 32, 160)
local C_DIV    = Color3.fromRGB(75, 22, 115)
local C_BTN_ON = Color3.fromRGB(85, 15, 140)

-- ── Utility ──────────────────────────────────────────────────────────────────
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and res and #res > 0 then return res end
    return nil
end

local function httpPost(url, body)
    local ok, res = pcall(function()
        return HttpService:PostAsync(url, HttpService:JSONEncode(body), Enum.HttpContentType.ApplicationJson)
    end)
    if ok and res then
        local dok, data = pcall(function() return HttpService:JSONDecode(res) end)
        if dok then return data end
    end
    return nil
end

local function httpGetJson(url)
    local raw = httpGet(url)
    if not raw then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok then return data end
    return nil
end

local function readCache()
    local ok, raw = pcall(function() return readfile(KEY_FILE) end)
    if not ok or not raw then return nil end
    local dok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if dok then return data end
    return nil
end

local function writeCache(key, uid, expiresAt)
    pcall(function()
        writefile(KEY_FILE, HttpService:JSONEncode({ key = key, userId = tonumber(uid), expiresAt = expiresAt }))
    end)
end

local function clearCache()
    pcall(function() writefile(KEY_FILE, "{}") end)
end

local function validateKey(key, uid)
    return httpGetJson(WORKER_URL .. "/api/validate?key=" .. key .. "&userId=" .. uid)
end

-- ── GUI Helpers ──────────────────────────────────────────────────────────────
local W = 340

local function mkGrad(parent, c1, c2, rot)
    local g = Instance.new("UIGradient", parent)
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot
end

local function mkStroke(parent, color, thick, transp)
    local s = Instance.new("UIStroke", parent)
    s.Color = color
    s.Thickness = thick
    s.Transparency = transp or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

local function mkBtn(parent, text, yOff, color)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -32, 0, 32)
    btn.Position = UDim2.new(0, 16, 0, yOff)
    btn.BackgroundColor3 = color or C_BTN_ON
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = text
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    mkStroke(btn, C_DIV, 1, 0.25)
    return btn
end

local function mkLabel(parent, text, yOff, size, color, xAlign)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, -32, 0, 20)
    lbl.Position = UDim2.new(0, 16, 0, yOff)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color or Color3.fromRGB(180, 150, 220)
    lbl.Text = text
    lbl.TextSize = size or 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    return lbl
end

local function mkDivider(parent, yOff)
    local d = Instance.new("Frame", parent)
    d.Size = UDim2.new(1, -24, 0, 1)
    d.Position = UDim2.new(0, 12, 0, yOff)
    d.BackgroundColor3 = C_DIV
    d.BorderSizePixel = 0
    mkGrad(d, C_DIV, Color3.fromRGB(140, 18, 50), 0)
end

local function mkInput(parent, placeholder, yOff)
    local box = Instance.new("TextBox", parent)
    box.Size = UDim2.new(1, -32, 0, 32)
    box.Position = UDim2.new(0, 16, 0, yOff)
    box.BackgroundColor3 = Color3.fromRGB(13, 4, 32)
    box.TextColor3 = Color3.fromRGB(208, 176, 255)
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Color3.fromRGB(100, 70, 140)
    box.Text = ""
    box.TextSize = 14
    box.Font = Enum.Font.Code
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    mkStroke(box, Color3.fromRGB(74, 24, 120), 1, 0)
    return box
end

-- ── Copy to clipboard ────────────────────────────────────────────────────────
local function copyText(text)
    pcall(function() setclipboard(text) end)
end

-- ── Build Key Gate GUI ───────────────────────────────────────────────────────
local KEY_VALID = false
local currentKey = ""
local keyExpiresAt = 0

local function showKeyGate(onValidated)
    local gui = Instance.new("ScreenGui")
    gui.Name = "DevilishKeyGate"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Try gethui, fallback to PlayerGui
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then
        gui.Parent = hui
    else
        gui.Parent = PL.PlayerGui
    end

    local panel = Instance.new("Frame", gui)
    panel.Size = UDim2.new(0, W, 0, 420)
    panel.Position = UDim2.new(0.5, -math.floor(W / 2), 0.5, -210)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

    local bg = Instance.new("Frame", panel)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = C_BG
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)
    mkGrad(bg, C_BG, C_BG2, 120)
    mkStroke(bg, C_STROKE, 1.5, 0)

    -- Title bar
    local tBar = Instance.new("Frame", panel)
    tBar.Size = UDim2.new(1, 0, 0, 32)
    tBar.BackgroundColor3 = C_TITLE
    tBar.BorderSizePixel = 0
    Instance.new("UICorner", tBar).CornerRadius = UDim.new(0, 8)
    mkGrad(tBar, C_TITLE, C_TITLE2, 135)

    local tLbl = Instance.new("TextLabel", tBar)
    tLbl.Size = UDim2.new(1, -44, 1, 0)
    tLbl.Position = UDim2.new(0, 12, 0, 0)
    tLbl.BackgroundTransparency = 1
    tLbl.TextColor3 = Color3.new(1, 1, 1)
    tLbl.Text = "Devilish Scripts \u{2014} Key Required"
    tLbl.TextSize = 13
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left

    local xBtn = Instance.new("TextButton", tBar)
    xBtn.Size = UDim2.new(0, 28, 0, 24)
    xBtn.Position = UDim2.new(1, -32, 0, 4)
    xBtn.BackgroundColor3 = Color3.fromRGB(140, 18, 35)
    xBtn.TextColor3 = Color3.fromRGB(255, 155, 165)
    xBtn.Text = "X"
    xBtn.TextSize = 13
    xBtn.Font = Enum.Font.GothamBold
    xBtn.BorderSizePixel = 0
    Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 5)
    mkGrad(xBtn, Color3.fromRGB(160, 22, 45), Color3.fromRGB(95, 8, 75), 90)
    xBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- Draggable
    local dragging, dragStart, startPos
    tBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
        end
    end)
    tBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local y = 40

    -- Player ID row
    local idLbl = mkLabel(panel, "Your Player ID: " .. userId, y, 12, Color3.fromRGB(160, 130, 200))
    idLbl.Size = UDim2.new(1, -100, 0, 20)
    local copyIdBtn = Instance.new("TextButton", panel)
    copyIdBtn.Size = UDim2.new(0, 64, 0, 20)
    copyIdBtn.Position = UDim2.new(1, -80, 0, y)
    copyIdBtn.BackgroundColor3 = Color3.fromRGB(50, 15, 85)
    copyIdBtn.TextColor3 = Color3.fromRGB(200, 170, 240)
    copyIdBtn.Text = "Copy ID"
    copyIdBtn.TextSize = 11
    copyIdBtn.Font = Enum.Font.GothamBold
    copyIdBtn.BorderSizePixel = 0
    Instance.new("UICorner", copyIdBtn).CornerRadius = UDim.new(0, 4)
    copyIdBtn.MouseButton1Click:Connect(function() copyText(userId) end)
    y = y + 28

    -- Key input
    mkLabel(panel, "Enter Key:", y, 12)
    y = y + 18
    local keyInput = mkInput(panel, "DVLS-XXXX-XXXX-XXXX-XXXX", y)
    y = y + 40

    -- Validate button
    local validateBtn = mkBtn(panel, "Validate Key", y, Color3.fromRGB(20, 100, 50))
    y = y + 40

    -- Divider
    mkDivider(panel, y)
    y = y + 8

    -- Get Key button
    local getKeyBtn = mkBtn(panel, "Get Key (Copy Link)", y, Color3.fromRGB(85, 15, 140))
    y = y + 46

    -- Status + expiry
    local statusLbl = mkLabel(panel, "Waiting for key...", y, 12, Color3.fromRGB(160, 128, 192), Enum.TextXAlignment.Center)
    y = y + 18
    local expiryLbl = mkLabel(panel, "Key Expires: --:--:--", y, 11, Color3.fromRGB(112, 96, 160), Enum.TextXAlignment.Center)
    y = y + 24

    panel.Size = UDim2.new(0, W, 0, y)
    panel.Position = UDim2.new(0.5, -math.floor(W / 2), 0.5, -math.floor(y / 2))

    -- ── Button Logic ─────────────────────────────────────────────────────────
    local function setStatus(msg, color)
        statusLbl.Text = msg
        statusLbl.TextColor3 = color or Color3.fromRGB(160, 128, 192)
    end

    local function updateExpiry(ts)
        if ts and ts > 0 then
            local rem = ts - os.time()
            if rem > 0 then
                local h = math.floor(rem / 3600)
                local m = math.floor((rem % 3600) / 60)
                local s = rem % 60
                expiryLbl.Text = string.format("Key Expires: %02d:%02d:%02d", h, m, s)
            else
                expiryLbl.Text = "Key Expired"
            end
        end
    end

    local function tryValidate(key)
        if not key or #key < 10 then
            setStatus("Invalid key format.", Color3.fromRGB(210, 80, 80))
            return
        end
        setStatus("Validating...", Color3.fromRGB(210, 210, 80))
        local result = validateKey(key, userId)
        if not result then
            -- Worker unreachable, check cache
            local cache = readCache()
            if cache and cache.key == key and cache.userId == tonumber(userId) and cache.expiresAt and os.time() < cache.expiresAt then
                setStatus("Offline: Using cached key", Color3.fromRGB(210, 180, 80))
                currentKey = key
                keyExpiresAt = cache.expiresAt
                KEY_VALID = true
                updateExpiry(keyExpiresAt)
                task.wait(1)
                gui:Destroy()
                onValidated()
                return
            end
            setStatus("Could not reach server. Try again.", Color3.fromRGB(210, 80, 80))
            return
        end
        if result.valid then
            currentKey = key
            keyExpiresAt = result.expiresAt
            KEY_VALID = true
            writeCache(key, userId, result.expiresAt)
            setStatus("Key valid!", Color3.fromRGB(80, 210, 80))
            updateExpiry(keyExpiresAt)
            task.wait(1)
            gui:Destroy()
            onValidated()
        else
            local err = result.error or "unknown"
            if err == "invalid_key" then
                setStatus("Invalid key.", Color3.fromRGB(210, 80, 80))
            elseif err == "expired" then
                setStatus("Key expired. Get a new one.", Color3.fromRGB(210, 80, 80))
            elseif err == "wrong_user" then
                setStatus("This key belongs to another player.", Color3.fromRGB(210, 80, 80))
            else
                setStatus("Error: " .. err, Color3.fromRGB(210, 80, 80))
            end
            clearCache()
        end
    end

    validateBtn.MouseButton1Click:Connect(function()
        tryValidate(keyInput.Text:match("^%s*(.-)%s*$"))
    end)

    getKeyBtn.MouseButton1Click:Connect(function()
        local link = KEY_PAGE .. "?userId=" .. userId
        copyText(link)
        setStatus("Link copied! Open in browser to get key.", Color3.fromRGB(80, 210, 80))
    end)

    -- Expiry timer
    task.spawn(function()
        while gui.Parent do
            updateExpiry(keyExpiresAt)
            task.wait(1)
        end
    end)
end

-- ── Unsupported Game GUI ─────────────────────────────────────────────────────
local function showUnsupported()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DevilishUnsupported"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true

    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then
        gui.Parent = hui
    else
        gui.Parent = PL.PlayerGui
    end

    local h = 160
    local panel = Instance.new("Frame", gui)
    panel.Size = UDim2.new(0, W, 0, h)
    panel.Position = UDim2.new(0.5, -math.floor(W / 2), 0.5, -math.floor(h / 2))
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

    local bg = Instance.new("Frame", panel)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = C_BG
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)
    mkGrad(bg, C_BG, C_BG2, 120)
    mkStroke(bg, C_STROKE, 1.5, 0)

    -- Title
    local tBar = Instance.new("Frame", panel)
    tBar.Size = UDim2.new(1, 0, 0, 32)
    tBar.BackgroundColor3 = C_TITLE
    tBar.BorderSizePixel = 0
    Instance.new("UICorner", tBar).CornerRadius = UDim.new(0, 8)
    mkGrad(tBar, C_TITLE, C_TITLE2, 135)

    local tLbl = Instance.new("TextLabel", tBar)
    tLbl.Size = UDim2.new(1, -24, 1, 0)
    tLbl.Position = UDim2.new(0, 12, 0, 0)
    tLbl.BackgroundTransparency = 1
    tLbl.TextColor3 = Color3.new(1, 1, 1)
    tLbl.Text = "Devilish Scripts"
    tLbl.TextSize = 13
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left

    local y = 40
    mkLabel(panel, "This game is not currently supported.", y, 12, Color3.fromRGB(210, 150, 150), Enum.TextXAlignment.Center)
    y = y + 24
    mkLabel(panel, "Supported Games:", y, 11, Color3.fromRGB(140, 110, 180))
    y = y + 18
    for _, info in pairs(GAMES) do
        mkLabel(panel, "  \u{2022} " .. info.name, y, 11, Color3.fromRGB(180, 160, 220))
        y = y + 16
    end
    y = y + 8

    local closeBtn = mkBtn(panel, "Close", y, Color3.fromRGB(140, 18, 35))
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
    y = y + 40

    panel.Size = UDim2.new(0, W, 0, y)
    panel.Position = UDim2.new(0.5, -math.floor(W / 2), 0.5, -math.floor(y / 2))
end

-- ── Periodic Re-validation ───────────────────────────────────────────────────
local function startRevalidation()
    task.spawn(function()
        while KEY_VALID do
            local remaining = keyExpiresAt == 0 and 999999 or (keyExpiresAt - os.time())
            local interval = 60
            task.wait(interval)
            local result = validateKey(currentKey, userId)
            if result and result.valid then
                keyExpiresAt = result.expiresAt
                if _G._devilishKey then
                    _G._devilishKey.expiresAt = keyExpiresAt
                end
                writeCache(currentKey, userId, keyExpiresAt)
            elseif result and not result.valid then
                pcall(function() TPS:Teleport(game.PlaceId, PL) end)
                break
            end
            -- If result is nil (network error), do nothing, trust cache
        end
    end)
end

-- ── Expiry Enforcement ───────────────────────────────────────────────────────
local function startExpiryWatch()
    task.spawn(function()
        while KEY_VALID do
            if keyExpiresAt ~= 0 and os.time() >= keyExpiresAt then
                pcall(function() TPS:Teleport(game.PlaceId, PL) end)
                break
            end
            task.wait(1)
        end
    end)
end

-- ── Load Game Script ─────────────────────────────────────────────────────────
local function loadGame(info)
    _G._devilishKey = {
        key = currentKey,
        expiresAt = keyExpiresAt,
        userId = userId,
        workerUrl = WORKER_URL,
        keyPage = KEY_PAGE,
    }

    startRevalidation()
    startExpiryWatch()

    local url = WORKER_URL .. "/api/script?key=" .. currentKey .. "&userId=" .. userId .. "&game=" .. tostring(game.PlaceId)
    local src = httpGet(url)
    if src then
        local fn, err = loadstring(src)
        if fn then
            fn()
        else
            print("[DevilishHub] Failed to compile " .. info.file .. ": " .. tostring(err))
        end
    else
        print("[DevilishHub] Failed to download " .. info.file)
    end
end

-- ── Main ─────────────────────────────────────────────────────────────────────
local function main()
    local function onKeyValid()
        local placeId = game.PlaceId
        local info = GAMES[placeId]
        if info then
            loadGame(info)
        else
            showUnsupported()
        end
    end

    -- Try cached key first
    local cache = readCache()
    if cache and cache.key and cache.userId == tonumber(userId) and cache.expiresAt then
        local result = validateKey(cache.key, userId)
        if result and result.valid then
            currentKey = cache.key
            keyExpiresAt = result.expiresAt
            KEY_VALID = true
            writeCache(currentKey, userId, keyExpiresAt)
            onKeyValid()
            return
        elseif not result and os.time() < cache.expiresAt then
            -- Worker unreachable, trust cache
            currentKey = cache.key
            keyExpiresAt = cache.expiresAt
            KEY_VALID = true
            onKeyValid()
            return
        else
            clearCache()
        end
    end

    -- No valid cache — show key gate
    showKeyGate(onKeyValid)
end

main()
