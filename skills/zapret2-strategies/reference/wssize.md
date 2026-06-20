# wssize / wsize — TCP window-size manipulation

## Lua signatures

`function wssize(ctx, desync)` — `lua/zapret-antidpi.lua:337-355` `[evidence: verified]` CLI: `--lua-desync=wssize[:arg=...]`

`function wsize(ctx, desync)` — `lua/zapret-antidpi.lua:317-330` `[evidence: verified]` CLI: `--lua-desync=wsize[:arg=...]`

## What it does

Both rewrite `tcp.th_win` and/or the window-scaling TCP option to a small value so the peer sends its data in small segments — defeating DPI that inspects large server responses (TLS 1.2 server certificates/certs). `wssize` rewrites **every** TCP packet in the chosen direction until a cutoff; `wsize` rewrites only the single SYN,ACK and then cuts off `[evidence: verified]`.

- **`wssize`** is a **zero-phase strategy**: it must act before the hostname is known, so with hostlists it works only with `--ipcache-hostname` (the first connection to an IP is not affected because the hostname is not yet cached) `[evidence: community-observed]` (zero-phase + `--ipcache-hostname` requirement from upstream manual). Verdict: `VERDICT_MODIFY` `[evidence: verified]`.
- **`wsize`** is the **legacy, server-side** variant: it rewrites the window in SYN,ACK (sent by a server to its clients) and then cuts off. It is not useful on the router agent's client-side deployment. Verdict: `VERDICT_MODIFY` `[evidence: verified]`.

## Arguments (own)

### `wssize`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `direction` | `in`/`out`/`any` | `out` | Standard direction filter — which side's window to shrink. | verified |
| `wsize` | number | (required) | TCP window size to set. | verified |
| `scale` | number | none | Window-scaling factor to write into the TCP option (only decrease is honoured; increase is blocked). | verified |
| `forced_cutoff` | comma list | any data | Payload types that trigger `instance cutoff`; default = any non-empty payload. `forced_cutoff=no` → never cutoff (apply wssize indefinitely). | verified |

### `wsize`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `wsize` | number | (required) | TCP window size to set in SYN,ACK. | verified |
| `scale` | number | none | Window-scaling factor (only decrease honoured). | verified |

`wsize` has **no `direction`** — it acts on the SYN,ACK the local side emits (server-side semantics) `[evidence: verified]`.

## Verdict & protocol

- Verdict: `VERDICT_MODIFY` for both (only when a rewrite actually happened) `[evidence: verified]`.
- Protocol: TCP only (non-TCP/related-ICMP takes no cutoff) `[evidence: verified]`.

## Gotchas

- **`wssize` must come BEFORE `syndata`.** `syndata` returns `VERDICT_DROP` and replaces the SYN; if `wssize` sits after it, `wssize` never sees the SYN (it is already dropped) and the window is never shrunk. Place the `wssize` instance first: `--lua-desync=wssize:wsize=1:scale=6 --lua-desync=syndata:…`. `[evidence: verified]` (ordering consequence of `syndata`'s `VERDICT_DROP` at `lua/zapret-antidpi.lua:395-416`); `[evidence: community-observed]` (the nfqws1 `--wssize 1:6` → separate pre-syndata instance mapping).
- **Zero-phase + hostlists needs `--ipcache-hostname`.** Without hostname caching the first connection to an IP bypasses `wssize` (hostname unknown); with a hostlist you may also need to duplicate `wssize` in a pre-hostname profile that always applies (and always pays the speed cost). `[evidence: community-observed]` (deploy implication; full `--ipcache-hostname` reference lives in `zapret2-router-deploy`).
- **`wssize` always cuts speed** — keeping the server's window tiny forces slow, small-segment responses. Use `forced_cutoff` to release the pressure once the DPI-critical phase passes, or `forced_cutoff=no` only when you accept modem-grade throughput. `[evidence: community-observed]`
- **`wsize` is server-side, not applicable to the router agent's client-side deployment.** It rewrites the window in the SYN,ACK the *server* sends to *its* clients — useful only for a server operator protecting inbound clients, not for a client-side router. Documented for completeness because it appears in upstream presets. `[evidence: community-observed]`
- `scale` is only honoured when it decreases the effective window; an increase is blocked by `wsize_rewrite`. `[evidence: verified]`
- Typical parameters: `wsize=1:scale=6` `[evidence: community-observed]` (upstream manual "Типичные параметры").

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--wssize 1:6` | `--lua-desync=wssize:wsize=1:scale=6` (**place before `syndata`**) |
| `--wsize` (server-side) | `--lua-desync=wsize:wsize=..:scale=..` (server-side, not applicable to router agent) |

`[evidence: community-observed]` for the migration mapping; `[evidence: verified]` for the verdicts and SYN,ACK-only behaviour of `wsize`.

## Cross-references

`syndata` (must precede it — see `syndata.md` "Instance order matters"), `fake`/`multisplit` (data-phase techniques that pair with `wssize`), `orchestrators.md` (`stopif` to release `wssize` on a condition). Full migration: `../migration.md`; `--ipcache-hostname` deploy implications: `zapret2-router-deploy`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:337-355` (`wssize`), `:317-330` (`wsize`). Window rewrite helper: `wsize_rewrite` (in `zapret-lib.lua`).
