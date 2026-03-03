local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("Peak Evo - RB1000 (Dungeon + Kill)", "DarkTheme")

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ==============================================================================
-- INSTELLINGEN & DATA
-- ==============================================================================

-- 1. Lobby Route (Om de dungeon in te gaan)
local LobbyRoute = {
    {Type = "Walk", Pos = Vector3.new(-1682.3, 6.5, 54.2)},
    {Type = "Walk", Pos = Vector3.new(-1685.6, 6.3, 0.1)},
    {Type = "Walk", Pos = Vector3.new(-1689.6, 22.6, -321.2)},
    {Type = "Walk", Pos = Vector3.new(-1686.7, 22.6, -319.1)},
    {Type = "Walk", Pos = Vector3.new(-1744.0, 22.6, -322.5)},
}

-- 2. Dungeon Route (De route binnenin)
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

-- Globals
_G.RunRoute = _G.RunRoute or false
_G.AutoAttack = _G.AutoAttack or true -- Val automatisch aan
_G.AttackRange = 45 -- Hoe dichtbij moet een monster zijn om te stoppen met lopen?
_G.PartyDifficulty = _G.PartyDifficulty or "Normal"
if _G.AutoReexecuteOnTeleport == nil then _G.AutoReexecuteOnTeleport = true end

-- ==============================================================================
-- LOGICA: MONSTERS ZOEKEN & VECHTEN
-- ==============================================================================

local function FindClosestEnemy()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    
    local myPos = char.HumanoidRootPart.Position
    local closest = nil
    local minDist = _G.AttackRange -- Alleen monsters binnen deze range

    -- Zoek in Workspace.Stage (zoals in je screenshot)
    local stage = Workspace:FindFirstChild("Stage")
    if stage then
        for _, map in pairs(stage:GetChildren()) do
            -- Check of er een 'monster' folder is (zoals in map3)
            local monsterFolder = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
            
            -- Als er geen monster folder is, check of de map zelf monsters bevat
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
    return closest
end

local function AttackTarget(target)
    if not target or not target:FindFirstChild("HumanoidRootPart") then return end
    
    local char = LocalPlayer.Character
    VirtualUser:CaptureController()
    
    -- Kijk naar monster
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(char.HumanoidRootPart.Position, Vector3.new(target.HumanoidRootPart.Position.X, char.HumanoidRootPart.Position.Y, target.HumanoidRootPart.Position.Z))
    end

    -- Klikken (Attack)
    VirtualUser:ClickButton1(Vector2.new(900, 500))
    
    -- Eventueel skills vuren (optioneel, bv E of R drukken)
    -- VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
end

-- ==============================================================================
-- LOGICA: INTELLIGENT LOPEN (STOP VOOR MONSTERS)
-- ==============================================================================

local function WalkToWithCombat(targetPos)
    local char = LocalPlayer.Character
    local hum = char:WaitForChild("Humanoid")
    local root = char:WaitForChild("HumanoidRootPart")
    
    hum:MoveTo(targetPos)

    local stuckTimer = 0
    local lastPos = root.Position

    -- Loop totdat we op de bestemming zijn
    while (root.Position - targetPos).Magnitude > 4 do
        if not _G.RunRoute then hum:MoveTo(root.Position) return end -- Stop knop
        
        -- 1. Check voor monsters
        local enemy = FindClosestEnemy()
        
        if enemy then
            -- STOP LOPEN! ER IS EEN VIJAND!
            hum:MoveTo(root.Position) -- Remmen
            
            repeat
                if not _G.RunRoute then return end
                -- Val aan
                AttackTarget(enemy)
                
                -- Loop klein beetje naar enemy als hij ver weg rent
                if enemy.HumanoidRootPart then
                    hum:MoveTo(enemy.HumanoidRootPart.Position)
                end
                
                task.wait(0.1)
                -- Check of hij nog leeft en dichtbij is
            until not enemy or not enemy.Parent or enemy.Humanoid.Health <= 0 or (root.Position - enemy.HumanoidRootPart.Position).Magnitude > _G.AttackRange + 10
            
            -- Enemy dood? Hervat route naar waypoint
            hum:MoveTo(targetPos)
        end
        
        -- 2. Anti-Stuck (als je tegen een muur loopt)
        if (root.Position - lastPos).Magnitude < 0.5 then
            stuckTimer = stuckTimer + 1
            if stuckTimer > 20 then -- 2 seconden vast?
                hum.Jump = true
                stuckTimer = 0
            end
        else
            stuckTimer = 0
        end
        lastPos = root.Position

        task.wait(0.1)
    end
