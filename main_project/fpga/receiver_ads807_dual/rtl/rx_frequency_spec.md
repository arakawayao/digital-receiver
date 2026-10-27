# rx_frequency

clk=43.5 MHz，同步低有效复位。输入寄存后的 offset binary ADC12。
输出 phase_step32、RF_Hz32、locked、update、valid_window、measured_bins16。
65536 点窗口，Q10 DC IIR，±16 迟滞正向过零；幅度均值至少 32 码，
窗口裁剪次数不超过 256，alias 约 1–21 MHz，周期 gap 2–46，分散不超过 3。
连续两个合格窗口差不超过 32 count 才锁定，锁定后超差或无效则失锁。
phase_step=(两窗 count 之和)<<15，alias=round(pair*43500000/131072)，
RF=87000000+alias，RF 元数据按 88–108 MHz 端点夹紧。
换算四拍流水，phase/RF/locked/update 同拍提交，锁定期间 LO 保持。
不是 AM/FM 分类器，也不消除真实采样的奈奎斯特区歧义。
覆盖端点、AM、FM、静默、直流、弱信号；普遍精度、低 SNR 和多载波未验收。

```json
{"signal":[{"name":"clk","wave":"p......."},{"name":"qualified_pair","wave":"010....."},{"name":"acquire_state","wave":"0=.=.=.0","data":[1,2,3,4]},{"name":"update","wave":"0.....10"},{"name":"locked","wave":"0.....1."}]}
```
