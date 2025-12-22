-- 精简版：只有Rayfield自带控制 + 僵尸高亮功能
print("正在加载Rayfield...")

-- 尝试不同的Rayfield链接
local Rayfield
local rayfieldLinks = {
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/Syntaxx64/Rayfield/main/Rayfield"
}

for i, link in ipairs(rayfieldLinks) do
    print("尝试链接 " .. i .. ": " .. link)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(link))()
    end)
    
    if success then
        Rayfield = result
        print("✅ Rayfield加载成功，来自链接" .. i)
        break
    else
        print("❌ 链接" .. i .. "失败: " .. tostring(result))
    end
end

if not Rayfield then
    print("所有Rayfield链接都失败")
    return
end

print("创建Rayfield窗口...")

local Window = Rayfield:CreateWindow({
    Name = "僵尸高亮系统",
    LoadingTitle = "加载中",
    LoadingSubtitle = "请稍候",
    ConfigurationSaving = {
        Enabled = false
    }
})

-- ===== 获取游戏服务 =====
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local camera = Workspace:WaitForChild("Camera")

-- ===== 系统变量 =====
local systemConfig = {
    zombieHighlighter = {
        Enabled = true,
        AutoHighlight = true,
        HighlightEffect = true,
        Colors = {
            Torch = Color3.fromRGB(255, 165, 0),
            Cuirskull = Color3.fromRGB(128, 0, 128),
            Axe = Color3.fromRGB(255, 0, 0),
            Eye = Color3.fromRGB(0, 200, 255),
            Normal = Color3.fromRGB(0, 170, 0)
        }
    },
    nightVision = {
        Enabled = false,
        OriginalOutdoorAmbient = Lighting.OutdoorAmbient,
        NightVisionColor = Color3.fromRGB(255, 255, 255),
        UpdateConnection = nil
    },
    speedSystem = {
        customSpeed = 16,
        freezeSpeed = false,
        speedLoop = nil
    }
}

-- ===== 创建所有标签页 =====
print("创建标签页...")
local MainTab = Window:CreateTab("主要控制", 4483362458)
local HighlightTab = Window:CreateTab("高亮", 4483362458)
local NightVisionTab = Window:CreateTab("夜视", 4483362458)
local SpeedTab = Window:CreateTab("速度", 4483362458)
local SettingsTab = Window:CreateTab("颜色设置", 4483362458)
print("标签页创建完成")

-- ===== 夜视功能 =====
local function updateNightVision()
    if systemConfig.nightVision.Enabled then
        Lighting.OutdoorAmbient = systemConfig.nightVision.NightVisionColor
    else
        Lighting.OutdoorAmbient = systemConfig.nightVision.OriginalOutdoorAmbient
    end
end

local function startNightVisionUpdater()
    if systemConfig.nightVision.UpdateConnection then
        systemConfig.nightVision.UpdateConnection:Disconnect()
    end
    
    systemConfig.nightVision.UpdateConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if systemConfig.nightVision.Enabled then
            Lighting.OutdoorAmbient = systemConfig.nightVision.NightVisionColor
        end
    end)
end

-- ===== 僵尸高亮功能 =====
local function processZombie(zombie)
    if not systemConfig.zombieHighlighter.Enabled then return end
    
    local function hasComponent(name)
        if zombie:FindFirstChild(name) then return true end
        for _, d in ipairs(zombie:GetDescendants()) do
            if d.Name == name then return true end
        end
        return false
    end
    
    local color
    local hasTorch = hasComponent("Torch")
    local hasCuirskull = hasComponent("Cuirskull")
    local hasEye = hasComponent("Eye")
    local hasAxe = hasComponent("Axe")
    
    if hasTorch then
        color = systemConfig.zombieHighlighter.Colors.Torch
    elseif hasCuirskull then
        color = systemConfig.zombieHighlighter.Colors.Cuirskull
    elseif hasEye and hasAxe then
        color = systemConfig.zombieHighlighter.Colors.Axe
    elseif hasEye then
        color = systemConfig.zombieHighlighter.Colors.Eye
    else
        color = systemConfig.zombieHighlighter.Colors.Normal
    end
    
    local hl = zombie:FindFirstChild("Highlight")
    
    if systemConfig.zombieHighlighter.HighlightEffect then
        if hl then
            hl.FillColor = color
            hl.OutlineColor = color
            hl.Enabled = true
        else
            hl = Instance.new("Highlight")
            hl.Name = "Highlight"
            hl.Adornee = zombie
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillColor = color
            hl.FillTransparency = 0.5
            hl.OutlineColor = color
            hl.OutlineTransparency = 0
            hl.Parent = zombie
        end
    else
        if hl then
            hl.Enabled = false
        end
    end