end

-- ==============================================================================
-- HOOFDFUNCTIES
-- ==============================================================================

function StartDungeonLogic()
    task.spawn(function()
        print("Dungeon gedetecteerd of gestart!")
        
        -- Wacht 10 seconden voor de deur (zoals gevraagd)
        Window:UpdateLabel("Status: Wachten op Deur (10s)...")
        print("Wachten op deur (10s)...")
        task.wait(10)
        
        print("Start Dungeon Route + Auto Attack")
        Window:UpdateLabel("Status: Dungeon Farmen...")
        
        _G.RunRoute = true
        
        for i, point in ipairs(DungeonRoute) do
            if not _G.RunRoute then break end
            print("Lopen naar punt " .. i)
            WalkToWithCombat(point)
        end
        
        print("Dungeon klaar!")
        Window:UpdateLabel("Status: Dungeon Klaar")
    end)
end

function StartLobbyLogic()
    task.spawn(function()
        print("Lobby logic gestart...")
        Window:UpdateLabel("Status: Naar Dungeon Lopen...")
        _G.RunRoute = true

        -- Loop de lobby route
        for i, step in ipairs(LobbyRoute) do
            if not _G.RunRoute then break end
            local char = LocalPlayer.Character
            local hum = char:FindFirstChild("Humanoid")
            
            if step.Type == "Walk" then
                hum:MoveTo(step.Pos)
                hum.MoveToFinished:Wait(3)
            end
            task.wait(0.1)
        end

        -- Party Maken
        if _G.RunRoute then
            Window:UpdateLabel("Status: Party Maken...")
            -- Hier de logica van je oude script (kort samengevat)
            local function Click(btn)
                if btn and btn.Visible then
                    pcall(function()
                        for _,v in pairs(getconnections(btn.MouseButton1Click)) do v:Fire() end
                    end)
                    return true
                end
                return false
            end
            
            -- Probeert de UI sequence (simpel gehouden voor overzicht)
            -- Let op: Dit gedeelte leunt op je vorige script logica voor GUI finding
            -- Ik ga ervan uit dat je de GUI functies uit deel 1 hebt. 
            -- Voor nu simpel de start aanroep:
            print("Probeer party te starten...")
            -- (Voeg hier je TryCreateParty() logica toe of gebruik auto-execute na teleport)
        end
    end)
end

-- Check waar we zijn bij opstarten
local function CheckLocationAndStart()
    local stage = Workspace:FindFirstChild("Stage")
    if stage then
        -- We zijn in de dungeon!
        StartDungeonLogic()
    else
        -- We zijn waarschijnlijk in de lobby
        print("Geen Stage gevonden, we zijn in de Lobby.")
        -- Optioneel: StartLobbyLogic() aanroepen als je dat automatisch wilt
    end
end

-- ==============================================================================
-- UI SETUP
-- ==============================================================================

local MainTab = Window:NewTab("Main")
local Section = MainTab:NewSection("Controls")

Section:NewButton("Start Dungeon Route (Nu)", "Start direct de route + kill script", function()
    StartDungeonLogic()
end)

Section:NewButton("Start Lobby Route", "Loopt naar startpunt", function()
    StartLobbyLogic()
end)

Section:NewToggle("Auto Attack", "Val monsters aan tijdens lopen", function(state)
    _G.AutoAttack = state
end)

Section:NewSlider("Attack Range", "Afstand tot monster voor stop", 100, 15, function(v)
    _G.AttackRange = v
end)

Section:NewButton("Stop Alles", "Stopt lopen en vechten", function()
    _G.RunRoute = false
    LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position)
end)

-- Queue on Teleport (zodat hij herstart na dungeon joinen)
local queue_on_teleport = queue_on_teleport or syn.queue_on_teleport
if queue_on_teleport and _G.AutoReexecuteOnTeleport then
    queue_on_teleport([[
        repeat task.wait() until game:IsLoaded()
        task.wait(2)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
        -- Laad dit script opnieuw (als je het in een file of url hebt, zet dat hier)
        print("Re-executed!")
    ]])
end

-- Start check
CheckLocationAndStart()
