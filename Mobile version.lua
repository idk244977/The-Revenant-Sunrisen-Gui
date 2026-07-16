-- The Revenant: Sunrisen GUI (Mobile)
-- Made with Rayfield V2 Library
-- version V1.2

if _G.RevenantGui_Kill then
    _G.RevenantGui_Kill = true
    task.wait(0.2)
end
_G.RevenantGui_Kill = false
local function isKilled() return _G.RevenantGui_Kill end

-- ===== RAYFIELD =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "The Revenant: Sunrisen GUI (Mobile)",
    Icon = 0,
    LoadingTitle = "Loading Revenant GUI",
    LoadingSubtitle = "Mobile version",
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

local Tabs = {
    Main = Window:CreateTab("Main", "swords"),
    Scraps = Window:CreateTab("Scraps", "package"),
    Settings = Window:CreateTab("Settings", "cog")
}

-- ===== GLOBALS =====
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
    shedDescConn = nil,

    airdropESPActive = false,
    airdropHighlights = {},
    airdropBillboards = {},
    airdropDescConn = nil,

    blackMarketESPActive = false,
    blackMarketHighlights = {},
    blackMarketBillboards = {},
    blackMarketDescConn = nil,

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
    ragdollFolderConn = nil,

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

    mainDescConn = nil,
    mainRemConn = nil,

    destroying = false
}

local function cleanupAll()
    for _, model in ipairs(State.hitboxConns) do
        for _, c in ipairs(model) do pcall(c.Disconnect) end
    end
    State.hitboxConns = {}
    for part, sz in pairs(State.originalSizes) do
        if part and part:IsA("BasePart") then
            part.Size = sz
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

local function getHead(model)
    return model and model:FindFirstChild("Head")
end

local function getBasePart(model)
    if not model then return nil end
    local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
    if part then return part end
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("BasePart") then return child end
    end
    return nil
end

-- ===== SCRAP FUNCTIONS =====
local function getScrapType(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return nil end
    local text = prompt.ObjectText or ""
    if text:find("Common", 1, true) then return "Common" end
    if text:find("Shiny", 1, true) then return "Shiny" end
    if text:find("Golden", 1, true) then return "Golden" end
    if text:find("Cursed", 1, true) then return "Cursed" end
    return nil
end

local function getScrapFolder()
    local map = Workspace:FindFirstChild("MAP")
    if not map then return nil end
    return map:FindFirstChild("Scraps")
end

local function getScrapColor(scrapType)
    if scrapType == "Common" then return Color3.fromRGB(139, 69, 19)
    elseif scrapType == "Shiny" then return Color3.fromRGB(192, 192, 192)
    elseif scrapType == "Golden" then return Color3.fromRGB(255, 215, 0)
    elseif scrapType == "Cursed" then return Color3.fromRGB(255, 0, 0)
    end
    return Color3.fromRGB(255,255,255)
end

-- ===== HITBOX =====
local function applyHitboxPart(part)
    if not part or not part:IsA("BasePart") then return end
    if not State.originalSizes[part] then State.originalSizes[part] = part.Size end
    part.Size = Vector3.new(State.hitboxSize, State.hitboxSize, State.hitboxSize)
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
        if child:IsA("BasePart") and child.Name == "Head" then applyHitboxPart(child) end
    end)
    table.insert(conns, childConn)
    local remConn = model.ChildRemoved:Connect(function(child)
        if child:IsA("BasePart") and child.Name == "Head" then revertHitboxPart(child) end
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
    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return end
    for _, m in ipairs(folder:GetChildren()) do
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

-- ===== NPC ESP =====
local npcFolder = Workspace:FindFirstChild("NPCs")

local function createESP(model)
    if not model or not model:IsA("Model") or State.espHighlights[model] then return end
    if model.Parent ~= npcFolder then return end

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.OutlineColor = Color3.fromRGB(255, 255, 0)
    hl.FillTransparency = 0.3
    hl.OutlineTransparency = 0
    hl.Adornee = model
    hl.Parent = model
    State.espHighlights[model] = hl

    local function createBillboard()
        if State.espBillboards[model] then return end
        local head = getHead(model)
        local parent = head or model
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
        bb.Parent = parent
        State.espBillboards[model] = bb
        return bb
    end

    createBillboard()

    if not getHead(model) then
        local conn = model.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") and child.Name == "Head" and not State.espBillboards[model] then
                createBillboard()
                conn:Disconnect()
            end
        end)
    end
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
    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return end
    npcFolder = folder
    for _, m in ipairs(folder:GetChildren()) do
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

