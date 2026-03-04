-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v1.5 - Compacte GUI + run time logging
-- ============================================================

local ok, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
end)
if not ok or not Library then
    warn("[PeakEvo] FATAL: UI Library laden mislukt: " .. tostring(Library))
    return
end

local Window = Library.CreateLib("Peak Evo - RB1000", "DarkTheme")

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
-- ==============================================================================
local function Log(module, msg)
    print("[PeakEvo][" .. module .. "] " .. tostring(msg))
end
local function Warn(module, msg)
    warn("[PeakEvo][" .. module .. "] " .. tostring(msg))
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
-- STATE
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
        DoorWait     = 12,
        TotalKills   = 0,
        BestTime     = nil,   -- snelste run in seconden
        RunStartTime = 0,
    }
end
local S = _G.PeakEvo
Log("Boot", "Running=" .. tostring(S.Running) .. " Phase=" .. S.Phase .. " Run=" .. S.CurrentRun)

-- ==============================================================================
-- GUI — alles in 1 tab, 2 compacte secties
-- Sectie 1: Config (instellingen)
-- Sectie 2: Live (status + stats samen)
-- ==============================================================================
local MainTab     = Window:NewTab("Main")
local CfgSection  = MainTab:NewSection("Config")
local LiveSection = MainTab:NewSection("Live")

-- Config
CfgSection:NewDropdown("Difficulty", "Easy / Normal / Hard", {"Easy","Normal","Hard"}, function(val)
    S.Difficulty = val
    Log("Config", "Difficulty=" .. val)
end)

CfgSection:NewDropdown("Runs", "Aantal runs", {"1","2","3","5","10","25","50","Oneindig"}, function(val)
    S.MaxRuns    = val == "Oneindig" and 0 or tonumber(val)
    S.CurrentRun = 0
    Log("Config", "MaxRuns=" .. tostring(S.MaxRuns))
end)

CfgSection:NewDropdown("Deur (s)", "Wacht op deur", {"8","10","12","15","20"}, function(val)
    S.DoorWait = tonumber(val)
    Log("Config", "DoorWait=" .. val .. "s")
end)

CfgSection:NewToggle("Auto Attack", "Aan/Uit", true, function(state)
    S.AutoAttack = state
    Log("Config", "AutoAttack=" .. tostring(state))
end)

-- Live labels (compact, alles zichtbaar zonder scrollen)
local LblStatus  = LiveSection:NewLabel("Status   : Idle")
local LblPhase   = LiveSection:NewLabel("Fase     : IDLE")
local LblRuns    = LiveSection:NewLabel("Runs     : 0 / 0")
local LblEnemy   = LiveSection:NewLabel("Enemies  : -")
local LblTime    = LiveSection:NewLabel("Tijd     : -")
local LblBest    = LiveSection:NewLabel("Best     : -")
local LblKills   = LiveSection:NewLabel("Kills    : 0")

-- Knoppen direct onder de labels
LiveSection:NewButton("START", "Start loop", function()
    if S.Running then
        pcall(function() LblStatus:UpdateLabel("Status   : Al bezig!") end)
        return
    end
    S.Running    = true
    S.CurrentRun = 0
    S.TotalKills = 0
    S.Phase      = "LOBBY"
    pcall(function()
        LblRuns:UpdateLabel("Runs     : 0 / " .. (S.MaxRuns == 0 and "inf" or S.MaxRuns))
        LblKills:UpdateLabel("Kills    : 0")
        LblEnemy:UpdateLabel("Enemies  : -")
        LblTime:UpdateLabel("Tijd     : -")
    end)
    Log("Control", "START")
    task.spawn(function() _G._PeakEvoAutoStart() end)
end)

LiveSection:NewButton("STOP", "Stop direct", function()
    S.Running = false
    S.Phase   = "IDLE"
    pcall(function()
        LblStatus:UpdateLabel("Status   : Gestopt")
        LblPhase:UpdateLabel("Fase     : IDLE")
        LblEnemy:UpdateLabel("Enemies  : -")
        local _, hum, root = unpack({(function()
            local char = LocalPlayer.Character
            if not char then return nil, nil, nil end
            return char, char:FindFirstChild("Humanoid"), char:FindFirstChild("HumanoidRootPart")
        end)()})
        if hum and root then hum:MoveTo(root.Position) end
    end)
    Log("Control", "STOP")
end)

