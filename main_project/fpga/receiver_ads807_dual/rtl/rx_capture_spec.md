# rx_capture

43.5 MHz `clk`，`rst_n` 同步低有效。12 位 `adc` 输入按 `OFFSET_BINARY`
选择翻转 MSB 或保持补码，输出 signed12 `sample`。enable=1 的上升沿更新 sample，
valid 跟随 enable；enable=0 保持 sample、valid=0。复位 sample/valid=0。
无 ready/反压。覆盖 4096 个码值、复位和使能间断。

```json
{"signal":[{"name":"clk","wave":"p...."},{"name":"enable","wave":"01.0."},{"name":"valid","wave":"0.1.0"}]}
```
