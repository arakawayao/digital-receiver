# rx_control

USB_REPLAY 默认 0，opcode9 返回未知命令。独立样本测试配置为 1 时，opcode9
允许手动且未 tuned 状态写入样本对（argument[23:0]）至地址 requested_rf[11:0]；
高位非零/地址越界返回4，模式错误或已调谐返回5，CRC/保留字段错误仍优先返回。

sample_clk=43.5 MHz，rst_n 同步低有效；command160 和 response384 通过 mailbox。
reset 默认 mode=1、running=1、tuned=0；冷启动无调谐参数时等待原 FPGA 过零估频器。
模式1 FPGA 自动：采纳 detector_rf；相差≤5kHz时只更新NCO步长，保持相位/滤波历史，
标记随后66点暂态；首次捕获或大频差切换增加epoch，清样本索引并复位DSP32周期。
模式2手动：接受88..108MHz整数Hz TUNE，经64周期除法器计算phase32。
手动设置无需detector_locked，TUNE始终增加epoch和config_id；模式切换取消原调谐。
命令优先于自动调谐。仅空闲且无待发送response时接收一条command；response保持至ACK消费确认。
MODE只接受1/2，0返回error4；opcode4/6返回error3；自动模式TUNE返回error5。
QUALITY只更新手动模式的可信度/estimated_rf，不修改载频。无信号允许未知状态。
HOLD=1..60000ms，默认500；每43500拍计1ms，16位计数饱和，避免32位乘法。
短时/长时低可信度均保持DSP及FIFO，超时仅flag10置位；STOP停止写新样本并增加epoch。
IQ valid时sample_index逐点推进（包括FIFO满的点）；配置及索引为u32，按模2^32回绕。
flags:模式bits1:0、tuned8、confidence9、hold_expired10、transient12。
验证：tb_dual检查手动无锁启动、端点、拒绝命令、保持/超时、STOP及自动重启。

```json
{"signal":[{"name":"clk","wave":"p........."},{"name":"TUNE_valid","wave":"010......."},{"name":"divider_done","wave":"0....10..."},{"name":"tuned","wave":"0.....1..."},{"name":"response_valid","wave":"0......1.0"}]}
```
概念图压缩了64周期除法和32周期DSP复位时间。
