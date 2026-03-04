-- ============================================================
-- Peak Evo - RB1000 | Stable Build voor Velocity
-- v1.7 - shared+_G state + betere Again knop detectie
-- ============================================================

local Players             = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local TweenService        = game:GetService("TweenService")
local Workspace           = game.Workspace
local LocalPlayer         = Players.LocalPlayer
if not LocalPlayer then warn("[PeakEvo] Geen LocalPlayer!") return end

local function Log(mod, msg)  print("[PeakEvo][" .. mod .. "] " .. tostring(msg)) end
local function Warn(mod, msg) warn("[PeakEvo][" .. mod .. "] " .. tostring(msg))  end

-- Anti-AFK
pcall(function()
    LocalPlayer.Idled:Connect(function()
        pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new(0,0)) end)
    end)
end)

-- ==============================================================================
-- STATE — opgeslagen in _G én shared zodat teleport het niet wist
-- ==============================================================================
local function SaveState(tbl)
    _G.PeakEvo     = tbl
    shared.PeakEvo = tbl
end

local function LoadState()
    if type(_G.PeakEvo) == "table" and _G.PeakEvo.Phase then
        Log("State","Uit _G | Phase=".._G.PeakEvo.Phase.." Run=".._G.PeakEvo.CurrentRun)
        return _G.PeakEvo
    end
    if type(shared.PeakEvo) == "table" and shared.PeakEvo.Phase then
        Log("State","Uit shared | Phase="..shared.PeakEvo.Phase.." Run="..shared.PeakEvo.CurrentRun)
        _G.PeakEvo = shared.PeakEvo
        return shared.PeakEvo
    end
    Log("State","Fresh aangemaakt")
    return {
        Running=false, AutoAttack=true, AttackRange=45,
        Difficulty="Easy", MaxRuns=0, CurrentRun=0,
        Phase="IDLE", DoorWait=12, TotalKills=0,
        BestTime=nil, RunStartTime=0,
    }
end

local S = LoadState()
SaveState(S)

local function SetPhaseAndSave(phase)
    S.Phase = phase
    SaveState(S)
    Log("Phase","→ "..phase)
end

Log("Boot","Running="..tostring(S.Running).." Phase="..S.Phase.." Run="..S.CurrentRun)

-- ==============================================================================
-- CUSTOM GUI
-- ==============================================================================
pcall(function()
    local old = LocalPlayer.PlayerGui:FindFirstChild("PeakEvoGui")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PeakEvoGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer.PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 340)
Main.Position = UDim2.new(0, 16, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)
local TFix = Instance.new("Frame")
TFix.Size = UDim2.new(1,0,0,8) TFix.Position = UDim2.new(0,0,1,-8)
TFix.BackgroundColor3 = Color3.fromRGB(26,26,32) TFix.BorderSizePixel=0 TFix.Parent=TitleBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1,-12,1,0) TitleLbl.Position = UDim2.new(0,12,0,0)
TitleLbl.BackgroundTransparency=1 TitleLbl.Text="⚡ Peak Evo - RB1000"
TitleLbl.TextColor3=Color3.fromRGB(220,220,255) TitleLbl.TextSize=13
TitleLbl.Font=Enum.Font.GothamBold TitleLbl.TextXAlignment=Enum.TextXAlignment.Left
TitleLbl.Parent=TitleBar

local function Sec(txt, y)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,-20,0,14) l.Position=UDim2.new(0,10,0,y)
    l.BackgroundTransparency=1 l.Text=txt l.TextColor3=Color3.fromRGB(100,100,140)
    l.TextSize=10 l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=Main
end

local function Div(y)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,-20,0,1) f.Position=UDim2.new(0,10,0,y)
    f.BackgroundColor3=Color3.fromRGB(40,40,55) f.BorderSizePixel=0 f.Parent=Main
end

