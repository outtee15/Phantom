local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/outtee15/Phantom/refs/heads/main/uiLibrary.lua"))()

local function printValue(name, value)
	if value == nil then
		print("[uiLibrary test] " .. name)
		return
	end
	if type(value) == "table" then
		local parts = {}
		for _, item in ipairs(value) do
			table.insert(parts, tostring(item))
		end
		value = table.concat(parts, ", ")
	end
	print("[uiLibrary test] " .. name .. ": " .. tostring(value))
end

local window = Library:CreateWindow({
	name = "uiLibrary Test",
	subtitle = "Interactive element showcase",
	theme = "default",
	sidebarLayout = true,
})

local tab = window:CreateTab({ name = "Elements", icon = "E" })
local controls = tab:CreateSection({ name = "Interactive Controls", icon = "*" })

controls:CreateButton({
	name = "Test Button",
	buttonText = "Print",
	callback = function()
		printValue("button clicked")
	end,
})

controls:CreateButton({
	name = "Test Notification",
	buttonText = "Notify",
	callback = function()
		window:Notify({
			title = "Notification test",
			content = "The notification system is working.",
			duration = 4,
		})
	end,
})

controls:CreateToggle({
	name = "Test Toggle",
	value = false,
	callback = function(value)
		printValue("Toggle", value)
	end,
})

controls:CreateSlider({
	name = "Test Slider",
	range = { 0, 100 },
	increment = 5,
	value = 50,
	suffix = "%",
	callback = function(value)
		printValue("Slider", value)
	end,
})

controls:CreateDropdown({
	name = "Test Dropdown",
	options = { "Apple", "Banana", "Cherry" },
	value = "Apple",
	callback = function(value)
		printValue("Dropdown", value)
	end,
})

controls:CreateInput({
	name = "Test Input",
	placeholder = "Type and press enter",
	value = "",
	callback = function(value)
		printValue("Input", value)
	end,
})

local keybind
keybind = controls:CreateKeybind({
	name = "Test Keybind",
	value = Enum.KeyCode.K,
	forgetState = true,
	callback = function()
		printValue("Keybind pressed", keybind.value)
	end,
})

controls:CreateColorPicker({
	name = "Test Color",
	color = Color3.fromRGB(211, 117, 164),
	callback = function(value)
		printValue("Color picker", value)
	end,
})

controls:CreateLabel({
	name = "Static label",
})

controls:CreateParagraph({
	title = "Paragraph",
	content = "A non-interactive text element for testing layout.",
})

controls:CreateDivider()

print("[uiLibrary test] Loaded. Use the controls above; each interaction prints its value.")