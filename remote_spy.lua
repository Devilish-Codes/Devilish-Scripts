-- Remote Spy | Delta Executor
-- Hooks ALL remote calls via metatable (works in Delta)
-- Press F8 in-game to copy the log to clipboard

local log = {}

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = function(self, ...)
    local method = getnamecallmethod()

    if method == "FireServer" and self:IsA("RemoteEvent") then
        local args = {...}
        local parts = {}
        for _, v in ipairs(args) do
            local t = typeof(v)
            if t == "string" or t == "number" or t == "boolean" then
                table.insert(parts, tostring(v))
            else
                table.insert(parts, "[" .. t .. "]")
            end
        end
        local line = "[FireServer] " .. self.Name .. "(" .. table.concat(parts, ", ") .. ")"
        table.insert(log, line)
        print(line)

    elseif method == "InvokeServer" and self:IsA("RemoteFunction") then
        local args = {...}
        local parts = {}
        for _, v in ipairs(args) do
            local t = typeof(v)
            if t == "string" or t == "number" or t == "boolean" then
                table.insert(parts, tostring(v))
            else
                table.insert(parts, "[" .. t .. "]")
            end
        end
        local line = "[InvokeServer] " .. self.Name .. "(" .. table.concat(parts, ", ") .. ")"
        table.insert(log, line)
        print(line)
    end

    return oldNamecall(self, ...)
end

setreadonly(mt, true)

print("[RemoteSpy] Active. Play normally, then press F8 to copy the log.")

game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.F8 then
        if #log == 0 then
            print("[RemoteSpy] No calls captured yet.")
        else
            setclipboard(table.concat(log, "\n"))
            print("[RemoteSpy] Copied " .. #log .. " calls to clipboard.")
        end
    end
end)
