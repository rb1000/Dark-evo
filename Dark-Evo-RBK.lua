-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v1.7 - State persistence fix + again button fix
-- ============================================================

-- ==============================================================================
-- SERVICES
-- ==============================================================================
local Players             = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local TweenService        = game:GetService("TweenService")
local Workspace           = game.Workspace
local LocalPlayer         = Players.LocalPlayer
if not LocalPlayer then warn("[PeakEvo] Geen LocalPlayer!") return end

-- ==============================================================================
-- LOGGING
-- ==============================================================================
local function Log(mod, msg)  print("[PeakEvo][" .. mod .. "] " .. tostring(msg)) end
local function Warn(mod, msg) warn("[PeakEvo][" .. mod .. "] " .. tostring(msg))  end

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
-- _G.PeakEvo overleeft teleports en script-herlaads
-- WasRunning = true betekent: script was bezig, hervat na reload
-- ==============================================================================
if type(_G.PeakEvo) ~= "table" then
    _G.PeakEvo = {
        Running      = false,
        WasRunning   = false,  -- wordt true zodra START gedrukt, false bij STOP
        AutoAttack   = true,
        AttackRange  = 45,
        Difficulty   = "Easy",
        MaxRuns      = 0,
        CurrentRun   = 0,
        Phase        = "IDLE", -- IDLE / LOBBY / PARTY / DUNGEON
        DoorWait     = 12,
        TotalKills   = 0,
        BestTime     = nil,
        RunStartTime = 0,
    }
end
local S = _G.PeakEvo

Log("Boot", "WasRunning=" .. tostring(S.WasRunning) .. " Phase=" .. S.Phase .. " Run=" .. S.CurrentRun)

-- ==============================================================================
-- CUSTOM GUI
-- ==============================================================================
pcall(function()
    local old = LocalPlayer.PlayerGui:FindFirstChild("PeakEvoGui")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "PeakEvoGui"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = LocalPlayer.PlayerGui

local Main = Instance.new("Frame")
Main.Name             = "Main"
Main.Size             = UDim2.new(0, 300, 0, 340)
Main.Position         = UDim2.new(0, 16, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel  = 0
Main.Active           = true
Main.Draggable        = true
Main.Parent           = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

-- Titelbalk
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
TitleBar.BorderSizePixel  = 0
TitleBar.Parent           = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)
local TFix = Instance.new("Frame") -- fix ronde hoeken onderkant titelbalk
TFix.Size             = UDim2.new(1, 0, 0, 8)
TFix.Position         = UDim2.new(0, 0, 1, -8)
TFix.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
TFix.BorderSizePixel  = 0
TFix.Parent           = TitleBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size                 = UDim2.new(1, -12, 1, 0)
TitleLbl.Position             = UDim2.new(0, 12, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text                 = "⚡ Peak Evo  RB1000"
TitleLbl.TextColor3           = Color3.fromRGB(220, 220, 255)
TitleLbl.TextSize             = 13
TitleLbl.Font                 = Enum.Font.GothamBold
TitleLbl.TextXAlignment       = Enum.TextXAlignment.Left
TitleLbl.Parent               = TitleBar

-- Helpers
local function MakeSectionHeader(text, posY)
    local l = Instance.new("TextLabel")
    l.Size                 = UDim2.new(1, -20, 0, 14)
    l.Position             = UDim2.new(0, 10, 0, posY)
    l.BackgroundTransparency = 1
    l.Text                 = text
    l.TextColor3           = Color3.fromRGB(100, 100, 140)
    l.TextSize             = 10
    l.Font                 = Enum.Font.GothamBold
    l.TextXAlignment       = Enum.TextXAlignment.Left
    l.Parent               = Main
end

local function MakeDivider(posY)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, -20, 0, 1)
    f.Position         = UDim2.new(0, 10, 0, posY)
    f.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    f.BorderSizePixel  = 0
    f.Parent           = Main
end

local function MakeDropdown(label, options, default, posY, onChanged)
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(1, -20, 0, 24)
    container.Position         = UDim2.new(0, 10, 0, posY)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    container.BorderSizePixel  = 0
    container.Parent           = Main
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 5)

    local keyL = Instance.new("TextLabel")
    keyL.Size                 = UDim2.new(0, 90, 1, 0)
    keyL.Position             = UDim2.new(0, 8, 0, 0)
    keyL.BackgroundTransparency = 1
    keyL.Text                 = label
    keyL.TextColor3           = Color3.fromRGB(160, 160, 190)
    keyL.TextSize             = 11
    keyL.Font                 = Enum.Font.Gotham
    keyL.TextXAlignment       = Enum.TextXAlignment.Left
    keyL.Parent               = container

    local valL = Instance.new("TextLabel")
    valL.Size                 = UDim2.new(0, 110, 1, 0)
    valL.Position             = UDim2.new(0, 96, 0, 0)
    valL.BackgroundTransparency = 1
    valL.Text                 = tostring(default)
    valL.TextColor3           = Color3.fromRGB(220, 220, 255)
    valL.TextSize             = 11
    valL.Font                 = Enum.Font.GothamBold
    valL.TextXAlignment       = Enum.TextXAlignment.Left
    valL.Parent               = container

    local arrow = Instance.new("TextLabel")
    arrow.Size                 = UDim2.new(0, 18, 1, 0)
    arrow.Position             = UDim2.new(1, -20, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text                 = "›"
    arrow.TextColor3           = Color3.fromRGB(120, 120, 160)
    arrow.TextSize             = 14
    arrow.Font                 = Enum.Font.GothamBold
    arrow.Parent               = container

    local idx = 1
    for i, v in ipairs(options) do if tostring(v) == tostring(default) then idx = i break end end

    local btn = Instance.new("TextButton")
    btn.Size                 = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                 = ""
    btn.Parent               = container
    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        valL.Text = tostring(options[idx])
        onChanged(options[idx])
    end)
