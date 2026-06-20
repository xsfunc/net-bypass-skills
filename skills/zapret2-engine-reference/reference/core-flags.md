# core-flags — preset header globals

The **preset header** is the block of global flags that precedes the first `--new`-separated profile. These flags configure the engine itself (Lua libraries, conntrack, IP cache, named blobs) and apply to every profile below. The profile composition model (`--new` separator, profile anatomy, stacking, `--lua-desync=pass`) lives in `zapret2-strategies/reference/preset.md` and `profile.md` — this card owns only the header tokens. `[evidence: community-observed]` (header/globals convention from upstream preset documentation).

## Header globals

| Flag | One-line glossary | Detail | Evidence |
|------|-------------------|--------|----------|
| `--lua-init=@lua/<file>.lua` | Load a Lua library (strategies, automation, custom funcs). **Required** — without `zapret-antidpi.lua` / `zapret-auto.lua` the `--lua-desync` techniques have nothing to call. Also accepts inline Lua: `--lua-init="<expr>"` (e.g. startup blob mutation, see `blob.md`). | Load order matters — libraries must be loaded before techniques that reference their functions. | verified |
| `--ctrack-disable=0` | Enable connection tracking (conntrack). Needed by the `circular` orchestrator, most fooling (`ip_autottl`, …), and per-connection `l7proto` reuse. | `0` = enabled. Disabled conntrack breaks `--out-range`/`--in-range` counting and `l7proto` persistence. | verified |
| `--ipcache-lifetime=N` | IP-cache TTL in seconds (e.g. `8400`). | Controls how long hostname→IP / IP state is cached. | verified |
| `--ipcache-hostname=1` | Cache hostname → IP. | Enables hostname-based cache lookups used by `--hostlist`. | verified |
| `--blob=name:@file\|0xhex\|+off@file` | Named binary placeholder referenced by `blob=` in desync args. | Full syntax + `tls_mod` mutation in `blob.md`. | verified |

`[evidence: verified]` (flag syntax is code-defined); `[evidence: community-observed]` (the "header holds globals" placement convention).

## General flags (apply to all engines: nfqws2/dvtws2/winws2)

Beyond the header globals above, the engine accepts these top-level flags. They are code-defined flag syntax (`docs/manual.md` §"Полный список опций") and apply regardless of engine:

| Flag | Glossary | Evidence |
|------|----------|----------|
| `@<config_file>` | read options from file; all other cmdline opts ignored | verified |
| `--debug=0\|1\|syslog\|android\|@<filename>` | debug log target | verified |
| `--version` | print version | verified |
| `--dry-run` | validate cmdline + file existence; does NOT check Lua scripts | verified |
| `--comment=<text>` | arbitrary comment (stored, not acted on) | verified |
| `--intercept=0\|1` | `0` = run `--lua-init` then exit, no NFQUEUE (use for Lua-init-only / timer daemons); `1` = normal intercept | verified |
| `--ctrack-timeouts=S:E:F[:U]` | conntrack timeouts tcp SYN:ESTABLISHED:FIN[:udp] (seconds) | verified |
| `--payload-disable=[type[,type]]` | disable discovery of payload types; no arg = all | verified |
| `--reasm-disable=[type[,type]]` | disable reasm for `tls_client_hello`/`quic_initial`; no arg = all | verified |
| `--server=0\|1` | server mode — inverts IP/port interpretation for `--ipset`/`--port-filter` (run nfqws2 on the server side) | verified |
| `--writable[=<dir>]` | create a writable dir for Lua; path exposed in env `WRITABLE` (only one `--writable` allowed) | verified |
| `--lua-gc=<int>` | Lua GC interval seconds; `0` = disable periodic GC | verified |
| `--ipcache-lifetime=<int>` | IP-cache TTL in seconds | verified (see Header globals above) |
| `--ipcache-hostname=0\|1` | cache hostname → IP | verified (see Header globals above) |

`[evidence: verified]` (flag syntax is code-defined per `docs/manual.md` §"Полный список опций").

## nfqws2-specific flags (Linux)

These are parsed only by the Linux engine (`nfqws2`); `dvtws2`/`winws2` do not register them.

| Flag | Glossary | Evidence |
|------|----------|----------|
| `--qnum=<nfqueue_number>` | NFQUEUE queue number — must match the nftables `queue num` (see `zapret2-router-deploy/reference/nfqueue-wiring.md`) | verified |
| `--user=<username>` / `--uid=uid[:gid1,gid2,...]` | drop privileges after bind (Keenetic: set `WS_USER=nobody` in `config`) | verified |
| `--fwmark=<int\|0xHEX>` | default `0x40000000` — mark bit to prevent re-capture loop (see `DESYNC_MARK` in `config`) | verified |
| `--bind-fix4` / `--bind-fix6` | fix generated packets egress on the wrong iface under policy-based routing | verified |

`[evidence: verified]` (flag syntax is code-defined per `docs/manual.md` §nfqws2-specific; `--fwmark` default `0x40000000` = `DESYNC_MARK`).

## Profile-scope tokens (one-liners)

These appear **inside** a profile block and have their own reference cards:

