-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v2.3 - Minimize/Close/F8-Toggle + GUI Upgrade
-- ============================================================

local Players             = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local Workspace           = game.Workspace
local LocalPlayer         = Players.LocalPlayer
if not LocalPlayer then warn("[PeakEvo] Geen LocalPlayer!") return end

local PushMiniLog = nil
local function Log(m,t)
    local msg = "[PeakEvo]["..m.."] "..tostring(t)
    print(msg)
    if PushMiniLog then pcall(function() PushMiniLog("["..m.."] "..tostring(t), Color3.fromRGB(170,170,200)) end) end
end
local function Warn(m,t)
    local msg = "[PeakEvo]["..m.."] "..tostring(t)
    warn(msg)
    if PushMiniLog then pcall(function() PushMiniLog("["..m.."] "..tostring(t), Color3.fromRGB(255,120,120)) end) end
end

-- ==============================================================================
-- AUTO-HERSTART NA TELEPORT
-- ==============================================================================
local queueteleport = queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or nil

if queueteleport then
    local url = _G._PeakEvoURL or ""
    if url ~= "" then
        local loaderScript = '_G._PeakEvoURL="'..url..'"\nloadstring(game:HttpGet("'..url..'"))()'
        pcall(function() queueteleport(loaderScript) end)
        Log("AutoRestart", "queue_on_teleport ingesteld")
    else
        Warn("AutoRestart", "Geen _G._PeakEvoURL - stel in voor teleport-herstart")
    end
else
    Warn("AutoRestart", "queue_on_teleport niet beschikbaar in deze executor")
end

-- ==============================================================================
-- ANTI-AFK
-- ==============================================================================
if not _G._PeakAFK then
    _G._PeakAFK = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0,0))
        end)
    end)
end

-- ==============================================================================
-- STATE
-- ==============================================================================
local SAVE_FILE = "peakevo_state.json"

local function SaveState(s)
    _G.PeakEvo = s
    shared.PeakEvo = s
    -- Sla lifetime + config op in bestand zodat ze teleport/restart overleven
    pcall(function()
        local data = {
            TotalKills   = s.TotalKills   or 0,
            TotalRuns    = s.TotalRuns    or 0,
            TotalTimeSec = s.TotalTimeSec or 0,
            BestTime     = s.BestTime     or nil,
            Difficulty   = s.Difficulty   or "Easy",
            MaxRuns      = s.MaxRuns      or 0,
        }
        writefile(SAVE_FILE, game:GetService("HttpService"):JSONEncode(data))
    end)
end

local function LoadState()
    -- Probeer eerst _G / shared (zelfde sessie, geen teleport)
    if type(_G.PeakEvo)=="table" and _G.PeakEvo.Phase then
        Log("State","_G | Phase=".._G.PeakEvo.Phase.." Run=".._G.PeakEvo.CurrentRun)
        return _G.PeakEvo
    end
    if type(shared.PeakEvo)=="table" and shared.PeakEvo.Phase then
        Log("State","shared | Phase="..shared.PeakEvo.Phase)
        _G.PeakEvo = shared.PeakEvo
        return shared.PeakEvo
    end

    -- Basis state
    local s = {Running=false, AttackRange=45, Difficulty="Easy",
               MaxRuns=0, CurrentRun=0, Phase="IDLE",
               TotalKills=0, BestTime=nil, RunStart=0,
               TotalRuns=0, TotalTimeSec=0,
               SessionKills=0, SessionRuns=0, RunKills=0}

    -- Lifetime stats uit bestand laden (overleeft teleport)
    pcall(function()
        if isfile(SAVE_FILE) then
            local ok, data = pcall(function()
                return game:GetService("HttpService"):JSONDecode(readfile(SAVE_FILE))
            end)
            if ok and type(data) == "table" then
                s.TotalKills   = data.TotalKills   or 0
                s.TotalRuns    = data.TotalRuns    or 0
                s.TotalTimeSec = data.TotalTimeSec or 0
                s.BestTime     = data.BestTime     or nil
                s.Difficulty   = data.Difficulty   or s.Difficulty
                s.MaxRuns      = tonumber(data.MaxRuns) or 0
                Log("State","Bestand geladen | Runs="..s.TotalRuns.." Kills="..s.TotalKills)
            end
        end
    end)

    return s
end

local S = LoadState()
_G._PeakDashEnabled = true
SaveState(S)

local function SetPhase(p) S.Phase=p SaveState(S) Log("Phase","-> "..p) end

Log("Boot","Running="..tostring(S.Running).." Phase="..S.Phase.." Run="..S.CurrentRun)

-- ==============================================================================
-- F-DASH LOOP
-- ==============================================================================
local _lastDash = 0
local DASH_INTERVAL = 2.05

local function TryDash()
    if tick() - _lastDash < DASH_INTERVAL then return end
    _lastDash = tick()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.F, false, game)
        task.wait(0.08)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
end

-- ==============================================================================
-- GUI SETUP
-- ==============================================================================
pcall(function()
    local old = LocalPlayer.PlayerGui:FindFirstChild("PeakEvoGui")
    if old then old:Destroy() end
end)

local GUI_WIDTH  = 310
local GUI_HEIGHT = 410  -- compact, met ruimte voor logpaneel + progress
local GUI_SCALE  = 1.20 -- algemene schaal voor betere leesbaarheid

local COLORS = {
    BG        = Color3.fromRGB(13, 13, 18),
    BG2       = Color3.fromRGB(20, 20, 28),
    BG3       = Color3.fromRGB(28, 28, 40),
    ACCENT    = Color3.fromRGB(82, 130, 255),
    ACCENT2   = Color3.fromRGB(120, 80, 255),
    GREEN     = Color3.fromRGB(55, 190, 100),
    RED       = Color3.fromRGB(210, 55, 65),
    ORANGE    = Color3.fromRGB(220, 140, 40),
    PURPLE    = Color3.fromRGB(110, 70, 200),
    TEXT      = Color3.fromRGB(235, 235, 255),   -- helderwit
    TEXTDIM   = Color3.fromRGB(170, 170, 200),   -- was 110,110,150 - nu veel leesbaarder
    DIV       = Color3.fromRGB(35, 35, 52),
    STATBG    = Color3.fromRGB(22, 22, 32),
}

local Screen = Instance.new("ScreenGui")
Screen.Name="PeakEvoGui" Screen.ResetOnSpawn=false
Screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
Screen.Parent=LocalPlayer.PlayerGui

local Main = Instance.new("Frame")
Main.Name="Main" Main.Size=UDim2.new(0,GUI_WIDTH,0,GUI_HEIGHT)
Main.Position=UDim2.new(0,16,0.5,-GUI_HEIGHT/2)
Main.BackgroundColor3=COLORS.BG
Main.BorderSizePixel=0 Main.Active=true Main.Draggable=true Main.Parent=Screen
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,10)

local MainUIScale = Instance.new("UIScale")
MainUIScale.Scale = GUI_SCALE
MainUIScale.Parent = Main

-- Shadow als child van Main zodat hij automatisch mee beweegt bij drag
local Shadow = Instance.new("Frame")
Shadow.Name="Shadow" Shadow.Size=UDim2.new(1,8,1,8)
Shadow.Position=UDim2.new(0,-4,0,-4)
Shadow.BackgroundColor3=Color3.fromRGB(0,0,0)
Shadow.BackgroundTransparency=0.6 Shadow.BorderSizePixel=0
Shadow.ZIndex=Main.ZIndex-1 Shadow.Parent=Main
Instance.new("UICorner",Shadow).CornerRadius=UDim.new(0,14)

