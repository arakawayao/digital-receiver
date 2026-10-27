# FCore2S 数字接收机 FPGA 新工程

2026-10-04 按用户要求从头编写，不引用旧 srcs、ip、project1 或旧 RTL 测试。
顶层是 `rtl/receiver_top.v`，Quartus 入口为 `receiver32.qpf`、`receiver40.qpf`。
工程实现采集、DDC、滤波、预处理与 USB；识别、解调、测频、放音仍由上位机实现。
本轮未删除旧文件，但编写期间旧工程已从共享目录移走/删除，来源未确认。

## 工具和板卡依据

实际调用 Quartus Prime **18.1.0 Build 625 Standard**、ModelSim SE-64 **2020.4**。
不是旧工程的 Quartus 20.1.1 或 Vivado Simulator；没有安装新软件。

依据均来自 `ETree_FCore2S_Board/`：

- `硬件原理图/FCore2S硬件原理图_E6.pdf` 第 2、4 页及 `FPGA引脚定义.xlsx`：
  EP4CE6F17C8、24 MHz U3、3.3 V VCCIO、CY7C68013A、USB PB/PA/FLAG/IFCLK。
  时钟 M16、复位 M12、LED L12 和 USB 引脚已交叉核对，见 `board_pins.tcl`。
- `FPGA_project/08_USB_FIFO_WR.zip`：8 bit Slave FIFO 写、FLAGB、EP2 地址 00、
  反相 IFCLK；`09_USB_FIFO_RD.zip`：EP6 地址 10、FLAGC。
- `USB2.0/Firmware/Bulkloop/bulkloop.c`：IFCONFIG=03、EP2 bulk IN/EP6 bulk OUT、
  AUTOIN/AUTOOUT、PA1 暂停与 vendor A8/A9。PA1 由固件输出，FPGA 必须配置为输入；
  没有沿用示例顶层未驱动的 output PA1，也未复制错误的示例 SDC。
- `芯片手册/CY7C68013A.pdf` 第 43、46 页：外部 IFCLK 的同步读写时序。

**本新工程使用板载 FX2 USB 2.0。** 根 README 的 USB 3.0 是另一硬件目标，
未在这里伪装为 SuperSpeed。原板卡文件、ZIP、固件均未修改；真实驱动、固件下载
和持续吞吐仍需实测。参考源工程和原理图中没有外接 ADC 接线。

## 处理链和数据接口

```text
24 MHz -> ALTPLL -> 32/40 MHz 采样域 + 24 MHz USB 域
ADC 12 bit -> 码型转换 -> NCO/复数混频 -> 五级 CIC -> 补偿低通 FIR
           -> 舍入/饱和 -> DCFIFO -> 连续样本组帧/CRC32 -> FX2 EP2 IN
FX2 EP6 OUT -> 暂停时更新频率/方向 -> toggle 跨域传递稳定配置
ALTDDIO_OUT -> 外送反相 IFCLK
```

| 接口 | 参数与行为 |
| --- | --- |
| ADC | 单通道 12 bit，OFFSET_BINARY=1 翻转 MSB，0 保留补码；转成 -2048…2047 整数 |
| 采集 | 上升沿、连续流、数据/valid 寄存；同步低有效复位，无硬件反压 |
| NCO | 32 bit 相位，1024 点 ROM，signed12 Q1.11 系数，峰值 2047/2048 |
| 混频 | I=x*cos、Q=-x*sin；倒置频谱时共轭一次；各 signed24，11 小数位，完整乘积 |
| NCO 流水线 | 输入边沿 n，输出 n+1 后有效；间断使能暂停相位，不表示丢样 |
| CIC | 五级积分/梳状，R=64 或 80，58 bit 模运算；对真实有效样本积分 |
| CIC 输出 | 32 MHz 右移 37 位、40 MHz 右移 39 位，向负无穷取整；饱和 signed18、clip |
| FIR | Fs=500 kS/s，61 个 signed18 Q1.17 系数，系数和 131072；两路 MAC、42 bit 累加 |
| FIR 输出 | 加半 LSB 后右移 17，最近舍入、半值向正无穷，饱和 int16，valid/clip 对齐 |
| FIFO | Quartus DCFIFO，512×97 bit、show-ahead，双域各 4 级指针同步，满/空保护 |
| FIFO 排列 | `{clip, dropped[31:0], index[31:0], Q[15:0], I[15:0]}` |
| FIFO 满 | 丢弃当前输出，累计 dropped 饱和递增，index 自然回绕继续递增，不隐藏缺口 |
| USB | 24 MHz，8 bit，EP2 IN/EP6 OUT；寄存 FLAG 后操作，写后 guard 等新的 FULL 状态 |
| 启动 | 复位/失锁/暂停异步断言流复位，各域同步释放后等 32 周期 |