| Token | One-line | Detail |
|-------|----------|--------|
| `--filter-l3/tcp/udp/l7` | transport/protocol filter | `filter.md` |
| `--payload=<type>` | per-packet payload-type filter | `payload.md` |
| `--out-range` / `--in-range` | packet-range filter | `out-range.md` |
| `--hostlist` / `--ipset` | domain / IP filter primitives | `zapret2-router-deploy` (#5 — management) |
| `--lua-desync=<func>:…` | the bypass strategy | `zapret2-strategies` (technique semantics) |

## `--new` — profile separator (pointer)

`--new` terminates a profile and starts the next. It is **not** owned here — the profile composition model (`--new`-separated blocks, first-match-wins ordering, `--lua-desync=pass` exclusion profile) lives in `zapret2-strategies/reference/preset.md` and `profile.md`. `[evidence: verified]` (`--new` separator is code-defined); ownership: `zapret2-strategies`.

## Windows-only flags — do NOT use on the router (boundary marker)

The `--wf-*` family is the **WinDivert capture filter** for the Windows engine (`winws2`). The router engine (`nfqws2`) does **not** parse WinDivert flags — copying them from a Windows/legacy preset into `NFQWS2_OPT` produces an invalid config. On the router, packet capture is done by **nftables → NFQUEUE** wiring, documented in `zapret2-router-deploy` (#5).

| Windows-only flag | Purpose (Windows) | Router equivalent |
|-------------------|-------------------|-------------------|
| `--wf-iface` | interface filter | nftables rule interface match (#5) |
| `--wf-l3` | L3 protocol filter | `--filter-l3` (engine-side) / nftables (#5) |
| `--wf-tcp-in` / `--wf-tcp-out` | TCP port capture | nftables `tcp dport` → NFQUEUE (#5) |
| `--wf-udp-in` / `--wf-udp-out` | UDP port capture | nftables `udp dport` → NFQUEUE (#5) |
| `--wf-tcp-empty` | queue empty ACKs | NFQUEUE rule scope (#5) |
| `--wf-raw` / `--wf-raw-part` | WinDivert filter language | nftables rules / `--filter-*` (engine-side) |
| `--wf-filter-lan` | exclude LAN | nftables rule (#5) |
| `--wf-save` | dump filter and exit | n/a |
| `--ssid-filter` | WiFi SSID filter (winws2) | `--filter-ssid` (nfqws2/Linux, AP router — see `filter.md`) |

`[evidence: verified]` (the `--wf-*` flags are Windows/WinDivert-only; nfqws2 does not parse them — router capture is nftables/NFQUEUE); router wiring: `zapret2-router-deploy` (#5).

## Header example (router)

```
--lua-init=@lua/zapret-lib.lua
--lua-init=@lua/zapret-antidpi.lua
--lua-init=@lua/zapret-auto.lua
--lua-init="fake_default_tls = tls_mod(fake_default_tls,'rnd,rndsni')"
--ctrack-disable=0 --ipcache-lifetime=8400 --ipcache-hostname=1
--blob=tls_google:@/opt/zapret2/bin/tls_clienthello_www_google_com.bin
--blob=fake_default_http:0x00

--filter-tcp=80,443 --hostlist=/opt/zapret2/lists/youtube.txt
--out-range=-d8 --payload=tls_client_hello
--lua-desync=multisplit:pos=2,midsld-2:seqovl=1:seqovl_pattern=tls7
--new
--filter-tcp=80,443 --hostlist=/opt/zapret2/lists/ru-exceptions.txt
--lua-desync=pass
```

`[evidence: community-observed]` (composition shape from upstream presets); `[evidence: verified]` (flag syntax, `--new` separator).

## Gotchas

- **`--lua-init` load order matters.** Libraries (`zapret-lib.lua`, `zapret-antidpi.lua`, `zapret-auto.lua`) must be loaded before any `--lua-desync` technique that calls their functions, and before inline `--lua-init` expressions that reference their globals (e.g. `tls_mod`). `[evidence: verified]`
- **`--ctrack-disable=0` is a prerequisite** for `ip_autottl`/`ip6_autottl`, `--out-range`/`--in-range` counting, `l7proto` persistence, and the `circular` orchestrator. Disabling conntrack silently breaks all of them. `[evidence: verified]`
- **Do not copy `--wf-*` from Windows presets.** They are WinDivert-only; the router uses nftables/NFQUEUE (see `zapret2-router-deploy`). `[evidence: verified]`
- **Blobs declared in the header are global.** A `--blob` inside a profile block is not standard — declare named blobs in the header so every profile can reference them. `[evidence: community-observed]`

## Cross-references

`blob.md` (`--blob` syntax, `tls_mod` startup mutation); `filter.md` / `payload.md` / `out-range.md` (profile-scope tokens); `fooling.md` (`--ctrack-disable=0` prerequisite for `ip_autottl`); `zapret2-strategies/reference/preset.md` (the container — header + `--new`-separated profiles); `zapret2-strategies/reference/profile.md` (profile anatomy); `zapret2-router-deploy` (nftables/NFQUEUE wiring that replaces `--wf-*`, hostlist/ipset management).

## Source mapping

Upstream documentation: `docs/manual.md` §"Полный список опций" (General flags: `--debug`/`--version`/`--dry-run`/`--comment`/`--intercept`/`--ctrack-timeouts`/`--payload-disable`/`--reasm-disable`/`--server`/`--writable`/`--lua-gc`), §nfqws2-specific (`--qnum`/`--user`/`--uid`/`--fwmark`/`--bind-fix4`/`--bind-fix6`), preset header model (globals convention, `--lua-init`/`--ctrack-disable`/`--ipcache-*`/`--blob`). Upstream code: `nfqws.c` / `lua/zapret-lib.lua` (flag parsing, Lua init, conntrack, IP cache). The `--wf-*` set is WinDivert-only (`nfqws2` does not register these options); `--fwmark` default `0x40000000` = `DESYNC_MARK`.
