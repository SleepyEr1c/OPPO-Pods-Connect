# 设备适配列表

本文记录 OPPO Pods for macOS 内置型号库与客户端适配分级。数据源为 `Resources/device_models.json`，当前共 141 条。

## 如何理解“支持”

- **已验证**：本项目收到过具体型号的实机反馈。
- **协议候选**：型号元数据未关闭 SPP，macOS 客户端可以尝试建立 HeyMelody RFCOMM 控制通道；不代表所有功能均已实测。
- **元数据能力**：表格中的 ANC、空间音效、佩戴检测、双设备、EQ 来自型号 JSON，而不是运行时承诺。固件、地区版本和同名不同 product ID 都可能造成差异。
- **通用探测**：游戏低延迟等功能还会在运行时探测旧 `0x06` / 新 `0x28` feature ID，因此不单独按静态元数据承诺。

> 普通 A2DP/HFP 音频能连接，不等于厂商 RFCOMM 控制通道一定开放。反过来，表格没有声明某项能力，也不一定表示硬件绝对不支持。

## 汇总

| 分类 | 数量 |
|---|---:|
| 型号数据库记录 | 141 |
| `supportSpp != false` | 135 |
| 排除数据库中的 3 个音箱后，耳机协议候选 | 132 |
| OPPO 耳机候选 | 53 |
| OnePlus 耳机候选 | 33 |
| realme / DIZO 耳机候选 | 46 |
| 明确关闭 SPP | 6 |
| 已收到 macOS 实机反馈 | 1 |

静态元数据中，135 个 SPP 设备有 40 个声明 ANC、10 个声明自适应降噪、49 个声明空间音效、49 个声明佩戴检测、51 个声明双设备连接、74 个声明预设或自定义 EQ。该统计包含下文单独列出的 3 个 realme 音箱。

## 已验证设备

| Product ID | 型号 | 已反馈功能 | 验证级别 |
|---|---|---|---|
| `06C010` | OPPO Enco Free4（丹拿版） | 控制通道、电量、降噪、空间音效 | 用户实机反馈；其他功能仍需逐项验证 |

## macOS 协议候选

下面 128 款耳机 / 颈挂耳机在元数据中没有关闭 SPP。`✓` 只表示型号数据声明了该能力；`三档` 表示空间音频数据包含三模式元数据，`开关` 表示单一空间音效开关。

### OPPO（51）

