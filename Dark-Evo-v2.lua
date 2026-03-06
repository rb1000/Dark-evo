-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v2.2 - F-dash spam, persistente runs/kills/tijd
-- ============================================================

local Players             = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local Workspace           = game.Workspace
local LocalPlayer         = Players.LocalPlayer
if not LocalPlayer then warn("[PeakEvo] Geen LocalPlayer!") return end

local function Log(m,t)  print("[PeakEvo]["..m.."] "..tostring(t)) end
local function Warn(m,t) warn("[PeakEvo]["..m.."] "..tostring(t))  end

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
local function SaveState(s) _G.PeakEvo = s shared.PeakEvo = s end
local function LoadState()
    if type(_G.PeakEvo)=="table" and _G.PeakEvo.Phase then
        Log("State","_G | Phase=".._G.PeakEvo.Phase.." Run=".._G.PeakEvo.CurrentRun)
        return _G.PeakEvo
    end
    if type(shared.PeakEvo)=="table" and shared.PeakEvo.Phase then
        Log("State","shared | Phase="..shared.PeakEvo.Phase)
        _G.PeakEvo = shared.PeakEvo return shared.PeakEvo
    end
    Log("State","Nieuw aangemaakt")
    return {Running=false,AutoAttack=true,AttackRange=45,Difficulty="Easy",
            MaxRuns=0,CurrentRun=0,Phase="IDLE",DoorWait=12,
            TotalKills=0,BestTime=nil,RunStart=0,
            TotalRuns=0,TotalTimeSec=0}   -- TotalRuns + TotalTime overleven teleports
end

local S = LoadState()
SaveState(S)

local function SetPhase(p) S.Phase=p SaveState(S) Log("Phase","-> "..p) end

Log("Boot","Running="..tostring(S.Running).." Phase="..S.Phase.." Run="..S.CurrentRun)

-- ==============================================================================
-- F-DASH LOOP
-- Simuleert de F-toets (dash ability) elke 2 seconden tijdens het lopen.
-- Werkt alleen als S.Running actief is.
-- ==============================================================================
local _lastDash = 0
local DASH_INTERVAL = 2.05   -- iets meer dan 2s cooldown van het spel

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
-- GUI
-- ==============================================================================
pcall(function()
    local old = LocalPlayer.PlayerGui:FindFirstChild("PeakEvoGui")
    if old then old:Destroy() end
end)

local Screen = Instance.new("ScreenGui")
Screen.Name="PeakEvoGui" Screen.ResetOnSpawn=false
Screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
Screen.Parent=LocalPlayer.PlayerGui

local Main = Instance.new("Frame")
Main.Name="Main" Main.Size=UDim2.new(0,300,0,340)
Main.Position=UDim2.new(0,16,0.5,-183)
Main.BackgroundColor3=Color3.fromRGB(18,18,22)
Main.BorderSizePixel=0 Main.Active=true Main.Draggable=true Main.Parent=Screen
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,8)

local TB=Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,32) TB.BackgroundColor3=Color3.fromRGB(26,26,32)
TB.BorderSizePixel=0 TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,8)
local TFix=Instance.new("Frame")
TFix.Size=UDim2.new(1,0,0,8) TFix.Position=UDim2.new(0,0,1,-8)
TFix.BackgroundColor3=Color3.fromRGB(26,26,32) TFix.BorderSizePixel=0 TFix.Parent=TB

local TL=Instance.new("TextLabel")
TL.Size=UDim2.new(1,-12,1,0) TL.Position=UDim2.new(0,12,0,0)
TL.BackgroundTransparency=1 TL.Text=">> Peak Evo - RB1000"
TL.TextColor3=Color3.fromRGB(220,220,255) TL.TextSize=13
TL.Font=Enum.Font.GothamBold TL.TextXAlignment=Enum.TextXAlignment.Left TL.Parent=TB

local function Hdr(txt,y)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,-20,0,14) l.Position=UDim2.new(0,10,0,y)
    l.BackgroundTransparency=1 l.Text=txt
    l.TextColor3=Color3.fromRGB(100,100,140) l.TextSize=10
    l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=Main
end

local function Div(y)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,-20,0,1) f.Position=UDim2.new(0,10,0,y)
    f.BackgroundColor3=Color3.fromRGB(40,40,55) f.BorderSizePixel=0 f.Parent=Main
end

