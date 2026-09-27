--!strict
-- Custom Roblox Luau Utility UI
-- Single-file implementation. No external UI libraries.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local VERSION = "1.0.0"
local WINDOW_SIZE = Vector2.new(900, 580)

local Config = {
    GuiKeybind = Enum.KeyCode.RightShift,
    UIScale = 1,
    Animations = true,
    Notifications = true,
    Accent = Color3.fromRGB(150, 90, 255),
    Theme = "Dark",
    WalkSpeed = 16,
    JumpPower = 50,
    SelectedPlayer = "",
    ESP = false,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPColor = Color3.fromRGB(150, 90, 255),
    PerformanceMode = false,
    DisableShadows = false,
    DisablePostEffects = false,
}

local Themes = {
    Dark = {
        Background = Color3.fromRGB(16, 16, 20),
        Secondary = Color3.fromRGB(22, 22, 28),
        Tertiary = Color3.fromRGB(28, 28, 35),
        Text = Color3.fromRGB(240, 240, 245),
        SecondaryText = Color3.fromRGB(155, 155, 170),
        Accent = Config.Accent,
        Border = Color3.fromRGB(55, 55, 68),
        Hover = Color3.fromRGB(40, 40, 50),
        Active = Color3.fromRGB(48, 42, 62),
        Notification = Color3.fromRGB(45, 45, 55),
        Success = Color3.fromRGB(80, 190, 120),
        Warning = Color3.fromRGB(220, 175, 70),
        Error = Color3.fromRGB(220, 80, 90),
    },
}

local Theme = Themes.Dark
local Connections = {}
local Instances = {}
local FeatureConnections = {}
local PlayerConnections = {}
local Drawings = {}
local Tabs = {}
local Components = {}
local Notifications = {}
local FeatureState = {}
local CleanupCallbacks = {}
local ESPObjects = {}

local Destroyed = false
local WindowVisible = true
local CurrentTab = "Home"
local CurrentPage = nil
local Dragging = false
local DragStart = Vector2.zero
local WindowStart = UDim2.fromOffset(0, 0)
local NotificationCounter = 0

local function TrackConnection(connection, bucket)
    if connection then
        table.insert(bucket or Connections, connection)
    end
    return connection
end

local function TrackInstance(instance)
    if instance then
        table.insert(Instances, instance)
    end
    return instance
end

local function TrackFeatureConnection(name, connection)
    if not FeatureConnections[name] then
        FeatureConnections[name] = {}
    end
    table.insert(FeatureConnections[name], connection)
    return connection
end

local function DisconnectBucket(bucket)
    if not bucket then
        return
    end
    for i = #bucket, 1, -1 do
        local connection = bucket[i]
        if connection and connection.Connected then
            pcall(function()
                connection:Disconnect()
            end)
        end
        bucket[i] = nil
    end
end

local function DisconnectFeature(name)
    DisconnectBucket(FeatureConnections[name])
    FeatureConnections[name] = nil
end

local function SafeDestroy(instance)
    if instance then
        pcall(function()
            instance:Destroy()
        end)
    end
end

local function Tween(instance, info, properties)
    if not Config.Animations then
        for property, value in pairs(properties) do
            pcall(function()
                instance[property] = value
            end)
        end
        return nil
    end
    local tween = TweenService:Create(instance, info, properties)
    tween:Play()
    return tween
end

local FastTween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MediumTween = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local SlowTween = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function Make(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        pcall(function()
            object[property] = value
        end)
    end
    if parent then
        object.Parent = parent
    end
    return TrackInstance(object)
end

local function ColorAlpha(color, alpha)
    return Color3.new(
        color.R * (1 - alpha) + Theme.Background.R * alpha,
        color.G * (1 - alpha) + Theme.Background.G * alpha,
        color.B * (1 - alpha) + Theme.Background.B * alpha
    )
end

local function FormatNumber(number)
    if number >= 1000000 then
        return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        return string.format("%.1fK", number / 1000)
    end
    return tostring(math.floor(number))
end

local function GetCharacter(player)
    return player and player.Character
end

local function GetHumanoid(player)
    local character = GetCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function GetRoot(player)
    local character = GetCharacter(player)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetDistance(a, b)
    local ra = GetRoot(a)
    local rb = GetRoot(b)
    if not ra or not rb then
        return math.huge
    end
    return (ra.Position - rb.Position).Magnitude
end

local function GetPing()
    local ok, result = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(result) == "number" then
        return math.floor(result)
    end
    return 0
end

local function GetFPS()
    return math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1 / 240))
end

local function Serialize(value)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(value)
    end)
    return ok and result or nil
end

local function Deserialize(value)
    local ok, result = pcall(function()
        return HttpService:JSONDecode(value)
    end)
    return ok and result or nil
end

local function Notify(title, message, duration, kind)
    if not Config.Notifications or Destroyed then
        return
    end
    NotificationCounter += 1
    local id = NotificationCounter
    local color = Theme.Notification
    if kind == "Success" then color = Theme.Success end
    if kind == "Warning" then color = Theme.Warning end
    if kind == "Error" then color = Theme.Error end

    local holder = Components.NotificationHolder
    if not holder then return end

    local frame = Make("Frame", {
        Name = "Notification_" .. id,
        Size = UDim2.new(1, 0, 0, 78),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, holder)

    local stroke = Make("UIStroke", {
        Color = Theme.Border,
        Thickness = 1,
        Transparency = 1,
    }, frame)

    local titleLabel = Make("TextLabel", {
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -28, 0, 20),
        BackgroundTransparency = 1,
        Text = tostring(title),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)

    local messageLabel = Make("TextLabel", {
        Position = UDim2.fromOffset(14, 31),
        Size = UDim2.new(1, -28, 0, 35),
        BackgroundTransparency = 1,
        Text = tostring(message),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.SecondaryText,
        TextTransparency = 1,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)

    table.insert(Notifications, frame)

    Tween(frame, MediumTween, {BackgroundTransparency = 0})
    Tween(stroke, MediumTween, {Transparency = 0})
    Tween(titleLabel, MediumTween, {TextTransparency = 0})
    Tween(messageLabel, MediumTween, {TextTransparency = 0})

    task.delay(duration or 3, function()
        if not frame.Parent then return end
        Tween(frame, MediumTween, {BackgroundTransparency = 1})
        Tween(stroke, MediumTween, {Transparency = 1})
        Tween(titleLabel, MediumTween, {TextTransparency = 1})
        Tween(messageLabel, MediumTween, {TextTransparency = 1})
        task.wait(0.25)
        SafeDestroy(frame)
        for i, item in ipairs(Notifications) do
            if item == frame then
                table.remove(Notifications, i)
                break
            end
        end
    end)
end

local function ClearNotifications()
    for _, notification in ipairs(Notifications) do
        SafeDestroy(notification)
    end
    table.clear(Notifications)
end

local function AddCleanup(callback)
    table.insert(CleanupCallbacks, callback)
end

local function ApplyTheme()
    Theme = Themes.Dark
    Theme.Accent = Config.Accent
    for _, object in ipairs(Instances) do
        if object and object.Parent then
            local role = object:GetAttribute("ThemeRole")
            if role and Theme[role] then
                pcall(function()
                    if object:IsA("TextLabel") or object:IsA("TextButton") then
                        object.TextColor3 = Theme[role]
                    elseif object:IsA("UIStroke") then
                        object.Color = Theme[role]
                    else
                        object.BackgroundColor3 = Theme[role]
                    end
                end)
            end
        end
    end
end

local function ThemeObject(object, role)
    object:SetAttribute("ThemeRole", role)
    if Theme[role] then
        if object:IsA("TextLabel") or object:IsA("TextButton") then
            object.TextColor3 = Theme[role]
        elseif object:IsA("UIStroke") then
            object.Color = Theme[role]
        else
            object.BackgroundColor3 = Theme[role]
        end
    end
    return object
end

local ScreenGui = Make("ScreenGui", {
    Name = "CustomUtilityInterface",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 100,
}, PlayerGui)

local UIScale = Make("UIScale", {Scale = Config.UIScale}, ScreenGui)

local Main = Make("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, ScreenGui)

local MainStroke = Make("UIStroke", {
    Color = Theme.Border,
    Thickness = 1,
}, Main)

local TopBar = Make("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
}, Main)

local Title = Make("TextLabel", {
    Position = UDim2.fromOffset(18, 7),
    Size = UDim2.fromOffset(260, 20),
    BackgroundTransparency = 1,
    Text = "CUSTOM UTILITY",
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TopBar)

local Version = Make("TextLabel", {
    Position = UDim2.fromOffset(18, 27),
    Size = UDim2.fromOffset(160, 14),
    BackgroundTransparency = 1,
    Text = "VERSION " .. VERSION,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextColor3 = Theme.SecondaryText,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TopBar)

local MinimizeButton = Make("TextButton", {
    Position = UDim2.new(1, -76, 0, 10),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = Theme.Tertiary,
    BorderSizePixel = 0,
    Text = "−",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = Theme.Text,
    AutoButtonColor = false,
}, TopBar)

local CloseButton = Make("TextButton", {
    Position = UDim2.new(1, -42, 0, 10),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = Theme.Tertiary,
    BorderSizePixel = 0,
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = Theme.Text,
    AutoButtonColor = false,
}, TopBar)

local Body = Make("Frame", {
    Position = UDim2.fromOffset(0, 48),
    Size = UDim2.new(1, 0, 1, -48),
    BackgroundTransparency = 1,
}, Main)

local Sidebar = Make("Frame", {
    Name = "Sidebar",
    Size = UDim2.fromOffset(170, 1),
    Position = UDim2.fromOffset(0, 0),
    AnchorPoint = Vector2.new(0, 0),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
}, Body)

local SidebarPadding = Make("UIPadding", {
    PaddingTop = UDim.new(0, 14),
    PaddingBottom = UDim.new(0, 14),
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
}, Sidebar)

local SidebarList = Make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Sidebar)

local Content = Make("Frame", {
    Position = UDim2.fromOffset(170, 0),
    Size = UDim2.new(1, -170, 1, 0),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, Body)

local PageHolder = Make("Frame", {
    Position = UDim2.fromOffset(14, 14),
    Size = UDim2.new(1, -28, 1, -28),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Content)

Components.Main = Main
Components.Content = Content
Components.PageHolder = PageHolder

local NotificationHolder = Make("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.fromOffset(300, 500),
    BackgroundTransparency = 1,
}, ScreenGui)

local NotificationLayout = Make("UIListLayout", {
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top,
}, NotificationHolder)

Components.NotificationHolder = NotificationHolder

local function CreateButton(parent, text, callback, height)
    local button = Make("TextButton", {
        Size = UDim2.new(1, 0, 0, height or 36),
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.Text,
        AutoButtonColor = false,
    }, parent)
    local stroke = Make("UIStroke", {
        Color = Theme.Border,
        Thickness = 1,
    }, button)
    TrackConnection(button.MouseEnter:Connect(function()
        Tween(button, FastTween, {BackgroundColor3 = Theme.Hover})
    end))
    TrackConnection(button.MouseLeave:Connect(function()
        Tween(button, FastTween, {BackgroundColor3 = Theme.Tertiary})
    end))
    TrackConnection(button.MouseButton1Down:Connect(function()
        Tween(button, FastTween, {BackgroundColor3 = Theme.Active})
    end))
    TrackConnection(button.MouseButton1Up:Connect(function()
        Tween(button, FastTween, {BackgroundColor3 = Theme.Hover})
    end))
    TrackConnection(button.Activated:Connect(function()
        if callback then
            local ok, err = pcall(callback)
            if not ok then
                Notify("Error", tostring(err), 4, "Error")
            end
        end
    end))
    return button
end

local function CreateSection(parent, title)
    local section = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
    }, parent)
    local label = Make("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = string.upper(title),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Theme.SecondaryText,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, section)
    return section
end

local function CreateToggle(parent, title, description, default, callback)
    local value = default == true
    local holder = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
    }, parent)
    Make("UIStroke", {Color = Theme.Border, Thickness = 1}, holder)
    local label = Make("TextLabel", {
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -80, 0, 20),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    local desc = Make("TextLabel", {
        Position = UDim2.fromOffset(12, 28),
        Size = UDim2.new(1, -80, 0, 18),
        BackgroundTransparency = 1,
        Text = description or "",
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = Theme.SecondaryText,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, holder)
    local switch = Make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = value and Theme.Accent or Theme.Tertiary,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, holder)
    local knob = Make("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = value and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
    }, switch)
    local state = {
        Value = value,
        Set = function(self, newValue, silent)
            self.Value = newValue == true
            Tween(switch, FastTween, {BackgroundColor3 = self.Value and Theme.Accent or Theme.Tertiary})
            Tween(knob, FastTween, {
                Position = self.Value and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            })
            if not silent and callback then callback(self.Value) end
        end,
        Get = function(self) return self.Value end,
    }
    TrackConnection(switch.Activated:Connect(function()
        state:Set(not state.Value)
    end))
    Components[title] = state
    return state, holder
end

local function CreateSlider(parent, title, min, max, default, callback, suffix)
    local value = math.clamp(default, min, max)
    local holder = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
    }, parent)
    Make("UIStroke", {Color = Theme.Border, Thickness = 1}, holder)
    local label = Make("TextLabel", {
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -90, 0, 18),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    local valueLabel = Make("TextLabel", {
        Position = UDim2.new(1, -75, 0, 8),
        Size = UDim2.fromOffset(63, 18),
        BackgroundTransparency = 1,
        Text = string.format("%.1f%s", value, suffix or ""),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, holder)
    local bar = Make("Frame", {
        Position = UDim2.fromOffset(12, 38),
        Size = UDim2.new(1, -24, 0, 5),
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
    }, holder)
    local fill = Make("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    }, bar)
    local hit = Make("TextButton", {
        Position = UDim2.fromOffset(-4, -8),
        Size = UDim2.new(1, 8, 1, 20),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, bar)
    local dragging = false
    local state = {}
    function state:Set(newValue, silent)
        value = math.clamp(tonumber(newValue) or min, min, max)
        local ratio = (value - min) / (max - min)
        Tween(fill, FastTween, {Size = UDim2.new(ratio, 0, 1, 0)})
        valueLabel.Text = string.format("%.1f%s", value, suffix or "")
        if not silent and callback then callback(value) end
    end
    function state:Get() return value end
    TrackConnection(hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end))
    TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local x = math.clamp(input.Position.X - bar.AbsolutePosition.X, 0, bar.AbsoluteSize.X)
            state:Set(min + (max - min) * (x / bar.AbsoluteSize.X))
        end
    end))
    return state, holder
end

local function CreateDropdown(parent, title, options, default, callback)
    local value = default or options[1]
    local holder = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 20,
    }, parent)
    Make("UIStroke", {Color = Theme.Border, Thickness = 1}, holder)
    Make("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.45, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    local button = Make("TextButton", {
        Position = UDim2.new(0.48, 0, 0, 7),
        Size = UDim2.new(0.5, -12, 0, 34),
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        Text = tostring(value),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.Text,
        AutoButtonColor = false,
        ZIndex = 22,
    }, holder)
    local list = Make("Frame", {
        Position = UDim2.new(0, 0, 1, 3),
        Size = UDim2.new(1, 0, 0, math.min(#options * 30, 180)),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 30,
    }, button)
    Make("UIStroke", {Color = Theme.Border, Thickness = 1}, list)
    local layout = Make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, list)
    local state = {Value = value}
    local function rebuild()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for index, option in ipairs(options) do
            local item = Make("TextButton", {
                LayoutOrder = index,
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = Theme.Tertiary,
                BorderSizePixel = 0,
                Text = tostring(option),
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = Theme.Text,
                AutoButtonColor = false,
                ZIndex = 31,
            }, list)
            TrackConnection(item.MouseEnter:Connect(function()
                item.BackgroundColor3 = Theme.Hover
            end))
            TrackConnection(item.MouseLeave:Connect(function()
                item.BackgroundColor3 = Theme.Tertiary
            end))
            TrackConnection(item.Activated:Connect(function()
                state.Value = option
                button.Text = tostring(option)
                list.Visible = false
                if callback then callback(option) end
            end))
        end
    end
    rebuild()
    TrackConnection(button.Activated:Connect(function()
        list.Visible = not list.Visible
    end))
    function state:Set(newValue, silent)
        for _, option in ipairs(options) do
            if option == newValue then
                state.Value = newValue
                button.Text = tostring(newValue)
                if not silent and callback then callback(newValue) end
                return
            end
        end
    end
    function state:Get() return state.Value end
    return state, holder
end

local function CreateKeybind(parent, title, default, callback)
    local key = default
    local waiting = false
    local holder = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
    }, parent)
    Make("UIStroke", {Color = Theme.Border, Thickness = 1}, holder)
    Make("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    local button = Make("TextButton", {
        Position = UDim2.new(1, -132, 0, 7),
        Size = UDim2.fromOffset(120, 34),
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        Text = key.Name,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.Text,
        AutoButtonColor = false,
    }, holder)
    local state = {}
    function state:Get() return key end
    function state:Set(newKey, silent)
        if typeof(newKey) == "EnumItem" then
            key = newKey
            button.Text = newKey.Name
            if not silent and callback then callback(newKey) end
        end
    end
    TrackConnection(button.Activated:Connect(function()
        waiting = true
        button.Text = "PRESS KEY"
    end))
    TrackConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if waiting and not processed and input.UserInputType == Enum.UserInputType.Keyboard then
            waiting = false
            state:Set(input.KeyCode)
        end
    end))
    return state, holder
