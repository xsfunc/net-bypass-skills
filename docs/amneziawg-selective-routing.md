# Selective Telegram routing via AmneziaWG on OpenWrt

Manual for routing **only Telegram traffic** through an AmneziaWG (WARP) tunnel on an OpenWrt router, while all other traffic goes directly through WAN. Based on a real deployment session (2026-06-30).

## Problem

Telegram is **IP-blocked** by the ISP — all Telegram DC IP ranges are null-routed at L3 (SYN drop). This is **not** a DPI block; zapret2 (a packet-content manipulator) cannot help. The solution is a VPN tunnel with selective policy routing: only Telegram DC IP ranges go through the tunnel, everything else stays direct.

## Architecture

```
Client
  │
  │ request to Telegram DC IP (149.154.x, 91.108.x, 91.105.192.x, 185.76.151.x, ...)
  ▼
  nft mangle_prerouting: iifname "" ip daddr @via_awg → meta mark set 0x100
  │
  ▼
  ip rule 28900: fwmark 0x100/0xff00 iif br-lan → lookup table 200
  │
  ▼
  table 200: default dev awg0
  │
  ▼
  AmneziaWG tunnel (awg0) → Cloudflare WARP endpoint
  │
  ▼
  Telegram DC IP — reachable

Client
  │
  │ request to any other IP (google.com, youtube.com, ...)
  ▼
  nft mangle_prerouting: daddr NOT in @via_awg → no mark
  │
  ▼
  ip rule 32766: from all lookup main → WAN (direct)
```

### Components

| Component | Role |
|-----------|------|
| **awg0** | AmneziaWG tunnel interface, proto `amneziawg` in UCI |
| **@via_awg nftset** | Set of Telegram DC IP ranges; traffic to these IPs gets marked |
| **mangle_prerouting nft rule** | Marks packets destined for `@via_awg` with `0x100` |
| **ip rule (priority 28900)** | Routes `fwmark 0x100` from `br-lan` → table 200 (awg0) |
| **ip rule (priority 29000)** | Same for `br-umbra` (pre-existing Umbra WiFi network) |
| **firewall forwarding lan→awg** | Allows forwarded traffic from LAN zone to AWG zone |
| **WARP+AmneziaWG config** | Cloudflare WARP endpoint with AmneziaWG obfuscation (SIP masquerade) |

## Prerequisites

### Router

- OpenWrt with **firewall4** (fw4/nftables)
- **amneziawg-tools** + **kmod-amneziawg** installed
- Kernel module loaded: `lsmod | grep amneziawg` or `dmesg | grep amneziawg`

### WARP+AmneziaWG configs

You need one or more AmneziaWG config files generated for Cloudflare WARP. These are standard AmneziaWG `.conf` files with WARP endpoint, obfuscation parameters (Jc/Jmin/Jmax/H1-H4/S1-S4), and junk payloads (I1/I2/L1).

The AmneziaWG proto on OpenWrt supports these UCI options: `awg_jc`, `awg_jmin`, `awg_jmax`, `awg_s1`-`awg_s4`, `awg_h1`-`awg_h4`, `awg_i1`, `awg_i2`. It does **not** support `awg_l1` (L1 is silently ignored — safe to delete from UCI).

## Step-by-step

### Inspect existing configuration

Check if awg0 already exists and what state it's in:

```sh
ssh router 'ip addr show awg0 2>/dev/null'
ssh router 'awg show awg0 2>/dev/null'
ssh router 'uci show network | grep -E "awg|amnezia"'
ssh router 'nft list set inet fw4 via_awg 2>/dev/null'
ssh router 'ip rule show'
ssh router 'nft list chain inet fw4 mangle_prerouting 2>/dev/null'
```

Key things to check:
- Is `awg0` interface up? (`ip addr show awg0`)
- Is there a recent handshake? (`awg show awg0 latest-handshakes` — should be < 5 min ago)
- Can you ping through the tunnel? (`ping -c 3 -I awg0 1.1.1.1`)
- Is `@via_awg` set populated or empty?
- Are there ip rules for `fwmark 0x100`?

### Backup current config

Always backup before making changes:

```sh
ssh router 'uci show network > /tmp/awg-backup-$(date +%s).txt && echo "Backup saved" && ls -la /tmp/awg-backup-*.txt'
```

### Apply WARP+AmneziaWG config

Choose the config you want to try. The recommended approach is to try configs in order of obfuscation strength — SIP masquerade first (best chance against DPI), then binary junk payloads.

