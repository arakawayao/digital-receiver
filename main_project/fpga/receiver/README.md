# FCore2S 自主数字接收机：固定 56 MHz

2026-10-04 按用户最新更正重构。**ADC 采样时钟由 FPGA PLL 提供，固定 56 MHz；
FPGA 自行估计输入频率并设置数字本振。上位机接收处理后的 I/Q，再做 AM/FM
识别、解调和放音，不下发调谐频率或 NCO 配置。**

当前入口为 [receiver56.qpf](receiver56.qpf)，顶层 `rtl/receiver_top.v`。
32/40 MHz、EP6 RCF1 调谐及其测试结果已废止为当前方案，历史资料在
[legacy_32_40/](legacy_32_40/)。历史结果不能作为本版本验证证据。

## 依据与硬件边界

实际工具为 Quartus Prime 18.1.0 Build 625 Standard、ModelSim SE-64 2020.4。
板卡资料来自 `ETree_FCore2S_Board/`：核心板原理图第2/4页及引脚表确认
EP4CE6F17C8、24 MHz U3、3.3 V VCCIO、CY7C68013A；USB实现参考
`08_USB_FIFO_WR.zip`、`USB2.0/Firmware/Bulkloop/bulkloop.c` 和芯片同步 FIFO 时序。

ALTPLL 由本机 Quartus Clearbox 生成：24 MHz ×7/÷3 → **56 MHz ADC 时钟**，
另一路 24 MHz 驱动 USB，ALTDDIO_OUT 外送反相 IFCLK。没有动态采样档位切换。
USB使用板载 FX2 USB 2.0；根目录历史 USB 3.0 目标不由本工程兑现。

