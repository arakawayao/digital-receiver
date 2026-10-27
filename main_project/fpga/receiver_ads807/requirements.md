# 实现契约和计划

用户批准的采样率为 43500000 Hz；ADC 引脚暂留虚拟。保持源 receiver 的
ADC → 自动测频/DDC → CIC/FIR → 异步 FIFO → FCR1 → FX2 接收职责。
不移入其他顶层、回放链路、上位机、旧缓存、旧 SOF 或旧验证通过结论。

1. 先建立独立整数参考：R87、59 位回绕、SHIFT40、63 拍 FIR、正 alias 混频。
2. 迁入必要的 capture/NCO/CIC/FIR/reset/packet/FX2 和生成式 FIFO/DDIO IP。
3. 固定 PLL 和测频换算为 43.5 MHz；同拍提交 phase/RF/locked/update。
4. ADC 输入先寄存再分支给测频和 DSP，避免未寄存输入直接穿过测频组合链。
5. 手写 Verilog 一行一信号声明、一条赋值，wire 声明不含初始化。
6. 创建独立 QPF/QSF/SDC，记录目标器件假设和虚拟 ADC 的约束缺口。
7. 用本地现有 ModelSim/Quartus 验证该工程，记录静态、仿真、实现时序各自证据。

原接收器的 frequency.acquire_state 启动赋值被注释，迁入时恢复；
原顶层 ADC_RATE 默认值与 PLL 不一致，独立工程改为一致的固定参数。
FIR 启动历史由 filled 计数屏蔽，RAM 不逐单元复位。
锁定总线通过先同步 locked、再读稳定数据的原机制跨域，流复位延迟 32 拍。
数据通路无上游反压；USB 反压止于有限 FIFO，溢出必须反映在帧头和 index。
