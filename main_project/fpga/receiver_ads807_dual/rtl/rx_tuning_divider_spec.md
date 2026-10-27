# rx_tuning_divider

clk=43.5MHz，rst_n同步低有效；start空闲时启动，活动时忽略start。
rf_hz仅接受由control事先校验过的88..108MHz u32。
计算 round((RF-87000000)*2^32/43500000)，64位恢复除法，除数常量，64步迭代，无组合除法器。
start装入分子和半除数21750000，随后每拍移位/比较/相减，done一拍，phase_step保持至下次完成。
phase_step正数且小于2^31，32位无符号NCO步长，I/Q方向与原DSP一致。
验证：tb_dual的88/98/108MHz结果与Python整数舍入参考比较。

```json
{"signal":[{"name":"clk","wave":"p......."},{"name":"start","wave":"010....."},{"name":"active","wave":"0.1...0."},{"name":"done","wave":"0.....10"},{"name":"phase_step","wave":"=.....=.","data":["old","rounded result"]}]}
```
迭代区间压缩为示意。
