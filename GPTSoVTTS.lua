-- GPTSoVTTS.lua
-- DaVinci Resolve 插件
-- 版本: 1.0
-- 作者: 125690d
-- 功能: 用于自动化请求GPT-SoVITS进行语音合成，并自动添加到视频音轨上

local ui = fu.UIManager
local dispatcher = bmd.UIDispatcher(ui)

----------------------常量配置----------------------
local LanguageMap = {
    [0] = "all_zh",
    "en",
    "all_ja",
    "all_ko",
    "all_yue",

    "zh",
    "ja",
    "yue",
    "ko",
    "auto",
    "auto_yue"
}
local LanguageTextMap = {
    [0] = "中文",
    "英文",
    "日文",
    "韩语",
    "粤语",

    "中英混合",
    "日英混合",
    "粤英混合",
    "韩英混合",
    "多语种混合",
    "多语种混合(粤语)"
}

local TempFolderName = "GPTSoVTTSTemp"
local ConfigFileName = "Config.txt"
local EnablePrintLog = false


----------------------小工具函数----------------------
-- 日志打印
local function log(...)
    local t = {...}
    local s = ""
    for i = 1, #t do s = s .. tostring(t[i]) .. "\t" end
    if EnablePrintLog then
        print("[GPTSoVTTS] " .. s)
    end
end

-- Safe find widget
local function findWidget(win, id)
    if not win then return nil end
    local ok, w = pcall(function() return win:Find(id) end)
    if ok then return w end
    return nil
end

-- Resolve helper
local function SafeGetResolve()
    local ok, res = pcall(function() return fusion:GetResolve() end)
    if ok and res then return res end
    ok, res = pcall(function() return bmd.scriptapp("Resolve") end)
    if ok and res then return res end
    return nil
end

local function SafeGetProjectAndTimeline()
    local resolve = SafeGetResolve()
    if not resolve then return nil, nil end
    local ok, pm = pcall(function() return resolve:GetProjectManager() end)
    if not ok or not pm then return nil, nil end
    local ok2, proj = pcall(function() return pm:GetCurrentProject() end)
    if not ok2 or not proj then return nil, nil end
    local ok3, timeline = pcall(function() return proj:GetCurrentTimeline() end)
    if not ok3 then timeline = nil end
    return proj, timeline
end

----------------------路径函数----------------------
-- 获取脚本文件路径
local function GetScriptPath()
    local separator = package.config:sub(1,1)
    local path
    
    if separator == '\\' then  -- Windows
        path = fusion:MapPath("Scripts:/Utility/GPTSoVTTS/")
    else  -- macOS/Linux
        path = fusion:MapPath("Scripts:/Utility/GPTSoVTTS/")
    end
    return path
end
-- 获取配置文件路径
local function GetConfigPath()
    return GetScriptPath() .. ConfigFileName
end
-- 获取临时文件夹路径
local function GetTempPath()
    return GetScriptPath() .. TempFolderName .. "/"
end


-- UI 管理对象
local UIManager = {}
UIManager.__index = UIManager

function UIManager:new()
    local obj = { window = nil }
    setmetatable(obj, UIManager)
    return obj
end

