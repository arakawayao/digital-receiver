# USB接收修正记录

## 2026-10-26 启动 EP6 写入超时

实机只发送 QUERY，复现 EP6 OUT 返回 0/512 字节，约 518 ms，
LastError=997、NtStatus=0x3e3、UsbdStatus=0xc0010000。
设备当时可枚举为 04B4:1004，高速 USB、alt 0，EP2/EP6 均为 512 字节 Bulk。
用户确认下载后未断开重连 USB；尚不能仅凭错误码断定 FX2 FIFO 或驱动的唯一根因。
下一次尝试恢复前设备已不再枚举，因此未完成实机恢复验证。

本轮上位机修改：

- TRI1 启动时在采集线程对 EP6/EP2 执行 Abort/Reset，然后才启动 IN 接收和 OUT 命令线程。
  这是驱动端点恢复，不等同于重新初始化 FX2 AUTOOUT/FIFO；不能保证修复所有板端状态。
- 写入失败记录长度、LastError、NtStatus、UsbdStatus 和耗时，不重发状态未知的命令。
- 异步接收组件 Dispose 报错时仍释放设备列表，保留原始失败信息。
- 不修改 FPGA、FX2 固件、协议或估频门限；新增离线测试覆盖恢复顺序、失败清理和短写诊断。

复测需完全退出旧上位机，再运行 `start_host.bat`。若仍失败，保留新日志，关闭上位机，
重新连接 FX2 数据 USB 后复测；若此操作导致板卡断电，需要重新下载 SOF。
本次不自动执行板卡复位、固件烧录或 A9 厂商命令。

日期：2026-10-23。对象：`main_project/host`，配套 `receiver_ads807_dual`。
本次未修改RTL、FX2固件、采样率、I/Q格式或512字节上行帧。

## 1. 手动配置与固件版本

> 历史记录说明：本节原记录的 2026-10-22 SOF 是 USB 稳定性基线。
> 2026-10-26 自动 AM 重锁修复产生了新的候选 SOF，当前清单以
> `firmware/receiver_ads807_dual/manifest.json` 和
> [AM_RESTART_DIAGNOSIS.md](AM_RESTART_DIAGNOSIS.md) 为准；新 SOF 尚未上板复测。

发现交付清单及主SOF仍为TCM1 v1，而当前软件/FPGA源码均为v2；
尚未读取用户板上固件，不能据此断言实机故障唯一原因。
交付主SOF同步为2026-10-22 13:28:52构建，SHA256：
`44380c70bf809f80151053ba14a3d0009983add355be3a731bfaa342e55a54e6`。
既有构建记录的map/fit/已约束路径多工况STA通过，不代替ADC板级时序或上板验证。
旧主SOF和修改前代码位于 `../.harness/usb_fix/before/`；历史RAM测试SOF保留v1标记。

`ads807/tuning.py` 现在明确提示v2拒绝，并检查MODE模式、TUNE载频/NCO步进/使能、
HOLD保持时间和STOP取消调谐。回读不一致时报错；不盲目重复发送配置。

## 2. ACK与DSP分开

`ads807/runtime.py` 新增接收路由线程，唯一解包器统一跟踪CRC及跨IQ/ACK的全局序号。
ACK立即交给调谐线程，识别、FFT、解调和音频另从有界队列读取。
最多256批处理缓存；常规32KiB一批约14.2ms样本，256批约2.3s。
队列满时丢弃新批次，累计丢字节/丢样，在下一成功入队的IQ标记间断。
主机丢弃计数包含原始队列和处理队列；保存统计提供独立DSP队列深度、容量和丢样数。
真实间断仍清理连续段，禁止把断开的音频静默拼接。

停止请求立即通知调谐线程；接收路由与USB保持运行到STOP确认或明确超时。
DSP异常的清理路径也遵循该顺序，避免停止解包后等待无法分发的ACK。

## 3. 普通GUI启用异步接收

`ads807/gui.py` 的USB入口设置 `usb_managed_pump=True`，复用既有官方CyUSB
Begin/Wait/FinishDataXfer接收组件：128个512字节IN请求、有界32KiB批处理，OUT独立发送。
没有新增Python依赖；组件缺失/哈希不一致会报错，不自动回退同步读。
源码交付到其他机器后，从host目录重新构建：

```powershell
python -B -m ads807.build_usb_pump
```

本机已编译生成 `.harness/ads807_host/managed/UsbReceivePump_7d83615ef6f02182.dll`，
旁边JSON记录源码、SDK及DLL哈希。普通GUI不烧录，也不自动连接设备。

## 验证与待实测

- 命令/回读专项：29项通过。
- 接收路由、合成流水线及回放专项：34项通过，覆盖DSP阻塞、异常、队列满和STOP ACK。
- 完整上位机回归：127项通过，结果 `../.harness/usb_fix/tests.xml`。
- 异步组件编译成功；软件测试验证GUI选择异步接收，初始化失败不回退。

以上均为离线证据。真实USB持续收数、板上v2手动调谐、实际ADC及物理放音尚未复测。
原有512点FPGA FIFO仅1.024ms，真实USB长停顿仍可能造成FPGA丢样；本次不宣称已消除硬件丢样。
复测时需同时记录ACK回读、CRC/序号/样本缺口、FPGA丢样、主机丢弃和音频欠载。
