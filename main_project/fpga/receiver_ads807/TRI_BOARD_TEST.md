# EP4CE6 三模式可视化实板回放

2026-10-20：ADC 尚未接入，输入为合成 ADC12 码；DSP 和 FX2 USB 必须在实际板上运行。
本入口沿用根目录 PyQt6 上位机的解析、AM/FM 识别、解调和绘图；不自动打开扬声器。

## 模式与波形

| 模式 | 实板配置 | 输入 | 周期单音 |
| --- | --- | --- | --- |
| 上位机自动搜索 | 固定模式的 TRI1，EP4CE6 | 4096 点 ROM；真实 ADC 快照经 USB 上传后，由生产搜索函数调谐 | 10620.1171875 Hz |
| FPGA 自主估频 | 已验证的 `receiver_replay.sof`，RPL1/FCR1 | USB 上传一次 8192 点 RAM，然后自由运行 | 5310.05859375 Hz |
| 手动载频 | 固定模式的 TRI1，EP4CE6 | 4096 点 ROM；按实际载频 TUNE | 10620.1171875 Hz |

由于原三模式同时启用的实现超过 EP4CE6 资源，三种模式按独立 SOF 分别验证。
不能将本测试宣称为同一 SOF 下三模式热切换已通过。固定 TRI1 配置拒绝其他模式的 MODE 命令。
FPGA 自主模式仍使用原自主过零估频器，未将主机测得的载频设置伪装为 FPGA 测量。

所有波形为单通道 12 位 offset binary、中心 2048 码；ADC 采样率 43.5 MS/s。
载波峰值幅度分别为 800 / 80 码，相差 20 dB；AM 调制度 0.5，峰值包络分别 1200 / 120 码。
FM 频偏 ±25 kHz。请求 RF=98 MHz，周期栅格实际 RF=98002441.40625 Hz，正别名=11002441.40625 Hz。
I=x*cos、Q=-x*sin；继承原 CIC/FIR 定点配置，500 kS/s signed I16/Q16，小端。
没有加入模拟噪声、前端非线性或 ADC 时钟抖动，因此小幅度通过也不等于模拟弱信号性能通过。

TRI1 每帧最多 111 对 I/Q，约 2.306 MB/s；FCR1 最多 112 对，约 2.286 MB/s。
TRI1 为容纳 ROM 将 FPGA FIFO 改为 256 点（0.512 ms）；原 FCR1 为 512 点（1.024 ms）。
USB 芯片及主机还有缓存，但不能据此保证任意操作系统停顿都不丢样。

## 构建与验证

在项目根目录使用 `D:/conda_envs/ads807_host/python.exe -B` 执行：

```powershell
& 'D:/conda_envs/ads807_host/python.exe' -B main_project/fpga/receiver_ads807/scripts/tri_replay_build.py --mode auto
& 'D:/conda_envs/ads807_host/python.exe' -B main_project/fpga/receiver_ads807/scripts/tri_replay_build.py --mode manual
& 'D:/conda_envs/ads807_host/python.exe' -B main_project/fpga/receiver_ads807/scripts/tri_replay_build.py --mode fpga
& 'D:/conda_envs/ads807_host/python.exe' -B main_project/fpga/receiver_ads807/scripts/tri_replay_check.py auto
& 'D:/conda_envs/ads807_host/python.exe' -B main_project/fpga/receiver_ads807/scripts/tri_replay_check.py manual
& 'D:/conda_envs/ads807_host/python.exe' -B main_project/fpga/receiver_ads807/scripts/tri_replay_ready.py
```

构建脚本在 `.harness/tri_board_test/<mode>/project/` 复制原三模式工程并进行显式基线匹配转换。
生成差异包括：ROM 输入、固定调谐权限、256 点 FIFO、ACK 显式字选择，
以及 mailbox 保留源端 held_data、目的端直接使用稳定总线，去除重复目的端寄存器。
请求经过两级同步后才发布 dst_valid，消费者接受后才返回 ACK，ACK 再同步回源端后才能改写总线。
两域整体复位；USB→采样、采样→USB 的稳定总线分别约束最大延迟 20 / 35 ns，不给数据总线加 false path。
PA1 不暂停此测试配置；启停由协议控制。

