#!/bin/sh
# Generic auto-rollback for the OpenWrt router agent (§6).
# Deploy once per session to /tmp/agent-revert.sh on the router (sh -n it first),
# then arm via:
#   ( sleep 300 && /tmp/agent-revert.sh "$RB" ) &
#   echo $! > "$RB/revert.pid"
# Usage: /tmp/agent-revert.sh <RB>
# Restores configs, then reloads network + firewall (fw4 rebuilds nft from
# /etc/config/firewall — nft-ruleset.txt snapshot is audit-only) and restarts
# dnsmasq/https-dns-proxy/zapret2. network/firewall use reload (keeps SSH session);
# daemons use restart (full state reset for emergency revert).
set -eu

RB=$1
cp -a "$RB/etc-config/." /etc/config/
cp -a "$RB/zapret2-config" /opt/zapret2/config 2>/dev/null || true
/etc/init.d/network reload
/etc/init.d/firewall reload
/etc/init.d/dnsmasq restart
/etc/init.d/https-dns-proxy restart
/etc/init.d/zapret2 restart 2>/dev/null || true
echo "AUTO-ROLLBACK from $RB" >> /tmp/agent-audit.log