-- 创建并初始化主窗口
function UIManager:Init()
    self.window = dispatcher:AddWindow({
        ID = "GPTSoVTTS_MainWindow",
        WindowTitle = "GPTSoVITS - 语音合成",
        Geometry = {100, 100, 700, 540},
        ui.VGroup{
            ID = "MainLayout",
            ui.HGroup{
                ui.Label{
                    ID = "TitleLabel",
                    Text = "GPTSoVITS Bridge",
                    Weight = 1,
                    Alignment = { AlignHCenter = true, AlignVCenter = true },
                    Font = ui.Font{ PixelSize = 16, Bold = true }
                }
            },
            ui.VGap(8),
            ui.VGroup{
                ID = "ServerModelGroup",
                ui.Label{
                    ID = "ServerModelTitle",
                    Text = "服务 & 模型设置",
                    Font = ui.Font{ PixelSize = 14, Bold = true },
                    Alignment = { AlignHLeft = true, AlignVCenter = true }
                },
                ui.VGap(6),
                ui.VGroup{
                    ui.HGroup{
                        ui.Label{ ID = "ServerUrlLabel", Text = "服务地址:", Weight = 0.18 },
                        ui.LineEdit{ ID = "ServerUrlEdit", Text = "http://127.0.0.1:9880", Weight = 0.82 }
                    },
                    ui.HGroup{
                        ui.Label{ ID = "GPTModelLabel", Text = "GPT 模型权重:", Weight = 0.18 },
                        ui.LineEdit{ ID = "GPTModelEdit", Text = "", Weight = 0.66, PlaceholderText = "选择 GPT 模型权重文件" },
                        ui.Button{ ID = "BrowseGPTModelButton", Text = "选择文件", Weight = 0.16 }
                    },
                    ui.HGroup{
                        ui.Label{ ID = "SoVITSModelLabel", Text = "SoVITS 模型权重:", Weight = 0.18 },
                        ui.LineEdit{ ID = "SoVITSModelEdit", Text = "", Weight = 0.66, PlaceholderText = "选择 SoVITS 模型权重文件" },
                        ui.Button{ ID = "BrowseSoVITSModelButton", Text = "选择文件", Weight = 0.16 }
                    },
                    ui.HGroup{
                        ui.Label{ ID = "PromptAudioLabel", Text = "提示语音 (ref_audio):", Weight = 0.18 },
                        ui.LineEdit{ ID = "PromptAudioEdit", Text = "", Weight = 0.66, PlaceholderText = "选择提示语音文件" },
                        ui.Button{ ID = "BrowsePromptAudioButton", Text = "选择文件", Weight = 0.16 }
                    },
                    ui.HGroup{
                        ui.Label{ ID = "PromptTextLabel", Text = "提示语音对应文本:", Weight = 0.18 },
                        ui.LineEdit{ ID = "PromptTextEdit", Text = "", Weight = 0.82, PlaceholderText = "例如：你好，我是旁白" }
                    },
                    ui.HGroup{
                        ui.Label{ ID = "PromptLangLabel", Text = "提示文本语言:", Weight = 0.18 },
                        ui.ComboBox{ ID = "PromptLangCombo", CurrentIndex = 0, Weight = 0.82 }
                    }
                }
            },
            ui.VGap(10),
            ui.VGroup{
                ID = "OutputGroup",
                ui.Label{
                    ID = "OutputGroupTitle",
                    Text = "输出与轨道设置",
                    Font = ui.Font{ PixelSize = 14, Bold = true },
                    Alignment = { AlignHLeft = true, AlignVCenter = true }
                },
                ui.VGap(6),
                ui.VGroup{
                    ui.HGroup{
                        ui.Label{ ID = "OutputPathLabel", Text = "输出文件夹:", Weight = 0.18 },
                        ui.LineEdit{ ID = "OutputPathEdit", Text = "", Weight = 0.66, PlaceholderText = "请选择输出文件夹" },
                        ui.Button{ ID = "BrowseOutputButton", Text = "选择文件夹", Weight = 0.16 }
                    },
                    ui.HGroup{
                        ui.Label{ ID = "OutputLangLabel", Text = "输出语言:", Weight = 0.18 },
                        ui.ComboBox{ ID = "OutputLangCombo", CurrentIndex = 0, Weight = 0.82 }
                    },
                    ui.HGroup{
                        ui.Label{ ID = "TrackLabel", Text = "目标音频轨 (第几轨):", Weight = 0.18 },
                        ui.ComboBox{ ID = "TrackCombo", Items = { "自动(追加到时间线末端)" }, CurrentIndex = 0, Weight = 0.66 },
                        ui.Button{ ID = "RefreshTracksButton", Text = "刷新轨道列表", Weight = 0.16 }
                    }
                }
            },
            ui.VGap(12),
            ui.HGroup{
                ui.Button{ ID = "ProcessButton", Text = "开始", Weight = 0.6, Font = ui.Font{ PixelSize = 15, Bold = true } },
                ui.Button{ ID = "TestButton", Text = "测试连接", Weight = 0.2 }
            },
            ui.VGap(10),
            ui.VGroup{
                ui.Label{ ID = "ProgressLabel", Text = "就绪", Font = ui.Font{ PixelSize = 15 } },
            }
        }
    })

    self:ConnectEvents()
    self:RefreshTrackList()
    return true
end

