# rx_tri_packet

clk=USB24MHz，rst_n同步低有效；TRI1 v1 512B，64B头、444B载荷、CRC32/IEEE。
仅IQ(kind1、≤111对I16Q16)和ACK(kind3、48B)。名称tri仅沿用协议名，不代表三种模式。
IDLE先服务ACK，再IQ。IQ_FILL收样本；出现index/epoch/RF/phase/config/estimate/flags变化时封部分帧，
flags仅削顶bit11可在帧内累加；空FIFO的q无效不参与gap判断。
已填非零样本时，12000拍超时或待应答可提前封帧；ACK_FILL通过12路固定32位case取response。
同步RAM读经历RAM_WAIT→LOAD→HOLD，byte_valid && byte_ready时消费，反压保持data/valid。
未用载荷补0；CRC后全局sequence递增，IQ/ACK共用序号。整帧边界仲裁，命令不截断当前帧。
response_ready在最后一字载入payload时确认，之后不再读取源response。
验证：tb_dual读取实际USB总线，以CRC、填充、ACK和实际FIFO写入数据逐点比对。

```json
{"signal":[{"name":"clk","wave":"p......."},{"name":"byte_valid","wave":"0..1..0."},{"name":"byte_ready","wave":"0....10."},{"name":"byte_data","wave":"x..=..x.","data":["held byte"]}]}
```
