# shellcheck shell=bash
# =====================================================================
#  Kali VPN Manager — VMware NAT + Windows host proxy
#  This file is sourced (not executed). Works in bash and zsh.
#  این فایل source می‌شود (اجرا نمی‌شود). سازگار با bash و zsh.
# =====================================================================

VPN_HOME="${VPN_HOME:-$HOME/.local/share/vpn-manager}"
VPN_CONF="${VPN_CONF:-$HOME/.config/vpn-manager/config}"

# ---------- defaults (override in the config file above) ----------
VPN_LANG="en"              # en | fa
VPN_PORT=10808             # proxy port on Windows
VPN_PROTO="http"           # http | socks5
VPN_HOST=""                # empty = auto (x.x.x.1 on VMware NAT)
NET_IFACE=""               # empty = auto (from default route)
VPN_CHECK_TIMEOUT=5
VPN_IP_URL="https://api.ipify.org"
VPN_DNS_SERVER="1.1.1.1"   # DNS asked over TCP through the proxy in TUN mode
# -----------------------------------------------------------------
# shellcheck disable=SC1090
[ -f "$VPN_CONF" ] && . "$VPN_CONF"

_R=$'\033[0;31m'; _G=$'\033[0;32m'; _Y=$'\033[1;33m'
_B=$'\033[0;34m'; _C=$'\033[0;36m'; _N=$'\033[0m'

# _t "فارسی" "English"  → prints the string for the selected language
_t() { if [ "$VPN_LANG" = "fa" ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

_VPN_SB_CONF="$VPN_HOME/singbox.json"
_VPN_SB_LOG="$VPN_HOME/singbox.log"
_VPN_PC_CONF="$VPN_HOME/proxychains.conf"

# ---------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------
_vpn_gateway() {
    ip route 2>/dev/null | awk '/^default/ {print $3; exit}'
}

_vpn_iface() {
    if [ -n "$NET_IFACE" ]; then echo "$NET_IFACE"; return; fi
    ip route 2>/dev/null | awk '/^default/ {print $5; exit}'
}

# Windows host address. On VMware NAT: gateway is x.x.x.2, host is x.x.x.1.
_vpn_host() {
    local gw
    if [ -n "$VPN_HOST" ]; then echo "$VPN_HOST"; return 0; fi
    gw=$(_vpn_gateway)
    [ -z "$gw" ] && return 1
    echo "$gw" | awk -F. '{printf "%s.%s.%s.1\n", $1, $2, $3}'
}

_vpn_url() {
    case "$VPN_PROTO" in
        socks5|socks) echo "socks5h://$1:$VPN_PORT" ;;
        *)            echo "http://$1:$VPN_PORT" ;;
    esac
}

_vpn_port_open() {
    timeout 2 bash -c "echo > /dev/tcp/$1/$VPN_PORT" 2>/dev/null
}

_vpn_public_ip() {
    curl -s --max-time "$VPN_CHECK_TIMEOUT" "$VPN_IP_URL" 2>/dev/null
}

_vpn_singbox_bin() {
    if [ -x "$VPN_HOME/bin/sing-box" ]; then
        echo "$VPN_HOME/bin/sing-box"
    elif command -v sing-box >/dev/null 2>&1; then
        command -v sing-box
    else
        return 1
    fi
}

_vpn_tun_running() {
    pgrep -f "run -c $_VPN_SB_CONF" >/dev/null 2>&1
}

_vpn_unknown() { _t "نامشخص" "unknown"; }

