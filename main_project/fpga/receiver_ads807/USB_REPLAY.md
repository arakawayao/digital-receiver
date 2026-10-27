# EP4CE6 无 ADC 的 USB 回放测试

本轮实际结果见 [REPLAY_VALIDATION.md](REPLAY_VALIDATION.md)：AM/FM 仿真、9项软件测试及
EP4CE6 SOF 构建已通过；已成功下载并完成AM/FM实板512帧测试，重新上电后FM→AM→FM
连续三轮通过。此前曾有首条STOP等待ACK超时，仅重下SOF未恢复，重新上电后恢复；根因待查。

2026-10-19 用户确认实际 FPGA 为 **EP4CE6F17C8**，先做内部 RAM 回放。
独立工程 `receiver_replay.qpf`，顶层 `receiver_replay_top`；无 ADC 数据/时钟端口，
不需要外部跳线，未用引脚设置为输入三态。本测试不替代 ADC 或模拟前端实测。

## 链路与参数

电脑生成 ADC12 样本 → FX2 EP6 OUT `0x06` → 8192×12 RAM → 43.5 MHz 循环回放
→ FPGA 自主过零估频 → ADS807 DDC / CIC / FIR → 500 kS/s I/Q → EP2 IN `0x82`
→ 电脑 CRC、连续性校验、实际 AM/FM 识别和参数测量。

三模式工程此前拟合需要 7535 LE，超过 EP4CE6 的 6272 LE，因此本次采用单模式自主估频。
复用 `receiver_ads807` 的 DSP、PLL、FIFO、FCR1 v2 封装，及相邻
`receiver_v2/rtl/rx_usb_replay.v`、`rx_fx2_duplex.v` 的上传与双向 USB 控制。
应保留这些相对目录，不能单独移动 QPF。

| 参数 | 当前测试配置 |
| --- | --- |
| 参考/采样/USB 时钟 | 24 MHz / 43.5 MHz / 24 MHz |
| 输入样本 | 单通道 ADC12 offset binary，上传为小端 u16，高 4 位为 0 |
| RF 映射 | 正别名，RF = 87 MHz + alias，88..108 MHz 是数字测试标签 |
| 混频 | I=x*cos，Q=-x*sin，不共轭 |
| 抽取 | 五级 CIC /87，59 位模回绕，SHIFT=40，61 tap Q1.17 FIR |
| I/Q 输出 | 500 kS/s，I16/Q16，饱和至有符号 16 位 |
| 输出帧 | FCR1 v2：512 B = 60 B 头 + 最多 112 对 I/Q + CRC32 |
| 上传/应答 | RPL1/RPA1，512 B，小端，CRC32/IEEE 覆盖前 508 B |
| 启停 | RPL1 START/STOP，PA1 不控制回放 |

43.5 MS/s 按 u16 连续上传需 87 MB/s，因此先上传再回放。
8192 点周期约 188.322 us，默认调制单音约 5310.059 Hz；默认请求 98 MHz，
实际周期栅格载频为 98.00244140625 MHz，比较时以 manifest 实际值为准。
本测试不是实时上传任意音乐，也不是同时采集整个 88..108 MHz 频段。
FCR1 满帧吞吐约 2.286 MB/s，25% 余量后 2.857 MB/s，USB 协议开销另计。
512 点 FIFO 仅约 1.024 ms，主机阻塞可造成丢样，脚本会拒绝不连续结果。

## 构建与烧录

在 `D:\class_project` 执行：

```powershell
& 'D:\conda_envs\ads807_host\python.exe' -B main_project/fpga/receiver_ads807/scripts/replay_build.py
```

默认 Quartus Standard 18.1，可用 `--quartus` 指定已安装目录。
SOF：`D:\class_project\.harness\receiver_replay\quartus\receiver_replay.sof`。
`build.json` 记录目标器件、SHA256 和最小 STA 裕量。
Quartus Programmer 用 Auto Detect 核对 EP4CE6 后，通过 USB-Blaster 下载 SOF。
SOF 为易失配置，断电后需重下载；本流程不写配置 Flash、不刷 FX2 固件。