end

local function initializeZombies()
    for _, z in ipairs(camera:GetChildren()) do
        if z:IsA("Model") and z.Name == "m_Zombie" then
            processZombie(z)
        end
    end
end

local function removeAllHighlights()
    for _, z in ipairs(camera:GetChildren()) do
        if z:IsA("Model") and z.Name == "m_Zombie" then
            local hl = z:FindFirstChild("Highlight")
            if hl then hl:Destroy() end
        end
    end
end

local function toggleHighlightEffects(enabled)
    for _, z in ipairs(camera:GetChildren()) do
        if z:IsA("Model") and z.Name == "m_Zombie" then
            local hl = z:FindFirstChild("Highlight")
            if hl then
                hl.Enabled = enabled
            end
        end
    end
end

-- ===== 速度控制功能 =====
local function applySpeedToPlayer()
    if not LocalPlayer then
        print("❌ 找不到本地玩家")
        return false
    end
    
    local character = LocalPlayer.Character
    if not character then
        local connection
        connection = LocalPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(0.5)
            local humanoid = newChar:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = systemConfig.speedSystem.customSpeed
            end
            connection:Disconnect()
        end)
        return false
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        print("❌ 找不到Humanoid")
        return false
    end
    
    humanoid.WalkSpeed = systemConfig.speedSystem.customSpeed
    return true
end

local function startSpeedLoop()
    if systemConfig.speedSystem.speedLoop then
        systemConfig.speedSystem.speedLoop:Disconnect()
        systemConfig.speedSystem.speedLoop = nil
    end
    
    systemConfig.speedSystem.speedLoop = game:GetService("RunService").Heartbeat:Connect(function()
        if not systemConfig.speedSystem.freezeSpeed then return end
        applySpeedToPlayer()
    end)
end

-- ===== 监听新僵尸 =====
camera.ChildAdded:Connect(function(z)
    if z:IsA("Model") and z.Name == "m_Zombie" and systemConfig.zombieHighlighter.AutoHighlight then
        task.wait(0.2)
        processZombie(z)
    end
end)

-- 立即初始化
initializeZombies()

-- ===== 主要控制标签页内容 =====
MainTab:CreateToggle({
    Name = "启用僵尸高亮",
    CurrentVCurrentValue = systemConfig.zombieHighlighter.Enabled,
    Callback = function(value)
        systemConfig.zombieHighlighter.Enabled = value
        if value then
            initializeZombies()
            Rayfield:Notify({
                Title = "系统开启",
                Content = "僵尸高亮已启用",
                Duration = 2
            })
        else
            removeAllHighlights()
            Rayfield:Notify({
                Title = "系统关闭",
                Content = "僵尸高亮已禁用",
                Duration = 2
            })
        end
    end
})

MainTab:CreateToggle({
    Name = "自动高亮新僵尸",
    CurrentValue = systemConfig.zombieHighlighter.AutoHighlight,
    Callback = function(value)
        systemConfig.zombieHighlighter.AutoHighlight = value
    end
})

MainTab:CreateButton({
    Name = "立即高亮所有僵尸",
    Callback = function()
        initializeZombies()
        Rayfield:Notify({
            Title = "操作完成",
            Content = "已更新所有僵尸高亮",
            Duration = 2
        })
    end
})

MainTab:CreateButton({
    Name = "清除所有高亮",
    Callback = function()
        removeAllHighlights()
        Rayfield:Notify({
            Title = "操作完成",
            Content = "已清除所有高亮",
            Duration = 2
        })
    end
})

-- ===== 高亮标签页内容 =====
HighlightTab:CreateSection("高亮效果控制")

