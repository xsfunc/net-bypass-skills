# init-script — actions, custom.d helpers, OpenWrt integration

`zapret2` is driven by an init script (`init.d/openwrt/zapret2` on OpenWrt, `init.d/sysv` on classic Linux) that starts/stops the nfqws2 daemon(s) and applies/removes the firewall rules. This card documents the action surface, the `init.d/custom.d/` shell-include hook system for advanced deploys, and the OpenWrt integration points (init enable, hotplug, fw3 include, cron). `[evidence: verified]` (script actions are code-defined in `init.d/openwrt/zapret2`); `[evidence: community-observed]` (custom.d helper conventions).

For the **parameters** the init script consumes (`NFQWS2_OPT`, `MODE_FILTER`, `FLOWOFFLOAD`, etc.), see `config-file.md`. For the **firewall rules** it applies, see `nfqueue-wiring.md`. For the **install/enable procedure**, see `deploy.md` Step 5.

## Init script actions

Main executable `zapret2`; action in `$1`. `[evidence: verified]` (action dispatch in `init.d/openwrt/zapret2`).

| Action | Does | Evidence |
|--------|------|----------|
| `start` / `stop` / `restart` | full start/stop/restart (daemons + firewall) | verified |
| `start_daemons` / `stop_daemons` / `restart_daemons` | only the nfqws2 daemon(s) | verified |
| `start_fw` / `stop_fw` / `restart_fw` | only the firewall rules | verified |
| `reload_ifsets` (nft) | reload wanif/wanif6/lanif/flowtable sets on iface events | verified |
| `list_ifsets` (nft) | list ifsets | verified |
| `list_table` (nft) | list the zapret2 nft table | verified |

`[evidence: verified]` (action names + dispatch in `init.d/openwrt/zapret2`).

## `init.d/custom.d/` shell includes

For advanced deploy — drop shell scripts in `init.d/custom.d/` to override daemon/firewall construction. The init script sources them and calls the hooks it finds. `[evidence: community-observed]` (custom.d helper conventions).

### Hooks to implement

| Hook | Purpose | Evidence |
|------|---------|----------|
| `zapret_custom_daemons` | construct/start custom daemons | community-observed |
| `zapret_custom_firewall` | custom firewall entry (dispatches to nft/ipt) | community-observed |
| `zapret_custom_firewall_nft` | custom nftables firewall rules | community-observed |
| `zapret_custom_firewall_nft_flush` | flush the custom nftables rules | community-observed |

### Helpers available

| Helper | Purpose | Evidence |
|--------|---------|----------|
| `alloc_dnum` / `alloc_qnum` | allocate daemon/queue numbers | community-observed |
| `do_nfqws` | construct an nfqws2 invocation | community-observed |
| `filter_apply_hostlist_target` | apply hostlist target filter to a rule | community-observed |
| `standard_mode_daemons` | start the standard nfqws2 instance(s) | community-observed |
| `fw_nfqws_post` / `fw_nfqws_pre` | add post/pre NFQUEUE rules | community-observed |
| `zapret_do_firewall_standard_tpws_rules_ipt` / `_nft` | **naming artifact** — applies rules for the **standard nfqws2 instance**, not tpws (no tpws in zapret2) | community-observed |
| `filter_apply_ipset_target` | apply ipset target filter to a rule | community-observed |
| `reverse_nfqws_rule` / `reverse_nfqws_rule_stream` | reverse a NFQUEUE rule (for the reply-direction pre chain) | community-observed |
| `ipt` / `ipta` / `ipt_del` / `ipt6` / `ipt_first_packets` / `ipt_port_ipset` | iptables helpers (fw3 path; out of scope on fw4) | community-observed |
| `nft_fw_nfqws_post` / `nft_fw_nfqws_pre` | nftables NFQUEUE rule helpers | community-observed |
| `nft_filter_apply_ipset_target` | nftables ipset target filter | community-observed |
| `nft_reverse_nfqws_rule` | nftables reply-direction reversal | community-observed |
| `nft_add_chain` / `nft_delete_chain` / `nft_create_set` / `nft_del_set` / `nft_flush_set` / `nft_set_exists` / `nft_add_set_element` / `nft_add_set_elements` / `nft_flush_chain` / `nft_add_rule` / `nft_insert_rule` | nftables chain/set/rule primitives | community-observed |
| `nft_first_packets` | nftables connbytes-limiter expression helper | community-observed |

`[evidence: community-observed]` (helper names + conventions in `init.d/custom.d.examples.linux`).

### Examples

`init.d/custom.d.examples.linux` contains reference custom scripts (e.g. `80-dns-intercept` for Linux DNS-interception deploys). Read those before writing your own. `[evidence: community-observed]` (examples ship with the tarball).

## OpenWrt integration

`[evidence: verified]` (integration commands follow standard OpenWrt init-script + hotplug conventions); `[evidence: community-observed]` (cron schedule widely attested).

```sh
ln -s /opt/zapret2/init.d/openwrt/zapret2 /etc/init.d/zapret2
/etc/init.d/zapret2 enable
ln -s /opt/zapret2/init.d/openwrt/90-zapret2 /etc/hotplug.d/iface/90-zapret2
```

- **fw3 (iptables) on OpenWrt**: firewall managed via the include `firewall.zapret2` + hotplug `90-zapret2`. `[evidence: verified]` (fw3 include + hotplug convention)
- **nftables**: reloads wanif/wanif6/lanif/flowtable sets on iface events (via `reload_ifsets`). `[evidence: verified]` (action in `init.d/openwrt/zapret2`)
- **cron job**: `/opt/zapret2/ipset/get_config.sh` nightly, random every 2 days — refreshes the ip/host lists. `[evidence: community-observed]` (schedule widely attested; see `list-management.md`)

## Gotchas

- **`zapret_do_firewall_standard_tpws_rules_*` is a naming artifact** — there is no tpws in zapret2; the helper applies rules for the standard nfqws2 instance. Read it as "standard daemon rules". `[evidence: community-observed]`
- **`reload_ifsets` only applies on nft** — fw3/iptables path uses different iface-event handling. `[evidence: verified]`
- **`/etc/init.d/zapret2 enable` does NOT start the service** — it only registers the symlinks for boot. Start explicitly with `start` after wiring. `[evidence: verified]` (standard OpenWrt init semantics)
- **Custom.d scripts are sourced** — a syntax error in a custom.d file breaks the whole init script. Validate with `sh -n` before dropping one in (openwrt-ops §7). `[evidence: hypothesis]` (operator-safety policy; the init script does not catch source errors gracefully)

## Cross-references

`config-file.md` (parameters the init script consumes); `nfqueue-wiring.md` (the firewall rules `start_fw` applies); `deploy.md` (canonical `install_easy.sh` performs init enable/hotplug/cron automatically; fallback Step 5 covers manual init-script deployment + enable); `list-management.md` (`get_config.sh` cron job, `GETLIST`); `openwrt-ops` §6 (safe-mode for restart/reload), §7 (`sh -n` validation for custom.d), §11 (no hardcoded strategy — applies to custom.d constructions too).

## Source mapping

Upstream code: `init.d/openwrt/zapret2` (action dispatch, `reload_ifsets`/`list_ifsets`/`list_table`); `init.d/sysv` (classic-Linux equivalent); `init.d/custom.d.examples.linux` (reference custom scripts + helper conventions). Upstream documentation: `docs/manual.md` §"init scripts" (action reference + custom.d hooks).
