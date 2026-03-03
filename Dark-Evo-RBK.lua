local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("Peak Evo - RB1000", "DarkTheme")

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ==============================================================================
-- DEEL 1: JOUW ROUTE (HIER PLAK JE DE CODE UIT F9)
-- ==============================================================================
local MijnRoute = {
    {Type = "Walk", Pos = Vector3.new(-1682.3, 6.5, 54.2)},
    {Type = "Walk", Pos = Vector3.new(-1685.6, 6.3, 0.1)},
    {Type = "Walk", Pos = Vector3.new(-1689.6, 22.6, -321.2)},
	{Type = "Walk", Pos = Vector3.new(-1686.7, 22.6, -319.1)},
	{Type = "Walk", Pos = Vector3.new(-1744.0, 22.6, -322.5)},
}

-- Instellingen
_G.RunRoute = false
_G.AutoFarm = false -- Zet dit aan in GUI na het starten van dungeon
_G.PartyDifficulty = "Normal"
_G.AutoReexecuteOnTeleport = true
_G.ScriptFilePath = _G.ScriptFilePath or "Dark-Evo-RBK.lua"
_G.ScriptSourceUrl = _G.ScriptSourceUrl or ""
_G.TeleportReexecuteCode = _G.TeleportReexecuteCode or ""
_G.TeleportReexecuteDelay = _G.TeleportReexecuteDelay or 4

-- ==============================================================================
-- DEEL 2: DE LOGICA (NIET AANPASSEN)
-- ==============================================================================

local function GetQueueOnTeleport()
    return queue_on_teleport
        or queueonteleport
        or (syn and syn.queue_on_teleport)
end

local function BuildTeleportReexecuteCode()
    if type(_G.TeleportReexecuteCode) == "string" and _G.TeleportReexecuteCode ~= "" then
        return _G.TeleportReexecuteCode
    end

    if type(_G.ScriptSourceUrl) == "string" and _G.ScriptSourceUrl ~= "" then
        return string.format([[
task.spawn(function()
    repeat task.wait() until game:IsLoaded()
    task.wait(%s)
    local ok, result = pcall(function()
        return game:HttpGet(%q)
    end)
    if not ok then
        warn("Teleport HttpGet error:", result)
        return
    end
    local fn, err = loadstring(result)
    if not fn then
        warn("Teleport loadstring error:", err)
        return
    end
    fn()
end)
]], tostring(_G.TeleportReexecuteDelay), _G.ScriptSourceUrl)
    end

    if type(_G.ScriptFilePath) == "string" and _G.ScriptFilePath ~= "" then
        return string.format([[
task.spawn(function()
    repeat task.wait() until game:IsLoaded()
    task.wait(%s)
    local readFn = readfile or read_file or (syn and (syn.readfile or syn.read_file))
    local isFileFn = isfile or is_file or (syn and (syn.isfile or syn.is_file))
    if not readFn then
        warn("Teleport readfile API niet beschikbaar.")
        return
    end
    if isFileFn then
        local exists = false
        local okExists, resultExists = pcall(function()
            return isFileFn(%q)
        end)
        exists = okExists and resultExists
        if not exists then
            warn("Teleport script file niet gevonden:", %q)
            return
        end
    end
    local okRead, source = pcall(function()
        return readFn(%q)
    end)
    if not okRead then
        warn("Teleport readfile error:", source)
        return
    end
    local fn, err = loadstring(source)
    if not fn then
        warn("Teleport loadstring error:", err)
        return
    end
    fn()
end)
]], tostring(_G.TeleportReexecuteDelay), _G.ScriptFilePath, _G.ScriptFilePath, _G.ScriptFilePath)
    end

    return nil
end

local function QueueScriptOnTeleport()
    if not _G.AutoReexecuteOnTeleport then
        return false
    end

    local queueTeleport = GetQueueOnTeleport()
    if not queueTeleport then
        warn("queue_on_teleport niet beschikbaar in deze executor.")
        return false
    end

    local code = BuildTeleportReexecuteCode()
    if not code then
        warn("Geen TeleportReexecuteCode of ScriptFilePath ingesteld.")
        return false
    end

    queueTeleport(code)
    print("Teleport re-execute queued.")
    return true
end

local function ClickGuiObject(guiObject)
    if not guiObject or not guiObject.AbsolutePosition or not guiObject.AbsoluteSize then
        return false
    end

    local centerX = guiObject.AbsolutePosition.X + (guiObject.AbsoluteSize.X / 2)
    local centerY = guiObject.AbsolutePosition.Y + (guiObject.AbsoluteSize.Y / 2)

    pcall(function()
        guiObject:Activate()
    end)

    pcall(function()
        for _, conn in pairs(getconnections(guiObject.MouseButton1Click)) do
            conn:Fire()
        end
    end)

    pcall(function()
        for _, conn in pairs(getconnections(guiObject.Activated)) do
            conn:Fire()
        end
    end)

    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
    print("GUI klik op:", guiObject:GetFullName())
    return true