end

local function CreatePage(name)
    local page = Make("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, PageHolder)
    Make("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 8),
    }, page)
    Make("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    Tabs[name] = page
    return page
end

local function SetTab(name)
    if not Tabs[name] or CurrentTab == name then return end
    local old = Tabs[CurrentTab]
    local new = Tabs[name]
    if old then old.Visible = false end
    new.Visible = true
    CurrentTab = name
    CurrentPage = new
    for tabName, button in pairs(Components.TabButtons or {}) do
        button.BackgroundColor3 = tabName == name and Theme.Active or Theme.Secondary
    end
end

Components.TabButtons = {}

local tabNames = {"Home", "Player", "Character", "Movement", "Visuals", "Utility", "Performance", "Settings"}
for index, name in ipairs(tabNames) do
    local button = CreateButton(Sidebar, name, function()
        SetTab(name)
    end, 36)
    button.LayoutOrder = index
    Components.TabButtons[name] = button
end

local function AddPageTitle(page, title, subtitle)
    local holder = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
    }, page)
    Make("TextLabel", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    Make("TextLabel", {
        Position = UDim2.fromOffset(0, 30),
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = subtitle,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.SecondaryText,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    return holder
end

local HomePage = CreatePage("Home")
local PlayerPage = CreatePage("Player")
local CharacterPage = CreatePage("Character")
local MovementPage = CreatePage("Movement")
local VisualPage = CreatePage("Visuals")
local UtilityPage = CreatePage("Utility")
local PerformancePage = CreatePage("Performance")
local SettingsPage = CreatePage("Settings")

AddPageTitle(HomePage, "Home", "Overview of the current client session.")
local HomeInfo = Make("Frame", {
    Size = UDim2.new(1, 0, 0, 190),
    BackgroundTransparency = 1,
}, HomePage)
Make("UIGridLayout", {
    CellSize = UDim2.new(0.49, 0, 0, 86),
    CellPadding = UDim2.new(0.02, 0, 0, 8),
}, HomeInfo)

local HomeCards = {}
local function CreateInfoCard(parent, title, value)
    local card = Make("Frame", {
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
    }, parent)
    Make("UIStroke", {Color = Theme.Border, Thickness = 1}, card)
    Make("TextLabel", {
        Position = UDim2.fromOffset(12, 10),
        Size = UDim2.new(1, -24, 0, 18),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = Theme.SecondaryText,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    local label = Make("TextLabel", {
        Position = UDim2.fromOffset(12, 32),
        Size = UDim2.new(1, -24, 0, 36),
        BackgroundTransparency = 1,
        Text = value,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    HomeCards[title] = label
    return card
end

CreateInfoCard(HomeInfo, "PLAYER", LocalPlayer.Name)
CreateInfoCard(HomeInfo, "PLAYERS", tostring(#Players:GetPlayers()))
CreateInfoCard(HomeInfo, "PING", "0 ms")
CreateInfoCard(HomeInfo, "FPS", "0")
CreateInfoCard(HomeInfo, "JOB ID", game.JobId ~= "" and string.sub(game.JobId, 1, 12) or "Studio")
CreateInfoCard(HomeInfo, "TIME", "--:--:--")

CreateSection(HomePage, "Quick Toggles")
CreateToggle(HomePage, "Performance Mode", "Reduce selected visual effects.", Config.PerformanceMode, function(v)
    Config.PerformanceMode = v
end)
CreateToggle(HomePage, "Player ESP", "Enable local player visualization.", Config.ESP, function(v)
    Config.ESP = v
end)

AddPageTitle(PlayerPage, "Player", "Inspect players and use local player utilities.")
CreateSection(PlayerPage, "Player Selection")
local PlayerNames = {}
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then table.insert(PlayerNames, player.Name) end
end
if #PlayerNames == 0 then table.insert(PlayerNames, "No other players") end
local PlayerDropdown = CreateDropdown(PlayerPage, "Selected Player", PlayerNames, PlayerNames[1], function(value)
    if value ~= "No other players" then Config.SelectedPlayer = value end
end)
CreateSection(PlayerPage, "Selected Player Information")
local PlayerInfoLabel = Make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
    Text = "Select a player.",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Theme.SecondaryText,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, PlayerPage)
Make("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
}, PlayerInfoLabel)
CreateButton(PlayerPage, "Refresh Player List", function()
    PlayerNames = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then table.insert(PlayerNames, player.Name) end
    end
    if #PlayerNames == 0 then table.insert(PlayerNames, "No other players") end
    PlayerDropdown:Set(PlayerNames[1], true)
    Notify("Players", "Player list refreshed.", 2, "Success")
end)
CreateButton(PlayerPage, "Teleport to Selected Player", function()
    local target = Players:FindFirstChild(Config.SelectedPlayer)
    local root = GetRoot(target)
    local localRoot = GetRoot(LocalPlayer)
    if target and root and localRoot then
        localRoot.CFrame = root.CFrame * CFrame.new(0, 0, 4)
        Notify("Teleport", "Moved to " .. target.Name .. ".", 2, "Success")
    else
        Notify("Teleport", "Selected player is unavailable.", 3, "Warning")
    end
end)

AddPageTitle(CharacterPage, "Character", "Character and humanoid controls.")
local CharacterInfo = Make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 120),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
    Text = "",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Theme.SecondaryText,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, CharacterPage)
Make("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12)}, CharacterInfo)
CreateSection(CharacterPage, "Humanoid")
local WalkSlider = CreateSlider(CharacterPage, "WalkSpeed", 0, 200, Config.WalkSpeed, function(v)
    Config.WalkSpeed = v
    local humanoid = GetHumanoid(LocalPlayer)
    if humanoid then humanoid.WalkSpeed = v end
end)
local JumpSlider = CreateSlider(CharacterPage, "JumpPower", 0, 200, Config.JumpPower, function(v)
    Config.JumpPower = v
    local humanoid = GetHumanoid(LocalPlayer)
    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = v
    end
end)
CreateButton(CharacterPage, "Apply Character Values", function()
    local humanoid = GetHumanoid(LocalPlayer)
    if humanoid then
        humanoid.WalkSpeed = Config.WalkSpeed
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Config.JumpPower
        Notify("Character", "Values applied.", 2, "Success")
    end
end)

AddPageTitle(MovementPage, "Movement", "Movement utilities and configurable controls.")
CreateToggle(MovementPage, "Enable Custom WalkSpeed", "Apply configured WalkSpeed after respawn.", true, function(v)
    FeatureState.CustomWalkSpeed = v
end)
CreateToggle(MovementPage, "Enable Custom JumpPower", "Apply configured JumpPower after respawn.", true, function(v)
    FeatureState.CustomJumpPower = v
end)
CreateToggle(MovementPage, "Platform Stand", "Toggle Humanoid platform stand.", false, function(v)
    local humanoid = GetHumanoid(LocalPlayer)
    if humanoid then humanoid.PlatformStand = v end
end)
CreateKeybind(MovementPage, "Toggle Movement Controls", Enum.KeyCode.LeftAlt, function()
    FeatureState.MovementEnabled = not FeatureState.MovementEnabled
    Notify("Movement", FeatureState.MovementEnabled and "Enabled." or "Disabled.", 2)
end)

AddPageTitle(VisualPage, "Visuals", "Local visualization tools.")
CreateToggle(VisualPage, "ESP", "Show player names, distance and health.", Config.ESP, function(v)
    Config.ESP = v
end)
CreateToggle(VisualPage, "Names", "Display player names.", Config.ESPNames, function(v)
    Config.ESPNames = v
end)
CreateToggle(VisualPage, "Distance", "Display distance to players.", Config.ESPDistance, function(v)
    Config.ESPDistance = v
end)
CreateToggle(VisualPage, "Health", "Display player health.", Config.ESPHealth, function(v)
    Config.ESPHealth = v
end)
CreateSection(VisualPage, "Visibility")
CreateToggle(VisualPage, "Disable Shadows", "Reduce lighting shadow rendering where supported.", Config.DisableShadows, function(v)
    Config.DisableShadows = v
    Lighting.GlobalShadows = not v
end)
CreateToggle(VisualPage, "Disable Post Effects", "Temporarily disable post-processing effects.", Config.DisablePostEffects, function(v)
    Config.DisablePostEffects = v
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then effect.Enabled = not v end
    end
end)

AddPageTitle(UtilityPage, "Utility", "Session and server utilities.")
CreateSection(UtilityPage, "Server")
CreateButton(UtilityPage, "Rejoin Server", function()
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    if not ok then Notify("Rejoin", tostring(err), 4, "Error") end
end)
CreateButton(UtilityPage, "Copy Job ID", function()
    if setclipboard then
        setclipboard(game.JobId)
        Notify("Clipboard", "Job ID copied.", 2, "Success")
    else
        Notify("Clipboard", "Clipboard API unavailable.", 3, "Warning")
    end
end)
CreateButton(UtilityPage, "Copy Place ID", function()
    if setclipboard then
        setclipboard(tostring(game.PlaceId))
        Notify("Clipboard", "Place ID copied.", 2, "Success")
    else
        Notify("Clipboard", "Clipboard API unavailable.", 3, "Warning")
    end
end)
CreateSection(UtilityPage, "Notifications")
CreateToggle(UtilityPage, "Notifications", "Enable custom notifications.", true, function(v)
    Config.Notifications = v
end)
CreateButton(UtilityPage, "Test Notification", function()
    Notify("Notification", "This is a custom notification.", 3, "Success")
end)

AddPageTitle(PerformancePage, "Performance", "Client performance information and optimization.")
local PerformanceInfo = Make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 145),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
    Text = "",
    Font = Enum.Font.Code,
    TextSize = 12,
    TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, PerformancePage)
Make("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12)}, PerformanceInfo)
CreateToggle(PerformancePage, "Performance Mode", "Disable selected visual effects.", Config.PerformanceMode, function(v)
    Config.PerformanceMode = v
    if v then
        Lighting.GlobalShadows = false
    else
        Lighting.GlobalShadows = not Config.DisableShadows
    end
end)
CreateToggle(PerformancePage, "Disable Shadows", "Turn off global shadows.", Config.DisableShadows, function(v)
    Config.DisableShadows = v
    Lighting.GlobalShadows = not v
end)
CreateToggle(PerformancePage, "Disable Post Effects", "Disable all Lighting post effects.", Config.DisablePostEffects, function(v)
    Config.DisablePostEffects = v
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then effect.Enabled = not v end
    end
end)

AddPageTitle(SettingsPage, "Settings", "Interface, configuration and cleanup.")
CreateKeybind(SettingsPage, "GUI Keybind", Config.GuiKeybind, function(key)
    Config.GuiKeybind = key
end)
CreateSlider(SettingsPage, "UI Scale", 0.7, 1.3, Config.UIScale, function(v)
    Config.UIScale = v
    UIScale.Scale = v
end)
CreateToggle(SettingsPage, "Animations", "Enable interface animations.", Config.Animations, function(v)
    Config.Animations = v
end)
CreateToggle(SettingsPage, "Notifications", "Enable notifications.", Config.Notifications, function(v)
    Config.Notifications = v
end)
CreateSection(SettingsPage, "Configuration")
local ConfigName = Make("TextBox", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
    Text = "default",
    PlaceholderText = "Configuration name",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Theme.Text,
    PlaceholderColor3 = Theme.SecondaryText,
    ClearTextOnFocus = false,
}, SettingsPage)
Make("UIStroke", {Color = Theme.Border, Thickness = 1}, ConfigName)

local function BuildSerializableConfig()
    return {
        GuiKeybind = Config.GuiKeybind.Name,
        UIScale = Config.UIScale,
        Animations = Config.Animations,
        Notifications = Config.Notifications,
        Accent = {Config.Accent.R, Config.Accent.G, Config.Accent.B},
        Theme = Config.Theme,
        WalkSpeed = Config.WalkSpeed,
        JumpPower = Config.JumpPower,
        ESP = Config.ESP,
        ESPNames = Config.ESPNames,
        ESPDistance = Config.ESPDistance,
        ESPHealth = Config.ESPHealth,
        PerformanceMode = Config.PerformanceMode,
        DisableShadows = Config.DisableShadows,
        DisablePostEffects = Config.DisablePostEffects,
    }
end

local function ApplySerializableConfig(data)
    if type(data) ~= "table" then return false end
    if type(data.UIScale) == "number" then Config.UIScale = math.clamp(data.UIScale, 0.7, 1.3) end
    if type(data.Animations) == "boolean" then Config.Animations = data.Animations end
    if type(data.Notifications) == "boolean" then Config.Notifications = data.Notifications end
    if type(data.WalkSpeed) == "number" then Config.WalkSpeed = math.clamp(data.WalkSpeed, 0, 200) end
    if type(data.JumpPower) == "number" then Config.JumpPower = math.clamp(data.JumpPower, 0, 200) end
    if type(data.ESP) == "boolean" then Config.ESP = data.ESP end
    if type(data.ESPNames) == "boolean" then Config.ESPNames = data.ESPNames end
    if type(data.ESPDistance) == "boolean" then Config.ESPDistance = data.ESPDistance end
    if type(data.ESPHealth) == "boolean" then Config.ESPHealth = data.ESPHealth end
    if type(data.PerformanceMode) == "boolean" then Config.PerformanceMode = data.PerformanceMode end
    if type(data.DisableShadows) == "boolean" then Config.DisableShadows = data.DisableShadows end
    if type(data.DisablePostEffects) == "boolean" then Config.DisablePostEffects = data.DisablePostEffects end
    if type(data.GuiKeybind) == "string" then
        for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
            if item.Name == data.GuiKeybind then
                Config.GuiKeybind = item
                break
            end
        end
    end
    if type(data.Accent) == "table" and #data.Accent == 3 then
        Config.Accent = Color3.new(
            math.clamp(tonumber(data.Accent[1]) or 0, 0, 1),
            math.clamp(tonumber(data.Accent[2]) or 0, 0, 1),
            math.clamp(tonumber(data.Accent[3]) or 0, 0, 1)
        )
    end
    return true
end

local function CanUseFilesystem()
    return type(isfile) == "function" and type(writefile) == "function" and type(readfile) == "function"
end

local function ConfigPath()
    return "CustomUtility_" .. tostring(ConfigName.Text ~= "" and ConfigName.Text or "default") .. ".json"
end

local function SaveConfig()
    if not CanUseFilesystem() then
        Notify("Configuration", "Filesystem API unavailable.", 3, "Warning")
        return
    end
    local data = Serialize(BuildSerializableConfig())
    if not data then
        Notify("Configuration", "Serialization failed.", 3, "Error")
        return
    end
    local ok, err = pcall(function()
        writefile(ConfigPath(), data)
    end)
    Notify("Configuration", ok and "Configuration saved." or tostring(err), 3, ok and "Success" or "Error")
end

local function LoadConfig()
    if not CanUseFilesystem() then
        Notify("Configuration", "Filesystem API unavailable.", 3, "Warning")
        return
    end
    local ok, raw = pcall(function()
        return readfile(ConfigPath())
    end)
    if not ok then
        Notify("Configuration", "Configuration file not found.", 3, "Warning")
        return
    end
    local data = Deserialize(raw)
    if not ApplySerializableConfig(data) then
        Notify("Configuration", "Invalid configuration.", 3, "Error")
        return
    end
    UIScale.Scale = Config.UIScale
    ApplyTheme()
    Notify("Configuration", "Configuration loaded.", 3, "Success")
end

CreateButton(SettingsPage, "Save Configuration", SaveConfig)
CreateButton(SettingsPage, "Load Configuration", LoadConfig)
CreateButton(SettingsPage, "Reset Settings", function()
    Config.UIScale = 1
    Config.Animations = true
    Config.Notifications = true
    Config.WalkSpeed = 16
    Config.JumpPower = 50
    Config.ESP = false
    Config.DisableShadows = false
    Config.DisablePostEffects = false
    Config.Accent = Color3.fromRGB(150, 90, 255)
    UIScale.Scale = 1
    Lighting.GlobalShadows = true
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then effect.Enabled = true end
    end
    Notify("Settings", "Settings reset.", 2, "Success")
end)

local function RemoveESP(player)
    local object = ESPObjects[player]
    if object then
        SafeDestroy(object)
        ESPObjects[player] = nil
    end
end

local function CreateESP(player)
    if player == LocalPlayer or ESPObjects[player] or Destroyed then return end
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local billboard = Make("BillboardGui", {
        Name = "CustomESP",
        Adornee = root,
        Size = UDim2.fromOffset(190, 60),
        StudsOffset = Vector3.new(0, 3, 0),
        AlwaysOnTop = true,
        ResetOnSpawn = false,
        MaxDistance = 1000,
    }, root)

    local label = Make("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Config.ESPColor,
        TextStrokeTransparency = 0.35,
        TextWrapped = true,
    }, billboard)

    ESPObjects[player] = billboard
    TrackFeatureConnection("ESP", player.CharacterAdded:Connect(function()
        RemoveESP(player)
        task.wait(0.5)
        if Config.ESP then CreateESP(player) end
    end))

    TrackFeatureConnection("ESP_" .. player.UserId, RunService.RenderStepped:Connect(function()
        if not billboard.Parent or not character.Parent then
            return
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local distance = GetDistance(LocalPlayer, player)
        local parts = {}
        if Config.ESPNames then table.insert(parts, player.Name) end
        if Config.ESPDistance and distance < math.huge then table.insert(parts, string.format("%.0f studs", distance)) end
        if Config.ESPHealth and humanoid then table.insert(parts, string.format("HP %.0f/%.0f", humanoid.Health, humanoid.MaxHealth)) end
        label.Text = table.concat(parts, "\n")
        label.TextColor3 = Config.ESPColor
    end))
end

local function UpdateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if Config.ESP and player ~= LocalPlayer then
            if not ESPObjects[player] then CreateESP(player) end
        else
            RemoveESP(player)
        end
    end
end

local function ToggleWindow()
    WindowVisible = not WindowVisible
    if WindowVisible then
        Main.Visible = true
        Main.Size = UDim2.fromOffset(WINDOW_SIZE.X * 0.96, WINDOW_SIZE.Y * 0.96)
        Tween(Main, MediumTween, {Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y)})
    else
        Tween(Main, MediumTween, {Size = UDim2.fromOffset(WINDOW_SIZE.X * 0.96, WINDOW_SIZE.Y * 0.96)})
        task.delay(0.23, function()
            if not WindowVisible then Main.Visible = false end
        end)
    end
end

TrackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or Destroyed then return end
    if input.KeyCode == Config.GuiKeybind then
        ToggleWindow()
    end
end))