local function DD(lbl,opts,def,y,cb)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,-20,0,24) c.Position=UDim2.new(0,10,0,y)
    c.BackgroundColor3=Color3.fromRGB(30,30,38) c.BorderSizePixel=0 c.Parent=Main
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,5)
    local kl=Instance.new("TextLabel")
    kl.Size=UDim2.new(0,90,1,0) kl.Position=UDim2.new(0,8,0,0)
    kl.BackgroundTransparency=1 kl.Text=lbl kl.TextColor3=Color3.fromRGB(160,160,190)
    kl.TextSize=11 kl.Font=Enum.Font.Gotham kl.TextXAlignment=Enum.TextXAlignment.Left kl.Parent=c
    local vl=Instance.new("TextLabel")
    vl.Size=UDim2.new(0,110,1,0) vl.Position=UDim2.new(0,96,0,0)
    vl.BackgroundTransparency=1 vl.Text=tostring(def)
    vl.TextColor3=Color3.fromRGB(220,220,255) vl.TextSize=11
    vl.Font=Enum.Font.GothamBold vl.TextXAlignment=Enum.TextXAlignment.Left vl.Parent=c
    local al=Instance.new("TextLabel")
    al.Size=UDim2.new(0,18,1,0) al.Position=UDim2.new(1,-20,0,0)
    al.BackgroundTransparency=1 al.Text=">" al.TextColor3=Color3.fromRGB(120,120,160)
    al.TextSize=14 al.Font=Enum.Font.GothamBold al.Parent=c
    local idx=1
    for i,v in ipairs(opts) do if tostring(v)==tostring(def) then idx=i break end end
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.Parent=c
    btn.MouseButton1Click:Connect(function()
        idx=idx%#opts+1 vl.Text=tostring(opts[idx]) cb(opts[idx])
    end)
end

local function TG(lbl,def,y,cb)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,-20,0,24) c.Position=UDim2.new(0,10,0,y)
    c.BackgroundColor3=Color3.fromRGB(30,30,38) c.BorderSizePixel=0 c.Parent=Main
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,5)
    local kl=Instance.new("TextLabel")
    kl.Size=UDim2.new(1,-50,1,0) kl.Position=UDim2.new(0,8,0,0)
    kl.BackgroundTransparency=1 kl.Text=lbl kl.TextColor3=Color3.fromRGB(160,160,190)
    kl.TextSize=11 kl.Font=Enum.Font.Gotham kl.TextXAlignment=Enum.TextXAlignment.Left kl.Parent=c
    local st=def
    local pill=Instance.new("Frame")
    pill.Size=UDim2.new(0,36,0,16) pill.Position=UDim2.new(1,-44,0.5,-8)
    pill.BackgroundColor3=st and Color3.fromRGB(80,180,100) or Color3.fromRGB(60,60,80)
    pill.BorderSizePixel=0 pill.Parent=c
    Instance.new("UICorner",pill).CornerRadius=UDim.new(1,0)
    local knob=Instance.new("Frame")
    knob.Size=UDim2.new(0,12,0,12)
    knob.Position=st and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
    knob.BackgroundColor3=Color3.fromRGB(255,255,255) knob.BorderSizePixel=0 knob.Parent=pill
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.Parent=c
    btn.MouseButton1Click:Connect(function()
        st=not st
        TweenService:Create(pill,TweenInfo.new(0.15),{BackgroundColor3=st and Color3.fromRGB(80,180,100) or Color3.fromRGB(60,60,80)}):Play()
        TweenService:Create(knob,TweenInfo.new(0.15),{Position=st and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)}):Play()
        cb(st)
    end)
end

local function Btn(txt,x,y,w,col)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(0,w,0,26) b.Position=UDim2.new(0,x,0,y)
    b.BackgroundColor3=col b.BorderSizePixel=0 b.Text=txt
    b.TextColor3=Color3.fromRGB(220,220,255) b.TextSize=12
    b.Font=Enum.Font.GothamBold b.AutoButtonColor=false b.Parent=Main
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=col:Lerp(Color3.new(1,1,1),0.12)}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=col}):Play() end)
    return b
end

local function StatBox(key,col,row)
    local x=col==0 and 10 or 155
    local y=188+row*22
    local box=Instance.new("Frame")
    box.Size=UDim2.new(0,135,0,20) box.Position=UDim2.new(0,x,0,y)
    box.BackgroundColor3=Color3.fromRGB(26,26,34) box.BorderSizePixel=0 box.Parent=Main
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,4)
    local kl=Instance.new("TextLabel")
    kl.Size=UDim2.new(0,48,1,0) kl.Position=UDim2.new(0,6,0,0)
    kl.BackgroundTransparency=1 kl.Text=key kl.TextColor3=Color3.fromRGB(100,100,140)
    kl.TextSize=10 kl.Font=Enum.Font.Gotham kl.TextXAlignment=Enum.TextXAlignment.Left kl.Parent=box
    local vl=Instance.new("TextLabel")
    vl.Size=UDim2.new(1,-54,1,0) vl.Position=UDim2.new(0,50,0,0)
    vl.BackgroundTransparency=1 vl.Text="-"
    vl.TextColor3=Color3.fromRGB(220,220,255) vl.TextSize=10
    vl.Font=Enum.Font.GothamBold vl.TextXAlignment=Enum.TextXAlignment.Left vl.Parent=box
    return vl