-- 绑定事件
function UIManager:ConnectEvents()
    local w = self.window
    if not w then return end

    -- 关闭窗口事件
    self.window.On.GPTSoVTTS_MainWindow.Close = function()
        log("用户关闭窗口")
        self:SaveConfig()
        dispatcher:ExitLoop()
        pcall(function() UIManager:Close() end)
    end

    -- Browse GPT 模型
    w.On.BrowseGPTModelButton.Clicked = function()
        local ok, path = pcall(function() return fusion:RequestFile() end)
        if ok and path and path ~= "" then
            local ed = findWidget(w, "GPTModelEdit")
            if ed then ed.Text = path end
            log("已选择 GPT 模型: " .. path)
        else
            log("未选择 GPT 模型")
        end
    end

    -- Browse SoVITS 模型
    w.On.BrowseSoVITSModelButton.Clicked = function()
        local ok, path = pcall(function() return fusion:RequestFile() end)
        if ok and path and path ~= "" then
            local ed = findWidget(w, "SoVITSModelEdit")
            if ed then ed.Text = path end
            log("已选择 SoVITS 模型: " .. path)
        else
            log("未选择 SoVITS 模型")
        end
    end

    -- Browse Prompt audio
    w.On.BrowsePromptAudioButton.Clicked = function()
        local ok, path = pcall(function() return fusion:RequestFile() end)
        if ok and path and path ~= "" then
            local ed = findWidget(w, "PromptAudioEdit")
            if ed then ed.Text = path end
            log("已选择提示语音: " .. path)
        else
            log("未选择提示语音")
        end
    end

    -- Browse output folder
    w.On.BrowseOutputButton.Clicked = function()
        ok, res = pcall(function() return fusion:RequestDir() end)
        if res then
            local ed = findWidget(w, "OutputPathEdit")
            if ed then ed.Text = res end
            log("已选择输出文件夹: " .. res)
        else
            log("未选择输出文件夹")
        end
    end

    -- 刷新轨道列表
    w.On.RefreshTracksButton.Clicked = function()
        self:RefreshTrackList()
    end

    -- 测试连接
    w.On.TestButton.Clicked = function()
        self:TestConnection()
    end

    -- 开始操作
    w.On.ProcessButton.Clicked = function()
        self:StartGPT()
    end
end

-- 刷新支持语言
function UIManager:RefreshSupportedLanguage()
    local combos = {findWidget(self.window, "PromptLangCombo"),findWidget(self.window, "OutputLangCombo")}
    for _, combo in ipairs(combos) do
        if not combo then return end
        -- 先清空现有选项
        if combo.Clear then pcall(function() combo:Clear() end) end

        -- 添加语言项
        for i = 0, #LanguageTextMap do
            combo:AddItem(LanguageTextMap[i])
        end
        -- 默认选择第一项
        if combo.CurrentIndex then combo.CurrentIndex = 0 end
    end
end



-- 刷新轨道列表
function UIManager:RefreshTrackList()
    local combo = findWidget(self.window, "TrackCombo")
    if not combo then return end
    local LogLabel = findWidget(self.window, "ProgressLabel")
    if not LogLabel then return end

    -- 先清空现有选项
    if combo.Clear then pcall(function() combo:Clear() end) end

    -- 添加默认项
    local proj, timeline = SafeGetProjectAndTimeline()
    local trackCount = 0

    if timeline then
        local ok, count = pcall(function() return timeline:GetTrackCount("audio") end)
        if ok and type(count) == "number" and count >= 1 then
            trackCount = count
            LogLabel.Text = "检测到音频轨数: " .. tostring(count)
            log("检测到音频轨数: " .. tostring(count))
        else
            trackCount = 1
            LogLabel.Text = "无法读取轨数，使用默认 1 轨"
            log("无法读取轨数，使用默认 1 轨")
        end
    else
        trackCount = 1
        LogLabel.Text = "未找到时间线，使用默认 1 轨"
        log("未找到时间线，使用默认 1 轨")
    end

    -- 添加轨道项
    for i = 1, trackCount do
        if combo.AddItem then pcall(function() combo:AddItem(tostring(i)) end) end
    end

    -- 默认选择第一项
    if combo.CurrentIndex then combo.CurrentIndex = 0 end
end



