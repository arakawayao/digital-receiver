# ADS807 上位机工程

本目录可以独立复制交付，应用、协议、测试、依赖和交接资料均在目录内。
实时USB对应EP4CE6两模式TCM1 v2 / TRI1 v1；支持FPGA自动估频和手动载频。
GUI的USB采集默认异步接收，首次使用先从本目录运行 `python -B -m ads807.build_usb_pump`。
本轮修改、离线证据和实测边界见 [USB接收修正](docs/USB_STABILITY.md)。

先阅读 [交接与对齐说明](HANDOFF.md)、[应用说明](ads807/README.md) 和
[接口协议](docs/PROTOCOL.md)。已有验证与限制见 [VALIDATION.md](ads807/VALIDATION.md)。

## 启动

Windows 便携独立版的使用、驱动要求、自检及重建见 [独立软件说明](docs/PORTABLE.md)。
独立版解压后双击 `ADS807Host.exe`，无需 Python/Conda；需一并保留 `_internal` 文件夹。
2026-10-27 的发布包和测试边界见 [独立版验证记录](docs/PORTABLE_VALIDATION.md)。

最简单的方式是双击本目录的 `start_host.bat`。脚本会自动切换到本目录，并固定使用
`D:\conda_envs\ads807_host\python.exe`，因此不要求先激活 Conda 环境。

也可以在 PowerShell 中执行：

```powershell
& 'D:\class_project\main_project\host\start_host.bat'
```

脚本支持继续传递启动参数，例如：

```powershell
& 'D:\class_project\main_project\host\start_host.bat' --demo AM
& 'D:\class_project\main_project\host\start_host.bat' --demo AM --preview
```

在PowerShell中执行（环境已创建时跳过第一条）：

```powershell
conda create --prefix "D:\conda_envs\ads807_host" python=3.11 pip -y
conda activate "D:\conda_envs\ads807_host"
Set-Location "D:\class_project\main_project\host"
python -m pip install -r requirements.txt
python -m pip check
python -B -m ads807
```

不激活环境也可从任意目录执行：

```powershell
& 'D:\conda_envs\ads807_host\python.exe' -B 'D:\class_project\main_project\host\run.py' --demo AM --preview
```

预览地址由控制台打印，默认 http://127.0.0.1:8767。它显示真实Qt界面。
普通启动不连接USB、不开启扬声器、不烧录FPGA。环境路径可自行修改，`run.ps1` 默认使用当前环境的python，
也可用 `-Python <解释器路径>` 指定；`ads807/run.ps1` 保留为兼容转发。
若本机 PowerShell 策略禁止运行 `.ps1`，直接使用上面的 `run.py` 命令，无需修改系统策略。

## 目录

```text
host/
  run.py / run.ps1       启动入口
  requirements.txt      依赖入口
  ads807/               PyQt6应用
    interfaces/         当前共享协议与IQ质量判定
    legacy/             旧固件的上位机工具
  tests/                当前及历史回放测试
  docs/                 独立接口与FPGA联调说明
  firmware/             FPGA同学提供的SOF和清单，非Python依赖
  evidence/             交接所需历史结果摘要
  captures/             默认手动保存目录（运行时创建）
  .harness/             测试、镜像及构建产物，可再生成
  HANDOFF.md            待对齐清单与接手顺序
```

Conda环境、系统驱动、CyUSB SDK及Quartus需另行安装，不属于源码包。
`.harness` 中历史软件产物约1.35GB，可在交付源码时排除；`evidence` 保留关键摘要，
其中可能记录旧机器绝对路径，只作为证据，不作运行配置。

## 菜单与面板

顶部菜单为“文件、视图、采集、分析、音频、记录”。“视图”按采集设置、分析校验、
日志记录分组，分别勾选连接、调谐、显示与 FFT、音频、识别、调谐状态、测量、完整性、
日志及记录面板；工具栏和状态栏可单独隐藏。波形窗口始终保留，可切换解调、FFT 和原始 I/Q。
同侧面板全部隐藏后释放空间；隐藏只改变显示，采集、校验和音频的运行状态由相应控制决定。
支持“显示全部面板”“仅显示波形”（保留当前工具栏和状态栏）及“恢复默认布局”。

采集、分析和音频菜单提供参数弹窗，侧栏各设置组的配置按钮打开同一弹窗。
“确定”应用设置，“取消”保留原值；运行中的连接、调谐和回放选择锁定。
音频菜单与侧栏共用扬声器状态，错误后的实际状态由控制器回传。
默认输出优先使用与系统默认设备同名的 Windows WASAPI（支持 48 kHz 时），
避免 MME 成批回调造成长时间欠载/溢出；明确选择的设备不自动替换。
日志和保存记录包含实际 Host API、设备延迟、动态缓冲及回调诊断。
记录菜单提供目录选择、刷新和查找；目录用于测量记录查询及后续保存的默认位置。
布局目前只在本次运行中维护，重启恢复默认布局。

“视图 → 主题”提供“浅色”（白天）和“深色”（夜间）切换，默认深色。
菜单、参数弹窗、日志和波形区域同步配色；浅色主题使用深色曲线以保持对比度。
运行中可切换，保留当前波形、缩放范围、冻结显示和采集状态；重启后恢复深色。

“分析 → 解调模式”提供“自动识别 / 强制 AM / 强制 FM”，也可在右侧“调制识别”面板
或“分析 → 解调参数…”弹窗设置，支持运行中切换。默认自动识别。
强制模式按指定方式解调有效 I/Q，不因低信号质量、未知调制或削顶标志而静音；
自动识别结果、评分和削顶等校验提示仍保留，不把强制模式当成识别成功。
切换模式清除旧解调缓存并重新预热；断流、无有效连续数据或协议错误仍按原有流程处理。
保存的 metadata.json 用 demodulation 字段记录模式、实际解调类型和 forced 标志；
测量记录显示自动结果及强制模式。软件重启恢复自动，停止后再开始保留本次选择。
弱信号或空频道可能输出噪声，强制解调不保证能恢复节目。接收已知 FM 广播可选“强制 FM”。

本次界面更新的软件测试、合成验证和限制见 [界面验证记录](docs/UI_MENUS.md)。
持续镜像中已观察到队列溢出，详见该记录；短时测试通过不代表持续吞吐验收。

## 离线验证

从本目录执行，无USB、不烧录、不输出物理音频：

```powershell
python -B -m pytest tests -q -p no:cacheprovider --basetemp .harness/pytest --junitxml .harness/tests.xml
python -B -m ads807.verify
```

输出均在本目录内。复制到其他路径也使用同样命令；不需要外层FPGA源码或项目harness。
根项目旧 `python -m host.ads807` 和FPGA旧Python路径保留兼容，所有实际实现只维护在本目录。
