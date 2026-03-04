-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v1.6 - Custom compacte GUI + run time logging
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
        pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new(0,0)) end)
    end)
end)

-- ==============================================================================
-- STATE
-- ==============================================================================
if type(_G.PeakEvo) ~= "table" then
    _G.PeakEvo = {
        Running=false, AutoAttack=true, AttackRange=45,
        Difficulty="Easy", MaxRuns=0, CurrentRun=0,
        Phase="IDLE", DoorWait=12, TotalKills=0,
        BestTime=nil, RunStartTime=0,
    }
end
local S = _G.PeakEvo
Log("Boot","Running="..tostring(S.Running).." Phase="..S.Phase.." Run="..S.CurrentRun)

-- ==============================================================================
-- CUSTOM GUI
-- ==============================================================================
-- Verwijder oude GUI als script herlaadt
pcall(function()
    local old = LocalPlayer.PlayerGui:FindFirstChild("PeakEvoGui")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "PeakEvoGui"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = LocalPlayer.PlayerGui

-- Hoofdframe
local Main = Instance.new("Frame")
Main.Name            = "Main"
Main.Size            = UDim2.new(0, 300, 0, 340)
Main.Position        = UDim2.new(0, 16, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active          = true
Main.Draggable       = true
Main.Parent          = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

-- Schaduw
local Shadow = Instance.new("Frame")
Shadow.Size              = UDim2.new(1, 6, 1, 6)
Shadow.Position          = UDim2.new(0, -3, 0, 3)
Shadow.BackgroundColor3  = Color3.fromRGB(0,0,0)
Shadow.BackgroundTransparency = 0.7
Shadow.BorderSizePixel   = 0
Shadow.ZIndex            = 0
Shadow.Parent            = Main
Instance.new("UICorner", Shadow).CornerRadius = UDim.new(0, 10)

-- Titelbalk
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
TitleBar.BorderSizePixel  = 0
TitleBar.Parent           = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)
-- Fix: onderste hoeken van titelbalk recht
local TitleFix = Instance.new("Frame")
TitleFix.Size             = UDim2.new(1, 0, 0, 8)
TitleFix.Position         = UDim2.new(0, 0, 1, -8)
TitleFix.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
TitleFix.BorderSizePixel  = 0
TitleFix.Parent           = TitleBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size             = UDim2.new(1, -40, 1, 0)
TitleLbl.Position         = UDim2.new(0, 12, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text             = "⚡ Peak Evo - RB1000"
TitleLbl.TextColor3       = Color3.fromRGB(220, 220, 255)
TitleLbl.TextSize         = 13
TitleLbl.Font             = Enum.Font.GothamBold
TitleLbl.TextXAlignment   = Enum.TextXAlignment.Left
TitleLbl.Parent           = TitleBar

-- Helper: maak een label
local function MakeLabel(parent, text, posY, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1, -20, 0, 16)
    lbl.Position             = UDim2.new(0, 10, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = text
    lbl.TextColor3           = color or Color3.fromRGB(180, 180, 200)
    lbl.TextSize             = 12
    lbl.Font                 = Enum.Font.Gotham
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.Parent               = parent
    return lbl
end

-- Helper: maak een knop
local function MakeButton(parent, text, posY, height, accent)
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(1, -20, 0, height or 26)
    btn.Position          = UDim2.new(0, 10, 0, posY)
    btn.BackgroundColor3  = accent or Color3.fromRGB(60, 60, 80)
    btn.BorderSizePixel   = 0
    btn.Text              = text
    btn.TextColor3        = Color3.fromRGB(220, 220, 255)
    btn.TextSize          = 12
    btn.Font              = Enum.Font.GothamBold
    btn.AutoButtonColor   = false
    btn.Parent            = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    -- Hover effect
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = (accent or Color3.fromRGB(60,60,80)):Lerp(Color3.fromRGB(255,255,255), 0.1)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = accent or Color3.fromRGB(60,60,80)
        }):Play()
    end)
    return btn
end