HighlightTab:CreateToggle({
    Name = "开启高亮效果",
    CurrentValue = systemConfig.zombieHighlighter.HighlightEffect,
    Callback = function(value)
        systemConfig.zombieHighlighter.HighlightEffect = value
        if value then
            toggleHighlightEffects(true)
            Rayfield:Notify({
                Title = "高亮效果",
                Content = "高亮效果已开启",
                Duration = 2
            })
        else
            toggleHighlightEffects(false)
            Rayfield:Notify({
                Title = "高亮效果",
                Content = "高亮效果已关闭",
                Duration = 2
            })
        end
    end
})
HighlightTab:CreateSlider({
    Name = "填充透明度",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.5,
    Callback = function(value)
        for _, z in ipairs(camera:GetChildren()) do
            if z:IsA("Model") and z.Name == "m_Zombie" then
                local hl = z:FindFirstChild("Highlight")
                if hl then
                    hl.FillTransparency = value
                end
            end
        end
    end
})

HighlightTab:CreateSlider({
    Name = "轮廓透明度",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0,
    Callback = function(value)
        for _, z in ipairs(camera:GetChildren()) do
            if z:IsA("Model") and z.Name == "m_Zombie" then
                local hl = z:FindFirstChild("Highlight")
                if hl then
                    hl.OutlineTransparency = value
                end
            end
        end
    end
})

HighlightTab:CreateDropdown({
    Name = "深度模式",
    Options = {"总是最前", "遮挡", "总是最后"},
    CurrentOption = "总是最前",
    Callback = function(option)
        local depthMode
        if option == "总是最前" then
            depthMode = Enum.HighlightDepthMode.AlwaysOnTop
        elseif option == "遮挡" then
            depthMode = Enum.HighlightDepthMode.Occluded
        else
            depthMode = Enum.HighlightDepthMode.AlwaysBehind
        end
        
        for _, z in ipairs(camera:GetChildren()) do
            if z:IsA("Model") and z.Name == "m_Zombie" then
                local hl = z:FindFirstChild("Highlight")
                if hl then
                    hl.DepthMode = depthMode
                end
            end
        end
    end
})

HighlightTab:CreateButton({
    Name = "重置高亮设置",
    Callback = function()
        for _, z in ipairs(camera:GetChildren()) do
            if z:IsA("Model") and z.Name == "m_Zombie" then
                local hl = z:FindFirstChild("Highlight")
                if hl then
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
            end
        end
        
        Rayfield:Notify({
            Title = "重置完成",
            Content = "高亮设置已恢复默认",
            Duration = 2
        })
    end
})
-- ===== 夜视标签页内容 =====
NightVisionTab:CreateSection("夜视效果")

NightVisionTab:CreateToggle({
    Name = "开启夜视模式",
    CurrentValue = systemConfig.nightVision.Enabled,
    Callback = function(value)
        systemConfig.nightVision.Enabled = value
        
        if value then
            systemConfig.nightVision.OriginalOutdoorAmbient = Lighting.OutdoorAmbient
            updateNightVision()
            startNightVisionUpdater()
            
            Rayfield:Notify({
                Title = "夜视模式",
                Content = "夜视模式已开启",
                Duration = 2
            })
        else
            if systemConfig.nightVision.UpdateConnection then
                systemConfig.nightVision.UpdateConnection:Disconnect()
                systemConfig.nightVision.UpdateConnection = nil
            end
            updateNightVision()
            
            Rayfield:Notify({
                Title = "夜视模式",
                Content = "夜视模式已关闭",
                Duration = 2
            })
        end
    end
})

NightVisionTab:CreateColorPicker({
    Name = "夜视颜色",
    Color = systemConfig.nightVision.NightVisionColor,
    Callback = function(color)
        systemConfig.nightVision.NightVisionColor = color
        if systemConfig.nightVision.Enabled then
            updateNightVision()
        end
    end
})

NightVisionTab:CreateSlider({
    Name = "夜视亮度",
    Range = {0, 255},
    Increment = 5,
    Suffix = "",
    CurrentValue = 255,
    Callback = function(value)
        systemConfig.nightVision.NightVisionColor = Color3.fromRGB(value, value, value)
        if systemConfig.nightVision.Enabled then
            updateNightVision()
        end
    end
})

