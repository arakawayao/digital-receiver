# 两模式工程验证记录

日期：2026-10-20。目标为用户确认的EP4CE6F17C8，入口receiver_ads807_dual.qpf。
原工程未修改；7个采集/估频/DSP/reset模块及2个系数表与receiver_ads807逐文件SHA256一致。
以下均为本新工程的实际执行结果，不沿用旧三模式工程的通过记录。

## USB 控制实板测试（2026-10-20）

ADC 未接入。通过 USB-Blaster 下载本工程 SOF 到 EP4CE6F17C8，Programmer 返回 0，
Configuration succeeded；FX2 数据 USB 为 04B4:1004，IN 0x82 / OUT 0x06。
SOF SHA256：`1fa7167bb0d74f7ce7feb300d4267057a0f8b1f69a63e0f61bae6830942acc12`。

首轮控制边界检查及 60 秒持续 QUERY 完成，440 条命令均收到预期 ACK，
最长往返 64.694 ms；解析 700 帧，无全局序号间断、CRC 错误或丢弃字节。
自动/手动模式、88/98/108 MHz 手动参数及 NCO 步长、STOP、HOLD、QUALITY(0)，
以及越界、MODE0、已删除命令、坏 CRC 和非零保留字段的错误响应均符合预期。
末条 STOP ACK 成功。260 帧 I/Q 仅计数且忽略内容，不属于信号有效性或吞吐验证。
实际 Qt 窗口可通过本地浏览器同步显示 ACK 计数与日志，测试后保持开启。

证据：`.harness/receiver_ads807_dual/board_control/20261020_162353/result.json`、
同目录 `program.log`、`startup.bin` 和 `preview.json`。
此结果仅证明本轮 USB 控制往返通过，不代表 ADC/射频、AM/FM、音频或长期流稳定性通过。
下文“未烧录/未连接真实 USB”描述为此前构建阶段的历史状态。

## 按用户P3接线补齐全部ADC引脚

用户后续明确：从A15开始，依次OTR、ADC高位到低位、adc_clk。
配置已补齐：OTR=A15、data[11:8]=A14/F11/A13/A12，低8位及CLK沿用下方原映射。
14个端口均3.3-V LVTTL、VIRTUAL_PIN OFF。新增adc_otr为独立预留输入，
暂不参与DSP或USB协议，不将硬件OTR与原有数字削顶混为同一指标。
ModelSim重新编译receiver_top及连接adc_otr的tb_dual通过，逐行编码检查21文件通过。
本轮Quartus 18.1 map/fit/sta返回码均0，Fitter实际引脚表逐项核对14个位置通过，
目标EP4CE6F17C8，虚拟引脚0；资源6178/6272 LE（剩94 LE）、4013寄存器、
169002/276480 RAM位。三个工况setup为1.188/1.614/2.987ns，hold为0.324/0.310/0.095ns，
全部已约束检查通过。Fitter将显式VIRTUAL_PIN OFF列为忽略赋值，实际端口均为物理引脚，
位置约束均生效；其他已有I/O赋值及DSP警告仍保留。
本轮未重跑完整动态仿真及上位机回归，下方相关结果为此前验证记录。
本轮构建证据为`.harness/receiver_ads807_dual/build/summary.json`及quartus目录fit报告。
ADC板级I/O延迟、采样相位、VDRV和PCB条件仍需实测；未烧录。

## 此前低8位配置（历史）

ADC低8位0..7依次为E10、D11、B6、B7、D8、A9、A10、A11，adc_clk为D9，
均已配置物理位置及3.3-V LVTTL。adc_data[1]截图被截断，按旧receiver56.qsf交叉核对为D11。
截图未给出adc_data[8..11]，这四位继续保留虚拟；未猜配引脚，未把12位RTL改成8位。
截图仅确认FPGA电平设置，不构成ADS807E实测VDRV或板级延迟证据；接口时序签核仍未完成。
重新运行map/fit/STA均返回0，fit报告已核对9个指定物理位置，剩余虚拟端口4个。
当时资源为6177/6272 LE（剩95 LE）、169002/276480 RAM位、21/30 M9K。
三个工况setup最小值依次为1.201/1.614/2.987ns，hold为0.329/0.320/0.103ns；
全部已约束检查通过，ADC接口因缺少板级I/O约束仍未签核，未下载SOF。
该轮构建产物已被本轮覆盖，历史数值仅保留于本节。
下方初版资源表是13个ADC虚拟端口时的历史结果，以顶部全部引脚配置后的记录及最新构建报告为准。

## 仿真与软件

