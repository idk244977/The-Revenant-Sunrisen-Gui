-- The Revenant:

if _G.RevenantGui_Kill then
    _G.RevenantGui_Kill = true
    task.wait(0.2)
end
_G.RevenantGui_Kill = false
local function isKilled() return _G.RevenantGui_Kill end

-- ==================== LINORIALIB ====================
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==================== CONFIG ====================
local NPC_FOLDER_NAME = "NPCs"
local HEAD_SIZE_MAX = 6.2
local AMMO_LOOP_DELAY = 0.3

-- ==================== CAPTURE ORIGINAL LIGHTING ====================
local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient
}

-- ==================== STATE TABLE ====================
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

-- ==================== NO LOCAL firesignal – USE EXECUTOR'S GLOBAL ====================

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
    if State.espHighlights[model] then State.espHighlights[model]:Destroy(); State.espHighlights[model] = nil end
    if State.espBillboards[model] then State.espBillboards[model]:Destroy(); State.espBillboards[model] = nil end
end

local function applyESPAll()
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
    for model, hl in pairs(State.espHighlights) do hl:Destroy() end
    State.espHighlights = {}
    for model, bb in pairs(State.espBillboards) do bb:Destroy() end
    State.espBillboards = {}
    if State.distanceConn then pcall(State.distanceConn.Disconnect, State.distanceConn); State.distanceConn = nil end
end

-- ==================== AMMO (USING GLOBAL firesignal) ====================
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

-- ==================== INFINITE STAMINA (USING GLOBAL firesignal) ====================
local function getInfStamina()
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then
        Library:Notify("Events folder not found!", 2)
        return
    end
    local remoteEvent = events:FindFirstChild("I__NFSTA_AXDLOL")
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        pcall(firesignal, remoteEvent.OnClientEvent, true, math.huge)
        Library:Notify("Infinite Stamina activated!", 2)
    else
        Library:Notify("Stamina remote not found!", 2)
    end
end

-- ==================== NO RECOIL ====================
local recoilModulePath = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("GunSystem") and ReplicatedStorage.Modules.GunSystem:FindFirstChild("Shared") and ReplicatedStorage.Modules.GunSystem.Shared:FindFirstChild("Recoil")
local Recoil = recoilModulePath and require(recoilModulePath)
local originalAccelerate = nil

local function enableNoRecoil()
    if not Recoil then
        Library:Notify("Recoil module not found!", 2)
        return
    end
    if not originalAccelerate then
        originalAccelerate = Recoil.Accelerate
        Recoil.Accelerate = function(self, ...)
            return {}
        end
        Library:Notify("No Recoil enabled", 2)
    end
end

local function disableNoRecoil()
    if Recoil and originalAccelerate then
        Recoil.Accelerate = originalAccelerate
        originalAccelerate = nil
        Library:Notify("No Recoil disabled", 2)
    end
end

-- ==================== SHED ESP (FIXED: use specific part) ====================
local function onShedAdded(model)
    if model.Name == "Shed" and model:IsA("Model") and not State.shedHighlights[model] then
        -- Find a suitable part for the highlight
        local adornPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
        if not adornPart then return end

        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(0, 255, 255)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 0
        hl.Adornee = adornPart
        hl.Parent = adornPart
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
end
local function onShedRemoved(model)
    if model.Name ~= "Shed" then return end
    if State.shedHighlights[model] then State.shedHighlights[model]:Destroy(); State.shedHighlights[model] = nil end
    if State.shedBillboards[model] then State.shedBillboards[model]:Destroy(); State.shedBillboards[model] = nil end
end
local function startShedESP()
    if State.shedESPActive then return end
    State.shedESPActive = true
    State.shedChildAddedConn = Workspace.ChildAdded:Connect(onShedAdded)
    State.shedChildRemovedConn = Workspace.ChildRemoved:Connect(onShedRemoved)
    for _, child in ipairs(Workspace:GetChildren()) do onShedAdded(child) end
