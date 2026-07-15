-- The Revenant: Sunrisen GUI (Mobile Version)
-- Made using Rayfield V2 Library

if _G.RevenantGui_Kill then
    _G.RevenantGui_Kill = true
    task.wait(0.2)
end
_G.RevenantGui_Kill = false
local function isKilled() return _G.RevenantGui_Kill end

-- ==================== RAYFIELD ====================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "The Revenant: Sunrisen GUI (Mobile Version)",
    Icon = 0,
    LoadingTitle = "Loading Revenant GUI",
    LoadingSubtitle = "Mobile Version",
    Theme = "Default",

    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,

    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RevenantSunrisenMobile",
        FileName = "Config"
    },

    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },

    KeySystem = false,
    KeySettings = {
        Title = "Untitled",
        Subtitle = "Key System",
        Note = "No method of obtaining the key is provided",
        FileName = "Key",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"Hello"}
    }
})

-- ==================== TAB ICONS ====================
local MainTab = Window:CreateTab("Main", "swords")
local ScrapsTab = Window:CreateTab("Scraps", "package")
local SettingsTab = Window:CreateTab("Settings", "cog")

-- ==================== GLOBAL NOTIFICATION DURATION ====================
local notificationDuration = 3

local function Notify(Title, Content, Duration)
    local dur = Duration or notificationDuration
    Rayfield:Notify({
        Title = Title,
        Content = Content,
        Duration = dur
    })
end

-- ==================== SERVICES, STATE, FUNCTIONS ====================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NPC_FOLDER_NAME = "NPCs"
local HEAD_SIZE_MAX = 6.2
local AMMO_LOOP_DELAY = 0.3

local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient
}

local State = {
    originalSizes = {},
    selectionBoxes = {},
    hitboxConns = {},
    hitboxEnabled = false,
    hitboxSize = HEAD_SIZE_MAX,

    espHighlights = {},
    espBillboards = {},
    distanceConn = nil,
    espEnabled = false,

    shedESPActive = false,
    shedHighlights = {},
    shedBillboards = {},
    shedChildAddedConn = nil,
    shedChildRemovedConn = nil,

    airdropESPActive = false,
    airdropHighlights = {},
    airdropBillboards = {},
    airdropChildAddedConn = nil,
    airdropChildRemovedConn = nil,

    blackMarketESPActive = false,
    blackMarketHighlights = {},
    blackMarketBillboards = {},
    blackMarketDescAddedConn = nil,
    blackMarketDescRemovedConn = nil,

    structNotifierActive = false,
    structNotifierConnections = {},

    ammoLoopRunning = false,
    ammoLoopThread = nil,
    ammoLoopActive = false,

    scrapESPActive = false,
    scrapHighlights = {},
    scrapBillboards = {},
    scrapAddedConn = nil,
    scrapRemovedConn = nil,
    scrapESPTypes = { Common = true, Shiny = true, Golden = true, Cursed = true },

    scrapTPActive = false,
    scrapTPThread = nil,
    scrapTPStop = false,
    scrapTPTypes = { Common = false, Shiny = false, Golden = true },

    barbedWireActive = false,
    hiddenBarbedWire = {},
    barbedWireChildConn = nil,

    ragdollActive = false,
    hiddenRagdoll = {},
    ragdollChildConn = nil,

    fullbrightActive = false,
    fullbrightConnection = nil,
    originalLighting = originalLighting,

    instantProxActive = false,
    originalPromptDurations = {},
    instantProxAddedConn = nil,

    orbitActive = false,
    orbitRadius = 80,
    orbitSpeed = 0.1,
    orbitAngle = 0,
    orbitConn = nil,

    childAddConn = nil,
    childRemConn = nil,

    destroying = false
}

-- ==================== FORCE CLEANUP ON START ====================
local function cleanupAll()
    for _, model in ipairs(State.hitboxConns) do
        for _, c in ipairs(model) do pcall(c.Disconnect) end
    end
    State.hitboxConns = {}
    for part, sz in pairs(State.originalSizes) do
        if part and part:IsA("BasePart") then
            part.Size = sz
            part.CanCollide = true
        end
    end
    State.originalSizes = {}
    for _, box in pairs(State.selectionBoxes) do pcall(box.Destroy, box) end
    State.selectionBoxes = {}

    for _, hl in pairs(State.espHighlights) do pcall(hl.Destroy, hl) end
    State.espHighlights = {}
    for _, bb in pairs(State.espBillboards) do pcall(bb.Destroy, bb) end
    State.espBillboards = {}
    if State.distanceConn then pcall(State.distanceConn.Disconnect, State.distanceConn); State.distanceConn = nil end
end
cleanupAll()
State.hitboxEnabled = false
State.espEnabled = false

-- ==================== HELPERS ====================
local function getHead(model)
    return model and model:FindFirstChild("Head")
end

local function getNPCFolder()
    if not Workspace then return nil end
    local folder = Workspace:FindFirstChild(NPC_FOLDER_NAME)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = NPC_FOLDER_NAME
        folder.Parent = Workspace
    end
    return folder
end
local npcFolder = getNPCFolder()
if not npcFolder then
    warn("Failed to create NPC folder – workspace not ready")
end

local function getAllNPCs()
    local npcs = {}
    if not npcFolder then return npcs end
    for _, child in ipairs(npcFolder:GetChildren()) do
        if child:FindFirstChild("Head") then
            table.insert(npcs, child)
        end
    end
    return npcs
end

local function getRootPart(npc)
    return npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head"))
end

local function findNearestNPC()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pos = hrp.Position
    local best, bestDist = nil, math.huge
    for _, npc in ipairs(getAllNPCs()) do
        local root = getRootPart(npc)
        if root and root:IsA("BasePart") then
            local d = (root.Position - pos).Magnitude
            if d < bestDist then
                bestDist = d
                best = npc
            end
        end
    end
    return best
end

local function stabilizeCharacter()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if hrp then
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end
    if hum then
        hum.AutoRotate = false
    end
end

local function restoreAutoRotate()
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.AutoRotate = true
        end
    end
end

-- ==================== HITBOX FUNCTIONS ====================
local function applyHitboxPart(part)
    if not part or not part:IsA("BasePart") then return end
    if not State.originalSizes[part] then State.originalSizes[part] = part.Size end
    part.Size = Vector3.new(State.hitboxSize, State.hitboxSize, State.hitboxSize)
    part.CanCollide = false
    if not State.selectionBoxes[part] then
        local box = Instance.new("SelectionBox")
        box.Color3 = Color3.fromRGB(0, 255, 0)
        box.LineThickness = 0.05
        box.Transparency = 0.3
        box.Adornee = part
        box.Parent = part
        State.selectionBoxes[part] = box
    end
end

local function revertHitboxPart(part)
    if not part then return end
    if State.originalSizes[part] then
        part.Size = State.originalSizes[part]
        State.originalSizes[part] = nil
    end
    part.CanCollide = true
    if State.selectionBoxes[part] then
        State.selectionBoxes[part]:Destroy()
        State.selectionBoxes[part] = nil
    end
