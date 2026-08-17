#!/usr/bin/env bash
# sign_pass.sh — 用 Pass Type ID 证书签名 .pkpass
#
# 前置条件（必读）：
#   1. 拥有 Apple Developer 账号
#   2. 在 https://developer.apple.com/account/resources/identifiers/list/pass
#      创建 Pass Type ID（例如 pass.com.nfccardwallet.app）
#   3. 申请对应的 Pass 证书，导出为 .p12（带密码）
#   4. 下载 Apple Worldwide Developer Relations 中间证书 WWDR
#      https://developer.apple.com/certificationauthority/AppleWWDRCA.cer
#
# 用法：
#   ./scripts/sign_pass.sh <name> <uid> <type> <card_number> <serial> <color_index> <cert.p12> <p12_password>
#
# 示例：
#   ./scripts/sign_pass.sh "小区门禁卡" "04A3125F7B81" "MIFARE Ultralight" "04A3125F7B81" "uuid-1234" 0 pass.p12 mypass123
#
# 输出：./build/passes/<serial>.pkpass

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$PROJECT_DIR/ios/NFCCardWallet/NFCCardWallet/pass.template"
OUTPUT_DIR="$PROJECT_DIR/build/passes"
WWDR_CER="${WWDR_CER:-$PROJECT_DIR/certs/AppleWWDRCA.cer}"

if [[ "$#" -lt 8 ]]; then
    cat <<EOF
用法:
  $0 <name> <uid> <type> <card_number> <serial> <color_index> <cert.p12> <p12_password>

参数说明:
  name          卡片显示名称
  uid           NFC UID（无分隔符，如 04A3125F7B81）
  type          卡片类型字符串
  card_number   卡号（一般同 uid）
  serial        唯一序列号（建议用 UUID）
  color_index   颜色索引 0-5
  cert.p12      Pass Type ID 证书（.p12 格式）
  p12_password  .p12 文件密码
EOF
    exit 1
fi

NAME="$1"
UID_HEX="$2"
CARD_TYPE="$3"
CARD_NUM="$4"
SERIAL="$5"
COLOR_IDX="$6"
CERT_P12="$7"
P12_PWD="$8"

# 颜色调色板（与 Swift 端一致）
BG_COLORS=("rgb(44,62,80)" "rgb(142,68,173)" "rgb(192,57,43)" "rgb(22,160,133)" "rgb(41,128,185)" "rgb(211,84,0)")
LABEL_COLORS=("rgb(180,200,220)" "rgb(220,200,240)" "rgb(240,200,200)" "rgb(200,240,230)" "rgb(200,220,240)" "rgb(255,220,200)")

BG="${BG_COLORS[$COLOR_IDX]}"
LABEL="${LABEL_COLORS[$COLOR_IDX]}"

UID_DISPLAY=$(echo "$UID_HEX" | sed 's/\(..\)/\1:/g' | sed 's/:$//')

# 临时工作目录
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

echo "==> 准备 pass 内容..."
cp -R "$TEMPLATE_DIR/." "$WORK_DIR/"
# 如果模板里没有 icon.png / logo.png，可放占位图（这里跳过，让 pass 用 logoText）

# 替换 pass.json 中的占位符
PASS_JSON="$WORK_DIR/pass.json"
sed -i '' \
    -e "s/REPLACE_NAME/$NAME/g" \
    -e "s/REPLACE_UID/$UID_DISPLAY/g" \
    -e "s/REPLACE_TYPE/$CARD_TYPE/g" \
    -e "s/REPLACE_NUM/$CARD_NUM/g" \
    -e "s/REPLACE_SERIAL/$SERIAL/g" \
    -e "s|rgb(44,62,80)|$BG|g" \
    -e "s|rgb(180,200,220)|$LABEL|g" \
    "$PASS_JSON"

echo "==> 生成 manifest.json..."
# 列出所有文件（除 manifest 与 signature）
MANIFEST="$WORK_DIR/manifest.json"
{
    echo "{"
    FIRST=1
    for f in $(find "$WORK_DIR" -type f ! -name "manifest.json" ! -name "signature" | sort); do
        REL="${f#$WORK_DIR/}"
        HASH=$(openssl sha1 -r "$f" | awk '{print $1}')
        if [[ $FIRST -eq 0 ]]; then echo ","; fi
        printf '  "%s" : "%s"' "$REL" "$HASH"
        FIRST=0
    done
    echo ""
    echo "}"
} > "$MANIFEST"

if [[ ! -f "$WWDR_CER" ]]; then
    echo "❌ 未找到 WWDR 中间证书: $WWDR_CER"
    echo "   下载地址: https://developer.apple.com/certificationauthority/AppleWWDRCA.cer"
    echo "   或设置环境变量: export WWDR_CER=/path/to/AppleWWDRCA.cer"
    exit 1
fi

echo "==> 签名 manifest..."
# 1) 从 .p12 提取签名密钥（要求 .p12 同时包含 Pass 证书 + 私钥）
KEY_PEM="$WORK_DIR/key.pem"
CERT_PEM="$WORK_DIR/cert.pem"
openssl pkcs12 -in "$CERT_P12" -nocerts -out "$KEY_PEM" -nodes -passin "pass:$P12_PWD" 2>/dev/null
openssl pkcs12 -in "$CERT_P12" -clcerts -nokeys -out "$CERT_PEM" -passin "pass:$P12_PWD" 2>/dev/null

# 2) 用私钥 + Pass 证书 + WWDR 中间证书签名 manifest
openssl smime -binary -sign \
    -certfile "$WWDR_CER" \
    -signer "$CERT_PEM" \
    -inkey "$KEY_PEM" \
    -in "$MANIFEST" \
    -out "$WORK_DIR/signature" \
    -outform DER 2>/dev/null

# 删除临时密钥文件（不应进入 .pkpass）
rm -f "$KEY_PEM" "$CERT_PEM"

echo "==> 打包 .pkpass..."
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/${SERIAL}.pkpass"
rm -f "$OUTPUT_FILE"
cd "$WORK_DIR"
zip -q -X "$OUTPUT_FILE" ./*

echo ""
echo "✅ Pass 签名完成！"
echo "   文件: $OUTPUT_FILE"
echo "   大小: $(du -h "$OUTPUT_FILE" | awk '{print $1}')"
echo ""
echo "验证方式："
echo "   • Mac 上双击 .pkpass 会自动加到「钱包」App"
echo "   • 或用 iOS 邮件/AirDrop 发到 iPhone，点击即可添加"
