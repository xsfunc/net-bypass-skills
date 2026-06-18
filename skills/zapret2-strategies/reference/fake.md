# fake — fake packet injection

## Lua signature

`function fake(ctx, desync)` — `lua/zapret-antidpi.lua:438` `[evidence: verified]` CLI: `--lua-desync=fake[:arg1[=val1][:arg2=val2]...]`

## What it does

Sends a fake payload as a separate packet and leaves the original untouched. It does **not** return a verdict — the original passes through `[evidence: verified]`. This makes fake "area fire": broad, simple, but blunt. For fakes interleaved inside real segments use `fakedsplit`/`fakeddisorder`; for hidden fakes via the TCP window use `seqovl` in `multisplit`/`multidisorder`.

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `blob` | name/hex | (required) | Fake data source. **Errors if absent** unless `optional`. Resolution: `0x` inline hex → `desync[name]` → `_G[name]`. | verified |
| `optional` | flag | off | Silently skip if blob missing instead of erroring. | verified |
| `tls_mod` | list | none | TLS mods: `none`/`rnd`/`rndsni`/`sni=<domain>`/`dupsid`/`padencap`. Supports `sni=%var`. Silently skipped without `reasm_data` (only first replay chunk is modified). | verified |

Plus standard sections: A) direction (`dir`), B) payload filter (`payload`), C) fooling (applies to **fakes only**, not the original), D) ipid, E) ipfrag, F) reconstruct, G) rawsend — see `desync.md`/`migration.md`.

## Verdict & protocol

- Verdict: **none** (original passes) `[evidence: verified]`.
- Protocols: **TCP and UDP** (unlike segmentation funcs, which are TCP-only) `[evidence: verified]`.

## Gotchas

- **Fooling is mandatory on TCP.** Fake without a limiting fooling (`tcp_md5`, `ip_ttl`, `badsum`, …) desyncs the stream — the server accepts the fake as real data and the connection breaks. `[evidence: verified]` (attributed to bolvan/zapret staff: "fake без ограничителей на tcp = гарантированный слом соединения"). For UDP (QUIC) TCP-specific fooling is meaningless; use IP-level fooling (`ip_ttl`, `badsum`, `ipfrag`, IPv6 ext headers).
- `tls_mod` runs only on the first replay chunk and is silently skipped without `reasm_data` (contrast `syndata`, where `tls_mod` always runs). `[evidence: verified]`
- `blob` is required (errors if absent without `optional`). nfqws1 auto-selected a blob by payload type; nfqws2 needs an explicit `blob=` and separate instances per protocol. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=fake` | `--lua-desync=fake:blob=...` (explicit blob required) |
| `--dpi-desync-fake-http=...` / `-tls=...` / `-quic=...` | separate `fake:blob=<proto_blob>` instances |
| `--dpi-desync-fake-tls-mod=...` | `:tls_mod=...` |
| fooling flags | see `migration.md` (`md5sig`→`tcp_md5`, `badseq`→`tcp_seq=-10000`/`tcp_ack=-66000`, `ipfrag1`→`ipfrag`, …) |
| `--dpi-desync-autottl=...` | `:ip_autottl=delta,min-max` (format mandatory) |

Key difference: nfqws1 picked the blob automatically per protocol; nfqws2 requires explicit `blob=` per instance `[evidence: verified]`.

## Cross-references

`syndata` (SYN-phase fake), `fakedsplit`, `fakeddisorder` (fakes inside segments), `multisplit`/`multidisorder` (seqovl hidden fakes). Full fooling-flag migration: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:438-461`.