end

local function MakeToggle(label, default, posY, onChanged)
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(1, -20, 0, 24)
    container.Position         = UDim2.new(0, 10, 0, posY)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    container.BorderSizePixel  = 0
    container.Parent           = Main
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 5)

    local keyL = Instance.new("TextLabel")
    keyL.Size                 = UDim2.new(1, -50, 1, 0)
    keyL.Position             = UDim2.new(0, 8, 0, 0)
    keyL.BackgroundTransparency = 1
    keyL.Text                 = label
    keyL.TextColor3           = Color3.fromRGB(160, 160, 190)
    keyL.TextSize             = 11
    keyL.Font                 = Enum.Font.Gotham
    keyL.TextXAlignment       = Enum.TextXAlignment.Left
    keyL.Parent               = container

    local state = default
    local pill = Instance.new("Frame")
    pill.Size             = UDim2.new(0, 36, 0, 16)
    pill.Position         = UDim2.new(1, -44, 0.5, -8)
    pill.BackgroundColor3 = state and Color3.fromRGB(80, 180, 100) or Color3.fromRGB(60, 60, 80)
    pill.BorderSizePixel  = 0
    pill.Parent           = container
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 12, 0, 12)
    knob.Position         = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel  = 0
    knob.Parent           = pill
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size                 = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                 = ""
    btn.Parent               = container
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(pill, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(80,180,100) or Color3.fromRGB(60,60,80)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
        }):Play()
        onChanged(state)
    end)
end

local function MakeButton(text, posX, posY, w, color)
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(0, w, 0, 26)
    btn.Position          = UDim2.new(0, posX, 0, posY)
    btn.BackgroundColor3  = color
    btn.BorderSizePixel   = 0
    btn.Text              = text
    btn.TextColor3        = Color3.fromRGB(220, 220, 255)
    btn.TextSize          = 12
    btn.Font              = Enum.Font.GothamBold
    btn.AutoButtonColor   = false
    btn.Parent            = Main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = color:Lerp(Color3.fromRGB(255,255,255), 0.12)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = color}):Play()
    end)
    return btn