#### Understanding the config fields

A WARP+AmneziaWG config looks like:

```ini
[Interface]
PrivateKey = <base64>           # Tunnel private key
Address = 172.16.0.2            # Tunnel IP (WARP assigns this)
DNS = 1.1.1.1, 1.0.0.1          # DNS through tunnel
MTU = 1280                      # Reduced MTU for tunnel
S1 = 0                          # Obfuscation: header magic
S2 = 0
S3 = 0
S4 = 0
Jc = 4                          # Junk packet count
Jmin = 40                       # Junk size min
Jmax = 70                       # Junk size max
H1 = 1                          # Header modify
H2 = 2
H3 = 3
H4 = 4
I1 = <b 0x...>                  # Junk payload in initiation packet
I2 = <b 0x...>                  # Junk payload in response packet (optional)

[Peer]
PublicKey = <base64>            # Server public key
AllowedIPs = 0.0.0.0/0, ::/0    # What goes through tunnel (we use nftset for selectivity)
Endpoint = <IP>:<PORT>          # WARP endpoint
PersistentKeepalive = 25
```

**I1/I2 are the key differentiator between configs.** They are junk data inserted into the first handshake packets to disguise the WireGuard signature from DPI:

| Config type | I1 content | I2 content | DPI evasion |
|-------------|-----------|-----------|-------------|
| Binary junk | Raw bytes (1250B) | — | Moderate — looks like random data |
| **SIP masquerade** | SIP INVITE message (343B) | SIP 100 Trying (245B) | **Best** — looks like VoIP traffic |

SIP masquerade is effective because providers rarely block SIP/VoIP — it's business telephony. The handshake literally looks like a SIP call initiation:

```
INVITE sip:bob@biloxi.com SIP/2.0
Via: SIP/2.0/UDP pc33.atlanta.com;branch=z9hG4bK776asdhds
Max-Forwards: 70
To: Bob <sip:bob@biloxi.com>
From: Alice <sip:alice@atlanta.com>;tag=1928301774
...
```

#### Apply via UCI

Replace `<values>` with your config's values:

```sh
ssh router '
# Private key (from [Interface] section)
uci set network.awg0.private_key="<PrivateKey>"

# Endpoint (from [Peer] section)
uci set network.awg0_peer.endpoint_host="<endpoint_IP>"
uci set network.awg0_peer.endpoint_port="<endpoint_PORT>"

# I1 junk payload
uci set network.awg0.awg_i1="<b 0x...>"

# I2 junk payload (only if your config has it)
uci set network.awg0.awg_i2="<b 0x...>"

# Remove L1 if it exists (proto doesn't support it, but clean up)
uci delete network.awg0.awg_l1 2>/dev/null

uci commit network
echo "Config applied. Restarting awg0..."
ifdown awg0
sleep 2
ifup awg0
echo "awg0 restarted"
'
```

### Verify tunnel is alive

Wait 30 seconds for the handshake, then check:

```sh
# Wait for handshake
sleep 30

# Check handshake freshness
ssh router 'awg show awg0 latest-handshakes'
# Output: <peer_key>  <unix_timestamp>
# Convert timestamp to check age:
# python3 -c "import datetime; print(datetime.datetime.fromtimestamp(<ts>, tz=datetime.timezone.utc))"

# Check full tunnel state
ssh router 'awg show awg0'

# Ping through tunnel
ssh router 'ping -c 3 -W 3 -I awg0 1.1.1.1'
```

**Success criteria:**
- `latest-handshakes` shows a timestamp from < 1 minute ago
- `ping -I awg0 1.1.1.1` returns 0% packet loss

**If tunnel is dead** (no handshake, 100% packet loss):
1. The endpoint IP may be ICMP-reachable but UDP-blocked by DPI
2. Try a different config (different endpoint + different I1/I2)
3. Restore backup: `ssh router 'cat /tmp/awg-backup-*.txt | while read line; do eval "$line"; done'` (or re-apply manually)

### Add LAN marking rule (if not already present)

**Create the nft include file:**

```sh
ssh router 'cat > /etc/lan-via-awg-mark.nft << "NFTEOF"
iifname "br-lan" ip daddr @via_awg counter meta mark set 0x100 comment "LAN Telegram via AWG"
NFTEOF'
```

**Register it in UCI firewall:**

