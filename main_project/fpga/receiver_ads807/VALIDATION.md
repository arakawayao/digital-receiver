# 构建与验证记录

日期：2026-10-17。入口 `receiver_ads807.qpf`，顶层 `receiver_top`。
源工程为相邻 `receiver`，本次新建独立目录；没有改动原接收工程或上位机。
工作目录没有 Git 仓库，未初始化仓库，不能提供 Git 差异作为历史基线证据。

## 工具和重建

- Quartus Prime Standard 18.1.0 Build 625，安装目录 `D:/intelFPGA/18.1/quartus`。
- ModelSim SE 2020.4，安装目录 `D:/modeltech64_2020.4/win64`。
- 验证脚本使用 Python 标准库；`filter_check.py` 另需 NumPy。
- 目标 Cyclone IV E EP4CE10F17C8 沿用原工程当前 QSF，实物型号仍待核对。
- `ip/rx_pll_ads807.v` 由本机 Clearbox 生成，固定 24 MHz 输入及 43.5/24 MHz 输出。
  重新生成命令见下；`rx_fifo.v` 和 `rx_ifclk.v` 保留原 receiver 的生成代码，
  分别为 512×97 DCFIFO 和输出时钟 DDIO，没有手改生成代码。

在 `D:/class_project` 运行：

```powershell
python -B main_project/fpga/receiver_ads807/scripts/generate_ip.py
python -B main_project/fpga/receiver_ads807/scripts/check_style.py
python -B main_project/fpga/receiver_ads807/scripts/simulate.py
python -B main_project/fpga/receiver_ads807/scripts/build.py
```

安装 NumPy 的 Python 可运行：

```powershell
python -B main_project/fpga/receiver_ads807/scripts/filter_check.py
```

本机滤波检查实际使用带 NumPy 的 bundled Python：
`C:/Users/yjj/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`。
脚本支持用 `--quartus`、`--modelsim` 指定已有工具路径。
`build.py` 执行 map、fit 和多工况 STA，不执行 assembler，不生成可下载 SOF。
构建结果位于根目录 `.harness/receiver_ads807/`；TimeQuest 详细报告位于工程目录。
这些输出可再生成，不属于硬件交付源文件。

## 已完成的检查

声明/赋值格式检查：15 个手写 RTL 和 testbench 文件通过。
检查逐信号声明、逐语句一行和 wire 声明不内联赋值；Intel 生成 IP 不手工格式化。

ModelSim 完整仿真通过。单项通过 ADC 全部 4096 个码值转换、实际 PLL 43.5/24 MHz 输出，
以及 7 个测频场景（88/108 MHz 单音、100.7 MHz FM、93.37 MHz AM，
静默、直流和弱输入拒锁）。这些是合成输入的数字行为检查。

DSP 共 261046 拍与独立整数参考逐拍一致，包含全 ADC 码域、随机输入、
enable 间断、复位、六个 RF 单音点及 AM/FM/静默。另对 2001 个 RF 网格点
检查正 alias 的参考换算，这不是 2001 点硬件测频测试。
AM 深度为 0.499664（输入 0.5），FM 瞬时频偏范围约 -25010.63 至 +25000.87 Hz
（输入正弦调频 ±25 kHz）；这些检查验证 DDC 输出，没有实现上位机音频链。

整链使用实际生成的 PLL、DCFIFO、DDIO，直接驱动 ADC 总线，未注入 RF/LO 真值。
98 MHz AM 输入自主估计为 98000118 Hz；锁定后连续 3 ms 获得 1499 对 I/Q，
间隔均为 87 个 ADC 时钟，正常路径无溢出。6656 字节组成 13 个完整 USB 帧，
CRC、序号、样本连续性、采样率/SHIFT/方向字段检查通过，载荷逐样本对照
真实 DUT FIFO 写入值通过。随后静默 4 ms 正常失锁。
最终整链仿真用时约 6 分钟，结果见 `simulation/summary.json` 和各模块日志。

