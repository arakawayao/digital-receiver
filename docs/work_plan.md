# 简易数字接收机并行工作计划

本计划依据任务书、根目录 AGENTS.md 和 README.md。工作包描述待开发功能，
harness 任务描述可执行检查；两者的完成状态分别记录。

## 当前基线

2026-10-20 上位机交付目录已统一为 `host/`，包括 `host/tests/`、共享Python协议、
历史上位机工具、文档和默认产物。旧 `tests/host/` 已迁移；FPGA目录内原host脚本只保留
兼容转发，实际实现归HOST维护。根harness同步引用新位置；本说明下方旧目录属于历史计划。


2026-10-20 当前FPGA工作入口新增 `receiver_ads807_dual`，从原ADS807工程采集/DSP派生，
EP4CE6F17C8，仅MODE1 FPGA自动与MODE2手动；无主机搜索/快照RAM。
现有 `host/ads807` 已对齐新目录和两模式协议；原 `receiver_ads807` 保留。
初版map/fit/已约束多工况STA通过，6183/6272 LE；后按用户P3原理图和接线顺序，
补齐ADC12位、OTR及CLK全部物理引脚，最新构建见新工程VALIDATION.md；不等于上板验收。
软件78项回归和合成GUI四场景通过，新增双向总线/保持/异常命令/FIFO验证入口见新工程文档。
下述三模式及回放矩阵为历史独立基线，不作为本轮实现状态。

2026-10-20 增加 `receiver_ads807/scripts/tri_replay_*` 和 `host/ads807/board_test.py`，
分别配置 EP4CE6 自动/手动 TRI1 ROM 回放与原 FPGA 自主 RPL1 回放，形成 12 组可视化实板计划。
自动/手动构建及新引脚级仿真通过；实板先遇到残留和 USB 枚举失败，重新上电恢复后，
自动搜索 AM/800 码复测仍出现 FIFO 丢样，矩阵未完成。
新增 `tri-fifo-budget` 离线检查，实际 Intel FIFO 模型的 256/512 点共 12 个停顿/恢复场景符合预期；
当前 256 点仅有 0.512 ms 样本容量，512 点在现有回放配置下估计需 33/30 个 M9K，不能直接扩容。
后续确认打包器在 FIFO 空时比较无效 showahead 数据，导致 34/35 对 I/Q 提前封帧；
已修复并重建八份 ROM SOF，自动/手动最小裕量 0.157/0.102 ns，满帧比例和逐点仿真通过。
新增可选官方 CyUSB 异步 IN 接收组件、耗时证据和失败归档；不改驱动或 FX2 固件。
实板自动模式 AM/800、FM/800、AM/80 各完成 30 秒，但同矩阵 FM/80 出现上位机队列溢出，
STOP 收尾超时也如实记录。单组 profiler 复测可通过，0.5 ms Python 切换间隔仍失败，
具体积压诱因未确认；12 组连续矩阵及小时级稳定性仍未完成。
后续同一矩阵 11/12 组各 30 秒通过，末组手动 FM/80 仍队列溢出。
将参数/FFT 稳定更新率限制到 10 Hz、保持逐块音频后，手动 FM/80 完成 60 秒零异常；
最新 60 秒矩阵自动 AM/800、FM/800 通过，第三组烧录前 FX2 匹配 0 个设备，
已按用户要求立即停止，等待重新上电，不自动重试。
入口、协议差异、弱幅度和证据见 [三模式实板测试](../main_project/fpga/receiver_ads807/TRI_BOARD_TEST.md)。

2026-10-19 测试硬件确认 EP4CE6F17C8，ADC 未焊完，先做内部 USB RAM 回放。
新增 `receiver_ads807/receiver_replay.qpf` 与 `host/replay.py`；独占新增回放文件，
复用已有 ADS807 DSP 和 receiver_v2 上传模块，不修改三模式源链路。
三模式已有 7535 LE 超过 EP4CE6 容量，因此本轮只保留 FPGA 自主估频。
接口、验证及烧录步骤见 [USB 回放说明](../main_project/fpga/receiver_ads807/USB_REPLAY.md)。
新增 receiver-replay-host-tests/am/fm/build 四项 harness 任务；任务通过不等于上板通过。
本轮回放仿真和EP4CE6构建完成，已实际下载并完成AM/FM 512帧USB回环；
重新上电后FM→AM→FM连续三轮零CRC错误、零丢样。历史ACK超时在重新上电后恢复，
仍须定位原因并补充持续运行、断连恢复与ADC实测。

