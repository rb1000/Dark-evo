-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v1.3 - Teleport-proof state + deur + loading detectie
-- 
-- HOE HET WERKT NA TELEPORT:
--   Loader herlaadt dit script → _G.PeakEvo nog intact
--   → WaitForWorldLoad() wacht tot Stage geladen is
--   → _G.PeakEvo.Phase bepaalt wat er moet gebeuren
--   → DUNGEON phase = LoadingGui wachten + deur wachten + lopen
-- ============================================================

local ok, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
end)
if not ok or not Library then
    warn("[PeakEvo] UI Library laden mislukt:", tostring(Library))
    return
end

local Window = Library.CreateLib("Peak Evo - RB1000 (Stable)", "DarkTheme")

-- ==============================================================================
-- SERVICES
-- ==============================================================================
local function GetService(name)
    local s, r = pcall(function() return game:GetService(name) end)
    return s and r or nil
end

local Players             = GetService("Players")
local VirtualInputManager = GetService("VirtualInputManager")
local VirtualUser         = GetService("VirtualUser")
local Workspace           = game.Workspace
local LocalPlayer         = Players and Players.LocalPlayer

if not LocalPlayer then warn("[PeakEvo] Geen LocalPlayer!") return end

-- ==============================================================================
-- ANTI-AFK
-- ==============================================================================
pcall(function()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end)

-- ==============================================================================
-- STATE — _G overleeft elke teleport
-- Alleen aanmaken als het nog niet bestaat (fresh start)
-- Na teleport blijven alle waarden bewaard
-- ==============================================================================
if type(_G.PeakEvo) ~= "table" then
    _G.PeakEvo = {
        Running      = false,
        AutoAttack   = true,
        AttackRange  = 45,
        Difficulty   = "Easy",
        MaxRuns      = 0,
        CurrentRun   = 0,
        -- Fases: IDLE → LOBBY → PARTY → DUNGEON → (loop)
        Phase        = "IDLE",
    }
end
local S = _G.PeakEvo
print("[Boot] State geladen: Running=" .. tostring(S.Running) .. " Phase=" .. S.Phase .. " Run=" .. S.CurrentRun)

-- ==============================================================================
-- GUI SETUP (vroeg definiëren zodat UpdateStatus overal beschikbaar is)
-- ==============================================================================
local MainTab        = Window:NewTab("Main")
local Section        = MainTab:NewSection("Instellingen")
local ControlSection = MainTab:NewSection("Controls")
local StatusLabel    = Section:NewLabel("Status: Idle")
local RunsLabel      = Section:NewLabel("Runs: 0 / 0")

local function UpdateStatus(text)
    pcall(function() StatusLabel:UpdateLabel("Status: " .. tostring(text)) end)
    print("[Status]", text)
end

local function UpdateRuns(current, max)
    pcall(function()
        local suffix = (max == 0) and " / inf" or (" / " .. max)
        RunsLabel:UpdateLabel("Runs: " .. current .. suffix)
    end)
end

-- ==============================================================================
-- WERELD LADEN WACHTER
-- Na een teleport is Workspace nog leeg. Wacht tot Stage bestaat en children heeft.
-- ==============================================================================
local function WaitForWorldLoad(maxWait)
    maxWait = maxWait or 15
    local deadline = tick() + maxWait
    UpdateStatus("Wereld laden...")
    while tick() < deadline do
        local ok2, ready = pcall(function()
            local stage = Workspace:FindFirstChild("Stage")
            return stage ~= nil and #stage:GetChildren() > 0
        end)
        if ok2 and ready then
            print("[World] Stage geladen")
            task.wait(0.5) -- klein extra moment voor stabiliteit
            return true
        end
        task.wait(0.3)
    end
    warn("[World] Stage niet gevonden na " .. maxWait .. "s")
    return false
end

-- ==============================================================================
-- DETECTIE: IN DUNGEON?
-- baseStage = lobby, map* = dungeon
-- ==============================================================================
local function IsInDungeon()
    local ok2, result = pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return false end
        if stage:FindFirstChild("baseStage") then
            print("[Detect] baseStage gevonden = lobby")
            return false
        end
        for _, child in pairs(stage:GetChildren()) do
            if string.sub(child.Name, 1, 3) == "map" then
                print("[Detect] Dungeon map gevonden:", child.Name)
                return true
            end
        end
        print("[Detect] Geen map gevonden in Stage")
        return false
    end)
    return ok2 and result or false
end

-- ==============================================================================
-- LOADINGGUI WACHTER
-- PlayerGui > LoadingGui moet weg zijn voordat we beginnen
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
            print("[Loading] Klaar")
            task.wait(0.2)
            return
        end
    end
    warn("[Loading] Timeout 30s, toch doorgaan")
end

