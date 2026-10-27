# rx_mailbox

WIDTH参数；两端独立时钟，均低有效异步置复位，必须整体复位且本地同步释放。
**src_ready为目的端消费完成的延迟确认**，不表示启动时可立即交付。
源端assert src_valid后必须保持src_data/valid直到src_ready。
以request_toggle跨两级同步置dst_valid，dst_valid && dst_ready消费一次并翻转ACK；
ACK经两级源同步后才给src_ready。目的背压期间dst_data、dst_valid稳定。
dst_data直接连接源寄存器，省去两份宽总线缓存。parser/control是唯一生产者且遵守上述保持契约。
源数据在request同步前已稳定，ACK返回前不变；SDC将命令到控制限制20ns、response到packet限制35ns，
均小于相应目的周期；仅同步器第一级设false_path，未设置宽泛clock-group异常。
禁止接入会在等待确认时改变数据的生产者；禁止独立复位任意一侧。
验证：tb_mailbox采用10/14ns不同时钟、100次传输、目的背压、待处理交易整体复位及重传。

```json
{"signal":[{"name":"src_valid","wave":"01......0"},{"name":"src_data","wave":"x=......x","data":["payload"]},{"name":"dst_valid","wave":"0...1.0.."},{"name":"dst_ready","wave":"0....1..."},{"name":"src_ready","wave":"0......10"}]}
```
