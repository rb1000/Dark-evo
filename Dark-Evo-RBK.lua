local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("Peak Evo - RB1000 (Smart Detect)", "DarkTheme")

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
    print("[Anti-AFK] Kick voorkomen")
end)

-- ==============================================================================
-- DETECTIE (bovenaan nodig voor boot-check)
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

local function IsEndScreenVisible()
    local gui          = LocalPlayer:FindFirstChild("PlayerGui")
    local partyOverGui = gui and gui:FindFirstChild("PartyOverGui")
    local frame        = partyOverGui and partyOverGui:FindFirstChild("Frame")
    if not frame or not frame.Visible then return false end
    local bg = frame:FindFirstChild("bg")
    if not bg or not bg.Visible then return false end
    -- Extra check: list moet zichtbaar zijn (alleen na dungeon clear)
    local list = bg:FindFirstChild("list")
    if not list or not list.Visible then return false end
    return true
end

local function IsBossDead()
    local stage = Workspace:FindFirstChild("Stage")
    if not stage then return true end -- geen stage = dungeon voorbij
    for _, map in pairs(stage:GetChildren()) do
        if string.sub(map.Name, 1, 3) == "map" then
            local monster = map:FindFirstChild("monster")
            if monster then
                local c3 = monster:FindFirstChild("c3")
                if c3 then
                    local hum = c3:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        return false -- Boss leeft nog
                    end
                end
            end
        end
    end
    return true -- c3 niet gevonden of health <= 0
end

-- ==============================================================================
-- STATE (_G blijft bewaard, maar bij server->server teleport reset Roblox _G)
-- Oplossing: sla Running/Phase op in een aparte persistent check via dungeon detectie
-- ==============================================================================

if _G.PeakEvo == nil then
    _G.PeakEvo = {
        Running     = false,
        AutoAttack  = true,
        AttackRange = 45,
        Difficulty  = "Easy",
        MaxRuns     = 0,
        CurrentRun  = 0,
        Phase       = "IDLE",
    }
end

local S = _G.PeakEvo

-- Sleutelcheck: als we in dungeon zijn bij boot, altijd auto-hervat
-- ongeacht wat S.Running zegt (want bij server->server teleport reset _G)
local bootInDungeon = IsInDungeon()
if bootInDungeon then
    S.Running = true
    S.Phase   = "DUNGEON"
    print("[Boot] Dungeon gedetecteerd - auto-hervat")
end

-- ==============================================================================
-- GUI SETUP
-- ==============================================================================

local MainTab     = Window:NewTab("Main")
local Section     = MainTab:NewSection("⚙️ Instellingen")
local CtrlSection = MainTab:NewSection("▶️ Controls")
local StatusLabel = Section:NewLabel("Status: Idle")
local RunsLabel   = Section:NewLabel("Runs: 0 / ∞")

local function UpdateStatus(text)
    StatusLabel:UpdateLabel("Status: " .. text)
end

local function UpdateRuns(current, max)
    RunsLabel:UpdateLabel("Runs: " .. current .. " / " .. (max == 0 and "∞" or max))
end

-- ==============================================================================
-- ROUTE DATA
-- ==============================================================================

local LobbyRoute = {
    {Type = "Walk", Pos = Vector3.new(-1682.3, 6.5,   54.2)},
    {Type = "Walk", Pos = Vector3.new(-1685.6, 6.3,    0.1)},
    {Type = "Walk", Pos = Vector3.new(-1689.6, 22.6, -321.2)},
    {Type = "Walk", Pos = Vector3.new(-1686.7, 22.6, -319.1)},
    {Type = "Walk", Pos = Vector3.new(-1744.0, 22.6, -322.5)},
}

local DungeonEnd = Vector3.new(-880.3, 31.6, -507.3)

-- ==============================================================================
-- KLIK SYSTEEM
-- ==============================================================================

local function ClickGuiObject(guiObject)
    if not guiObject or not guiObject.AbsolutePosition or not guiObject.AbsoluteSize then
        return false
    end
    local cx = guiObject.AbsolutePosition.X + guiObject.AbsoluteSize.X / 2
    local cy = guiObject.AbsolutePosition.Y + guiObject.AbsoluteSize.Y / 2
    pcall(function() guiObject:Activate() end)
    pcall(function()
        for _, c in pairs(getconnections(guiObject.MouseButton1Click)) do c:Fire() end
    end)
    pcall(function()
        for _, c in pairs(getconnections(guiObject.Activated)) do c:Fire() end
    end)
    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    print("[Klik]", guiObject:GetFullName())
    return true
end

-- ==============================================================================
-- PARTY FIND FUNCTIES
-- ==============================================================================

local function FindPartyDifficultyButton(difficulty)
    local map = { Easy = "btn4", Normal = "btn5", Hard = "btn6" }
    local gui      = LocalPlayer:FindFirstChild("PlayerGui")
    local partyGui = gui and gui:FindFirstChild("PartyGui")
    local frame    = partyGui and partyGui:FindFirstChild("Frame")
    local createBg = frame and frame:FindFirstChild("createBg")
    local left     = createBg and createBg:FindFirstChild("left")
    local btnName  = map[difficulty or S.Difficulty]
    local btn      = left and btnName and left:FindFirstChild(btnName)
    if btn and btn:IsA("GuiObject") and btn.Visible then return btn end
    return nil
