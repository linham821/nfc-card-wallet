#!/usr/bin/env bash
# build_ipa.sh — 一键构建 IPA（支持未签名模式，便于 Sideloadly 二次签名）
#
# 依赖：
#   - Xcode（含 iOS SDK + xcodebuild）—— App Store 下载
#   - XcodeGen（brew install xcodegen）—— 生成 .xcodeproj
#
# 用法：
#   ./scripts/build_ipa.sh                          # 默认 unsigned（推荐给 Sideloadly）
#   ./scripts/build_ipa.sh unsigned                 # 显式 unsigned
#   ./scripts/build_ipa.sh development ABC12345     # 用付费 Developer 账号签名（Team ID）
#   ./scripts/build_ipa.sh app-store ABC12345       # 上架签名
#
# 三种模式说明：
#   unsigned      → 产出未签名 .ipa，需 Sideloadly/AltStore + 免费 Apple ID 重签后才能装
#   development   → 用付费 Developer 账号签名，可直接装自己设备（1 年有效）
#   app-store     → 上架用，只能装 TestFlight 或提交 App Store

set -euo pipefail

# === 配置区 ===
SCHEME="NFCCardWallet"
CONFIGURATION="Release"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$PROJECT_DIR/ios/NFCCardWallet"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/NFCCardWallet.xcarchive"
EXPORT_DIR="$BUILD_DIR/ipa"

METHOD="${1:-unsigned}"
TEAM_ID="${2:-}"

echo "==> 项目目录: $IOS_DIR"
echo "==> 构建模式: $METHOD"
[[ -n "$TEAM_ID" ]] && echo "==> Team ID: $TEAM_ID"

# === 检查 Xcode ===
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "❌ 未找到 xcodebuild。请先从 App Store 安装完整 Xcode："
    echo "   https://apps.apple.com/cn/app/xcode/id497799835"
    echo "   装完后运行: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

cd "$IOS_DIR"

# === 1. 生成 .xcodeproj（如不存在）===
if [[ ! -d "NFCCardWallet.xcodeproj" ]]; then
    echo "==> 生成 Xcode 工程..."
    if ! command -v xcodegen >/dev/null 2>&1; then
        echo "❌ 未安装 xcodegen，请先运行: brew install xcodegen"
        echo "   （brew 未装的话: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"）"
        exit 1
    fi
    xcodegen generate 2>&1 | sed 's/^/    /'
fi

mkdir -p "$BUILD_DIR"

# === 分支：unsigned 模式（直接 build .app，再手动打 .ipa）===
if [[ "$METHOD" == "unsigned" ]]; then
    echo "==> [unsigned] 编译未签名 .app..."
    DERIVED_DATA="$BUILD_DIR/DerivedData"
    xcodebuild build \
        -project NFCCardWallet.xcodeproj \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        DEVELOPMENT_TEAM="" \
        2>&1 | sed 's/^/    /' | tail -50

    APP_PATH=$(find "$DERIVED_DATA/Build/Products" -name "NFCCardWallet.app" -type d | head -1)
    if [[ -z "$APP_PATH" ]]; then
        echo "❌ 编译失败，未找到 .app"
        exit 1
    fi
    echo "==> .app 路径: $APP_PATH"

    # 用 ad-hoc codesign 嵌入 entitlements（NFC 等能力需要）
    # 这样 Sideloadly 重签时能保留这些 entitlements
    ENTITLEMENTS_PATH="$IOS_DIR/NFCCardWallet/NFCCardWallet.entitlements"
    if [[ -f "$ENTITLEMENTS_PATH" ]]; then
        echo "==> 嵌入 entitlements: $ENTITLEMENTS_PATH"
        codesign --force --sign - --entitlements "$ENTITLEMENTS_PATH" "$APP_PATH" 2>&1 | sed 's/^/    /'
        echo "    ✅ Entitlements 已嵌入"
    else
        echo "    ⚠️  未找到 entitlements 文件: $ENTITLEMENTS_PATH"
    fi

    # 包装为 .ipa（Payload/ 目录结构）
    rm -rf "$EXPORT_DIR"
    mkdir -p "$EXPORT_DIR/Payload"
    cp -R "$APP_PATH" "$EXPORT_DIR/Payload/"
    cd "$EXPORT_DIR"
    rm -f "NFCCardWallet-unsigned.ipa"
    zip -q -r "NFCCardWallet-unsigned.ipa" Payload/
    rm -rf Payload

    IPA_FILE="$EXPORT_DIR/NFCCardWallet-unsigned.ipa"
    echo ""
    echo "✅ 未签名 IPA 构建完成！"
    echo "   IPA: $IPA_FILE"
    echo "   大小: $(du -h "$IPA_FILE" | awk '{print $1}')"
    echo ""
    echo "⚠️  此 IPA 未签名，无法直接装到 iPhone。请用 Sideloadly + 免费 Apple ID 重签："
    echo "   详见: scripts/sideload_guide.md"
    exit 0
fi

# === 分支：签名模式（development / app-store）===
if [[ -z "$TEAM_ID" ]]; then
    echo "❌ 签名模式必须提供 Team ID"
    echo "   用法: $0 $METHOD YOUR_TEAM_ID"
    exit 1
fi

SIGNING_STYLE="manual"

EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${METHOD}</string>
    <key>signingStyle</key>
    <string>${SIGNING_STYLE}</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF
echo "==> ExportOptions 已写入: $EXPORT_OPTIONS"

echo "==> 开始 archive..."
xcodebuild archive \
    -project NFCCardWallet.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_STYLE="$SIGNING_STYLE" \
    2>&1 | sed 's/^/    /' | tail -100

echo "==> 导出签名 IPA..."
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    2>&1 | sed 's/^/    /' | tail -50

IPA_FILE=$(find "$EXPORT_DIR" -name "*.ipa" -maxdepth 1 | head -1)
if [[ -z "$IPA_FILE" ]]; then
    echo "❌ 未找到导出的 IPA 文件，请检查上方日志"
    exit 1
fi

echo ""
echo "✅ 签名 IPA 构建完成！"
echo "   IPA: $IPA_FILE"
echo "   大小: $(du -h "$IPA_FILE" | awk '{print $1}')"