end

local function FindClickableFromLabel(labelObject)
    local current = labelObject

    while current and current ~= LocalPlayer.PlayerGui do
        if current:IsA("TextButton") or current:IsA("ImageButton") then
            return current
        end

        current = current.Parent
    end

    return nil
end

local function FindPartyCreateButton()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then
        return nil
    end

    local partyGui = gui:FindFirstChild("PartyGui")
    local frame = partyGui and partyGui:FindFirstChild("Frame")
    local createBg = frame and frame:FindFirstChild("createBg")
    local right = createBg and createBg:FindFirstChild("right")
    local createBtn = right and right:FindFirstChild("createBtn")

    if createBtn and createBtn:IsA("GuiObject") and createBtn.Visible then
        return createBtn
    end

    return nil
end

local function FindPartyDifficultyButton(difficulty)
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then
        return nil
    end

    local buttonMap = {
        Easy = "btn4",
        Normal = "btn5",
        Hard = "btn6",
    }

    local partyGui = gui:FindFirstChild("PartyGui")
    local frame = partyGui and partyGui:FindFirstChild("Frame")
    local createBg = frame and frame:FindFirstChild("createBg")
    local left = createBg and createBg:FindFirstChild("left")
    local buttonName = buttonMap[difficulty or _G.PartyDifficulty]
    local difficultyButton = left and buttonName and left:FindFirstChild(buttonName)

    if difficultyButton and difficultyButton:IsA("GuiObject") and difficultyButton.Visible then
        return difficultyButton
    end

    return nil
end

local function IsPartyDifficultyWindowOpen()
    return FindPartyDifficultyButton("Easy") or FindPartyDifficultyButton("Normal") or FindPartyDifficultyButton("Hard")
end

local function ClickVisibleButton(buttonName, timeout)
    local gui = LocalPlayer:WaitForChild("PlayerGui")
    local deadline = tick() + (timeout or 5)

    while tick() < deadline do
        local shouldUsePartyCreatePath = buttonName == "Create a Party" or buttonName == "createBtn"
        local partyCreateButton = shouldUsePartyCreatePath and FindPartyCreateButton()
        if partyCreateButton and ClickGuiObject(partyCreateButton) then
            return true
        end

        for _, v in pairs(gui:GetDescendants()) do
            if v:IsA("GuiObject") and v.Visible then
                local matchesName = v.Name and v.Name:find(buttonName)
                local matchesText = (v:IsA("TextButton") or v:IsA("TextLabel")) and v.Text and v.Text:find(buttonName)

                if matchesName or matchesText then
                    local clickable = v
                    if v:IsA("TextLabel") or v:IsA("ImageLabel") or v:IsA("Frame") then
                        clickable = FindClickableFromLabel(v) or v
                    end

                    if ClickGuiObject(clickable) then
                        return true
                    end
                end
            end
        end

        task.wait(0.05)
    end

    return false
end

local function SelectPartyDifficulty(timeout)
    local deadline = tick() + (timeout or 5)

    while tick() < deadline do
        local difficultyButton = FindPartyDifficultyButton(_G.PartyDifficulty)
        if difficultyButton and ClickGuiObject(difficultyButton) then
            print("Party difficulty gekozen:", _G.PartyDifficulty)
            return true
        end

        task.wait(0.05)
    end

    warn("Difficulty knop niet gevonden: " .. tostring(_G.PartyDifficulty))
    return false
end

local function ConfirmPartyCreate(timeout)
    local deadline = tick() + (timeout or 5)

    while tick() < deadline do
        local createButton = FindPartyCreateButton()
        if createButton and ClickGuiObject(createButton) then
            return true
        end

        task.wait(0.05)
    end

    warn("Final createBtn niet gevonden.")
    return false
end

local function TryCreateParty()
    if not IsPartyDifficultyWindowOpen() then
        local openedPartyMenu = ClickVisibleButton("Create a Party", 10)
        if not openedPartyMenu then
            warn("Create a Party knop niet gevonden.")
            return false
        end

        task.wait(0.2)
    end

    local selectedDifficulty = SelectPartyDifficulty(10)
    if not selectedDifficulty then
        return false
    end

    task.wait(0.2)

    local createdParty = ConfirmPartyCreate(10)
    if not createdParty then
        return false
    end

    task.wait(1)

    QueueScriptOnTeleport()

    local startedParty = ConfirmPartyCreate(10)
    if not startedParty then
        warn("Party start createBtn niet gevonden.")
        return false
    end

    return startedParty
