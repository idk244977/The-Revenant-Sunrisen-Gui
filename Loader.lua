local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local PC_URL = "https://raw.githubusercontent.com/idk244977/The-Revenant-Sunrisen-Gui/refs/heads/revenant/The%20Revenant-Sunrisen%20Gui.lua"
local MOBILE_URL = "https://raw.githubusercontent.com/idk244977/The-Revenant-Sunrisen-Gui/refs/heads/revenant/Mobile%20version.lua"

-- Premium Dark Forest Palette
local BG_DARK = Color3.fromRGB(14, 18, 16)
local PANEL_BG = Color3.fromRGB(22, 30, 26)
local ACCENT_GREEN = Color3.fromRGB(46, 213, 115)
local BORDER_GREEN = Color3.fromRGB(38, 54, 46)
local TEXT_WHITE = Color3.fromRGB(245, 247, 246)
local ERROR_RED = Color3.fromRGB(255, 71, 87)

local FONT_BOLD = Enum.Font.GothamBold
local FONT_REGULAR = Enum.Font.Gotham

local function fetchURL(url)
    local methods = {
        function() return httpget(url, "GET") end,
        function() return httpget(url) end,
        function() return game:HttpGet(url) end,
    }
    for _, method in ipairs(methods) do
        local success, result = pcall(method)
        if success and result and result ~= "" then
            return result
        end
    end
    error("All HTTP methods failed.")
end

-- Procedural Spinner Creator (No assets, pure code UI)
local function createProceduralSpinner(parent, size, position)
    local spinnerFrame = Instance.new("Frame")
    spinnerFrame.Size = size
    spinnerFrame.Position = position
    spinnerFrame.BackgroundTransparency = 1
    spinnerFrame.Parent = parent

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = spinnerFrame

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = ACCENT_GREEN
    uiStroke.Thickness = 3
    uiStroke.Parent = spinnerFrame

    local uiGradient = Instance.new("UIGradient")
    uiGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.8),
        NumberSequenceKeypoint.new(1, 1)
    })
    uiGradient.Parent = spinnerFrame

    return spinnerFrame
end

-- Main Interface Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RevenantLoader"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 500, 0, 400)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
mainFrame.BackgroundColor3 = BG_DARK
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

local border = Instance.new("UIStroke")
border.Color = BORDER_GREEN
border.Thickness = 1.5
border.Parent = mainFrame

-- Subtle Ambient Shadow
local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.new(0, -15, 0, -15)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.6
shadow.BorderSizePixel = 0
shadow.ZIndex = 0
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 20)
shadowCorner.Parent = shadow
shadow.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -42, 0, 12)
closeBtn.BackgroundColor3 = PANEL_BG
closeBtn.Text = "×"
closeBtn.TextColor3 = TEXT_WHITE
closeBtn.Font = FONT_REGULAR
closeBtn.TextSize = 24
closeBtn.AutoButtonColor = false
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = BORDER_GREEN
closeStroke.Thickness = 1
closeStroke.Parent = closeBtn
closeBtn.Parent = mainFrame

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = ERROR_RED, TextColor3 = Color3.new(1,1,1)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = PANEL_BG, TextColor3 = TEXT_WHITE}):Play()
end)

-- Initial Preloader
local preloader = Instance.new("Frame")
preloader.Size = UDim2.new(1, 0, 1, 0)
preloader.BackgroundTransparency = 1
preloader.ZIndex = 10
preloader.Parent = mainFrame

