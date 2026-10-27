# FPGA 开发入口

2026-10-20当前ADS807E入口为 [receiver_ads807_dual](receiver_ads807_dual/README.md)，
由 `receiver_ads807` 原工程派生，EP4CE6F17C8，43.5MS/s，两模式：FPGA自动估频/上位机手动载频。
Quartus入口 `receiver_ads807_dual/receiver_ads807_dual.qpf`；ADC12位、OTR及CLK已按用户
指定的P3接线顺序全部配置物理引脚，无ADC虚拟端口。
下述56MHz方案为历史工程说明。

新的 FCore2S 数字接收机工程位于 **[receiver/README.md](receiver/README.md)**。
2026-10-04 按用户要求从头编写并按最新更正改为固定56MHz，使用 Quartus 18.1 / ModelSim 2020.4，
不依赖旧 srcs、ip、project1 或旧 RTL 测试。顶层 receiver_top；采集、NCO、
CIC/FIR、FIFO、USB 配置及带 CRC 的 IQ 传输已实现并有真实验证入口。

ADC由FPGA PLL提供56MHz时钟，FPGA自主识别频率并设置DDC；上位机接收I/Q后
完成AM/FM识别、解调和放音，不下发RF/NCO配置。工程入口：`receiver/receiver56.qpf`。
验证记录见 [VALIDATION.md](receiver/VALIDATION.md)。板载链路明确为 FX2 USB 2.0，
外接 ADC 引脚尚为虚拟端口，完整板级时序、上板与整机验收未完成。

完整 FPGA 链路仿真入口为 `receiver/scripts/full_chain.py`：合成 AM/FM ADC 输入、
实际 PLL/自主测频/DSP/FIFO、FX2 总线输出、频跳重捕获、溢出和暂停恢复，附独立载荷/CRC核对。
`receiver/scripts/view_full_chain.ps1` 输出 ModelSim 的分组波形查看命令。

旧32/40MHz与EP6调频入口已移至`receiver/legacy_32_40/`，仅作历史资料。

本轮期间旧 FPGA 文件从共享目录移走/删除，本对话未执行该操作。
公共文档、IQ 契约、harness 清单和硬件 EDA 未在本对话中修改。