# ---------------------------------------------------------------
#  Main entry
# ---------------------------------------------------------------
vpn() {
    local cmd="$1"

    # commands that do not need a network
    case "$cmd" in
        lang)           shift; _vpn_lang "$@"; return ;;
        help|-h|--help) _vpn_help; return ;;
    esac

    local host
    host=$(_vpn_host)
    if [ -z "$host" ]; then
        echo "${_R}✗ $(_t "گیت‌وی پیدا نشد! (شبکه وصل است؟ یا VPN_HOST را در $VPN_CONF بگذار)" "Gateway not found! (is the network up? or set VPN_HOST in $VPN_CONF)")${_N}"
        return 1
    fi

    [ $# -gt 0 ] && shift
    case "$cmd" in
        on|1)          _vpn_on "$host"; return ;;
        off|2)         _vpn_off; return ;;
        clr|clear|3)   _vpn_clear; return ;;
        st|status|4)   _vpn_status "$host"; return ;;
        rn|renew|5)    vpn_renew; return ;;
        app|6)         _vpn_app "$host" "$@"; return ;;
        tun|8)         _vpn_tun_on "$host"; return ;;
        untun|9)       _vpn_tun_off; return ;;
        info)          vpn_info; return ;;
        "")            ;;
        *)             echo "${_R}⚠ $(_t "دستور نامعتبر" "Unknown command"): $cmd${_N}"; _vpn_help; return 1 ;;
    esac

    echo "${_C}╔══════════════════════════════════════════════╗${_N}"
    echo "${_C}║${_N}     ${_Y}$(_t "مدیریت پروکسی VPN (Kali ↔ Windows)" "VPN Proxy Manager (Kali ↔ Windows)")${_N}"
    echo "${_C}╠══════════════════════════════════════════════╣${_N}"
    echo "${_C}║${_N}  $(_t "پروکسی" "Proxy"): ${_G}$VPN_PROTO://$host:$VPN_PORT${_N}"
    echo "${_C}╠══════════════════════════════════════════════╣${_N}"
    echo "${_C}║${_N}  ${_G}1)${_N} $(_t "روشن پروکسی شل" "Shell proxy ON")"
    echo "${_C}║${_N}  ${_R}2)${_N} $(_t "خاموش پروکسی شل" "Shell proxy OFF")"
    echo "${_C}║${_N}  ${_Y}3)${_N} $(_t "پاک کردن همه تنظیمات" "Clear all proxy settings")"
    echo "${_C}║${_N}  ${_B}4)${_N} $(_t "نمایش وضعیت" "Show status")"
    echo "${_C}║${_N}  ${_C}5)${_N} $(_t "دریافت IP جدید (DHCP)" "Renew IP (DHCP)")"
    echo "${_C}╠══════════════════════════════════════════════╣${_N}"
    echo "${_C}║${_N}  ${_Y}6)${_N} $(_t "اجرای یک برنامه CLI از طریق VPN" "Run a CLI program through the VPN")"
    echo "${_C}╠══════════════════════════════════════════════╣${_N}"
    echo "${_C}║${_N}  ${_G}8)${_N} $(_t "روشن TUN Mode (کل کالی از VPN)" "TUN Mode ON (whole system via VPN)")"
    echo "${_C}║${_N}  ${_R}9)${_N} $(_t "خاموش TUN Mode" "TUN Mode OFF")"
    echo "${_C}║${_N}  ${_C}7)${_N} $(_t "زبان / Language" "Language / زبان")"
    echo "${_C}║${_N}  ${_C}0)${_N} $(_t "خروج" "Exit")"
    echo "${_C}╚══════════════════════════════════════════════╝${_N}"

    local choice
    printf " %s [0-9]: " "$(_t "انتخاب" "Choice")"
    read -r choice
    echo

    case "$choice" in
        1) _vpn_on "$host" ;;
        2) _vpn_off ;;
        3) _vpn_clear ;;
        4) _vpn_status "$host" ;;
        5) vpn_renew ;;
        6) _vpn_app "$host" ;;
        7) _vpn_lang ;;
        8) _vpn_tun_on "$host" ;;
        9) _vpn_tun_off ;;
        0) echo "$(_t "خروج." "Bye.")" ;;
        *) echo "${_R}⚠ $(_t "گزینه نامعتبر!" "Invalid option!")${_N}" ;;
    esac
}

_vpn_help() {
    if [ "$VPN_LANG" = "fa" ]; then
        cat <<EOF
استفاده: vpn [دستور]

  vpn               منوی تعاملی
  vpn on            روشن پروکسی شل (http_proxy و ...)
  vpn off           خاموش پروکسی شل
  vpn clear         پاک کردن تنظیمات پروکسی
  vpn st            وضعیت
  vpn renew         دریافت IP جدید
  vpn app CMD ...   اجرای CMD از طریق proxychains (مثلاً: vpn app nmap -sT -Pn x.com)
  vpn tun           روشن TUN Mode
  vpn untun         خاموش TUN Mode
  vpn info          اطلاعات شبکه
  vpn lang [fa|en]  تغییر زبان
تنظیمات: $VPN_CONF
EOF
    else
        cat <<EOF
Usage: vpn [command]

  vpn               interactive menu
  vpn on            shell proxy ON (http_proxy, ...)
  vpn off           shell proxy OFF
  vpn clear         clear proxy settings
  vpn st            status
  vpn renew         get a new IP (DHCP)
  vpn app CMD ...   run CMD through proxychains (e.g. vpn app nmap -sT -Pn x.com)
  vpn tun           TUN Mode ON
  vpn untun         TUN Mode OFF
  vpn info          network info
  vpn lang [fa|en]  change language
Config: $VPN_CONF
EOF
    fi
}

