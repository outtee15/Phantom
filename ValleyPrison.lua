--RScripts Analytics
task.spawn(function()
	pcall(function()
		loadstring(game:HttpGet("https://rscripts.net/api/telemetry/v2/client.lua?s=6a67d5c512012322a367b466"))()
	end)
end)

getgenv().RAYFIELD_SECURE = true
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local players = game:GetService("Players")
local plr = players.LocalPlayer
local plrVars = plr.ServerVariables

local function infstam(value)
    local characterVars = plrVars:FindFirstChild("Character")
    local stamina = characterVars and characterVars:FindFirstChild("Stamina")
    local depletionRate = stamina and stamina:FindFirstChild("DepletionRate")
    if depletionRate and depletionRate:IsA("NumberValue") then
        depletionRate.Value = value and 0 or 0.5
    end

    local jumpDepletion = stamina and stamina:FindFirstChild("JumpDepletion")
    if jumpDepletion and jumpDepletion:IsA("NumberValue") then
        jumpDepletion.Value = value and 0 or 10
    end
end

local chamsEnabled = false
local fillOpacity = 50
local outlineOpacity = 80
local lockedTargetPlayer = nil
local targetChamsList = {}

local activeHighlights = {}
local chamsConnections = {}

local function removeHighlight(player)
    if activeHighlights[player] then
        activeHighlights[player]:Destroy()
        activeHighlights[player] = nil
    end
end

local function getTargetTeams()
    local myTeam = plr.Team and plr.Team.Name or ""
    
    if myTeam == "Department of Corrections" or myTeam == "State Police" then
        return { ["Escapee"] = true }
    elseif myTeam == "Escapee" or myTeam == "Maximum Security" or myTeam == "Medium Security" or myTeam == "Minimum Security" or myTeam == "Booking" then
        return { ["Department of Corrections"] = true, ["State Police"] = true }
    end
    
    return {}
end

local function hasToggleInnocence(player)
    local function checkContainer(container)
        if not container then return false end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item:FindFirstChild("ToggleInnocence") then
                return true
            end
        end
        return false
    end
    
    return checkContainer(player:FindFirstChild("Backpack")) or checkContainer(player.Character)
end

local function getTeamColors(player, hasContraband, isTargetCham)
    if isTargetCham then
        return Color3.fromRGB(138, 43, 226), Color3.fromRGB(75, 0, 130)
    end
    if player == lockedTargetPlayer then
        return Color3.fromRGB(255, 140, 0), Color3.fromRGB(140, 60, 0)
    end
    if hasContraband then
        return Color3.fromRGB(255, 85, 0), Color3.fromRGB(130, 40, 0)
    end

    local playerTeam = player.Team and player.Team.Name or ""
    if playerTeam == "Department of Corrections" or playerTeam == "State Police" then
        return Color3.fromRGB(0, 130, 255), Color3.fromRGB(0, 40, 120)
    else
        return Color3.fromRGB(255, 40, 40), Color3.fromRGB(120, 10, 10)
    end
end

local function updatePlayerChams(player)
    if not chamsEnabled or player == plr then
        removeHighlight(player)
        return
    end
    
    local isTargetCham = false
    for _, targetName in ipairs(targetChamsList) do
        if string.lower(player.Name) == string.lower(targetName) or string.lower(player.DisplayName) == string.lower(targetName) then
            isTargetCham = true
            break
        end
    end

    local targetTeams = getTargetTeams()
    local playerTeam = player.Team and player.Team.Name or ""
    
    local isPrisoner = (playerTeam == "Maximum Security" or playerTeam == "Medium Security" or playerTeam == "Minimum Security" or playerTeam == "Booking")
    local hasContraband = false
    
    if isPrisoner then
        hasContraband = hasToggleInnocence(player)
    end

    local myTeam = plr.Team and plr.Team.Name or ""
    local amIPolice = (myTeam == "Department of Corrections" or myTeam == "State Police")
    
    local shouldHighlight = false
    if isTargetCham then
        shouldHighlight = true
    elseif targetTeams[playerTeam] then
        shouldHighlight = true
    elseif amIPolice and hasContraband then
        shouldHighlight = true
    end

    if shouldHighlight and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local fillColor, outlineColor = getTeamColors(player, hasContraband, isTargetCham)

        if not activeHighlights[player] or activeHighlights[player].Parent ~= player.Character then
            removeHighlight(player)
            
            local highlight = Instance.new("Highlight")
            highlight.Name = "TeamChams"
            highlight.FillColor = fillColor
            highlight.OutlineColor = outlineColor
            highlight.FillTransparency = 1 - (fillOpacity / 100)
            highlight.OutlineTransparency = 1 - (outlineOpacity / 100)
            highlight.Adornee = player.Character
            highlight.Parent = player.Character
            
            activeHighlights[player] = highlight
        else
            local highlight = activeHighlights[player]
            highlight.FillColor = fillColor
            highlight.OutlineColor = outlineColor
            highlight.FillTransparency = 1 - (fillOpacity / 100)
            highlight.OutlineTransparency = 1 - (outlineOpacity / 100)
        end
    else
        removeHighlight(player)
    end
