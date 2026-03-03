local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("Peak Evo - RB1000 (Smart Detect)", "DarkTheme")

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

-- ==============================================================================
-- GUI SETUP
-- ==============================================================================

local MainTab = Window:NewTab("Main")
local Section = MainTab:NewSection("⚙️ Instellingen")
local ControlSection = MainTab:NewSection("▶️ Controls")
local StatusLabel = Section:NewLabel("Status: Idle")
local RunsLabel = Section:NewLabel("Runs: 0 / 0")

local function UpdateStatus(text)
    StatusLabel:UpdateLabel("Status: " .. text)
end

local function UpdateRuns(current, max)
    if max == 0 then
        RunsLabel:UpdateLabel("Runs: " .. current .. " / ∞")
    else
        RunsLabel:UpdateLabel("Runs: " .. current .. " / " .. max)
    end
end

-- ==============================================================================
-- INSTELLINGEN
-- ==============================================================================

_G.RunRoute  = false
_G.AutoAttack = true
_G.AttackRange = 45
_G.PartyDifficulty = "Easy"
_G.MaxRuns = 0      -- 0 = oneindig
_G.CurrentRun = 0

local LobbyRoute = {
    {Type = "Walk", Pos = Vector3.new(-1682.3, 6.5,   54.2)},
    {Type = "Walk", Pos = Vector3.new(-1685.6, 6.3,    0.1)},
    {Type = "Walk", Pos = Vector3.new(-1689.6, 22.6, -321.2)},
    {Type = "Walk", Pos = Vector3.new(-1686.7, 22.6, -319.1)},
    {Type = "Walk", Pos = Vector3.new(-1744.0, 22.6, -322.5)},
}

-- Rechte lijn: beginpunt → eindpunt
local DungeonStart = Vector3.new(-877.7, 31.6,  621.3)
local DungeonEnd   = Vector3.new(-880.3, 31.6, -507.3)

-- ==============================================================================
-- KLIK SYSTEEM
-- ==============================================================================

local function ClickGuiObject(guiObject)
    if not guiObject or not guiObject.AbsolutePosition or not guiObject.AbsoluteSize then
        return false
    end

    local centerX = guiObject.AbsolutePosition.X + (guiObject.AbsoluteSize.X / 2)
    local centerY = guiObject.AbsolutePosition.Y + (guiObject.AbsoluteSize.Y / 2)

    pcall(function() guiObject:Activate() end)
    pcall(function()
        for _, conn in pairs(getconnections(guiObject.MouseButton1Click)) do conn:Fire() end
    end)
    pcall(function()
        for _, conn in pairs(getconnections(guiObject.Activated)) do conn:Fire() end
    end)

    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true,  game, 0)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
    print("GUI klik op:", guiObject:GetFullName())
    return true
end

-- ==============================================================================
-- PARTY FUNCTIES
-- ==============================================================================

local function FindPartyDifficultyButton(difficulty)
    local buttonMap = { Easy = "btn4", Normal = "btn5", Hard = "btn6" }
    local gui      = LocalPlayer:FindFirstChild("PlayerGui")
    local partyGui = gui and gui:FindFirstChild("PartyGui")
    local frame    = partyGui and partyGui:FindFirstChild("Frame")
    local createBg = frame and frame:FindFirstChild("createBg")
    local left     = createBg and createBg:FindFirstChild("left")
    local btnName  = buttonMap[difficulty or _G.PartyDifficulty]
    local btn      = left and btnName and left:FindFirstChild(btnName)
    if btn and btn:IsA("GuiObject") and btn.Visible then return btn end
    return nil
end

local function IsPartyDifficultyWindowOpen()
    return FindPartyDifficultyButton("Easy")
        or FindPartyDifficultyButton("Normal")
        or FindPartyDifficultyButton("Hard")
end

