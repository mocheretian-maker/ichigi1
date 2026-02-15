local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local VioletUI = {}
VioletUI.__index = VioletUI

local DefaultTheme = {
	Background  = Color3.fromRGB(12, 10, 18),
	Background2 = Color3.fromRGB(18, 15, 28),
	Surface     = Color3.fromRGB(22, 19, 35),
	Surface2    = Color3.fromRGB(28, 24, 45),
	Stroke      = Color3.fromRGB(55, 48, 86),

	Text        = Color3.fromRGB(235, 235, 240),
	MutedText   = Color3.fromRGB(170, 170, 185),

	Accent      = Color3.fromRGB(166, 66, 255),
	Accent2     = Color3.fromRGB(120, 45, 200),

	Danger      = Color3.fromRGB(255, 80, 90),
}

local function ShallowClone(t)
	local n = {}
	for k, v in pairs(t) do
		n[k] = v
	end
	return n
end

local function Create(className, props, children)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	return inst
end

local function Tween(obj, time_, props, style, dir)
	local info = TweenInfo.new(time_, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function Clamp(n, a, b)
	if n < a then return a end
	if n > b then return b end
	return n
end

local function Round(n, step)
	step = step > 0 and step or 1
	return math.floor((n / step) + 0.5) * step
end

local function EnableDrag(dragHandle, target)
	local dragging = false
	local dragStart
	local startPos

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if dragStart and startPos then
				local delta = input.Position - dragStart
				target.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

local Window = {}
Window.__index = Window

function Window:_BindTheme(inst, prop, themeKey)
	self._themeBindings[#self._themeBindings + 1] = {i = inst, p = prop, k = themeKey}
	inst[prop] = self.Theme[themeKey]
end

function Window:SetTheme(patch)
	for k, v in pairs(patch) do
		self.Theme[k] = v
	end
	for _, b in ipairs(self._themeBindings) do
		if b.i and b.i.Parent then
			b.i[b.p] = self.Theme[b.k]
		end
	end
end

function Window:_SetFlag(flagName, value)
	if not flagName or flagName == "" then return end
	self.Flags[flagName] = value
end

function Window:Toggle()
	self.Open = not self.Open
	self.ScreenGui.Enabled = self.Open
end

function Window:Destroy()
	for _, c in ipairs(self._connections) do
		pcall(function() c:Disconnect() end)
	end
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

function Window:ExportConfig()
	local out = {}
	for k, v in pairs(self.Flags) do
		if typeof(v) == "Color3" then
			out[k] = {
				__type = "Color3",
				r = math.floor(v.R * 255 + 0.5),
				g = math.floor(v.G * 255 + 0.5),
				b = math.floor(v.B * 255 + 0.5),
			}
		else
			out[k] = v
		end
	end
	return HttpService:JSONEncode(out)
end

function Window:ImportConfig(jsonOrTable, opts)
	opts = opts or {}
	local fire = true
	if opts.FireCallbacks == false then
		fire = false
	end

	local data
	if type(jsonOrTable) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(jsonOrTable)
		end)
		if not ok then
			return false
		end
		data = decoded
	elseif type(jsonOrTable) == "table" then
		data = jsonOrTable
	else
		return false
	end

	for flag, val in pairs(data) do
		local setter = self._flagSetters[flag]
		if setter then
			setter(val, not fire)
		else
			self.Flags[flag] = val
		end
	end
	return true
end

function Window:SaveConfig(name)
	if not name or name == "" then return false end
	self.Configs[name] = self:ExportConfig()
	return true
end

function Window:LoadConfig(name, opts)
	if not name or name == "" then return false end
	local json = self.Configs[name]
	if not json then return false end
	return self:ImportConfig(json, opts)
end

function Window:Notify(opts)
	opts = opts or {}
	local title = tostring(opts.Title or "Notification")
	local content = tostring(opts.Content or "")
	local time_ = tonumber(opts.Time) or 3

	local item = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 14)}),
		Create("UIStroke", {Thickness = 1, Color = self.Theme.Stroke}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
		Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	self:_BindTheme(item, "BackgroundColor3", "Surface")
	self:_BindTheme(item:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

	local t = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		TextTransparency = 1,
	})
	t.Parent = item
	self:_BindTheme(t, "TextColor3", "Text")

	local c = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = content,
		TextTransparency = 1,
	})
	c.Parent = item
	self:_BindTheme(c, "TextColor3", "MutedText")

	item.Parent = self.Notifications

	Tween(item, 0.16, {BackgroundTransparency = 0})
	Tween(t, 0.16, {TextTransparency = 0})
	Tween(c, 0.16, {TextTransparency = 0})

	task.delay(time_, function()
		if not item or not item.Parent then return end
		Tween(item, 0.16, {BackgroundTransparency = 1})
		Tween(t, 0.16, {TextTransparency = 1})
		Tween(c, 0.16, {TextTransparency = 1})
		task.delay(0.18, function()
			if item and item.Parent then
				item:Destroy()
			end
		end)
	end)

	return item
end