end

Hdr("CONFIG",36)
DD("Difficulty",{"Easy","Normal","Hard"},S.Difficulty,52,function(v) S.Difficulty=v end)
DD("Runs",{"1","2","3","5","10","25","50","Oneindig"},"Oneindig",80,function(v)
    S.MaxRuns=v=="Oneindig" and 0 or tonumber(v) S.CurrentRun=0 SaveState(S)
end)
DD("Deur wacht",{"8","10","12","15","20"},"12",108,function(v) S.DoorWait=tonumber(v) end)
TG("Auto Attack",S.AutoAttack,136,function(v) S.AutoAttack=v end)
Div(166) Hdr("LIVE",172)

local VS=StatBox("Status",0,0)
local VP=StatBox("Fase",  1,0)
local VR=StatBox("Runs",  0,1)
local VE=StatBox("Enemy", 1,1)
local VT=StatBox("Tijd",  0,2)
local VB=StatBox("Best",  1,2)
local VK=StatBox("Kills", 0,3)
local VL=StatBox("Timer", 1,3)

Div(278)
local BtnStart = Btn("[START]", 10,  282, 84, Color3.fromRGB(55,150,80))
local BtnStop  = Btn("[STOP]",  108, 282, 84, Color3.fromRGB(170,55,55))
local BtnParty = Btn("[Party]", 206, 282, 84, Color3.fromRGB(90,70,150))

local FaseKleur={IDLE=Color3.fromRGB(120,120,140),LOBBY=Color3.fromRGB(100,180,255),PARTY=Color3.fromRGB(255,200,80),DUNGEON=Color3.fromRGB(80,220,120)}

local function US(t) pcall(function() VS.Text=tostring(t) end) Log("Status",t) end
local function UP(p)
    S.Phase=p SaveState(S)
    pcall(function() VP.Text=p VP.TextColor3=FaseKleur[p] or Color3.fromRGB(220,220,255) end)
end
local function UR() pcall(function() VR.Text=S.CurrentRun.."/".. (S.MaxRuns==0 and "inf" or S.MaxRuns) end) end
local function UE(a,t) pcall(function() VE.Text=a and (a.."/"..t) or "-" end) end
local function UK() pcall(function() VK.Text=tostring(S.TotalKills) end) end
local function UT(s) pcall(function() VT.Text=s or "-" end) end
local function UB(s) if not s then return end pcall(function() VB.Text=string.format("%d:%02d",math.floor(s/60),s%60) end) end
local function UL(s) pcall(function() VL.Text=s or "-" end) end

-- ==============================================================================
-- LIVE TIMER
-- ==============================================================================
local timerConn = nil
local function StartLiveTimer()
    if timerConn then pcall(function() timerConn:Disconnect() end) timerConn=nil end
    S.RunStart = tick()
    timerConn = RunService.Heartbeat:Connect(function()
        if not S.Running or S.Phase ~= "DUNGEON" then
            pcall(function() timerConn:Disconnect() end)
            timerConn = nil
            return
        end
        local e = math.floor(tick()-S.RunStart)
        UL(string.format("%d:%02d",math.floor(e/60),e%60))
    end)
end

local function StopLiveTimer()
    if timerConn then pcall(function() timerConn:Disconnect() end) timerConn=nil end
end

-- ==============================================================================
-- WERELD
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
    local w=S.DoorWait or 12 Log("Deur","Wachten "..w.."s")
    for i=w,1,-1 do
        if not S.Running then return end
        US("Deur in "..i.."s...") task.wait(1)
    end
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
-- ROUTES
-- ==============================================================================
-- GetChar hier zodat FindNearestRouteIndex het kan gebruiken
local function GetChar()
    local c=LocalPlayer.Character if not c then return nil,nil,nil end
    return c,c:FindFirstChild("Humanoid"),c:FindFirstChild("HumanoidRootPart")
end

