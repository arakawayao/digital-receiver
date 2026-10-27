# rx_fx2

clk=24 MHz，同步低有效复位，外送反相 IFCLK；源板 FX2 EP2 IN。
tx_data8/valid/ready 接口仅 valid&&ready 时消费；ready 由 WRITE、寄存 FLAGB、
rst_n、pause 决定。每次写后保护一拍，复位/暂停后 SETTLE 等待四拍。
dq 在 rst_n 时驱动注册数据，否则高阻；SLRD/SLOE 保持无效，不读取 EP6。
FIFOADR=00，PKTEND 高，SLCS 随复位，SLWR 为注册低脉冲。
FLAGB 延迟和 FX2 实物服务速率需要板级联调；仿真不代表实际驱动通过。

```json
{"signal":[{"name":"clk","wave":"p......"},{"name":"tx_valid","wave":"1......"},{"name":"tx_ready","wave":"01010.."},{"name":"slwr_n","wave":"1.0101."}]}
```