local function FindPartyOpenButton()
    local gui      = LocalPlayer:FindFirstChild("PlayerGui")
    local partyGui = gui and gui:FindFirstChild("PartyGui")
    local frame    = partyGui and partyGui:FindFirstChild("Frame")
    local mainBg   = frame and frame:FindFirstChild("mainBg")
    local right    = mainBg and mainBg:FindFirstChild("right")
    local btn      = right and right:FindFirstChild("btn")
    if btn and btn.Visible then return btn end
    return nil
end

local function FindPartyCreateButton()
    local gui      = LocalPlayer:FindFirstChild("PlayerGui")
    local partyGui = gui and gui:FindFirstChild("PartyGui")
    local frame    = partyGui and partyGui:FindFirstChild("Frame")
    local createBg = frame and frame:FindFirstChild("createBg")
    local right    = createBg and createBg:FindFirstChild("right")
    local btn      = right and right:FindFirstChild("createBtn")
    if btn and btn.Visible then return btn end
    return nil
end

local function FindPartyStartButton()
    local gui      = LocalPlayer:FindFirstChild("PlayerGui")
    local partyGui = gui and gui:FindFirstChild("PartyGui")
    local frame    = partyGui and partyGui:FindFirstChild("Frame")
    local roomBg   = frame and frame:FindFirstChild("roomBg")
    local right    = roomBg and roomBg:FindFirstChild("right")
    local btn      = right and right:FindFirstChild("StartBtn")
    if btn and btn.Visible then return btn end
    return nil
end

local function FindAgainButton()
    local gui          = LocalPlayer:FindFirstChild("PlayerGui")
    local partyOverGui = gui and gui:FindFirstChild("PartyOverGui")
    local frame        = partyOverGui and partyOverGui:FindFirstChild("Frame")
    local bg           = frame and frame:FindFirstChild("bg")
    local btn          = bg and bg:FindFirstChild("againbtn")
    if btn and btn.Visible then return btn end
    return nil
end

local function SelectPartyDifficulty(timeout)
    local deadline = tick() + (timeout or 5)
    while tick() < deadline do
        local btn = FindPartyDifficultyButton(_G.PartyDifficulty)
        if btn and ClickGuiObject(btn) then
            print("[Party] Difficulty:", _G.PartyDifficulty)
            return true
        end
        task.wait(0.05)
    end
    warn("[Party] Difficulty knop niet gevonden")
    return false
end

local function ConfirmPartyCreate(timeout)
    local deadline = tick() + (timeout or 5)
    while tick() < deadline do
        local btn = FindPartyCreateButton()
        if btn and ClickGuiObject(btn) then
            print("[Party] Create geklikt")
            return true
        end
        task.wait(0.05)
    end
    warn("[Party] createBtn niet gevonden")
    return false
end

local function StartPartyAfterCreate(timeout)
    local deadline = tick() + (timeout or 8)
    while tick() < deadline do
        local btn = FindPartyStartButton()
        if btn and ClickGuiObject(btn) then
            print("[Party] Party gestart!")
            return true
        end
        task.wait(0.6)
    end
    warn("[Party] StartBtn niet gevonden")
    return false
end

local function TryCreateParty()
    UpdateStatus("Party menu openen...")

    if not IsPartyDifficultyWindowOpen() then
        local deadline = tick() + 10
        local opened = false
        while tick() < deadline do
            local btn = FindPartyOpenButton()
            if btn and ClickGuiObject(btn) then opened = true break end
            task.wait(0.1)
        end
        if not opened then
            warn("[Party] Open knop niet gevonden")
            UpdateStatus("❌ Party mislukt (open)")
            return false
        end
        task.wait(0.5)
    end

    UpdateStatus("Difficulty selecteren...")
    if not SelectPartyDifficulty(10) then UpdateStatus("❌ Party mislukt (difficulty)") return false end
    task.wait(0.3)

    UpdateStatus("Party aanmaken...")
    if not ConfirmPartyCreate(10) then UpdateStatus("❌ Party mislukt (create)") return false end
    task.wait(1)

    UpdateStatus("Wachten op StartBtn...")
    if not StartPartyAfterCreate(8) then UpdateStatus("❌ Party mislukt (start)") return false end

    UpdateStatus("Party gestart! Teleporteren...")
    return true
