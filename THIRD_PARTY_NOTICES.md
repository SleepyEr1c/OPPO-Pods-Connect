# Third-party notices / 第三方声明

本文说明独立 macOS 仓库 OPPOPods 使用、修改或参考的外部来源。它帮助贡献者和二进制分发者保留必要归属，不替代各项目自己的许可证正文。

## 项目沿革

| 项目 | 与本仓库的关系 | 许可证 |
|---|---|---|
| [Leaf-lsgtky/OppoPods](https://github.com/Leaf-lsgtky/OppoPods) | 本 macOS 客户端最初在该 Android / Xposed 仓库中开发，随后拆分为独立仓库；协议结论、型号数据和早期 Swift 实现从该工作树迁移 | GPL-3.0（依其项目声明及衍生链） |
| [Art-Chen/HyperPods](https://github.com/Art-Chen/HyperPods) | 原 OPPOPods Android 项目的上游基础，构成项目历史与 GPL 衍生链 | [GPL-3.0](https://github.com/Art-Chen/HyperPods/blob/aap/LICENSE) |

本仓库继续按 GPL-3.0 发布，完整条款见根目录 [`LICENSE`](LICENSE)。拆分仓库不改变已有代码和衍生内容的许可证义务。

## macOS 构建依赖

本仓库没有外部 Swift Package 依赖。构建和运行使用：

- Swift 标准库
- SwiftUI
- AppKit
- Foundation
- IOBluetooth

这些组件由 Apple 的 Xcode / macOS SDK 提供，并不作为第三方源码随仓库再分发。使用 Xcode 和 Apple SDK 时还应遵守 Apple 对应的许可条款。

## 协议与互操作性研究来源

以下来源用于理解设备通信或交叉验证协议事实，并不表示其代码作为依赖链接进 App：

| 来源 | 使用方式 | 性质 |
|---|---|---|
| OPPO / HeyTap **HeyMelody** 官方客户端 | 观察蓝牙通信，分析 SPP UUID、命令编号、product ID、型号能力字段和通知流程 | 官方闭源软件；不是开源依赖，本仓库不分发 APK |
| 原 OPPOPods 仓库的协议文档与实现 | RFCOMM 外层帧、握手、电量、ANC、状态、空间音效、EQ 与 feature 命令的直接迁移来源 | GPL-3.0 项目内容 |
| 本项目贡献者的蓝牙日志和实机测试 | 验证型号差异、命令响应与连接时序 | 只保留脱敏结论；不得提交蓝牙地址或用户私有抓包 |
| [AasheeshLikePanner/cracked-oneplus-buds](https://github.com/AasheeshLikePanner/cracked-oneplus-buds) 及其 [OPOv1 研究说明](https://aasheesh.vercel.app/blog/oneplus-buds) | 相邻的 OnePlus / OPPO / realme 协议研究，用于交叉验证社区结论 | 协议参考；当前 Swift RFCOMM 传输和封包代码来自本项目代码线 |

协议文档位于：

- [`docs/Protocol_Notes.md`](docs/Protocol_Notes.md)
- [`docs/Protocol_Research.md`](docs/Protocol_Research.md)

这些内容用于实现用户自有设备与 macOS 的互操作性，不是 OPPO / HeyTap 官方协议规范。

## 型号元数据与 EQ 名称

以下资源从原 OPPOPods 工作树拆分：

- `Resources/device_models.json`
- `Resources/eq_mode_names.json`
- `Resources/eq_mode_names.en.json`

这些数据基于 HeyMelody 兼容性元数据整理，用于 product ID 识别、ANC protocol index、功能显隐和 EQ 名称。它们不表示 OPPO / HeyTap 对本项目的授权、认可或技术支持。

型号表中的“SPP 候选”仅代表元数据未关闭相应控制路径，不等于所有设备、固件和功能已经实机验证。

## 应用图标与界面资源

- `AppBundle/Assets/AppIcon.png` 和 `AppIcon.icns` 是为本项目制作并后期处理的资源。
- 图标不包含 OPPO、Apple 或其他厂商 Logo；通用耳机造型仅用于表达软件用途。
- SwiftUI 界面使用 Apple SF Symbols 系统符号，不将其作为独立素材重新分发。

## 不包含的内容

本仓库不应包含：

- HeyMelody 或其他官方 APK
- 耳机固件和厂商私有二进制
- Apple / OPPO / HeyTap 签名材料
- 用户账号信息、蓝牙 MAC 地址或未脱敏抓包
- 从官方客户端提取的受版权保护图片、音频或品牌资源

## 分发者须知

分发 `OPPOPods.app`、DMG、修改版或源码时：

1. 保留根目录 GPL-3.0 `LICENSE` 与本声明。
2. 提供与所分发二进制对应的完整源码和构建说明。
3. 保留原 OPPOPods、HyperPods 以及其他实际使用来源的版权与许可证说明。
4. 不得暗示项目获得 OPPO、OnePlus、realme、HeyTap 或 Apple 官方认可。
5. 使用 Developer ID 签名或 Apple 公证时，由分发者自行承担证书与平台条款责任。

如发现遗漏或归属错误，请提交 Issue，并附项目链接、涉及文件和许可证依据。
