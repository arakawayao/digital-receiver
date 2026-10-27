# rx_fx2_tri

USB24MHz同步SlaveFIFO，转发反相IFCLK；EP2 IN地址00，EP6 OUT地址10。
FLAGB=所选FIFO非满，FLAGC=所选FIFO非空；切换地址/方向后等待稳定再使用寄存后的标志。
DQ连续输入寄存，RX_ENABLE等待3拍后RX_READY读已稳定头，再在后续SLRD边沿消费。
TX有效/ready时锁存字节，随后写选通；DQ仅TX_STROBE/GUARD驱动，读模式高阻，避免总线争用。
每方向最多64字节预算，防止长IN流饿死命令OUT；单字节接收寄存保持至rx_ready。
rst_n同步低有效，空闲输出写/读无效，pktend_n固定1（始终512B整包）。
SDC读数据tXFD≤15ns与写控制/数据建立保持源自既有板接口，PCB延迟尚待实测。
FAST_INPUT_REGISTER对8个DQ分别设置，不能用带字面大括号的节点名使约束被忽略。
验证：tb_dual真实引脚级IN/OUT双向、命令CRC和TX背压；不代表实板USB时序验收。

```json
{"signal":[{"name":"clk","wave":"p......."},{"name":"tx_ready","wave":"010....."},{"name":"slwr_n","wave":"1.01...."},{"name":"sloe_n","wave":"1...0..."},{"name":"slrd_n","wave":"1.....01"}]}
```
