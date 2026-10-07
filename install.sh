#!/usr/bin/env bash
# =====================================================================
#  Kali VPN Manager — Installer
#  bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/install.sh)
#
#  Options / گزینه‌ها:
#    --lang en|fa      interface language / زبان (default: ask, else en)
#    --with-singbox    install sing-box for TUN mode without asking
#    --no-singbox      never install sing-box
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

LANG_CHOICE=""
SINGBOX_MODE=ask
while [ $# -gt 0 ]; do
    case "$1" in
        --with-singbox) SINGBOX_MODE=yes ;;
        --no-singbox)   SINGBOX_MODE=no ;;
        --lang)         shift; LANG_CHOICE="${1:-}" ;;
        --lang=*)       LANG_CHOICE="${1#--lang=}" ;;
        -h|--help)      sed -n '2,11p' "$0"; exit 0 ;;
        *)              echo "${R}✗ unknown option: $1${N}" >&2; exit 1 ;;
    esac
    shift
done

# ---- language ----
case "$LANG_CHOICE" in
    en|fa) ;;
    "")
        LANG_CHOICE=en
        if [ -r /dev/tty ]; then
            printf "Language / زبان:  1) English   2) فارسی   [1]: " > /dev/tty
            read -r a < /dev/tty
            [ "$a" = "2" ] && LANG_CHOICE=fa
        fi ;;
    *) echo "${R}✗ --lang must be en or fa${N}" >&2; exit 1 ;;
esac
t() { if [ "$LANG_CHOICE" = fa ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

die()  { echo "${R}✗ $*${N}" >&2; exit 1; }
ok()   { echo "${G}    ✓ $*${N}"; }
step() { echo; echo "${Y}[$1/5]${N} ${C}$2${N}"; }

echo "${C}══════ Kali VPN Manager — $(t "نصب‌کننده" "Installer") ══════${N}"

[ "$(id -u)" -eq 0 ] && die "$(t "این اسکریپت را با کاربر معمولی اجرا کن، نه root." "Run this as a normal user, not root.")"
[ -f /etc/debian_version ] || die "$(t "فقط برای Debian / Ubuntu / Kali." "Debian / Ubuntu / Kali only.")"
command -v sudo >/dev/null 2>&1 || die "$(t "sudo نصب نیست." "sudo is not installed.")"

ask_yes() {  # ask_yes "question" → 0 if y
    [ -r /dev/tty ] || return 1
    local a
    printf "%s (y/N): " "$1" > /dev/tty
    read -r a < /dev/tty
    [ "$a" = "y" ] || [ "$a" = "Y" ]
}

# ---------------------------------------------------------------- 1
step 1 "$(t "پیش‌نیازها" "Prerequisites")"
MISSING=()
command -v curl >/dev/null 2>&1         || MISSING+=(curl)
command -v proxychains4 >/dev/null 2>&1 || MISSING+=(proxychains4)
command -v ip >/dev/null 2>&1           || MISSING+=(iproute2)
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "    → $(t "نصب" "installing"): ${MISSING[*]}"
    sudo apt-get update -qq && sudo apt-get install -y "${MISSING[@]}" || die "$(t "نصب پیش‌نیازها ناموفق بود." "Installing prerequisites failed.")"
else
    ok "$(t "همه نصب هستند" "all present")"
fi

# ---------------------------------------------------------------- 2
step 2 "$(t "ساخت پوشه‌ها" "Creating directories")"
mkdir -p "$INSTALL_DIR/bin" "$CONF_DIR" || die "$(t "ساخت پوشه ناموفق بود." "mkdir failed.")"
ok "$INSTALL_DIR"

# ---------------------------------------------------------------- 3
step 3 "$(t "نصب vpn.sh" "Installing vpn.sh")"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/vpn.sh" ]; then
    cp "$SELF_DIR/vpn.sh" "$INSTALL_DIR/vpn.sh" || die "$(t "کپی ناموفق بود." "copy failed.")"
    ok "$(t "از پوشه محلی کپی شد" "copied from local checkout")"
else
    curl -fsSL "$RAW/vpn.sh" -o "$INSTALL_DIR/vpn.sh.tmp" || die "$(t "دانلود vpn.sh ناموفق بود" "downloading vpn.sh failed") ($RAW/vpn.sh)"
    mv "$INSTALL_DIR/vpn.sh.tmp" "$INSTALL_DIR/vpn.sh"
    ok "$(t "از GitHub دانلود شد" "downloaded from GitHub") ($REF)"
fi
bash -n "$INSTALL_DIR/vpn.sh" || die "$(t "vpn.sh خطای سینتکس دارد." "vpn.sh has a syntax error.")"
chmod 644 "$INSTALL_DIR/vpn.sh"

if [ ! -f "$CONF_FILE" ]; then
    cat > "$CONF_FILE" <<CONF
# Kali VPN Manager config — uncomment and edit / خط‌ها را از حالت کامنت دربیاور و تغییر بده
VPN_LANG="$LANG_CHOICE"
#VPN_PORT=10808        # proxy port on Windows (v2rayN: mixed=10808 / http=10809)
#VPN_PROTO="http"      # http | socks5
#VPN_HOST=""           # empty = auto (x.x.x.1); set it for non-VMware-NAT networks
#NET_IFACE=""          # empty = auto
#VPN_DNS_SERVER="1.1.1.1"
CONF
    ok "$(t "فایل تنظیمات" "config file"): $CONF_FILE"
else
    sed -i '/^#\?VPN_LANG=/d' "$CONF_FILE"
    echo "VPN_LANG=\"$LANG_CHOICE\"" >> "$CONF_FILE"
    ok "$(t "فایل تنظیمات قبلی حفظ شد (زبان به‌روز شد)" "existing config kept (language updated)")"
fi

# sing-box
if [ ! -x "$INSTALL_DIR/bin/sing-box" ] && ! command -v sing-box >/dev/null 2>&1; then
    want=no
    case "$SINGBOX_MODE" in
        yes) want=yes ;;
        ask) ask_yes "    $(t "sing-box (برای TUN Mode) نصب شود؟" "Install sing-box (needed for TUN mode)?")" && want=yes ;;
    esac
    if [ "$want" = yes ]; then
        case "$(uname -m)" in
            x86_64|amd64)  arch=amd64; sha="$SINGBOX_SHA256_amd64" ;;
            aarch64|arm64) arch=arm64; sha="$SINGBOX_SHA256_arm64" ;;
            *) arch=""; echo "${R}    ✗ $(t "معماری پشتیبانی نمی‌شود" "unsupported architecture"): $(uname -m)${N}" ;;
        esac
        if [ -n "$arch" ]; then
            tgz="sing-box-$SINGBOX_VERSION-linux-$arch.tar.gz"
            tmp="$(mktemp -d)"
            echo "    → $(t "دانلود" "downloading") $tgz ..."
            if curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/$tgz" -o "$tmp/$tgz" \
               && echo "$sha  $tmp/$tgz" | sha256sum -c --quiet - \
               && tar -xzf "$tmp/$tgz" -C "$tmp" \
               && install -m 755 "$tmp/sing-box-$SINGBOX_VERSION-linux-$arch/sing-box" "$INSTALL_DIR/bin/sing-box"; then
                ok "sing-box $SINGBOX_VERSION $(t "نصب شد (checksum تایید شد)" "installed (checksum verified)")"
            else
                echo "${R}    ✗ $(t "نصب sing-box ناموفق بود؛ TUN Mode کار نمی‌کند ولی بقیه چیزها کار می‌کنند." "sing-box install failed; TUN mode won't work, everything else will.")${N}"
            fi
            rm -rf "$tmp"
        fi
    else
        echo "    - $(t "sing-box رد شد (بعداً: install.sh --with-singbox)" "sing-box skipped (later: install.sh --with-singbox)")"
    fi
