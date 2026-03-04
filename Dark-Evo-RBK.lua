-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- ============================================================

local ok, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
end)
if not ok or not Library then
    warn("[PeakEvo] UI Library laden mislukt:", Library)
    return
end

local Window = Library.CreateLib("Peak Evo - RB1000 (Stable)", "DarkTheme")

-- ==============================================================================
-- SERVICES (veilig ophalen)
-- ==============================================================================
local function GetService(name)
    local s, result = pcall(function() return game:GetService(name) end)
    return s and result or nil
end

local Players            = GetService("Players")
local VirtualInputManager = GetService("VirtualInputManager")
local VirtualUser        = GetService("VirtualUser")
local Workspace          = game.Workspace

local LocalPlayer = Players and Players.LocalPlayer
if not LocalPlayer then warn("[PeakEvo] Geen LocalPlayer!") return end

-- ==============================================================================
-- ANTI-AFK (veilig)
-- ==============================================================================
local _afkConn
pcall(function()
    _afkConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end)

-- ==============================================================================
-- STATE (_G zodat hij teleport overleeft)
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
    }
end
local S = _G.PeakEvo

-- ==============================================================================
-- DETECTIE
-- ==============================================================================
local function IsInDungeon()
    local ok2, result = pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return false end
        if stage:FindFirstChild("baseStage") then return false end
        for _, child in pairs(stage:GetChildren()) do
            if string.sub(child.Name, 1, 3) == "map" then return true end
        end
        return false
    end)
    return ok2 and result or false
end

-- ==============================================================================
-- GUI SETUP
-- ==============================================================================
local MainTab        = Window:NewTab("Main")
local Section        = MainTab:NewSection("⚙️ Instellingen")
local ControlSection = MainTab:NewSection("▶️ Controls")
local StatusLabel    = Section:NewLabel("Status: Idle")
local RunsLabel      = Section:NewLabel("Runs: 0 / 0")

local function UpdateStatus(text)
    pcall(function() StatusLabel:UpdateLabel("Status: " .. tostring(text)) end)
    print("[Status]", text)
end

local function UpdateRuns(current, max)
    pcall(function()
        if max == 0 then
            RunsLabel:UpdateLabel("Runs: " .. current .. " / ∞")
        else
            RunsLabel:UpdateLabel("Runs: " .. current .. " / " .. max)
        end
    end)
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
-- KLIK SYSTEEM (crash-safe)
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
    if s then print("[Klik]", pcall(function() return guiObject:GetFullName() end)) end
    return s
end

-- ==============================================================================
-- PARTY FUNCTIES (veilig)
-- ==============================================================================
local function SafeFind(...)
    local args = {...}
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
    local btnName = buttonMap[difficulty or S.Difficulty]
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
        UpdateStatus("❌ Party menu niet verschenen")
        return false
    end

    -- Difficulty
    UpdateStatus("Difficulty selecteren: " .. S.Difficulty)
    local d_deadline = tick() + 10
    while tick() < d_deadline do
        local btn = FindPartyDifficultyButton(S.Difficulty)
        if btn and ClickGuiObject(btn) then break end
        task.wait(0.1)
    end
    task.wait(0.4)

    -- Create
    UpdateStatus("Lobby aanmaken...")
    local c_deadline = tick() + 10
    while tick() < c_deadline do
        local btn = FindPartyCreateButton()
        if btn and ClickGuiObject(btn) then break end
        task.wait(0.1)
    end
    task.wait(1)

    -- Start (blijf klikken tot teleport)
    UpdateStatus("Wachten op StartBtn...")
    local s_deadline = tick() + 20
    while tick() < s_deadline do
        if not S.Running then return false end
        local btn = FindPartyStartButton()
        if btn then
            ClickGuiObject(btn)
            task.wait(1.5)
            if not FindPartyStartButton() then
                UpdateStatus("Party gestart! Teleporteren...")
                return true
            end
        end
        task.wait(0.5)
    end

    UpdateStatus("❌ StartBtn timeout")
    return false
end