-- ===== SHED ESP =====
local function applyShedESP(model)
    if not model:IsA("Model") or model.Name ~= "Shed" then return end
    if model.Parent ~= Workspace then return end
    if State.shedHighlights[model] then return end

    local adornPart = getBasePart(model)
    if not adornPart then
        task.spawn(function()
            local attempts = 0
            while attempts < 30 do
                task.wait(0.1)
                adornPart = getBasePart(model)
                if adornPart then break end
                attempts = attempts + 1
            end
            if adornPart and not State.shedHighlights[model] then
                applyShedESP(model)
            end
        end)
        return
    end

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

local function removeShedESP(model)
    if State.shedHighlights[model] then
        State.shedHighlights[model]:Destroy()
        State.shedHighlights[model] = nil
    end
    if State.shedBillboards[model] then
        State.shedBillboards[model]:Destroy()
        State.shedBillboards[model] = nil
    end
end

local function startShedESP()
    if State.shedESPActive then return end
    State.shedESPActive = true
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child.Name == "Shed" then applyShedESP(child) end
    end
end

local function stopShedESP()
    State.shedESPActive = false
    for model, _ in pairs(State.shedHighlights) do
        removeShedESP(model)
    end
    State.shedHighlights = {}
    State.shedBillboards = {}
end

-- ===== AIRDROP ESP =====
local function applyAirdropESP(model)
    if not model:IsA("Model") or model.Name ~= "Airdrop" then return end
    if model.Parent ~= Workspace then return end
    if State.airdropHighlights[model] then return end

    local adornPart = getBasePart(model)
    if not adornPart then
        task.spawn(function()
            local attempts = 0
            while attempts < 30 do
                task.wait(0.1)
                adornPart = getBasePart(model)
                if adornPart then break end
                attempts = attempts + 1
            end
            if adornPart and not State.airdropHighlights[model] then
                applyAirdropESP(model)
            end
        end)
        return
    end

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

local function removeAirdropESP(model)
    if State.airdropHighlights[model] then
        State.airdropHighlights[model]:Destroy()
        State.airdropHighlights[model] = nil
    end
    if State.airdropBillboards[model] then
        State.airdropBillboards[model]:Destroy()
        State.airdropBillboards[model] = nil
    end
end

local function startAirdropESP()
    if State.airdropESPActive then return end
    State.airdropESPActive = true
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child.Name == "Airdrop" then applyAirdropESP(child) end
    end
end

local function stopAirdropESP()
    State.airdropESPActive = false
    for model, _ in pairs(State.airdropHighlights) do
        removeAirdropESP(model)
    end
    State.airdropHighlights = {}
    State.airdropBillboards = {}
end

-- ===== BLACK MARKET ESP =====
local function isBlackMarket(instance)
    if not instance or not instance:IsA("Model") then return false end
    if instance.Name ~= "BlackMarket" then return false end
    local p = instance.Parent
    if not p or p.Name ~= "Structures" then return false end
    p = p.Parent
    if not p or p.Name ~= "MAIN" then return false end
    p = p.Parent
    if not p or p.Name ~= "MAP" then return false end
    p = p.Parent
    if not p or p ~= Workspace then return false end
    return true
end

local function applyBlackMarketESP(instance)
    if not isBlackMarket(instance) or State.blackMarketHighlights[instance] then return end

    local adornPart = getBasePart(instance)
    if not adornPart then
        task.spawn(function()
            local attempts = 0
            while attempts < 30 do
                task.wait(0.1)
                adornPart = getBasePart(instance)
                if adornPart then break end
                attempts = attempts + 1
            end
            if adornPart and not State.blackMarketHighlights[instance] then
                applyBlackMarketESP(instance)
            end
        end)
        return
    end

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
    if State.blackMarketHighlights[instance] then
        State.blackMarketHighlights[instance]:Destroy()
        State.blackMarketHighlights[instance] = nil
    end
    if State.blackMarketBillboards[instance] then
        State.blackMarketBillboards[instance]:Destroy()
        State.blackMarketBillboards[instance] = nil
    end
end

local function startBlackMarketESP()
    if State.blackMarketESPActive then return end
    State.blackMarketESPActive = true
    for _, child in ipairs(Workspace:GetDescendants()) do
        if isBlackMarket(child) then applyBlackMarketESP(child) end
    end
end

local function stopBlackMarketESP()
    State.blackMarketESPActive = false
    for instance, _ in pairs(State.blackMarketHighlights) do
        removeBlackMarketESP(instance)
    end
    State.blackMarketHighlights = {}
    State.blackMarketBillboards = {}
