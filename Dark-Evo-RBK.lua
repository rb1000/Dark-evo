-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v1.8 - Memory leak fixes + ingebouwde run timer
-- ============================================================

local Players             = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local TweenService        = game:GetService("TweenService")
local Workspace           = game.Workspace
local LocalPlayer         = Players.LocalPlayer
if not LocalPlayer then warn("[PeakEvo] Geen LocalPlayer!") return end

local function Log(m,t)  print("[PeakEvo]["..m.."] "..tostring(t)) end
local function Warn(m,t) warn("[PeakEvo]["..m.."] "..tostring(t))  end

-- ==============================================================================
-- ANTI-AFK — maar 1 connection, nooit dubbel
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
            TotalKills=0,BestTime=nil,RunStart=0}
end

local S = LoadState()
SaveState(S)

local function SetPhase(p) S.Phase=p SaveState(S) Log("Phase","→ "..p) end

Log("Boot","Running="..tostring(S.Running).." Phase="..S.Phase.." Run="..S.CurrentRun)

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
Main.Position=UDim2.new(0,16,0.5,-170)
Main.BackgroundColor3=Color3.fromRGB(18,18,22)
Main.BorderSizePixel=0 Main.Active=true Main.Draggable=true Main.Parent=Screen
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,8)

-- Titelbalk
local TB=Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,32) TB.BackgroundColor3=Color3.fromRGB(26,26,32)
TB.BorderSizePixel=0 TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,8)
local TFix=Instance.new("Frame")
TFix.Size=UDim2.new(1,0,0,8) TFix.Position=UDim2.new(0,0,1,-8)
TFix.BackgroundColor3=Color3.fromRGB(26,26,32) TFix.BorderSizePixel=0 TFix.Parent=TB

local TL=Instance.new("TextLabel")
TL.Size=UDim2.new(1,-12,1,0) TL.Position=UDim2.new(0,12,0,0)
TL.BackgroundTransparency=1 TL.Text="⚡ Peak Evo - RB1000"
TL.TextColor3=Color3.fromRGB(220,220,255) TL.TextSize=13
TL.Font=Enum.Font.GothamBold TL.TextXAlignment=Enum.TextXAlignment.Left TL.Parent=TB

-- Helpers
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
    al.BackgroundTransparency=1 al.Text="›" al.TextColor3=Color3.fromRGB(120,120,160)
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

-- Layout
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
-- Live run timer (telt zelf)
local VL=StatBox("Timer", 1,3)

Div(278)
local BtnStart = Btn("▶ START", 10,  282, 84, Color3.fromRGB(55,150,80))
local BtnStop  = Btn("⏹ STOP",  108, 282, 84, Color3.fromRGB(170,55,55))
local BtnParty = Btn("🎉 Party", 206, 282, 84, Color3.fromRGB(90,70,150))

local FaseKleur={IDLE=Color3.fromRGB(120,120,140),LOBBY=Color3.fromRGB(100,180,255),PARTY=Color3.fromRGB(255,200,80),DUNGEON=Color3.fromRGB(80,220,120)}

-- Update helpers
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
local function UL(s) pcall(function() VL.Text=s or "-" end) end -- live timer label

