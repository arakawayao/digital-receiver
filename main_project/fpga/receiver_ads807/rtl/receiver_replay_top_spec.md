# receiver_replay_top 接口与时序约定

用途为 EP4CE6F17C8 无 ADC 的 USB 内部回放，操作与格式见 `../USB_REPLAY.md`。
`clk`=24 MHz；`rst_n` 低有效；PLL 生成 43.5 MHz 采样与 24 MHz USB 时钟。
各域异步断言复位，经 rx_reset 同步释放并等待 32 拍启动。
`usb_pa1` 保留板卡输入但不控制运行；无 ADC 外部端口。

`usb_dq[7:0]` 为双向三态总线；`usb_flagb`/`usb_flagc` 为 indexed FLAG 输入。
`usb_pclk` 输出反相 USB 时钟；`usb_wr`/`usb_rd`、`usb_pa7`（SLCS）、
`usb_pa2`（SLOE）低有效；`usb_pa5`/`usb_pa4` 为 FIFOADR 高/低位。
`usb_pa6`（PKTEND）、`usb_pa0` 恒高。`led` 为 PLL、回放和载波锁定且 DSP 无截止错误。

输入使用 rx_ready/rx_valid，输出使用 byte_ready/byte_valid，停顿时保持数据。
只在完整输出帧边界接收命令，STOP 后残缺帧补齐 512 B 再发送 ACK；
补齐帧 CRC 不保证正确，不得用于分析。新 START 后帧和样本索引从 0 开始，epoch 递增。
USB 写 RAM，采样域读 RAM；STOP/BEGIN 等待 inactive 同步确认，DATA 仅在停止时提交。
长度停止时写入，启动同步及运行中保持，稳定总线传入 sample_length。
未完整上传禁止启动；RAM 不复位；每拍读一个 ADC12 offset binary 样本，length-1 后回 0。

无活动/无可信载波时没有有效 I/Q。锁定和流复位释放等待完成后 DSP 工作，
混频 I=x*cos、Q=-x*sin，CIC /87 与 61 tap FIR 输出 500 kS/s。
满 FIFO 丢样并计数，帧携带索引、epoch、频率、削顶与丢样状态。

WaveJSON 示意（不同域事件示意，不表示两时钟等频）：

```json
{"signal":[{"name":"usb_clk","wave":"p..........."},{"name":"RPL1","wave":"x.2.3.4...5.","data":["BEGIN","DATA/ACK","START/ACK","STOP/ACK"]},{"name":"RAM writable","wave":"0.1...0....."},{"name":"sample active","wave":"0......1..0."},{"name":"frequency lock","wave":"0.......1.0."},{"name":"FCR1","wave":"x........2.x","data":["IQ frames"]}]}
```

tb_usb_replay/replay_check 覆盖非法命令、周期边界、USB 方向、逐点回放、I/Q 间隔、
溢出与截止错误、USB 载荷和生产分类。实板、任意实时消息及物理音频尚未验证。
