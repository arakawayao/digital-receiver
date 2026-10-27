# 固定56MHz自主接收机验证记录

2026-10-04。依据用户最新更正：PLL提供ADC56MHz；FPGA自主测频/DDC；
PC接收后仍识别AM/FM、解调和放音，不发调频配置。
旧32/40与EP6配置结果移至 `legacy_32_40/`，不用于本版本验收。

## 已实际完成

| 检查 | 当前证据与结果 |
| --- | --- |
| 本机IP生成 | Quartus18.1 Clearbox：rx_pll56(24×7/3和24MHz)、DCFIFO、DDIO |
| rx_frequency | ModelSim20场景PASS：端点/单音、AM80%、FM75k@5k、DC、AWGN、纯噪声、弱信号、裁剪、越界、跳频与失锁重获 |
| 测频流水 | 4拍转换，同拍phase/RF/locked/update；每时钟一致性断言PASS |
| 56MHz模块 | capture/pll/fir/transport PASS；DSP333046周期逐样本数据/valid/clip/error匹配 |
| 频段映射模型 | 88…108MHz每10kHz共2001点映射至4…24MHz；不是硬件实测 |
| 滤波模型 | CIC R112+量化FIR通带约±0.001dB；阻带-96.84dB，首级折叠抑制-63.10dB |
| Quartus56 | map/fit/STA PASS；实报ADC56.0MHz，USB24.0MHz |
| 自主ADC→USB全链 | ModelSim与独立载荷/CRC检查全部PASS，68完整帧、7568有效I/Q、7个epoch |
| 锁定后正常实时流 | 连续6ms逐ADC拍检查PASS；335990拍均采集/混频，正常短反压下零丢样，26帧2912对I/Q载荷/CRC逐值一致 |

独立测频单音场景误差0…427Hz，AM98.5MHz约305Hz，
FM100.7MHz/75k@5k约-659Hz。这不是对所有输入精度的保证：
实际流启动可能落在窗口中部；低调制频率FM、有限窗、低SNR、多载波和窄带噪声
需进一步验证。LO半count步距427.246Hz不等于中心频率测量误差。
全链试验的12kHz门槛属于原型设置，课程正式精度阈值未确定。

## 自主全链路实测仿真结果

实际执行full_chain.py，全程未发送RF/phase命令、未force内部配置。
真实PLL/FIFO/DDIO与receiver_top运行35.807ms仿真时间；记录939253个运行中DSP采样周期。
接收34833byte，68完整512byte帧全部通过version/全部头字段/IQ/clip/补零/CRC检查。
ADC输入按每次流复位独立定点重放，FIR63拍、CIC59位、检测器实际LO均与USB载荷一致。

| 场景 | FPGA RF估计 | 接收后测量 |
| --- | --- | --- |
| 初次未知98MHz AM | 98.005127MHz，误差+5127Hz | AM深度0.500356（真值0.5） |
| 运行中跳到88MHz FM | 88.000305MHz，误差+305Hz | FM偏差25006.21Hz（真值25000） |
| 跳到108MHz FM | RF字段108MHz（端点clamp） | FM偏差25013.00Hz |
| 跳到93.37MHz AM | 93.369934MHz，误差-66Hz | AM深度0.500593 |
| 静默/宽带噪声 | 失锁；各观察3.5ms没有新数据 | 未伪造有效流 |
| 信号重现98MHz | 98MHz，epoch=5 | 自动恢复AM，深度0.500076 |
| PA1暂停/恢复 | 测频保持；epoch=6 | index/sequence重启，无需频率命令 |
| 主机堵塞2ms再恢复 | 真FIFO满，累计丢439个I/Q | index缺口=439，64样本部分帧补零正确 |
| 帧中暂停后恢复 | 17byte残帧剔除；epoch=7 | 重新接收4完整帧、无丢样 |

首次锁定约2.342ms，所测跳频重捕获约3.273ms。98MHz初次启动的第一窗口包含少量
静默，导致+5.127kHz估计偏差；此误差明确保留在帧与结果中，未用真值纠正。
LO量化427Hz不能作为普遍测频精度，初始partial-window可能有约14kHz量级偏差；
本轮已测信号仍在滤波通带，低调制频率FM/更宽信号与更严格精度仍需另验。

证据：`.harness/receiver/full_chain56/summary.json`、`chain56000000_summary.json`、
ADC输入/USB字节/事件txt、`chain56000000_iq.csv`、`chain56000000.log`和WLF。
ModelSim GUI实际回放新56MHz WLF、加载全部分组并导出波形格式，最终无错误：
`full_chain56/view_check/gui.log`和`loaded_wave.do`。PS1默认打印的打开命令也已核验为56MHz。

