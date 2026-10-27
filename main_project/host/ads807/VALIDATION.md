# 上位机验证记录

## 2026-10-20 独立目录迁移

应用、共享协议、历史Python工具、测试和默认产物已统一到host目录。
迁移后104项回归通过；只有host的独立副本同样104项通过；实际Qt离线四场景PASS。
详细范围、证据和未验证项见 [迁移记录](../docs/MIGRATION.md)。
下文旧软件产物路径现相对host；FPGA相关历史证据的关键摘要见 `../evidence/`。

## 2026-10-20 两模式新工程适配

当前对象为 `main_project/fpga/receiver_ads807_dual`，已移除对不存在的tri目录的Python导入。
MODE1默认FPGA自动，MODE2手动；保持既有采集、USB后台读写和界面处理优化。
78项软件回归通过，证据 `.harness/ads807_host/dual_new_tests.xml`；固件模型确认不发送opcode4/6，
手动TUNE被拒绝、STOP ACK丢失均报告错误。低可信度/无I/Q不会触发主机重搜。
实际Qt离屏AM/FM/静默/噪声4场景通过，证据 `.harness/ads807_host/dual_verification/result.json`。
两模式USB模拟界面截图位于 `.harness/ads807_host/dual_new_pytest/test_gui_runtime_two_modes_and*/tri_mode_*.png`。
未连接物理USB、未烧录、未播放物理音频。FPGA仿真与资源另见新工程VALIDATION.md。
新RTL实际FX2输出已由生产GUI解析器交叉检查：107帧（89 IQ、18 ACK），8835样本，
按71B分块接收，CRC/帧头/丢字节/全局序号异常均0；证据
`.harness/receiver_ads807_dual/simulation/host_crosscheck.json`。
以下三模式条目为历史记录，不是当前功能或当前验证结果。

## 2026-10-18 三模式适配

适配对象为根目录现有 `host/ads807` PyQt6 工作台，FPGA 为
`main_project/fpga/receiver_ads807_tri`。本轮没有修改 RTL、下载固件或连接真实 USB。
沿用以下 Windows / Python 3.11 / Qt 6.7.1 环境，无新增第三方依赖。

| 项目 | 本轮结果与证据 |
| --- | --- |
| 完整软件回归 | 68 passed，0 failures；`.harness/ads807_host/tests.xml` |
| 集成 harness | `ads807-host-tests`、`ads807-host-offline-verification` 均 passed；`.harness/runs/20261017T163218-c28fb7ba7441/summary.json` |
| 三模式专项 | 10 passed；最终加强断言确认 TRACK 后恢复 AM 和非零解调音频，截图位于 `.harness/ads807_host/tri_final_focus/test_gui_runtime_three_modes_a*/tri_mode_*.png` |
| 双向固件模型 | 自动模式 8 段快照 → TUNE → QUALITY / TRACK；FPGA 模式不发送 TUNE / QUALITY / TRACK；手动模式保持指定 RF，低可信度超过 500 ms 不重调谐、不切断 I/Q 连续段 |
| 边界与错误 | RAW 先于 ACK、RAW / ACK 插入 I/Q 的序号检查、CRC 恢复、u32 序号回绕、配置变更、无 I/Q 后自动重搜、拒绝 TUNE、丢失 STOP ACK 均有断言；拒绝或超时不盲目重发 |
| 文件回放 | TRI1 文件不创建调谐线程、不发控制命令；保留原 FCR1 任意分块、CRC、DSP、保存回放等回归 |
| 既有 RTL 输出交叉检查 | 读取已有 `.harness/receiver_ads807_tri/simulation/tri_bytes.txt`，新 GUI 解析器接收 59,392 B / 116 帧（84 IQ、19 RAW、13 ACK），CRC / 帧头 / 全局序号异常 / 丢弃字节均为 0；未重新运行 RTL 仿真 |
| GUI / DSP 离线完整路径 | AM、FM、无信号、噪声 4 场景 PASS；`.harness/ads807_host/verification/result.json`，同目录三视图及 1100×760 紧凑截图；已检查实际 Windows Qt 截图中的新增控件和文字布局 |
| CLI 兼容性 | `receiver_ads807_tri/tests/test_host.py` 16 项通过；GUI 与 CLI 复用协议和搜索函数，只增加包导入兼容 |
| harness 本身回归 | `tests/test_runner.py` 11 项通过；新增桌面上位机任务已注册至共享清单 |

TRI1 与 FCR1 分别解释 flags 和头字段；所有帧全局序号与 I/Q 样本连续性分别统计。
短时质量变化不复位主机连续段；epoch / config / 数据缺口切段并重新稳定音频。
TRI1 有暂态标志的整帧保守排除，因此有效样本舍弃数可能超过 FPGA 实际 66 对暂态。
停止时保持接收和解码至 STOP ACK；应答丢失会报告错误、清理音频和活动缓存，不报告已确认停止。