FIR 接受输入后 62 周期输出，64 周期间隔已验证。启动时以已填充样本数屏蔽历史
RAM 未初始化值，使 Quartus 推断 M9K；超期置 sticky deadline_error。LED 表示
锁定且没有非法命令/处理超期，不代表射频接收正常。

CIC 最大增益 80^5=3276800000，24 bit 输入加 32 bit 增长需 56 bit，58 bit 留余量。
积分器无限累加会回绕，统一模宽的梳状差分消除回绕。FIR 61 个 18×18 乘积用
42 bit 累加，不截位。实数单音输入幅度 A，对应目标输出幅度约
`A/2 * 2047 * R^5 / 2^SHIFT`；**两档增益不同**，PC 须按速率/SHIFT 解释和校准。
输出码不是电压/功率，不直接等同于离线 normalized_float IQ。
帧中采样率是名义 PLL 目标，参考晶振误差和实际采样频率尚未校准。

候选有效带宽 ±100 kHz，100–150 kHz 过渡，150 kHz 起为 FIR 阻带。生成器检查
CIC+量化 FIR 通带偏差 <0.15 dB、阻带 <-65 dB、抽取前会折入 ±100 kHz 的 CIC
别名抑制 <-60 dB，实际结果见 `filter_report.json`。这些是本数字原型的设计门槛，
不是课程正式指标，不包含模拟前端/ADC/时钟抖动性能。

## 调谐与采样范围

32/40 MHz 是两个静态工程配置，换档需要重新配置 FPGA；未实现动态 PLL 切换。
32 MHz 在 96 MHz、40 MHz 在 100 MHz 有折叠边界，一档不能保证任意 88–108 MHz
中心可恢复。两档对 ±100 kHz 加 50 kHz 保护带数学上互补，仍需核验 ADC 完整
料号、模拟带宽、前端预选滤波、采样时钟和捕获时序。

默认 RF=98 MHz，32 MHz 档 LO=2 MHz，40 MHz 档 LO=18 MHz，均不倒置。RF 是调谐
元数据，不是实测中心频率。没有 RF 自动消歧、识别或解调。

`scripts/prepare_command.py` 从已知 RF 先验计算别名/NCO 字/方向，拒绝跨折叠
保护带的配置。RTL 拒绝 RF 越界、保留位、错误方向及 RF/LO 过近折叠边界；RTL
不核验任意手写 phase_step 与 RF 的精确对应，应通过命令生成器保持一致。

EP6 命令 16 byte 小端：ASCII RCF1、u32 phase_step、u32 RF_Hz、u32 flags
（只有 bit0=conjugate）。流程：vendor A8 令 PA1 高，发送 16 byte 至 0x06 OUT，
等至少 1 ms，再 vendor A9 恢复。暂停时 DSP/FIFO/帧清空，配置路径继续运行；接受
命令和恢复均递增 epoch。主机必须清理旧 USB 读缓冲，核对恢复帧中的实际配置。
没有独立命令应答，坏命令置 sticky 指示。固件 A9 会复位端点 FIFO。

配置总线保持稳定，用两级 toggle 同步后捕获，不逐位同步。命令之间至少 16 个
USB 周期，远大于两级采样域同步时间；恢复再等 1 ms。流运行中不可直接改配置。