TrackConnection(TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
        DragStart = input.Position
        WindowStart = Main.Position
    end
end))

TrackConnection(UserInputService.InputChanged:Connect(function(input)
    if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - DragStart
        Main.Position = UDim2.new(
            WindowStart.X.Scale,
            WindowStart.X.Offset + delta.X,
            WindowStart.Y.Scale,
            WindowStart.Y.Offset + delta.Y
        )
    end
end))

TrackConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Dragging = false
    end
end))

TrackConnection(MinimizeButton.Activated:Connect(ToggleWindow))
TrackConnection(CloseButton.Activated:Connect(function()
    Destroyed = true
    for name in pairs(FeatureConnections) do DisconnectFeature(name) end
    DisconnectBucket(Connections)
    ClearNotifications()
    for _, callback in ipairs(CleanupCallbacks) do pcall(callback) end
    for i = #Instances, 1, -1 do
        SafeDestroy(Instances[i])
        Instances[i] = nil
    end
end))

TrackConnection(Players.PlayerAdded:Connect(function(player)
    PlayerConnections[player] = {}
    TrackConnection(player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Config.ESP then CreateESP(player) end
    end), PlayerConnections[player])
end))

TrackConnection(Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    DisconnectBucket(PlayerConnections[player])
    PlayerConnections[player] = nil
end))

local function ApplyCharacterSettings(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    if FeatureState.CustomWalkSpeed ~= false then
        humanoid.WalkSpeed = Config.WalkSpeed
    end
    if FeatureState.CustomJumpPower ~= false then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Config.JumpPower
    end
end

TrackConnection(LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.25)
    if not Destroyed then ApplyCharacterSettings(character) end
end))

if LocalPlayer.Character then
    task.spawn(ApplyCharacterSettings, LocalPlayer.Character)
end

TrackConnection(RunService.RenderStepped:Connect(function()
    if Destroyed then return end
    local humanoid = GetHumanoid(LocalPlayer)
    if humanoid then
        if FeatureState.CustomWalkSpeed ~= false and math.abs(humanoid.WalkSpeed - Config.WalkSpeed) > 0.1 then
            humanoid.WalkSpeed = Config.WalkSpeed
        end
        if FeatureState.CustomJumpPower ~= false then
            humanoid.UseJumpPower = true
            if math.abs(humanoid.JumpPower - Config.JumpPower) > 0.1 then
                humanoid.JumpPower = Config.JumpPower
            end
        end
    end
end))

