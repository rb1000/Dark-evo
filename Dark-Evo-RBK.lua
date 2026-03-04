-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v1.4 - 12s deur timer + enemy counter + betere logging
-- ============================================================

local ok, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
end)
if not ok or not Library then
    warn("[PeakEvo] FATAL: UI Library laden mislukt: " .. tostring(Library))
    return
end

local Window = Library.CreateLib("Peak Evo - RB1000 (Stable)", "DarkTheme")

-- ==============================================================================
-- SERVICES
-- ==============================================================================
local function GetService(name)
    local s, r = pcall(function() return game:GetService(name) end)
    if not s then warn("[PeakEvo] Service niet gevonden: " .. name) end
    return s and r or nil
end

local Players             = GetService("Players")
local VirtualInputManager = GetService("VirtualInputManager")
local VirtualUser         = GetService("VirtualUser")
local Workspace           = game.Workspace
local LocalPlayer         = Players and Players.LocalPlayer

if not LocalPlayer then warn("[PeakEvo] FATAL: Geen LocalPlayer!") return end

-- ==============================================================================
-- LOGGING
-- Prefix geeft aan uit welke module het komt
-- ==============================================================================
local LOG_PREFIX = "[PeakEvo]"
local function Log(module, msg)
    print(LOG_PREFIX .. "[" .. module .. "] " .. tostring(msg))
end
local function Warn(module, msg)
    warn(LOG_PREFIX .. "[" .. module .. "] " .. tostring(msg))
end

-- ==============================================================================
-- ANTI-AFK
-- ==============================================================================
pcall(function()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
            Log("AFK", "Kick voorkomen")
        end)
    end)
end)

-- ==============================================================================
-- STATE — _G overleeft elke teleport
-- ==============================================================================
if type(_G.PeakEvo) ~= "table" then
    _G.PeakEvo = {
        Running      = false,
        AutoAttack   = true,
        AttackRange  = 45,
        Difficulty   = "Easy",
        MaxRuns      = 0,
        CurrentRun   = 0,
        Phase        = "IDLE",
        DoorWait     = 12, -- seconden wachten op deur
    }
end
local S = _G.PeakEvo
Log("Boot", "State geladen | Running=" .. tostring(S.Running) .. " Phase=" .. S.Phase .. " Run=" .. S.CurrentRun)

-- ==============================================================================
-- GUI SETUP
-- ==============================================================================
local MainTab        = Window:NewTab("Main")
local Section        = MainTab:NewSection("Instellingen")
local ControlSection = MainTab:NewSection("Controls")
local StatsSection   = MainTab:NewSection("Live Stats")

local StatusLabel    = Section:NewLabel("Status: Idle")
local RunsLabel      = StatsSection:NewLabel("Runs: 0 / 0")
local EnemyLabel     = StatsSection:NewLabel("Enemies: -")
local PhaseLabel     = StatsSection:NewLabel("Fase: IDLE")

local function UpdateStatus(text)
    pcall(function() StatusLabel:UpdateLabel("Status: " .. tostring(text)) end)
    Log("Status", text)
end

local function UpdateRuns(current, max)
    pcall(function()
        local suffix = (max == 0) and " / inf" or (" / " .. max)
        RunsLabel:UpdateLabel("Runs: " .. current .. suffix)
    end)
end

local function UpdatePhaseLabel(phase)
    pcall(function() PhaseLabel:UpdateLabel("Fase: " .. tostring(phase)) end)
end

local function UpdateEnemyLabel(alive, total)
    pcall(function()
        if alive == nil then
            EnemyLabel:UpdateLabel("Enemies: -")
        else
            EnemyLabel:UpdateLabel("Enemies: " .. alive .. " / " .. total .. " over")
        end
    end)
end