end

local function applyHitboxToModel(model)
    if not model or not model:IsA("Model") then return end
    if State.hitboxConns[model] then
        for _, c in ipairs(State.hitboxConns[model]) do pcall(c.Disconnect) end
        State.hitboxConns[model] = nil
    end
    local conns = {}
    local head = getHead(model)
    if head then applyHitboxPart(head) end
    local childConn = model.ChildAdded:Connect(function(child)
        if child.Name == "Head" and child:IsA("BasePart") then applyHitboxPart(child) end
    end)
    table.insert(conns, childConn)
    local remConn = model.ChildRemoved:Connect(function(child)
        if child.Name == "Head" and child:IsA("BasePart") then revertHitboxPart(child) end
    end)
    table.insert(conns, remConn)
    local ancesConn = model.AncestryChanged:Connect(function()
        if not model.Parent then
            for part, _ in pairs(State.originalSizes) do
                if part and part:IsDescendantOf(model) then revertHitboxPart(part) end
            end
            if State.hitboxConns[model] then
                for _, c in ipairs(State.hitboxConns[model]) do pcall(c.Disconnect) end
                State.hitboxConns[model] = nil
            end
        end
    end)
    table.insert(conns, ancesConn)
    State.hitboxConns[model] = conns
end

local function removeHitboxFromModel(model)
    if not model then return end
    for part, _ in pairs(State.originalSizes) do
        if part and part:IsDescendantOf(model) then revertHitboxPart(part) end
    end
    if State.hitboxConns[model] then
        for _, c in ipairs(State.hitboxConns[model]) do pcall(c.Disconnect) end
        State.hitboxConns[model] = nil
    end
end

local function applyHitboxAll()
    if not State.hitboxEnabled then return end
    if not npcFolder then return end
    for _, m in ipairs(npcFolder:GetChildren()) do
        if m:IsA("Model") then applyHitboxToModel(m) end
    end
end

local function removeHitboxAll()
    for model, _ in pairs(State.hitboxConns) do removeHitboxFromModel(model) end
    State.hitboxConns = {}
    for part, _ in pairs(State.originalSizes) do revertHitboxPart(part) end
    State.originalSizes = {}
    for _, box in pairs(State.selectionBoxes) do box:Destroy() end
    State.selectionBoxes = {}
end

-- ==================== NPC ESP FUNCTIONS ====================
local function createESP(model)
    if not model or not model:IsA("Model") or State.espHighlights[model] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.OutlineColor = Color3.fromRGB(255, 255, 0)
    hl.FillTransparency = 0.3
    hl.OutlineTransparency = 0
    hl.Adornee = model
    hl.Parent = model
    State.espHighlights[model] = hl

    local head = getHead(model)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.Text = "0 m"
    lbl.Parent = bb
    bb.Parent = head or model
    State.espBillboards[model] = bb
end

local function removeESP(model)
    if not model then return end
    if State.espHighlights[model] then
        State.espHighlights[model]:Destroy()
        State.espHighlights[model] = nil
    end
    if State.espBillboards[model] then
        State.espBillboards[model]:Destroy()
        State.espBillboards[model] = nil
    end
end

local function applyESPAll()
    if not State.espEnabled then return end
    if not npcFolder then return end
    for _, m in ipairs(npcFolder:GetChildren()) do
        if m:IsA("Model") then createESP(m) end
    end
    if not State.distanceConn then
        State.distanceConn = RunService.Heartbeat:Connect(function()
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for model, bb in pairs(State.espBillboards) do
                if bb and bb.Parent then
                    local head = getHead(model) or model:FindFirstChild("HumanoidRootPart")
                    if head then
                        local dist = (hrp.Position - head.Position).Magnitude
                        local rounded = math.floor(dist)
                        local lbl = bb:FindFirstChild("TextLabel")
                        if lbl then
                            lbl.Text = rounded .. " m"
                            lbl.TextColor3 = (rounded <= 75) and Color3.fromRGB(255,0,0) or
                                (rounded <= 175) and Color3.fromRGB(255,165,0) or
                                Color3.fromRGB(0,255,0)
                            local newSize = math.clamp(10 + math.floor(140 / (dist + 10)), 10, 24)
                            lbl.TextSize = newSize
                        end
                    end
                end
            end
        end)
    end
end

local function removeESPAll()
    for model, hl in pairs(State.espHighlights) do
        if hl then hl:Destroy() end
    end
    State.espHighlights = {}
    for model, bb in pairs(State.espBillboards) do
        if bb then bb:Destroy() end
    end
    State.espBillboards = {}
    if State.distanceConn then
        State.distanceConn:Disconnect()
        State.distanceConn = nil
    end
end

-- ==================== AMMO ====================
local function getEquippedTool()
    local char = player.Character
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") then return v end
        end
    end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") then return v end
        end
    end
    return nil
end

local function giveAmmoOnce()
    local tool = getEquippedTool()
    if not tool then return end
    local signal = tool:FindFirstChild("Signal")
    if signal and signal:IsA("RemoteEvent") then
        pcall(firesignal, signal.OnClientEvent, "HandleAmmo", { Type = "ToMax" })
    end
end

local function startAmmoLoop()
    if State.ammoLoopRunning then return end
    State.ammoLoopRunning = true
    State.ammoLoopActive = true
    State.ammoLoopThread = task.spawn(function()
        while State.ammoLoopActive do
            giveAmmoOnce()
            task.wait(AMMO_LOOP_DELAY)
        end
        State.ammoLoopRunning = false
    end)
end

local function stopAmmoLoop()
    State.ammoLoopActive = false
    State.ammoLoopRunning = false
    if State.ammoLoopThread then State.ammoLoopThread = nil end
end

-- ==================== INFINITE STAMINA ====================
local function getInfStamina()
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then
        Notify("Error", "Events folder not found!")
        return
    end
    local remoteEvent = events:FindFirstChild("I__NFSTA_AXDLOL")
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        pcall(firesignal, remoteEvent.OnClientEvent, true, math.huge)
        Notify("Stamina", "Infinite Stamina activated!")
    else
        Notify("Error", "Stamina remote not found!")
    end
end

-- ==================== NO RECOIL ====================
local recoilModulePath = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("GunSystem") and ReplicatedStorage.Modules.GunSystem:FindFirstChild("Shared") and ReplicatedStorage.Modules.GunSystem.Shared:FindFirstChild("Recoil")
local Recoil = recoilModulePath and require(recoilModulePath)
local originalAccelerate = nil

local function enableNoRecoil()
    if not Recoil then
        Notify("Error", "Recoil module not found!")
        return
    end
    if not originalAccelerate then
        originalAccelerate = Recoil.Accelerate
        Recoil.Accelerate = function(self, ...)
            return {}
        end
        Notify("No Recoil", "Enabled")
    end
end

local function disableNoRecoil()
    if Recoil and originalAccelerate then
        Recoil.Accelerate = originalAccelerate
        originalAccelerate = nil
        Notify("No Recoil", "Disabled")
    end
end

