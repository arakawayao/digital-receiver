# ADS807 Windows 独立版

## 使用

1. 将整个 ZIP 解压至有写入权限的目录，例如 `D:\ADS807Host`。
2. 双击 `ADS807Host.exe` 或 `启动 ADS807.bat`。必须保留同目录 `_internal`，不能只复制 EXE。
3. 默认启动不连接 USB，不开启扬声器，也不下载 FPGA 固件。
4. 连接板卡后，选 USB、确认自动/手动载频并点击“开始”；音频输出需单独勾选。

无需安装 Python 或 Conda。当前提供 Windows x64 便携目录版，包含 Python、Qt、
NumPy、SciPy、PortAudio、pythonnet、CyUSB.dll 和匹配的 USB 异步接收组件。
新电脑仍需安装官方 Cypress USB 驱动，以及 .NET Framework 4.x（建议 4.8）；
程序不安装驱动、不改变 FX2 固件和 FPGA SOF。SDK 编译器与 Quartus 不属于运行依赖。
已有驱动的本机可以直接使用；其他 Windows 电脑仍需实测驱动及音频兼容性。

## 功能与文件

- AM/FM 自动识别、强制解调、FFT、原始 I/Q、实时放音、去加重与记录沿用现有上位机。
- “视图 → 主题”切换浅色/深色，默认深色。
- 默认波形保存到 EXE 同目录 `captures`；记录菜单可以切换保存目录。
- 诊断日志在 `logs/application.log`；不建议放在需要管理员写入权限的 Program Files。
- Python 及第三方组件版本、文件 SHA256 见 `build_manifest.json`；许可证见 `licenses`。
- `source.zip` 保留本次应用及打包脚本源码，便于交接和重建；不包含采集历史、驱动、FPGA 固件。

USB DLL 默认优先使用程序附带的版本。若手动选择其他 CyUSB.dll，异步组件的哈希校验
可能拒绝不同 SDK 版本；需用该 SDK 重新构建独立版，不能随意替换 DLL。

## 软件自检

PowerShell 中执行（示例路径按实际位置修改）：

```powershell
& 'D:\ADS807Host\ADS807Host.exe' --self-test 'D:\ADS807Host\self_test'
```

等待进程退出后查看 `self_test/portable_result.json`，成功为 `PASS`。
自检验证随包 .NET/USB 组件加载、PortAudio 加载、合成 AM/FM/无信号/噪声及强制 FM、
主题切换、波形保存和 GUI 截图；不打开 USB 设备、不播放物理音频。
此结果不能代替板卡持续接收、真实射频和扬声器实测。

## 从源码重建

在 `host` 目录和现有 64 位 Python 3.11 环境下执行：

```powershell
python -B -m pip install -r requirements.txt
python -B -m pip install --target .harness/build_tools -r tools/requirements-build.txt
python -B tools/build_windows.py
```

构建需要本机官方 Cypress SDK 和 .NET Framework C# 编译器；
可通过 `--sdk-dll '其他路径\CyUSB.dll'` 指定 SDK。
构建脚本在 `.harness/releases/时间戳` 生成目录、ZIP、校验文件和验证报告，
每次使用新目录，不覆盖现有发布或用户波形。