# vpn lang [fa|en] — switches language now and saves it to the config file
_vpn_lang() {
    local l="${1:-}"
    if [ -z "$l" ]; then
        echo "  1) English"
        echo "  2) فارسی"
        printf " [1-2]: "
        read -r l
        case "$l" in 1) l=en ;; 2) l=fa ;; esac
    fi
    case "$l" in
        en|fa) ;;
        *) echo "${_R}⚠ usage: vpn lang [fa|en]${_N}"; return 1 ;;
    esac
    VPN_LANG="$l"
    mkdir -p "$(dirname "$VPN_CONF")"
    touch "$VPN_CONF"
    sed -i '/^#\?VPN_LANG=/d' "$VPN_CONF"
    echo "VPN_LANG=\"$l\"" >> "$VPN_CONF"
    echo "${_G}✓ $(_t "زبان: فارسی" "Language: English")${_N}"
}

# ---------------------------------------------------------------
#  Shell proxy
# ---------------------------------------------------------------
_vpn_on() {
    local url
    url=$(_vpn_url "$1")
    export http_proxy="$url" https_proxy="$url" ftp_proxy="$url" all_proxy="$url"
    export HTTP_PROXY="$url" HTTPS_PROXY="$url" FTP_PROXY="$url" ALL_PROXY="$url"
    export no_proxy="localhost,127.0.0.1,::1,$1" NO_PROXY="localhost,127.0.0.1,::1,$1"
    echo "${_G}✓ $(_t "پروکسی شل روشن شد" "Shell proxy ON") → ${_N}$url"
    if ! _vpn_port_open "$1"; then
        echo "${_Y}⚠ $(_t "پورت $VPN_PORT روی $1 باز نیست؛ VPN ویندوز روشن است و Allow LAN فعال؟" "Port $VPN_PORT on $1 is closed; is the Windows VPN running with Allow LAN enabled?")${_N}"
    fi
    echo "${_Y}ℹ $(_t "برای apt از  sudo -E apt ...  استفاده کن (sudo متغیرها را پاک می‌کند)." "For apt use  sudo -E apt ...  (plain sudo drops the variables).")${_N}"
}

_vpn_off() {
    unset http_proxy https_proxy ftp_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY no_proxy NO_PROXY
    echo "${_R}✗ $(_t "پروکسی شل خاموش شد." "Shell proxy OFF.")${_N}"
}

_vpn_clear() {
    _vpn_off >/dev/null
    gsettings reset org.gnome.system.proxy mode 2>/dev/null
    echo "${_Y}🧹 $(_t "تنظیمات پروکسی این شل پاک شد." "Proxy settings of this shell cleared.")${_N}"
}

# ---------------------------------------------------------------
#  Run a CLI program through proxychains
# ---------------------------------------------------------------
_vpn_app() {
    local host=$1
    shift
    local line="$*"

    if ! command -v proxychains4 >/dev/null 2>&1; then
        echo "${_R}✗ $(_t "proxychains4 نصب نیست!" "proxychains4 is not installed!") → sudo apt install proxychains4${_N}"
        return 1
    fi

    if [ -z "$line" ]; then
        echo "${_C}─── $(_t "اجرای برنامه از طریق VPN" "Run a program through the VPN") ───${_N}"
        echo "${_Y}$(_t "مثال" "Example"): nmap -sT -Pn example.com   |   curl ifconfig.me   |   sqlmap -u ...${_N}"
        printf " %s: " "$(_t "دستور" "Command")"
        read -r line
    fi
    if [ -z "$line" ]; then
        echo "${_R}✗ $(_t "دستوری وارد نشد." "No command given.")${_N}"
        return 1
    fi

    case "${line%% *}" in
        firefox*|chromium*|chrome*|burpsuite|wireshark)
            echo "${_R}⚠ $(_t "این برنامه GUI است و proxychains رویش مطمئن کار نمی‌کند." "This is a GUI program; proxychains will not work reliably.")${_N}"
            echo "${_Y}$(_t "راه‌حل: FoxyProxy یا TUN Mode (vpn tun)" "Use FoxyProxy or TUN Mode (vpn tun) instead.")${_N}"
            return 1
            ;;
    esac

    local ptype=http
    case "$VPN_PROTO" in socks5|socks) ptype=socks5 ;; esac

    mkdir -p "$VPN_HOME"
    cat > "$_VPN_PC_CONF" <<EOF
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
$ptype $host $VPN_PORT
EOF

    echo "${_G}✓ $(_t "اجرا از طریق" "Running via") $ptype://$host:$VPN_PORT${_N}"
    echo "${_Y}ℹ $(_t "proxychains فقط TCP را رد می‌کند: برای nmap از -sT -Pn استفاده کن." "proxychains only carries TCP: use -sT -Pn with nmap.")${_N}"
    proxychains4 -q -f "$_VPN_PC_CONF" bash -c "$line"
}

