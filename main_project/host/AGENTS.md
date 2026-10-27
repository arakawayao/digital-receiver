# 上位机工作规范

本目录是可独立交付的 Python 上位机工程，默认使用中文说明。

- 从本目录执行 `python -B -m ads807`，或从任意目录执行本目录的 `run.py`。
- 应用只依赖本目录内 Python 模块；不要重新导入外层 `main_project`、`reference` 或项目 harness。
- `ads807/interfaces/` 是共享协议实现，`docs/PROTOCOL.md` 是接口说明；改协议先与 FPGA 同学协调。
- 保留采集、处理、音频及界面职责分离，跨线程 UI 更新走 Qt signals/slots，GUI 线程不等 USB ACK。
- 接收/音频队列有界，丢样、CRC、断连、未知/无有效信号均应可观察，不能静默合成替代数据。
- 应用、测试、依赖、文档和默认产物都放在本目录内。默认保存为 `captures/`，生成产物为 `.harness/`。
- 离线验证：`python -B -m pytest tests -q -p no:cacheprovider --basetemp .harness/pytest`；
  `python -B -m ads807.verify`。先合成验证，再做真实 USB/射频/音频验证，分别报告结论。
- `legacy/` 位于 `ads807/` 内，仅兼容旧固件；不要把历史采样率或测试 SOF 当作生产配置。
- 普通启动不刷固件；诊断烧录脚本应先核对 `firmware/` 清单、SOF哈希、工具路径和实际硬件。
- 此目录不包含 Conda、系统驱动、CyUSB SDK 或 Quartus 安装，按 README 配置。
