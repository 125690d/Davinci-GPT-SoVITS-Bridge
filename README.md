
# 达芬奇 与 GPT-SoVITS Bridge
这是一个Lua脚本, 它可以读取时间线上的字幕并自动提交GPT-SoVITS进行语音合成

## 如何使用
将`GPTSoV.lua`复制到如下目录中(也可以创建一个GPTSoVTTS文件夹然后再放进去)
```
%AppData%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility
```
随后打开达芬奇，你就可以在`工作区->脚本->GPTSoVTTS`中看到GPTSoVTTS选项

启动后会跳出UI界面，便可使用脚本功能

## 如何连接GPT-SoVITS
首先你需要安装GPT-SoVITS项目：[**项目地址**](https://github.com/RVC-Boss/GPT-SoVITS/)

为了能调用API，我们需要启动项目中的api_v2.py文件，等待加载完成，在脚本中即可通过连通性测试

### 注意事项:
脚本会通过Lua调用PowerShell来执行Curl命令，所以请保证PowerShell的执行命令不会被杀毒软件拦截


##### 由于个人开发，脚本功能可能不够丰富，需要的话也可以自行拓展功能！