local function DD(label, opts, def, y, fn)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,-20,0,24) c.Position=UDim2.new(0,10,0,y)
    c.BackgroundColor3=Color3.fromRGB(30,30,38) c.BorderSizePixel=0 c.Parent=Main
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,5)
    local kl=Instance.new("TextLabel")
    kl.Size=UDim2.new(0,90,1,0) kl.Position=UDim2.new(0,8,0,0) kl.BackgroundTransparency=1
    kl.Text=label kl.TextColor3=Color3.fromRGB(160,160,190) kl.TextSize=11
    kl.Font=Enum.Font.Gotham kl.TextXAlignment=Enum.TextXAlignment.Left kl.Parent=c
    local vl=Instance.new("TextLabel")
    vl.Size=UDim2.new(0,100,1,0) vl.Position=UDim2.new(0,95,0,0) vl.BackgroundTransparency=1
    vl.Text=tostring(def) vl.TextColor3=Color3.fromRGB(220,220,255) vl.TextSize=11
    vl.Font=Enum.Font.GothamBold vl.TextXAlignment=Enum.TextXAlignment.Left vl.Parent=c
    local ar=Instance.new("TextLabel")
    ar.Size=UDim2.new(0,20,1,0) ar.Position=UDim2.new(1,-22,0,0) ar.BackgroundTransparency=1
    ar.Text="›" ar.TextColor3=Color3.fromRGB(120,120,160) ar.TextSize=14
    ar.Font=Enum.Font.GothamBold ar.Parent=c
    local idx=1
    for i,v in ipairs(opts) do if tostring(v)==tostring(def) then idx=i break end end
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.Parent=c
    btn.MouseButton1Click:Connect(function()
        idx=idx%#opts+1 vl.Text=tostring(opts[idx]) fn(opts[idx])
    end)
end

local function TG(label, def, y, fn)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(1,-20,0,24) c.Position=UDim2.new(0,10,0,y)
    c.BackgroundColor3=Color3.fromRGB(30,30,38) c.BorderSizePixel=0 c.Parent=Main
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,5)
    local kl=Instance.new("TextLabel")
    kl.Size=UDim2.new(1,-50,1,0) kl.Position=UDim2.new(0,8,0,0) kl.BackgroundTransparency=1
    kl.Text=label kl.TextColor3=Color3.fromRGB(160,160,190) kl.TextSize=11
    kl.Font=Enum.Font.Gotham kl.TextXAlignment=Enum.TextXAlignment.Left kl.Parent=c
    local state=def
    local pill=Instance.new("Frame")
    pill.Size=UDim2.new(0,36,0,16) pill.Position=UDim2.new(1,-44,0.5,-8)
    pill.BackgroundColor3=state and Color3.fromRGB(80,180,100) or Color3.fromRGB(60,60,80)
    pill.BorderSizePixel=0 pill.Parent=c
    Instance.new("UICorner",pill).CornerRadius=UDim.new(1,0)
    local knob=Instance.new("Frame")
    knob.Size=UDim2.new(0,12,0,12)
    knob.Position=state and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
    knob.BackgroundColor3=Color3.fromRGB(255,255,255) knob.BorderSizePixel=0 knob.Parent=pill
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.Parent=c
    btn.MouseButton1Click:Connect(function()
        state=not state
        TweenService:Create(pill,TweenInfo.new(0.15),{BackgroundColor3=state and Color3.fromRGB(80,180,100) or Color3.fromRGB(60,60,80)}):Play()
        TweenService:Create(knob,TweenInfo.new(0.15),{Position=state and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)}):Play()
        fn(state)
    end)
end

local function Btn(txt, x, y, w, col)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(0,w,0,26) b.Position=UDim2.new(0,x,0,y)
    b.BackgroundColor3=col b.BorderSizePixel=0 b.Text=txt
    b.TextColor3=Color3.fromRGB(220,220,255) b.TextSize=11
    b.Font=Enum.Font.GothamBold b.AutoButtonColor=false b.Parent=Main
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=col:Lerp(Color3.fromRGB(255,255,255),0.12)}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=col}):Play() end)
    return b
end

