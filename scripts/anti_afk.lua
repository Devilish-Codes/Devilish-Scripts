local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local PL      = Players.LocalPlayer

-- Disable AutoRejoin module loop
pcall(function()
    local m = require(RS.Source.Features.AutoRejoin.AutoRejoinServiceClient)
    m.disable()
end)

-- Disconnect all handlers on the Idled event (prevents native idle kick)
pcall(function()
    for _, connection in pairs(getconnections(PL.Idled)) do
        if connection["Disable"] then
            connection["Disable"](connection)
        elseif connection["Disconnect"] then
            connection["Disconnect"](connection)
        end
    end
end)

