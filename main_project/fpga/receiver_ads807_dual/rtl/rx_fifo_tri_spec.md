# rx_fifo_tri

ADDRESS_BITS 默认为9（512点）；独立 USB 样本测试配置传入8（256点），
宽度288、showahead及满时丢当前点语义不变。

Intel dcfifo，512×288bit，showahead ON，EAB ON；wrclk43.5MHz、rdclk24MHz。
全局aclr异步置位，read/write_aclr_synch ON，各方向同步器4级。
data从低到高每32位依次为{Q16,I16}、index、dropped、epoch、RF、phase、flags、config、estimate。
wrreq仅在非满写入，rdreq仅在非空且packet接受时读取。满丢当前点并由top计数，不覆盖旧点。
空时q不是有效头，packet不得比较其元信息。tune/失锁不清FIFO，保留旧epoch可追溯样本。
容量为1.024ms I/Q，正常协议2.3063MB/s，预留25%约2.883MB/s；USB长期停顿必然溢出。
验证：tb_dual真实Intel模型包含1.5ms主机背压，检查丢样可见和恢复后逐点载荷。

```json
{"signal":[{"name":"wrclk","wave":"p......"},{"name":"wrfull","wave":"0..1.0."},{"name":"wrreq","wave":"0110.1."},{"name":"rdempty","wave":"1.0...."},{"name":"rdreq","wave":"0...10."}]}
```