2026-10-04最新用户更正：ADC固定56MHz由FPGA PLL提供，FPGA自主测频/控制DDC，
上位机不下发RF/NCO命令，接收后仍负责AM/FM识别/解调/放音。
当前FPGA入口为`main_project/fpga/receiver/receiver56.qpf`，旧32/40MHz与RCF1配置路径
已退役归档。W-005/007/008A数字实现与模块仿真、56MHzmap/fit/已约束路径STA通过；
自主ADC→USB全链路68完整帧及恢复检查通过，板级ADC约束、上板、生产PC与系统验收仍未完成。
实时要求经用户确认是锁定后持续处理、USB正常接收时不丢样；
新增receiver56-realtime-tests独立审计整个锁定时间轴，不以预期故障丢样作为通过。
实际正常短反压场景连续6ms、335990个ADC时钟全采集/混频、26完整USB帧逐值/CRC通过，
没有FIFO丢样；上板持续USB服务仍须实测。
FM查看问题已按既有WLF独立核查：88/108MHz各704对有效I/Q，各自场景的
6完整USB帧逐样本一致；epoch后4帧属于下一场景跳频尾段，统计时明确区分。
增加FM88/FM108查看预设，不改RTL；证据见receiver/VALIDATION.md及fm_iq_audit。
新增receiver-frequency-tests、receiver56-module-tests、receiver56-full-chain-tests、
receiver56-quartus已注册；旧adc-capture-tests/ddc-mixer-tests退出活跃harness，
下列旧采样率/路径/任务ID记录属于历史。状态以当前receiver/VALIDATION.md为准。

2026-10-04 核对实际 PLL 为 ×5/÷3 / 40 MHz，与下列历史 10 MHz 记录冲突；
根目录 EDA ADC 页为 AD9235BRUZRL7-40，参考核心板为 FX2 USB 2.0。
当前事实及方案门槛见 [项目审阅结论](project_review_2026-10-04.md)。本轮 INT 增加
`harness/dialog.py`、`tests/test_dialog.py` 和 `dialog-tests`，复用调度器并提供
GUI 后台执行、取消、状态与日志；W-013 增量已验证，不改变其他工作包交付状态。

2026-09-29 DDC 增量：实际路径 `main_project/fpga/srcs/ddc_mixer.v` 实现 NCO 及复数混频，
测试位于 `tests/test_ddc_mixer.py` 和 `tests/rtl/ddc/`，`ddc-mixer-tests` 已通过
Vivado Simulator 2025.1 数值、复位/使能/流水线和单音频移验证。W-007 为部分实现，
低通、抽取及系统定点策略尚未完成。24 MHz 参考、10 MS/s 计划采样率及 PLL ×5/÷12
配置已确认，板级时序未验证；10 MS/s 折叠边界及 RF 消歧仍须解决。

2026-09-29 增量：按当前实际目录在 `main_project/fpga/srcs/adc_capture.v` 实现
采集与码型转换（FPGA-A 范围），验证入口为 `tests/test_adc_capture.py`，测试台在
`tests/rtl/acquisition/`。`adc-capture-tests` 已使用 Vivado Simulator 2025.1 通过，
覆盖两种 12 bit 码型、复位与间断使能。实际工程配置为 Quartus 20.1.1 / Cyclone IV E，
本次未验证完整工程综合、时序或上板，W-005 仍仅部分实现。

