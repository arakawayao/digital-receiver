# rx_sample_replay 测试样本源

仅用于 receiver_usb_samples 配置，不属于正式 ADC 采样入口。
43.5 MHz 同一时钟域，rst_n 同步低有效。写入地址为 0..4095，每地址包含两个
12 位 offset-binary ADC 样本，低 12 位先回放。内存 4096 x 24，无内存复位。
write_enable 每个有效命令脉冲一次；写入必须从地址 0 开始并严格连续。
完整 8192 点写入后 loaded 置位，连续循环输出；未完成时输出中点 2048。
乱序写入清除 loaded，重新从地址 0 上传。注册 RAM 读出与高低选择均延迟一拍。
不驱动 ADC 数据引脚；不支持上传与回放并行，上一轮需 STOP 后切手动模式再写。

```json
{"signal":[{"name":"clk","wave":"p......"},{"name":"write_enable","wave":"01010.."},{"name":"write_address","wave":"x2.3.x.","data":["4094","4095"]},{"name":"loaded","wave":"0...1.."},{"name":"adc_data","wave":"2...333","data":["2048","sample0","sample1","sample2"]}]}
```

验证包含不完整上传、乱序拒绝、连续回放跨环、第二轮上传替换。
顶层 USB_REPLAY 默认 0，rx_control 同名参数默认 0；只有测试配置启用 opcode 9。
该命令 argument 低 24 位为样本对、rf_hz 字段借作地址；高位非零返回错误 4，
非手动模式或已经 tuned 返回错误 5，正式配置始终返回未知命令错误 3。
测试配置 FIFO 为 256 对 I/Q（0.512 ms）；正式配置仍为 512 对（1.024 ms）。