| Product ID | 型号 | ANC | 自适应 | 空间音效 | 佩戴检测 | 双设备 | EQ |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|
| 061810 | OPPO Enco Air | — | — | — | — | — | — |
| 068810 | OPPO Enco Air 3i | — | — | — | — | — | ✓ |
| 062810 | OPPO Enco Air Lite | — | — | — | — | — | — |
| 063410 | OPPO Enco Air2 | — | — | — | — | — | ✓ |
| 063810 | OPPO Enco Air2 Pro | ✓ | ✓ | — | ✓ | — | ✓ |
| 064410 | OPPO Enco Air2i | — | — | — | — | — | ✓ |
| 066C10 | OPPO Enco Air2（新声版） | — | — | 开关 | — | — | ✓ |
| 064C10 | OPPO Enco Air3 | — | — | 开关 | — | ✓ | ✓ |
| 065C10 | OPPO Enco Air3 Pro | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 067010 | OPPO Enco Air3i | — | — | 开关 | — | — | ✓ |
| 067810 | OPPO Enco Air3s | — | — | 开关 | — | ✓ | ✓ |
| 069010 | OPPO Enco Air4 | ✓ | — | 开关 | — | ✓ | ✓ |
| 067C10 | OPPO Enco Air4 Pro | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 069850 | OPPO Enco Air4i | — | — | 开关 | — | ✓ | ✓ |
| 06F010 | OPPO Enco Air4s | ✓ | — | 开关 | — | ✓ | ✓ |
| 06B050 | OPPO Enco Air4（新声版） | — | — | 开关 | — | ✓ | ✓ |
| 06D810 | OPPO Enco Air5 | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 06C410 | OPPO Enco Air5 Pro | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 06C810 | OPPO Enco Air5s | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 06E810 | OPPO Enco Air5s（星光版） | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 062410 | OPPO Enco Buds | — | — | — | — | — | — |
| 064810 | OPPO Enco Buds2 | — | — | — | — | — | ✓ |
| 068010 | OPPO Enco Buds2 Pro | — | — | — | — | — | ✓ |
| 06A450 | OPPO Enco Buds3 | — | — | 开关 | — | ✓ | ✓ |
| 06A850 | OPPO Enco Buds3 Pro | — | — | 开关 | — | ✓ | ✓ |
| 06A010 | OPPO Enco Buds3 Pro+ | ✓ | — | 开关 | — | ✓ | ✓ |
| 06B810 | OPPO Enco Clip | — | — | 开关 | ✓ | ✓ | ✓ |
| 06E010 | OPPO Enco Clip2 | — | — | 开关 | ✓ | ✓ | ✓ |
| 060410 | OPPO Enco Free | — | — | — | — | — | — |
| 062010 | OPPO Enco Free2 | ✓ | ✓ | — | ✓ | ✓ | ✓ |
| 064010 | OPPO Enco Free2i | ✓ | ✓ | — | ✓ | ✓ | ✓ |
| 066010 | OPPO Enco Free3 | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 068C10 | OPPO Enco Free4 | ✓ | ✓ | 开关 | ✓ | ✓ | ✓ |
| 06C010 | OPPO Enco Free4（丹拿版） | ✓ | ✓ | 开关 | ✓ | ✓ | ✓ |
| 050410 | OPPO Enco M31 | — | — | — | — | — | — |
| 050C10 | OPPO Enco M33 | ✓ | — | — | — | — | ✓ |
| 061C10 | OPPO Enco Play | — | — | — | — | — | — |
| 063010 | OPPO Enco R | — | — | — | — | — | ✓ |
| 065010 | OPPO Enco R Pro | ✓ | ✓ | — | ✓ | — | ✓ |
| 065810 | OPPO Enco R2 | — | — | 开关 | — | ✓ | ✓ |
| 068410 | OPPO Enco R3 | — | — | 开关 | — | — | ✓ |
| 069C10 | OPPO Enco R3 Pro | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 06AC50 | OPPO Enco R4 | — | — | 开关 | — | ✓ | ✓ |
| 06B450 | OPPO Enco R5 | — | — | 开关 | — | ✓ | ✓ |
| 060810 | OPPO Enco W31 | — | — | — | — | — | — |
| 060C10 | OPPO Enco W51 | — | — | — | ✓ | — | — |
| 061410 | OPPO Enco X | ✓ | — | — | ✓ | — | ✓ |
| 063C10 | OPPO Enco X2 | ✓ | ✓ | — | ✓ | ✓ | ✓ |
| 067410 | OPPO Enco X3 | ✓ | ✓ | 三档 | ✓ | ✓ | ✓ |
| 066810 | OPPO Enco X3i | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 06BC10 | OPPO Enco X3s | ✓ | ✓ | 开关 | ✓ | ✓ | ✓ |
| 06EC10 | OPPO Enco X4 | ✓ | ✓ | 三档 | ✓ | ✓ | ✓ |

### OnePlus（31）

