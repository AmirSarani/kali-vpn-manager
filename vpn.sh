# shellcheck shell=bash
# =====================================================================
#  Kali VPN Manager — VMware NAT + Windows host proxy
#  این فایل source می‌شود (اجرا نمی‌شود). سازگار با bash و zsh.
# =====================================================================

VPN_HOME="${VPN_HOME:-$HOME/.local/share/vpn-manager}"
VPN_CONF="${VPN_CONF:-$HOME/.config/vpn-manager/config}"

# ---------- پیش‌فرض‌ها (با فایل config بالا قابل تغییر) ----------
VPN_PORT=10808             # پورت پروکسی روی ویندوز
VPN_PROTO="http"           # http | socks5
VPN_HOST=""                # خالی = خودکار (x.x.x.1 در VMware NAT)
NET_IFACE=""               # خالی = خودکار (از default route)
VPN_CHECK_TIMEOUT=5
VPN_IP_URL="https://api.ipify.org"
VPN_DNS_SERVER="1.1.1.1"   # DNS که در TUN Mode از طریق پروکسی (TCP) پرسیده می‌شود
# -----------------------------------------------------------------
# shellcheck disable=SC1090
[ -f "$VPN_CONF" ] && . "$VPN_CONF"

_R=$'\033[0;31m'; _G=$'\033[0;32m'; _Y=$'\033[1;33m'
_B=$'\033[0;34m'; _C=$'\033[0;36m'; _N=$'\033[0m'

_VPN_SB_CONF="$VPN_HOME/singbox.json"
_VPN_SB_LOG="$VPN_HOME/singbox.log"
_VPN_PC_CONF="$VPN_HOME/proxychains.conf"

# ---------------------------------------------------------------
#  توابع کمکی
# ---------------------------------------------------------------
_vpn_gateway() {
    ip route 2>/dev/null | awk '/^default/ {print $3; exit}'
}

_vpn_iface() {
    if [ -n "$NET_IFACE" ]; then echo "$NET_IFACE"; return; fi
    ip route 2>/dev/null | awk '/^default/ {print $5; exit}'
}

# آدرس پروکسی (ویندوز هاست). در VMware NAT گیت‌وی x.x.x.2 و هاست x.x.x.1 است.
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

# ---------------------------------------------------------------
#  منوی اصلی / دستورات
# ---------------------------------------------------------------
vpn() {
    local host
    host=$(_vpn_host)
    if [ -z "$host" ]; then
        echo "${_R}✗ گیت‌وی پیدا نشد! (شبکه وصل است؟ یا VPN_HOST را در $VPN_CONF بگذار)${_N}"
        return 1
    fi

    local cmd="$1"
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
        help|-h|--help) _vpn_help; return ;;
        "")            ;;
        *)             echo "${_R}⚠ دستور نامعتبر: $cmd${_N}"; _vpn_help; return 1 ;;
    esac

    echo "${_C}╔══════════════════════════════════════════════╗${_N}"
    echo "${_C}║${_N}     ${_Y}مدیریت پروکسی VPN (Kali ↔ Windows)${_N}"
    echo "${_C}╠══════════════════════════════════════════════╣${_N}"
    echo "${_C}║${_N}  پروکسی: ${_G}$VPN_PROTO://$host:$VPN_PORT${_N}"
    echo "${_C}╠══════════════════════════════════════════════╣${_N}"
    echo "${_C}║${_N}  ${_G}1)${_N} روشن پروکسی شل"
    echo "${_C}║${_N}  ${_R}2)${_N} خاموش پروکسی شل"
    echo "${_C}║${_N}  ${_Y}3)${_N} پاک کردن همه تنظیمات"
    echo "${_C}║${_N}  ${_B}4)${_N} نمایش وضعیت"
    echo "${_C}║${_N}  ${_C}5)${_N} دریافت IP جدید (DHCP)"
    echo "${_C}╠══════════════════════════════════════════════╣${_N}"
    echo "${_C}║${_N}  ${_Y}6)${_N} اجرای یک برنامه CLI از طریق VPN"
    echo "${_C}╠══════════════════════════════════════════════╣${_N}"
    echo "${_C}║${_N}  ${_G}8)${_N} روشن TUN Mode (کل کالی از VPN)"
    echo "${_C}║${_N}  ${_R}9)${_N} خاموش TUN Mode"
    echo "${_C}║${_N}  ${_C}0)${_N} خروج"
    echo "${_C}╚══════════════════════════════════════════════╝${_N}"

    local choice
    printf " انتخاب [0-9]: "
    read -r choice
    echo

    case "$choice" in
        1) _vpn_on "$host" ;;
        2) _vpn_off ;;
        3) _vpn_clear ;;
        4) _vpn_status "$host" ;;
        5) vpn_renew ;;
        6) _vpn_app "$host" ;;
        8) _vpn_tun_on "$host" ;;
        9) _vpn_tun_off ;;
        0) echo "خروج." ;;
        *) echo "${_R}⚠ گزینه نامعتبر!${_N}" ;;
    esac
}

