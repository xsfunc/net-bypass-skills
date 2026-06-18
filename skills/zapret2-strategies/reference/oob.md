# oob — out-of-band byte insertion at SYN (new in nfqws2)

## Lua signature

`function oob(ctx, desync)` — `lua/zapret-antidpi.lua:1084-1176` (helpers in `lua/zapret-lib.lua:1148-1192`) `[evidence: verified]` CLI: `--lua-desync=oob[:arg=...]`  (**`--in-range=-s1` mandatory**)

## What it does

Inserts a single out-of-band (OOB) byte into the first data packet by shifting the TCP sequence at SYN/first-ACK. The server TCP stack discards the OOB byte; DPI may not. Phase 1: intercept SYN, shift `th_seq -= 1`. Phase 2: insert the OOB byte (`TH_URG` + `th_urp`) into the first data packet. Phase 3: cutoff; incoming packets get `th_ack += 1` to compensate so the client OS is not confused `[evidence: verified]`. **New in nfqws2 — no nfqws1 equivalent** (tpws `--split-pos=.. --oob` is close but not identical).

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `char` | 1-byte | none | OOB byte as a character. | verified |
| `byte` | 0..255 | none | OOB byte as a number. | verified |
| `urp` | b/e/marker | `b` | Urgent pointer mode. `b` (th_urp=0) works **only on Linux servers**; `e` generally useless for bypass; markers use `th_urp=pos+1` (RFC 1122). | verified |

**No `dir`, no `payload` filter** — once seq is shifted at SYN, the function cannot bail or seq numbers desync and TCP breaks. Fooling is limited in value here (it applies to the **real** OOB packet — if the server drops it, data is lost); use safe fooling (`tcp_ts_up`, IPv6 ext headers). ipfrag supported.

## Verdict & protocol

- Verdict: `VERDICT_MODIFY` (SYN/ACK seq shift) / `VERDICT_DROP` (data packet replaced by the OOB version). `[evidence: verified]`
- Protocol: TCP only. Requires conntrack (`desync.track`); must be applied from the very first SYN (else cutoff). `[evidence: verified]`

## Gotchas

- **`--in-range=-s1` is MANDATORY** for HTTP/TLS — oob must see the incoming SYN-ACK for ack correction; without it oob refuses (cutoff). `[evidence: verified]`
- **`urp=b` (th_urp=0) works ONLY on Linux servers** — Windows/BSD break (RFC 1122 says th_urp=0 is invalid). `urp=e` is generally useless. Markers (`th_urp=pos+1`, RFC 1122) are portable. `[evidence: verified]`
- **Incompatible** with `multisplit`/`multidisorder`/`fakedsplit`/`fakeddisorder` in the same stream — they send payload copies without OOB/seq-shift awareness. "split + OOB" is not achievable by combination (unlike tpws). `[evidence: verified]`
- **Lasting desync:** between SYN (seq shift) and first payload (OOB insert) several packets pass. If a profile switches mid-handshake (e.g. `--ipcache-hostname` resolves), the new profile **must also contain oob** or TCP breaks. Duplicate oob across all profiles that may take over. `[evidence: verified]`
- Hostlist filtering only via `--ipcache-hostname`; OOB byte is exactly 1 byte. `[evidence: verified]`

## nfqws1 → nfqws2 migration

**N/A — new in nfqws2, no nfqws1 equivalent.** Closest analogue is tpws `--split-pos=.. --oob`; comparison: tpws needs no `--in-range` (it is a proxy), nfqws2 oob requires `--in-range=-s1` + conntrack `[evidence: verified]`.

## Cross-references

`multisplit`/`fakedsplit` (incompatible in-stream), `fake`/`syndata`, `tcpseg`, `instance_cutoff`. Full migration + marker table: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:1084-1176`; helpers `lua/zapret-lib.lua:1148-1192`.