else
    ok "$(t "sing-box موجود است" "sing-box present")"
fi

# ---------------------------------------------------------------- 4
step 4 "$(t "اضافه کردن به شل" "Hooking into your shell")"
add_rc() {
    local rc=$1
    [ -f "$rc" ] || return 0
    if grep -qF "$MARK_BEGIN" "$rc" || grep -q "vpn-manager/vpn.sh" "$rc"; then
        ok "$(basename "$rc"): $(t "از قبل موجود" "already set up")"
        return 0
    fi
    cp "$rc" "$rc.vpn-manager.bak"
    {
        echo
        echo "$MARK_BEGIN"
        echo '[ -f "$HOME/.local/share/vpn-manager/vpn.sh" ] && . "$HOME/.local/share/vpn-manager/vpn.sh"'
        echo "$MARK_END"
    } >> "$rc"
    ok "$(basename "$rc"): $(t "اضافه شد (بکاپ" "added (backup"): $(basename "$rc").vpn-manager.bak)"
}
[ -f "$HOME/.zshrc" ] || [ -f "$HOME/.bashrc" ] || touch "$HOME/.bashrc"
add_rc "$HOME/.zshrc"
add_rc "$HOME/.bashrc"

# ---------------------------------------------------------------- 5
step 5 "$(t "تست" "Self-test")"
[ -f "$INSTALL_DIR/vpn.sh" ] && ok "vpn.sh" || die "$(t "vpn.sh پیدا نشد" "vpn.sh missing")"
command -v proxychains4 >/dev/null 2>&1 && ok "proxychains4"
if bash -c ". '$INSTALL_DIR/vpn.sh' && type vpn >/dev/null"; then ok "$(t "تابع vpn لود می‌شود" "vpn function loads")"; else die "$(t "لود vpn.sh ناموفق" "loading vpn.sh failed")"; fi

echo
echo "${G}══════ $(t "نصب با موفقیت انجام شد" "Installed successfully") ══════${N}"
echo "  $(t "ترمینال جدید باز کن (یا" "Open a new terminal (or run"):  ${Y}source ~/.zshrc${N}  /  ${Y}source ~/.bashrc${N})"
echo "  $(t "سپس" "then"):  ${G}vpn${N}"
echo "  $(t "قبلش در ویندوز VPN را روشن و Allow LAN را فعال کن." "First, on Windows: turn the VPN on and enable Allow LAN.")"
echo "  $(t "تنظیمات (پورت/پروتکل/زبان)" "Settings (port/protocol/language)"):  ${Y}$CONF_FILE${N}   ($(t "تغییر زبان" "change language"): ${Y}vpn lang${N})"