# ---------------------------------------------------------------
#  TUN Mode (sing-box)
# ---------------------------------------------------------------
# prints a sing-box (1.12+) config on stdout
_vpn_gen_singbox_config() {
    local host=$1 otype=http
    case "$VPN_PROTO" in socks5|socks) otype=socks ;; esac
    cat <<EOF
{
  "log": {"level": "warn", "output": "$_VPN_SB_LOG"},
  "dns": {
    "servers": [
      {"type": "tcp", "tag": "remote", "server": "$VPN_DNS_SERVER", "detour": "proxy"}
    ],
    "final": "remote"
  },
  "inbounds": [{
    "type": "tun",
    "tag": "tun-in",
    "interface_name": "tun0",
    "address": ["172.19.0.1/30"],
    "mtu": 1500,
    "auto_route": true,
    "strict_route": true,
    "stack": "system"
  }],
  "outbounds": [
    {"type": "$otype", "tag": "proxy", "server": "$host", "server_port": $VPN_PORT},
    {"type": "direct", "tag": "direct"}
  ],
  "route": {
    "rules": [
      {"action": "sniff"},
      {"protocol": "dns", "action": "hijack-dns"},
      {"ip_is_private": true, "action": "route", "outbound": "direct"}
    ],
    "final": "proxy",
    "auto_detect_interface": true
  }
}
EOF
}

_vpn_tun_on() {
    local host=$1 bin
    if ! bin=$(_vpn_singbox_bin); then
        echo "${_R}✗ $(_t "sing-box نصب نیست! نصب‌کننده را با --with-singbox دوباره اجرا کن." "sing-box is not installed! Re-run the installer with --with-singbox.")${_N}"
        return 1
    fi
    if _vpn_tun_running; then
        echo "${_Y}⚠ $(_t "TUN Mode از قبل روشن است (اول  vpn untun)." "TUN Mode is already on (run  vpn untun  first).")${_N}"
        return 0
    fi
    if ! _vpn_port_open "$host"; then
        echo "${_R}✗ $(_t "پورت $VPN_PORT روی $host باز نیست؛ اگر TUN روشن شود اینترنت قطع می‌شود." "Port $VPN_PORT on $host is closed; enabling TUN would cut your internet.")${_N}"
        echo "  $(_t "VPN ویندوز روشن و Allow LAN فعال باشد. (vpn st)" "Make sure the Windows VPN is on and Allow LAN is enabled. (vpn st)")"
        return 1
    fi

    echo "${_Y}🛠  $(_t "ساخت کانفیگ TUN..." "Building TUN config...")${_N}"
    mkdir -p "$VPN_HOME"
    _vpn_gen_singbox_config "$host" > "$_VPN_SB_CONF"

    if ! "$bin" check -c "$_VPN_SB_CONF"; then
        echo "${_R}✗ $(_t "کانفیگ sing-box نامعتبر است." "Invalid sing-box config.")${_N}"
        return 1
    fi

    sudo -v || return 1
    sudo sh -c "nohup '$bin' run -c '$_VPN_SB_CONF' >>'$_VPN_SB_LOG' 2>&1 &"

    local i
    # shellcheck disable=SC2034
    for i in 1 2 3 4 5 6; do
        sleep 1
        ip link show tun0 >/dev/null 2>&1 && break
    done

    if ip link show tun0 >/dev/null 2>&1; then
        echo "${_G}✓ $(_t "TUN Mode روشن شد؛ کل ترافیک از $host:$VPN_PORT رد می‌شود." "TUN Mode ON; all traffic goes through $host:$VPN_PORT.")${_N}"
        local ip
        ip=$(_vpn_public_ip)
        echo "${_G}$(_t "IP فعلی" "Current IP"): ${_N}${ip:-$(_vpn_unknown)}"
    else
        echo "${_R}✗ $(_t "TUN Mode بالا نیامد!" "TUN Mode failed to start!")${_N}  $(_t "لاگ" "Log"): sudo tail $_VPN_SB_LOG"
        sudo pkill -f "run -c $_VPN_SB_CONF" 2>/dev/null
        return 1
    fi
}

