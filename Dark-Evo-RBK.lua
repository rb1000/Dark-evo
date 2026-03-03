local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("Peak Evo - RB1000 (Smart Detect)", "DarkTheme")

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

-- ==============================================================================
-- INSTELLINGEN & DATA
-- ==============================================================================

local LobbyRoute = {
    {Type = "Walk", Pos = Vector3.new(-1682.3, 6.5, 54.2)},
    {Type = "Walk", Pos = Vector3.new(-1685.6, 6.3, 0.1)},
    {Type = "Walk", Pos = Vector3.new(-1689.6, 22.6, -321.2)},
    {Type = "Walk", Pos = Vector3.new(-1686.7, 22.6, -319.1)},
    {Type = "Walk", Pos = Vector3.new(-1744.0, 22.6, -322.5)},
}

local DungeonRoute = {
    Vector3.new(-877.7, 31.6, 621.3),
    Vector3.new(-877.1, 31.6, 566.7),
    Vector3.new(-879.0, 31.6, 411.5),
    Vector3.new(-879.7, 31.6, 353.8),
    Vector3.new(-881.6, 31.6, 202.8),
    Vector3.new(-881.9, 31.6, 177.5),
    Vector3.new(-881.1, 31.6, 133.7),
    Vector3.new(-882.6, 31.6, 13.6),
    Vector3.new(-882.6, 31.6, 13.6),
    Vector3.new(-883.2, 31.6, -39.6),
    Vector3.new(-883.8, 31.6, -87.2),
    Vector3.new(-885.4, 31.6, -216.1),
    Vector3.new(-881.3, 31.6, -259.4),
    Vector3.new(-880.3, 31.6, -507.3),
}

_G.RunRoute = false
_G.AutoAttack = true
_G.AttackRange = 45

-- ==============================================================================
-- PARTY FUNCTIES
-- ==============================================================================

local function GetPartyGui()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    return playerGui:FindFirstChild("PartyGui")
end

local function ClickButton(button)
    if not button then return false end
    -- Simuleer een echte muisklik via FireButton
    local mouse = LocalPlayer:GetMouse()
    button:FireButton1Down(mouse)
    task.wait(0.05)
    button:FireButton1Up(mouse)
    return true
end

local function OpenCreatePartyMenu()
    local partyGui = GetPartyGui()
    if not partyGui then
        print("[Party] PartyGui niet gevonden!")
        return false
    end

    local frame = partyGui:FindFirstChild("Frame")
    if not frame then
        print("[Party] Frame niet gevonden in PartyGui!")
        return false
    end

    -- Zoek de createBg knop/frame
    local createBg = frame:FindFirstChild("createBg")
    if not createBg then
        print("[Party] createBg niet gevonden!")
        return false
    end

    -- Probeer een klikbare knop binnenin createBg te vinden
    local btn = createBg:FindFirstChildOfClass("TextButton")
        or createBg:FindFirstChildOfClass("ImageButton")

    if btn then
        print("[Party] Knop gevonden in createBg: " .. btn.Name)
        ClickButton(btn)
        return true
    else
        -- createBg zelf is mogelijk de knop
        if createBg:IsA("TextButton") or createBg:IsA("ImageButton") then
            print("[Party] createBg is zelf een knop, klikken...")
            ClickButton(createBg)
            return true
        end
    end

    print("[Party] Geen klikbare knop gevonden in createBg!")
    return false
end

local function ConfirmCreateParty()
    -- Na het openen, zoek een bevestigingsknop (bijv. "createSelectStageBg" of een confirm-knop)
    task.wait(0.5)

    local partyGui = GetPartyGui()
    if not partyGui then return false end

    local frame = partyGui:FindFirstChild("Frame")
    if not frame then return false end

    -- Probeer createSelectStageBg (stage selectie scherm)
    local createSelectStageBg = frame:FindFirstChild("createSelectStageBg")
    if createSelectStageBg and createSelectStageBg.Visible then
        local confirmBtn = createSelectStageBg:FindFirstChildOfClass("TextButton")
            or createSelectStageBg:FindFirstChildOfClass("ImageButton")
        if confirmBtn then
            print("[Party] Stage selectie bevestigen: " .. confirmBtn.Name)
            ClickButton(confirmBtn)
            return true
        end
    end

    return false
end

function AutoCreateParty()
    task.spawn(function()
        print("[Party] Party aanmaken starten...")
        UpdateStatus("Status: Party Aanmaken...")

        -- Wacht tot PartyGui beschikbaar is
        local timeout = 10
        local partyGui = nil
        repeat
            partyGui = GetPartyGui()
            task.wait(0.5)
            timeout = timeout - 0.5
        until partyGui or timeout <= 0

        if not partyGui then
            print("[Party] Timeout: PartyGui niet gevonden na 10s")
            UpdateStatus("Status: Party GUI niet gevonden!")
            return
        end

        -- Stap 1: Open create menu
        local success = OpenCreatePartyMenu()
        if not success then
            UpdateStatus("Status: Party aanmaken mislukt!")
            return
        end

        task.wait(0.5)

        -- Stap 2: Bevestig (optioneel, afhankelijk van game flow)
        ConfirmCreateParty()

        print("[Party] Party aangemaakt!")
        UpdateStatus("Status: Party Aangemaakt ✓")
    end)
