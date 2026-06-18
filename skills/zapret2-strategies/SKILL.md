---
name: zapret2-strategies
description: >-
  zapret2 desync strategy taxonomy (the `--lua-desync` flag family) plus the
  orchestrator and preset/profile model, as a reference pack for the OpenWrt
  router agent (nfqws2 engine, fw4/nftables, apk/opkg). Distills the 10 desync
  techniques (fake, syndata, multisplit, multidisorder, multidisorder_legacy,
  fakedsplit, fakeddisorder, hostfakesplit, tcpseg, oob), the circular
  auto-rotation orchestrator, the preset composition model and the profile
  anatomy, plus the nfqws1->nfqws2 migration map and a progressive testing
  ladder. Use when: desync strategy, desync technique, --lua-desync, nfqws2
  desync, fake, syndata, multisplit, multidisorder, multidisorder_legacy,
  fakedsplit, fakeddisorder, hostfakesplit, tcpseg, oob, seqovl, position
  marker, TCP desynchronization, DPI bypass split fake disorder, nfqws1 to
  nfqws2 migration, desync testing ladder, blockcheck2 strategy selection,
  which desync technique to use, build a desync chain, circular auto-rotation,
  strategy rotation RST retransmission redirect, orchestrator, preset model,
  preset composition, profile model, profile anatomy, multi-profile config,
  YouTube and Discord in one preset, --new profile separator, --lua-desync=pass
  exclusion, desync stacking multiple lua-desync. Do NOT use for: wifi wireless
  setup, sysupgrade firmware, Windows GUI launcher winws2, WinDivert, ZapretHub,
  прямой запуск direct launch GUI, %AppData% preset file, MTProto VPS
  proxy-server, AmneziaWG client, VLESS endpoint hardening, --filter flag,
  --payload flag, --out-range flag, --wf windivert, router install apk opkg,
  nftables NFQUEUE wiring, DPI TSPU theory, JA3 JA4 fingerprint.
---

# zapret2-strategies — desync technique + orchestrator/preset/profile reference pack

Scope: the OpenWrt router agent (nfqws2 engine, fw4/nftables). This pack covers the **desync strategy taxonomy** (the `--lua-desync` flag family), the **circular auto-rotation orchestrator**, and the **preset/profile composition model**. It is reference material for constructing and selecting desync strategies, not a menu to hardcode.

## The path: autodetect, never hardcode

zapret2 **MUST** use autodetection / `blockcheck2` — never hardcode a strategy. The cards here explain *how each technique works* so the agent can read a `blockcheck2` result, translate an operator's goal into the right technique family, and migrate legacy nfqws1 presets. They are not a substitute for running `blockcheck2`. If no strategy works, run autodetection; do not guess from these cards.

## Evidence tags (ternary)

Every claim in every card carries one of three tags (assigned during distillation — the source files carry none):

- `[evidence: verified]` — behavior confirmed by cited upstream Lua source (each card names `lua/zapret-antidpi.lua:NNN` or `lua/zapret-auto.lua:NNN`).
- `[evidence: community-observed]` — empirical practice/model from upstream zapret2 documentation and community presets: not code-confirmed, but widely attested. The agent may rely on it as community practice but should flag the tier when applying to a live router.
- `[evidence: hypothesis]` — DPI-behavior reasoning, effectiveness rationale, or "when to use X" heuristics not confirmed by code or community practice. Treated as **report-and-ask**: the agent surfaces these to the operator and never auto-applies them as fact on a live router.

> **Slice-1 note (tech-debt):** the 10 desync technique cards (issue #2) use the binary subset `{verified, hypothesis}` — `community-observed` was not introduced until issue #3. They are not retroactively rewritten in #3; a future pass may upgrade community-attested claims there to `community-observed`.

## Pack contents

- `reference/fake.md` — fake packet injection (no verdict; fooling mandatory).
- `reference/syndata.md` — SYN-phase payload (phase 0; replaces SYN).
- `reference/multisplit.md` — forward-order multi-point split.
- `reference/multidisorder.md` — reverse-order split + buffer-overwrite seqovl.
- `reference/multidisorder_legacy.md` — per-packet nfqws1-compatible variant.
- `reference/fakedsplit.md` — split surrounded by same-seq fakes (6 packets).
- `reference/fakeddisorder.md` — reverse-order split + fakes (triple confusion).
- `reference/hostfakesplit.md` — hostname-boundary split + generated fake host.
- `reference/tcpseg.md` — range segmentation, no verdict (new in nfqws2).
- `reference/oob.md` — out-of-band byte insertion at SYN (new in nfqws2).
- `reference/circular.md` — orchestrator auto-rotation of strategies on RST/retransmission/redirect failures (new in nfqws2, no nfqws1 analog).
- `reference/preset.md` — preset composition model (header + `--new`-separated profiles), router-reframed.
- `reference/profile.md` — one profile's anatomy (filter AND desync), `--lua-desync=pass` exclusion, desync stacking, ordering.
- `migration.md` — consolidated nfqws1 -> nfqws2 master table (fooling flags + per-technique pos/seqovl/pattern/host args; new nfqws2-only capabilities).
- `testing-ladder.md` — progressive escalation: tcpseg -> dup -> split -> aggressive (fakedsplit/fakeddisorder).

## Operational safety reminder

Any change to a zapret2 config built from these cards (editing `/opt/zapret2/config`, the sole non-UCI exception) must be wrapped in safe-mode: snapshot to `/tmp/rollback/<ts>/`, arm the rollback timer *before* applying, validate with `sh -n /opt/zapret2/config`, restart via the init script, and disarm only on `touch /tmp/agent_ok`. Hypothesis-tagged content is report-and-ask — never auto-apply.

Cross-references between cards preserve the source wikilink graph; each card links its siblings rather than duplicating the per-file comparison matrices.