_vpn_tun_off() {
    echo "${_Y}🛠  $(_t "خاموش کردن TUN Mode..." "Turning TUN Mode off...")${_N}"
    if _vpn_tun_running; then
        sudo pkill -f "run -c $_VPN_SB_CONF" 2>/dev/null
        sleep 1
    fi
    _vpn_off >/dev/null
    echo "${_G}✓ $(_t "TUN Mode و پروکسی شل خاموش شدند." "TUN Mode and shell proxy are off.")${_N}"
    local ip
    ip=$(_vpn_public_ip)
    echo "${_G}$(_t "IP فعلی" "Current IP"): ${_N}${ip:-$(_vpn_unknown)}"
}

# ---------------------------------------------------------------
#  Status and tools
# ---------------------------------------------------------------
_vpn_status() {
    local host=$1 iface ip
    iface=$(_vpn_iface)
    echo "${_C}─── $(_t "وضعیت شبکه" "Network status") ──────────────────────────${_N}"
    echo "  $(_t "IP کالی" "Kali IP"):        $(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}') ($iface)"
    echo "  $(_t "آدرس پروکسی" "Proxy"):      ${_G}$VPN_PROTO://$host:$VPN_PORT${_N}"

    printf "  %s:     " "$(_t "پورت پروکسی" "Proxy port")"
    if _vpn_port_open "$host"; then
        echo "${_G}$(_t "باز" "open")${_N}"
    else
        echo "${_R}$(_t "بسته" "closed")${_N}"
    fi

    echo "  http_proxy:      ${_Y}${http_proxy:-$(_t "تنظیم نشده" "not set")}${_N}"

    printf "  TUN Mode:        "
    if _vpn_tun_running; then echo "${_G}$(_t "فعال" "active")${_N}"; else echo "${_R}$(_t "غیرفعال" "inactive")${_N}"; fi

    printf "  %s:        " "$(_t "IP عمومی" "Public IP")"
    ip=$(_vpn_public_ip)
    if [ -n "$ip" ]; then echo "${_G}$ip${_N}"; else echo "${_R}$(_vpn_unknown)${_N}"; fi
    echo "${_C}─────────────────────────────────────────────${_N}"
}

vpn_renew() {
    local iface
    iface=$(_vpn_iface)
    if [ -z "$iface" ]; then
        echo "${_R}✗ $(_t "کارت شبکه پیدا نشد." "Network interface not found.")${_N}"
        return 1
    fi
    echo "${_Y}🔄 $(_t "دریافت IP جدید روی" "Renewing IP on") $iface ...${_N}"
    if command -v nmcli >/dev/null 2>&1 && nmcli -t -f RUNNING general 2>/dev/null | grep -q running; then
        sudo nmcli device disconnect "$iface" >/dev/null 2>&1
        sudo nmcli device connect "$iface" >/dev/null 2>&1
    elif command -v dhclient >/dev/null 2>&1; then
        sudo dhclient -r "$iface" 2>/dev/null
        sudo dhclient "$iface" 2>/dev/null
    else
        echo "${_R}✗ $(_t "نه NetworkManager هست نه dhclient." "Neither NetworkManager nor dhclient is available.")${_N}"
        return 1
    fi
    sleep 2
    ip -4 addr show "$iface" | awk '/inet /{print "  IP: " $2}'
    echo "  $(_t "گیت‌وی" "Gateway"): $(_vpn_gateway)"
}

vpn_info() {
    local iface
    iface=$(_vpn_iface)
    echo "${_C}═══ $(_t "اطلاعات شبکه" "Network info") ═══${_N}"
    echo "  Interface : $iface"
    echo "  IP        : $(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}')"
    echo "  Gateway   : ${_G}$(_vpn_gateway)${_N}"
    echo "  ProxyHost : ${_G}$(_vpn_host)${_N}"
    printf "  TUN       : "
    if _vpn_tun_running; then echo "${_G}$(_t "فعال" "active")${_N}"; else echo "${_R}$(_t "غیرفعال" "inactive")${_N}"; fi
    echo "${_C}════════════════════${_N}"
}

# backward-compatible aliases
renew()   { vpn_renew; }
netinfo() { vpn_info; }