_vpn_help() {
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
تنظیمات: $VPN_CONF
EOF
}

# ---------------------------------------------------------------
#  پروکسی شل
# ---------------------------------------------------------------
_vpn_on() {
    local url
    url=$(_vpn_url "$1")
    export http_proxy="$url" https_proxy="$url" ftp_proxy="$url" all_proxy="$url"
    export HTTP_PROXY="$url" HTTPS_PROXY="$url" FTP_PROXY="$url" ALL_PROXY="$url"
    export no_proxy="localhost,127.0.0.1,::1,$1" NO_PROXY="localhost,127.0.0.1,::1,$1"
    echo "${_G}✓ پروکسی شل روشن شد → ${_N}$url"
    if ! _vpn_port_open "$1"; then
        echo "${_Y}⚠ پورت $VPN_PORT روی $1 باز نیست؛ VPN ویندوز روشن است و Allow LAN فعال؟${_N}"
    fi
    echo "${_Y}ℹ برای apt از  sudo -E apt ...  استفاده کن (sudo متغیرها را پاک می‌کند).${_N}"
}

_vpn_off() {
    unset http_proxy https_proxy ftp_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY no_proxy NO_PROXY
    echo "${_R}✗ پروکسی شل خاموش شد.${_N}"
}

_vpn_clear() {
    _vpn_off >/dev/null
    gsettings reset org.gnome.system.proxy mode 2>/dev/null
    echo "${_Y}🧹 تنظیمات پروکسی این شل پاک شد.${_N}"
}

# ---------------------------------------------------------------
#  اجرای یک برنامه CLI از طریق proxychains
# ---------------------------------------------------------------
_vpn_app() {
    local host=$1
    shift
    local line="$*"

    if ! command -v proxychains4 >/dev/null 2>&1; then
        echo "${_R}✗ proxychains4 نصب نیست! → sudo apt install proxychains4${_N}"
        return 1
    fi

    if [ -z "$line" ]; then
        echo "${_C}─── اجرای برنامه از طریق VPN ───${_N}"
        echo "${_Y}مثال: nmap -sT -Pn example.com   |   curl ifconfig.me   |   sqlmap -u ...${_N}"
        printf " دستور: "
        read -r line
    fi
    if [ -z "$line" ]; then
        echo "${_R}✗ دستوری وارد نشد.${_N}"
        return 1
    fi

    case "${line%% *}" in
        firefox*|chromium*|chrome*|burpsuite|wireshark)
            echo "${_R}⚠ این برنامه GUI است و proxychains رویش مطمئن کار نمی‌کند.${_N}"
            echo "${_Y}راه‌حل: FoxyProxy یا TUN Mode (vpn tun)${_N}"
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

    echo "${_G}✓ اجرا از طریق $ptype://$host:$VPN_PORT${_N}"
    echo "${_Y}ℹ proxychains فقط TCP را رد می‌کند: برای nmap از -sT -Pn استفاده کن.${_N}"
    proxychains4 -q -f "$_VPN_PC_CONF" bash -c "$line"
}

# ---------------------------------------------------------------
#  TUN Mode (sing-box)
# ---------------------------------------------------------------
# خروجی: کانفیگ sing-box (۱.۱۲+) روی stdout
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
        echo "${_R}✗ sing-box نصب نیست! نصب‌کننده را با --with-singbox دوباره اجرا کن.${_N}"
        return 1
    fi
    if _vpn_tun_running; then
        echo "${_Y}⚠ TUN Mode از قبل روشن است (اول  vpn untun).${_N}"
        return 0
    fi
    if ! _vpn_port_open "$host"; then
        echo "${_R}✗ پورت $VPN_PORT روی $host باز نیست؛ اگر TUN روشن شود اینترنت قطع می‌شود.${_N}"
        echo "  VPN ویندوز روشن و Allow LAN فعال باشد. (vpn st)"
        return 1
    fi

    echo "${_Y}🛠  ساخت کانفیگ TUN...${_N}"
    mkdir -p "$VPN_HOME"
    _vpn_gen_singbox_config "$host" > "$_VPN_SB_CONF"

    if ! "$bin" check -c "$_VPN_SB_CONF"; then
        echo "${_R}✗ کانفیگ sing-box نامعتبر است.${_N}"
        return 1
    fi

    sudo -v || return 1
    sudo sh -c "nohup '$bin' run -c '$_VPN_SB_CONF' >>'$_VPN_SB_LOG' 2>&1 &"

    local i
    for i in 1 2 3 4 5 6; do
        sleep 1
        ip link show tun0 >/dev/null 2>&1 && break
    done

    if ip link show tun0 >/dev/null 2>&1; then
        echo "${_G}✓ TUN Mode روشن شد؛ کل ترافیک از $host:$VPN_PORT رد می‌شود.${_N}"
        local ip
        ip=$(_vpn_public_ip)
        echo "${_G}IP فعلی: ${_N}${ip:-نامشخص}"
    else
        echo "${_R}✗ TUN Mode بالا نیامد!${_N}  لاگ: sudo tail $_VPN_SB_LOG"
        sudo pkill -f "run -c $_VPN_SB_CONF" 2>/dev/null
        return 1
    fi
}

