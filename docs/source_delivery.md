# GitHub 源码交付说明

整理日期：2026-10-28。仓库：https://github.com/arakawayao/digital-receiver 。

## 保留范围

| 内容 | 位置与用途 |
| --- | --- |
| 当前 FPGA 源工程 | `main_project/fpga/receiver_ads807_dual/`：RTL、ROM/系数、IP 配置及被 QIP 引用的 HDL、QPF/QSF/SDC、引脚脚本、构建和验证脚本、测试台 |
| 当前上位机 | `main_project/host/`：应用、共享协议、界面资源、依赖清单、启动入口、打包脚本、测试和联调说明 |
| 必要旧版依赖 | `main_project/fpga/receiver_ads807/` 的参考模型仍供两模式验证使用；`main_project/host/ads807/legacy/` 部分模块仍供回放和测试使用 |
| 历史 FPGA 基线 | `main_project/fpga/receiver/` 保留已有 56 MHz 源码及其测试入口，作为历史基线；其中的 32/40 MHz 子目录也是历史资料，不是当前硬件配置 |
| 硬件源工程 | `main_project/pcb/` 内两份 `.epro2`，未仅凭日期删除或指定最终硬件基线 |
| 协作与验证 | `AGENTS.md`、任务书、`docs/`、`harness/`、`reference/`、`tests/`、上位机 `evidence/` 内的必要结果及少量诊断音频 |

IP 目录中的生成 HDL 不能当作普通编译缓存全部忽略：当前 QIP 和仿真脚本直接引用它们。
重新生成 IP 应通过现有生成脚本和对应版本工具完成，不直接修改生成 HDL。

## 排除范围

`.gitignore` 排除 `.harness/`、Python 缓存、本机编辑器和助手配置、Quartus 数据库、
ModelSim 编译库及波形、重复编译报告、打包后的 Windows 程序、原始采集目录和本地凭据。
上位机固件目录原有规则继续排除 SOF/POF，保留用途、版本、哈希清单及构建摘要。

本次通过 Git 提交范围排除上述文件，不删除本机原文件。可发布的独立软件、固件和大型采集
数据需单独交付，并标明源版本、SHA256、生产或测试用途与验证边界。

`.harness/` 中的实测原始记录没有随源码上传；已有摘要可能引用本机绝对路径。
相关原始文件仍需在本机或工程外归档保存，离线重新测试不能恢复过去的实测记录。

## 当前运行与验证

上位机使用 Windows x64、Python 3.11 环境；运行依赖见
`main_project/host/requirements.txt`，打包依赖另见 `tools/requirements-build.txt`。
从上位机目录执行：

```powershell
python -m pip install -r requirements.txt
python -B -m ads807 --demo FM
python -B -m pytest tests -q -p no:cacheprovider --basetemp .harness/pytest
```

从仓库根目录可选择不访问硬件的基础任务：

```powershell
python -B -m harness.runner run --jobs 3 --task dialog-tests --task harness-tests --task iq-contract-tests --task signal-fixture-tests --task generate-fixtures
```

当前两模式 FPGA 原工程记录的工具为 Quartus Prime 18.1.0 Build 625 和 ModelSim SE 2020.4。
完整构建、参考模型和仿真步骤见其 README；单独的 Python 测试不能替代这些验证。
本次上传不修改引脚、时钟或信号处理实现，也不烧录板卡。

本次上传前已实际执行上述 5 项基础 harness 任务，全部通过；上位机完整测试为
184 项通过。上述结果只覆盖所列离线检查，未执行全量 harness、FPGA 重新构建、
板卡烧录、真实射频或物理放音测试。新运行日志保存在本机 `.harness/` 中。

## 已知历史缺项与迁移限制

- 当前目录已经没有 `receiver_v2`、`receiver_ads807_tri`；任务清单和部分旧回放脚本仍引用它们。历史三模式、旧回放及其依赖任务不属于可完整重建的当前基线，不能声称全量 harness 已通过。
- 根目录旧 `test_adc_capture.py`、`test_ddc_mixer.py` 引用的早期 `main_project/fpga/srcs/` 已不存在；它们没有注册为当前 harness 任务。
- 旧文档中的根 `host/` 路径应按当前 `main_project/host/` 入口使用；早期板卡资料目录、ADS 工程骨架和根 EDA 实例目前不在交付目录中。
- 当前 QSF、下载链、仿真器工程和部分启动器包含原机器的绝对路径；在其他机器构建或下载前需按工具安装位置和工作目录核对。QSF 中指向 `.harness/` 的 CDF 不随源码交付，下载链应按实际设备重新建立。
- 打包脚本支持从 `main_project/host/.harness/build_tools` 加载工具；该目录不上传，需要时按 `tools/requirements-build.txt` 安装构建依赖。
- 固件清单区分当前 TCM1 v2 与历史 TCM1 v1 回放配置；不能将旧 RAM 测试 SOF 当作当前生产固件。
- 仿真、已约束路径时序、USB 联调、真实 ADC/RF、物理音频及端到端系统验收结论分别记录；上传源码不表示完成任何新增硬件验收。
