# 新 FPGA 工程验证记录

日期：2026-10-04（Asia/Shanghai）。工程为本目录内 receiver32/receiver40，
顶层 receiver_top。实际工具 Quartus 18.1.0 Standard、ModelSim SE-64 2020.4。
旧工程/旧 adc-capture-tests 和 ddc-mixer-tests 不作为本工程证据。

## ModelSim 与参考模型

运行 `python -B main_project/fpga/receiver/scripts/simulate.py`。
编译真实 Quartus ALTPLL/DCFIFO/ALTDDIO_OUT 生成文件和 Cyclone IV E 仿真库。

| 检查 | 输入与预期 | 结果 |
| --- | --- | --- |
| capture_tb | 两种 ADC 码型各 4096 码值、同步复位优先、使能间断、数据保持与 valid 对齐 | 通过 |
| pll_tb | 24 MHz 输入、32/40 MHz 输出、24 MHz USB 输出、复位重启 | 通过 |
| control_tb | FX2 15 ns 读延迟；合法 EP6、保留位/RF 越界/折叠边界拒绝、恢复 epoch | 通过 |
| fir_tb | ±signed18 满量程、int16 饱和、64 周期输入截止、复位清历史 | 通过 |
| transport_tb | 40 样本后人为缺口、两组 112 样本、端点 FULL、FIFO 填满/在途复位 | 通过；1536 byte，计数/补零/IQ/CRC 全部与独立 Python 核对 |
| DSP 32 MHz | 174172 周期：ADC 全码、随机使能、随机满幅、复位、单音/AM/FM/静默 | 逐周期数据/valid/clip/error 全一致 |
| DSP 40 MHz | 215132 周期，同类输入 | 逐周期全一致 |
| 32/40 MHz 顶层 | 实际 PLL、连续 ADC、DSP、异步 FIFO、FX2 FULL/恢复 | 两档各 3 帧，载荷逐样本与整数模型一致，CRC 正确 |
| RF 两档模型 | 88…108 MHz 每 10 kHz，2001 点，±100 kHz +50 kHz 保护带 | 每点至少一个静态档合法；不是硬件实测 |

单音覆盖 88、96、98、100、104、108 MHz 与 ±5 kHz 频偏；32 MHz 拒绝 96 MHz，
40 MHz 拒绝 100 MHz，正负折叠方向均覆盖。AM 真值 0.5，测得约 0.49984；FM
真值 ±25 kHz，测得约 ±25 kHz（32 MHz 最大 25000.72 Hz、40 MHz 最大 24990.95 Hz）。
这些是仿真输入与数字测量，不是生产 AM/FM 识别或真实信号源测量。

证据：项目 `.harness/receiver/sim/summary.json`、同目录每项 log、输入/输出 txt
与 WLF。整数模型独立实现寄存时序、CIC 模运算和 FIR 卷积，正弦值用 Python
三角函数计算；USB CRC 用 zlib，不依赖 RTL 的 CRC 实现。

## 扩展顶层全链路仿真

运行 `python -B main_project/fpga/receiver/scripts/full_chain.py`，实际 ModelSim
SE-64 2020.4 两档均输出 `FULL_CHAIN_PASS`，Python 全部独立检查通过。
测试实例化真实 receiver_top 和 Clearbox IP，ADC 在引脚输入、USB 在 FX2 IFCLK
边沿采集；没有 force 内部逻辑。FX2 数据/FLAG 延迟分别为 15/13.5 ns。

| 检查 | 32 MHz | 40 MHz |
| --- | --- | --- |
| 采样域输入日志周期 | 465108 | 581235 |
| 完整 USB 帧/有效 I/Q | 32 /3536 | 32 /3536 |
| USB 头全部字段、逐样本 I/Q、CRC、补零 | 全部一致 | 全部一致 |
| 98 MHz AM，5 kHz，深度真值 0.5 | 0.49984365 | 0.49984633 |
| 88 MHz FM，5 kHz，频偏真值 ±25 kHz | -24987.31…+24987.25 Hz，共轭=1 | -24983.41…+24997.94 Hz，共轭=0 |
| 104 MHz FM，同上 | -24987.31…+24987.25 Hz，共轭=0 | -24997.99…+24983.31 Hz，共轭=1 |
| 静默 | 稳态 I/Q 全零 | 稳态 I/Q 全零 |
| USB 堵塞 2 ms | FIFO 真正满，439 个样本丢弃 | 同左 |
| 堵塞恢复 | index 缺口累计=439，dropped=439；64 样本部分帧补零后继续输出 | 同左 |
| 帧中暂停 | 留下 17 byte 残帧并单独记录 | 同左 |
| 暂停后 USB 调到 108 MHz +5 kHz | epoch=12，sequence/index 归零，载荷/频偏正确 | 同左，切换共轭=1 |

