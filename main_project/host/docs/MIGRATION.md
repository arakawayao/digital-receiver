# 上位机独立目录迁移记录

日期2026-10-20。目标：只交付host目录即可开发、测试和运行上位机。

## 迁移范围

- 当前TCM1/TRI1协议与IQ质量实现迁入 `ads807/interfaces/`。
- 原FPGA工程内receiver/receiver_v2/receiver_ads807的Python上位机工具迁入 `ads807/legacy/`。
- 原 `tests/host/ads807/` 测试迁入 `tests/ads807/`，回放与持续监控测试迁入 `tests/legacy/`。
- 原FPGA路径只保留兼容转发和测试发现入口，实际实现唯一维护于host。
- 独立入口为 `run.py` 或 `python -B -m ads807`；运行、测试及可选C#构建默认产物均在host内。
- 原 `.harness/ads807_host/` 约1.35GB产物已完整移入 `host/.harness/ads807_host/`，未删除证据。
- 必要协议/联调资料和关键结果摘要放入docs/evidence；现有SOF及真实构建摘要复制到firmware，
  来源及哈希见 `evidence/ASSETS.json`，此次未重新构建或烧录。
- 外层harness只调整相关测试/产物路径；根README和工作计划补充迁移入口，FPGA RTL未改。

## 验证

| 检查 | 实际结果 |
| --- | --- |
| host目录完整回归 | 104 passed；`.harness/migration_tests.xml` |
| 独立交付副本 | 临时目录只含host副本、无外层FPGA源码，104 passed；`.harness/isolated_tests.xml` |
| 实际Qt离线路径 | AM/FM/静默/噪声四场景PASS；`.harness/migration_verification/result.json`，同目录截图/捕获 |
| 任意工作目录启动 | 独立副本run.py，离屏FM运行4秒并正常退出；`.harness/isolated_fm.png`、`isolated_health.json` |
| Python模块导入 | 当前工程35个模块全部导入成功；未打开设备 |
| 原FPGA测试入口兼容 | 15项历史unittest通过，继续由host实现执行 |
| 外层harness兼容 | `ads807-dual-control-tests`通过；相关任务声明已更新到host |
| 文档链接/外部导入 | 当前文档链接有效，ads807及tests无main_project/外层host导入 |

PowerShell启动器在本机被系统脚本执行策略拒绝，未修改策略；已验证的任意目录入口为
`python -B <host目录>/run.py`。这不影响直接模块启动、离线测试或Python入口运行。

初次验证发现新输出目录的父目录未建立、两处测试读取QSS依赖旧工作目录，均已修复后复测。
这次无USB连接、SOF下载、物理音频或射频测试，结果不能替代硬件验收。
完整系统验收及已有STOP ACK问题见 [HANDOFF.md](../HANDOFF.md)。
