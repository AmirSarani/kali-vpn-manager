#!/usr/bin/env bash
# =====================================================================
#  Kali VPN Manager — Uninstaller
#  bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/uninstall.sh)
# =====================================================================
set -u

INSTALL_DIR="${VPN_HOME:-$HOME/.local/share/vpn-manager}"
CONF_DIR="$HOME/.config/vpn-manager"
MARK_BEGIN="# >>> kali-vpn-manager >>>"
MARK_END="# <<< kali-vpn-manager <<<"

G=$'\033[0;32m'; Y=$'\033[1;33m'; N=$'\033[0m'

if [ "${1:-}" != "-y" ] && [ -r /dev/tty ]; then
    printf "Kali VPN Manager حذف شود؟ (y/N): " > /dev/tty
    read -r a < /dev/tty
    [ "$a" = "y" ] || [ "$a" = "Y" ] || { echo "لغو شد."; exit 0; }
fi

# TUN Mode را خاموش کن (اگر روشن است)
if pgrep -f "run -c $INSTALL_DIR/singbox.json" >/dev/null 2>&1; then
    sudo pkill -f "run -c $INSTALL_DIR/singbox.json"
    echo "${G}✓ TUN Mode خاموش شد${N}"
fi

rm -rf "$INSTALL_DIR" "$CONF_DIR"

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] || continue
    sed -i "\|$MARK_BEGIN|,\|$MARK_END|d" "$rc"          # بلوک جدید
    sed -i '\|vpn-manager/vpn.sh|d; \|^# Kali VPN Manager$|d' "$rc"   # نسخهٔ قدیمی نصب‌کننده
done

echo "${G}✓ حذف انجام شد.${N}"
echo "${Y}ترمینال را ببند و دوباره باز کن. (فایل‌های *.vpn-manager.bak در home باقی می‌مانند)${N}"