end

-- Stat box helper (2-kolom grid)
local function MakeStatBox(key, col, row)
    local x = col == 0 and 10 or 155
    local y = 188 + row * 22

    local box = Instance.new("Frame")
    box.Size             = UDim2.new(0, 135, 0, 20)
    box.Position         = UDim2.new(0, x, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    box.BorderSizePixel  = 0
    box.Parent           = Main
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

    local kL = Instance.new("TextLabel")
    kL.Size                 = UDim2.new(0, 48, 1, 0)
    kL.Position             = UDim2.new(0, 6, 0, 0)
    kL.BackgroundTransparency = 1
    kL.Text                 = key
    kL.TextColor3           = Color3.fromRGB(100, 100, 140)
    kL.TextSize             = 10
    kL.Font                 = Enum.Font.Gotham
    kL.TextXAlignment       = Enum.TextXAlignment.Left
    kL.Parent               = box

    local vL = Instance.new("TextLabel")
    vL.Size                 = UDim2.new(1, -54, 1, 0)
    vL.Position             = UDim2.new(0, 50, 0, 0)
    vL.BackgroundTransparency = 1
    vL.Text                 = "-"
    vL.TextColor3           = Color3.fromRGB(220, 220, 255)
    vL.TextSize             = 10
    vL.Font                 = Enum.Font.GothamBold
    vL.TextXAlignment       = Enum.TextXAlignment.Left
    vL.Parent               = box

    return vL
end

-- ==============================================================================
-- GUI LAYOUT
-- 0-32   titelbalk
-- 36     CONFIG header
-- 52-136 dropdowns + toggle
-- 166    divider
-- 172    LIVE header
-- 188    stats grid
-- 278    divider
-- 282    knoppen
-- ==============================================================================
MakeSectionHeader("CONFIG", 36)
MakeDropdown("Difficulty", {"Easy","Normal","Hard"}, S.Difficulty, 52, function(v)
    S.Difficulty = v Log("Config","Difficulty="..v)
end)
MakeDropdown("Runs", {"1","2","3","5","10","25","50","Oneindig"}, "Oneindig", 80, function(v)
    S.MaxRuns = v == "Oneindig" and 0 or tonumber(v)
    S.CurrentRun = 0 Log("Config","MaxRuns="..tostring(S.MaxRuns))
end)
MakeDropdown("Deur wacht", {"8","10","12","15","20"}, "12", 108, function(v)
    S.DoorWait = tonumber(v) Log("Config","DoorWait="..v.."s")
end)
MakeToggle("Auto Attack", S.AutoAttack, 136, function(v)
    S.AutoAttack = v Log("Config","AutoAttack="..tostring(v))
end)

MakeDivider(166)
MakeSectionHeader("LIVE", 172)

-- Stats: 2 kolommen x 4 rijen
local ValStatus = MakeStatBox("Status", 0, 0)
local ValPhase  = MakeStatBox("Fase",   1, 0)
local ValRuns   = MakeStatBox("Runs",   0, 1)
local ValEnemy  = MakeStatBox("Enemies",1, 1)
local ValTime   = MakeStatBox("Tijd",   0, 2)
local ValBest   = MakeStatBox("Best",   1, 2)
local ValKills  = MakeStatBox("Kills",  0, 3)

local FaseKleur = {
    IDLE    = Color3.fromRGB(120,120,140),
    LOBBY   = Color3.fromRGB(100,180,255),
    PARTY   = Color3.fromRGB(255,200,80),
    DUNGEON = Color3.fromRGB(80,220,120),
}

MakeDivider(278)

local BtnStart = MakeButton("▶ START", 10,  282, 84, Color3.fromRGB(55,150,80))
local BtnStop  = MakeButton("⏹ STOP",  108, 282, 84, Color3.fromRGB(170,55,55))
local BtnParty = MakeButton("🎉 Party", 206, 282, 84, Color3.fromRGB(90,70,150))

-- ==============================================================================
-- UPDATE HELPERS
-- ==============================================================================
local function UpdateStatus(text)
    pcall(function() ValStatus.Text = tostring(text) end)
    Log("Status", text)
end

local function UpdatePhase(phase)
    S.Phase = phase
    pcall(function()
        ValPhase.Text       = tostring(phase)
        ValPhase.TextColor3 = FaseKleur[phase] or Color3.fromRGB(220,220,255)
    end)
end

local function UpdateRuns()
    pcall(function()
        local s = S.MaxRuns == 0 and "inf" or tostring(S.MaxRuns)
        ValRuns.Text = S.CurrentRun .. "/" .. s
    end)
end

local function UpdateEnemy(alive, total)
    pcall(function() ValEnemy.Text = alive and (alive.."/"..total) or "-" end)
end

local function UpdateKills()
    pcall(function() ValKills.Text = tostring(S.TotalKills) end)
end

local function UpdateTime(str)
    pcall(function() ValTime.Text = str or "-" end)
end

local function UpdateBest(sec)
    if not sec then return end
    pcall(function() ValBest.Text = string.format("%d:%02d", math.floor(sec/60), sec%60) end)
end

-- ==============================================================================
-- WERELD LADEN
-- ==============================================================================
local function WaitForWorldLoad(maxWait)
    maxWait = maxWait or 15
    local deadline = tick() + maxWait
    UpdateStatus("Wereld laden...")
    while tick() < deadline do
        local ok2, ready = pcall(function()
            local s = Workspace:FindFirstChild("Stage")
            return s ~= nil and #s:GetChildren() > 0
        end)
        if ok2 and ready then
            Log("World", "Stage geladen ("..#Workspace.Stage:GetChildren().." children)")
            task.wait(0.5)
            return true
        end
        task.wait(0.3)
    end
    Warn("World", "Stage timeout "..maxWait.."s")
    return false
end

-- ==============================================================================
-- DETECTIE
-- ==============================================================================
local function IsInDungeon()
    local ok2, result = pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return false end
        if stage:FindFirstChild("baseStage") then Log("Detect","baseStage = lobby") return false end
        for _, child in pairs(stage:GetChildren()) do
            if string.sub(child.Name, 1, 3) == "map" then
                Log("Detect", "map gevonden: " .. child.Name)
                return true
            end
        end
        Log("Detect", "geen map = lobby")
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
                            local h = mob:FindFirstChild("Humanoid")
                            if h then total += 1 if h.Health > 0 then alive += 1 end end
                        end)
                    end
                end
            end
        end
    end)
    return alive, total