-- ==================== SHED ESP ====================
local function onShedAdded(model)
    if not model:IsA("Model") or model.Name ~= "Shed" then return end
    if State.shedHighlights[model] then return end
    local adornPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
    if not adornPart then return end

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(0, 255, 255)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.3
    hl.OutlineTransparency = 0
    hl.Adornee = model
    hl.Parent = model
    State.shedHighlights[model] = hl

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 80, 0, 20)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "SHED"
    lbl.TextColor3 = Color3.fromRGB(0, 255, 255)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.Parent = bb
    bb.Parent = adornPart
    State.shedBillboards[model] = bb
end
local function onShedRemoved(model)
    if not model:IsA("Model") or model.Name ~= "Shed" then return end
    if State.shedHighlights[model] then State.shedHighlights[model]:Destroy(); State.shedHighlights[model] = nil end
    if State.shedBillboards[model] then State.shedBillboards[model]:Destroy(); State.shedBillboards[model] = nil end
end
local function startShedESP()
    if State.shedESPActive then return end
    State.shedESPActive = true
    State.shedChildAddedConn = Workspace.DescendantAdded:Connect(onShedAdded)
    State.shedChildRemovedConn = Workspace.DescendantRemoving:Connect(onShedRemoved)
    for _, child in ipairs(Workspace:GetDescendants()) do onShedAdded(child) end
end
local function stopShedESP()
    State.shedESPActive = false
    if State.shedChildAddedConn then pcall(State.shedChildAddedConn.Disconnect, State.shedChildAddedConn); State.shedChildAddedConn = nil end
    if State.shedChildRemovedConn then pcall(State.shedChildRemovedConn.Disconnect, State.shedChildRemovedConn); State.shedChildRemovedConn = nil end
    for model, hl in pairs(State.shedHighlights) do hl:Destroy() end
    for model, bb in pairs(State.shedBillboards) do bb:Destroy() end
    State.shedHighlights, State.shedBillboards = {}, {}
end

-- ==================== AIRDROP ESP ====================
local function onAirdropAdded(model)
    if not model:IsA("Model") or model.Name ~= "Airdrop" then return end
    if State.airdropHighlights[model] then return end
    local adornPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
    if not adornPart then return end

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 0, 255)
    hl.OutlineColor = Color3.fromRGB(255, 255, 0)
    hl.FillTransparency = 0.2
    hl.OutlineTransparency = 0
    hl.Adornee = model
    hl.Parent = model
    State.airdropHighlights[model] = hl

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 90, 0, 20)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "AIRDROP"
    lbl.TextColor3 = Color3.fromRGB(255, 0, 255)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.Parent = bb
    bb.Parent = adornPart
    State.airdropBillboards[model] = bb
end
local function onAirdropRemoved(model)
    if not model:IsA("Model") or model.Name ~= "Airdrop" then return end
    if State.airdropHighlights[model] then State.airdropHighlights[model]:Destroy(); State.airdropHighlights[model] = nil end
    if State.airdropBillboards[model] then State.airdropBillboards[model]:Destroy(); State.airdropBillboards[model] = nil end
end
local function startAirdropESP()
    if State.airdropESPActive then return end
    State.airdropESPActive = true
    State.airdropChildAddedConn = Workspace.DescendantAdded:Connect(onAirdropAdded)
    State.airdropChildRemovedConn = Workspace.DescendantRemoving:Connect(onAirdropRemoved)
    for _, child in ipairs(Workspace:GetDescendants()) do onAirdropAdded(child) end
end
local function stopAirdropESP()
    State.airdropESPActive = false
    if State.airdropChildAddedConn then pcall(State.airdropChildAddedConn.Disconnect, State.airdropChildAddedConn); State.airdropChildAddedConn = nil end
    if State.airdropChildRemovedConn then pcall(State.airdropChildRemovedConn.Disconnect, State.airdropChildRemovedConn); State.airdropChildRemovedConn = nil end
    for model, hl in pairs(State.airdropHighlights) do hl:Destroy() end
    for model, bb in pairs(State.airdropBillboards) do bb:Destroy() end
    State.airdropHighlights, State.airdropBillboards = {}, {}
end

-- ==================== BLACK MARKET ESP ====================
local function isBlackMarket(instance)
    if not instance or not instance:IsA("Model") then return false end
    if instance.Name ~= "BlackMarket" then return false end
    local parent = instance.Parent
    if not parent or parent.Name ~= "Structures" then return false end
    parent = parent.Parent
    if not parent or parent.Name ~= "MAIN" then return false end
    parent = parent.Parent
    if not parent or parent.Name ~= "MAP" then return false end
    parent = parent.Parent
    if not parent or parent ~= Workspace then return false end
    return true
end
local function applyBlackMarketESP(instance)
    if not isBlackMarket(instance) or State.blackMarketHighlights[instance] then return end
    local adornPart = instance:FindFirstChild("HumanoidRootPart") or instance.PrimaryPart or instance:FindFirstChild("Head") or instance:FindFirstChildWhichIsA("BasePart")
    if not adornPart then return end

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 255, 0)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.2
    hl.OutlineTransparency = 0
    hl.Adornee = instance
    hl.Parent = instance
    State.blackMarketHighlights[instance] = hl

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 20)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "BLACK MARKET"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 0)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.Parent = bb
    bb.Parent = adornPart
    State.blackMarketBillboards[instance] = bb
end
local function removeBlackMarketESP(instance)
    if State.blackMarketHighlights[instance] then State.blackMarketHighlights[instance]:Destroy(); State.blackMarketHighlights[instance] = nil end
    if State.blackMarketBillboards[instance] then State.blackMarketBillboards[instance]:Destroy(); State.blackMarketBillboards[instance] = nil end
end
local function startBlackMarketESP()
    if State.blackMarketESPActive then return end
    State.blackMarketESPActive = true
    for _, child in ipairs(Workspace:GetDescendants()) do
        if isBlackMarket(child) then applyBlackMarketESP(child) end
    end
    State.blackMarketDescAddedConn = Workspace.DescendantAdded:Connect(function(desc)
        if isBlackMarket(desc) then applyBlackMarketESP(desc) end
    end)
    State.blackMarketDescRemovedConn = Workspace.DescendantRemoving:Connect(function(desc)
        if isBlackMarket(desc) then removeBlackMarketESP(desc) end
    end)
end
local function stopBlackMarketESP()
    State.blackMarketESPActive = false
    if State.blackMarketDescAddedConn then pcall(State.blackMarketDescAddedConn.Disconnect, State.blackMarketDescAddedConn); State.blackMarketDescAddedConn = nil end
    if State.blackMarketDescRemovedConn then pcall(State.blackMarketDescRemovedConn.Disconnect, State.blackMarketDescRemovedConn); State.blackMarketDescRemovedConn = nil end
    for instance, hl in pairs(State.blackMarketHighlights) do hl:Destroy() end
    for instance, bb in pairs(State.blackMarketBillboards) do bb:Destroy() end
    State.blackMarketHighlights, State.blackMarketBillboards = {}, {}
