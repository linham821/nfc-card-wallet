#!/usr/bin/env bash
# setup_env.sh — 一键准备 iOS 构建环境并产出 IPA
#
# 这个脚本会按顺序做这些事：
#   1. 检查磁盘空间
#   2. 检查 Xcode 是否安装（没装会打开 App Store 让你下载）
#   3. 安装 Homebrew（如未装）
#   4. 安装 xcodegen
#   5. 运行 build_ipa.sh 产出未签名 IPA（给 Sideloadly 用）
#
# 用法：
#   ./scripts/setup_env.sh
#
# 你需要自己做的事（脚本没法替你）：
#   - 装 Xcode（App Store 下载约 12GB）
#   - 删照片/视频腾出磁盘空间（Xcode 需要 35GB）

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()    { echo -e "${GREEN}✓ $1${NC}"; }
err()   { echo -e "${RED}❌ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
step()  { echo -e "\n${GREEN}=== $1 ===${NC}"; }

# === 1. 检查磁盘空间 ===
step "1/5 检查磁盘空间"
AVAIL_GB=$(df -g /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}' || df -g / | awk 'NR==2 {print $4}')
echo "  当前可用: ${AVAIL_GB} GB"
if [[ "$AVAIL_GB" -lt 30 ]]; then
    warn "可用空间不足 30GB（Xcode 需要约 35GB）"
    echo "  建议清理："
    echo "    - ~/Downloads/*.dmg (约 1.6GB)"
    echo "    - ~/Library/Caches/* (已清过，可再清 com.apple.MobileSMS 等)"
    echo "    - 照片/视频/iCloud 缓存"
    echo "    - /Applications 里的大型软件"
    read -p "  是否继续？(y/N) " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
else
    ok "磁盘空间足够"
fi

# === 2. 检查 Xcode ===
step "2/5 检查 Xcode"
if ! command -v xcodebuild >/dev/null 2>&1; then
    err "未安装完整 Xcode（只有 Command Line Tools）"
    echo ""
    echo "请按以下步骤安装："
    echo "  1. 打开 App Store"
    echo "  2. 搜索 Xcode"
    echo "  3. 点击下载安装（约 12GB，需要 Apple ID 登录）"
    echo "  4. 装完后在终端运行:"
    echo "       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo "       sudo xcodebuild -runFirstLaunch"
    echo "       sudo xcodebuild -license accept"
    echo ""
    read -p "  是否现在打开 App Store Xcode 页面？(Y/n) " open_store
    if [[ ! "$open_store" =~ ^[Nn]$ ]]; then
        open "macappstore://apps.apple.com/app/xcode/id497799835"
    fi
    echo ""
    echo "装完 Xcode 后，重新运行此脚本："
    echo "  ./scripts/setup_env.sh"
    exit 1
fi
XCODE_VER=$(xcodebuild -version 2>&1 | head -1)
ok "已安装 $XCODE_VER"

# 确保选中正确的 Xcode
SELECTED=$(xcode-select -p 2>/dev/null || echo "")
if [[ "$SELECTED" != "/Applications/Xcode.app/Contents/Developer" ]]; then
    warn "当前 developer directory 不是 Xcode.app: $SELECTED"
    echo "  请运行: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    read -p "  是否现在尝试切换？（需要 sudo 密码）(Y/n) " switch
    if [[ ! "$switch" =~ ^[Nn]$ ]]; then
        sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    fi
fi

# === 3. 安装 Homebrew ===
step "3/5 检查 Homebrew"
if ! command -v brew >/dev/null 2>&1; then
    warn "未安装 Homebrew，开始安装..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Apple Silicon 需要 eval
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    ok "Homebrew 已安装: $(brew --version | head -1)"
fi

# === 4. 安装 xcodegen ===
step "4/5 检查 xcodegen"
if ! command -v xcodegen >/dev/null 2>&1; then
    warn "未安装 xcodegen，开始安装..."
    brew install xcodegen
else
    ok "xcodegen 已安装: $(xcodegen --version 2>&1 | head -1)"
fi

# === 5. 构建 IPA ===
step "5/5 构建未签名 IPA"
echo "  运行 build_ipa.sh ..."
echo ""
"$PROJECT_DIR/scripts/build_ipa.sh" unsigned

echo ""
ok "全部完成！"
echo ""
echo "下一步：用 Sideloadly 把 IPA 装到 iPhone："
echo "  详见 scripts/sideload_guide.md"