ROM 用显式 Intel altsyncram 与可追踪 `replay.mif`。首次完整编译，随后 `quartus_cdb --update_mif`
与 `quartus_asm` 更新波形。四份 ROM SOF 必须 SHA256 各不相同，防止未实际更新 ROM 而误测同一信号。
每种配置检查实际器件、拟合成功、42 项多工况时序。PCB 偏斜仍未实测，状态 LED 仍未约束。

仿真使用真实 Intel PLL/ROM/FIFO、带 13.5 ns FLAG 和 15 ns DQ 延迟的 FX2 模型；
核对连续 ROM 样本、4096 点 RAW 快照、所有 USB I/Q 与实际 DUT 输出逐点一致、命令应答和小幅度 FM 识别。
TRI1 自动/手动的新仿真覆盖最终 FM/80 码 ROM，另外三个波形的实际验证依赖实板矩阵。
风格技能的严格门禁不等于 Quartus/ModelSim 检查，原项目风格与该门禁冲突仍单独报告。
本轮已执行严格门禁，结果未通过，见 `.harness/tri_board_test/style.json`；
包含既有空格缩进、双语固定头、端口命名规则冲突及单文件调用的厂商/项目 IP 闭包缺失，不能称为门禁就绪。

离线任务已注册 `tri-board-build-*`、`tri-board-check-*`、`tri-board-offline-ready`。
这些脚本本身不访问 USB、不下载 FPGA。

## 可视化实板测试

`ready.json` 就绪后，下列入口会自动下载配置并开始真实 USB 接收：

```powershell
& 'D:/conda_envs/ads807_host/python.exe' -B -m host.ads807.build_usb_pump
& 'D:/conda_envs/ads807_host/python.exe' -B -m host.ads807.board_test --offscreen --seconds 30 --managed-pump
```

默认生成本地页面 `http://127.0.0.1:8767`；端口占用时自动顺延，实际地址见 `preview.json`。
去掉 `--offscreen` 可同时显示独立桌面窗口。页面镜像真实 Qt 窗口；USB 由上位机采集线程独占，
TRI1 命令发送使用独立 OUT 线程，与 IN 接收并行；设备列表仍由采集线程创建，发送线程退出后才关闭。
RPL1 上传与启停仍由同一采集线程完成。镜像与绘图负载包含在本轮实测环境内。
实验 `--managed-pump` 使用官方 Cypress Begin/Wait/FinishDataXfer 异步生命周期，
维持 128 个 512 字节 IN 请求；本地编译组件按源码和 SDK 的 SHA256 校验。
RPL1 在同步上传 RAM 后、START 前启用异步 IN，完整保留 START 应答批次中的 I/Q，
临时 I/Q 缓存上限 64 KiB；超过上限或交换期间 CRC/解析异常会失败。
native 队列和 Python 队列均有容量限制，任一丢弃或线程错误立即失败。
`max_requeue_ms` 是单个请求槽重新入队耗时，其他请求仍可挂起，不能解释为 USB 完全无请求的时间。

测试顺序为三种模式各 AM/800、FM/800、AM/80、FM/80，共 12 组。
每组在识别稳定后连续检查 30 秒；每秒检查分类、载频及调制参数，逐帧检查 CRC 和连续性。
CRC、帧头、丢样、削顶、队列丢弃、全局序号异常或 USB 错误立即判 FAIL 并停止矩阵。
有效 I/Q 超时 1 秒、20 秒不能完成识别、平均处理速率低于 490 kS/s 也判 FAIL。
这些是原型自检阈值，不是课程正式验收指标。

每次下载后，在 MODE/START 前进行至多 64 KiB 的有界启动 FIFO 排空，保存为 `*_startup.bin`。
此时 ROM 配置尚未调谐、RAM 配置尚未启动；排空字节仅作为启动残留，不计入连续接收窗口。
连续接收期间绝不忽略解析错误或间断。若启动 FIFO 不能变空，直接失败。
检测不到数据 USB 时立即停下，等待用户重新上电，不自动重试、不刷固件或替换驱动。
烧录前后检查在独立子进程执行，GUI 内 Cypress 设备列表仅由采集线程创建和持有，
避免预检查线程与 GUI 接收线程分别创建/释放设备列表；此前枚举失败的硬件/驱动根因仍待查。