-- 加载配置
function UIManager:LoadConfig()
    local file = io.open(GetConfigPath(), "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        local itm = self.window:GetItems()
        -- 解析配置文件
        for line in content:gmatch("[^\r\n]+") do
            local key, value = line:match("(.+)=(.+)")
            if key and value then
                if key == "ServerUrlEdit" then
                    itm.ServerUrlEdit.Text = value
                elseif key == "GPTModelEdit" then
                    itm.GPTModelEdit.Text = value
                elseif key == "SoVITSModelEdit" then
                    itm.SoVITSModelEdit.Text = value
                elseif key == "PromptAudioEdit" then
                    itm.PromptAudioEdit.Text = value
                elseif key == "PromptTextEdit" then
                    itm.PromptTextEdit.Text = value
                elseif key == "PromptLangCombo" then
                    for index, langValue in pairs(LanguageMap) do
                        if langValue == value then
                            itm.PromptLangCombo.CurrentIndex = index
                            break
                        end
                    end
                    
                elseif key == "OutputLangCombo" then
                    for index, langValue in pairs(LanguageMap) do
                        if langValue == value then
                            itm.OutputLangCombo.CurrentIndex = index
                            break
                        end
                    end
                elseif key == "OutputPathEdit" then
                    itm.OutputPathEdit.Text = value
                end
            end
        end
    end
end

-- 保存配置(使用文本格式)
function UIManager:SaveConfig()
    local itm = self.window:GetItems()
    local config = string.format(
        "ServerUrlEdit=%s\nGPTModelEdit=%s\nSoVITSModelEdit=%s\nPromptAudioEdit=%s\nPromptTextEdit=%s\nPromptLangCombo=%s\nOutputLangCombo=%s\nOutputPathEdit=%s",
        itm.ServerUrlEdit.Text,
        itm.GPTModelEdit.Text,
        itm.SoVITSModelEdit.Text,
        itm.PromptAudioEdit.Text,
        itm.PromptTextEdit.Text,
        LanguageMap[itm.PromptLangCombo.CurrentIndex],
        LanguageMap[itm.OutputLangCombo.CurrentIndex],
        itm.OutputPathEdit.Text
    )
    
    local file = io.open(GetConfigPath(), "w")
    if file then
        file:write(config)
        file:close()
    end
end

function UIManager:Show()
    if self.window then pcall(function() self.window:Show() end) end
end

function UIManager:Close()
    if self.window then pcall(function() self.window:Close() end) end
end

-- 清理函数
function Cleanup()
    if uiManager then
        uiManager:Close()
    end
end

-- 脚本结束时的清理
function OnExit()
    Cleanup()
end

-- 执行命令函数
local function ExecuteCommand(command)
    local path = os.getenv("PATH") or ""
    local newPath = "/usr/local/bin:/opt/homebrew/bin:" .. path
    local fullCommand = string.format('export PATH="%s" && %s', newPath, command)
    local handle = io.popen(fullCommand .. " 2>&1")
    local result = handle:read("*a")
    local success = handle:close()
    return success, result
end

-- URL 编码函数
local function URLEncode(str)
    if not str or str == "" then return str end
    
    local result = {}
    local i = 1
    local len = #str
    
    while i <= len do
        local char = string.sub(str, i, i)
        local byte = string.byte(char)
        
        -- 编码空格为 %20
        if char == " " then
            table.insert(result, "%20")
            i = i + 1
        -- 检测中文字符（UTF-8 3字节字符）
        elseif byte >= 0xE0 and byte <= 0xEF then
            -- 确保有足够的字节
            if i + 2 <= len then
                local b1, b2, b3 = string.byte(str, i, i + 2)
                -- 验证这是有效的UTF-8序列
                if b2 and b3 and b2 >= 0x80 and b2 <= 0xBF and b3 >= 0x80 and b3 <= 0xBF then
                    table.insert(result, string.format("%%%02X", b1))
                    table.insert(result, string.format("%%%02X", b2))
                    table.insert(result, string.format("%%%02X", b3))
                    i = i + 3
                else
                    -- 无效的UTF-8序列，按普通字符处理
                    table.insert(result, char)
                    i = i + 1
                end
            else
                -- 字节不足，按普通字符处理
                table.insert(result, char)
                i = i + 1
            end
        else
            -- 非中文字符直接保留
            table.insert(result, char)
            i = i + 1
        end
    end
    
    return table.concat(result)
end

local function TransitionPath(TargetPath)
    if not TargetPath then return "" end
    TargetPath = string.gsub(TargetPath, "\\", "/")
    return TargetPath
end

-- 基本JSON转义
local function escapeJson(str)
    if not str then return "" end
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, "\"", "\\\"")
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\t", "\\t")
    return str
end