end

local function refreshAllChams()
    for _, player in ipairs(players:GetPlayers()) do
        updatePlayerChams(player)
    end
end

local function toggleChams(value)
    chamsEnabled = value

    for _, conn in ipairs(chamsConnections) do
        conn:Disconnect()
    end
    chamsConnections = {}

    if not chamsEnabled then
        for player, _ in pairs(activeHighlights) do
            removeHighlight(player)
        end
        return
    end

    local function attachInventoryListeners(player)
        local function onInventoryChanged(child)
            if child:IsA("Tool") then
                task.wait(0.1)
                updatePlayerChams(player)
            end
        end
        local char = player.Character
        if char then
            table.insert(chamsConnections, char.ChildAdded:Connect(onInventoryChanged))
            table.insert(chamsConnections, char.ChildRemoved:Connect(onInventoryChanged))
        end
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            table.insert(chamsConnections, backpack.ChildAdded:Connect(onInventoryChanged))
            table.insert(chamsConnections, backpack.ChildRemoved:Connect(onInventoryChanged))
        end
    end

    for _, player in ipairs(players:GetPlayers()) do
        updatePlayerChams(player)
        attachInventoryListeners(player)

        local teamConn = player:GetPropertyChangedSignal("Team"):Connect(function()
            updatePlayerChams(player)
        end)
        local charConn = player.CharacterAdded:Connect(function()
            task.wait(0.5)
            attachInventoryListeners(player)
            updatePlayerChams(player)
        end)

        table.insert(chamsConnections, teamConn)
        table.insert(chamsConnections, charConn)
    end

    local myTeamConn = plr:GetPropertyChangedSignal("Team"):Connect(function()
        refreshAllChams()
    end)
    table.insert(chamsConnections, myTeamConn)

    local playerAddedConn = players.PlayerAdded:Connect(function(player)
        local teamConn = player:GetPropertyChangedSignal("Team"):Connect(function()
            updatePlayerChams(player)
        end)
        local charConn = player.CharacterAdded:Connect(function()
            task.wait(0.5)
            attachInventoryListeners(player)
            updatePlayerChams(player)
        end)
        table.insert(chamsConnections, teamConn)
        table.insert(chamsConnections, charConn)
    end)
    table.insert(chamsConnections, playerAddedConn)
end

local noRecoilEnabled = false
local recoilConnections = {}

local function applyNoRecoil(tool)
    if not tool:IsA("Tool") then return end

    local recoil = tool:FindFirstChild("Recoil")
    if not recoil then return end

    local blowbackWeight = recoil:FindFirstChild("BlowbackWeight")
    if blowbackWeight then
        blowbackWeight.Value = 0
    end

    local cameraRecoilMultiplier = recoil:FindFirstChild("CameraRecoilMultiplier")
    if cameraRecoilMultiplier then
        cameraRecoilMultiplier.Value = 0
    end

    local muzzleRise = recoil:FindFirstChild("MuzzleRise")
    if muzzleRise then
        muzzleRise.Value = false
    end
end

local function scanAndApplyRecoil(container)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        applyNoRecoil(child)
    end
end

local function toggleNoRecoil(value)
    noRecoilEnabled = value

    for _, conn in ipairs(recoilConnections) do
        conn:Disconnect()
    end
    recoilConnections = {}

    if not noRecoilEnabled then return end

    local backpack = plr:FindFirstChild("Backpack")
    local char = plr.Character

    if backpack then scanAndApplyRecoil(backpack) end
    if char then scanAndApplyRecoil(char) end

    if backpack then
        local bConn = backpack.ChildAdded:Connect(function(child)
            task.wait(0.1)
            applyNoRecoil(child)
        end)
        table.insert(recoilConnections, bConn)
    end

    local charAddedConn = plr.CharacterAdded:Connect(function(newChar)
        local cConn = newChar.ChildAdded:Connect(function(child)
            task.wait(0.1)
            applyNoRecoil(child)
        end)
        table.insert(recoilConnections, cConn)
        scanAndApplyRecoil(newChar)
    end)
    table.insert(recoilConnections, charAddedConn)

    if char then
        local cConn = char.ChildAdded:Connect(function(child)
            task.wait(0.1)
            applyNoRecoil(child)
        end)
        table.insert(recoilConnections, cConn)
    end
