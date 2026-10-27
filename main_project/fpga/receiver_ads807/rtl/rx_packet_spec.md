# rx_packet

24 MHz，同步低有效复位。show-ahead FIFO97 排列为
{clip1,dropped32,index32,Q16,I16}；非空且 FILL 且无 index 缺口时 fifo_read 消费。
输出 byte_data8/byte_valid/byte_ready，只有 valid&&ready 推进字节；反压保持字节。
每帧 512 字节：60 字节小端头、112 对 I16/Q16 容量、CRC32 IEEE reflected。
version2，ADC_rate43500000，IQ_rate500000，SHIFT40，容量112；RF 为本地估计值。
index 缺口终止部分帧，下一样本留待下一帧；未满载荷零填充。
失锁可截断字节流，消费者需 magic/version/CRC/epoch 重同步。
完整帧 CRC 和实际 FIFO 载荷逐值比较；本轮正常链路无缺口，故障覆盖见验证边界。

```json
{"signal":[{"name":"clk","wave":"p......"},{"name":"byte_valid","wave":"01...0."},{"name":"byte_ready","wave":"0...1.."},{"name":"byte_data","wave":"x=...x.","data":["held"]}]}
```
