# 外部固件交付目录

本目录接收FPGA同学提供的固件及清单；Python应用与离线测试不需要SOF。
本次目录整理没有重新构建、烧录或将测试配置替换成生产配置。
系统驱动、CyUSB SDK和Quartus属于外部工具，不打包进Python源码。

供现有诊断脚本使用的布局（相对host根目录）：

```text
firmware/
  receiver_ads807_dual/
    receiver_ads807_dual.sof       # 生产工程，dual_control_test使用
    manifest.json                 # FPGA负责人提供：源版本/工具/哈希/用途
    usb_samples/
      receiver_usb_samples.sof    # 手动RAM回放测试配置
      receiver_usb_samples_auto.sof
      build/summary.json          # 对应测试配置的真实构建摘要，status须为PASS
      build_auto/summary.json
```

清单应包含SOF SHA256、生产/测试用途、FPGA型号、源版本、工具版本、采样率、协议版本和
构建验证限制。生产和RAM测试固件不能混用；样本测试配置可能只有256点FIFO。
诊断脚本的Quartus programmer路径/USB-Blaster名称仍需按本机配置核对。
`dual_control_test` 会记录SOF哈希和本目录随附的RTL/工程约束哈希（如果提供），
这些随附源文件不能代替FPGA负责人维护的完整可重建工程。

当前已有SOF和构建摘要会作为历史联调输入复制到此目录，旁附迁移清单；其存在不表示
允许接手人省略版本核对或声称完成真实ADC验收。
