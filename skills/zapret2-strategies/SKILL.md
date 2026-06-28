---
name: zapret2-strategies
description: desync strategy taxonomy (`--lua-desync`). Distills the 10 desync techniques (fake, syndata, multisplit, multidisorder, multidisorder_legacy, fakedsplit, fakeddisorder, hostfakesplit, tcpseg, oob), nfqws1->nfqws2 migration map and a progressive testing ladder.
---

# zapret2-strategies

Scope: nfqws2 engine, fw4/nftables, covers the **desync strategy taxonomy** (`--lua-desync`), the **circular auto-rotation orchestrator**, and the **preset/profile composition model**. It is reference material for constructing and selecting desync strategies, not a menu to hardcode.

## The path: autodetect, never hardcode

zapret2 **MUST** use autodetection / `blockcheck2` — never hardcode a strategy. The cards here explain *how each technique works* so the agent can read a `blockcheck2` result, translate an operator's goal into the right technique family, and migrate legacy nfqws1 presets. They are not a substitute for running `blockcheck2`. If no strategy works, run autodetection; do not guess from these cards.

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
- `reference/drop.md` — cancel the current packet (pairs with `send`/`tcpseg`/`fake` to replace the original).
- `reference/send.md` — emit the current dissect with modifiers (no verdict; pair with `drop`).
- `reference/pktmod.md` — modify the current dissect in place (no send; `VERDICT_MODIFY`).
- `reference/luaexec.md` — run arbitrary Lua per packet (dynamic blobs, custom verdict logic; new in nfqws2).
- `reference/detect-payload-str.md` — content-based custom payload-type detector (new in nfqws2).
- `reference/http-fooling.md` — `http_hostcase`/`http_domcase`/`http_methodeol`/`http_unixeol` HTTP header tampering (nginx-only gotchas).
- `reference/wssize.md` — `wssize` + `wsize` TCP window-size manipulation (zero-phase; must precede `syndata`).
- `reference/misc-desync.md` — `tls_client_hello_clone`/`rst`/`udplen`/`dht_dn`/`synack`/`synack_split` (server-side noted for `synack*`/`wsize`).
- `reference/circular.md` — orchestrator auto-rotation of strategies on RST/retransmission/redirect failures (new in nfqws2, no nfqws1 analog).
- `reference/orchestrators.md` — `repeater`/`condition`/`per_instance_condition`/`stopif` orchestrators + iff functions (new in nfqws2, no nfqws1 analog).
- `reference/preset.md` — preset composition model (header + `--new`-separated profiles), router-reframed.
- `reference/profile.md` — one profile's anatomy (filter AND desync), `--lua-desync=pass` exclusion, desync stacking, ordering.
- `reference/byedpi-migration.md` — byedpi flag reference + byedpi -> nfqws2 migration map and gaps/divergences
- `migration.md` — consolidated nfqws1 -> nfqws2 master table (fooling flags + per-technique pos/seqovl/pattern/host args; new nfqws2-only capabilities).
- `testing-ladder.md` — progressive escalation: tcpseg -> dup -> split -> aggressive (fakedsplit/fakeddisorder).

## Operational safety reminder

Any change to a zapret2 config built from these cards (editing `/opt/zapret2/config`) must be validated with `sh -n /opt/zapret2/config`, restart via the init script. Hypothesis-tagged content is report-and-ask — never auto-apply.