end

local function IsPartyDifficultyWindowOpen()
    return FindPartyDifficultyButton("Easy")
        or FindPartyDifficultyButton("Normal")
        or FindPartyDifficultyButton("Hard")
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
    if not IsEndScreenVisible() then return nil end
    if not IsBossDead() then
        print("[Again] Eindscherm zichtbaar maar boss leeft nog, wachten...")
        return nil
    end
    local gui          = LocalPlayer:FindFirstChild("PlayerGui")
    local partyOverGui = gui and gui:FindFirstChild("PartyOverGui")
    local frame        = partyOverGui and partyOverGui:FindFirstChild("Frame")
    local bg           = frame and frame:FindFirstChild("bg")
    return bg and bg:FindFirstChild("againbtn")
end
-- ==============================================================================
-- PARTY AANMAKEN
-- ==============================================================================

local function TryCreateParty()
    UpdateStatus("Wachten op party menu...")
    local deadline = tick() + 15
    while tick() < deadline do
        if not S.Running then return false end
        if IsPartyDifficultyWindowOpen() then break end
        task.wait(0.2)
    end

    if not IsPartyDifficultyWindowOpen() then
        UpdateStatus("❌ Party menu niet verschenen")
        return false
    end

    -- Difficulty
    UpdateStatus("Difficulty selecteren...")
    local d = tick() + 10
    while tick() < d do
        local btn = FindPartyDifficultyButton(S.Difficulty)
        if btn and ClickGuiObject(btn) then print("[Party] Difficulty OK") break end
        task.wait(0.05)
    end
    task.wait(0.3)

    -- Create (1x)
    UpdateStatus("Lobby aanmaken...")
    local c = tick() + 10
    while tick() < c do
        local btn = FindPartyCreateButton()
        if btn and ClickGuiObject(btn) then print("[Party] CreateBtn OK") break end
        task.wait(0.05)
    end
    task.wait(1)

    -- StartBtn: blijf klikken tot teleport
    UpdateStatus("Wachten op StartBtn...")
    local s = tick() + 15
    while tick() < s do
        if not S.Running then return false end
        local btn = FindPartyStartButton()
        if btn and ClickGuiObject(btn) then
            print("[Party] StartBtn geklikt, check teleport...")
            task.wait(1.5)
            if not FindPartyStartButton() then
                UpdateStatus("Teleporteren naar dungeon...")
                S.Phase = "DUNGEON"
                return true
            end
            print("[Party] Nog niet geteleporteerd, opnieuw...")
        end
        task.wait(0.5)
    end

    UpdateStatus("❌ StartBtn timeout")
    return false
end

-- ==============================================================================
-- COMBAT & LOPEN
-- ==============================================================================

local function FindClosestEnemy()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position
    local closest, minDist = nil, S.AttackRange
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
    local stuckTimer, lastPos = 0, root.Position

    while (root.Position - targetPos).Magnitude > 4 do
        if not S.Running then hum:MoveTo(root.Position) return end

        -- Check of eindscherm al zichtbaar is (boss dood voor eindpunt bereikt)
        local gui          = LocalPlayer:FindFirstChild("PlayerGui")
        local partyOverGui = gui and gui:FindFirstChild("PartyOverGui")
        local frame        = partyOverGui and partyOverGui:FindFirstChild("Frame")
        local bg           = frame and frame:FindFirstChild("bg")
        local againBtn     = bg and bg:FindFirstChild("againbtn")
        if IsEndScreenVisible() then
            print("[WalkToWithCombat] Eindscherm gedetecteerd!")
            hum:MoveTo(root.Position)
            return
        end

        local enemy = FindClosestEnemy()
        if enemy and S.AutoAttack then
            hum:MoveTo(root.Position)
            repeat
                if not S.Running then return end
                AttackTarget(enemy)
                if enemy.HumanoidRootPart then hum:MoveTo(enemy.HumanoidRootPart.Position) end
                task.wait(0.1)
            until not enemy or not enemy.Parent or enemy.Humanoid.Health <= 0
                or (root.Position - enemy.HumanoidRootPart.Position).Magnitude > S.AttackRange + 10
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
-- FASE LOGICA
-- ==============================================================================