2026-09-27 方案更正：采用 SMA 单信号射频带通采样，12 位 ADC 同时保留
ADI `AD9235`（20/40/65 MSPS 等级及封装待定）与 TI `ADC12020CIVYX/NOPB`
（最高 20 MS/s、并行 CMOS/TTL、offset binary）两款候选，撤回单一选型。
USB 3.0 保持不变。设计及后续 harness 输入见
[工程设计说明 v0.3](engineering_design_v0.1.md) 第 1、3、5、10 节。
实际采样档位、折叠区间/方向、未知 RF 消歧以及 108 MHz 实测性能仍待确认，
19/20 MS/s 仅为模型算例。harness 需按候选完整料号区分采样上限和码型，
不能将 20 MS/s 当作所有 AD9235 等级的上限；24/25 MS/s 对 ADC12020 和
AD9235-20 非法，对更高速 AD9235 等级仍需论证。供电和捕获时序不视为兼容。

已实现离线 IQ JSON 契约、AM/FM/静默合成样本、并行命令调度器和对应测试。
初始基线记录为统一入口已通过 22 项测试、四项已注册任务均成功（本次文档更新未重跑）；这不代表生产识别、
解调、RTL、实时放音或实物接收已经完成。

IQ 契约见 `docs/iq_contract.md`：包含 schema_version、sample_rate_hz、
center_frequency_hz、iq_format、samples 和可选 metadata。当前不包含帧序号、
丢包状态或识别结果字段。`metadata.truth.kind` 只是生成器标签，
接收算法不得读取它作为识别结果。硬件传输协议另行设计。

## 五人团队与文件归属

角色是职责划分，可以兼任，不代表新增团队人数。下面是与任务书一致的五人分工建议，
实际人员尚未指定。

| 人员角色 | 职责 | 独占写入范围 |
| --- | --- | --- |
| 硬件负责人 HW | 选型、原理图、PCB | `hardware/` |
| FPGA 负责人 A | ADC 接口、CDC、数据传输 RTL | `fpga/acquisition/`、`fpga/transport/`、`tests/rtl/acquisition/`、`tests/rtl/transport/` |
| FPGA 负责人 B，兼 ALGO | DDC、定点参考模型及离线算法 | `fpga/ddc/`、`reference/`、`tests/rtl/ddc/`、`tests/reference/` |
| 上位机负责人 HOST | 接收、算法接入、放音、结果管理 | `host/`（含 `host/tests/`） |
| 集成负责人 INT，兼 QA/MECH | 公共接口、harness、结构与验收 | `docs/`、`harness/`、`tests/harness/`、`mechanical/`、`reports/`、根说明文件 |

现有平铺测试文件不迁移：`tests/test_runner.py` 归 INT，
`tests/test_iq_contract.py` 和 `tests/test_signal_fixtures.py` 归 ALGO。
未来目录随实际工作建立，表中列出不代表已存在。每个目录同一时间只有一个写入者；
同一负责人名下若再拆并行子任务，也必须明确互不重叠的子目录或文件。

公共契约由 INT 协调：ALGO 维护解析实现，INT 维护接口说明，消费者给出评审。
修改契约字段时暂停受影响的并行编辑，顺序集成实现、说明及消费方测试，
再恢复并行。共享任务清单和根文档只由 INT 修改。

## 可执行验证任务

以下 ID 与 `harness/tasks.json` 一致：

| 任务 ID | 依赖 | 实际验证或产物 |
| --- | --- | --- |
| `dialog-tests` | 无 | 5 项后台执行、依赖选择、失败/取消、运行锁及有界日志检查；不依赖桌面显示 |
| `harness-tests` | 无 | 11 项调度、失败、超时、中断及配置检查 |
| `iq-contract-tests` | 无 | 6 项离线 JSON 校验与读写检查 |
| `signal-fixture-tests` | 无 | 5 项确定性、AM 包络、FM 相位增量及静默样本检查 |
| `generate-fixtures` | `iq-contract-tests`、`signal-fixture-tests` | 生成 `.harness/fixtures/` 下的三个 JSON 文件 |
| `adc-capture-tests` | 无 | 使用 Icarus 或 Vivado Simulator 检查两种码型全部输入、复位、使能和寄存对齐；需要对应工具在 PATH |
| `ddc-mixer-tests` | 无 | NCO/全位宽混频与三角函数参考模型对照，检查复位、相位、有效间断及正负频移；需要 RTL 仿真器 |