end

QueueScriptOnTeleport()

-- Functie: Voer de route uit
function RunTheRoute()
    task.spawn(function()
        print("Route gestart...")
        for i, step in ipairs(MijnRoute) do
            if not _G.RunRoute then break end
            
            local char = LocalPlayer.Character
            local hum = char:FindFirstChild("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            
            -- STAP: LOPEN
            if step.Type == "Walk" then
                if hum and root then
                    hum:MoveTo(step.Pos)
                    -- Wacht tot we er zijn (of max 3 sec)
                    local reached = hum.MoveToFinished:Wait(3)
                end
            
            -- STAP: WACHTEN
            elseif step.Type == "Wait" then
                task.wait(step.Time)
            
            -- STAP: GUI KLIKKEN
            elseif step.Type == "Click" then
                local found = ClickVisibleButton(step.Name, step.Timeout or 5)
                if not found then warn("Knop niet gevonden: " .. step.Name) end
            end
            
            task.wait(0.2) -- Korte pauze tussen stappen
        end

        TryCreateParty()

        print("Route klaar! Nu auto-farmen...")
        _G.RunRoute = false -- Zet route uit
        _G.AutoFarm = true -- Zet farm aan
    end)
end

-- Functie: Auto Farm (Simpel, slaat alles in de buurt)
function FarmLoop()
    task.spawn(function()
        while true do
            if _G.AutoFarm then
                pcall(function()
                    local char = LocalPlayer.Character
                    local mobs = workspace:FindFirstChild("Mobs") or workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Dungeon")
                    
                    if mobs then
                        for _, e in pairs(mobs:GetChildren()) do
                            if e:FindFirstChild("Humanoid") and e.Humanoid.Health > 0 then
                                local root = char.HumanoidRootPart
                                local eRoot = e.HumanoidRootPart
                                local dist = (root.Position - eRoot.Position).Magnitude
                                
                                if dist < 200 then -- Als enemy in de buurt is
                                    if dist > 15 then
                                        char.Humanoid:MoveTo(eRoot.Position)
                                    else
                                        char.Humanoid:MoveTo(root.Position)
                                        VirtualUser:CaptureController()
                                        VirtualUser:ClickButton1(Vector2.new(900, 500))
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            task.wait(0.1)
        end
    end)
end
FarmLoop() -- Start de farm loop op de achtergrond

-- ==============================================================================
-- DEEL 3: GUI TOOLS (RECORDER)
-- ==============================================================================
local Tab = Window:NewTab("Recorder")
local RecSection = Tab:NewSection("Maak je Route")

RecSection:NewLabel("1. Loop naar punt -> Klik 'Log Stap'")
RecSection:NewButton("Log Huidige Stap (Lopen)", "Print coordinaten in F9", function()
    local pos = LocalPlayer.Character.HumanoidRootPart.Position
    local code = string.format('{Type = "Walk", Pos = Vector3.new(%.1f, %.1f, %.1f)},', pos.X, pos.Y, pos.Z)
    print(code)
end)

RecSection:NewLabel("2. Wacht je op een GUI? -> Klik 'Log Wacht'")
RecSection:NewButton("Log Wacht (2 sec)", "Voegt wachttijd toe", function()
    print('{Type = "Wait", Time = 2},')
end)

RecSection:NewLabel("3. Zie je de Startknop? -> Klik 'Log Klik'")
RecSection:NewButton("Log Klik (Zoek Start Knop)", "Zoekt naar Start/Play knoppen", function()
    print('{Type = "Click", Name = "Start"}, -- Verander "Start" als de knop anders heet')
end)

local RunTab = Window:NewTab("Runner")
local RunSection = RunTab:NewSection("Start Bot")

RunSection:NewToggle("Start Mijn Route", "Voert de stappen hierboven uit", function(state)
    _G.RunRoute = state
    if state then
        RunTheRoute()
    end
end)

RunSection:NewToggle("Auto Farm (Attack)", "Slaat enemies (automatisch na route)", function(state)
    _G.AutoFarm = state
end)

RunSection:NewDropdown("Party Difficulty", "Kies Easy, Normal of Hard", {"Easy", "Normal", "Hard"}, function(value)
    _G.PartyDifficulty = value
    print("Party difficulty ingesteld op:", value)
end)

RunSection:NewButton("Test Party GUI", "Opent party, kiest difficulty en klikt create", function()
    task.spawn(function()
        TryCreateParty()
    end)
end)
