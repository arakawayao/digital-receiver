# tb_dual

仿真专用，24MHz真实PLL驱动ADC43.5MHz和USB24MHz。
ADC合成98MHz AM及静默；FX2模型只从外部双向引脚收发，不强制内部locked/调谐真值。
正常/异常共18条TCM1命令；检查手动无锁启动、88/108MHz端点、CRC与保留字段错误、
禁用模式/命令、STOP、自动启动、低可信度不重启DSP。1.5ms IN背压产生预期FIFO丢样。
逐点记录真实FIFO写入值；Python验证上行CRC/载荷/全部元数据，无RAW。
35ms超时，成功DUAL_PASS。

```json
{"signal":[{"name":"rst_n","wave":"01......."},{"name":"mode","wave":"=..=...=.","data":["auto","manual","auto"]},{"name":"signal","wave":"1...0.1.."},{"name":"dsp_run","wave":"0.1.01..."}]}
```
示意图非实际波形；实际证据为仿真日志和WLF。