end

-- ===== STRUCTURE NOTIFIER =====
local function startStructNotifier()
    if State.structNotifierActive then return end
    State.structNotifierActive = true
end

local function stopStructNotifier()
    State.structNotifierActive = false
end

-- ===== AMMO =====
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
        pcall(function()
            if firesignal then
                firesignal(signal.OnClientEvent, "HandleAmmo", { Type = "ToMax" })
            end
        end)
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

-- ===== INFINITE STAMINA =====
local function getInfStamina()
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then
        Rayfield:Notify({ Title = "Error", Content = "Events folder not found!", Duration = 3 })
        return
    end
    local remoteEvent = events:FindFirstChild("I__NFSTA_AXDLOL")
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        pcall(function()
            if firesignal then
                firesignal(remoteEvent.OnClientEvent, true, math.huge)
            end
        end)
        Rayfield:Notify({ Title = "Stamina", Content = "Infinite Stamina activated!", Duration = 2 })
    else
        Rayfield:Notify({ Title = "Error", Content = "Stamina remote not found!", Duration = 3 })
    end
end

-- ===== NO RECOIL =====
local recoilModulePath = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("GunSystem") and ReplicatedStorage.Modules.GunSystem:FindFirstChild("Shared") and ReplicatedStorage.Modules.GunSystem.Shared:FindFirstChild("Recoil")
local Recoil = recoilModulePath and require(recoilModulePath)
local originalAccelerate = nil

local function enableNoRecoil()
    if not Recoil then
        Rayfield:Notify({ Title = "Error", Content = "Recoil module not found!", Duration = 3 })
        return
    end
    if not originalAccelerate then
        originalAccelerate = Recoil.Accelerate
        Recoil.Accelerate = function(self, ...)
            return {}
        end
        Rayfield:Notify({ Title = "No Recoil", Content = "Enabled", Duration = 2 })
    end
end

local function disableNoRecoil()
    if Recoil and originalAccelerate then
        Recoil.Accelerate = originalAccelerate
        originalAccelerate = nil
        Rayfield:Notify({ Title = "No Recoil", Content = "Disabled", Duration = 2 })
    end
end

-- ===== BARBED WIRE =====
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
        State.barbedWireChildConn:Disconnect()
        State.barbedWireChildConn = nil
    end
    restoreBarbedWireParts()
end

-- ===== RAGDOLL REMOVER =====
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

local function setupRagdollListener()
    if State.ragdollChildConn then
        State.ragdollChildConn:Disconnect()
        State.ragdollChildConn = nil
    end
    local folder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("RagdollParts")
    if folder then
        State.ragdollChildConn = folder.ChildAdded:Connect(function(child)
            if State.ragdollActive and child:IsA("BasePart") and child.Name == "RagdollPart" then
                removeRagdollPart(child)
            end
        end)
    end
end

local function startRagdollRemover()
    if State.ragdollActive then return end
    State.ragdollActive = true
    applyRagdollRemoval()
    setupRagdollListener()
    local filter = Workspace:FindFirstChild("Filter")
    if filter then
        if State.ragdollFolderConn then State.ragdollFolderConn:Disconnect() end
        State.ragdollFolderConn = filter.ChildAdded:Connect(function(child)
            if child.Name == "RagdollParts" then
                setupRagdollListener()
            end
        end)
    end
end

local function stopRagdollRemover()
    State.ragdollActive = false
    if State.ragdollChildConn then
        State.ragdollChildConn:Disconnect()
        State.ragdollChildConn = nil
    end
    if State.ragdollFolderConn then
        State.ragdollFolderConn:Disconnect()
        State.ragdollFolderConn = nil
    end
    restoreRagdollParts()
end

-- ===== FULLBRIGHT =====
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

-- ===== INSTANT PROX =====
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

