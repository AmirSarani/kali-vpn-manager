# 🌐 Kali VPN Manager

**English** | **[فارسی](README.fa.md)**

[![CI](https://github.com/AmirSarani/kali-vpn-manager/actions/workflows/ci.yml/badge.svg)](https://github.com/AmirSarani/kali-vpn-manager/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Kali%20%7C%20Debian%20%7C%20Ubuntu-red)
![Shell](https://img.shields.io/badge/shell-zsh%20%7C%20bash-green)

Route a **Kali Linux VM (VMware NAT)** through the VPN / proxy client running on the **Windows host** (v2rayN, Clash, Nekoray…) — one-line install, one `vpn` command. The interface speaks **English or Persian** (your choice).

---

## ✨ Features

| Feature | Description |
|---|---|
| 🟢 Shell proxy | `curl`, `wget`, `git`, `pip`… via `http_proxy` |
| 🎯 Per-app proxy | `vpn app nmap -sT -Pn target` (proxychains, no system changes) |
| 🌐 TUN mode | the whole system (Firefox, everything) goes through the VPN (sing-box) |
| 🔌 HTTP & SOCKS5 | set with `VPN_PROTO` |
| 🔍 Auto-detection | Windows host address from the gateway, NIC from the default route |
| 🔄 Renew DHCP | via NetworkManager or dhclient |
| 🌍 Languages | English / فارسی — switch any time with `vpn lang` |

---

## 📋 Requirements

1. **Kali / Debian / Ubuntu** (amd64 or arm64)
2. **VMware** with **NAT** networking
3. On **Windows**: your VPN client running with **Allow LAN / Allow connections from LAN** enabled
4. Know the proxy port (script default: `10808`)
   - v2rayN: the **mixed** port (usually `10808`) speaks both HTTP and SOCKS. If ports are separate: SOCKS=`10808`, HTTP=`10809`.
   - Windows Firewall must allow inbound connections on that port from the VMnet8 network.

---

## 📥 Install (one line)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/install.sh)
```

The installer asks for your language (English / فارسی). To skip the questions:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/install.sh) --lang en --with-singbox
```

| Option | Meaning |
|---|---|
| `--lang en\|fa` | interface language (default: ask, otherwise `en`) |
| `--with-singbox` | install sing-box for TUN mode without asking |
| `--no-singbox` | never install sing-box |

> No internet in Kali yet (VPN not connected)? Download the repo on Windows, copy it into the VM (shared folder / `scp`) and run `./install.sh`, or:
>
> ```bash
> git clone https://github.com/AmirSarani/kali-vpn-manager.git && cd kali-vpn-manager && ./install.sh
> ```

Then open a new terminal (or `source ~/.zshrc`) and run:

```bash
vpn
```

The installer installs prerequisites, puts `vpn.sh` in `~/.local/share/vpn-manager/`, adds a marked block to `~/.zshrc` / `~/.bashrc` (with a backup), and is safe to re-run.

---

## 🚀 Usage

| Command | Action |
|---|---|
| `vpn` | interactive menu |
| `vpn on` / `vpn off` | shell proxy on / off |
| `vpn st` | status (port open? TUN? public IP) |
| `vpn app CMD…` | run a CLI program through the VPN, e.g. `vpn app curl ifconfig.me` |
| `vpn tun` / `vpn untun` | TUN mode on / off |
| `vpn renew` | get a new IP via DHCP |
| `vpn info` | network info |
| `vpn clear` | clear proxy settings |
| `vpn lang [fa\|en]` | switch language (saved to the config file) |

Examples:

```bash
vpn on && curl ifconfig.me          # public IP through the VPN
vpn app nmap -sT -Pn example.com    # only nmap goes through the VPN
vpn tun                             # whole system through the VPN
vpn untun
```

---

## 🔧 Configuration

`~/.config/vpn-manager/config` (created by the installer, never overwritten on update):

```bash
VPN_LANG="en"           # en | fa
VPN_PORT=10808          # proxy port on Windows
VPN_PROTO="http"        # http | socks5
VPN_HOST=""             # empty = auto (x.x.x.1); set it for non-NAT networks
NET_IFACE=""            # empty = auto
VPN_DNS_SERVER="1.1.1.1"
```

---

## ⚠️ Good to know

1. **The shell proxy only affects that terminal.** For apt use `sudo -E apt update` (plain sudo drops the variables).
2. **`vpn app` carries TCP only.** With nmap always use `-sT -Pn` (ping / UDP / SYN scans don't go through a proxy). GUI and statically linked programs don't work with proxychains → use TUN.
3. **TUN mode over an HTTP proxy carries TCP only** (no UDP/QUIC); DNS is asked over TCP through the proxy. For UDP use SOCKS5 (`VPN_PROTO="socks5"`, if your Windows client supports it).
4. **Private networks (192.168/10/172.16) bypass the proxy**, so lab machines stay reachable.
5. **Run `vpn untun` before shutting down or rebooting Kali.**
6. TUN mode uses `sudo` (routes / network changes). Its config is `~/.local/share/vpn-manager/singbox.json`, log is `singbox.log`.
7. Use this only for lawful work and on systems you are authorized to test.

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| `Gateway not found` | the VM network is down, or set `VPN_HOST` manually |
| Proxy port shows "closed" | Windows VPN running? Allow LAN? Windows Firewall? correct port? (`vpn st`) |
| `TUN Mode failed to start` | `sudo tail ~/.local/share/vpn-manager/singbox.log` |
| TUN is up but sites don't load | `VPN_PROTO` doesn't match the port type (http vs socks) |
| `proxychains4: command not found` | `sudo apt install proxychains4` |
| Windows client also has TUN on | turn one of the two TUNs off |

---

## 🗑️ Uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/main/uninstall.sh)
```

---

## 🔒 Security

- The installer only downloads files from this repo and a **pinned sing-box** build, verified by **SHA-256**.
- Read the script before running it, or pin a tag:
  `VPN_REF=v1.0.0 bash <(curl -fsSL https://raw.githubusercontent.com/AmirSarani/kali-vpn-manager/v1.0.0/install.sh)`

## 🤝 Contributing

Issues and pull requests are welcome. Run the tests first: `bash tests/test.sh`

## 📄 License

[MIT](LICENSE) © 2026 AmirSarani