end

local noSpreadEnabled = false
local spreadConnections = {}

local function applyNoSpread(tool)
    if not tool:IsA("Tool") then return end

    local config = tool:FindFirstChild("Configuration")
    if not config then return end

    local inaccuracy = config:GetAttribute("inaccuracy")
    if inaccuracy ~= nil then
        config:SetAttribute("inaccuracy", 0)
    end
end

local function scanAndApplySpread(container)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        applyNoSpread(child)
    end
end

local function toggleNoSpread(value)
    noSpreadEnabled = value

    for _, conn in ipairs(spreadConnections) do
        conn:Disconnect()
    end
    spreadConnections = {}

    if not noSpreadEnabled then return end

    local backpack = plr:FindFirstChild("Backpack")
    local char = plr.Character

    if backpack then scanAndApplySpread(backpack) end
    if char then scanAndApplySpread(char) end

    if backpack then
        local bConn = backpack.ChildAdded:Connect(function(child)
            task.wait(0.1)
            applyNoSpread(child)
        end)
        table.insert(spreadConnections, bConn)
    end

    local charAddedConn = plr.CharacterAdded:Connect(function(newChar)
        local cConn = newChar.ChildAdded:Connect(function(child)
            task.wait(0.1)
            applyNoSpread(child)
        end)
        table.insert(spreadConnections, cConn)
        scanAndApplySpread(newChar)
    end)
    table.insert(spreadConnections, charAddedConn)

    if char then
        local cConn = char.ChildAdded:Connect(function(child)
            task.wait(0.1)
            applyNoSpread(child)
        end)
        table.insert(spreadConnections, cConn)
    end
end

local function updateQuickBinPrompts(targetDuration)
    local bins = workspace:FindFirstChild("unorganized map bins", true)
    if not bins then return end

    for _, binGroup in ipairs(bins:GetChildren()) do
        if binGroup.Name == "Binx2" or binGroup.Name == "Binx3" then
            for _, binColor in ipairs(binGroup:GetChildren()) do
                if binColor.Name == "BinRed" or binColor.Name == "BinGreen" or binColor.Name == "BinBlue" then
                    local proximity = binColor:FindFirstChild("Proximity")
                    local prompt = proximity and proximity:FindFirstChild("ProximityPrompt")
                    if prompt and prompt:IsA("ProximityPrompt") then
                        prompt.HoldDuration = targetDuration
                    end
                end
            end
        end
    end
end

local function updateQuickBins(value)
    updateQuickBinPrompts(value and 0 or 5)
end

local quickRopeConnection = nil

local function updateQuickRope(value)
    local targetDuration = value and 0 or 5

    local map = workspace:FindFirstChild("Map")
    if not map then return end
    local functional = map:FindFirstChild("Functional")
    if not functional then return end
    local ropesDir = functional:FindFirstChild("Ropes")
    if not ropesDir then return end

    local ropeManager = ropesDir:FindFirstChild("RopeManager")
    if ropeManager then
        local rmPrompt = ropeManager:FindFirstChild("RopePrompt")
        if rmPrompt and rmPrompt:IsA("ProximityPrompt") then
            rmPrompt.HoldDuration = targetDuration
        end
    end

    local function updateRopeModel(ropeModel)
        if ropeModel.Name == "Rope" then
            local truss = ropeModel:FindFirstChild("Truss")
            if truss then
                local point = truss:FindFirstChild("Point")
                if point then
                    local rPrompt = point:FindFirstChild("RopePrompt")
                    if rPrompt and rPrompt:IsA("ProximityPrompt") then
                        rPrompt.HoldDuration = targetDuration
                    end
                end
            end
        end
    end

    for _, child in ipairs(ropesDir:GetChildren()) do
        updateRopeModel(child)
    end

    if quickRopeConnection then
        quickRopeConnection:Disconnect()
        quickRopeConnection = nil
    end

    if value then
        quickRopeConnection = ropesDir.ChildAdded:Connect(function(child)
            task.wait(0.1)
            updateRopeModel(child)
        end)
    end