输出位于 `.harness/tri_board_test/`：`ready.json`、`result.json`、各组截图、下载日志、启动残留，
以及离线构建/仿真证据。内存缓冲有界，不保存无限增长的全量原始流。
完成后保持页面和最后画面，采集停止；30 秒通过不能称为小时级长期稳定性已验证。

## 2026-10-20 当前结果

- 修复打包器后，自动/手动 EP4CE6 重新编译及已约束时序通过，最小时序裕量分别 0.157 / 0.102 ns。
- 两种 TRI1 引脚级仿真通过：各 6 条 ACK、55 帧、3186 对有效 I/Q、4096 点 RAW，
  可用 IQ 帧 28/29 达到 111 对满帧；小幅度 FM 参数和逐点载荷比较通过。
- 上位机 74 项测试通过，包含 RPL1 上传/停止、TRI1 控制写入期间持续读取和 USB 耗时指标；回放软件此前 15 项通过。
- 首次实板启动在有效 I/Q 前遇到 2048 字节解析残留，已判 FAIL；证据 `attempt_initial.json`。
- 加入启动排空后，一次 GUI 启动报告匹配 0 个 04B4:1004，已停止并等待用户重新上电。
- 用户再次重新上电后，检测到高速 FX2 数据 USB，下载并启动自动搜索 AM/800 码实板测试。
  同步发送命令的运行在停止判定时发现 8 次间断、3635 个 FPGA 丢样，证据 `attempt_sync_control.json`。
- 将 TRI1 命令发送移至独立线程后，复测同组仍失败：2.36 秒时发现 4 次间断、1329 个 FPGA 丢样；
  当时 CRC、帧头、解析残留、上位机队列丢弃均为 0，识别仍在稳定性确认中。
  历史证据保留在 `attempts/`。这些是停止触发时计数，停止收尾期间计数可能继续增长。
  本次未发生 USB 未枚举报错；丢样根因尚未确认，不能将线程拆分宣称为已解决实板问题。
- 后续修复打包器并启用异步请求后，自动搜索 AM/800 已完成一次 30.093 秒连续测试：
  499639.5 IQ/s，30 次参数检查，AM 调制度 0.500079，所有传输完整性计数为 0。
  该轮启用了 cProfile，证据在对应 `attempts/`；关闭 profiler 的完整矩阵仍在继续。
  此前同配置曾出现 Python 队列丢弃 294912 字节，不能仅凭一次通过宣称长期稳定性解决。

## 打包效率与接收调度排查

`receiver_ads807_tri/rtl/rx_tri_packet.v` 原 `gap` 在 showahead FIFO 为空时仍比较无效 `q`，
会提前结束 IQ 帧，实板常见 34/35 对 I/Q，增大帧开销及主机解析负载。
已增加 `!fifo_empty` 限定；旧代码回归为 0/67 个可用帧达到满帧，修复后为 28/29。
实板短抓包确认 272 帧为 111 对，另有 1 帧 78 对和 1 帧 ACK。
八份 ROM SOF 已按新源码重建，ready 验证包括构建/仿真指纹和满帧比例。
原三模式仿真也通过全部 3 模式、13 命令、CRC、逐点载荷、保持与溢出恢复检查。
该 RTL 修复的严格风格检查仍未通过，见 `packet_before_style.*` / `packet_after_style.*`。

修复打包后，Python 同步 IN 实测仍有约 19 ms 提交间隔并丢样；实验异步接收用于持续挂起 IN 请求。
一次异步接收失败触发时 native 队列、FPGA 丢样、CRC 和序号均为 0，但 Python 队列已满，
故停止并保留失败，不通过扩大队列或忽略计数改变判定。
随后 profiler 单组跑满 30 秒，处理线程约 16 秒用于测量/解调/频谱，约 8 秒等待入口数据；
本轮未复现该积压，尚不能确认上一次积压的具体诱因。