## FM 最终 I/Q 独立复核

直接加载同一WLF，以`iq_valid`上升沿提取实际RTL的`iq_i/iq_q`，没有重新仿真
或用参考模型替代波形。88MHz场景7027.192–8433.237μs、108MHz场景
11708.485–13114.530μs各704对有效I/Q；每段最初8对为零，随后滤波器启动。
7200–8000μs和11900–12700μs各400对稳定样本的复幅度约3279–3283，
相位差恢复5kHz、约±25kHz FM。每个FM场景自身的6帧/672对I/Q
重新计算CRC并与WLF逐样本一致。

原epoch 2/3各10帧的后4帧包含下一场景跳频后的旧锁定尾段，不全部属于
稳定目标FM。4682.581–7023.906μs、9363.874–11705.199μs是失锁重捕获区，
没有有效I/Q；22938μs为纯噪声stage 5，I/Q为零。
`iq_valid`为每2μs高约17.857ns的窄脉冲，任意光标处读零不能判断整段无输出。
证据：`.harness/receiver/fm_iq_audit/README.md`、`wlf_valid_iq.csv`、`fm_iq.png`。
`view_full_chain.ps1 -View FM88/FM108`提供最终I/Q专用查看入口。
本机ModelSim GUI已实际加载两段FM查看配置，108MHz的12000μs光标值
为I=2345、Q=2295；查看配置导出至`fm_view/fm_loaded_wave.do`。

## 2231 μs混频波形独立复核

从已保存的全链路WLF提取实际波形，不重跑长仿真、不使用同结构整数模型
作为唯一依据。2231 μs时`detector/locked=0`、`stream_sample_n=0`、
`capture_valid=mix_valid=0`、`mi=mq=0`，是首次捕获前的复位值。
约2344 μs后才开始连续采集/混频。

2600–3600 μs中55997个可对齐乘积，与前两拍的实际ADC样本及NCO相位逐点一致，
最大整数误差0；mi/mq峰值2405697/2328750，无signed24溢出。
实际LO13.994873046875MHz、98MHz射频折叠-14MHz，复乘正确差频为
-5126.953125Hz，和频像为+27.994873046875MHz。
实际两枝主载波幅818790.65、各±5kHz边带幅204702，符合0.5深度AM。
滤波后USB I/Q相位斜率-5127.075Hz，AM深度0.500356。
因此原始乘积的高频形状不能作为基带波形错误的判据。
第一次AM的测试台包络为`800×(1+0.5cos(2π·5kHz·t))`，周期200μs；
实际WLF中2600–2700μs复乘积包络从约1200降至400 ADC码，2700–2800μs又回到约1200，
与测试台公式一致。这个“先变小再变大”是AM本身，不能把单个`mi`或`mq`支路的短时下降
当成混频器增益衰减。对照图：`.harness/receiver/mixer_audit/first_am_envelope.png`。

精确98MHz/14MHz=Fs/4及该采样初相位下，mi全零而mq零/幅值交替也可正常解调；
信号可整体旋转至任意I/Q方向，AM应观察复幅度。
证据：`.harness/receiver/mixer_audit/result.json`、`actual_mixer.csv`、
`audit.py`、`plot.py`、`mixer_actual.png`。本轮未发现需要更改混频RTL的问题。

用户将实时无丢范围明确为锁定后持续处理、USB正常接收。
新增`realtime_check.py`独立审计整个锁定时间轴，正常测试不允许dropped、
FIFO满、采集/混频缺拍或输出索引缺口；长USB故障的预期丢样单独报告。

## 锁定后正常USB实时检查

实际运行`realtime_check.py`，输入93.37MHz/0.5深度/5kHz AM，只经ADC引脚进入FPGA，
未提供RF/NCO真值配置。首次自动捕获约2.341ms，另计固定捕获/混频流水启动。
随后连续审计6.000013ms：335990个外部ADC时钟、335990次正确采集、
335990次有效混频，NCO逐拍推进、CIC逐拍接收，两路CIC与I/Q输出间隔均为112拍。
WLF转VCD后独立计数同一审计区间的外部ADC上升沿，得到335990拍，
与TB、采集和混频计数完全一致；测得平均周期17.857714285ns。
3000次CIC结果、2999对完成FIR的I/Q，最后一个CIC结果仍在FIR处理中。
2999对完成I/Q全部写入FIFO，没有满、丢样或FIR deadline error。