-- ==============================================================================
-- LIVE TIMER — telt in dungeon, geen connections, geen leak
-- Wordt gestart/gestopt via S.RunStart=tick() en S.Running
-- ==============================================================================
local timerConn = nil
local function StartLiveTimer()
    -- Cleanup vorige timer eerst
    if timerConn then pcall(function() timerConn:Disconnect() end) timerConn=nil end
    S.RunStart = tick()
    timerConn = game:GetService("RunService").Heartbeat:Connect(function()
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
        if s:FindFirstChild("baseStage") then Log("Detect","Lobby") return false end
        for _,c in pairs(s:GetChildren()) do
            if string.sub(c.Name,1,3)=="map" then Log("Detect","Dungeon: "..c.Name) return true end
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
local LobbyRoute={
    {Pos=Vector3.new(-1682.3,6.5,54.2)},
    {Pos=Vector3.new(-1685.6,6.3,0.1)},
    {Pos=Vector3.new(-1689.6,22.6,-321.2)},
    {Pos=Vector3.new(-1686.7,22.6,-319.1)},
    {Pos=Vector3.new(-1744.0,22.6,-322.5)},
}
local DungeonEnd=Vector3.new(-880.3,31.6,-507.3)

-- ==============================================================================
-- KLIK — geen getconnections spam, alleen VirtualInput
-- ==============================================================================
local function ClickObj(obj)
    if not obj then return false end
    return pcall(function()
        if not obj.AbsolutePosition then return end
        local cx=obj.AbsolutePosition.X+obj.AbsoluteSize.X/2
        local cy=obj.AbsolutePosition.Y+obj.AbsoluteSize.Y/2
        -- Probeer eerst via Activated event, dan VirtualInput als fallback
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
        -- Altijd ook VirtualInput voor zekerheid
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

-- Again knop — zoekt op alle plekken
local function FindAgainBtn()
    local found=nil
    pcall(function()
        local pg=LocalPlayer:FindFirstChild("PlayerGui")
        local pog=pg and pg:FindFirstChild("PartyOverGui") if not pog then return end
        local bg=pog.Frame and pog.Frame:FindFirstChild("bg") if not bg then return end
        -- Direct
        local b=bg:FindFirstChild("againbtn")
        if b and b.Visible then Log("Again","gevonden in bg") found=b return end
        -- In againFrame
        local af=bg:FindFirstChild("againFrame")
        if af then
            local b2=af:FindFirstChild("againbtn")
            if b2 and b2.Visible then Log("Again","gevonden in againFrame") found=b2 return end
        end
        -- Deep search fallback
        local b3=bg:FindFirstChild("againbtn",true)
        if b3 and b3.Visible then Log("Again","gevonden via deep search") found=b3 end
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
-- COMBAT — VirtualUser:CaptureController maar 1x per aanval, niet elke frame
-- ==============================================================================
local function GetChar()
    local c=LocalPlayer.Character if not c then return nil,nil,nil end
    return c,c:FindFirstChild("Humanoid"),c:FindFirstChild("HumanoidRootPart")
end

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

-- Attack: CaptureController maar 1x, niet elke 0.1s
local _lastCapture=0
local function Attack(target)
    pcall(function()
        if not target or not target:FindFirstChild("HumanoidRootPart") then return end
        local _,_,root=GetChar() if not root then return end
        -- CaptureController max 1x per seconde
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
    hum:MoveTo(targetPos)
    local stuckT=0 local lastPos=root.Position
    local timeout=tick()+300 local lastEL=tick()
    local _,totalStart=CountEnemies() local killsBefore=0

    while tick()<timeout do
        if not S.Running then pcall(function() hum:MoveTo(root.Position) end) return end

        -- Stop zodra eindscherm zichtbaar
        if IsEndScreenVisible() then
            Log("Walk","Eindscherm zichtbaar, stoppen")
            pcall(function() hum:MoveTo(root.Position) end)
            break
        end

        char,hum,root=GetChar()
        if not char or not hum or not root then task.wait(1) return end
        if (root.Position-targetPos).Magnitude<=4 then break end

        -- Enemy counter elke 2s
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
                    task.wait(0.15) -- iets meer delay = minder CPU
                until tick()>ct or not enemy or not enemy.Parent
                    or not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health<=0
                pcall(function() hum:MoveTo(targetPos) end)
            end
        end

        -- Stuck check
        char,hum,root=GetChar()
        if root then
            if (root.Position-lastPos).Magnitude<0.5 then
                stuckT+=1
                if stuckT>20 then
                    pcall(function() hum.Jump=true end)
                    Log("Move","Jump") stuckT=0
                end
            else stuckT=0 end
            lastPos=root.Position
        end
        task.wait(0.15) -- was 0.1, nu 0.15 = minder CPU
    end
    local alive,total=CountEnemies()
    Log("Combat","Klaar | "..alive.."/"..total.." over") UE(alive,total)
end

-- ==============================================================================
-- FASES
-- ==============================================================================
local function RunDungeonPhase()
    UP("DUNGEON") Log("Dungeon","=== Run "..S.CurrentRun.." start ===")

    WaitForWorldLoad(15)   if not S.Running then return end
    WaitForLoadingGui(30)  if not S.Running then return end
    WaitForDoor()          if not S.Running then return end

    -- Start live timer
    StartLiveTimer()

    local alive,total=CountEnemies()
    Log("Dungeon","Enemies: "..alive.."/"..total) UE(alive,total)

    US("Run "..S.CurrentRun.." | Lopen...")
    Walk(DungeonEnd)
    if not S.Running then StopLiveTimer() return end

    -- Stop timer, sla tijd op
    StopLiveTimer()
    local elapsed=math.floor(tick()-S.RunStart)
    local timeStr=string.format("%d:%02d",math.floor(elapsed/60),elapsed%60)
    UT(timeStr) Log("Dungeon","Run tijd: "..timeStr)
    if not S.BestTime or elapsed<S.BestTime then
        S.BestTime=elapsed SaveState(S) UB(elapsed)
        Log("Dungeon","Nieuwe best: "..timeStr)
    end

    S.CurrentRun+=1 SaveState(S) UR()
    Log("Dungeon","=== Run "..S.CurrentRun.." klaar | Kills: "..S.TotalKills.." ===")

    if S.MaxRuns>0 and S.CurrentRun>S.MaxRuns then
        US("Klaar! "..S.MaxRuns.." runs") Log("Dungeon","Max bereikt")
        S.Running=false SaveState(S) UP("IDLE") UE(nil,nil) return
    end

    -- Wacht op Again knop
    US("Wacht Opnieuw...") Log("Dungeon","Zoeken againbtn (max 40s)...")
    local dl=tick()+40
    while tick()<dl do
        if not S.Running then return end
        local b=FindAgainBtn()
        if b then
            Log("Dungeon","Again gevonden! Klikken...")
            ClickObj(b) task.wait(1.5)
            if not IsEndScreenVisible() then
                SetPhase("DUNGEON") Log("Dungeon","Teleport, Phase=DUNGEON bewaard")
                US("Teleporteren...") return
            end
            Log("Dungeon","Eindscherm nog zichtbaar, opnieuw klikken...")
        end
        task.wait(0.5)
    end
    Warn("Dungeon","Again timeout") US("Again niet gevonden")
    S.Running=false SaveState(S) UP("IDLE") StopLiveTimer()
end

local function RunLobbyPhase()
    UP("LOBBY") Log("Lobby","Start")
    WaitForWorldLoad(15) if not S.Running then return end
    US("Lobby route...")
    local _,hum,_=GetChar()
    if not hum then S.Running=false SaveState(S) return end
    for i,step in ipairs(LobbyRoute) do
        if not S.Running then return end
        Log("Lobby","Stap "..i)
        pcall(function()
            hum:MoveTo(step.Pos)
            local t=tick() local done=false
            local conn=hum.MoveToFinished:Connect(function() done=true end)
            while not done and tick()-t<6 do task.wait(0.1) end
            pcall(function() conn:Disconnect() end) -- altijd disconnecten
        end)
        task.wait(0.1)
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
    local inDungeon=IsInDungeon()
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
    S.Running=true S.CurrentRun=0 S.TotalKills=0
    SaveState(S) UP("LOBBY")
    UR() UK() UE(nil,nil) UT(nil) UL(nil)
    Log("Control","START") task.spawn(AutoStart)
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

if S.Running then
    Log("Boot","Hervatten (Phase="..S.Phase..")")
    task.spawn(AutoStart)
else
    US("Idle - Druk op START") Log("Boot","Fresh start")
end