前三项及 ADC 检查可独立运行，样本生成等待其两项前置检查通过。生成器通过仅表示样本生成成功。
ADC 与混频模块仿真已注册，其余 RTL、上位机及系统验收检查仍待入口实际可运行后加入。
不得为未实现功能加入恒成功占位命令，也不得把未注册任务称为已执行的 blocked 任务。

从项目根目录执行：

```powershell
python -B -m harness.runner list
python -B -m harness.runner run --jobs 3
python -B -m harness.runner run --jobs 2 --task generate-fixtures
```

每次运行有独立日志和 summary.json。验证命令在项目根目录运行，使用命令数组，
不经 shell；`{python}` 使用当前解释器。新增任务必须声明依赖、超时和真实共享写入路径。
无依赖排序的任务写入目录重叠会在运行前拒绝。任务内部独立临时文件使用系统临时目录。
这只是冲突预检，不是文件访问沙箱，也不会自动创建或驱动 AI 会话。

## 开发工作包

“前置条件”表示完整交付所需条件；准备工作可按下节提前开展。
每项输出均在上述归属范围内，公共文档由 INT 整理并写入。

| ID / 主责 | 前置条件和读取输入 | 交付内容与写入位置 | 验收门槛 | 当前状态 |
| --- | --- | --- | --- | --- |
| W-001 / INT | 任务书、现有说明 | 需求条目、未决指标、证据索引；`docs/requirements.md` | 明确课程要求、项目约定和未定事项，可逐项追踪 | 初步清单已有，正式指标待确认 |
| W-002 / ALGO + INT | W-001 已知功能边界 | 离线 IQ 契约、解析和版本说明；`reference/iq.py`、`docs/iq_contract.md` | 合法输入往返一致，非法输入明确报错 | v1 基线完成 |
| W-003 / ALGO | W-002 | 带通采样、RF 消歧、方向校正、AM/FM 识别解调及 DDC 模型；`reference/`、`tests/reference/` | 不读取真值标签判别，允许未知/无信号/频率未确定；覆盖折叠边界、频偏、噪声及定点 | 仅基带合成样本已完成，RF 带通采样及接收算法待实现 |
| W-004 / HOST，INT 集成 | W-002；最终预算需 W-009 | 传输协议提案、字节序、序号、丢包及吞吐预算；HOST 在 `host/protocol/`、`tests/host/protocol/` 实现编解码，INT 写 `docs/interfaces/` | FPGA/HOST 对同一帧解释一致，异常帧明确处理，吞吐含开销 | 待开发，可先做参数化提案 |
| W-005 / FPGA-A | W-009 器件及接口时序；W-002 数据语义 | ADC 并行接口、按配置码型转换、复位、CDC 和缓存；实际源文件在 `main_project/fpga/srcs/` | 各候选码型边界、时钟切换、FIFO 及复位仿真；约束有资料依据 | 部分实现：采集/码型转换仿真通过，PLL 已配置；CDC、缓存及板级时序待验证 |
| W-006 / HOST | W-002、W-003 算法接口 | 离线处理管线、识别/解调/测量适配；`host/processing/` | 对照参考结果，错误和无信号可观察，不读取真值标签 | 可先做输入适配，算法联调待 W-003 |
| W-007 / FPGA-B | W-003 DDC 模型、W-009 采样方案 | 混频、滤波、抽取、位宽及定点策略；实际混频源文件在 `main_project/fpga/srcs/` | 参考向量对照、抗混叠、溢出和流水线对齐；工具版本明确 | 部分实现：NCO/混频 RTL 与数值参考对照通过，低通/抽取及综合上板未完成 |
| W-008A / FPGA-A | W-004 协议、W-005/W-007 数据接口、物理链路选型 | FPGA 帧封装、传输、反压和错误统计；`fpga/transport/` | 与 HOST 共用协议样本，停顿/溢出可复现 | 待协议及平台确定 |
| W-008B / HOST | W-004、W-006；音频后端需主机平台 | 接收、有界队列、放音及记录保存/查找/分类；`host/io/`、`host/audio/`、`host/records/` | 协议和断连测试、记录往返；真实持续放音独立验证 | 可先实现回放输入，实时验收待硬件 |
| W-009 / HW | W-001、器件资料、预算及可用设备 | 两款 ADC 比较、RF/接口验证及 FPGA/时钟/电源选型；`hardware/selection/` | 按完整料号核对带宽、码型、供电、时序及成本；100–108 MHz 性能有实测证据 | AD9235 与 ADC12020CIVYX/NOPB 并列候选；最终选型与性能验证未完成 |
| W-010 / HW | W-009、W-004 接口决策 | 原理图、PCB、BOM、ERC/DRC；`hardware/` | 源工程一致，规则检查和豁免有记录，制造参数有依据 | 选型及板厂条件阻塞最终设计 |
| W-011 / INT-MECH | W-010 外形、孔位、连接器与散热需求 | 可编辑结构模型与打印输出；`mechanical/` | 尺寸检查和实物装配分别验证 | 可先整理约束，外形未定 |
| W-012 / INT | W-003/004/005/006/007/008A/008B/010/011 的交付 | 集成记录、版本表、连接图和证据；`docs/integration/`、`reports/` | 分别记录仿真、时序、上板、实时链路结果 | 待上游，可先维护清单 |
| W-013 / INT-QA | 各工作包提供真实可执行测试入口 | 扩展 `harness/tasks.json` 和调度器测试；各模块测试仍由各自负责人维护 | 失败下游不执行，独立任务可继续，日志可追溯 | 基线完成，随功能增量扩展 |
| W-014 / INT | W-012、W-013、课程正式验收要求 | 任务书逐项验收与报告；`docs/acceptance/` | 每项结论指向输入条件与证据，缺项标未验证 | 待系统联调 |