6 个场景均通过 EP6 发送合法 RCF1 命令，等待 1 ms 后恢复；epoch 为
2、4、6、8、10、12。通常场景各 4 帧，溢出场景 12 帧，后一完整帧填充前因
主动暂停留下 17 字节。残帧不作为有效帧；后续场景按新 epoch 重新接收。
AM/FM 测量从 USB 收到的载荷计算，准确整数对照包含全部启动过渡样本。

证据：`.harness/receiver/full_chain/summary.json`、各档 `chain*_summary.json`、
`chain*_inputs.txt`、`chain*_bytes.txt`、`chain*_iq.csv`、`chain*_stages.txt`、log、
`full_chain*.wlf`。32 MHz 的同次运行临时 WLF 已保存回固定名称。
ModelSim GUI 实际加载 `scripts/view_full_chain.do` 成功：8 个分组、81 个关键信号，
无错误；GUI 验证日志及波形格式导出在 `full_chain/view_check/`。
PS1 查看入口为 `scripts/view_full_chain.ps1 -Rate 32000000` 或 `-Rate 40000000`，
脚本打印可直接执行的 GUI 回放命令。ModelSim batch 模式不支持 GUI 波形命令。

这是 **ADC 数字输入→FPGA 处理→USB 字节输出＋离线解调检查** 的全链路仿真。
FX2 为接口时序模型，未执行 8051 固件、USB 物理层/驱动；模拟射频前端、真实 ADC、
生产上位机 AM/FM 识别、实时声音与记录管理不在本次仿真中。此次只增加测试、
查看脚本与说明，未改变可综合 RTL/IP/引脚/时序，Quartus 结果沿用下节已有构建。

## Quartus 综合、实现与时序

顺序执行 build.py --rate 40 / --rate 32，真实 project/map/fit/sta 返回码均 0。
三角是 Slow 1200mV 85°C、Slow 1200mV 0°C、Fast 1200mV 0°C。

| 项目 | 32 MHz | 40 MHz |
| --- | --- | --- |
| 综合与布局布线 | 成功 | 成功 |
| Logic elements | 3752 /6272（60%） | 3755 /6272（60%） |
| 存储位 | 71242 /276480（26%） | 同左 |
| 9 bit 乘法器元素 | 8 /30（27%） | 同左 |
| PLL | 1 /2 | 1 /2 |
| 三角最差 setup slack | +2.372 ns | +2.024 ns |
| 三角最差 hold slack | +0.136 ns | +0.141 ns |
| 三角最差 recovery slack | +4.936 ns | +3.212 ns |
| 三角最差 removal slack | +0.697 ns | +0.585 ns |

最初 FIR RAM 未推断成 M9K，导致容量不足，已通过无条件 RAM 读与历史有效屏蔽
修复。USB FLAG 直达帧逻辑的半周期路径已改为寄存 FLAG/写后 guard；外送时钟
使用 DDIO IP。SDC 检查对预期 pin/register 数量断言，忽略的约束会使构建失败。

EP6 数据 multicycle 来源于实际状态机：SLRD 在 clk n 置低、FX2 在 n+0.5 输出
数据；n+1 等待、n+2 采样，下一次读最早 n+3.5。数据跨过不读的 IFCLK 边沿保持。
仅 USB 输入到 command_data 有 setup=2/hold=1，不影响 FLAG、DSP 或其他接口。

证据：`.harness/receiver/build/receiver{32,40}_summary.json`、map/fit/sta log，
本目录 output_*/receiver*.fit.summary、receiver*_corner*_*.rpt、
receiver*_check_timing.rpt 和 receiver*_unconstrained.rpt。

## 不能据此宣称的完成状态

- **完整板级时序未完成**：13 个 ADC 端口为虚拟引脚，缺 ADC 接线/相位/延迟；
  USB 使用零 PCB skew，缺实际走线/抖动预算。
- check_timing 保留 no_clock（Clearbox PLL 锁定事件寄存器）、ADC/LED 未约束、
  无虚拟时钟等问题。参考时钟 41.666667 ns 被工具截为 41.666 ns，记录该警告；
  名义采样率未作晶振校准。已约束路径余量为正不等于所有路径约束齐全。
- **上板、RF/ADC 实测、USB 连续吞吐、实际固件/驱动、音频和课程整机验收未验证**。
  没有生成下载文件、烧录 FPGA 或修改板卡固件。
- 32/40 MHz 换档为静态工程选择，动态切换未实现。FX2 是 USB 2.0；USB 3.0
  目标未由此工程兑现。FCR1 是独立提案，公共协议尚未冻结。

下一步硬件输入：ADC 完整料号及 MODE/DVDD、D[11:0]/CLK 到扩展口接线、供电
电平、板级延迟与时钟相位，之后移除对应虚拟引脚、补约束、重新实现并上板测试。