end

-- ==============================================================================
-- RUN TIJD UIT PartyOverGui > Frame > bg > time
-- ==============================================================================
local function GetRunTime()
    local t = nil
    pcall(function()
        local pg  = LocalPlayer:FindFirstChild("PlayerGui")
        local pog = pg and pg:FindFirstChild("PartyOverGui")
        local bg  = pog and pog.Frame and pog.Frame:FindFirstChild("bg")
        local lbl = bg and bg:FindFirstChild("time")
        if lbl and lbl.Text ~= "" then t = lbl.Text end
    end)
    if t then Log("Time","Tijd uit PartyOverGui: "..t) end
    return t
end

local function ParseTime(str)
    if not str then return nil end
    local parts = {}
    for p in str:gmatch("%d+") do table.insert(parts, tonumber(p)) end
    if #parts == 2 then return parts[1]*60 + parts[2]
    elseif #parts == 3 then return parts[1]*3600 + parts[2]*60 + parts[3] end
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
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local ld = pg and pg:FindFirstChild("LoadingGui")
            isLoading = ld ~= nil and ld.Enabled == true
        end)
        if isLoading then UpdateStatus("Loading...") task.wait(0.3)
        else Log("Loading","Klaar") task.wait(0.2) return end
    end
    Warn("Loading","Timeout 30s, doorgaan")