-- 创建临时 JSON 文件
local function WriteTempJson(jsonStr, tempFilePath)
    local file = io.open(tempFilePath, "w")
    if not file then
        print("[GPTSoVTTS] 无法创建临时文件: " .. tempFilePath)
        return false
    end
    file:write(jsonStr)
    file:close()
    return true
end


-- 调用 GPT-SoVITS 合成语音
-- params:
--   baseUrl      : 服务地址，例如 "http://127.0.0.1:9880"
--   text         : 要合成的文本
--   textLang     : 文本语言
--   refAudioPath : 提示语音文件路径
--   promptText   : 提示文本
--   promptLang   : 提示文本语言
--   outPath      : 输出 wav 文件路径
local function SynthesizeSpeech(baseUrl, text, textLang, refAudioPath, promptText, promptLang, outPath)
    -- 参数校验
    if not baseUrl or baseUrl == "" then
        log("错误：未提供服务地址")
        return false
    end
    if not refAudioPath or refAudioPath == "" then
        log("错误：必须提供参考音频路径")
        return false
    end
    if not outPath or outPath == "" then
        log("错误：未提供输出路径")
        return false
    end

    -- 移除 baseUrl 末尾的斜杠
    baseUrl = string.gsub(baseUrl, "/+$", "")

    -- 默认值
    if not text or text == "" then text = "测试语音" end
    if not textLang or textLang == "" then textLang = "zh" end
    if not promptText then promptText = "" end
    if not promptLang or promptLang == "" then promptLang = "zh" end

    -- 构造 JSON 数据
    local jsonData = string.format([[
    {
        "text":"%s",
        "text_lang":"%s",
        "ref_audio_path":"%s",
        "prompt_text":"%s",
        "prompt_lang":"%s",
        "text_split_method":"cut0",
        "speed_factor":1.0,
        "top_k": 5,
        "top_p": 1,
        "temperature": 1,
        "seed": -1
    }]], escapeJson(text), textLang, TransitionPath(refAudioPath), escapeJson(promptText), promptLang)
    -- 临时路径
    local tmpDir = GetTempPath()
    os.execute('mkdir "' .. tmpDir .. '" 2>nul')  -- Windows 下创建文件夹，Linux 下会忽略

    local tmpJson = tmpDir  .. os.time() .. ".json"
    --tmpOut = outPath
    -- 写 JSON 到临时文件
    local f = io.open(tmpJson, "w")
    if not f then
        log("错误:无法创建临时JSON文件: ", tmpJson)
        return false
    end
    f:write(jsonData)
    f:close()

    -- 使用PowerShell执行curl命令(带URL编解码处理，单行格式)
    local curlCmd = [[[Console]::OutputEncoding = [System.Text.Encoding]::UTF8;Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force;Add-Type -AssemblyName System.Web 2>$null;$baseUrl = [System.Web.HttpUtility]::UrlDecode(']]..URLEncode(TransitionPath(baseUrl))..[[');$tmpJson = [System.Web.HttpUtility]::UrlDecode(']]..URLEncode(TransitionPath(tmpJson))..[[');$tmpOut = [System.Web.HttpUtility]::UrlDecode(']]..URLEncode(TransitionPath(outPath))..[[');curl.exe -s -f -X POST "$baseUrl/tts" -H "Content-Type: application/json" --data-binary "@$tmpJson" -o "$tmpOut"]]

    -- 使用PowerShell执行curl命令
    local handle = io.popen('powershell -Command "' .. curlCmd .. '"')
    if not handle then
        log("错误：无法执行PowerShell")
        os.remove(tmpJson)
        return false
    end
    local result = handle:read("*a")
    local success = handle:close()

    -- 清理临时文件
    os.remove(tmpJson)

    log("语音合成成功:", outPath)
    return true
end


-- 检查时间线上是否有指定名称的音频（允许帧数偏差）
-- params:
--   timeline : 时间线对象
--   trackIndex : 音频轨道索引
--   startFrame : 开始帧位置
--   fileName : 要检查的文件名
--   frameTolerance : 帧数容差（默认10帧）
local function CheckAudioExistsOnTimeline(timeline, trackIndex, startFrame, fileName, frameTolerance)
    if not timeline then return false end
    frameTolerance = frameTolerance or 10  -- 默认10帧容差
    
    -- 获取音频轨道上的所有项
    local ok, audioItems = pcall(function() return timeline:GetItemListInTrack("audio", trackIndex) end)
    if not ok or not audioItems then return false end
    
    -- 检查每个音频项
    for _, audioItem in ipairs(audioItems) do
        -- 获取音频项的开始帧和名称
        local audioStartFrame = audioItem:GetStart()
        local audioName = audioItem:GetName()
        
        -- 检查是否在容差范围内且有相同名称
        if audioName == fileName and math.abs(audioStartFrame - startFrame) <= frameTolerance then
            log("时间线上已存在音频: " .. fileName .. " 在帧 " .. audioStartFrame .. " (容差: " .. frameTolerance .. "帧)")
            return true
        end
    end
    
    return false