function Window:Prompt(opts)
	opts = opts or {}
	local title = tostring(opts.Title or "Prompt")
	local content = tostring(opts.Content or "")
	local buttons = opts.Buttons
	if type(buttons) ~= "table" or #buttons == 0 then
		buttons = {
			{Text = "OK", Primary = true, Callback = function() end}
		}
	end

	if self._modalOverlay and self._modalOverlay.Parent then
		self._modalOverlay:Destroy()
	end

	local overlay = Create("Frame", {
		Name = "ModalOverlay",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
	}, nil)
	overlay.Parent = self.ScreenGui
	self._modalOverlay = overlay

	local block = Create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 1, 0),
	}, nil)
	block.Parent = overlay

	local panel = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(420, 220),
		BackgroundColor3 = self.Theme.Background2,
		BorderSizePixel = 0,
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 14)}),
		Create("UIStroke", {Thickness = 1, Color = self.Theme.Stroke}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
		}),
	})
	panel.Parent = overlay
	self:_BindTheme(panel, "BackgroundColor3", "Background2")
	self:_BindTheme(panel:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

	local titleLbl = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamSemibold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	}, nil)
	titleLbl.Parent = panel
	self:_BindTheme(titleLbl, "TextColor3", "Text")

	local contentLbl = Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 28),
		Size = UDim2.new(1, 0, 1, -86),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = content,
	}, nil)
	contentLbl.Parent = panel
	self:_BindTheme(contentLbl, "TextColor3", "MutedText")

	local btnRow = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 44),
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	})
	btnRow.Parent = panel

	local function Close()
		if not overlay or not overlay.Parent then return end
		Tween(overlay, 0.15, {BackgroundTransparency = 1})
		Tween(panel, 0.15, {Position = UDim2.new(0.5, 0, 0.5, 12)})
		task.delay(0.16, function()
			if overlay and overlay.Parent then
				overlay:Destroy()
			end
		end)
	end

	for i, b in ipairs(buttons) do
		local txt = tostring(b.Text or ("Button" .. i))
		local primary = (b.Primary == true)
		local cb = b.Callback or function() end

		local btn = Create("TextButton", {
			Size = UDim2.fromOffset(110, 34),
			BackgroundColor3 = primary and self.Theme.Accent2 or self.Theme.Surface,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
		}, {
			Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
			Create("UIStroke", {Thickness = 1, Color = self.Theme.Stroke}),
		})
		btn.Parent = btnRow

		if primary then
			self:_BindTheme(btn, "BackgroundColor3", "Accent2")
		else
			self:_BindTheme(btn, "BackgroundColor3", "Surface")
		end
		self:_BindTheme(btn:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

		local lbl = Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Font = Enum.Font.GothamSemibold,
			TextSize = 13,
			Text = txt,
		}, nil)
		lbl.Parent = btn
		self:_BindTheme(lbl, "TextColor3", "Text")

		btn.MouseEnter:Connect(function()
			if primary then
				Tween(btn, 0.12, {BackgroundColor3 = self.Theme.Accent})
			else
				Tween(btn, 0.12, {BackgroundColor3 = self.Theme.Surface2})
			end
		end)
		btn.MouseLeave:Connect(function()
			if primary then
				Tween(btn, 0.12, {BackgroundColor3 = self.Theme.Accent2})
			else
				Tween(btn, 0.12, {BackgroundColor3 = self.Theme.Surface})
			end
		end)

		btn.MouseButton1Click:Connect(function()
			pcall(cb)
			Close()
		end)
	end

	Tween(overlay, 0.16, {BackgroundTransparency = 0.35})
	panel.Position = UDim2.new(0.5, 0, 0.5, 12)
	Tween(panel, 0.16, {Position = UDim2.new(0.5, 0, 0.5, 0)})

	return {
		Close = Close,
		Overlay = overlay,
		Panel = panel,
	}
end

