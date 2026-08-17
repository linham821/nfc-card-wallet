# 用 GitHub Actions 云端构建 IPA

不需要本地装 Xcode，不需要磁盘空间。把代码 push 到 GitHub，云端自动构建，下载 IPA。

## 一次性准备（约 5 分钟）

### 1. 注册 GitHub 账号

如果还没有，去 https://github.com/signup 注册（免费）。

### 2. 创建仓库

1. 登录 GitHub → 右上角 + → New repository
2. Repository name: `nfc-card-wallet`（或任意名）
3. 选 **Private**（推荐，避免代码公开）或 Public（公开仓库免费额度更多）
4. **不要**勾选 "Add a README"、"Add .gitignore"、"Choose a license"（项目里已有）
5. 点 Create repository

### 3. 把项目 push 上去

在终端执行（替换 `你的用户名`）：

```bash
cd "/Users/lin/Desktop/iPhone nfc/nfc"

# 初始化 git
git init
git add .
git commit -m "Initial commit: NFC Card Wallet iOS app"

# 关联远程仓库并推送
git branch -M main
git remote add origin https://github.com/你的用户名/nfc-card-wallet.git
git push -u origin main
```

首次 push 会提示输入 GitHub 用户名和密码。**密码要用 Personal Access Token**，不能用账号密码：

1. 去 https://github.com/settings/tokens
2. Generate new token (classic)
3. 勾选 `repo` 权限
4. 生成后复制 token（只显示一次！）
5. push 时密码栏粘贴 token

或者用 SSH key（更方便，配置一次永久可用）：https://docs.github.com/authentication/connecting-to-github-with-ssh

## 触发构建

push 完成后，GitHub 会**自动触发**构建（因为 workflow 配置了 push 触发）。

也可手动触发：
1. 进仓库页面 → 顶部 **Actions** tab
2. 左侧选 "Build iOS IPA"
3. 右侧 "Run workflow" → Run workflow

## 下载 IPA

1. 进 Actions tab
2. 点最近一次运行（黄色/绿色圆点）
3. 滚动到页面底部 **Artifacts** 区域
4. 点 `NFCCardWallet-unsigned-ipa` 下载
5. 解压得到 `NFCCardWallet-unsigned.ipa`

## 装到 iPhone

按 [sideload_guide.md](sideload_guide.md) 操作：
1. 装 Sideloadly
2. 用 Apple ID + 应用专用密码签名
3. iPhone 信任开发者证书

## 常见问题

### Q: 构建失败怎么办？

进 Actions → 点失败的运行 → 看红色那一步的日志。常见原因：
- 代码编译错误（Swift 语法问题）
- xcodegen 配置问题
- 网络/依赖问题（重试即可）

把错误日志发我，我帮你修。

### Q: 免费额度够用吗？

- **公开仓库**：完全免费，无限制
- **私有仓库**：每月 2000 分钟免费，但 macOS runner 是 10x 计费，相当于 200 分钟 macOS
- 一次构建约 10-15 分钟，足够你跑 10-20 次

### Q: 构建产物保留多久？

默认 30 天。到期可重新触发构建。

### Q: 能否自动签名出可装 IPA？

GitHub Actions 上可以用免费 Apple ID 签名，但有局限：
- 需要 Apple ID 凭证（不安全，不建议放 CI）
- 免费签名 7 天过期
- 不如本地用 Sideloadly 签名稳定

建议方案：CI 出未签名 IPA，本地 Sideloadly 签名。