-- ==============================================================================
-- WERELD LADEN WACHTER
-- ==============================================================================
local function WaitForWorldLoad(maxWait)
    maxWait = maxWait or 15
    local deadline = tick() + maxWait
    while tick() < deadline do
        local ok2, ready = pcall(function()
            local stage = Workspace:FindFirstChild("Stage")
            return stage ~= nil and #stage:GetChildren() > 0
        end)
        if ok2 and ready then
            Log("World", "Stage geladen")
            task.wait(0.5)
            return true
        end
        task.wait(0.3)
    end
    Warn("World", "Stage niet gevonden na " .. maxWait .. "s")
    return false
end

-- ==============================================================================
-- DETECTIE: IN DUNGEON?
-- ==============================================================================
local function IsInDungeon()
    local ok2, result = pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return false end
        if stage:FindFirstChild("baseStage") then
            Log("Detect", "baseStage gevonden = lobby")
            return false
        end
        for _, child in pairs(stage:GetChildren()) do
            if string.sub(child.Name, 1, 3) == "map" then
                Log("Detect", "Dungeon map gevonden: " .. child.Name)
                return true
            end
        end
        Log("Detect", "Geen map in Stage = lobby")
        return false
    end)
    return ok2 and result or false
end

-- ==============================================================================
-- ENEMY COUNTER
-- Telt alle levende enemies in de huidige dungeon map
-- ==============================================================================
local function CountEnemies()
    local alive = 0
    local total = 0
    pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return end
        for _, map in pairs(stage:GetChildren()) do
            if string.sub(map.Name, 1, 3) == "map" then
                local folder = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                if folder then
                    for _, mob in pairs(folder:GetChildren()) do
                        pcall(function()
                            local hum = mob:FindFirstChild("Humanoid")
                            if hum then
                                total += 1
                                if hum.Health > 0 then
                                    alive += 1
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)
    return alive, total
end

-- ==============================================================================
-- LOADINGGUI WACHTER
-- ==============================================================================
local function WaitForLoadingGui(maxWait)
    maxWait = maxWait or 30
    local deadline = tick() + maxWait
    while tick() < deadline do
        if not S.Running then return end
        local isLoading = false
        pcall(function()
            local pg      = LocalPlayer:FindFirstChild("PlayerGui")
            local loading = pg and pg:FindFirstChild("LoadingGui")
            isLoading = loading ~= nil and loading.Enabled == true
        end)
        if isLoading then
            UpdateStatus("Loading screen...")
            task.wait(0.3)
        else
            Log("Loading", "LoadingGui weg, doorgaan")
            task.wait(0.2)
            return
        end
    end
    Warn("Loading", "Timeout 30s, toch doorgaan")
end

-- ==============================================================================
-- DEUR WACHTER — simpele vaste timer
-- ==============================================================================
local function WaitForDoor()
    local wait = S.DoorWait or 12
    Log("Deur", "Wachten " .. wait .. "s voor deur opent...")
    for i = wait, 1, -1 do
        if not S.Running then return end
        UpdateStatus("Deur opent in " .. i .. "s...")
        task.wait(1)
    end
    Log("Deur", "Timer klaar, doorgaan")
end

