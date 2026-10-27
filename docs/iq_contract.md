# 离线 IQ 交换契约 v1

本契约用于算法、FPGA 参考模型和上位机之间交换离线测试数据。它不是 FPGA 传输线上的帧协议，不规定 ADC、物理链路或定点位宽，也不代表解调应用已经实现。后续硬件协议仍须单独确定字节序、序号、丢包、时钟与溢出策略。

## JSON 格式

文件使用 UTF-8，每个文件包含一个对象；重复键和未知顶层字段均拒绝。必需字段如下：

| 字段 | 约束与含义 |
| --- | --- |
| `schema_version` | 整数 `1`，不接受布尔值或 `1.0` |
| `sample_rate_hz` | 正的有限实数，表示复数基带样本率，不是 ADC 采样率 |
| `center_frequency_hz` | 有限实数，范围 `[88000000, 108000000]`，表示接收调谐中心频率 |
| `iq_format` | 固定字符串 `normalized_float` |
| `samples` | 非空数组，每项严格为 `[I, Q]` 两元素数组，按时间顺序排列 |
| `metadata` | 可选对象，包含说明或已知真值；不参与接收算法判别 |

I/Q 分量各自为 `[-1, 1]` 内的有限 JSON 数值，不接受字符串、布尔值、NaN 或 Infinity。幅度是无量纲归一化数值，不代表电压、功率或 ADC 满量程；模长可以达到 `sqrt(2)`。所有 metadata 数值也必须有限，键必须为字符串。

复数约定为 `z[n] = I[n] + j Q[n]`。时间原点为第一个样本，`t[n] = n / sample_rate_hz`，相位随时间正向增加表示正基带频率。中心频率是调谐元数据，不是由当前样本测出的信号中心频率。文件只描述连续样本，不可将丢包后的样本拼接成连续数据而不另行定义有效性信息。

## API 与生成命令

`reference.iq` 提供 `validate_capture(capture)`、`read_capture(path)`、`write_capture(path, capture)`。验证成功返回 `None`，读取返回已验证字典。无效数据抛出 `ValueError`；文件访问异常保持原始类型。写入前先验证，成功写入会覆盖同名文件；调用者负责建立父目录。

从项目根目录运行：

```powershell
python -B -m reference.fixtures --output-dir .harness/fixtures
python -B -m unittest discover -s tests -p test_iq_contract.py
python -B -m unittest discover -s tests -p test_signal_fixtures.py
```

生成 `am.json`、`fm.json`、`silence.json`。无需第三方依赖，不写入当前时间或随机数据。同一运行环境中重复生成结果相同；不同数学运行库最后几位浮点值可能有差异，不应将跨平台逐字节一致作为验收要求。`make_capture(kind)` 接受 `am`、`fm`、`silence`，其他值抛出 `ValueError`。

## 合成样本真值

三种样本均为 48000 complex samples/s、4800 点、调谐中心频率 100 MHz，基带载波偏移为 0。配置记录在 `metadata.truth`，仅作为测试预期，识别算法不得读取标签作为判断结果。

- AM：`I[n] = 0.5 * (1 + 0.6 * cos(2*pi*1000*n/48000))`，`Q[n] = 0`，包络范围 0.2 至 0.8。
- FM：`z[n] = 0.5 * exp(j*phase[n])`，初相为 0，`phase[n+1] - phase[n] = 2*pi*2000/48000 * cos(2*pi*1000*n/48000)`。离散瞬时频率按相邻样本差定义，对应区间 `[n,n+1]`。
- silence：全部 I/Q 为 0，用于后续“无有效信号”路径验证。

1 kHz 单音、2 kHz FM 频偏及 48 kHz 基带采样率仅为小规模测试参数，不是广播宽带 FM 的验收配置，也不确定音频输出采样率。当前样本不包含噪声、频偏、丢包、定点量化或硬件采集误差；这些覆盖以及真实接收、识别、解调、放音仍待实现。