LiveSection:NewButton("Party Aanmaken", "Handmatig", function()
    if not S.Running then
        Log("Control", "Handmatige party")
        task.spawn(function() _G._PeakEvoParty() end)
    end
end)

-- ==============================================================================
-- UPDATE HELPERS
-- ==============================================================================
local function UpdateStatus(text)
    pcall(function() LblStatus:UpdateLabel("Status   : " .. tostring(text)) end)
    Log("Status", text)
end

local function UpdatePhase(phase)
    S.Phase = phase
    pcall(function() LblPhase:UpdateLabel("Fase     : " .. tostring(phase)) end)
end

local function UpdateRuns()
    pcall(function()
        local suffix = S.MaxRuns == 0 and "inf" or tostring(S.MaxRuns)
        LblRuns:UpdateLabel("Runs     : " .. S.CurrentRun .. " / " .. suffix)
    end)
end

local function UpdateEnemy(alive, total)
    pcall(function()
        if alive == nil then
            LblEnemy:UpdateLabel("Enemies  : -")
        else
            LblEnemy:UpdateLabel("Enemies  : " .. alive .. " / " .. total)
        end
    end)
end

local function UpdateKills()
    pcall(function() LblKills:UpdateLabel("Kills    : " .. S.TotalKills) end)
end

local function UpdateTime(timeStr)
    pcall(function() LblTime:UpdateLabel("Tijd     : " .. tostring(timeStr)) end)
end

local function UpdateBest(seconds)
    if not seconds then return end
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    local str  = string.format("%d:%02d", mins, secs)
    pcall(function() LblBest:UpdateLabel("Best     : " .. str) end)
end

-- ==============================================================================
-- WERELD LADEN
-- ==============================================================================
local function WaitForWorldLoad(maxWait)
    maxWait = maxWait or 15
    local deadline = tick() + maxWait
    while tick() < deadline do
        local ok2, ready = pcall(function()
            local stage = Workspace:FindFirstChild("Stage")
            return stage ~= nil and #stage:GetChildren() > 0
        end)
        if ok2 and ready then Log("World", "Stage geladen") task.wait(0.5) return true end
        task.wait(0.3)
    end
    Warn("World", "Stage timeout " .. maxWait .. "s")
    return false
end

-- ==============================================================================
-- DETECTIE
-- ==============================================================================
local function IsInDungeon()
    local ok2, result = pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return false end
        if stage:FindFirstChild("baseStage") then Log("Detect", "Lobby (baseStage)") return false end
        for _, child in pairs(stage:GetChildren()) do
            if string.sub(child.Name, 1, 3) == "map" then
                Log("Detect", "Dungeon: " .. child.Name)
                return true
            end
        end
        Log("Detect", "Geen map gevonden")
        return false
    end)
    return ok2 and result or false
end

-- ==============================================================================
-- ENEMY COUNTER
-- ==============================================================================
local function CountEnemies()
    local alive, total = 0, 0
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
                                if hum.Health > 0 then alive += 1 end
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
-- RUN TIME UITLEZEN
-- PartyOverGui > Frame > bg > time (TextLabel)
-- ==============================================================================
local function GetRunTime()
    local timeStr = nil
    pcall(function()
        local pg    = LocalPlayer:FindFirstChild("PlayerGui")
        local pog   = pg and pg:FindFirstChild("PartyOverGui")
        local frame = pog and pog:FindFirstChild("Frame")
        local bg    = frame and frame:FindFirstChild("bg")
        local lbl   = bg and bg:FindFirstChild("time")
        if lbl and lbl.Text and lbl.Text ~= "" then
            timeStr = lbl.Text
        end
    end)
    return timeStr
end

