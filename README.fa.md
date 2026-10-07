# 🌐 Kali VPN Manager

**[English](README.md)** | **فارسی**

[![CI](https://github.com/AmirSarani/kali-vpn-manager/actions/workflows/ci.yml/badge.svg)](https://github.com/AmirSarani/kali-vpn-manager/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Kali%20%7C%20Debian%20%7C%20Ubuntu-red)
![Shell](https://img.shields.io/badge/shell-zsh%20%7C%20bash-green)

وصل کردن **Kali Linux داخل VMware (NAT)** به VPN/فیلترشکنی که روی **ویندوزِ هاست** روشن است — با یک دستور نصب و یک دستور `vpn`.

> English: a tiny shell tool that routes a Kali VM's traffic through the proxy (v2rayN / Clash / …) running on the Windows host — shell proxy, per-app proxychains, or full-system TUN mode via sing-box.

---

## ✨ امکانات

| قابلیت | توضیح |
|---|---|
| 🟢 پروکسی شل | `curl`, `wget`, `git`, `pip`… از طریق `http_proxy` |
| 🎯 اجرای برنامه از VPN | `vpn app nmap -sT -Pn target` (proxychains، بدون دست‌زدن به تنظیمات سیستم) |
| 🌐 TUN Mode | کل کالی (فایرفاکس، همه‌چیز) از VPN رد می‌شود (sing-box) |
| 🔌 HTTP و SOCKS5 | با `VPN_PROTO` |
| 🔍 تشخیص خودکار | آدرس هاست ویندوز از روی گیت‌وی و کارت شبکه از روی default route |
| 🔄 Renew DHCP | با NetworkManager یا dhclient |

---

## 📋 پیش‌نیازها

1. **Kali / Debian / Ubuntu** (معماری amd64 یا arm64)
2. **VMware** با شبکه‌ی **NAT**
3. روی **ویندوز**: برنامه‌ی VPN (v2rayN، Clash، Nekoray…) روشن و گزینه‌ی **Allow LAN / Allow connections from LAN** فعال
4. پورت پروکسی را بدان (پیش‌فرض اسکریپت `10808`)
   - v2rayN: پورت **mixed** (معمولاً `10808`) هم HTTP هم SOCKS را پشتیبانی می‌کند. اگر پورت‌ها جدا بودند: SOCKS=`10808`، HTTP=`10809`.
   - فایروال ویندوز باید اجازه‌ی ورودی روی آن پورت را از شبکه‌ی VMnet8 بدهد.

---

## 📥 نصب (یک دستور)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/install.sh)
```

نصب‌کننده زبان را می‌پرسد (فارسی/English). برای انتخاب مستقیم `--lang fa` یا `--lang en` بده؛ بعداً هم با `vpn lang` عوض می‌شود.

نصب همراه با sing-box (برای TUN Mode) بدون سؤال:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/install.sh) --lang fa --with-singbox
```

> اگر کالی اینترنت ندارد (چون هنوز VPN وصل نیست)، ابتدا فایل را روی ویندوز دانلود و با پوشه‌ی اشتراکی/`scp` به کالی ببر، یا با کلون:
>
> ```bash
> git clone https://github.com/AmirSarani/kali-vpn-manager.git && cd kali-vpn-manager && ./install.sh
> ```

سپس ترمینال جدید باز کن (یا `source ~/.zshrc`) و بزن:

```bash
vpn
```

نصب‌کننده: پیش‌نیازها را نصب می‌کند، `vpn.sh` را در `~/.local/share/vpn-manager/` می‌گذارد، یک بلوک امن به `~/.zshrc` و `~/.bashrc` اضافه می‌کند (با بکاپ) و دوباره‌اجرا کردنش مشکلی ایجاد نمی‌کند (idempotent).

---

## 🚀 استفاده

| دستور | کار |
|---|---|
| `vpn` | منوی تعاملی |
| `vpn on` / `vpn off` | روشن / خاموش پروکسی شل |
| `vpn st` | وضعیت (پورت باز؟ TUN؟ IP عمومی) |
| `vpn app CMD…` | اجرای یک برنامه‌ی CLI از VPN، مثلاً `vpn app curl ifconfig.me` |
| `vpn tun` / `vpn untun` | روشن / خاموش TUN Mode |
| `vpn renew` | گرفتن IP جدید از DHCP |
| `vpn info` | اطلاعات شبکه |
| `vpn lang [fa\|en]` | تغییر زبان (فارسی / انگلیسی) |
| `vpn clear` | پاک کردن تنظیمات پروکسی |

نمونه:

```bash
vpn on && curl ifconfig.me          # IP عمومی از طریق VPN
vpn app nmap -sT -Pn example.com    # فقط nmap از VPN
vpn tun                             # کل سیستم از VPN
vpn untun
```

---

## 🔧 تنظیمات

فایل `~/.config/vpn-manager/config` (نصب‌کننده می‌سازد؛ با آپدیت پاک نمی‌شود):

```bash
VPN_PORT=10808          # پورت پروکسی روی ویندوز
VPN_LANG="fa"           # fa | en
VPN_PROTO="http"        # http | socks5
VPN_HOST=""             # خالی = خودکار (x.x.x.1). برای شبکه‌ی غیر NAT مقدار بده
NET_IFACE=""            # خالی = خودکار
VPN_DNS_SERVER="1.1.1.1"
```

---

## ⚠️ نکات مهم

1. **پروکسی شل فقط همان ترمینال را پوشش می‌دهد.** برای apt: `sudo -E apt update` (sudo متغیرها را پاک می‌کند).
2. **`vpn app` فقط ترافیک TCP را رد می‌کند.** برای nmap حتماً `-sT -Pn` بزن (پینگ/UDP/SYN-scan از پروکسی رد نمی‌شود). برنامه‌های GUI/استاتیک با proxychains کار نمی‌کنند → از TUN استفاده کن.
3. **TUN Mode با HTTP-proxy فقط TCP را رد می‌کند** (UDP/QUIC کار نمی‌کند؛ DNS از طریق TCP روی پروکسی پرسیده می‌شود). برای UDP از SOCKS5 هم استفاده کن (`VPN_PROTO="socks5"`، به شرط پشتیبانی کلاینت ویندوز).
4. **ترافیک شبکه‌های خصوصی (192.168/10/172.16) مستقیم می‌رود**، پس به ماشین‌های لَب دسترسی داری.
5. **قبل از خاموش کردن/ری‌استارت کالی TUN را با `vpn untun` خاموش کن.**
6. TUN Mode از `sudo` استفاده می‌کند (route و تغییر شبکه). کانفیگ در `~/.local/share/vpn-manager/singbox.json` و لاگ در `singbox.log` است.
7. از VPN فقط برای کارهای قانونی و روی سیستم‌هایی که اجازه‌ی تست‌شان را داری استفاده کن.

---

## 🐛 رفع اشکال

| مشکل | راه‌حل |
|---|---|
| `گیت‌وی پیدا نشد` | شبکه‌ی VM وصل نیست یا `VPN_HOST` را دستی بگذار |
| پورت پروکسی «بسته» | VPN ویندوز روشن؟ Allow LAN؟ فایروال ویندوز؟ پورت درست؟ (`vpn st`) |
| `TUN Mode بالا نیامد` | `sudo tail ~/.local/share/vpn-manager/singbox.log` |
| TUN روشن شد ولی سایت‌ها باز نمی‌شوند | `VPN_PROTO` با نوع پورت جور نیست (http به‌جای socks یا برعکس) |
| `proxychains4: command not found` | `sudo apt install proxychains4` |
| کلاینت ویندوز هم TUN دارد | TUN ویندوز را خاموش کن یا فقط یکی از TUNها را روشن بگذار |

---

## 🗑️ حذف

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/uninstall.sh)
```

---

## 🔒 امنیت

- نصب‌کننده، فقط فایل‌های همین ریپو و باینری sing-box (نسخه‌ی pinned، با بررسی **SHA-256**) را دانلود می‌کند.
- برای اطمینان بیشتر، قبل از اجرا آن را بخوان یا یک تگ مشخص نصب کن:
  `VPN_REF=v1.0.0 bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/v1.0.0/install.sh)`

## 🤝 مشارکت

Issue و Pull Request خوش‌آمد است. قبل از PR تست‌ها را بزن: `bash tests/test.sh`

## 📄 مجوز

[MIT](LICENSE) © 2026 AmirSarani
