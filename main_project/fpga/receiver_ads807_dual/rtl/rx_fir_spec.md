# rx_fir

clk=43.5 MHz，同步低有效复位；500 kS/s signed18 复输入，每 87 拍一次。
61 tap signed18 Q1.17，42 位乘加累加，历史 RAM 不复位，由 filled 屏蔽未初始化位置。
RAM/ROM 同步读；输出在输入接受后 63 拍提交。加 65536 后右移 17，
最近舍入且半值向正无穷，饱和到 signed16，clipped 包含 input_clip。
计算未结束时的新输入触发 sticky deadline_error；无 ready，不能任意提高输入率。
参考模型逐拍比较输出，覆盖 startup、使能间断、复位、滤波和幅度边界。

```json
{"signal":[{"name":"clk","wave":"p......"},{"name":"valid","wave":"010...."},{"name":"busy","wave":"0.1..0."},{"name":"out_valid","wave":"0.....1"}]}
```
