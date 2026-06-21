# nfqueue-wiring — fw4 custom rules, NFQUEUE, conntrack, flow-offload conflict

nfqws2 reads packets **exclusively** from an NFQUEUE callback (`nfq2/nfqws.c` — the callback is the only entry point for packets into the engine). Without nftables rules directing traffic into that queue, nfqws2 runs but intercepts nothing — `ps` shows the daemon, but no packets arrive. This file covers the wiring that makes interception work, the conntrack specifics that determine *which* packets arrive, and the **flow-offload conflict** that is the single most common silent-break cause on OpenWrt.

For the conceptual model of NFQUEUE verdicts (PASS/DROP/MODIFY), see `theory.md`.

## The NFQUEUE model on OpenWrt

```
egress packet → nftables hook (prerouting/output/forward) → queue statement → NFQUEUE (queue-num N) → nfqws2 userspace → verdict (PASS/MODIFY/DROP) → kernel resumes
```

The `queue num` must match the `--qnum=N` (or equivalent) flag nfqws2 was started with via the init script. A mismatch produces "rule present, packets missing" — see troubleshooting matrix below.

## Canonical pattern (upstream manual nftables example)

The upstream manual ships an nftables pattern that is the canonical NFQUEUE wiring for nfqws2. It adds a loop-guard, a connbytes limiter at the nftables level, a fail-open `bypass` keyword, a `notrack` predefrag chain, and explicit rules for `fin,rst` / `syn,ack` packets so conntrack sees them. This is the pattern to mirror in any deploy; the minimal example further below is a degenerate fallback.

```nft
IFACE_WAN=wan
MAX_PKT_IN=15
MAX_PKT_OUT=15
FWMARK=0x40000000
PORTS_TCP=80,443
PORTS_UDP=443
QNUM=200

nft create table inet ztest

nft add chain inet ztest postnat "{type filter hook postrouting priority srcnat+1;}"
nft add rule inet ztest postnat oifname $IFACE_WAN meta mark and $FWMARK == 0 udp dport "{$PORTS_UDP}" ct original packets 1-$MAX_PKT_OUT queue num $QNUM bypass
nft add rule inet ztest postnat oifname $IFACE_WAN meta mark and $FWMARK == 0 tcp dport "{$PORTS_TCP}" ct original packets 1-$MAX_PKT_OUT queue num $QNUM bypass
nft add rule inet ztest postnat oifname $IFACE_WAN meta mark and $FWMARK == 0 tcp dport "{$PORTS_TCP}" tcp flags fin,rst queue num $QNUM bypass

nft add chain inet ztest pre "{type filter hook prerouting priority filter;}"
nft add rule inet ztest pre iifname $IFACE_WAN udp sport "{$PORTS_UDP}" ct reply packets 1-$MAX_PKT_IN queue num $QNUM bypass
nft add rule inet ztest pre iifname $IFACE_WAN tcp sport "{$PORTS_TCP}" ct reply packets 1-$MAX_PKT_IN queue num $QNUM bypass
nft add rule inet ztest pre iifname $IFACE_WAN tcp sport "{$PORTS_TCP}" "tcp flags & (syn | ack) == (syn | ack)" queue num $QNUM bypass
nft add rule inet ztest pre iifname $IFACE_WAN tcp sport "{$PORTS_TCP}" tcp flags fin,rst queue num $QNUM bypass

nft add chain inet ztest predefrag "{type filter hook output priority -401;}"
nft add rule inet ztest predefrag "mark & $FWMARK != 0x00000000 notrack"
```

The manual example binds the rules to `oifname`/`iifname $IFACE_WAN`. The include-file example below omits interface names so the same file works regardless of WAN interface; add `oifname`/`iifname` constraints if you want to match the manual exactly.

### Piece-by-piece

