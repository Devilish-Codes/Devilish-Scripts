-- Remote/Service Dumper | Paste directly into Delta
-- Skips Workspace to avoid clipboard overflow

local lines = {}

local function crawl(obj, depth, maxDepth)
	if depth > maxDepth then return end
	table.insert(lines, string.rep("  ", depth) .. obj.Name .. " [" .. obj.ClassName .. "]")
	local ok, children = pcall(function() return obj:GetChildren() end)
	if ok then
		for _, child in ipairs(children) do
			crawl(child, depth + 1, maxDepth)
		end
	end
end

local services = {
	"ReplicatedStorage",
	"ReplicatedFirst",
	"ServerScriptService",
	"StarterGui",
	"StarterPlayer",
	"Players",
	"SoundService",
	"MarketplaceService",
}

for _, name in ipairs(services) do
	local ok, svc = pcall(function() return game:GetService(name) end)
	if ok and svc then
		crawl(svc, 0, 10)
		table.insert(lines, "")
	end
end

local fullText = table.concat(lines, "\n")

setclipboard(fullText)

game:GetService("StarterGui"):SetCore("SendNotification", {
	Title = "Remote Dump",
	Text = #lines .. " lines copied to clipboard!",
	Duration = 5
})

print("[RemoteDump] " .. #lines .. " lines copied to clipboard.")
