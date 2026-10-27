# FPGA 联调资料

本文供独立上位机工程使用，记录2026-10-20基线。FPGA源工程由FPGA同学另行维护，
不是运行合成演示、文件回放、软件测试或接收既有USB数据的Python依赖。

## 当前硬件与协议

生产工程原位置：`main_project/fpga/receiver_ads807_dual/receiver_ads807_dual.qpf`。
目标EP4CE6F17C8、ADS807E，24MHz参考经PLL产生43.5MHz ADC时钟。
12位offset binary，I=x*cos、Q=-x*sin，CIC /87、SHIFT40和FIR后输出500kS/s signed16 IQ。
FPGA FIFO512点，仅1.024ms容量；满时丢当前点并累计。ADC OTR目前未进入DSP/USB。

USB为FX2 USB2.0高速Bulk：04B4:1004，EP2 IN=0x82、EP6 OUT=0x06，512字节包。
当前下行TCM1 v2、上行TRI1 v1。v2 TUNE由主机计算NCO步进；历史v1 SOF不兼容。
MODE1为FPGA自动估频、MODE2为手动；MODE0及opcode4/6已撤销。
协议字段、ACK和保持语义见 [PROTOCOL.md](PROTOCOL.md)。

ADC引脚已按用户提供的P3接线配置，但采样相位、板级延迟、VDRV、模拟预选和RF动态性能仍需实测。
已约束Quartus时序通过不等于ADC电气/板级接口或真实射频验收通过。

## 测试固件与普通应用

普通GUI不烧录。默认USB已要求两模式生产固件；历史FCR1文件可回放。
2026-10-23交付主SOF已更新为10月22日构建，哈希见清单，本轮尚未上板复测。
普通GUI先启动异步IN接收，再发送控制；ACK经独立路由分发，停止时等待STOP ACK后关闭USB。
软件修正与当前离线证据见 [USB_STABILITY.md](USB_STABILITY.md)。
`ads807.dual_control_test` 和 `ads807.dual_sample_test` 有下载SOF等硬件副作用，
仅在FPGA同学提供对应固件、构建摘要及工具路径后使用。固件交付布局见
[firmware/README.md](../firmware/README.md)。

旧 `ads807.board_test` 是三模式ROM矩阵的历史诊断入口，不能作为当前两模式验收入口。
其配置清单位于 `host/.harness/tri_board_test/ready.json`；该清单及其SOF必须由历史工程负责人提供。
清单的sof路径支持绝对路径，交付时应改为本目录内的路径并保留匹配的sha256。
旧回放CLI已迁入 `ads807/legacy/`，默认输出也落在本工程内。
历史工具中的可选PyUSB后端及缺失的usb_replay_gui不是当前PyQt工作台的必需依赖。

## 已有实板证据边界

- 2026-10-20生产SOF控制测试：ADC未接入，60秒440条命令ACK符合预期，CRC/序号无异常。
- 同日专用RAM样本回放：手动AM/800首组10秒通过，第二组AM/80等待STOP ACK超时，整轮FAIL。
- 上述均不能替代真实ADC、射频识别精度、持续音频及长期零丢样验证。

交接所需结果摘要随包保存在 `evidence/`；历史上位机详细日志迁入 `.harness/ads807_host/`。
原始FPGA构建、时序和仿真产物仍由FPGA负责人保管。下一步共同填写 [HANDOFF.md](../HANDOFF.md) 的对齐表。