local mainSpinner = createProceduralSpinner(preloader, UDim2.new(0, 48, 0, 48), UDim2.new(0.5, -24, 0.5, -24))
local spinnerTween = TweenService:Create(mainSpinner, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
spinnerTween:Play()

-- Content Container
local contentGroup = Instance.new("Frame")
contentGroup.Name = "ContentGroup"
contentGroup.Size = UDim2.new(1, 0, 1, 0)
contentGroup.BackgroundTransparency = 1
contentGroup.Visible = false
contentGroup.Parent = mainFrame

-- Typography
local titleContainer = Instance.new("Frame")
titleContainer.Size = UDim2.new(1, -40, 0, 48)
titleContainer.Position = UDim2.new(0, 20, 0, 32)
titleContainer.BackgroundTransparency = 1
titleContainer.Parent = contentGroup

local textRevenant = Instance.new("TextLabel")
textRevenant.Size = UDim2.new(0, 190, 1, 0)
textRevenant.Position = UDim2.new(0.5, -145, 0, 0)
textRevenant.BackgroundTransparency = 1
textRevenant.Text = "The Revenant: "
textRevenant.TextColor3 = TEXT_WHITE
textRevenant.Font = FONT_BOLD
textRevenant.TextSize = 30
textRevenant.TextXAlignment = Enum.TextXAlignment.Right
textRevenant.Parent = titleContainer

local textSunrisen = Instance.new("TextLabel")
textSunrisen.Size = UDim2.new(0, 100, 1, 0)
textSunrisen.Position = UDim2.new(0.5, 45, 0, 0)
textSunrisen.BackgroundTransparency = 1
textSunrisen.Text = "Sunrisen"
textSunrisen.TextColor3 = ERROR_RED
textSunrisen.Font = FONT_BOLD
textSunrisen.TextSize = 30
textSunrisen.TextXAlignment = Enum.TextXAlignment.Left
textSunrisen.Parent = titleContainer

local subTitle = Instance.new("TextLabel")
subTitle.Size = UDim2.new(1, -40, 0, 30)
subTitle.Position = UDim2.new(0, 20, 0, 80)
subTitle.BackgroundTransparency = 1
subTitle.Text = "Gui Loader"
subTitle.TextColor3 = ACCENT_GREEN
subTitle.Font = FONT_BOLD
subTitle.TextSize = 24
subTitle.Parent = contentGroup

-- Interface Buttons
local function createModernButton(name, text, yPos)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 320, 0, 50)
    btn.Position = UDim2.new(0.5, -160, 0, yPos)
    btn.BackgroundColor3 = PANEL_BG
    btn.Text = text
    btn.TextColor3 = TEXT_WHITE
    btn.Font = FONT_BOLD
    btn.TextSize = 18
    btn.AutoButtonColor = false
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = btn
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = BORDER_GREEN
    btnStroke.Thickness = 1
    btnStroke.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(28, 38, 33)}):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.2), {Color = ACCENT_GREEN}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = PANEL_BG}):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.2), {Color = BORDER_GREEN}):Play()
    end)
    
    return btn
end

local pcButton = createModernButton("PcButton", "Load PC Version", 145)
pcButton.Parent = contentGroup

local mobileButton = createModernButton("MobileButton", "Load Mobile Version", 210)
mobileButton.Parent = contentGroup

-- Status & Attribution
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 24)
statusLabel.Position = UDim2.new(0, 20, 1, -60)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = Color3.fromRGB(140, 155, 148)
statusLabel.Font = FONT_REGULAR
statusLabel.TextSize = 14
statusLabel.Parent = contentGroup

local watermark = Instance.new("TextLabel")
watermark.Size = UDim2.new(1, -40, 0, 24)
watermark.Position = UDim2.new(0, 20, 1, -32)
watermark.BackgroundTransparency = 1
watermark.Text = "All scripts made by idk244977"
watermark.TextColor3 = ERROR_RED
watermark.Font = FONT_REGULAR
watermark.TextSize = 15
watermark.Parent = contentGroup

local function animateWatermark()
    local t1 = TweenService:Create(watermark, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextColor3 = ACCENT_GREEN, TextSize = 16})
    local t2 = TweenService:Create(watermark, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextColor3 = ERROR_RED, TextSize = 15})
    t1:Play()
    t1.Completed:Connect(function()
        t2:Play()
        t2.Completed:Connect(animateWatermark)
    end)