| Product ID | 型号 | ANC | 自适应 | 空间音效 | 佩戴检测 | 双设备 | EQ |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|
| 060414 | OnePlus Buds | — | — | — | — | — | — |
| 068414 | OnePlus Buds | — | — | — | — | — | — |
| 063C14 | OnePlus Buds 3 | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 066054 | OnePlus Buds 3V | — | — | 开关 | — | ✓ | ✓ |
| 065414 | OnePlus Buds 4 | ✓ | ✓ | 开关 | ✓ | ✓ | ✓ |
| 062814 | OnePlus Buds Ace | ✓ | — | — | — | — | ✓ |
| 064C14 | OnePlus Buds Ace 2 | ✓ | — | 开关 | — | ✓ | ✓ |
| 066414 | OnePlus Buds Ace 3 | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 061814 | OnePlus Buds N | — | — | — | — | — | ✓ |
| 060C14 | OnePlus Buds Pro | ✓ | — | — | ✓ | ✓ | ✓ |
| 062014 | OnePlus Buds Pro 2 | ✓ | — | 三档 | ✓ | ✓ | ✓ |
| 063414 | OnePlus Buds Pro 2R | ✓ | — | — | ✓ | ✓ | ✓ |
| 063014 | OnePlus Buds Pro 2（轻享版） | ✓ | — | — | ✓ | ✓ | ✓ |
| 064014 | OnePlus Buds Pro 3 | ✓ | — | 三档 | ✓ | ✓ | ✓ |
| 064814 | OnePlus Buds V | — | — | — | — | — | ✓ |
| 060814 | OnePlus Buds Z | — | — | — | — | — | — |
| 068814 | OnePlus Buds Z | — | — | — | — | — | — |
| 061014 | OnePlus Buds Z2 | ✓ | — | — | ✓ | — | ✓ |
| 051014 | OnePlus Bullets Wireless Z3 | — | — | 开关 | — | — | ✓ |
| 050C14 | OnePlus BulletsWireless Z2 ANC | ✓ | — | — | — | — | ✓ |
| 067414 | OnePlus Flow Buds | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 061414 | OnePlus Nord Buds | — | — | — | — | — | ✓ |
| 062414 | OnePlus Nord Buds 2 | ✓ | — | — | — | — | ✓ |
| 062C14 | OnePlus Nord Buds 2r | — | — | — | — | — | ✓ |
| 065014 | OnePlus Nord Buds 3 | ✓ | — | 开关 | — | ✓ | ✓ |
| 064414 | OnePlus Nord Buds 3 Pro | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 065854 | OnePlus Nord Buds 3r | — | — | 开关 | — | ✓ | ✓ |
| 067014 | OnePlus Nord Buds 4 | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 066814 | OnePlus Nord Buds 4 Pro | ✓ | — | 开关 | ✓ | ✓ | ✓ |
| 061C14 | OnePlus Nord Buds CE | — | — | — | — | — | ✓ |
| 065C14 | OnePlus Open Buds | — | — | 开关 | ✓ | ✓ | ✓ |

### realme / DIZO（46）

