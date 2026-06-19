---
name: zapret2-router-deploy
description: >-
  zapret2 router-side deployment pack for the OpenWrt router agent (fw4/nftables,
  apk 25.x / opkg pre-25). Distills the canonical tarball install to /opt/zapret2
  with init-script enablement, the nftables/NFQUEUE wiring that makes nfqws2
  actually intercept traffic (fw4 custom rules, queue-num, conntrack specifics,
  the flow-offload conflict that silently breaks interception), the networking
  theory a debugger needs (L2-L7, TCP seq/ack/MSS, NFQUEUE verdicts,
  dissect/reconstruct, payload types, Lua pipeline, start/cutoff and why n2<n3
  lands on ClientHello), the hostlist/ipset/nftset management model for scoping
  bypass to specific domains via dnsmasq nftset, and the blockcheck2
  autodetection procedure for when no hardcoded strategy works. Use when:
  install zapret2 on OpenWrt, apk install zapret2, opkg install zapret2, tarball
  /opt/zapret2, init script /etc/init.d/zapret2, nfqws2 not intercepting,
  NFQUEUE rule missing, nftables dnat_nf_queue, fw4 custom rule, queue-num,
  flow offload conflict, software offload nfqws2, hardware offload nfqws2,
  conntrack established not intercepted, ct info mark, why zapret2 not working,
  L2 L3 L4 L7 network layers, TCP seq ack MSS window, NFQUEUE verdicts PASS DROP
  MODIFY, dissect reconstruct, Lua pipeline instances, start cutoff n2 n3
  ClientHello, dnsmasq nftset, hostlist domain filter, ipset IP filter,
  --hostlist --ipset --hostlist-exclude, hostlist-auto, black hostlist,
  blockcheck2 autodetection, autodetect strategy, zapret not working
  troubleshooting. Do NOT use for: which desync technique to use, --lua-desync
  function semantics, fake syndata multisplit multidisorder, position markers,
  seqovl, orchestrator circular auto-rotation, preset composition, profile
  anatomy, --filter-tcp --filter-l7 --payload --out-range --blob --lua-init
  --ctrack-disable fooling flags ip_ttl ip_autottl tcp_md5 argument ordering,
  DPI TSPU theory, JA3 JA4 fingerprint, Siberian scheme, wifi wireless setup,
  sysupgrade firmware, Windows GUI launcher winws2, WinDivert, MTProto VPS
  proxy-server, AmneziaWG client, VLESS endpoint hardening, Keenetic, dnsmasq
  configuration outside zapret scope, https-dns-proxy setup, general package
  management outside zapret2 install.
---

# zapret2-router-deploy — OpenWrt deployment, NFQUEUE wiring, theory, hostlist & blockcheck pack

Scope: the OpenWrt router agent (nfqws2 engine, fw4/nftables, apk 25.x / opkg pre-25). This pack covers **router-side deployment of zapret2**: install procedure, nftables/NFQUEUE wiring, the networking theory needed to debug interception, hostlist/ipset/nftset management, and blockcheck2 autodetection. It is procedural and conceptual reference material for getting nfqws2 installed and intercepting on the router — **strategy selection** (which `--lua-desync` function to compose) is `zapret2-strategies`'s job; **engine flag syntax** is `zapret2-engine-reference`'s job; **generic router ops** (safe-mode, PM commands, UCI, dnsmasq-full swap) is `openwrt-ops`'s job.

## The path: autodetect, never hardcode

zapret2 **MUST** use autodetection / `blockcheck2` — never hardcode a strategy (openwrt-ops §11). This pack explains *how to install zapret2, wire NFQUEUE, and debug interception* so the agent can get to the point where `blockcheck2` can run. It is not a substitute for `blockcheck2`; if no strategy works after wiring is correct, run autodetection (see `reference/blockcheck.md`). Do not guess a strategy from this pack.

## Evidence tags (ternary)

Every claim in every reference file carries one of three tags (assigned during distillation — the source files carry none):

- `[evidence: verified]` — behavior confirmed by cited upstream code (e.g. `nfq2/nfqws.c:NNN`), by code-defined nftables/fw4 syntax, or by direct quotation from `openwrt-ops` operational manual sections.
- `[evidence: community-observed]` — empirical practice from upstream zapret2 documentation and community deployment patterns: not code-confirmed here, but widely attested. The agent may rely on it as community practice but should flag the tier when applying to a live router.
- `[evidence: hypothesis]` — behavior reasoning or "why X breaks" heuristics not confirmed by code or community practice. Treated as **report-and-ask**: the agent surfaces these to the operator and never auto-applies them as fact on a live router.

## Pack contents

- `reference/deploy.md` — canonical tarball install to `/opt/zapret2` for both PM axes (apk 25.x / opkg pre-25), init-script enablement, layout, and third-party installers (`zapret4rocket`, `remittor/zapret-openwrt`) marked `community-observed` with audit warnings.
- `reference/nfqueue-wiring.md` — fw4 custom-rule include for NFQUEUE, queue-num, conntrack specifics (`ct info` mark, why established connections bypass interception), the **flow-offload conflict** (the most common silent-break cause), PM-axis fw3-vs-fw4 split, and a 5-step "rule present, packets missing" troubleshooting matrix.
- `reference/theory.md` — the networking theory a debugger needs, distilled from the 7-part upstream tutorial: L2-L7 stack, TCP seq/ack/MSS/window/retransmission, NFQUEUE verdicts (PASS/DROP/MODIFY), dissect/reconstruct, payload types & reasm/replay (concept only — types table lives in `zapret2-engine-reference`), Lua pipeline (instances, args, cutoff), and start/cutoff (why `n2<n3` lands on ClientHello when empty ACKs aren't intercepted).
- `reference/hostlist-ipset-nftset.md` — domain and IP filter management (`--hostlist`/`--hostlist-exclude`/`--hostlist-domains`, `--ipset`/`--ipset-exclude`/`--ipset-ip`, `--hostlist-auto*` family), dnsmasq nftset wiring for domain-scoped bypass, hostlist categories, the black hostlist, and the `ipset-discord` raw CIDR list flagged "needs curation" (duplicates, mixed ASNs — never load as a ready-made rule).
- `reference/blockcheck.md` — `blockcheck2` autodetection procedure, reading the log, the "no strategy works" decision tree, and the `zapret_not_working` troubleshooting framework (DPI update, IP-block vs DPI-block vs throttle, local conflicts, multi-CDN sites).

## Operational safety reminder

Any router-facing change described in this pack (install, nftables edit, dnsmasq nftset change, zapret2 config edit, blockcheck run that modifies state) must be wrapped in safe-mode: snapshot to `/tmp/rollback/<ts>/`, arm the rollback timer *before* applying, validate with `nft -c -f` (nftables) / `sh -n /opt/zapret2/config` (zapret), apply, validate post-apply, and disarm only on `touch /tmp/agent_ok`. Hypothesis-tagged content is report-and-ask — never auto-applied. The full procedures (snapshot script, revert script, timer arming, audit log format, PM commands, validation matrix, forbidden commands) live in `openwrt-ops` — load `$openwrt-ops` before any router-facing step from this pack. *(mirrors openwrt-ops §6 safe-mode/rollback, §1 preflight, §7 validation, §10 audit as of 2026-06-19)*

Cross-references between reference files preserve the source wikilink graph; each card links its siblings and the neighbouring skills (`zapret2-strategies` for desync technique semantics, `zapret2-engine-reference` for flag syntax, `openwrt-ops` for generic router ops) rather than duplicating their content.