- **`meta mark and 0x40000000 == 0`** — loop guard: zapret2-generated packets are fwmarked with `DESYNC_MARK` (`0x40000000`); this match ensures they are not re-queued (infinite-loop prevention). The mark value MUST match `DESYNC_MARK` in `/opt/zapret2/config` (see `config-file.md`)
- **`ct original packets 1-15` / `ct reply packets 1-15`** — connbytes limiter at the nftables level: only the first 15 packets of each direction go to userspace. **This is the kernel-side CPU optimisation that complements `NFQWS2_TCP_PKT_OUT=20`/`_IN=10` in `config`** (`config-file.md`). Tune the number per deployment; 15 is the upstream manual example, 20/10 is the `config.default`
- **`tcp flags fin,rst` and `tcp flags & (syn|ack) == (syn|ack)` rules** — intercept FIN/RST/SYN-ACK packets so conntrack sees them and cleans up/records state correctly. The upstream manual explicitly says FIN/RST interception is recommended. 
- **`queue num 200 bypass`** — `bypass` keyword: if nfqws2 is not running, packets pass through unmodified (fail-open) instead of being dropped. Trade-off: a dead nfqws2 silently disables bypass
- **`predefrag` chain with `notrack`** — zapret2-generated packets (marked) are excluded from conntrack re-fragmentation so the engine's careful IP-fragment layout is preserved
- **`priority srcnat+1` (=101) (postrouting) / `filter` (=0) (prerouting)** — hook priorities; `postrouting` for outgoing (POSTNAT mode default), `prerouting` for incoming. PRENAT mode uses `output`/`input` instead — out of scope for the default

## fw4 custom-rule include

fw4 loads nftables include files from `/etc/nftables.d/*.nft` at firewall start. Custom NFQUEUE rules go in a dedicated include file so they survive `fw4 reload` and don't get clobbered by UCI-driven fw4 rebuilds.

### Example: `/etc/nftables.d/10-zapret2.nft` (canonical pattern)

```nft
table inet zapret2 {
    chain post {
        type filter hook postrouting priority 101; policy accept;
        ip protocol tcp tcp dport { 80, 443 } meta mark & 0x40000000 == 0 ct original packets 1-15 counter queue num 200 bypass
        ip6 nexthdr tcp tcp dport { 80, 443 } meta mark & 0x40000000 == 0 ct original packets 1-15 counter queue num 200 bypass
        meta l4proto udp udp dport { 443 } meta mark & 0x40000000 == 0 ct original packets 1-15 counter queue num 200 bypass
        ip protocol tcp tcp dport { 80, 443 } meta mark & 0x40000000 == 0 tcp flags fin,rst counter queue num 200 bypass
        ip6 nexthdr tcp tcp dport { 80, 443 } meta mark & 0x40000000 == 0 tcp flags fin,rst counter queue num 200 bypass
    }
    chain pre {
        type filter hook prerouting priority filter; policy accept;
        ip protocol tcp tcp sport { 80, 443 } meta mark & 0x40000000 == 0 ct reply packets 1-15 counter queue num 200 bypass
        ip6 nexthdr tcp tcp sport { 80, 443 } meta mark & 0x40000000 == 0 ct reply packets 1-15 counter queue num 200 bypass
        meta l4proto udp udp sport { 443 } meta mark & 0x40000000 == 0 ct reply packets 1-15 counter queue num 200 bypass
        ip protocol tcp tcp sport { 80, 443 } meta mark & 0x40000000 == 0 "tcp flags & (syn | ack) == (syn | ack)" counter queue num 200 bypass
        ip6 nexthdr tcp tcp sport { 80, 443 } meta mark & 0x40000000 == 0 "tcp flags & (syn | ack) == (syn | ack)" counter queue num 200 bypass
        ip protocol tcp tcp sport { 80, 443 } meta mark & 0x40000000 == 0 tcp flags fin,rst counter queue num 200 bypass
        ip6 nexthdr tcp tcp sport { 80, 443 } meta mark & 0x40000000 == 0 tcp flags fin,rst counter queue num 200 bypass
    }
    chain predefrag {
        type filter hook output priority -401; policy accept;
        meta mark & 0x40000000 != 0x00000000 notrack
    }
}
```