end
animateWatermark()

-- Interactive Action Spinner
local actionSpinner = createProceduralSpinner(contentGroup, UDim2.new(0, 24, 0, 24), UDim2.new(0.5, -12, 1, -92))
actionSpinner.Visible = false
local actionSpinnerTween

local function startActionSpinner()
    actionSpinner.Visible = true
    actionSpinner.Rotation = 0
    actionSpinnerTween = TweenService:Create(actionSpinner, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
    actionSpinnerTween:Play()
end

local function stopActionSpinner()
    if actionSpinnerTween then actionSpinnerTween:Cancel(); actionSpinnerTween = nil end
    actionSpinner.Visible = false
end

-- Loader Logic Sequence
local function loadFromURL(url)
    if not url or url == "" then
        statusLabel.Text = "Error: No URL Provided"
        return
    end
    
    pcButton.Active = false
    mobileButton.Active = false
    TweenService:Create(pcButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.5, TextTransparency = 0.5}):Play()
    TweenService:Create(mobileButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.5, TextTransparency = 0.5}):Play()
    
    statusLabel.Text = "Downloading script structure..."
    startActionSpinner()

    local success, content = pcall(fetchURL, url)
    if not success then
        statusLabel.Text = "Network Error: " .. tostring(content)
        stopActionSpinner()
        pcButton.Active = true
        mobileButton.Active = true
        pcButton.BackgroundTransparency, mobileButton.BackgroundTransparency = 0, 0
        pcButton.TextTransparency, mobileButton.TextTransparency = 0, 0
        return
    end

    statusLabel.Text = "Compiling bytecode..."
    local loadSuccess, compiled = pcall(loadstring, content)
    if not loadSuccess or not compiled then
        statusLabel.Text = "Compilation Error: Script compilation failed"
        stopActionSpinner()
        pcButton.Active = true
        mobileButton.Active = true
        pcButton.BackgroundTransparency, mobileButton.BackgroundTransparency = 0, 0
        pcButton.TextTransparency, mobileButton.TextTransparency = 0, 0
        return
    end

    statusLabel.Text = "Executing environment..."
    local execSuccess, result = pcall(compiled)
    stopActionSpinner()
    
    if not execSuccess then
        statusLabel.Text = "Runtime Error: " .. tostring(result)
        pcButton.Active = true
        mobileButton.Active = true
        pcButton.BackgroundTransparency, mobileButton.BackgroundTransparency = 0, 0
        pcButton.TextTransparency, mobileButton.TextTransparency = 0, 0
        return
    end

    statusLabel.Text = "Successfully Loaded!"
    local fadeOut = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1
    })
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        screenGui:Destroy()
    end)
end

pcButton.MouseButton1Click:Connect(function() loadFromURL(PC_URL) end)
mobileButton.MouseButton1Click:Connect(function() loadFromURL(MOBILE_URL) end)

-- Presentation Intro Animation
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.Rotation = -4
mainFrame.Parent = screenGui

local tweenIn = TweenService:Create(mainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 500, 0, 400),
    BackgroundTransparency = 0,
    Rotation = 0
})
tweenIn:Play()

task.wait(0.7)

local fadePre = TweenService:Create(preloader, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    BackgroundTransparency = 1
})
fadePre:Play()
fadePre.Completed:Connect(function()
    preloader:Destroy()
    contentGroup.Visible = true
    contentGroup.Position = UDim2.new(0, 0, 0.05, 0)
    
    TweenService:Create(contentGroup, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
end)

-- Mount Context Mapping
local targetPlayer = Players.LocalPlayer
if targetPlayer then
    local playerGui = targetPlayer:FindFirstChildOfClass("PlayerGui")
    screenGui.Parent = playerGui or game:GetService("CoreGui")
else
    screenGui.Parent = game:GetService("CoreGui")
end