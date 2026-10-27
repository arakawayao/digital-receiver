# USB 无 ADC 回放测试

本测试链路：电脑生成 ADC12 样本 → EP6 OUT 上传 → FPGA RAM 以 56 MHz 循环播放 → 56 MHz 配置的自动选频、NCO、FIR → 500 kS/s I/Q → EP2 IN → 电脑校验。

这是 `receiver_loop.qpf` 的 **56 MS/s、12 位回放测试链路**，和ACM2108 实际 ADC 的 `receiver56.qpf`（32 MS/s、8 位）配置不同，也和根目录以前的 240 MHz 扫描工程不同。测试使用相同的接收 DSP，滤波总通带 200 kHz（±100 kHz）。没有真实 ADC 时，可以验证数字处理、端点方向和数据格式；不能验证模拟前端。

## 端点与固件必须对应

| 用途 | 主机端点地址 | FPGA FIFOADR | 固件要求 |
|---|---|---|---|
| 电脑上传 ADC 样本 | 0x06，EP6 OUT | 2'b10 | EP6 配置为 OUT |
| FPGA 返回应答和 I/Q | 0x82，EP2 IN | 2'b00 | EP2 配置为 IN |

IN/OUT 以电脑为参照。2026-10-13 已通过官方 CyUSB.dll 读取板卡实际描述符：04B4:1004，EP6 OUT=0x06、EP2 IN=0x82，512 字节高速 Bulk。FLAGB 写许可、FLAGC 读许可沿用板卡原示例，设备描述符本身不显示 FLAG 寄存器配置。

本实现约定：

- 同步 Slave FIFO、8 位数据总线；FPGA 向 FX2 提供 24 MHz IFCLK。FX2 必须选择外部 IFCLK，不能同时驱动该引脚。
- 用户提供的 bulkloop.iic 使用索引标志（PINFLAGSAB=PINFLAGSCD=0）：FLAGB 高表示当前所选 FIFO 非满，FLAGC 高表示当前所选 FIFO 非空。FPGA 必须先选中 EP6 并等待标志稳定，再判断能否读取。
- SLRD、SLWR、SLOE、SLCS 低有效。
- 高速 USB Bulk，512 字节包；EP6 AUTOOUT，EP2 AUTOIN，自动提交长度 512 字节。
- 测试版本忽略 PA1，使用 START/STOP 命令控制回放；普通 ADC 版本保留原 PA1 控制。

本次保留现有 Cypress CYUSB3 驱动及固件，没有刷写 FX2。上位机默认自动优先使用本机 SDK 的 CyUSB.dll，可显式指定 --backend cyusb。

## 文件与使用步骤

1. Quartus 打开 `receiver_loop.qpf`，顶层 `receiver_loop_top`，编译后下载 `output_loop/receiver_loop.sof`。这个测试顶层没有 ADC 管脚，仍使用 56 MHz PLL 和 `rtl/fir_coeff56.hex`。板卡和 USB 管脚沿用当前 receiver 工程。
2. 当前设备使用 Cypress CYUSB3 驱动：安装 pythonnet，并使用官方 CyUSB.dll。用户当前 bluetooth 虚拟环境中已安装 pythonnet；不需更换驱动。PyUSB/libusb 作为可选后端保留。
3. 在 receiver 目录运行，VID/PID 必须替换为实际设备值：

```powershell
python host/usb_replay.py generate --kind am --output validation/my_am
python host/usb_replay.py run --kind am --vid 0x实际VID --pid 0x实际PID --output validation/my_am
```

上面的 VID/PID 是占位说明，不能原样执行。生成文件不需要 USB 或 PyUSB。AM 默认调制度 0.5；FM 测试使用 `--kind fm --deviation 25000`。

脚本会 STOP、BEGIN、逐块 DATA、START；每条命令都等待 FPGA 应答，然后收集 16 帧 I/Q、STOP 并检查结果。输出：

- `manifest.json`：实际测试载频、采样率、调制参数。
- `capture.bin`：收到的原始 FCR1 数据帧。
- `iq.csv`：样本序号、I、Q、估计频率、频率控制字。
- `result.json`：CRC/连续性通过后的 AM 深度或 FM 频偏等检查结果。

采集后可重复检查：`python host/usb_replay.py check --output validation/my_am`。

需要持续做 USB 回环时，在 `run` 参数中增加 `--continuous`，例如：

```powershell
python host/usb_replay.py run --kind am --backend cyusb --fx2-init none --vid 0x04B4 --pid 0x1004 --continuous --frames 16 --output validation/my_am
```

