-- Remote Spy | Delta Executor
-- Prints ALL remote calls to Delta's console in real time
-- No clipboard, no GUI — just watch the console while you play

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
        warn("[Fire] " .. self.Name .. "(" .. table.concat(parts, ", ") .. ")")

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
        warn("[Invoke] " .. self.Name .. "(" .. table.concat(parts, ", ") .. ")")
    end

    return oldNamecall(self, ...)
end

setreadonly(mt, true)

warn("[RemoteSpy] Active — watch this console while you play.")