end

-- ==============================================================================
-- GUI (eerst aanmaken, zodat StatusLabel beschikbaar is)
-- ==============================================================================

local MainTab = Window:NewTab("Main")
local Section = MainTab:NewSection("Controls")

local StatusLabel = Section:NewLabel("Status: Idle")

local function UpdateStatus(text)
    StatusLabel:UpdateLabel(text)
end

-- ==============================================================================
-- LOGICA: DETECTIE
-- ==============================================================================

local function IsInDungeon()
    local stage = Workspace:FindFirstChild("Stage")
    if not stage then return false end

    if stage:FindFirstChild("baseStage") then
        return false
    end

    if stage:FindFirstChild("map1") or stage:FindFirstChild("map2") or stage:FindFirstChild("map3") then
        return true
    end

    for _, child in pairs(stage:GetChildren()) do
        if string.sub(child.Name, 1, 3) == "map" then
            return true
        end
    end

    return false
end

-- ==============================================================================
-- LOGICA: COMBAT & LOPEN
-- ==============================================================================

local function FindClosestEnemy()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

    local myPos = char.HumanoidRootPart.Position
    local closest = nil
    local minDist = _G.AttackRange

    local stage = Workspace:FindFirstChild("Stage")
    if stage then
        for _, map in pairs(stage:GetChildren()) do
            if map.Name ~= "baseStage" then
                local monsterFolder = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                local searchTarget = monsterFolder and monsterFolder:GetChildren() or {}

                for _, mob in pairs(searchTarget) do
                    if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") then
                        if mob.Humanoid.Health > 0 then
                            local dist = (mob.HumanoidRootPart.Position - myPos).Magnitude
                            if dist < minDist then
                                minDist = dist
                                closest = mob
                            end
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
    local hum = char:WaitForChild("Humanoid")
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
            stuckTimer = stuckTimer + 1
            if stuckTimer > 20 then hum.Jump = true stuckTimer = 0 end
        else
            stuckTimer = 0
        end
        lastPos = root.Position
        task.wait(0.1)
    end
end

-- ==============================================================================
-- START FUNCTIES
-- ==============================================================================

function StartDungeonLogic()
    _G.RunRoute = true
    task.spawn(function()
        print("DUNGEON START: Wacht 10s op deur...")
        UpdateStatus("Status: Wachten op deur (10s)...")

        task.wait(10)

        print("DUNGEON: Route starten...")
        UpdateStatus("Status: Dungeon Farmen...")

        for i, point in ipairs(DungeonRoute) do
            if not _G.RunRoute then break end
            WalkToWithCombat(point)
        end
        UpdateStatus("Status: Dungeon Klaar")
    end)
end

function StartLobbyLogic()
    _G.RunRoute = true
    task.spawn(function()
        print("LOBBY START: Lopen naar startpunt...")
        UpdateStatus("Status: Lopen in Lobby...")

        local char = LocalPlayer.Character
        local hum = char:FindFirstChild("Humanoid")

        for i, step in ipairs(LobbyRoute) do
            if not _G.RunRoute then break end

            if step.Type == "Walk" then
                print("Lobby stap:", i)
                hum:MoveTo(step.Pos)
                hum.MoveToFinished:Wait(5)
            end
            task.wait(0.1)
        end

        if _G.RunRoute then
            -- Automatisch party aanmaken na lobby route
            AutoCreateParty()
        end
    end)
end

function AutoDetectAndStart()
    if IsInDungeon() then
        print("Locatie: DUNGEON")
        StartDungeonLogic()
    else
        print("Locatie: LOBBY (baseStage gevonden)")
        StartLobbyLogic()
    end
end

-- ==============================================================================
-- GUI KNOPPEN
-- ==============================================================================

Section:NewButton("Start Lobby Route", "Forceert de lobby loop route", function()
    print("Knop ingedrukt: Start Lobby Route")
    StartLobbyLogic()
end)

Section:NewButton("Start Dungeon Route", "Forceert de dungeon route + kill", function()
    print("Knop ingedrukt: Start Dungeon Route")
    StartDungeonLogic()
end)

Section:NewButton("Party Aanmaken", "Maakt handmatig een party aan", function()
    AutoCreateParty()
end)

Section:NewButton("Stop Alles", "Stopt direct", function()
    _G.RunRoute = false
    LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position)
    UpdateStatus("Status: Gestopt")
end)

Section:NewToggle("Auto Attack", "Aan/Uit", function(state)
    _G.AutoAttack = state
end)

-- Check bij opstarten
AutoDetectAndStart()