The `queue num` (200) must match the `--qnum` set by the init script from `config`; the `0x40000000` mask must match `DESYNC_MARK` in `config` — if either drifts, either packets loop or nothing is queued.

Also set the sysctl out-of-band (it is not an nftables statement). The upstream manual example does **not** include this line, but it is required in practice because zapret2's bad-seq/bad-ack fooling generates packets that strict conntrack would drop:

```sh
sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=1
```

## PM-axis split: fw4 vs fw3

| PM axis | Firewall stack | Include path | Reload command | Evidence |
|---------|----------------|--------------|----------------|----------|
| `apk` (25.x) | fw4 (nftables) | `/etc/nftables.d/*.nft` | `fw4 reload` | verified |
| `opkg` (pre-25, 23.05+) | fw4 (nftables, default since 22.03) | `/etc/nftables.d/*.nft` | `fw4 reload` | verified |
| `opkg` (older pre-25, e.g. 21.02) | fw3 (iptables) | **out of scope** | n/a — stop and report | verified |

If the router is on fw3/iptables, **stop and report**. The operator must upgrade to fw4 first (a separate, out-of-scope firmware/config task).

## The flow-offload conflict (most common silent-break)

**Hardware or software flow offload bypasses NFQUEUE entirely.** When offload is enabled, nftables `queue` statements are skipped for established flows — the kernel shortcuts packets through the fast path, and nfqws2 never sees them. The symptom: "first packet of a connection is intercepted, then nothing" or "ruleset shows the rule, `nft list ruleset` counter increments once, but bypass doesn't work."

### Detection

```sh
# Software offload
uci -q get firewall.@defaults[0].flow_offloading
# Hardware offload
uci -q get firewall.@defaults[0].flow_offloading_hw
# Running nft ruleset — look for 'offload' chains
nft list ruleset | grep -i offload
```

### Fix — disable offload under safe-mode

```sh
# Disable both software and hardware offload
uci set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'  # only if the key exists
uci commit firewall
# Validate — offload chains gone, NFQUEUE chain present
nft list ruleset | grep -i offload || echo "offload disabled"
nft list ruleset | grep -A2 'queue num 200'
```

On `capable` HW where offload matters for throughput, the operator may want a finer fix — **stop and report** before re-enabling, because any offload re-enablement risks re-breaking NFQUEUE.

## conntrack specifics

nfqws2 uses conntrack state (`desync.track` in Lua) to count packets per connection (`n/d/s/b/p` counters), recognise retransmissions, and drive the `circular` orchestrator.

Three consequences for wiring:

1. **Established connections are not re-intercepted.** Once a flow is in conntrack's `ESTABLISHED` state and the first packets have passed the NFQUEUE rule, subsequent packets on the same flow may take the fast path (with offload) or re-hit the queue (without offload) — but the Lua pipeline's `cutoff` logic typically self-disables after the critical phase. **Restarting zapret2 does not flush conntrack.** If the operator changes a strategy and wants it to apply to existing connections, the connections must be killed (conntrack flush or targeted `conntrack -D`):
   ```sh
   # Flush conntrack (disruptive — kills all tracked flows)
   conntrack -F
   # Or targeted — kill flows to a specific host
   conntrack -D --orig-src <lan-client-ip> 2>/dev/null
   ```
   Wrap in safe-mode; this is a network disruption, not just a config change. `[evidence: hypothesis]` (disruption severity is deployment-dependent).

2. **`ct info` mark / conntrack mark.** Some NFQUEUE setups use `ct info set mark` in the nftables rule to tag flows that have already been inspected, so subsequent packets skip the queue. This is an optimisation, not a requirement — nfqws2's own `cutoff` handles the same goal in userspace. Mixing both can cause counters to drift.