_vpn_tun_off() {
    echo "${_Y}🛠  خاموش کردن TUN Mode...${_N}"
    if _vpn_tun_running; then
        sudo pkill -f "run -c $_VPN_SB_CONF" 2>/dev/null
        sleep 1
    fi
    _vpn_off >/dev/null
    echo "${_G}✓ TUN Mode و پروکسی شل خاموش شدند.${_N}"
    local ip
    ip=$(_vpn_public_ip)
    echo "${_G}IP فعلی: ${_N}${ip:-نامشخص}"
}

# ---------------------------------------------------------------
#  وضعیت و ابزارها
# ---------------------------------------------------------------
_vpn_status() {
    local host=$1 iface ip
    iface=$(_vpn_iface)
    echo "${_C}─── وضعیت شبکه ──────────────────────────────${_N}"
    echo "  IP کالی:         $(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}') ($iface)"
    echo "  آدرس پروکسی:     ${_G}$VPN_PROTO://$host:$VPN_PORT${_N}"

    printf "  پورت پروکسی:     "
    if _vpn_port_open "$host"; then
        echo "${_G}باز${_N}"
    else
        echo "${_R}بسته${_N}"
    fi

    echo "  http_proxy:      ${_Y}${http_proxy:-تنظیم نشده}${_N}"

    printf "  TUN Mode:        "
    if _vpn_tun_running; then echo "${_G}فعال${_N}"; else echo "${_R}غیرفعال${_N}"; fi

    printf "  IP عمومی:        "
    ip=$(_vpn_public_ip)
    if [ -n "$ip" ]; then echo "${_G}$ip${_N}"; else echo "${_R}نامشخص${_N}"; fi
    echo "${_C}─────────────────────────────────────────────${_N}"
}

vpn_renew() {
    local iface
    iface=$(_vpn_iface)
    if [ -z "$iface" ]; then
        echo "${_R}✗ کارت شبکه پیدا نشد.${_N}"
        return 1
    fi
    echo "${_Y}🔄 دریافت IP جدید روی $iface ...${_N}"
    if command -v nmcli >/dev/null 2>&1 && nmcli -t -f RUNNING general 2>/dev/null | grep -q running; then
        sudo nmcli device disconnect "$iface" >/dev/null 2>&1
        sudo nmcli device connect "$iface" >/dev/null 2>&1
    elif command -v dhclient >/dev/null 2>&1; then
        sudo dhclient -r "$iface" 2>/dev/null
        sudo dhclient "$iface" 2>/dev/null
    else
        echo "${_R}✗ نه NetworkManager هست نه dhclient.${_N}"
        return 1
    fi
    sleep 2
    ip -4 addr show "$iface" | awk '/inet /{print "  IP: " $2}'
    echo "  گیت‌وی: $(_vpn_gateway)"
}

vpn_info() {
    local iface
    iface=$(_vpn_iface)
    echo "${_C}═══ اطلاعات شبکه ═══${_N}"
    echo "  Interface : $iface"
    echo "  IP        : $(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}')"
    echo "  Gateway   : ${_G}$(_vpn_gateway)${_N}"
    echo "  ProxyHost : ${_G}$(_vpn_host)${_N}"
    printf "  TUN       : "
    if _vpn_tun_running; then echo "${_G}فعال${_N}"; else echo "${_R}غیرفعال${_N}"; fi
    echo "${_C}════════════════════${_N}"
}

# سازگاری با نسخهٔ قبلی
renew()   { vpn_renew; }
netinfo() { vpn_info; }