end

-- ==================== STRUCTURE NOTIFIER ====================
local function notifyShed(model)
    if model.Name == "Shed" and model:IsA("Model") then
        Notify("Structure", "Shed spawned!")
    end
end
local function notifyAirdrop(model)
    if model.Name == "Airdrop" and model:IsA("Model") then
        Notify("Structure", "Airdrop spawned!")
    end
end
local function notifyBlackMarket(instance)
    if isBlackMarket(instance) then
        Notify("Structure", "Black Market spawned!")
    end
end
local function notifyCursedScrap(scrapObject)
    if scrapObject and scrapObject:IsA("Model") then
        local prompt = scrapObject:FindFirstChild("ProximityPrompt", true)
        if prompt and prompt:IsA("ProximityPrompt") then
            local typ = getScrapType(prompt)
            if typ == "Cursed" then
                Notify("Scrap", "Cursed Scrap spawned!")
            end
        end
    end
end

local function startStructNotifier()
    if State.structNotifierActive then return end
    State.structNotifierActive = true
    local shedConn = Workspace.DescendantAdded:Connect(notifyShed)
    local airdropConn = Workspace.DescendantAdded:Connect(notifyAirdrop)
    local blackMarketConn = Workspace.DescendantAdded:Connect(function(desc)
        if isBlackMarket(desc) then
            Notify("Structure", "Black Market spawned!")
        end
    end)
    local scrapFolder = getScrapFolder()
    local scrapConn
    if scrapFolder then
        scrapConn = scrapFolder.DescendantAdded:Connect(function(desc)
            if desc:IsA("ProximityPrompt") then
                local parentModel = desc.Parent and desc.Parent.Parent
                if parentModel then
                    notifyCursedScrap(parentModel)
                end
            end
        end)
    end
    State.structNotifierConnections = { shedConn, airdropConn, blackMarketConn, scrapConn }
    for _, child in ipairs(Workspace:GetDescendants()) do
        notifyShed(child)
        notifyAirdrop(child)
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if isBlackMarket(desc) then
            Notify("Structure", "Black Market spawned!")
        end
    end
    if scrapFolder then
        for _, prompt in ipairs(scrapFolder:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") then
                local parentModel = prompt.Parent and prompt.Parent.Parent
                if parentModel then
                    notifyCursedScrap(parentModel)
                end
            end
        end
    end
end

local function stopStructNotifier()
    State.structNotifierActive = false
    for _, conn in ipairs(State.structNotifierConnections) do
        if conn then pcall(conn.Disconnect, conn) end
    end
    State.structNotifierConnections = {}
end

-- ==================== BARBED WIRE REMOVER ====================
local function removeBarbedWirePart(part)
    if not part or not part:IsA("MeshPart") then return end
    table.insert(State.hiddenBarbedWire, { part = part, parent = part.Parent })
    part.Parent = nil
end
local function restoreBarbedWireParts()
    for _, data in ipairs(State.hiddenBarbedWire) do
        local part = data.part
        local parent = data.parent
        if part and parent then
            part.Parent = parent
        end
    end
    State.hiddenBarbedWire = {}
end
local function applyBarbedWireRemoval()
    local folder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("BarbedWire")
    if not folder then return end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("MeshPart") then
            removeBarbedWirePart(child)
        end
    end
end
local function startBarbedWireRemover()
    if State.barbedWireActive then return end
    State.barbedWireActive = true
    applyBarbedWireRemoval()
    local folder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("BarbedWire")
    if folder then
        State.barbedWireChildConn = folder.ChildAdded:Connect(function(child)
            if State.barbedWireActive and child:IsA("MeshPart") then
                removeBarbedWirePart(child)
            end
        end)
    end
end
local function stopBarbedWireRemover()
    State.barbedWireActive = false
    if State.barbedWireChildConn then
        pcall(State.barbedWireChildConn.Disconnect, State.barbedWireChildConn)
        State.barbedWireChildConn = nil
    end
    restoreBarbedWireParts()
end

-- ==================== RAGDOLL REMOVER ====================
local function removeRagdollPart(part)
    if not part or not part:IsA("BasePart") or part.Name ~= "RagdollPart" then return end
    table.insert(State.hiddenRagdoll, { part = part, parent = part.Parent })
    part.Parent = nil
end
local function restoreRagdollParts()
    for _, data in ipairs(State.hiddenRagdoll) do
        local part = data.part
        local parent = data.parent
        if part and parent then
            part.Parent = parent
        end
    end
    State.hiddenRagdoll = {}
end
local function applyRagdollRemoval()
    local folder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("RagdollParts")
    if not folder then return end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") and child.Name == "RagdollPart" then
            removeRagdollPart(child)
        end
    end
end
local function startRagdollRemover()
    if State.ragdollActive then return end
    State.ragdollActive = true
    applyRagdollRemoval()
    local folder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("RagdollParts")
    if folder then
        State.ragdollChildConn = folder.ChildAdded:Connect(function(child)
            if State.ragdollActive and child:IsA("BasePart") and child.Name == "RagdollPart" then
                removeRagdollPart(child)
            end
        end)
    end
end
local function stopRagdollRemover()
    State.ragdollActive = false
    if State.ragdollChildConn then
        pcall(State.ragdollChildConn.Disconnect, State.ragdollChildConn)
        State.ragdollChildConn = nil
    end
    restoreRagdollParts()
end

-- ==================== FULLBRIGHT ====================
local function applyFullbright()
    if State.fullbrightActive then
        Lighting.Brightness = 1
        Lighting.ClockTime = 12
        Lighting.FogEnd = 786543
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    else
        Lighting.Brightness = State.originalLighting.Brightness or 1
        Lighting.ClockTime = State.originalLighting.ClockTime or 12
        Lighting.FogEnd = State.originalLighting.FogEnd or 786543
        Lighting.GlobalShadows = State.originalLighting.GlobalShadows ~= nil and State.originalLighting.GlobalShadows or false
        Lighting.Ambient = State.originalLighting.Ambient or Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = State.originalLighting.OutdoorAmbient or Color3.fromRGB(178, 178, 178)
    end
end

local function startFullbright()
    if State.fullbrightConnection then return end
    State.originalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient
    }
    State.fullbrightActive = true
    State.fullbrightConnection = RunService.Heartbeat:Connect(applyFullbright)
    applyFullbright()
end

local function stopFullbright()
    State.fullbrightActive = false
    if State.fullbrightConnection then
        State.fullbrightConnection:Disconnect()
        State.fullbrightConnection = nil
    end
    applyFullbright()
end

-- ==================== INSTANT PROX. PROMPTS ====================
local INSTANT_PROX_DURATION = 0
local EXCEPTION_PROX_DURATION = 0.0001

local function isPowerStationPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    local core = prompt.Parent
    if not core or core.Name ~= "Core" then return false end
    local powerStation = core.Parent
    if not powerStation or powerStation.Name ~= "PowerStation" then return false end
    local structures = powerStation.Parent
    if not structures or structures.Name ~= "Structures" then return false end
    local main = structures.Parent
    if not main or main.Name ~= "MAIN" then return false end
    local map = main.Parent
    if not map or map.Name ~= "MAP" then return false end
    local ws = map.Parent
    if ws ~= Workspace then return false end
    return true