local function RunDungeonPhase()
    S.Phase = "DUNGEON"

    -- Countdown
    for i = 15, 1, -1 do
        if not S.Running then return end
        UpdateStatus("Run " .. S.CurrentRun .. " | Deur opent in " .. i .. "s...")
        task.wait(1)
    end

    UpdateStatus("Run " .. S.CurrentRun .. " | Lopen + killen...")
    WalkToWithCombat(DungeonEnd)
    if not S.Running then return end

    -- Check limiet
    if S.MaxRuns > 0 and S.CurrentRun >= S.MaxRuns then
        UpdateStatus("✅ Klaar! " .. S.CurrentRun .. " / " .. S.MaxRuns .. " runs gedaan")
        S.Running = false
        S.Phase   = "IDLE"
        return
    end

    -- Wacht op againbtn, blijf ondertussen enemies aanvallen (boss kan nog leven)
    UpdateStatus("Wachten op eindscherm...")
    local deadline = tick() + 120
    local againClicked = false  -- NIEUW: voorkomt dubbele klik
    while tick() < deadline do
        if not S.Running then return end
    
        if not againClicked then
            local btn = FindAgainButton()
            if btn then
                againClicked = true  -- NIEUW: zet vlag direct
                task.wait(0.5)
                ClickGuiObject(btn)
                print("[Again] Geklikt!")
                UpdateStatus("Opnieuw geklikt! Laden...")
                lastAgainClick = tick()  -- NIEUW: sla tijdstip op
                task.wait(3)  -- NIEUW: wacht op teleport animatie
                S.CurrentRun += 1
                UpdateRuns(S.CurrentRun, S.MaxRuns)
                S.Phase = "DUNGEON"
                return
            end
        end
    
        -- Boss nog niet dood? Blijf aanvallen
        local enemy = FindClosestEnemy()
        if enemy and S.AutoAttack then
            AttackTarget(enemy)
        end
    
        task.wait(0.3)
    end

    warn("[Again] Timeout")
    UpdateStatus("❌ Eindscherm niet gevonden")
    S.Running = false
    S.Phase   = "IDLE"
end

local function RunLobbyPhase()
    S.Phase = "LOBBY"
    UpdateStatus("Lobby route lopen...")

    local char = LocalPlayer.Character
    local hum  = char:FindFirstChild("Humanoid")

    for i, step in ipairs(LobbyRoute) do
        if not S.Running then return end
        if step.Type == "Walk" then
            hum:MoveTo(step.Pos)
            hum.MoveToFinished:Wait(5)
        end
        task.wait(0.1)
    end

    if not S.Running then return end

    S.Phase = "PARTY"
    local ok = TryCreateParty()
    if not ok then
        UpdateStatus("❌ Party mislukt")
        S.Running = false
        S.Phase   = "IDLE"
    end
end

local lastAgainClick = 0  -- NIEUW: tijdstip van laatste Again klik

local function AutoStart()
    if not S.Running then return end
    UpdateRuns(S.CurrentRun, S.MaxRuns)

    -- NIEUW: Wacht minimaal 5 seconden na een Again klik (teleport cooldown)
    local timeSinceClick = tick() - lastAgainClick
    if timeSinceClick < 5 then
        task.wait(5 - timeSinceClick)
    end

    if IsInDungeon() then
        print("[AutoStart] Dungeon - Run", S.CurrentRun)
        UpdateStatus("Run " .. S.CurrentRun .. " | Dungeon gedetecteerd!")
        task.wait(1)
        RunDungeonPhase()
    else
        print("[AutoStart] Lobby")
        RunLobbyPhase()
    end
end
-- ==============================================================================
-- GUI KNOPPEN
-- ==============================================================================

Section:NewDropdown("Moeilijkheid", "Easy / Normal / Hard", {"Easy","Normal","Hard"}, function(val)
    S.Difficulty = val
end)

Section:NewDropdown("Aantal Runs", "Hoeveel runs", {"1","2","3","5","10","25","50","Oneindig"}, function(val)
    S.MaxRuns    = val == "Oneindig" and 0 or tonumber(val)
    S.CurrentRun = 0
    UpdateRuns(0, S.MaxRuns)
end)

Section:NewToggle("Auto Attack", "Aan/Uit", true, function(state)
    S.AutoAttack = state
end)

CtrlSection:NewButton("▶ START", "Start de volledige loop", function()
    if S.Running then return end
    S.Running    = true
    S.CurrentRun = 1
    S.Phase      = "LOBBY"
    UpdateRuns(S.CurrentRun, S.MaxRuns)
    task.spawn(AutoStart)
end)

CtrlSection:NewButton("⏹ STOP", "Stopt alles direct", function()
    S.Running = false
    S.Phase   = "IDLE"
    pcall(function()
        LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position)
    end)
    UpdateStatus("Gestopt")
end)

CtrlSection:NewButton("🎉 Party Aanmaken", "Handmatig party aanmaken", function()
    task.spawn(TryCreateParty)
end)

-- ==============================================================================
-- BOOT
-- ==============================================================================

UpdateStatus("Idle - Druk op START")
UpdateRuns(S.CurrentRun, S.MaxRuns)

if bootInDungeon then
    -- Altijd starten als we in dungeon zijn, ook als _G reset was
    print("[Boot] In dungeon - direct starten, Run:", S.CurrentRun)
    task.wait(2)
    task.spawn(AutoStart)
elseif S.Running then
    print("[Boot] Hervat vanuit lobby, Phase:", S.Phase)
    task.wait(1)
    task.spawn(AutoStart)
else
    print("[Boot] Fresh start - wacht op START knop")
end
