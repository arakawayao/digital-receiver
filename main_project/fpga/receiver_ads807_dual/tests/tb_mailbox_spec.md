# tb_mailbox

仿真专用，source10ns/destination14ns，周期性目的背压。
连续100个顺序payload验证不丢不重、valid/data背压稳定，待处理事务整体复位后验证10次传输。
src_valid/data保持到延迟src_ready。100us超时，成功MAILBOX_PASS。

```json
{"signal":[{"name":"src_clk","wave":"p......."},{"name":"src_valid","wave":"01....0."},{"name":"dst_valid","wave":"0..1.0.."},{"name":"src_ready","wave":"0....10."}]}
```