NightVisionTab:CreateLabel("当前环境光颜色:")
local currentColorLabel = NightVisionTab:CreateLabel(
    string.format("R: %.2f, G: %.2f, B: %.2f", 
        Lighting.OutdoorAmbient.R * 255,
        Lighting.OutdoorAmbient.G * 255,
        Lighting.OutdoorAmbient.B * 255
    )
)

spawn(function()
    while true do
        task.wait(1)
        if systemConfig.nightVision.Enabled then
            currentColorLabel.Text = string.format("夜视中: R: %.0f, G: %.0f, B: %.0f",
                systemConfig.nightVision.NightVisionColor.R * 255,
                systemConfig.nightVision.NightVisionColor.G * 255,
                systemConfig.nightVision.NightVisionColor.B * 255
            )
        else
            currentColorLabel.Text = string.format("原始: R: %.2f, G: %.2f, B: %.2f",
                Lighting.OutdoorAmbient.R * 255,
                Lighting.OutdoorAmbient.G * 255,
                Lighting.OutdoorAmbient.B * 255
            )
        end
    end
end)

NightVisionTab:CreateButton({
    Name = "重置夜视设置",
    Callback = function()
        if systemConfig.nightVision.Enabled then
            systemConfig.nightVision.Enabled = false
            if systemConfig.nightVision.UpdateConnection then
                systemConfig.nightVision.UpdateConnection:Disconnect()
                systemConfig.nightVision.UpdateConnection = nil
            end
            updateNightVision()
        end
        
        systemConfig.nightVision.NightVisionColor = Color3.fromRGB(255, 255, 255)
        
        Rayfield:Notify({
            Title = "夜视重置",
            Content = "夜视设置已恢复默认",
            Duration = 2
        })
    end
})
-- ===== 速度标签页内容 =====
SpeedTab:CreateSection("速度设置")

SpeedTab:CreateSlider({
    Name = "移动速度",
    Range = {0, 300},
    Increment = 1,
    Suffix = " 单位",
    CurrentValue = systemConfig.speedSystem.customSpeed,
    Callback = function(value)
        systemConfig.speedSystem.customSpeed = value
        if systemConfig.speedSystem.freezeSpeed then
            applySpeedToPlayer()
        end
        
        Rayfield:Notify({
            Title = "速度设置",
            Content = "速度已设置为: " .. value,
            Duration = 2
        })
    end
})

SpeedTab:CreateToggle({
    Name = "锁定速度",
    CurrentValue = systemConfig.speedSystem.freezeSpeed,
    Callback = function(value)
        systemConfig.speedSystem.freezeSpeed = value
        
        if value then
            applySpeedToPlayer()
            startSpeedLoop()
            Rayfield:Notify({
                Title = "速度锁定",
                Content = "速度已锁定: " .. systemConfig.speedSystem.customSpeed,
                Duration = 2
            })
        else
            if systemConfig.speedSystem.speedLoop then
                systemConfig.speedSystem.speedLoop:Disconnect()
                systemConfig.speedSystem.speedLoop = nil
            end
            Rayfield:Notify({
                Title = "速度锁定",
                Content = "速度锁定已关闭",
                Duration = 2
            })
        end
    end
})

SpeedTab:CreateLabel("当前速度设置:")
local speedValueLabel = SpeedTab:CreateLabel(systemConfig.speedSystem.customSpeed .. " 单位")

SpeedTab:CreateSection("预设速度")

local presetSpeeds = {
    {Name = "慢速 (10)", Speed = 10},
    {Name = "默认 (16)", Speed = 16},
    {Name = "快速 (30)", Speed = 30},
    {Name = "极速 (50)", Speed = 50},
    {Name = "超速 (100)", Speed = 100},
    {Name = "闪电 (200)", Speed = 200}
}