3. **`--ctrack-disable=0` is required for `circular`.** The `circular` orchestrator returns early if `desync.track` is missing. If the config sets `--ctrack-disable=1` globally, `circular` cannot rotate. See `zapret2-strategies/reference/circular.md`.
## Queue number selection

The `queue num` (200 in the example) is arbitrary but must match the nfqws2 startup flag. OpenWrt's NFQUEUE range is 0–65535; numbers above 1024 avoid collisions with other userspace queue consumers. A single nfqws2 instance handles one queue; multiple queues require multiple nfqws2 processes (rare on routers).

`--queue-bypass` (or the kernel `bypass` queue flag): if nfqws2 is not running, packets in the queue are dropped by default. `bypass` makes them pass through unmodified instead — useful for fail-open behaviour during zapret2 restarts. Trade-off: a dead nfqws2 silently disables bypass.

## Troubleshooting matrix — "rule present, packets missing"

Walk top-down; stop at the first failing layer.

| # | Check | Command | If fail | Evidence |
|---|-------|---------|---------|----------|
| 1 | nfqws2 running? | `ps w \| grep [n]fqws2` | Start it: `/etc/init.d/zapret2 start` (under safe-mode). If it won't start → `logread \| tail` for the error. | verified |
| 2 | Queue num matches? | `ps w \| grep [n]fqws2` shows `--qnum=N`; `nft list ruleset \| grep 'queue num'` shows the rule's `N` | Mismatch → fix one side. Restart nfqws2 after changing `--qnum` (init script config). | community-observed |
| 3 | Flow offload off? | `uci -q get firewall.@defaults[0].flow_offloading` → must be `0` | Re-run the offload-disable procedure above. | community-observed |
| 4 | Rule counter incrementing? | `nft list ruleset \| grep -A1 'queue num 200' \| grep counter` | Counter at 0 → rule's filter (daddr/dport) doesn't match the test traffic. Widen the filter or test with traffic that matches. | verified |
| 5 | conntrack flushing helps? | `conntrack -L \| grep <test-flow>` then `conntrack -F` and retry | If new connections work but old ones don't → expected (established flows); flush is the fix when changing strategy. | community-observed |

## IPv4 vs IPv6

NFQUEUE rules are per-address-family in nftables. A `table inet zapret2` rule covers both, but the `ip`/`ip6` expressions inside must each be present. If the operator only needs IPv4 bypass (common for Discord/YouTube CDN-only scope), the `ip6` lines can be omitted — but verify the target sites don't serve over IPv6 from the client's perspective (`nslookup <domain> AAAA`).

nfqws2 itself handles both families from one queue; no separate process is needed.

## Gotchas

- **`fw4 reload` rebuilds the ruleset from UCI + includes.** A rule edited directly via `nft add` is lost on reload — use the `/etc/nftables.d/*.nft` include file
- **Include-file ordering is lexical.** `10-foo.nft` runs before `20-bar.nft`. If another include creates a chain that accepts traffic first, `queue` never fires
- **`priority filter` (=0) for prerouting is what the upstream manual example uses.** Using `priority mangle` (=-150) is also safe and runs earlier; using `priority filter` may race with fw4 accept rules in some setups. Pick one and stay consistent
- **Queuenum 0 is valid but risky** — some kernel/userspace tooling reserves it. Use ≥ 1024
- **`conntrack -F` is disruptive.** It kills all tracked flows on the router — every LAN client's connections drop. Use targeted `conntrack -D` when possible
- **dvtws2 is an alternative engine**. It uses a different interception mechanism (TPROXY/mark) and is out of scope for this card
- **`queue num` must match `--qnum`** (set by the init script from `config`); the `0x40000000` mask must match `DESYNC_MARK` in `config` (`config-file.md`) — if either drifts, either packets loop or nothing is queued
- **`net.netfilter.nf_conntrack_tcp_be_liberal=1` is required** for zapret2's bad-seq/bad-ack fooling; strict conntrack drops the generated packets. Set it out-of-band via `sysctl` (or `/etc/sysctl.d/`)