-- ==============================================================================
-- DEUR WACHTER
-- Zoekt door1 in Stage > map* > Art
-- Wacht tot door1.Parent == nil (object verwijderd = timer op 0)
-- ==============================================================================
local function FindDoor()
    local found = nil
    pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return end
        for _, map in pairs(stage:GetChildren()) do
            if string.sub(map.Name, 1, 3) == "map" then
                local art = map:FindFirstChild("Art")
                if art then
                    local door = art:FindFirstChild("door1")
                    if door then
                        found = door
                        print("[Deur] Gevonden:", door:GetFullName())
                        return
                    end
                end
            end
        end
    end)
    return found
end

local function WaitForDoorToOpen(maxWait)
    maxWait    = maxWait or 90
    local door = FindDoor()

    if not door then
        print("[Deur] Geen deur aanwezig, direct doorgaan")
        return
    end

    print("[Deur] Wachten tot deur verdwijnt (max " .. maxWait .. "s)...")
    local deadline = tick() + maxWait
    local elapsed  = 0

    while tick() < deadline do
        if not S.Running then return end

        local doorGone = false
        pcall(function()
            doorGone = door.Parent == nil
        end)

        if doorGone then
            print("[Deur] Deur verdwenen, doorgaan!")
            UpdateStatus("Deur open!")
            task.wait(0.5)
            return
        end

        elapsed += 0.5
        UpdateStatus("Wachten op deur... (" .. math.floor(elapsed) .. "s)")
        task.wait(0.5)
    end

    warn("[Deur] Timeout " .. maxWait .. "s, toch doorgaan")
    UpdateStatus("Deur timeout, doorgaan")
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
    UpdateStatus("Wachten op party menu...")
    local deadline = tick() + 15
    while tick() < deadline do
        if not S.Running then return false end
        if IsPartyDifficultyWindowOpen() then break end
        task.wait(0.2)
    end
    if not IsPartyDifficultyWindowOpen() then
        UpdateStatus("Party menu niet verschenen")
        return false
    end

    UpdateStatus("Difficulty: " .. S.Difficulty)
    local d_deadline = tick() + 10
    while tick() < d_deadline do
        local btn = FindPartyDifficultyButton(S.Difficulty)
        if btn and ClickGuiObject(btn) then break end
        task.wait(0.1)
    end
    task.wait(0.4)

    UpdateStatus("Lobby aanmaken...")
    local c_deadline = tick() + 10
    while tick() < c_deadline do
        local btn = FindPartyCreateButton()
        if btn and ClickGuiObject(btn) then break end
        task.wait(0.1)
    end
    task.wait(1)

    UpdateStatus("Wachten op StartBtn...")
    local s_deadline = tick() + 20
    while tick() < s_deadline do
        if not S.Running then return false end
        local btn = FindPartyStartButton()
        if btn then
            ClickGuiObject(btn)
            task.wait(1.5)
            if not FindPartyStartButton() then
                -- Sla op dat we naar DUNGEON gaan VOOR de teleport
                S.Phase = "DUNGEON"
                UpdateStatus("Party gestart! Teleporteren...")
                return true
            end
        end
        task.wait(0.5)
    end

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
    local myPos               = root.Position
    local closest, minDist    = nil, S.AttackRange

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
-- LOPEN MET COMBAT
-- ==============================================================================
local function WalkToWithCombat(targetPos)
    local char, hum, root = GetCharParts()
    if not char or not hum or not root then return end

    hum:MoveTo(targetPos)
    local stuckTimer = 0
    local lastPos    = root.Position
    local timeout    = tick() + 300

    while tick() < timeout do
        if not S.Running then
            pcall(function() hum:MoveTo(root.Position) end)
            return
        end

        char, hum, root = GetCharParts()
        if not char or not hum or not root then task.wait(1) return end

        if (root.Position - targetPos).Magnitude <= 4 then break end

        if S.AutoAttack then
            local enemy = FindClosestEnemy()
            if enemy then
                pcall(function() hum:MoveTo(root.Position) end)
                local combatTimeout = tick() + 15
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
                pcall(function() hum:MoveTo(targetPos) end)
            end
        end

        char, hum, root = GetCharParts()
        if root then
            if (root.Position - lastPos).Magnitude < 0.5 then
                stuckTimer += 1
                if stuckTimer > 20 then
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
end