-- Gradient achtergrond accent
local BgGrad = Instance.new("UIGradient")
BgGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18,18,30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(13,13,20))
})
BgGrad.Rotation = 135
BgGrad.Parent = Main

-- ==============================================================================
-- TITLE BAR
-- ==============================================================================
local TB = Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,36) TB.BackgroundColor3=COLORS.BG2
TB.BorderSizePixel=0 TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,10)

-- Fix voor afgeronde hoeken onder de titlebar
local TFix=Instance.new("Frame")
TFix.Size=UDim2.new(1,0,0,10) TFix.Position=UDim2.new(0,0,1,-10)
TFix.BackgroundColor3=COLORS.BG2 TFix.BorderSizePixel=0 TFix.Parent=TB

-- Gekleurde accent lijn bovenaan
local AccentLine = Instance.new("Frame")
AccentLine.Size=UDim2.new(0.6,0,0,2) AccentLine.Position=UDim2.new(0.2,0,0,0)
AccentLine.BackgroundColor3=COLORS.ACCENT AccentLine.BorderSizePixel=0 AccentLine.Parent=TB
local ALGrad = Instance.new("UIGradient")
ALGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(82,130,255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150,100,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(82,130,255))
})
ALGrad.Parent = AccentLine
Instance.new("UICorner",AccentLine).CornerRadius=UDim.new(0,1)

-- Status indicator bolletje
local StatusDot = Instance.new("Frame")
StatusDot.Size=UDim2.new(0,8,0,8) StatusDot.Position=UDim2.new(0,12,0.5,-4)
StatusDot.BackgroundColor3=Color3.fromRGB(60,60,80) StatusDot.BorderSizePixel=0 StatusDot.Parent=TB
Instance.new("UICorner",StatusDot).CornerRadius=UDim.new(1,0)

local TL=Instance.new("TextLabel")
TL.Size=UDim2.new(1,-100,1,0) TL.Position=UDim2.new(0,26,0,0)
TL.BackgroundTransparency=1 TL.Text="PEAK EVO  ·  RB1000"
TL.TextColor3=COLORS.TEXT TL.TextSize=12
TL.Font=Enum.Font.GothamBold TL.TextXAlignment=Enum.TextXAlignment.Left TL.Parent=TB

local VerLabel = Instance.new("TextLabel")
VerLabel.Size=UDim2.new(0,28,0,14) VerLabel.Position=UDim2.new(0,26,0,21)
VerLabel.BackgroundColor3=Color3.fromRGB(40,40,60) VerLabel.BorderSizePixel=0
VerLabel.Text="v2.3" VerLabel.TextColor3=COLORS.TEXTDIM VerLabel.TextSize=8
VerLabel.Font=Enum.Font.GothamBold VerLabel.Parent=TB
Instance.new("UICorner",VerLabel).CornerRadius=UDim.new(0,3)

-- ==============================================================================
-- TITLEBAR KNOPPEN: MINIMIZE & CLOSE
-- ==============================================================================
local function MkTBBtn(xOffset, bgColor, symbol)
    local btn = Instance.new("TextButton")
    btn.Size=UDim2.new(0,22,0,22) btn.Position=UDim2.new(1,xOffset,0.5,-11)
    btn.BackgroundColor3=bgColor btn.BorderSizePixel=0
    btn.Text=symbol btn.TextColor3=Color3.fromRGB(220,220,255) btn.TextSize=13
    btn.Font=Enum.Font.GothamBold btn.AutoButtonColor=false btn.Parent=TB
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=bgColor:Lerp(Color3.new(1,1,1),0.2)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=bgColor}):Play()
    end)
    return btn
end

local BtnClose    = MkTBBtn(-30,  Color3.fromRGB(190,50,55),  "✕")
local BtnMinimize = MkTBBtn(-56,  Color3.fromRGB(50,50,75),   "─")

-- F8 hint label
local F8Hint = Instance.new("TextLabel")
F8Hint.Size=UDim2.new(0,60,0,12) F8Hint.Position=UDim2.new(1,-106,0.5,-6)
F8Hint.BackgroundTransparency=1 F8Hint.Text="F8 = hide"
F8Hint.TextColor3=Color3.fromRGB(60,60,90) F8Hint.TextSize=9
F8Hint.Font=Enum.Font.Gotham F8Hint.Parent=TB

-- ==============================================================================
-- CONTENT FRAME (alles behalve titlebar - kan minimised worden)
-- ==============================================================================
local Content = Instance.new("Frame")
Content.Name="Content" Content.Size=UDim2.new(1,0,1,-36) Content.Position=UDim2.new(0,0,0,36)
Content.BackgroundTransparency=1 Content.BorderSizePixel=0 Content.Parent=Main

-- ==============================================================================
-- MINIMIZE / CLOSE LOGICA
-- ==============================================================================
local isMinimized = false
local isVisible = true
local FULL_HEIGHT = GUI_HEIGHT
local MINI_HEIGHT = 36

local function SetGuiVisible(v)
    isVisible = v
    Main.Visible = v
end

local function SetMinimized(mini)
    isMinimized = mini
    local targetH = mini and MINI_HEIGHT or FULL_HEIGHT
    Content.Visible = not mini
    TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, GUI_WIDTH, 0, targetH)
    }):Play()
    -- Shadow schaalt automatisch mee omdat hij 1,8 / 1,8 relatief is
    BtnMinimize.Text = mini and "▲" or "─"
end

BtnMinimize.MouseButton1Click:Connect(function()
    SetMinimized(not isMinimized)
end)

BtnClose.MouseButton1Click:Connect(function()
    -- Stop alles netjes
    S.Running = false
    SaveState(S)
    -- Verwijder GUI volledig
    pcall(function()
        local g = LocalPlayer.PlayerGui:FindFirstChild("PeakEvoGui")
        if g then g:Destroy() end
    end)
    Log("GUI","Gesloten via close knop")
end)

-- ==============================================================================
-- F8 TOGGLE ZICHTBAARHEID
-- ==============================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F8 then
        SetGuiVisible(not isVisible)
        Log("GUI", isVisible and "Zichtbaar" or "Verborgen")
    end
end)

-- ==============================================================================
-- GUI HELPER FUNCTIES
-- ==============================================================================
local function Hdr(txt, y)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,-20,0,14) l.Position=UDim2.new(0,10,0,y)
    l.BackgroundTransparency=1 l.Text=txt
    l.TextColor3=COLORS.TEXTDIM l.TextSize=9
    l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=Content
end

local function Div(y)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,-20,0,1) f.Position=UDim2.new(0,10,0,y)
    f.BackgroundColor3=COLORS.DIV f.BorderSizePixel=0 f.Parent=Content
end