end

-- ==============================================================================
-- DEUR TIMER
-- ==============================================================================
local function WaitForDoor()
    local wait = S.DoorWait or 12
    Log("Deur", "Wachten "..wait.."s")
    for i = wait, 1, -1 do
        if not S.Running then return end
        UpdateStatus("Deur in "..i.."s...")
        task.wait(1)
    end
    Log("Deur", "Klaar")
end

-- ==============================================================================
-- ROUTES
-- ==============================================================================
local LobbyRoute = {
    {Pos = Vector3.new(-1682.3, 6.5,   54.2)},
    {Pos = Vector3.new(-1685.6, 6.3,    0.1)},
    {Pos = Vector3.new(-1689.6, 22.6, -321.2)},
    {Pos = Vector3.new(-1686.7, 22.6, -319.1)},
    {Pos = Vector3.new(-1744.0, 22.6, -322.5)},
}
local DungeonEnd = Vector3.new(-880.3, 31.6, -507.3)

-- ==============================================================================
-- KLIK SYSTEEM
-- ==============================================================================
local function ClickGuiObject(obj)
    if not obj then return false end
    local s = pcall(function()
        if not obj.AbsolutePosition then return end
        local cx = obj.AbsolutePosition.X + obj.AbsoluteSize.X / 2
        local cy = obj.AbsolutePosition.Y + obj.AbsoluteSize.Y / 2
        pcall(function() obj:Activate() end)
        pcall(function()
            for _, c in pairs(getconnections(obj.MouseButton1Click)) do pcall(function() c:Fire() end) end
        end)
        pcall(function()
            for _, c in pairs(getconnections(obj.Activated)) do pcall(function() c:Fire() end) end
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
    local args = {...}
    local cur  = LocalPlayer:FindFirstChild("PlayerGui")
    for _, n in ipairs(args) do
        if not cur then return nil end
        local ok3, r = pcall(function() return cur:FindFirstChild(n) end)
        cur = ok3 and r or nil
    end
    return cur
end

local function FindDiffBtn(diff)
    local map = {Easy="btn4", Normal="btn5", Hard="btn6"}
    local name = map[diff or S.Difficulty]
    if not name then return nil end
    local left = SafeFind("PartyGui","Frame","createBg","left")
    if not left then return nil end
    local ok4, btn = pcall(function() return left:FindFirstChild(name) end)
    if ok4 and btn and btn:IsA("GuiObject") and btn.Visible then return btn end
    return nil
end

local function IsPartyOpen()
    return FindDiffBtn("Easy") or FindDiffBtn("Normal") or FindDiffBtn("Hard")
end

local function FindCreateBtn()
    local r = SafeFind("PartyGui","Frame","createBg","right")
    if not r then return nil end
    local ok5, b = pcall(function() return r:FindFirstChild("createBtn") end)
    if ok5 and b and b.Visible then return b end
    return nil
end

local function FindStartBtn()
    local r = SafeFind("PartyGui","Frame","roomBg","right")
    if not r then return nil end
    local ok6, b = pcall(function() return r:FindFirstChild("StartBtn") end)
    if ok6 and b and b.Visible then return b end
    return nil
end

-- AGAIN BUTTON — uitgebreide debug zodat we precies zien waarom hij hem mist
local function FindAgainBtn()
    local found = nil
    pcall(function()
        local pg  = LocalPlayer:FindFirstChild("PlayerGui")
        local pog = pg and pg:FindFirstChild("PartyOverGui")
        if not pog then Log("Again","PartyOverGui niet gevonden") return end
        local frame = pog:FindFirstChild("Frame")
        if not frame then Log("Again","Frame niet gevonden") return end
        local bg = frame:FindFirstChild("bg")
        if not bg then Log("Again","bg niet gevonden") return end
        local btn = bg:FindFirstChild("againbtn")
        if not btn then Log("Again","againbtn niet gevonden") return end
        Log("Again","againbtn gevonden | Visible="..tostring(btn.Visible))
        if btn.Visible then found = btn end
    end)
    return found
end

local function TryCreateParty()
    UpdateStatus("Wacht party menu...")
    local dl = tick() + 15
    while tick() < dl do
        if not S.Running then return false end
        if IsPartyOpen() then Log("Party","Menu open") break end
        task.wait(0.2)
    end
    if not IsPartyOpen() then
        Warn("Party","Menu timeout 15s")
        UpdateStatus("Party menu timeout")
        return false
    end

    UpdateStatus("Difficulty: "..S.Difficulty)
    local d = tick()+10
    while tick() < d do
        local b = FindDiffBtn(S.Difficulty)
        if b and ClickGuiObject(b) then Log("Party","Difficulty OK") break end
        task.wait(0.1)
    end
    task.wait(0.4)

    UpdateStatus("Lobby aanmaken...")
    local c = tick()+10
    while tick() < c do
        local b = FindCreateBtn()
        if b and ClickGuiObject(b) then Log("Party","Create OK") break end
        task.wait(0.1)
    end
    task.wait(1)

    UpdateStatus("Wacht Start...")
    local st = tick()+20
    while tick() < st do
        if not S.Running then return false end
        local b = FindStartBtn()
        if b then
            ClickGuiObject(b) task.wait(1.5)
            if not FindStartBtn() then
                -- Bewaar fase EN WasRunning VOOR teleport
                S.WasRunning = true
                UpdatePhase("DUNGEON")
                Log("Party","Start OK, WasRunning=true Phase=DUNGEON bewaard")
                UpdateStatus("Teleporteren...")
                return true
            end
        end
        task.wait(0.5)
    end
    Warn("Party","Start timeout 20s")
    UpdateStatus("Start timeout")
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
            target.HumanoidRootPart.Position.X, root.Position.Y,
            target.HumanoidRootPart.Position.Z))
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
    local stuckTimer  = 0
    local lastPos     = root.Position
    local timeout     = tick() + 300
    local lastELog    = tick()
    local _, totalStart = CountEnemies()
    local killsBefore = 0

    while tick() < timeout do
        if not S.Running then pcall(function() hum:MoveTo(root.Position) end) return end

        char, hum, root = GetCharParts()
        if not char or not hum or not root then task.wait(1) return end
        if (root.Position - targetPos).Magnitude <= 4 then break end

        -- Enemy counter (elke 2s)
        if tick() - lastELog > 2 then
            local alive, total = CountEnemies()
            UpdateEnemy(alive, total)
            local newKills = totalStart - alive
            if newKills > killsBefore then
                S.TotalKills += (newKills - killsBefore)
                killsBefore = newKills
                UpdateKills()
            end
            lastELog = tick()
        end

        if S.AutoAttack then
            local enemy = FindClosestEnemy()
            if enemy then
                pcall(function() hum:MoveTo(root.Position) end)
                local ct = tick() + 15
                repeat
                    if not S.Running then return end
                    char, hum, root = GetCharParts()
                    if not char then return end
                    AttackTarget(enemy)
                    pcall(function()
                        if enemy.HumanoidRootPart then hum:MoveTo(enemy.HumanoidRootPart.Position) end
                    end)
                    task.wait(0.1)
                until tick() > ct
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
                    Log("Move","Jump (stuck)")
                    stuckTimer = 0
                end
            else stuckTimer = 0 end
            lastPos = root.Position
        end
        task.wait(0.1)
    end
    local alive, total = CountEnemies()
    Log("Combat","Route klaar | "..alive.."/"..total.." over")
    UpdateEnemy(alive, total)