-- Helper: maak dropdown
local function MakeDropdown(parent, label, options, default, posY, onChanged)
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(1, -20, 0, 24)
    container.Position         = UDim2.new(0, 10, 0, posY)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    container.BorderSizePixel  = 0
    container.Parent           = parent
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(0, 90, 1, 0)
    lbl.Position             = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = label
    lbl.TextColor3           = Color3.fromRGB(160, 160, 190)
    lbl.TextSize             = 11
    lbl.Font                 = Enum.Font.Gotham
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.Parent               = container

    local valLbl = Instance.new("TextLabel")
    valLbl.Size              = UDim2.new(0, 100, 1, 0)
    valLbl.Position          = UDim2.new(0, 95, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text              = tostring(default)
    valLbl.TextColor3        = Color3.fromRGB(220, 220, 255)
    valLbl.TextSize          = 11
    valLbl.Font              = Enum.Font.GothamBold
    valLbl.TextXAlignment    = Enum.TextXAlignment.Left
    valLbl.Parent            = container

    -- Klikken cyclet door opties
    local idx = 1
    for i, v in ipairs(options) do
        if tostring(v) == tostring(default) then idx = i break end
    end

    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text              = ""
    btn.Parent            = container
    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        valLbl.Text = tostring(options[idx])
        onChanged(options[idx])
    end)

    local arrow = Instance.new("TextLabel")
    arrow.Size             = UDim2.new(0, 20, 1, 0)
    arrow.Position         = UDim2.new(1, -22, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text             = "›"
    arrow.TextColor3       = Color3.fromRGB(120, 120, 160)
    arrow.TextSize         = 14
    arrow.Font             = Enum.Font.GothamBold
    arrow.Parent           = container

    return container, valLbl
end

-- Helper: toggle
local function MakeToggle(parent, label, default, posY, onChanged)
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(1, -20, 0, 24)
    container.Position         = UDim2.new(0, 10, 0, posY)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    container.BorderSizePixel  = 0
    container.Parent           = parent
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1, -50, 1, 0)
    lbl.Position             = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = label
    lbl.TextColor3           = Color3.fromRGB(160, 160, 190)
    lbl.TextSize             = 11
    lbl.Font                 = Enum.Font.Gotham
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.Parent               = container

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
    btn.Size              = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text              = ""
    btn.Parent            = container
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
    return container
end

-- Divider lijn
local function MakeDivider(parent, posY)
    local line = Instance.new("Frame")
    line.Size             = UDim2.new(1, -20, 0, 1)
    line.Position         = UDim2.new(0, 10, 0, posY)
    line.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    line.BorderSizePixel  = 0
    line.Parent           = parent
    return line
end

