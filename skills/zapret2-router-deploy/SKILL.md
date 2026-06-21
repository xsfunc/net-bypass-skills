---
name: zapret2-router-deploy
description: zapret2 router-side deployment pack. Use when installing on OpenWrt
---

# OpenWrt deployment, NFQUEUE wiring, theory, hostlist & blockcheck pack

Scope: OpenWrt router agent. Covers: installation, nftables/NFQUEUE wiring, debugging interception, hostlist/ipset/nftset management, and blockcheck2 autodetection.

**Cross-skill routing:** 
- load `/openwrt-ops` before any router-facing step
- load `/zapret2-strategies` for desync technique semantics
- load `/zapret2-engine-reference` for engine flag syntax

## The path: autodetect, never invent

zapret2 **MUST NOT** invent a strategy from scratch. Use either `blockcheck2` autodetection **or** a community preset known to work for the target ISP/region; both are evidence-based paths. A community preset is a starting point, not a drop-in config — validate it with operational testing before applying. If a previously-working strategy stops working, the DPI evolved: run `blockcheck2` or try a fresher community preset.

## Router deploy checklist

1. **Load `/openwrt-ops`.** No router-facing command runs without safe-mode.
2. **Install zapret2.** Canonical path is `install_easy.sh` per `deploy.md`.
3. **Enable autostart:** `/etc/init.d/zapret2 enable`.
4. **Wire NFQUEUE** in `/etc/nftables.d/` per `nfqueue-wiring.md`.
5. **Disable flow offload** (software and hardware) per `nfqueue-wiring.md`.
6. **Choose a strategy** — run `blockcheck2` or use a validated community preset (`blockcheck.md`).
7. **Apply `/opt/zapret2/config`** under safe-mode (`sh -n` validate).
8. **Scope traffic** with hostlist/ipset or dnsmasq nftset per `hostlist-ipset-nftset.md` if needed.

## Pack contents

- `reference/deploy.md` — Covers installer scripts (`install_easy.sh`/`install_bin.sh`/`install_prereq.sh`/`uninstall_easy.sh`), third-party installers (`zapret4rocket`, `remittor/zapret-openwrt`) marked `community-observed` with audit warnings, and upgrade procedure.
- `reference/nfqueue-wiring.md` — fw4 custom-rule include for NFQUEUE, the **canonical pattern** from the upstream manual.
- `reference/config-file.md` — `/opt/zapret2/config` parameter reference: enable/ports/packet counts, `NFQWS2_OPT` + `<HOSTLIST>` placeholders, `MODE_FILTER`, marks, `POSTNAT`, `FLOWOFFLOAD`, `DISABLE_*`, OpenWrt/classic-Linux iface selection, init-script hooks, `GETLIST`, autohostlist, ipset, ip2net, mdig, misc with defaults + evidence tags.
- `reference/init-script.md` — init-script actions (`start`/`stop`/`restart`, `*_daemons`, `*_fw`, `reload_ifsets`, `list_ifsets`, `list_table`), `init.d/custom.d/` shell-include hooks + helper catalogue (with the `zapret_do_firewall_standard_tpws_rules_*` naming-artifact note), and OpenWrt integration.
- `reference/list-management.md` — ipset list-fetching infrastructure (`get_*.sh` catalogue + `GETLIST`), standard list files table, ipban system, `ip2net` utility flags + algorithm, `mdig` utility flags + DoH example. The *production* side of the lists that `hostlist-ipset-nftset.md` consumes.
- `reference/theory.md` — the networking theory a debugger needs, distilled from the 7-part upstream tutorial: L2-L7 stack, TCP seq/ack/MSS/window/retransmission, NFQUEUE verdicts (PASS/DROP/MODIFY), dissect/reconstruct, payload types & reasm/replay (concept only — types table lives in `zapret2-engine-reference`), Lua pipeline (instances, args, cutoff), and start/cutoff (why `n2<n3` lands on ClientHello when empty ACKs aren't intercepted).
- `reference/hostlist-ipset-nftset.md` — domain and IP filter management (`--hostlist`/`--hostlist-exclude`/`--hostlist-domains`, `--ipset`/`--ipset-exclude`/`--ipset-ip`, `--hostlist-auto*` family), dnsmasq nftset wiring for domain-scoped bypass, hostlist categories, the black hostlist, and the `ipset-discord` raw CIDR list flagged "needs curation" (duplicates, mixed ASNs — never load as a ready-made rule).
- `reference/blockcheck.md` — `blockcheck2` autodetection procedure, the **full env-var + test-variable tables + test-structure + custom-test-files reference**, reading the log, the "no strategy works" decision tree, and the `zapret_not_working` troubleshooting framework (DPI update, IP-block vs DPI-block vs throttle, local conflicts, multi-CDN sites).