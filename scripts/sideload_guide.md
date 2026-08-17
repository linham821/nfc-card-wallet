# Sideloadly 安装指南 — 把未签名 IPA 装到 iPhone

本文档介绍如何用 Sideloadly + 免费 Apple ID，把 `build/ipa/NFCCardWallet-unsigned.ipa` 装到非越狱 iPhone。

> ⚠️ 免费 Apple ID 签名的 App **7 天后失效**，需要重新连电脑跑一次签名。App 内数据会保留（同名重装即可）。如需 1 年有效，需购买 $99/年 Apple Developer 账号。

## 前置条件

1. ✅ Mac 上已装 Xcode（App Store 下载）
2. ✅ 已运行 `./scripts/build_ipa.sh`，产出 `build/ipa/NFCCardWallet-unsigned.ipa`
3. ✅ 一个 Apple ID（不必是付费 Developer 账号，免费的就行）
4. ✅ 一根 USB 数据线 + 你的 iPhone
5. ✅ iPhone 已解锁，已信任此电脑

> 💡 建议用一个**专门用来侧载的 Apple ID**（小号），避免主账号产生异常登录提示。

## 步骤 1：装 Sideloadly

到官网下载：https://sideloadly.io/

- 下载 Sideloadly for macOS
- 解压后拖到 `/Applications/`
- 首次打开时如果被 Gatekeeper 拦截：系统设置 → 隐私与安全性 → 仍要打开

## 步骤 2：准备 iPhone

1. 用 USB 线连接 iPhone 到 Mac
2. iPhone 上弹出"信任此电脑" → 点信任
3. 解锁屏幕保持亮起

## 步骤 3：在 Sideloadly 中签名安装

打开 Sideloadly，按以下顺序操作：

1. **iPhone 图标**（左上角）→ 选择你连接的设备
2. **IPA 路径**（拖入或点图标选择）：选 `build/ipa/NFCCardWallet-unsigned.ipa`
3. **Apple ID**：输入你的 Apple ID 邮箱
4. **密码**：点 "Start" 后会弹出输入密码
   - 如果你开了**双重认证**（几乎所有人都开了），不要输 Apple ID 主密码
   - 要去 https://appleid.apple.com → 登录 → 应用专用密码 → 生成一个专用密码
   - 把生成的专用密码（格式 `xxxx-xxxx-xxxx-xxxx`）填进去
5. **Bundle ID**（可选）：默认会自动改写为 `com.yourappleid.NFCCardWallet`，避免与已有 App 冲突
6. 点 **Start** 开始签名 + 安装

整个过程 1-3 分钟，会显示进度条。

## 步骤 4：信任开发者证书（iPhone 上必做！）

装完后图标会出现，但点击会提示"不受信任的开发者"。需要：

1. iPhone → 设置 → 通用 → VPN 与设备管理
2. 找到你的 Apple ID 对应的"开发者 App"
3. 点击 → 信任
4. 回桌面就能正常打开 App 了

## 常见问题

### Q1: 提示 "Anisette server error" 或 " provisioning failed"

Sideloadly 需要一个 Apple 服务的中间代理。检查：
- 网络（VPN 可能干扰，先关掉试试）
- Sideloadly 版本是否最新
- 重启 Sideloadly 再试

### Q2: 提示 "maximum number of App IDs reached"

免费 Apple ID 每周只能签 **10 个不同的 Bundle ID**。等 7 天后额度刷新，或换一个 Apple ID。

### Q3: 装完后 NFC 功能不工作

NFC 读取**必须真机**，且：
- iPhone 7 或更新机型
- iOS 14+（建议最新版）
- App 必须在前台 + 屏幕解锁
- 卡片贴近 iPhone 背部摄像头附近
- 如果提示"无法使用 NFC 读取"，检查 `Info.plist` 的 `NFCReaderUsageDescription` 是否生效

### Q4: 7 天后 App 闪退怎么办

免费签名 7 天过期。重新连 Mac → 打开 Sideloadly → 选同样的 IPA → Start。重签不会丢数据（除非你卸载了 App）。

### Q5: 我想让 App 永久有效

购买 Apple Developer 账号（$99/年）：
1. 在 developer.apple.com 注册
2. 在 App Store Connect 创建 App ID + Provisioning Profile
3. 导入证书到 Mac 钥匙串
4. 运行 `./scripts/build_ipa.sh development 你的TeamID`
5. 产出的 IPA 直接拖到 Xcode → Devices 安装，1 年有效

## 一键检查清单

- [ ] Xcode 已装（`xcodebuild -version` 能输出版本号）
- [ ] `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` 已执行
- [ ] Homebrew 已装（`brew --version` 能输出版本号）
- [ ] xcodegen 已装（`brew install xcodegen`）
- [ ] `./scripts/build_ipa.sh` 跑通，产出 `build/ipa/NFCCardWallet-unsigned.ipa`
- [ ] Sideloadly 已装
- [ ] iPhone 已用 USB 连接并信任
- [ ] 应用专用密码已生成（https://appleid.apple.com）
- [ ] 装完后在 iPhone 设置里信任开发者证书
