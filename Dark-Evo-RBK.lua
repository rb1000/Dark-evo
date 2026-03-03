local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("Peak Evo - RB1000 (Smart Detect)", "DarkTheme")

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")


-- ==============================================================================
-- ANTI-AFK
-- ==============================================================================
local VirtualUser = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
    print("[Anti-AFK] AFK kick voorkomen")
end)


-- ==============================================================================
-- DETECTIE (bovenaan zodat het bij boot gebruikt kan worden)
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
-- INSTELLINGEN (_G zodat ze teleport overleven)
-- ==============================================================================

-- Alleen initialiseren als ze nog niet bestaan (na teleport bewaren we ze)
if _G.PeakEvo == nil then
    _G.PeakEvo = {
        Running      = false,
        AutoAttack   = true,
        AttackRange  = 45,
        Difficulty   = "Easy",
        MaxRuns      = 0,
        CurrentRun   = 0,
        Phase        = "IDLE",
    }
end

local S = _G.PeakEvo

-- Na teleport: als we in dungeon zitten, forceer Running=true
if IsInDungeon() and S.Phase == "DUNGEON" then
    S.Running = true
    print("[Boot] Dungeon gedetecteerd + Phase=DUNGEON, auto-hervat")
end

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
    print("[Klik]", guiObject:GetFullName())
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
    local btnName  = buttonMap[difficulty or S.Difficulty]
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
    local gui          = LocalPlayer:FindFirstChild("PlayerGui")
    local partyOverGui = gui and gui:FindFirstChild("PartyOverGui")
    local frame        = partyOverGui and partyOverGui:FindFirstChild("Frame")
    local bg           = frame and frame:FindFirstChild("bg")
    local btn          = bg and bg:FindFirstChild("againbtn")
    if btn and btn.Visible then return btn end
    return nil
end

local function TryCreateParty()
    -- Wacht tot createBg automatisch zichtbaar wordt (menu opent vanzelf)
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
    local d_deadline = tick() + 10
    while tick() < d_deadline do
        local btn = FindPartyDifficultyButton(S.Difficulty)
        if btn and ClickGuiObject(btn) then
            print("[Party] Difficulty OK:", S.Difficulty)
            break
        end
        task.wait(0.05)
    end
    task.wait(0.3)

    -- CreateBtn (1x klikken)
    UpdateStatus("Lobby aanmaken...")
    local c_deadline = tick() + 10
    while tick() < c_deadline do
        local btn = FindPartyCreateButton()
        if btn and ClickGuiObject(btn) then
            print("[Party] CreateBtn OK")
            break
        end
        task.wait(0.05)
    end
    task.wait(1)

    -- StartBtn
-- StartBtn (blijf proberen tot teleport daadwerkelijk gebeurt)
UpdateStatus("Wachten op StartBtn...")
local s_deadline = tick() + 15
while tick() < s_deadline do
    local btn = FindPartyStartButton()
    if btn and ClickGuiObject(btn) then
        print("[Party] StartBtn geklikt, wachten op teleport...")
        task.wait(1.5)
        -- Check of we al geteleporteerd zijn (roomBg verdwenen = teleport bezig)
        local stillVisible = FindPartyStartButton()
        if not stillVisible then
            print("[Party] Teleport bezig!")
            UpdateStatus("Party gestart! Teleporteren...")
            return true
        end
        -- Nog steeds zichtbaar = nog niet geteleporteerd, opnieuw klikken
        print("[Party] Nog niet geteleporteerd, opnieuw klikken...")
    end
    task.wait(0.5)
