-- Config Dumper | Paste directly into Delta
-- Requires game modules at runtime to extract upgrade IDs, beast stages, etc.

local RS = game:GetService("ReplicatedStorage")
local Modules = RS:FindFirstChild("Modules")
local lines = {}

local function dump(val, depth, key)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    local t = typeof(val)

    if t == "table" then
        table.insert(lines, indent .. (key and (key .. " = ") or "") .. "{")
        for k, v in pairs(val) do
            dump(v, depth + 1, tostring(k))
        end
        table.insert(lines, indent .. "}")
    elseif t == "string" or t == "number" or t == "boolean" then
        table.insert(lines, indent .. (key and (key .. " = ") or "") .. tostring(val))
    else
        table.insert(lines, indent .. (key and (key .. " = ") or "") .. "[" .. t .. "]")
    end
end

local targets = {
    "UpgradeBoardModel",
    "BeastHuntConfig",
    "BeastUpgradeConfig",
    "BeastStageBoardModel",
    "InsightUpgradeConfig",
    "EssenceUpgradeConfig",
    "SoulUpgradeConfig",
    "RealmConfig",
    "RunUpgradeRules",
}

for _, name in ipairs(targets) do
    local mod = Modules and Modules:FindFirstChild(name)
    if mod then
        local ok, result = pcall(require, mod)
        if ok then
            table.insert(lines, "=== " .. name .. " ===")
            dump(result, 0)
            table.insert(lines, "")
        else
            table.insert(lines, "=== " .. name .. " === ERROR: " .. tostring(result))
        end
    else
        table.insert(lines, "=== " .. name .. " === NOT FOUND")
    end
end

local fullText = table.concat(lines, "\n")
setclipboard(fullText)
print("[ConfigDump] Done — " .. #lines .. " lines copied to clipboard.")