end
local function stopShedESP()
    State.shedESPActive = false
    if State.shedChildAddedConn then pcall(State.shedChildAddedConn.Disconnect, State.shedChildAddedConn); State.shedChildAddedConn = nil end
    if State.shedChildRemovedConn then pcall(State.shedChildRemovedConn.Disconnect, State.shedChildRemovedConn); State.shedChildRemovedConn = nil end
    for model, hl in pairs(State.shedHighlights) do hl:Destroy() end
    for model, bb in pairs(State.shedBillboards) do bb:Destroy() end
    State.shedHighlights, State.shedBillboards = {}, {}
end

-- ==================== AIRDROP ESP (FIXED: use specific part) ====================
local function onAirdropAdded(model)
    if model.Name == "Airdrop" and model:IsA("Model") and not State.airdropHighlights[model] then
        local adornPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
        if not adornPart then return end

        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255, 0, 255)
        hl.OutlineColor = Color3.fromRGB(255, 255, 0)
        hl.FillTransparency = 0.2
        hl.OutlineTransparency = 0
        hl.Adornee = adornPart
        hl.Parent = adornPart
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
end
local function onAirdropRemoved(model)
    if model.Name ~= "Airdrop" then return end
    if State.airdropHighlights[model] then State.airdropHighlights[model]:Destroy(); State.airdropHighlights[model] = nil end
    if State.airdropBillboards[model] then State.airdropBillboards[model]:Destroy(); State.airdropBillboards[model] = nil end
end
local function startAirdropESP()
    if State.airdropESPActive then return end
    State.airdropESPActive = true
    State.airdropChildAddedConn = Workspace.ChildAdded:Connect(onAirdropAdded)
    State.airdropChildRemovedConn = Workspace.ChildRemoved:Connect(onAirdropRemoved)
    for _, child in ipairs(Workspace:GetChildren()) do onAirdropAdded(child) end
end
local function stopAirdropESP()
    State.airdropESPActive = false
    if State.airdropChildAddedConn then pcall(State.airdropChildAddedConn.Disconnect, State.airdropChildAddedConn); State.airdropChildAddedConn = nil end
    if State.airdropChildRemovedConn then pcall(State.airdropChildRemovedConn.Disconnect, State.airdropChildRemovedConn); State.airdropChildRemovedConn = nil end
    for model, hl in pairs(State.airdropHighlights) do hl:Destroy() end
    for model, bb in pairs(State.airdropBillboards) do bb:Destroy() end
    State.airdropHighlights, State.airdropBillboards = {}, {}
end

-- ==================== BLACK MARKET ESP (FIXED: use specific part) ====================
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
    hl.Adornee = adornPart
    hl.Parent = adornPart
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
        Library:Notify("Shed spawned!", 3)
    end
end
local function notifyAirdrop(model)
    if model.Name == "Airdrop" and model:IsA("Model") then
        Library:Notify("Airdrop spawned!", 3)
    end
end
local function notifyBlackMarket(instance)
    if isBlackMarket(instance) then
        Library:Notify("Black Market spawned!", 3)
    end
end
local function notifyCursedScrap(scrapObject)
    if scrapObject and scrapObject:IsA("Model") then
        local prompt = scrapObject:FindFirstChild("ProximityPrompt", true)
        if prompt and prompt:IsA("ProximityPrompt") then
            local typ = getScrapType(prompt)
            if typ == "Cursed" then
                Library:Notify("Cursed Scrap spawned!", Color3.fromRGB(255,0,0))
            end
        end
    end
end

