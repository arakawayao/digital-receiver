# 简易数字接收机

基于 FPGA 与上位机的 88–108 MHz AM/FM 数字接收机，对应 2026 年秋季“工程教育（高级）”课程项目。FPGA 负责采集、数字下变频与数据传输，上位机负责调制识别、解调、实时放音和测量记录管理；硬件交付还包括原理图、PCB 与 3D 打印结构设计。

**状态更新：2026-10-28。已实现两模式 FPGA 与桌面上位机，并开展真实信号和天线接收调试；整机验收尚未完成。** 本页根据上位机、FPGA、PCB、测试等对话的完成记录及仓库源码、证据摘要整理，区分软件实现、离线验证、用户实测反馈和待验证事项。

## 当前工程与架构

- FPGA：[receiver_ads807_dual](main_project/fpga/receiver_ads807_dual/README.md)，入口为 `receiver_ads807_dual.qpf`，顶层 `receiver_top`，器件为已确认的 **EP4CE6F17C8**。
- 上位机：[main_project/host](main_project/host/README.md)，Windows x64 / Python 3.11 / PyQt6；可独立运行，已有 Windows 便携版构建流程。
- PCB：[可编辑源工程](main_project/pcb/)，包含早期接收机工程与 ADS807E ADC 模块工程；最终板级基线、原生 ERC/DRC 和制板验证仍需收尾。
- 需求依据：根目录 `工程教育（高级）任务书（2026秋).doc`。目标频段、功能职责及便携、低成本取向来自任务书；下述实现参数不是课程规定的验收指标。

```text
单个 88–108 MHz AM/FM 信号
    → 射频预选 / 增益与驱动 / ADS807E
    → FPGA：12 位采集 → 自动估频或手动调谐 → NCO → CIC / FIR
    → 500 kS/s I/Q → 异步 FIFO → FX2 USB 2.0
    → 上位机：解包与校验 → I/Q 处理 → 识别 / 解调 → 48 kHz 单声道音频
                                      → 参数测量、保存、查询与分类
```

当前使用 **USB 2.0 FX2**；早期 USB 3.0、AD9235 / ADC12020 及 32/40/56 MHz 方案属于历史资料。88–108 MHz 是可调载频范围，不代表同时采集整个 20 MHz 频段。43.5 MS/s 带通采样仍依赖模拟带宽、预选滤波、镜像抑制和实际输入条件。

| 项目 | 当前实现 |
| --- | --- |
| 参考时钟 / ADC 采样率 | 24 MHz / PLL 产生 43.5 MS/s |
| ADC 输入 | 单通道 12 位 offset-binary，进入 DSP 后为有符号数 |
| DDC | 32 位 NCO，I=x·cos、Q=−x·sin；5 阶 CIC、87 倍抽取，61 tap FIR |
| CIC 实现 | 已接入 Intel CIC II，包含位宽裁剪及适配 |
| I/Q 输出 | 500 kS/s，每对 I16/Q16，小端、I 在前；软件按 I+jQ / 32768 归一化 |
| USB / 协议 | VID:PID 04B4:1004；EP2 IN 0x82、EP6 OUT 0x06；TCM1 v2 / TRI1 v1 |
| 帧与缓存 | 固定 512 B、CRC32、样本索引与配置元数据；默认 512 点 FIFO 约 1.024 ms |
| 音频 | 48 kHz 单声道；未实现立体声解码或 RDS |

协议以[上位机接口说明](main_project/host/docs/PROTOCOL.md)和两端源码为准。部分 FPGA 旧文档仍写 TCM1 v1，不能按其配置当前主机；v2 手动 TUNE 携带主机计算的 NCO 步进，并核对 ACK 回读。满帧 I/Q 协议流量约 2.31 MB/s；缓存有限，不能保证任意 USB 或主机停顿下都不丢样。

## 功能完成情况

| 模块 | 已实现或已完成的工作 | 当前边界 |
| --- | --- | --- |
| FPGA 采集与 DSP | 12 位采集、NCO、CIC/FIR、CDC、FIFO、组帧与双向控制；官方 CIC IP 已接入 | ADC/PCB I/O 时序、模拟幅度范围和全频段动态性能尚未签核 |
| 两种调谐模式 | MODE=1 FPGA 自动估频；MODE=2 上位机手动载频，手动启动不依赖估频 locked | 不含旧主机快照搜索；MODE0、SNAPSHOT、TRACK 已撤销 |
| USB 与应答 | GUI 默认异步 IN 接收；ACK 路由与 DSP 分离；有界队列、CRC/丢样/断连状态可观察 | 实际配置失败仍需按板上固件版本、端点和 ACK 路径排查 |
| 识别与解调 | AM/FM/未知/无有效信号；自动、强制 AM、强制 FM；宽带 FM 与导频辅助识别、分类切换确认 | 强制解调不等于识别通过，也不保证有节目；弱信号、干扰和多径仍可能失败 |
| 音频 | 连续滤波与重采样；默认设备优先同名 WASAPI，按设备延迟设置有界缓冲并记录诊断 | 已修正部分欠载和溢出问题，长时间真实接收放音仍待复测 |
| 界面与记录 | 解调/FFT/IQ 视图、参数弹窗、面板显隐、浅/深主题、波形保存、记录查询分类与回放 | 数字电平及测量参数未作仪器级标定 |
| 独立软件 | Windows x64 便携版、配套依赖与许可证、接收机图标、自动打包及自检 | 源码仓库不含发布 ZIP；其他电脑驱动和真实 USB/放音仍需验证 |
| 硬件与结构 | 已有 EDA 源工程，开展 ADC/滤波、接口、电源与 LNA 方案审阅；讨论过外壳工具和打印流程 | 审阅建议不代表已落入 PCB；未确认最终 ERC/DRC、制造、外壳模型与实物装配完成 |