end

local function setPromptDuration(prompt, duration)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    if not State.originalPromptDurations[prompt] then
        State.originalPromptDurations[prompt] = prompt.HoldDuration
    end
    prompt.HoldDuration = duration
end

local function applyInstantProx()
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            if State.instantProxActive then
                local duration = INSTANT_PROX_DURATION
                if isPowerStationPrompt(prompt) then
                    duration = EXCEPTION_PROX_DURATION
                end
                setPromptDuration(prompt, duration)
            else
                if State.originalPromptDurations[prompt] then
                    prompt.HoldDuration = State.originalPromptDurations[prompt]
                    State.originalPromptDurations[prompt] = nil
                end
            end
        end
    end
end

local function startInstantProx()
    if State.instantProxActive then return end
    State.instantProxActive = true
    applyInstantProx()
    State.instantProxAddedConn = Workspace.DescendantAdded:Connect(function(desc)
        if State.instantProxActive and desc:IsA("ProximityPrompt") then
            local duration = INSTANT_PROX_DURATION
            if isPowerStationPrompt(desc) then
                duration = EXCEPTION_PROX_DURATION
            end
            setPromptDuration(desc, duration)
        end
    end)
end

local function stopInstantProx()
    State.instantProxActive = false
    if State.instantProxAddedConn then
        State.instantProxAddedConn:Disconnect()
        State.instantProxAddedConn = nil
    end
    applyInstantProx()
end

-- ==================== ORBIT SPIN ====================
local function startOrbit()
    if State.orbitConn then return end
    State.orbitActive = true
    State.orbitAngle = 0
    State.orbitConn = RunService.Stepped:Connect(function(_, dt)
        if not State.orbitActive then return end
        dt = math.min(dt, 0.1)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local npc = findNearestNPC()
        if not npc then return end
        local root = getRootPart(npc)
        if not root then return end
        State.orbitAngle = State.orbitAngle + State.orbitSpeed * dt
        local offset = Vector3.new(math.cos(State.orbitAngle) * State.orbitRadius, 0, math.sin(State.orbitAngle) * State.orbitRadius)
        hrp.CFrame = CFrame.new(root.Position) * CFrame.new(offset)
        stabilizeCharacter()
    end)
end
local function stopOrbit()
    State.orbitActive = false
    if State.orbitConn then
        State.orbitConn:Disconnect()
        State.orbitConn = nil
    end
    restoreAutoRotate()
end

-- ==================== SCRAP HELPERS ====================
local function getScrapType(prompt)
    local text = prompt.ObjectText or ""
    if text:find("Common", 1, true) then return "Common" end
    if text:find("Shiny", 1, true) then return "Shiny" end
    if text:find("Golden", 1, true) then return "Golden" end
    if text:find("Cursed", 1, true) then return "Cursed" end
    return nil
end
local function getScrapColor(scrapType)
    if scrapType == "Common" then return Color3.fromRGB(139, 69, 19)
    elseif scrapType == "Shiny" then return Color3.fromRGB(192, 192, 192)
    elseif scrapType == "Golden" then return Color3.fromRGB(255, 215, 0)
    elseif scrapType == "Cursed" then return Color3.fromRGB(255, 0, 0)
    end
    return Color3.fromRGB(255,255,255)
end
local function getBasePartFromScrap(scrapObject)
    if not scrapObject then return nil end
    if scrapObject:IsA("BasePart") and scrapObject.Name == "Base" then
        return scrapObject
    end
    local base = scrapObject:FindFirstChild("Base")
    if base and base:IsA("BasePart") then return base end
    for _, child in ipairs(scrapObject:GetDescendants()) do
        if child.Name == "Base" and child:IsA("BasePart") then
            return child
        end
    end
    return nil
end
local function shouldShowScrapType(scrapType)
    if scrapType == "Common" then return State.scrapESPTypes.Common
    elseif scrapType == "Shiny" then return State.scrapESPTypes.Shiny
    elseif scrapType == "Golden" then return State.scrapESPTypes.Golden
    elseif scrapType == "Cursed" then return State.scrapESPTypes.Cursed
    end
    return false
end
local function shouldTPType(scrapType)
    if scrapType == "Cursed" then return false end
    if scrapType == "Common" then return State.scrapTPTypes.Common
    elseif scrapType == "Shiny" then return State.scrapTPTypes.Shiny
    elseif scrapType == "Golden" then return State.scrapTPTypes.Golden
    end
    return false
end
local function getScrapFolder()
    return Workspace:FindFirstChild("MAP") and Workspace.MAP:FindFirstChild("Scraps")
end

local function getScrapCount()
    local coreGui = player:FindFirstChild("PlayerGui")
    if not coreGui then return nil, nil end
    local statsFrame = coreGui:FindFirstChild("CoreGUI") and coreGui.CoreGUI:FindFirstChild("StatsFrame")
    if not statsFrame then return nil, nil end
    local frame = statsFrame:FindFirstChild("Frame")
    if not frame then return nil, nil end
    local topMenu = frame:FindFirstChild("TopMenu")
    if not topMenu then return nil, nil end
    local holder = topMenu:FindFirstChild("Holder")
    if not holder then return nil, nil end
    local scraps = holder:FindFirstChild("Scraps")
    if not scraps then return nil, nil end
    local currentLabel = scraps:FindFirstChild("Current")
    if not currentLabel or not currentLabel:IsA("TextLabel") then return nil, nil end
    local text = currentLabel.Text
    local parts = string.split(text, "/")
    if #parts ~= 2 then return nil, nil end
    local current = tonumber(parts[1])
    local max = tonumber(parts[2])
    return current, max
end

-- ==================== SCRAP ESP ====================
local function applyScrapESP(scrapObject)
    if not scrapObject or State.scrapHighlights[scrapObject] then return end
    local prompt = scrapObject:FindFirstChild("ProximityPrompt", true)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    local scrapType = getScrapType(prompt)
    if not scrapType or not shouldShowScrapType(scrapType) then return end
    local base = getBasePartFromScrap(scrapObject)
    if not base then return end
    local color = getScrapColor(scrapType)

    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.2
    hl.OutlineTransparency = 0
    hl.Adornee = base
    hl.Parent = base
    State.scrapHighlights[scrapObject] = hl

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 60, 0, 16)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = scrapType
    lbl.TextColor3 = color
    lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 8
    lbl.Parent = bb
    bb.Parent = base
    State.scrapBillboards[scrapObject] = bb
end
local function removeScrapESP(scrapObject)
    if State.scrapHighlights[scrapObject] then
        State.scrapHighlights[scrapObject]:Destroy()
        State.scrapHighlights[scrapObject] = nil
    end
    if State.scrapBillboards[scrapObject] then
        State.scrapBillboards[scrapObject]:Destroy()
        State.scrapBillboards[scrapObject] = nil
    end
