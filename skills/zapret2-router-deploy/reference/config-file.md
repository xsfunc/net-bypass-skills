# config parameter reference

`/opt/zapret2/config` is a **shell file**, not UCI. Every parameter OpenWrt init script (`init.d/openwrt/zapret2`) consumes is defined here.

This is reference agent loads **before** editing any `config` parameter. Validate with `sh -n /opt/zapret2/config` before applying. For the **flag syntax** that goes inside `NFQWS2_OPT` (`--filter-*`, `--payload`, `--lua-desync=...`), load `/zapret2-engine-reference` — this file documents the shell-file parameters, not the engine flag grammar.

## 1. Enable / ports / packet counts

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `NFQWS2_ENABLE=0\|1` | `0` | Master switch for the nfqws2 daemon + firewall rules | verified |
| `NFQWS2_PORTS_TCP=80,443` | `80,443` | TCP ports redirected to NFQUEUE (comma-separated) | verified |
| `NFQWS2_PORTS_UDP=443` | `443` | UDP ports redirected to NFQUEUE (QUIC) | verified |
| `NFQWS2_TCP_PKT_OUT=20` | `20` | connbytes dir=original packet cap (outgoing TCP) | verified |
| `NFQWS2_TCP_PKT_IN=10` | `10` | connbytes dir=reply packet cap (incoming TCP) | verified |
| `NFQWS2_UDP_PKT_OUT=5` | `5` | connbytes dir=original packet cap (outgoing UDP) | verified |
| `NFQWS2_UDP_PKT_IN=3` | `3` | connbytes dir=reply packet cap (incoming UDP) | verified |
| `NFQWS2_PORTS_TCP_KEEPALIVE=80` | `80` | No-connbytes mode: TCP ports to keep intercepting for stateless DPI / HTTP keep-alives — **very CPU-consuming, enable with care** | verified |
| `NFQWS2_PORTS_UDP_KEEPALIVE=` | (empty) | No-connbytes UDP equivalent | verified |

`PKT_OUT` maps to connbytes direction `original`, `PKT_IN` to direction `reply` — the kernel-side limiter that complements the nftables `ct original packets 1-N` / `ct reply packets 1-N` expression (see `nfqueue-wiring.md` §Canonical pattern).

## 2. `NFQWS2_OPT="..."` — the desync payload

The desync payload string passed to `nfqws2`.

- `<HOSTLIST>` and `<HOSTLIST_NOAUTO>` are **placeholders** the init script replaces per `MODE_FILTER` and existing list files. Direct `--hostlist=` inside `NFQWS2_OPT` is discouraged — use the placeholders so `MODE_FILTER` keeps control.
- The init script auto-adds the standard Lua files (`zapret-lib.lua`, `zapret-antidpi.lua`, `zapret-auto.lua`) via `--lua-init=@lua/...` and the `--qnum` / `--user` flags from `config`. **Do NOT duplicate them in `NFQWS2_OPT`** — a duplicate `--qnum` causes a parse error.

For the engine flag grammar that goes inside `NFQWS2_OPT`, see `zapret2-engine-reference/reference/core-flags.md` and `zapret2-engine-reference/reference/arg-ordering.md`.

## 3. `MODE_FILTER=none|ipset|hostlist|autohostlist`

| Value | `<HOSTLIST>` expands to | Kernel sets loaded | Evidence |
|-------|-------------------------|--------------------|----------|
| `none` | empty | none | verified |
| `ipset` | path to the IP include list | `zapret`/`zapret6` include, `nozapret`/`nozapret6` exclude | verified |
| `hostlist` | path to the user hostlist | none (engine-side domain filter only) | verified |
| `autohostlist` | path to the auto-populated hostlist | none (engine populates the list at runtime) | verified |

See `hostlist-ipset-nftset.md` for the engine flag side and `list-management.md` for the list-fetching infrastructure.

## 4. Marks

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `DESYNC_MARK=0x40000000` | `0x40000000` | Mark bit nfqws2 sets on generated packets to prevent re-queue (loop guard). MUST match the nftables `meta mark and 0x40000000 == 0` guard — see `nfqueue-wiring.md` §Canonical pattern. | verified |
| `DESYNC_MARK_POSTNAT=0x20000000` | `0x20000000` | Mark used in pre-nat mode (`POSTNAT=0`) | verified |
| `FILTER_MARK` | (unset) | Optional; if set, only outgoing traffic carrying this mark goes to nfqws2 — lets the operator write their own limiting rules upstream | verified |