W-005 与 W-008A 同归 FPGA-A，W-006 与 W-008B 同归 HOST，顺序安排或细分独占目录后执行。
W-003 与 W-007 可交替推进，先建立参考行为，再提交 RTL 对照结果。

## 依赖与并行批次

```text
W-001 -> W-002 -> W-003 -> W-006 -> W-008B
  |        |                          ^
  |        +-----> W-004 -------------+
  |                   |
  +-----> W-009 ------>+--> W-010 -> W-011
             |
             +--> W-005 --+
             +--> W-007 --+--> W-008A
                    ^           ^
                 W-003       W-004

W-003/004/005/006/007/008A/008B/010/011 -> W-012
各模块可执行入口 -> W-013
W-012 + W-013 -> W-014
```

1. 本轮基线已完成：离线契约、样本、并行验证入口。本轮使用三个子任务并行实现，
   由协调者审查和集成。
2. 下一批可并行：ALGO 推进 W-003；HOST 推进 W-004 与 W-006 输入适配；
   HW 推进 W-009；INT 补 W-001 并维护 W-013。尚无算法实现时，上位机只能测试
   数据流和错误路径，不能声称识别解调已完成。
3. 器件与协议确定后：W-005、W-007、W-008B、W-010 可在各自前置条件满足后并行，
   W-008A 依据输入数据接口接入；每条线保留独立测试。
4. PCB 外形稳定后完成 W-011，随后 W-012 系统联调，最后 W-014 验收交付。

硬件约束尚缺时，允许模型、预算模板和模拟接口工作；引脚、电平、最终滤波系数、
吞吐结论、时序和实物性能必须等待真实依据。任务书所要求的实时音频仍需要设备验证。

## 分配、集成与状态维护

每次分配任务应提供工作包 ID、输入版本、独占文件、预期产物、可执行验收命令及
已知阻塞项。代理提交结果时附修改文件和实际验证，不自行改公共接口或别人的模块。

当前没有 Git 仓库，不自动创建 worktree、分支、提交或新 Codex 任务。
本地多代理使用同一目录，目录归属需要协调执行；harness 只并行运行命令。

公共接口变化由 INT 记录原因、旧/新字段、受影响消费者和迁移步骤，
由各负责人顺序更新对应实现，再运行相关检查。不将新接口悄悄写入单个模块。
工作包的“计划/实现中/已实现/已验证/受阻”与运行报告中的 passed/failed/blocked
是不同维度；每次开发完成后更新相关工作包状态，并保留未完成范围。