end

local function TryAgainDungeon(timeout)
    UpdateStatus("Wachten op 'Opnieuw' knop...")
    local deadline = tick() + (timeout or 15)
    while tick() < deadline do
        local btn = FindAgainButton()
        if btn and ClickGuiObject(btn) then
            print("[Again] Opnieuw knop geklikt!")
            return true
        end
        task.wait(0.5)
    end
    warn("[Again] Opnieuw knop niet gevonden binnen timeout")
    return false
end

-- ==============================================================================
-- COMBAT & LOPEN
-- ==============================================================================

local function FindClosestEnemy()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position
    local closest, minDist = nil, _G.AttackRange

    local stage = Workspace:FindFirstChild("Stage")
    if stage then
        for _, map in pairs(stage:GetChildren()) do
            if map.Name ~= "baseStage" then
                local folder = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                for _, mob in pairs(folder and folder:GetChildren() or {}) do
                    if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") then
                        if mob.Humanoid.Health > 0 then
                            local dist = (mob.HumanoidRootPart.Position - myPos).Magnitude
                            if dist < minDist then minDist = dist closest = mob end
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function AttackTarget(target)
    if not target or not target:FindFirstChild("HumanoidRootPart") then return end
    local char = LocalPlayer.Character
    VirtualUser:CaptureController()
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(
            char.HumanoidRootPart.Position,
            Vector3.new(
                target.HumanoidRootPart.Position.X,
                char.HumanoidRootPart.Position.Y,
                target.HumanoidRootPart.Position.Z
            )
        )
    end
    VirtualUser:ClickButton1(Vector2.new(900, 500))
end

local function WalkToWithCombat(targetPos)
    local char = LocalPlayer.Character
    local hum  = char:WaitForChild("Humanoid")
    local root = char:WaitForChild("HumanoidRootPart")
    hum:MoveTo(targetPos)
    local stuckTimer = 0
    local lastPos = root.Position

    while (root.Position - targetPos).Magnitude > 4 do
        if not _G.RunRoute then hum:MoveTo(root.Position) return end

        local enemy = FindClosestEnemy()
        if enemy and _G.AutoAttack then
            hum:MoveTo(root.Position)
            repeat
                if not _G.RunRoute then return end
                AttackTarget(enemy)
                if enemy.HumanoidRootPart then hum:MoveTo(enemy.HumanoidRootPart.Position) end
                task.wait(0.1)
            until not enemy or not enemy.Parent or enemy.Humanoid.Health <= 0
                or (root.Position - enemy.HumanoidRootPart.Position).Magnitude > _G.AttackRange + 10
            hum:MoveTo(targetPos)
        end

        if (root.Position - lastPos).Magnitude < 0.5 then
            stuckTimer += 1
            if stuckTimer > 20 then hum.Jump = true stuckTimer = 0 end
        else
            stuckTimer = 0
        end
        lastPos = root.Position
        task.wait(0.1)
    end
end

-- ==============================================================================
-- DETECTIE
-- ==============================================================================

local function IsInDungeon()
    local stage = Workspace:FindFirstChild("Stage")
    if not stage then return false end
    if stage:FindFirstChild("baseStage") then return false end
    for _, child in pairs(stage:GetChildren()) do
        if string.sub(child.Name, 1, 3) == "map" then return true end
    end
    return false
end

-- ==============================================================================
-- HOOFD LOOP
-- ==============================================================================

