# rx_dsp

固定 ADC_RATE=43500000 Hz，500 kS/s I/Q，R87、SHIFT40。
接口为 offset binary ADC12、enable、NCO phase_step32、conjugate，
输出 I/Q signed16、valid、clipped、deadline_error；同步低有效复位。
capture → NCO → 双 CIC → 双通道 FIR。各级 valid 通过寄存链对齐，
ADC 连续时每 87 拍输出一对。conjugate=0 用于本工程正 alias。
单音幅度 A 的稳态输出幅度约 A/2*2047*87^5/2^40；不是归一化电压。
用标准库整数参考逐拍比较，另检查 AM 深度和 FM 瞬时频偏。

```json
{"signal":[{"name":"clk","wave":"p......"},{"name":"enable","wave":"1......"},{"name":"valid","wave":"0...10."}]}
```
