# ADS807E 独立接收工程

2026-10-19 新增 EP4CE6F17C8 无 ADC 的独立 `receiver_replay.qpf`。
43.5 MHz 内部 RAM 回放、USB 上传/回传及操作见 [USB_REPLAY.md](USB_REPLAY.md)。
下列原 ADC 工程保留；其 EP4CE10 目标不是用户最新确认的测试板型号。

本工程从 `../receiver/` 的接收链派生，原目录和 `receiver_v2` 均不修改。
入口为 `receiver_ads807.qpf`，顶层为 `receiver_top`。用户确认采用
43.5 MS/s，并暂留 ADC 虚拟引脚。目标器件暂沿用源工程 QSF 的
EP4CE10F17C8；这不是对实物核心板型号的确认。

## 参数和硬件依据

TI ADS807 数据手册 SBAS072A（2002-07），官方来源：
https://www.ti.com/lit/ds/symlink/ads807.pdf

- 12 位 Straight Offset Binary；RTL 将 MSB 翻转为 signed12。
- 最高 53 MS/s，转换延迟 6 个 ADC 时钟，输入在 CLK 上升沿采样。
- 数据保持时间最小 2.7 ns，新数据延迟最大 12 ns（指定负载条件）。
- 模拟供电 5 V；VDRV 是独立数字输出驱动电源，不能将 5 V 输出直接接入
  本工程假定的 3.3 V FPGA Bank。实际 VDRV、电平、OE、布线负载需硬件核对。
- 270 MHz 模拟带宽不保证 88–108 MHz 实际接收性能。需要射频预选、适当驱动、
  低抖动时钟以及真实输入电平/调制条件的测试。

| 项目 | 配置 |
| --- | --- |
| FPGA 参考时钟 | 源板资料中的 24 MHz，实板待核对 |
| ADC 时钟 | PLL 24 MHz ×29/÷16 = 43.5 MHz，50% 占空比 |
| ADC 接口 | 单通道 12 位，无反压；adc_data[11] 对应 ADS807 Bit 1/MSB |
| RF 假定范围 | 88–108 MHz 单个被预选的载波；不是同时采集完整 20 MHz |
| alias | +1…+21 MHz，RF = 87 MHz + alias |
| NCO | phase32，1024 点 signed12 Q1.11；I=x*cos，Q=-x*sin，无共轭 |
| CIC | 五级 /87，59 位模运算，右移 40 位，饱和 signed18 |
| FIR | 61 tap signed18 Q1.17，500 kS/s，63 个 FPGA 时钟延迟 |
| I/Q 输出 | 500 kS/s，signed16，I 后 Q，小端 |
| FIFO | 原工程 512×97 异步 FIFO；满时丢当前样本并累计计数 |
| USB | 原板 FX2，24 MHz 同步 Slave FIFO，EP2 IN |

43.5 MHz 的该奈奎斯特区为 87–108.75 MHz。88 MHz 下边界余量 1 MHz，
108 MHz 上边界余量 750 kHz；候选信号带宽为中心 ±100 kHz，滤波过渡
100–150 kHz。前端必须抑制其他混叠区，RF 字段不是无先验的唯一测频结果。

每 65536 点为一个测频窗口（约 1.507 ms），连续两个合格窗口锁定。
一 count 为约 663.757 Hz，两窗平均的 NCO 量化间距约 331.879 Hz；这不是精度保证。
保留幅度、迟滞、削顶和周期分散检查，允许失锁/无有效流。

## 协议与连续性

沿用原接收工程 FCR1 v2：512 字节，60 字节头、最多 112 对 I16/Q16 和 CRC32。
ADC_rate=43500000，IQ_rate=500000，RF 字段为本地估计值，phase_step 为自动 LO，
flags.bit1=0 表示本工程不共轭，offset 48 的 CIC_SHIFT=40。
其他序号、epoch、样本索引、累计丢样及部分帧补零语义沿用原工程。
这是工程内协议，不修改公共离线 IQ JSON 契约。上位机需读取帧头，不能硬编码
56 MHz、32 MHz、SHIFT42 或强制共轭；上位机适配另行协调。

满帧线速为 500000/112×512 = 2.285714 MB/s，25% 余量为 2.857143 MB/s。
空 FIFO 容量为 1.024 ms I/Q；不等于任意主机停顿容许值。失锁和 PA1 暂停
清流并重启 epoch；FIFO 满导致 index 缺口，不静默拼接成连续数据。

## 工程与验证

仅 `rtl/` 中手写 Verilog 遵循逐信号声明、逐条赋值、wire 与 assign 分离。
`ip/` 是 Intel Clearbox 生成代码，禁止手工修改其内部布局和逻辑。
ADC 的 13 个数据/时钟端口均为 VIRTUAL_PIN，未分配真实引脚或假定 I/O 延迟。
SDC 约束内部时钟和源板 FX2 接口，保留板级 ADC、PCB skew 等未完成边界。
不能直接把此工程作为可下载验收版本。

项目根目录下的命令与实际验证结果见 `VALIDATION.md`。不注册或修改共享 harness。
