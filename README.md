
# 达芬奇 与 GPT-SoVITS Bridge

这是一个Lua脚本, 它可以读取时间线上的字幕并自动提交GPT-SoVITS进行语音合成



## 如何使用

发布在Bilibili的教学[**视频**](https://www.bilibili.com/video/BV1eSYFzREEe/)

将`GPTSoV.lua`复制到如下目录中(也可以创建一个GPTSoVTTS文件夹然后再放进去)

```
%AppData%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility
```

随后打开达芬奇，你就可以在`工作区->脚本->GPTSoVTTS`中看到GPTSoVTTS选项

启动后会跳出UI界面，便可使用脚本功能



## 如何连接GPT-SoVITS

首先你需要安装GPT-SoVITS项目：[**项目地址**](https://github.com/RVC-Boss/GPT-SoVITS/)

为了能调用API，我们需要启动GPT-SoVITS项目中的api_v2.py文件

如果你不会运行，请将Tool文件夹下的`Go_API_V2.bat`文件复制到GPT-SoVITS的根目录下启动

等待加载完成，在脚本中即可通过连通性测试



## 注意事项:

脚本会通过Lua调用PowerShell来执行Curl命令，所以请保证PowerShell的执行命令不会被杀毒软件拦截

已测试能够正常运行的达芬奇版本:DaVinci Resolve Studio 20



## Todo List

- [ ] **添加对英文的支持**

- [x] **添加关键字替换功能**
  - [ ] 为此功能添加UI

- [ ] **添加语速控制**

- [ ] **添加多角色模式**




##### 由于个人开发，脚本功能可能不够丰富，需要的话也可以自行拓展功能！