local function RunDungeonLoop()
    _G.RunRoute   = true
    _G.CurrentRun = 0

    task.spawn(function()
        -- Stap 1: Lobby route lopen
        UpdateStatus("Lobby route lopen...")
        local char = LocalPlayer.Character
        local hum  = char:FindFirstChild("Humanoid")

        for i, step in ipairs(LobbyRoute) do
            if not _G.RunRoute then return end
            if step.Type == "Walk" then
                print("Lobby stap:", i)
                hum:MoveTo(step.Pos)
                hum.MoveToFinished:Wait(5)
            end
            task.wait(0.1)
        end

        if not _G.RunRoute then return end

        -- Stap 2: Party aanmaken
        local ok = TryCreateParty()
        if not ok then
            UpdateStatus("❌ Gestopt (party mislukt)")
            _G.RunRoute = false
            return
        end

        -- Stap 3: Dungeon loop
        while _G.RunRoute do
            -- Controleer run limiet
            if _G.MaxRuns > 0 and _G.CurrentRun >= _G.MaxRuns then
                UpdateStatus("✅ Klaar! " .. _G.CurrentRun .. " runs gedaan")
                _G.RunRoute = false
                break
            end

            _G.CurrentRun += 1
            UpdateRuns(_G.CurrentRun, _G.MaxRuns)
            UpdateStatus("Run " .. _G.CurrentRun .. " | Wachten op deur (15s)...")
            print("[Dungeon] Run", _G.CurrentRun, "gestart")

            -- Wacht 15s op de deur
            for i = 15, 1, -1 do
                if not _G.RunRoute then return end
                UpdateStatus("Run " .. _G.CurrentRun .. " | Deur opent in " .. i .. "s...")
                task.wait(1)
            end

            -- Loop rechte lijn beginpunt → eindpunt
            UpdateStatus("Run " .. _G.CurrentRun .. " | Dungeon lopen...")
            WalkToWithCombat(DungeonEnd)

            if not _G.RunRoute then return end

            -- Dungeon klaar, wacht op "Opnieuw" knop
            UpdateStatus("Run " .. _G.CurrentRun .. " | Dungeon klaar! Opnieuw klikken...")
            print("[Dungeon] Run", _G.CurrentRun, "klaar")

            -- Check of er nog runs overblijven
            local nextRun = _G.CurrentRun + 1
            local hasRunsLeft = _G.MaxRuns == 0 or nextRun <= _G.MaxRuns

            if hasRunsLeft then
                local again = TryAgainDungeon(20)
                if not again then
                    UpdateStatus("❌ Opnieuw knop niet gevonden")
                    _G.RunRoute = false
                    break
                end
                task.wait(2) -- wacht op laden
            else
                UpdateStatus("✅ Klaar! " .. _G.CurrentRun .. " runs gedaan")
                _G.RunRoute = false
                break
            end
        end
    end)
end

-- ==============================================================================
-- GUI KNOPPEN & INSTELLINGEN
-- ==============================================================================

Section:NewDropdown("Moeilijkheid", "Easy / Normal / Hard", {"Easy", "Normal", "Hard"}, function(val)
    _G.PartyDifficulty = val
    print("Difficulty:", val)
end)

Section:NewDropdown("Aantal Runs", "Hoeveel runs uitvoeren", {"1","2","3","5","10","25","50","Oneindig"}, function(val)
    if val == "Oneindig" then
        _G.MaxRuns = 0
        print("Runs: Oneindig")
    else
        _G.MaxRuns = tonumber(val)
        print("Runs:", _G.MaxRuns)
    end
    UpdateRuns(_G.CurrentRun, _G.MaxRuns)
end)

Section:NewToggle("Auto Attack", "Aan/Uit", true, function(state)
    _G.AutoAttack = state
end)

ControlSection:NewButton("▶ START", "Start de volledige loop", function()
    if _G.RunRoute then
        print("Al bezig!")
        return
    end
    RunDungeonLoop()
end)

ControlSection:NewButton("⏹ STOP", "Stopt alles direct", function()
    _G.RunRoute = false
    pcall(function()
        LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position)
    end)
    UpdateStatus("Gestopt")
    print("Gestopt door gebruiker")
end)

ControlSection:NewButton("🎉 Party Aanmaken", "Maakt handmatig een party aan", function()
    task.spawn(TryCreateParty)
end)

-- Init labels
UpdateRuns(0, _G.MaxRuns)
UpdateStatus("Idle - Druk op START")