end
local function refreshScrapESP()
    local folder = getScrapFolder()
    if not folder then return end
    for obj, hl in pairs(State.scrapHighlights) do hl:Destroy() end
    State.scrapHighlights = {}
    for obj, bb in pairs(State.scrapBillboards) do bb:Destroy() end
    State.scrapBillboards = {}
    for _, prompt in ipairs(folder:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local scrapObject = prompt.Parent
            if scrapObject then
                local parentModel = scrapObject.Parent
                if parentModel then
                    applyScrapESP(parentModel)
                end
            end
        end
    end
end
local function startScrapESP()
    if State.scrapESPActive then return end
    State.scrapESPActive = true
    local folder = getScrapFolder()
    if not folder then return end
    refreshScrapESP()
    State.scrapAddedConn = folder.DescendantAdded:Connect(function(desc)
        if desc:IsA("ProximityPrompt") then
            local scrapObject = desc.Parent
            if scrapObject then
                local parentModel = scrapObject.Parent
                if parentModel then
                    applyScrapESP(parentModel)
                end
            end
        end
    end)
    State.scrapRemovedConn = folder.DescendantRemoving:Connect(function(desc)
        if desc:IsA("ProximityPrompt") then
            local scrapObject = desc.Parent
            if scrapObject then
                local parentModel = scrapObject.Parent
                if parentModel then
                    removeScrapESP(parentModel)
                end
            end
        end
        for obj, _ in pairs(State.scrapHighlights) do
            if not obj.Parent then removeScrapESP(obj) end
        end
    end)
end
local function stopScrapESP()
    State.scrapESPActive = false
    if State.scrapAddedConn then pcall(State.scrapAddedConn.Disconnect, State.scrapAddedConn); State.scrapAddedConn = nil end
    if State.scrapRemovedConn then pcall(State.scrapRemovedConn.Disconnect, State.scrapRemovedConn); State.scrapRemovedConn = nil end
    for obj, hl in pairs(State.scrapHighlights) do hl:Destroy() end
    State.scrapHighlights = {}
    for obj, bb in pairs(State.scrapBillboards) do bb:Destroy() end
    State.scrapBillboards = {}
end

-- ==================== SCRAP TP ====================
local function getAllScrapsOfTypes(types)
    local list = {}
    local folder = getScrapFolder()
    if not folder then return list end
    for _, prompt in ipairs(folder:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local typ = getScrapType(prompt)
            if typ and shouldTPType(typ) and types[typ] then
                local base = prompt.Parent
                if base and base:IsA("BasePart") and base.Transparency < 0.5 then
                    table.insert(list, base)
                end
            end
        end
    end
    return list
end
local function teleportToBase(basePart)
    if not basePart or not basePart:IsA("BasePart") then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = CFrame.new(basePart.Position + Vector3.new(0, 0.5, 0))
    return true
end
local function startScrapTP()
    if State.scrapTPActive then return end
    State.scrapTPActive = true
    State.scrapTPStop = false
    State.scrapTPThread = task.spawn(function()
        while State.scrapTPActive and not State.scrapTPStop do
            local current, max = getScrapCount()
            if current and max and current >= max then
                task.wait(0.5)
                continue
            end
            local types = {}
            if State.scrapTPTypes.Common then types.Common = true end
            if State.scrapTPTypes.Shiny then types.Shiny = true end
            if State.scrapTPTypes.Golden then types.Golden = true end
            local scraps = getAllScrapsOfTypes(types)
            if #scraps == 0 then
                task.wait(1)
            else
                for _, base in ipairs(scraps) do
                    if not State.scrapTPActive or State.scrapTPStop then break end
                    if not base or not base.Parent then continue end
                    local prompt = base:FindFirstChild("ProximityPrompt")
                    if not prompt then continue end
                    local typ = getScrapType(prompt)
                    if not typ or not shouldTPType(typ) then continue end
                    local cur, max2 = getScrapCount()
                    if cur and max2 and cur >= max2 then break end
                    local success = teleportToBase(base)
                    if success then
                        while State.scrapTPActive and not State.scrapTPStop and base and base.Parent do
                            if base.Transparency >= 0.9 then break end
                            task.wait(0.1)
                        end
                    else
                        task.wait(0.5)
                    end
                end
            end
            task.wait(0.5)
        end
        State.scrapTPActive = false
        State.scrapTPThread = nil
    end)
end
local function stopScrapTP()
    State.scrapTPActive = false
    State.scrapTPStop = true
    if State.scrapTPThread then task.cancel(State.scrapTPThread); State.scrapTPThread = nil end
end

-- ==================== TELEPORT COORDINATES ====================
local SHOP_POS = Vector3.new(-291.31, -13.74, -460.54)
local POWER_STATION = Vector3.new(-247.68, 21.58, 215.18)
local LAKE = Vector3.new(130.51, 36.86, 444.74)
local BUNKER = Vector3.new(-88.33, -61.69, 144.25)
local BUNKER_INSIDE = Vector3.new(-138.26, -112.90, 358.21)
local SCRAP_BUILDING = Vector3.new(-497.55, 13.94, 65.53)

local function teleportTo(pos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(pos)
end

-- ==================== TP TO STRUCTURES ====================
local function findNearestStructure(name, strictParentCheck)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pos = hrp.Position
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == name then
            if strictParentCheck then
                if name == "BlackMarket" then
                    local p = obj.Parent
                    if not p or p.Name ~= "Structures" then continue end
                    p = p.Parent
                    if not p or p.Name ~= "MAIN" then continue end
                    p = p.Parent
                    if not p or p.Name ~= "MAP" then continue end
                    p = p.Parent
                    if not p or p ~= Workspace then continue end
                end
            end
            local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChild("Head")
            if root and root:IsA("BasePart") then
                local d = (root.Position - pos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = obj
                end
            end
        end
    end
    return best
end

local function teleportToStructure(name, strictParentCheck)
    local structure = findNearestStructure(name, strictParentCheck)
    if not structure then
        Notify("Teleport", "No " .. name .. " found nearby!")
        return
    end
    local root = structure:FindFirstChild("HumanoidRootPart") or structure.PrimaryPart or structure:FindFirstChild("Head")
    if not root or not root:IsA("BasePart") then
        Notify("Teleport", "Cannot find root part of " .. name)
        return
    end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        Notify("Teleport", "No character")
        return
    end
    local targetPos = root.Position + Vector3.new(0, 5, 0)
    char.HumanoidRootPart.CFrame = CFrame.new(targetPos)
    Notify("Teleport", "Teleported to " .. name)
end

-- ==================== FOLDER LISTENERS ====================
local function onNPCAdded(child)
    if child:IsA("Model") then
        if State.hitboxEnabled then applyHitboxToModel(child) end
        if State.espEnabled then createESP(child) end
    end
end

local function onNPCRemoved(child)
    if child:IsA("Model") then
        if State.hitboxEnabled then removeHitboxFromModel(child) end
        if State.espEnabled then removeESP(child) end
    end
end

local function connectFolderListeners()
    if State.childAddConn then pcall(State.childAddConn.Disconnect, State.childAddConn) end
    if State.childRemConn then pcall(State.childRemConn.Disconnect, State.childRemConn) end
    if npcFolder then
        State.childAddConn = npcFolder.ChildAdded:Connect(onNPCAdded)
        State.childRemConn = npcFolder.ChildRemoved:Connect(onNPCRemoved)
    end
end

local function disconnectFolderListeners()
    if State.childAddConn then pcall(State.childAddConn.Disconnect, State.childAddConn); State.childAddConn = nil end
    if State.childRemConn then pcall(State.childRemConn.Disconnect, State.childRemConn); State.childRemConn = nil end
end

connectFolderListeners()

-- ==================== DESTROY ====================
local function destroyEverything()
    if State.destroying or _G.RevenantGui_Kill then return end
    State.destroying = true
    _G.RevenantGui_Kill = true
    stopScrapTP()
    stopScrapESP()
    stopBlackMarketESP()
    stopAirdropESP()
    stopShedESP()
    stopAmmoLoop()
    stopBarbedWireRemover()
    stopRagdollRemover()
    stopStructNotifier()
    stopFullbright()
    stopInstantProx()
    stopOrbit()
    if State.espEnabled then removeESPAll() end
    if State.hitboxEnabled then removeHitboxAll() end
    disconnectFolderListeners()
    State.destroying = false
end

-- ==================== CREATE UI ELEMENTS ====================
-- ========== MAIN TAB ==========
local npcSection = MainTab:CreateSection("NPC Features")

MainTab:CreateToggle({
    Name = "Hitbox Expander",
    CurrentValue = false,
    Callback = function(Value)
        State.hitboxEnabled = Value
        if State.hitboxEnabled then
            applyHitboxAll()
            Notify("Hitbox", "Enabled")
        else
            removeHitboxAll()
            Notify("Hitbox", "Disabled")
        end
    end
})

MainTab:CreateSlider({
    Name = "Hitbox Size",
    Range = {2, 6.2},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = 6.2,
    Callback = function(Value)
        State.hitboxSize = Value
        if State.hitboxEnabled then
            removeHitboxAll()
            applyHitboxAll()
        end
    end
})

MainTab:CreateToggle({
    Name = "NPC ESP",
    CurrentValue = false,
    Callback = function(Value)
        State.espEnabled = Value
        if State.espEnabled then
            applyESPAll()
            Notify("NPC ESP", "Enabled")
        else
            removeESPAll()
            Notify("NPC ESP", "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Orbit Spin",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startOrbit()
            Notify("Orbit", "Enabled")
        else
            stopOrbit()
            Notify("Orbit", "Disabled")
        end
    end
})

MainTab:CreateSlider({
    Name = "Orbit Radius",
    Range = {0, 200},
    Increment = 1,
    Suffix = "",
    CurrentValue = 80,
    Callback = function(Value)
        State.orbitRadius = Value
    end
})

MainTab:CreateSlider({
    Name = "Orbit Speed",
    Range = {0, 2},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0.1,
    Callback = function(Value)
        State.orbitSpeed = Value
    end
})

local gunsSection = MainTab:CreateSection("Guns Utilities")

MainTab:CreateButton({
    Name = "Give Ammo",
    Callback = function()
        giveAmmoOnce()
        Notify("Ammo", "Given")
    end
})

MainTab:CreateToggle({
    Name = "Loop Ammo",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startAmmoLoop()
            Notify("Loop Ammo", "Enabled")
        else
            stopAmmoLoop()
            Notify("Loop Ammo", "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "No Recoil",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            enableNoRecoil()
        else
            disableNoRecoil()
        end
    end
})

local playerSection = MainTab:CreateSection("Player Utilities")

MainTab:CreateButton({
    Name = "Infinite Stamina",
    Callback = function()
        getInfStamina()
    end
})

MainTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startFullbright()
            Notify("Fullbright", "Enabled")
        else
            stopFullbright()
            Notify("Fullbright", "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Instant Prox. Prompts",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startInstantProx()
            Notify("Instant Prox", "Enabled")
        else
            stopInstantProx()
            Notify("Instant Prox", "Disabled")
        end
    end
})

local worldSection = MainTab:CreateSection("World Utilities")

MainTab:CreateToggle({
    Name = "Shed ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startShedESP()
            Notify("Shed ESP", "Enabled")
        else
            stopShedESP()
            Notify("Shed ESP", "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Airdrop ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startAirdropESP()
            Notify("Airdrop ESP", "Enabled")
        else
            stopAirdropESP()
            Notify("Airdrop ESP", "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Black Market ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startBlackMarketESP()
            Notify("Black Market ESP", "Enabled")
        else
            stopBlackMarketESP()
            Notify("Black Market ESP", "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Structure Notifier",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startStructNotifier()
            Notify("Notifier", "Enabled")
        else
            stopStructNotifier()
            Notify("Notifier", "Disabled")
        end
    end
})

MainTab:CreateToggle({
    Name = "Remove Barbed Wire",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startBarbedWireRemover()
            Notify("Barbed Wire", "Removed")
        else
            stopBarbedWireRemover()
            Notify("Barbed Wire", "Restored")
        end
    end
})

MainTab:CreateToggle({
    Name = "Remove Ragdoll Parts",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startRagdollRemover()
            Notify("Ragdoll", "Removed")
        else
            stopRagdollRemover()
            Notify("Ragdoll", "Restored")
        end
    end
})

-- ========== SCRAPS TAB ==========
local scrapSection = ScrapsTab:CreateSection("Scrap ESP")

ScrapsTab:CreateToggle({
    Name = "Scrap ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startScrapESP()
            Notify("Scrap ESP", "Enabled")
        else
            stopScrapESP()
            Notify("Scrap ESP", "Disabled")
        end
    end
})

ScrapsTab:CreateLabel("Filter types to show:")

ScrapsTab:CreateToggle({
    Name = "Common",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapESPTypes.Common = Value
        if State.scrapESPActive then
            refreshScrapESP()
        end
    end
})

ScrapsTab:CreateToggle({
    Name = "Shiny",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapESPTypes.Shiny = Value
        if State.scrapESPActive then
            refreshScrapESP()
        end
    end
})

ScrapsTab:CreateToggle({
    Name = "Golden",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapESPTypes.Golden = Value
        if State.scrapESPActive then
            refreshScrapESP()
        end
    end
})

ScrapsTab:CreateToggle({
    Name = "Cursed",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapESPTypes.Cursed = Value
        if State.scrapESPActive then
            refreshScrapESP()
        end
    end
})

ScrapsTab:CreateSection("Scrap Teleport")

ScrapsTab:CreateToggle({
    Name = "Scrap Teleport",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startScrapTP()
            Notify("Scrap TP", "Enabled")
        else
            stopScrapTP()
            Notify("Scrap TP", "Disabled")
        end
    end
})

ScrapsTab:CreateLabel("Types to teleport to:")

ScrapsTab:CreateToggle({
    Name = "Common",
    CurrentValue = false,
    Callback = function(Value)
        State.scrapTPTypes.Common = Value
    end
})

ScrapsTab:CreateToggle({
    Name = "Shiny",
    CurrentValue = false,
    Callback = function(Value)
        State.scrapTPTypes.Shiny = Value
    end
})

ScrapsTab:CreateToggle({
    Name = "Golden",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapTPTypes.Golden = Value
    end
})

ScrapsTab:CreateSection("Teleports")

ScrapsTab:CreateButton({
    Name = "TP to Shop",
    Callback = function()
        teleportTo(SHOP_POS)
        Notify("Teleport", "To Shop")
    end
})

ScrapsTab:CreateButton({
    Name = "TP to Power Station",
    Callback = function()
        teleportTo(POWER_STATION)
        Notify("Teleport", "To Power Station")
    end
})

ScrapsTab:CreateButton({
    Name = "TP to Lake",
    Callback = function()
        teleportTo(LAKE)
        Notify("Teleport", "To Lake")
    end
})

ScrapsTab:CreateButton({
    Name = "TP to Bunker",
    Callback = function()
        teleportTo(BUNKER)
        Notify("Teleport", "To Bunker")
    end
})

ScrapsTab:CreateButton({
    Name = "TP Inside Bunker",
    Callback = function()
        teleportTo(BUNKER_INSIDE)
        Notify("Teleport", "Inside Bunker")
    end
})

ScrapsTab:CreateButton({
    Name = "TP to Scrap Building",
    Callback = function()
        teleportTo(SCRAP_BUILDING)
        Notify("Teleport", "To Scrap Building")
    end
})

ScrapsTab:CreateButton({
    Name = "TP to Shed",
    Callback = function()
        teleportToStructure('Shed', false)
    end
})

ScrapsTab:CreateButton({
    Name = "TP to Airdrop",
    Callback = function()
        teleportToStructure('Airdrop', false)
    end
})

ScrapsTab:CreateButton({
    Name = "TP to Black Market",
    Callback = function()
        teleportToStructure('BlackMarket', true)
    end
})

-- ===== CUSTOM TELEPORT SAVER =====
local savedPositions = {}
local function generateDefaultName()
    local base = "Placeholder"
    local name = base
    local i = 1
    while savedPositions[name] do i = i + 1; name = base .. " (" .. i .. ")" end
    return name
end
local function saveCurrentPosition(name)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    name = name or generateDefaultName()
    savedPositions[name] = { name = name, pos = hrp.Position }
    return true
end
local function deleteSavedPosition(name) savedPositions[name] = nil end
local function teleportToSaved(name)
    local data = savedPositions[name]
    if data then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(data.pos)
            Notify("Teleport", "To " .. name)
        end
    end
end

local teleportListDropdown
local function updateTeleportList()
    local names = {}
    for _, data in pairs(savedPositions) do
        table.insert(names, data.name)
    end
    table.sort(names)
    if teleportListDropdown then
        if #names > 0 then
            teleportListDropdown:Set(names)
        else
            teleportListDropdown:Set({"No saved positions"})
        end
    end
end

ScrapsTab:CreateSection("Custom Teleports")

ScrapsTab:CreateInput({
    Name = "Position Name",
    PlaceholderText = "Placeholder",
    Callback = function(Value)
        _G.customTeleportName = Value
    end
})

ScrapsTab:CreateButton({
    Name = "Save Current Position",
    Callback = function()
        local name = _G.customTeleportName or generateDefaultName()
        if savedPositions[name] then
            Notify("Error", "Name already exists!")
            return
        end
        if saveCurrentPosition(name) then
            updateTeleportList()
            Notify("Saved", "Position " .. name)
        else
            Notify("Error", "Failed to save (no character?)")
        end
    end
})

teleportListDropdown = ScrapsTab:CreateDropdown({
    Name = "Saved Positions",
    Options = {},
    CurrentOption = "",
    Callback = function(Option)
        _G.selectedTeleport = Option
    end
})
updateTeleportList()

ScrapsTab:CreateButton({
    Name = "Teleport to Selected",
    Callback = function()
        if _G.selectedTeleport then
            teleportToSaved(_G.selectedTeleport)
        else
            Notify("Error", "No position selected")
        end
    end
})

ScrapsTab:CreateButton({
    Name = "Delete Selected",
    Callback = function()
        if _G.selectedTeleport and savedPositions[_G.selectedTeleport] then
            deleteSavedPosition(_G.selectedTeleport)
            updateTeleportList()
            Notify("Deleted", _G.selectedTeleport)
            _G.selectedTeleport = nil
        else
            Notify("Error", "No position selected or does not exist")
        end
    end
})

-- ========== SETTINGS TAB ==========
local settingsSection = SettingsTab:CreateSection("General Settings")

SettingsTab:CreateLabel("The Revenant: Sunrisen Gui")
SettingsTab:CreateLabel("Mobile Version")
SettingsTab:CreateLabel("Version 1.1")

SettingsTab:CreateDivider()

local themeDropdown = SettingsTab:CreateDropdown({
    Name = "Theme",
    Options = {"Default", "Ocean", "Serpents", "Amethyst", "Midnight", "Synthwave"},
    CurrentOption = "Default",
    Callback = function(Option)
        pcall(function()
            Rayfield:SetTheme(Option)
        end)
        Notify("Theme", "Changed to " .. Option)
    end
})

SettingsTab:CreateSlider({
    Name = "Notification Duration",
    Range = {1, 10},
    Increment = 1,
    Suffix = " sec",
    CurrentValue = 3,
    Callback = function(Value)
        notificationDuration = Value
        Notify("Duration", "Set to " .. Value .. " seconds")
    end
})

SettingsTab:CreateDivider()

SettingsTab:CreateButton({
    Name = "Reset Configuration & Restart",
    Callback = function()
        local success, err = pcall(function()
            if isfolder and isfolder("RevenantSunrisenMobile") then
                delfolder("RevenantSunrisenMobile")
            end
            if isfolder and isfolder("Rayfield") then
                local configPath = "Rayfield/RevenantSunrisenMobile_Config.json"
                if isfile and isfile(configPath) then
                    delfile(configPath)
                end
            end
        end)
        Notify("Reset", "Configuration reset, restarting...")
        task.wait(1)
        -- Replace with your script URL
        local script = game:HttpGet("https://raw.githubusercontent.com/your-repo/script.lua")
        loadstring(script)()
        Rayfield:Destroy()
        _G.RevenantGui_Kill = true
    end
})

SettingsTab:CreateButton({
    Name = "Unload Script",
    Callback = function()
        destroyEverything()
        Rayfield:Destroy()
        Notify("Unloaded", "Script unloaded")
        task.wait(0.5)
        _G.RevenantGui_Kill = true
    end
})

-- ==================== LOAD CONFIGURATION ====================
Rayfield:LoadConfiguration()

Notify("Loaded", "The Revenant: Sunrisen Mobile")

print("The Revenant: Sunrisen GUI (Mobile Version) loaded successfully!")
