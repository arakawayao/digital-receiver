# EP4CE6 USB 回放验证记录

日期：2026-10-19；用户确认 EP4CE6F17C8、无 ADC 的内部回放。
运行环境：Quartus Standard 18.1.0 Build625，ModelSim SE2020.4，
`D:/conda_envs/ads807_host/python.exe`（NumPy、SciPy、pythonnet）。
当前目录不是 Git 仓库，未初始化仓库。

## 已执行结果

| 检查 | 结果及证据 |
| --- | --- |
| 项目行级 HDL 风格 | PASS，17 个手写文件；`scripts/check_style.py` |
| 回放软件测试 | PASS，9 项；拆包、CRC、缺帧、错误采样配置、截断、标签不能替代分类、输入边界、STOP 补齐尾帧 |
| AM 引脚级回放仿真 | PASS；41 个 ACK，包含错误 CRC 与不完整启动拒绝；每点 RAM 回放一致；前16帧1792对I/Q逐点等于 DUT 输出 |
| FM 引脚级回放仿真 | PASS；同上；87拍输出间隔、无正常FIFO溢出或FIR截止错误 |
| AM 实际生产分析函数 | AM，深度0.4996449，设定0.5；载频98002441.409 Hz，真值98002441.40625 Hz |
| FM 实际生产分析函数 | FM，频偏24974.573 Hz，设定25000 Hz；载频98002431.988 Hz |
| Quartus 综合/布局布线/装配 | PASS，0 errors/103 warnings；EP4CE6F17C8，4887/6272 LE，172618/276480 RAM bits，12/30乘法器 |
| 多工况 STA | 42 项 setup/hold/recovery/removal/min-pulse 检查均非负，最小0.148 ns；43.5/24 MHz PLL已核对 |
| SOF | `.harness/receiver_replay/quartus/receiver_replay.sof`；哈希以 `build.json` 为准 |
| JTAG 与实际下载 | 后续连接到 USB-Blaster [USB-0]，ID=0x020F10DD；Programmer 按 EP4CE6F17@1 校验并成功下载 SOF（0 errors/0 warnings） |
| FX2 枚举 | 后续识别04B4:1004 Cypress FX2LP Sample Device，EP6 OUT/EP2 IN，512 B高速Bulk；曾出现短时匹配数为0 |
| AM 实板回环 | PASS；512帧57344对I/Q，CRC=0、dropped=0；调制度0.4997427，载频98002441.406269 Hz |
| FM 实板回环 | 重新上电后PASS；512帧57344对I/Q，CRC=0、dropped=0；频偏24985.548 Hz，设定25000 Hz |
| 跨轮启停 | 重新上电并下载后，FM→AM→FM三个独立进程连续通过，各512帧，无需再次下载或断电 |

仿真使用真实 Intel PLL、DDIO、异步 FIFO；FX2 为带传播延时的引脚功能模型。
AM 和 FM 分别运行约13.09 ms仿真时间，约293616个回放采样点。
保存的前16帧 CRC、帧序号、样本索引、epoch、削顶、累计丢样和载荷逐值检查均通过。
STOP 后的残缺补齐尾帧不参与分析；软件有独立回归检查此边界。
默认实板采集512帧约114.7 ms；本轮不将短仿真作为长时间实时性能证明。

证据目录：`.harness/receiver_replay/am/`、`fm/`，包含编译/仿真日志、
`simulation.json`、`capture.bin`、`iq.csv`、`manifest.json` 与 `result.json`。
构建证据为 `.harness/receiver_replay/build.log`、`build.json`、`quartus/`。
所有 `.harness` 文件均可重新生成，不作为源码依赖。

## 未通过或未完成的检查

erie_strict 技能门禁已运行但失败：compile 通过，ast/readability/comment/naming/profile/testbench/toolchain
不全部就绪。报告 `.harness/receiver_replay/style.json` / `.md`。
其完整项目风格、命名、固定双语头与本工程既有规范不同，单文件调用也无法解析
Intel/相邻工程接口闭包；未将其宣称为通过，未为适配门禁重写原工程。
同名 spec Markdown 已提供接口、CDC、边界和 WaveJSON 源，未通过技能渲染器生成 SVG。

Quartus 的103条警告包含继承模块的明确截位、初始化ROM相关提示、未用端口/逻辑和
未约束 LED；完整记录保留在 build.log。未声称零警告或ASIC级交付。
唯一未约束输出是无同步采样要求的状态 LED；USB数据和控制引脚有输入输出延迟约束。
FX2时序约束暂按零 PCB 偏斜，不能称为板级时序签核。

实际AM证据为 `.harness/receiver_replay/live_am/`，FM为 `live_fm/`；
重新上电后的跨轮证据为 `repeat_am/`、`repeat_fm/`。
AM首次成功时间约16:50（北京时间），随后FM首条STOP（opcode=4、sequence=0）ACK超时，
仅重新下载SOF未恢复。16:55用户确认重新上电后，下载相同SOF，再做FM→AM→FM均成功。
没有发送A8/A9、刷FX2或更换驱动。先前枚举/ACK超时的根因仍未定位，
不能将三次短采集描述为长期稳定性或任意断连恢复已验证。

尚未验证：FX2寄存器/固件配置、持续USB吞吐与断连恢复、长时间实板无丢样、
ADC/射频前端、电平/采样时序、真实接收、物理音频和整机验收。
根目录桌面上位机仅通过文件回放兼容本 FCR1 v2；其实时USB控制仍为TRI1。
