# tb_board_replay

用途：验证 `tri_replay_build.py` 生成的 EP4CE6 固定模式 ROM 回放工程。
24 MHz 参考时钟；低有效复位，真实 Intel PLL 产生 43.5 MHz 采样和 24 MHz USB 时钟。
无物理 ADC 端口，ROM 4096×12 offset binary；实际 DSP 输出为 500 kS/s I16/Q16。

FX2 使用 indexed FLAG，FLAG 延迟 13.5 ns，数据延迟 15 ns。主机按 512 B 命令发 QUERY、
固定 MODE、HOLD、TUNE、SNAPSHOT、STOP，未公布的 OUT 字节不得读取。
记录 USB 输出、每个采样时钟的 ROM 输出，以及实际 DUT 的 epoch/index/I/Q。
在 Python 侧核对 ROM 固定流水延迟、RAW 环形周期、USB 与 DSP 逐样本相等、6 条应答、
无正常 FIFO 溢出、无 FIR 截止错误及真实生产 FM 分析。12 ms 看门狗防止挂起。

```json
{"signal":[{"name":"reference24","wave":"p......."},{"name":"rst_n","wave":"01......"},{"name":"MODE/TUNE","wave":"0.1.0..."},{"name":"dsp_run","wave":"0...1..."},{"name":"IQ_valid","wave":"0....101"},{"name":"USB_frame","wave":"x....===","data":["ACK","RAW","IQ"]}]}
```

时序为概念示意，精确时间以 ModelSim 日志为准；未通过技能 WaveDrom 渲染器渲染。