ADC完整料号、码型设置、供电与扩展口接线仍未提供。根目录旧资料中的
AD9235-40 不能直接视作适合 56 MS/s；应按[ADI数据手册](https://www.analog.com/media/en/technical-documentation/data-sheets/ad9235.pdf)
核对实际速率等级和 88–108 MHz 动态性能。
ADC 13个数据/时钟端口仍为 VIRTUAL_PIN，不能把本次 fit/STA 当作可烧录验收。
实际 ADC I/O 相位、输入/输出延迟、PCB skew及射频预选滤波仍待补齐。

## 处理链与自主测频

```text
24 MHz → ALTPLL → 56 MHz ADC域 + 24 MHz USB域
ADC12 ┬→ DC消除/迟滞过零/窗口资格判别 → alias与RF估计 → NCO控制/锁定
      └→ 采集 → NCO复数混频 → CIC(R112) → FIR → int16 I/Q
          → 异步DCFIFO → FCR1 v2/CRC → FX2 EP2 IN → 上位机识别/解调/放音
```

已知单个RF载波属于88–108 MHz时，56 MHz采样将它映射到负alias -24…-4 MHz，
因此 `RF_estimate = 112 MHz - |alias|`。方向固定共轭一次；NCO采用正的
alias幅值，I=x*cos、Q=+x*sin。已知频段和前端抑制其他奈奎斯特区的信号，
是这个映射的前提，不能只凭数字采样率保证射频可用。

`rx_frequency.v` 统计65536样本窗口内迟滞正向过零次数，每窗1.170286 ms。
相邻两个合格窗口平均生成32位phase_step，半count量化间距427.246 Hz；
频率转Hz经4拍寄存器流水，同拍提交phase/RF/locked。资格检查包括：
DC Q10 IIR、±16码迟滞、平均绝对值≥32码、交叉间隔分散≤3采样、频段与裁剪门槛。
两个候选窗口差≤32count才锁定；锁定期间LO保持，偏离>32count
（约27.344 kHz）或无效窗口触发失锁并重新捕获。

这是满足当前单载波原型的轻量估计器，不是AM/FM分类器。有限平均窗、低调制频率
FM、窄带噪声、多载波和低SNR会影响估计；没有宣称普遍精度或信号类型已确认。
检测器独立仿真覆盖静默/纯噪声/DC/弱信号/裁剪拒锁；上位机仍需允许未知和无信号。
LO量化间距不等同于RF估计误差；完整测试使用12 kHz门槛，仅为原型验证设置。

锁定前DSP/FIFO/组帧保持复位；失锁重新清流。锁定信号同步后捕获稳定RF/phase总线，
流释放另外等待32个各域时钟。每次流恢复epoch加1，sample index和frame sequence归零。
PA1只暂停传输并清流，检测器持续运行；EP6调频读取和RCF1配置路径已移除。
在检测窗口发现变化之前，旧流可能仍反映旧LO，PC需结合epoch和实际信号质量处理。

## 定点、抽取与传输

| 项目 | 配置 |
| --- | --- |
| ADC | 单通道12bit；默认offset binary，转signed12；补码选项仅转换码型 |
| NCO | phase32、1024点正弦ROM、signed12 Q1.11，峰值2047 |
| 混频 | 完整signed24乘积；56 MHz覆盖88–108 MHz时固定共轭 |
| CIC | 五级、R112，增益17,623,416,832；59bit模运算，SHIFT42，饱和signed18 |
| FIR | Fs=500 kS/s、61tap signed18 Q1.17、42bit累加；MAC和舍入分拍 |
| FIR输出 | 63时钟延迟；最近舍入半值向正无穷、饱和signed16/clip；112时钟输入间隔 |
| FIFO | Clearbox DCFIFO 512×97、show-ahead、双域4级指针同步、满/空保护 |
| FIFO排列 | {clip, dropped32, index32, Q16, I16} |
| FIFO满 | 丢当前I/Q、累计dropped，index继续递增，帧中明确反映缺口 |
| USB | 24 MHz/8bit EP2 IN；注册FLAGB，写后guard；主机无调频命令输入 |

候选基带为±100 kHz，100–150 kHz过渡，150 kHz起阻带。
CIC+量化FIR计算通带约±0.001 dB、阻带最差-96.84 dB、首级折叠抑制-63.10 dB；
见 `filter_report.json`。这些是数字设计门槛，不是课程正式指标或模拟硬件实测。
ADC幅度A单音的输出幅度约 `A/2 * 2047 * 112^5 / 2^42`；
I/Q码值不是电压或归一化浮点幅度，名义采样率未作晶振校准。

## FCR1 v2帧提案

固定512byte，60byte头+112组signed16 I/Q小端+CRC32。
v2把RF字段定义为**FPGA估计值**；接收方按version解码，不沿用v1调谐命令语义。
这是本工程协议提案，离线IQ JSON契约不变，生产PC驱动/协议尚需集成。

| offset | 字段 |
| --- | --- |
| 0 | ASCII FCR1 |
| 4 | u16 version=2，u16 header_length=60 |
| 8 /12 | u32 frame_sequence /epoch |
| 16 /20 /24 | u32 first_sample_index /valid_count(1…112) /cumulative_dropped |
| 28 /32 | u32 ADC_rate=56000000 /IQ_rate=500000 |
| 36 /40 | u32 RF_estimate_Hz /FPGA自动phase_step |
| 44 | flags：bit0丢样、bit1共轭、bit2clip、bit3启动过渡、bit4自动测频锁定 |
| 48 /52 /56 | u32 CIC_SHIFT=42 /capacity=112 /reserved=0 |
| 60…507 | I16、Q16，超出valid_count零填充 |
| 508 | CRC32/IEEE reflected，覆盖前508byte |

遇index缺口结束部分帧，下一帧从缺口后的样本开始。前66个I/Q为滤波启动区，
PC按index排除；暂停/失锁会截断字节流，PC需magic/version/CRC重同步和epoch检查。
满帧吞吐2.285714 MB/s，25%余量为2.857143 MB/s；FIFO容纳1.024ms I/Q，
另有112样本帧缓存。持续USB实际吞吐仍需设备/驱动联调。

## 锁定后实时连续性与混频波形

用户明确的无丢样范围是：**锁定后持续处理，USB正常接收时不丢样**。
锁定并完成固定流水线启动后，每个56 MHz ADC时钟都进入采集、混频和CIC；
每112个ADC时钟输出一对500 kS/s I/Q。CIC/FIR的滤波抽取按目标带宽处理，
不能将跳过输入时钟或FIFO丢样当作正常抽取。
正常接收检查独立于首次测频、跳频、PA1暂停和长USB堵塞的故障检查。
`scripts/realtime_check.py` 在真实PLL/FIFO/DDIO仿真中逐拍审计采集与混频，
检查CIC/FIR节拍、FIFO写入和USB帧序号/全部I/Q载荷/CRC；出现漏拍或丢样即失败。
正常USB服务预算为含协议至少2.857143 MB/s（25%余量）。1.024ms是空FIFO容量，
不能作为有积压时的停顿容许值或真实USB驱动已达标的证据。
实际连续6ms仿真通过：335990个ADC时钟全部采集/混频，产生2999对I/Q且全部进入FIFO；
26个完整USB帧/2912对I/Q逐值及CRC一致，丢样0。停止仿真时87对正在下一帧RAM待发送。
ADC拍数由仿真实际时钟周期决定，不能将时钟时间精度的舍入当作漏采样。

既有全链波形的**2231 μs尚未锁定**：`locked=0`、`mix_valid=0`、`mi=mq=0`，
约2344 μs才开始混频。锁定后`mi/mq`是滤波前乘积，包含差频及高频像；
应分别用微秒尺度看原始混频、用毫秒尺度看CIC/FIR后的`iq_i/iq_q`。
从实际WLF独立检查55997个可对齐乘积，最大整数误差0；98MHz AM场景的差频
为-5.127kHz，高频像为+27.994873MHz，最终AM深度0.500356。
这一残余频偏来自自动LO估计，精度限制仍如前述。
实际对照见[波形图](../../../.harness/receiver/mixer_audit/mixer_actual.png)和
[混频审查](../../../.harness/receiver/mixer_audit/README.md)。
第一次AM场景的测试输入是`800×(1+0.5cos(2π·5kHz·t))`，包络周期为200μs。
因此在2600–2700μs看到`mi/mq`包络下降、2700–2800μs再次上升是预期的AM调制，
不是混频器单向衰减；实际`|mi+jmq|/2047`与测试台包络重合。应使用复幅度或滤波后的
`iq_i/iq_q`检查AM，不要用单个原始乘积支路的瞬时峰值判断增益。
包络对照见[第一次AM包络图](../../../.harness/receiver/mixer_audit/first_am_envelope.png)。

既有全链仿真的最终 `iq_i/iq_q` 包含两段 FM 输出：stage 1 的 88 MHz 在
7027.192–8433.237 μs、stage 2 的 108 MHz 在11708.485–13114.530 μs，
每段704对有效I/Q。稳定观察区间分别选7200–8000 μs、11900–12700 μs；
复幅度约3281，实际相位差恢复5kHz、约±25kHz的调频。
每个FM场景自身发送6个完整USB帧，共672对I/Q，重新解码的字节与WLF逐样本一致。
按epoch统计的10帧含下一场景跳频后的旧锁定尾段，不能全称为稳定目标FM数据。
跳频重捕获期间没有有效输出；22938 μs属于stage 5纯噪声，失锁后I/Q为零。
`iq_valid`每2 μs仅高约17.857 ns，应查看上升沿；光标处为零不代表整段没有I/Q。
实际波形见[FM图](../../../.harness/receiver/fm_iq_audit/fm_iq.png)和
[独立核查](../../../.harness/receiver/fm_iq_audit/README.md)。

## 重建、验证与波形

在项目根目录运行：

```powershell
python -B main_project/fpga/receiver/scripts/generate.py --ip-only
python -B main_project/fpga/receiver/scripts/frequency_check.py
python -B main_project/fpga/receiver/scripts/simulate.py
python -B main_project/fpga/receiver/scripts/realtime_check.py
python -B main_project/fpga/receiver/scripts/full_chain.py
python -B main_project/fpga/receiver/scripts/build.py
& main_project/fpga/receiver/scripts/view_full_chain.ps1
# 打开交互查看器并放大原始混频（仅2us区间）
& main_project/fpga/receiver/scripts/view_full_chain.ps1 -View Mixer -Launch
# 查看基带的0.9ms区间；Startup检查首次锁定，Full显示全过程
& main_project/fpga/receiver/scripts/view_full_chain.ps1 -View Baseband -Launch
# 最终 I/Q 以有符号模拟阶梯显示，直接定位到两段稳定 FM
& main_project/fpga/receiver/scripts/view_full_chain.ps1 -View FM88 -Launch
& main_project/fpga/receiver/scripts/view_full_chain.ps1 -View FM108 -Launch
# 专门查看第一次AM的mi/mq包络（2600–2800μs）
& main_project/fpga/receiver/scripts/view_full_chain.ps1 -View FirstAM -Launch
```

已有WLF窗口可直接在ModelSim Transcript执行
`do {D:/class_project/main_project/fpga/receiver/scripts/view_fm.do}`；
若此前滚动到了其他分组，将Wave信号列表滚到顶部即可看到青色I、黄色Q。
切108MHz执行 `wave zoom range 11900us 12700us` 并将光标移到显示区间内。

查看脚本打印打开ModelSim已完成WLF的命令；波形分组包含ADC、测频/锁定、
NCO/CIC/FIR、FIFO、FCR1和USB。新输出位于 `.harness/receiver/frequency/`、
`sim56/`、`full_chain56/` 和 `build/receiver56_*`。
全链路刺激的RF真值只属于TB，未从命令、端口或force注入FPGA。
独立整数重放使用实际ADC样本和内部估计的LO；完整USB载荷/CRC与它对照。

IP不手工编辑，由本地Quartus生成。tables-only需NumPy，本机bundled Python可用；
运行/构建/仿真检查使用标准库。Quartus构建只到map/fit/多角STA，不生成烧录件。
FIR与测频关键路径曾在56MHz失败，已靠寄存器分级修复；未降低时钟或添加无依据例外。
USB约束保留器件写时序与FLAGB，旧EP6读数据multicycle已删除。
最终通过项目及证据见 [VALIDATION.md](VALIDATION.md)，上板、真实RF/ADC、USB驱动、
实时声音、PCB/ERC/DRC和课程整机验收仍须独立验证。