## 5. `POSTNAT=0|1`

| Value | Mode | Notes | Evidence |
|-------|------|-------|----------|
| `0` | pre-nat | Disables some bypass techniques for forwarded traffic but lets debug log show client IPs | verified |
| `1` | post-nat (default) | nftables only | verified |

## 6. `FLOWOFFLOAD=donttouch|none|software|hardware`

| Value | Meaning | Evidence |
|-------|---------|----------|
| `donttouch` | leave the existing offload setting | verified |
| `none` | disable offload (zapret2 needs this for NFQUEUE to work) | verified |
| `software` | enable software offload | verified |
| `hardware` | enable hardware offload | verified |

**Critical interaction with `nfqueue-wiring.md`: flow offload bypasses NFQUEUE — the safe setting is `none` (or `donttouch` if the operator has already disabled offload via UCI per `nfqueue-wiring.md` §flow-offload-conflict).** `FLOWOFFLOAD=hardware`/`software` re-breaks NFQUEUE.

## 7. `DISABLE_IPV4=1` / `DISABLE_IPV6=1`

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `DISABLE_IPV4=1` | `0` | Disable IPv4 family | verified |
| `DISABLE_IPV6=1` | `1` | Disable IPv6 family (RU deployments often IPv4-only) | verified |

If the deployment needs IPv6 bypass (QUIC over IPv6, IPv6-only CDN), set `DISABLE_IPV6=0` and ensure the nftables NFQUEUE rule has the `ip6` line (`nfqueue-wiring.md` §IPv4 vs IPv6).

## 8. OpenWrt iface selection

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `OPENWRT_LAN="lan lan2 lan3"` | `lan` | LAN interfaces (space-separated) | verified |
| `OPENWRT_WAN4="wan vpn"` | (ifaces with default route) | IPv4 WAN interfaces | verified |
| `OPENWRT_WAN6="wan6 vpn6"` | (ifaces with default route) | IPv6 WAN interfaces | verified |

## 9. Classic-Linux iface selection

| Parameter | Example | Purpose | Evidence |
|-----------|---------|---------|----------|
| `IFACE_LAN=eth0` | `eth0` | LAN interface (no effect on OpenWrt) | verified |
| `IFACE_WAN="eth0 eth1"` | `eth0 eth1` | IPv4 WAN (space-separated) | verified |
| `IFACE_WAN6="ipsec0 wireguard0 he_net"` | `ipsec0 wireguard0 he_net` | IPv6 WAN; if undefined, takes `IFACE_WAN`'s value | verified |

## 10. Init-script hooks

| Parameter | Purpose | Evidence |
|-----------|---------|----------|
| `INIT_APPLY_FW=0\|1` | Should start/stop apply firewall rules? Not applicable to openwrt+firewall3+iptables. | verified |
| `INIT_FW_PRE_UP_HOOK` | Shell script run before firewall rules go up | verified |
| `INIT_FW_POST_UP_HOOK` | Shell script run after firewall rules go up | verified |
| `INIT_FW_PRE_DOWN_HOOK` | Shell script run before firewall rules come down | verified |
| `INIT_FW_POST_DOWN_HOOK` | Shell script run after firewall rules come down | verified |

## 11. `GETLIST`

Selects the list-fetching script run by `get_config.sh` (cron nightly).

| Value | Source | Evidence |
|-------|--------|----------|
| `get_user.sh` | user-maintained list | verified |
| `get_antizapret.sh` | prostovpn.org | verified |
| `get_combined.sh` | combined sources | verified |
| `get_reestr.sh` | bol-van/rulist | verified |
| `get_hostlist.sh` | hostlist source | verified |

Comment out `GETLIST` to disable auto-fetch. See `list-management.md` for the full script catalogue.

## 12. Autohostlist

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `AUTOHOSTLIST_INCOMING_MAXSEQ=4096` | `4096` | Max incoming packet seq for auto-detection window | verified |
| `AUTOHOSTLIST_RETRANS_MAXSEQ=32768` | `32768` | Max seq for retransmission tracking | verified |
| `AUTOHOSTLIST_RETRANS_RESET=1` | `1` | Reset retrans counter on success | verified |
| `AUTOHOSTLIST_RETRANS_THRESHOLD=3` | `3` | Retransmissions counted as a failure | verified |
| `AUTOHOSTLIST_FAIL_THRESHOLD=3` | `3` | Failed attempts before adding a domain | verified |
| `AUTOHOSTLIST_FAIL_TIME=60` | `60` | Time window (sec) for failures to count | verified |
| `AUTOHOSTLIST_UDP_IN=1` | `1` | UDP incoming packet cap for autohostlist | verified |
| `AUTOHOSTLIST_UDP_OUT=4` | `4` | UDP outgoing packet cap for autohostlist | verified |
| `AUTOHOSTLIST_DEBUGLOG=0` | `0` | Enable autohostlist debug log | verified |

