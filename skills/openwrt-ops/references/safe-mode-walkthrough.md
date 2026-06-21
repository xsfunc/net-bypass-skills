# Safe-mode walkthrough — integrated example

Canonical end-to-end: add `example.com` to dnsmasq nftset `zapret_v4` (`apk + constrained` corner, ash-compatible). Each step ends on a checkable completion criterion — do not advance until it holds.

## A. dnsmasq nftset add

```sh
# 1. Preflight
df -h / /tmp; free -m; cat /etc/openwrt_release
# 2. nftset probe
dnsmasq --version 2>&1 | tr ' ' '\n' | grep -i nft
apk info nftables-json 2>/dev/null && echo OK || echo MISSING   # MISSING → §2 ipset fallback or stop
# 3. Snapshot
RB=$(sh scripts/snapshot.sh)     # or inline its body over SSH
# 4. UCI edit
uci add_list dhcp.@dnsmasq[0].nftset='/example.com/4#zapret_v4'; uci commit dhcp
# 5. Arm timer FIRST
( sleep 300 && /tmp/agent-revert.sh "$RB" ) &
echo $! > "$RB/revert.pid"
# 6. Apply
/etc/init.d/dnsmasq reload
# 7. Validate post-reload
/etc/init.d/dnsmasq status && logread | tail -20   # not running → revert + stop
# 8. Operator confirms
touch /tmp/agent_ok
# 9. Disarm
kill "$(cat "$RB/revert.pid")" 2>/dev/null; rm -f /tmp/agent_ok
# 10. Audit
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | uci add_list | dhcp.@dnsmasq[0].nftset | OK | example.com -> 4#zapret_v4" >> /tmp/agent-audit.log
```

Per-step completion criteria:

| Step | Done when |
|------|-----------|
| 1 Preflight | PM axis + HW axis classified; install-target free ≥1 MB for the planned change |
| 2 nftset probe | nftset support confirmed OK, OR ipset-fallback/stop decision made and logged |
| 3 Snapshot | `$RB` printed and non-empty; `uci-*.txt` + `etc-config/` present under `$RB` |
| 4 UCI edit | `uci show dhcp.@dnsmasq[0].nftset` shows the new entry; `uci commit dhcp` returned 0 |
| 5 Arm timer | `$RB/revert.pid` written and holds a live PID |
| 6 Apply | `dnsmasq reload` returned 0 |
| 7 Validate | `dnsmasq status` = running AND last 20 logread lines show no fatal error — else revert + stop |
| 8 Operator confirms | `/tmp/agent_ok` exists (touched by operator) |
| 9 Disarm | revert PID killed; `/tmp/agent_ok` removed |
| 10 Audit | new line appended to `/tmp/agent-audit.log` with ISO8601 + action + result |

Timer armed before reload so a DNS breakage still reverts. No `jq` — jsonfilter only if needed.

## B. Delta — zapret2 config edit

`/opt/zapret2/config`, sole non-UCI exception per §0.6. Compose desync from `blockcheck2` + `$zapret2-strategies`. Replace steps 4–7 of walkthrough A with:

```sh
# 4. Back up the config you are about to edit
cp -a /opt/zapret2/config "$RB/zapret2-config.precopy"
# 5. Edit /opt/zapret2/config (desync from blockcheck2 + $zapret2-strategies)
#    ... apply edits ...
# 6. Validate syntax BEFORE arming
sh -n /opt/zapret2/config || { echo "syntax fail"; exit 1; }
# 7. Apply: restart via init script
/etc/init.d/zapret2 restart
# 8. Validate post-restart
ps w | grep -q '[n]fqws2' && logread | tail -20   # no nfqws2 process -> revert + stop
```

Per-step completion criteria:

| Step | Done when |
|------|-----------|
| 4 Back up | `$RB/zapret2-config.precopy` exists and matches the pre-edit file |
| 5 Edit | intended desync lines present in `/opt/zapret2/config` |
| 6 Validate | `sh -n /opt/zapret2/config` returned 0 — else abort, do not arm |
| 7 Apply | `/etc/init.d/zapret2 restart` returned 0 |
| 8 Validate | `nfqws2` process present AND last 20 logread lines show no fatal error — else revert + stop |

`sh -n` runs before arming so a syntax error never reaches the apply step. The safe-mode timer arming + operator-confirm + disarm + audit steps (5/8/9/10 of walkthrough A) still apply around this delta — only 4–7 are replaced.

## Corner substitutions

- (PM) on `opkg`, replace `apk info nftables-json` with `opkg list-installed nftables-json`; the UCI/safe-mode/timer steps are PM-agnostic.
- (HW) `capable` only relaxes the heavy-runtime ban and install-target threshold — the procedure is identical on capable HW.
- `opkg`-only is normal on pre-25: do not abort the PM detection when only `opkg` is present.
