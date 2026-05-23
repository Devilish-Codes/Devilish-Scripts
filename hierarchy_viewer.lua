-- Hierarchy Viewer | Delta Executor compatible

local MAX_DEPTH = 20
local MAX_NODES = 5000

local lines = {}
local nodeCount = 0

local function crawl(obj, depth)
	if depth > MAX_DEPTH or nodeCount >= MAX_NODES then return end
	nodeCount = nodeCount + 1
	table.insert(lines, string.rep("  ", depth) .. obj.Name .. " [" .. obj.ClassName .. "]")
	local ok, children = pcall(function() return obj:GetChildren() end)
	if ok then
		for _, child in ipairs(children) do
			crawl(child, depth + 1)
		end
	end
end

crawl(game, 0)

if nodeCount >= MAX_NODES then
	table.insert(lines, "... (truncated at " .. MAX_NODES .. " nodes)")
end

local fullText = table.concat(lines, "\n")

-- ── GUI parent: use gethui() if available, else CoreGui ──────────────────────
local guiParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")

local old = guiParent:FindFirstChild("HierarchyViewer")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "HierarchyViewer"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = guiParent

local win = Instance.new("Frame")
win.Name             = "Window"
win.Size             = UDim2.new(0, 640, 0, 520)
win.Position         = UDim2.new(0.5, -320, 0.5, -260)
win.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
win.BorderSizePixel  = 0
win.Parent           = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = win

-- Title bar
local bar = Instance.new("Frame")
bar.Size             = UDim2.new(1, 0, 0, 32)
bar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
bar.BorderSizePixel  = 0
bar.Parent           = win

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 6)
barCorner.Parent = bar

-- patch so bar corners don't show through the window body
local barPatch = Instance.new("Frame")
barPatch.Size             = UDim2.new(1, 0, 0, 6)
barPatch.Position         = UDim2.new(0, 0, 1, -6)
barPatch.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
barPatch.BorderSizePixel  = 0
barPatch.Parent           = bar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(1, -140, 1, 0)
titleLbl.Position               = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "Game Hierarchy  (" .. nodeCount .. " nodes)"
titleLbl.TextColor3             = Color3.fromRGB(220, 220, 220)
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextSize               = 13
titleLbl.Parent                 = bar

local copyBtn = Instance.new("TextButton")
copyBtn.Size             = UDim2.new(0, 70, 0, 22)
copyBtn.Position         = UDim2.new(1, -120, 0.5, -11)
copyBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 204)
copyBtn.BorderSizePixel  = 0
copyBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
copyBtn.Text             = "Copy"
copyBtn.Font             = Enum.Font.GothamBold
copyBtn.TextSize         = 13
copyBtn.Parent           = bar

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 4)
copyCorner.Parent = copyBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 26, 0, 22)
closeBtn.Position         = UDim2.new(1, -36, 0.5, -11)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel  = 0
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.Text             = "x"
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 13
closeBtn.Parent           = bar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeBtn

-- Scroll area
local scroll = Instance.new("ScrollingFrame")
scroll.Size                = UDim2.new(1, -8, 1, -40)
scroll.Position            = UDim2.new(0, 4, 0, 36)
scroll.BackgroundColor3    = Color3.fromRGB(18, 18, 18)
scroll.BorderSizePixel     = 0
scroll.ScrollBarThickness  = 5
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
scroll.Parent              = win

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 4)
scrollCorner.Parent = scroll

local textBox = Instance.new("TextBox")
textBox.Size                   = UDim2.new(1, -8, 0, 0)
textBox.Position               = UDim2.new(0, 4, 0, 4)
textBox.BackgroundTransparency = 1
textBox.TextColor3             = Color3.fromRGB(190, 220, 190)
textBox.Text                   = fullText
textBox.Font                   = Enum.Font.Code
textBox.TextSize               = 12
textBox.TextXAlignment         = Enum.TextXAlignment.Left
textBox.TextYAlignment         = Enum.TextYAlignment.Top
textBox.MultiLine              = true
textBox.ClearTextOnFocus       = false
textBox.TextEditable           = false
textBox.AutomaticSize          = Enum.AutomaticSize.Y
textBox.Parent                 = scroll

-- ── Drag ─────────────────────────────────────────────────────────────────────
local dragging, dragStart, startPos

local UIS = game:GetService("UserInputService")

bar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging  = true
		dragStart = input.Position
		startPos  = win.Position
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		win.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

-- ── Buttons ───────────────────────────────────────────────────────────────────
copyBtn.MouseButton1Click:Connect(function()
	setclipboard(fullText)
	copyBtn.Text = "Copied!"
	task.delay(1.5, function()
		copyBtn.Text = "Copy"
	end)
end)

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)
