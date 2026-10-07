#!/usr/bin/env bash
# =====================================================================
#  Kali VPN Manager — Installer
#  bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/install.sh)
#
#  گزینه‌ها:  --with-singbox   نصب sing-box (برای TUN Mode) بدون سؤال
#             --no-singbox     نصب نکردن sing-box بدون سؤال
# =====================================================================
set -u

REPO="AmirSarani/kali-vpn-manager"
REF="${VPN_REF:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$REF"

SINGBOX_VERSION="1.13.21"
SINGBOX_SHA256_amd64="24f9ef8e7234e13e71e74c3598a4164c5fe07b7b67ccc6e96cf68b54789f72cd"
SINGBOX_SHA256_arm64="3e30b876c9a93c19e503e2a2d6249cf05e6a26766553d4b61e1daf48223f304f"

INSTALL_DIR="${VPN_HOME:-$HOME/.local/share/vpn-manager}"
CONF_DIR="$HOME/.config/vpn-manager"
CONF_FILE="$CONF_DIR/config"
MARK_BEGIN="# >>> kali-vpn-manager >>>"
MARK_END="# <<< kali-vpn-manager <<<"

R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; C=$'\033[0;36m'; N=$'\033[0m'
die()  { echo "${R}✗ $*${N}" >&2; exit 1; }
ok()   { echo "${G}    ✓ $*${N}"; }
step() { echo; echo "${Y}[$1/5]${N} ${C}$2${N}"; }

SINGBOX_MODE=ask
for arg in "$@"; do
    case "$arg" in
        --with-singbox) SINGBOX_MODE=yes ;;
        --no-singbox)   SINGBOX_MODE=no ;;
        -h|--help)      sed -n '2,9p' "$0"; exit 0 ;;
        *)              die "گزینه ناشناخته: $arg" ;;
    esac
done

echo "${C}══════ Kali VPN Manager — Installer ══════${N}"

[ "$(id -u)" -eq 0 ] && die "این اسکریپت را با کاربر معمولی اجرا کن، نه root."
[ -f /etc/debian_version ] || die "فقط برای Debian / Ubuntu / Kali."
command -v sudo >/dev/null 2>&1 || die "sudo نصب نیست."

ask_yes() {  # ask_yes "سؤال" → 0 اگر y
    [ -r /dev/tty ] || return 1
    local a
    printf "%s (y/N): " "$1" > /dev/tty
    read -r a < /dev/tty
    [ "$a" = "y" ] || [ "$a" = "Y" ]
}

# ---------------------------------------------------------------- 1
step 1 "پیش‌نیازها"
MISSING=()
command -v curl >/dev/null 2>&1        || MISSING+=(curl)
command -v proxychains4 >/dev/null 2>&1 || MISSING+=(proxychains4)
command -v ip >/dev/null 2>&1          || MISSING+=(iproute2)
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "    → نصب: ${MISSING[*]}"
    sudo apt-get update -qq && sudo apt-get install -y "${MISSING[@]}" || die "نصب پیش‌نیازها ناموفق بود."
else
    ok "همه نصب هستند"
fi

# ---------------------------------------------------------------- 2
step 2 "ساخت پوشه‌ها"
mkdir -p "$INSTALL_DIR/bin" "$CONF_DIR" || die "ساخت پوشه ناموفق بود."
ok "$INSTALL_DIR"

# ---------------------------------------------------------------- 3
step 3 "نصب vpn.sh"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/vpn.sh" ]; then
    cp "$SELF_DIR/vpn.sh" "$INSTALL_DIR/vpn.sh" || die "کپی ناموفق بود."
    ok "از پوشه محلی کپی شد"
else
    curl -fsSL "$RAW/vpn.sh" -o "$INSTALL_DIR/vpn.sh.tmp" || die "دانلود vpn.sh ناموفق بود ($RAW/vpn.sh)"
    mv "$INSTALL_DIR/vpn.sh.tmp" "$INSTALL_DIR/vpn.sh"
    ok "از GitHub دانلود شد ($REF)"
fi
bash -n "$INSTALL_DIR/vpn.sh" || die "vpn.sh خطای سینتکس دارد."
chmod 644 "$INSTALL_DIR/vpn.sh"

if [ ! -f "$CONF_FILE" ]; then
    cat > "$CONF_FILE" <<'EOF'