| Product ID | 型号 | ANC | 自适应 | 空间音效 | 佩戴检测 | 双设备 | EQ |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|
| C70A70 | DIZO GoPods | — | — | — | — | — | — |
| C70A6F | DIZO GoPods D | — | — | — | — | — | — |
| C70A6E | DIZO Wireless | — | — | — | — | — | — |
| 3D59CF | realme Buds Air | — | — | — | — | — | — |
| BA5D56 | realme Buds Air 2 | — | — | — | — | — | — |
| 1B5374 | realme Buds Air 2 Neo | — | — | — | — | — | — |
| 060812 | realme Buds Air 3 | — | — | — | — | — | — |
| 061812 | realme Buds Air 3 Neo | — | — | — | — | — | — |
| 061012 | realme Buds Air 3S | — | — | — | — | — | — |
| 062012 | realme Buds Air 5 | — | — | — | ✓ | — | — |
| 061C12 | realme Buds Air 5 Pro | — | — | — | ✓ | — | — |
| F85450 | realme Buds Air Neo | — | — | — | — | — | — |
| 8CD10F | realme Buds Air Pro | — | — | — | — | — | — |
| 063412 | realme Buds Air6 | — | — | — | ✓ | — | — |
| 063012 | realme Buds Air6 Pro | — | — | — | ✓ | — | — |
| 064812 | realme Buds Air7 | — | — | — | ✓ | — | — |
| 064C12 | realme Buds Air7 Pro | — | — | — | ✓ | — | — |
| 066812 | realme Buds Air8 | — | — | — | ✓ | — | — |
| 066C12 | realme Buds Air8 Pro | — | — | — | ✓ | — | — |
| 065C12 | realme Buds Clip | — | — | — | — | — | — |
| 064012 | realme Buds N1 | — | — | — | — | — | — |
| 063812 | realme Buds N1 Pro | — | — | — | — | — | — |
| 693878 | realme Buds Q2 | — | — | — | — | — | — |
| 060C12 | realme Buds Q2s | — | — | — | — | — | — |
| 064412 | realme Buds T01 | — | — | — | — | — | — |
| 061412 | realme Buds T100 | — | — | — | — | — | — |
| 062812 | realme Buds T110 | — | — | — | — | — | — |
| 065452 | realme Buds T200 | — | — | — | — | — | — |
| 065052 | realme Buds T200 Lite | — | — | — | — | — | — |
| 065852 | realme Buds T200x | — | — | — | — | — | — |
| 062412 | realme Buds T300 | — | — | — | — | — | — |
| 063C12 | realme Buds T310 | — | — | — | — | — | — |
| 067052 | realme Buds T500 | — | — | — | — | — | — |
| 066452 | realme Buds T500 Pro | — | — | — | ✓ | — | — |
| 067452 | realme Buds T500 Pro Harry Potter Edition | — | — | — | ✓ | — | — |
| C1E2B1 | realme Buds Wireless 2 | — | — | — | — | — | — |
| C70A6D | realme Buds Wireless 2 Neo | — | — | — | — | — | — |
| 050412 | realme Buds Wireless 2S | — | — | — | — | — | — |
| 050812 | realme Buds Wireless 3 | — | — | — | — | — | — |
| 050C12 | realme Buds Wireless 3 Neo | — | — | — | — | — | — |
| 051412 | realme Buds Wireless 5 ANC | — | — | — | — | — | — |
| 051C52 | realme Buds Wireless 6 | — | — | — | — | — | — |
| 052052 | realme Buds Wireless 6 ANC | — | — | — | — | — | — |
| 051812 | realme Buds Wireless 6 Neo | — | — | — | — | — | — |
| E3009F | realme Buds Wireless Pro | — | — | — | — | — | — |
| 066012 | realme TechLife Buds | — | — | — | — | — | — |


## 明确关闭 SPP 的型号

以下记录在型号库中标记 `supportSpp=false`。macOS 客户端不会为它们套用型号能力配置；普通蓝牙音频是否可用不在此表承诺范围内。

| Product ID | 型号 |
|---|---|
| `061010` | OPPO Enco W11 |
| `060412` | OPPO O-Free |
| `062C10` | OPPO Enco W31 Lite |
| `050010` | OPPO Enco Quiet |
| `050810` | OPPO Enco M32 |
| `050414` | OnePlus Bullets Wireless Z2 |

## 型号库中的非耳机设备

以下记录支持 SPP，但属于音箱，因此没有计入 128 款 macOS 耳机候选：

| Product ID | 型号 |
|---|---|
| `49074B` | realme Cobble Speaker |
| `C70A75` | realme Pocket Speaker |
| `A5FD66` | realme Brick Speaker |

## 提交测试结果

请在 Issue 中提供：

- 完整商品型号、product ID 和固件版本
- macOS 版本及 Mac 芯片类型
- 电量、ANC、通透、自适应、空间音效、低延迟、EQ、佩戴检测、双设备逐项结果
- 是否需要先断开再连接，以及可复现步骤
- 脱敏后的错误信息或日志

请删除蓝牙 MAC 地址、序列号、账号和其他隐私信息。确认结果后，可把设备从“协议候选”提升为“已验证”。

## 更新规则

型号表以 `device_models.json` 为唯一数据源。新增或修改型号时，应同时检查：

1. product ID 是否唯一且为大写十六进制字符串。
2. `supportSpp`、UUID、ANC protocol index 与空间音效类型是否正确。
3. macOS `DeviceModelRegistry` 能否解析新增字段。
4. 至少记录设备、固件和验证平台，避免只凭同系列名称推断。
