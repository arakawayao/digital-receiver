# rx_command

clk=USB24MHz，rst_n同步低有效。rx_valid && rx_ready消费一个字节；反压时上游保持字节。
扫描TCM1，收满512B后校验CRC32/IEEE、version和所有保留字节。错误也产生带序号的应答请求。
command[31:0]=sequence，[63:32]=opcode，[95:64]=argument，[127:96]=RF，[159:128]=error。
直接在最终command寄存器中逐字节组装，CRC完成前command_valid=0，不能应用半条命令。
CRC错误1，版本/保留字段错误2；command_valid保持至mailbox延迟src_ready。
只有一个待处理命令，等待时rx_ready=0，command所有字段保持不变。
复位丢弃当前半包，主机需重连后按完整帧重新发起。不能对ACK超时盲目重发。
验证：tb_dual从真实FX2 OUT引脚输入正常、错误CRC、非零保留字段命令并核对应答。

```json
{"signal":[{"name":"clk","wave":"p......."},{"name":"last_byte","wave":"010....."},{"name":"command_valid","wave":"0.1...0."},{"name":"command_ready","wave":"0....10."},{"name":"rx_ready","wave":"1.0...1."}]}
```