后续完整矩阵曾达到 11/12 组通过，最后手动 FM/80 因 Python 队列丢弃 65536 字节失败，
触发时 FPGA 丢样、CRC、序号异常均为 0。证据 `matrix_before_batch.json` 及 `attempts/`。
0.5 ms 解释器切换、I/Q 批量转换、USB 独立进程和数值库单线程对照均未单独消除间歇积压；
未将这些试验宣称为根因修复，独立进程实现已移除，保留运行证据。

稳定识别后将参数测量/FFT 从逐个约 20 ms 块改为最多 10 Hz；音频继续逐块处理全部 I/Q。
首次识别或候选变化仍逐块三次确认，削顶立即评估，数据段复位后立即重新测量。
I/Q 只在 DSP 批次和质量监测时转换，减少小帧重复数组运算。
手动 FM/80 已以此配置完成 60.172 秒，499813.2 IQ/s，全部完整性计数为 0 且 STOP 正常；
证据 `manual_fm_80_60s.json`。新的 12 组各 60 秒矩阵自动 AM/800、FM/800 通过，
准备 AM/80 时烧录前预检查匹配 0 个 FX2 设备，立即停止，等待用户重新上电。
当前 `result.json` 保存本次停测及前两组通过记录，不自动重新枚举或烧录；不能将矩阵记为通过。
新增等价性、测量限频不跳音频、削顶即时响应及 RPL1 临时缓存上限检查。
最终上位机回归 78 项通过（17.11 秒）；实验独立 USB 进程实现及其测试已移除。

## FIFO 容量专项排查

2026-10-20 核对本次自动搜索配置的实际生成 RTL 与 Fitter 报告：FIFO 为 256×288 位，
500 kS/s 对应从空到满的样本时间为 0.512 ms。每项含 I/Q 32 位和元数据 256 位；
上层仅在 `iq_valid && dsp_run && fifo_full` 时累计 dropped，因此实板计数反映 FPGA FIFO 写端已遇到满。
这说明溢出发生的位置，尚不能说明是主机调度、USB 服务停顿还是板内发送效率造成。

新增离线检查：

```powershell
& 'D:/conda_envs/ads807_host/python.exe' -B main_project/fpga/receiver_ads807/scripts/fifo_budget_check.py
```

对应 harness 任务 `tri-fifo-budget`，使用实际回放 FIFO 包装与 Intel `dcfifo` 模型；
512 点仅在独立仿真副本中改变深度和指针位宽，不改源工程、SOF 或 `ready.json`，不访问 USB。
写时钟 43.5 MHz，每 87 周期写一个样本；读时钟 24 MHz，从空开始暂停读取后恢复。

| 暂停读取 | 256 点暂停阶段丢样 | 512 点暂停阶段丢样 |
| --- | ---: | ---: |
| 0.25 ms | 0 | 0 |
| 0.50 ms | 0 | 0 |
| 0.75 ms | 119 | 0 |
| 1.00 ms | 244 | 0 |
| 2.00 ms | 744 | 488 |
| 5.00 ms | 2244 | 1988 |

12 个容量/恢复场景全部符合预期，恢复后成功入队数据逐字、顺序、序号间断和累计丢样核对一致。
这些是注入已知故障的仿真检查通过，不是零丢样实板测试通过。
测试不包含打包器与 FX2 的额外缓存，不能把表中时间直接当作实际主机 USB 停顿时间。
证据见 `.harness/tri_board_test/fifo_budget/result.json` 及两种深度的 `simulation.log`。
测试台严格门禁仍有 34 条注释放置错误，见同目录 `style.json`；不宣称风格门禁通过。

Fitter 的有效存储位为 193578/276480（70%），但物理 M9K 已用 25/30（83%）。
当前 FIFO 占 8 个 M9K；512×288 需要 16 个，其他配置不变时估计总需 33 个，超过器件容量。
33 个是按现有映射作出的预算，未执行 512 点配置综合/布局布线。
因此不能直接把当前回放配置改成 512 点后烧录，也不能据有效位数尚有余量判断放得下。
接入真实 ADC 后回放 ROM 可释放资源，但 ADC 版本的拟合、时序和持续接收仍需单独验证。

目前确认小 FIFO 对毫秒级停顿余量不足，实际停顿来源仍待测量；尚未实施缓存扩容修复。
