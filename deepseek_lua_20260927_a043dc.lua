--[[
    ============================================================
    NEXUS UI - A complete custom Roblox UI framework
    Built from scratch. No external UI libraries used.
    ============================================================
]]

-- ============================================================
-- SECTION 1: SERVICES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local StatsService = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- SECTION 2: CONFIGURATION
-- ============================================================
local CONFIG = {
    Name = "Nexus",
    Version = "1.0.0",
    Author = "Nexus",
    DefaultToggleKey = Enum.KeyCode.RightShift,
    DefaultUIScale = 1.0,
    SaveFileName = "NexusConfig.json",
    MaxNotifications = 6,
    NotificationDuration = 4,
    WindowSize = Vector2.new(620, 440),
    SidebarWidth = 160,
    TopBarHeight = 34,
    Padding = 10,
}

-- ============================================================
-- SECTION 3: STATE
-- ============================================================
local State = {
    Ready = false,
    Visible = true,
    Minimized = false,
    CurrentTab = nil,
    UIScale = CONFIG.DefaultUIScale,
    AnimationsEnabled = true,
    NotificationsEnabled = true,
    ThemeName = "Dark",
    ToggleKey = CONFIG.DefaultToggleKey,
    Connections = {},
    Instances = {},
    Loops = {},
    Threads = {},
    Features = {},
    SavedConfig = {},
    ConfigPersistence = false,
    DroppedFrames = 0,
}

-- ============================================================
-- SECTION 4: THEME SYSTEM
-- ============================================================
local Themes = {
    Dark = {
        Background = Color3.fromRGB(20, 20, 24),
        SecondaryBackground = Color3.fromRGB(28, 28, 34),
        TertiaryBackground = Color3.fromRGB(36, 36, 44),
        Text = Color3.fromRGB(240, 240, 245),
        SecondaryText = Color3.fromRGB(150, 150, 165),
        Accent = Color3.fromRGB(88, 132, 255),
        Border = Color3.fromRGB(46, 46, 56),
        Hover = Color3.fromRGB(44, 44, 54),
        Active = Color3.fromRGB(56, 56, 68),
        Notification = Color3.fromRGB(40, 40, 48),
        Success = Color3.fromRGB(76, 200, 120),
        Warning = Color3.fromRGB(230, 180, 70),
        Error = Color3.fromRGB(230, 90, 90),
    },
    Midnight = {
        Background = Color3.fromRGB(12, 14, 22),
        SecondaryBackground = Color3.fromRGB(18, 22, 34),
        TertiaryBackground = Color3.fromRGB(26, 30, 46),
        Text = Color3.fromRGB(230, 235, 245),
        SecondaryText = Color3.fromRGB(140, 150, 175),
        Accent = Color3.fromRGB(120, 100, 255),
        Border = Color3.fromRGB(38, 44, 62),
        Hover = Color3.fromRGB(34, 40, 58),
        Active = Color3.fromRGB(44, 52, 74),
        Notification = Color3.fromRGB(24, 28, 42),
        Success = Color3.fromRGB(90, 220, 140),
        Warning = Color3.fromRGB(240, 200, 90),
        Error = Color3.fromRGB(240, 100, 110),
    },
    Crimson = {
        Background = Color3.fromRGB(24, 16, 18),
        SecondaryBackground = Color3.fromRGB(34, 22, 24),
        TertiaryBackground = Color3.fromRGB(46, 30, 32),
        Text = Color3.fromRGB(245, 235, 235),
        SecondaryText = Color3.fromRGB(180, 150, 150),
        Accent = Color3.fromRGB(230, 70, 80),
        Border = Color3.fromRGB(60, 40, 42),
        Hover = Color3.fromRGB(54, 36, 38),
        Active = Color3.fromRGB(68, 44, 48),
        Notification = Color3.fromRGB(38, 24, 26),
        Success = Color3.fromRGB(120, 200, 120),
        Warning = Color3.fromRGB(230, 180, 70),
        Error = Color3.fromRGB(240, 100, 100),
    },
    Forest = {
        Background = Color3.fromRGB(16, 22, 18),
        SecondaryBackground = Color3.fromRGB(22, 32, 26),
        TertiaryBackground = Color3.fromRGB(30, 44, 36),
        Text = Color3.fromRGB(235, 245, 238),
        SecondaryText = Color3.fromRGB(150, 175, 158),
        Accent = Color3.fromRGB(80, 200, 130),
        Border = Color3.fromRGB(44, 60, 50),
        Hover = Color3.fromRGB(38, 52, 44),
        Active = Color3.fromRGB(48, 66, 56),
        Notification = Color3.fromRGB(26, 38, 30),
        Success = Color3.fromRGB(90, 220, 130),
        Warning = Color3.fromRGB(230, 190, 80),
        Error = Color3.fromRGB(230, 100, 100),
    },
    Light = {
        Background = Color3.fromRGB(240, 240, 244),
        SecondaryBackground = Color3.fromRGB(228, 228, 236),
        TertiaryBackground = Color3.fromRGB(214, 214, 224),
        Text = Color3.fromRGB(30, 30, 38),
        SecondaryText = Color3.fromRGB(90, 90, 105),
        Accent = Color3.fromRGB(88, 132, 255),
        Border = Color3.fromRGB(196, 196, 210),
        Hover = Color3.fromRGB(220, 220, 230),
        Active = Color3.fromRGB(206, 206, 220),
        Notification = Color3.fromRGB(255, 255, 255),
        Success = Color3.fromRGB(60, 180, 100),
        Warning = Color3.fromRGB(220, 160, 40),
        Error = Color3.fromRGB(220, 80, 80),
    },
}

local Theme = {}
Theme.Current = Themes.Dark
Theme.Name = "Dark"
Theme.Listeners = {}

function Theme.Get(key)
    return Theme.Current[key] or Color3.fromRGB(255, 255, 255)
end

function Theme.SetTheme(name)
    if not Themes[name] then return false end
    Theme.Name = name
    Theme.Current = Themes[name]
    State.ThemeName = name
    for _, listener in ipairs(Theme.Listeners) do
        pcall(listener, Theme.Current)
    end
    return true
end

function Theme.OnChange(fn)
    table.insert(Theme.Listeners, fn)
    return function()
        for i, l in ipairs(Theme.Listeners) do
            if l == fn then
                table.remove(Theme.Listeners, i)
                break
            end
        end
    end
end

function Theme.SetAccent(color)
    Theme.Current.Accent = color
    for _, listener in ipairs(Theme.Listeners) do
        pcall(listener, Theme.Current)
    end
end

-- ============================================================
-- SECTION 5: UTILITY FUNCTIONS
-- ============================================================
local Util = {}

function Util.New(className, props, children)
    local obj = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                obj[k] = v
            end
        end
    end
    if children then
        for _, c in ipairs(children) do
            c.Parent = obj
        end
    end
    if props and props.Parent then
        obj.Parent = props.Parent
    end
    return obj
end

function Util.Track(instance)
    table.insert(State.Instances, instance)
    return instance
end

function Util.Connect(signal, fn)
    local conn = signal:Connect(fn)
    table.insert(State.Connections, conn)
    return conn
end

function Util.Disconnect(conn)
    for i, c in ipairs(State.Connections) do
        if c == conn then
            pcall(function() c:Disconnect() end)
            table.remove(State.Connections, i)
            return
        end
    end
end