USB 引脚来自 `board_pins.tcl` 的 FCore2S E6 原理图与原厂示例。
FX2 应为外部 24 MHz IFCLK、同步 8 位 Slave FIFO、indexed FLAG、EP6 AUTOOUT /
EP2 AUTOIN、512 B 高速 Bulk；FLAGB=当前 FIFO 非满，FLAGC=当前 FIFO 非空。
FPGA 输出 IFCLK，FX2 不能同时驱动。描述符不能证明以上寄存器配置正确。
使用现有 Cypress 驱动与 SDK CyUSB.dll；不换驱动，不发 A8/A9 Vendor 命令。
旧资料包的 USB Control Center/CyUSB.dll 在当前环境枚举出现 OverflowException，
脚本默认使用本机 Cypress SDK DLL，已确认其能正常枚举（当前未找到匹配设备）。

## 上板测试

在项目根目录运行；默认 VID/PID 为 04B4:1004，可按实物覆盖：

```powershell
& 'D:\conda_envs\ads807_host\python.exe' -B main_project/fpga/receiver_ads807/host/replay.py probe
& 'D:\conda_envs\ads807_host\python.exe' -B main_project/fpga/receiver_ads807/host/replay.py run --kind am --output .harness/receiver_replay/live_am
& 'D:\conda_envs\ads807_host\python.exe' -B main_project/fpga/receiver_ads807/host/replay.py run --kind fm --output .harness/receiver_replay/live_fm
```

每次 STOP → BEGIN → DATA（每条最多 240 点、逐条 ACK）→ START → 收默认 512 帧
→ STOP → 验证。约 114.7 ms I/Q，足够桌面工作台完成多个识别窗口；`--frames` 支持 16..4096。
超时不盲目重发；START 已发送后异常会尝试 STOP，失败则报告状态未知。
有界解码缓冲 64 KiB，待消费记录最多一个 USB 读取块；本工具正常结束时停止回放。
输出 manifest.json、原始 capture.bin、iq.csv 和 result.json；失败写 FAIL，不伪造采集。
生产识别函数只看 I/Q 和 LO，标签仅作后验检查。
载频误差 12 kHz、AM 深度误差 0.05、FM 频偏误差 max(1500 Hz,10%) 为原型自检阈值，
不是课程正式指标或真实射频性能保证。

启动根目录 `host/ads807/run.ps1`，选择文件回放和 capture.bin，可查看解调、FFT、I/Q。
测试期间不要同时从 GUI 连接 USB：GUI 实时控制为 TRI1，与本 FCR1 v2 回放工程不同。

## 验证与限制

```powershell
& 'D:\conda_envs\ads807_host\python.exe' -B main_project/fpga/receiver_ads807/scripts/replay_check.py am
& 'D:\conda_envs\ads807_host\python.exe' -B main_project/fpga/receiver_ads807/scripts/replay_check.py fm
& 'D:\conda_envs\ads807_host\python.exe' -B -m harness.runner run --jobs 3 --task receiver-replay-build
```

ModelSim 使用真实 Intel PLL、DDIO、异步 FIFO 和带 13.5 ns FLAG / 15 ns 数据延时的 FX2 模型。
检查错误 CRC、未完整上传 START 拒绝、逐条 ACK、每个回放样本、87 拍 I/Q 间隔、
无溢出、USB 有效载荷与 DUT I/Q 逐点一致，以及生产 AM/FM 测量。
STOP 可以中断尾帧并补齐 512 B，分析只使用停止前的前 16 个完整帧。
SDC 依据 CY7C68013A 外部 IFCLK 时序，PCB 偏斜暂按 0；LED 是唯一未约束输出。
这些检查均不替代实板 USB、板级时序、长时间接收或物理音频测试。

技能 erie_strict 门禁与项目端口命名、空格缩进及 IP 闭包规则不一致，本轮未通过，
报告在 `.harness/receiver_replay/style.json`；不声称通过该门禁。
项目行级风格、ModelSim 功能、Quartus 构建和实际硬件结果分别报告。