local function startStructNotifier()
    if State.structNotifierActive then return end
    State.structNotifierActive = true
    local shedConn = Workspace.ChildAdded:Connect(notifyShed)
    local airdropConn = Workspace.ChildAdded:Connect(notifyAirdrop)
    local blackMarketConn = Workspace.DescendantAdded:Connect(function(desc)
        if isBlackMarket(desc) then
            Library:Notify("Black Market spawned!", 3)
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
    for _, child in ipairs(Workspace:GetChildren()) do
        notifyShed(child)
        notifyAirdrop(child)
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if isBlackMarket(desc) then
            Library:Notify("Black Market spawned!", 3)
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

-- ==================== FULLBRIGHT (restores fog when off) ====================
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

-- ==================== INSTANT PROX. PROMPTS (with exception) ====================
local INSTANT_PROX_DURATION = 0  -- default: instant click
local EXCEPTION_PROX_DURATION = 0.0001  -- for PowerStation.Core

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
        Library:Notify("No " .. name .. " found nearby!", 3)
        return
    end
    local root = structure:FindFirstChild("HumanoidRootPart") or structure.PrimaryPart or structure:FindFirstChild("Head")
    if not root or not root:IsA("BasePart") then
        Library:Notify("Cannot find root part of " .. name, 3)
        return
    end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        Library:Notify("No character", 3)
        return
    end
    local targetPos = root.Position + Vector3.new(0, 5, 0)
    char.HumanoidRootPart.CFrame = CFrame.new(targetPos)
    Library:Notify("Teleported to " .. name, 2)
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
    if Toggles and Toggles.NoRecoil and Toggles.NoRecoil.Value then
        disableNoRecoil()
    end
    if State.espEnabled then removeESPAll() end
    if State.hitboxEnabled then removeHitboxAll() end
    disconnectFolderListeners()
    State.destroying = false
end

-- ==================== LINORIALIB WINDOW ====================
local Window = Library:CreateWindow({
    Title = 'The Revenant: Sunrisen',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local gui = playerGui:FindFirstChild("Linoria")
if gui then gui.Name = "RevenantSunrisenGui" end

local Tabs = {
    Main = Window:AddTab('Main'),
    Scraps = Window:AddTab('Scraps & Teleports'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ===== MAIN TAB =====
local MainLeft = Tabs.Main:AddLeftGroupbox('NPC Features')
local MainMiddle = Tabs.Main:AddLeftGroupbox('Guns Utilities')
local MainRight = Tabs.Main:AddRightGroupbox('World Utilities')
local MainRightBottom = Tabs.Main:AddRightGroupbox('Player Utilities')

-- Hitbox
local hitboxToggle = MainLeft:AddToggle('Hitbox', {
    Text = 'Hitbox Expander',
    Default = false,
})
hitboxToggle:AddKeyPicker('HitboxKey', { Default = '', Mode = 'Toggle', Text = 'Hitbox Key', SyncToggleState = false })
Toggles.Hitbox:OnChanged(function()
    State.hitboxEnabled = Toggles.Hitbox.Value
    if State.hitboxEnabled then
        applyHitboxAll()
    else
        removeHitboxAll()
    end
end)
if Options.HitboxKey then
    Options.HitboxKey:OnClick(function() Toggles.Hitbox:SetValue(not Toggles.Hitbox.Value) end)
end

MainLeft:AddSlider('HitboxSize', {
    Text = 'Hitbox Size',
    Default = 6.2,
    Min = 2,
    Max = 6.2,
    Rounding = 1,
})
Options.HitboxSize:OnChanged(function()
    State.hitboxSize = Options.HitboxSize.Value
    if State.hitboxEnabled then
        removeHitboxAll()
        applyHitboxAll()
    end
end)

-- NPC ESP
local npcEspToggle = MainLeft:AddToggle('NPCESP', {
    Text = 'NPC ESP',
    Default = false,
})
npcEspToggle:AddKeyPicker('NPCESPKey', { Default = '', Mode = 'Toggle', Text = 'NPC ESP Key', SyncToggleState = false })
Toggles.NPCESP:OnChanged(function()
    State.espEnabled = Toggles.NPCESP.Value
    if State.espEnabled then
        applyESPAll()
    else
        removeESPAll()
    end
end)
if Options.NPCESPKey then
    Options.NPCESPKey:OnClick(function() Toggles.NPCESP:SetValue(not Toggles.NPCESP.Value) end)
end

-- Orbit Spin
local orbitToggle = MainLeft:AddToggle('OrbitSpin', {
    Text = 'Orbit Spin',
    Default = false,
})
orbitToggle:AddKeyPicker('OrbitKey', { Default = '', Mode = 'Toggle', Text = 'Orbit Key', SyncToggleState = false })
Toggles.OrbitSpin:OnChanged(function()
    if Toggles.OrbitSpin.Value then startOrbit() else stopOrbit() end
end)
if Options.OrbitKey then
    Options.OrbitKey:OnClick(function() Toggles.OrbitSpin:SetValue(not Toggles.OrbitSpin.Value) end)
end

MainLeft:AddSlider('OrbitRadius', {
    Text = 'Orbit Radius',
    Default = 80,
    Min = 0,
    Max = 200,
    Rounding = 1,
})
Options.OrbitRadius:OnChanged(function()
    State.orbitRadius = Options.OrbitRadius.Value
end)

MainLeft:AddSlider('OrbitSpeed', {
    Text = 'Orbit Speed',
    Default = 0.1,
    Min = 0,
    Max = 2,
    Rounding = 2,
})
Options.OrbitSpeed:OnChanged(function()
    State.orbitSpeed = Options.OrbitSpeed.Value
end)

-- Guns Utilities
MainMiddle:AddButton('Give Ammo', giveAmmoOnce)
local loopAmmoToggle = MainMiddle:AddToggle('LoopAmmo', {
    Text = 'Loop Ammo',
    Default = false,
})
loopAmmoToggle:AddKeyPicker('LoopAmmoKey', { Default = '', Mode = 'Toggle', Text = 'Loop Ammo Key', SyncToggleState = false })
Toggles.LoopAmmo:OnChanged(function()
    if Toggles.LoopAmmo.Value then startAmmoLoop() else stopAmmoLoop() end
end)
if Options.LoopAmmoKey then
    Options.LoopAmmoKey:OnClick(function() Toggles.LoopAmmo:SetValue(not Toggles.LoopAmmo.Value) end)
end

-- No Recoil
local noRecoilToggle = MainMiddle:AddToggle('NoRecoil', {
    Text = 'No Recoil',
    Default = false,
})
noRecoilToggle:AddKeyPicker('NoRecoilKey', { Default = '', Mode = 'Toggle', Text = 'No Recoil Key', SyncToggleState = false })
Toggles.NoRecoil:OnChanged(function()
    if Toggles.NoRecoil.Value then
        enableNoRecoil()
    else
        disableNoRecoil()
    end
end)
if Options.NoRecoilKey then
    Options.NoRecoilKey:OnClick(function() Toggles.NoRecoil:SetValue(not Toggles.NoRecoil.Value) end)
end

-- Player Utilities
MainRightBottom:AddButton('Infinite Stamina', function()
    getInfStamina()
end)

-- Fullbright
local fullbrightToggle = MainRightBottom:AddToggle('Fullbright', {
    Text = 'Fullbright',
    Default = false,
})
fullbrightToggle:AddKeyPicker('FullbrightKey', { Default = '', Mode = 'Toggle', Text = 'Fullbright Key', SyncToggleState = false })
Toggles.Fullbright:OnChanged(function()
    if Toggles.Fullbright.Value then startFullbright() else stopFullbright() end
end)
if Options.FullbrightKey then
    Options.FullbrightKey:OnClick(function() Toggles.Fullbright:SetValue(not Toggles.Fullbright.Value) end)
end

-- Instant Prox. Prompts
local proxToggle = MainRightBottom:AddToggle('InstantProx', {
    Text = 'Instant Prox. Prompts',
    Default = false,
})
proxToggle:AddKeyPicker('InstantProxKey', { Default = '', Mode = 'Toggle', Text = 'Instant Prox Key', SyncToggleState = false })
Toggles.InstantProx:OnChanged(function()
    if Toggles.InstantProx.Value then startInstantProx() else stopInstantProx() end
end)
if Options.InstantProxKey then
    Options.InstantProxKey:OnClick(function() Toggles.InstantProx:SetValue(not Toggles.InstantProx.Value) end)
end

-- World Utilities
local shedToggle = MainRight:AddToggle('ShedESP', {
    Text = 'Shed ESP',
    Default = false,
})
shedToggle:AddKeyPicker('ShedESPKey', { Default = '', Mode = 'Toggle', Text = 'Shed ESP Key', SyncToggleState = false })
Toggles.ShedESP:OnChanged(function()
    if Toggles.ShedESP.Value then startShedESP() else stopShedESP() end
end)
if Options.ShedESPKey then
    Options.ShedESPKey:OnClick(function() Toggles.ShedESP:SetValue(not Toggles.ShedESP.Value) end)
end

local airdropToggle = MainRight:AddToggle('AirdropESP', {
    Text = 'Airdrop ESP',
    Default = false,
})
airdropToggle:AddKeyPicker('AirdropESPKey', { Default = '', Mode = 'Toggle', Text = 'Airdrop ESP Key', SyncToggleState = false })
Toggles.AirdropESP:OnChanged(function()
    if Toggles.AirdropESP.Value then startAirdropESP() else stopAirdropESP() end
end)
if Options.AirdropESPKey then
    Options.AirdropESPKey:OnClick(function() Toggles.AirdropESP:SetValue(not Toggles.AirdropESP.Value) end)
end

local blackMarketToggle = MainRight:AddToggle('BlackMarketESP', {
    Text = 'Black Market ESP',
    Default = false,
})
blackMarketToggle:AddKeyPicker('BlackMarketESPKey', { Default = '', Mode = 'Toggle', Text = 'Black Market ESP Key', SyncToggleState = false })
Toggles.BlackMarketESP:OnChanged(function()
    if Toggles.BlackMarketESP.Value then startBlackMarketESP() else stopBlackMarketESP() end
end)
if Options.BlackMarketESPKey then
    Options.BlackMarketESPKey:OnClick(function() Toggles.BlackMarketESP:SetValue(not Toggles.BlackMarketESP.Value) end)
end

local notifierToggle = MainRight:AddToggle('StructureNotifier', {
    Text = 'Structure Notifier',
    Default = false,
})
notifierToggle:AddKeyPicker('StructNotifierKey', { Default = '', Mode = 'Toggle', Text = 'Notifier Key', SyncToggleState = false })
Toggles.StructureNotifier:OnChanged(function()
    if Toggles.StructureNotifier.Value then startStructNotifier() else stopStructNotifier() end
end)
if Options.StructNotifierKey then
    Options.StructNotifierKey:OnClick(function() Toggles.StructureNotifier:SetValue(not Toggles.StructureNotifier.Value) end)
end

local barbedWireToggle = MainRight:AddToggle('RemoveBarbedWire', {
    Text = 'Remove Barbed Wire',
    Default = false,
})
barbedWireToggle:AddKeyPicker('BarbedWireKey', { Default = '', Mode = 'Toggle', Text = 'Barbed Wire Key', SyncToggleState = false })
Toggles.RemoveBarbedWire:OnChanged(function()
    if Toggles.RemoveBarbedWire.Value then startBarbedWireRemover() else stopBarbedWireRemover() end
end)
if Options.BarbedWireKey then
    Options.BarbedWireKey:OnClick(function() Toggles.RemoveBarbedWire:SetValue(not Toggles.RemoveBarbedWire.Value) end)
end

local ragdollToggle = MainRight:AddToggle('RemoveRagdoll', {
    Text = 'Remove Ragdoll Parts',
    Default = false,
})
ragdollToggle:AddKeyPicker('RagdollKey', { Default = '', Mode = 'Toggle', Text = 'Ragdoll Key', SyncToggleState = false })
Toggles.RemoveRagdoll:OnChanged(function()
    if Toggles.RemoveRagdoll.Value then startRagdollRemover() else stopRagdollRemover() end
end)
if Options.RagdollKey then
    Options.RagdollKey:OnClick(function() Toggles.RemoveRagdoll:SetValue(not Toggles.RemoveRagdoll.Value) end)
end

-- ===== SCRAPS & TELEPORTS TAB =====
local ScrapLeft = Tabs.Scraps:AddLeftGroupbox('Scrap ESP')
local ScrapRight = Tabs.Scraps:AddRightGroupbox('Scrap TP & Teleports')

-- Scrap ESP
local scrapEspToggle = ScrapLeft:AddToggle('ScrapESP', {
    Text = 'Scrap ESP',
    Default = false,
})
scrapEspToggle:AddKeyPicker('ScrapESPKey', { Default = '', Mode = 'Toggle', Text = 'Scrap ESP Key', SyncToggleState = false })
Toggles.ScrapESP:OnChanged(function()
    if Toggles.ScrapESP.Value then startScrapESP() else stopScrapESP() end
end)
if Options.ScrapESPKey then
    Options.ScrapESPKey:OnClick(function() Toggles.ScrapESP:SetValue(not Toggles.ScrapESP.Value) end)
end

ScrapLeft:AddLabel('Filter types to show:')
ScrapLeft:AddToggle('ScrapESPCommon', { Text = 'Common', Default = true })
Toggles.ScrapESPCommon:OnChanged(function()
    State.scrapESPTypes.Common = Toggles.ScrapESPCommon.Value
    if Toggles.ScrapESP.Value then refreshScrapESP() end
end)
ScrapLeft:AddToggle('ScrapESPShiny', { Text = 'Shiny', Default = true })
Toggles.ScrapESPShiny:OnChanged(function()
    State.scrapESPTypes.Shiny = Toggles.ScrapESPShiny.Value
    if Toggles.ScrapESP.Value then refreshScrapESP() end
end)
ScrapLeft:AddToggle('ScrapESPGolden', { Text = 'Golden', Default = true })
Toggles.ScrapESPGolden:OnChanged(function()
    State.scrapESPTypes.Golden = Toggles.ScrapESPGolden.Value
    if Toggles.ScrapESP.Value then refreshScrapESP() end
end)
ScrapLeft:AddToggle('ScrapESPCursed', { Text = 'Cursed', Default = true })
Toggles.ScrapESPCursed:OnChanged(function()
    State.scrapESPTypes.Cursed = Toggles.ScrapESPCursed.Value
    if Toggles.ScrapESP.Value then refreshScrapESP() end
end)

-- Scrap TP
local scrapTPToggle = ScrapRight:AddToggle('ScrapTP', {
    Text = 'Scrap Teleport',
    Default = false,
})
scrapTPToggle:AddKeyPicker('ScrapTPKey', { Default = '', Mode = 'Toggle', Text = 'Scrap TP Key', SyncToggleState = false })
Toggles.ScrapTP:OnChanged(function()
    if Toggles.ScrapTP.Value then startScrapTP() else stopScrapTP() end
end)
if Options.ScrapTPKey then
    Options.ScrapTPKey:OnClick(function() Toggles.ScrapTP:SetValue(not Toggles.ScrapTP.Value) end)
end

ScrapRight:AddLabel('Types to teleport to:')
ScrapRight:AddToggle('ScrapTPCommon', { Text = 'Common', Default = false })
Toggles.ScrapTPCommon:OnChanged(function()
    State.scrapTPTypes.Common = Toggles.ScrapTPCommon.Value
end)
ScrapRight:AddToggle('ScrapTPShiny', { Text = 'Shiny', Default = false })
Toggles.ScrapTPShiny:OnChanged(function()
    State.scrapTPTypes.Shiny = Toggles.ScrapTPShiny.Value
end)
ScrapRight:AddToggle('ScrapTPGolden', { Text = 'Golden', Default = true })
Toggles.ScrapTPGolden:OnChanged(function()
    State.scrapTPTypes.Golden = Toggles.ScrapTPGolden.Value
end)

ScrapRight:AddDivider()
ScrapRight:AddButton('TP to Shop', function() teleportTo(SHOP_POS) end)
ScrapRight:AddButton('TP to Power Station', function() teleportTo(POWER_STATION) end)
ScrapRight:AddButton('TP to Lake', function() teleportTo(LAKE) end)
ScrapRight:AddButton('TP to Bunker', function() teleportTo(BUNKER) end)
ScrapRight:AddButton('TP Inside Bunker', function() teleportTo(BUNKER_INSIDE) end)
ScrapRight:AddButton('TP to Scrap Building', function() teleportTo(SCRAP_BUILDING) end)

ScrapRight:AddDivider()
ScrapRight:AddButton('TP to Shed', function() teleportToStructure('Shed', false) end)
ScrapRight:AddButton('TP to Airdrop', function() teleportToStructure('Airdrop', false) end)
ScrapRight:AddButton('TP to Black Market', function() teleportToStructure('BlackMarket', true) end)

-- ===== CUSTOM TELEPORT SAVER =====
local TeleportsGroup = Tabs.Scraps:AddLeftGroupbox('Custom Teleports')
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
        end
    end
end

local teleportListDropdown
local function updateTeleportList()
    local names = {}
    for _, data in pairs(savedPositions) do table.insert(names, data.name) end
    table.sort(names)
    if teleportListDropdown then teleportListDropdown:SetValues(names) end
end

TeleportsGroup:AddInput('TeleportName', {
    Text = 'Name',
    Default = generateDefaultName(),
    Placeholder = 'Placeholder',
    Finished = true,
})
TeleportsGroup:AddButton('Save Position', function()
    local name = Options.TeleportName.Value
    if name == nil or name:gsub(' ', '') == '' then
        name = generateDefaultName()
        Options.TeleportName:SetValue(name)
    end
    if savedPositions[name] then
        Library:Notify('A position with that name already exists!', 2)
        return
    end
    if saveCurrentPosition(name) then
        updateTeleportList()
        Library:Notify('Saved position ' .. name)
    else
        Library:Notify('Failed to save position (no character?)', 2)
    end
end)
TeleportsGroup:AddDivider()
teleportListDropdown = TeleportsGroup:AddDropdown('TeleportList', {
    Text = 'Saved Positions',
    Values = {},
    AllowNull = true,
})
TeleportsGroup:AddButton('Teleport', function()
    local name = Options.TeleportList.Value
    if name then teleportToSaved(name) end
end):AddButton('Delete', function()
    local name = Options.TeleportList.Value
    if name then
        deleteSavedPosition(name)
        updateTeleportList()
        Library:Notify('Deleted ' .. name)
    end
end)
updateTeleportList()

-- ===== UI SETTINGS =====
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI = true,
    Mode = 'Toggle',
    Text = 'Menu keybind'
})
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddToggle('ShowKeybinds', {
    Text = 'Show Keybinds',
    Default = true,
})
Toggles.ShowKeybinds:OnChanged(function()
    Library.KeybindFrame.Visible = Toggles.ShowKeybinds.Value
end)
Library.KeybindFrame.Visible = true

MenuGroup:AddButton('Unload Script', function()
    Library:Unload()
end)

Library:SetWatermark('The Revenant: Sunrisen Gui')
Library:SetWatermarkVisibility(true)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind', 'ShowKeybinds' })
SaveManager:SetFolder('RevenantSunrisen')
ThemeManager:SetFolder('RevenantSunrisen')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

-- ===== AFTER LOADING CONFIG: FORCE CORRECT STATES =====
if not Toggles.Hitbox.Value then
    State.hitboxEnabled = false
    removeHitboxAll()
else
    State.hitboxEnabled = true
    applyHitboxAll()
end

if not Toggles.NPCESP.Value then
    State.espEnabled = false
    removeESPAll()
else
    State.espEnabled = true
    applyESPAll()
end

if not Toggles.Fullbright.Value then
    stopFullbright()
else
    startFullbright()
end

if Toggles.LoopAmmo.Value then startAmmoLoop() end
if Toggles.NoRecoil.Value then enableNoRecoil() end
if Toggles.ShedESP.Value then startShedESP() end
if Toggles.AirdropESP.Value then startAirdropESP() end
if Toggles.BlackMarketESP.Value then startBlackMarketESP() end
if Toggles.StructureNotifier.Value then startStructNotifier() end
if Toggles.RemoveBarbedWire.Value then startBarbedWireRemover() end
if Toggles.RemoveRagdoll.Value then startRagdollRemover() end
if Toggles.ScrapESP.Value then startScrapESP() end
if Toggles.ScrapTP.Value then startScrapTP() end
if Toggles.InstantProx.Value then startInstantProx() end
if Toggles.OrbitSpin.Value then startOrbit() end

Library:OnUnload(function()
    destroyEverything()
end)

player.CharacterAdded:Connect(function()
    if State.hitboxEnabled then applyHitboxAll() end
    if State.espEnabled then applyESPAll() end
end)

print("The Revenant: Sunrisen Gui loaded successfully!")