量化滤波系数的双精度响应检查通过：五级 CIC /87 增益 4984209207，
59 位回绕、SHIFT40；通带 0–100 kHz 为 -0.000809 至 +0.001134 dB，
输出阻带 150–250 kHz 最大 -96.839 dB，首折叠区最大 -63.096 dB。
全幅单载波的 I/Q 幅度估计约 9497 码。结果见 `filter/summary.json`，
响应模型不包含 ADC 非线性、时钟抖动和模拟前端损伤。

Quartus map/fit/STA 均返回 0，资源占用如下：

| 资源 | 使用量 |
| --- | --- |
| 逻辑单元 | 4043 / 10320，39% |
| 寄存器 | 2900 |
| 存储位 | 71242 / 423936，17% |
| 9 位乘法器单元 | 12 / 46，26% |
| PLL | 1 / 2 |
| 虚拟引脚 | 13 |

多工况已约束路径的最小裕量（ns）：

| 工况报告 | Setup | Hold | Recovery | Removal |
| --- | ---: | ---: | ---: | ---: |
| corner1 | 1.661 | 0.424 | 18.520 | 1.335 |
| corner2 | 2.083 | 0.401 | 18.776 | 1.197 |
| corner3 | 3.976 | 0.145 | 20.828 | 0.550 |

当前 SDC 无未匹配约束警告。TimeQuest 将参考周期截到 41.666 ns，保留其警告。
`report_ucp` 仍有 12 个 ADC 输入和 adc_clk、led 两个输出未约束；
`check_timing` 另列异步 rst_n/usb_pa1、常量 usb_pa0、时钟 usb_pclk 的 I/O 提示，
生成 PLL 的 pll_lock_sync 无时钟提示，以及 held metadata 只有 max_delay 的提示。
因此上述正裕量只代表已约束路径，不能称为全设计或板级时序签核。

## 约束与修正依据

恢复源测频器被注释的 acquire_state 启动赋值，统一 ADC_RATE 与实际 PLL。
ADC 总线先寄存，再分给测频及 DSP。43.5/24 MHz 的相关时钟最近边沿很接近，
初次 STA 发现复位释放及稳定元数据跨域路径失败，随后：

- 仅复位两级同步器使用异步复位，启动计数器在本地同步清零。
- RF/phase 在锁定期间保持，locked 经两级同步后才允许读取；
  流启动再等待 32 拍。只对该稳定总线限定 20 ns 最大延迟。
- 仅对明确的首级控制同步器和复位同步入口设置时序例外；
  没有全时钟域 false path，也没有屏蔽 ADC 数据路径或降低目标频率。

初期全层级波形记录导致整链仿真超时，最终流程不记录全层级 WLF。
Intel 生成 FIFO 的仿真有 clock 端口类型兼容警告，须与真实运行结果一同解读。

## 额外静态门禁与未验证项

最终源码运行 readable-verilog-generator 严格门禁，结果未通过：

| 门禁 | 结果 |
| --- | --- |
| compile | passed，10 个模块无静态解析错误 |
| ast | failed，formatter 规范未满足，不是解析通过的反证 |
| readability | failed |
| comment | failed |
| naming | failed |
| profile | failed |
| testbench | not_requested（门禁内；实际 ModelSim 单独记录） |
| toolchain | not_requested（门禁内；实际 Quartus 单独记录） |

共 3355 errors、50 strict warnings，见 `.harness/receiver_ads807/quality/gate.json`
及 `gate.md`。诊断含该技能的文件头、注释、命名、FSM/组合深度要求，
也含外部 IP 接口未知和驱动/握手分析；不能将这些诊断概括为全部无害或已修复。
用户指定三条行级规则通过，不代表此额外门禁通过。
技能依赖 erie-remote-ssh、指定 WaveDrom renderer 未就绪，未安装、未做远程验证。
各模块 spec 的 WaveJSON 仅为概念时序，未渲染为通过 renderer 的波形图。

ADC 物理引脚、电平、采样相位、PCB 时钟/数据往返延迟待接线表和实物核对，
没有凭数据手册 t1/t2 编造外部延迟。FX2 约束沿用源板依据，PCB skew 仍假定为零。
尚未验证持续 USB 反压、FIFO 满/溢出恢复、暂停重启、真实 ADC/USB、上板接收、
上位机协议适配及实时放音。离线仿真和 STA 不代表端到端接收机完成。