-- ==============================================================================
-- KARAKTER HELPERS (veilig)
-- ==============================================================================
local function GetCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum  = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
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
                        local ok8, _ = pcall(function()
                            local hum2 = mob:FindFirstChild("Humanoid")
                            local mroot = mob:FindFirstChild("HumanoidRootPart")
                            if hum2 and mroot and hum2.Health > 0 then
                                local dist = (mroot.Position - myPos).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    closest = mob
                                end
                            end
                        end)
                        if not ok8 then end -- skip kapotte mob
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
-- LOPEN MET COMBAT (stabiel, geen infinite loops)
-- ==============================================================================
local function WalkToWithCombat(targetPos)
    local char, hum, root = GetCharParts()
    if not char or not hum or not root then return end

    hum:MoveTo(targetPos)
    local stuckTimer = 0
    local lastPos    = root.Position
    local timeout    = tick() + 300 -- max 5 minuten per route

    while tick() < timeout do
        if not S.Running then
            pcall(function() hum:MoveTo(root.Position) end)
            return
        end

        -- Karakter check (na teleport kan het nil zijn)
        char, hum, root = GetCharParts()
        if not char or not hum or not root then task.wait(1) return end

        local dist = (root.Position - targetPos).Magnitude
        if dist <= 4 then break end

        -- Combat
        if S.AutoAttack then
            local enemy = FindClosestEnemy()
            if enemy then
                pcall(function() hum:MoveTo(root.Position) end)
                local combatTimeout = tick() + 15 -- max 15s per vijand
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

        -- Stuck check
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

    UpdateStatus("Run " .. S.CurrentRun .. " | Dungeon lopen + killen...")
    WalkToWithCombat(DungeonEnd)
    if not S.Running then return end

    S.CurrentRun += 1
    UpdateRuns(S.CurrentRun, S.MaxRuns)

    if S.MaxRuns > 0 and S.CurrentRun > S.MaxRuns then
        UpdateStatus("✅ Klaar! " .. S.MaxRuns .. " runs gedaan")
        S.Running = false
        S.Phase   = "IDLE"
        return
    end

    -- Opnieuw knop
    UpdateStatus("Wachten op 'Opnieuw' knop...")
    local deadline = tick() + 25
    while tick() < deadline do
        if not S.Running then return end
        local btn = FindAgainButton()
        if btn and ClickGuiObject(btn) then
            UpdateStatus("Opnieuw geklikt! Teleporteren...")
            S.Phase = "DUNGEON"
            return
        end
        task.wait(0.5)
    end

    warn("[Again] Timeout - opnieuw knop niet gevonden")
    UpdateStatus("❌ Opnieuw knop timeout")
    S.Running = false
    S.Phase   = "IDLE"
end

local function RunLobbyPhase()
    S.Phase = "LOBBY"
    UpdateStatus("Lobby route lopen...")

    local _, hum, _ = GetCharParts()
    if not hum then
        UpdateStatus("❌ Karakter niet gevonden")
        S.Running = false
        return
    end

    for _, step in ipairs(LobbyRoute) do
        if not S.Running then return end
        if step.Type == "Walk" then
            pcall(function()
                hum:MoveTo(step.Pos)
                -- Wacht max 6 seconden per stap
                local t = tick()
                local conn
                local done = false
                conn = hum.MoveToFinished:Connect(function() done = true end)
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
    if not ok9 then
        UpdateStatus("❌ Party mislukt, gestopt")
        S.Running = false
        S.Phase   = "IDLE"
    end
end

local function AutoStart()
    if not S.Running then return end
    UpdateRuns(S.CurrentRun, S.MaxRuns)

    -- Kort wachten zodat karakter geladen is
    task.wait(1.5)

    local _, _, root = GetCharParts()
    if not root then
        UpdateStatus("⏳ Wachten op karakter...")
        local t = tick()
        repeat task.wait(0.5) until GetCharParts() or tick() - t > 15
    end

    if IsInDungeon() then
        print("[AutoStart] Dungeon gedetecteerd, phase:", S.Phase)
        UpdateStatus("Run " .. S.CurrentRun .. " | Dungeon gedetecteerd!")
        RunDungeonPhase()
    else
        print("[AutoStart] Lobby gedetecteerd")
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

Section:NewDropdown("Aantal Runs", "Hoeveel runs uitvoeren", {"1","2","3","5","10","25","50","Oneindig"}, function(val)
    S.MaxRuns    = val == "Oneindig" and 0 or tonumber(val)
    S.CurrentRun = 0
    UpdateRuns(0, S.MaxRuns)
    print("[Config] Runs:", val)
end)

Section:NewToggle("Auto Attack", "Aan/Uit", true, function(state)
    S.AutoAttack = state
    print("[Config] AutoAttack:", state)
end)

ControlSection:NewButton("▶ START", "Start de volledige loop", function()
    if S.Running then
        UpdateStatus("⚠️ Al bezig!")
        return
    end
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
        local _, hum, root = GetCharParts()
        if hum and root then hum:MoveTo(root.Position) end
    end)
    UpdateStatus("Gestopt")
end)

ControlSection:NewButton("🎉 Party Aanmaken", "Maakt handmatig een party aan", function()
    if not S.Running then
        task.spawn(TryCreateParty)
    end
end)

-- ==============================================================================
-- BOOT LOGICA
-- ==============================================================================
UpdateStatus("Idle - Druk op START")
UpdateRuns(S.CurrentRun, S.MaxRuns)

if S.Running then
    print("[Boot] Hervat na teleport - Phase:", S.Phase)
    task.spawn(AutoStart)
elseif IsInDungeon() and S.Phase ~= "IDLE" then
    print("[Boot] Vangnet: dungeon gevonden, herstel...")
    S.Running = true
    task.spawn(AutoStart)
else
    print("[Boot] Fresh start klaar")
end
