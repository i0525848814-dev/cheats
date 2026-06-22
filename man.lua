 -- [[ SWILL HUB PRO v3.6 - VISCHECK & TOGGLE FIX ]] --
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- Глобальные настройки
local Settings = {
    WalkSpeed = 16,
    AimbotEnabled = true,
    AimbotMode = "Hold", -- "Hold" (ПКМ) или "Toggle" (Нажатие клавиши F)
    AimbotActive = false,
    ESPEnabled = true,
    ESPBoxes = false, 
    ESPNames = true,  
    TeamCheck = true,
    CurrentGame = nil
}

local Binds = {
    Menu = Enum.KeyCode.RightShift,
    AimbotToggle = Enum.KeyCode.F
}

-- Внутренние утилиты
local function SetSpeed(val)
    Settings.WalkSpeed = val
end

local function IsEnemy(player)
    if not Settings.TeamCheck then return true end
    return player.Team ~= LocalPlayer.Team
end

-- ==========================================
-- ВАЛЛ-ЧЕК (ПРОВЕРКА НА ВИДИМОСТЬ)
-- ==========================================
local function IsVisible(targetPart, targetCharacter)
    if not LocalPlayer.Character or not targetCharacter then return false end
    
    -- Игнорируем себя, цель и саму камеру при просчете стен
    local ignoreList = {LocalPlayer.Character, targetCharacter, Camera}
    local obscuringParts = Camera:GetPartsObscuringTarget({targetPart.Position}, ignoreList)
    
    -- Если между нами нет объектов, значит цель видна
    return #obscuringParts == 0
end

-- Защищенный контейнер для ESP элементов
local EspOverlay = Instance.new("ScreenGui")
EspOverlay.Name = "Swill_ProESP_Overlay"
EspOverlay.Parent = CoreGui
EspOverlay.ResetOnSpawn = false
EspOverlay.DisplayOrder = 999998

local function ClearAllESP()
    EspOverlay:ClearAllChildren()
end

-- Смут-драг система для меню
local function MakeDraggable(guiFrame)
    guiFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local dragStart = input.Position
            local frameStart = guiFrame.Position

            local connection
            connection = UserInputService.InputChanged:Connect(function(inputChanged)
                if inputChanged.UserInputType == Enum.UserInputType.MouseMovement then
                    local delta = inputChanged.Position - dragStart
                    guiFrame.Position = UDim2.new(
                        frameStart.X.Scale,
                        frameStart.X.Offset + delta.X,
                        frameStart.Y.Scale,
                        frameStart.Y.Offset + delta.Y
                    )
                end
            end)

            local endConnection
            endConnection = UserInputService.InputEnded:Connect(function(inputEnded)
                if inputEnded.UserInputType == Enum.UserInputType.MouseButton1 then
                    connection:Disconnect()
                    endConnection:Disconnect()
                end
            end)
        end
    end)
end

-- СВЕРХЛЕГКИЙ ESP (БЕЗ БОКСОВ)
RunService.RenderStepped:Connect(function()
    if not Settings.ESPEnabled then
        ClearAllESP()
        return
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
            local char = player.Character
            local hrp = char.HumanoidRootPart
            local hum = char.Humanoid
            
            if IsEnemy(player) and hum.Health > 0 then
                local head = char:FindFirstChild("Head")
                local targetPart = head or hrp
                local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position + Vector3.new(0, 2, 0))
                
                if onScreen then
                    local pContainer = EspOverlay:FindFirstChild(player.Name)
                    if not pContainer then
                        pContainer = Instance.new("Folder")
                        pContainer.Name = player.Name
                        pContainer.Parent = EspOverlay
                    end
                    
                    if Settings.ESPNames then
                        local textLabel = pContainer:FindFirstChild("NameTag")
                        if not textLabel then
                            textLabel = Instance.new("TextLabel")
                            textLabel.Name = "NameTag"
                            textLabel.BackgroundTransparency = 1
                            textLabel.Size = UDim2.fromOffset(200, 30)
                            textLabel.Font = Enum.Font.SourceSansBold
                            textLabel.TextSize = 14
                            textLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
                            textLabel.TextStrokeTransparency = 0
                            textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            textLabel.Parent = pContainer
                        end
                        textLabel.Visible = true
                        textLabel.Position = UDim2.fromOffset(pos.X - 100, pos.Y - 15)
                        textLabel.Text = string.format("%s [%d HP]", player.Name, math.floor(hum.Health))
                    else
                        if pContainer:FindFirstChild("NameTag") then pContainer.NameTag:Destroy() end
                    end
                else
                    if EspOverlay:FindFirstChild(player.Name) then EspOverlay[player.Name]:Destroy() end
                end
            else
                if EspOverlay:FindFirstChild(player.Name) then EspOverlay[player.Name]:Destroy() end
            end
        else
            if EspOverlay:FindFirstChild(player.Name) then EspOverlay[player.Name]:Destroy() end
        end
    end
