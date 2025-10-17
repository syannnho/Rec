local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Folder Setup
local mainFolder = "AutoWalk"
if not isfolder(mainFolder) then
    makefolder(mainFolder)
end

-- Variables
local isRecording = false
local isPlaying = false
local recordedData = {}
local recordingStartTime = 0
local playbackStartTime = 0
local playbackConnection = nil
local checkpointButtons = {}
local scrollingFrame = nil

-- God Mode Variables
local godModeActive = false
local originalHealth = 100
local healthConnection = nil
local stateConnection = nil

-- FPS Independent Playback Variables
local lastPlaybackTime = 0
local accumulatedTime = 0

-- Landing/Jump State Variables
local lastGroundedState = false
local landingCooldown = 0
local jumpCooldown = 0

-- GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoWalkGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.Active = true
mainFrame.Parent = screenGui

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.BackgroundTransparency = 1
title.Text = "Auto Walk System"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -32, 0, 2.5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 18
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = titleBar

-- Drag functionality
local dragging = false
local dragInput, mousePos, framePos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        mousePos = input.Position
        framePos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

RunService.Heartbeat:Connect(function()
    if dragging and dragInput then
        local delta = dragInput.Position - mousePos
        mainFrame.Position = UDim2.new(
            framePos.X.Scale,
            framePos.X.Offset + delta.X,
            framePos.Y.Scale,
            framePos.Y.Offset + delta.Y
        )
    end
end)

local controlFrame = Instance.new("Frame")
controlFrame.Size = UDim2.new(1, -20, 0, 180)
controlFrame.Position = UDim2.new(0, 10, 0, 45)
controlFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
controlFrame.BorderSizePixel = 1
controlFrame.BorderColor3 = Color3.fromRGB(70, 70, 70)
controlFrame.Parent = mainFrame

local recordButton = Instance.new("TextButton")
recordButton.Size = UDim2.new(1, -20, 0, 35)
recordButton.Position = UDim2.new(0, 10, 0, 10)
recordButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
recordButton.BorderSizePixel = 1
recordButton.BorderColor3 = Color3.fromRGB(200, 200, 200)
recordButton.Text = "🔴 Record: OFF (Press F)"
recordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
recordButton.TextSize = 14
recordButton.Font = Enum.Font.Gotham
recordButton.Parent = controlFrame

local stopWalkButton = Instance.new("TextButton")
stopWalkButton.Size = UDim2.new(1, -20, 0, 35)
stopWalkButton.Position = UDim2.new(0, 10, 0, 50)
stopWalkButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
stopWalkButton.BorderSizePixel = 1
stopWalkButton.BorderColor3 = Color3.fromRGB(255, 100, 100)
stopWalkButton.Text = "🛑 STOP WALK"
stopWalkButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopWalkButton.TextSize = 14
stopWalkButton.Font = Enum.Font.GothamBold
stopWalkButton.Visible = false
stopWalkButton.Parent = controlFrame

local saveInput = Instance.new("TextBox")
saveInput.Size = UDim2.new(0.6, -10, 0, 35)
saveInput.Position = UDim2.new(0, 10, 0, 90)
saveInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
saveInput.BorderSizePixel = 1
saveInput.BorderColor3 = Color3.fromRGB(150, 150, 150)
saveInput.PlaceholderText = "checkpoint name..."
saveInput.Text = ""
saveInput.TextColor3 = Color3.fromRGB(255, 255, 255)
saveInput.TextSize = 12
saveInput.Font = Enum.Font.Gotham
saveInput.Parent = controlFrame

local saveButton = Instance.new("TextButton")
saveButton.Size = UDim2.new(0.4, -15, 0, 35)
saveButton.Position = UDim2.new(0.6, 5, 0, 90)
saveButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
saveButton.BorderSizePixel = 1
saveButton.BorderColor3 = Color3.fromRGB(100, 200, 100)
saveButton.Text = "💾 Save"
saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
saveButton.TextSize = 12
saveButton.Font = Enum.Font.GothamBold
saveButton.Parent = controlFrame

local refreshButton = Instance.new("TextButton")
refreshButton.Size = UDim2.new(1, -20, 0, 30)
refreshButton.Position = UDim2.new(0, 10, 0, 135)
refreshButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
refreshButton.BorderSizePixel = 1
refreshButton.BorderColor3 = Color3.fromRGB(100, 150, 255)
refreshButton.Text = "🔄 Refresh Checkpoints"
refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshButton.TextSize = 12
refreshButton.Font = Enum.Font.GothamBold
refreshButton.Parent = controlFrame