local function StatBox(key, val, col, row)
    local x=col==0 and 10 or 155
    local y=186+row*20
    local box=Instance.new("Frame")
    box.Size=UDim2.new(0,135,0,18) box.Position=UDim2.new(0,x,0,y)
    box.BackgroundColor3=Color3.fromRGB(26,26,34) box.BorderSizePixel=0 box.Parent=Main
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,4)
    local kl=Instance.new("TextLabel")
    kl.Size=UDim2.new(0,50,1,0) kl.Position=UDim2.new(0,6,0,0) kl.BackgroundTransparency=1
    kl.Text=key kl.TextColor3=Color3.fromRGB(100,100,140) kl.TextSize=10
    kl.Font=Enum.Font.Gotham kl.TextXAlignment=Enum.TextXAlignment.Left kl.Parent=box
    local vl=Instance.new("TextLabel")
    vl.Size=UDim2.new(1,-56,1,0) vl.Position=UDim2.new(0,52,0,0) vl.BackgroundTransparency=1
    vl.Text=tostring(val) vl.TextColor3=Color3.fromRGB(220,220,255) vl.TextSize=10
    vl.Font=Enum.Font.GothamBold vl.TextXAlignment=Enum.TextXAlignment.Left vl.Parent=box
    return vl
end

-- Bouw layout
Sec("CONFIG",36)
DD("Difficulty",{"Easy","Normal","Hard"},S.Difficulty,52,function(v) S.Difficulty=v SaveState(S) end)
DD("Runs",{"1","2","3","5","10","25","50","Oneindig"},"Oneindig",80,function(v) S.MaxRuns=v=="Oneindig" and 0 or tonumber(v) S.CurrentRun=0 SaveState(S) end)
DD("Deur (s)",{"8","10","12","15","20"},"12",108,function(v) S.DoorWait=tonumber(v) SaveState(S) end)
TG("Auto Attack",S.AutoAttack,136,function(v) S.AutoAttack=v SaveState(S) end)
Div(166)
Sec("LIVE",172)

local ValStatus = StatBox("Status","Idle",  0,0)
local ValPhase  = StatBox("Fase",  "IDLE",  1,0)
local ValRuns   = StatBox("Runs",  "0/0",   0,1)
local ValEnemy  = StatBox("Enemy", "-",     1,1)
local ValTime   = StatBox("Tijd",  "-",     0,2)
local ValBest   = StatBox("Best",  "-",     1,2)
local ValKills  = StatBox("Kills", "0",     0,3)

Div(272)
local BtnStart = Btn("▶ START", 10,  278, 84, Color3.fromRGB(60,160,90))
local BtnStop  = Btn("⏹ STOP",  108, 278, 84, Color3.fromRGB(180,60,60))
local BtnParty = Btn("🎉 Party", 206, 278, 84, Color3.fromRGB(100,80,160))

local FaseColors={IDLE=Color3.fromRGB(120,120,140),LOBBY=Color3.fromRGB(100,180,255),PARTY=Color3.fromRGB(255,200,80),DUNGEON=Color3.fromRGB(80,220,120)}

-- Update helpers
local function US(t) pcall(function() ValStatus.Text=tostring(t) end) Log("Status",t) end
local function UP(p)
    pcall(function() ValPhase.Text=p ValPhase.TextColor3=FaseColors[p] or Color3.fromRGB(220,220,255) end)
end
local function UR() pcall(function() ValRuns.Text=S.CurrentRun.."/".. (S.MaxRuns==0 and "inf" or S.MaxRuns) end) end
local function UE(a,t) pcall(function() ValEnemy.Text=a and (a.."/"..t) or "-" end) end
local function UK() pcall(function() ValKills.Text=tostring(S.TotalKills) end) end
local function UT(s) pcall(function() ValTime.Text=s or "-" end) end
local function UB(sec)
    if not sec then return end
    pcall(function() ValBest.Text=string.format("%d:%02d",math.floor(sec/60),sec%60) end)
end

local function SetPhaseAndSave(phase)
    S.Phase=phase SaveState(S) UP(phase) Log("Phase","→ "..phase)
end

