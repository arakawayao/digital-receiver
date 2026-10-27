# ADS807E 两模式接收工程

入口：`receiver_ads807_dual.qpf`，顶层 `receiver_top`，器件 **EP4CE6F17C8**。
2026-10-20 按用户要求从相邻 `receiver_ads807` 原工程建立，原目录不修改。
本工程不依赖已移走的 `receiver_ads807_tri`，也不包含主机快照搜索模式。

## 两种模式

| 模式值 | 行为 |
| --- | --- |
| 1（上电默认） | FPGA 原过零检测器自动估频并配置 DDC；冷启动需获得合格估频结果 |
| 2 | 上位机输入88–108MHz整数Hz载频，FPGA计算NCO并启动DDC；无需估频locked |

自动模式已获得调谐参数后，失锁只降低可信度并标记保持超时，不清FIFO或复位DDC。
手动模式固定用户频道，QUALITY仅更新可信度；不会自动搜索或修改载频。
MODE切换、手动TUNE或自动大幅跳频重启DSP并增加epoch；小幅自动修正保留相位累加器。
NCO完成频率搬移，不保证与输入绝对相位对齐；AM包络/FM相位差解调允许常量相位。
不声称实现相干载波恢复。完整协议见 [PROTOCOL.md](PROTOCOL.md)。

## 参数与来源

原工程的 `rx_capture/rx_frequency/rx_nco/rx_cic/rx_fir/rx_dsp/rx_reset`、
NCO/FIR表和PLL原样复用。通信控制在项目已有TCM1/TRI1模块基础上收敛为两模式，
未复制原工程的db、旧时序报告、回放SOF或测试ROM。新工程输出与原工程分别保存。

| 项目 | 配置 |
| --- | --- |
| 参考/ADC时钟 | 24MHz / PLL ×29÷16 = 43.5MHz |
| 输入 | 单通道12位 offset-binary；FPGA内部转换为signed12 |
| 频率关系 | RF=87MHz+alias，88..108MHz对应alias1..21MHz |
| NCO | phase32，1024点signed12 Q1.11，I=x*cos，Q=-x*sin |
| CIC/FIR | 五级/87，59位模运算，SHIFT40饱和signed18；61tap Q1.17 |
| 输出 | 500kS/s，signed16，I后Q、小端，暂态66点标记 |
| FIFO | 512×288含每点元数据；容量1.024ms；满时丢当前点并累计，不覆盖旧样本 |
| USB | 24MHz FX2同步Slave FIFO，EP2 IN / EP6 OUT；IQ满帧约2.3063MB/s |
| 工具 | Quartus Prime18.1.0 Build625 / ModelSim SE2020.4 / Verilog-2001 |

2026-10-26 自动估频修复：`rx_frequency` 默认过零门限调整为 4，停止时由
`receiver_top` 清除估频状态，避免 AM 改频后沿用旧窗口。源码和候选 SOF 的哈希、
ModelSim 证据及未完成的上板验证见 host 的 `docs/AM_RESTART_DIAGNOSIS.md`；
不要把候选 SOF 视为已完成硬件验收。

ADS807E接口依据及模拟采样论证沿用 [原工程说明](../receiver_ads807/README.md)：
最高53MS/s、12位、转换延迟6拍。43.5MHz可使目标RF位于同一折叠区，仍需预选滤波、
抗混叠、VDRV电平及输入动态性能验证。ADC12位、OTR和时钟已按用户提供的P3原理图及
接线顺序全部配置物理引脚，电平标准3.3-V LVTTL，无ADC虚拟端口。
原板FX2/24MHz参考引脚继承自board_pins.tcl，待核对真实原理图及PCB延迟。