-- ==============================================================================
-- ROUTES
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
    if not guiObject then return false end
    local s = pcall(function()
        if not guiObject.AbsolutePosition or not guiObject.AbsoluteSize then return end
        local cx = guiObject.AbsolutePosition.X + (guiObject.AbsoluteSize.X / 2)
        local cy = guiObject.AbsolutePosition.Y + (guiObject.AbsoluteSize.Y / 2)
        pcall(function() guiObject:Activate() end)
        pcall(function()
            for _, conn in pairs(getconnections(guiObject.MouseButton1Click)) do
                pcall(function() conn:Fire() end)
            end
        end)
        pcall(function()
            for _, conn in pairs(getconnections(guiObject.Activated)) do
                pcall(function() conn:Fire() end)
            end
        end)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
    return s
end

-- ==============================================================================
-- PARTY FUNCTIES
-- ==============================================================================
local function SafeFind(...)
    local args    = {...}
    local current = LocalPlayer:FindFirstChild("PlayerGui")
    for i = 1, #args do
        if not current then return nil end
        local ok3, result = pcall(function() return current:FindFirstChild(args[i]) end)
        current = ok3 and result or nil
    end
    return current
end

local function FindPartyDifficultyButton(difficulty)
    local buttonMap = {Easy = "btn4", Normal = "btn5", Hard = "btn6"}
    local btnName   = buttonMap[difficulty or S.Difficulty]
    if not btnName then return nil end
    local left = SafeFind("PartyGui", "Frame", "createBg", "left")
    if not left then return nil end
    local ok4, btn = pcall(function() return left:FindFirstChild(btnName) end)
    if ok4 and btn and btn:IsA("GuiObject") and btn.Visible then return btn end
    return nil
end

local function IsPartyDifficultyWindowOpen()
    return FindPartyDifficultyButton("Easy")
        or FindPartyDifficultyButton("Normal")
        or FindPartyDifficultyButton("Hard")
end

local function FindPartyCreateButton()
    local right = SafeFind("PartyGui", "Frame", "createBg", "right")
    if not right then return nil end
    local ok5, btn = pcall(function() return right:FindFirstChild("createBtn") end)
    if ok5 and btn and btn.Visible then return btn end
    return nil
end

local function FindPartyStartButton()
    local right = SafeFind("PartyGui", "Frame", "roomBg", "right")
    if not right then return nil end
    local ok6, btn = pcall(function() return right:FindFirstChild("StartBtn") end)
    if ok6 and btn and btn.Visible then return btn end
    return nil
end

local function FindAgainButton()
    local bg = SafeFind("PartyOverGui", "Frame", "bg")
    if not bg then return nil end
    local ok7, btn = pcall(function() return bg:FindFirstChild("againbtn") end)
    if ok7 and btn and btn.Visible then return btn end
    return nil
end

local function TryCreateParty()
    Log("Party", "Wachten op party menu...")
    UpdateStatus("Wachten op party menu...")
    local deadline = tick() + 15
    while tick() < deadline do
        if not S.Running then return false end
        if IsPartyDifficultyWindowOpen() then
            Log("Party", "Menu open!")
            break
        end
        task.wait(0.2)
    end
    if not IsPartyDifficultyWindowOpen() then
        Warn("Party", "Menu niet verschenen na 15s")
        UpdateStatus("Party menu niet verschenen")
        return false
    end

    Log("Party", "Difficulty selecteren: " .. S.Difficulty)
    UpdateStatus("Difficulty: " .. S.Difficulty)
    local d_deadline = tick() + 10
    while tick() < d_deadline do
        local btn = FindPartyDifficultyButton(S.Difficulty)
        if btn and ClickGuiObject(btn) then
            Log("Party", "Difficulty geklikt")
            break
        end
        task.wait(0.1)
    end
    task.wait(0.4)

    Log("Party", "Lobby aanmaken...")
    UpdateStatus("Lobby aanmaken...")
    local c_deadline = tick() + 10
    while tick() < c_deadline do
        local btn = FindPartyCreateButton()
        if btn and ClickGuiObject(btn) then
            Log("Party", "CreateBtn geklikt")
            break
        end
        task.wait(0.1)
    end
    task.wait(1)

    Log("Party", "Wachten op StartBtn...")
    UpdateStatus("Wachten op StartBtn...")
    local s_deadline = tick() + 20
    while tick() < s_deadline do
        if not S.Running then return false end
        local btn = FindPartyStartButton()
        if btn then
            ClickGuiObject(btn)
            task.wait(1.5)
            if not FindPartyStartButton() then
                S.Phase = "DUNGEON" -- bewaren VOOR teleport
                Log("Party", "StartBtn geklikt, teleporteren (Phase=DUNGEON bewaard)")
                UpdateStatus("Party gestart! Teleporteren...")
                return true
            end
        end
        task.wait(0.5)
    end

    Warn("Party", "StartBtn timeout na 20s")
    UpdateStatus("StartBtn timeout")
    return false
end

-- ==============================================================================
-- KARAKTER HELPERS
-- ==============================================================================
local function GetCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChild("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

-- ==============================================================================
-- COMBAT
-- ==============================================================================
local function FindClosestEnemy()
    local _, _, root = GetCharParts()
    if not root then return nil end
    local myPos            = root.Position
    local closest, minDist = nil, S.AttackRange

    pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return end
        for _, map in pairs(stage:GetChildren()) do
            if map.Name ~= "baseStage" then
                local folder = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                if folder then
                    for _, mob in pairs(folder:GetChildren()) do
                        pcall(function()
                            local hum2  = mob:FindFirstChild("Humanoid")
                            local mroot = mob:FindFirstChild("HumanoidRootPart")
                            if hum2 and mroot and hum2.Health > 0 then
                                local dist = (mroot.Position - myPos).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    closest = mob
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)
    return closest
end

local function AttackTarget(target)
    pcall(function()
        if not target or not target:FindFirstChild("HumanoidRootPart") then return end
        local _, _, root = GetCharParts()
        if not root then return end
        VirtualUser:CaptureController()
        root.CFrame = CFrame.new(
            root.Position,
            Vector3.new(
                target.HumanoidRootPart.Position.X,
                root.Position.Y,
                target.HumanoidRootPart.Position.Z
            )
        )
        VirtualUser:ClickButton1(Vector2.new(900, 500))
    end)
end

-- ==============================================================================
-- LOPEN MET COMBAT + live enemy counter
-- ==============================================================================
local function WalkToWithCombat(targetPos)
    local char, hum, root = GetCharParts()
    if not char or not hum or not root then return end

    hum:MoveTo(targetPos)
    local stuckTimer    = 0
    local lastPos       = root.Position
    local timeout       = tick() + 300
    local lastEnemyLog  = tick()

    while tick() < timeout do
        if not S.Running then
            pcall(function() hum:MoveTo(root.Position) end)
            return
        end

        char, hum, root = GetCharParts()
        if not char or not hum or not root then task.wait(1) return end

        if (root.Position - targetPos).Magnitude <= 4 then break end

        -- Live enemy counter updaten (elke 2s om spam te voorkomen)
        if tick() - lastEnemyLog > 2 then
            local alive, total = CountEnemies()
            UpdateEnemyLabel(alive, total)
            if total > 0 then
                Log("Combat", "Enemies: " .. alive .. "/" .. total .. " levend")
            end
            lastEnemyLog = tick()
        end

        if S.AutoAttack then
            local enemy = FindClosestEnemy()
            if enemy then
                pcall(function() hum:MoveTo(root.Position) end)
                local combatTimeout = tick() + 15
                local enemyName     = pcall(function() return enemy.Name end) and enemy.Name or "?"
                Log("Combat", "Aanvallen: " .. tostring(enemyName))
                repeat
                    if not S.Running then return end
                    char, hum, root = GetCharParts()
                    if not char then return end
                    AttackTarget(enemy)
                    pcall(function()
                        if enemy.HumanoidRootPart then
                            hum:MoveTo(enemy.HumanoidRootPart.Position)
                        end
                    end)
                    task.wait(0.1)
                until tick() > combatTimeout
                    or not enemy or not enemy.Parent
                    or not enemy:FindFirstChild("Humanoid")
                    or enemy.Humanoid.Health <= 0

                if enemy and enemy.Parent and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health <= 0 then
                    Log("Combat", tostring(enemyName) .. " dood")
                end
                pcall(function() hum:MoveTo(targetPos) end)
            end
        end

        char, hum, root = GetCharParts()
        if root then
            if (root.Position - lastPos).Magnitude < 0.5 then
                stuckTimer += 1
                if stuckTimer > 20 then
                    Log("Move", "Vastgelopen, springen")
                    pcall(function() hum.Jump = true end)
                    stuckTimer = 0
                end
            else
                stuckTimer = 0
            end
            lastPos = root.Position
        end

        task.wait(0.1)
    end

    local alive, total = CountEnemies()
    Log("Combat", "Route klaar | Enemies over: " .. alive .. "/" .. total)
    UpdateEnemyLabel(alive, total)
end

-- ==============================================================================
-- FASE: DUNGEON
-- ==============================================================================
local function RunDungeonPhase()
    S.Phase = "DUNGEON"
    UpdatePhaseLabel("DUNGEON")
    Log("Dungeon", "=== Run " .. S.CurrentRun .. " gestart ===")

    -- 1. Wereld laden
    WaitForWorldLoad(15)
    if not S.Running then return end

    -- 2. Loading screen
    WaitForLoadingGui(30)
    if not S.Running then return end

    -- 3. Vaste timer voor deur
    WaitForDoor()
    if not S.Running then return end

    -- 4. Enemy count bij start
    local alive, total = CountEnemies()
    Log("Dungeon", "Enemies bij start: " .. alive .. "/" .. total)
    UpdateEnemyLabel(alive, total)

    -- 5. Loop dungeon
    UpdateStatus("Run " .. S.CurrentRun .. " | Lopen + killen...")
    WalkToWithCombat(DungeonEnd)
    if not S.Running then return end

    -- 6. Run afronden
    S.CurrentRun += 1
    UpdateRuns(S.CurrentRun, S.MaxRuns)
    local aliveEnd, totalEnd = CountEnemies()
    Log("Dungeon", "=== Run " .. S.CurrentRun .. " klaar | Enemies over: " .. aliveEnd .. "/" .. totalEnd .. " ===")

    if S.MaxRuns > 0 and S.CurrentRun > S.MaxRuns then
        UpdateStatus("Klaar! " .. S.MaxRuns .. " runs gedaan")
        Log("Dungeon", "Max runs bereikt, stoppen")
        S.Running = false
        S.Phase   = "IDLE"
        UpdatePhaseLabel("IDLE")
        UpdateEnemyLabel(nil, nil)
        return
    end

    -- 7. Opnieuw knop
    UpdateStatus("Wachten op Opnieuw...")
    Log("Dungeon", "Wachten op Opnieuw knop...")
    local deadline = tick() + 25
    while tick() < deadline do
        if not S.Running then return end
        local btn = FindAgainButton()
        if btn and ClickGuiObject(btn) then
            S.Phase = "DUNGEON" -- bewaren VOOR teleport
            Log("Dungeon", "Opnieuw geklikt, Phase=DUNGEON bewaard voor teleport")
            UpdateStatus("Opnieuw! Teleporteren...")
            return
        end
        task.wait(0.5)
    end

    Warn("Dungeon", "Opnieuw knop niet gevonden na 25s")
    UpdateStatus("Opnieuw knop niet gevonden")
    S.Running = false
    S.Phase   = "IDLE"
    UpdatePhaseLabel("IDLE")
end

-- ==============================================================================
-- FASE: LOBBY
-- ==============================================================================
local function RunLobbyPhase()
    S.Phase = "LOBBY"
    UpdatePhaseLabel("LOBBY")
    Log("Lobby", "Start lobby fase")

    WaitForWorldLoad(15)
    if not S.Running then return end

    UpdateStatus("Lobby route lopen...")
    local _, hum, _ = GetCharParts()
    if not hum then
        Warn("Lobby", "Karakter niet gevonden")
        UpdateStatus("Karakter niet gevonden")
        S.Running = false
        return
    end

    for i, step in ipairs(LobbyRoute) do
        if not S.Running then return end
        if step.Type == "Walk" then
            Log("Lobby", "Stap " .. i .. " naar " .. tostring(step.Pos))
            pcall(function()
                hum:MoveTo(step.Pos)
                local t    = tick()
                local done = false
                local conn = hum.MoveToFinished:Connect(function() done = true end)
                while not done and tick() - t < 6 do task.wait(0.1) end
                pcall(function() conn:Disconnect() end)
            end)
        end
        task.wait(0.1)
    end

    if not S.Running then return end

    S.Phase = "PARTY"
    UpdatePhaseLabel("PARTY")
    Log("Lobby", "Route klaar, party aanmaken")
    UpdateStatus("Party aanmaken...")
    local ok9 = TryCreateParty()
    if not ok9 then
        Warn("Lobby", "Party aanmaken mislukt")
        UpdateStatus("Party mislukt, gestopt")
        S.Running = false
        S.Phase   = "IDLE"
        UpdatePhaseLabel("IDLE")
    end
end

-- ==============================================================================
-- AUTOSTART
-- ==============================================================================
local function AutoStart()
    if not S.Running then return end
    UpdateRuns(S.CurrentRun, S.MaxRuns)
    UpdateEnemyLabel(nil, nil)

    -- Wacht op karakter
    UpdateStatus("Wachten op karakter...")
    local t = tick()
    repeat task.wait(0.3) until GetCharParts() or tick() - t > 15

    -- Wereld laden
    WaitForWorldLoad(15)

    local inDungeon = IsInDungeon()
    Log("AutoStart", "Phase=" .. S.Phase .. " | IsInDungeon=" .. tostring(inDungeon))

    if S.Phase == "DUNGEON" or inDungeon then
        UpdatePhaseLabel("DUNGEON")
        UpdateStatus("Dungeon! Run " .. S.CurrentRun)
        RunDungeonPhase()
    else
        UpdatePhaseLabel("LOBBY")
        UpdateStatus("Lobby, starten...")
        RunLobbyPhase()
    end
end

-- ==============================================================================
-- GUI KNOPPEN
-- ==============================================================================
Section:NewDropdown("Moeilijkheid", "Easy / Normal / Hard", {"Easy","Normal","Hard"}, function(val)
    S.Difficulty = val
    Log("Config", "Difficulty = " .. val)
end)

Section:NewDropdown("Aantal Runs", "Hoeveel runs", {"1","2","3","5","10","25","50","Oneindig"}, function(val)
    S.MaxRuns    = val == "Oneindig" and 0 or tonumber(val)
    S.CurrentRun = 0
    UpdateRuns(0, S.MaxRuns)
    Log("Config", "MaxRuns = " .. tostring(S.MaxRuns))
end)

Section:NewDropdown("Deur Timer (s)", "Seconden wachten op deur", {"8","10","12","15","20"}, function(val)
    S.DoorWait = tonumber(val)
    Log("Config", "DoorWait = " .. val .. "s")
end)

Section:NewToggle("Auto Attack", "Aan/Uit", true, function(state)
    S.AutoAttack = state
    Log("Config", "AutoAttack = " .. tostring(state))
end)

ControlSection:NewButton("START", "Start de volledige loop", function()
    if S.Running then UpdateStatus("Al bezig!") return end
    S.Running    = true
    S.CurrentRun = 0
    S.Phase      = "LOBBY"
    UpdateRuns(0, S.MaxRuns)
    UpdateEnemyLabel(nil, nil)
    Log("Control", "START gedrukt")
    task.spawn(AutoStart)
end)

ControlSection:NewButton("STOP", "Stopt alles direct", function()
    S.Running = false
    S.Phase   = "IDLE"
    UpdatePhaseLabel("IDLE")
    UpdateEnemyLabel(nil, nil)
    pcall(function()
        local _, hum, root = GetCharParts()
        if hum and root then hum:MoveTo(root.Position) end
    end)
    Log("Control", "STOP gedrukt")
    UpdateStatus("Gestopt")
end)

ControlSection:NewButton("Party Aanmaken", "Handmatig party starten", function()
    if not S.Running then
        Log("Control", "Handmatige party start")
        task.spawn(TryCreateParty)
    end
end)

-- ==============================================================================
-- BOOT
-- ==============================================================================
UpdateStatus("Idle - Druk op START")
UpdateRuns(S.CurrentRun, S.MaxRuns)
UpdatePhaseLabel(S.Phase)

if S.Running then
    Log("Boot", "Script herladen na teleport, hervat (Phase=" .. S.Phase .. ")")
    task.spawn(AutoStart)
else
    Log("Boot", "Fresh start, wacht op START knop")
end