end

local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local aimassistEnabled = false
local fovCircleEnabled = false
local fovRadius = 100
local fovTransparency = 1
local aimSmoothness = 0
local targetBodyPart = "Head"

local aimassistConnection = nil
local fovCircle = nil

if Drawing and Drawing.new then
    fovCircle = Drawing.new("Circle")
    fovCircle.Visible = false
    fovCircle.Thickness = 1.5
    fovCircle.Color = Color3.fromRGB(255, 255, 255)
    fovCircle.Transparency = fovTransparency
    fovCircle.Filled = false
    fovCircle.Radius = fovRadius
end

local function isVisible(targetChar, targetPart)
    if not targetChar or not targetPart then return false end
    
    local origin = camera.CFrame.Position
    local destination = targetPart.Position
    local direction = destination - origin

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local filter = { camera }
    if plr.Character then
        table.insert(filter, plr.Character)
    end
    raycastParams.FilterDescendantsInstances = filter
    raycastParams.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, raycastParams)
    if result then
        if result.Instance:IsDescendantOf(targetChar) then
            return true
        end
        return false
    end
    return true
end

local function getScreenCenter()
    return Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

local function getTargetPart(char)
    if not char then return nil end
    if targetBodyPart == "Body" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    else
        return char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
    end
end

local targetUsersList = {}

local function getClosestTarget()
    local targetTeams = getTargetTeams()
    local centerPos = getScreenCenter()
    local closestPart = nil
    local shortestDistance = fovRadius
    
    local myTeam = plr.Team and plr.Team.Name or ""
    local amIPolice = (myTeam == "Department of Corrections" or myTeam == "State Police")

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= plr then
            local isManualTarget = false
            for _, targetName in ipairs(targetUsersList) do
                if string.lower(player.Name) == string.lower(targetName) or string.lower(player.DisplayName) == string.lower(targetName) then
                    isManualTarget = true
                    break
                end
            end

            local playerTeam = player.Team and player.Team.Name or ""
            
            local isPrisoner = (playerTeam == "Maximum Security" or playerTeam == "Medium Security" or playerTeam == "Minimum Security" or playerTeam == "Booking")
            local hasContraband = false
            if isPrisoner then
                hasContraband = hasToggleInnocence(player)
            end

            local isValidTarget = false
            if isManualTarget then
                isValidTarget = true
            elseif targetTeams[playerTeam] then
                isValidTarget = true
            elseif amIPolice and hasContraband then
                isValidTarget = true
            end

            if isValidTarget then
                local char = player.Character
                if char then
                    local targetPart = getTargetPart(char)
                    local humanoid = char:FindFirstChildOfClass("Humanoid")

                    if targetPart and humanoid and humanoid.Health > 0 then
                        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                            local dist = (screenVec - centerPos).Magnitude

                            if dist <= shortestDistance then
                                if isVisible(char, targetPart) then
                                    shortestDistance = dist
                                    closestPart = targetPart
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return closestPart
end

local function isHoldingGun()
    local char = plr.Character
    if not char then return false end
    local equippedTool = char:FindFirstChildOfClass("Tool")
    if equippedTool and equippedTool:FindFirstChild("Recoil") then
        return true
    end
    return false
end

local function toggleAimassist(value)
    aimassistEnabled = value

    if aimassistConnection then
        aimassistConnection:Disconnect()
        aimassistConnection = nil
    end

    if lockedTargetPlayer then
        local oldTarget = lockedTargetPlayer
        lockedTargetPlayer = nil
        if oldTarget then updatePlayerChams(oldTarget) end
    end

    if fovCircle then
        fovCircle.Visible = aimassistEnabled and fovCircleEnabled
    end

    if aimassistEnabled then
        aimassistConnection = runService.RenderStepped:Connect(function()
            local centerPos = getScreenCenter()
            if fovCircle then
                fovCircle.Position = centerPos
                fovCircle.Radius = fovRadius
                fovCircle.Visible = fovCircleEnabled
            end

            if userInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) and isHoldingGun() then
                local targetPart = getClosestTarget()
                local newLockedPlayer = nil

                if targetPart and targetPart.Parent then
                    newLockedPlayer = players:GetPlayerFromCharacter(targetPart.Parent)
                    local currentCFrame = camera.CFrame
                    local targetCFrame = CFrame.new(currentCFrame.Position, targetPart.Position)
                    if aimSmoothness == 0 then
                        camera.CFrame = targetCFrame
                    else
                        local smoothFactor = math.clamp(1 / math.max(1, aimSmoothness), 0.05, 1)
                        camera.CFrame = currentCFrame:Lerp(targetCFrame, smoothFactor)
                    end
                end

                if lockedTargetPlayer ~= newLockedPlayer then
                    local oldTarget = lockedTargetPlayer
                    lockedTargetPlayer = newLockedPlayer
                    if oldTarget then updatePlayerChams(oldTarget) end
                    if newLockedPlayer then updatePlayerChams(newLockedPlayer) end
                end
            else
                if lockedTargetPlayer then
                    local oldTarget = lockedTargetPlayer
                    lockedTargetPlayer = nil
                    if oldTarget then updatePlayerChams(oldTarget) end
                end
            end
        end)
    end