local listLabel = Instance.new("TextLabel")
listLabel.Size = UDim2.new(1, -20, 0, 25)
listLabel.Position = UDim2.new(0, 10, 0, 235)
listLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
listLabel.BorderSizePixel = 0
listLabel.Text = "📍 Saved Checkpoints"
listLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
listLabel.TextSize = 14
listLabel.Font = Enum.Font.GothamBold
listLabel.Parent = mainFrame

scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, -20, 1, -270)
scrollingFrame.Position = UDim2.new(0, 10, 0, 260)
scrollingFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
scrollingFrame.BorderSizePixel = 1
scrollingFrame.BorderColor3 = Color3.fromRGB(70, 70, 70)
scrollingFrame.ScrollBarThickness = 6
scrollingFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = scrollingFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 1, -20)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready | Press F to Record"
statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- Utility
local function vecToTable(v3)
    return {x = v3.X, y = v3.Y, z = v3.Z}
end

local function tableToVec(t)
    return Vector3.new(t.x, t.y, t.z)
end

local function updateStatus(text, color)
    statusLabel.Text = text
    statusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
end

-- Improved lerp helpers
local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpVector(a, b, t)
    return Vector3.new(lerp(a.X, b.X, t), lerp(a.Y, b.Y, t), lerp(a.Z, b.Z, t))
end

local function lerpAngle(a, b, t)
    local diff = (b - a)
    while diff > math.pi do diff = diff - 2*math.pi end
    while diff < -math.pi do diff = diff + 2*math.pi end
    return a + diff * t
end