```powershell
python -B main_project/fpga/receiver/scripts/prepare_command.py --rf-hz 98000000 --rate 32000000 --output .harness/receiver/tune98.bin
```

该命令只创建 USB 配置负载文件，不操作真实设备。

## FCR1 帧提案

这是新工程内部提案，公共 IQ JSON/线上协议文档尚未改动，也未冻结为 PC 协议。
固定 512 byte，适配 FX2 HS AUTOIN：60-byte 头、112 组 I/Q（448 byte）、4-byte CRC。
多字节均小端，每组 signed16 I、signed16 Q。CRC32/IEEE reflected、初值 FFFFFFFF、
poly EDB88320、最终取反，覆盖前 508 byte，已与 Python zlib 对照。

| offset | 字段 |
| --- | --- |
| 0 | ASCII FCR1 |
| 4 | u16 version=1，u16 header_length=60 |
| 8 | u32 frame_sequence，自然回绕；流复位归零 |
| 12 | u32 epoch，全局复位归零，命令/恢复递增 |
| 16 | u32 first_sample_index，自然回绕；流复位归零 |
| 20 | u32 valid_count，1…112 |
| 24 | u32 cumulative_dropped，饱和递增；流复位归零 |
| 28 | u32 ADC_rate_Hz |
| 32 | u32 IQ_rate_Hz=500000 |
| 36 | u32 RF_tuning_Hz（非测量值） |
| 40 | u32 phase_step |
| 44 | flags：bit0 累计丢样、bit1 共轭、bit2 本帧 clip、bit3 包含启动过渡 |
| 48 | u32 CIC_SHIFT=37/39 |
| 52 | u32 capacity=112 |
| 56 | u32 reserved=0 |
| 60…507 | I/Q；超出 valid_count 的样本填零，不是有效数据 |
| 508 | u32 CRC32 |

遇 index 缺口结束当前部分帧，缺口后的首样本留给下一帧，帧内有效样本始终连续。
前 66 个 IQ 输出属于滤波启动过渡区，PC 按 index 丢弃，bit3 提醒存在该区。
暂停/失锁可截断正在传输的帧，PC 必须重同步、检查 CRC/epoch/sequence/index。

满帧吞吐 `500000/112*512=2.285714 MB/s`，加 25% 余量为 2.857143 MB/s，仍需 USB
协议/驱动实测。组帧最多 8 MB/s，FULL 降速。FIFO 容纳 1.024 ms IQ，帧缓存另有
112 样本；不是无限缓存或正式延迟指标。

## 重建、仿真与证据

项目根目录执行，不依赖旧测试和仿真器 PATH：

```powershell
python -B main_project/fpga/receiver/scripts/generate.py --ip-only
python -B main_project/fpga/receiver/scripts/simulate.py
python -B main_project/fpga/receiver/scripts/full_chain.py
python -B main_project/fpga/receiver/scripts/build.py --rate 40
python -B main_project/fpga/receiver/scripts/build.py --rate 32
```

