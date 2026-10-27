# AM 停止改频后重新开始

日期：2026-10-26。状态：上位机诊断和 FPGA 修复候选已实现，专项 RTL 回归通过；
最终候选构建和实板验证状态见下文。尚未确认用户实机问题解决。

## 用户确认的输入

- 上位机选择 FPGA 自动估频，信号源 AM 深度 50%，载频 98 MHz。
- 输出 600 mVpp，直接连接 ADC，不经过 LNA。
- AM 调制频率及改频前后完整数值尚未提供；仿真采用 500 Hz 及代表性跳频。
- 信号源的电压不能在未核对 ADC 输入网络和满量程时直接换算为 ADC 码。

## 原因与修改

上位机每次开始会新建解包器、队列、调谐会话和解调器，并发送 QUERY、MODE、HOLD。
MODE 会取消旧调谐。FPGA 必须重新取得合格估频，才能使能 DDC 输出 I/Q。
此前估频器的固定 16 码过零门限在 AM 包络低谷可能漏计过零；STOP 期间估频器仍运行，
也可能把改频前后的样本混入同一估频窗口，随后保留有偏差的结果。

最终 RTL 修改限于 `receiver_ads807_dual/rtl/` 两个文件：

- `rx_frequency.v`：HYSTERESIS 默认从 16 降为 4。
  保留 GAP_SPREAD=3、平均幅度、削顶和频段资格条件。
- `receiver_top.v`：估频器同步复位条件增加 `running`；STOP 期间清理旧估频状态，
  MODE 重新启用接收后按当前输入建立新窗口。

未改变采样率、DDC I/Q 格式、TCM1/TRI1 协议、引脚分配或 FPGA 型号。
普通上位机启动不会把 RTL 或 SOF 自动下载到 FPGA。

最终候选 SOF：`firmware/receiver_ads807_dual/receiver_ads807_dual.sof`，
SHA256 `85524982f44c1a77ede67030c1bdda9855625c77adc856cd8e58b6e9c2583500`，
由 Quartus Prime 18.1 assembler 于 2026-10-26 13:29:43 生成。
候选已替换 host 主 SOF 路径，原 2026-10-22 SOF 未在本轮保留副本；
不要把相同文件名理解为与原固件二进制相同。manifest 与当前文件哈希已核对一致。

构建：map、fit、12 项多工况约束时序检查及 assembler 全部通过；
EP4CE6F17C8 使用 5187/6272 LE，最小约束裕量 0.103 ns。
ADC 输入/输出及 PCB 时序尚未签核；本次未更改既有时序约束来获得通过。
交付证据摘要在 `evidence/am_restart_20261026/`，不依赖 `.harness` 保留。

上位机诊断：

- 启动日志含 `启动检查 v2026-10-26`，手动模式显示本次实际载频。
- 自动模式后台约每 0.5 秒 QUERY；即使没有 I/Q 也能观察 FPGA 是否已调谐。
- 超过 2 秒尚无 I/Q 时记录启动诊断，不伪造信号、不自动改为手动模式。
- STOP ACK 返回或明确超时后才结束接收，GUI 线程不等待 ACK。

## 验证证据

可重现入口（从 host 执行，需要实际 FPGA 源码和 ModelSim）：

```powershell
& 'D:\conda_envs\ads807_host\python.exe' -B tests/fpga/run_am_restart.py --rtl-root ../fpga/receiver_ads807_dual
```

该检查已注册为根 harness 的 `ads807-am-restart-rtl`。测试台为
`tests/fpga/tb_am_restart.v`，结果在 `.harness/am_restart_validation/summary.json`。
运行器检查日志中的 Fatal/Error 以及明确的通过标记，不能仅凭 ModelSim 退出码判断成功。

- 50% AM、500 Hz 调制，80/400/800 ADC 码载波峰值，各连续经历
  98→103.7→99.5 MHz：9 次停止改频重启均通过；过程中 AM 始终开启，不插入正弦波。
- 同时检查 detector_locked、tuned、dsp_run，以及载频估计误差小于 2 kHz。
  本次这些场景实际最大误差约 214 Hz；该数值是合成输入仿真结果，不是仪器精度承诺。
- 无信号、8 码弱载波、削顶输入、确定性宽带噪声四类输入均拒绝启动 DSP。
- 原 `tb_frequency` 九场景通过，包含频段边界、FM、AM、低电平及直流输入。
- 上位机 Python 回归 131 项通过；其中同一模拟设备保留状态的手动改频测试
  验证了新 TUNE、非零解调波形和 STOP ACK。它与上述自动模式 RTL 回归是不同证据。

本次只连接实际估频器和控制器；不包含完整 ADC 时序、DDC 数值、USB 或扬声器。
FPGA 构建通过也不能替代实际射频接收与音频验证。

## 已知边界

- 探测中，80 码、50% AM 在 108 MHz 可能漏计或误估，不能用中频段结果宣称
  所有幅度下整个 88–108 MHz 频段已通过。原边界回归采用较强的输入。
- 95%/99% 深调制的部分低幅度场景仍失败，本修复不声称覆盖这些条件。
- 曾尝试把 GAP_SPREAD 放宽到 12；它允许有偏差的结果通过，最终未采用。
- DSP 削顶标志不能覆盖所有模拟前端过载；600 mVpp 的实测输入是否合规仍应核对 ADC 输入电路。

## 实板复测

1. 加载最终候选 SOF，确认下载器、器件及板卡连接与候选清单一致。
2. 保持用户的 50% AM、600 mVpp 直连 ADC，记录实际调制频率。
3. 自动估频锁定后停止，保持 AM 开启，只改载频，然后开始；重复往返至少三次。
4. 记录调谐载频、识别结果、I/Q 和解调波形、CRC、连续性、主机/FPGA 丢样和音频。
5. 若仍失败，保留新上位机启动日志和采集记录，不再依靠退出 AM 来掩盖问题。

本次只读枚举返回 `No JTAG hardware available`，尚未下载候选 SOF。