for _, preset in ipairs(presetSpeeds) do
    SpeedTab:CreateButton({
        Name = preset.Name,
        Callback = function()
            systemConfig.speedSystem.customSpeed = preset.Speed
            
            if systemConfig.speedSystem.freezeSpeed then
                applySpeedToPlayer()
            end
            
            Rayfield:Notify({
                Title = "预设速度",
                Content = "已设置为: " .. preset.Name,
                Duration = 2
            })
        end
    })
end

SpeedTab:CreateSection("实时监视")

SpeedTab:CreateLabel("实时移动速度:")
local realSpeedLabel = SpeedTab:CreateLabel("等待获取...")

spawn(function()
    while true do
        task.wait(0.5)
        if LocalPlayer and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                realSpeedLabel.Text = math.floor(humanoid.WalkSpeed) .. " 单位"
            else
                realSpeedLabel.Text = "无Humanoid"
            end
        else
            realSpeedLabel.Text = "无角色"
        end
    end
end)

SpeedTab:CreateSection("控制")

SpeedTab:CreateButton({
    Name = "立即应用速度",
    Callback = function()
        if applySpeedToPlayer() then
            Rayfield:Notify({
                Title = "应用成功",
                Content = "速度已应用: " .. systemConfig.speedSystem.customSpeed,
                Duration = 2
            })
        else
            Rayfield:Notify({
                Title = "应用失败",
                Content = "无法应用速度，请稍后重试",
                Duration = 2
            })
        end
    end
})
SpeedTab:CreateButton({
    Name = "重置速度",
    Callback = function()
        systemConfig.speedSystem.customSpeed = 16
        systemConfig.speedSystem.freezeSpeed = false
        
        if systemConfig.speedSystem.speedLoop then
            systemConfig.speedSystem.speedLoop:Disconnect()
            systemConfig.speedSystem.speedLoop = nil
        end
        
        if LocalPlayer and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
            end
        end
        
        Rayfield:Notify({
            Title = "速度重置",
            Content = "已恢复默认速度: 16",
            Duration = 2
        })
    end
})

-- ===== 颜色设置标签页内容 =====
SettingsTab:CreateColorPicker({
    Name = "自爆僵尸 (Torch)",
    Color = systemConfig.zombieHighlighter.Colors.Torch,
    Callback = function(color)
        systemConfig.zombieHighlighter.Colors.Torch = color
        initializeZombies()
    end
})

SettingsTab:CreateColorPicker({
    Name = "Cuirskull僵尸",
    Color = systemConfig.zombieHighlighter.Colors.Cuirskull,
    Callback = function(color)
        systemConfig.zombieHighlighter.Colors.Cuirskull = color
        initializeZombies()
    end
})

SettingsTab:CreateColorPicker({
    Name = "斧头僵尸 (Eye+Axe)",
    Color = systemConfig.zombieHighlighter.Colors.Axe,
    Callback = function(color)
        systemConfig.zombieHighlighter.Colors.Axe = color
        initializeZombies()
    end
})

SettingsTab:CreateColorPicker({
    Name = "快速僵尸 (Eye)",
    Color = systemConfig.zombieHighlighter.Colors.Eye,
    Callback = function(color)
        systemConfig.zombieHighlighter.Colors.Eye = color
        initializeZombies()
    end
})

SettingsTab:CreateColorPicker({
    Name = "普通僵尸",
    Color = systemConfig.zombieHighlighter.Colors.Normal,
    Callback = function(color)
        systemConfig.zombieHighlighter.Colors.Normal = color
        initializeZombies()
    end
})

SettingsTab:CreateButton({
    Name = "重置为默认颜色",
    Callback = function()
        systemConfig.zombieHighlighter.Colors = {
            Torch = Color3.fromRGB(255, 165, 0),
            Cuirskull = Color3.fromRGB(128, 0, 128),
            Axe = Color3.fromRGB(255, 0, 0),
            Eye = Color3.fromRGB(0, 200, 255),
            Normal = Color3.fromRGB(0, 170, 0)
        }
        initializeZombies()
        Rayfield:Notify({
            Title = "颜色重置",
            Content = "已恢复默认颜色",
            Duration = 2
        })
    end
})

print("✅ 系统启动完成！")

Rayfield:Notify({
    Title = "僵尸高亮系统",
    Content = "已启动！包含高亮、夜视、速度功能",
    Duration = 5
})