end

-- 设置 GPT 与 SoVITS 模型
-- params:
--   baseUrl : 服务地址，默认是 "http://127.0.0.1:9880"
--   gptPath : GPT 模型权重路径
--   sovitsPath : SoVITS 模型权重路径
local function SetModels(baseUrl, gptPath, sovitsPath)
    if not baseUrl or baseUrl == "" then
        log("未提供服务地址")
        return false
    end

    -- 设置 GPT 模型
    if gptPath and gptPath ~= "" then
        NewGPTPath = TransitionPath(gptPath)
        local gptCmd = string.format('curl -s "%s/set_gpt_weights?weights_path=%s"', baseUrl, NewGPTPath)
        gptCmd = URLEncode(gptCmd)
        log("设置 GPT 模型: " .. NewGPTPath)
        local ok, handle = pcall(io.popen, gptCmd)
        if ok and handle then
            local result = handle:read("*a")
            handle:close()
            log("服务器 返回: " .. result)
        else
            log("设置 GPT 模型失败")
            return false
        end
    end

    -- 设置 SoVITS 模型
    if sovitsPath and sovitsPath ~= "" then
        NewSovPath = TransitionPath(sovitsPath)
        local sovitsCmd = string.format('curl -s "%s/set_sovits_weights?weights_path=%s"', baseUrl, NewSovPath)
        sovitsCmd = URLEncode(sovitsCmd)
        --log("设置 SoVITS 模型: " .. NewSovPath)
        local ok, handle = pcall(io.popen, sovitsCmd)
        if ok and handle then
            local result = handle:read("*a")
            handle:close()
            log("服务器 返回: " .. result)
        else
            log("设置 SoVITS 模型失败")
            return false
        end
    end

    log("模型设置完成")
    return true
end