end

-- ==============================================================================
-- FASE: DUNGEON
-- ==============================================================================
local function RunDungeonPhase()
    UpdatePhase("DUNGEON")
    S.WasRunning = true  -- altijd bewaren
    Log("Dungeon","=== Run "..S.CurrentRun.." start ===")
    S.RunStartTime = tick()

    WaitForWorldLoad(15)   if not S.Running then return end
    WaitForLoadingGui(30)  if not S.Running then return end
    WaitForDoor()          if not S.Running then return end

    local alive, total = CountEnemies()
    Log("Dungeon","Start enemies: "..alive.."/"..total)
    UpdateEnemy(alive, total)

    UpdateStatus("Run "..S.CurrentRun.." | Lopen...")
    WalkToWithCombat(DungeonEnd)
    if not S.Running then return end

    -- Tijd ophalen — wacht tot PartyOverGui zichtbaar is (max 8s)
    UpdateStatus("Run klaar, wacht resultaat...")
    local rtStr, rtSec = nil, nil
    local rtDeadline = tick() + 8
    while tick() < rtDeadline do
        rtStr = GetRunTime()
        if rtStr then break end
        task.wait(0.3)
    end
    rtSec = ParseTime(rtStr)

    if rtStr then
        UpdateTime(rtStr)
        if rtSec and (not S.BestTime or rtSec < S.BestTime) then
            S.BestTime = rtSec
            UpdateBest(S.BestTime)
            Log("Dungeon","Nieuwe best: "..rtStr)
        end
    else
        local e = math.floor(tick() - S.RunStartTime)
        local fb = string.format("%d:%02d", math.floor(e/60), e%60)
        UpdateTime(fb)
        Log("Dungeon","Tijd fallback: "..fb)
    end

    S.CurrentRun += 1
    UpdateRuns()
    Log("Dungeon","=== Run "..S.CurrentRun.." klaar | Kills: "..S.TotalKills.." ===")

    if S.MaxRuns > 0 and S.CurrentRun > S.MaxRuns then
        UpdateStatus("Klaar! "..S.MaxRuns.." runs gedaan")
        Log("Dungeon","Max runs bereikt, stoppen")
        S.Running    = false
        S.WasRunning = false
        UpdatePhase("IDLE")
        UpdateEnemy(nil, nil)
        return
    end

    -- Again knop — langere timeout + elke iteratie debug log
    UpdateStatus("Wacht op Opnieuw...")
    Log("Dungeon","Zoeken naar againbtn (max 30s)...")
    local agDeadline = tick() + 30
    while tick() < agDeadline do
        if not S.Running then return end
        local btn = FindAgainBtn()
        if btn then
            Log("Dungeon","againbtn gevonden, klikken...")
            ClickGuiObject(btn)
            task.wait(1)
            -- Controleer of teleport begon (btn verdwenen)
            if not FindAgainBtn() then
                S.WasRunning = true
                UpdatePhase("DUNGEON")
                Log("Dungeon","Teleport gestart, Phase=DUNGEON WasRunning=true bewaard")
                UpdateStatus("Opnieuw! Teleporteren...")
                return
            else
                Log("Dungeon","Knop nog zichtbaar, opnieuw proberen...")
            end
        end
        task.wait(0.5)
    end

    Warn("Dungeon","againbtn timeout 30s, stoppen")
    UpdateStatus("Opnieuw knop niet gevonden")
    S.Running    = false
    S.WasRunning = false
    UpdatePhase("IDLE")