-- Sectie header
local function MakeSectionHeader(parent, text, posY)
    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1, -20, 0, 14)
    lbl.Position             = UDim2.new(0, 10, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = text
    lbl.TextColor3           = Color3.fromRGB(100, 100, 140)
    lbl.TextSize             = 10
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.Parent               = parent
    return lbl
end

-- ==============================================================================
-- GUI LAYOUT  (alles past in 340px hoogte)
-- ==============================================================================
-- Y=0..32 = titelbalk
-- Y=36    = Config header
-- Y=52..148 = dropdowns + toggle (4x 26px met 2px gap)
-- Y=154   = divider
-- Y=158   = Live header
-- Y=174   = stats grid (2 kolommen)
-- Y=272   = knoppen

-- CONFIG sectie
MakeSectionHeader(Main, "CONFIG", 36)

MakeDropdown(Main, "Difficulty", {"Easy","Normal","Hard"}, S.Difficulty, 52, function(v)
    S.Difficulty = v Log("Config","Difficulty="..v)
end)
MakeDropdown(Main, "Runs", {"1","2","3","5","10","25","50","Oneindig"}, "Oneindig", 80, function(v)
    S.MaxRuns = v == "Oneindig" and 0 or tonumber(v)
    S.CurrentRun = 0 Log("Config","MaxRuns="..tostring(S.MaxRuns))
end)
MakeDropdown(Main, "Deur wacht", {"8","10","12","15","20"}, "12", 108, function(v)
    S.DoorWait = tonumber(v) Log("Config","DoorWait="..v.."s")
end)
MakeToggle(Main, "Auto Attack", S.AutoAttack, 136, function(v)
    S.AutoAttack = v Log("Config","AutoAttack="..tostring(v))
end)

MakeDivider(Main, 166)

-- LIVE sectie
MakeSectionHeader(Main, "LIVE", 172)

-- Stats grid: 2 kolommen, 4 rijen
local function MakeStatBox(parent, key, val, col, row)
    -- col=0 links, col=1 rechts
    local x = col == 0 and 10 or 155
    local y = 186 + row * 20
    local w = 135

    local box = Instance.new("Frame")
    box.Size             = UDim2.new(0, w, 0, 18)
    box.Position         = UDim2.new(0, x, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    box.BorderSizePixel  = 0
    box.Parent           = parent
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

    local keyLbl = Instance.new("TextLabel")
    keyLbl.Size                 = UDim2.new(0, 50, 1, 0)
    keyLbl.Position             = UDim2.new(0, 6, 0, 0)
    keyLbl.BackgroundTransparency = 1
    keyLbl.Text                 = key
    keyLbl.TextColor3           = Color3.fromRGB(100, 100, 140)
    keyLbl.TextSize             = 10
    keyLbl.Font                 = Enum.Font.Gotham
    keyLbl.TextXAlignment       = Enum.TextXAlignment.Left
    keyLbl.Parent               = box

    local valLbl = Instance.new("TextLabel")
    valLbl.Size                 = UDim2.new(1, -56, 1, 0)
    valLbl.Position             = UDim2.new(0, 52, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                 = val
    valLbl.TextColor3           = Color3.fromRGB(220, 220, 255)
    valLbl.TextSize             = 10
    valLbl.Font                 = Enum.Font.GothamBold
    valLbl.TextXAlignment       = Enum.TextXAlignment.Left
    valLbl.Parent               = box

    return valLbl
end

local ValStatus  = MakeStatBox(Main, "Status",   "Idle",    0, 0)
local ValPhase   = MakeStatBox(Main, "Fase",     "IDLE",    1, 0)
local ValRuns    = MakeStatBox(Main, "Runs",     "0/0",     0, 1)
local ValEnemy   = MakeStatBox(Main, "Enemies",  "-",       1, 1)
local ValTime    = MakeStatBox(Main, "Tijd",     "-",       0, 2)
local ValBest    = MakeStatBox(Main, "Best",     "-",       1, 2)
local ValKills   = MakeStatBox(Main, "Kills",    "0",       0, 3)
-- Extra: fase kleur indicator
local FaseColors = {
    IDLE    = Color3.fromRGB(120,120,140),
    LOBBY   = Color3.fromRGB(100,180,255),
    PARTY   = Color3.fromRGB(255,200,80),
    DUNGEON = Color3.fromRGB(80,220,120),
}

MakeDivider(Main, 272)

-- Knoppen (3 naast elkaar)
local BtnStart = MakeButton(Main, "▶ START", 278, 26, Color3.fromRGB(60, 160, 90))
BtnStart.Size = UDim2.new(0, 84, 0, 26)
BtnStart.Position = UDim2.new(0, 10, 0, 278)

local BtnStop = MakeButton(Main, "⏹ STOP", 278, 26, Color3.fromRGB(180, 60, 60))
BtnStop.Size = UDim2.new(0, 84, 0, 26)
BtnStop.Position = UDim2.new(0, 108, 0, 278)

local BtnParty = MakeButton(Main, "🎉 Party", 278, 26, Color3.fromRGB(100, 80, 160))
BtnParty.Size = UDim2.new(0, 84, 0, 26)
BtnParty.Position = UDim2.new(0, 206, 0, 278)

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
        ValPhase.TextColor3 = FaseColors[phase] or Color3.fromRGB(220,220,255)
    end)
end

local function UpdateRuns()
    pcall(function()
        local suffix = S.MaxRuns == 0 and "inf" or tostring(S.MaxRuns)
        ValRuns.Text = S.CurrentRun .. "/" .. suffix
    end)
end

local function UpdateEnemy(alive, total)
    pcall(function()
        ValEnemy.Text = alive and (alive .. "/" .. total) or "-"
    end)
end

local function UpdateKills()
    pcall(function() ValKills.Text = tostring(S.TotalKills) end)
end

local function UpdateTime(str)
    pcall(function() ValTime.Text = str and tostring(str) or "-" end)
end

local function UpdateBest(sec)
    if not sec then return end
    local str = string.format("%d:%02d", math.floor(sec/60), sec%60)
    pcall(function() ValBest.Text = str end)
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
        if ok2 and ready then Log("World","Stage geladen") task.wait(0.5) return true end
        task.wait(0.3)
    end
    Warn("World","Stage timeout "..maxWait.."s") return false
end

-- ==============================================================================
-- DETECTIE
-- ==============================================================================
local function IsInDungeon()
    local ok2, result = pcall(function()
        local stage = Workspace:FindFirstChild("Stage")
        if not stage then return false end
        if stage:FindFirstChild("baseStage") then Log("Detect","Lobby") return false end
        for _, child in pairs(stage:GetChildren()) do
            if string.sub(child.Name,1,3) == "map" then Log("Detect","Dungeon: "..child.Name) return true end
        end
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
            if string.sub(map.Name,1,3) == "map" then
                local folder = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                if folder then
                    for _, mob in pairs(folder:GetChildren()) do
                        pcall(function()
                            local h = mob:FindFirstChild("Humanoid")
                            if h then total+=1 if h.Health>0 then alive+=1 end end
                        end)
                    end
                end
            end
        end
    end)
    return alive, total
end

-- ==============================================================================
-- RUN TIME UIT PartyOverGui
-- ==============================================================================
local function GetRunTime()
    local t = nil
    pcall(function()
        local pg  = LocalPlayer:FindFirstChild("PlayerGui")
        local pog = pg and pg:FindFirstChild("PartyOverGui")
        local lbl = pog and pog:FindFirstChild("Frame") and pog.Frame:FindFirstChild("bg") and pog.Frame.bg:FindFirstChild("time")
        if lbl and lbl.Text ~= "" then t = lbl.Text end
    end)
    return t
end

local function ParseTime(str)
    if not str then return nil end
    local parts = {}
    for p in str:gmatch("%d+") do table.insert(parts, tonumber(p)) end
    if #parts == 2 then return parts[1]*60+parts[2]
    elseif #parts == 3 then return parts[1]*3600+parts[2]*60+parts[3] end
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
    Warn("Loading","Timeout 30s")
end

-- ==============================================================================
-- DEUR TIMER
-- ==============================================================================
local function WaitForDoor()
    local wait = S.DoorWait or 12
    Log("Deur","Wachten "..wait.."s")
    for i = wait, 1, -1 do
        if not S.Running then return end
        UpdateStatus("Deur in "..i.."s...")
        task.wait(1)
    end
end

-- ==============================================================================
-- ROUTES
-- ==============================================================================
local LobbyRoute = {
    {Pos=Vector3.new(-1682.3,6.5,54.2)},
    {Pos=Vector3.new(-1685.6,6.3,0.1)},
    {Pos=Vector3.new(-1689.6,22.6,-321.2)},
    {Pos=Vector3.new(-1686.7,22.6,-319.1)},
    {Pos=Vector3.new(-1744.0,22.6,-322.5)},
}
local DungeonEnd = Vector3.new(-880.3, 31.6, -507.3)

-- ==============================================================================
-- KLIK SYSTEEM
-- ==============================================================================
local function ClickGuiObject(obj)
    if not obj then return false end
    local s = pcall(function()
        if not obj.AbsolutePosition then return end
        local cx = obj.AbsolutePosition.X + obj.AbsoluteSize.X/2
        local cy = obj.AbsolutePosition.Y + obj.AbsoluteSize.Y/2
        pcall(function() obj:Activate() end)
        pcall(function() for _,c in pairs(getconnections(obj.MouseButton1Click)) do pcall(function() c:Fire() end) end end)
        pcall(function() for _,c in pairs(getconnections(obj.Activated)) do pcall(function() c:Fire() end) end end)
        VirtualInputManager:SendMouseButtonEvent(cx,cy,0,true,game,0)
        VirtualInputManager:SendMouseButtonEvent(cx,cy,0,false,game,0)
    end)
    return s
end

-- ==============================================================================
-- PARTY FUNCTIES
-- ==============================================================================
local function SafeFind(...)
    local args = {...}
    local cur  = LocalPlayer:FindFirstChild("PlayerGui")
    for _,n in ipairs(args) do
        if not cur then return nil end
        local ok3,r = pcall(function() return cur:FindFirstChild(n) end)
        cur = ok3 and r or nil
    end
    return cur
end

local function FindDiffBtn(diff)
    local map = {Easy="btn4",Normal="btn5",Hard="btn6"}
    local name = map[diff or S.Difficulty] if not name then return nil end
    local left = SafeFind("PartyGui","Frame","createBg","left") if not left then return nil end
    local ok4,btn = pcall(function() return left:FindFirstChild(name) end)
    if ok4 and btn and btn:IsA("GuiObject") and btn.Visible then return btn end
    return nil
end

local function IsPartyOpen() return FindDiffBtn("Easy") or FindDiffBtn("Normal") or FindDiffBtn("Hard") end

local function FindCreateBtn()
    local r = SafeFind("PartyGui","Frame","createBg","right") if not r then return nil end
    local ok5,b = pcall(function() return r:FindFirstChild("createBtn") end)
    if ok5 and b and b.Visible then return b end return nil
end

local function FindStartBtn()
    local r = SafeFind("PartyGui","Frame","roomBg","right") if not r then return nil end
    local ok6,b = pcall(function() return r:FindFirstChild("StartBtn") end)
    if ok6 and b and b.Visible then return b end return nil
end

local function FindAgainBtn()
    local bg = SafeFind("PartyOverGui","Frame","bg") if not bg then return nil end
    local ok7,b = pcall(function() return bg:FindFirstChild("againbtn") end)
    if ok7 and b and b.Visible then return b end return nil
end

local function TryCreateParty()
    UpdateStatus("Wacht party menu...")
    local dl = tick()+15
    while tick()<dl do
        if not S.Running then return false end
        if IsPartyOpen() then Log("Party","Menu open") break end
        task.wait(0.2)
    end
    if not IsPartyOpen() then Warn("Party","Menu timeout") UpdateStatus("Party menu timeout") return false end

    UpdateStatus("Difficulty: "..S.Difficulty)
    local d=tick()+10 while tick()<d do local b=FindDiffBtn(S.Difficulty) if b and ClickGuiObject(b) then break end task.wait(0.1) end
    task.wait(0.4)

    UpdateStatus("Lobby aanmaken...")
    local c=tick()+10 while tick()<c do local b=FindCreateBtn() if b and ClickGuiObject(b) then Log("Party","Create OK") break end task.wait(0.1) end
    task.wait(1)

    UpdateStatus("Wacht Start...")
    local st=tick()+20
    while tick()<st do
        if not S.Running then return false end
        local b=FindStartBtn()
        if b then
            ClickGuiObject(b) task.wait(1.5)
            if not FindStartBtn() then
                UpdatePhase("DUNGEON")
                Log("Party","Start OK, Phase=DUNGEON")
                UpdateStatus("Teleporteren...")
                return true
            end
        end
        task.wait(0.5)
    end
    Warn("Party","Start timeout") UpdateStatus("Start timeout") return false
end

-- ==============================================================================
-- KARAKTER
-- ==============================================================================
local function GetCharParts()
    local char = LocalPlayer.Character
    if not char then return nil,nil,nil end
    return char, char:FindFirstChild("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

-- ==============================================================================
-- COMBAT
-- ==============================================================================
local function FindClosestEnemy()
    local _,_,root = GetCharParts() if not root then return nil end
    local myPos = root.Position
    local closest, minDist = nil, S.AttackRange
    pcall(function()
        local stage = Workspace:FindFirstChild("Stage") if not stage then return end
        for _, map in pairs(stage:GetChildren()) do
            if map.Name ~= "baseStage" then
                local folder = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                if folder then
                    for _, mob in pairs(folder:GetChildren()) do
                        pcall(function()
                            local h=mob:FindFirstChild("Humanoid") local r=mob:FindFirstChild("HumanoidRootPart")
                            if h and r and h.Health>0 then
                                local d=(r.Position-myPos).Magnitude
                                if d<minDist then minDist=d closest=mob end
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
        local _,_,root = GetCharParts() if not root then return end
        VirtualUser:CaptureController()
        root.CFrame = CFrame.new(root.Position, Vector3.new(
            target.HumanoidRootPart.Position.X, root.Position.Y, target.HumanoidRootPart.Position.Z))
        VirtualUser:ClickButton1(Vector2.new(900,500))
    end)
end

-- ==============================================================================
-- LOPEN MET COMBAT
-- ==============================================================================
local function WalkToWithCombat(targetPos)
    local char,hum,root = GetCharParts()
    if not char or not hum or not root then return end
    hum:MoveTo(targetPos)
    local stuckTimer=0 local lastPos=root.Position
    local timeout=tick()+300 local lastELog=tick()
    local _,totalStart = CountEnemies() local killsBefore=0

    while tick()<timeout do
        if not S.Running then pcall(function() hum:MoveTo(root.Position) end) return end
        char,hum,root = GetCharParts()
        if not char or not hum or not root then task.wait(1) return end
        if (root.Position-targetPos).Magnitude<=4 then break end

        if tick()-lastELog>2 then
            local alive,total = CountEnemies()
            UpdateEnemy(alive,total)
            local newKills = totalStart-alive
            if newKills>killsBefore then
                S.TotalKills = S.TotalKills+(newKills-killsBefore)
                killsBefore=newKills UpdateKills()
            end
            lastELog=tick()
        end

        if S.AutoAttack then
            local enemy = FindClosestEnemy()
            if enemy then
                pcall(function() hum:MoveTo(root.Position) end)
                local ct=tick()+15
                repeat
                    if not S.Running then return end
                    char,hum,root = GetCharParts() if not char then return end
                    AttackTarget(enemy)
                    pcall(function() if enemy.HumanoidRootPart then hum:MoveTo(enemy.HumanoidRootPart.Position) end end)
                    task.wait(0.1)
                until tick()>ct or not enemy or not enemy.Parent
                    or not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health<=0
                pcall(function() hum:MoveTo(targetPos) end)
            end
        end

        char,hum,root = GetCharParts()
        if root then
            if (root.Position-lastPos).Magnitude<0.5 then
                stuckTimer+=1
                if stuckTimer>20 then pcall(function() hum.Jump=true end) Log("Move","Jump") stuckTimer=0 end
            else stuckTimer=0 end
            lastPos=root.Position
        end
        task.wait(0.1)
    end
    local alive,total = CountEnemies()
    Log("Combat","Klaar | "..alive.."/"..total.." over") UpdateEnemy(alive,total)
end

-- ==============================================================================
-- FASE: DUNGEON
-- ==============================================================================
local function RunDungeonPhase()
    UpdatePhase("DUNGEON")
    Log("Dungeon","=== Run "..S.CurrentRun.." start ===")
    S.RunStartTime = tick()

    WaitForWorldLoad(15)    if not S.Running then return end
    WaitForLoadingGui(30)   if not S.Running then return end
    WaitForDoor()           if not S.Running then return end

    local alive,total = CountEnemies()
    Log("Dungeon","Start enemies: "..alive.."/"..total) UpdateEnemy(alive,total)

    UpdateStatus("Run "..S.CurrentRun.." | Lopen...")
    WalkToWithCombat(DungeonEnd)
    if not S.Running then return end

    task.wait(0.5)
    local rtStr = GetRunTime()
    local rtSec = ParseTime(rtStr)
    if rtStr then
        UpdateTime(rtStr) Log("Dungeon","Tijd: "..rtStr)
        if rtSec and (not S.BestTime or rtSec<S.BestTime) then
            S.BestTime=rtSec UpdateBest(S.BestTime) Log("Dungeon","Nieuwe best: "..rtStr)
        end
    else
        local e=math.floor(tick()-S.RunStartTime)
        local fallback=string.format("%d:%02d",math.floor(e/60),e%60)
        UpdateTime(fallback) Log("Dungeon","Tijd (fallback): "..fallback)
    end

    S.CurrentRun+=1 UpdateRuns()
    local a2,t2=CountEnemies()
    Log("Dungeon","=== Run "..S.CurrentRun.." klaar | "..a2.."/"..t2.." over | Kills: "..S.TotalKills.." ===")

    if S.MaxRuns>0 and S.CurrentRun>S.MaxRuns then
        UpdateStatus("Klaar! "..S.MaxRuns.." runs")
        S.Running=false UpdatePhase("IDLE") UpdateEnemy(nil,nil) return
    end

    UpdateStatus("Wacht Opnieuw...")
    local dl=tick()+25
    while tick()<dl do
        if not S.Running then return end
        local b=FindAgainBtn()
        if b and ClickGuiObject(b) then
            UpdatePhase("DUNGEON")
            Log("Dungeon","Opnieuw OK, Phase=DUNGEON bewaard")
            UpdateStatus("Teleporteren...") return
        end
        task.wait(0.5)
    end
    Warn("Dungeon","Opnieuw timeout") UpdateStatus("Opnieuw niet gevonden")
    S.Running=false UpdatePhase("IDLE")
end

-- ==============================================================================
-- FASE: LOBBY
-- ==============================================================================
local function RunLobbyPhase()
    UpdatePhase("LOBBY") Log("Lobby","Start")
    WaitForWorldLoad(15) if not S.Running then return end

    UpdateStatus("Lobby route...")
    local _,hum,_ = GetCharParts()
    if not hum then Warn("Lobby","Geen karakter") S.Running=false return end

    for i,step in ipairs(LobbyRoute) do
        if not S.Running then return end
        Log("Lobby","Stap "..i)
        pcall(function()
            hum:MoveTo(step.Pos)
            local t=tick() local done=false
            local conn=hum.MoveToFinished:Connect(function() done=true end)
            while not done and tick()-t<6 do task.wait(0.1) end
            pcall(function() conn:Disconnect() end)
        end)
        task.wait(0.1)
    end

    if not S.Running then return end
    UpdatePhase("PARTY") UpdateStatus("Party aanmaken...")
    local ok9=TryCreateParty()
    if not ok9 then Warn("Lobby","Party mislukt") UpdateStatus("Party mislukt") S.Running=false UpdatePhase("IDLE") end
end

-- ==============================================================================
-- AUTOSTART
-- ==============================================================================
local function AutoStart()
    if not S.Running then return end
    UpdateRuns() UpdateEnemy(nil,nil)
    UpdateStatus("Wacht karakter...")
    local t=tick() repeat task.wait(0.3) until GetCharParts() or tick()-t>15
    WaitForWorldLoad(15)
    local inDungeon=IsInDungeon()
    Log("AutoStart","Phase="..S.Phase.." InDungeon="..tostring(inDungeon))
    if S.Phase=="DUNGEON" or inDungeon then
        UpdateStatus("Dungeon! Run "..S.CurrentRun) RunDungeonPhase()
    else
        UpdateStatus("Lobby, starten...") RunLobbyPhase()
    end
end

-- ==============================================================================
-- KNOP EVENTS
-- ==============================================================================
BtnStart.MouseButton1Click:Connect(function()
    if S.Running then UpdateStatus("Al bezig!") return end
    S.Running=true S.CurrentRun=0 S.TotalKills=0 S.Phase="LOBBY"
    UpdateRuns() UpdateKills() UpdateEnemy(nil,nil) UpdateTime(nil) Log("Control","START")
    task.spawn(AutoStart)
end)

BtnStop.MouseButton1Click:Connect(function()
    S.Running=false UpdatePhase("IDLE") UpdateEnemy(nil,nil)
    pcall(function() local _,hum,root=GetCharParts() if hum and root then hum:MoveTo(root.Position) end end)
    UpdateStatus("Gestopt") Log("Control","STOP")
end)

BtnParty.MouseButton1Click:Connect(function()
    if not S.Running then Log("Control","Handmatige party") task.spawn(TryCreateParty) end
end)

-- ==============================================================================
-- BOOT
-- ==============================================================================
UpdateStatus("Idle")
UpdateRuns() UpdatePhase(S.Phase) UpdateKills()
if S.BestTime then UpdateBest(S.BestTime) end

if S.Running then
    Log("Boot","Hervatten na teleport (Phase="..S.Phase..")")
    task.spawn(AutoStart)
else
    Log("Boot","Fresh start")
end