工具位置可用 --quartus/--modelsim 指定。IP 由本机 Quartus Clearbox 真实生成，
ALTPLL/DCFIFO/ALTDDIO_OUT 配置、版本和端口保留在文件头与生成脚本；不手改 ip/*.v。
表已保存为 rtl/*.hex。离线重设计表使用 NumPy（FIR 最小二乘/频响），普通构建/
仿真对照只需 Python 标准库。本机 bundled Python 可重生成：

```powershell
& 'C:\Users\yjj\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -B main_project/fpga/receiver/scripts/generate.py --tables-only
```

ModelSim 编译 Quartus 的 altera_primitives.v、220model.v、altera_mf.v、
cycloneive_atoms.v，仿真实际生成 IP；未用假 FIFO 替代。覆盖 PLL/复位、配置拒绝/
方向恢复、FIR 饱和/历史清空/64 周期截止、FIFO 满/空/在途复位、USB FULL 反压、
缺口拆帧/补零/CRC、两档全链整数参考对照、频偏/方向/AM/FM/静默及顶层 ADC→USB。
顶层帧逐样本和 CRC 与独立参考核对。日志、向量、WLF、summary.json 位于
`.harness/receiver/sim/`，最终结论见 `VALIDATION.md`。

更完整的顶层场景入口为 `scripts/full_chain.py`，两档分别实例化
`tests/full_chain_tb.sv` 中的真实 receiver_top。输入是 12 bit ADC 引脚上的合成
实数射频采样；经过 PLL、采集、NCO、CIC、FIR、DCFIFO、组帧，输出由 FX2 总线
时序模型采集。98 MHz AM（5 kHz/深度 0.5）、88/104 MHz FM（5 kHz/±25 kHz）、
静默、2 ms USB 持续阻塞、108 MHz +5 kHz 单音依次运行。每个场景都通过真实
EP6 RCF1 命令暂停/调频/恢复，没有 force 内部信号或替换 IP。

检查 USB 头的全部字段、I/Q 逐样本整数参考、CRC、缺口、累计丢样、部分帧补零，
以及暂停截断后恢复的 epoch/sequence/index。AM 包络、FM 相位差、单音频偏检查
从 **USB 收到的载荷** 计算。它们是离线上位机算法检查，未接入正式采集驱动、
调制识别、实时放音或记录管理。FX2 固件/USB 物理层也不在 RTL 模型中执行。

结果在 `.harness/receiver/full_chain/`：每档的 `chain*_summary.json`、`chain*_iq.csv`、
输入/USB 字节/场景 txt、log 与 `full_chain*.wlf`。查看关键波形：

```powershell
# 重新仿真一个静态档（不传 --rate 则跑两档）
python -B main_project/fpga/receiver/scripts/full_chain.py --rate 40000000
# 输出可复制的 ModelSim GUI 查看命令；执行所打印的命令即可打开已完成的 WLF
& main_project/fpga/receiver/scripts/view_full_chain.ps1 -Rate 40000000
```

波形按 ADC、时钟/复位、NCO、CIC/FIR、FIFO、FCR1、FX2、EP6 调频分组；`stage`
对应上述 0…5 场景，`host_stall` 标记溢出压力区间。

构建由 Quartus Tcl 建工程，执行 map/fit、多角 setup/hold/recovery/removal STA。
忽略的约束或已约束路径负余量会使脚本失败。日志/摘要在
`.harness/receiver/build/`。output_*/、db/、incremental_db/、rpt、.harness/ 都可重建。
两个 Quartus 工程共享 db，构建必须顺序执行。公共 harness 清单由 INT 集成，
注册提案见 `scripts/harness_tasks.proposal.json`；旧模块任务不代表本工程通过。

## 尚未完成的硬件条件

ADC 数据/时钟 13 个端口是 **VIRTUAL_PIN**，不能下载作为接收机使用；构建脚本
止于 fit/STA，未生成下载文件或编程硬件。需补 ADC 完整料号、MODE/DVDD、供电与
电平、核心板扩展口接线、外送/捕获相位、数据延迟和前端预选滤波。

USB SDC 目前用器件时序、零 PCB skew；须加实际走线与抖动预算。仅异步复位开关/
PA1 第一同步级有具体路径例外。EP6 的 READ_STROBE 等待后由 READ_CAPTURE 采样，
FX2 数据跨过一个不读的 IFCLK 边沿保持，所以仅对 USB 数据到 command_data
设置 setup=2/hold=1 multicycle；没有对 ADC/DSP/整域加 false path。FIFO 自带
Gray 指针 CDC 例外在日志保留。

check_timing 保留未约束 ADC/LED、无虚拟时钟和生成 PLL pll_lock_sync 以锁定事件
驱动的 no_clock 问题，未造假消除。已约束路径正余量不等于完整板级时序验收。
ERC/DRC、真实射频/ADC、USB 持续吞吐、音频、上板和课程端到端验收均未完成。
