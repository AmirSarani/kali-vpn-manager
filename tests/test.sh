#!/usr/bin/env bash
# تست‌های ساده: لود شدن در bash، تولید کانفیگ sing-box معتبر، و (اگر موجود بود) sing-box check
set -u
cd "$(dirname "$0")/.." || exit 1
fail=0
t() { if "$@"; then echo "ok   - $*"; else echo "FAIL - $*"; fail=1; fi; }

VPN_HOME="$(mktemp -d)"
VPN_CONF="$VPN_HOME/config"
export VPN_HOME VPN_CONF
# shellcheck disable=SC1091
. ./vpn.sh

_vpn_help_quiet() { _vpn_help >/dev/null; }
t type vpn
t type vpn_renew
t _vpn_help_quiet

check_json() {
    local proto=$1 f
    f="$VPN_HOME/$proto.json"
    VPN_PROTO=$proto _vpn_gen_singbox_config 192.168.100.1 > "$f" || return 1
    if command -v jq >/dev/null; then jq . "$f" >/dev/null
    else { python3 -m json.tool "$f" || python -m json.tool "$f"; } >/dev/null 2>&1; fi || return 1
    if command -v sing-box >/dev/null; then sing-box check -c "$f"; fi
}
t check_json http
t check_json socks5

t test "$(VPN_PROTO=http _vpn_url 1.2.3.4)" = "http://1.2.3.4:10808"
t test "$(VPN_PROTO=socks5 _vpn_url 1.2.3.4)" = "socks5h://1.2.3.4:10808"
t test "$(VPN_HOST=9.9.9.9 _vpn_host)" = "9.9.9.9"

_vpn_on 192.168.100.1 >/dev/null
t test "$http_proxy" = "http://192.168.100.1:10808"
_vpn_off >/dev/null
t test -z "${http_proxy:-}"

t test "$(_t fa en)" = "en"
_vpn_lang fa >/dev/null
t test "$(_t fa en)" = "fa"
t grep -q '^VPN_LANG="fa"' "$VPN_CONF"
VPN_LANG=en

rm -rf "$VPN_HOME"
exit $fail
