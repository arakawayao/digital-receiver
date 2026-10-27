# Windows 独立版验证记录

## 2026-10-27 图标更新

新版发布目录：`.harness/releases/20261027_153028`，压缩包 `ADS807Host-Windows-x64.zip`。
SHA256：`c014e8ca34096467a6dcfcfd205033ec291d86518c34252e611410394ad80025`。
替换窗口、应用及 EXE 图标为接收机频谱/波形图标，提供 16–256 像素多尺寸 ICO；
17 项 GUI 测试通过，冻结 EXE 的合成场景与原生/托管组件自检通过，已提取并查看 EXE 图标。
使用新版压缩包启动，已有运行中的旧版本不会自动替换。未做本轮真实 USB/物理放音测试。

以下为首版独立软件的验证记录。

日期：2026-10-27。发布构建：`.harness/releases/20261027_132019`。

## 交付

- 程序：`ADS807Host/ADS807Host.exe`，目录便携版，保留 `_internal`。
- 压缩包：`ADS807Host-Windows-x64.zip`，95,514,255 字节。
- SHA256：`2658b36d82142eb55b8af4a7a98e53a880915c68770437c6da5632556a5ff116`。
- 附带使用说明、双击启动脚本、依赖许可证、源码 ZIP 和文件构建清单。

## 已验证

- `python -B -m pytest tests -q -p no:cacheprovider --basetemp .harness/pytest_portable --junitxml .harness/portable_tests.xml`：184 项通过。
- `python -B tools/build_windows.py`：构建及自检通过。
- 直接启动冻结 EXE，清除 Python/Conda/Qt 环境变量，PATH 仅保留 Windows 系统目录：通过。
- 随包 PortAudio、本机 .NET Framework、pythonnet、CyUSB 和异步接收组件加载：通过；
  USB 组件先核对 C# 源、SDK DLL、程序集 SHA256，不创建 USB 设备对象。
- 合成 AM/FM/无信号/噪声和强制 FM 共 5 场景、深浅主题、解调/FFT/IQ 截图、波形保存：通过。
- ZIP CRC 检查及解压至“迁移测试 含空格”，屏蔽已安装 SDK 目录后再次自检：通过；
  `sys.path` 不含 Conda 路径，SDK 和异步组件从迁移后的 `_internal` 加载。
- 常规入口 `--offscreen --demo FM --quit-after 6`：正常退出，生成截图和健康报告；
  此短测 CRC、帧头、连续性、主机丢弃和 DSP 丢样计数均为零，物理音频未启用。
- 已查看冻结 EXE 的深浅主题及普通启动截图，文字、坐标轴和波形正常。

证据在发布目录 `verification/portable_result.json`、`verification/gui/result.json`、
`迁移测试 含空格/验证报告/portable_result.json`、`normal_startup.png` 和 `normal_startup_health.json`。

## 边界

这是当前 Windows x64 开发机上的冻结程序及迁移验证，未在另一台纯净电脑实测。
新电脑需要 Cypress USB 驱动及 .NET Framework 4.x；包不安装驱动，不烧录板卡。
本轮未验证冻结程序的真实 USB 持续吞吐、射频接收或物理扬声器输出。
早期失败的构建目录保留为诊断产物，交付使用上述最终构建和 ZIP。