local function DD(lbl,opts,def,y,cb)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,-20,0,26) c.Position=UDim2.new(0,10,0,y)
    c.BackgroundColor3=COLORS.BG3 c.BorderSizePixel=0 c.Parent=Content
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,6)
    local kl=Instance.new("TextLabel")
    kl.Size=UDim2.new(0,90,1,0) kl.Position=UDim2.new(0,10,0,0)
    kl.BackgroundTransparency=1 kl.Text=lbl kl.TextColor3=COLORS.TEXTDIM
    kl.TextSize=11 kl.Font=Enum.Font.Gotham kl.TextXAlignment=Enum.TextXAlignment.Left kl.Parent=c
    local vl=Instance.new("TextLabel")
    vl.Size=UDim2.new(0,120,1,0) vl.Position=UDim2.new(0,98,0,0)
    vl.BackgroundTransparency=1 vl.Text=tostring(def)
    vl.TextColor3=COLORS.TEXT vl.TextSize=11
    vl.Font=Enum.Font.GothamBold vl.TextXAlignment=Enum.TextXAlignment.Left vl.Parent=c
    -- Kleine pijl rechts
    local al=Instance.new("TextLabel")
    al.Size=UDim2.new(0,20,1,0) al.Position=UDim2.new(1,-22,0,0)
    al.BackgroundTransparency=1 al.Text="›" al.TextColor3=COLORS.ACCENT
    al.TextSize=16 al.Font=Enum.Font.GothamBold al.Parent=c
    local idx=1
    for i,v in ipairs(opts) do if tostring(v)==tostring(def) then idx=i break end end
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.Parent=c
    btn.MouseButton1Click:Connect(function()
        idx=idx%#opts+1 vl.Text=tostring(opts[idx]) cb(opts[idx])
    end)
end

local function Btn(txt,x,y,w,col)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(0,w,0,28) b.Position=UDim2.new(0,x,0,y)
    b.BackgroundColor3=col b.BorderSizePixel=0 b.Text=txt
    b.TextColor3=Color3.fromRGB(235,235,255) b.TextSize=11
    b.Font=Enum.Font.GothamBold b.AutoButtonColor=false b.Parent=Content
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=col:Lerp(Color3.new(1,1,1),0.15)}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=col}):Play() end)
    return b
end

-- ==============================================================================
-- STAT BOXES (2-koloms raster)
-- ==============================================================================
local function StatBox(icon, key, col, row, yBase)
    local x = col==0 and 10 or 159
    local y = yBase + row*24
    local box=Instance.new("Frame")
    box.Size=UDim2.new(0,138,0,22) box.Position=UDim2.new(0,x,0,y)
    box.BackgroundColor3=COLORS.STATBG box.BorderSizePixel=0 box.Parent=Content
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,5)
    -- Linker kleur streepje
    local stripe=Instance.new("Frame")
    stripe.Size=UDim2.new(0,2,1,-4) stripe.Position=UDim2.new(0,0,0,2)
    stripe.BackgroundColor3=COLORS.ACCENT stripe.BorderSizePixel=0 stripe.Parent=box
    Instance.new("UICorner",stripe).CornerRadius=UDim.new(0,1)
    local kl=Instance.new("TextLabel")
    kl.Size=UDim2.new(0,52,1,0) kl.Position=UDim2.new(0,8,0,0)
    kl.BackgroundTransparency=1 kl.Text=icon.." "..key kl.TextColor3=Color3.fromRGB(160,160,200)
    kl.TextSize=10 kl.Font=Enum.Font.GothamBold kl.TextXAlignment=Enum.TextXAlignment.Left kl.Parent=box
    local vl=Instance.new("TextLabel")
    vl.Size=UDim2.new(1,-62,1,0) vl.Position=UDim2.new(0,60,0,0)
    vl.BackgroundTransparency=1 vl.Text="-"
    vl.TextColor3=Color3.fromRGB(240,240,255) vl.TextSize=11
    vl.Font=Enum.Font.GothamBold vl.TextXAlignment=Enum.TextXAlignment.Left vl.Parent=box
    return vl
end

-- ==============================================================================
-- GUI LAYOUT OPBOUW
-- ==============================================================================

-- CONFIG sectie
local function RunsToLabel(maxRuns)
    maxRuns = tonumber(maxRuns) or 0
    return maxRuns > 0 and tostring(maxRuns) or "Oneindig"
end

Hdr("CONFIG", 8)
DD("Difficulty",{"Easy","Normal","Hard"},S.Difficulty, 22, function(v)
    S.Difficulty=v
    SaveState(S)
end)
DD("Runs",{"1","2","3","5","10","25","50","Oneindig"},RunsToLabel(S.MaxRuns), 52, function(v)
    S.MaxRuns=v=="Oneindig" and 0 or tonumber(v) S.CurrentRun=0 SaveState(S)
end)

local ForceLabel = Instance.new("TextLabel")
ForceLabel.Size=UDim2.new(1,-20,0,12) ForceLabel.Position=UDim2.new(0,10,0,84)
ForceLabel.BackgroundTransparency=1
ForceLabel.Text="Auto Attack + Auto Dash: altijd aan"
ForceLabel.TextColor3=COLORS.TEXTDIM ForceLabel.TextSize=9
ForceLabel.Font=Enum.Font.Gotham ForceLabel.TextXAlignment=Enum.TextXAlignment.Left
ForceLabel.Parent=Content

Div(102)

-- LIVE sectie
Hdr("LIVE", 108)

local STAT_Y = 124
local VS = StatBox("◉","Status",  0, 0, STAT_Y)
local VP = StatBox("◈","Fase",    1, 0, STAT_Y)
local VR = StatBox("↺","Runs",    0, 1, STAT_Y)
local VE = StatBox("⚔","Alive/Run",   1, 1, STAT_Y)
local VT = StatBox("⏱","Tijd",    0, 2, STAT_Y)
local VB = StatBox("★","Best",    1, 2, STAT_Y)
local VK = StatBox("☠","Kills",   0, 3, STAT_Y)
local VL = StatBox("⌛","Timer",  1, 3, STAT_Y)
VK.TextSize = 9
VK.TextYAlignment = Enum.TextYAlignment.Top

local EnemyBar = Instance.new("Frame")
EnemyBar.Size=UDim2.new(1,-20,0,8) EnemyBar.Position=UDim2.new(0,10,0,220)
EnemyBar.BackgroundColor3=Color3.fromRGB(34,34,52) EnemyBar.BorderSizePixel=0 EnemyBar.Parent=Content
Instance.new("UICorner",EnemyBar).CornerRadius=UDim.new(1,0)

local EnemyBarFill = Instance.new("Frame")
EnemyBarFill.Size=UDim2.new(0,0,1,0) EnemyBarFill.Position=UDim2.new(0,0,0,0)
EnemyBarFill.BackgroundColor3=COLORS.GREEN EnemyBarFill.BorderSizePixel=0 EnemyBarFill.Parent=EnemyBar
Instance.new("UICorner",EnemyBarFill).CornerRadius=UDim.new(1,0)

local EnemyPct = Instance.new("TextLabel")
EnemyPct.Size=UDim2.new(0,50,0,10) EnemyPct.Position=UDim2.new(1,-50,0,209)
EnemyPct.BackgroundTransparency=1 EnemyPct.Text="0%" EnemyPct.TextColor3=COLORS.TEXTDIM
EnemyPct.TextSize=9 EnemyPct.Font=Enum.Font.GothamBold EnemyPct.TextXAlignment=Enum.TextXAlignment.Right
EnemyPct.Parent=Content

Div(230)

-- KNOPPEN rij
local BtnStart  = Btn("▶  START",  10,  236, 92, COLORS.GREEN)
local BtnStop   = Btn("■  STOP",   106, 236, 88, COLORS.RED)
local BtnParty  = Btn("⚑  PARTY", 198, 236, 102, COLORS.PURPLE)

