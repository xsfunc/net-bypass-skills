# http_hostcase / http_domcase / http_methodeol / http_unixeol — HTTP header tampering

## Lua signatures

`function http_hostcase(ctx, desync)` — `lua/zapret-antidpi.lua:154-181` `[evidence: verified]` CLI: `--lua-desync=http_hostcase[:arg=...]`

`function http_domcase(ctx, desync)` — `lua/zapret-antidpi.lua:127-149` `[evidence: verified]` CLI: `--lua-desync=http_domcase`

`function http_methodeol(ctx, desync)` — `lua/zapret-antidpi.lua:186-213` `[evidence: verified]` CLI: `--lua-desync=http_methodeol`

`function http_unixeol(ctx, desync)` — `lua/zapret-antidpi.lua:218-249` `[evidence: verified]` CLI: `--lua-desync=http_unixeol`

## What it does

A family of HTTP request (`http_req`) header mutations that exploit permissive HTTP parsers to confuse DPI that keys on literal `Host:`/`User-Agent:`/CRLF layout. All four act only on `desync.l7payload=="http_req"` and return `VERDICT_MODIFY` (the modified request replaces the original) `[evidence: verified]`. They are the nfqws2 home for nfqws1's `--dpi-desync=hostcase`/`domcase`/`methodeol` HTTP fooling (and `http_unixeol`, which nfqws1 lacked — tpws had `--unixeol`) `[evidence: community-observed]` (mapping from upstream migration examples; `[evidence: verified]` for the `http_unixeol` "nfqws1: not available, tpws: --unixeol" source comment at `lua/zapret-antidpi.lua:215-217`).

## Arguments (own)

| Function | Arg | Type | Default | Notes | Evidence |
|----------|-----|------|---------|-------|----------|
| `http_hostcase` | `direction` | `in`/`out`/`any` | `out` | Standard direction filter. | verified |
| `http_hostcase` | `spell` | string | `"host"` | Exact spelling of the `Host:` header. **Must be exactly 4 chars** or the function errors. | verified |
| `http_domcase` | `direction` | `in`/`out`/`any` | `out` | Standard direction filter. | verified |
| `http_methodeol` | `direction` | `in`/`out`/`any` | `out` | Standard direction filter. | verified |
| `http_unixeol` | `direction` | `in`/`out`/`any` | `out` | Standard direction filter. | verified |

No fooling/ipid/ipfrag/rawsend — these mutate the HTTP payload in place and return `VERDICT_MODIFY` `[evidence: verified]`.

### Per-function behaviour

- **`http_hostcase`** — rewrites the `Host:` header token to `spell` (e.g. `HOST`, `hOsT`). Default `spell="host"`; any 4-char spelling works (`Host`, `HOST`, `hOsT`). `[evidence: verified]`
- **`http_domcase`** — alternates case per character of the domain inside `Host:` (e.g. `rUtRaCkEr.oRg`). No args beyond direction. `[evidence: verified]`
- **`http_methodeol`** — inserts `\r\n` before the method and trims 2 chars off the end of the `User-Agent:` value to keep the total length. **nginx-only** — breaks other servers. **Must be the last HTTP-tampering instance** in the profile (it rewrites the start of the stream, so any later start-relative mutation sees a shifted buffer). `[evidence: verified]` (mechanism); `[evidence: community-observed]` (nginx-only constraint).
- **`http_unixeol`** — replaces CRLF (`0D0A`) with LF (`0A`) and pads the `User-Agent:` value with trailing spaces to compensate for the length difference. **nginx-only** — breaks other servers. `[evidence: verified]` (mechanism); `[evidence: community-observed]` (nginx-only constraint).

## Verdict & protocol

- Verdict: `VERDICT_MODIFY` for all four (modified request replaces the original) `[evidence: verified]`.
- Protocol: TCP only, **`http_req` only** — silently no-ops on any other payload type (and on related ICMP no cutoff is taken). `[evidence: verified]`

## Gotchas

- **nginx-only for `http_methodeol` and `http_unixeol`.** Both exploit nginx's permissive HTTP parser; Apache and other strict servers reject the mangled request and the connection breaks. Verify the upstream is nginx before applying. `[evidence: community-observed]`
- **`http_methodeol` must be the last HTTP-tampering instance.** It edits the start of the stream; any later instance that resolves start-relative markers (`method`, `host`) sees a shifted buffer and mis-resolves. Put other HTTP mutations before it. `[evidence: verified]` (source comment `lua/zapret-antidpi.lua:185`: "if using with other http tampering methodeol should be the last").
- **`http_hostcase` `spell` must be exactly 4 chars** — the function errors on any other length (`error("http_hostcase: invalid host spelling …")`). Default `"host"` is 4 chars; custom spells like `Host`/`HOST` work, `h` does not. `[evidence: verified]`
- `http_unixeol` requires a `User-Agent:` header (it pads it to compensate for the CRLF→LF length loss); without one it no-ops. `[evidence: verified]`
- `http_methodeol` requires a `User-Agent:` value at least 2 chars long; shorter values no-op. `[evidence: verified]`
- All four require `desync.l7payload=="http_req"` — they are not general TCP mutations; a profile without `--payload=http_req` (or HTTP detection) will not trip them. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=hostcase` | `--lua-desync=http_hostcase[:spell=…]` |
| `--dpi-desync=domcase` | `--lua-desync=http_domcase` |
| `--dpi-desync=methodeol` | `--lua-desync=http_methodeol` (nginx-only, **last instance**) |
| `--dpi-desync=unixeol` | `--lua-desync=http_unixeol` (nginx-only) — note: the source comment attributes `unixeol` to tpws (`--unixeol`), not nfqws1; the row is kept for parity with the tpws-originated flag name. |

`[evidence: community-observed]` for the migration mapping; `[evidence: verified]` for the `http_unixeol` tpws-origin note (`lua/zapret-antidpi.lua:215-217`).

## Cross-references

`send`/`pktmod` (apply fooling to the original), `luaexec` (custom HTTP mutations), `multisplit`/`fake` (HTTP-body splits/fakes). Full migration: `../migration.md`; HTTP payload detection: `detect-payload-str.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:154-181` (`http_hostcase`), `:127-149` (`http_domcase`), `:186-213` (`http_methodeol`), `:218-249` (`http_unixeol`).