-- ==============================================================================
-- GAME FUNCTIES
-- ==============================================================================
local function WaitForWorldLoad(max)
    max=max or 15 local dl=tick()+max
    while tick()<dl do
        local ok2,r=pcall(function() local st=Workspace:FindFirstChild("Stage") return st~=nil and #st:GetChildren()>0 end)
        if ok2 and r then Log("World","Geladen") task.wait(0.5) return true end
        task.wait(0.3)
    end
    Warn("World","Timeout") return false
end

local function IsInDungeon()
    local ok2,r=pcall(function()
        local st=Workspace:FindFirstChild("Stage") if not st then return false end
        if st:FindFirstChild("baseStage") then Log("Detect","Lobby") return false end
        for _,c in pairs(st:GetChildren()) do
            if string.sub(c.Name,1,3)=="map" then Log("Detect","Dungeon: "..c.Name) return true end
        end
        return false
    end)
    return ok2 and r or false
end

local function CountEnemies()
    local alive,total=0,0
    pcall(function()
        local st=Workspace:FindFirstChild("Stage") if not st then return end
        for _,map in pairs(st:GetChildren()) do
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

local function GetRunTime()
    local t=nil
    pcall(function()
        local pg=LocalPlayer:FindFirstChild("PlayerGui")
        local pog=pg and pg:FindFirstChild("PartyOverGui")
        local bg=pog and pog:FindFirstChild("Frame") and pog.Frame:FindFirstChild("bg")
        local lbl=bg and bg:FindFirstChild("time")
        if lbl and lbl.Text~="" then t=lbl.Text end
    end)
    return t
end

local function ParseTime(str)
    if not str then return nil end
    local parts={} for p in str:gmatch("%d+") do table.insert(parts,tonumber(p)) end
    if #parts==2 then return parts[1]*60+parts[2]
    elseif #parts==3 then return parts[1]*3600+parts[2]*60+parts[3] end
    return nil
end

local function WaitForLoadingGui(max)
    max=max or 30 local dl=tick()+max
    while tick()<dl do
        if not S.Running then return end
        local ld=false
        pcall(function()
            local pg=LocalPlayer:FindFirstChild("PlayerGui")
            local l=pg and pg:FindFirstChild("LoadingGui")
            ld=l~=nil and l.Enabled==true
        end)
        if ld then US("Loading...") task.wait(0.3) else Log("Loading","Klaar") task.wait(0.2) return end
    end
    Warn("Loading","Timeout")
end

local function WaitForDoor()
    local w=S.DoorWait or 12 Log("Deur","Wachten "..w.."s")
    for i=w,1,-1 do if not S.Running then return end US("Deur in "..i.."s...") task.wait(1) end
end

local LobbyRoute={
    {Pos=Vector3.new(-1682.3,6.5,54.2)},
    {Pos=Vector3.new(-1685.6,6.3,0.1)},
    {Pos=Vector3.new(-1689.6,22.6,-321.2)},
    {Pos=Vector3.new(-1686.7,22.6,-319.1)},
    {Pos=Vector3.new(-1744.0,22.6,-322.5)},
}
local DungeonEnd=Vector3.new(-880.3,31.6,-507.3)

local function ClickObj(obj)
    if not obj then return false end
    local s=pcall(function()
        if not obj.AbsolutePosition then return end
        local cx=obj.AbsolutePosition.X+obj.AbsoluteSize.X/2
        local cy=obj.AbsolutePosition.Y+obj.AbsoluteSize.Y/2
        pcall(function() obj:Activate() end)
        pcall(function() for _,c in pairs(getconnections(obj.MouseButton1Click)) do pcall(function() c:Fire() end) end end)
        pcall(function() for _,c in pairs(getconnections(obj.Activated)) do pcall(function() c:Fire() end) end end)
        VirtualInputManager:SendMouseButtonEvent(cx,cy,0,true,game,0)
        VirtualInputManager:SendMouseButtonEvent(cx,cy,0,false,game,0)
    end)
    return s
end

local function SF(...)
    local args={...} local cur=LocalPlayer:FindFirstChild("PlayerGui")
    for _,n in ipairs(args) do
        if not cur then return nil end
        local ok3,r=pcall(function() return cur:FindFirstChild(n) end)
        cur=ok3 and r or nil
    end
    return cur
end

local function FindDiffBtn(diff)
    local m={Easy="btn4",Normal="btn5",Hard="btn6"}
    local nm=m[diff or S.Difficulty] if not nm then return nil end
    local left=SF("PartyGui","Frame","createBg","left") if not left then return nil end
    local ok4,b=pcall(function() return left:FindFirstChild(nm) end)
    if ok4 and b and b:IsA("GuiObject") and b.Visible then return b end return nil
end

local function IsPartyOpen() return FindDiffBtn("Easy") or FindDiffBtn("Normal") or FindDiffBtn("Hard") end

local function FindCreateBtn()
    local r=SF("PartyGui","Frame","createBg","right") if not r then return nil end
    local ok5,b=pcall(function() return r:FindFirstChild("createBtn") end)
    if ok5 and b and b.Visible then return b end return nil
end

local function FindStartBtn()
    local r=SF("PartyGui","Frame","roomBg","right") if not r then return nil end
    local ok6,b=pcall(function() return r:FindFirstChild("StartBtn") end)
    if ok6 and b and b.Visible then return b end return nil
end

-- Again knop: 3 strategieën + volledige debug logging
local function FindAgainBtn()
    local pg=LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then Log("Again","Geen PlayerGui") return nil end

    -- Strategie 1: exacte pad (bg > againbtn)
    local ok1,b1=pcall(function()
        local pog=pg:FindFirstChild("PartyOverGui") if not pog then return nil end
        local bg=pog:FindFirstChild("Frame") and pog.Frame:FindFirstChild("bg") if not bg then return nil end
        return bg:FindFirstChild("againbtn")
    end)
    if ok1 and b1 then
        Log("Again","Pad 1 gevonden, Visible="..tostring(b1.Visible))
        if b1.Visible then return b1 end
    end

    -- Strategie 2: via againFrame
    local ok2,b2=pcall(function()
        local pog=pg:FindFirstChild("PartyOverGui") if not pog then return nil end
        local bg=pog.Frame and pog.Frame:FindFirstChild("bg") if not bg then return nil end
        local af=bg:FindFirstChild("againFrame") if not af then return nil end
        return af:FindFirstChild("againbtn") or af:FindFirstChildOfClass("TextButton")
    end)
    if ok2 and b2 and b2.Visible then Log("Again","Pad 2 (againFrame) gevonden") return b2 end

    -- Strategie 3: deep search op naam
    local ok3,b3=pcall(function()
        local pog=pg:FindFirstChild("PartyOverGui") if not pog then return nil end
        return pog:FindFirstChild("againbtn",true)
    end)
    if ok3 and b3 and b3.Visible then Log("Again","Deep search: "..b3:GetFullName()) return b3 end

    -- Debug: log alles wat er in PartyOverGui zit
    pcall(function()
        local pog=pg:FindFirstChild("PartyOverGui")
        if pog then
            Log("Again","PartyOverGui aanwezig, alle knoppen:")
            for _,c in pairs(pog:GetDescendants()) do
                if c:IsA("TextButton") or c:IsA("ImageButton") then
                    Log("Again","  "..c:GetFullName().." Visible="..tostring(c.Visible))
                end
            end
        else
            Log("Again","PartyOverGui NIET gevonden! PlayerGui heeft:")
            for _,c in pairs(pg:GetChildren()) do Log("Again","  "..c.Name) end
        end
    end)
    return nil
end

local function TryCreateParty()
    US("Wacht party menu...")
    local dl=tick()+15
    while tick()<dl do
        if not S.Running then return false end
        if IsPartyOpen() then Log("Party","Menu open") break end
        task.wait(0.2)
    end
    if not IsPartyOpen() then Warn("Party","Menu timeout") US("Party menu timeout") return false end

    US("Difficulty: "..S.Difficulty)
    local d=tick()+10
    while tick()<d do local b=FindDiffBtn(S.Difficulty) if b and ClickObj(b) then Log("Party","Diff OK") break end task.wait(0.1) end
    task.wait(0.4)

    US("Lobby aanmaken...")
    local c=tick()+10
    while tick()<c do local b=FindCreateBtn() if b and ClickObj(b) then Log("Party","Create OK") break end task.wait(0.1) end
    task.wait(1)

    US("Wacht Start...")
    local st=tick()+20
    while tick()<st do
        if not S.Running then return false end
        local b=FindStartBtn()
        if b then
            ClickObj(b) task.wait(1.5)
            if not FindStartBtn() then
                SetPhaseAndSave("DUNGEON")
                Log("Party","Start OK")
                US("Teleporteren...") return true
            end
        end
        task.wait(0.5)
    end
    Warn("Party","Start timeout") US("Start timeout") return false
end

local function GetChar()
    local char=LocalPlayer.Character if not char then return nil,nil,nil end
    return char,char:FindFirstChild("Humanoid"),char:FindFirstChild("HumanoidRootPart")
end

local function FindEnemy()
    local _,_,root=GetChar() if not root then return nil end
    local myPos=root.Position local closest,minDist=nil,S.AttackRange
    pcall(function()
        local st=Workspace:FindFirstChild("Stage") if not st then return end
        for _,map in pairs(st:GetChildren()) do
            if map.Name~="baseStage" then
                local f=map:FindFirstChild("monster") or map:FindFirstChild("Enemies")
                if f then
                    for _,mob in pairs(f:GetChildren()) do
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

local function Attack(target)
    pcall(function()
        if not target or not target:FindFirstChild("HumanoidRootPart") then return end
        local _,_,root=GetChar() if not root then return end
        VirtualUser:CaptureController()
        root.CFrame=CFrame.new(root.Position,Vector3.new(
            target.HumanoidRootPart.Position.X,root.Position.Y,target.HumanoidRootPart.Position.Z))
        VirtualUser:ClickButton1(Vector2.new(900,500))
    end)
end

local function Walk(targetPos)
    local char,hum,root=GetChar()
    if not char or not hum or not root then return end
    hum:MoveTo(targetPos)
    local stuckT=0 local lastPos=root.Position local timeout=tick()+300
    local lastEL=tick() local _,totalStart=CountEnemies() local killsBefore=0

    while tick()<timeout do
        if not S.Running then pcall(function() hum:MoveTo(root.Position) end) return end

        -- Stop meteen als eindscherm zichtbaar is (PartyOverGui)
        local endScreenVisible = false
        pcall(function()
            local pg  = LocalPlayer:FindFirstChild("PlayerGui")
            local pog = pg and pg:FindFirstChild("PartyOverGui")
            endScreenVisible = pog ~= nil and pog.Enabled == true
        end)
        if endScreenVisible then
            Log("Walk","PartyOverGui zichtbaar, stoppen met lopen")
            pcall(function() hum:MoveTo(root.Position) end)
            break
        end

        char,hum,root=GetChar()
        if not char or not hum or not root then task.wait(1) return end
        if (root.Position-targetPos).Magnitude<=4 then break end

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
                    char,hum,root=GetChar() if not char then return end
                    Attack(enemy)
                    pcall(function() if enemy.HumanoidRootPart then hum:MoveTo(enemy.HumanoidRootPart.Position) end end)
                    task.wait(0.1)
                until tick()>ct or not enemy or not enemy.Parent
                    or not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health<=0
                pcall(function() hum:MoveTo(targetPos) end)
            end
        end

        char,hum,root=GetChar()
        if root then
            if (root.Position-lastPos).Magnitude<0.5 then
                stuckT+=1
                if stuckT>20 then pcall(function() hum.Jump=true end) Log("Move","Jump") stuckT=0 end
            else stuckT=0 end
            lastPos=root.Position
        end
        task.wait(0.1)
    end
    local alive,total=CountEnemies()
    Log("Combat","Klaar | "..alive.."/"..total.." over") UE(alive,total)
end

-- ==============================================================================
-- FASES
-- ==============================================================================
local function RunDungeonPhase()
    SetPhaseAndSave("DUNGEON")
    Log("Dungeon","=== Run "..S.CurrentRun.." start ===")
    S.RunStartTime=tick() SaveState(S)

    WaitForWorldLoad(15)  if not S.Running then return end
    WaitForLoadingGui(30) if not S.Running then return end
    WaitForDoor()         if not S.Running then return end

    local alive,total=CountEnemies()
    Log("Dungeon","Enemies bij start: "..alive.."/"..total) UE(alive,total)

    US("Run "..S.CurrentRun.." | Lopen...")
    Walk(DungeonEnd)
    if not S.Running then return end

    -- Run tijd ophalen
    task.wait(0.5)
    local rtStr=GetRunTime()
    local rtSec=ParseTime(rtStr)
    if rtStr then
        UT(rtStr) Log("Dungeon","Tijd: "..rtStr)
        if rtSec and (not S.BestTime or rtSec<S.BestTime) then
            S.BestTime=rtSec SaveState(S) UB(S.BestTime)
            Log("Dungeon","Nieuwe best: "..rtStr)
        end
    else
        local e=math.floor(tick()-S.RunStartTime)
        local fb=string.format("%d:%02d",math.floor(e/60),e%60)
        UT(fb) Log("Dungeon","Tijd (fallback): "..fb)
    end

    S.CurrentRun+=1 SaveState(S) UR()
    local a2,t2=CountEnemies()
    Log("Dungeon","=== Run "..S.CurrentRun.." klaar | "..a2.."/"..t2.." over | Kills: "..S.TotalKills.." ===")

    if S.MaxRuns>0 and S.CurrentRun>S.MaxRuns then
        US("Klaar! "..S.MaxRuns.." runs") S.Running=false SaveState(S)
        SetPhaseAndSave("IDLE") UE(nil,nil) return
    end

    -- Wacht op Again knop — langere timeout + blijf proberen
    US("Wacht Opnieuw...")
    Log("Dungeon","Wachten op Again knop (max 40s)...")
    local dl=tick()+40
    while tick()<dl do
        if not S.Running then return end
        local b=FindAgainBtn()
        if b then
            Log("Dungeon","Again knop gevonden! Klikken...")
            ClickObj(b)
            task.wait(1)
            -- Controleer of we geteleporteerd zijn
            if not FindAgainBtn() then
                SetPhaseAndSave("DUNGEON")
                Log("Dungeon","Teleport bezig, Phase=DUNGEON bewaard")
                US("Teleporteren...") return
            end
            -- Nog steeds zichtbaar, opnieuw klikken
            Log("Dungeon","Nog niet geteleporteerd, opnieuw klikken...")
        end
        task.wait(0.5)
    end
    Warn("Dungeon","Again timeout 40s") US("Again knop niet gevonden")
    S.Running=false SaveState(S) SetPhaseAndSave("IDLE")
end

local function RunLobbyPhase()
    SetPhaseAndSave("LOBBY") Log("Lobby","Start")
    WaitForWorldLoad(15) if not S.Running then return end
    US("Lobby route...")
    local _,hum,_=GetChar()
    if not hum then Warn("Lobby","Geen karakter") S.Running=false SaveState(S) return end
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
    SetPhaseAndSave("PARTY") US("Party aanmaken...")
    local ok9=TryCreateParty()
    if not ok9 then Warn("Lobby","Party mislukt") US("Party mislukt") S.Running=false SaveState(S) SetPhaseAndSave("IDLE") end
end

local function AutoStart()
    if not S.Running then return end
    UR() UE(nil,nil)
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
    SaveState(S) SetPhaseAndSave("LOBBY")
    UR() UK() UE(nil,nil) UT(nil) Log("Control","START")
    task.spawn(AutoStart)
end)

BtnStop.MouseButton1Click:Connect(function()
    S.Running=false SaveState(S) SetPhaseAndSave("IDLE") UE(nil,nil)
    pcall(function() local _,hum,root=GetChar() if hum and root then hum:MoveTo(root.Position) end end)
    US("Gestopt") Log("Control","STOP")
end)

BtnParty.MouseButton1Click:Connect(function()
    if not S.Running then Log("Control","Handmatige party") task.spawn(TryCreateParty) end
end)

-- ==============================================================================
-- BOOT
-- ==============================================================================
US("Idle") UR() UP(S.Phase) UK()
if S.BestTime then UB(S.BestTime) end

if S.Running then
    Log("Boot","Hervatten na teleport (Phase="..S.Phase..")")
    task.spawn(AutoStart)
else
    Log("Boot","Fresh start")
end