end

-- ==============================================================================
-- FASE: LOBBY
-- ==============================================================================
local function RunLobbyPhase()
    UpdatePhase("LOBBY")
    S.WasRunning = true
    Log("Lobby","Start")

    WaitForWorldLoad(15)
    if not S.Running then return end

    UpdateStatus("Lobby route...")
    local _, hum, _ = GetCharParts()
    if not hum then
        Warn("Lobby","Geen karakter")
        S.Running = false
        return
    end

    for i, step in ipairs(LobbyRoute) do
        if not S.Running then return end
        Log("Lobby","Stap "..i)
        pcall(function()
            hum:MoveTo(step.Pos)
            local t = tick() local done = false
            local conn = hum.MoveToFinished:Connect(function() done = true end)
            while not done and tick()-t < 6 do task.wait(0.1) end
            pcall(function() conn:Disconnect() end)
        end)
        task.wait(0.1)
    end

    if not S.Running then return end
    UpdatePhase("PARTY")
    UpdateStatus("Party aanmaken...")
    local ok9 = TryCreateParty()
    if not ok9 then
        Warn("Lobby","Party mislukt")
        UpdateStatus("Party mislukt, gestopt")
        S.Running    = false
        S.WasRunning = false
        UpdatePhase("IDLE")
    end
