# nfqws1 → nfqws2 migration

Use this to translate legacy nfqws1 (`--dpi-desync=…`, `--dpi-desync-fooling=…`) presets to the nfqws2 Lua core (`--lua-desync=<func>:arg=val:…`). Per-technique detail lives in each `reference/<technique>.md` card; this file consolidates the shared fooling-flag table, the position-marker table, and flags the new nfqws2-only capabilities.

## Fooling flags

| nfqws1 | nfqws2 | Notes | Evidence |
|--------|--------|-------|----------|
| `md5sig` | `tcp_md5` | Add TCP MD5 signature option | verified |
| `badsum` | `badsum` | (unchanged) Bad IP checksum | verified |
| `badseq` | `tcp_seq=-10000` | Shift TCP sequence (for SYN) | verified |
| `badseq` | `tcp_ack=-66000` | Shift TCP ack (for data) — `badseq` was overloaded in nfqws1 | verified |
| `datanoack` | `tcp_flags_unset=ack` | Unset ACK flag | verified |
| `badack` | `tcp_ack=-66000` | Shift TCP ack | verified |
| `hopbyhop` | `ip6_hopbyhop` | IPv6 Hop-by-Hop header | verified |
| `hopbyhop2` | `ip6_hopbyhop2` | Second Hop-by-Hop | verified |
| `destopt` | `ip6_destopt` | IPv6 Destination Options | verified |
| `destopt2` | `ip6_destopt2` | Second Destination Options | verified |
| `ipfrag1` | `ipfrag` | IP fragmentation | verified |
| `--dpi-desync-autottl=…` | `:ip_autottl=delta,min-max` | **Format mandatory** (`delta,min-max`); bare `:ip_autottl` → `parse_autottl: invalid value`. Requires conntrack. | verified |

> **`tcp_ts_up` + `tcp_ack` on Linux:** Linux only drops bad-ack packets when the TCP timestamp option is first in the header. Always pair `tcp_ack=-66000` with `tcp_ts_up` when using `badack`/`badseq`-for-data without `badseq`-for-SYN. `[evidence: verified]`

## Position markers

| Marker | Meaning | Evidence |
|--------|---------|----------|
| `N` | Absolute position (number) | verified |
| `-N` | Position from end | verified |
| `host` | Start of hostname | verified |
| `endhost` | End of hostname | verified |
| `sld` | Second-level domain | verified |
| `midsld` | Middle of SLD | verified |
| `endsld` | End of SLD | verified |
| `method` | HTTP method | verified |
| `extlen` | TLS extensions length | verified |
| `sniext` | TLS SNI extension | verified |
| `marker+N` / `marker-N` | Marker plus/minus offset | verified |

Marker resolution differs per function: `multisplit`/`multidisorder`/`multidisorder_legacy` take a **list** (`resolve_multi_pos`); `fakedsplit`/`fakeddisorder` take a **single** marker (`resolve_pos`); `tcpseg` takes **exactly 2** as a range (`resolve_range`); `hostfakesplit` auto-resolves `host,endhost-1` (no `pos`).

## Per-technique `pos` / `seqovl` / pattern mapping

| Technique | `pos` | `seqovl` type | seqovl target | nfqws1 analog |
|-----------|-------|---------------|---------------|----------------|
| `fake` | n/a (no split) | n/a | n/a | `--dpi-desync=fake` (auto-blob → explicit `blob=`) |
| `syndata` | n/a (SYN) | n/a | n/a | `--dpi-desync=syndata` |
| `multisplit` | list | **number only** | 1st segment (TCP-window) | `--dpi-desync=split` |
| `multidisorder` | list | **marker** | 2nd segment (buffer-overwrite) | `--dpi-desync=disorder` |
| `multidisorder_legacy` | list (per-packet) | **marker** | per-packet | `--dpi-desync=disorder` (100% compat) |
| `fakedsplit` | single | **number only** | 1st real segment | `--dpi-desync=fakedsplit` |
| `fakeddisorder` | single | **marker** | 2nd real segment | `--dpi-desync=fakeddisorder` |
| `hostfakesplit` | auto (no `pos`) | none | n/a | `--dpi-desync=hostfakesplit` / `--dpi-desync-fake-unknown=0x…` → `:host=<template>` |
| `tcpseg` | exactly 2 (range) | **number only** | the segment | **new, no nfqws1 analog** |
| `oob` | n/a (SYN-based) | n/a | n/a | **new, no nfqws1 analog** (tpws `--oob` ≈) |

`pattern` (fake fill) maps `--dpi-desync-split-seqovl-pattern=0x…` → `:seqovl_pattern=0x…` for all seqovl-capable techniques. `hostfakesplit` has no `seqovl`/`pattern`; its `host=<template>` replaces `--dpi-desync-fake-unknown=hex`.

## New nfqws2-only capabilities (no nfqws1 analog)

- `seqovl` as a **marker** in `multidisorder`/`multidisorder_legacy`/`fakeddisorder` (nfqws1 accepted only numbers). `[evidence: verified]`
- `hostfakesplit`: `midhost`, `disorder_after`, `nofake1-2`. `[evidence: verified]`
- `tcpseg`: range segmentation + no-verdict + `drop` composition; `seqovl=#rnd`; dynamic blobs via `luaexec`. `[evidence: verified]`
- `oob`: SYN-phase OOB byte insertion with seq shift (tpws had a close analogue, nfqws1 did not). `[evidence: verified]`
- `multisplit` `seqovl=10000` works (auto MSS-segmentation); nfqws1 errored. `[evidence: verified]`

## Critical cross-technique gotchas (consolidated)

- **Windows-server seqovl breakage:** buffer-overwrite seqovl (used by `multidisorder`, `multidisorder_legacy`, `fakeddisorder`) does NOT work on Windows servers — they keep first-received data. TCP-window seqovl (`multisplit`, `fakedsplit`, `tcpseg`) works on all OSes. `[evidence: verified]`
- **Fooling target varies:** fakes-only (`fake`, `fakedsplit`, `fakeddisorder`, `hostfakesplit`) vs all-segments (`multisplit`, `multidisorder`, `multidisorder_legacy`) vs real-segment (`tcpseg`, `oob` — destructive fooling drops real data). `[evidence: verified]`
- **ipfrag unsupported** by `fakedsplit`, `fakeddisorder`, `hostfakesplit`. `[evidence: verified]`
- **`oob` incompatibility:** cannot combine with payload-sending functions (`multisplit`/`multidisorder`/`fakedsplit`/`fakeddisorder`) in the same stream; requires `--in-range=-s1` + conntrack + SYN-from-start + duplication across profile-switch boundaries. `[evidence: verified]`