-- ==============================================================================
-- FASE: DUNGEON
-- Wordt aangeroepen na elke teleport naar dungeon
-- ==============================================================================
local function RunDungeonPhase()
    S.Phase = "DUNGEON" -- bewaar fase voor als script opnieuw laadt

    -- 1. Wacht tot wereld en loading screen klaar zijn
    WaitForWorldLoad(15)
    if not S.Running then return end

    WaitForLoadingGui(30)
    if not S.Running then return end

    -- 2. Wacht tot deur verdwijnt
    WaitForDoorToOpen(90)
    if not S.Running then return end

    -- 3. Loop naar einde dungeon
    UpdateStatus("Run " .. S.CurrentRun .. " | Lopen...")
    WalkToWithCombat(DungeonEnd)
    if not S.Running then return end

    -- 4. Run tellen
    S.CurrentRun += 1
    UpdateRuns(S.CurrentRun, S.MaxRuns)
    print("[Dungeon] Run " .. S.CurrentRun .. " klaar")

    if S.MaxRuns > 0 and S.CurrentRun > S.MaxRuns then
        UpdateStatus("Klaar! " .. S.MaxRuns .. " runs gedaan")
        S.Running = false
        S.Phase   = "IDLE"
        return
    end

    -- 5. Opnieuw knop (teleporteert terug naar dungeon)
    UpdateStatus("Wachten op Opnieuw knop...")
    local deadline = tick() + 25
    while tick() < deadline do
        if not S.Running then return end
        local btn = FindAgainButton()
        if btn and ClickGuiObject(btn) then
            -- BELANGRIJK: phase bewaren VOOR teleport
            S.Phase = "DUNGEON"
            UpdateStatus("Opnieuw! Teleporteren...")
            print("[Dungeon] Opnieuw geklikt, phase=DUNGEON bewaard")
            return
        end
        task.wait(0.5)
    end

    warn("[Again] Timeout")
    UpdateStatus("Opnieuw knop niet gevonden")
    S.Running = false
    S.Phase   = "IDLE"
end

-- ==============================================================================
-- FASE: LOBBY
-- ==============================================================================
local function RunLobbyPhase()
    S.Phase = "LOBBY"

    WaitForWorldLoad(15)
    if not S.Running then return end

    UpdateStatus("Lobby route lopen...")
    local _, hum, _ = GetCharParts()
    if not hum then
        UpdateStatus("Karakter niet gevonden")
        S.Running = false
        return
    end

    for _, step in ipairs(LobbyRoute) do
        if not S.Running then return end
        if step.Type == "Walk" then
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
    UpdateStatus("Party aanmaken...")
    local ok9 = TryCreateParty()
    -- TryCreateParty zet S.Phase = "DUNGEON" al voor teleport
    if not ok9 then
        UpdateStatus("Party mislukt, gestopt")
        S.Running = false
        S.Phase   = "IDLE"
    end
end

-- ==============================================================================
-- AUTOSTART — bepaalt op basis van _G state wat er moet gebeuren
-- ==============================================================================
local function AutoStart()
    if not S.Running then return end
    UpdateRuns(S.CurrentRun, S.MaxRuns)

    -- Wacht op karakter
    UpdateStatus("Wachten op karakter...")
    local t = tick()
    repeat task.wait(0.3) until GetCharParts() or tick() - t > 15

    -- Wacht tot wereld geladen is
    WaitForWorldLoad(15)

    print("[AutoStart] Phase=" .. S.Phase .. " InDungeon=" .. tostring(IsInDungeon()))

    -- Keuze op basis van opgeslagen phase + werkelijke locatie
    if S.Phase == "DUNGEON" or IsInDungeon() then
        UpdateStatus("Dungeon! Run " .. S.CurrentRun)
        RunDungeonPhase()
    else
        UpdateStatus("Lobby, starten...")
        RunLobbyPhase()
    end
end

-- ==============================================================================
-- GUI KNOPPEN
-- ==============================================================================
Section:NewDropdown("Moeilijkheid", "Easy / Normal / Hard", {"Easy","Normal","Hard"}, function(val)
    S.Difficulty = val
    print("[Config] Difficulty:", val)
end)

Section:NewDropdown("Aantal Runs", "Hoeveel runs", {"1","2","3","5","10","25","50","Oneindig"}, function(val)
    S.MaxRuns    = val == "Oneindig" and 0 or tonumber(val)
    S.CurrentRun = 0
    UpdateRuns(0, S.MaxRuns)
    print("[Config] Runs:", val)
end)

Section:NewToggle("Auto Attack", "Aan/Uit", true, function(state)
    S.AutoAttack = state
end)

ControlSection:NewButton("START", "Start de volledige loop", function()
    if S.Running then UpdateStatus("Al bezig!") return end
    S.Running    = true
    S.CurrentRun = 0
    S.Phase      = "LOBBY"
    UpdateRuns(0, S.MaxRuns)
    task.spawn(AutoStart)
end)

ControlSection:NewButton("STOP", "Stopt alles direct", function()
    S.Running = false
    S.Phase   = "IDLE"
    pcall(function()
        local _, hum, root = GetCharParts()
        if hum and root then hum:MoveTo(root.Position) end
    end)
    UpdateStatus("Gestopt")
end)

ControlSection:NewButton("Party Aanmaken", "Handmatig party starten", function()
    if not S.Running then task.spawn(TryCreateParty) end
end)

-- ==============================================================================
-- BOOT — na elke (her)laad bepaalt _G.PeakEvo.Phase wat er gebeurt
-- ==============================================================================
UpdateStatus("Idle - Druk op START")
UpdateRuns(S.CurrentRun, S.MaxRuns)

if S.Running then
    -- Script herladen na teleport, hervat automatisch
    print("[Boot] Hervatten - Phase=" .. S.Phase)
    task.spawn(AutoStart)
else
    print("[Boot] Fresh start, wacht op START knop")
end
