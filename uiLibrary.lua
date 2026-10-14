local Library = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Themes = {
	default = {
		background = Color3.fromRGB(20, 20, 20),
		panel = Color3.fromRGB(25, 25, 25),
		row = Color3.fromRGB(29, 29, 29),
		header = Color3.fromRGB(15, 15, 15),
		text = Color3.fromRGB(240, 240, 240),
		muted = Color3.fromRGB(155, 155, 155),
		accent = Color3.fromRGB(211, 117, 164),
		border = Color3.fromRGB(43, 43, 43),
		input = Color3.fromRGB(34, 34, 34),
	},
	ember = { accent = Color3.fromRGB(236, 132, 91) },
	cobalt = { accent = Color3.fromRGB(87, 159, 222) },
	frost = { accent = Color3.fromRGB(114, 194, 194) },
	rose = { accent = Color3.fromRGB(211, 117, 164) },
	amethyst = { accent = Color3.fromRGB(174, 132, 211) },
}

local function read(props, key, fallback)
	if type(props) ~= "table" then
		return fallback
	end
	local value = props[key]
	if value == nil then
		local pascal = key:sub(1, 1):upper() .. key:sub(2)
		value = props[pascal]
	end
	if value == nil then
		return fallback
	end
	return value
end

local function make(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function round(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, parent)
end

local function stroke(parent, color, thickness)
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = 0,
	}, parent)
end

local function invoke(callback, ...)
	if type(callback) == "function" then
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[uiLibrary] " .. tostring(err))
		end
	end
end

local function normalizedTheme(theme)
	local result = {}
	for key, value in pairs(Themes.default) do
		result[key] = value
	end
	if type(theme) == "string" then
		for key, value in pairs(Themes[theme:lower()] or {}) do
			result[key] = value
		end
	elseif type(theme) == "table" then
		for key, value in pairs(theme) do
			if result[key] ~= nil and typeof(value) == "Color3" then
				result[key] = value
			end
		end
	end
	return result
end

local function getGuiParent()
	local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui
	end
	return game:GetService("CoreGui")
end