end)

-- УЛУЧШЕННЫЙ АИМБОТ С ВАЛЛ-ЧЕКОМ
local function GetClosestPlayer()
    local closest = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsEnemy(player) and player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local head = player.Character.Head
            local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
            
            if onScreen then
                -- Проверка: виден ли игрок (не за стеной)
                if IsVisible(head, player.Character) then
                    local distance = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    if distance < shortestDistance then
                        closest = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if Settings.AimbotEnabled then
        local shouldAim = false
        
        if Settings.AimbotMode == "Hold" then
            shouldAim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif Settings.AimbotMode == "Toggle" then
            shouldAim = Settings.AimbotActive
        end

        if shouldAim then
            local target = GetClosestPlayer()
            if target and target.Character and target.Character:FindFirstChild("Head") then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.Head.Position)
            end
        end
    end
end)

-- Форсинг обхода скорости
RunService.Heartbeat:Connect(function()
    if Settings.WalkSpeed > 16 then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Settings.WalkSpeed
        end
    end
end)

-- ИНТЕРФЕЙС УПРАВЛЕНИЯ
local ControlFrame
local AimStatusBtn

local function LaunchControlPanel(gameName)
    Settings.CurrentGame = gameName
    Settings.AimbotEnabled = true
    Settings.ESPEnabled = true
    
    if gameName == "RIVALS" then SetSpeed(35)
    elseif gameName == "ARSENAL" then SetSpeed(42) end

    local MainGui = Instance.new("ScreenGui")
    MainGui.Name = "SwillHub_Core"
    MainGui.Parent = CoreGui
    MainGui.ResetOnSpawn = false
    MainGui.DisplayOrder = 999999

    ControlFrame = Instance.new("Frame")
    ControlFrame.Size = UDim2.fromOffset(300, 340)
    ControlFrame.Position = UDim2.new(0.5, -150, 0.5, -170)
    ControlFrame.BackgroundColor3 = Color3.fromRGB(17, 18, 20)
    ControlFrame.BorderSizePixel = 0
    ControlFrame.Active = true
    ControlFrame.Parent = MainGui
    
    Instance.new("UICorner", ControlFrame).CornerRadius = UDim.new(0, 16)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(26, 29, 37)
    stroke.Thickness = 2
    stroke.Parent = ControlFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 45)
    Title.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
    Title.Text = "SWILL HUB PRO — " .. gameName
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 15
    Title.Parent = ControlFrame
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 16)

    MakeDraggable(ControlFrame)

    local function CreateMenuButton(text, offsetIdx, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(260, 35)
        btn.Position = UDim2.fromOffset(20, 55 + (offsetIdx * 45))
        btn.BackgroundColor3 = Color3.fromRGB(27, 29, 37)
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 14
        btn.Parent = ControlFrame
        
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        btn.MouseButton1Click:Connect(function() callback(btn) end)
        return btn
    end

    CreateMenuButton("Aimbot: ON", 0, function(b)
        Settings.AimbotEnabled = not Settings.AimbotEnabled
        b.Text = Settings.AimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
    end)

    AimStatusBtn = CreateMenuButton("Aim Mode: " .. Settings.AimbotMode, 1, function(b)
        Settings.AimbotMode = Settings.AimbotMode == "Hold" and "Toggle" or "Hold"
        Settings.AimbotActive = false
        if Settings.AimbotMode == "Toggle" then
            b.Text = "Aim Mode: Toggle [F: OFF]"
        else
            b.Text = "Aim Mode: Hold [ПКМ]"
        end
    end)

    CreateMenuButton("Team Check: ON", 2, function(b)
        Settings.TeamCheck = not Settings.TeamCheck
        b.Text = Settings.TeamCheck and "Team Check: ON" or "Team Check: OFF"
    end)

    CreateMenuButton("ESP (Only Visible): ON", 3, function(b)
        Settings.ESPNames = not Settings.ESPNames
        b.Text = Settings.ESPNames and "ESP (Only Visible): ON" or "ESP (Only Visible): OFF"
    end)

    CreateMenuButton("Speed Bypass: ON", 4, function(b)
        if Settings.WalkSpeed > 16 then
            SetSpeed(16)
            b.Text = "Speed Bypass: OFF"
        else
            SetSpeed(gameName == "ARSENAL" and 42 or 35)
            b.Text = "Speed Bypass: ON"
        end
    end)
    
    local HelpText = Instance.new("TextLabel")
    HelpText.Size = UDim2.new(1, 0, 0, 30)
    HelpText.Position = UDim2.fromOffset(0, 295)
    HelpText.BackgroundTransparency = 1
    HelpText.Text = "[RSHIFT] Меню  |  [F] Переключатель видимых целей"
    HelpText.TextColor3 = Color3.fromRGB(100, 110, 130)
    HelpText.Font = Enum.Font.SourceSans
    HelpText.TextSize = 12
    HelpText.Parent = ControlFrame
end

-- СТАРТОВЫЙ ЛОАДЕР
local LoaderGui = Instance.new("ScreenGui")
LoaderGui.Name = "SwillLoader"
LoaderGui.Parent = CoreGui
LoaderGui.ResetOnSpawn = false
LoaderGui.DisplayOrder = 999999

local LauncherFrame = Instance.new("Frame")
LauncherFrame.Size = UDim2.fromOffset(360, 240)
LauncherFrame.Position = UDim2.new(0.5, -180, 0.5, -120)
LauncherFrame.BackgroundColor3 = Color3.fromRGB(17, 18, 20)
LauncherFrame.BorderSizePixel = 0
LauncherFrame.Active = true
LauncherFrame.Parent = LoaderGui

Instance.new("UICorner", LauncherFrame).CornerRadius = UDim.new(0, 20)
local lStroke = Instance.new("UIStroke")
lStroke.Color = Color3.fromRGB(26, 29, 37)
lStroke.Thickness = 2
lStroke.Parent = LauncherFrame

local LTitle = Instance.new("TextLabel")
LTitle.Size = UDim2.new(1, 0, 0, 50)
LTitle.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
LTitle.Text = "SWILL HUB PRO — SELECT GAME"
LTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
LTitle.Font = Enum.Font.SourceSansBold
LTitle.TextSize = 16
LTitle.Parent = LauncherFrame
Instance.new("UICorner", LTitle).CornerRadius = UDim.new(0, 20)

MakeDraggable(LauncherFrame)

local targetSelected = nil

local function BuildSelectorBtn(name, xOffset, colorHighlight)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(130, 50)
    btn.Position = UDim2.fromOffset(xOffset, 80)
    btn.BackgroundColor3 = Color3.fromRGB(27, 29, 37)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 15
    btn.Parent = LauncherFrame
    
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(35, 38, 47)
    s.Thickness = 1.5
    s.Parent = btn
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
    
    btn.MouseButton1Click:Connect(function()
        targetSelected = name
        lStroke.Color = colorHighlight
        s.Color = colorHighlight
    end)
    return btn
end

local rBtn = BuildSelectorBtn("RIVALS", 35, Color3.fromRGB(255, 60, 60))
local aBtn = BuildSelectorBtn("ARSENAL", 195, Color3.fromRGB(60, 150, 255))

local LoadBtn = Instance.new("TextButton")
LoadBtn.Size = UDim2.fromOffset(290, 45)
LoadBtn.Position = UDim2.fromOffset(35, 160)
LoadBtn.BackgroundColor3 = Color3.fromRGB(140, 155, 208)
LoadBtn.Text = "LOAD CHEATS"
LoadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadBtn.Font = Enum.Font.SourceSansBold
LoadBtn.TextSize = 16
LoadBtn.Parent = LauncherFrame
Instance.new("UICorner", LoadBtn).CornerRadius = UDim.new(0, 12)

LoadBtn.MouseButton1Click:Connect(function()
    if targetSelected then
        local target = targetSelected
        LoaderGui:Destroy()
        LaunchControlPanel(target)
    else
        LoadBtn.Text = "SELECT TARGET GAME FIRST!"
        task.wait(1)
        LoadBtn.Text = "LOAD CHEATS"
    end
end)

-- ==========================================
-- ОБРАБОТКА ХОТКЕЕВ (ФИКС TOGGLE)
-- ==========================================
UserInputService.InputBegan:Connect(function(input, processed)
    -- Перехватываем F ВСЕГДА, даже если игра думает, что кнопка занята действием
    if input.KeyCode == Binds.AimbotToggle then
        if Settings.AimbotMode == "Toggle" then
            Settings.AimbotActive = not Settings.AimbotActive
            if AimStatusBtn then
                AimStatusBtn.Text = Settings.AimbotActive and "Aim Mode: Toggle [F: ACTIVE]" or "Aim Mode: Toggle [F: OFF]"
            end
        end
        return -- Выходим, чтобы processed ниже не заблокировал логику
    end
    
    -- Для остальных кнопок (например, открытие GUI на Shift) стандартный чек
    if processed then return end
    
    if input.KeyCode == Binds.Menu then
        if ControlFrame then 
            ControlFrame.Visible = not ControlFrame.Visible 
        end
    end
end)
