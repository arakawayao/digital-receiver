# 上位机交接与接口对齐说明

2026-10-23 USB接收修正：当前控制协议为TCM1 v2，主SOF已同步为10月22日官方CIC构建；
历史RAM测试SOF仍为v1。普通GUI改为异步接收，ACK独立于DSP分发，停止时保留接收至STOP确认。
首次USB采集前运行 `python -B -m ads807.build_usb_pump`；详细修改和验证见
[USB接收修正](docs/USB_STABILITY.md)。本次未下载固件或进行真实USB/ADC/音频复测。

2026-10-21 界面增量：顶部菜单及功能面板显隐已按确认预览实现，参数支持确认/取消弹窗。
使用方法见 [README](README.md#菜单与面板)，验证范围及证据见 [菜单验证](docs/UI_MENUS.md)。
本轮 110 项软件测试和 4 种合成场景通过；未新增真实 USB、射频或物理音频验收结论。

整理日期：2026-10-20。对象：接手上位机的同学、FPGA 同学及系统集成人员。
本文根据现有源码、协议、验证文档和结果文件整理。后续按交付要求将上位机工程独立收拢到host；
迁移验证另见 `docs/MIGRATION.md`。本次迁移未连接USB、下载SOF或播放物理音频；未初始化Git仓库。

## 1. 先确定接手的是哪个版本

| 项目 | 当前基线 |
| --- | --- |
| 上位机 | 本目录 `ads807/`，Python 3.11、PyQt6；模块入口 `ads807`（从host目录运行） |
| 实时 FPGA 工程 | `main_project/fpga/receiver_ads807_dual/receiver_ads807_dual.qpf` |
| 实际 FPGA | EP4CE6F17C8，已由用户确认；不能照搬旧 EP4CE10 资源预算 |
| 当前调谐 | MODE=1 FPGA 自动估频（默认）；MODE=2 手动载频 |
| 当前 USB 协议 | 下行 TCM1，上行 TRI1；双向 Bulk |
| 历史兼容 | FCR1 v2 合成源/文件回放，历史 TRI1 文件回放；不启用旧主机搜索 |

2026-10-26：确认停止后改频重新开始时使用 MODE=1。候选 RTL 已修复 AM 过零门限及
STOP 期间旧估频状态清理；host 固件目录同步了候选 SOF，SHA256 见
`firmware/receiver_ads807_dual/manifest.json`。ModelSim AM 重启矩阵、Quartus map/fit/STA
和 assembler 已通过，JTAG 未枚举，交付前必须完成实板烧录复测。

**MODE=0、SNAPSHOT 和 TRACK 已撤销。** 不要按历史三模式文档重新编号或恢复自动搜索。
根 README 和工作计划包含大量历史条目，当前接口以
[两模式联调说明](docs/FPGA_INTEGRATION.md)、
[协议](docs/PROTOCOL.md) 与实际源码为准。
文档或 SOF 与源码不一致时，记录差异并由 FPGA/HOST/集成人员共同确认。

## 2. 交付整个 host 目录即可

当前应用、共享协议、历史上位机工具、测试、依赖与必要联调资料已集中到本目录。
复制整个 `host` 并保留内部结构即可；不再需要复制外层 `main_project`、`tests` 或 `harness`。
目录与命令见 [README.md](README.md)。软件协议的唯一实现现为
[interfaces/protocol.py](ads807/interfaces/protocol.py)；FPGA旧路径只做转发，避免两份代码漂移。
历史工具在 `ads807/legacy/`，测试在 `tests/`，历史软件产物在 `.harness/ads807_host/`。

`docs/` 提供本地协议和联调说明，`evidence/` 提供关键历史结果摘要；`firmware/` 用于
接收FPGA负责人交付的固件与清单。完整可重建FPGA工程由FPGA同学维护，不是Python运行依赖。
Conda环境、系统驱动、CyUSB SDK和Quartus仍需本机安装。交付源码可排除可再生成的
`.harness`、`__pycache__`，并按约定选择是否附带原始捕获和固件。

## 3. 环境与启动

原开发机解释器：`D:\conda_envs\ads807_host\python.exe`，Windows x64 / Python 3.11。
新机器可以使用其他固定路径。以下命令从收到的host目录执行：

```powershell
conda create --prefix "D:\conda_envs\ads807_host" python=3.11 pip -y
conda activate "D:\conda_envs\ads807_host"
python -m pip install -r requirements.txt
python -m pip check
python -c "import sys; print(sys.executable)"
python -B -m ads807 --demo AM --preview
```

已存在环境时跳过创建。依赖用途如下，锁定版本见
[requirements.txt](ads807/requirements.txt)：

| 依赖 | 版本 | 用途 |
| --- | --- | --- |
| PyQt6 / pyqtgraph | 6.7.1 / 0.13.7 | 桌面控件、交互绘图 |
| NumPy / SciPy | 1.26.4 / 1.13.1 | IQ、FFT、滤波、重采样和参数估计 |
| sounddevice | 0.5.1 | PortAudio 扬声器输出 |
| pythonnet | 3.0.5 | Windows 官方 CyUSB .NET 接口；USB 还需本机驱动/SDK |
| pytest / pytest-qt | 8.3.5 / 4.4.0 | 软件及 Qt 回归 |

不需要 PyTorch。`run.ps1` 默认使用当前环境的Python，也可通过 `-Python` 显式指定解释器；
`run.py` 支持从任意工作目录启动。程序启动不自动连接 USB，音频默认关闭。

普通桌面启动为 `python -B -m ads807`。右侧镜像使用 `--preview`，控制台打印实际
loopback 地址，默认 `http://127.0.0.1:8767`，占用时顺延端口；浏览器打开该地址即可。
镜像来自实际 Qt 窗口，完整交互仍在桌面；仅观察时可追加 `--offscreen`。
持续 USB 吞吐验收应关闭镜像，避免截图干扰。

首次接手先运行不涉及硬件的检查：

```powershell
python -B -m pytest tests -q -p no:cacheprovider --basetemp .harness/ads807_host/handoff_pytest
python -B -m ads807.verify --output .harness/ads807_host/handoff_verification
```

第二条默认无 USB、无物理音频，验证 AM/FM/静默/噪声并生成实际 Qt 截图。
若在外层完整项目中，也可从外层根目录运行
`python -B -m harness.runner run --jobs 3 --task ads807-host-offline-verification`。
它已依赖 `ads807-host-tests`，无需同时另开一轮相同测试；`tasks.proposal.json` 为保留清单，
当前任务已注册到共享 harness。测试历史通过数量不是新机器应固定得到的数量，新增测试以后以实际报告为准。

## 4. FPGA/HOST 必须共同冻结的接口

### 4.1 信号与频率含义

| 参数 | 当前实现约定 | 需要共同确认的内容 |
| --- | --- | --- |
| 射频输入 | 单个预选的 88–108 MHz AM/FM 信号 | 前端预选、幅度和有效边带，不能据此宣称同时采集 20 MHz |
| ADC | ADS807E，12 位 offset binary；参考 24 MHz，PLL ×29/÷16，43,500,000 Hz | 实际采样时钟、码型、VDRV、电气连接及板级采样时序 |
| 频率映射 | 正 alias，RF=87 MHz+alias；目标 alias 为 1–21 MHz | 模拟带宽、抗混叠和镜像抑制；不能把任意 alias 唯一解释为 RF |
| 混频 | I=x*cos，Q=-x*sin；主机 I+jQ，不共轭 | 通过已知正/负频偏样本确认方向 |
| 抽取/滤波 | 五级 CIC /87，SHIFT=40，再 FIR；输出 500,000 对 IQ/s | 修改任一采样率、增益或抽取配置时同步修改两端及参考测试 |
| IQ 排列 | signed16 小端，I 后 Q；主机除 32768 | 数字归一化幅度与 dBFS 均未标定为电压/功率 |
| 音频 | 主机输出 48,000 Hz 单声道 | 放音设备、带宽、去加重和验收延迟 |

显示的载频估计为 `87 MHz + phase_step × 43.5 MHz / 2^32 + 基带残余频偏`。
TRI1 的 `tuned_rf` 是设置值，`estimated_rf` 是估计值，二者都不能直接等同于经标定的测量结果。
ADC OTR 当前为预留输入，未参与 DSP/协议；GUI 削顶标志来自数字 DSP 饱和，不能代替 OTR。

### 4.2 USB 与启动/停止

| 项目 | 当前约定 |
| --- | --- |
| 设备 | 已有板上 FX2、USB 2.0 High Speed；当前测试 VID/PID=04B4:1004 |
| 端点 | alternate interface 0；EP2 IN=0x82、EP6 OUT=0x06，均 512 B Bulk |
| 主机接口 | 官方 Cypress 驱动 + `CyUSB.dll` + pythonnet；需要恰好匹配一个设备 |
| 自动模式启动 | QUERY → MODE(1) → HOLD；由 FPGA 自动估频，不发送 TUNE/QUALITY/TRACK |
| 手动模式启动 | QUERY → MODE(2) → HOLD → TUNE(整数 Hz)，随后报告 QUALITY；QUALITY 不改 LO |
| 保持 | 默认 500 ms，可设 1–60000 ms；低可信度/超时保持当前频道，不切换模式 |
| 停止 | 保持读入/解码直到 STOP ACK；错误、超时或事件溢出报告并停止，不盲目重发 |
| 恢复 | 无自动重连；检查设备/日志后手动重新开始。PLL/全局复位取消未完成事务，需要重建连接 |

运行时更改模式或手动载频，要先停止后重新开始。普通 GUI 不发 Vendor 命令、不刷 FX2 固件、
不下载 SOF；FX2 固件、Slave FIFO 配置、PA1 等板上使能条件由 FPGA/硬件同学提供准确操作步骤。
使用官方 DLL，Python/.NET/原生依赖的位数和运行时需匹配；DLL 可在 GUI 手动选择。

**诊断脚本有不同的硬件副作用：** `dual_control_test.py` 会通过 USB-Blaster 下载指定 SOF；
`dual_sample_test.py` 会下载专用测试配置并上传 ADC12 RAM 样本；历史 `board_test.py` 也含烧录流程。
这些不是普通启动入口。接手先读其源码、对应 FPGA 说明及输出位置，再与 FPGA 同学安排测试。
可选 C# 异步接收组件由 `build_usb_pump.py` 构建，普通 GUI 尚未默认使用；历史实验通过
不能证明普通 GUI 接收路径具有相同性能。不要直接改驱动或将实验路径当成正式默认值。

### 4.3 当前帧格式速查

完整定义唯一来源为 [PROTOCOL.md](docs/PROTOCOL.md)
和共享 [protocol.py](ads807/interfaces/protocol.py)，不要在 GUI 中复制另一份定义。
整数小端 u32；每帧固定 512 B，offset508 为前 508 B 的 CRC32/IEEE（`zlib.crc32`）。

TCM1：offset0=`TCM1`，4=version1，8=command sequence，12=opcode，16=argument，
20=RF 整数 Hz，24..507 全零。opcode：QUERY=1、MODE=2、TUNE=3、QUALITY=5、STOP=7、HOLD=8。
每次仅等待一条命令 ACK，匹配 sequence/opcode/error；当前主机 ACK 等待上限约 2 秒。
错误码：0 成功、1 CRC、2 版本/保留字、3 未知命令、4 参数越界、5 模式或状态不允许。

TRI1 头为 16 个 u32（64 B）：

| 字索引 | 内容 |
| --- | --- |
| 0 / 1 | `TRI1` / `0x00400001`（头长64、版本1） |
| 2 / 3 | kind（IQ=1、ACK=3）/ 全局帧序号 |
| 4 / 5 / 6 | epoch / 首样本 index / IQ 对数或 ACK 字节数48 |
| 7 / 8 | ADC rate=43500000 / IQ rate=500000 |
| 9 / 10 | tuned_rf Hz / phase_step |
| 11 / 12 | flags / IQ 累计 dropped 或 ACK command sequence |
| 13 / 14 / 15 | config_id / estimated_rf Hz（不可信0）/ IQ SHIFT40 或 ACK0 |

载荷 offset64..507：IQ 为 1–111 对 `<hh`；ACK 为 12 个 u32：sequence、opcode、error、mode、
tuned_rf、phase_step、epoch、config_id、sample_index、flags、estimated_rf、hold_ms。未用区域补零。
flags bits1:0=模式，bit8=已调谐、9=可信、10=保持超时、11=削顶、12=暂态、13=累计溢出。
已调谐不保证有效 AM/FM 或可放音。RAW(kind2) 仅兼容历史文件；当前实时收到 RAW 应报固件不匹配。

全局序号跨 IQ/ACK 递增，IQ 连续性另按 epoch/config_id/sample_index 判断。
不能因 ACK 插入误报 IQ 丢帧，也不能把 epoch/config 变化前后的数据拼接。
sample_index 包含满 FIFO 丢弃的点；dropped 为 epoch 内饱和累计值。
CRC、序号、样本缺口必须可观察并切分连续段；u32 回绕按协议处理。
TRI1 暂态整帧保守丢弃；旧 FCR1 则按流开头 66 点处理，二者不可混用。

## 5. 上位机现有功能与接手边界

| 模块 | 文件与现状 |
| --- | --- |
| 输入/控制 | `transport.py`、`sources.py`、`tuning.py`：USB 后台读写、有界命令/事件队列；合成源和原始文件回放 |
| 校验/连续性 | `protocol.py`：FCR1/TRI1 适配、CRC/格式检查及重同步；`interfaces/`负责 TCM1/TRI1 定义 |
| 算法 | `dsp.py`：启发式 AM/FM/未知/无有效信号，包络/相位差解调、FFT、载频及调制参数估计 |
| 协调 | `runtime.py`：接收、处理、保存、记录扫描和设备查询的职责与线程协调 |
| 音频 | `audio.py`：48 kHz 单声道、有界缓冲、预缓冲、欠载/溢出统计 |
| GUI | `gui.py`、`theme.qss`：深色工作台、三视图、滚轮缩放/平移、手动窗口、状态和记录 |
| 保存/预览 | `records.py`：捕获包；`preview.py`：loopback 实际 Qt 镜像 |
| 检查入口 | `verify.py` 为离线验证；带 `board`/`dual_*test` 的脚本用途需分别确认 |

现有功能需保留的语义：

- 默认显示解调波形，可切 FFT/原始 IQ；时间窗口 2–200 ms，滚轮缩放和拖动平移，复位恢复跟随。
- 冻结只停止显示；接收/音频仍继续。保存的是后台最新连续段，最长约 2 秒，**不保证是冻结画面**。
- FFT 为 Hann 窗 2048/4096/8192 点（约 244.14/122.07/61.04 Hz），横轴相对数字本振。
- AM/FM 需约 20 ms 窗口连续三次确认；特征可信度不是标定概率。低调制度、复合信号、多载波等仍可能误判。
- AM 深度为包络分位数估计；FM 频偏为瞬时频率分位数估计，调制指数仅适用于明显单音。
- 音频为 15 kHz 低通、抽取/有状态重采样、35 Hz 高通；FM 可选关闭/50/75 µs 去加重，未实现立体声/RDS。
- USB 异常报告并停止；超过约 0.6 秒无有效 IQ 清理活动波形/音频；文件 EOF 保留最后画面，无自动模拟补流。

吞吐与缓冲需要实测：IQ 净载荷 2 MB/s，TRI1 满帧约 2.3063 MB/s，加 25% 余量约
2.883 MB/s，ACK/USB 总线开销另计。生产 FPGA FIFO 512 点仅 1.024 ms；专用测试配置
可能只有 256 点，必须看测试固件，不可沿用生产容量。主机接收队列 128 项、每次最多 32 KiB，
满时丢当前块并计数；音频上限 250 ms，溢出丢最旧数据，欠载输出静音并计数。
这些有限缓存不能保证任意系统停顿不丢样。先定位 USB 服务、队列或处理耗时，再决定优化方式。

捕获目录包含 `waveforms.npz`、`iq.csv`、`demodulated.wav`、`transport.fcr`、`metadata.json`。
元数据记录保存时间、来源配置、传输配置、测量、完整性计数、epoch、单位/采样率及去加重。
`transport.fcr` 的扩展名不代表内容一定是 FCR1，也可能是 TRI1；原始帧可多出窗口首尾样本，
音频存在因果滤波延迟与稳定静音。WAV 不乘扬声器音量。当前按元数据目录扫描查询，无数据库。

## 6. 已验证什么，以及哪些失败仍需接手

以下为迁移前的已有证据；软件历史路径现相对host，FPGA结果摘要随包放入evidence。
本次离线迁移复验见 `docs/MIGRATION.md`；软件、RTL、时序、实板和射频验收分别判断。

| 范围 | 已有结果及证据（相对host根目录） | 不能据此认定的内容 |
| --- | --- | --- |
| 两模式软件 | 2026-10-20 记录为78项回归通过；`.harness/ads807_host/dual_new_tests.xml` | 真实 USB 吞吐或识别精度 |
| 实际 Qt 离线 | AM/FM/静默/噪声4场景通过；`.harness/ads807_host/dual_verification/result.json` | ADC/射频或真实音质 |
| RTL→生产解析器 | 107帧（89 IQ、18 ACK）、8835样本，任意分块校验通过；`evidence/rtl_host_crosscheck.json` | 真实 USB 或正常工况长期无丢样 |
| FPGA 构建 | 见新工程 VALIDATION；物理引脚配置后的已约束时序通过，资源余量很小 | ADC 板级 I/O 延迟和实际采样相位签核 |
| 实板 USB 控制 | ADC未接入；60秒440条命令符合预期，无CRC/全局序号异常；`evidence/board_control_20261020_162353.json` | AM/FM、ADC、持续IQ/音频或射频验收 |
| 专用 RAM 样本回放 | `evidence/usb_samples_20261020_182443.json` 为 **FAIL**；首组手动 AM/800 通过10秒，第二组 AM/80 等待 STOP ACK 超时 | 整轮矩阵通过、普通 GUI 接收性能或真实 ADC 输入 |
| 历史物理音频 | 2026-10-17 合成AM解调短时PortAudio输出；见 `ads807/VALIDATION.md` | 当前USB→真实射频→持续扬声器链路 |

最新样本回放失败原因尚未定位；不能据单条超时断定是主机、FX2 或 FPGA 的单方问题。
历史三模式/回放测试另有队列溢出、ACK 超时、USB 无法枚举及重新上电恢复记录。
这些问题要带固件版本、时间和原始证据交给 FPGA/集成人员共同复现，不应通过自动重试掩盖。
当前尚无真实 ADS807 射频识别准确率、深度/频偏标定、端到端时延和长期音频/零丢样验收结论。

## 7. 交接时逐项对齐并填写

下表空项均为待共同确认，当前数值是实现配置而非任务书的正式验收阈值。

| 待对齐项 | 责任方 | 交接时填写/确认 |
| --- | --- | --- |
| 交付源码包与当前生产 SOF | FPGA + HOST | 包名/日期/源码哈希：____；SOF路径及SHA256：____ |
| 板卡/FX2 固件与启动条件 | FPGA + 硬件 | 驱动/固件版本、端点、PA1/跳线、复位及上电顺序：____ |
| ADC连接与码型 | 硬件 + FPGA | ADS807E完整料号、12位接线、VDRV/时钟/OTR及采样时序验证记录：____ |
| 协议冻结 | FPGA + HOST | MODE1/2、TCM1/TRI1、速率、SHIFT、IQ方向、CRC和版本拒绝规则确认：____ |
| 模式职责 | FPGA + HOST | 自动不发TUNE/QUALITY；手动QUALITY不改LO；低可信度持续IQ；STOP ACK语义确认：____ |
| 断连/超时恢复 | FPGA + HOST | 正常STOP、ACK丢失、USB拔插/枚举失败的复现及人工恢复步骤：____ |
| 射频测试输入 | 硬件 + ALGO | 信号源、88/98/108MHz等测试点、电平、AM深度/FM频偏、音频频率与噪声条件：____ |
| 参数精度 | ALGO + 集成 | 载频/AM深度/FM频偏误差、识别正确率、未知判定条件与参考仪表：____ |
| 持续性和时延 | HOST + 集成 | 连续时长、丢样/CRC/音频欠载指标、接收和放音延迟测法：____ |
| 音频 | HOST + 集成 | 本机输出设备、FM去加重、目标音频带宽与音质判据：____；勿复用历史设备号10 |
| 保存/查询语义 | HOST + 集成 | 是否继续保存最新约2秒，是否需长录制/冻结窗口导出、目录和检索字段：____ |
| 开发归属 | 全员 | HOST在本目录内开发与测试；共享协议/FPGA变更先协调；根文档与harness清单由集成维护 |

## 8. 建议接手顺序与交付验收

1. 在接手电脑建立环境，按第3节完成合成演示、全量软件回归及截图；保存本机结果和依赖信息。
2. 与 FPGA 同学填写第7节，确认生产 SOF 与测试 SOF 的区别，冻结协议及采样配置。
3. 先复现 QUERY/MODE/HOLD/TUNE/STOP 和异常ACK，再共同排查最新 STOP 超时；操作记录保留原始帧和版本。
4. 用已知 ADC12 样本检查搬频方向、连续性、AM/FM参数及回放；真实ADC验证再覆盖88/98/108MHz与边界带宽。
5. 校准真实信号的识别与参数后开启低音量扬声器，分别验证AM/FM、去加重、无信号静音、丢样复位和断连。
6. 在约定机器/负载下做持续流、音频和时延验收；普通GUI与实验异步接收路径分别记录，失败如实保留。

验收时至少检查：

- [ ] 开机默认无硬件动作；合成/文件/USB来源明确，未知和无信号不会强制归类。
- [ ] 两种调谐、边界频点、命令拒绝/超时、停止和重连人工流程均符合冻结接口。
- [ ] FFT/IQ/解调三视图、手动窗口、滚轮缩放、冻结和后台接收语义一致。
- [ ] CRC错误、缺帧、样本间断、epoch/config切换、主机溢出和音频欠载均可观察，不拼接无效连续段。
- [ ] 保存包包含配置/单位/完整性信息，回放与查询分类可用；录制长度及冻结保存行为已与使用者确认。
- [ ] 真正射频输入下的识别、载频/调制参数和持续放音分别有约定条件及测量证据。

每个缺陷附：复现步骤、时间、信号源设定、源代码/SOF/驱动版本、模式与采样配置、
`metadata.json`、原始帧、日志、异常前后计数和必要截图。当前GUI保存仅覆盖最新约2秒，
持续性问题还需独立长时统计/抓取方案，不能只提交一张正常波形图。
