---
name: zapret2-engine-reference
description: >-
  zapret2 nfqws2 engine flag and argument-syntax reference pack for the OpenWrt
  router agent (fw4/nftables). Distills the profile-scope filter flags
  (--filter-l3/tcp/udp/l7), the payload-type filter (--payload), the packet-range
  filter (--out-range/--in-range), the binary blob model (--blob, tls_mod,
  standard blobs), the per-desync fooling flags (ip_ttl, ip_autottl, ip6_hopbyhop,
  tcp_md5, tcp_seq, tcp_ack, badsum, tcp_flags_unset), the preset header globals
  (--lua-init, --ctrack-disable, --ipcache-lifetime, --ipcache-hostname), and the
  argument-ordering rules (--payload/--out-range must precede the --lua-desync
  they scope). Use when: --filter-tcp, --filter-udp, --filter-l7, --filter-l3,
  --payload flag, payload types, tls_client_hello, http_req, quic_initial,
  --out-range, --in-range, packet range, n d s b prefix, data packet counting,
  --blob flag, blob syntax, tls_mod, fooling flags, ip_ttl, ip_autottl, tcp_md5,
  tcp_seq, tcp_ack, badsum, --lua-init, --ctrack-disable, --ipcache-lifetime,
  --ipcache-hostname, argument ordering, payload before lua-desync, out-range
  before lua-desync, filter AND semantics, n vs d prefix. Do NOT use for: which
  desync technique to use, --lua-desync function semantics, fake syndata
  multisplit multidisorder fakedsplit fakeddisorder hostfakesplit tcpseg oob,
  position markers pos midsld sld endhost, seqovl, seqovl_pattern, repeats,
  orchestrator circular auto-rotation, preset composition model, --new profile
  separator, profile anatomy, --lua-desync=pass, desync stacking, router install
  apk opkg, nftables NFQUEUE wiring, hostlist ipset nftset management,
  blockcheck, DPI TSPU theory, JA3 JA4 fingerprint, wifi wireless, sysupgrade,
  Windows GUI launcher winws2, WinDivert, MTProto L7 recognition mtproto_initial,
  AmneziaWG client, VLESS endpoint hardening.
---

# zapret2-engine-reference — nfqws2 flag & argument-syntax reference pack

Scope: the OpenWrt router agent (nfqws2 engine, fw4/nftables). This pack covers the **engine flag and argument-syntax reference** — the profile-scope filters, payload-type filter, packet-range filter, blob model, per-desync fooling flags, preset header globals, and argument-ordering rules. It is reference material for constructing a *syntactically correct* `NFQWS2_OPT` config line; **strategy selection** (which `--lua-desync` function to use) is `zapret2-strategies`'s job.

## The path: autodetect shapes the config, this pack is the syntax

zapret2 **MUST** use autodetection / `blockcheck2` — never hardcode a strategy. The cards here explain *what each flag means and how it must be ordered* so the agent can translate a `blockcheck2` result and an operator's goal into a valid config line. They are not a substitute for running `blockcheck2`, and they do not pick a technique — for technique semantics see `zapret2-strategies`.

## Evidence tags (ternary)

Every claim in every card carries one of three tags (assigned during distillation — the source files carry none):

- `[evidence: verified]` — behavior confirmed by cited upstream code (each card names `nfq2/<file>.c:NNN` or `lua/zapret-lib.lua:NNN`) or by code-defined flag syntax.
- `[evidence: community-observed]` — empirical practice/model from upstream zapret2 documentation and community presets: not code-confirmed, but widely attested. The agent may rely on it as community practice but should flag the tier when applying to a live router.
- `[evidence: hypothesis]` — behavior reasoning or heuristics not confirmed by code or community practice. Treated as **report-and-ask**: the agent surfaces these to the operator and never auto-applies them as fact on a live router.

## Pack contents

- `reference/filter.md` — profile-scope transport/protocol filters (`--filter-l3/tcp/udp/l7`), AND-semantics, TCP/UDP mutual exclusion; `--ipset`/`--hostlist` as filter primitives (management → `zapret2-router-deploy`).
- `reference/payload.md` — payload-type filter (`--payload`), full type list, default `known`, `~`-inversion, comma-lists, `l7proto` vs `l7payload`.
- `reference/out-range.md` — packet-range filter (`--out-range`/`--in-range`), `n/d/s/b/a/x` prefixes, `-`/`<` separators, data-packet counting; `d`-stable-vs-`n` gotcha.
- `reference/blob.md` — binary blob model (`--blob=name:@file|0xhex|+off@file`), standard blobs, `tls_mod` function (signature, startup vs on-the-fly mutation).
- `reference/fooling.md` — per-desync fooling flags (`ip_ttl`, `ip_autottl`, `ip6_*`, `tcp_seq/ack/ts/md5`, `tcp_flags_*`, `tcp_ts_up`, `badsum`, `fool=`) + nfqws1 combonyms pointer.
- `reference/core-flags.md` — preset header globals (`--lua-init`, `--ctrack-disable`, `--ipcache-*`, `--blob` one-liner) + Windows-only `--wf-*` boundary marker (router-safety).
- `reference/arg-ordering.md` — argument-ordering rules: `--payload`/`--out-range`/`--in-range` must precede the `--lua-desync` they scope; scope table; correct vs invalid example.

## Operational safety reminder

Any change to a zapret2 config built from these flags (editing `/opt/zapret2/config`, the sole non-UCI exception) must be wrapped in safe-mode: snapshot to `/tmp/rollback/<ts>/`, arm the rollback timer *before* applying, validate with `sh -n /opt/zapret2/config`, restart via the init script, and disarm only on `touch /tmp/agent_ok`. Hypothesis-tagged content is report-and-ask — never auto-applied. *(mirrors AGENTS.md §6 safe-mode/rollback, §7 validation, §10 audit as of 2026-06-18)*

Cross-references between cards preserve the source wikilink graph; each card links its siblings and the neighbouring skills (`zapret2-strategies` for technique semantics, `zapret2-router-deploy` for install/nftables/hostlist-ipset management) rather than duplicating their content.