Div(270)

-- MINI LOG (laatste 4 regels, groter en leesbaarder)
local LogPanel = Instance.new("Frame")
LogPanel.Size=UDim2.new(1,-20,0,64) LogPanel.Position=UDim2.new(0,10,0,274)
LogPanel.BackgroundColor3=Color3.fromRGB(18,18,28) LogPanel.BorderSizePixel=0 LogPanel.Parent=Content
Instance.new("UICorner",LogPanel).CornerRadius=UDim.new(0,5)

local LogLines = {}
for i=1,4 do
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,-10,0,12) l.Position=UDim2.new(0,6,0,(i-1)*14+4)
    l.BackgroundTransparency=1 l.Text="-"
    l.TextColor3=Color3.fromRGB(210,210,230) l.TextSize=10
    l.Font=Enum.Font.Code l.TextXAlignment=Enum.TextXAlignment.Left
    l.Parent=LogPanel
    LogLines[i]=l
end

-- STATS sessie-overzicht balk onderaan
local SessionBar = Instance.new("Frame")
SessionBar.Size=UDim2.new(1,-20,0,18) SessionBar.Position=UDim2.new(0,10,0,340)
SessionBar.BackgroundColor3=COLORS.STATBG SessionBar.BorderSizePixel=0 SessionBar.Parent=Content
Instance.new("UICorner",SessionBar).CornerRadius=UDim.new(0,5)

local SessionLabel = Instance.new("TextLabel")
SessionLabel.Size=UDim2.new(1,-74,1,0) SessionLabel.Position=UDim2.new(0,8,0,0)
SessionLabel.BackgroundTransparency=1
SessionLabel.Text="Lifetime: 0 runs | 0 kills | 0m 0s"
SessionLabel.TextColor3=Color3.fromRGB(180,180,220) SessionLabel.TextSize=10
SessionLabel.Font=Enum.Font.GothamBold SessionLabel.TextXAlignment=Enum.TextXAlignment.Left
SessionLabel.Parent=SessionBar

local BtnResetLifetime = Instance.new("TextButton")
BtnResetLifetime.Size=UDim2.new(0,58,1,-2) BtnResetLifetime.Position=UDim2.new(1,-60,0,1)
BtnResetLifetime.BackgroundColor3=Color3.fromRGB(80,50,52) BtnResetLifetime.BorderSizePixel=0
BtnResetLifetime.Text="RESET" BtnResetLifetime.TextColor3=Color3.fromRGB(255,220,220) BtnResetLifetime.TextSize=9
BtnResetLifetime.Font=Enum.Font.GothamBold BtnResetLifetime.AutoButtonColor=false BtnResetLifetime.Parent=SessionBar
Instance.new("UICorner",BtnResetLifetime).CornerRadius=UDim.new(0,4)

-- F8 hint onderaan
local HintBar = Instance.new("TextLabel")
HintBar.Size=UDim2.new(1,0,0,12) HintBar.Position=UDim2.new(0,0,0,362)
HintBar.BackgroundTransparency=1 HintBar.Text="F8 = toon/verberg | Sleep titlebar = verplaatsen"
HintBar.TextColor3=Color3.fromRGB(255,255,255) HintBar.TextSize=10
HintBar.Font=Enum.Font.Gotham HintBar.Parent=Content

local _miniLogItems = {}
PushMiniLog = function(txt, color)
    local line = tostring(txt or "-"):gsub("[%c\r\n]+"," ")
    if #line > 56 then line = string.sub(line,1,56).."..." end
    table.insert(_miniLogItems, 1, {
        t = line,
        c = color or COLORS.TEXTDIM
    })
    while #_miniLogItems > 4 do table.remove(_miniLogItems, #_miniLogItems) end
    for i=1,4 do
        local item = _miniLogItems[i]
        if item then
            LogLines[i].Text = item.t
            LogLines[i].TextColor3 = item.c
        else
            LogLines[i].Text = "-"
            LogLines[i].TextColor3 = COLORS.TEXTDIM
        end
    end
end

-- ==============================================================================
-- FASE KLEUREN
-- ==============================================================================
local FaseKleur={
    IDLE    = Color3.fromRGB(100, 100, 130),
    LOBBY   = Color3.fromRGB(80,  180, 255),
    PARTY   = Color3.fromRGB(255, 200, 80),
    DUNGEON = Color3.fromRGB(80,  220, 120),
}

-- ==============================================================================
-- UI UPDATE FUNCTIES
-- ==============================================================================
local function StatusColorFromText(msg)
    local s = string.lower(tostring(msg or ""))
    if string.find(s, "timeout", 1, true)
        or string.find(s, "mislukt", 1, true)
        or string.find(s, "niet gevonden", 1, true)
        or string.find(s, "error", 1, true)
    then
        return COLORS.RED
    end
    if string.find(s, "wacht", 1, true) or string.find(s, "loading", 1, true) then
        return COLORS.ORANGE
    end
    if string.find(s, "klaar", 1, true)
        or string.find(s, "hervatten", 1, true)
        or string.find(s, "starten", 1, true)
    then
        return COLORS.GREEN
    end
    return COLORS.TEXT
end

local function US(t)
    pcall(function()
        VS.Text=tostring(t)
        VS.TextColor3 = StatusColorFromText(t)
    end)
    Log("Status",t)
end

local function UpdateStatusDot(running)
    pcall(function()
        local col = running and COLORS.GREEN or Color3.fromRGB(60,60,80)
        TweenService:Create(StatusDot, TweenInfo.new(0.3), {BackgroundColor3=col}):Play()
    end)
end

local function UP(p)
    S.Phase=p SaveState(S)
    pcall(function()
        VP.Text=p
        VP.TextColor3=FaseKleur[p] or COLORS.TEXT
    end)
    UpdateStatusDot(S.Running)
end

local function UR()
    pcall(function() VR.Text=tostring(S.TotalRuns or 0) end)
end

local function UE(a,t)
    pcall(function() VE.Text=a and (a.."/"..t) or "-" end)
end

local function UK()
    -- Kills box: run + lifetime op aparte regel
    pcall(function()
        local run = S.RunKills or 0
        local total = S.TotalKills or 0
        VK.Text = "RunKills "..run.."\nLife "..total
    end)
end

local function UT(s)
    pcall(function() VT.Text=s or "-" end)
end

local function UB(s)
    if not s then return end
    pcall(function() VB.Text=string.format("%d:%02d",math.floor(s/60),s%60) end)
end

local function UL(s)
    pcall(function() VL.Text=s or "-" end)
end

-- Forward declaration, zodat UpdateSessionBar en timer dezelfde lokale variabele gebruiken.
local _localRunStart = 0
local _countedMobs = {}

local function GetRunKills()
    return S.RunKills or 0
end

local function UpdateEnemyProgress(alive)
    local a = alive or 0
    local totalThisRun = a + GetRunKills()
    UE(a, totalThisRun)
    pcall(function()
        local killed = math.max(0, totalThisRun - a)
        local pct = totalThisRun > 0 and math.clamp(killed / totalThisRun, 0, 1) or 0
        EnemyBarFill.Size = UDim2.new(pct,0,1,0)
        EnemyPct.Text = string.format("%d%%", math.floor(pct * 100 + 0.5))
    end)