end

    UpdateStatus("❌ StartBtn niet gevonden")
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
    local stuckTimer = 0
    local lastPos = root.Position

    while (root.Position - targetPos).Magnitude > 4 do
        if not S.Running then hum:MoveTo(root.Position) return end

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
    UpdateStatus("Run " .. S.CurrentRun .. " | Wachten op deur...")

    -- 15 seconden countdown
    for i = 15, 1, -1 do
        if not S.Running then return end
        UpdateStatus("Run " .. S.CurrentRun .. " | Deur opent in " .. i .. "s...")
        task.wait(1)
    end

    UpdateStatus("Run " .. S.CurrentRun .. " | Dungeon lopen + killen...")
    WalkToWithCombat(DungeonEnd)
    if not S.Running then return end

    -- Dungeon klaar
    S.CurrentRun += 1
    UpdateRuns(S.CurrentRun, S.MaxRuns)

    -- Check of we klaar zijn
    if S.MaxRuns > 0 and S.CurrentRun > S.MaxRuns then
        UpdateStatus("✅ Klaar! " .. S.MaxRuns .. " runs gedaan")
        S.Running = false
        S.Phase = "IDLE"
        return
    end

    -- Klik opnieuw
    UpdateStatus("Wachten op 'Opnieuw' knop...")
    local deadline = tick() + 20
    while tick() < deadline do
        if not S.Running then return end
        local btn = FindAgainButton()
        if btn and ClickGuiObject(btn) then
            print("[Again] Opnieuw geklikt, teleporteren...")
            UpdateStatus("Opnieuw geklikt! Teleporteren...")
            -- Script herstart automatisch via auto-exec na teleport
            -- _G.PeakEvo.Phase = "DUNGEON" blijft bewaard
            S.Phase = "DUNGEON"
            return
        end
        task.wait(0.5)
    end

    warn("[Again] Opnieuw knop niet gevonden")
    UpdateStatus("❌ Opnieuw knop niet gevonden")
    S.Running = false
    S.Phase = "IDLE"
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
        UpdateStatus("❌ Party mislukt, gestopt")
        S.Running = false
        S.Phase = "IDLE"
    end
    -- Na party -> teleport -> script herstart -> IsInDungeon() = true -> RunDungeonPhase()
end

local function AutoStart()
    if not S.Running then return end

    UpdateRuns(S.CurrentRun, S.MaxRuns)

    if IsInDungeon() then
        -- Script herstart na teleport, ga direct door met dungeon
        print("[AutoStart] In dungeon gedetecteerd, fase:", S.Phase)
        S.CurrentRun += 1
        UpdateRuns(S.CurrentRun, S.MaxRuns)
        UpdateStatus("Run " .. S.CurrentRun .. " | Dungeon gedetecteerd!")
        task.wait(1)
        RunDungeonPhase()
    else
        -- In lobby, begin van voor af aan
        print("[AutoStart] In lobby gedetecteerd")
        RunLobbyPhase()
    end
end

-- ==============================================================================
-- GUI KNOPPEN
-- ==============================================================================

Section:NewDropdown("Moeilijkheid", "Easy / Normal / Hard", {"Easy", "Normal", "Hard"}, function(val)
    S.Difficulty = val
    print("Difficulty:", val)
end)

Section:NewDropdown("Aantal Runs", "Hoeveel runs uitvoeren", {"1","2","3","5","10","25","50","Oneindig"}, function(val)
    S.MaxRuns = val == "Oneindig" and 0 or tonumber(val)
    S.CurrentRun = 0
    UpdateRuns(0, S.MaxRuns)
    print("Runs ingesteld:", val)
end)

Section:NewToggle("Auto Attack", "Aan/Uit", true, function(state)
    S.AutoAttack = state
end)

ControlSection:NewButton("▶ START", "Start de volledige loop", function()
    if S.Running then print("Al bezig!") return end
    S.Running    = true
    S.CurrentRun = 0
    S.Phase      = "LOBBY"
    UpdateRuns(0, S.MaxRuns)
    task.spawn(AutoStart)
end)

ControlSection:NewButton("⏹ STOP", "Stopt alles direct", function()
    S.Running = false
    S.Phase   = "IDLE"
    pcall(function()
        LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position)
    end)
    UpdateStatus("Gestopt")
end)

ControlSection:NewButton("🎉 Party Aanmaken", "Maakt handmatig een party aan", function()
    task.spawn(TryCreateParty)
end)

-- ==============================================================================
-- AUTO START NA TELEPORT
-- ==============================================================================

UpdateStatus("Idle - Druk op START")
UpdateRuns(S.CurrentRun, S.MaxRuns)

if S.Running then
    print("[Boot] Hervat - Phase:", S.Phase)
    task.wait(2)
    task.spawn(AutoStart)
elseif IsInDungeon() and S.Phase ~= "IDLE" then
    -- Vangnet: in dungeon maar Running was false geworden
    print("[Boot] Vangnet: in dungeon, Running hersteld")
    S.Running = true
    task.wait(2)
    task.spawn(AutoStart)
else
    print("[Boot] Fresh start")
end