local LobbyRoute={
    {Pos=Vector3.new(-1696, 22.6, -321.6)},
    {Pos=Vector3.new(-1741.2, 22.8, -322.6)},
}

local DungeonEnd=Vector3.new(-880.3,31.6,-507.3)

-- ==============================================================================
-- SLIM STARTPUNT
-- Zoekt het dichtstbijzijnde waypoint in de route en begint VANAF daar.
-- Zo loopt hij niet terug als je al ver bent.
-- ==============================================================================
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
    -- Als we al heel dicht bij het eindpunt zijn, sla de hele route over
    local lastPos = route[#route].Pos
    if (root.Position - lastPos).Magnitude < 8 then
        return #route + 1   -- geeft aan: sla alle waypoints over
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
            if map.Name~="baseStage" then
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
    local _,totalStart=CountEnemies() local killsBefore=0

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
        TryDash()   -- F-dash elke ~2s tijdens lopen

        if tick()-lastEL>2 then
            local alive,total=CountEnemies() UE(alive,total)
            local nk=totalStart-alive
            if nk>killsBefore then S.TotalKills=S.TotalKills+(nk-killsBefore) killsBefore=nk UK() end
            lastEL=tick()
        end

        if S.AutoAttack then
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
    Log("Combat","Klaar | "..alive.."/"..total.." over") UE(alive,total)
end

-- ==============================================================================
-- DUNGEON CLEAR
-- ==============================================================================
local function ClearDungeon()
    Log("Dungeon","Monster clear gestart")
    local timeout = time() + 300
    while S.Running and time() < timeout do
        if IsEndScreenVisible() then
            Log("Dungeon","Eindscherm al zichtbaar")
            return
        end
        local enemy = FindEnemy()
        if not enemy then
            Log("Dungeon","Geen mobs meer gevonden")
            return
        end
        local er = enemy:FindFirstChild("HumanoidRootPart")
        local hum = enemy:FindFirstChild("Humanoid")
        if er and hum and hum.Health > 0 then
            local _,playerHum,root = GetChar()
            if not root or not playerHum then return end
            playerHum:MoveTo(er.Position)
            TryDash()   -- dash naar mob toe
            local combatTimeout = time() + 15
            repeat
                if not S.Running then return end
                if IsEndScreenVisible() then return end
                Attack(enemy)
                pcall(function() playerHum:MoveTo(er.Position) end)
                task.wait(0.15)
            until not enemy or not enemy.Parent or hum.Health <= 0 or time() > combatTimeout
            if hum and hum.Health <= 0 then
                S.TotalKills += 1
                SaveState(S)
                UK()
            end
        end
        task.wait(0.1)
    end
    Log("Dungeon","Clear timeout")
end

-- ==============================================================================
-- FASES
-- ==============================================================================
local function RunDungeonPhase()
    UP("DUNGEON") Log("Dungeon","=== Run "..S.CurrentRun.." start ===")

    WaitForWorldLoad(15)   if not S.Running then return end
    WaitForLoadingGui(30)  if not S.Running then return end
    WaitForDoor()          if not S.Running then return end

    StartLiveTimer()

    local alive,total=CountEnemies()
    Log("Dungeon","Enemies: "..alive.."/"..total) UE(alive,total)

    US("Run "..S.CurrentRun.." | Lopen...")
    ClearDungeon()
    Walk(DungeonEnd)
    if not S.Running then StopLiveTimer() return end

    local endWait = tick()+10
    while tick()<endWait and not IsEndScreenVisible() do
        task.wait(0.3)
    end
    if not IsEndScreenVisible() then
        Warn("Dungeon","Eindscherm niet gevonden na walk")
    end

    StopLiveTimer()
    local elapsed=math.floor(tick()-S.RunStart)
    local timeStr=string.format("%d:%02d",math.floor(elapsed/60),elapsed%60)
    UT(timeStr) Log("Dungeon","Run tijd: "..timeStr)
    if not S.BestTime or elapsed<S.BestTime then
        S.BestTime=elapsed SaveState(S) UB(elapsed)
        Log("Dungeon","Nieuwe best: "..timeStr)
    end

    -- Persistente tellers: overleven teleports via _G/shared
    S.TotalRuns = (S.TotalRuns or 0) + 1
    S.TotalTimeSec = (S.TotalTimeSec or 0) + elapsed
    S.CurrentRun+=1 SaveState(S) UR()

    local totalTimeStr = string.format("%dh %dm",
        math.floor(S.TotalTimeSec/3600),
        math.floor((S.TotalTimeSec%3600)/60))
    Log("Dungeon","=== Run "..S.CurrentRun.." klaar | Kills: "..S.TotalKills.." | TotalRuns: "..S.TotalRuns.." | TotalTijd: "..totalTimeStr.." ===")

    if S.MaxRuns>0 and S.CurrentRun>S.MaxRuns then
        US("Klaar! "..S.MaxRuns.." runs") Log("Dungeon","Max bereikt")
        S.Running=false SaveState(S) UP("IDLE") UE(nil,nil) return
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
            Log("Dungeon","Eindscherm nog zichtbaar na klik, opnieuw proberen...")
        end
        task.wait(0.5)
    end
    Warn("Dungeon","Again timeout") US("Again niet gevonden")
    S.Running=false SaveState(S) UP("IDLE") StopLiveTimer()
end

-- ==============================================================================
-- LOBBY FASE - SLIM STARTPUNT
-- Start vanaf het dichtstbijzijnde waypoint, loopt nooit terug
-- ==============================================================================
local function RunLobbyPhase()
    UP("LOBBY") Log("Lobby","Start")
    WaitForWorldLoad(15) if not S.Running then return end
    US("Lobby route...")

    local _,hum,_=GetChar()
    if not hum then S.Running=false SaveState(S) return end

    -- Bepaal slim startpunt: ga naar het dichtstbijzijnde waypoint
    local startIdx = FindNearestRouteIndex(LobbyRoute)
    Log("Lobby","Route start bij waypoint "..startIdx.." van "..#LobbyRoute)

    if startIdx <= #LobbyRoute then
        for i = startIdx, #LobbyRoute do
            if not S.Running then return end
            local step = LobbyRoute[i]
            Log("Lobby","Stap "..i)
            US("Lobby stap "..i.."/"..#LobbyRoute)
            pcall(function()
                hum:MoveTo(step.Pos)
                local t=tick() local done=false
                local conn=hum.MoveToFinished:Connect(function() done=true end)
                while not done and tick()-t<6 do task.wait(0.1) end
                pcall(function() conn:Disconnect() end)
            end)
            task.wait(0.1)
        end
    else
        Log("Lobby","Al bij eindpunt, route overgeslagen")
        US("Al bij party-knop!")
    end

    if not S.Running then return end
    UP("PARTY") US("Party aanmaken...")
    local ok=TryCreateParty()
    if not ok then
        Warn("Lobby","Party mislukt") US("Party mislukt")
        S.Running=false SaveState(S) UP("IDLE")
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
        US("Dungeon! Run "..S.CurrentRun) RunDungeonPhase()
    else
        US("Lobby, starten...") RunLobbyPhase()
    end
end

-- ==============================================================================
-- KNOPPEN
-- ==============================================================================
BtnStart.MouseButton1Click:Connect(function()
    if S.Running then US("Al bezig!") return end
    -- CurrentRun en TotalKills resetten voor nieuwe sessie
    -- TotalRuns en TotalTimeSec blijven staan (persistent over alle sessies)
    S.Running=true S.CurrentRun=0 S.TotalKills=0
    if not S.TotalRuns then S.TotalRuns=0 end
    if not S.TotalTimeSec then S.TotalTimeSec=0 end
    SaveState(S) UP("LOBBY")
    UR() UK() UE(nil,nil) UT(nil) UL(nil)
    Log("Control","START | TotalRuns tot nu: "..S.TotalRuns) task.spawn(AutoStart)
end)

BtnStop.MouseButton1Click:Connect(function()
    S.Running=false SaveState(S) UP("IDLE") UE(nil,nil) UL(nil)
    StopLiveTimer()
    pcall(function() local _,hum,root=GetChar() if hum and root then hum:MoveTo(root.Position) end end)
    US("Gestopt") Log("Control","STOP")
end)

BtnParty.MouseButton1Click:Connect(function()
    if not S.Running then task.spawn(TryCreateParty) end
end)

-- ==============================================================================
-- BOOT
-- ==============================================================================
US("Idle") UR() UP(S.Phase) UK() UL(nil)
if S.BestTime then UB(S.BestTime) end
Log("Boot","TotalRuns="..(S.TotalRuns or 0).." TotalTijd="..(S.TotalTimeSec or 0).."s Kills="..S.TotalKills)

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
        UR() UK() UE(nil,nil) UL(nil)
        US("Dungeon gedetecteerd! Hervatten...")
        RunDungeonPhase()
    elseif S.Running then
        Log("Boot","Hervatten (Phase="..S.Phase..")")
        task.spawn(AutoStart)
    else
        US("Idle - Druk op START")
        Log("Boot","Fresh start")
    end
end)