end

-- ==============================================================================
-- AUTOSTART
-- Bepaalt op basis van WasRunning + Phase + IsInDungeon wat er moet
-- ==============================================================================
local function AutoStart()
    if not S.Running then return end
    UpdateRuns() UpdateEnemy(nil, nil)

    -- Wacht op karakter
    UpdateStatus("Wacht karakter...")
    local t = tick()
    repeat task.wait(0.3) until GetCharParts() or tick()-t > 15

    -- Wacht op wereld
    WaitForWorldLoad(15)

    local inDungeon = IsInDungeon()
    Log("AutoStart","WasRunning="..tostring(S.WasRunning).." Phase="..S.Phase.." InDungeon="..tostring(inDungeon))

    -- Keuze: Phase=DUNGEON OF we zijn al in dungeon gespot
    if S.Phase == "DUNGEON" or inDungeon then
        Log("AutoStart","→ Dungeon fase")
        UpdateStatus("Dungeon! Run "..S.CurrentRun)
        RunDungeonPhase()
    else
        Log("AutoStart","→ Lobby fase")
        UpdateStatus("Lobby, starten...")
        RunLobbyPhase()
    end
end

-- ==============================================================================
-- KNOP EVENTS
-- ==============================================================================
BtnStart.MouseButton1Click:Connect(function()
    if S.Running then UpdateStatus("Al bezig!") return end
    S.Running    = true
    S.WasRunning = true
    S.CurrentRun = 0
    S.TotalKills = 0
    S.Phase      = "LOBBY"
    UpdateRuns() UpdateKills() UpdateEnemy(nil,nil) UpdateTime(nil)
    Log("Control","START")
    task.spawn(AutoStart)
end)

BtnStop.MouseButton1Click:Connect(function()
    S.Running    = false
    S.WasRunning = false
    S.Phase      = "IDLE"
    UpdatePhase("IDLE") UpdateEnemy(nil,nil)
    pcall(function()
        local _, hum, root = GetCharParts()
        if hum and root then hum:MoveTo(root.Position) end
    end)
    UpdateStatus("Gestopt")
    Log("Control","STOP — WasRunning=false, Phase=IDLE")
end)

BtnParty.MouseButton1Click:Connect(function()
    if not S.Running then Log("Control","Handmatige party") task.spawn(TryCreateParty) end
end)

-- ==============================================================================
-- BOOT
-- Als WasRunning=true weet het script dat het midden in een sessie was
-- en hervat het automatisch zonder dat de gebruiker START hoeft te drukken
-- ==============================================================================
UpdateStatus("Idle")
UpdateRuns() UpdatePhase(S.Phase) UpdateKills()
if S.BestTime then UpdateBest(S.BestTime) end

if S.WasRunning then
    -- Script herladen na teleport, hervat automatisch
    S.Running = true
    Log("Boot","WasRunning=true → automatisch hervatten (Phase="..S.Phase..")")
    task.spawn(AutoStart)
else
    Log("Boot","Fresh start, wacht op START")
    UpdateStatus("Idle - Druk op START")
end