| ADC端口 | FPGA引脚 | P3物理脚号 |
| --- | --- | --- |
| adc_otr | PIN_A15 | 3 |
| adc_data[11]（MSB） | PIN_A14 | 5 |
| adc_data[10] | PIN_F11 | 7 |
| adc_data[9] | PIN_A13 | 9 |
| adc_data[8] | PIN_A12 | 11 |
| adc_data[7] | PIN_A11 | 13 |
| adc_data[6] | PIN_A10 | 15 |
| adc_data[5] | PIN_A9 | 17 |
| adc_data[4] | PIN_D8 | 19 |
| adc_data[3] | PIN_B7 | 21 |
| adc_data[2] | PIN_B6 | 23 |
| adc_data[1] | PIN_D11 | 25 |
| adc_data[0]（LSB） | PIN_E10 | 27 |
| adc_clk | PIN_D9 | 29 |

adc_otr为过量程预留输入，当前不参与DSP或USB协议；现有削顶标志仍来自DSP饱和检测。

ADC输入/输出延迟与采样相位尚未做板级签核；位置已配置不等于ADC接口时序已完成验证。

## 上位机

从项目根目录启动现有桌面工作台：

```powershell
& D:/conda_envs/ads807_host/python.exe -B -m host.ads807
```

选择USB和“手动载频”，输入例如98.000000MHz，点击开始。
连接流程为QUERY→MODE(2)→HOLD→TUNE(98000000)，收到ACK后接收I/Q。
选择“FPGA自动估频”则MODE(1)，由FPGA自行取得载频。
运行期间要改模式或载频，先停止后重新开始；停止会等待STOP ACK。
音频默认关闭，程序不会自动烧录FPGA。原FCR1和历史TRI1文件仍支持回放。

## 构建与验证

### USB 控制实板测试（ADC 未接入）

从项目根目录执行以下命令，打开实际 Qt 窗口并运行控制边界检查及 60 秒命令往返：

```powershell
& D:/conda_envs/ads807_host/python.exe -B -m host.ads807.dual_control_test --seconds 60
```

此入口会检查数据 USB，随后通过 USB-Blaster 下载
`.harness/receiver_ads807_dual/quartus/receiver_ads807_dual.sof` 到 FPGA 易失配置，
不写 Flash。需要已有该 SOF；不会自动重新构建。浏览器同步画面地址打印为 `PREVIEW_URL`。
测试覆盖两模式、88/98/108 MHz 手动参数及异常命令 ACK；接收的 I/Q 仅计数，
不作为 ADC、估频、AM/FM 或持续数据吞吐验证。失败立即停止，不自动重连或重发。
测试结束后保持窗口和页面开启，结果及 SOF/源文件哈希在
`.harness/receiver_ads807_dual/board_control/<时间>/`。

### 离线检查

以下命令从 `D:/class_project` 执行，均不连接USB、不烧录、不播放物理音频：

```powershell
& D:/conda_envs/ads807_host/python.exe -B main_project/fpga/receiver_ads807_dual/scripts/check_style.py
& D:/conda_envs/ads807_host/python.exe -B main_project/fpga/receiver_ads807_dual/scripts/dsp_reference.py
& D:/conda_envs/ads807_host/python.exe -B main_project/fpga/receiver_ads807_dual/scripts/simulate.py
& D:/conda_envs/ads807_host/python.exe -B main_project/fpga/receiver_ads807_dual/scripts/host_check.py
& D:/conda_envs/ads807_host/python.exe -B main_project/fpga/receiver_ads807_dual/scripts/build.py
```

build执行map/fit/多工况STA，**不执行asm或programmer**；报告在项目根`.harness/receiver_ads807_dual/`。
最终资源/时序和验证边界见 [VALIDATION.md](VALIDATION.md)。当前可装入EP4CE6，但逻辑余量很小。

新检查已注册harness，可在上述Python环境运行：

```powershell
python -B -m harness.runner run --jobs 3 --task receiver-ads807-dual-quartus
```

该任务会按依赖运行新工程检查和上位机测试；无须运行历史三模式ROM任务。
