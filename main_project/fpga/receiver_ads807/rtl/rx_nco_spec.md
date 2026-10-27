# rx_nco

43.5 MHz，同步低有效复位。输入 signed12 sample、phase_step32、valid、conjugate。
输出完整 signed24 I/Q 和 out_valid，无饱和。phase 仅在 valid 时累加，复位为零。
1024 点 signed12 Q1.11 正弦 ROM，峰值 2047；同步 ROM 与 sample/valid 对齐。
I=sample*cos；conjugate=0 时 Q=-sample*sin，1 时 Q=sample*sin。
输出在输入接受后的下一拍提交（模块间消费另按非阻塞语义计算）。
参考模型以独立三角函数量化计算，覆盖有效间断、复位、正负频移和全位宽。

```json
{"signal":[{"name":"clk","wave":"p...."},{"name":"valid","wave":"010.."},{"name":"out_valid","wave":"0.10."}]}
```