| 项目 | 结果 | 证据（项目根目录相对路径） |
| --- | --- | --- |
| 用户逐行规范 | 21个手写HDL文件通过；单信号声明、单赋值、wire与assign分离 | scripts/check_style.py |
| 原DSP独立定点模型 | 新工程实际RTL与261046周期整数参考逐拍一致；使能间断、复位、量化/饱和、边界频点、AM/FM/静默通过 | .harness/receiver_ads807_dual/reference/modules_summary.json |
| ADC/PLL/估频 | capture、真实PLL模型、7种输入的估频/拒绝通过 | reference/与simulation/中的tb_capture、tb_pll、tb_frequency日志 |
| CDC握手 | 不同时钟、100次传输、背压稳定、待处理交易整体复位后10次传输通过 | .harness/receiver_ads807_dual/simulation/tb_mailbox.log |
| 双向引脚全链路 | 实际Intel FIFO/PLL + ADC AM/静默 + FX2 OUT/IN；107帧、8835对I/Q、18条ACK，无RAW | .harness/receiver_ads807_dual/simulation/summary.json |
| 数据核对 | CRC、补零、全局序号、逐样本I/Q及全部FIFO元信息一致 | 同上，dual_bytes.txt及dual_iq.txt |
| 控制边界 | 无锁定手动启动、88/98/108MHz步长、越界、MODE0、已删除命令、CRC错误、非零保留字、自动模式TUNE拒绝 | 同上；ACK errors为8个0后4,4,3,3,0,0,0,1,2,5 |
| 失锁保持 | 自动已调谐后静默不复位DSP；手动低可信度/超时仍推进index、epoch不变 | tb_dual.log |
| FIFO故障 | 人为1.5ms IN反压，出现预期丢样并计数，恢复后CRC与实际FIFO载荷一致 | simulation/summary.json |
| 上位机完整回归 | 78 passed，包括两模式GUI、协议、DSP、停止/ACK错误和有界接收 | .harness/ads807_host/dual_new_tests.xml |
| 实际RTL→生产解析器 | 按71B任意分块读取107帧：89 IQ、18 ACK，8835样本，CRC/头/丢字节/帧序号错误均0 | .harness/receiver_ads807_dual/simulation/host_crosscheck.json |
| Qt离线链路 | AM/FM/无信号/噪声4场景PASS；已检查手动模式实际Qt截图，载频输入、状态和波形布局正常 | .harness/ads807_host/dual_verification/result.json |

FIFO故障测试中的预期丢样不是正常USB无丢样证明。自动估频结果不保证绝对载频精度，
冷启动弱信号仍可能无法自动获得调谐参数；可由用户选择手动模式启动DDC。
语义波形图是spec中的概念WaveJSON，未渲染为实际测量波形；动态证据为ModelSim日志/WLF。

## 综合、布局布线及时序

Quartus Prime18.1.0 Build625，map/fit/sta返回码均0；未运行asm或programmer。
修正USB FAST_INPUT_REGISTER逐引脚节点后重新构建，最终map/fit/sta日志无Critical Warning。

| 资源 | 最终结果 |
| --- | --- |
| LE | **6183 / 6272（98.58%，Quartus显示99%），仅89 LE余量** |
| 寄存器 | 4013 |
| RAM位 | 169002 / 276480（61%） |
| M9K | 21 / 30（70%） |
| 9位乘法器 | 12 / 30（40%） |
| PLL | 1 / 2 |
| ADC虚拟端口 | 13 |

| 工况 | Setup ns | Hold ns | Recovery ns | Removal ns |
| --- | --- | --- | --- | --- |
| corner1 | 1.157 | 0.319 | 18.804 | 1.156 |
| corner2 | 1.603 | 0.308 | 19.014 | 1.060 |
| corner3 | 2.987 | 0.094 | 21.034 | 0.492 |

证据：`.harness/receiver_ads807_dual/build/summary.json`、
`.harness/receiver_ads807_dual/quartus/receiver_ads807_dual.fit.summary`及同目录fit.rpt。
当前配置已能装入器件，但LE和最小hold裕量都较小，不能据此承诺新增逻辑空间或板级时序。
SDC只豁免toggle同步器第一级及外部异步复位/暂停第一阶段；没有按整个时钟组屏蔽数据路径。
握手源数据保持到目的消费确认，命令/应答跨域总线分别限制20ns/35ns。

## 限制与未完成项

ADC12位、OTR及CLK均已配置物理引脚，但ADC往返板级延迟未知；FX2输出drive strength仍未指定，
fit报告保留不完整I/O赋值警告。原DSP存在位宽截取和推断ROM相关警告，
本轮保留原实现，通过独立整数模型核对其数值行为，未把警告描述为全部消除。
真实USB控制与新SOF下载已按顶部记录完成；未运行物理音频、未实测ADC/射频或端到端长期稳定性。

另运行了readable-verilog-generator的erie_strict门禁，结果 **未通过**：
compile通过、parse_errors=0；ast格式规范、readability、comment、naming和profile未通过，
共5765 errors / 74 strict warnings，delivery_ready=false。
报告在 `.harness/receiver_ads807_dual/quality/gate.json`及gate.md。
其要求的全面命名/注释/分区/状态机及组合运算预算没有在本轮继承工程中全面改造，
不将实际ModelSim/Quartus通过混同为该技能严格样式认证通过。