-- Ground detection helper
local function isNearGround(pos, threshold)
    threshold = threshold or 3
    local rayOrigin = pos + Vector3.new(0, 1, 0)
    local rayDirection = Vector3.new(0, -threshold - 1, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    return result ~= nil, result and result.Position or nil
end

-- GOD MODE FUNCTIONS
local function enableGodMode()
    if godModeActive then return end
    
    godModeActive = true
    
    if not humanoid then return end
    
    originalHealth = humanoid.MaxHealth
    humanoid.MaxHealth = math.huge
    humanoid.Health = math.huge
    
    if healthConnection then healthConnection:Disconnect() end
    healthConnection = humanoid.HealthChanged:Connect(function(health)
        if godModeActive and health < math.huge then
            humanoid.Health = math.huge
        end
    end)
    
    if stateConnection then stateConnection:Disconnect() end
    stateConnection = humanoid.StateChanged:Connect(function(old, new)
        if not godModeActive then return end
        
        if new == Enum.HumanoidStateType.FallingDown or
           new == Enum.HumanoidStateType.Ragdoll or
           new == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
    
    if humanoidRootPart then
        humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
    
    updateStatus("🛡️ God Mode: ACTIVE", Color3.fromRGB(255, 215, 0))
end

local function disableGodMode()
    if not godModeActive then return end
    
    godModeActive = false
    
    if healthConnection then
        healthConnection:Disconnect()
        healthConnection = nil
    end
    
    if stateConnection then
        stateConnection:Disconnect()
        stateConnection = nil
    end
    
    if humanoid then
        humanoid.MaxHealth = originalHealth
        humanoid.Health = originalHealth
    end
    
    updateStatus("🛡️ God Mode: OFF", Color3.fromRGB(150, 150, 150))
end

-- File save/load
local function saveCheckpoint(name)
    if #recordedData == 0 then
        updateStatus("No recording to save!", Color3.fromRGB(255, 100, 100))
        return false
    end
    
    local fileName = name .. ".json"
    local filePath = mainFolder .. "/" .. fileName
    
    local success, err = pcall(function()
        local jsonData = HttpService:JSONEncode(recordedData)
        writefile(filePath, jsonData)
    end)
    
    if success then
        updateStatus("Saved: " .. name, Color3.fromRGB(150, 255, 150))
        return true
    else
        updateStatus("Save failed!", Color3.fromRGB(255, 100, 100))
        warn("Save error:", err)
        return false
    end
end

local function loadCheckpoint(name)
    local fileName = name .. ".json"
    local filePath = mainFolder .. "/" .. fileName
    
    if not isfile(filePath) then
        updateStatus("File not found!", Color3.fromRGB(255, 100, 100))
        return nil
    end
    
    local success, result = pcall(function()
        local jsonData = readfile(filePath)
        return HttpService:JSONDecode(jsonData)
    end)
    
    if success then
        updateStatus("Loaded: " .. name, Color3.fromRGB(150, 255, 150))
        return result
    else
        updateStatus("Load failed!", Color3.fromRGB(255, 100, 100))
        warn("Load error:", result)
        return nil
    end
end

-- Recording controls
local function startRecording()
    if isPlaying then
        updateStatus("Stop playback first!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    isRecording = true
    recordedData = {}
    recordingStartTime = tick()
    
    recordButton.Text = "🔴 Recording... (Press F)"
    recordButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    updateStatus("Recording...", Color3.fromRGB(255, 100, 100))
end

local function stopRecording()
    isRecording = false
    
    recordButton.Text = "🔴 Record: OFF (Press F)"
    recordButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    updateStatus("Stopped - " .. #recordedData .. " frames", Color3.fromRGB(150, 255, 150))
end

-- Improved frame finding with binary search for better performance
local function findSurroundingFrames(data, t)
    if #data == 0 then
        return nil, nil, 0
    end
    
    if t <= data[1].time then
        return 1, 1, 0
    end
    
    if t >= data[#data].time then
        return #data, #data, 0
    end
    
    -- Binary search for efficiency
    local left, right = 1, #data
    while left < right - 1 do
        local mid = math.floor((left + right) / 2)
        if data[mid].time <= t then
            left = mid
        else
            right = mid
        end
    end
    
    local i0, i1 = left, right
    local span = data[i1].time - data[i0].time
    local alpha = span > 0 and math.clamp((t - data[i0].time) / span, 0, 1) or 0
    
    return i0, i1, alpha
end

-- Improved playback with better jump/landing handling
local function stopPlayback()
    isPlaying = false
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    disableGodMode()
    stopWalkButton.Visible = false
    
    if character and humanoid then
        humanoid:Move(Vector3.new(0, 0, 0), false)
        -- Reset to normal walking state
        if humanoid:GetState() ~= Enum.HumanoidStateType.Running and 
           humanoid:GetState() ~= Enum.HumanoidStateType.RunningNoPhysics then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
    
    lastGroundedState = false
    landingCooldown = 0
    jumpCooldown = 0
    
    updateStatus("Playback stopped", Color3.fromRGB(150, 255, 150))
end

local function startPlayback(data)
    if not data or #data == 0 then
        updateStatus("No data to play!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if isRecording then
        updateStatus("Stop recording first!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if isPlaying then
        stopPlayback()
    end
    
    enableGodMode()
    
    -- Instant teleport to start position
    if character and character:FindFirstChild("HumanoidRootPart") and data[1] then
        local firstFrame = data[1]
        local startPos = tableToVec(firstFrame.position)
        local startYaw = firstFrame.rotation or 0
        
        local hrp = character.HumanoidRootPart
        hrp.CFrame = CFrame.new(startPos) * CFrame.Angles(0, startYaw, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        updateStatus("🛡️ Teleported + God Mode ON", Color3.fromRGB(255, 215, 0))
        task.wait(0.1)
    end
    
    isPlaying = true
    playbackStartTime = tick()
    lastPlaybackTime = playbackStartTime
    accumulatedTime = 0
    
    updateStatus("Playing with God Mode...", Color3.fromRGB(100, 255, 100))
    stopWalkButton.Visible = true
    
    local lastJumping = false
    local lastYVelocity = 0
    local wasFalling = false
    lastGroundedState = true
    landingCooldown = 0
    jumpCooldown = 0
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    -- Use Heartbeat for more consistent timing across different FPS
    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not isPlaying then return end
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        if not humanoid or humanoid.Parent ~= character then
            humanoid = character:FindFirstChild("Humanoid")
        end
        
        -- Decrease cooldowns
        if landingCooldown > 0 then
            landingCooldown = landingCooldown - deltaTime
        end
        if jumpCooldown > 0 then
            jumpCooldown = jumpCooldown - deltaTime
        end
        
        -- FPS-independent time tracking using deltaTime
        local currentTime = tick()
        local actualDelta = currentTime - lastPlaybackTime
        lastPlaybackTime = currentTime
        
        -- Clamp delta to prevent huge jumps on lag spikes
        actualDelta = math.min(actualDelta, 0.1)
        accumulatedTime = accumulatedTime + actualDelta
        
        local totalDuration = data[#data].time
        
        if accumulatedTime > totalDuration then
            local final = data[#data]
            if character and character:FindFirstChild("HumanoidRootPart") then
                local hrp = character.HumanoidRootPart
                local finalPos = tableToVec(final.position)
                local finalYaw = final.rotation or 0
                local targetCFrame = CFrame.new(finalPos) * CFrame.Angles(0, finalYaw, 0)
                hrp.CFrame = targetCFrame
                if humanoid then
                    humanoid:Move(tableToVec(final.moveDirection or {x=0,y=0,z=0}), false)
                end
            end
            stopPlayback()
            return
        end
        
        local i0, i1, alpha = findSurroundingFrames(data, accumulatedTime)
        local f0, f1 = data[i0], data[i1]
        if not f0 or not f1 then return end
        
        local pos0 = tableToVec(f0.position)
        local pos1 = tableToVec(f1.position)
        local vel0 = tableToVec(f0.velocity or {x=0,y=0,z=0})
        local vel1 = tableToVec(f1.velocity or {x=0,y=0,z=0})
        local move0 = tableToVec(f0.moveDirection or {x=0,y=0,z=0})
        local move1 = tableToVec(f1.moveDirection or {x=0,y=0,z=0})
        local yaw0 = f0.rotation or 0
        local yaw1 = f1.rotation or 0
        
        local state0 = f0.state or "Running"
        local state1 = f1.state or "Running"
        
        -- Smooth interpolation
        local interpPos = lerpVector(pos0, pos1, alpha)
        local interpVel = lerpVector(vel0, vel1, alpha)
        local interpMove = lerpVector(move0, move1, alpha)
        local interpYaw = lerpAngle(yaw0, yaw1, alpha)
        
        local hrp = character.HumanoidRootPart
        local targetCFrame = CFrame.new(interpPos) * CFrame.Angles(0, interpYaw, 0)
        
        -- Detect if we're supposed to be grounded based on state
        local shouldBeGrounded = (state0 == "Running" or state0 == "RunningNoPhysics" or state0 == "Landed") and
                                  (state1 == "Running" or state1 == "RunningNoPhysics" or state1 == "Landed")
        
        -- Check actual ground proximity
        local nearGround, groundPos = isNearGround(interpPos, 4)
        
        -- Improved position update with ground snapping
        if shouldBeGrounded and nearGround and landingCooldown <= 0 then
            -- Snap to ground when we should be grounded
            local lerpFactor = math.clamp(1 - math.exp(-15 * actualDelta), 0, 1)
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, lerpFactor)
            
            -- Nullify Y velocity when grounded
            if interpVel.Y < 0 then
                interpVel = Vector3.new(interpVel.X, 0, interpVel.Z)
            end
            
            -- Force grounded state if needed
            if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
                humanoid:ChangeState(Enum.HumanoidStateType.Landed)
                task.wait()
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
            
            lastGroundedState = true
        else
            -- Normal interpolation when in air
            local lerpFactor = math.clamp(1 - math.exp(-12 * actualDelta), 0, 1)
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, lerpFactor)
            lastGroundedState = false
        end
        
        -- Apply velocity with improved Y handling
        pcall(function()
            local currentVel = hrp.AssemblyLinearVelocity
            -- Smooth Y velocity to prevent jittering
            local smoothedYVel = lerp(currentVel.Y, interpVel.Y, 0.7)
            
            -- Detect landing
            if lastYVelocity < -5 and smoothedYVel > -2 and nearGround then
                landingCooldown = 0.3 -- Cooldown after landing
                smoothedYVel = 0
                if humanoid:GetState() ~= Enum.HumanoidStateType.Running then
                    humanoid:ChangeState(Enum.HumanoidStateType.Landed)
                    task.wait(0.05)
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
            
            hrp.AssemblyLinearVelocity = Vector3.new(interpVel.X, smoothedYVel, interpVel.Z)
            lastYVelocity = smoothedYVel
        end)
        
        if humanoid then
            humanoid:Move(interpMove, false)
        end
        
        -- Improved jump handling
        local jumpingNow = f0.jumping or false
        if f1.jumping then
            jumpingNow = true
        end
        
        -- Only trigger jump if not recently jumped and currently grounded
        if jumpingNow and not lastJumping and jumpCooldown <= 0 then
            local currentState = humanoid:GetState()
            if currentState == Enum.HumanoidStateType.Running or 
               currentState == Enum.HumanoidStateType.RunningNoPhysics or
               currentState == Enum.HumanoidStateType.Landed or
               nearGround then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                jumpCooldown = 0.5 -- Prevent double jumping
            end
        end
        lastJumping = jumpingNow
    end)
end

-- GUI helpers
local function createCheckpointButton(checkpointName)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 40)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.fromRGB(150, 150, 150)
    button.Text = "▶️ " .. checkpointName
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 13
    button.Font = Enum.Font.Gotham
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.TextTruncate = Enum.TextTruncate.AtEnd
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.Parent = button
    
    button.MouseButton1Click:Connect(function()
        local data = loadCheckpoint(checkpointName)
        if data then
            startPlayback(data)
        end
    end)
    
    button.Parent = scrollingFrame
    return button
end

local function refreshCheckpointList()
    for _, btn in pairs(checkpointButtons) do
        btn:Destroy()
    end
    checkpointButtons = {}
    
    local files = listfiles(mainFolder)
    local count = 0
    
    for _, filePath in pairs(files) do
        if filePath:match("%.json$") then
            local fileName = filePath:match("([^/\\]+)%.json$")
            if fileName then
                checkpointButtons[fileName] = createCheckpointButton(fileName)
                count = count + 1
            end
        end
    end
    
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, count * 45)
    updateStatus("Found " .. count .. " checkpoints", Color3.fromRGB(150, 255, 150))
end

-- Button Events
recordButton.MouseButton1Click:Connect(function()
    if isRecording then
        stopRecording()
    else
        startRecording()
    end
end)

-- Keybind F untuk toggle recording
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F then
        if isRecording then
            stopRecording()
        else
            startRecording()
        end
    end
end)

stopWalkButton.MouseButton1Click:Connect(function()
    if isPlaying then
        stopPlayback()
        updateStatus("Walk stopped by user", Color3.fromRGB(255, 200, 100))
    end
end)

saveButton.MouseButton1Click:Connect(function()
    local name = saveInput.Text:gsub("%s+", "_")
    if name ~= "" then
        if saveCheckpoint(name) then
            saveInput.Text = ""
            task.wait(0.5)
            refreshCheckpointList()
        end
    else
        updateStatus("Enter checkpoint name!", Color3.fromRGB(255, 100, 100))
    end
end)

refreshButton.MouseButton1Click:Connect(function()
    refreshCheckpointList()
end)

closeButton.MouseButton1Click:Connect(function()
    if isRecording then stopRecording() end
    if isPlaying then stopPlayback() end
    disableGodMode()
    screenGui:Destroy()
end)

-- Improved Recording Loop with state tracking
RunService.Heartbeat:Connect(function()
    if not isRecording then return end
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = character.HumanoidRootPart
    local hum = character:FindFirstChild("Humanoid")
    
    if hrp and hum then
        local currentTime = tick() - recordingStartTime
        local _, y, _ = hrp.CFrame:ToOrientation()
        
        -- Get current humanoid state as string for better tracking
        local currentState = hum:GetState()
        local stateString = "Running"
        
        if currentState == Enum.HumanoidStateType.Jumping then
            stateString = "Jumping"
        elseif currentState == Enum.HumanoidStateType.Freefall then
            stateString = "Freefall"
        elseif currentState == Enum.HumanoidStateType.Flying then
            stateString = "Flying"
        elseif currentState == Enum.HumanoidStateType.Landed then
            stateString = "Landed"
        elseif currentState == Enum.HumanoidStateType.RunningNoPhysics then
            stateString = "RunningNoPhysics"
        end
        
        local frameData = {
            time = currentTime,
            position = vecToTable(hrp.Position),
            rotation = y,
            velocity = vecToTable(hrp.AssemblyLinearVelocity),
            moveDirection = vecToTable(hum.MoveDirection),
            jumping = currentState == Enum.HumanoidStateType.Jumping,
            state = stateString, -- Added state tracking
        }
        
        table.insert(recordedData, frameData)
    end
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    if isRecording then stopRecording() end
    if isPlaying then stopPlayback() end
    disableGodMode()
end)

-- Initial load
refreshCheckpointList()