调谐模式与解调模式是两个独立设置：手动设置载频只决定接收频道，自动识别仍可能判为未知。选择强制 AM/FM 可以继续解调有效 I/Q，但不会伪造自动识别结果或跳过传输校验。

FM 去加重可选关闭、50、75、100、150、200、300 µs；50/75 µs 是广播常用档位，100 µs 以上为实验配置。详见[解调配置](main_project/host/docs/DEMODULATION_MODE.md)。

## 已有验证与实测

以下是已有记录，不表示本次文档更新重新执行了 FPGA 构建或硬件测试。

| 验证层级 | 已记录结果与证据 |
| --- | --- |
| 上位机软件回归 | 2026-10-28 上传准备时完整回归 **184 项通过**；基础 harness **5 项任务通过**。运行日志留在本机，交付范围见[源码交付说明](docs/source_delivery.md) |
| FPGA 仿真 | 已有定点参考模型、CIC IP、双模式链路、CRC/元数据、CDC、反压和上位机解析核对；AM 停止改频重启专项回归通过，见[AM 重启诊断](main_project/host/docs/AM_RESTART_DIAGNOSIS.md) |
| FPGA 综合与实现时序 | 官方 CIC 优化后约占 83% LE。2026-10-26 AM 修复候选为 **5187/6272 LE**，map/fit/12 项已约束多工况时序及 assembler 通过，最小约束裕量 **0.103 ns**；仅对应该候选，不代替后续构建或板级签核 |
| USB 实板控制 | 2026-10-20、ADC 未接入时完成 60 秒控制往返，440 条命令应答符合预期；仅证明该版本控制链路，见[历史实板记录](main_project/fpga/receiver_ads807_dual/VALIDATION.md) |
| 真实天线采集 | 103.7 MHz 三份保存窗口索引连续，CRC、主机/FPGA 丢样及削顶计数为零，分块均为 FM；只覆盖已保存窗口，见[天线音频诊断](main_project/host/docs/FM_ANTENNA_AUDIO.md) |
| 独立版 | 2026-10-27 完成 EXE 自检、中文路径迁移、合成场景、主题及图标验证；未据此验证独立版真实 USB 长测，见[独立版验证](main_project/host/docs/PORTABLE_VALIDATION.md) |

真实广播接收的进度按证据区分：

| 频道 | 当前结论 |
| --- | --- |
| 103.7 MHz | 有真实采集数据，已有窗口均识别 FM；用户反馈可听清 |
| 89.9 / 91.4 / 101.7 MHz | 用户反馈可听清；未提供对应保存窗口用于独立复核 |
| 93.4 MHz | 修复分类门限重复拒绝后，实采数据离线 22/22 块识别 FM，回放恢复音频；待新版实机复测 |
| 105.7 MHz | 增加 19 kHz 导频辅助后，实采数据离线 74/74 块识别 FM；待实机听辨 |
| 90.9 MHz | 分类切换确认修正消除已保存数据中一处约 60 ms 中断；不能据此宣称全部断续解决 |
| 98.1 MHz | 已有数据 52/52 块仍为未知，用户未确认诊断音频有节目；根因尚未确定 |

详细输入条件和分析见[频道诊断记录](main_project/host/docs/FM_CLASSIFIER_GATE.md)。用户还反馈音频设备的 24 位输出有杂音、16 位正常；软件已优先使用 WASAPI 和动态缓冲，这些局部对照不能替代长期音频验收。

## 启动上位机

推荐 Windows x64、64 位 Python 3.11。运行依赖包括 PyQt6、pyqtgraph、NumPy、SciPy、sounddevice 和 pythonnet，锁定版本见[依赖文件](main_project/host/ads807/requirements.txt)；不需要 PyTorch。

在仓库根目录，用已创建并激活的 Python 3.11 环境执行：

```powershell
Set-Location .\main_project\host
python -m pip install -r requirements.txt
python -m pip check
python -B -m ads807 --demo FM
```

去掉 `--demo FM` 可正常启动；合成 AM 可用 `--demo AM`。启动默认不自动连接 USB、不开扬声器、不烧录 FPGA。原开发机也可使用 `start_host.bat`，但其解释器路径固定为 `D:\conda_envs\ads807_host\python.exe`，新机器需按环境调整。

真实 USB 接收前需安装匹配的 Cypress 驱动、CyUSB SDK 及 .NET Framework，并从上位机目录构建异步接收组件：

