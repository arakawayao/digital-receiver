# receiver_top

24 MHz `clk`、低有效外部复位；PLL 输出 43.5 MHz ADC 和 24 MHz USB。
`adc_data[11:0]` 为 ADS807E offset binary，MSB 对应 Bit 1，LSB 对应 Bit 12。
输入每拍先寄存，不反压；`adc_clk` 连续输出。USB 数据总线 8 位双向端口在本工程只写。
`usb_flagb` 表示 EP2 可写，PA1 异步暂停；其余 USB 引脚沿用源板约定。
`led` 表示 PLL、测频锁定且 DSP 未报告 deadline error。

检测锁定前 DSP 复位。失锁/暂停异步清流，各时钟域同步释放并等待 32 拍。
锁定 RF/phase 总线保持稳定，USB 域先同步 locked 再读总线；未进行独立 CDC 工具签核。
FIFO 满丢当前 I/Q，index 继续增加，dropped 饱和累加；重启流时 index/dropped 清零，epoch 增加。
ADC 引脚虚拟、无板级时序；ADC 自身 6 拍转换延迟在外部，不由本模块补偿。

验证：真实生成 PLL/FIFO/DDIO 仿真、98 MHz AM 自主锁定、持续 /87 I/Q、
CRC/完整载荷对照、静默失锁；不代表真实 USB、ADC 或射频实测。

```json
{"signal":[{"name":"sample_clk","wave":"p......."},{"name":"frequency_locked","wave":"0.1....."},{"name":"stream_sample_n","wave":"0...1..."},{"name":"iq_valid","wave":"0.....10"}],"config":{"hscale":2}}
```

此图为释放顺序示意，省略 32 拍等待和 R87 节拍；未安装 WaveDrom 渲染器。