function Util.FormatNumber(n, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return tostring(math.floor(n * mult + 0.5) / mult)
end

function Util.FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

function Util.FormatClock()
    local t = os.date("*t")
    return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
end

function Util.Lerp(a, b, t)
    return a + (b - a) * t
end

function Util.LerpColor(a, b, t)
    return Color3.new(
        Util.Lerp(a.R, b.R, t),
        Util.Lerp(a.G, b.G, t),
        Util.Lerp(a.B, b.B, t)
    )
end

function Util.RoundTo(value, step)
    step = step or 1
    return math.floor(value / step + 0.5) * step
end

function Util.Clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

function Util.GetCharacter()
    return LocalPlayer.Character
end

function Util.GetHumanoid()
    local char = Util.GetCharacter()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

function Util.GetRoot()
    local char = Util.GetCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

function Util.CopyToClipboard(text)
    if setclipboard then
        pcall(setclipboard, text)
        return true
    end
    return false
end

function Util.SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[Nexus] Error:", err)
    end
    return ok, err
end

-- ============================================================
-- SECTION 6: ANIMATION SYSTEM
-- ============================================================
local Anim = {}

local TWEEN_INFO = TweenInfo.new

function Anim.Create(duration, style, direction)
    return TWEEN_INFO.new(
        duration or 0.25,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
end

function Anim.Tween(obj, props, duration, style, direction, cb)
    if not State.AnimationsEnabled then
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
        if cb then cb() end
        return nil
    end
    local info = Anim.Create(duration, style, direction)
    local tween = TweenService:Create(obj, info, props)
    if cb then
        tween.Completed:Connect(cb)
    end
    tween:Play()
    return tween
end

function Anim.FadeIn(obj, duration)
    obj.Visible = true
    obj.BackgroundTransparency = 1
    Anim.Tween(obj, { BackgroundTransparency = 0 }, duration or 0.3)
end

function Anim.FadeOut(obj, duration, cb)
    local t = Anim.Tween(obj, { BackgroundTransparency = 1 }, duration or 0.3)
    if t then
        t.Completed:Connect(function()
            obj.Visible = false
            if cb then cb() end
        end)
    else
        obj.Visible = false
        if cb then cb() end
    end
end

function Anim.SlideIn(obj, fromY, toY, duration)
    obj.Position = UDim2.new(obj.Position.X.Scale, obj.Position.X.Offset, 0, fromY)
    Anim.Tween(obj, { Position = UDim2.new(obj.Position.X.Scale, obj.Position.X.Offset, 0, toY) }, duration or 0.35, Enum.EasingStyle.Quint)
end

function Anim.ScaleIn(obj, duration)
    obj.Size = UDim2.new(0, 0, 0, 0)
    Anim.Tween(obj, { Size = UDim2.new(obj.Size.X.Scale, obj.Size.X.Offset, obj.Size.Y.Scale, obj.Size.Y.Offset) }, duration or 0.3, Enum.EasingStyle.Back)
end

function Anim.Press(obj)
    local originalSize = obj.Size
    Anim.Tween(obj, { Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, originalSize.Y.Scale, originalSize.Y.Offset - 2) }, 0.08)
    task.delay(0.08, function()
        Anim.Tween(obj, { Size = originalSize }, 0.12)
    end)
end

function Anim.Hover(obj, targetColor, originalColor)
    if not State.AnimationsEnabled then
        if targetColor then obj.BackgroundColor3 = targetColor end
        return
    end
    if targetColor then
        Anim.Tween(obj, { BackgroundColor3 = targetColor }, 0.15)
    end
end

-- ============================================================
-- SECTION 7: DRAWING / UI CREATION SYSTEM
-- ============================================================
local Draw = {}

function Draw.Frame(parent, props)
    props = props or {}
    props.BackgroundColor3 = props.BackgroundColor3 or Theme.Get("SecondaryBackground")
    props.BorderSizePixel = props.BorderSizePixel or 0
    props.Parent = parent
    return Util.New("Frame", props)
end

function Draw.TextLabel(parent, props)
    props = props or {}
    props.BackgroundTransparency = props.BackgroundTransparency or 1
    props.BorderSizePixel = 0
    props.Font = props.Font or Enum.Font.Gotham
    props.TextColor3 = props.TextColor3 or Theme.Get("Text")
    props.TextSize = props.TextSize or 14
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
    props.Parent = parent
    return Util.New("TextLabel", props)
end

function Draw.TextButton(parent, props)
    props = props or {}
    props.BackgroundColor3 = props.BackgroundColor3 or Theme.Get("SecondaryBackground")
    props.BorderSizePixel = 0
    props.Font = props.Font or Enum.Font.Gotham
    props.TextColor3 = props.TextColor3 or Theme.Get("Text")
    props.TextSize = props.TextSize or 14
    props.AutoButtonColor = false
    props.Text = props.Text or ""
    props.Parent = parent
    return Util.New("TextButton", props)
end

function Draw.ImageLabel(parent, props)
    props = props or {}
    props.BackgroundTransparency = props.BackgroundTransparency or 1
    props.BorderSizePixel = 0
    props.Parent = parent
    return Util.New("ImageLabel", props)
end

function Draw.ScrollingFrame(parent, props)
    props = props or {}
    props.BackgroundColor3 = props.BackgroundColor3 or Theme.Get("SecondaryBackground")
    props.BorderSizePixel = 0
    props.ScrollBarThickness = props.ScrollBarThickness or 3
    props.ScrollBarImageColor3 = props.ScrollBarImageColor3 or Theme.Get("Border")
    props.CanvasSize = props.CanvasSize or UDim2.new(0, 0, 0, 0)
    props.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
    props.Parent = parent
    return Util.New("ScrollingFrame", props)
end

function Draw.UIList(parent, props)
    props = props or {}
    props.Parent = parent
    return Util.New("UIListLayout", props)
end

function Draw.UIPadding(parent, props)
    props = props or {}
    props.Parent = parent
    return Util.New("UIPadding", props)
end

function Draw.UIStroke(parent, props)
    props = props or {}
    props.Color = props.Color or Theme.Get("Border")
    props.Thickness = props.Thickness or 1
    props.Transparency = props.Transparency or 0
    props.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    props.Parent = parent
    return Util.New("UIStroke", props)
end

function Draw.UIGradient(parent, props)
    props = props or {}
    props.Parent = parent
    return Util.New("UIGradient", props)
end

function Draw.Corner(parent)
    -- Intentionally NO UICorner is ever used per spec.
    return nil
end

-- ============================================================
-- SECTION 8: NOTIFICATION SYSTEM
-- ============================================================
local Notify = {}
Notify.Container = nil
Notify.Active = {}

function Notify.Init(guiParent)
    local container = Draw.Frame(guiParent, {
        Name = "Notifications",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 320, 1, -40),
        Position = UDim2.new(1, -340, 0, 20),
        ZIndex = 1000,
    })
    Draw.UIList(container, {
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Notify.Container = container
    return container
end

function Notify.Push(title, message, duration, ntype)
    if not State.NotificationsEnabled then return end
    if not Notify.Container then return end
    duration = duration or CONFIG.NotificationDuration
    ntype = ntype or "info"

    if #Notify.Active >= CONFIG.MaxNotifications then
        local oldest = Notify.Active[1]
        if oldest then
            Notify.Dismiss(oldest)
        end
    end

    local accentColor = Theme.Get("Accent")
    if ntype == "success" then accentColor = Theme.Get("Success") end
    if ntype == "warning" then accentColor = Theme.Get("Warning") end
    if ntype == "error" then accentColor = Theme.Get("Error") end

    local frame = Draw.Frame(Notify.Container, {
        Name = "Notify",
        BackgroundColor3 = Theme.Get("Notification"),
        Size = UDim2.new(1, 0, 0, 66),
        Position = UDim2.new(1, 60, 0, 0),
        ClipsDescendants = true,
    })
    Draw.UIStroke(frame, { Color = Theme.Get("Border"), Thickness = 1 })

    local accentBar = Draw.Frame(frame, {
        BackgroundColor3 = accentColor,
        Size = UDim2.new(0, 3, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
    })

    local titleLabel = Draw.TextLabel(frame, {
        Text = title or "Notification",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.Get("Text"),
        Size = UDim2.new(1, -32, 0, 22),
        Position = UDim2.new(0, 12, 0, 8),
    })

    local messageLabel = Draw.TextLabel(frame, {
        Text = message or "",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.Get("SecondaryText"),
        Size = UDim2.new(1, -32, 0, 26),
        Position = UDim2.new(0, 12, 0, 30),
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    local closeBtn = Draw.TextButton(frame, {
        Text = "x",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.Get("SecondaryText"),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -26, 0, 6),
    })

    local timerBar = Draw.Frame(frame, {
        BackgroundColor3 = accentColor,
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BorderSizePixel = 0,
    })

    local entry = { Frame = frame, TimerBar = timerBar, Start = tick(), Duration = duration }
    table.insert(Notify.Active, entry)

    -- slide in
    Anim.Tween(frame, { Position = UDim2.new(0, 0, 0, 0) }, 0.35, Enum.EasingStyle.Quint)
    Anim.Tween(timerBar, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)

    closeBtn.MouseButton1Click:Connect(function()
        Notify.Dismiss(entry)
    end)
    closeBtn.MouseEnter:Connect(function()
        closeBtn.TextColor3 = Theme.Get("Text")
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.TextColor3 = Theme.Get("SecondaryText")
    end)

    task.delay(duration, function()
        Notify.Dismiss(entry)
    end)

    return entry
end

function Notify.Dismiss(entry)
    if not entry or entry.Removed then return end
    entry.Removed = true
    for i, e in ipairs(Notify.Active) do
        if e == entry then
            table.remove(Notify.Active, i)
            break
        end
    end
    if entry.Frame and entry.Frame.Parent then
        Anim.Tween(entry.Frame, {
            Position = UDim2.new(1, 80, 0, 0),
            BackgroundTransparency = 1
        }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        if entry.TimerBar then
            Anim.Tween(entry.TimerBar, { BackgroundTransparency = 1 }, 0.25)
        end
        task.delay(0.3, function()
            if entry.Frame then
                entry.Frame:Destroy()
            end
        end)
    end
end

function Notify.Clear()
    for _, e in ipairs(Notify.Active) do
        Notify.Dismiss(e)
    end
    Notify.Active = {}
end

-- ============================================================
-- SECTION 9: SAVE / LOAD CONFIGURATION
-- ============================================================
local ConfigStore = {}
ConfigStore.Enabled = false
ConfigStore.Data = {}

function ConfigStore.Detect()
    ConfigStore.Enabled = false
    -- Filesystem is not available in vanilla Roblox outside Studio.
    -- We fall back to in-memory config always. Persistence would need
    -- an external mechanism (DataStore, HttpService, etc.)
    pcall(function()
        if writefile and readfile then
            ConfigStore.Enabled = true
        end
    end)
end

function ConfigStore.Save()
    local data = {
        Version = CONFIG.Version,
        Theme = Theme.Name,
        UIScale = State.UIScale,
        Animations = State.AnimationsEnabled,
        Notifications = State.NotificationsEnabled,
        ToggleKey = State.ToggleKey and State.ToggleKey.Name or "RightShift",
        Features = {},
    }
    for k, v in pairs(State.Features) do
        data.Features[k] = v
    end
    local json = HttpService:JSONEncode(data)
    ConfigStore.Data = data
    if ConfigStore.Enabled and writefile then
        pcall(writefile, CONFIG.SaveFileName, json)
    end
    return true
end

function ConfigStore.Load()
    local raw
    if ConfigStore.Enabled and readfile and isfile and isfile(CONFIG.SaveFileName) then
        pcall(function() raw = readfile(CONFIG.SaveFileName) end)
    end
    if not raw then return false end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok or not data then return false end
    ConfigStore.Data = data
    if data.Theme and Themes[data.Theme] then
        Theme.SetTheme(data.Theme)
    end
    if data.UIScale then State.UIScale = data.UIScale end
    if data.Animations ~= nil then State.AnimationsEnabled = data.Animations end
    if data.Notifications ~= nil then State.NotificationsEnabled = data.Notifications end
    if data.ToggleKey then
        local ok2, key = pcall(function() return Enum.KeyCode[data.ToggleKey] end)
        if ok2 and key then State.ToggleKey = key end
    end
    if data.Features then
        for k, v in pairs(data.Features) do
            State.Features[k] = v
        end
    end
    return true
end

function ConfigStore.Reset()
    State.Features = {}
    State.UIScale = CONFIG.DefaultUIScale
    State.AnimationsEnabled = true
    State.NotificationsEnabled = true
    State.ToggleKey = CONFIG.DefaultToggleKey
    Theme.SetTheme("Dark")
end

-- ============================================================
-- SECTION 10: COMPONENT: TOGGLE
-- ============================================================
local Toggle = {}
Toggle.__index = Toggle

function Toggle.new(parent, opts)
    opts = opts or {}
    local self = setmetatable({}, Toggle)
    self.Value = opts.Default or false
    self.Changed = opts.Changed or function() end
    self.Key = opts.Key

    local row = Draw.Frame(parent, {
        Name = "Toggle_" .. (opts.Name or "unnamed"),
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(1, 0, 0, 32),
    })
    Draw.UIStroke(row, { Color = Theme.Get("Border"), Thickness = 1 })
    Draw.UIPadding(row, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) })

    local label = Draw.TextLabel(row, {
        Text = opts.Name or "Toggle",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Get("Text"),
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
    })

    local switchBg = Draw.Frame(row, {
        BackgroundColor3 = self.Value and Theme.Get("Accent") or Theme.Get("TertiaryBackground"),
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -40, 0.5, -10),
        BorderSizePixel = 0,
    })
    Draw.UIStroke(switchBg, { Color = Theme.Get("Border"), Thickness = 1 })

    local knob = Draw.Frame(switchBg, {
        BackgroundColor3 = Color3.fromRGB(240, 240, 245),
        Size = UDim2.new(0, 16, 0, 16),
        Position = self.Value and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BorderSizePixel = 0,
    })

    local btn = Draw.TextButton(row, {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        ZIndex = 3,
    })

    local function setVisual(value, animate)
        if animate == nil then animate = true end
        local targetPos = value and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local targetColor = value and Theme.Get("Accent") or Theme.Get("TertiaryBackground")
        if animate and State.AnimationsEnabled then
            Anim.Tween(knob, { Position = targetPos }, 0.18, Enum.EasingStyle.Quad)
            Anim.Tween(switchBg, { BackgroundColor3 = targetColor }, 0.18)
        else
            knob.Position = targetPos
            switchBg.BackgroundColor3 = targetColor
        end
    end

    function self:Set(value, silent)
        value = not not value
        if self.Value == value then return end
        self.Value = value
        setVisual(value, true)
        if not silent then
            pcall(self.Changed, value)
        end
        if self.Key then
            State.Features[self.Key] = value
        end
    end

    function self:Get()
        return self.Value
    end

    btn.MouseButton1Click:Connect(function()
        self:Set(not self.Value)
    end)
    btn.MouseEnter:Connect(function()
        Anim.Tween(row, { BackgroundColor3 = Theme.Get("Hover") }, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        Anim.Tween(row, { BackgroundColor3 = Theme.Get("SecondaryBackground") }, 0.15)
    end)

    self.Instance = row
    setVisual(self.Value, false)
    return self
end

-- ============================================================
-- SECTION 11: COMPONENT: SLIDER
-- ============================================================
local Slider = {}
Slider.__index = Slider

function Slider.new(parent, opts)
    opts = opts or {}
    local self = setmetatable({}, Slider)
    self.Min = opts.Min or 0
    self.Max = opts.Max or 100
    self.Step = opts.Step or 1
    self.Value = opts.Default or self.Min
    self.Suffix = opts.Suffix or ""
    self.Changed = opts.Changed or function() end
    self.Key = opts.Key

    local row = Draw.Frame(parent, {
        Name = "Slider_" .. (opts.Name or "unnamed"),
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(1, 0, 0, 44),
    })
    Draw.UIStroke(row, { Color = Theme.Get("Border"), Thickness = 1 })
    Draw.UIPadding(row, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })

    local label = Draw.TextLabel(row, {
        Text = opts.Name or "Slider",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Get("Text"),
        Size = UDim2.new(1, -60, 0, 18),
        Position = UDim2.new(0, 0, 0, 4),
    })

    local valueLabel = Draw.TextLabel(row, {
        Text = tostring(self.Value) .. self.Suffix,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Theme.Get("Accent"),
        Size = UDim2.new(0, 60, 0, 18),
        Position = UDim2.new(1, -60, 0, 4),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local track = Draw.Frame(row, {
        BackgroundColor3 = Theme.Get("TertiaryBackground"),
        Size = UDim2.new(1, 0, 0, 4),
        Position = UDim2.new(0, 0, 1, -12),
        BorderSizePixel = 0,
    })

    local fill = Draw.Frame(track, {
        BackgroundColor3 = Theme.Get("Accent"),
        Size = UDim2.new(0, 0, 1, 0),
        BorderSizePixel = 0,
    })

    local knob = Draw.Frame(track, {
        BackgroundColor3 = Color3.fromRGB(240, 240, 245),
        Size = UDim2.new(0, 10, 0, 12),
        Position = UDim2.new(0, 0, 0.5, -6),
        BorderSizePixel = 0,
        ZIndex = 2,
    })

    local hit = Draw.TextButton(row, {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 1, -20),
        ZIndex = 4,
    })

    local dragging = false

    local function updateFromX(mouseX)
        local absPos = track.AbsolutePosition.X
        local absSize = track.AbsoluteSize.X
        local rel = Util.Clamp((mouseX - absPos) / absSize, 0, 1)
        local raw = self.Min + rel * (self.Max - self.Min)
        local stepped = Util.RoundTo(raw, self.Step)
        stepped = Util.Clamp(stepped, self.Min, self.Max)
        self:Set(stepped, true)
        pcall(self.Changed, stepped)
    end

    function self:Set(value, silent)
        value = Util.Clamp(Util.RoundTo(value, self.Step), self.Min, self.Max)
        self.Value = value
        local rel = (value - self.Min) / (self.Max - self.Min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -5, 0.5, -6)
        valueLabel.Text = tostring(value) .. self.Suffix
        if not silent then
            pcall(self.Changed, value)
        end
        if self.Key then
            State.Features[self.Key] = value
        end
    end

    function self:Get()
        return self.Value
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)

    Util.Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)

    Util.Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    hit.MouseEnter:Connect(function()
        Anim.Tween(knob, { BackgroundColor3 = Theme.Get("Accent") }, 0.15)
    end)
    hit.MouseLeave:Connect(function()
        Anim.Tween(knob, { BackgroundColor3 = Color3.fromRGB(240, 240, 245) }, 0.15)
    end)

    self.Instance = row
    self:Set(self.Value, true)
    return self
end

-- ============================================================
-- SECTION 12: COMPONENT: DROPDOWN
-- ============================================================
local Dropdown = {}
Dropdown.__index = Dropdown

function Dropdown.new(parent, opts)
    opts = opts or {}
    local self = setmetatable({}, Dropdown)
    self.Options = opts.Options or {}
    self.Value = opts.Default or (self.Options[1] or "")
    self.Changed = opts.Changed or function() end
    self.Open = false
    self.Key = opts.Key

    local row = Draw.Frame(parent, {
        Name = "Dropdown_" .. (opts.Name or "unnamed"),
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(1, 0, 0, 32),
        ClipsDescendants = false,
        ZIndex = 3,
    })
    Draw.UIStroke(row, { Color = Theme.Get("Border"), Thickness = 1 })
    Draw.UIPadding(row, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })

    local label = Draw.TextLabel(row, {
        Text = opts.Name or "Dropdown",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Get("Text"),
        Size = UDim2.new(0.5, -5, 1, 0),
    })

    local selected = Draw.TextButton(row, {
        Text = tostring(self.Value) .. "  v",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.Get("Accent"),
        BackgroundColor3 = Theme.Get("TertiaryBackground"),
        Size = UDim2.new(0.5, -5, 0, 22),
        Position = UDim2.new(0.5, 5, 0.5, -11),
    })
    Draw.UIStroke(selected, { Color = Theme.Get("Border"), Thickness = 1 })

    local popup = Draw.Frame(row, {
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(0.5, -5, 0, 0),
        Position = UDim2.new(0.5, 5, 1, 4),
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 50,
    })
    Draw.UIStroke(popup, { Color = Theme.Get("Border"), Thickness = 1 })
    local popupList = Draw.UIList(popup, {
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local function refresh()
        for _, c in ipairs(popup:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for _, opt in ipairs(self.Options) do
            local b = Draw.TextButton(popup, {
                Text = tostring(opt),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextColor3 = Theme.Get("Text"),
                BackgroundColor3 = Theme.Get("SecondaryBackground"),
                Size = UDim2.new(1, 0, 0, 26),
            })
            b.MouseEnter:Connect(function()
                Anim.Tween(b, { BackgroundColor3 = Theme.Get("Hover") }, 0.12)
            end)
            b.MouseLeave:Connect(function()
                Anim.Tween(b, { BackgroundColor3 = Theme.Get("SecondaryBackground") }, 0.12)
            end)
            b.MouseButton1Click:Connect(function()
                self:Set(opt)
                self:Toggle(false)
            end)
        end
        local count = #self.Options
        local targetHeight = count * 26
        if targetHeight > 200 then targetHeight = 200 end
        popup.Size = UDim2.new(0.5, -5, 0, targetHeight)
    end

    function self:Toggle(force)
        self.Open = (force ~= nil) and force or not self.Open
        popup.Visible = self.Open
        if self.Open then
            refresh()
            popup.Size = UDim2.new(0.5, -5, 0, 0)
            local count = #self.Options
            local targetHeight = math.min(count * 26, 200)
            Anim.Tween(popup, { Size = UDim2.new(0.5, -5, 0, targetHeight) }, 0.18)
        end
    end

    function self:Set(value)
        self.Value = value
        selected.Text = tostring(value) .. "  v"
        pcall(self.Changed, value)
        if self.Key then
            State.Features[self.Key] = value
        end
    end

    function self:Get()
        return self.Value
    end

    selected.MouseButton1Click:Connect(function()
        self:Toggle()
    end)

    self.Instance = row
    return self
end

-- ============================================================
-- SECTION 13: COMPONENT: KEYBIND
-- ============================================================
local Keybind = {}
Keybind.__index = Keybind

function Keybind.new(parent, opts)
    opts = opts or {}
    local self = setmetatable({}, Keybind)
    self.Value = opts.Default or Enum.KeyCode.Unknown
    self.Changed = opts.Changed or function() end
    self.Listening = false
    self.Key = opts.Key

    local row = Draw.Frame(parent, {
        Name = "Keybind_" .. (opts.Name or "unnamed"),
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(1, 0, 0, 32),
    })
    Draw.UIStroke(row, { Color = Theme.Get("Border"), Thickness = 1 })
    Draw.UIPadding(row, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })

    local label = Draw.TextLabel(row, {
        Text = opts.Name or "Keybind",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Get("Text"),
        Size = UDim2.new(0.5, -5, 1, 0),
    })

    local btn = Draw.TextButton(row, {
        Text = self.Value.Name,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.Get("Accent"),
        BackgroundColor3 = Theme.Get("TertiaryBackground"),
        Size = UDim2.new(0.5, -5, 0, 22),
        Position = UDim2.new(0.5, 5, 0.5, -11),
    })
    Draw.UIStroke(btn, { Color = Theme.Get("Border"), Thickness = 1 })

    btn.MouseButton1Click:Connect(function()
        self.Listening = not self.Listening
        if self.Listening then
            btn.Text = "[press key]"
            btn.TextColor3 = Theme.Get("Warning")
        else
            btn.Text = self.Value.Name
            btn.TextColor3 = Theme.Get("Accent")
        end
    end)

    Util.Connect(UserInputService.InputBegan, function(input, gp)
        if self.Listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                self.Value = input.KeyCode
                btn.Text = self.Value.Name
                btn.TextColor3 = Theme.Get("Accent")
                self.Listening = false
                pcall(self.Changed, self.Value)
                if self.Key then
                    State.Features[self.Key] = self.Value.Name
                end
            end
        end
    end)

    function self:Set(key)
        self.Value = key
        btn.Text = self.Value.Name
        pcall(self.Changed, self.Value)
    end

    function self:Get()
        return self.Value
    end

    self.Instance = row
    return self
end

-- ============================================================
-- SECTION 14: COMPONENT: BUTTON
-- ============================================================
local Button = {}
Button.__index = Button

function Button.new(parent, opts)
    opts = opts or {}
    local self = setmetatable({}, Button)
    local frame = Draw.TextButton(parent, {
        Name = "Button_" .. (opts.Name or "unnamed"),
        Text = "",
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(1, 0, 0, 32),
    })
    Draw.UIStroke(frame, { Color = Theme.Get("Border"), Thickness = 1 })

    local txt = Draw.TextLabel(frame, {
        Text = opts.Name or "Button",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Get("Text"),
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
    })

    local callback = opts.Callback or function() end

    frame.MouseEnter:Connect(function()
        Anim.Tween(frame, { BackgroundColor3 = Theme.Get("Hover") }, 0.15)
        txt.TextColor3 = Theme.Get("Accent")
    end)
    frame.MouseLeave:Connect(function()
        Anim.Tween(frame, { BackgroundColor3 = Theme.Get("SecondaryBackground") }, 0.15)
        txt.TextColor3 = Theme.Get("Text")
    end)
    frame.MouseButton1Click:Connect(function()
        Anim.Press(frame)
        pcall(callback)
    end)

    self.Instance = frame
    self.Label = txt
    return self
end

-- ============================================================
-- SECTION 15: COMPONENT: LABEL
-- ============================================================
local Label = {}
Label.__index = Label

function Label.new(parent, opts)
    opts = opts or {}
    local self = setmetatable({}, Label)
    local frame = Draw.Frame(parent, {
        Name = "Label_" .. (opts.Name or "unnamed"),
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(1, 0, 0, 28),
    })
    Draw.UIStroke(frame, { Color = Theme.Get("Border"), Thickness = 1 })

    local left = Draw.TextLabel(frame, {
        Text = opts.Name or "",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.Get("Text"),
        Size = UDim2.new(0.5, -10, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
    })
    local right = Draw.TextLabel(frame, {
        Text = opts.Value or "",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Theme.Get("Accent"),
        Size = UDim2.new(0.5, -10, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    function self:SetValue(v)
        right.Text = tostring(v)
    end
    function self:SetName(n)
        left.Text = tostring(n)
    end

    self.Instance = frame
    self.Left = left
    self.Right = right
    return self
end

-- ============================================================
-- SECTION 16: WINDOW MANAGEMENT
-- ============================================================
local Window = {}
Window.__index = Window
Window.Tabs = {}
Window.Current = nil

function Window.Create()
    local gui = Util.New("ScreenGui", {
        Name = "NexusUI_" .. tostring(math.random(100000, 999999)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    })

    -- Try to parent to CoreGui (executor) or PlayerGui
    local parented = false
    pcall(function()
        if gethui then
            gui.Parent = gethui()
            parented = true
        elseif syn and syn.protect_gui then
            syn.protect_gui(gui)
            gui.Parent = CoreGui
            parented = true
        end
    end)
    if not parented then
        pcall(function() gui.Parent = CoreGui end)
        if gui.Parent == nil then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end

    Util.Track(gui)
    Window.Gui = gui

    -- Main root frame (also contains scale)
    local root = Draw.Frame(gui, {
        Name = "Root",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y),
        Position = UDim2.new(0.5, -CONFIG.WindowSize.X / 2, 0.5, -CONFIG.WindowSize.Y / 2),
    })

    -- Backing frame
    local main = Draw.Frame(root, {
        Name = "Main",
        BackgroundColor3 = Theme.Get("Background"),
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
    })
    Draw.UIStroke(main, { Color = Theme.Get("Border"), Thickness = 1 })

    -- Top bar
    local topBar = Draw.Frame(main, {
        Name = "TopBar",
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(1, 0, 0, CONFIG.TopBarHeight),
        Position = UDim2.new(0, 0, 0, 0),
    })
    Draw.UIStroke(topBar, { Color = Theme.Get("Border"), Thickness = 1 })

    local title = Draw.TextLabel(topBar, {
        Text = CONFIG.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Theme.Get("Text"),
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
    })

    local version = Draw.TextLabel(topBar, {
        Text = "v" .. CONFIG.Version,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.Get("SecondaryText"),
        Size = UDim2.new(0, 60, 1, 0),
        Position = UDim2.new(0, 12 + 200, 0, 0),
    })

    local minimizeBtn = Draw.TextButton(topBar, {
        Text = "-",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Theme.Get("SecondaryText"),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 30, 1, 0),
        Position = UDim2.new(1, -70, 0, 0),
    })
    minimizeBtn.MouseEnter:Connect(function()
        minimizeBtn.BackgroundColor3 = Theme.Get("Hover")
        minimizeBtn.BackgroundTransparency = 0
    end)
    minimizeBtn.MouseLeave:Connect(function()
        minimizeBtn.BackgroundTransparency = 1
    end)

    local closeBtn = Draw.TextButton(topBar, {
        Text = "x",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.Get("SecondaryText"),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 30, 1, 0),
        Position = UDim2.new(1, -36, 0, 0),
    })
    closeBtn.MouseEnter:Connect(function()
        closeBtn.BackgroundColor3 = Theme.Get("Error")
        closeBtn.BackgroundTransparency = 0
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.BackgroundTransparency = 1
        closeBtn.TextColor3 = Theme.Get("SecondaryText")
    end)

    -- Sidebar
    local sidebar = Draw.Frame(main, {
        Name = "Sidebar",
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(0, CONFIG.SidebarWidth, 1, -CONFIG.TopBarHeight),
        Position = UDim2.new(0, 0, 0, CONFIG.TopBarHeight),
    })
    Draw.UIStroke(sidebar, { Color = Theme.Get("Border"), Thickness = 1 })

    local sidebarList = Draw.UIList(sidebar, {
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })

    -- Content area
    local content = Draw.Frame(main, {
        Name = "Content",
        BackgroundColor3 = Theme.Get("Background"),
        Size = UDim2.new(1, -CONFIG.SidebarWidth, 1, -CONFIG.TopBarHeight),
        Position = UDim2.new(0, CONFIG.SidebarWidth, 0, CONFIG.TopBarHeight),
        ClipsDescendants = true,
    })

    -- Init notification container
    Notify.Init(gui)

    local self = setmetatable({}, Window)
    self.Gui = gui
    self.Root = root
    self.Main = main
    self.TopBar = topBar
    self.Sidebar = sidebar
    self.SidebarList = sidebarList
    self.Content = content
    self.Tabs = {}
    self.TabButtons = {}
    self.Current = nil
    self.Visible = true

    -- Dragging
    local dragging = false
    local dragStart, startPos

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = root.Position
        end
    end)
    Util.Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    Util.Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Minimize / close
    self.Minimized = false
    minimizeBtn.MouseButton1Click:Connect(function()
        self:ToggleMinimize()
    end)
    closeBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)

    -- Keybind for showing/hiding
    Util.Connect(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if input.KeyCode == State.ToggleKey then
            self:Toggle()
        end
    end)

    -- Theme listener
    Theme.OnChange(function(theme)
        self:ApplyTheme()
    end)

    -- Responsive: when viewport size changes, clamp position
    Util.Connect(Camera:GetPropertyChangedSignal("ViewportSize"), function()
        self:ClampToScreen()
    end)

    return self
end

function Window:ToggleMinimize()
    self.Minimized = not self.Minimized
    if self.Minimized then
        Anim.Tween(self.Main, { Size = UDim2.new(1, 0, 0, CONFIG.TopBarHeight) }, 0.25)
    else
        Anim.Tween(self.Main, { Size = UDim2.new(1, 0, 1, 0) }, 0.25)
    end
end

function Window:Toggle()
    self.Visible = not self.Visible
    if self.Visible then
        self.Root.Visible = true
        local original = self.Root.Position
        self.Root.Position = UDim2.new(original.X.Scale, original.X.Offset, original.Y.Scale, original.Y.Offset + 20)
        Anim.Tween(self.Root, { Position = original }, 0.22, Enum.EasingStyle.Quad)
        self.Main.BackgroundTransparency = 0.4
        Anim.Tween(self.Main, { BackgroundTransparency = 0 }, 0.2)
    else
        self.Main.BackgroundTransparency = 0
        local done = false
        local t = Anim.Tween(self.Main, { BackgroundTransparency = 0.4 }, 0.15)
        task.delay(0.18, function()
            self.Root.Visible = false
            self.Main.BackgroundTransparency = 0
        end)
    end
end

function Window:ClampToScreen()
    local vp = Camera.ViewportSize
    local pos = self.Root.AbsolutePosition
    local size = self.Root.AbsoluteSize
    local newX = Util.Clamp(pos.X, 0, math.max(0, vp.X - size.X))
    local newY = Util.Clamp(pos.Y, 0, math.max(0, vp.Y - size.Y))
    self.Root.Position = UDim2.new(0, newX, 0, newY)
end

function Window:ApplyTheme()
    self.Main.BackgroundColor3 = Theme.Get("Background")
    self.TopBar.BackgroundColor3 = Theme.Get("SecondaryBackground")
    self.Sidebar.BackgroundColor3 = Theme.Get("SecondaryBackground")
    self.Content.BackgroundColor3 = Theme.Get("Background")
end

function Window:CreateTab(name, icon)
    local btn = Draw.TextButton(self.Sidebar, {
        Text = "",
        BackgroundColor3 = Theme.Get("SecondaryBackground"),
        Size = UDim2.new(1, 0, 0, 34),
        Name = "Tab_" .. name,
    })

    local indicator = Draw.Frame(btn, {
        BackgroundColor3 = Theme.Get("Accent"),
        Size = UDim2.new(0, 3, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        Visible = false,
    })

    local label = Draw.TextLabel(btn, {
        Text = "  " .. name,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Get("SecondaryText"),
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
    })

    local page = Draw.ScrollingFrame(self.Content, {
        Name = "Page_" .. name,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        Visible = false,
    })
    Draw.UIPadding(page, {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    })
    Draw.UIList(page, {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local tab = {
        Name = name,
        Button = btn,
        Indicator = indicator,
        Label = label,
        Page = page,
        Content = page,
    }
    self.Tabs[name] = tab
    table.insert(self.TabButtons, tab)

    btn.MouseEnter:Connect(function()
        if self.Current ~= tab then
            Anim.Tween(btn, { BackgroundColor3 = Theme.Get("Hover") }, 0.12)
            label.TextColor3 = Theme.Get("Text")
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.Current ~= tab then
            Anim.Tween(btn, { BackgroundColor3 = Theme.Get("SecondaryBackground") }, 0.12)
            label.TextColor3 = Theme.Get("SecondaryText")
        end
    end)
    btn.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)

    return tab
end

function Window:SelectTab(name)
    local tab = self.Tabs[name]
    if not tab then return end
    if self.Current == tab then return end
    local prev = self.Current
    self.Current = tab

    for _, t in ipairs(self.TabButtons) do
        if t == tab then
            Anim.Tween(t.Button, { BackgroundColor3 = Theme.Get("Active") }, 0.15)
            t.Label.TextColor3 = Theme.Get("Accent")
            t.Indicator.Visible = true
        else
            Anim.Tween(t.Button, { BackgroundColor3 = Theme.Get("SecondaryBackground") }, 0.15)
            t.Label.TextColor3 = Theme.Get("SecondaryText")
            t.Indicator.Visible = false
        end
        t.Page.Visible = (t == tab)
    end

    -- Slide animation on new page
    if State.AnimationsEnabled then
        tab.Page.Position = UDim2.new(0, 20, 0, 0)
        tab.Page.BackgroundTransparency = 1
        Anim.Tween(tab.Page, { Position = UDim2.new(0, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quad)
    end
end

-- ============================================================
-- SECTION 17: PLAYER UTILITIES
-- ============================================================
local PlayerUtil = {}

function PlayerUtil.GetAllPlayers()
    return Players:GetPlayers()
end

function PlayerUtil.GetName(plr)
    return plr and plr.Name or "?"
end

function PlayerUtil.GetDisplay(plr)
    return plr and plr.DisplayName or "?"
end

function PlayerUtil.GetDistance(plr)
    local char = Util.GetCharacter()
    local root = Util.GetRoot()
    if not char or not root or not plr or not plr.Character then return math.huge end
    local theirRoot = plr.Character:FindFirstChild("HumanoidRootPart")
    if not theirRoot then return math.huge end
    return (theirRoot.Position - root.Position).Magnitude
end

function PlayerUtil.TeleportTo(plr)
    local root = Util.GetRoot()
    if not root or not plr or not plr.Character then return false end
    local target = plr.Character:FindFirstChild("HumanoidRootPart")
    if not target then return false end
    pcall(function()
        root.CFrame = target.CFrame + Vector3.new(0, 2, 3)
    end)
    return true
end

function PlayerUtil.GetHealth(plr)
    if not plr or not plr.Character then return 0, 0 end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return 0, 0 end
    return hum.Health, hum.MaxHealth
end

-- ============================================================
-- SECTION 18: CHARACTER UTILITIES
-- ============================================================
local CharUtil = {}

function CharUtil.GetHumanoid()
    return Util.GetHumanoid()
end

function CharUtil.SetWalkSpeed(speed)
    local hum = Util.GetHumanoid()
    if hum then
        pcall(function() hum.WalkSpeed = speed end)
    end
end

function CharUtil.SetJumpPower(power)
    local hum = Util.GetHumanoid()
    if hum then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = power
        end)
    end
end

function CharUtil.SetHealth(hp)
    local hum = Util.GetHumanoid()
    if hum then
        pcall(function() hum.Health = hp end)
    end
end

function CharUtil.SetGravity(gravity)
    local hum = Util.GetHumanoid()
    if hum then
        pcall(function() hum:SetAttribute("CustomGravity", gravity) end)
    end
end

function CharUtil.InfiniteJump(enabled)
    local hum = Util.GetHumanoid()
    if not hum then return end
    if enabled then
        if State.Loops.InfiniteJump then return end
        State.Loops.InfiniteJump = Util.Connect(UserInputService.JumpRequest, function()
            local h = Util.GetHumanoid()
            if h then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    else
        if State.Loops.InfiniteJump then
            Util.Disconnect(State.Loops.InfiniteJump)
            State.Loops.InfiniteJump = nil
        end
    end
end

function CharUtil.Noclip(enabled)
    local root = Util.GetRoot()
    if not root then return end
    if enabled then
        if State.Loops.Noclip then return end
        State.Loops.Noclip = Util.Connect(RunService.Stepped, function()
            local char = Util.GetCharacter()
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
        end)
    else
        if State.Loops.Noclip then
            Util.Disconnect(State.Loops.Noclip)
            State.Loops.Noclip = nil
        end
        local char = Util.GetCharacter()
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function() p.CanCollide = true end)
                end
            end
        end
    end
end

-- ============================================================
-- SECTION 19: MOVEMENT UTILITIES
-- ============================================================
local MoveUtil = {}

MoveUtil.SpeedEnabled = false
MoveUtil.SpeedValue = 16

function MoveUtil.SetSpeed(value)
    MoveUtil.SpeedValue = value
    if MoveUtil.SpeedEnabled then
        CharUtil.SetWalkSpeed(value)
    end
end

function MoveUtil.ToggleSpeed(enabled)
    MoveUtil.SpeedEnabled = enabled
    if enabled then
        CharUtil.SetWalkSpeed(MoveUtil.SpeedValue)
    else
        CharUtil.SetWalkSpeed(16)
    end
end

MoveUtil.JumpEnabled = false
MoveUtil.JumpValue = 50

function MoveUtil.SetJump(value)
    MoveUtil.JumpValue = value
    if MoveUtil.JumpEnabled then
        CharUtil.SetJumpPower(value)
    end
end

function MoveUtil.ToggleJump(enabled)
    MoveUtil.JumpEnabled = enabled
    if enabled then
        CharUtil.SetJumpPower(MoveUtil.JumpValue)
    else
        CharUtil.SetJumpPower(50)
    end
end

MoveUtil.FlyEnabled = false
MoveUtil.FlySpeed = 60

function MoveUtil.ToggleFly(enabled)
    MoveUtil.FlyEnabled = enabled
    local root = Util.GetRoot()
    if not root then return end

    if enabled then
        local bodyVel = root:FindFirstChild("NexusFlyVelocity")
        if not bodyVel then
            bodyVel = Util.New("BodyVelocity", {
                Name = "NexusFlyVelocity",
                Parent = root,
                MaxForce = Vector3.new(1e5, 1e5, 1e5),
                Velocity = Vector3.new(0, 0, 0),
            })
        end

        MoveUtil.FlyConn = Util.Connect(RunService.RenderStepped, function()
            local hum = Util.GetHumanoid()
            local rt = Util.GetRoot()
            if not hum or not rt then return end
            local vel = rt:FindFirstChild("NexusFlyVelocity")
            if not vel then return end
            local cam = Workspace.CurrentCamera
            local move = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                move = move + cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                move = move - cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                move = move - cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                move = move + cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                move = move + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                move = move - Vector3.new(0, 1, 0)
            end
            if move.Magnitude > 0 then
                move = move.Unit * MoveUtil.FlySpeed
            end
            vel.Velocity = move
            hum.PlatformStand = true
        end)
    else
        if MoveUtil.FlyConn then
            Util.Disconnect(MoveUtil.FlyConn)
            MoveUtil.FlyConn = nil
        end
        local root2 = Util.GetRoot()
        if root2 then
            local v = root2:FindFirstChild("NexusFlyVelocity")
            if v then v:Destroy() end
        end
        local hum = Util.GetHumanoid()
        if hum then hum.PlatformStand = false end
    end
end

-- ============================================================
-- SECTION 20: CAMERA UTILITIES
-- ============================================================
local CamUtil = {}

function CamUtil.SetFOV(fov)
    if Camera then
        pcall(function() Camera.FieldOfView = fov end)
    end
end

function CamUtil.SetDistance(distance)
    local plr = LocalPlayer
    plr.CameraMaxZoomDistance = distance
    plr.CameraMinZoomDistance = distance
end

function CamUtil.ResetZoom()
    LocalPlayer.CameraMaxZoomDistance = 128
    LocalPlayer.CameraMinZoomDistance = 0.5
end

-- ============================================================
-- SECTION 21: VISUAL UTILITIES (ESP)
-- ============================================================
local Visual = {}

Visual.ESPEnabled = false
Visual.ESPObjects = {}
Visual.DrawDistance = false
Visual.DrawName = true
Visual.DrawHealth = true
Visual.AccentColor = nil

function Visual.CreateESPFor(player)
    if not player.Character then return end
    local char = player.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not head then return end

    local billboard = Util.New("BillboardGui", {
        Name = "NexusESP_" .. player.Name,
        Adornee = head,
        Size = UDim2.new(0, 120, 0, 40),
        StudsOffset = Vector3.new(0, 2.5, 0),
        AlwaysOnTop = true,
        Parent = head,
    })
    local container = Draw.Frame(billboard, {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    })
    local list = Draw.UIList(container, {
        Padding = UDim.new(0, 1),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    local name = Draw.TextLabel(container, {
        Text = player.DisplayName,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Visual.AccentColor or Theme.Get("Accent"),
        Size = UDim2.new(1, 0, 0, 16),
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.new(0, 0, 0),
    })
    local dist = Draw.TextLabel(container, {
        Text = "0m",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        Size = UDim2.new(1, 0, 0, 14),
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.new(0, 0, 0),
    })
    local healthBg = Draw.Frame(container, {
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        Size = UDim2.new(0.7, 0, 0, 4),
        BorderSizePixel = 0,
    })
    local healthFill = Draw.Frame(healthBg, {
        BackgroundColor3 = Theme.Get("Success"),
        Size = UDim2.new(1, 0, 1, 0),
        BorderSizePixel = 0,
    })
    Visual.ESPObjects[player] = {
        Billboard = billboard,
        Name = name,
        Dist = dist,
        HealthBg = healthBg,
        HealthFill = healthFill,
    }
end

function Visual.DestroyESPFor(player)
    local obj = Visual.ESPObjects[player]
    if obj and obj.Billboard then
        obj.Billboard:Destroy()
    end
    Visual.ESPObjects[player] = nil
end

function Visual.RefreshESP()
    for plr, obj in pairs(Visual.ESPObjects) do
        if not plr.Parent or not plr.Character then
            Visual.DestroyESPFor(plr)
        else
            local char = plr.Character
            local head = char:FindFirstChild("Head")
            if not head then
                Visual.DestroyESPFor(plr)
            else
                obj.Billboard.Adornee = head
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local pct = hum.Health / math.max(hum.MaxHealth, 1)
                    obj.HealthFill.Size = UDim2.new(pct, 0, 1, 0)
                end
                obj.Name.Text = plr.DisplayName
                obj.Dist.Text = string.format("%dm", math.floor(PlayerUtil.GetDistance(plr)))
                obj.Name.Visible = Visual.DrawName
                obj.Dist.Visible = Visual.DrawDistance
                obj.HealthBg.Visible = Visual.DrawHealth
            end
        end
    end
end

function Visual.ToggleESP(enabled)
    Visual.ESPEnabled = enabled
    if enabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                Visual.CreateESPFor(plr)
            end
        end
        Visual.Loop = Util.Connect(RunService.RenderStepped, Visual.RefreshESP)
    else
        if Visual.Loop then
            Util.Disconnect(Visual.Loop)
            Visual.Loop = nil
        end
        for plr, _ in pairs(Visual.ESPObjects) do
            Visual.DestroyESPFor(plr)
        end
        Visual.ESPObjects = {}
    end
end

-- ============================================================
-- SECTION 22: PERFORMANCE UTILITIES
-- ============================================================
local Perf = {}

Perf.FPS = 0
Perf.LastFPSUpdate = 0
Perf.FrameCount = 0
Perf.Ping = 0
Perf.Memory = 0
Perf.LowGraphics = false
Perf.SavedGraphics = nil

function Perf.GetPing()
    local ok, ping = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and ping then return ping end
    return 0
end

function Perf.GetMemory()
    local ok, mem = pcall(function()
        return StatsService:GetTotalMemoryUsageMb()
    end)
    if ok and mem then return mem end
    return 0
end

function Perf.StartLoop()
    if Perf.Loop then return end
    Perf.Loop = Util.Connect(RunService.RenderStepped, function()
        Perf.FrameCount = Perf.FrameCount + 1
        local now = tick()
        if now - Perf.LastFPSUpdate >= 0.5 then
            Perf.FPS = Perf.FrameCount / (now - Perf.LastFPSUpdate)
            Perf.FrameCount = 0
            Perf.LastFPSUpdate = now
            Perf.Ping = Perf.GetPing()
            Perf.Memory = Perf.GetMemory()
        end
    end)
end

function Perf.ToggleLowGraphics(enabled)
    Perf.LowGraphics = enabled
    if enabled then
        Perf.SavedGraphics = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
        }
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    else
        if Perf.SavedGraphics then
            Lighting.GlobalShadows = Perf.SavedGraphics.GlobalShadows
            Lighting.FogEnd = Perf.SavedGraphics.FogEnd
        end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    end
end

-- ============================================================
-- SECTION 23: CLEANUP MANAGER
-- ============================================================
local Cleanup = {}

function Cleanup.All()
    -- disconnect connections
    for _, c in ipairs(State.Connections) do
        pcall(function() c:Disconnect() end)
    end
    State.Connections = {}

    -- stop loops
    for k, c in pairs(State.Loops) do
        if typeof(c) == "RBXScriptConnection" then
            pcall(function() c:Disconnect() end)
        end
        State.Loops[k] = nil
    end

    -- cancel threads
    for _, t in ipairs(State.Threads) do
        pcall(function() task.cancel(t) end)
    end
    State.Threads = {}

    -- disable features
    pcall(function() CharUtil.InfiniteJump(false) end)
    pcall(function() CharUtil.Noclip(false) end)
    pcall(function() MoveUtil.ToggleFly(false) end)
    pcall(function() Visual.ToggleESP(false) end)

    -- clear notifications
    pcall(Notify.Clear)

    -- destroy GUI
    if Window.Gui then
        pcall(function() Window.Gui:Destroy() end)
        Window.Gui = nil
    end

    State.Instances = {}
    State.Ready = false
end

-- ============================================================
-- SECTION 24: ERROR HANDLING
-- ============================================================
local function SafeWrap(fn, context)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            warn(string.format("[Nexus] %s: %s", context or "error", tostring(err)))
        end
        return ok
    end
end

-- ============================================================
-- SECTION 25: BUILD THE INTERFACE
-- ============================================================
local function BuildHomePage(tab)
    local title = Label.new(tab.Content, { Name = "Welcome to " .. CONFIG.Name .. " v" .. CONFIG.Version, Value = "" })

    local info = Label.new(tab.Content, { Name = "Player", Value = LocalPlayer.Name })
    local display = Label.new(tab.Content, { Name = "Display Name", Value = LocalPlayer.DisplayName })
    local userid = Label.new(tab.Content, { Name = "User ID", Value = tostring(LocalPlayer.UserId) })
    local accage = Label.new(tab.Content, { Name = "Account Age", Value = tostring(LocalPlayer.AccountAge) .. " days" })

    local serverInfo = Label.new(tab.Content, { Name = "Server JobId", Value = tostring(game.JobId) })
    local playerCount = Label.new(tab.Content, { Name = "Players", Value = "#" .. tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers) })
    local placeInfo = Label.new(tab.Content, { Name = "Place ID", Value = tostring(game.PlaceId) })

    local fpsLabel = Label.new(tab.Content, { Name = "FPS", Value = "0" })
    local pingLabel = Label.new(tab.Content, { Name = "Ping", Value = "0 ms" })
    local timeLabel = Label.new(tab.Content, { Name = "Time", Value = Util.FormatClock() })
    local uptimeLabel = Label.new(tab.Content, { Name = "Session Uptime", Value = "00:00" })

    local startTime = tick()
    task.spawn(function()
        while State.Ready do
            pcall(function()
                fpsLabel:SetValue(string.format("%.0f", Perf.FPS))
                pingLabel:SetValue(string.format("%.0f ms", Perf.Ping))
                timeLabel:SetValue(Util.FormatClock())
                uptimeLabel:SetValue(Util.FormatTime(tick() - startTime))
                playerCount:SetValue("#" .. tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers))
            end)
            task.wait(0.5)
        end
    end)

    local quickHeader = Label.new(tab.Content, { Name = "-- Quick Toggles --", Value = "" })

    Toggle.new(tab.Content, {
        Name = "Infinite Jump",
        Default = false,
        Key = "QuickInfiniteJump",
        Changed = function(v) CharUtil.InfiniteJump(v) end,
    })

    Toggle.new(tab.Content, {
        Name = "Noclip",
        Default = false,
        Key = "QuickNoclip",
        Changed = function(v) CharUtil.Noclip(v) end,
    })

    Button.new(tab.Content, {
        Name = "Rejoin Server",
        Callback = function()
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end,
    })
end

local function BuildPlayerPage(tab)
    local selectedPlayer = nil

    local header = Label.new(tab.Content, { Name = "Player Selection", Value = "" })

    local currentLabel = Label.new(tab.Content, { Name = "Selected", Value = "None" })
    local distLabel = Label.new(tab.Content, { Name = "Distance", Value = "-" })
    local healthLabel = Label.new(tab.Content, { Name = "Health", Value = "-" })

    local drop = Dropdown.new(tab.Content, {
        Name = "Choose Player",
        Options = {},
        Changed = function(val)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Name == val or plr.DisplayName == val then
                    selectedPlayer = plr
                    currentLabel:SetValue(plr.Name)
                    break
                end
            end
        end,
    })

    local function refreshOptions()
        local names = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                table.insert(names, plr.Name)
            end
        end
        drop.Options = names
    end
    refreshOptions()

    Players.PlayerAdded:Connect(refreshOptions)
    Players.PlayerRemoving:Connect(refreshOptions)

    Button.new(tab.Content, {
        Name = "Teleport To Player",
        Callback = function()
            if selectedPlayer then
                PlayerUtil.TeleportTo(selectedPlayer)
            end
        end,
    })

    Toggle.new(tab.Content, {
        Name = "Highlight Selected Player",
        Default = false,
        Changed = function(v)
            if not selectedPlayer then return end
            if v then
                local hl = selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("NexusHighlight")
                if not hl and selectedPlayer.Character then
                    hl = Instance.new("Highlight")
                    hl.Name = "NexusHighlight"
                    hl.FillColor = Theme.Get("Accent")
                    hl.OutlineColor = Color3.new(1, 1, 1)
                    hl.FillTransparency = 0.6
                    hl.Parent = selectedPlayer.Character
                end
            else
                if selectedPlayer.Character then
                    local hl = selectedPlayer.Character:FindFirstChild("NexusHighlight")
                    if hl then hl:Destroy() end
                end
            end
        end,
    })

    task.spawn(function()
        while State.Ready do
            pcall(function()
                if selectedPlayer and selectedPlayer.Parent then
                    distLabel:SetValue(string.format("%.0f studs", PlayerUtil.GetDistance(selectedPlayer)))
                    local hp, maxhp = PlayerUtil.GetHealth(selectedPlayer)
                    healthLabel:SetValue(string.format("%.0f / %.0f", hp, maxhp))
                else
                    distLabel:SetValue("-")
                    healthLabel:SetValue("-")
                end
            end)
            task.wait(0.25)
        end
    end)
end

local function BuildCharacterPage(tab)
    local header = Label.new(tab.Content, { Name = "Character Information", Value = "" })

    local nameLabel = Label.new(tab.Content, { Name = "Name", Value = "-" })
    local healthLabel = Label.new(tab.Content, { Name = "Health", Value = "-" })
    local stateLabel = Label.new(tab.Content, { Name = "State", Value = "-" })
    local wsLabel = Label.new(tab.Content, { Name = "WalkSpeed", Value = "-" })
    local jpLabel = Label.new(tab.Content, { Name = "JumpPower", Value = "-" })

    local function refreshInfo()
        local hum = Util.GetHumanoid()
        local char = Util.GetCharacter()
        if char then nameLabel:SetValue(char.Name) else nameLabel:SetValue("-") end
        if hum then
            healthLabel:SetValue(string.format("%.0f / %.0f", hum.Health, hum.MaxHealth))
            stateLabel:SetValue(tostring(hum:GetState()))
            wsLabel:SetValue(tostring(hum.WalkSpeed))
            jpLabel:SetValue(tostring(hum.JumpPower))
        end
    end

    task.spawn(function()
        while State.Ready do
            pcall(refreshInfo)
            task.wait(0.3)
        end
    end)

    local header2 = Label.new(tab.Content, { Name = "Controls", Value = "" })

    Slider.new(tab.Content, {
        Name = "WalkSpeed",
        Min = 16, Max = 500, Step = 1, Default = 16,
        Changed = function(v) CharUtil.SetWalkSpeed(v) end,
    })

    Slider.new(tab.Content, {
        Name = "JumpPower",
        Min = 50, Max = 500, Step = 1, Default = 50,
        Changed = function(v) CharUtil.SetJumpPower(v) end,
    })

    Toggle.new(tab.Content, {
        Name = "Infinite Jump",
        Default = false,
        Changed = function(v) CharUtil.InfiniteJump(v) end,
    })

    Toggle.new(tab.Content, {
        Name = "Noclip",
        Default = false,
        Changed = function(v) CharUtil.Noclip(v) end,
    })

    Button.new(tab.Content, {
        Name = "Respawn",
        Callback = function()
            local hum = Util.GetHumanoid()
            if hum then
                pcall(function() hum.Health = 0 end)
            end
        end,
    })

    Button.new(tab.Content, {
        Name = "Reset Character",
        Callback = function()
            pcall(function() LocalPlayer.Character:BreakJoints() end)
        end,
    })
end

local function BuildMovementPage(tab)
    local header = Label.new(tab.Content, { Name = "Movement Features", Value = "" })

    Toggle.new(tab.Content, {
        Name = "Speed Enabled",
        Default = false,
        Key = "SpeedEnabled",
        Changed = function(v) MoveUtil.ToggleSpeed(v) end,
    })
    Slider.new(tab.Content, {
        Name = "Speed Value",
        Min = 16, Max = 300, Step = 1, Default = 16, Suffix = "",
        Key = "SpeedValue",
        Changed = function(v) MoveUtil.SetSpeed(v) end,
    })

    Toggle.new(tab.Content, {
        Name = "Jump Enabled",
        Default = false,
        Key = "JumpEnabled",
        Changed = function(v) MoveUtil.ToggleJump(v) end,
    })
    Slider.new(tab.Content, {
        Name = "Jump Value",
        Min = 50, Max = 300, Step = 1, Default = 50,
        Key = "JumpValue",
        Changed = function(v) MoveUtil.SetJump(v) end,
    })

    Toggle.new(tab.Content, {
        Name = "Fly",
        Default = false,
        Key = "FlyEnabled",
        Changed = function(v) MoveUtil.ToggleFly(v) end,
    })
    Slider.new(tab.Content, {
        Name = "Fly Speed",
        Min = 10, Max = 500, Step = 5, Default = 60,
        Key = "FlySpeed",
        Changed = function(v) MoveUtil.FlySpeed = v end,
    })

    local hint = Label.new(tab.Content, { Name = "Fly Controls", Value = "WASD / Space / LCtrl" })
end

local function BuildVisualsPage(tab)
    local header = Label.new(tab.Content, { Name = "ESP Options", Value = "" })

    Toggle.new(tab.Content, {
        Name = "Enable ESP",
        Default = false,
        Key = "ESP",
        Changed = function(v) Visual.ToggleESP(v) end,
    })
    Toggle.new(tab.Content, {
        Name = "Show Distance",
        Default = true,
        Key = "ESP_Distance",
        Changed = function(v) Visual.DrawDistance = v end,
    })
    Toggle.new(tab.Content, {
        Name = "Show Name",
        Default = true,
        Key = "ESP_Name",
        Changed = function(v) Visual.DrawName = v end,
    })
    Toggle.new(tab.Content, {
        Name = "Show Health",
        Default = true,
        Key = "ESP_Health",
        Changed = function(v) Visual.DrawHealth = v end,
    })

    Slider.new(tab.Content, {
        Name = "ESP Red",
        Min = 0, Max = 255, Step = 1, Default = 88,
        Changed = function(v)
            local c = Color3.fromRGB(v, 132, 255)
            Visual.AccentColor = c
            for _, obj in pairs(Visual.ESPObjects) do
                if obj.Name then obj.Name.TextColor3 = c end
            end
        end,
    })
    Slider.new(tab.Content, {
        Name = "ESP Green",
        Min = 0, Max = 255, Step = 1, Default = 132,
        Changed = function(v) end,
    })
    Slider.new(tab.Content, {
        Name = "ESP Blue",
        Min = 0, Max = 255, Step = 1, Default = 255,
        Changed = function(v) end,
    })
end

local function BuildUtilityPage(tab)
    local header = Label.new(tab.Content, { Name = "Server Information", Value = "" })

    Label.new(tab.Content, { Name = "Job ID", Value = tostring(game.JobId) })
    Label.new(tab.Content, { Name = "Place ID", Value = tostring(game.PlaceId) })
    Label.new(tab.Content, { Name = "Game ID", Value = tostring(game.GameId) })
    Label.new(tab.Content, { Name = "Creator ID", Value = tostring(game.CreatorId) })
    Label.new(tab.Content, { Name = "Max Players", Value = tostring(Players.MaxPlayers) })
    Label.new(tab.Content, { Name = "Player Count", Value = tostring(#Players:GetPlayers()) })

    Button.new(tab.Content, {
        Name = "Copy Job ID",
        Callback = function()
            if Util.CopyToClipboard(game.JobId) then
                Notify.Push("Utility", "Job ID copied to clipboard", 3, "success")
            else
                Notify.Push("Utility", "Copy failed (no executor clipboard)", 3, "error")
            end
        end,
    })

    Button.new(tab.Content, {
        Name = "Copy Place ID",
        Callback = function()
            if Util.CopyToClipboard(tostring(game.PlaceId)) then
                Notify.Push("Utility", "Place ID copied to clipboard", 3, "success")
            else
                Notify.Push("Utility", "Copy failed", 3, "error")
            end
        end,
    })

    Button.new(tab.Content, {
        Name = "Rejoin Server",
        Callback = function()
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end,
    })

    Button.new(tab.Content, {
        Name = "Server Hop (random)",
        Callback = function()
            pcall(function()
                local req = HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
                ))
                if req and req.data then
                    for _, srv in ipairs(req.data) do
                        if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                            return
                        end
                    end
                end
                Notify.Push("Utility", "No suitable servers found", 3, "warning")
            end)
        end,
    })

    local header2 = Label.new(tab.Content, { Name = "Notifications", Value = "" })

    Button.new(tab.Content, {
        Name = "Test Success Notification",
        Callback = function() Notify.Push("Success", "Operation completed!", 3, "success") end,
    })
    Button.new(tab.Content, {
        Name = "Test Warning Notification",
        Callback = function() Notify.Push("Warning", "Something may be wrong.", 3, "warning") end,
    })
    Button.new(tab.Content, {
        Name = "Test Error Notification",
        Callback = function() Notify.Push("Error", "Something went wrong!", 3, "error") end,
    })
    Button.new(tab.Content, {
        Name = "Clear All Notifications",
        Callback = function() Notify.Clear() end,
    })
end

local function BuildPerformancePage(tab)
    local header = Label.new(tab.Content, { Name = "Realtime Information", Value = "" })

    local fpsLabel = Label.new(tab.Content, { Name = "FPS", Value = "0" })
    local pingLabel = Label.new(tab.Content, { Name = "Ping", Value = "0 ms" })
    local memLabel = Label.new(tab.Content, { Name = "Memory", Value = "0 MB" })

    task.spawn(function()
        while State.Ready do
            pcall(function()
                fpsLabel:SetValue(string.format("%.0f", Perf.FPS))
                pingLabel:SetValue(string.format("%.0f ms", Perf.Ping))
                memLabel:SetValue(string.format("%.1f MB", Perf.Memory))
            end)
            task.wait(0.5)
        end
    end)

    local header2 = Label.new(tab.Content, { Name = "Performance Toggles", Value = "" })

    Toggle.new(tab.Content, {
        Name = "Low Graphics Mode",
        Default = false,
        Key = "LowGraphics",
        Changed = function(v) Perf.ToggleLowGraphics(v) end,
    })

    Slider.new(tab.Content, {
        Name = "Field of View",
        Min = 50, Max = 120, Step = 1, Default = 70,
        Changed = function(v) CamUtil.SetFOV(v) end,
    })

    Button.new(tab.Content, {
        Name = "Reset FOV",
        Callback = function() CamUtil.SetFOV(70) end,
    })
end

local function BuildSettingsPage(tab)
    local header = Label.new(tab.Content, { Name = "Interface Settings", Value = "" })

    Keybind.new(tab.Content, {
        Name = "Toggle Key",
        Default = State.ToggleKey,
        Changed = function(k)
            State.ToggleKey = k
            Notify.Push("Settings", "Toggle key set to " .. k.Name, 2, "info")
        end,
    })

    Slider.new(tab.Content, {
        Name = "UI Scale",
        Min = 70, Max = 130, Step = 5, Default = 100, Suffix = "%",
        Changed = function(v)
            State.UIScale = v / 100
            pcall(function()
                if Window.Gui then
                    Window.Gui.IgnoreGuiInset = Window.Gui.IgnoreGuiInset
                end
            end)
        end,
    })

    Toggle.new(tab.Content, {
        Name = "Enable Animations",
        Default = State.AnimationsEnabled,
        Changed = function(v) State.AnimationsEnabled = v end,
    })

    Toggle.new(tab.Content, {
        Name = "Enable Notifications",
        Default = State.NotificationsEnabled,
        Changed = function(v) State.NotificationsEnabled = v end,
    })

    local header2 = Label.new(tab.Content, { Name = "Theme", Value = "" })

    Dropdown.new(tab.Content, {
        Name = "Theme",
        Options = { "Dark", "Midnight", "Crimson", "Forest", "Light" },
        Default = "Dark",
        Changed = function(v)
            if Theme.SetTheme(v) then
                Notify.Push("Theme", "Theme changed to " .. v, 2, "success")
            end
        end,
    })

    Slider.new(tab.Content, {
        Name = "Accent Red",
        Min = 0, Max = 255, Step = 1, Default = 88,
        Changed = function(v)
            local c = Theme.Get("Accent")
            Theme.SetAccent(Color3.fromRGB(v, c.G * 255, c.B * 255))
        end,
    })
    Slider.new(tab.Content, {
        Name = "Accent Green",
        Min = 0, Max = 255, Step = 1, Default = 132,
        Changed = function(v)
            local c = Theme.Get("Accent")
            Theme.SetAccent(Color3.fromRGB(c.R * 255, v, c.B * 255))
        end,
    })
    Slider.new(tab.Content, {
        Name = "Accent Blue",
        Min = 0, Max = 255, Step = 1, Default = 255,
        Changed = function(v)
            local c = Theme.Get("Accent")
            Theme.SetAccent(Color3.fromRGB(c.R * 255, c.G * 255, v))
        end,
    })

    local header3 = Label.new(tab.Content, { Name = "Configuration", Value = "" })

    Button.new(tab.Content, {
        Name = "Save Configuration",
        Callback = function()
            ConfigStore.Save()
            Notify.Push("Config", "Configuration saved", 2, "success")
        end,
    })

    Button.new(tab.Content, {
        Name = "Load Configuration",
        Callback = function()
            if ConfigStore.Load() then
                Notify.Push("Config", "Configuration loaded", 2, "success")
            else
                Notify.Push("Config", "No configuration found", 2, "warning")
            end
        end,
    })

    Button.new(tab.Content, {
        Name = "Reset Settings",
        Callback = function()
            ConfigStore.Reset()
            Notify.Push("Config", "Settings reset", 2, "info")
        end,
    })

    Button.new(tab.Content, {
        Name = "Destroy GUI",
        Callback = function()
            Cleanup.All()
        end,
    })
end

-- ============================================================
-- SECTION 26: INITIALIZATION
-- ============================================================
local function Init()
    if State.Ready then return end
    State.Ready = true

    ConfigStore.Detect()
    ConfigStore.Load()

    Perf.StartLoop()

    local win = Window.Create()

    -- Create tabs
    win:CreateTab("Home")
    win:CreateTab("Player")
    win:CreateTab("Character")
    win:CreateTab("Movement")
    win:CreateTab("Visuals")
    win:CreateTab("Utility")
    win:CreateTab("Performance")
    win:CreateTab("Settings")

    -- Build pages
    SafeWrap(BuildHomePage, "Home")(win.Tabs["Home"])
    SafeWrap(BuildPlayerPage, "Player")(win.Tabs["Player"])
    SafeWrap(BuildCharacterPage, "Character")(win.Tabs["Character"])
    SafeWrap(BuildMovementPage, "Movement")(win.Tabs["Movement"])
    SafeWrap(BuildVisualsPage, "Visuals")(win.Tabs["Visuals"])
    SafeWrap(BuildUtilityPage, "Utility")(win.Tabs["Utility"])
    SafeWrap(BuildPerformancePage, "Performance")(win.Tabs["Performance"])
    SafeWrap(BuildSettingsPage, "Settings")(win.Tabs["Settings"])

    -- Select first tab
    win:SelectTab("Home")

    -- Opening animation
    if State.AnimationsEnabled then
        win.Main.Size = UDim2.new(1, 0, 0, 0)
        Anim.Tween(win.Main, { Size = UDim2.new(1, 0, 1, 0) }, 0.4, Enum.EasingStyle.Quint)
    end

    -- Welcome notification
    task.delay(0.4, function()
        Notify.Push(CONFIG.Name .. " v" .. CONFIG.Version, "Loaded successfully.", 3, "success")
    end)

    -- Character respawn handling
    Util.Connect(LocalPlayer.CharacterAdded, function(char)
        task.wait(1)
        Notify.Push("Character", "Respawned as " .. char.Name, 2, "info")
        -- re-apply character features
        if State.Features and State.Features.QuickNoclip then
            CharUtil.Noclip(true)
        end
    end)
end

-- ============================================================
-- SECTION 27: BOOT
-- ============================================================
do
    local ok, err = pcall(Init)
    if not ok then
        warn("[Nexus] Failed to initialize: " .. tostring(err))
    end
end

-- Expose for external access (optional)
if getgenv then
    pcall(function()
        getgenv().Nexus = {
            Window = Window,
            Notify = Notify,
            Theme = Theme,
            Cleanup = Cleanup.All,
            Config = ConfigStore,
            State = State,
        }
    end)
end

-- ============================================================
-- END OF SCRIPT
-- ============================================================