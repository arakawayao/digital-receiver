# rx_reset

arst_n 异步低有效置位复位，clk 为目标域时钟（43.5 或 24 MHz）。
两级同步后 wait_count 增长至 bit5=1，再释放输出 rst_n；期间 rst_n=0。
仅 sync 寄存器异步复位，wait_count 在 sync[1]=0 时同步清零；
rst_n=sync[1]&&wait_count[5] 保证断言立即拉低且不暴露未同步计数器释放。
用于 PLL 锁定、暂停/失锁清流后的独立域释放。无数据接口。
复位重复断言必须立即生效；释放延迟按本地时钟计，不用跨域计数器。

```json
{"signal":[{"name":"clk","wave":"p......"},{"name":"arst_n","wave":"01....."},{"name":"rst_n","wave":"0....1."}]}
```