```sh
ssh router '
uci set firewall.lan_awg_mark=include
uci set firewall.lan_awg_mark.type="nftables"
uci set firewall.lan_awg_mark.path="/etc/lan-via-awg-mark.nft"
uci set firewall.lan_awg_mark.position="chain-pre"
uci set firewall.lan_awg_mark.chain="mangle_prerouting"

# Allow forwarding from lan zone to awg zone
uci set firewall.lan_to_awg=forwarding
uci set firewall.lan_to_awg.src="lan"
uci set firewall.lan_to_awg.dest="awg"

uci commit firewall
fw4 reload
'
```

**Add the policy routing rule:**

```sh
ssh router '
uci set network.lan_awg_mark=rule
uci set network.lan_awg_mark.in="lan"
uci set network.lan_awg_mark.mark="0x100/0xff00"
uci set network.lan_awg_mark.lookup="200"
uci set network.lan_awg_mark.priority="28900"

uci commit network
/etc/init.d/network reload
'
```

**Verify the rule appeared:**

```sh
ssh router 'ip rule show | grep 28900'
# Expected: 28900: from all fwmark 0x100/0xff00 iif br-lan lookup 200
```

### Populate @via_awg with Telegram DC IP ranges

#### Official source: cidr.txt

Telegram publishes its own IP list at **`https://core.telegram.org/resources/cidr.txt`**. This is the authoritative source — it is what Telegram considers its current infrastructure. **Use this, not ASN lookups.**

Fetch and extract the IPv4 ranges:

```sh
curl -sS https://core.telegram.org/resources/cidr.txt | grep -v ':'
```

Output (IPv4 only, as of 2026-06-30):

```
91.108.56.0/22
91.108.4.0/22
91.108.8.0/22
91.108.16.0/22
91.108.12.0/22
149.154.160.0/20
91.105.192.0/23
91.108.20.0/22
185.76.151.0/24
```

#### Why not ASN lookup?

Looking up prefixes by ASN (AS62041, AS59930, AS62014, AS211157 via RIPEstat) is a **fallback method only**. It has two pitfalls:

- **Stale ranges**: Telegram owns an ASN but may have retired some prefixes. E.g. `95.161.64.0/20` appears in AS62041's RIPEstat output but is **not** in cidr.txt — Telegram no longer uses it.
- **Rented servers in foreign ASNs**: Telegram rents media/CDN capacity from providers like Hetzner (AS24940). These IPs show up in conntrack but are **not** in cidr.txt — adding them routes unrelated traffic through the tunnel.

The official cidr.txt is the ground truth. If you suspect it's outdated, you can cross-reference with ASN lookups, but **cidr.txt wins** when there's a conflict.

#### Add ranges to the nftset (runtime)

```sh
ssh router 'nft add element inet fw4 via_awg {
  149.154.160.0/20,
  91.108.4.0/22,
  91.108.8.0/22,
  91.108.12.0/22,
  91.108.16.0/22,
  91.108.20.0/22,
  91.108.56.0/22,
  91.105.192.0/23,
  185.76.151.0/24
}'
```

#### Make it persistent (survives reboot)

Create an nftables include file that fw4 loads on reload:

```sh
ssh router 'cat > /usr/share/nftables.d/ruleset-post/30-telegram-via-awg.nft << "NFTEOF"
add element inet fw4 via_awg { 149.154.160.0/20, 91.108.4.0/22, 91.108.8.0/22, 91.108.12.0/22, 91.108.16.0/22, 91.108.20.0/22, 91.108.56.0/22, 91.105.192.0/23, 185.76.151.0/24 }
NFTEOF'
```

Verify persistence:

```sh
ssh router 'fw4 reload && nft list set inet fw4 via_awg'
# The set should still contain all Telegram ranges after reload
```

### Step 7. Verify end-to-end

**From your workstation (LAN client), test TCP 443 to Telegram DC IPs:**

```sh
# Ensure proxy env vars are unset (they can interfere)
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

for ip in 149.154.175.50 91.108.56.5 91.108.20.10 91.105.192.100 185.76.151.50; do
  echo -n "  $ip:443 → "
  timeout 8 bash -c "echo > /dev/tcp/$ip/443" 2>/dev/null && echo "OPEN" || echo "CLOSED"
done
```

All should be **OPEN** (traffic routed through awg0).

**Check nft counters are incrementing:**

```sh
ssh router 'nft list chain inet fw4 mangle_prerouting | grep counter'
# The br-lan rule should show packets > 0 and bytes > 0
```

**Check tunnel is still alive:**

