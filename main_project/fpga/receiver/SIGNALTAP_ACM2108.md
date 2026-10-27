# Signal Tap：ACM2108 ADC 与锁频观测

本说明对应 `receiver56.qpf`。按用户确认，ACM2108 接到 FPGA 的 ADC 数据总线为 8 位，另有两位未接；FPGA 提供 32 MHz Encode/采样时钟。当前 RTL 按 8 位直二进制码解释并减去 128，这属于工程假设，建议用静态输入核对码值和位序。

## 工程内配置

工程已加入 `receiver56.stp`，由 `receiver56.qsf` 启用。Signal Tap 使用 PLL 的 32 MHz 输出 `rx_pll32:pll_32m.pll|wire_pll1_clk[0]` 采样，深度 32 点（约 1 µs），并包含以下探针：

- `adc_data[7:0]`：ACM2108 的 8 位 FPGA 数据总线。
- `rx_frequency:detector|measured_bins[14:11]`：过零计数高 4 位；每步代表 2048 个窗口 bin，约 1 MHz，用于快速判断混叠频率区间。
- `rx_frequency:detector|valid_window`：本次 65536 点窗口是否满足频率、幅度、削顶和周期稳定性条件。
- `rx_frequency:detector|update`：估计结果提交脉冲，也是当前默认触发信号（上升沿）。
- `rx_frequency:detector|locked`：自动选频锁定状态。
- `rx_frequency:detector|rf_hz[31:0]`：估计 RF 频率，单位 Hz；Signal Tap 中可将其显示格式设为 unsigned decimal。

`update` 只会在连续有效窗口完成锁定并提交结果时产生。如果目前尚未锁频，默认触发会一直等待。此时可在 Signal Tap 中把触发条件改成 Don't Care/立即触发来先看 ADC 数据和 `measured_bins`；如要观察锁定瞬间，再恢复 `update` 上升沿。修改触发条件后若 Quartus 要求重新编译，应重新下载对应 SOF。

32 点窗口用来观察 ADC 的短时采样形态和估计器状态，不覆盖完整估计窗口。过零频率统计每 65536 个采样更新一次，32 MHz 下一个窗口约 2.048 ms；成功锁定需要连续有效窗口。

## 下载与采集

1. 用 Quartus 打开 `D:\receiver\receiver56.qpf`。
2. 在 Programmer 下载新生成的 `D:\receiver\output_56\receiver56.sof`。不要继续使用旧 SOF。
3. 打开 Tools → Signal Tap Logic Analyzer，加载工程中的 `receiver56.stp`，选择 USB-Blaster 与 FPGA 器件并运行采集。
4. 需要先看 ADC 时，将触发设为 Don't Care；确认波形后再观察 `valid_window`、`locked`、`measured_bins` 和 `rf_hz`。要等待锁定提交，则使用 `update` 上升沿触发。

当前完整工程已由 Quartus 18.1 Standard 编译成功，Signal Tap 合并报告显示 81/81 个所需连接均已接通。当前环境没有 ACM2108 实板采集结果；编译通过只验证了工程节点与器件资源，不代表数据位序、极性或锁频已经实测通过。
