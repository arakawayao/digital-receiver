# 交付证据索引

`ASSETS.json` 记录迁移来源、host内目标位置与SHA256，原结果保持字节一致。

- `dual_new_tests.xml` / `dual_verification.json`：迁移前两模式软件及合成GUI结果。
- `rtl_host_crosscheck.json`：已有RTL字节经生产解析器校验的结果。
- `board_control_20261020_162353.json`：ADC未接入的USB控制通过记录。
- `usb_samples_20261020_182443.json`：RAM回放整轮FAIL记录，保留STOP ACK超时。

详细历史上位机日志/截图/捕获已迁至 `../.harness/ads807_host/`，新迁移验证在
`../.harness/migration_tests.xml`、`../.harness/isolated_tests.xml` 和
`../.harness/migration_verification/`。
历史JSON内可能带原机器绝对路径，仅用于追溯；不作为当前程序运行配置。