按 Ctrl+C 结束。每一回合重新上传同一段 ADC 测试波形，接收并校验 16 帧 I/Q；`capture.bin`、`iq.csv` 和 `result.json` 只保留最近一回合，避免文件无限增长。回合之间会短暂停止回放。这是周期性上传与采集，不能代替 56 MS/s 不间断的新 ADC 数据流，也不能验证 ACM2108/32 MHz 接口。

AM、FM 轮流上传和校验可使用 `--kind alternate --continuous`：

```powershell
python host/usb_replay.py run --kind alternate --continuous --backend cyusb --fx2-init none --vid 0x04B4 --pid 0x1004 --frames 16 --output validation/my_alternate
```

顺序为 AM → FM → AM → FM，直到 Ctrl+C。默认 AM 请求载频 100.7 MHz，FM 请求载频 101.7 MHz；可用 `--rf` 修改 AM、`--fm-rf` 修改 FM（单位 Hz）。实际回放频率会对齐到 8192 点周期的频率栅格，并在每回合日志及各自的 `manifest.json` 中显示。AM 和 FM 最近一回合的 `manifest.json`、`capture.bin`、`iq.csv`、`result.json` 分别保存在 `validation/my_alternate/am` 和 `validation/my_alternate/fm`，可分别用 `check --output` 复查。

`generate` 另输出 `adc_u16le.bin`（12 位偏移二进制放在小端 16 位字中）和 `upload.bin`（37 条完整上传命令）。自己写上位机时，应每次发送一条 512 字节命令并等待应答，而不是直接一次写入整个文件。

## 为什么先上传再播放

56 MS/s × 2 字节 = 112 MB/s，不能依靠这个 FX2 接口实时输入每个 ADC 样本。FPGA 先存最多 8192 点，再按固定采样时钟循环读取；USB 的间隔不进入 ADC 时间轴。

默认长度 8192，周期约 146.286 μs。为使循环边界连续，载波和调制频率取这个周期的整数频点：请求 100.7 MHz，实际生成约 **100.7001953125 MHz**；调制频率约 **6.8359375 kHz**。这是一段周期测试信号，适合验证 AM/FM，不是任意长度音乐的实时传输。比较检测结果时使用 manifest 中的实际载频。

## RTL 分工

| 文件 | 用处 |
|---|---|
| rtl/receiver_loop_top.v | 无 ADC 管脚的测试顶层，启用 USB_REPLAY |
| rtl/receiver_top.v | 切换真实 ADC / RAM 回放源，共用选频和 DSP；按完整 512 字节帧切换命令与数据 |
| rtl/rx_usb_replay.v | 命令校验、暂存、RAM 写入、跨时钟启动/停止、ADC 循环回放、应答 |
| rtl/rx_fx2_duplex.v | EP6 读取 / EP2 写入、总线三态和方向切换、FLAG 流控 |
| rtl/rx_fx2.v | 普通 ADC 工程的单向发送；也已改为 EP2 IN |
| host/usb_replay.py | 波形生成、上传、读取、CRC、帧序号、幅度/频偏检查 |
| scripts/usb_loop_check.py | ModelSim 回环及独立整数 DSP 参考比对 |
| verification/fifo_model.v | 长仿真的功能级 FIFO，仅用于测试，Quartus 工程不包含它 |

## 上传协议 RPL1

每条命令 512 字节，小端；末尾 CRC32/IEEE 为前 508 字节的 zlib.crc32。

| 字节偏移 | 内容 |
|---|---|
| 0 | ASCII RPL1 |
| 4 / 6 | u16 版本 1 / u16 操作码 |
| 8 | u32 命令序号 |
| 12 | u32 参数 |
| 16 | u32 样本数 |
| 20、24 | 保留，必须为 0 |
| 28..507 | 最多 240 个 u16 ADC 样本，范围 0..4095；未使用处补 0 |
| 508 | u32 CRC32 |

操作码：1 BEGIN（参数=总长度 1..8192）；2 DATA（参数=顺序写入偏移，样本数 1..240）；3 START；4 STOP。除 DATA 外样本数为 0，START/STOP 参数为 0。未上传完整不能 START。CRC、顺序或 ADC 码值错误不提交暂存数据。重新上传先 BEGIN，STOP 后也可以再次 START 播放同一段数据。

应答也是 512 字节：RPA1、u16 版本 1、u16 状态、u32 原命令序号、u32 操作码、u32 已上传点数、u32 总长度、u32 运行状态；其余补 0，末尾 CRC32。状态 0 成功、1 CRC 错、2 头/操作码错、3 范围或顺序错、4 ADC 超范围、5 未准备好。

