# receiver_top

USB_REPLAY 默认 0，正式工程仍直接采集 adc_data，FIFO512。
独立 receiver_usb_samples 配置将其置 1：使用 rx_sample_replay 替换输入，FIFO256，
未完整写入时估频器复位。测试 opcode9 经同一 CRC/命令邮箱写入样本 RAM，
仅手动且未 tuned 时允许写入，细节见 rx_sample_replay_spec.md；正式配置不识别此命令。

从 `../receiver_ads807` 复用采集/估频/NCO/CIC/FIR/reset 和 PLL；目标 EP4CE6F17C8。
单通道 ADC12 offset-binary，43.5 MHz 上升沿连续采集，输出 adc_clk；参考 clk=24 MHz。
rst_n 低有效；PLL 锁定后，各域 rx_reset 同步释放。I=x*cos，Q=-x*sin，500 kS/s signed16。
DSP 变频参数由 sample_clk 域控制。MODE/TUNE/STOP 可重置 DSP，低可信度不重置。
USB=24 MHz，EP2 IN / EP6 OUT，握手经两个 rx_mailbox。usb_pa1 同步后暂停 TX；不清 FIFO。
FIFO512×288 存储每点的 I/Q、index、dropped、epoch、RF、phase、flags、config、estimate，
全局复位才清空 FIFO。更换配置时旧数据带旧元信息排出，禁止与新配置合帧。
满时丢弃当前样本，index 继续推进、dropped 饱和累计，epoch 变化后重新累计。
USB packet 不受 MODE/TUNE/STOP 复位，始终发送完整 CRC 帧。
ADC12位、OTR和时钟已按用户P3原理图及接线顺序配置3.3-V LVTTL物理引脚，均非虚拟；
新增adc_otr为独立预留输入，暂未用于DSP或上位机协议，数字削顶标志含义不变。
ADC接口/参考板PCB延迟尚未签核。不能据内部时序通过直接烧录。

验证：tb_dual 驱动 ADC 和真实 FX2 引脚；对每个输出 I/Q 与实际写 FIFO 的值及元数据核对。

```json
{"signal":[{"name":"sample_clk","wave":"p......."},{"name":"tuned","wave":"0.1....."},{"name":"dsp_run","wave":"0...1..."},{"name":"iq_valid","wave":"0....10."}]}
```
概念时序：调谐后32周期释放DSP，I/Q的实际首次延迟由原DSP流水线决定；图不按比例。
