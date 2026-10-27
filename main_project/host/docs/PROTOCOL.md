# 两模式 TCM1 / TRI1

上位机接口基线，更新日期2026-10-23。软件实现位于 `ads807/interfaces/protocol.py`（相对host根）。
当前为TCM1 v2 / TRI1 v1，与两模式FPGA当前源码对齐。
协议变更必须由FPGA与HOST共同更新实现、本文和两端测试。

保持已有wire编号，mode1=FPGA自动、mode2=手动；mode0已撤销，不能重编号为自动。
所有整数小端u32，I/Q为小端signed16，固定512B，末4B为前508B的CRC32/IEEE。
FX2 EP6 OUT=0x06，EP2 IN=0x82。每次只等待一条命令ACK，不盲目重发。

## 命令 TCM1

offset0为ASCII TCM1，4=version2，8=sequence，12=opcode，16=argument，20=RF整数Hz。
24..507全零。FPGA收完整帧、校验CRC后才应用；错误命令也返回同序号ACK。

| opcode | 命令 | 参数及效果 |
| --- | --- | --- |
| 1 | QUERY | 返回当前状态，不切换频道 |
| 2 | MODE | argument1/2；重新启用接收，取消旧调谐、增加epoch |
| 3 | TUNE | 仅手动模式且running；RF=88000000..108000000；argument为主机计算的NCO步进；无需估频锁定 |
| 5 | QUALITY | 仅已调谐手动模式；argument0/1，1时RF为估计中心87..108.75MHz；不改LO |
| 7 | STOP | 停止产生新I/Q；FIFO内旧样本仍带原元数据排出；不截断在途帧 |
| 8 | HOLD | argument1..60000ms，默认500；超时仅置标志，不取消调谐 |

opcode4 SNAPSHOT与6 TRACK不再支持，返回error3。
error0成功、1CRC错误、2版本/保留字错误、3未知命令、4参数越界、5模式/状态不允许。
MODE0返回error4；自动模式TUNE返回error5。旧主机自动搜索程序不能用于本固件。

TUNE argument = floor(((RF-87000000) * 2^32 + 21750000) / 43500000)。
例如98MHz对应1086083684。v1由FPGA计算步进，v2把该计算移到主机，二者不能混用。
FPGA范围检查argument；主机必须核对ACK回读的RF、phase_step和已调谐标志。
主机收到版本/保留字error2时提示核对板上固件；该提示不能证明板上实际版本。

## 上行 TRI1

64B头，共16个u32；offset64..507是444B载荷，未用补零；offset508是CRC。

| 字索引 | 内容 |
| --- | --- |
| 0 / 1 | ASCII TRI1 / 0x00400001（头长64、版本1） |
| 2 / 3 | kind：IQ1、ACK3 / 全局帧序号（跨IQ/ACK递增） |
| 4 / 5 / 6 | epoch / 首样本index / 样本数或ACK字节数48 |
| 7 / 8 | ADC43500000Hz / IQ500000Hz |
| 9 / 10 | tuned_rf Hz / phase_step u32 |
| 11 / 12 | flags / IQ累计dropped或ACK命令sequence |
| 13 / 14 / 15 | config_id / estimated_rf Hz（不可信为0） / IQ SHIFT40或ACK0 |

IQ每帧1..111对I16/Q16；ACK为12个u32：
sequence、opcode、error、mode、tuned_rf、phase_step、epoch、config_id、sample_index、flags、estimated_rf、hold_ms。
kind2 RAW仅留在软件中支持历史文件回放；本硬件无快照RAM，不产生RAW。

flags bits1:0为模式；8已调谐、9可信、10保持超时、11削顶、12暂态、13累计溢出。
“已调谐”仅说明NCO配置有效，不代表有信号或可放音。手动参数不依赖检测器locked。
LO=87MHz+phase_step×43500000/2^32；按最近整数步长舍入。
I=x*cos，Q=-x*sin，I+jQ不共轭。signed16除32768是数字归一化值，不代表电压/功率。

## 连续性与CDC

sample_index包括因满FIFO丢弃的样本；dropped饱和u32，epoch变化时重新累计。
epoch改变表示DSP重启；config_id也标记保持相位的自动微调。索引/epoch/config/帧序号按u32回绕。
每点携带完整元信息，头字段变化时封部分帧，避免切换后旧样本被错误标注新载频。
CRC错误、全局序号缺口、index缺口均由上位机观察并重建连续段，不能静默拼接。
低可信度/保持超时不清FIFO，也不会触发上位机重搜。暂态帧不进入解调或可信度估计。

命令USB→采样域、ACK反向使用toggle握手；源payload保持到目的消费确认返回。
不支持单独复位任一域。PLL失锁/全局复位会取消未完成事务，需重新建立主机连接。
FIFO512点=1.024ms容量，满帧协议2.3063MB/s，加25%余量约2.883MB/s，ACK/换向/总线开销另计。