```powershell
python -B -m ads807.build_usb_pump
python -B -m ads807
```

确认板上 SOF 与 TCM1 v2 匹配，先关闭音频做手动载频与 ACK 检查，再验证 I/Q 和放音。信号源与上位机应设置相同载频；幅度须根据实际 ADC 输入网络核对，不能把信号源面板电压当作 ADC 引脚电压或通用安全阈值。

便携版无需 Python/Conda，但需保留整个程序目录及 `_internal`，新电脑仍需驱动和 .NET。源码仓库不提供已打包程序，使用与重建步骤见[独立版说明](main_project/host/docs/PORTABLE.md)。

## 开发与验证入口

从上位机目录执行软件回归和合成 GUI 验证，默认不访问 USB 或播放物理音频：

```powershell
python -B -m pytest tests -q -p no:cacheprovider --basetemp .harness/pytest
python -B -m ads807.verify --output .harness/verification
```

从仓库根目录运行基础 harness：

```powershell
python -B -m harness.runner run --jobs 3 --task dialog-tests --task harness-tests --task iq-contract-tests --task signal-fixture-tests --task generate-fixtures
```

FPGA 原工程记录的工具为 Quartus Prime **18.1.0 Build 625**、ModelSim SE **2020.4**、Verilog-2001。构建与仿真脚本见[两模式 FPGA 工程](main_project/fpga/receiver_ads807_dual/README.md)，工具路径、输出位置和下载链需按机器核对；不能直接照搬旧文档的引脚表，应结合实际 QSF、原理图和接线确认。

`harness/tasks.json` 仍有指向已不在本仓库中的 `receiver_v2`、`receiver_ads807_tri` 等历史流程；根测试还保留引用已移除早期 RTL 的测试。当前 `harness.runner list` 还会因 `ads807-managed-pump-build` 与 `ads807-host-portable-build` 声明了未排序的同一写入范围而拒绝加载。本次只更新说明，未修复这些历史入口及调度配置；使用上述已验证的指定任务命令，**不把全量 harness 或根测试发现当作当前全部可通过的验证入口**。

## 仓库目录与交付范围

```text
README.md                           当前入口、状态与验证边界
AGENTS.md                           项目工作规范
工程教育（高级）任务书（2026秋).doc   课程任务依据
main_project/
  fpga/receiver_ads807_dual/         当前两模式 FPGA 工程
  fpga/receiver_ads807/              旧 ADS807 基线及当前参考模型依赖
  fpga/receiver/                    历史 56 MHz 及 32/40 MHz 方案
  host/                             上位机、协议、测试、打包脚本与交接资料
    evidence/                       关键结果摘要及少量诊断音频
    firmware/                       固件用途、哈希及构建摘要；SOF 不随源码上传
  pcb/                              两份 EDA 可编辑源工程
harness/                            验证调度器与任务清单
reference/                          离线 I/Q 契约、合成样本与参考资料
tests/                              基础测试和保留的早期 RTL 测试
docs/                               接口、交付范围、历史方案和工作计划
```

Git 仓库排除 `.harness/`、Python/Quartus/ModelSim 缓存、运行波形、原始采集和打包程序，本地文件仍保留。必要 IP HDL、ROM/系数、约束和部分旧代码是当前构建或测试的输入，不能仅凭“生成文件”或“历史版本”名称删除。详见[源码交付说明](docs/source_delivery.md)。

## 未完成与后续工作

1. **射频与自动估频**：继续确认大幅度拒锁、弱信号及 FM 周期变化判据。AM 重启候选已完成仿真和构建，但对应实板复测尚未确认；不以其他版本能收信代替该候选验证。
2. **连续传输与放音**：核对板上固件/协议版本，复测配置应答、启停改频、断连恢复和长期 USB/音频连续性。短窗口零丢样不代表长期通过。
3. **硬件设计**：闭环 ADC 输入滤波、位序及连接器映射、匹配、去耦、电源选择与防倒灌；完成原生 ERC/DRC、BOM、供电/时钟和板级时序验证。讨论中的改值或双电源方案不作为已落板事实。
4. **结构交付**：按最终 PCB、安装孔、接口和散热建立可编辑外壳模型，导出打印文件并实物试装；目前仅有工具与流程讨论。
5. **系统验收**：明确精度、灵敏度、时延、连续运行时长等阈值，补齐 88–108 MHz 代表频点与端点、AM/FM、幅度和噪声条件的输入、结果及证据；完成课程报告和交付清单。

FIR II 仅完成隔离评估，因资源增加未替换主工程；FPGA AGC 尚未加入，应先完成实际幅度与过载评估。另一个对话审阅的独立工程 `D:\ADS807_FPGA_2026-10-25` 与本仓库目录不是同一交付副本，其构建结果和 SOF 不能直接视为已合入本仓库。

原 README 进展流水已移至[历史归档](docs/project_history.md)。[工作计划](docs/work_plan.md)及早期方案仍含旧状态，当前入口以本页为准；具体协议、源版本和验证条件以对应源码与证据为准。