-- Probeert run tijd te parsen naar seconden voor best-time tracking
local function ParseTimeToSeconds(timeStr)
    if not timeStr then return nil end
    -- Formaten: "1:23", "0:45", "2:03:10" etc.
    local parts = {}
    for part in timeStr:gmatch("%d+") do
        table.insert(parts, tonumber(part))
    end
    if #parts == 2 then
        return parts[1] * 60 + parts[2]
    elseif #parts == 3 then
        return parts[1] * 3600 + parts[2] * 60 + parts[3]
    end
    return nil
end

-- ==============================================================================
-- LOADING GUI WACHTER
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
            Log("Loading", "Klaar")
            task.wait(0.2)
            return
        end
    end
    Warn("Loading", "Timeout 30s")
end

-- ==============================================================================
-- DEUR TIMER
-- ==============================================================================
local function WaitForDoor()
    local wait = S.DoorWait or 12
    Log("Deur", "Wachten " .. wait .. "s...")
    for i = wait, 1, -1 do
        if not S.Running then return end
        UpdateStatus("Deur opent in " .. i .. "s...")
        task.wait(1)
    end
    Log("Deur", "Klaar")
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
            for _, conn in pairs(getconnections(guiObject.MouseButton1Click)) do pcall(function() conn:Fire() end) end
        end)
        pcall(function()
            for _, conn in pairs(getconnections(guiObject.Activated)) do pcall(function() conn:Fire() end) end
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

local function IsPartyWindowOpen()
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
    UpdateStatus("Wachten op party menu...")
    local deadline = tick() + 15
    while tick() < deadline do
        if not S.Running then return false end
        if IsPartyWindowOpen() then Log("Party", "Menu open") break end
        task.wait(0.2)
    end
    if not IsPartyWindowOpen() then
        Warn("Party", "Menu timeout 15s")
        UpdateStatus("Party menu niet verschenen")
        return false
    end

    UpdateStatus("Difficulty: " .. S.Difficulty)
    local d = tick() + 10
    while tick() < d do
        local btn = FindPartyDifficultyButton(S.Difficulty)
        if btn and ClickGuiObject(btn) then Log("Party", "Difficulty OK") break end
        task.wait(0.1)
    end
    task.wait(0.4)

    UpdateStatus("Lobby aanmaken...")
    local c = tick() + 10
    while tick() < c do
        local btn = FindPartyCreateButton()
        if btn and ClickGuiObject(btn) then Log("Party", "Create OK") break end
        task.wait(0.1)
    end
    task.wait(1)

    UpdateStatus("Wachten op Start...")
    local st = tick() + 20
    while tick() < st do
        if not S.Running then return false end
        local btn = FindPartyStartButton()
        if btn then
            ClickGuiObject(btn)
            task.wait(1.5)
            if not FindPartyStartButton() then
                UpdatePhase("DUNGEON") -- bewaar VOOR teleport
                Log("Party", "Start OK, Phase=DUNGEON bewaard")
                UpdateStatus("Teleporteren...")
                return true
            end
        end
        task.wait(0.5)
    end

    Warn("Party", "StartBtn timeout 20s")
    UpdateStatus("StartBtn timeout")
    return false
end

-- ==============================================================================
-- KARAKTER
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
    local myPos = root.Position
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
                            local h = mob:FindFirstChild("Humanoid")
                            local r = mob:FindFirstChild("HumanoidRootPart")
                            if h and r and h.Health > 0 then
                                local d = (r.Position - myPos).Magnitude
                                if d < minDist then minDist = d closest = mob end
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
        root.CFrame = CFrame.new(root.Position, Vector3.new(
            target.HumanoidRootPart.Position.X,
            root.Position.Y,
            target.HumanoidRootPart.Position.Z
        ))
        VirtualUser:ClickButton1(Vector2.new(900, 500))
    end)
end

