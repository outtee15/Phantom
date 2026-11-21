local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local env = (getgenv and getgenv()) or _G
local FLAG = "__AntiAFK_Running"

local function reportError(msg)
	local text = "[Anti-AFK ERROR] " .. tostring(msg)

	task.spawn(error, text)

	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local channels = TextChatService:FindFirstChild("TextChannels")
			local general = channels and channels:FindFirstChild("RBXGeneral")
			if general then
				general:DisplaySystemMessage('<font color="#FF3C3C">' .. text .. "</font>")
			end
		else
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = text,
				Color = Color3.fromRGB(255, 60, 60),
				Font = Enum.Font.SourceSansBold,
				FontSize = Enum.FontSize.Size18,
			})
		end
	end)
end

local function notify(msg)
	print("[Anti-AFK] " .. msg)
end

local existing = env[FLAG]
if existing and existing.player and existing.player.Parent then
	reportError("Already running. Second instance cancelled.")
	return
end

local ok, err = pcall(function()
	local player = Players.LocalPlayer
	if not player then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		player = Players.LocalPlayer
	end
	if not player then
		error("LocalPlayer not found")
	end

	local state = { player = player }
	env[FLAG] = state

	local connection
	connection = player.Idled:Connect(function()
		local success, result = pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
		if not success then
			reportError("Failed to send anti-AFK input: " .. tostring(result))
		end
	end)

	player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if env[FLAG] == state then
				env[FLAG] = nil
			end
			if connection then
				connection:Disconnect()
			end
		end
	end)

	notify("Active. You will not be kicked for idling.")
end)

if not ok then
	env[FLAG] = nil
	reportError(err)
end