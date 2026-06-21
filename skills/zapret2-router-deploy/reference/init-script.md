# init-script — actions, custom.d helpers, OpenWrt integration

`zapret2` is driven by an init script (`init.d/openwrt/zapret2` on OpenWrt, `init.d/sysv` on classic Linux) that starts/stops the nfqws2 daemon(s) and applies/removes the firewall rules. This card documents the action surface, the `init.d/custom.d/` shell-include hook system for advanced deploys, and the OpenWrt integration points (init enable, hotplug, fw3 include, cron).

For the **parameters** the init script consumes (`NFQWS2_OPT`, `MODE_FILTER`, `FLOWOFFLOAD`, etc.), see `config-file.md`. For the **firewall rules** it applies, see `nfqueue-wiring.md`. For the **install/enable procedure**, see `deploy.md`.

## Init script actions

| Action | Does | Evidence |
|--------|------|----------|
| `start` / `stop` / `restart` | full start/stop/restart (daemons + firewall) | verified |
| `start_daemons` / `stop_daemons` / `restart_daemons` | only the nfqws2 daemon(s) | verified |
| `start_fw` / `stop_fw` / `restart_fw` | only the firewall rules | verified |
| `reload_ifsets` (nft) | reload wanif/wanif6/lanif/flowtable sets on iface events | verified |
| `list_ifsets` (nft) | list ifsets | verified |
| `list_table` (nft) | list the zapret2 nft table | verified |

## `init.d/custom.d/` shell includes

For advanced deploy — drop shell scripts in `init.d/custom.d/` to override daemon/firewall construction. The init script sources them and calls the hooks it finds.

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

### Examples

`init.d/custom.d.examples.linux` contains reference custom scripts (e.g. `80-dns-intercept` for Linux DNS-interception deploys). Read those before writing your own.

## OpenWrt integration

```sh
ln -s /opt/zapret2/init.d/openwrt/zapret2 /etc/init.d/zapret2
/etc/init.d/zapret2 enable
ln -s /opt/zapret2/init.d/openwrt/90-zapret2 /etc/hotplug.d/iface/90-zapret2
```

- **fw3 (iptables) on OpenWrt**: firewall managed via the include `firewall.zapret2` + hotplug `90-zapret2`
- **nftables**: reloads wanif/wanif6/lanif/flowtable sets on iface events (via `reload_ifsets`)
- **cron job**: `/opt/zapret2/ipset/get_config.sh` nightly, random every 2 days — refreshes the ip/host lists

## Gotchas

- **`zapret_do_firewall_standard_tpws_rules_*` is a naming artifact** — there is no tpws in zapret2; the helper applies rules for the standard nfqws2 instance
- **`reload_ifsets` only applies on nft** — fw3/iptables path uses different iface-event handling
- **`/etc/init.d/zapret2 enable` does NOT start the service** — it only registers the symlinks for boot. Start explicitly with `start` after wiring
- **Custom.d scripts are sourced** — a syntax error in a custom.d file breaks the whole init script. Validate with `sh -n`