-- ==============================================================================
-- LOPEN MET COMBAT
-- ==============================================================================
local function WalkToWithCombat(targetPos)
    local char, hum, root = GetCharParts()
    if not char or not hum or not root then return end

    hum:MoveTo(targetPos)
    local stuckTimer   = 0
    local lastPos      = root.Position
    local timeout      = tick() + 300
    local lastEnemyLog = tick()
    local killsBefore  = 0

    -- Tellen hoeveel er dood zijn aan het begin
    local _, totalStart = CountEnemies()

    while tick() < timeout do
        if not S.Running then pcall(function() hum:MoveTo(root.Position) end) return end

        char, hum, root = GetCharParts()
        if not char or not hum or not root then task.wait(1) return end
        if (root.Position - targetPos).Magnitude <= 4 then break end

        -- Enemy counter update (elke 2s)
        if tick() - lastEnemyLog > 2 then
            local alive, total = CountEnemies()
            UpdateEnemy(alive, total)
            -- Kills bijhouden
            local newKills = (totalStart - alive)
            if newKills > killsBefore then
                S.TotalKills = S.TotalKills + (newKills - killsBefore)
                killsBefore  = newKills
                UpdateKills()
                Log("Combat", "Kill! Totaal: " .. S.TotalKills)
            end
            lastEnemyLog = tick()
        end

        if S.AutoAttack then
            local enemy = FindClosestEnemy()
            if enemy then
                pcall(function() hum:MoveTo(root.Position) end)
                local combatT   = tick() + 15
                local eName     = tostring(pcall(function() return enemy.Name end) and enemy.Name or "?")
                repeat
                    if not S.Running then return end
                    char, hum, root = GetCharParts()
                    if not char then return end
                    AttackTarget(enemy)
                    pcall(function()
                        if enemy.HumanoidRootPart then hum:MoveTo(enemy.HumanoidRootPart.Position) end
                    end)
                    task.wait(0.1)
                until tick() > combatT
                    or not enemy or not enemy.Parent
                    or not enemy:FindFirstChild("Humanoid")
                    or enemy.Humanoid.Health <= 0
                pcall(function() hum:MoveTo(targetPos) end)
            end
        end

        char, hum, root = GetCharParts()
        if root then
            if (root.Position - lastPos).Magnitude < 0.5 then
                stuckTimer += 1
                if stuckTimer > 20 then
                    pcall(function() hum.Jump = true end)
                    Log("Move", "Jump (stuck)")
                    stuckTimer = 0
                end
            else stuckTimer = 0 end
            lastPos = root.Position
        end
        task.wait(0.1)
    end

    local alive, total = CountEnemies()
    Log("Combat", "Route klaar | " .. alive .. "/" .. total .. " enemies over")
    UpdateEnemy(alive, total)
end

-- ==============================================================================
-- FASE: DUNGEON
-- ==============================================================================
local function RunDungeonPhase()
    UpdatePhase("DUNGEON")
    Log("Dungeon", "=== Run " .. S.CurrentRun .. " start ===")
    S.RunStartTime = tick()

    WaitForWorldLoad(15)
    if not S.Running then return end

    WaitForLoadingGui(30)
    if not S.Running then return end

    WaitForDoor()
    if not S.Running then return end

    local alive, total = CountEnemies()
    Log("Dungeon", "Enemies bij start: " .. alive .. "/" .. total)
    UpdateEnemy(alive, total)

    UpdateStatus("Run " .. S.CurrentRun .. " | Lopen...")
    WalkToWithCombat(DungeonEnd)
    if not S.Running then return end

    -- Run tijd ophalen uit PartyOverGui
    task.wait(0.5) -- kort wachten zodat GUI verschijnt
    local runTimeStr = GetRunTime()
    local runTimeSec = ParseTimeToSeconds(runTimeStr)

    if runTimeStr then
        UpdateTime(runTimeStr)
        Log("Dungeon", "Run tijd: " .. runTimeStr)
        -- Best time bijhouden
        if runTimeSec and (S.BestTime == nil or runTimeSec < S.BestTime) then
            S.BestTime = runTimeSec
            UpdateBest(S.BestTime)
            Log("Dungeon", "Nieuwe beste tijd: " .. runTimeStr)
        end
    else
        -- Fallback: zelf berekenen
        local elapsed = math.floor(tick() - S.RunStartTime)
        local mins    = math.floor(elapsed / 60)
        local secs    = elapsed % 60
        runTimeStr    = string.format("%d:%02d", mins, secs)
        UpdateTime(runTimeStr)
        Log("Dungeon", "Run tijd (zelf berekend): " .. runTimeStr)
    end

    S.CurrentRun += 1
    UpdateRuns()

    local alive2, total2 = CountEnemies()
    Log("Dungeon", "=== Run " .. S.CurrentRun .. " klaar | Enemies over: " .. alive2 .. "/" .. total2 .. " | Kills: " .. S.TotalKills .. " ===")

    if S.MaxRuns > 0 and S.CurrentRun > S.MaxRuns then
        UpdateStatus("Klaar! " .. S.MaxRuns .. " runs gedaan")
        Log("Dungeon", "Max runs bereikt")
        S.Running = false
        UpdatePhase("IDLE")
        UpdateEnemy(nil, nil)
        return
    end

    -- Opnieuw
    UpdateStatus("Wachten op Opnieuw...")
    local deadline = tick() + 25
    while tick() < deadline do
        if not S.Running then return end
        local btn = FindAgainButton()
        if btn and ClickGuiObject(btn) then
            UpdatePhase("DUNGEON") -- bewaar VOOR teleport
            Log("Dungeon", "Opnieuw geklikt, Phase=DUNGEON bewaard")
            UpdateStatus("Opnieuw! Teleporteren...")
            return
        end
        task.wait(0.5)
    end

    Warn("Dungeon", "Opnieuw knop timeout 25s")
    UpdateStatus("Opnieuw knop niet gevonden")
    S.Running = false
    UpdatePhase("IDLE")