function Window:PromptExportConfig(opts)
	opts = opts or {}
	local json = self:ExportConfig()

	local overlay = self:Prompt({
		Title = tostring(opts.Title or "Export Config"),
		Content = tostring(opts.Content or "Скопируй JSON ниже:"),
		Buttons = {
			{Text = "Close", Primary = true, Callback = function() end}
		}
	})

	local panel = overlay.Panel
	local box = Create("TextBox", {
		Position = UDim2.new(0, 0, 0, 110),
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Code,
		TextSize = 11,
		Text = json,
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		Create("UIStroke", {Thickness = 1, Color = self.Theme.Stroke}),
	})
	box.Parent = panel
	self:_BindTheme(box, "BackgroundColor3", "Surface")
	self:_BindTheme(box, "TextColor3", "Text")
	self:_BindTheme(box:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

	return overlay
end

function Window:PromptImportConfig(opts)
	opts = opts or {}
	local overlay
	local inputBox

	overlay = self:Prompt({
		Title = tostring(opts.Title or "Import Config"),
		Content = tostring(opts.Content or "Вставь JSON ниже и нажми Load."),
		Buttons = {
			{
				Text = "Load",
				Primary = true,
				Callback = function()
					if inputBox then
						self:ImportConfig(inputBox.Text, {FireCallbacks = (opts.FireCallbacks ~= false)})
					end
				end
			},
			{Text = "Cancel", Primary = false, Callback = function() end}
		}
	})

	local panel = overlay.Panel
	inputBox = Create("TextBox", {
		Position = UDim2.new(0, 0, 0, 110),
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Code,
		TextSize = 11,
		Text = "",
		PlaceholderText = "JSON ...",
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		Create("UIStroke", {Thickness = 1, Color = self.Theme.Stroke}),
	})
	inputBox.Parent = panel
	self:_BindTheme(inputBox, "BackgroundColor3", "Surface")
	self:_BindTheme(inputBox, "TextColor3", "Text")
	self:_BindTheme(inputBox, "PlaceholderColor3", "MutedText")
	self:_BindTheme(inputBox:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

	return overlay
end

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

function VioletUI:CreateWindow(config)
	config = config or {}

	local window = setmetatable({}, Window)
	window.Theme = ShallowClone(DefaultTheme)
	if config.Theme then
		for k, v in pairs(config.Theme) do
			window.Theme[k] = v
		end
	end

	window.Flags = {}
	window.Configs = {}
	window.Tabs = {}
	window.Open = true
	window._connections = {}
	window._themeBindings = {}
	window._flagSetters = {}

	local parent = config.Parent or (LocalPlayer:WaitForChild("PlayerGui"))

	local name = config.Name or "VioletUI"
	local keybind = config.Keybind or Enum.KeyCode.RightShift
	local size = config.Size or UDim2.fromOffset(640, 430)

	local sg = Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		Enabled = true,
	})
	sg.Parent = parent
	window.ScreenGui = sg

	local main = Create("Frame", {
		Name = "Main",
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = window.Theme.Background,
		BorderSizePixel = 0,
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 14)}),
		Create("UIStroke", {Thickness = 1}),
	})
	main.Parent = sg
	window.Main = main
	window:_BindTheme(main, "BackgroundColor3", "Background")
	window:_BindTheme(main:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

	local top = Create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = window.Theme.Background2,
		BorderSizePixel = 0,
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 14)}),
	})
	top.Parent = main
	window:_BindTheme(top, "BackgroundColor3", "Background2")

	local title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(1, -120, 1, 0),
		Font = Enum.Font.GothamSemibold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = config.Title or "VioletUI",
	})
	title.Parent = top
	window:_BindTheme(title, "TextColor3", "Text")

	local subtitle = Create("TextLabel", {
		Name = "SubTitle",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 22),
		Size = UDim2.new(1, -120, 0, 18),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = config.SubTitle or "Custom UI",
	})
	subtitle.Parent = top
	window:_BindTheme(subtitle, "TextColor3", "MutedText")

	local closeBtn = Create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(34, 28),
		BackgroundColor3 = window.Theme.Surface,
		BorderSizePixel = 0,
		Text = "×",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		AutoButtonColor = false,
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
		Create("UIStroke", {Thickness = 1}),
	})
	closeBtn.Parent = top
	window:_BindTheme(closeBtn, "BackgroundColor3", "Surface")
	window:_BindTheme(closeBtn:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")
	window:_BindTheme(closeBtn, "TextColor3", "Text")

	closeBtn.MouseEnter:Connect(function()
		Tween(closeBtn, 0.12, {BackgroundColor3 = window.Theme.Surface2})
	end)
	closeBtn.MouseLeave:Connect(function()
		Tween(closeBtn, 0.12, {BackgroundColor3 = window.Theme.Surface})
	end)
	closeBtn.MouseButton1Click:Connect(function()
		window:Toggle()
	end)

	EnableDrag(top, main)

	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, 0, 1, -44),
	})
	body.Parent = main

	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 180, 1, 0),
		BackgroundColor3 = window.Theme.Background2,
		BorderSizePixel = 0,
	})
	sidebar.Parent = body
	window:_BindTheme(sidebar, "BackgroundColor3", "Background2")

	local sideStroke = Create("Frame", {
		Name = "SideStroke",
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = window.Theme.Stroke,
		BorderSizePixel = 0,
	})
	sideStroke.Parent = sidebar
	window:_BindTheme(sideStroke, "BackgroundColor3", "Stroke")

	local tabsList = Create("ScrollingFrame", {
		Name = "TabsList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 1, -20),
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
	}, {
		Create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}),
		Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
	})
	tabsList.Parent = sidebar

	local content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 180, 0, 0),
		Size = UDim2.new(1, -180, 1, 0),
	})
	content.Parent = body

	local pagesFolder = Create("Folder", {Name = "Pages"})
	pagesFolder.Parent = content
	window.PagesFolder = pagesFolder

	local notifWrap = Create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(320, 240),
		BackgroundTransparency = 1,
	})
	notifWrap.Parent = sg

	local notifList = Create("Frame", {
		Name = "List",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		})
	})
	notifList.Parent = notifWrap
	window.Notifications = notifList

	window._connections[#window._connections + 1] = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == keybind then
			window:Toggle()
		end
	end)

	function window:CreateTab(tabName)
		local tab = setmetatable({}, Tab)
		tab.Window = window
		tab.Name = tabName
		tab.Sections = {}

		local tabBtn = Create("TextButton", {
			Name = "TabButton",
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = window.Theme.Surface,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
		}, {
			Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
			Create("UIStroke", {Thickness = 1}),
		})
		tabBtn.Parent = tabsList
		window:_BindTheme(tabBtn, "BackgroundColor3", "Surface")
		window:_BindTheme(tabBtn:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

		local accentBar = Create("Frame", {
			Name = "Accent",
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.new(0, 8, 0, 6),
			BackgroundColor3 = window.Theme.Accent,
			BorderSizePixel = 0,
			Visible = false,
		}, {
			Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
		})
		accentBar.Parent = tabBtn
		window:_BindTheme(accentBar, "BackgroundColor3", "Accent")

		local tabText = Create("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 18, 0, 0),
			Size = UDim2.new(1, -26, 1, 0),
			Font = Enum.Font.GothamSemibold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tabName,
		})
		tabText.Parent = tabBtn
		window:_BindTheme(tabText, "TextColor3", "Text")

		local page = Create("ScrollingFrame", {
			Name = tabName .. "_Page",
			Visible = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 10),
			Size = UDim2.new(1, 0, 1, -20),
			ScrollBarThickness = 4,
			CanvasSize = UDim2.new(0, 0, 0, 0),
		}, {
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 14),
			}),
			Create("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}),
		})
		page.Parent = pagesFolder

		local pageLayout = page:FindFirstChildOfClass("UIListLayout")
		pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 24)
		end)

		tab.Page = page
		tab.Button = tabBtn
		tab._accent = accentBar

		local function SelectThis()
			for _, t in ipairs(window.Tabs) do
				t.Page.Visible = false
				t._accent.Visible = false
				Tween(t.Button, 0.12, {BackgroundColor3 = window.Theme.Surface})
			end
			tab.Page.Visible = true
			tab._accent.Visible = true
			Tween(tab.Button, 0.12, {BackgroundColor3 = window.Theme.Surface2})
		end

		tabBtn.MouseEnter:Connect(function()
			if tab.Page.Visible then return end
			Tween(tabBtn, 0.12, {BackgroundColor3 = window.Theme.Surface2})
		end)
		tabBtn.MouseLeave:Connect(function()
			if tab.Page.Visible then return end
			Tween(tabBtn, 0.12, {BackgroundColor3 = window.Theme.Surface})
		end)
		tabBtn.MouseButton1Click:Connect(SelectThis)

		function tab:CreateSection(sectionTitle)
			local section = setmetatable({}, Section)
			section.Tab = tab
			section.Window = window

			local holder = Create("Frame", {
				Name = "Section",
				BackgroundColor3 = window.Theme.Surface,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, {
				Create("UICorner", {CornerRadius = UDim.new(0, 14)}),
				Create("UIStroke", {Thickness = 1}),
				Create("UIPadding", {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
				}),
				Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}),
			})
			holder.Parent = tab.Page
			window:_BindTheme(holder, "BackgroundColor3", "Surface")
			window:_BindTheme(holder:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

			local header = Create("TextLabel", {
				Name = "Header",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = sectionTitle,
			})
			header.Parent = holder
			window:_BindTheme(header, "TextColor3", "Text")

			section.Holder = holder

			function section:AddLabel(opts)
				opts = opts or {}
				local txt = tostring(opts.Text or opts.Name or "Label")
				local align = opts.Align or Enum.TextXAlignment.Left
				local sizeY = tonumber(opts.SizeY) or 16
				local muted = (opts.Muted == true)

				local lbl = Create("TextLabel", {
					Name = "Label",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, sizeY),
					Font = Enum.Font.Gotham,
					TextSize = tonumber(opts.TextSize) or 12,
					TextXAlignment = align,
					Text = txt,
				})
				lbl.Parent = holder
				window:_BindTheme(lbl, "TextColor3", muted and "MutedText" or "Text")
				return lbl
			end

			function section:AddParagraph(opts)
				opts = opts or {}
				local t = tostring(opts.Title or "Paragraph")
				local c = tostring(opts.Content or "")

				local wrap = Create("Frame", {
					Name = "Paragraph",
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = window.Theme.Surface2,
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
					Create("UIPadding", {
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 10),
						PaddingBottom = UDim.new(0, 10),
					}),
					Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
				})
				wrap.Parent = holder
				window:_BindTheme(wrap, "BackgroundColor3", "Surface2")
				window:_BindTheme(wrap:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local titleLbl = Create("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18),
					Font = Enum.Font.GothamSemibold,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = t,
				})
				titleLbl.Parent = wrap
				window:_BindTheme(titleLbl, "TextColor3", "Text")

				local contentLbl = Create("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
					Text = c,
				})
				contentLbl.Parent = wrap
				window:_BindTheme(contentLbl, "TextColor3", "MutedText")

				return wrap
			end

			function section:AddButton(opts)
				opts = opts or {}
				local text = tostring(opts.Name or "Button")
				local cb = opts.Callback or function() end

				local btn = Create("TextButton", {
					Name = "Button",
					Size = UDim2.new(1, 0, 0, 36),
					BackgroundColor3 = window.Theme.Surface2,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
				})
				btn.Parent = holder
				window:_BindTheme(btn, "BackgroundColor3", "Surface2")
				window:_BindTheme(btn:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local label = Create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 0),
					Size = UDim2.new(1, -24, 1, 0),
					Font = Enum.Font.GothamSemibold,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
				})
				label.Parent = btn
				window:_BindTheme(label, "TextColor3", "Text")

				btn.MouseEnter:Connect(function()
					Tween(btn, 0.12, {BackgroundColor3 = window.Theme.Accent2})
				end)
				btn.MouseLeave:Connect(function()
					Tween(btn, 0.12, {BackgroundColor3 = window.Theme.Surface2})
				end)
				btn.MouseButton1Click:Connect(function()
					pcall(cb)
				end)

				return btn
			end

			function section:AddToggle(opts)
				opts = opts or {}
				local text = tostring(opts.Name or "Toggle")
				local flag = opts.Flag
				local state = (opts.Default == true)
				local cb = opts.Callback or function(_) end

				local row = Create("Frame", {
					Name = "Toggle",
					Size = UDim2.new(1, 0, 0, 38),
					BackgroundColor3 = window.Theme.Surface2,
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
				})
				row.Parent = holder
				window:_BindTheme(row, "BackgroundColor3", "Surface2")
				window:_BindTheme(row:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local label = Create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 0),
					Size = UDim2.new(1, -60, 1, 0),
					Font = Enum.Font.GothamSemibold,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
				})
				label.Parent = row
				window:_BindTheme(label, "TextColor3", "Text")

				local box = Create("Frame", {
					Name = "Box",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(22, 22),
					BackgroundColor3 = window.Theme.Surface,
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 8)}),
					Create("UIStroke", {Thickness = 1}),
				})
				box.Parent = row
				window:_BindTheme(box, "BackgroundColor3", "Surface")
				window:_BindTheme(box:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local check = Create("Frame", {
					Name = "Check",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
				})
				check.Parent = box

				local left = Create("Frame", {
					Name = "Left",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.30, 0, 0.58, 0),
					Size = UDim2.new(0, 6, 0, 2),
					Rotation = 45,
					BorderSizePixel = 0,
					Visible = false,
				}, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
				left.Parent = check
				window:_BindTheme(left, "BackgroundColor3", "Accent")

				local right = Create("Frame", {
					Name = "Right",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.42, 0, 0.62, 0),
					Size = UDim2.new(0, 11, 0, 2),
					Rotation = -45,
					BorderSizePixel = 0,
					Visible = false,
				}, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
				right.Parent = check
				window:_BindTheme(right, "BackgroundColor3", "Accent")

				local function Render(silent)
					if state then
						Tween(box, 0.12, {BackgroundColor3 = window.Theme.Accent2})
						left.Visible = true
						right.Visible = true
					else
						Tween(box, 0.12, {BackgroundColor3 = window.Theme.Surface})
						left.Visible = false
						right.Visible = false
					end
					window:_SetFlag(flag, state)
					if not silent then
						pcall(cb, state)
					end
				end

				local click = Create("TextButton", {
					Name = "Click",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Text = "",
					AutoButtonColor = false,
				})
				click.Parent = row

				click.MouseButton1Click:Connect(function()
					state = not state
					Render(false)
				end)

				Render(true)
				pcall(cb, state)

				local api = {}
				function api:Set(v, silent)
					state = (v == true)
					Render(silent == true)
				end
				function api:Get()
					return state
				end

				if flag and flag ~= "" then
					window._flagSetters[flag] = function(v, silent)
						api:Set(v, silent)
					end
				end

				return api
			end

			function section:AddSlider(opts)
				opts = opts or {}
				local text = tostring(opts.Name or "Slider")
				local min = tonumber(opts.Min) or 0
				local max = tonumber(opts.Max) or 100
				local increment = tonumber(opts.Increment) or 1
				local scrollStep = tonumber(opts.ScrollStep) or increment
				local flag = opts.Flag
				local cb = opts.Callback or function(_) end

				local value = tonumber(opts.Default)
				if value == nil then value = min end
				value = Clamp(value, min, max)
				value = Round(value, increment)

				local row = Create("Frame", {
					Name = "Slider",
					Size = UDim2.new(1, 0, 0, 56),
					BackgroundColor3 = window.Theme.Surface2,
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
				})
				row.Parent = holder
				window:_BindTheme(row, "BackgroundColor3", "Surface2")
				window:_BindTheme(row:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local label = Create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 8),
					Size = UDim2.new(1, -90, 0, 18),
					Font = Enum.Font.GothamSemibold,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
				})
				label.Parent = row
				window:_BindTheme(label, "TextColor3", "Text")

				local valLabel = Create("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 8),
					Size = UDim2.new(0, 70, 0, 18),
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = tostring(value),
				})
				valLabel.Parent = row
				window:_BindTheme(valLabel, "TextColor3", "MutedText")

				local barBg = Create("Frame", {
					Name = "BarBg",
					Position = UDim2.new(0, 12, 0, 34),
					Size = UDim2.new(1, -24, 0, 10),
					BackgroundColor3 = window.Theme.Surface,
					BorderSizePixel = 0,
				}, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
				barBg.Parent = row
				window:_BindTheme(barBg, "BackgroundColor3", "Surface")

				local fill = Create("Frame", {
					Name = "Fill",
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundColor3 = window.Theme.Accent,
					BorderSizePixel = 0,
				}, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
				fill.Parent = barBg
				window:_BindTheme(fill, "BackgroundColor3", "Accent")

				local knob = Create("Frame", {
					Name = "Knob",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = window.Theme.Text,
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
					Create("UIStroke", {Thickness = 1}),
				})
				knob.Parent = barBg
				window:_BindTheme(knob, "BackgroundColor3", "Text")
				window:_BindTheme(knob:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local hovered = false
				barBg.MouseEnter:Connect(function() hovered = true end)
				barBg.MouseLeave:Connect(function() hovered = false end)

				local function SetValue(v, silent)
					v = Clamp(v, min, max)
					v = Round(v, increment)
					value = v

					local alpha = 0
					if max ~= min then
						alpha = (value - min) / (max - min)
					end
					fill.Size = UDim2.new(alpha, 0, 1, 0)
					knob.Position = UDim2.new(alpha, 0, 0.5, 0)
					valLabel.Text = tostring(value)

					window:_SetFlag(flag, value)
					if not silent then
						pcall(cb, value)
					end
				end

				local dragging = false
				local function UpdateFromX(x)
					local absPos = barBg.AbsolutePosition.X
					local absSize = barBg.AbsoluteSize.X
					local rel = Clamp((x - absPos) / absSize, 0, 1)
					local v = min + (max - min) * rel
					SetValue(v, false)
				end

				barBg.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = true
						UpdateFromX(input.Position.X)
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						UpdateFromX(input.Position.X)
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = false
					end
				end)

				UserInputService.InputChanged:Connect(function(input, gp)
					if gp then return end
					if not hovered then return end
					if input.UserInputType == Enum.UserInputType.MouseWheel then
						local delta = input.Position.Z
						if delta ~= 0 then
							SetValue(value + (scrollStep * delta), false)
						end
					end
				end)

				SetValue(value, true)
				pcall(cb, value)

				local api = {}
				function api:Set(v, silent)
					SetValue(tonumber(v) or value, silent == true)
				end
				function api:Get()
					return value
				end

				if flag and flag ~= "" then
					window._flagSetters[flag] = function(v, silent)
						api:Set(v, silent)
					end
				end

				return api
			end

			local function BuildDropdownBase(name, currentText)
				local row = Create("Frame", {
					Name = name,
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundColor3 = window.Theme.Surface2,
					BorderSizePixel = 0,
					ClipsDescendants = false,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
				})
				window:_BindTheme(row, "BackgroundColor3", "Surface2")
				window:_BindTheme(row:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local label = Create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 0),
					Size = UDim2.new(1, -120, 1, 0),
					Font = Enum.Font.GothamSemibold,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = name,
				})
				label.Parent = row
				window:_BindTheme(label, "TextColor3", "Text")

				local valueLabel = Create("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -32, 0.5, 0),
					Size = UDim2.new(0, 80, 1, 0),
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = currentText or "-",
				})
				valueLabel.Parent = row
				window:_BindTheme(valueLabel, "TextColor3", "MutedText")

				local arrow = Create("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					Text = "▾",
				})
				arrow.Parent = row
				window:_BindTheme(arrow, "TextColor3", "Text")

				local dropWrap = Create("Frame", {
					Name = "DropWrap",
					Position = UDim2.new(0, 12, 1, 6),
					Size = UDim2.new(1, -24, 0, 0),
					BackgroundColor3 = window.Theme.Surface,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Visible = false,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
				})
				dropWrap.Parent = row
				window:_BindTheme(dropWrap, "BackgroundColor3", "Surface")
				window:_BindTheme(dropWrap:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local list = Create("ScrollingFrame", {
					Name = "Options",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
					ScrollBarThickness = 3,
					CanvasSize = UDim2.new(0, 0, 0, 0),
				}, {
					Create("UIPadding", {
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
					}),
					Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
				})
				list.Parent = dropWrap

				local listLayout = list:FindFirstChildOfClass("UIListLayout")
				listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					list.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 16)
				end)

				local click = Create("TextButton", {
					Name = "Click",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Text = "",
					AutoButtonColor = false,
				})
				click.Parent = row

				return row, label, valueLabel, arrow, dropWrap, list, click
			end

			function section:AddDropdown(opts)
				opts = opts or {}
				local text = tostring(opts.Name or "Dropdown")
				local options = opts.Options or {}
				local flag = opts.Flag
				local cb = opts.Callback or function(_) end

				local current = opts.Default
				if current == nil and #options > 0 then
					current = options[1]
				end

				local row, label, valueLabel, arrow, dropWrap, list, click = BuildDropdownBase(text, current and tostring(current) or "-")
				row.Name = "Dropdown"
				row.Parent = holder

				local opened = false
				local function Open()
					if opened then return end
					opened = true
					dropWrap.Visible = true
					local target = math.min((#options * 32) + 16, 170)
					Tween(dropWrap, 0.16, {Size = UDim2.new(1, -24, 0, target)})
					Tween(arrow, 0.16, {Rotation = 180})
				end

				local function Close()
					if not opened then return end
					opened = false
					Tween(dropWrap, 0.14, {Size = UDim2.new(1, -24, 0, 0)})
					Tween(arrow, 0.14, {Rotation = 0})
					task.delay(0.15, function()
						if not opened then
							dropWrap.Visible = false
						end
					end)
				end

				local function Set(v, silent)
					current = v
					valueLabel.Text = tostring(current)
					window:_SetFlag(flag, current)
					if not silent then
						pcall(cb, current)
					end
				end

				for _, opt in ipairs(options) do
					local optBtn = Create("TextButton", {
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundColor3 = window.Theme.Surface2,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						Text = "",
					}, {
						Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
					})
					optBtn.Parent = list
					window:_BindTheme(optBtn, "BackgroundColor3", "Surface2")

					local optText = Create("TextLabel", {
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 10, 0, 0),
						Size = UDim2.new(1, -20, 1, 0),
						Font = Enum.Font.Gotham,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = tostring(opt),
					})
					optText.Parent = optBtn
					window:_BindTheme(optText, "TextColor3", "Text")

					optBtn.MouseEnter:Connect(function()
						Tween(optBtn, 0.10, {BackgroundColor3 = window.Theme.Accent2})
					end)
					optBtn.MouseLeave:Connect(function()
						Tween(optBtn, 0.10, {BackgroundColor3 = window.Theme.Surface2})
					end)

					optBtn.MouseButton1Click:Connect(function()
						Set(opt, false)
						Close()
					end)
				end

				click.MouseButton1Click:Connect(function()
					if opened then Close() else Open() end
				end)

				if current ~= nil then
					Set(current, true)
					pcall(cb, current)
				end

				local api = {}
				function api:Set(v, silent)
					Set(v, silent == true)
				end
				function api:Get()
					return current
				end
				function api:Open()
					Open()
				end
				function api:Close()
					Close()
				end

				if flag and flag ~= "" then
					window._flagSetters[flag] = function(v, silent)
						api:Set(v, silent)
					end
				end

				return api
			end

			function section:AddMultiDropdown(opts)
				opts = opts or {}
				local text = tostring(opts.Name or "MultiDropdown")
				local options = opts.Options or {}
				local flag = opts.Flag
				local cb = opts.Callback or function(_) end

				local selectedSet = {}
				local selectedList = {}

				local function NormalizeSelection(arr)
					selectedSet = {}
					selectedList = {}
					if type(arr) == "table" then
						for _, v in ipairs(arr) do
							selectedSet[v] = true
						end
					end
					for _, opt in ipairs(options) do
						if selectedSet[opt] then
							selectedList[#selectedList + 1] = opt
						end
					end
				end

				NormalizeSelection(opts.Default)

				local function DisplayText()
					if #selectedList == 0 then return "-" end
					if #selectedList == 1 then return tostring(selectedList[1]) end
					return tostring(#selectedList) .. " selected"
				end

				local row, label, valueLabel, arrow, dropWrap, list, click = BuildDropdownBase(text, DisplayText())
				row.Name = "MultiDropdown"
				row.Parent = holder

				local opened = false
				local function Open()
					if opened then return end
					opened = true
					dropWrap.Visible = true
					local target = math.min((#options * 32) + 16, 190)
					Tween(dropWrap, 0.16, {Size = UDim2.new(1, -24, 0, target)})
					Tween(arrow, 0.16, {Rotation = 180})
				end

				local function Close()
					if not opened then return end
					opened = false
					Tween(dropWrap, 0.14, {Size = UDim2.new(1, -24, 0, 0)})
					Tween(arrow, 0.14, {Rotation = 0})
					task.delay(0.15, function()
						if not opened then
							dropWrap.Visible = false
						end
					end)
				end

				local function Commit(silent)
					valueLabel.Text = DisplayText()
					window:_SetFlag(flag, selectedList)
					if not silent then
						pcall(cb, selectedList)
					end
				end

				local optionButtons = {}

				local function UpdateOptionVisual(opt)
					local btn = optionButtons[opt]
					if not btn then return end
					local box = btn:FindFirstChild("Box")
					local checkL = box and box:FindFirstChild("Left")
					local checkR = box and box:FindFirstChild("Right")

					if selectedSet[opt] then
						Tween(box, 0.10, {BackgroundColor3 = window.Theme.Accent2})
						if checkL then checkL.Visible = true end
						if checkR then checkR.Visible = true end
					else
						Tween(box, 0.10, {BackgroundColor3 = window.Theme.Surface})
						if checkL then checkL.Visible = false end
						if checkR then checkR.Visible = false end
					end
				end

				local function RebuildSelectedList()
					selectedList = {}
					for _, opt in ipairs(options) do
						if selectedSet[opt] then
							selectedList[#selectedList + 1] = opt
						end
					end
				end

				for _, opt in ipairs(options) do
					local optBtn = Create("TextButton", {
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundColor3 = window.Theme.Surface2,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						Text = "",
					}, {
						Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
					})
					optBtn.Parent = list
					window:_BindTheme(optBtn, "BackgroundColor3", "Surface2")

					local optText = Create("TextLabel", {
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 10, 0, 0),
						Size = UDim2.new(1, -52, 1, 0),
						Font = Enum.Font.Gotham,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = tostring(opt),
					})
					optText.Parent = optBtn
					window:_BindTheme(optText, "TextColor3", "Text")

					local box = Create("Frame", {
						Name = "Box",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(18, 18),
						BackgroundColor3 = window.Theme.Surface,
						BorderSizePixel = 0,
					}, {
						Create("UICorner", {CornerRadius = UDim.new(0, 7)}),
						Create("UIStroke", {Thickness = 1, Color = window.Theme.Stroke}),
					})
					box.Parent = optBtn
					window:_BindTheme(box, "BackgroundColor3", "Surface")
					window:_BindTheme(box:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

					local left = Create("Frame", {
						Name = "Left",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0.28, 0, 0.58, 0),
						Size = UDim2.new(0, 5, 0, 2),
						Rotation = 45,
						BorderSizePixel = 0,
						Visible = false,
					}, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
					left.Parent = box
					window:_BindTheme(left, "BackgroundColor3", "Accent")

					local right = Create("Frame", {
						Name = "Right",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0.40, 0, 0.62, 0),
						Size = UDim2.new(0, 9, 0, 2),
						Rotation = -45,
						BorderSizePixel = 0,
						Visible = false,
					}, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
					right.Parent = box
					window:_BindTheme(right, "BackgroundColor3", "Accent")

					optionButtons[opt] = optBtn
					UpdateOptionVisual(opt)

					optBtn.MouseEnter:Connect(function()
						Tween(optBtn, 0.10, {BackgroundColor3 = window.Theme.Surface})
					end)
					optBtn.MouseLeave:Connect(function()
						Tween(optBtn, 0.10, {BackgroundColor3 = window.Theme.Surface2})
					end)

					optBtn.MouseButton1Click:Connect(function()
						selectedSet[opt] = not selectedSet[opt]
						RebuildSelectedList()
						UpdateOptionVisual(opt)
						Commit(false)
					end)
				end

				click.MouseButton1Click:Connect(function()
					if opened then Close() else Open() end
				end)

				Commit(true)
				pcall(cb, selectedList)

				local api = {}
				function api:Set(arr, silent)
					NormalizeSelection(arr)
					for _, opt in ipairs(options) do
						UpdateOptionVisual(opt)
					end
					Commit(silent == true)
				end
				function api:Get()
					return selectedList
				end
				function api:Open()
					Open()
				end
				function api:Close()
					Close()
				end

				if flag and flag ~= "" then
					window._flagSetters[flag] = function(v, silent)
						api:Set(v, silent)
					end
				end

				return api
			end

			function section:AddInput(opts)
				opts = opts or {}
				local text = tostring(opts.Name or "Input")
				local placeholder = tostring(opts.Placeholder or "Введите текст...")
				local flag = opts.Flag
				local cb = opts.Callback or function(_) end

				local row = Create("Frame", {
					Name = "Input",
					Size = UDim2.new(1, 0, 0, 56),
					BackgroundColor3 = window.Theme.Surface2,
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
				})
				row.Parent = holder
				window:_BindTheme(row, "BackgroundColor3", "Surface2")
				window:_BindTheme(row:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local label = Create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 8),
					Size = UDim2.new(1, -24, 0, 18),
					Font = Enum.Font.GothamSemibold,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
				})
				label.Parent = row
				window:_BindTheme(label, "TextColor3", "Text")

				local box = Create("TextBox", {
					Name = "Box",
					Position = UDim2.new(0, 12, 0, 30),
					Size = UDim2.new(1, -24, 0, 18),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					Text = tostring(opts.Default or ""),
					PlaceholderText = placeholder,
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				box.Parent = row
				window:_BindTheme(box, "TextColor3", "Text")
				window:_BindTheme(box, "PlaceholderColor3", "MutedText")

				local underline = Create("Frame", {
					Name = "Underline",
					Position = UDim2.new(0, 12, 1, -8),
					Size = UDim2.new(0, 0, 0, 2),
					BackgroundColor3 = window.Theme.Accent,
					BorderSizePixel = 0,
				}, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
				underline.Parent = row
				window:_BindTheme(underline, "BackgroundColor3", "Accent")

				box.Focused:Connect(function()
					Tween(underline, 0.15, {Size = UDim2.new(1, -24, 0, 2)})
				end)
				box.FocusLost:Connect(function()
					Tween(underline, 0.15, {Size = UDim2.new(0, 0, 0, 2)})
					window:_SetFlag(flag, box.Text)
					pcall(cb, box.Text)
				end)

				if opts.Numeric == true then
					box:GetPropertyChangedSignal("Text"):Connect(function()
						local t = box.Text
						local filtered = t:gsub("[^%d%.%-]", "")
						if filtered ~= t then
							box.Text = filtered
						end
					end)
				end

				window:_SetFlag(flag, box.Text)
				pcall(cb, box.Text)

				local api = {}
				function api:Set(v, silent)
					box.Text = tostring(v or "")
					window:_SetFlag(flag, box.Text)
					if not (silent == true) then
						pcall(cb, box.Text)
					end
				end
				function api:Get()
					return box.Text
				end

				if flag and flag ~= "" then
					window._flagSetters[flag] = function(v, silent)
						api:Set(v, silent)
					end
				end

				return api
			end

			function section:AddColorPicker(opts)
				opts = opts or {}
				local text = tostring(opts.Name or "ColorPicker")
				local flag = opts.Flag
				local cb = opts.Callback or function(_) end

				local current = opts.Default
				if typeof(current) ~= "Color3" then
					current = Color3.fromRGB(255, 255, 255)
				end

				local row = Create("Frame", {
					Name = "ColorPicker",
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundColor3 = window.Theme.Surface2,
					BorderSizePixel = 0,
					ClipsDescendants = false,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
				})
				row.Parent = holder
				window:_BindTheme(row, "BackgroundColor3", "Surface2")
				window:_BindTheme(row:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local label = Create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 0),
					Size = UDim2.new(1, -120, 1, 0),
					Font = Enum.Font.GothamSemibold,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
				})
				label.Parent = row
				window:_BindTheme(label, "TextColor3", "Text")

				local preview = Create("Frame", {
					Name = "Preview",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(34, 22),
					BackgroundColor3 = current,
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
					Create("UIStroke", {Thickness = 1, Color = window.Theme.Stroke}),
				})
				preview.Parent = row
				window:_BindTheme(preview:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local arrow = Create("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -54, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					Text = "▾",
				})
				arrow.Parent = row
				window:_BindTheme(arrow, "TextColor3", "Text")

				local dropWrap = Create("Frame", {
					Name = "PickerWrap",
					Position = UDim2.new(0, 12, 1, 6),
					Size = UDim2.new(1, -24, 0, 0),
					BackgroundColor3 = window.Theme.Surface,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Visible = false,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1}),
					Create("UIPadding", {
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 10),
						PaddingBottom = UDim.new(0, 10),
					}),
				})
				dropWrap.Parent = row
				window:_BindTheme(dropWrap, "BackgroundColor3", "Surface")
				window:_BindTheme(dropWrap:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local picker = Create("Frame", {
					Name = "Picker",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 170),
				}, {
					Create("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						Padding = UDim.new(0, 10),
					})
				})
				picker.Parent = dropWrap

				local leftCol = Create("Frame", {
					Name = "Left",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(210, 170),
				})
				leftCol.Parent = picker

				local svBase = Create("Frame", {
					Name = "SV",
					Position = UDim2.new(0, 0, 0, 0),
					Size = UDim2.fromOffset(190, 140),
					BackgroundColor3 = Color3.fromHSV(0, 1, 1),
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1, Color = window.Theme.Stroke}),
				})
				svBase.Parent = leftCol
				window:_BindTheme(svBase:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local whiteOverlay = Create("Frame", {
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIGradient", {
						Rotation = 0,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					})
				})
				whiteOverlay.Parent = svBase

				local blackOverlay = Create("Frame", {
					BackgroundColor3 = Color3.new(0, 0, 0),
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIGradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(1, 0),
						}),
					})
				})
				blackOverlay.Parent = svBase

				local svCursor = Create("Frame", {
					Name = "SVCursor",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(12, 12),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
					Create("UIStroke", {Thickness = 2, Color = Color3.fromRGB(0, 0, 0)}),
				})
				svCursor.Parent = svBase

				local hueBar = Create("Frame", {
					Name = "Hue",
					Position = UDim2.new(0, 196, 0, 0),
					Size = UDim2.fromOffset(14, 140),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
					Create("UIStroke", {Thickness = 1, Color = window.Theme.Stroke}),
					Create("UIGradient", {
						Rotation = 90,
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
							ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 255, 0)),
							ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
							ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
							ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 0, 255)),
							ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
							ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
						}),
					})
				})
				hueBar.Parent = leftCol
				window:_BindTheme(hueBar:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local hueCursor = Create("Frame", {
					Name = "HueCursor",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0, 0),
					Size = UDim2.fromOffset(18, 4),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
					Create("UIStroke", {Thickness = 2, Color = Color3.fromRGB(0, 0, 0)}),
				})
				hueCursor.Parent = hueBar

				local rightCol = Create("Frame", {
					Name = "Right",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -220, 1, 0),
				}, {
					Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
				})
				rightCol.Parent = picker

				local bigPreview = Create("Frame", {
					Name = "BigPreview",
					Size = UDim2.new(1, 0, 0, 42),
					BackgroundColor3 = current,
					BorderSizePixel = 0,
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
					Create("UIStroke", {Thickness = 1, Color = window.Theme.Stroke}),
				})
				bigPreview.Parent = rightCol
				window:_BindTheme(bigPreview:FindFirstChildOfClass("UIStroke"), "Color", "Stroke")

				local rgbText = Create("TextLabel", {
					Name = "RGB",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "",
				})
				rgbText.Parent = rightCol
				window:_BindTheme(rgbText, "TextColor3", "MutedText")

				local closeHint = Create("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "Click to close",
				})
				closeHint.Parent = rightCol
				window:_BindTheme(closeHint, "TextColor3", "MutedText")

				local opened = false
				local h, s, v = Color3.toHSV(current)

				local function UpdateVisual()
					svBase.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
					svCursor.Position = UDim2.new(s, 0, (1 - v), 0)
					hueCursor.Position = UDim2.new(0.5, 0, h, 0)

					local col = Color3.fromHSV(h, s, v)
					preview.BackgroundColor3 = col
					bigPreview.BackgroundColor3 = col

					rgbText.Text = ("RGB: %d, %d, %d"):format(
						math.floor(col.R * 255 + 0.5),
						math.floor(col.G * 255 + 0.5),
						math.floor(col.B * 255 + 0.5)
					)
				end

				local function SetColor(c, silent)
					if type(c) == "table" and c.__type == "Color3" then
						c = Color3.fromRGB(tonumber(c.r) or 255, tonumber(c.g) or 255, tonumber(c.b) or 255)
					end
					if typeof(c) == "Color3" then
						current = c
						h, s, v = Color3.toHSV(current)
						UpdateVisual()
						window:_SetFlag(flag, current)
						if not silent then
							pcall(cb, current)
						end
					end
				end

				local function Open()
					if opened then return end
					opened = true
					dropWrap.Visible = true
					UpdateVisual()
					Tween(dropWrap, 0.16, {Size = UDim2.new(1, -24, 0, 190)})
					Tween(arrow, 0.16, {Rotation = 180})
				end

				local function Close()
					if not opened then return end
					opened = false
					Tween(dropWrap, 0.14, {Size = UDim2.new(1, -24, 0, 0)})
					Tween(arrow, 0.14, {Rotation = 0})
					task.delay(0.15, function()
						if not opened then
							dropWrap.Visible = false
						end
					end)
				end

				local click = Create("TextButton", {
					Name = "Click",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Text = "",
					AutoButtonColor = false,
				})
				click.Parent = row
				click.MouseButton1Click:Connect(function()
					if opened then Close() else Open() end
				end)

				local draggingSV = false
				local draggingHue = false

				local function SetSVFromPos(px, py)
					local ap = svBase.AbsolutePosition
					local as = svBase.AbsoluteSize
					local rx = Clamp((px - ap.X) / as.X, 0, 1)
					local ry = Clamp((py - ap.Y) / as.Y, 0, 1)
					s = rx
					v = 1 - ry
					SetColor(Color3.fromHSV(h, s, v), false)
				end

				local function SetHueFromPos(py)
					local ap = hueBar.AbsolutePosition
					local as = hueBar.AbsoluteSize
					local ry = Clamp((py - ap.Y) / as.Y, 0, 1)
					h = ry
					SetColor(Color3.fromHSV(h, s, v), false)
				end

				svBase.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						draggingSV = true
						SetSVFromPos(input.Position.X, input.Position.Y)
					end
				end)

				hueBar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						draggingHue = true
						SetHueFromPos(input.Position.Y)
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					if draggingSV then
						SetSVFromPos(input.Position.X, input.Position.Y)
					elseif draggingHue then
						SetHueFromPos(input.Position.Y)
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						draggingSV = false
						draggingHue = false
					end
				end)

				SetColor(current, true)
				pcall(cb, current)

				local api = {}
				function api:Set(v_, silent)
					SetColor(v_, silent == true)
				end
				function api:Get()
					return current
				end
				function api:Open()
					Open()
				end
				function api:Close()
					Close()
				end

				if flag and flag ~= "" then
					window._flagSetters[flag] = function(v_, silent)
						api:Set(v_, silent)
					end
				end

				return api
			end

			return section
		end

		window.Tabs[#window.Tabs + 1] = tab

		if #window.Tabs == 1 then
			tab.Page.Visible = true
			tab._accent.Visible = true
			Tween(tab.Button, 0.01, {BackgroundColor3 = window.Theme.Surface2})
		end

		return tab
	end

	return window
end

if script:IsA("ModuleScript") then
	return VioletUI
else
	_G.VioletUI = VioletUI
end