-- 开始语音合成
function UIManager:StartGPT()
    local itm = self.window:GetItems()
    itm.ProgressLabel.Text = "正在设置模型"
    local RequestURL = itm.ServerUrlEdit.Text
    SetModels(RequestURL,itm.GPTModelEdit.Text,itm.SoVITSModelEdit.Text)
    itm.ProgressLabel.Text = "正在读取字幕文件"
    -- 获取当前项目和当前时间线
    local resolve = Resolve()
    local projectManager = resolve:GetProjectManager()
    local project = projectManager:GetCurrentProject()
    local mediaPool = project:GetMediaPool()
    local timeline = project:GetCurrentTimeline()

    -- 获取字幕轨道数量
    local subtitleTrackCount = timeline:GetTrackCount("subtitle")

    -- 辅助函数：将帧数转换为时间码
    local function frames_to_timecode(frames, fps)
        local h = math.floor(frames / (fps*3600))
        local m = math.floor(frames / (fps*60) % 60)
        local s = math.floor(frames / fps % 60)
        local f = math.floor(frames % fps)
        return string.format("%02d:%02d:%02d:%02d", h, m, s, f)
    end
    local fps = timeline:GetSetting("timelineFrameRate")
    
    -- 查找或创建 GPTSoVTTS 文件夹（只在循环外部创建一次）
    local gptFolder = nil
    local rootFolder = mediaPool:GetRootFolder()

    -- 设置目标语言
    local ItmList = self.window:GetItems()
    local text_lang = LanguageMap[itm.OutputLangCombo.CurrentIndex]
    local prompt_lang = LanguageMap[itm.PromptLangCombo.CurrentIndex]
    
    -- 首先检查GPTSoVTTS文件夹是否存在
    local subfolders = rootFolder:GetSubFolderList()
    for _, folder in ipairs(subfolders) do
        if folder:GetName() == "GPTSoVTTS" then
            gptFolder = folder
            log("找到现有的 GPTSoVTTS 文件夹")
            break
        end
    end
    
    -- 如果不存在，则使用 mediaPool:AddSubFolder 创建文件夹
    if not gptFolder then
        log("正在创建 GPTSoVTTS 文件夹...")
        
        -- 使用 mediaPool:AddSubFolder 方法创建文件夹
        local mpSuccess, mpResult = pcall(function() 
            return mediaPool:AddSubFolder(rootFolder, "GPTSoVTTS")
        end)
        
        if mpSuccess and mpResult then
            gptFolder = mpResult
            log("使用 mediaPool 成功创建 GPTSoVTTS 文件夹")
            
            -- 重新获取子文件夹列表以确认创建成功
            subfolders = rootFolder:GetSubFolderList()
            for _, folder in ipairs(subfolders) do
                if folder:GetName() == "GPTSoVTTS" then
                    gptFolder = folder
                    log("确认 GPTSoVTTS 文件夹已创建并可见")
                    break
                end
            end
            
            -- 如果仍然找不到，可能是API调用成功但文件夹未立即可见
            if not gptFolder then
                log("警告: API调用成功但文件夹未在列表中立即可见,使用返回的文件夹对象")
                gptFolder = mpResult
            end
        else
            log("创建 GPTSoVTTS 文件夹失败: " .. tostring(mpResult))
            -- 如果创建失败，使用根文件夹作为后备
            gptFolder = rootFolder
            log("将使用根文件夹作为后备")
        end
    end
    
    -- 确保设置当前文件夹到 GPTSoVTTS 文件夹
    local setFolderSuccess = pcall(function()
        mediaPool:SetCurrentFolder(gptFolder)
        log("已设置当前文件夹到: " .. gptFolder:GetName())
        
        -- 验证当前文件夹确实已设置
        local currentFolder = mediaPool:GetCurrentFolder()
        if currentFolder and currentFolder:GetName() == gptFolder:GetName() then
            log("成功验证当前文件夹: " .. currentFolder:GetName())
        else
            log("警告: 当前文件夹设置可能未生效")
        end
    end)
    
    if not setFolderSuccess then
        log("设置当前文件夹失败，将使用根文件夹")
        pcall(function() mediaPool:SetCurrentFolder(rootFolder) end)
        gptFolder = rootFolder
    end
    -- 遍历所有字幕轨道
    for TrackIndex = 1, subtitleTrackCount do
        -- 获取轨道上的所有字幕项
        local subtitleItems = timeline:GetItemListInTrack("subtitle", TrackIndex)
        -- 进度百分比
        local totalItems = #subtitleItems
        local processed = 0
        -- 遍历所有字幕项
        for _, item in ipairs(subtitleItems) do
            
            -- 获取信息
            local StartFrame = item:GetStart()
            local endFrame = item:GetEnd()
            local text = item:GetName()
            local FileName = text .. "_" .. prompt_lang .. ".wav"
            local audio_file = itm.OutputPathEdit.Text .. FileName
            -- 计算进度百分比，并限制为1位小数
            local progressPercent = string.format("%.1f", (processed or 0) / (totalItems or 1) * 100)

            -- 获取目标音频轨道
            local targetTrack = 1  -- 默认第一轨
            local trackCombo = findWidget(self.window, "TrackCombo")
            if trackCombo and trackCombo.CurrentIndex >= 0 then
                targetTrack = trackCombo.CurrentIndex + 1  -- 轨道从1开始
            end
            
            -- 首先检查时间线上是否已经有相同名称的音频
            local timelineAudioExists = CheckAudioExistsOnTimeline(timeline, targetTrack, StartFrame, FileName, 10)
            
            -- 如果时间线上已有音频，跳过处理
            if timelineAudioExists then
                log("时间线上已存在音频 ", FileName, ",跳过字幕: ", text)
                processed = processed + 1
                itm.ProgressLabel.Text = "已生成" .. progressPercent .. "%,时间线音频已存在，跳过:" .. text
                goto continue  -- 跳过这个字幕项的处理
            end
            
            -- 检查音频文件是否已存在  使用 达芬奇 接口尝试导入
            local fileExists = false
            local audio_clips = mediaPool:ImportMedia({audio_file})
            if audio_clips and #audio_clips > 0 then
                fileExists = true
                log("音频文件已存在，跳过合成: " .. audio_file)
                -- 清理导入的媒体项，因为我们只是检查文件是否存在
                for _, clip in ipairs(audio_clips) do
                    pcall(function() mediaPool:DeleteClips({clip}) end)
                end
            end
            
            -- 打印字幕信息
            
            log(string.format("字幕轨道 %d: 开始帧 %d, 结束帧 %d, 内容: %s", TrackIndex, StartFrame, endFrame, text))
            
            local success = false
            -- 如果文件不存在，才进行语音合成
            if not fileExists then
                itm.ProgressLabel.Text = "已生成" .. progressPercent .. "%,当前正在合成:" .. text
                success = SynthesizeSpeech(
                    RequestURL,
                    text,
                    text_lang,
                    itm.PromptAudioEdit.Text,
                    itm.PromptTextEdit.Text,
                    prompt_lang,
                    audio_file
                )
            else
                success = true
                itm.ProgressLabel.Text = "已生成" .. progressPercent .. "%,文件已存在，跳过合成:" .. text
            end
            processed = processed + 1
            if success then
                -- 跳转到GPTSoVTTS文件夹
                mediaPool:SetCurrentFolder(gptFolder)
                -- 导入媒体文件到指定文件夹
                local audio_clips = mediaPool:ImportMedia({audio_file})
                
                if audio_clips and #audio_clips > 0 then
                    local audio_clip = audio_clips[1]
                    
                    -- 获取音频时长信息
                    local clip_props = audio_clip:GetClipProperty()
                    local duration = tonumber(clip_props["Duration"]) or 3.0
                    
                    -- 使用 AppendToTimeline 方法精确插入音频到时间线
                    -- 创建子剪辑配置，精确对齐字幕开始时间
                    local subClip = {
                        mediaPoolItem = audio_clip,
                        startFrame = 0,  -- 从音频开头开始
                        endFrame = -1,   -- 到音频结尾
                        recordFrame = StartFrame,  -- 在时间线上的开始帧（字幕开始位置）
                        trackIndex = targetTrack  -- 目标音频轨道
                        --mediaType = 2  -- 音频类型
                    }
                    -- 插入到时间线
                    local success = mediaPool:AppendToTimeline({subClip})
                    if success then
                        log("音频成功插入到时间线轨道 ", targetTrack, ": ", audio_file)
                        log("音频开始帧: ", StartFrame)
                    else
                        log("音频插入失败: ", audio_file)
                    end
                else
                    log("音频文件导入失败: ", audio_file)
                end
            else
                log("处理失败: ", text)
            end
            ::continue::
        end
    end
    itm.ProgressLabel.Text = "就绪！"