未验证：真实 EP6 / EP2 双向固件、实际 ADS807 数据、长期 USB 吞吐、射频弱信号搜索和跟踪性能、
新链路持续物理音频或端到端时延。本轮没有开启扬声器；下方历史物理音频结果不能替代三模式硬件验证。
软件检查通过不代表 ADC 电气接口、FPGA 板级时序、上板或系统验收完成。

## 2026-10-17 历史基线

日期：2026-10-17（Asia/Shanghai）。环境：Windows x64，
`D:\conda_envs\ads807_host\python.exe`，Python 3.11、PyQt6/Qt 6.7.1、
NumPy 1.26.4、SciPy 1.13.1。项目没有 Git 仓库，本轮未初始化。

## 已执行

| 项目 | 结果及证据 |
| --- | --- |
| 新增自动化测试 | 57 passed；`.harness/ads807_host/tests.xml` |
| 协议 | USB 任意分片、CRC、重同步、部分帧、独立构造的 RTL 帧布局、非法配置、旧 v3 拒绝、历史累计丢样、epoch、uint32 回绕 |
| DSP | AM/FM 在不同幅度、正负频偏、25–40 dB SNR 下识别；深度、FM 频偏、载频、单音频率与合成预期比较；噪声/无信号/纯载波/削顶拒绝 |
| 音频算法 | 任意块边界与整段滤波输出误差 <1e-6；48 kHz 输出、1 kHz 主频、抗混叠滤波、间断重置、音频队列满/空 |
| 实时服务 | 丢样切段、接收队列溢出、模拟 USB 断连、超时、反复启停、文件回放结束保留最后视图、保存及读取 |
| GUI | 三视图、冻结显示仍继续采集、时间窗口、实际滚轮缩放、记录搜索、1440×940/1100×760 布局、活动流关闭 |
| 离线完整路径 | 4 场景 PASS；`.harness/ads807_host/verification_final/result.json`；同目录 AM/FM 三视图和紧凑窗口截图、捕获目录 |
| 物理音频 | Realtek WASAPI 输出设备 10，48 kHz 单声道；合成 FCR1→解码→AM 解调→约 1.2 秒低音量 1 kHz 扬声器输出，计数见 verification_final/result.json；未评价主观音质 |
| 既有离线契约回归 | IQ 契约 6 项、合成样本 5 项均通过，未修改公共契约 |
| 依赖 | `python -m pip check`：No broken requirements found |

## 发现并修复

- AM 逐块取平均归一化产生边界幅度变化：改为连续一阶平滑包络基准，补充不同分块长度一致性测试。
- GUI 销毁后闭包定时器回调在 Windows Qt 触发 access violation：改为 QObject 控制器信号与接收对象槽，测试活动流关闭。
- Windows Qt offscreen 未加载字体：仅离屏时读取本机系统字体文件，中文与数值均恢复显示。
- 物理音频测试最初用相对等待导致累计供给延误：改为绝对时间节拍，并加入真实输出启动预缓冲；复测无欠载。
- 高 DPI 实际窗口截图会增大主线程开销：镜像缩放到逻辑尺寸、在独立线程编码 JPEG、降低镜像刷新频率，推荐右侧预览使用 offscreen。

## 持续流与边界

单独基准：解码约 125.7 MB/s、DSP 约 2.56 Mcomplex/s、完整处理线程约
1.87 Mcomplex/s（该机器短时测量，不是性能保证）。完整 Qt 窗口加本地镜像的前台
10 秒验证约 498.8 kIQ/s，队列未溢出，CRC/连续性检查无异常。
另一次前台 30 秒 FM 窗口加镜像实测 132960 帧（约 498.98 kIQ/s），
CRC/帧头/连续性/主机丢弃均为 0；证据 `.harness/ads807_host/soak.json`。
最终在运行会话中保留的右侧 AM 镜像，102.765 秒记录 458723 帧，
主机丢弃与连续性异常均为 0；证据 `.harness/ads807_host/preview_health.json`。

后台右侧预览曾在本机同时运行测试/截图的情况下出现接收队列积压及主机丢弃，
校验计数和事件日志可观察到，不能将早先错误会话的画面当作零丢样证据。
USB 性能验收应在实际应用运行条件下独立进行；有限队列不能保证任意调度停顿无丢样。

尚未执行真实 ADS807 USB 接收、ADC/FPGA 上板、射频识别正确率标定、
真实 AM/FM 的深度或频偏精度、端到端时延、持续音频或长期无丢样验收。
未执行综合/实现时序或修改 FPGA，本记录不替代 FPGA 工程的验证结论。
AM/FM 判别为启发式；复杂噪声、低调制度、复合调制与不对称消息等边界仍需更多真实样本。

历史基线当时仅提供 harness 提案；2026-10-18 已注册，当前命令与软件接口见本目录 `README.md`。