end

local noSprayThread = nil

local function toggleNoSpray(value)
    if noSprayThread then
        task.cancel(noSprayThread)
        noSprayThread = nil
    end

    local function setSprayClientDisabled(disabled)
        local playerGui = plr:FindFirstChildOfClass("PlayerGui")
        local weaponEffects = playerGui and playerGui:FindFirstChild("WeaponEffects")
        local sprayClient = weaponEffects and weaponEffects:FindFirstChild("SprayClient")
        if sprayClient and sprayClient:IsA("LocalScript") then
            sprayClient.Disabled = disabled
        end
    end

    if not value then
        setSprayClientDisabled(false)
        return
    end

    noSprayThread = task.spawn(function()
        while true do
            setSprayClientDisabled(true)
            task.wait(0.05)
        end
    end)
end

-- AntiAFK toggle function
local antiAfkConnection = nil
local antiAfkDisabledConnections = {}

local function AntiAFK(enabled)
    local player = game:GetService("Players").LocalPlayer

    if enabled then
        -- Clean up any previous state first
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end

        if getconnections then
            -- Disable Roblox's built-in idle-kick handlers
            antiAfkDisabledConnections = {}
            for _, connection in pairs(getconnections(player.Idled)) do
                if connection["Disable"] then
                    connection["Disable"](connection)
                    table.insert(antiAfkDisabledConnections, {conn = connection, method = "Enable"})
                elseif connection["Disconnect"] then
                    connection["Disconnect"](connection)
                    -- Note: once Disconnect()'d, it can't be re-enabled;
                    -- only tracked here for completeness
                end
            end
        else
            -- Fallback: simulate input whenever Idled fires
            antiAfkConnection = player.Idled:Connect(function()
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end

    else
        -- Turn it back off
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end

        if getconnections then
            for _, entry in pairs(antiAfkDisabledConnections) do
                if entry.conn[entry.method] then
                    entry.conn[entry.method](entry.conn)
                end
            end
            antiAfkDisabledConnections = {}
        end
    end
end

local window = Rayfield:CreateWindow({
    name = "Valley Prison Phantom",
    subtitle = "By outtee",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "ValleyPrisonCFG",
        customFolder = "Phantom",
    },
    sidebarLayout = "true",
    showIconOnly = "true",
})

local main = window:CreateTab({ name = "Main" })
local combat = window:CreateTab({ name = "Combat" })
local guns = window:CreateTab({ name = "Guns" })
local playerT = window:CreateTab({ name = "Player" })
local visual = window:CreateTab({ name = "Visuals" })
local misc = window:CreateTab({ name = "Misc" })


local quickbinsToggle = main:CreateToggle({
    name = "Quick Bins",
    flag = "QuickBins",
    value = false,
    callback = function(value)
        updateQuickBins(value)
    end,
})

local quickropeToggle = main:CreateToggle({
    name = "Quick Rope",
    flag = "QuickRope",
    value = false,
    callback = function(value)
        updateQuickRope(value)
    end,
})

local aimassistToggle = combat:CreateToggle({
    name = "Aim Assist",
    flag = "AimAssist",
    value = false,
    callback = function(value)
        toggleAimassist(value)
    end,
})

local targetUsersInput = combat:CreateInput({
    name = "Target Users",
    placeholder = "username1, username2...",
    flag = "TargetUsers",
    callback = function(text)
        targetUsersList = {}
        if text and text ~= "" then
            for name in string.gmatch(text, "([^,]+)") do
                local cleanName = string.match(name, "^%s*(.-)%s*$")
                if cleanName and cleanName ~= "" then
                    table.insert(targetUsersList, cleanName)
                end
            end
        end
    end,
})

