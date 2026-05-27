local TYPES = { Script = true, LocalScript = true, ModuleScript = true }
local BASE = "decompiled/"
local RS = game:GetService("ReplicatedStorage")
local SOURCE_ROOT = RS:FindFirstChild("Source")

local function sanitize(s)
    return s:gsub('[\\/:*?"<>|]', "_")
end

local function getRelPath(obj)
    local path = ""
    local cur = obj
    while cur and cur ~= game do
        path = path == "" and sanitize(cur.Name) or sanitize(cur.Name) .. "/" .. path
        cur = cur.Parent
    end
    return path
end

local function isGameScript(obj)
    local cur = obj.Parent
    while cur do
        if cur == SOURCE_ROOT then return true end
        cur = cur.Parent
    end
    return false
end

if not SOURCE_ROOT then
    print("[Decompile] RS.Source not found!")
    return
end

local scripts = {}
local count = 0
for _, obj in ipairs(SOURCE_ROOT:GetDescendants()) do
    if TYPES[obj.ClassName] then
        count = count + 1
        scripts[count] = obj
    end
end
print(string.format("[Decompile] Found %d game scripts. Starting...", count))

pcall(makefolder, BASE)

local done, failed = 0, 0

for i = 1, count do
    local obj = scripts[i]
    local relPath = getRelPath(obj)
    local filePath = BASE .. relPath .. ".lua"

    local folderPath = BASE
    for part in relPath:gmatch("([^/]+)/") do
        folderPath = folderPath .. part .. "/"
        pcall(makefolder, folderPath)
    end

    local ok, src = pcall(decompile, obj)
    if ok and type(src) == "string" and src ~= "" then
        local wok = pcall(writefile, filePath, src)
        if wok then done = done + 1 else failed = failed + 1 end
    else
        failed = failed + 1
    end

    if i % 10 == 0 then
        task.wait()
        print(string.format("[Decompile] %d / %d...", i, count))
    end
end

print(string.format("[Decompile] Complete. %d saved, %d failed/empty.", done, failed))