end

local function UpdateSessionBar()
    pcall(function()
        local total = (S.TotalTimeSec or 0)
        local runStart = _localRunStart or 0
        -- Voeg huidige lopende run toe als timer actief is
        if runStart > 0 and S.Running then
            total = total + math.floor(tick() - runStart)
        end
        local h  = math.floor(total / 3600)
        local m  = math.floor((total % 3600) / 60)
        local sc = total % 60
        local timeStr = h > 0
            and string.format("%dh %dm %ds", h, m, sc)
            or  string.format("%dm %ds", m, sc)
        SessionLabel.Text = string.format(
            "Lifetime: %d runs | %d kills | %s",
            S.TotalRuns or 0, S.TotalKills or 0, timeStr
        )
    end)
end

-- Live heartbeat voor de session bar (update elke ~1s)
local _lastBarUpdate = 0
local _resetLifetimeArmed = false
local _resetLifetimeExpire = 0

RunService.Heartbeat:Connect(function()
    if tick() - _lastBarUpdate < 1 then return end
    _lastBarUpdate = tick()
    if _resetLifetimeArmed and tick() > _resetLifetimeExpire then
        _resetLifetimeArmed = false
        BtnResetLifetime.Text = "RESET"
        BtnResetLifetime.BackgroundColor3 = Color3.fromRGB(80,50,52)
    end
    UpdateSessionBar()
    UK()
    UR()
end)

BtnResetLifetime.MouseButton1Click:Connect(function()
    local now = tick()
    if (not _resetLifetimeArmed) or now > _resetLifetimeExpire then
        _resetLifetimeArmed = true
        _resetLifetimeExpire = now + 5
        BtnResetLifetime.Text = "CONFIRM"
        BtnResetLifetime.BackgroundColor3 = COLORS.ORANGE
        US("Klik RESET nogmaals binnen 5s")
        return
    end

    _resetLifetimeArmed = false
    BtnResetLifetime.Text = "RESET"
    BtnResetLifetime.BackgroundColor3 = Color3.fromRGB(80,50,52)

    S.TotalKills = 0
    S.TotalRuns = 0
    S.TotalTimeSec = 0
    S.BestTime = nil
    S.SessionKills = 0
    S.SessionRuns = 0
    S.RunKills = 0
    SaveState(S)

    pcall(function() VB.Text = "-" end)
    UR()
    UK()
    UpdateEnemyProgress(0)
    UpdateSessionBar()
    US("Lifetime stats gereset")
end)

-- ==============================================================================
-- LIVE TIMER
-- ==============================================================================
local timerConn = nil

local function StartLiveTimer()
    if timerConn then pcall(function() timerConn:Disconnect() end) timerConn=nil end
    _localRunStart = tick()
    S.RunStart = os.time()
    SaveState(S)
    timerConn = RunService.Heartbeat:Connect(function()
        if not S.Running or S.Phase ~= "DUNGEON" then
            pcall(function() timerConn:Disconnect() end)
            timerConn = nil
            return
        end
        local e = math.floor(tick() - _localRunStart)
        local str = string.format("%d:%02d", math.floor(e/60), e%60)
        UL(str)  -- Timer (live countdown)
        UT(str)  -- TIJD ook live bijwerken
    end)
end

local function StopLiveTimer()
    if timerConn then pcall(function() timerConn:Disconnect() end) timerConn=nil end
    _localRunStart = 0
end