local targetPartDropdown = combat:CreateDropdown({
    name = "Target Part",
    flag = "TargetPart",
    options = { "Head", "Body" },
    value = "Head",
    callback = function(selected)
        if type(selected) == "table" then
            targetBodyPart = selected[1] or "Head"
        else
            targetBodyPart = selected or "Head"
        end
    end,
})

local fovToggle = combat:CreateToggle({
    name = "Show FOV Circle",
    flag = "ShowFOVCircle",
    value = false,
    callback = function(value)
        fovCircleEnabled = value
        if fovCircle then
            fovCircle.Visible = aimassistEnabled and fovCircleEnabled
        end
    end,
})

local fovSlider = combat:CreateSlider({
    name = "FOV Size",
    flag = "FOVSize",
    range = { 30, 500 },
    increment = 5,
    value = 100,
    suffix = "px",
    callback = function(value)
        fovRadius = value
        if fovCircle then
            fovCircle.Radius = value
        end
    end,
})

local fovTransparencySlider = combat:CreateSlider({
    name = "FOV Transparency",
    flag = "FOVTransparency",
    range = { 0, 1 },
    increment = 0.1,
    value = 1,
    suffix = "",
    callback = function(value)
        fovTransparency = value
        if fovCircle then
            fovCircle.Transparency = fovTransparency
        end
    end,
})

local norecoil = guns:CreateToggle({
    name = "No Recoil",
    flag = "NoRecoil",
    value = false,
    callback = function(value)
        toggleNoRecoil(value)
    end,
})

local nospread = guns:CreateToggle({
    name = "No Spread",
    flag = "NoSpread",
    value = false,
    callback = function(value)
        toggleNoSpread(value)
    end,
})

local infstamina = playerT:CreateToggle({
    name = "Infinite Stamina",
    flag = "InfStamina",
    value = false,
    callback = function(value)
        infstam(value)
    end,
})

local nospray = playerT:CreateToggle({
    name = "No OC Spray Overlay",
    flag = "NoSpray",
    value = false,
    callback = function(value)
        toggleNoSpray(value)
    end,
})

local chams = visual:CreateToggle({
    name = "Team Chams",
    flag = "TeamChams",
    value = false,
    callback = function(value)
        toggleChams(value)
    end,
})


local targetChamsInput = visual:CreateInput({
    name = "Target Chams",
    placeholderText = "username1, username2...",
    flag = "TargetChams",
    removeTextAfterFocusLost = false,
    callback = function(text)
        targetChamsList = {}
        if text and text ~= "" then
            for name in string.gmatch(text, "([^,]+)") do
                local cleanName = string.match(name, "^%s*(.-)%s*$")
                if cleanName and cleanName ~= "" then
                    table.insert(targetChamsList, cleanName)
                end
            end
        end
        refreshAllChams()
    end,
})

local fillSlider = visual:CreateSlider({
    name = "Chams Fill Opacity",
    flag = "ChamsFillOpacity",
    range = { 0, 100 },
    increment = 1,
    value = 50,
    suffix = "%",
    callback = function(value)
        fillOpacity = value
        refreshAllChams()
    end,
})

local outlineSlider = visual:CreateSlider({
    name = "Chams Outline Opacity",
    flag = "ChamsOutlineOpacity",
    range = { 0, 100 },
    increment = 1,
    value = 80,
    suffix = "%",
    callback = function(value)
        outlineOpacity = value
        refreshAllChams()
    end,
})

local antiafkToggle = misc:CreateToggle({
    name = "Anti-AFK",
    flag = "AntiAFK",
    value = false,
    callback = function(value)
        AntiAFK(value)
    end,
})

local dex = misc:CreateButton({
    name = "Load Dex Explorer",
    callback = function()
        loadstring(game:HttpGet("https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua"))()
    end,
})

local destroy = misc:CreateButton({
    name = "Unload UI",
    description = "Removes UI and turns off all features.",
    callback = function()
        AntiAFK(false)
        infstam(false)
        toggleNoSpray(false)
        updateQuickBins(false)
        updateQuickRope(false)
        toggleChams(false)
        toggleNoRecoil(false)
        toggleNoSpread(false)
        toggleAimassist(false)
        if fovCircle then
            fovCircle:Remove()
            fovCircle = nil
        end
        window:Unload()
    end,
})