回传 I/Q 沿用 **FCR1 v3**：60 字节头 + 最多 112 组 I16/Q16 + CRC32，共 512 字节，500 k 组/秒。此回放工程头部报告 ADC_RATE=56 MHz、混频右移 7；实际 ACM2108 工程报告 32 MHz、右移 3。不能把整个 USB 包都当成 I/Q。脚本忽略启动前 32 组用于调制测量，并检查首帧/首样本从 0 开始、连续序号、丢样和削顶标志。

## 仿真与验证范围

```powershell
python scripts/usb_loop_check.py am
python scripts/usb_loop_check.py fm
python scripts/usb_loop_check.py am --real-fifo
```

默认使用真实 Intel PLL、DDIO 和功能级异步 FIFO 模型来缩短运行时间；`--real-fifo` 使用工程中的 Intel FIFO 仿真模型，明显更慢。两种模式都运行实际接收 RTL。测试包括 USB 引脚方向/延时、错误命令拒绝、上传 RAM 的每个回放样本、I/Q 与独立整数模型逐点比对、帧 CRC 和序号、自动频率估计、AM 或 FM 参数。

测试结果在 `validation/usb_loop_am`、`validation/usb_loop_fm`，真实 FIFO 选项另加 `_real`。`PASS` 代表所列数字测试通过，不代表已经完成实际 FX2 固件和电脑驱动的联调。SDC 使用芯片手册时序及零板级偏斜假设，真实 PCB 时序仍需按硬件核实。

芯片接口配置可对照 Infineon 官方 [AN61345：FX2LP Slave FIFO 接口](https://www.infineon.com/assets/row/public/documents/24/42/infineon-an61345-designing-with-ez-usb-fx2lp-slave-fifo-interface-applicationnotes-en.pdf)。电脑端依赖说明见 [PyUSB 官方 FAQ](https://github.com/pyusb/pyusb/blob/master/docs/faq.rst)。


## 当前板卡的 PyCharm 参数（2026-10-13 更新）

先下载本次重新编译的 `output_loop/receiver_loop.sof`，旧 EP6 IN 版本不能用于当前固件。保留当前 bluetooth Python 解释器；脚本形参填写：

```text
run --kind am --backend cyusb --vid 0x04B4 --pid 0x1004 --output D:/diansai/gongjiaogao/receiver/validation/my_am
```

仅检查连接和端点，不上传样本时：

```text
probe --backend cyusb --vid 0x04B4 --pid 0x1004
```

换到新 Python 环境后，安装 `python -m pip install pythonnet`。当前 bluetooth 环境已安装。脚本自动查找 Cypress/EZ-USB FX3 SDK 中的 `CyUSB.dll`，也可用 `--cyusb-dll` 指定路径。官方 DLL 同时支持当前 FX2 芯片。

`host/usb_transport.py` 封装 Cypress 与 PyUSB 后端，固定为 EP6 OUT 0x06 上传、EP2 IN 0x82 回传。当前驱动为 Cypress CYUSB3；不需要替换成 WinUSB，也不要更改 USB-Blaster 驱动。

## EP6 首次发送失败时的诊断

若设备已识别但第一条 STOP 命令发送失败，尚未进入 ADC 上传或 DSP 测试。997 本身不能唯一判定根因；脚本现在会打印命令序号、实际耗时和请求/完成字节数，区分 OUT 发送失败与 IN 应答超时。

原厂 USB_Demo 的播放流程先发送设备级 Vendor OUT 0xA9，再发送 0xA8（Value/Index/长度均为 0）。可以按原厂顺序重试：

```text
run --kind am --backend cyusb --fx2-init none --vid 0x04B4 --pid 0x1004 --output D:/diansai/gongjiaogao/receiver/validation/my_am
```

上述命令使用 none，不发送 A9/A8。旧 fcore2s 选项仍保留并打印警告，仅供确知固件支持该流程时使用。FPGA 回放由 RPL1 START/STOP 控制；本次 indexed FLAG 修正需要重新下载新生成的 SOF。


### bulkloop.iic 实测文件审查后的修正

A9 会复位 EP2/EP6，但没有重新切换 EP6 AUTOOUT；A8 只置位 PA1。因此上面复测命令使用 none，不执行旧的 A9/A8 序列。先重新上电并下载新版 SOF。原有固定 FLAG 假设已修正为 indexed FLAG，测试模型也已修正。完整证据见 validation/bulkloop_firmware_review.md。文件静态检查不能证明板上运行的固件字节与之完全一致。