# تنظیمات Kali VPN Manager — خط‌ها را از حالت کامنت دربیاور و تغییر بده
#VPN_PORT=10808        # پورت پروکسی روی ویندوز (v2rayN: mixed=10808 / http=10809)
#VPN_PROTO="http"      # http | socks5
#VPN_HOST=""           # خالی = خودکار (x.x.x.1). برای شبکه‌های غیر VMware NAT مقدار بده
#NET_IFACE=""          # خالی = خودکار
#VPN_DNS_SERVER="1.1.1.1"
EOF
    ok "فایل تنظیمات: $CONF_FILE"
else
    ok "فایل تنظیمات قبلی حفظ شد"
fi

# sing-box
if [ ! -x "$INSTALL_DIR/bin/sing-box" ] && ! command -v sing-box >/dev/null 2>&1; then
    want=no
    case "$SINGBOX_MODE" in
        yes) want=yes ;;
        ask) ask_yes "    sing-box (برای TUN Mode) نصب شود؟" && want=yes ;;
    esac
    if [ "$want" = yes ]; then
        case "$(uname -m)" in
            x86_64|amd64)  arch=amd64; sha="$SINGBOX_SHA256_amd64" ;;
            aarch64|arm64) arch=arm64; sha="$SINGBOX_SHA256_arm64" ;;
            *) arch=""; echo "${R}    ✗ معماری $(uname -m) پشتیبانی نمی‌شود؛ sing-box را دستی نصب کن.${N}" ;;
        esac
        if [ -n "$arch" ]; then
            tgz="sing-box-$SINGBOX_VERSION-linux-$arch.tar.gz"
            tmp="$(mktemp -d)"
            echo "    → دانلود $tgz ..."
            if curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/$tgz" -o "$tmp/$tgz" \
               && echo "$sha  $tmp/$tgz" | sha256sum -c --quiet - \
               && tar -xzf "$tmp/$tgz" -C "$tmp" \
               && install -m 755 "$tmp/sing-box-$SINGBOX_VERSION-linux-$arch/sing-box" "$INSTALL_DIR/bin/sing-box"; then
                ok "sing-box $SINGBOX_VERSION نصب شد (checksum تایید شد)"
            else
                echo "${R}    ✗ نصب sing-box ناموفق بود؛ بقیه قابلیت‌ها کار می‌کنند، TUN Mode نه.${N}"
            fi
            rm -rf "$tmp"
        fi
    else
        echo "    - sing-box رد شد (TUN Mode کار نمی‌کند؛ بعداً: install.sh --with-singbox)"
    fi
else
    ok "sing-box موجود است"
fi

# ---------------------------------------------------------------- 4
step 4 "اضافه کردن به شل"
add_rc() {
    local rc=$1
    [ -f "$rc" ] || return 0
    if grep -qF "$MARK_BEGIN" "$rc" || grep -q "vpn-manager/vpn.sh" "$rc"; then
        ok "$(basename "$rc"): از قبل موجود"
        return 0
    fi
    cp "$rc" "$rc.vpn-manager.bak"
    {
        echo
        echo "$MARK_BEGIN"
        echo '[ -f "$HOME/.local/share/vpn-manager/vpn.sh" ] && . "$HOME/.local/share/vpn-manager/vpn.sh"'
        echo "$MARK_END"
    } >> "$rc"
    ok "$(basename "$rc"): اضافه شد (بکاپ: $(basename "$rc").vpn-manager.bak)"
}
[ -f "$HOME/.zshrc" ] || [ -f "$HOME/.bashrc" ] || touch "$HOME/.bashrc"
add_rc "$HOME/.zshrc"
add_rc "$HOME/.bashrc"

# ---------------------------------------------------------------- 5
step 5 "تست"
[ -f "$INSTALL_DIR/vpn.sh" ] && ok "vpn.sh" || die "vpn.sh پیدا نشد"
command -v proxychains4 >/dev/null 2>&1 && ok "proxychains4"
if bash -c ". '$INSTALL_DIR/vpn.sh' && type vpn >/dev/null"; then ok "تابع vpn لود می‌شود"; else die "لود vpn.sh ناموفق"; fi

echo
echo "${G}══════ نصب با موفقیت انجام شد ══════${N}"
echo "  ترمینال جدید باز کن (یا:  ${Y}source ~/.zshrc${N}  /  ${Y}source ~/.bashrc${N})"
echo "  سپس:  ${G}vpn${N}"
echo "  قبلش در ویندوز، VPN را روشن و ${Y}Allow LAN${N} را فعال کن."
echo "  تنظیمات (پورت/پروتکل):  ${Y}$CONF_FILE${N}"