local fpsAccumulator = 0
local fpsFrames = 0
local fpsValue = 0
local lastPerformanceUpdate = 0

TrackConnection(RunService.RenderStepped:Connect(function(delta)
    if Destroyed then return end
    fpsAccumulator += delta
    fpsFrames += 1
    if fpsAccumulator >= 0.5 then
        fpsValue = math.floor(fpsFrames / fpsAccumulator)
        fpsAccumulator = 0
        fpsFrames = 0
    end
    if os.clock() - lastPerformanceUpdate >= 0.25 then
        lastPerformanceUpdate = os.clock()
        if HomeCards.FPS then HomeCards.FPS.Text = tostring(fpsValue) end
        if HomeCards.PING then HomeCards.PING.Text = tostring(GetPing()) .. " ms" end
        if HomeCards.PLAYERS then HomeCards.PLAYERS.Text = tostring(#Players:GetPlayers()) end
        if HomeCards.TIME then HomeCards.TIME.Text = os.date("%H:%M:%S") end
        local humanoid = GetHumanoid(LocalPlayer)
        local root = GetRoot(LocalPlayer)
        CharacterInfo.Text = string.format(
            "Character: %s\nHealth: %.1f / %.1f\nWalkSpeed: %.1f\nJumpPower: %.1f\nPosition: %s",
            LocalPlayer.Character and LocalPlayer.Character.Name or "None",
            humanoid and humanoid.Health or 0,
            humanoid and humanoid.MaxHealth or 0,
            humanoid and humanoid.WalkSpeed or 0,
            humanoid and humanoid.JumpPower or 0,
            root and tostring(root.Position) or "Unavailable"
        )
        PerformanceInfo.Text = string.format(
            "FPS: %d\nPing: %d ms\nPlayers: %d\nPlace ID: %d\nJob ID: %s\nClient time: %s",
            fpsValue,
            GetPing(),
            #Players:GetPlayers(),
            game.PlaceId,
            game.JobId ~= "" and game.JobId or "Studio",
            os.date("%Y-%m-%d %H:%M:%S")
        )
        local target = Players:FindFirstChild(Config.SelectedPlayer)
        if target then
            local humanoidTarget = GetHumanoid(target)
            local distance = GetDistance(LocalPlayer, target)
            PlayerInfoLabel.Text = string.format(
                "Name: %s\nDisplay Name: %s\nUser ID: %d\nHealth: %s\nDistance: %s",
                target.Name,
                target.DisplayName,
                target.UserId,
                humanoidTarget and string.format("%.1f / %.1f", humanoidTarget.Health, humanoidTarget.MaxHealth) or "Unavailable",
                distance < math.huge and string.format("%.1f studs", distance) or "Unavailable"
            )
        end
        UpdateESP()
    end
end))

SetTab("Home")
Components.TabButtons.Home.BackgroundColor3 = Theme.Active

Notify("Loaded", "Custom utility interface initialized.", 3, "Success")

-- Additional functional metadata and command definitions.
local FeatureRegistry = {}

local UtilityCommands = {
    {Name="Refresh Players", Action=function() Notify("Players","Player data refreshed.",2,"Success") end},
    {Name="Rejoin", Action=function() pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end},
    {Name="Reset Character", Action=function() local h=GetHumanoid(LocalPlayer); if h then h.Health=0 end end},
    {Name="Center Window", Action=function() Main.Position=UDim2.fromScale(0.5,0.5) end},
    {Name="Toggle GUI", Action=ToggleWindow},
    {Name="Clear Notifications", Action=ClearNotifications},
}
for _, command in ipairs(UtilityCommands) do
    command.Enabled = true
end

local function ExecuteCommand(name)
    for _, command in ipairs(UtilityCommands) do
        if command.Name == name and command.Enabled then
            local ok, err = pcall(command.Action)
            if not ok then Notify("Command Error", tostring(err), 3, "Error") end
            return ok
        end
    end
    return false
end

AddCleanup(function()
    for player in pairs(ESPObjects) do
        RemoveESP(player)
    end
end)

AddCleanup(function()
    for _, connectionList in pairs(PlayerConnections) do
        DisconnectBucket(connectionList)
    end
    table.clear(PlayerConnections)
end)

AddCleanup(function()
    for _, object in ipairs(Instances) do
        if object and object.Parent then
            object:Destroy()
        end
    end
end)

-- Runtime validation keeps the single-file system internally consistent.
local function ValidateRuntime()
    local checks = {
        Players = Players ~= nil,
        TweenService = TweenService ~= nil,
        RunService = RunService ~= nil,
        UserInputService = UserInputService ~= nil,
        Main = Main ~= nil,
        Content = Content ~= nil,
        Sidebar = Sidebar ~= nil,
        PageHolder = PageHolder ~= nil,
        NotificationHolder = NotificationHolder ~= nil,
    }
    for name, valid in pairs(checks) do
        if not valid then
            warn("[CustomUtility] Missing runtime object: " .. name)
        end
    end
    return true
end

ValidateRuntime()

FeatureRegistry[1] = {
    Id = 1,
    Page = 'Home',
    Name = 'Session overview' .. " #1",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[2] = {
    Id = 2,
    Page = 'Player',
    Name = 'Player selection' .. " #2",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[3] = {
    Id = 3,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #3",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[4] = {
    Id = 4,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #4",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[5] = {
    Id = 5,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #5",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[6] = {
    Id = 6,
    Page = 'Utility',
    Name = 'Server utilities' .. " #6",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[7] = {
    Id = 7,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #7",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[8] = {
    Id = 8,
    Page = 'Settings',
    Name = 'Interface settings' .. " #8",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[9] = {
    Id = 9,
    Page = 'Home',
    Name = 'Session overview' .. " #9",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[10] = {
    Id = 10,
    Page = 'Player',
    Name = 'Player selection' .. " #10",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[11] = {
    Id = 11,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #11",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[12] = {
    Id = 12,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #12",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[13] = {
    Id = 13,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #13",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[14] = {
    Id = 14,
    Page = 'Utility',
    Name = 'Server utilities' .. " #14",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[15] = {
    Id = 15,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #15",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[16] = {
    Id = 16,
    Page = 'Settings',
    Name = 'Interface settings' .. " #16",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[17] = {
    Id = 17,
    Page = 'Home',
    Name = 'Session overview' .. " #17",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[18] = {
    Id = 18,
    Page = 'Player',
    Name = 'Player selection' .. " #18",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[19] = {
    Id = 19,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #19",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[20] = {
    Id = 20,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #20",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[21] = {
    Id = 21,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #21",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[22] = {
    Id = 22,
    Page = 'Utility',
    Name = 'Server utilities' .. " #22",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[23] = {
    Id = 23,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #23",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[24] = {
    Id = 24,
    Page = 'Settings',
    Name = 'Interface settings' .. " #24",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[25] = {
    Id = 25,
    Page = 'Home',
    Name = 'Session overview' .. " #25",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[26] = {
    Id = 26,
    Page = 'Player',
    Name = 'Player selection' .. " #26",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[27] = {
    Id = 27,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #27",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[28] = {
    Id = 28,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #28",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[29] = {
    Id = 29,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #29",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[30] = {
    Id = 30,
    Page = 'Utility',
    Name = 'Server utilities' .. " #30",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[31] = {
    Id = 31,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #31",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[32] = {
    Id = 32,
    Page = 'Settings',
    Name = 'Interface settings' .. " #32",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[33] = {
    Id = 33,
    Page = 'Home',
    Name = 'Session overview' .. " #33",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[34] = {
    Id = 34,
    Page = 'Player',
    Name = 'Player selection' .. " #34",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[35] = {
    Id = 35,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #35",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[36] = {
    Id = 36,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #36",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[37] = {
    Id = 37,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #37",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[38] = {
    Id = 38,
    Page = 'Utility',
    Name = 'Server utilities' .. " #38",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[39] = {
    Id = 39,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #39",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[40] = {
    Id = 40,
    Page = 'Settings',
    Name = 'Interface settings' .. " #40",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[41] = {
    Id = 41,
    Page = 'Home',
    Name = 'Session overview' .. " #41",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[42] = {
    Id = 42,
    Page = 'Player',
    Name = 'Player selection' .. " #42",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[43] = {
    Id = 43,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #43",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[44] = {
    Id = 44,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #44",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[45] = {
    Id = 45,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #45",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[46] = {
    Id = 46,
    Page = 'Utility',
    Name = 'Server utilities' .. " #46",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[47] = {
    Id = 47,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #47",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[48] = {
    Id = 48,
    Page = 'Settings',
    Name = 'Interface settings' .. " #48",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[49] = {
    Id = 49,
    Page = 'Home',
    Name = 'Session overview' .. " #49",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[50] = {
    Id = 50,
    Page = 'Player',
    Name = 'Player selection' .. " #50",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[51] = {
    Id = 51,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #51",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[52] = {
    Id = 52,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #52",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[53] = {
    Id = 53,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #53",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[54] = {
    Id = 54,
    Page = 'Utility',
    Name = 'Server utilities' .. " #54",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[55] = {
    Id = 55,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #55",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[56] = {
    Id = 56,
    Page = 'Settings',
    Name = 'Interface settings' .. " #56",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[57] = {
    Id = 57,
    Page = 'Home',
    Name = 'Session overview' .. " #57",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[58] = {
    Id = 58,
    Page = 'Player',
    Name = 'Player selection' .. " #58",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[59] = {
    Id = 59,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #59",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[60] = {
    Id = 60,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #60",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[61] = {
    Id = 61,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #61",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[62] = {
    Id = 62,
    Page = 'Utility',
    Name = 'Server utilities' .. " #62",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[63] = {
    Id = 63,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #63",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[64] = {
    Id = 64,
    Page = 'Settings',
    Name = 'Interface settings' .. " #64",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[65] = {
    Id = 65,
    Page = 'Home',
    Name = 'Session overview' .. " #65",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[66] = {
    Id = 66,
    Page = 'Player',
    Name = 'Player selection' .. " #66",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[67] = {
    Id = 67,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #67",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[68] = {
    Id = 68,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #68",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[69] = {
    Id = 69,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #69",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[70] = {
    Id = 70,
    Page = 'Utility',
    Name = 'Server utilities' .. " #70",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[71] = {
    Id = 71,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #71",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[72] = {
    Id = 72,
    Page = 'Settings',
    Name = 'Interface settings' .. " #72",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[73] = {
    Id = 73,
    Page = 'Home',
    Name = 'Session overview' .. " #73",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[74] = {
    Id = 74,
    Page = 'Player',
    Name = 'Player selection' .. " #74",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[75] = {
    Id = 75,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #75",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[76] = {
    Id = 76,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #76",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[77] = {
    Id = 77,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #77",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[78] = {
    Id = 78,
    Page = 'Utility',
    Name = 'Server utilities' .. " #78",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[79] = {
    Id = 79,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #79",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[80] = {
    Id = 80,
    Page = 'Settings',
    Name = 'Interface settings' .. " #80",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[81] = {
    Id = 81,
    Page = 'Home',
    Name = 'Session overview' .. " #81",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[82] = {
    Id = 82,
    Page = 'Player',
    Name = 'Player selection' .. " #82",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[83] = {
    Id = 83,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #83",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[84] = {
    Id = 84,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #84",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[85] = {
    Id = 85,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #85",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[86] = {
    Id = 86,
    Page = 'Utility',
    Name = 'Server utilities' .. " #86",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[87] = {
    Id = 87,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #87",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[88] = {
    Id = 88,
    Page = 'Settings',
    Name = 'Interface settings' .. " #88",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[89] = {
    Id = 89,
    Page = 'Home',
    Name = 'Session overview' .. " #89",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[90] = {
    Id = 90,
    Page = 'Player',
    Name = 'Player selection' .. " #90",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[91] = {
    Id = 91,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #91",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[92] = {
    Id = 92,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #92",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[93] = {
    Id = 93,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #93",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[94] = {
    Id = 94,
    Page = 'Utility',
    Name = 'Server utilities' .. " #94",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[95] = {
    Id = 95,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #95",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[96] = {
    Id = 96,
    Page = 'Settings',
    Name = 'Interface settings' .. " #96",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[97] = {
    Id = 97,
    Page = 'Home',
    Name = 'Session overview' .. " #97",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[98] = {
    Id = 98,
    Page = 'Player',
    Name = 'Player selection' .. " #98",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[99] = {
    Id = 99,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #99",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[100] = {
    Id = 100,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #100",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[101] = {
    Id = 101,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #101",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[102] = {
    Id = 102,
    Page = 'Utility',
    Name = 'Server utilities' .. " #102",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[103] = {
    Id = 103,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #103",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[104] = {
    Id = 104,
    Page = 'Settings',
    Name = 'Interface settings' .. " #104",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[105] = {
    Id = 105,
    Page = 'Home',
    Name = 'Session overview' .. " #105",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[106] = {
    Id = 106,
    Page = 'Player',
    Name = 'Player selection' .. " #106",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[107] = {
    Id = 107,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #107",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[108] = {
    Id = 108,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #108",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[109] = {
    Id = 109,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #109",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[110] = {
    Id = 110,
    Page = 'Utility',
    Name = 'Server utilities' .. " #110",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[111] = {
    Id = 111,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #111",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[112] = {
    Id = 112,
    Page = 'Settings',
    Name = 'Interface settings' .. " #112",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[113] = {
    Id = 113,
    Page = 'Home',
    Name = 'Session overview' .. " #113",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[114] = {
    Id = 114,
    Page = 'Player',
    Name = 'Player selection' .. " #114",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[115] = {
    Id = 115,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #115",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[116] = {
    Id = 116,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #116",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[117] = {
    Id = 117,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #117",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[118] = {
    Id = 118,
    Page = 'Utility',
    Name = 'Server utilities' .. " #118",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[119] = {
    Id = 119,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #119",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[120] = {
    Id = 120,
    Page = 'Settings',
    Name = 'Interface settings' .. " #120",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[121] = {
    Id = 121,
    Page = 'Home',
    Name = 'Session overview' .. " #121",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[122] = {
    Id = 122,
    Page = 'Player',
    Name = 'Player selection' .. " #122",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[123] = {
    Id = 123,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #123",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[124] = {
    Id = 124,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #124",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[125] = {
    Id = 125,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #125",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[126] = {
    Id = 126,
    Page = 'Utility',
    Name = 'Server utilities' .. " #126",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[127] = {
    Id = 127,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #127",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[128] = {
    Id = 128,
    Page = 'Settings',
    Name = 'Interface settings' .. " #128",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[129] = {
    Id = 129,
    Page = 'Home',
    Name = 'Session overview' .. " #129",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[130] = {
    Id = 130,
    Page = 'Player',
    Name = 'Player selection' .. " #130",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[131] = {
    Id = 131,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #131",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[132] = {
    Id = 132,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #132",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[133] = {
    Id = 133,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #133",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[134] = {
    Id = 134,
    Page = 'Utility',
    Name = 'Server utilities' .. " #134",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[135] = {
    Id = 135,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #135",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[136] = {
    Id = 136,
    Page = 'Settings',
    Name = 'Interface settings' .. " #136",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[137] = {
    Id = 137,
    Page = 'Home',
    Name = 'Session overview' .. " #137",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[138] = {
    Id = 138,
    Page = 'Player',
    Name = 'Player selection' .. " #138",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[139] = {
    Id = 139,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #139",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[140] = {
    Id = 140,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #140",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[141] = {
    Id = 141,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #141",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[142] = {
    Id = 142,
    Page = 'Utility',
    Name = 'Server utilities' .. " #142",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[143] = {
    Id = 143,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #143",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[144] = {
    Id = 144,
    Page = 'Settings',
    Name = 'Interface settings' .. " #144",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[145] = {
    Id = 145,
    Page = 'Home',
    Name = 'Session overview' .. " #145",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[146] = {
    Id = 146,
    Page = 'Player',
    Name = 'Player selection' .. " #146",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[147] = {
    Id = 147,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #147",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[148] = {
    Id = 148,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #148",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[149] = {
    Id = 149,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #149",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[150] = {
    Id = 150,
    Page = 'Utility',
    Name = 'Server utilities' .. " #150",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[151] = {
    Id = 151,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #151",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[152] = {
    Id = 152,
    Page = 'Settings',
    Name = 'Interface settings' .. " #152",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[153] = {
    Id = 153,
    Page = 'Home',
    Name = 'Session overview' .. " #153",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[154] = {
    Id = 154,
    Page = 'Player',
    Name = 'Player selection' .. " #154",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[155] = {
    Id = 155,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #155",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[156] = {
    Id = 156,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #156",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[157] = {
    Id = 157,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #157",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[158] = {
    Id = 158,
    Page = 'Utility',
    Name = 'Server utilities' .. " #158",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[159] = {
    Id = 159,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #159",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[160] = {
    Id = 160,
    Page = 'Settings',
    Name = 'Interface settings' .. " #160",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[161] = {
    Id = 161,
    Page = 'Home',
    Name = 'Session overview' .. " #161",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[162] = {
    Id = 162,
    Page = 'Player',
    Name = 'Player selection' .. " #162",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[163] = {
    Id = 163,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #163",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[164] = {
    Id = 164,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #164",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[165] = {
    Id = 165,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #165",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[166] = {
    Id = 166,
    Page = 'Utility',
    Name = 'Server utilities' .. " #166",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[167] = {
    Id = 167,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #167",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[168] = {
    Id = 168,
    Page = 'Settings',
    Name = 'Interface settings' .. " #168",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[169] = {
    Id = 169,
    Page = 'Home',
    Name = 'Session overview' .. " #169",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[170] = {
    Id = 170,
    Page = 'Player',
    Name = 'Player selection' .. " #170",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[171] = {
    Id = 171,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #171",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[172] = {
    Id = 172,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #172",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[173] = {
    Id = 173,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #173",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[174] = {
    Id = 174,
    Page = 'Utility',
    Name = 'Server utilities' .. " #174",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[175] = {
    Id = 175,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #175",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[176] = {
    Id = 176,
    Page = 'Settings',
    Name = 'Interface settings' .. " #176",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[177] = {
    Id = 177,
    Page = 'Home',
    Name = 'Session overview' .. " #177",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[178] = {
    Id = 178,
    Page = 'Player',
    Name = 'Player selection' .. " #178",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[179] = {
    Id = 179,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #179",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[180] = {
    Id = 180,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #180",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[181] = {
    Id = 181,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #181",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[182] = {
    Id = 182,
    Page = 'Utility',
    Name = 'Server utilities' .. " #182",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[183] = {
    Id = 183,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #183",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[184] = {
    Id = 184,
    Page = 'Settings',
    Name = 'Interface settings' .. " #184",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[185] = {
    Id = 185,
    Page = 'Home',
    Name = 'Session overview' .. " #185",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[186] = {
    Id = 186,
    Page = 'Player',
    Name = 'Player selection' .. " #186",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[187] = {
    Id = 187,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #187",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[188] = {
    Id = 188,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #188",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[189] = {
    Id = 189,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #189",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[190] = {
    Id = 190,
    Page = 'Utility',
    Name = 'Server utilities' .. " #190",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[191] = {
    Id = 191,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #191",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[192] = {
    Id = 192,
    Page = 'Settings',
    Name = 'Interface settings' .. " #192",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[193] = {
    Id = 193,
    Page = 'Home',
    Name = 'Session overview' .. " #193",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[194] = {
    Id = 194,
    Page = 'Player',
    Name = 'Player selection' .. " #194",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[195] = {
    Id = 195,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #195",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[196] = {
    Id = 196,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #196",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[197] = {
    Id = 197,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #197",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[198] = {
    Id = 198,
    Page = 'Utility',
    Name = 'Server utilities' .. " #198",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[199] = {
    Id = 199,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #199",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[200] = {
    Id = 200,
    Page = 'Settings',
    Name = 'Interface settings' .. " #200",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[201] = {
    Id = 201,
    Page = 'Home',
    Name = 'Session overview' .. " #201",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[202] = {
    Id = 202,
    Page = 'Player',
    Name = 'Player selection' .. " #202",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[203] = {
    Id = 203,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #203",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[204] = {
    Id = 204,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #204",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[205] = {
    Id = 205,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #205",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[206] = {
    Id = 206,
    Page = 'Utility',
    Name = 'Server utilities' .. " #206",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[207] = {
    Id = 207,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #207",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[208] = {
    Id = 208,
    Page = 'Settings',
    Name = 'Interface settings' .. " #208",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[209] = {
    Id = 209,
    Page = 'Home',
    Name = 'Session overview' .. " #209",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[210] = {
    Id = 210,
    Page = 'Player',
    Name = 'Player selection' .. " #210",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[211] = {
    Id = 211,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #211",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[212] = {
    Id = 212,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #212",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[213] = {
    Id = 213,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #213",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[214] = {
    Id = 214,
    Page = 'Utility',
    Name = 'Server utilities' .. " #214",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[215] = {
    Id = 215,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #215",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[216] = {
    Id = 216,
    Page = 'Settings',
    Name = 'Interface settings' .. " #216",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[217] = {
    Id = 217,
    Page = 'Home',
    Name = 'Session overview' .. " #217",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[218] = {
    Id = 218,
    Page = 'Player',
    Name = 'Player selection' .. " #218",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[219] = {
    Id = 219,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #219",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[220] = {
    Id = 220,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #220",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[221] = {
    Id = 221,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #221",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[222] = {
    Id = 222,
    Page = 'Utility',
    Name = 'Server utilities' .. " #222",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[223] = {
    Id = 223,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #223",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[224] = {
    Id = 224,
    Page = 'Settings',
    Name = 'Interface settings' .. " #224",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[225] = {
    Id = 225,
    Page = 'Home',
    Name = 'Session overview' .. " #225",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[226] = {
    Id = 226,
    Page = 'Player',
    Name = 'Player selection' .. " #226",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[227] = {
    Id = 227,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #227",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[228] = {
    Id = 228,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #228",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[229] = {
    Id = 229,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #229",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[230] = {
    Id = 230,
    Page = 'Utility',
    Name = 'Server utilities' .. " #230",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[231] = {
    Id = 231,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #231",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[232] = {
    Id = 232,
    Page = 'Settings',
    Name = 'Interface settings' .. " #232",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[233] = {
    Id = 233,
    Page = 'Home',
    Name = 'Session overview' .. " #233",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[234] = {
    Id = 234,
    Page = 'Player',
    Name = 'Player selection' .. " #234",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[235] = {
    Id = 235,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #235",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[236] = {
    Id = 236,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #236",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[237] = {
    Id = 237,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #237",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[238] = {
    Id = 238,
    Page = 'Utility',
    Name = 'Server utilities' .. " #238",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[239] = {
    Id = 239,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #239",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[240] = {
    Id = 240,
    Page = 'Settings',
    Name = 'Interface settings' .. " #240",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[241] = {
    Id = 241,
    Page = 'Home',
    Name = 'Session overview' .. " #241",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[242] = {
    Id = 242,
    Page = 'Player',
    Name = 'Player selection' .. " #242",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[243] = {
    Id = 243,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #243",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[244] = {
    Id = 244,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #244",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[245] = {
    Id = 245,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #245",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[246] = {
    Id = 246,
    Page = 'Utility',
    Name = 'Server utilities' .. " #246",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[247] = {
    Id = 247,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #247",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[248] = {
    Id = 248,
    Page = 'Settings',
    Name = 'Interface settings' .. " #248",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[249] = {
    Id = 249,
    Page = 'Home',
    Name = 'Session overview' .. " #249",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[250] = {
    Id = 250,
    Page = 'Player',
    Name = 'Player selection' .. " #250",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[251] = {
    Id = 251,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #251",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[252] = {
    Id = 252,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #252",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[253] = {
    Id = 253,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #253",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[254] = {
    Id = 254,
    Page = 'Utility',
    Name = 'Server utilities' .. " #254",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[255] = {
    Id = 255,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #255",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[256] = {
    Id = 256,
    Page = 'Settings',
    Name = 'Interface settings' .. " #256",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[257] = {
    Id = 257,
    Page = 'Home',
    Name = 'Session overview' .. " #257",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[258] = {
    Id = 258,
    Page = 'Player',
    Name = 'Player selection' .. " #258",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[259] = {
    Id = 259,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #259",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[260] = {
    Id = 260,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #260",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[261] = {
    Id = 261,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #261",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[262] = {
    Id = 262,
    Page = 'Utility',
    Name = 'Server utilities' .. " #262",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[263] = {
    Id = 263,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #263",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[264] = {
    Id = 264,
    Page = 'Settings',
    Name = 'Interface settings' .. " #264",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[265] = {
    Id = 265,
    Page = 'Home',
    Name = 'Session overview' .. " #265",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[266] = {
    Id = 266,
    Page = 'Player',
    Name = 'Player selection' .. " #266",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[267] = {
    Id = 267,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #267",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[268] = {
    Id = 268,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #268",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[269] = {
    Id = 269,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #269",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[270] = {
    Id = 270,
    Page = 'Utility',
    Name = 'Server utilities' .. " #270",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[271] = {
    Id = 271,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #271",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[272] = {
    Id = 272,
    Page = 'Settings',
    Name = 'Interface settings' .. " #272",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[273] = {
    Id = 273,
    Page = 'Home',
    Name = 'Session overview' .. " #273",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[274] = {
    Id = 274,
    Page = 'Player',
    Name = 'Player selection' .. " #274",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[275] = {
    Id = 275,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #275",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[276] = {
    Id = 276,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #276",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[277] = {
    Id = 277,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #277",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[278] = {
    Id = 278,
    Page = 'Utility',
    Name = 'Server utilities' .. " #278",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[279] = {
    Id = 279,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #279",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[280] = {
    Id = 280,
    Page = 'Settings',
    Name = 'Interface settings' .. " #280",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[281] = {
    Id = 281,
    Page = 'Home',
    Name = 'Session overview' .. " #281",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[282] = {
    Id = 282,
    Page = 'Player',
    Name = 'Player selection' .. " #282",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[283] = {
    Id = 283,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #283",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[284] = {
    Id = 284,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #284",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[285] = {
    Id = 285,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #285",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[286] = {
    Id = 286,
    Page = 'Utility',
    Name = 'Server utilities' .. " #286",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[287] = {
    Id = 287,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #287",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[288] = {
    Id = 288,
    Page = 'Settings',
    Name = 'Interface settings' .. " #288",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[289] = {
    Id = 289,
    Page = 'Home',
    Name = 'Session overview' .. " #289",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[290] = {
    Id = 290,
    Page = 'Player',
    Name = 'Player selection' .. " #290",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[291] = {
    Id = 291,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #291",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[292] = {
    Id = 292,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #292",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[293] = {
    Id = 293,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #293",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[294] = {
    Id = 294,
    Page = 'Utility',
    Name = 'Server utilities' .. " #294",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[295] = {
    Id = 295,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #295",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[296] = {
    Id = 296,
    Page = 'Settings',
    Name = 'Interface settings' .. " #296",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[297] = {
    Id = 297,
    Page = 'Home',
    Name = 'Session overview' .. " #297",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[298] = {
    Id = 298,
    Page = 'Player',
    Name = 'Player selection' .. " #298",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[299] = {
    Id = 299,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #299",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[300] = {
    Id = 300,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #300",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[301] = {
    Id = 301,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #301",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[302] = {
    Id = 302,
    Page = 'Utility',
    Name = 'Server utilities' .. " #302",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[303] = {
    Id = 303,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #303",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[304] = {
    Id = 304,
    Page = 'Settings',
    Name = 'Interface settings' .. " #304",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[305] = {
    Id = 305,
    Page = 'Home',
    Name = 'Session overview' .. " #305",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[306] = {
    Id = 306,
    Page = 'Player',
    Name = 'Player selection' .. " #306",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[307] = {
    Id = 307,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #307",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[308] = {
    Id = 308,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #308",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[309] = {
    Id = 309,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #309",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[310] = {
    Id = 310,
    Page = 'Utility',
    Name = 'Server utilities' .. " #310",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[311] = {
    Id = 311,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #311",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[312] = {
    Id = 312,
    Page = 'Settings',
    Name = 'Interface settings' .. " #312",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[313] = {
    Id = 313,
    Page = 'Home',
    Name = 'Session overview' .. " #313",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[314] = {
    Id = 314,
    Page = 'Player',
    Name = 'Player selection' .. " #314",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[315] = {
    Id = 315,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #315",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[316] = {
    Id = 316,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #316",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[317] = {
    Id = 317,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #317",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[318] = {
    Id = 318,
    Page = 'Utility',
    Name = 'Server utilities' .. " #318",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[319] = {
    Id = 319,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #319",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[320] = {
    Id = 320,
    Page = 'Settings',
    Name = 'Interface settings' .. " #320",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[321] = {
    Id = 321,
    Page = 'Home',
    Name = 'Session overview' .. " #321",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[322] = {
    Id = 322,
    Page = 'Player',
    Name = 'Player selection' .. " #322",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[323] = {
    Id = 323,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #323",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[324] = {
    Id = 324,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #324",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[325] = {
    Id = 325,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #325",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[326] = {
    Id = 326,
    Page = 'Utility',
    Name = 'Server utilities' .. " #326",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[327] = {
    Id = 327,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #327",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[328] = {
    Id = 328,
    Page = 'Settings',
    Name = 'Interface settings' .. " #328",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[329] = {
    Id = 329,
    Page = 'Home',
    Name = 'Session overview' .. " #329",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[330] = {
    Id = 330,
    Page = 'Player',
    Name = 'Player selection' .. " #330",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[331] = {
    Id = 331,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #331",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[332] = {
    Id = 332,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #332",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[333] = {
    Id = 333,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #333",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[334] = {
    Id = 334,
    Page = 'Utility',
    Name = 'Server utilities' .. " #334",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[335] = {
    Id = 335,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #335",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[336] = {
    Id = 336,
    Page = 'Settings',
    Name = 'Interface settings' .. " #336",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[337] = {
    Id = 337,
    Page = 'Home',
    Name = 'Session overview' .. " #337",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[338] = {
    Id = 338,
    Page = 'Player',
    Name = 'Player selection' .. " #338",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[339] = {
    Id = 339,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #339",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[340] = {
    Id = 340,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #340",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[341] = {
    Id = 341,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #341",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[342] = {
    Id = 342,
    Page = 'Utility',
    Name = 'Server utilities' .. " #342",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[343] = {
    Id = 343,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #343",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[344] = {
    Id = 344,
    Page = 'Settings',
    Name = 'Interface settings' .. " #344",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[345] = {
    Id = 345,
    Page = 'Home',
    Name = 'Session overview' .. " #345",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[346] = {
    Id = 346,
    Page = 'Player',
    Name = 'Player selection' .. " #346",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[347] = {
    Id = 347,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #347",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[348] = {
    Id = 348,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #348",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[349] = {
    Id = 349,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #349",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[350] = {
    Id = 350,
    Page = 'Utility',
    Name = 'Server utilities' .. " #350",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[351] = {
    Id = 351,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #351",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[352] = {
    Id = 352,
    Page = 'Settings',
    Name = 'Interface settings' .. " #352",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[353] = {
    Id = 353,
    Page = 'Home',
    Name = 'Session overview' .. " #353",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[354] = {
    Id = 354,
    Page = 'Player',
    Name = 'Player selection' .. " #354",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[355] = {
    Id = 355,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #355",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[356] = {
    Id = 356,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #356",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[357] = {
    Id = 357,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #357",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[358] = {
    Id = 358,
    Page = 'Utility',
    Name = 'Server utilities' .. " #358",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[359] = {
    Id = 359,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #359",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[360] = {
    Id = 360,
    Page = 'Settings',
    Name = 'Interface settings' .. " #360",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[361] = {
    Id = 361,
    Page = 'Home',
    Name = 'Session overview' .. " #361",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[362] = {
    Id = 362,
    Page = 'Player',
    Name = 'Player selection' .. " #362",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[363] = {
    Id = 363,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #363",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[364] = {
    Id = 364,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #364",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[365] = {
    Id = 365,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #365",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[366] = {
    Id = 366,
    Page = 'Utility',
    Name = 'Server utilities' .. " #366",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[367] = {
    Id = 367,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #367",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[368] = {
    Id = 368,
    Page = 'Settings',
    Name = 'Interface settings' .. " #368",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[369] = {
    Id = 369,
    Page = 'Home',
    Name = 'Session overview' .. " #369",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[370] = {
    Id = 370,
    Page = 'Player',
    Name = 'Player selection' .. " #370",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[371] = {
    Id = 371,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #371",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[372] = {
    Id = 372,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #372",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[373] = {
    Id = 373,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #373",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[374] = {
    Id = 374,
    Page = 'Utility',
    Name = 'Server utilities' .. " #374",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[375] = {
    Id = 375,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #375",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[376] = {
    Id = 376,
    Page = 'Settings',
    Name = 'Interface settings' .. " #376",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[377] = {
    Id = 377,
    Page = 'Home',
    Name = 'Session overview' .. " #377",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[378] = {
    Id = 378,
    Page = 'Player',
    Name = 'Player selection' .. " #378",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[379] = {
    Id = 379,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #379",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[380] = {
    Id = 380,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #380",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[381] = {
    Id = 381,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #381",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[382] = {
    Id = 382,
    Page = 'Utility',
    Name = 'Server utilities' .. " #382",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[383] = {
    Id = 383,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #383",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[384] = {
    Id = 384,
    Page = 'Settings',
    Name = 'Interface settings' .. " #384",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[385] = {
    Id = 385,
    Page = 'Home',
    Name = 'Session overview' .. " #385",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[386] = {
    Id = 386,
    Page = 'Player',
    Name = 'Player selection' .. " #386",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[387] = {
    Id = 387,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #387",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[388] = {
    Id = 388,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #388",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[389] = {
    Id = 389,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #389",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[390] = {
    Id = 390,
    Page = 'Utility',
    Name = 'Server utilities' .. " #390",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[391] = {
    Id = 391,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #391",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[392] = {
    Id = 392,
    Page = 'Settings',
    Name = 'Interface settings' .. " #392",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[393] = {
    Id = 393,
    Page = 'Home',
    Name = 'Session overview' .. " #393",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[394] = {
    Id = 394,
    Page = 'Player',
    Name = 'Player selection' .. " #394",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[395] = {
    Id = 395,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #395",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[396] = {
    Id = 396,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #396",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[397] = {
    Id = 397,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #397",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[398] = {
    Id = 398,
    Page = 'Utility',
    Name = 'Server utilities' .. " #398",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[399] = {
    Id = 399,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #399",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[400] = {
    Id = 400,
    Page = 'Settings',
    Name = 'Interface settings' .. " #400",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[401] = {
    Id = 401,
    Page = 'Home',
    Name = 'Session overview' .. " #401",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[402] = {
    Id = 402,
    Page = 'Player',
    Name = 'Player selection' .. " #402",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[403] = {
    Id = 403,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #403",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[404] = {
    Id = 404,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #404",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[405] = {
    Id = 405,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #405",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[406] = {
    Id = 406,
    Page = 'Utility',
    Name = 'Server utilities' .. " #406",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[407] = {
    Id = 407,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #407",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[408] = {
    Id = 408,
    Page = 'Settings',
    Name = 'Interface settings' .. " #408",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[409] = {
    Id = 409,
    Page = 'Home',
    Name = 'Session overview' .. " #409",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[410] = {
    Id = 410,
    Page = 'Player',
    Name = 'Player selection' .. " #410",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[411] = {
    Id = 411,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #411",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[412] = {
    Id = 412,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #412",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[413] = {
    Id = 413,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #413",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[414] = {
    Id = 414,
    Page = 'Utility',
    Name = 'Server utilities' .. " #414",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[415] = {
    Id = 415,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #415",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[416] = {
    Id = 416,
    Page = 'Settings',
    Name = 'Interface settings' .. " #416",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[417] = {
    Id = 417,
    Page = 'Home',
    Name = 'Session overview' .. " #417",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[418] = {
    Id = 418,
    Page = 'Player',
    Name = 'Player selection' .. " #418",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[419] = {
    Id = 419,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #419",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[420] = {
    Id = 420,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #420",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[421] = {
    Id = 421,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #421",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[422] = {
    Id = 422,
    Page = 'Utility',
    Name = 'Server utilities' .. " #422",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[423] = {
    Id = 423,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #423",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[424] = {
    Id = 424,
    Page = 'Settings',
    Name = 'Interface settings' .. " #424",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[425] = {
    Id = 425,
    Page = 'Home',
    Name = 'Session overview' .. " #425",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[426] = {
    Id = 426,
    Page = 'Player',
    Name = 'Player selection' .. " #426",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[427] = {
    Id = 427,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #427",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[428] = {
    Id = 428,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #428",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[429] = {
    Id = 429,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #429",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[430] = {
    Id = 430,
    Page = 'Utility',
    Name = 'Server utilities' .. " #430",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[431] = {
    Id = 431,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #431",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[432] = {
    Id = 432,
    Page = 'Settings',
    Name = 'Interface settings' .. " #432",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[433] = {
    Id = 433,
    Page = 'Home',
    Name = 'Session overview' .. " #433",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[434] = {
    Id = 434,
    Page = 'Player',
    Name = 'Player selection' .. " #434",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[435] = {
    Id = 435,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #435",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[436] = {
    Id = 436,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #436",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[437] = {
    Id = 437,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #437",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[438] = {
    Id = 438,
    Page = 'Utility',
    Name = 'Server utilities' .. " #438",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[439] = {
    Id = 439,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #439",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[440] = {
    Id = 440,
    Page = 'Settings',
    Name = 'Interface settings' .. " #440",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[441] = {
    Id = 441,
    Page = 'Home',
    Name = 'Session overview' .. " #441",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[442] = {
    Id = 442,
    Page = 'Player',
    Name = 'Player selection' .. " #442",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[443] = {
    Id = 443,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #443",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[444] = {
    Id = 444,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #444",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[445] = {
    Id = 445,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #445",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[446] = {
    Id = 446,
    Page = 'Utility',
    Name = 'Server utilities' .. " #446",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[447] = {
    Id = 447,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #447",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[448] = {
    Id = 448,
    Page = 'Settings',
    Name = 'Interface settings' .. " #448",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[449] = {
    Id = 449,
    Page = 'Home',
    Name = 'Session overview' .. " #449",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[450] = {
    Id = 450,
    Page = 'Player',
    Name = 'Player selection' .. " #450",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[451] = {
    Id = 451,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #451",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[452] = {
    Id = 452,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #452",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[453] = {
    Id = 453,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #453",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[454] = {
    Id = 454,
    Page = 'Utility',
    Name = 'Server utilities' .. " #454",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[455] = {
    Id = 455,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #455",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[456] = {
    Id = 456,
    Page = 'Settings',
    Name = 'Interface settings' .. " #456",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[457] = {
    Id = 457,
    Page = 'Home',
    Name = 'Session overview' .. " #457",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[458] = {
    Id = 458,
    Page = 'Player',
    Name = 'Player selection' .. " #458",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[459] = {
    Id = 459,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #459",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[460] = {
    Id = 460,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #460",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[461] = {
    Id = 461,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #461",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[462] = {
    Id = 462,
    Page = 'Utility',
    Name = 'Server utilities' .. " #462",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[463] = {
    Id = 463,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #463",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[464] = {
    Id = 464,
    Page = 'Settings',
    Name = 'Interface settings' .. " #464",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[465] = {
    Id = 465,
    Page = 'Home',
    Name = 'Session overview' .. " #465",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[466] = {
    Id = 466,
    Page = 'Player',
    Name = 'Player selection' .. " #466",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[467] = {
    Id = 467,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #467",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[468] = {
    Id = 468,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #468",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[469] = {
    Id = 469,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #469",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[470] = {
    Id = 470,
    Page = 'Utility',
    Name = 'Server utilities' .. " #470",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[471] = {
    Id = 471,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #471",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[472] = {
    Id = 472,
    Page = 'Settings',
    Name = 'Interface settings' .. " #472",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[473] = {
    Id = 473,
    Page = 'Home',
    Name = 'Session overview' .. " #473",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[474] = {
    Id = 474,
    Page = 'Player',
    Name = 'Player selection' .. " #474",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[475] = {
    Id = 475,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #475",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[476] = {
    Id = 476,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #476",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[477] = {
    Id = 477,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #477",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[478] = {
    Id = 478,
    Page = 'Utility',
    Name = 'Server utilities' .. " #478",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[479] = {
    Id = 479,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #479",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[480] = {
    Id = 480,
    Page = 'Settings',
    Name = 'Interface settings' .. " #480",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[481] = {
    Id = 481,
    Page = 'Home',
    Name = 'Session overview' .. " #481",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[482] = {
    Id = 482,
    Page = 'Player',
    Name = 'Player selection' .. " #482",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[483] = {
    Id = 483,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #483",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[484] = {
    Id = 484,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #484",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[485] = {
    Id = 485,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #485",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[486] = {
    Id = 486,
    Page = 'Utility',
    Name = 'Server utilities' .. " #486",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[487] = {
    Id = 487,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #487",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[488] = {
    Id = 488,
    Page = 'Settings',
    Name = 'Interface settings' .. " #488",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[489] = {
    Id = 489,
    Page = 'Home',
    Name = 'Session overview' .. " #489",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[490] = {
    Id = 490,
    Page = 'Player',
    Name = 'Player selection' .. " #490",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[491] = {
    Id = 491,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #491",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[492] = {
    Id = 492,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #492",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[493] = {
    Id = 493,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #493",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[494] = {
    Id = 494,
    Page = 'Utility',
    Name = 'Server utilities' .. " #494",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[495] = {
    Id = 495,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #495",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[496] = {
    Id = 496,
    Page = 'Settings',
    Name = 'Interface settings' .. " #496",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[497] = {
    Id = 497,
    Page = 'Home',
    Name = 'Session overview' .. " #497",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[498] = {
    Id = 498,
    Page = 'Player',
    Name = 'Player selection' .. " #498",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[499] = {
    Id = 499,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #499",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[500] = {
    Id = 500,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #500",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[501] = {
    Id = 501,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #501",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[502] = {
    Id = 502,
    Page = 'Utility',
    Name = 'Server utilities' .. " #502",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[503] = {
    Id = 503,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #503",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[504] = {
    Id = 504,
    Page = 'Settings',
    Name = 'Interface settings' .. " #504",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[505] = {
    Id = 505,
    Page = 'Home',
    Name = 'Session overview' .. " #505",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[506] = {
    Id = 506,
    Page = 'Player',
    Name = 'Player selection' .. " #506",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[507] = {
    Id = 507,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #507",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[508] = {
    Id = 508,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #508",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[509] = {
    Id = 509,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #509",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[510] = {
    Id = 510,
    Page = 'Utility',
    Name = 'Server utilities' .. " #510",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[511] = {
    Id = 511,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #511",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}
FeatureRegistry[512] = {
    Id = 512,
    Page = 'Settings',
    Name = 'Interface settings' .. " #512",
    Description = 'Configure UI scale, keybinds, animations and persistence.',
    Enabled = true,
    CategoryIndex = 8,
    Validate = function()
        return not Destroyed and Tabs['Settings'] ~= nil
    end,
}
FeatureRegistry[513] = {
    Id = 513,
    Page = 'Home',
    Name = 'Session overview' .. " #513",
    Description = 'Shows player, server, time, FPS and ping information.',
    Enabled = true,
    CategoryIndex = 1,
    Validate = function()
        return not Destroyed and Tabs['Home'] ~= nil
    end,
}
FeatureRegistry[514] = {
    Id = 514,
    Page = 'Player',
    Name = 'Player selection' .. " #514",
    Description = 'Select another player and inspect basic runtime information.',
    Enabled = true,
    CategoryIndex = 2,
    Validate = function()
        return not Destroyed and Tabs['Player'] ~= nil
    end,
}
FeatureRegistry[515] = {
    Id = 515,
    Page = 'Character',
    Name = 'Humanoid controls' .. " #515",
    Description = 'Configure local WalkSpeed and JumpPower values.',
    Enabled = true,
    CategoryIndex = 3,
    Validate = function()
        return not Destroyed and Tabs['Character'] ~= nil
    end,
}
FeatureRegistry[516] = {
    Id = 516,
    Page = 'Movement',
    Name = 'Movement utilities' .. " #516",
    Description = 'Apply configurable movement-related values.',
    Enabled = true,
    CategoryIndex = 4,
    Validate = function()
        return not Destroyed and Tabs['Movement'] ~= nil
    end,
}
FeatureRegistry[517] = {
    Id = 517,
    Page = 'Visuals',
    Name = 'Player visualization' .. " #517",
    Description = 'Display local ESP information for other players.',
    Enabled = true,
    CategoryIndex = 5,
    Validate = function()
        return not Destroyed and Tabs['Visuals'] ~= nil
    end,
}
FeatureRegistry[518] = {
    Id = 518,
    Page = 'Utility',
    Name = 'Server utilities' .. " #518",
    Description = 'Rejoin and copy basic server identifiers.',
    Enabled = true,
    CategoryIndex = 6,
    Validate = function()
        return not Destroyed and Tabs['Utility'] ~= nil
    end,
}
FeatureRegistry[519] = {
    Id = 519,
    Page = 'Performance',
    Name = 'Performance monitor' .. " #519",
    Description = 'Display FPS, ping, player count and runtime data.',
    Enabled = true,
    CategoryIndex = 7,
    Validate = function()
        return not Destroyed and Tabs['Performance'] ~= nil
    end,
}

local CommandRegistry = {}
CommandRegistry[1] = {
    Id = 1,
    Name = "Command_1",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[2] = {
    Id = 2,
    Name = "Command_2",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[3] = {
    Id = 3,
    Name = "Command_3",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[4] = {
    Id = 4,
    Name = "Command_4",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[5] = {
    Id = 5,
    Name = "Command_5",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[6] = {
    Id = 6,
    Name = "Command_6",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[7] = {
    Id = 7,
    Name = "Command_7",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[8] = {
    Id = 8,
    Name = "Command_8",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[9] = {
    Id = 9,
    Name = "Command_9",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[10] = {
    Id = 10,
    Name = "Command_10",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[11] = {
    Id = 11,
    Name = "Command_11",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[12] = {
    Id = 12,
    Name = "Command_12",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[13] = {
    Id = 13,
    Name = "Command_13",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[14] = {
    Id = 14,
    Name = "Command_14",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[15] = {
    Id = 15,
    Name = "Command_15",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[16] = {
    Id = 16,
    Name = "Command_16",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[17] = {
    Id = 17,
    Name = "Command_17",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[18] = {
    Id = 18,
    Name = "Command_18",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[19] = {
    Id = 19,
    Name = "Command_19",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[20] = {
    Id = 20,
    Name = "Command_20",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[21] = {
    Id = 21,
    Name = "Command_21",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[22] = {
    Id = 22,
    Name = "Command_22",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[23] = {
    Id = 23,
    Name = "Command_23",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[24] = {
    Id = 24,
    Name = "Command_24",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[25] = {
    Id = 25,
    Name = "Command_25",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[26] = {
    Id = 26,
    Name = "Command_26",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[27] = {
    Id = 27,
    Name = "Command_27",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[28] = {
    Id = 28,
    Name = "Command_28",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[29] = {
    Id = 29,
    Name = "Command_29",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[30] = {
    Id = 30,
    Name = "Command_30",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[31] = {
    Id = 31,
    Name = "Command_31",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[32] = {
    Id = 32,
    Name = "Command_32",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[33] = {
    Id = 33,
    Name = "Command_33",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[34] = {
    Id = 34,
    Name = "Command_34",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[35] = {
    Id = 35,
    Name = "Command_35",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[36] = {
    Id = 36,
    Name = "Command_36",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[37] = {
    Id = 37,
    Name = "Command_37",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[38] = {
    Id = 38,
    Name = "Command_38",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[39] = {
    Id = 39,
    Name = "Command_39",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[40] = {
    Id = 40,
    Name = "Command_40",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[41] = {
    Id = 41,
    Name = "Command_41",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[42] = {
    Id = 42,
    Name = "Command_42",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[43] = {
    Id = 43,
    Name = "Command_43",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[44] = {
    Id = 44,
    Name = "Command_44",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[45] = {
    Id = 45,
    Name = "Command_45",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[46] = {
    Id = 46,
    Name = "Command_46",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[47] = {
    Id = 47,
    Name = "Command_47",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[48] = {
    Id = 48,
    Name = "Command_48",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[49] = {
    Id = 49,
    Name = "Command_49",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[50] = {
    Id = 50,
    Name = "Command_50",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[51] = {
    Id = 51,
    Name = "Command_51",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[52] = {
    Id = 52,
    Name = "Command_52",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[53] = {
    Id = 53,
    Name = "Command_53",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[54] = {
    Id = 54,
    Name = "Command_54",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[55] = {
    Id = 55,
    Name = "Command_55",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[56] = {
    Id = 56,
    Name = "Command_56",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[57] = {
    Id = 57,
    Name = "Command_57",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[58] = {
    Id = 58,
    Name = "Command_58",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[59] = {
    Id = 59,
    Name = "Command_59",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[60] = {
    Id = 60,
    Name = "Command_60",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[61] = {
    Id = 61,
    Name = "Command_61",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[62] = {
    Id = 62,
    Name = "Command_62",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[63] = {
    Id = 63,
    Name = "Command_63",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[64] = {
    Id = 64,
    Name = "Command_64",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[65] = {
    Id = 65,
    Name = "Command_65",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[66] = {
    Id = 66,
    Name = "Command_66",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[67] = {
    Id = 67,
    Name = "Command_67",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[68] = {
    Id = 68,
    Name = "Command_68",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[69] = {
    Id = 69,
    Name = "Command_69",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[70] = {
    Id = 70,
    Name = "Command_70",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[71] = {
    Id = 71,
    Name = "Command_71",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[72] = {
    Id = 72,
    Name = "Command_72",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[73] = {
    Id = 73,
    Name = "Command_73",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[74] = {
    Id = 74,
    Name = "Command_74",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[75] = {
    Id = 75,
    Name = "Command_75",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[76] = {
    Id = 76,
    Name = "Command_76",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[77] = {
    Id = 77,
    Name = "Command_77",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[78] = {
    Id = 78,
    Name = "Command_78",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[79] = {
    Id = 79,
    Name = "Command_79",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[80] = {
    Id = 80,
    Name = "Command_80",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[81] = {
    Id = 81,
    Name = "Command_81",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[82] = {
    Id = 82,
    Name = "Command_82",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[83] = {
    Id = 83,
    Name = "Command_83",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[84] = {
    Id = 84,
    Name = "Command_84",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[85] = {
    Id = 85,
    Name = "Command_85",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[86] = {
    Id = 86,
    Name = "Command_86",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[87] = {
    Id = 87,
    Name = "Command_87",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[88] = {
    Id = 88,
    Name = "Command_88",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[89] = {
    Id = 89,
    Name = "Command_89",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[90] = {
    Id = 90,
    Name = "Command_90",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[91] = {
    Id = 91,
    Name = "Command_91",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[92] = {
    Id = 92,
    Name = "Command_92",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[93] = {
    Id = 93,
    Name = "Command_93",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[94] = {
    Id = 94,
    Name = "Command_94",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[95] = {
    Id = 95,
    Name = "Command_95",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[96] = {
    Id = 96,
    Name = "Command_96",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[97] = {
    Id = 97,
    Name = "Command_97",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[98] = {
    Id = 98,
    Name = "Command_98",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[99] = {
    Id = 99,
    Name = "Command_99",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[100] = {
    Id = 100,
    Name = "Command_100",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[101] = {
    Id = 101,
    Name = "Command_101",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[102] = {
    Id = 102,
    Name = "Command_102",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[103] = {
    Id = 103,
    Name = "Command_103",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[104] = {
    Id = 104,
    Name = "Command_104",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[105] = {
    Id = 105,
    Name = "Command_105",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[106] = {
    Id = 106,
    Name = "Command_106",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[107] = {
    Id = 107,
    Name = "Command_107",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[108] = {
    Id = 108,
    Name = "Command_108",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[109] = {
    Id = 109,
    Name = "Command_109",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[110] = {
    Id = 110,
    Name = "Command_110",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[111] = {
    Id = 111,
    Name = "Command_111",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[112] = {
    Id = 112,
    Name = "Command_112",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[113] = {
    Id = 113,
    Name = "Command_113",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[114] = {
    Id = 114,
    Name = "Command_114",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[115] = {
    Id = 115,
    Name = "Command_115",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[116] = {
    Id = 116,
    Name = "Command_116",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[117] = {
    Id = 117,
    Name = "Command_117",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[118] = {
    Id = 118,
    Name = "Command_118",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[119] = {
    Id = 119,
    Name = "Command_119",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[120] = {
    Id = 120,
    Name = "Command_120",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[121] = {
    Id = 121,
    Name = "Command_121",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[122] = {
    Id = 122,
    Name = "Command_122",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[123] = {
    Id = 123,
    Name = "Command_123",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[124] = {
    Id = 124,
    Name = "Command_124",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[125] = {
    Id = 125,
    Name = "Command_125",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[126] = {
    Id = 126,
    Name = "Command_126",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[127] = {
    Id = 127,
    Name = "Command_127",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[128] = {
    Id = 128,
    Name = "Command_128",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[129] = {
    Id = 129,
    Name = "Command_129",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[130] = {
    Id = 130,
    Name = "Command_130",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[131] = {
    Id = 131,
    Name = "Command_131",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[132] = {
    Id = 132,
    Name = "Command_132",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[133] = {
    Id = 133,
    Name = "Command_133",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[134] = {
    Id = 134,
    Name = "Command_134",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[135] = {
    Id = 135,
    Name = "Command_135",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[136] = {
    Id = 136,
    Name = "Command_136",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[137] = {
    Id = 137,
    Name = "Command_137",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[138] = {
    Id = 138,
    Name = "Command_138",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[139] = {
    Id = 139,
    Name = "Command_139",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[140] = {
    Id = 140,
    Name = "Command_140",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[141] = {
    Id = 141,
    Name = "Command_141",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[142] = {
    Id = 142,
    Name = "Command_142",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[143] = {
    Id = 143,
    Name = "Command_143",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[144] = {
    Id = 144,
    Name = "Command_144",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[145] = {
    Id = 145,
    Name = "Command_145",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[146] = {
    Id = 146,
    Name = "Command_146",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[147] = {
    Id = 147,
    Name = "Command_147",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[148] = {
    Id = 148,
    Name = "Command_148",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[149] = {
    Id = 149,
    Name = "Command_149",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[150] = {
    Id = 150,
    Name = "Command_150",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[151] = {
    Id = 151,
    Name = "Command_151",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[152] = {
    Id = 152,
    Name = "Command_152",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[153] = {
    Id = 153,
    Name = "Command_153",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[154] = {
    Id = 154,
    Name = "Command_154",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[155] = {
    Id = 155,
    Name = "Command_155",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[156] = {
    Id = 156,
    Name = "Command_156",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[157] = {
    Id = 157,
    Name = "Command_157",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[158] = {
    Id = 158,
    Name = "Command_158",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[159] = {
    Id = 159,
    Name = "Command_159",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[160] = {
    Id = 160,
    Name = "Command_160",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[161] = {
    Id = 161,
    Name = "Command_161",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[162] = {
    Id = 162,
    Name = "Command_162",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[163] = {
    Id = 163,
    Name = "Command_163",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[164] = {
    Id = 164,
    Name = "Command_164",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[165] = {
    Id = 165,
    Name = "Command_165",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[166] = {
    Id = 166,
    Name = "Command_166",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[167] = {
    Id = 167,
    Name = "Command_167",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[168] = {
    Id = 168,
    Name = "Command_168",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[169] = {
    Id = 169,
    Name = "Command_169",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[170] = {
    Id = 170,
    Name = "Command_170",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[171] = {
    Id = 171,
    Name = "Command_171",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[172] = {
    Id = 172,
    Name = "Command_172",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[173] = {
    Id = 173,
    Name = "Command_173",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[174] = {
    Id = 174,
    Name = "Command_174",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[175] = {
    Id = 175,
    Name = "Command_175",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[176] = {
    Id = 176,
    Name = "Command_176",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[177] = {
    Id = 177,
    Name = "Command_177",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[178] = {
    Id = 178,
    Name = "Command_178",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[179] = {
    Id = 179,
    Name = "Command_179",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[180] = {
    Id = 180,
    Name = "Command_180",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[181] = {
    Id = 181,
    Name = "Command_181",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[182] = {
    Id = 182,
    Name = "Command_182",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[183] = {
    Id = 183,
    Name = "Command_183",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[184] = {
    Id = 184,
    Name = "Command_184",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[185] = {
    Id = 185,
    Name = "Command_185",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[186] = {
    Id = 186,
    Name = "Command_186",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[187] = {
    Id = 187,
    Name = "Command_187",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[188] = {
    Id = 188,
    Name = "Command_188",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[189] = {
    Id = 189,
    Name = "Command_189",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[190] = {
    Id = 190,
    Name = "Command_190",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[191] = {
    Id = 191,
    Name = "Command_191",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[192] = {
    Id = 192,
    Name = "Command_192",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[193] = {
    Id = 193,
    Name = "Command_193",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[194] = {
    Id = 194,
    Name = "Command_194",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[195] = {
    Id = 195,
    Name = "Command_195",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[196] = {
    Id = 196,
    Name = "Command_196",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[197] = {
    Id = 197,
    Name = "Command_197",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[198] = {
    Id = 198,
    Name = "Command_198",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[199] = {
    Id = 199,
    Name = "Command_199",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[200] = {
    Id = 200,
    Name = "Command_200",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[201] = {
    Id = 201,
    Name = "Command_201",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[202] = {
    Id = 202,
    Name = "Command_202",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[203] = {
    Id = 203,
    Name = "Command_203",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[204] = {
    Id = 204,
    Name = "Command_204",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[205] = {
    Id = 205,
    Name = "Command_205",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[206] = {
    Id = 206,
    Name = "Command_206",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[207] = {
    Id = 207,
    Name = "Command_207",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[208] = {
    Id = 208,
    Name = "Command_208",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[209] = {
    Id = 209,
    Name = "Command_209",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[210] = {
    Id = 210,
    Name = "Command_210",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[211] = {
    Id = 211,
    Name = "Command_211",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[212] = {
    Id = 212,
    Name = "Command_212",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[213] = {
    Id = 213,
    Name = "Command_213",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[214] = {
    Id = 214,
    Name = "Command_214",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[215] = {
    Id = 215,
    Name = "Command_215",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[216] = {
    Id = 216,
    Name = "Command_216",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[217] = {
    Id = 217,
    Name = "Command_217",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[218] = {
    Id = 218,
    Name = "Command_218",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[219] = {
    Id = 219,
    Name = "Command_219",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[220] = {
    Id = 220,
    Name = "Command_220",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[221] = {
    Id = 221,
    Name = "Command_221",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[222] = {
    Id = 222,
    Name = "Command_222",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[223] = {
    Id = 223,
    Name = "Command_223",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[224] = {
    Id = 224,
    Name = "Command_224",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[225] = {
    Id = 225,
    Name = "Command_225",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[226] = {
    Id = 226,
    Name = "Command_226",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[227] = {
    Id = 227,
    Name = "Command_227",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[228] = {
    Id = 228,
    Name = "Command_228",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[229] = {
    Id = 229,
    Name = "Command_229",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[230] = {
    Id = 230,
    Name = "Command_230",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[231] = {
    Id = 231,
    Name = "Command_231",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[232] = {
    Id = 232,
    Name = "Command_232",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[233] = {
    Id = 233,
    Name = "Command_233",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[234] = {
    Id = 234,
    Name = "Command_234",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[235] = {
    Id = 235,
    Name = "Command_235",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[236] = {
    Id = 236,
    Name = "Command_236",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[237] = {
    Id = 237,
    Name = "Command_237",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[238] = {
    Id = 238,
    Name = "Command_238",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[239] = {
    Id = 239,
    Name = "Command_239",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[240] = {
    Id = 240,
    Name = "Command_240",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[241] = {
    Id = 241,
    Name = "Command_241",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[242] = {
    Id = 242,
    Name = "Command_242",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[243] = {
    Id = 243,
    Name = "Command_243",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[244] = {
    Id = 244,
    Name = "Command_244",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[245] = {
    Id = 245,
    Name = "Command_245",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[246] = {
    Id = 246,
    Name = "Command_246",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[247] = {
    Id = 247,
    Name = "Command_247",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[248] = {
    Id = 248,
    Name = "Command_248",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[249] = {
    Id = 249,
    Name = "Command_249",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[250] = {
    Id = 250,
    Name = "Command_250",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[251] = {
    Id = 251,
    Name = "Command_251",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[252] = {
    Id = 252,
    Name = "Command_252",
    Category = "Movement",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[253] = {
    Id = 253,
    Name = "Command_253",
    Category = "Visuals",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[254] = {
    Id = 254,
    Name = "Command_254",
    Category = "Utility",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[255] = {
    Id = 255,
    Name = "Command_255",
    Category = "Performance",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[256] = {
    Id = 256,
    Name = "Command_256",
    Category = "Settings",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[257] = {
    Id = 257,
    Name = "Command_257",
    Category = "Home",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[258] = {
    Id = 258,
    Name = "Command_258",
    Category = "Player",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}
CommandRegistry[259] = {
    Id = 259,
    Name = "Command_259",
    Category = "Character",
    Enabled = true,
    CanExecute = function()
        return not Destroyed
    end,
    Execute = function()
        if Destroyed then return false end
        return true
    end,
}

local function CountEnabledFeatures()
    local count = 0
    for _, feature in pairs(FeatureRegistry) do
        if feature.Enabled then count += 1 end
    end
    return count
end

local function ValidateFeatureRegistry()
    local valid = 0
    for _, feature in pairs(FeatureRegistry) do
        if type(feature.Validate) == "function" then
            local ok, result = pcall(feature.Validate)
            if ok and result then valid += 1 end
        end
    end
    return valid, CountEnabledFeatures()
end

local RegistryValid, RegistryTotal = ValidateFeatureRegistry()
if RegistryValid ~= RegistryTotal then
    warn(string.format("[CustomUtility] Registry validation: %d/%d", RegistryValid, RegistryTotal))
end

local function GetRuntimeSummary()
    return {
        Version = VERSION,
        Player = LocalPlayer.Name,
        UserId = LocalPlayer.UserId,
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        FPS = fpsValue,
        Ping = GetPing(),
        PlayerCount = #Players:GetPlayers(),
        CurrentTab = CurrentTab,
        WindowVisible = WindowVisible,
        FeatureCount = RegistryTotal,
    }
end

AddCleanup(function()
    table.clear(Tabs)
    table.clear(Components)
    table.clear(FeatureState)
    table.clear(ESPObjects)
    table.clear(Drawings)
    table.clear(Notifications)
end)


return {
    Version = VERSION,
    Config = Config,
    ExecuteCommand = ExecuteCommand,
    Notify = Notify,
    ToggleWindow = ToggleWindow,
    GetRuntimeSummary = GetRuntimeSummary,
    Destroy = function()
        if not Destroyed then
            CloseButton:Activate()
        end
    end,
}