end

-- ==============================================================================
-- FASE: LOBBY
-- ==============================================================================
local function RunLobbyPhase()
    UpdatePhase("LOBBY")
    Log("Lobby", "Start")

    WaitForWorldLoad(15)
    if not S.Running then return end

    UpdateStatus("Lobby route lopen...")
    local _, hum, _ = GetCharParts()
    if not hum then
        Warn("Lobby", "Geen karakter")
        UpdateStatus("Geen karakter")
        S.Running = false
        return
    end

    for i, step in ipairs(LobbyRoute) do
        if not S.Running then return end
        Log("Lobby", "Stap " .. i)
        pcall(function()
            hum:MoveTo(step.Pos)
            local t = tick() local done = false
            local conn = hum.MoveToFinished:Connect(function() done = true end)
            while not done and tick() - t < 6 do task.wait(0.1) end
            pcall(function() conn:Disconnect() end)
        end)
        task.wait(0.1)
    end

    if not S.Running then return end
    UpdatePhase("PARTY")
    UpdateStatus("Party aanmaken...")
    local ok9 = TryCreateParty()
    if not ok9 then
        Warn("Lobby", "Party mislukt")
        UpdateStatus("Party mislukt")
        S.Running = false
        UpdatePhase("IDLE")
    end
end

-- ==============================================================================
-- AUTOSTART
-- ==============================================================================
local function AutoStart()
    if not S.Running then return end
    UpdateRuns()
    UpdateEnemy(nil, nil)

    UpdateStatus("Wachten op karakter...")
    local t = tick()
    repeat task.wait(0.3) until GetCharParts() or tick() - t > 15

    WaitForWorldLoad(15)

    local inDungeon = IsInDungeon()
    Log("AutoStart", "Phase=" .. S.Phase .. " InDungeon=" .. tostring(inDungeon))

    if S.Phase == "DUNGEON" or inDungeon then
        UpdateStatus("Dungeon! Run " .. S.CurrentRun)
        RunDungeonPhase()
    else
        UpdateStatus("Lobby, starten...")
        RunLobbyPhase()
    end
end

-- Global refs zodat knoppen ze kunnen aanroepen
_G._PeakEvoAutoStart = AutoStart
_G._PeakEvoParty     = TryCreateParty

-- ==============================================================================
-- BOOT
-- ==============================================================================
UpdateStatus("Idle - Druk op START")
UpdateRuns()
UpdatePhase(S.Phase)
UpdateKills()

if S.Running then
    Log("Boot", "Hervatten na teleport (Phase=" .. S.Phase .. ")")
    task.spawn(AutoStart)
else
    Log("Boot", "Fresh start")
end