-- ===== ORBIT =====
local function findNearestNPC()
    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return nil end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pos = hrp.Position
    local best, bestDist = nil, math.huge
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then
            local root = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChild("Head") or child:FindFirstChildWhichIsA("BasePart")
            if root and root:IsA("BasePart") then
                local d = (root.Position - pos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = child
                end
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
        local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart")
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

-- ===== SCRAP ESP =====
local function applyScrapESP(basePart)
    if not basePart or not basePart:IsA("BasePart") then return end
    if basePart.Name ~= "Base" then return end

    local scrapFolder = getScrapFolder()
    if not scrapFolder then return end
    if not basePart:IsDescendantOf(scrapFolder) then return end

    local scrapModel = basePart.Parent
    if not scrapModel or not scrapModel:IsA("Model") then return end

    local prompt = scrapModel:FindFirstChild("ProximityPrompt", true)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end

    local scrapType = getScrapType(prompt)
    if not scrapType or not State.scrapESPTypes[scrapType] then return end
    if State.scrapHighlights[basePart] then return end

    local color = getScrapColor(scrapType)

    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.2
    hl.OutlineTransparency = 0
    hl.Adornee = basePart
    hl.Parent = basePart
    State.scrapHighlights[basePart] = hl

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
    bb.Parent = basePart
    State.scrapBillboards[basePart] = bb
end

local function removeScrapESP(basePart)
    if State.scrapHighlights[basePart] then
        State.scrapHighlights[basePart]:Destroy()
        State.scrapHighlights[basePart] = nil
    end
    if State.scrapBillboards[basePart] then
        State.scrapBillboards[basePart]:Destroy()
        State.scrapBillboards[basePart] = nil
    end
end

local function refreshScrapESP()
    local folder = getScrapFolder()
    if not folder then return end
    for part, hl in pairs(State.scrapHighlights) do
        if hl then hl:Destroy() end
    end
    State.scrapHighlights = {}
    for part, bb in pairs(State.scrapBillboards) do
        if bb then bb:Destroy() end
    end
    State.scrapBillboards = {}
    if not State.scrapESPActive then return end
    for _, basePart in ipairs(folder:GetDescendants()) do
        if basePart:IsA("BasePart") and basePart.Name == "Base" then
            applyScrapESP(basePart)
        end
    end
end

local function startScrapESP()
    if State.scrapESPActive then return end
    State.scrapESPActive = true
    local folder = getScrapFolder()
    if not folder then return end
    refreshScrapESP()
end

local function stopScrapESP()
    State.scrapESPActive = false
    for part, hl in pairs(State.scrapHighlights) do
        if hl then hl:Destroy() end
    end
    State.scrapHighlights = {}
    for part, bb in pairs(State.scrapBillboards) do
        if bb then bb:Destroy() end
    end
    State.scrapBillboards = {}
end

-- ===== SCRAP TP =====
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

local function getAllScrapsOfTypes(types)
    local list = {}
    local folder = getScrapFolder()
    if not folder then return list end
    for _, basePart in ipairs(folder:GetDescendants()) do
        if basePart:IsA("BasePart") and basePart.Name == "Base" then
            local scrapModel = basePart.Parent
            if scrapModel and scrapModel:IsA("Model") then
                local prompt = scrapModel:FindFirstChild("ProximityPrompt", true)
                if prompt and prompt:IsA("ProximityPrompt") then
                    local typ = getScrapType(prompt)
                    if typ and State.scrapTPTypes[typ] and types[typ] then
                        if basePart.Transparency < 0.5 then
                            table.insert(list, basePart)
                        end
                    end
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
                    local scrapModel = base.Parent
                    local prompt = scrapModel and scrapModel:FindFirstChild("ProximityPrompt", true)
                    if not prompt then continue end
                    local typ = getScrapType(prompt)
                    if not typ or not State.scrapTPTypes[typ] then continue end
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

-- ===== TELEPORT COORDINATES =====
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

local function findNearestStructure(name, strictParentCheck)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pos = hrp.Position
    local best, bestDist = nil, math.huge
    if name == "Shed" or name == "Airdrop" then
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Model") and child.Name == name then
                local root = child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart or child:FindFirstChild("Head") or child:FindFirstChildWhichIsA("BasePart")
                if root and root:IsA("BasePart") then
                    local d = (root.Position - pos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = child
                    end
                end
            end
        end
    elseif name == "BlackMarket" then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == name then
                local p = obj.Parent
                if not p or p.Name ~= "Structures" then continue end
                p = p.Parent
                if not p or p.Name ~= "MAIN" then continue end
                p = p.Parent
                if not p or p.Name ~= "MAP" then continue end
                p = p.Parent
                if not p or p ~= Workspace then continue end
                local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChild("Head") or obj:FindFirstChildWhichIsA("BasePart")
                if root and root:IsA("BasePart") then
                    local d = (root.Position - pos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = obj
                    end
                end
            end
        end
    end
    return best
end

local function teleportToStructure(name, strictParentCheck)
    local structure = findNearestStructure(name, strictParentCheck)
    if not structure then
        Rayfield:Notify({ Title = "Teleport", Content = "No " .. name .. " found nearby!", Duration = 3 })
        return
    end
    local root = structure:FindFirstChild("HumanoidRootPart") or structure.PrimaryPart or structure:FindFirstChild("Head") or structure:FindFirstChildWhichIsA("BasePart")
    if not root or not root:IsA("BasePart") then
        Rayfield:Notify({ Title = "Teleport", Content = "Cannot find root part of " .. name, Duration = 3 })
        return
    end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        Rayfield:Notify({ Title = "Teleport", Content = "No character", Duration = 3 })
        return
    end
    local targetPos = root.Position + Vector3.new(0, 5, 0)
    char.HumanoidRootPart.CFrame = CFrame.new(targetPos)
    Rayfield:Notify({ Title = "Teleport", Content = "Teleported to " .. name, Duration = 2 })
end

-- ===== ЕДИНЫЙ ОБРАБОТЧИК =====
local function onDescendantAdded(desc)
    if not desc or not desc:IsA("Instance") then return end
    if desc:IsA("Model") then
        -- NPC ESP
        if State.espEnabled and npcFolder and desc.Parent == npcFolder then
            createESP(desc)
        end
        if State.hitboxEnabled and npcFolder and desc.Parent == npcFolder then
            applyHitboxToModel(desc)
        end

        -- Shed
        if State.shedESPActive and desc.Name == "Shed" and desc.Parent == Workspace and not State.shedHighlights[desc] then
            applyShedESP(desc)
        end
        -- Airdrop
        if State.airdropESPActive and desc.Name == "Airdrop" and desc.Parent == Workspace and not State.airdropHighlights[desc] then
            applyAirdropESP(desc)
        end
        -- Black Market
        if State.blackMarketESPActive and isBlackMarket(desc) and not State.blackMarketHighlights[desc] then
            applyBlackMarketESP(desc)
        end

        -- Structure Notifier
        if State.structNotifierActive then
            if desc.Name == "Shed" and desc.Parent == Workspace then
                Rayfield:Notify({ Title = "Structure", Content = "Shed spawned!", Duration = 3 })
            end
            if desc.Name == "Airdrop" and desc.Parent == Workspace then
                Rayfield:Notify({ Title = "Structure", Content = "Airdrop spawned!", Duration = 3 })
            end
            if isBlackMarket(desc) then
                Rayfield:Notify({ Title = "Structure", Content = "Black Market spawned!", Duration = 3 })
            end
        end
    end

    -- Scrap ESP
    if State.scrapESPActive and desc:IsA("BasePart") and desc.Name == "Base" then
        local scrapFolder = getScrapFolder()
        if scrapFolder and desc:IsDescendantOf(scrapFolder) then
            applyScrapESP(desc)
        end
    end

    -- Structure Notifier for Cursed Scrap
    if State.structNotifierActive and desc:IsA("ProximityPrompt") then
        local parentModel = desc.Parent and desc.Parent.Parent
        if parentModel and parentModel:IsA("Model") then
            local typ = getScrapType(desc)
            if typ == "Cursed" then
                Rayfield:Notify({ Title = "Scrap", Content = "Cursed Scrap spawned!", Duration = 3 })
            end
        end
    end
end

local function onDescendantRemoved(desc)
    if not desc or not desc:IsA("Instance") then return end
    if desc:IsA("Model") then
        if State.espEnabled and npcFolder and desc.Parent == npcFolder then
            removeESP(desc)
        end
        if State.hitboxEnabled and npcFolder and desc.Parent == npcFolder then
            removeHitboxFromModel(desc)
        end
        if State.shedESPActive and desc.Name == "Shed" and desc.Parent == Workspace then
            removeShedESP(desc)
        end
        if State.airdropESPActive and desc.Name == "Airdrop" and desc.Parent == Workspace then
            removeAirdropESP(desc)
        end
        if State.blackMarketESPActive and isBlackMarket(desc) then
            removeBlackMarketESP(desc)
        end
    end
    if State.scrapESPActive and desc:IsA("BasePart") and desc.Name == "Base" then
        local scrapFolder = getScrapFolder()
        if scrapFolder and desc:IsDescendantOf(scrapFolder) then
            removeScrapESP(desc)
        end
    end
end

local function setupGlobalListeners()
    if State.mainDescConn then State.mainDescConn:Disconnect() end
    if State.mainRemConn then State.mainRemConn:Disconnect() end
    State.mainDescConn = Workspace.DescendantAdded:Connect(onDescendantAdded)
    State.mainRemConn = Workspace.DescendantRemoving:Connect(onDescendantRemoved)
end

setupGlobalListeners()

-- ===== ПЕРЕПОДПИСКА ПОСЛЕ РЕСПАВНА =====
local function respawnHandler()
    task.wait(0.5)
    npcFolder = Workspace:FindFirstChild("NPCs")
    if not npcFolder then
        npcFolder = Workspace:WaitForChild("NPCs", 5)
    end
    if npcFolder then
        if State.hitboxEnabled then
            removeHitboxAll()
            applyHitboxAll()
        end
        if State.espEnabled then
            removeESPAll()
            applyESPAll()
        end
        setupGlobalListeners()
    else
        warn("NPCs folder not found after respawn!")
    end
    if State.ragdollActive then
        setupRagdollListener()
        applyRagdollRemoval()
    end
end

player.CharacterAdded:Connect(respawnHandler)

-- ===== DESTROY =====
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
    removeESPAll()
    removeHitboxAll()
    if State.mainDescConn then State.mainDescConn:Disconnect() end
    if State.mainRemConn then State.mainRemConn:Disconnect() end
    State.destroying = false
end

-- ===== UI ЭЛЕМЕНТЫ (RAYFIELD) =====

-- ===== MAIN TAB =====
local MainLeft = Tabs.Main:CreateSection("NPC Features")

Tabs.Main:CreateToggle({
    Name = "Hitbox Expander",
    CurrentValue = false,
    Callback = function(Value)
        State.hitboxEnabled = Value
        if State.hitboxEnabled then
            removeHitboxAll()
            applyHitboxAll()
            Rayfield:Notify({ Title = "Hitbox", Content = "Enabled", Duration = 2 })
        else
            removeHitboxAll()
            Rayfield:Notify({ Title = "Hitbox", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateSlider({
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

Tabs.Main:CreateToggle({
    Name = "NPC ESP",
    CurrentValue = false,
    Callback = function(Value)
        State.espEnabled = Value
        if State.espEnabled then
            removeESPAll()
            applyESPAll()
            Rayfield:Notify({ Title = "NPC ESP", Content = "Enabled", Duration = 2 })
        else
            removeESPAll()
            Rayfield:Notify({ Title = "NPC ESP", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Orbit Spin",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startOrbit()
            Rayfield:Notify({ Title = "Orbit", Content = "Enabled", Duration = 2 })
        else
            stopOrbit()
            Rayfield:Notify({ Title = "Orbit", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateSlider({
    Name = "Orbit Radius",
    Range = {0, 200},
    Increment = 1,
    Suffix = "",
    CurrentValue = 80,
    Callback = function(Value)
        State.orbitRadius = Value
    end
})

Tabs.Main:CreateSlider({
    Name = "Orbit Speed",
    Range = {0, 2},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0.1,
    Callback = function(Value)
        State.orbitSpeed = Value
    end
})

local gunsSection = Tabs.Main:CreateSection("Guns Utilities")

Tabs.Main:CreateButton({
    Name = "Give Ammo",
    Callback = function()
        giveAmmoOnce()
        Rayfield:Notify({ Title = "Ammo", Content = "Given", Duration = 2 })
    end
})

Tabs.Main:CreateToggle({
    Name = "Loop Ammo",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startAmmoLoop()
            Rayfield:Notify({ Title = "Loop Ammo", Content = "Enabled", Duration = 2 })
        else
            stopAmmoLoop()
            Rayfield:Notify({ Title = "Loop Ammo", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
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

local playerSection = Tabs.Main:CreateSection("Player Utilities")

Tabs.Main:CreateButton({
    Name = "Infinite Stamina",
    Callback = function()
        getInfStamina()
    end
})

Tabs.Main:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startFullbright()
            Rayfield:Notify({ Title = "Fullbright", Content = "Enabled", Duration = 2 })
        else
            stopFullbright()
            Rayfield:Notify({ Title = "Fullbright", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Instant Prox. Prompts",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startInstantProx()
            Rayfield:Notify({ Title = "Instant Prox", Content = "Enabled", Duration = 2 })
        else
            stopInstantProx()
            Rayfield:Notify({ Title = "Instant Prox", Content = "Disabled", Duration = 2 })
        end
    end
})

local worldSection = Tabs.Main:CreateSection("World Utilities")

Tabs.Main:CreateToggle({
    Name = "Shed ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startShedESP()
            Rayfield:Notify({ Title = "Shed ESP", Content = "Enabled", Duration = 2 })
        else
            stopShedESP()
            Rayfield:Notify({ Title = "Shed ESP", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Airdrop ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startAirdropESP()
            Rayfield:Notify({ Title = "Airdrop ESP", Content = "Enabled", Duration = 2 })
        else
            stopAirdropESP()
            Rayfield:Notify({ Title = "Airdrop ESP", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Black Market ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startBlackMarketESP()
            Rayfield:Notify({ Title = "Black Market ESP", Content = "Enabled", Duration = 2 })
        else
            stopBlackMarketESP()
            Rayfield:Notify({ Title = "Black Market ESP", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Structure Notifier",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startStructNotifier()
            Rayfield:Notify({ Title = "Notifier", Content = "Enabled", Duration = 2 })
        else
            stopStructNotifier()
            Rayfield:Notify({ Title = "Notifier", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Remove Barbed Wire",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startBarbedWireRemover()
            Rayfield:Notify({ Title = "Barbed Wire", Content = "Removed", Duration = 2 })
        else
            stopBarbedWireRemover()
            Rayfield:Notify({ Title = "Barbed Wire", Content = "Restored", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Remove Ragdoll Parts",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startRagdollRemover()
            Rayfield:Notify({ Title = "Ragdoll", Content = "Removed", Duration = 2 })
        else
            stopRagdollRemover()
            Rayfield:Notify({ Title = "Ragdoll", Content = "Restored", Duration = 2 })
        end
    end
})

-- ===== SCRAPS TAB =====
local ScrapLeft = Tabs.Scraps:CreateSection("Scrap ESP")

Tabs.Scraps:CreateToggle({
    Name = "Scrap ESP",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startScrapESP()
            Rayfield:Notify({ Title = "Scrap ESP", Content = "Enabled", Duration = 2 })
        else
            stopScrapESP()
            Rayfield:Notify({ Title = "Scrap ESP", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Scraps:CreateLabel("Filter types to show:")

Tabs.Scraps:CreateToggle({
    Name = "Common",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapESPTypes.Common = Value
        if Toggles.ScrapESP.Value then refreshScrapESP() end
    end
})

Tabs.Scraps:CreateToggle({
    Name = "Shiny",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapESPTypes.Shiny = Value
        if Toggles.ScrapESP.Value then refreshScrapESP() end
    end
})

Tabs.Scraps:CreateToggle({
    Name = "Golden",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapESPTypes.Golden = Value
        if Toggles.ScrapESP.Value then refreshScrapESP() end
    end
})

Tabs.Scraps:CreateToggle({
    Name = "Cursed",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapESPTypes.Cursed = Value
        if Toggles.ScrapESP.Value then refreshScrapESP() end
    end
})

local scrapTPSection = Tabs.Scraps:CreateSection("Scrap Teleport")

Tabs.Scraps:CreateToggle({
    Name = "Scrap Teleport",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startScrapTP()
            Rayfield:Notify({ Title = "Scrap TP", Content = "Enabled", Duration = 2 })
        else
            stopScrapTP()
            Rayfield:Notify({ Title = "Scrap TP", Content = "Disabled", Duration = 2 })
        end
    end
})

Tabs.Scraps:CreateLabel("Types to teleport to:")

Tabs.Scraps:CreateToggle({
    Name = "Common",
    CurrentValue = false,
    Callback = function(Value)
        State.scrapTPTypes.Common = Value
    end
})

Tabs.Scraps:CreateToggle({
    Name = "Shiny",
    CurrentValue = false,
    Callback = function(Value)
        State.scrapTPTypes.Shiny = Value
    end
})

Tabs.Scraps:CreateToggle({
    Name = "Golden",
    CurrentValue = true,
    Callback = function(Value)
        State.scrapTPTypes.Golden = Value
    end
})

local teleportSection = Tabs.Scraps:CreateSection("Teleports")

Tabs.Scraps:CreateButton({
    Name = "TP to Shop",
    Callback = function()
        teleportTo(SHOP_POS)
        Rayfield:Notify({ Title = "Teleport", Content = "To Shop", Duration = 2 })
    end
})

Tabs.Scraps:CreateButton({
    Name = "TP to Power Station",
    Callback = function()
        teleportTo(POWER_STATION)
        Rayfield:Notify({ Title = "Teleport", Content = "To Power Station", Duration = 2 })
    end
})

Tabs.Scraps:CreateButton({
    Name = "TP to Lake",
    Callback = function()
        teleportTo(LAKE)
        Rayfield:Notify({ Title = "Teleport", Content = "To Lake", Duration = 2 })
    end
})

Tabs.Scraps:CreateButton({
    Name = "TP to Bunker",
    Callback = function()
        teleportTo(BUNKER)
        Rayfield:Notify({ Title = "Teleport", Content = "To Bunker", Duration = 2 })
    end
})

Tabs.Scraps:CreateButton({
    Name = "TP Inside Bunker",
    Callback = function()
        teleportTo(BUNKER_INSIDE)
        Rayfield:Notify({ Title = "Teleport", Content = "Inside Bunker", Duration = 2 })
    end
})

Tabs.Scraps:CreateButton({
    Name = "TP to Scrap Building",
    Callback = function()
        teleportTo(SCRAP_BUILDING)
        Rayfield:Notify({ Title = "Teleport", Content = "To Scrap Building", Duration = 2 })
    end
})

Tabs.Scraps:CreateButton({
    Name = "TP to Shed",
    Callback = function()
        teleportToStructure('Shed', false)
    end
})

Tabs.Scraps:CreateButton({
    Name = "TP to Airdrop",
    Callback = function()
        teleportToStructure('Airdrop', false)
    end
})

Tabs.Scraps:CreateButton({
    Name = "TP to Black Market",
    Callback = function()
        teleportToStructure('BlackMarket', true)
    end
})

-- ===== CUSTOM TELEPORT =====
local CustomGroup = Tabs.Scraps:CreateSection("Custom Teleports")
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
            Rayfield:Notify({ Title = "Teleport", Content = "To " .. name, Duration = 2 })
        end
    end
end

local teleportListDropdown
local function updateTeleportList()
    local names = {}
    for _, data in pairs(savedPositions) do
        if data.name then table.insert(names, data.name) end
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

Tabs.Scraps:CreateInput({
    Name = "Position Name",
    PlaceholderText = "Placeholder",
    Callback = function(Value)
        _G.customTeleportName = Value
    end
})

Tabs.Scraps:CreateButton({
    Name = "Save Current Position",
    Callback = function()
        local name = _G.customTeleportName or generateDefaultName()
        if savedPositions[name] then
            Rayfield:Notify({ Title = "Error", Content = "Name already exists!", Duration = 2 })
            return
        end
        if saveCurrentPosition(name) then
            updateTeleportList()
            Rayfield:Notify({ Title = "Saved", Content = "Position " .. name, Duration = 2 })
        else
            Rayfield:Notify({ Title = "Error", Content = "Failed to save (no character?)", Duration = 2 })
        end
    end
})

teleportListDropdown = Tabs.Scraps:CreateDropdown({
    Name = "Saved Positions",
    Options = {},
    CurrentOption = "",
    Callback = function(Option)
        _G.selectedTeleport = Option
    end
})
updateTeleportList()

Tabs.Scraps:CreateButton({
    Name = "Teleport to Selected",
    Callback = function()
        if _G.selectedTeleport then
            teleportToSaved(_G.selectedTeleport)
        else
            Rayfield:Notify({ Title = "Error", Content = "No position selected", Duration = 2 })
        end
    end
})

Tabs.Scraps:CreateButton({
    Name = "Delete Selected",
    Callback = function()
        if _G.selectedTeleport and savedPositions[_G.selectedTeleport] then
            deleteSavedPosition(_G.selectedTeleport)
            updateTeleportList()
            Rayfield:Notify({ Title = "Deleted", Content = _G.selectedTeleport, Duration = 2 })
            _G.selectedTeleport = nil
        else
            Rayfield:Notify({ Title = "Error", Content = "No position selected or does not exist", Duration = 2 })
        end
    end
})

-- ===== SETTINGS TAB =====
local settingsSection = Tabs.Settings:CreateSection("General Settings")

Tabs.Settings:CreateLabel("The Revenant: Sunrisen Gui")
Tabs.Settings:CreateLabel("Mobile version")
Tabs.Settings:CreateLabel("version V1.2")

Tabs.Settings:CreateDivider()

local themeDropdown = Tabs.Settings:CreateDropdown({
    Name = "Theme",
    Options = {"Default", "Ocean", "Serpents", "Amethyst", "Midnight", "Synthwave"},
    CurrentOption = "Default",
    Callback = function(Option)
        pcall(function()
            Rayfield:SetTheme(Option)
        end)
        Rayfield:Notify({ Title = "Theme", Content = "Changed to " .. Option, Duration = 2 })
    end
})

Tabs.Settings:CreateButton({
    Name = "Unload Script",
    Callback = function()
        destroyEverything()
        Rayfield:Destroy()
        _G.RevenantGui_Kill = true
    end
})

-- ===== ЗАГРУЗКА КОНФИГУРАЦИИ =====
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title = "Loaded",
    Content = "The Revenant: Sunrisen Mobile",
    Duration = 3
})

print("The Revenant: Sunrisen GUI (Mobile) loaded successfully!")
