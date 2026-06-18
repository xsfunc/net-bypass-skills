# hostfakesplit — hostname-boundary split + generated fake host

## Lua signature

`function hostfakesplit(ctx, desync)` — `lua/zapret-antidpi.lua:695-800` `[evidence: verified]` CLI: `--lua-desync=hostfakesplit[:arg=...]`

## What it does

Specialized split that works **only** on payloads containing a hostname (`http_req` and `tls_client_hello`). It auto-detects the hostname boundaries, generates a fake hostname of the **same length** (via `genhost`, so DPI cannot distinguish by size), and sends real + fake hostname segments with the same TCP seq. Returns `VERDICT_DROP` `[evidence: verified]`. Best when DPI keys on the hostname and you want size-matched fakes.

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `host` | string | (template) | Template for `genhost` to produce the fake hostname. | verified |
| `midhost` | posmarker | none | Extra cut inside the hostname. Must be strictly inside `host+1..endhost-1` else ignored. | verified |
| `disorder_after` | posmarker | `"-1"` | Reverse-order cut after the hostname. Must be > `endhost+1` else ignored; empty value = last byte. | verified |
| `nofake1` | flag | off | Suppress first fake. | verified |
| `nofake2` | flag | off | Suppress second fake. | verified |
| `blob` | name/hex | (data) | Override payload source. | verified |
| `optional` | flag | off | Silent skip if blob missing. | verified |
| `nodrop` | flag | off | `VERDICT_PASS` (debug; server gets the hostname twice — duplication). | verified |

**NO `pos`** (auto-resolves `host,endhost-1` via `resolve_range` with `strict=true`). **NO `seqovl`.** **NO `ipfrag`** (both opts have `ipfrag={}`). Fooling/repeats/badsum **only on fakes**; `tcp_ts_up` on both. 5 segments basic, 6 with `midhost`, 6 with `disorder_after`, 7 with both.

## Verdict & protocol

- Verdict: `VERDICT_DROP` (unless `nodrop`) `[evidence: verified]`.
- Protocol: TCP only, and **only `http_req`/`tls_client_hello`** — `unknown`/`quic_initial` → "host range cannot be resolved", silent no-op. `[evidence: verified]`

## Gotchas

- **Hostname-only:** silently no-ops on payloads without a hostname. `[evidence: verified]`
- Both fakes use the **same** generated `fakehost` (`genhost` called once), same TCP seq as the real hostname. `[evidence: verified]`
- **Fooling mandatory** — without it the server gets two conflicting hostnames and the stream breaks. `[evidence: verified]`
- `midhost`/`disorder_after`/`nofake1-2` are **new nfqws2 capabilities** with no nfqws1 analog. `[evidence: verified]`
- ipfrag not supported; combine with other tools if IP-fragmentation over a hostname cut is needed. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=hostfakesplit` (or fake-unknown hex) | `--lua-desync=hostfakesplit:host=<template>` |
| `--dpi-desync-fake-unknown=0x…` | `:host=<template>` (genhost replaces raw hex) |
| `midhost`/`disorder_after`/`nofake1-2` | **new, no nfqws1 analog** |
| fooling flags | see `migration.md` |

## Cross-references

`multisplit`/`multidisorder`, `fakedsplit`/`fakeddisorder`, `tcpseg`, `oob`, `genhost` (fake-hostname generator). Full migration + marker table: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:695-800`.