## 13. ipset

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `SET_MAXELEM=522288` | `522288` | Max elements in the kernel ipset/nftset | verified |
| `IPSET_OPT="hashsize 262144 maxelem $SET_MAXELEM"` | `hashsize 262144 maxelem 522288` | ipset creation options | verified |
| `IPSET_HOOK="/etc/zapret2.ipset.hook"` | (path) | Dynamic IP generation hook; `$1` = ipset/nftset/table name | verified |

## 14. ip2net

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `IP2NET_OPT4="--prefix-length=22-30 --v4-threshold=3/4"` | `--prefix-length=22-30 --v4-threshold=3/4` | ip2net IPv4 options | verified |
| `IP2NET_OPT6="--prefix-length=56-64 --v6-threshold=5"` | `--prefix-length=56-64 --v6-threshold=5` | ip2net IPv6 options | verified |

## 15. mdig

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `MDIG_THREADS=30` | `30` | mdig resolver thread count | verified |
| `MDIG_EAGAIN=10` | `10` | Retry count on DNS eagain | verified |
| `MDIG_EAGAIN_DELAY=500` | `500` | Delay (ms) between eagain retries | verified |

## 16. Misc

| Parameter | Default | Purpose | Evidence |
|-----------|---------|---------|----------|
| `TMPDIR` | (unset → `/tmp`) | Override if `/tmp` is small | verified |
| `WS_USER=nobody` | `nobody` | Daemon user; required on Keenetic | verified |
| `FWTYPE=iptables\|nftables\|ipfw` | (autodetect) | Override firewall-stack autodetect | verified |
| `GZIP_LISTS=1` | `1` | Compress large lists (`.gz` appended) | verified |
| `LISTS_RELOAD` | (empty) | Command to reload ip/host lists after update; empty = auto backend selection; `-` = disable; on BSD+PF no auto reload, must provide own command | verified |
| `FILTER_TTL_EXPIRED_ICMP=1` | `1` | Drop ICMP time-exceeded for tampered connections; can interfere with `mtr`/`traceroute` in POSTNAT — use a source port not redirected | verified |

## Gotchas

- **`/opt/zapret2/config` is the sole non-UCI exception**; edit with `sh -n` validation under safe-mode
- **`FLOWOFFLOAD=hardware`/`software` re-breaks NFQUEUE** — see `nfqueue-wiring.md`. Safe value is `none` (or `donttouch` if the operator has already disabled offload via UCI)
- **`NFQWS2_OPT` must NOT include `--qnum`, `--user`, or the standard `--lua-init=@lua/zapret-lib.lua` etc.** 
- **`DISABLE_IPV6=1` is the default** — if the deployment needs IPv6 bypass (QUIC over IPv6, IPv6-only CDN), set `DISABLE_IPV6=0` and ensure the nftables NFQUEUE rule has the `ip6` line.
- **`MODE_FILTER=none` means `<HOSTLIST>` expands to empty** — a profile with `<HOSTLIST>` but `MODE_FILTER=none` has no hostlist filtering.
- **`NFQWS2_PORTS_*_KEEPALIVE` is CPU-consuming** — no-connbytes mode intercepts packets for the whole connection lifetime; enable only on stateless DPI / HTTP keep-alive scenarios.

## Cross-references

`deploy.md` (install path); `nfqueue-wiring.md` (`DESYNC_MARK` ↔ `meta mark` guard; `FLOWOFFLOAD` conflict §flow-offload-conflict; `PKT_OUT`/`PKT_IN` ↔ `ct original/reply packets 1-N`); `hostlist-ipset-nftset.md` (`MODE_FILTER`, autohostlist engine flags); `list-management.md` (`GETLIST` + ipset scripts, `IPSET_OPT`, `IP2NET_OPT4/6`, `MDIG_*`, `GZIP_LISTS`, `LISTS_RELOAD`); `init-script.md` (init-script actions, hooks, custom.d); `zapret2-engine-reference/reference/core-flags.md` (flag syntax that goes inside `NFQWS2_OPT`); `zapret2-engine-reference/reference/arg-ordering.md` (flag ordering) 
