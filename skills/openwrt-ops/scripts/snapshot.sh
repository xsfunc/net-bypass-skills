#!/bin/sh
# Safe-mode snapshot for the OpenWrt router agent (§6).
# Run on the router. Creates /tmp/rollback/<ts>/, captures uci + /etc/config +
# /opt/zapret2/config + nft ruleset (audit-only) to RAM, and prints the rollback
# dir on stdout. Usage: RB=$(sh snapshot.sh)
set -eu

TS=$(date +%Y%m%d-%H%M%S)
RB=/tmp/rollback/$TS
mkdir -p "$RB"

for c in network dhcp firewall https-dns-proxy; do
  uci show "$c" > "$RB/uci-$c.txt" 2>/dev/null || true
done
cp -a /etc/config "$RB/etc-config"
cp -a /opt/zapret2/config "$RB/zapret2-config" 2>/dev/null || true
nft list ruleset > "$RB/nft-ruleset.txt" 2>/dev/null || true
echo "$TS" > "$RB/TS"

echo "$RB"