end


-- 测试连接功能
function UIManager:TestConnection()
    local w = self.window
    if not w then
        log("无法获取窗口")
        return false
    end

    -- 获取日志标签
    local LogLabel = findWidget(self.window, "ProgressLabel")
    if not LogLabel then return end
    LogLabel.Text = "准备进行连通性测试"

    -- 获取用户输入的服务地址
    local serverEdit = findWidget(w, "ServerUrlEdit")
    if not serverEdit or serverEdit.Text == "" then
        log("未输入服务地址")
        LogLabel.Text = "未输入服务地址"
        return false
    end
    local url = serverEdit.Text

    -- 使用 curl 获取 HTTP 状态码和响应内容
    local cmd = string.format('curl -s -w "%%{http_code}" "%s"', url)
    local ok, handle = pcall(io.popen, cmd)
    if not ok or not handle then
        log("测试连接失败: 无法执行命令")
        LogLabel.Text = "测试连接失败: 无法执行命令"
        return false
    end
    LogLabel.Text = "正在进行连通性测试"
    
    local output = handle:read("*a")
    handle:close()

    -- 分离响应体和 HTTP 状态码
    local body = output:sub(1, -4)
    local code = output:sub(-3)

    if code == "000" then
        LogLabel.Text = "测试连接失败"
        log("测试连接失败")
        return false
    else
        LogLabel.Text = "测试连接成功"
        log("测试连接成功")
        return true
    end
end


-- Main 函数 - 插件主入口点
local function main()
    log("GPTSoVTTS 插件启动")
    -- 创建并初始化UI管理器
    local uiManager = UIManager:new()
    if not uiManager:Init() then
        log("UI初始化失败")
        return false
    end
    -- 显示窗口
    uiManager:Show()
    -- 刷新支持的语言列表
    uiManager:RefreshSupportedLanguage()
    -- 加载配置
    uiManager:LoadConfig()
    -- 运行事件循环
    dispatcher:RunLoop()
    log("插件窗口已退出")
    return true
end

-- 程序主入口
main()
