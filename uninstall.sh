#!/usr/bin/env bash
# =====================================================================
#  Kali VPN Manager — Uninstaller
#  bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/uninstall.sh)
#  Options: -y (no prompt)
# =====================================================================
set -u

INSTALL_DIR="${VPN_HOME:-$HOME/.local/share/vpn-manager}"
CONF_DIR="$HOME/.config/vpn-manager"
MARK_BEGIN="# >>> kali-vpn-manager >>>"
MARK_END="# <<< kali-vpn-manager <<<"

G=$'\033[0;32m'; Y=$'\033[1;33m'; N=$'\033[0m'

# language = the one chosen at install time
VPN_LANG=en
# shellcheck disable=SC1091
[ -f "$CONF_DIR/config" ] && . "$CONF_DIR/config"
t() { if [ "$VPN_LANG" = fa ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

if [ "${1:-}" != "-y" ] && [ -r /dev/tty ]; then
    printf "%s (y/N): " "$(t "Kali VPN Manager حذف شود؟" "Remove Kali VPN Manager?")" > /dev/tty
    read -r a < /dev/tty
    [ "$a" = "y" ] || [ "$a" = "Y" ] || { echo "$(t "لغو شد." "Cancelled.")"; exit 0; }
fi

# turn TUN mode off if it is running
if pgrep -f "run -c $INSTALL_DIR/singbox.json" >/dev/null 2>&1; then
    sudo pkill -f "run -c $INSTALL_DIR/singbox.json"
    echo "${G}✓ $(t "TUN Mode خاموش شد" "TUN mode stopped")${N}"
fi

rm -rf "$INSTALL_DIR" "$CONF_DIR"

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] || continue
    sed -i "\|$MARK_BEGIN|,\|$MARK_END|d" "$rc"                       # new marker block
    sed -i '\|vpn-manager/vpn.sh|d; \|^# Kali VPN Manager$|d' "$rc"   # legacy installer lines
done

echo "${G}✓ $(t "حذف انجام شد." "Uninstalled.")${N}"
echo "${Y}$(t "ترمینال را ببند و دوباره باز کن. (فایل‌های *.vpn-manager.bak در home باقی می‌مانند)" "Close and reopen your terminal. (*.vpn-manager.bak backups in your home folder are kept)")${N}"