```sh
ssh router 'awg show awg0 latest-handshakes && ping -c 2 -W 3 -I awg0 1.1.1.1'
```

### Step 8. Test on phone

1. Connect phone to WiFi "Home" (the main LAN network)
2. Open Telegram
3. Messages should load
4. **Media (photos, videos, files) should load** — if not, see Troubleshooting below

## Troubleshooting

### Tunnel is dead (no handshake)

**Symptom:** `awg show awg0 latest-handshakes` shows a timestamp hours/days old, `ping -I awg0 1.1.1.1` returns 100% loss.

**Diagnosis:**
1. Is the endpoint IP ICMP-reachable? `ssh router 'ping -c 2 162.159.192.8'`
   - If ping works but handshake doesn't → **DPI is blocking UDP to WARP** (the WireGuard handshake pattern is detected despite obfuscation)
2. Try a different config with different obfuscation (SIP masquerade is strongest)
3. Check `dmesg | grep amneziawg` for kernel module errors

**Fix:** Switch to a different WARP+AmneziaWG config (different endpoint, different I1/I2 payloads). See Step 3.

### Messages work but media doesn't load

**Symptom:** Text messages load in Telegram, but photos/videos/files hang or fail.

**Cause:** Telegram media is served from **different IP ranges** than the main DCs — specifically `91.105.192.0/23` and `185.76.151.0/24` (Helsinki media servers).

**Diagnosis:**
1. Check conntrack for UNREPLIED SYN_SENT from the phone:
   ```sh
   ssh router 'cat /proc/net/nf_conntrack | grep "SYN_SENT" | grep "UNREPLIED"'
   ```
2. Look for destination IPs that are NOT in the `@via_awg` set:
   ```sh
   ssh router 'nft list set inet fw4 via_awg'
   ```
3. If you see IPs like `91.105.192.x` or `185.76.151.x` in UNREPLIED conntrack entries, those are Telegram media servers not yet in the set.

**Fix:** Add the missing ranges (see Step 6). Re-fetch the official list to check for new ranges:
   ```sh
   curl -sS https://core.telegram.org/resources/cidr.txt | grep -v ':'
   ```

**How to investigate unknown IPs:**
If you see an unfamiliar IP in conntrack that you suspect is Telegram, look up its ASN:
   ```sh
   # Look up which ASN an IP belongs to
   curl -sS "https://ipinfo.io/<IP>/json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('org'))"
   ```
Then check if it matches one of Telegram's ASNs (AS62041, AS59930, AS62014, AS211157). But **always cross-reference with cidr.txt** — ASN membership alone is not sufficient (see "Why not ASN lookup?" above).

### Traffic not going through tunnel (nft counters stay at 0)

**Cause:** The nft marking rule or ip rule is missing/misconfigured.

**Diagnosis:**
1. Check the nft rule exists:
   ```sh
   ssh router 'nft list chain inet fw4 mangle_prerouting | grep br-lan'
   ```
2. Check the ip rule exists:
   ```sh
   ssh router 'ip rule show | grep 28900'
   ```
3. Check the @via_awg set is populated:
   ```sh
   ssh router 'nft list set inet fw4 via_awg'
   ```

**Fix:** Re-apply Step 5 (marking rule + ip rule) and Step 6 (populate set).

### Non-Telegram traffic going through tunnel

**Cause:** Too-broad IP ranges in `@via_awg`, or AllowedIPs pulling everything through.

**Diagnosis:**
1. Check what's in @via_awg — should only be Telegram ranges
2. Check `awg show awg0 allowed-ips` — the peer may have `0.0.0.0/0` but this is OK because policy routing (not AllowedIPs) controls what enters the tunnel
3. The selectivity comes from the **nft mark rule** (only `@via_awg` IPs get marked) and the **ip rule** (only marked traffic goes to table 200). If these are correct, non-Telegram traffic stays on WAN.

### SSH access lost during work

**Symptom:** `ssh router` returns "Permission denied" after working previously.

**Cause:** SSH agent lost the key identity (common when key has a passphrase and agent times out).

**Fix:**
```sh
ssh-add ~/.ssh/vps
ssh router 'echo connected'
```

## File reference