function Library:CreateWindow(props)
	props = props or {}
	local theme = normalizedTheme(read(props, "theme", "default"))
	local connections = {}
	local tabs = {}
	local flags = {}
	local activeTab
	local unloaded = false
	local notificationCards = {}
	local config = read(props, "configuration", nil)
	local closeCallback = read(props, "onClose", read(props, "closeCallback", nil))
	local configFile
	local configFolder
	local settingsFile = "uiLibrary_settings.json"
	local gui
	local notificationGui
	local windowFrame
	local contentFrame
	local tabButtons = {}
	local sectionCards = {}
	local activeSections = {}
	local defaultSections = {}
	local currentSidebarWidth = 142

	local function fileFunction(name)
		local ok, fn = pcall(function()
			local getter = _G["getgenv"]
			local environment = type(getter) == "function" and getter() or _G
			return environment[name] or _G[name]
		end)
		return ok and type(fn) == "function" and fn or nil
	end

	local function loadHideKey()
		local reader = fileFunction("readfile")
		local exists = fileFunction("isfile")
		if not reader then return Enum.KeyCode.RightControl end
		if exists then
			local ok, present = pcall(exists, settingsFile)
			if not ok or not present then return Enum.KeyCode.RightControl end
		end
		local ok, settings = pcall(function() return HttpService:JSONDecode(reader(settingsFile)) end)
		if ok and type(settings) == "table" and type(settings.hideKey) == "string" then
			local keyOk, key = pcall(function() return Enum.KeyCode[settings.hideKey] end)
			if keyOk and key then return key end
		end
		return Enum.KeyCode.RightControl
	end

	local function saveHideKey(key)
		local writer = fileFunction("writefile")
		if not writer then return false end
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode({ hideKey = key.Name })
		end)
		if not ok then return false end
		local saved = pcall(writer, settingsFile, encoded)
		return saved
	end

	local hideKey = loadHideKey()
	saveHideKey(hideKey)
	local waitingForHideKey = false
	local settingsPopup
	local hideKeyButton

	local function connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end

	local function tween(object, properties, duration)
		local animation = TweenService:Create(object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
		animation:Play()
		return animation
	end

	local function viewportSize()
		local camera = workspace.CurrentCamera
		return camera and camera.ViewportSize or Vector2.new(900, 700)
	end

	gui = make("ScreenGui", {
		Name = "uiLibrary",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, getGuiParent())
	notificationGui = make("ScreenGui", {
		Name = "uiLibraryNotifications",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = gui.DisplayOrder + 1,
	}, getGuiParent())

	local viewport = viewportSize()
	local width = math.max(320, math.min(860, viewport.X - 24))
	local height = math.max(300, math.min(620, viewport.Y - 24))
	windowFrame = make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = theme.background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gui)
	round(windowFrame, 5)
	stroke(windowFrame, theme.border)

	local header = make("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = theme.header,
		BorderSizePixel = 0,
	}, windowFrame)

	local sidebar = make("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(0, currentSidebarWidth, 1, -70),
		BackgroundColor3 = theme.header,
		BorderSizePixel = 0,
	}, windowFrame)
	make("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, sidebar)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
	}, sidebar)
	local sidebarDivider = make("Frame", {
		Position = UDim2.fromOffset(currentSidebarWidth - 1, 52),
		Size = UDim2.new(0, 1, 1, -70),
		BackgroundColor3 = theme.border,
		BorderSizePixel = 0,
	}, windowFrame)

	local titleLabel = make("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.32, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = tostring(read(props, "name", "Rayfield Window")),
		TextColor3 = theme.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	local subtitleLabel = make("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(0.32, 0, 0, 15),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = tostring(read(props, "subtitle", "")),
		TextColor3 = theme.muted,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	local search = make("TextBox", {
		Name = "Search",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -96, 0.5, 0),
		Size = UDim2.fromOffset(math.max(92, math.min(195, width * 0.27)), 32),
		BackgroundColor3 = theme.input,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		PlaceholderText = "Search...",
		Text = "",
		TextColor3 = theme.text,
		PlaceholderColor3 = theme.muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	round(search, 4)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 8),
	}, search)
	local settingsButton = make("TextButton", {
		Name = "Settings",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -68, 0.5, 0),
		Size = UDim2.fromOffset(22, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "⚙",
		TextColor3 = theme.muted,
		TextSize = 16,
	}, header)
	local hideButton = make("TextButton", {
		Name = "Hide",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.fromOffset(22, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "−",
		TextColor3 = theme.muted,
		TextSize = 18,
	}, header)
	local closeButton = make("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(22, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "×",
		TextColor3 = theme.muted,
		TextSize = 18,
	}, header)
	settingsPopup = make("Frame", {
		Name = "SettingsPopup",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 48),
		Size = UDim2.fromOffset(220, 86),
		BackgroundColor3 = theme.panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 70,
	}, windowFrame)
	round(settingsPopup, 4)
	stroke(settingsPopup, theme.border)
	make("TextLabel", {
		Position = UDim2.fromOffset(10, 7),
		Size = UDim2.new(1, -20, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "Hide window keybind",
		TextColor3 = theme.text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 71,
	}, settingsPopup)
	hideKeyButton = make("TextButton", {
		Position = UDim2.fromOffset(10, 37),
		Size = UDim2.new(1, -20, 0, 32),
		BackgroundColor3 = theme.row,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		Text = hideKey.Name,
		TextColor3 = theme.text,
		TextSize = 11,
		ZIndex = 71,
	}, settingsPopup)
	round(hideKeyButton, 3)

	contentFrame = make("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(currentSidebarWidth, 52),
		Size = UDim2.new(1, -currentSidebarWidth, 1, -70),
		BackgroundColor3 = theme.background,
		BorderSizePixel = 0,
	}, windowFrame)
	make("TextLabel", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = theme.header,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		Text = "Phantom UI by outtee",
		TextColor3 = theme.muted,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, windowFrame)

	local function makeColumn(parent, position, widthScale)
		local column = make("ScrollingFrame", {
			Position = position,
			Size = UDim2.new(widthScale, -12, 1, -12),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = theme.accent,
		}, parent)
		make("UIListLayout", {
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, column)
		make("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
		}, column)
		return column
	end

	local tabContent = make("Frame", {
		Name = "TabContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, contentFrame)
	local leftColumn = makeColumn(tabContent, UDim2.fromOffset(8, 0), 0.5)
	local rightColumn = makeColumn(tabContent, UDim2.new(0.5, 4, 0, 0), 0.5)

	local window = {
		Flags = flags,
		unloaded = false,
		_gui = gui,
		_tabs = tabs,
		_theme = theme,
	}

	local function updateLayout()
		if unloaded then
			return
		end
		local size = viewportSize()
		local newWidth = math.max(320, math.min(860, size.X - 24))
		local newHeight = math.max(300, math.min(620, size.Y - 24))
		windowFrame.Size = UDim2.fromOffset(newWidth, newHeight)
		search.Size = UDim2.fromOffset(math.max(92, math.min(195, newWidth * 0.27)), 32)
		local narrow = size.X < 680
		currentSidebarWidth = math.clamp(math.floor(newWidth * 0.2), 120, 142)
		sidebar.Size = UDim2.new(0, currentSidebarWidth, 1, -70)
		sidebarDivider.Position = UDim2.fromOffset(currentSidebarWidth - 1, 52)
		sidebarDivider.Size = UDim2.new(0, 1, 1, -70)
		contentFrame.Position = UDim2.fromOffset(currentSidebarWidth, 52)
		contentFrame.Size = UDim2.new(1, -currentSidebarWidth, 1, -70)
		titleLabel.Size = UDim2.new(newWidth < 500 and 0.18 or 0.32, 0, 0, 20)
		subtitleLabel.Size = UDim2.new(newWidth < 500 and 0.18 or 0.32, 0, 0, 15)
		search.Visible = newWidth >= 500
		for _, tab in ipairs(tabs) do
			tab._button.Size = UDim2.fromOffset(currentSidebarWidth - 14, 34)
			tab._nameLabel.Size = UDim2.new(1, -43, 1, 0)
			local tabLeft, tabRight = tab._columns[1], tab._columns[2]
			tabLeft.Size = narrow and UDim2.new(1, -16, 1, -12) or UDim2.new(0.5, -12, 1, -12)
			tabRight.Position = narrow and UDim2.new(0, -10000, 0, 0) or UDim2.new(0.5, 4, 0, 0)
			tabRight.Visible = not narrow
			for _, section in ipairs(tab._sections) do
				if section.root and section.root.Parent then
					section.root.Parent = narrow and tabLeft or section.column
				end
			end
		end
	end

	local function setActive(tab)
		if not tab or tab._window ~= window then
			return
		end
		activeTab = tab
		for _, item in ipairs(tabs) do
			item._page.Visible = item == tab
			local selected = item == tab
			item._button.BackgroundColor3 = selected and theme.accent or theme.header
			if item._icon:IsA("ImageLabel") then
				item._icon.ImageColor3 = selected and theme.text or theme.muted
			else
				item._icon.TextColor3 = selected and theme.text or theme.muted
			end
			item._nameLabel.TextColor3 = selected and theme.text or theme.muted
		end
	end

	local function makeTabPage(tab)
		local page = make("Frame", {
			Name = "Page_" .. tostring(#tabs + 1),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
		}, tabContent)
		tab._page = page
		local oldLeft, oldRight = leftColumn, rightColumn
		leftColumn = makeColumn(page, UDim2.fromOffset(8, 0), 0.5)
		rightColumn = makeColumn(page, UDim2.new(0.5, 4, 0, 0), 0.5)
		tab._columns = { leftColumn, rightColumn }
		leftColumn, rightColumn = oldLeft, oldRight
		return tab._columns
	end

	local function makeSection(tab, name, icon)
		local index = #tab._sections + 1
		local columnIndex = ((index - 1) % 2) + 1
		local column = tab._columns[columnIndex]
		local card = make("Frame", {
			Name = "Section_" .. tostring(name),
			Size = UDim2.new(1, -2, 0, 34),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = theme.panel,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = index,
		}, column)
		round(card, 4)
		stroke(card, theme.border)
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}, card)
		local heading = make("TextButton", {
			Name = "SectionHeader",
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = "",
			TextColor3 = theme.text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}, card)
		local iconText = icon and tostring(icon) or ""
		local headingIcon = make("TextLabel", {
			Position = UDim2.fromOffset(9, 0),
			Size = UDim2.fromOffset(21, 36),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = iconText,
			TextColor3 = theme.accent,
			TextSize = 15,
		}, heading)
		local headingName = make("TextLabel", {
			Position = UDim2.fromOffset(iconText ~= "" and 37 or 12, 0),
			Size = UDim2.new(1, -62, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = tostring(name),
			TextColor3 = theme.text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, heading)
		local chevron = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = "v",
			TextColor3 = theme.muted,
			TextSize = 18,
		}, heading)
		local body = make("Frame", {
			Name = "Elements",
			Size = UDim2.new(1, -16, 0, 0),
			Position = UDim2.fromOffset(8, 36),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, card)
		local bodyList = make("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, body)
		local bodyPadding = make("UIPadding", {
			PaddingLeft = UDim.new(0, 7),
			PaddingRight = UDim.new(0, 7),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 7),
		}, body)
		local section = {
			_name = name,
			_tab = tab,
			_root = card,
			_body = body,
			_bodyList = bodyList,
			_bodyPadding = bodyPadding,
			_heading = heading,
			_headingName = headingName,
			_headingIcon = headingIcon,
			_chevron = chevron,
			column = column,
			_collapsed = false,
			_order = index,
			_entries = {},
		}
		section.root = card
		table.insert(tab._sections, section)
		table.insert(sectionCards, section)
		connect(heading.Activated, function()
			section._collapsed = not section._collapsed
			body.Visible = not section._collapsed
			chevron.Text = section._collapsed and ">" or "v"
			card.AutomaticSize = section._collapsed and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
			card.Size = UDim2.new(1, -2, 0, section._collapsed and 36 or 34)
		end)
		return section
	end

	local function ensureDefaultSection(tab)
		if not defaultSections[tab] then
			defaultSections[tab] = makeSection(tab, "General")
		end
		return defaultSections[tab]
	end

	local function createRow(section, height)
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, height or 34),
			BackgroundTransparency = 1,
		}, section._body)
		return row
	end

	local function createValueHandle(tab, section, kind, props, initialValue, setter)
		local name = tostring(read(props, "name", kind))
		local flag = tostring(read(props, "flag", name:gsub("%s+", "")))
		local forgetState = read(props, "forgetState", false) == true
		local handle = {
			value = initialValue,
			flag = flag,
			name = name,
			_locked = false,
			_callback = read(props, "callback", nil),
			_onChanged = read(props, "onChanged", nil),
			_row = nil,
			_controls = {},
			_kind = kind,
			_forgetState = forgetState,
		}
		function handle:Set(value, silent)
			if self._destroyed then
				return
			end
			local nextValue = setter and setter(value) or value
			self.value = nextValue
			if not self._forgetState then flags[self.flag] = nextValue end
			if self._refresh then
				self._refresh(nextValue)
			end
			if not silent then
				invoke(self._callback, nextValue)
			end
			if not silent and config and read(config, "autoSave", false) then
				window:Save()
			end
		end
		function handle:Get()
			return self.value
		end
		function handle:Lock(reason)
			self._locked = true
			if self._description then
				self._description.Text = tostring(reason or read(props, "description", ""))
				self._description.Visible = true
			end
		end
		function handle:Unlock()
			self._locked = false
			if self._description then
				self._description.Text = tostring(read(props, "description", ""))
				self._description.Visible = self._description.Text ~= ""
			end
		end
		function handle:IsLocked()
			return self._locked
		end
		function handle:Destroy()
			self._destroyed = true
			if self._row then
				self._row:Destroy()
			end
		end
		function handle:MoveTo(index)
			if self._row then
				self._row.LayoutOrder = math.max(1, tonumber(index) or 1)
			end
		end
		function handle:MoveToTop()
			self:MoveTo(1)
		end
		function handle:MoveToBottom()
			self:MoveTo(100000)
		end
		function handle:MoveUp()
			self:MoveTo((self._row and self._row.LayoutOrder or 1) - 1)
		end
		function handle:MoveDown()
			self:MoveTo((self._row and self._row.LayoutOrder or 1) + 1)
		end
		table.insert(section._entries, handle)
		if not forgetState then
			flags[flag] = initialValue
			tab._window.Flags[flag] = initialValue
		end
		return handle
	end

	local function attachDescription(handle, row, props, label)
		local descriptionText = tostring(read(props, "description", ""))
		if descriptionText == "" then
			return
		end
		local description = make("TextLabel", {
			Name = "Description",
			Position = UDim2.fromOffset(0, 19),
			Size = UDim2.new(1, -4, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = descriptionText,
			TextColor3 = theme.muted,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, label)
		handle._description = description
	end

	local function makeLabel(row, text, widthScale)
		return make("TextLabel", {
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(widthScale or 0.7, 0, 0, 28),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = tostring(text),
			TextColor3 = theme.muted,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
	end

	local function addElement(tab, kind, props, builder, initialValue, setter)
		props = props or {}
		local section = activeSections[tab] or ensureDefaultSection(tab)
		local row = createRow(section, read(props, "description", "") ~= "" and 42 or 34)
		row.LayoutOrder = #section._entries + 1
		local handle = createValueHandle(tab, section, kind, props, initialValue, setter)
		handle._row = row
		builder(handle, row, props)
		attachDescription(handle, row, props)
		return handle
	end

	local function createElementApi(contextTab, forcedSection)
		local function api(name, kind)
			return function(_, props)
				if type(props) ~= "table" then
					props = { name = props }
				end
				local previousSection = activeSections[contextTab]
				if forcedSection then activeSections[contextTab] = forcedSection end
				local result = name(contextTab, props)
				if forcedSection then activeSections[contextTab] = previousSection end
				return result
			end
		end
		local apiTable = {}
		apiTable.CreateButton = api(function(tab, props)
			local handle = addElement(tab, "Button", props, function(buttonHandle, row, options)
				local label = makeLabel(row, read(options, "name", "Button"), 0.68)
				label.TextColor3 = theme.text
				local button = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(82, 26),
					BackgroundColor3 = theme.row,
					BorderSizePixel = 0,
					Font = Enum.Font.Gotham,
					Text = tostring(read(options, "buttonText", "Run")),
					TextColor3 = theme.text,
					TextSize = 10,
				}, row)
				round(button, 3)
				stroke(button, theme.border)
				table.insert(buttonHandle._controls, button)
				connect(button.Activated, function()
					if not buttonHandle._locked then
						invoke(buttonHandle._callback)
					end
				end)
			end, nil, function(value) return value end)
			return handle
		end)
		apiTable.CreateToggle = api(function(tab, props)
			local value = read(props, "value", false) == true
			return addElement(tab, "Toggle", props, function(handle, row, options)
				local label = makeLabel(row, read(options, "name", "Toggle"), 0.76)
				local switch = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(38, 21),
					BackgroundColor3 = theme.muted,
					BorderSizePixel = 0,
					Text = "",
				}, row)
				round(switch, 2)
				local thumb = make("Frame", {
					Position = UDim2.fromOffset(3, 3),
					Size = UDim2.fromOffset(15, 15),
					BackgroundColor3 = Color3.fromRGB(245, 245, 245),
					BorderSizePixel = 0,
				}, switch)
				round(thumb, 1)
				handle._refresh = function(nextValue)
					tween(switch, { BackgroundColor3 = nextValue and theme.accent or theme.muted }, 0.12)
					tween(thumb, { Position = nextValue and UDim2.new(1, -18, 0, 3) or UDim2.fromOffset(3, 3) }, 0.12)
				end
				handle._refresh(handle.value)
				connect(switch.Activated, function()
					if not handle._locked then handle:Set(not handle.value) end
				end)
				connect(label.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and not handle._locked then
						handle:Set(not handle.value)
					end
				end)
			end, value, function(nextValue) return nextValue == true end)
		end)
		apiTable.CreateSlider = api(function(tab, props)
			local range = read(props, "range", { 0, 100 })
			local minValue, maxValue = tonumber(range[1]) or 0, tonumber(range[2]) or 100
			local value = math.clamp(tonumber(read(props, "value", minValue)) or minValue, minValue, maxValue)
			local increment = tonumber(read(props, "increment", 1)) or 1
			return addElement(tab, "Slider", props, function(handle, row, options)
				row.Size = UDim2.new(1, 0, 0, 51)
				makeLabel(row, read(options, "name", "Slider"), 0.7)
				local readout = make("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.fromOffset(88, 25),
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextColor3 = theme.text,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Right,
				}, row)
				local track = make("TextButton", {
					Position = UDim2.fromOffset(0, 30),
					Size = UDim2.new(1, 0, 0, 9),
					BackgroundColor3 = theme.row,
					BorderSizePixel = 0,
					Text = "",
				}, row)
				round(track, 2)
				local fill = make("Frame", {
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundColor3 = theme.accent,
					BorderSizePixel = 0,
				}, track)
				round(fill, 2)
				local function refresh(nextValue)
					local fraction = maxValue == minValue and 0 or (nextValue - minValue) / (maxValue - minValue)
					fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
					readout.Text = tostring(nextValue) .. tostring(read(options, "suffix", ""))
				end
				handle._refresh = refresh
				refresh(handle.value)
				local function updateFromInput(input)
					local fraction = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
					local nextValue = minValue + (maxValue - minValue) * fraction
					nextValue = math.floor((nextValue / increment) + 0.5) * increment
					nextValue = math.clamp(nextValue, minValue, maxValue)
					handle:Set(nextValue, true)
				end
				local sliderDragging = false
				connect(track.InputBegan, function(input)
					if not handle._locked and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
						sliderDragging = true
						updateFromInput(input)
					end
				end)
				connect(UserInputService.InputChanged, function(input)
					if sliderDragging and not handle._locked and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
						updateFromInput(input)
					end
				end)
				connect(UserInputService.InputEnded, function(input)
					if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
						sliderDragging = false
						if not handle._locked then handle:Set(handle.value) end
					end
				end)
			end, value, function(nextValue)
				local numeric = math.clamp(tonumber(nextValue) or minValue, minValue, maxValue)
				return math.clamp(math.floor((numeric / increment) + 0.5) * increment, minValue, maxValue)
			end)
		end)
		apiTable.CreateDropdown = api(function(tab, props)
			local options = read(props, "options", {})
			local multi = read(props, "multiple", false) == true
			local initial = read(props, "value", nil)
			if initial == nil then initial = read(props, "currentOption", nil) end
			local selected = type(initial) == "table" and initial or (initial ~= nil and { initial } or {})
			local function normalize(value)
				if type(value) == "table" then
					return value
				end
				return value == nil and {} or { value }
			end
			return addElement(tab, "Dropdown", props, function(handle, row, configuration)
				row.Size = UDim2.new(1, 0, 0, 55)
				makeLabel(row, read(configuration, "name", "Dropdown"), 1)
				local choice = make("TextButton", {
					Position = UDim2.fromOffset(0, 27),
					Size = UDim2.new(1, 0, 0, 25),
					BackgroundColor3 = theme.row,
					BorderSizePixel = 0,
					Font = Enum.Font.Gotham,
					Text = "",
					TextColor3 = theme.muted,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, row)
				round(choice, 3)
				make("UIPadding", { PaddingLeft = UDim.new(0, 8) }, choice)
				local popup = make("Frame", {
					Position = UDim2.new(0, 0, 1, 3),
					Size = UDim2.new(1, 0, 0, 0),
					BackgroundColor3 = theme.panel,
					BorderSizePixel = 0,
					Visible = false,
					ZIndex = 30,
				}, choice)
				round(popup, 3)
				stroke(popup, theme.border)
				make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, popup)
				local function refresh(nextValue)
					local values = normalize(nextValue)
					local names = {}
					for _, entry in ipairs(values) do table.insert(names, tostring(entry)) end
					choice.Text = #names > 0 and table.concat(names, ", ") or "---"
				end
				handle._refresh = refresh
				refresh(handle.value)
				local function setPopupOpen(isOpen)
					popup.Visible = isOpen
					row.Size = UDim2.new(1, 0, 0, isOpen and (55 + math.min(#options * 25, 150)) or 55)
					popup.Size = UDim2.new(1, 0, 0, math.min(#options * 25, 150))
				end
				local function rebuildOptions()
					for _, child in ipairs(popup:GetChildren()) do
						if child:IsA("TextButton") then child:Destroy() end
					end
					for index, option in ipairs(options) do
						local optionButton = make("TextButton", {
							Size = UDim2.new(1, 0, 0, 25),
							BackgroundColor3 = theme.panel,
							BorderSizePixel = 0,
							Font = Enum.Font.Gotham,
							Text = tostring(option),
							TextColor3 = theme.text,
							TextSize = 10,
							LayoutOrder = index,
							ZIndex = 31,
					}, popup)
						connect(optionButton.Activated, function()
							if handle._locked then return end
							local nextValue = {}
							if multi then
								for _, current in ipairs(handle.value or {}) do
									if current ~= option then table.insert(nextValue, current) end
								end
								local found = false
								for _, current in ipairs(handle.value or {}) do if current == option then found = true end end
								if not found then table.insert(nextValue, option) end
							else
								nextValue[1] = option
								setPopupOpen(false)
							end
							handle:Set(nextValue)
						end)
					end
				end
				rebuildOptions()
				connect(choice.Activated, function()
					if not handle._locked then setPopupOpen(not popup.Visible) end
				end)
				function handle:Refresh(newOptions)
					options = newOptions or {}
					rebuildOptions()
				end
			end, selected, normalize)
		end)
		apiTable.CreateInput = api(function(tab, props)
			local value = tostring(read(props, "value", ""))
			return addElement(tab, "Input", props, function(handle, row, options)
				row.Size = UDim2.new(1, 0, 0, 54)
				makeLabel(row, read(options, "name", "Input"), 1)
				local box = make("TextBox", {
					Position = UDim2.fromOffset(0, 26),
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = theme.row,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					Font = Enum.Font.Gotham,
					PlaceholderText = tostring(read(options, "placeholder", read(options, "placeholderText", "Enter text..."))),
					Text = handle.value,
					TextColor3 = theme.text,
					PlaceholderColor3 = theme.muted,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, row)
				round(box, 3)
				make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)
				handle._refresh = function(nextValue) box.Text = tostring(nextValue or "") end
				connect(box.FocusLost, function()
					if not handle._locked then
						handle:Set(box.Text)
						if read(options, "removeTextAfterFocusLost", false) then box.Text = "" end
					end
				end)
			end, value, function(nextValue) return tostring(nextValue or "") end)
		end)
		apiTable.CreateKeybind = api(function(tab, props)
			local initial = read(props, "value", read(props, "default", nil))
			return addElement(tab, "Keybind", props, function(handle, row, options)
				makeLabel(row, read(options, "name", "Keybind"), 0.68)
				local button = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(82, 26),
					BackgroundColor3 = theme.row,
					BorderSizePixel = 0,
					Font = Enum.Font.Gotham,
					Text = "",
					TextColor3 = theme.text,
					TextSize = 10,
				}, row)
				round(button, 3)
				local capturing = false
				local function display(value)
					button.Text = typeof(value) == "EnumItem" and value.Name or tostring(value)
				end
				handle._refresh = display
				display(handle.value)
				connect(button.Activated, function()
					if not handle._locked then capturing = true; button.Text = "..." end
				end)
				connect(UserInputService.InputBegan, function(input, processed)
					if processed then return end
					if capturing then
					if input.KeyCode ~= Enum.KeyCode.Escape then handle:Set(input.KeyCode) else display(handle.value) end
					capturing = false
				elseif input.KeyCode == handle.value and not handle._locked then
					invoke(handle._callback)
				end
				end)
			end, initial, function(nextValue)
				if typeof(nextValue) == "EnumItem" then return nextValue end
				if type(nextValue) == "string" then
					local ok, key = pcall(function() return Enum.KeyCode[nextValue] end)
					if ok and key then return key end
				end
				return nil
			end)
		end)
		apiTable.CreateColorPicker = api(function(tab, props)
			local initial = read(props, "color", read(props, "value", Color3.fromRGB(255, 255, 255)))
			local initialHue, initialSaturation, initialBrightness = initial:ToHSV()
			return addElement(tab, "ColorPicker", props, function(handle, row, options)
				makeLabel(row, read(options, "name", "Color"), 0.72)
				local swatch = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 4),
					Size = UDim2.fromOffset(42, 22),
					BackgroundColor3 = initial,
					BorderSizePixel = 0,
					Text = "",
				}, row)
				round(swatch, 3)
				stroke(swatch, theme.border)
				local picker = make("Frame", {
					Position = UDim2.fromOffset(0, 32),
					Size = UDim2.new(1, 0, 0, 128),
					BackgroundColor3 = theme.panel,
					BorderSizePixel = 0,
					Visible = false,
					ZIndex = 30,
				}, row)
				round(picker, 3)
				stroke(picker, theme.border)
				local saturationValue = make("TextButton", {
					Position = UDim2.fromOffset(7, 7),
					Size = UDim2.new(1, -14, 0, 82),
					BackgroundColor3 = Color3.fromHSV(initialHue, 1, 1),
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Text = "",
					ZIndex = 31,
				}, picker)
				round(saturationValue, 2)
				make("UIGradient", {
					Color = ColorSequence.new(Color3.new(1, 1, 1)),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}, saturationValue)
				make("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					ZIndex = 32,
				}, saturationValue)
				local shade = saturationValue:FindFirstChildOfClass("Frame")
				make("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.new(0, 0, 0)),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(1, 0),
					}),
				}, shade)
			local hueBar = make("TextButton", {
				Position = UDim2.fromOffset(7, 96),
				Size = UDim2.new(1, -14, 0, 20),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Text = "",
				ZIndex = 31,
			}, picker)
			round(hueBar, 2)
			make("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
				}),
			}, hueBar)
			local hue, saturation, brightness = initialHue, initialSaturation, initialBrightness
			local dragTarget
			local activeTouch
			local function refresh(nextColor)
				if typeof(nextColor) ~= "Color3" then return end
				swatch.BackgroundColor3 = nextColor
				hue, saturation, brightness = nextColor:ToHSV()
				saturationValue.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			end
			local function updatePicker(input, target)
				local bounds = target.AbsolutePosition
				local dimensions = target.AbsoluteSize
				if target == hueBar then
					hue = math.clamp((input.Position.X - bounds.X) / math.max(dimensions.X, 1), 0, 1)
				else
					saturation = math.clamp((input.Position.X - bounds.X) / math.max(dimensions.X, 1), 0, 1)
					brightness = 1 - math.clamp((input.Position.Y - bounds.Y) / math.max(dimensions.Y, 1), 0, 1)
				end
				handle:Set(Color3.fromHSV(hue, saturation, brightness), true)
			end
			handle._refresh = refresh
			refresh(handle.value)
			connect(swatch.Activated, function()
				if handle._locked then return end
				picker.Visible = not picker.Visible
				row.Size = UDim2.new(1, 0, 0, picker.Visible and 164 or 34)
			end)
			for _, control in ipairs({ hueBar, saturationValue }) do
				connect(control.InputBegan, function(input)
					if handle._locked then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragTarget = control
						activeTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
						updatePicker(input, control)
					end
				end)
			end
			connect(UserInputService.InputChanged, function(input)
				if dragTarget and (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeTouch) then
					updatePicker(input, dragTarget)
				end
			end)
			connect(UserInputService.InputEnded, function(input)
				if dragTarget and (input.UserInputType == Enum.UserInputType.MouseButton1 or input == activeTouch) then
					dragTarget = nil
					activeTouch = nil
					if not handle._locked then handle:Set(handle.value) end
				end
			end)
			end, initial, function(nextColor)
				return typeof(nextColor) == "Color3" and nextColor or initial
			end)
		end)
		apiTable.CreateLabel = api(function(tab, props)
			local text = tostring(read(props, "name", read(props, "text", "")))
			local sectionNow = activeSections[tab] or ensureDefaultSection(tab)
			local row = createRow(sectionNow, 28)
			row.LayoutOrder = #sectionNow._entries + 1
			local label = makeLabel(row, text, 1)
			label.TextColor3 = theme.text
			local handle = { _row = row, name = text }
			function handle:Set(nextText) label.Text = tostring(nextText) end
			function handle:Destroy() row:Destroy() end
			return handle
		end)
		apiTable.CreateParagraph = api(function(tab, props)
			local sectionNow = activeSections[tab] or ensureDefaultSection(tab)
			local row = createRow(sectionNow, 52)
			row.LayoutOrder = #sectionNow._entries + 1
			make("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				Text = tostring(read(props, "title", read(props, "name", ""))),
				TextColor3 = theme.text,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)
			local body = make("TextLabel", {
				Position = UDim2.fromOffset(0, 19),
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Text = tostring(read(props, "content", read(props, "text", ""))),
				TextColor3 = theme.muted,
				TextSize = 10,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}, row)
			return { Set = function(_, nextText) body.Text = tostring(nextText) end, Destroy = function() row:Destroy() end }
		end)
		apiTable.CreateDivider = api(function(tab)
			local sectionNow = activeSections[tab] or ensureDefaultSection(tab)
			local row = createRow(sectionNow, 13)
			row.LayoutOrder = #sectionNow._entries + 1
			make("Frame", {
				Position = UDim2.fromOffset(0, 6),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = theme.border,
				BorderSizePixel = 0,
			}, row)
			return { Destroy = function() row:Destroy() end }
		end)
		return apiTable
	end

	function window:CreateTab(tabProps)
		if unloaded then return nil end
		tabProps = type(tabProps) == "table" and tabProps or { name = tostring(tabProps) }
		local tabName = tostring(read(tabProps, "name", "Tab"))
		local tab = {
			name = tabName,
			_window = window,
			_sections = {},
			_page = nil,
		}
		tab._columns = makeTabPage(tab)
		local button = make("TextButton", {
			Name = "Tab_" .. tabName,
			Size = UDim2.fromOffset(currentSidebarWidth - 14, 34),
			BackgroundColor3 = theme.header,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = #tabs + 1,
		}, sidebar)
		round(button, 5)
		local iconValue = read(tabProps, "icon", nil)
		local iconIsAsset = type(iconValue) == "number" or (type(iconValue) == "string" and (iconValue:find("rbxassetid://", 1, true) == 1 or iconValue:find("rbxthumb://", 1, true) == 1))
		local icon = make(iconIsAsset and "ImageLabel" or "TextLabel", {
			Position = UDim2.fromOffset(8, 7),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
		}, button)
		if iconIsAsset then
			icon.Image = type(iconValue) == "number" and ("rbxassetid://" .. tostring(iconValue)) or iconValue
			icon.ImageColor3 = theme.muted
			icon.ScaleType = Enum.ScaleType.Fit
		else
			icon.Font = Enum.Font.GothamMedium
			icon.Text = iconValue and tostring(iconValue) or "◇"
			icon.TextColor3 = theme.muted
			icon.TextSize = 16
		end
		local nameLabel = make("TextLabel", {
			Name = "TabName",
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(1, -43, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = tabName,
			TextColor3 = theme.muted,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, button)
		connect(button.Activated, function() setActive(tab) end)
		tab._button = button
		tab._icon = icon
		tab._nameLabel = nameLabel
		local elementApi = createElementApi(tab)
		for key, value in pairs(elementApi) do tab[key] = value end
		function tab:CreateSection(sectionProps)
			local sectionName = type(sectionProps) == "table" and read(sectionProps, "name", "Section") or tostring(sectionProps or "Section")
			local sectionIcon = type(sectionProps) == "table" and read(sectionProps, "icon", nil) or nil
			local section = makeSection(self, sectionName, sectionIcon)
			activeSections[self] = section
			local sectionApi = createElementApi(self, section)
			for key, value in pairs(sectionApi) do section[key] = value end
			updateLayout()
			return section
		end
		function tab:Select() setActive(self) end
		function tab:SetName(nextName)
			self.name = tostring(nextName)
			self._nameLabel.Text = self.name
			self._button.Name = "Tab_" .. self.name
		end
		table.insert(tabs, tab)
		table.insert(tabButtons, button)
		if #tabs == 1 then setActive(tab) end
		updateLayout()
		return tab
	end

	function window:CreateTag(tagProps)
		local tagText = type(tagProps) == "table" and read(tagProps, "name", "") or tostring(tagProps or "")
		local tag = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -84, 0.5, 0),
			Size = UDim2.fromOffset(50, 23),
			BackgroundColor3 = theme.row,
			Font = Enum.Font.Gotham,
			Text = tostring(tagText),
			TextColor3 = theme.accent,
			TextSize = 10,
		}, header)
		round(tag, 4)
		return { Destroy = function() tag:Destroy() end }
	end

	function window:Notify(notification)
		notification = notification or {}
		local toast = make("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -18, 1, -18 - (#notificationCards * 84)),
			Size = UDim2.fromOffset(260, 76),
			BackgroundColor3 = theme.panel,
			BorderSizePixel = 0,
			ZIndex = 100,
		}, notificationGui)
		table.insert(notificationCards, toast)
		round(toast, 4)
		stroke(toast, theme.border)
		make("TextLabel", {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = tostring(read(notification, "title", "Notification")),
			TextColor3 = theme.text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 101,
		}, toast)
		make("TextLabel", {
			Position = UDim2.fromOffset(12, 31),
			Size = UDim2.new(1, -24, 0, 34),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = tostring(read(notification, "content", read(notification, "message", ""))),
			TextColor3 = theme.muted,
			TextSize = 10,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 101,
		}, toast)
		task.delay(tonumber(read(notification, "duration", 4)) or 4, function()
			local index = table.find(notificationCards, toast)
			if index then table.remove(notificationCards, index) end
			if toast.Parent then toast:Destroy() end
			for cardIndex, card in ipairs(notificationCards) do
				card.Position = UDim2.new(1, -18, 1, -18 - ((#notificationCards - cardIndex) * 84))
			end
		end)
		return toast
	end
	window.Toast = window.Notify

	function window:Show()
		if not unloaded then gui.Enabled = true; windowFrame.Visible = true end
	end
	function window:Hide()
		if not unloaded then gui.Enabled = false end
	end
	function window:ToggleHide()
		if not unloaded then gui.Enabled = not gui.Enabled end
	end
	function window:GetHideKey()
		return hideKey
	end
	function window:SetHideKey(key)
		local nextKey = key
		if type(nextKey) == "string" then
			local ok, resolved = pcall(function() return Enum.KeyCode[nextKey] end)
			if not ok then return false end
			nextKey = resolved
		end
		if typeof(nextKey) ~= "EnumItem" or nextKey.EnumType ~= Enum.KeyCode then return false end
		hideKey = nextKey
		hideKeyButton.Text = hideKey.Name
		saveHideKey(hideKey)
		return true
	end
	function window:Close()
		self:Unload()
	end
	function window:ToggleMinimise()
		if not unloaded then contentFrame.Visible = not contentFrame.Visible; sidebar.Visible = contentFrame.Visible end
	end
	function window:Navigate(tabOrName)
		for _, tab in ipairs(tabs) do
			if tab == tabOrName or tab.name == tabOrName then setActive(tab); return true end
		end
		return false
	end
	function window:ChangeTheme(nextTheme)
		local previousTheme = theme
		theme = normalizedTheme(nextTheme)
		self._theme = theme
		local colorKeys = { "background", "panel", "row", "header", "text", "muted", "accent", "border", "input" }
		local replacements = {}
		for _, key in ipairs(colorKeys) do replacements[previousTheme[key]] = theme[key] end
		for _, targetGui in ipairs({ gui, notificationGui }) do
			for _, descendant in ipairs(targetGui:GetDescendants()) do
				for _, property in ipairs({ "BackgroundColor3", "TextColor3", "ImageColor3", "Color", "ScrollBarImageColor3" }) do
					local ok, currentColor = pcall(function() return descendant[property] end)
					if ok and replacements[currentColor] then
						pcall(function() descendant[property] = replacements[currentColor] end)
					end
				end
			end
		end
	end
	function window:Get(flag)
		return flags[flag]
	end
	function window:Set(flag, value, silent)
		for _, tab in ipairs(tabs) do
			for _, section in ipairs(tab._sections) do
				for _, element in ipairs(section._entries) do
					if element.flag == flag then element:Set(value, silent); return true end
				end
			end
		end
		return false
	end

	if config then
		local fileName = tostring(read(config, "fileName", tostring(read(props, "name", "RayfieldWindow"))))
		configFolder = read(config, "customFolder", nil)
		configFile = (configFolder and (tostring(configFolder) .. "/") or "") .. fileName .. ".json"
	end
	function window:GetPath()
		return configFolder or "", configFile or ""
	end
	local function serialize(value)
		local valueType = typeof(value)
		if valueType == "Color3" then
			return { __uiLibraryType = "Color3", r = value.R, g = value.G, b = value.B }
		elseif valueType == "EnumItem" then
			return { __uiLibraryType = value.EnumType.Name, name = value.Name }
		elseif type(value) == "table" then
			local result = {}
			for key, item in pairs(value) do result[key] = serialize(item) end
			return result
		end
		return value
	end
	local function deserialize(value)
		if type(value) ~= "table" then return value end
		if value.__uiLibraryType == "Color3" then
			return Color3.new(value.r, value.g, value.b)
		elseif value.__uiLibraryType == "KeyCode" then
			local ok, keyCode = pcall(function() return Enum.KeyCode[value.name] end)
			return ok and keyCode or nil
		end
		for key, item in pairs(value) do value[key] = deserialize(item) end
		return value
	end
	function window:Save()
		if not config then return false end
		local writer = fileFunction("writefile")
		if not writer then return false end
		local folder = fileFunction("makefolder")
		local isFolder = fileFunction("isfolder")
		if configFolder and folder and (not isFolder or not isFolder(configFolder)) then pcall(folder, configFolder) end
		local ok, encoded = pcall(function() return HttpService:JSONEncode(serialize(flags)) end)
		if not ok then return false end
		local saved = pcall(writer, configFile, encoded)
		return saved
	end
	function window:Load()
		if not config or not configFile then return false end
		local exists = fileFunction("isfile")
		local reader = fileFunction("readfile")
		if not reader or (exists and not exists(configFile)) then return false end
		local ok, decoded = pcall(function() return HttpService:JSONDecode(reader(configFile)) end)
		if not ok or type(decoded) ~= "table" then return false end
		for flag, value in pairs(decoded) do self:Set(flag, deserialize(value), false) end
		return true
	end
	function window:ListConfigs()
		local lister = fileFunction("listfiles")
		if not lister or not configFolder then return {} end
		local ok, paths = pcall(lister, configFolder)
		return ok and paths or {}
	end
	function window:DeleteConfig(name)
		local delete = fileFunction("delfile")
		if not delete or not configFile then return false end
		local target = configFolder and (configFolder .. "/" .. tostring(name) .. ".json") or configFile
		return pcall(delete, target)
	end

	function window:Unload()
		if unloaded then return end
		unloaded = true
		self.unloaded = true
		invoke(closeCallback, self)
		for _, connection in ipairs(connections) do connection:Disconnect() end
		connections = {}
		if gui then gui:Destroy() end
		if notificationGui then notificationGui:Destroy() end
	end

	local dragging = false
	local dragStart
	local startPosition
	connect(header.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = windowFrame.Position
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			windowFrame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	connect(settingsButton.Activated, function()
		settingsPopup.Visible = not settingsPopup.Visible
	end)
	connect(hideKeyButton.Activated, function()
		waitingForHideKey = true
		hideKeyButton.Text = "Press a key..."
	end)
	connect(closeButton.Activated, function() window:Close() end)
	connect(hideButton.Activated, function()
		window:Hide()
		window:Notify({
			title = "Phantom UI",
			content = "UI hidden. Press " .. hideKey.Name .. " to unhide it.",
			duration = 5,
		})
	end)
	connect(UserInputService.InputBegan, function(input)
		if waitingForHideKey then
			if input.KeyCode.Name == "Unknown" then return end
			if input.KeyCode.Name == "Escape" then
				waitingForHideKey = false
				hideKeyButton.Text = hideKey.Name
				return
			end
			window:SetHideKey(input.KeyCode)
			waitingForHideKey = false
			hideKeyButton.Text = hideKey.Name
			return
		end
		if input.KeyCode == hideKey then window:ToggleHide() end
	end)
	connect(search:GetPropertyChangedSignal("Text"), function()
		local query = search.Text:lower()
		for _, section in ipairs(sectionCards) do
			local isActivePage = section._tab == activeTab
			local sectionMatches = tostring(section._name):lower():find(query, 1, true) ~= nil
			local visibleElements = 0
			for _, entry in ipairs(section._entries) do
				local entryName = tostring(entry.name or ""):lower()
				local matches = query == "" or sectionMatches or entryName:find(query, 1, true) ~= nil
				if entry._row then entry._row.Visible = matches end
				if matches then visibleElements += 1 end
			end
			section.root.Visible = isActivePage and (query == "" or sectionMatches or visibleElements > 0)
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then connect(camera:GetPropertyChangedSignal("ViewportSize"), updateLayout) end

	if config and read(config, "autoLoad", false) then
		task.defer(function() window:Load() end)
	end
	return window
end

return Library