-- ==============================================================================
-- WERELD HULPFUNCTIES
-- ==============================================================================
local function WaitForWorldLoad(max)
    max=max or 15 local dl=tick()+max US("Wereld laden...")
    while tick()<dl do
        local ok,r=pcall(function() local s=Workspace:FindFirstChild("Stage") return s and #s:GetChildren()>0 end)
        if ok and r then Log("World","Stage klaar") task.wait(0.5) return true end
        task.wait(0.3)
    end
    Warn("World","Stage timeout") return false
end

local function IsInDungeon()
    local ok,r=pcall(function()
        local s=Workspace:FindFirstChild("Stage") if not s then return false end
        if s:FindFirstChild("baseStage") then return false end
        for _,c in pairs(s:GetChildren()) do
            if string.sub(c.Name,1,3)=="map" then return true end
        end
        return false
    end)
    return ok and r or false
end

local function CountEnemies()
    local alive,total=0,0
    pcall(function()
        local s=Workspace:FindFirstChild("Stage") if not s then return end
        for _,map in pairs(s:GetChildren()) do
            if string.sub(map.Name,1,3)=="map" then
                local f=map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                if f then
                    for _,mob in pairs(f:GetChildren()) do
                        pcall(function()
                            local h=mob:FindFirstChild("Humanoid")
                            if h then total+=1 if h.Health>0 then alive+=1 end end
                        end)
                    end
                end
            end
        end
    end)
    return alive,total
end

local function WaitForLoadingGui(max)
    max=max or 30 local dl=tick()+max
    while tick()<dl do
        if not S.Running then return end
        local loading=false
        pcall(function()
            local pg=LocalPlayer:FindFirstChild("PlayerGui")
            local ld=pg and pg:FindFirstChild("LoadingGui")
            loading=ld~=nil and ld.Enabled==true
        end)
        if loading then US("Loading...") task.wait(0.3)
        else Log("Loading","Klaar") task.wait(0.2) return end
    end
    Warn("Loading","Timeout")
end

local function WaitForDoor()
    -- Wacht niet op een vaste timer maar tot mobs daadwerkelijk geladen zijn
    local max = 30  -- maximaal 30s wachten
    local dl = tick() + max
    Log("Deur", "Wachten op mobs...")
    while tick() < dl do
        if not S.Running then return end
        local alive, total = CountEnemies()
        if total > 0 then
            Log("Deur", "Mobs geladen: " .. total .. " gevonden")
            US("Mobs gevonden! Starten...")
            task.wait(0.5)  -- kort wachten zodat server volledig gesync is
            return
        end
        US("Wacht op mobs... " .. math.ceil(dl - tick()) .. "s")
        task.wait(0.5)
    end
    Warn("Deur", "Timeout - geen mobs gevonden, toch doorgaan")
end

local function IsEndScreenVisible()
    local r=false
    pcall(function()
        local pg=LocalPlayer:FindFirstChild("PlayerGui")
        local pog=pg and pg:FindFirstChild("PartyOverGui")
        r=pog~=nil and pog.Enabled==true
    end)
    return r
end

-- ==============================================================================
-- KARAKTER / ROUTES
-- ==============================================================================
local function GetChar()
    local c=LocalPlayer.Character if not c then return nil,nil,nil end
    return c,c:FindFirstChild("Humanoid"),c:FindFirstChild("HumanoidRootPart")
end

local LobbyRoute={
    {Pos=Vector3.new(-1696, 22.6, -321.6)},
    {Pos=Vector3.new(-1741.2, 22.8, -322.6)},
}

local DungeonEnd=Vector3.new(-880.3,31.6,-507.3)

local function FindNearestRouteIndex(route)
    local _,_,root = GetChar()
    if not root then return 1 end
    local bestIdx = 1
    local bestDist = math.huge
    for i, step in ipairs(route) do
        local d = (root.Position - step.Pos).Magnitude
        if d < bestDist then
            bestDist = d
            bestIdx = i
        end
    end
    local lastPos = route[#route].Pos
    if (root.Position - lastPos).Magnitude < 8 then
        return #route + 1
    end
    Log("Route","Dichtstbijzijnde waypoint: "..bestIdx.." (dist="..math.floor(bestDist)..")")
    return bestIdx
end

-- ==============================================================================
-- KLIK
-- ==============================================================================
local function ClickObj(obj)
    if not obj then return false end
    return pcall(function()
        if not obj.AbsolutePosition then return end
        local cx=obj.AbsolutePosition.X+obj.AbsoluteSize.X/2
        local cy=obj.AbsolutePosition.Y+obj.AbsoluteSize.Y/2
        local fired=false
        pcall(function()
            for _,c in pairs(getconnections(obj.Activated)) do
                pcall(function() c:Fire() end) fired=true
            end
        end)
        if not fired then
            pcall(function()
                for _,c in pairs(getconnections(obj.MouseButton1Click)) do
                    pcall(function() c:Fire() end)
                end
            end)
        end
        VirtualInputManager:SendMouseButtonEvent(cx,cy,0,true,game,0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(cx,cy,0,false,game,0)
    end)
end

-- ==============================================================================
-- PARTY
-- ==============================================================================
local function SF(...)
    local args={...} local cur=LocalPlayer:FindFirstChild("PlayerGui")
    for _,n in ipairs(args) do
        if not cur then return nil end
        local ok,r=pcall(function() return cur:FindFirstChild(n) end)
        cur=ok and r or nil
    end
    return cur
end

local function FindDiffBtn(d)
    local m={Easy="btn4",Normal="btn5",Hard="btn6"}
    local n=m[d or S.Difficulty] if not n then return nil end
    local l=SF("PartyGui","Frame","createBg","left") if not l then return nil end
    local ok,b=pcall(function() return l:FindFirstChild(n) end)
    if ok and b and b:IsA("GuiObject") and b.Visible then return b end
end
local function IsPartyOpen() return FindDiffBtn("Easy") or FindDiffBtn("Normal") or FindDiffBtn("Hard") end
local function FindCreateBtn()
    local r=SF("PartyGui","Frame","createBg","right") if not r then return nil end
    local ok,b=pcall(function() return r:FindFirstChild("createBtn") end)
    if ok and b and b.Visible then return b end
end
local function FindStartBtn()
    local r=SF("PartyGui","Frame","roomBg","right") if not r then return nil end
    local ok,b=pcall(function() return r:FindFirstChild("StartBtn") end)
    if ok and b and b.Visible then return b end
end

local function FindAgainBtn()
    local found=nil
    pcall(function()
        local pg=LocalPlayer:FindFirstChild("PlayerGui")
        local pog=pg and pg:FindFirstChild("PartyOverGui") if not pog then return end
        local bg=pog.Frame and pog.Frame:FindFirstChild("bg") if not bg then return end
        local b=bg:FindFirstChild("againbtn")
        if b and b.Visible then found=b return end
        local af=bg:FindFirstChild("againFrame")
        if af then
            local b2=af:FindFirstChild("againbtn")
            if b2 and b2.Visible then found=b2 return end
        end
        local b3=bg:FindFirstChild("againbtn",true)
        if b3 and b3.Visible then found=b3 end
    end)
    return found
end

local function TryCreateParty()
    US("Wacht party menu...")
    local dl=tick()+15
    while tick()<dl do
        if not S.Running then return false end
        if IsPartyOpen() then Log("Party","Menu open") break end
        task.wait(0.2)
    end
    if not IsPartyOpen() then Warn("Party","Timeout") return false end

    US("Difficulty: "..S.Difficulty)
    local d=tick()+10
    while tick()<d do local b=FindDiffBtn(S.Difficulty) if b and ClickObj(b) then break end task.wait(0.1) end
    task.wait(0.4)

    US("Lobby aanmaken...")
    local c=tick()+10
    while tick()<c do local b=FindCreateBtn() if b and ClickObj(b) then break end task.wait(0.1) end
    task.wait(1)

    US("Wacht Start...")
    local st=tick()+20
    while tick()<st do
        if not S.Running then return false end
        local b=FindStartBtn()
        if b then
            ClickObj(b) task.wait(1.5)
            if not FindStartBtn() then
                SetPhase("DUNGEON") Log("Party","Start OK") US("Teleporteren...") return true
            end
        end
        task.wait(0.5)
    end
    Warn("Party","Timeout") return false
end

-- ==============================================================================
-- COMBAT
-- ==============================================================================
local function FindEnemy()
    local _,_,root=GetChar() if not root then return nil end
    local mp=root.Position local cl,md=nil,S.AttackRange
    pcall(function()
        local st=Workspace:FindFirstChild("Stage") if not st then return end
        for _,map in pairs(st:GetChildren()) do
            if string.sub(map.Name,1,3)=="map" then
                local f=map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                if f then
                    for _,mob in pairs(f:GetChildren()) do
                        pcall(function()
                            local h=mob:FindFirstChild("Humanoid")
                            local r=mob:FindFirstChild("HumanoidRootPart")
                            if h and r and h.Health>0 then
                                local d=(r.Position-mp).Magnitude
                                if d<md then md=d cl=mob end
                            end
                        end)
                    end
                end
            end
        end
    end)
    return cl
end

local _lastCapture=0
local function Attack(target)
    pcall(function()
        if not target or not target:FindFirstChild("HumanoidRootPart") then return end
        local _,_,root=GetChar() if not root then return end
        if tick()-_lastCapture>1 then
            VirtualUser:CaptureController()
            _lastCapture=tick()
        end
        root.CFrame=CFrame.new(root.Position,Vector3.new(
            target.HumanoidRootPart.Position.X,root.Position.Y,
            target.HumanoidRootPart.Position.Z))
        VirtualUser:ClickButton1(Vector2.new(900,500))
    end)
end

-- ==============================================================================
-- LOPEN MET COMBAT
-- ==============================================================================
local function Walk(targetPos)
    local char,hum,root=GetChar()
    if not char or not hum or not root then return end

    local lastMoveTo = 0
    local function RefreshMoveTo()
        if tick()-lastMoveTo > 4.5 then
            pcall(function() hum:MoveTo(targetPos) end)
            lastMoveTo = tick()
        end
    end

    RefreshMoveTo()

    local stuckT=0 local lastPos=root.Position
    local timeout=tick()+300 local lastEL=tick()

    while tick()<timeout do
        if not S.Running then pcall(function() hum:MoveTo(root.Position) end) return end

        if IsEndScreenVisible() then
            Log("Walk","Eindscherm zichtbaar, run klaar")
            pcall(function() hum:MoveTo(root.Position) end)
            break
        end

        char,hum,root=GetChar()
        if not char or not hum or not root then task.wait(1) return end

        if (root.Position-targetPos).Magnitude<=4 then
            Log("Walk","Doel bereikt")
            break
        end

        RefreshMoveTo()

        TryDash()

        if tick()-lastEL>2 then
            local alive,total=CountEnemies()
            UpdateEnemyProgress(alive)
            lastEL=tick()
        end

        local enemy=FindEnemy()
        if enemy then
            pcall(function() hum:MoveTo(root.Position) end)
            local ct=tick()+15
            repeat
                if not S.Running then return end
                if IsEndScreenVisible() then return end
                char,hum,root=GetChar() if not char then return end
                Attack(enemy)
                pcall(function()
                    if enemy.HumanoidRootPart then hum:MoveTo(enemy.HumanoidRootPart.Position) end
                end)
                task.wait(0.15)
            until tick()>ct or not enemy or not enemy.Parent
                or not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health<=0
            lastMoveTo = 0
            RefreshMoveTo()
        end

        char,hum,root=GetChar()
        if root then
            if (root.Position-lastPos).Magnitude<0.5 then
                stuckT+=1
                if stuckT>20 then
                    pcall(function() hum.Jump=true end)
                    Log("Move","Jump") stuckT=0
                    lastMoveTo=0
                end
            else stuckT=0 end
            lastPos=root.Position
        end
        task.wait(0.15)
    end

    local alive,total=CountEnemies()
    Log("Combat","Klaar | "..alive.."/"..total.." over")
    UpdateEnemyProgress(alive)
end

-- ==============================================================================
-- DUNGEON CLEAR - TP PER ENEMY
-- ==============================================================================
local function ClearDungeon()
    Log("Dungeon","TP-per-enemy clear gestart")
    local timeout = time() + 300
    local totalMobsAtStart = 0  -- alleen voor logging

    -- Tel beginaantal voor de UI
    pcall(function()
        local st = Workspace:FindFirstChild("Stage") if not st then return end
        for _, map in pairs(st:GetChildren()) do
            if string.sub(map.Name,1,3)=="map" then
                local f = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                if f then
                    for _, mob in pairs(f:GetChildren()) do
                        pcall(function()
                            local h = mob:FindFirstChild("Humanoid")
                            if h and h.Health > 0 then totalMobsAtStart += 1 end
                        end)
                    end
                end
            end
        end
    end)
    Log("Dungeon","Start mobcount: "..totalMobsAtStart)

    while S.Running and time() < timeout do
        if IsEndScreenVisible() then
            Log("Dungeon","Eindscherm zichtbaar")
            return
        end

        local aliveMobs = {}
        pcall(function()
            local st = Workspace:FindFirstChild("Stage") if not st then return end
            for _, map in pairs(st:GetChildren()) do
                if string.sub(map.Name,1,3)=="map" then
                    local f = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                    if f then
                        for _, mob in pairs(f:GetChildren()) do
                            pcall(function()
                                local h = mob:FindFirstChild("Humanoid")
                                local r = mob:FindFirstChild("HumanoidRootPart")
                                if h and r and h.Health > 0 then
                                    table.insert(aliveMobs, mob)
                                end
                            end)
                        end
                    end
                end
            end
        end)

        if #aliveMobs == 0 then
            Log("Dungeon","Alle mobs dood")
            UpdateEnemyProgress(0)
            local waitEnd = time() + 5
            while time() < waitEnd do
                if IsEndScreenVisible() then return end
                task.wait(0.3)
            end
            return
        end

        UpdateEnemyProgress(#aliveMobs)
        Log("Dungeon", #aliveMobs .. " mobs over")

        for _, mob in ipairs(aliveMobs) do
            if not S.Running then return end
            if IsEndScreenVisible() then return end

            local hum = mob:FindFirstChild("Humanoid")
            local er  = mob:FindFirstChild("HumanoidRootPart")
            if not hum or not er or hum.Health <= 0 then continue end

            local _, playerHum, root = GetChar()
            if not root or not playerHum then return end

            -- Teleport naast mob
            pcall(function()
                root.CFrame = CFrame.new(er.Position + Vector3.new(2, 0, 0))
            end)
            task.wait(0.1)

            -- Aanvallen tot dood
            local combatTimeout = time() + 20
            local mobDead = false
            repeat
                if not S.Running then return end
                if IsEndScreenVisible() then return end
                _, playerHum, root = GetChar()
                if not root then return end

                -- Blijf op mob positie
                pcall(function()
                    root.CFrame = CFrame.new(er.Position + Vector3.new(2, 0, 0))
                end)

                Attack(mob)
                task.wait(0.15)

                -- Check dood: mob uit workspace OF health 0
                local stillExists = mob and mob.Parent ~= nil
                if not stillExists then
                    mobDead = true
                    break
                end
                local h2 = mob:FindFirstChild("Humanoid")
                if not h2 or h2.Health <= 0 then
                    mobDead = true
                    break
                end

            until time() > combatTimeout

            -- Kill tellen
            if mobDead then
                if not _countedMobs[mob] then
                    _countedMobs[mob] = true
                    S.TotalKills = (S.TotalKills or 0) + 1
                    S.SessionKills = (S.SessionKills or 0) + 1
                    S.RunKills = (S.RunKills or 0) + 1
                    SaveState(S)
                    UK()
                    Log("Dungeon","Mob gekild | DungeonRun: "..dungeonRunNo.." | RunKills: "..(S.RunKills or 0).." | Life: "..(S.TotalKills or 0))
                else
                    Log("Dungeon","Kill skip (al geteld)")
                end
            else
                Log("Dungeon","Mob combat timeout, volgende")
            end

            -- Live enemy teller updaten na elke mob
            local stillAlive = 0
            pcall(function()
                local st = Workspace:FindFirstChild("Stage") if not st then return end
                for _, map in pairs(st:GetChildren()) do
                    if string.sub(map.Name,1,3)=="map" then
                        local f = map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                        if f then
                            for _, m in pairs(f:GetChildren()) do
                                pcall(function()
                                    local h = m:FindFirstChild("Humanoid")
                                    if h and h.Health > 0 then stillAlive += 1 end
                                end)
                            end
                        end
                    end
                end
            end)
            UpdateEnemyProgress(stillAlive)
            UpdateSessionBar()

            task.wait(0.05)
        end

        task.wait(0.3)
    end

    Log("Dungeon","Clear timeout")
end

-- ==============================================================================
-- FASES
-- ==============================================================================
local function RunDungeonPhase()
    local dungeonRunNo = (S.CurrentRun or 0) + 1
    UP("DUNGEON") Log("Dungeon","=== Run "..dungeonRunNo.." start ===")

    WaitForWorldLoad(15)   if not S.Running then return end
    WaitForLoadingGui(30)  if not S.Running then return end
    WaitForDoor()          if not S.Running then return end

    _countedMobs = {}
    S.RunKills = 0
    UK()
    StartLiveTimer()

    local alive,total=CountEnemies()
    Log("Dungeon","Enemies init: "..alive.."/"..total)
    UpdateEnemyProgress(alive)

    US("Run "..dungeonRunNo.." | Aanvallen...")
    ClearDungeon()
    if not S.Running then StopLiveTimer() return end

    local endWait = tick()+10
    while tick()<endWait and not IsEndScreenVisible() do
        task.wait(0.3)
    end
    if not IsEndScreenVisible() then
        Warn("Dungeon","Eindscherm niet gevonden na walk")
    end

    StopLiveTimer()
    -- os.time() overleeft teleport, tick() niet
    local elapsed = os.time() - (S.RunStart or os.time())
    if elapsed <= 0 or elapsed > 3600 then elapsed = math.floor(tick() - _localRunStart) end
    if elapsed <= 0 then elapsed = 1 end
    local timeStr=string.format("%d:%02d",math.floor(elapsed/60),elapsed%60)
    UT(timeStr) Log("Dungeon","Run tijd: "..timeStr)
    if not S.BestTime or elapsed<S.BestTime then
        S.BestTime=elapsed SaveState(S) UB(elapsed)
        Log("Dungeon","Nieuwe best: "..timeStr)
    end

    S.TotalRuns = (S.TotalRuns or 0) + 1
    S.SessionRuns = (S.SessionRuns or 0) + 1
    S.TotalTimeSec = (S.TotalTimeSec or 0) + elapsed
    S.CurrentRun += 1
    SaveState(S) UR()
    UpdateSessionBar()

    local totalTimeStr = string.format("%dh %dm",
        math.floor(S.TotalTimeSec/3600),
        math.floor((S.TotalTimeSec%3600)/60))
    Log("Dungeon","=== Run "..S.CurrentRun.." klaar | Kills: "..S.TotalKills.." | TotalRuns: "..S.TotalRuns.." | TotalTijd: "..totalTimeStr.." ===")

    if S.MaxRuns>0 and S.CurrentRun>S.MaxRuns then
        US("Klaar! "..S.MaxRuns.." runs") Log("Dungeon","Max bereikt")
        S.Running=false SaveState(S) UP("IDLE") UE(nil,nil)
        UpdateStatusDot(false)
        return
    end

    US("Wacht Again...") Log("Dungeon","Zoeken againbtn (max 40s)...")
    local dl=tick()+40
    while tick()<dl do
        if not S.Running then return end
        if not IsEndScreenVisible() then
            Log("Dungeon","Eindscherm verdwenen, al geteleporteerd")
            SetPhase("DUNGEON")
            return
        end
        local b=FindAgainBtn()
        if b then
            Log("Dungeon","Again gevonden! Klikken...")
            ClickObj(b)
            local tw=tick()+8
            while tick()<tw do
                task.wait(0.3)
                if not IsEndScreenVisible() then
                    Log("Dungeon","Teleport gestart")
                    SetPhase("DUNGEON")
                    US("Teleporteren...")
                    return
                end
            end
        end
        task.wait(0.5)
    end
    Warn("Dungeon","Again timeout") US("Again niet gevonden")
    S.Running=false SaveState(S) UP("IDLE") StopLiveTimer()
    UpdateStatusDot(false)
end

local function RunLobbyPhase()
    UP("LOBBY") Log("Lobby","Start")
    WaitForWorldLoad(15) if not S.Running then return end
    US("Lobby route...")

    local _, hum, root = GetChar()
    if not hum or not root then S.Running=false SaveState(S) return end

    local startIdx = FindNearestRouteIndex(LobbyRoute)
    Log("Lobby","Route start bij waypoint "..startIdx.." van "..#LobbyRoute)

    if startIdx <= #LobbyRoute then
        for i = startIdx, #LobbyRoute do
            if not S.Running then return end
            local step = LobbyRoute[i]
            Log("Lobby","Stap "..i.." | TP naar "..tostring(step.Pos))
            US("Lobby stap "..i.."/"..#LobbyRoute)
            pcall(function()
                root.CFrame = CFrame.new(step.Pos)
            end)
            task.wait(0.2)
        end
    else
        Log("Lobby","Al bij eindpunt, route overgeslagen")
        US("Al bij party-knop!")
    end

    if not S.Running then return end
    UP("PARTY") US("Party aanmaken...")
    local ok = TryCreateParty()
    if not ok then
        Warn("Lobby","Party mislukt") US("Party mislukt")
        S.Running=false SaveState(S) UP("IDLE")
        UpdateStatusDot(false)
    end
end

local function AutoStart()
    if not S.Running then return end
    UR() UE(nil,nil) UL(nil)
    US("Wacht karakter...")
    local t=tick() repeat task.wait(0.3) until GetChar() or tick()-t>15
    WaitForWorldLoad(15)

    local inDungeon = IsInDungeon()
    if not inDungeon and S.Phase == "DUNGEON" then
        US("Wacht op dungeon detectie...")
        local dl = tick() + 10
        while tick() < dl and not inDungeon do
            task.wait(0.5)
            inDungeon = IsInDungeon()
        end
    end

    Log("AutoStart","Phase="..S.Phase.." InDungeon="..tostring(inDungeon))
    if S.Phase=="DUNGEON" or inDungeon then
        US("Dungeon! Run "..((S.CurrentRun or 0) + 1)) RunDungeonPhase()
    else
        US("Lobby, starten...") RunLobbyPhase()
    end
end

-- ==============================================================================
-- HOOFD KNOPPEN
-- ==============================================================================
BtnStart.MouseButton1Click:Connect(function()
    if S.Running then US("Al bezig!") return end
    -- Sessie tellers resetten
    S.Running=true
    S.CurrentRun=0
    S.SessionKills=0
    S.SessionRuns=0
    S.RunKills=0
    _countedMobs={}
    -- Lifetime totals NIET resetten: TotalRuns, TotalTimeSec, TotalKills, BestTime
    if not S.TotalRuns then S.TotalRuns=0 end
    if not S.TotalTimeSec then S.TotalTimeSec=0 end
    if not S.TotalKills then S.TotalKills=0 end
    SaveState(S) UP("LOBBY")
    UR() UK() UE(nil,nil) UT(nil) UL(nil)
    UpdateStatusDot(true)
    UpdateSessionBar()
    Log("Control","START | Lifetime runs: "..S.TotalRuns.." kills: "..S.TotalKills)
    task.spawn(AutoStart)
end)

BtnStop.MouseButton1Click:Connect(function()
    S.Running=false SaveState(S) UP("IDLE") UE(nil,nil) UL(nil)
    StopLiveTimer()
    UpdateStatusDot(false)
    pcall(function() local _,hum,root=GetChar() if hum and root then hum:MoveTo(root.Position) end end)
    US("Gestopt") Log("Control","STOP")
end)

BtnParty.MouseButton1Click:Connect(function()
    if not S.Running then task.spawn(TryCreateParty) end
end)

-- ==============================================================================
-- BOOT
-- ==============================================================================
_G._PeakDashEnabled = true

US("Idle") UR() UP(S.Phase) UK() UL(nil) UpdateSessionBar()
if S.BestTime then UB(S.BestTime) end
UpdateStatusDot(S.Running)
Log("Boot","TotalRuns="..(S.TotalRuns or 0).." TotalTijd="..(S.TotalTimeSec or 0).."s Kills="..S.TotalKills)
Log("Boot","[F8] = GUI tonen/verbergen  |  [─] = minimaliseren  |  [✕] = sluiten")

task.spawn(function()
    task.wait(2)
    local inDungeon = IsInDungeon()

    if not inDungeon then
        local dl = tick() + 10
        while tick() < dl do
            task.wait(0.5)
            inDungeon = IsInDungeon()
            if inDungeon then break end
        end
    end

    if inDungeon then
        Log("Boot","Dungeon gedetecteerd bij boot, automatisch hervatten")
        S.Running = true
        SaveState(S)
        UP("DUNGEON")
        UpdateStatusDot(true)
        UR() UK() UE(nil,nil) UL(nil)
        US("Dungeon gedetecteerd! Hervatten...")
        RunDungeonPhase()
    elseif S.Running then
        Log("Boot","Hervatten (Phase="..S.Phase..")")
        task.spawn(AutoStart)
    else
        US("Idle - Druk op START")
        Log("Boot","Fresh start - F8 om GUI te verbergen")
    end
end)