| File | Purpose | Persistent? |
|------|---------|-------------|
| `/etc/config/network` (UCI) | awg0 interface, peer, ip rules | Yes (UCI) |
| `/etc/config/firewall` (UCI) | firewall zones, forwarding, nft includes | Yes (UCI) |
| `/etc/lan-via-awg-mark.nft` | nft marking rule for br-lan | Yes (file) |
| `/etc/umbra-via-awg-mark.nft` | nft marking rule for br-umbra (pre-existing) | Yes (file) |
| `/usr/share/nftables.d/ruleset-post/30-telegram-via-awg.nft` | Telegram DC ranges in @via_awg | Yes (file) |
| `/tmp/awg-backup-*.txt` | UCI backup before changes | No (tmpfs) |

## Telegram DC IP ranges (official list)

For the `@via_awg` nftset. Sourced from **`https://core.telegram.org/resources/cidr.txt`** (IPv4 only, as of 2026-06-30). Telegram owns multiple ASNs (AS62041, AS59930, AS62014, AS211157) but the official cidr.txt is the authoritative list — ASN lookups can include stale or unrelated ranges.

```nft
149.154.160.0/20,     # Main DCs (DC1-DC5)
91.108.4.0/22,        # DC2/DC4 (Amsterdam)
91.108.8.0/22,        # DC2/DC4
91.108.12.0/22,       # DC2/DC4
91.108.16.0/22,       # DC2/DC4
91.108.20.0/22,       # DC2/DC4
91.108.56.0/22,       # DC5 (Miami)
91.105.192.0/23,      # Media servers (Helsinki)
185.76.151.0/24       # Media servers
```

> **Verify before deploying**: Telegram may add or retire ranges. Always re-fetch:
> ```sh
> curl -sS https://core.telegram.org/resources/cidr.txt | grep -v ':'
> ```

## Quick reference — all commands

```sh
# === Apply WARP+AmneziaWG config (SIP masquerade) ===
ssh router '
uci set network.awg0.private_key="<PrivateKey>"
uci set network.awg0_peer.endpoint_host="<IP>"
uci set network.awg0_peer.endpoint_port="<PORT>"
uci set network.awg0.awg_i1="<b 0x...>"
uci set network.awg0.awg_i2="<b 0x...>"
uci delete network.awg0.awg_l1 2>/dev/null
uci commit network
ifdown awg0; sleep 2; ifup awg0
'

# === Wait and verify tunnel ===
sleep 30
ssh router 'awg show awg0 latest-handshakes && ping -c 3 -I awg0 1.1.1.1'

# === Add LAN marking (if not present) ===
ssh router 'cat > /etc/lan-via-awg-mark.nft << "NFTEOF"
iifname "br-lan" ip daddr @via_awg counter meta mark set 0x100 comment "LAN Telegram via AWG"
NFTEOF
uci set firewall.lan_awg_mark=include
uci set firewall.lan_awg_mark.type="nftables"
uci set firewall.lan_awg_mark.path="/etc/lan-via-awg-mark.nft"
uci set firewall.lan_awg_mark.position="chain-pre"
uci set firewall.lan_awg_mark.chain="mangle_prerouting"
uci set firewall.lan_to_awg=forwarding
uci set firewall.lan_to_awg.src="lan"
uci set firewall.lan_to_awg.dest="awg"
uci commit firewall
fw4 reload
uci set network.lan_awg_mark=rule
uci set network.lan_awg_mark.in="lan"
uci set network.lan_awg_mark.mark="0x100/0xff00"
uci set network.lan_awg_mark.lookup="200"
uci set network.lan_awg_mark.priority="28900"
uci commit network
/etc/init.d/network reload
'

# === Populate @via_awg (runtime + persistent) ===
ssh router 'nft add element inet fw4 via_awg { 149.154.160.0/20, 91.108.4.0/22, 91.108.8.0/22, 91.108.12.0/22, 91.108.16.0/22, 91.108.20.0/22, 91.108.56.0/22, 91.105.192.0/23, 185.76.151.0/24 }'

ssh router 'cat > /usr/share/nftables.d/ruleset-post/30-telegram-via-awg.nft << "NFTEOF"
add element inet fw4 via_awg { 149.154.160.0/20, 91.108.4.0/22, 91.108.8.0/22, 91.108.12.0/22, 91.108.16.0/22, 91.108.20.0/22, 91.108.56.0/22, 91.105.192.0/23, 185.76.151.0/24 }
NFTEOF'

# === Verify ===
ssh router 'nft list set inet fw4 via_awg'
ssh router 'nft list chain inet fw4 mangle_prerouting | grep counter'
ssh router 'ip rule show | grep 28900'
ssh router 'awg show awg0 latest-handshakes'
```