USB模拟端点按6MB/s credit补充速率限速，周期约41.5μs含2.5μs短停顿；
实际credit到零，byte反压确实发生，采集端保持连续。
收到13312byte/26完整帧/2912对I/Q，全部头字段、连续序号与index、
真实FIFO写入值逐样本对照及CRC通过；丢样和index缺口均为0。
停止仿真时另有87对I/Q已进入下一帧RAM待发送，明确不计入已接收数量。
这项短时仿真验证既定正常服务条件，不能代替真实USB驱动持续吞吐和长时间上板测试。

首轮失败原因是测试误把理想6ms对应的336000拍作为硬门槛。
ModelSim 1ps精度下参考源半周期20.8335ns舍入为20.834ns，实际ADC周期略偏离
理想56MHz；正确做法是按实际外部ADC边沿审计，每一拍都要求被采集/混频。
未修改DUT时钟、处理逻辑或放宽允许漏拍数。完整测试保留≥6ms时间条件。
首轮证据保留在`realtime56/first_attempt/`。

证据：`.harness/receiver/realtime56/summary.json`、`realtime56.log`、
`realtime_stats.txt`、`realtime_iq.txt`（每次真实FIFO wrreq的index/I/Q/clip）、
`realtime_bytes.txt`、`realtime56.wlf`、`realtime56_adc.vcd`。
测试台为`tests/realtime_tb.sv`，最后源版本已实际完整运行，ModelSim 0错误。
本轮未改可综合RTL，因此不重复原本通过的Quartus实现；新增TB不加入综合源清单。

## 综合、实现与时序

首轮56MHz慢角存在真实负setup：测频DC→count→Hz转换为-7.489ns，FIR最后MAC→
舍入/饱和为-2.881ns。已分别用测频4拍流水、FIR最后结果寄存解决；
FIR总延迟由62改63时钟，整数参考和测试同步更新。

第二轮Quartus18.1实际map/fit/多角STA成功：

| 角 | setup | hold | recovery | removal |
| --- | --- | --- | --- | --- |
| Slow1200mV85°C | +1.842ns | +0.315ns | +1.597ns | +1.207ns |
| Slow1200mV0°C | +2.806ns | +0.306ns | +1.942ns | +1.079ns |
| Fast1200mV0°C | +4.325ns | +0.092ns | +3.978ns | +0.548ns |

资源：4050/6272 LE(65%)，71242/276480 RAM bit(26%)，12/30 DSP9bit元素(40%)，
1/2 PLL。最差路径为FIR历史RAM→final_i，data delay15.520ns。
未降低56MHz目标，也未通过新增false path/multicycle掩盖问题。
旧EP6读数据约束随读取路径删除；FLAGB和USB写数据/控制保留实际器件时序约束。

证据：`.harness/receiver/build/receiver56_summary.json`、map/fit/sta日志、
本目录 `receiver56_corner*_*.rpt`、`output_56/*.fit.rpt`；
首轮失败报告在 `build/initial56/`。
旧入口归档后实际Quartus Shell重新导出QSF，0错误/警告，确认只列十个活跃RTL
和PLL56/FIFO/DDIO，没有rx_config或32/40PLL引用；这次源码清单整理未改变已实现RTL。

## 入口与完成边界

```powershell
python -B main_project/fpga/receiver/scripts/frequency_check.py
python -B main_project/fpga/receiver/scripts/simulate.py
python -B main_project/fpga/receiver/scripts/realtime_check.py
python -B main_project/fpga/receiver/scripts/full_chain.py
python -B main_project/fpga/receiver/scripts/build.py
```

harness新增receiver-frequency-tests、receiver56-module-tests、receiver56-realtime-tests、
receiver56-full-chain-tests、receiver56-quartus。当前证据为上述实际脚本运行；
注册任务或harness列出不等于整个harness已经执行。
波形查看入口 `scripts/view_full_chain.ps1`，新WLF在 `full_chain56/`。
Wave中的stage依次为0首次AM、1/2端点FM跳频、3非整数AM、4静默、5噪声、
6信号重现、7PA1恢复、8USB堵塞恢复、9帧中暂停恢复。

13个ADC端口仍为VIRTUAL_PIN；ADC料号/码型/电平/接线及I/O时序未确认。
USB使用零PCBskew模型，check_timing/UCP保留ADC/LED、无虚拟时钟及PLL锁定寄存器
no_clock等未解决项。已约束路径正余量不等于完整板级时序验收。
实际RF/ADC、上板、USB物理层/固件/驱动、实时放音、PCB/ERC/DRC及课程整机验收未完成。
