# NFC Card Wallet — iPhone NFC 卡片读取与钱包管理 App

一个运行在 iPhone 上的 SwiftUI App，用于读取 NFC 卡片信息、本地保存管理，并把卡片作为通用 Pass 加入 Apple Wallet。

> ⚠️ **重要限制说明**：iPhone 不支持第三方 App 做 NFC 卡模拟（Card Emulation）。本 App 的"加入钱包"是把卡片 UID 等信息打包成 `generic` 类型的 Pass（含二维码），让用户在系统「钱包」App 中以扫码形式出示——**不是**真正的 NFC 门禁卡模拟。真正的 NFC 门禁卡模拟需要 Android 设备（HCE）。

## 功能

- **NFC 读取**：使用 Core NFC 的 `NFCTagReaderSession` 读取卡片 UID、SAK、ATQA、类型（MIFARE/FeliCa/ISO14443/ISO15693）
- **本地存储**：基于 SwiftData，卡片持久化保存，支持删除
- **二维码生成**：把 UID 转成 QR Code，方便扫码门禁使用
- **加入 Apple Wallet**：用 PassKit 生成 `.pkpass` 并通过 `PKAddPassesViewController` 添加到系统钱包
- **Mac 预览版**：浏览器打开 `preview/index.html` 即可体验完整流程

## 目录结构

```
nfc/
├── preview/
│   └── index.html             # Mac 浏览器可打开的 HTML 预览版
├── ios/
│   └── NFCCardWallet/
│       ├── project.yml         # XcodeGen 项目配置
│       └── NFCCardWallet/
│           ├── NFCCardWalletApp.swift        # App 入口
│           ├── Models/
│           │   └── NFCCard.swift             # SwiftData 模型
│           ├── Services/
│           │   ├── NFCReader.swift           # Core NFC 读取
│           │   └── PassGenerator.swift       # PassKit 生成 .pkpass
│           ├── Views/
│           │   ├── CardListView.swift        # 卡片列表
│           │   ├── ScanView.swift            # 扫描界面
│           │   ├── CardDetailView.swift      # 卡片详情 + 二维码
│           │   └── AddWalletView.swift       # 加入钱包
│           ├── Assets.xcassets/              # 图标与颜色
│           ├── pass.template/
│           │   └── pass.json                 # .pkpass 模板
│           ├── Info.plist
│           └── NFCCardWallet.entitlements
└── scripts/
    ├── build_ipa.sh            # 构建 IPA
    ├── sign_pass.sh            # OpenSSL 签名 .pkpass
    └── ExportOptions.plist     # 签名配置参考
```

## 快速开始

### 1. 在 Mac 上预览（无需任何账号、5 秒）

```bash
open "preview/index.html"
```

浏览器会显示 iPhone 模拟器外壳，点击「+」或「扫描」即可体验完整流程。

### 2. 用 Xcode 打开 iOS 工程

```bash
cd "ios/NFCCardWallet"
brew install xcodegen        # 如未安装
xcodegen generate            # 生成 .xcodeproj
open NFCCardWallet.xcodeproj
```

在 Xcode 中：
1. 选 Team（需要 Apple ID 免费账号也可，但 NFC 真机调试需付费 Developer 账号）
2. 连接 iPhone，选择真机目标
3. Cmd+R 运行

### 3. 构建 IPA

```bash
# 方式 A：自动签名（已配置 Developer 账号）
./scripts/build_ipa.sh development ABC12345

# 方式 B：未签名（用 Sideloadly/AltStore 二次签名）
./scripts/build_ipa.sh development
```

输出位置：`build/ipa/NFCCardWallet.ipa`

## 让"加入钱包"真正生效（关键）

iOS 上 App 不能在设备端动态生成 `.pkpass`，必须用 **Pass Type ID 证书**签名。完整流程：

### 1. 申请 Pass Type ID 证书

1. 登录 [Apple Developer](https://developer.apple.com/account/resources/identifiers/list/pass)
2. Identifiers → + → Pass Type IDs
3. 填入 `pass.com.nfccardwallet.app`
4. 创建并下载证书，双击导入钥匙串
5. 在钥匙串中导出为 `.p12`（设置密码）

### 2. 下载 WWDR 中间证书

```bash
mkdir -p certs
curl -o certs/AppleWWDRCA.cer https://developer.apple.com/certificationauthority/AppleWWDRCA.cer
```

### 3. 把 Pass 集成到 App

修改 `PassGenerator.swift` 的 `loadBundledSignedPass`：
- 让 App 在用户点击「加入钱包」时调用一个服务端接口（或本地预生成 `.pkpass`）
- 把返回的 `.pkpass` 二进制传给 `PKAddPassesViewController`

或直接在构建期预签名一个 `.pkpass` 放入 Bundle：

```bash
./scripts/sign_pass.sh "测试卡" "04A3125F7B81" "MIFARE Ultralight" \
    "04A3125F7B81" "test-001" 0 pass.p12 mypass123
# 生成 build/passes/test-001.pkpass
# 把它拖入 Xcode 的 Resources
```

### 4. 配置 entitlements

修改 `NFCCardWallet.entitlements`：

```xml
<key>com.apple.developer.pass-type-identifiers</key>
<array>
    <string>pass.com.nfccardwallet.app</string>
</array>
```

`teamIdentifier` 在 `pass.json` 里改成你的 10 位 Team ID（不要带 `TEAMIDXX`）。

## 权限说明

| 权限 | 用途 | 配置位置 |
|---|---|---|
| `NFCReaderUsageDescription` | App 用 NFC 读卡时的系统提示语 | Info.plist |
| `com.apple.developer.nfc.readersession` | 允许前台 NFC 读取 | entitlements |
| `com.apple.developer.nfc.readersession.iso7816.selectidentifiers` | 支持的 ISO7816 AID 列表 | Info.plist |
| `com.apple.developer.pass-type-identifiers` | 允许添加对应 Pass Type ID 到钱包 | entitlements |

## 真机测试注意

1. NFC 读取**只在真机**有效，模拟器无法测试 NFC
2. App 必须在前台，屏幕亮起，且 iPhone 解锁状态
3. 卡片贴近 iPhone 背部上方（摄像头附近）才会触发
4. `NFCReaderSession` 一次最多 60 秒
5. 部分 MIFARE Classic 卡需要密钥才能读数据块，本 App 仅读 UID

## 关于"卡模拟"的再次说明

如果你最终目标是"用 iPhone 替代实体门禁卡刷开门禁"——**这事在 iPhone 上做不到**。Apple 把 NFC 卡模拟限制在 Apple Pay，第三方 App 完全无法访问相关硬件能力。无论怎么签名、怎么封装 IPA 都无法绕过这个限制。

可行替代方案：
1. 用 Android 手机的 HCE 功能做卡模拟
2. 用本 App 读取卡 UID，再写入一张空白 NFC 标签（需要 NFC 写卡器 + 标签）
3. 用本 App + 通用 Pass，把 UID 做成二维码给支持扫码的门禁用

## License

仅供学习研究使用。请勿用于绕过任何门禁系统或未经授权的卡片复制。
