# blob — binary blob model

A **blob** is a Lua `string` variable holding a block of binary data (1 byte to gigabytes). Blobs supply fake-packet content and other binary payloads referenced by desync techniques via `blob=<name>`. `[evidence: verified]` (blob model is code-defined in `lua/zapret-lib.lua`).

## `--blob` — declaration syntax

```
--blob=name:@<file>            # load from binary file
--blob=name:0x<hex>            # inline hex
--blob=name:+<offset>@<file>   # load from file at byte offset
```

A blob declared in the preset **header** (before the first `--new`) is global — visible to every profile. `[evidence: verified]` (flag syntax); `[evidence: community-observed]` (header placement convention — see `core-flags.md`).

```
--blob=myblob:0x1603010000
--blob=custom_tls:@/opt/zapret2/bin/tls_clienthello.bin
--blob=custom_tls:+100@/opt/zapret2/bin/file.bin
```

Reference: `--lua-desync=fake:blob=myblob` (see `zapret2-strategies/reference/fake.md` for the `blob=` argument semantics, the `optional` flag, and the "blob required" error).

## Standard blobs (auto-initialised)

nfqws2 auto-creates three blobs at startup — no `--blob` declaration needed:

| Blob | Size | Content | Evidence |
|------|------|---------|----------|
| `fake_default_tls` | 680 B | TLS Client Hello with SNI `www.microsoft.com` (TLS 1.2/1.3, modern cipher suites, HTTP/2 support, standard extensions) | verified |
| `fake_default_http` | 227 B | HTTP/1.1 GET to `www.iana.org` with a Firefox User-Agent | verified |
| `fake_default_quic` | 620 B | Minimal valid QUIC Initial (first byte `0x40` long header, rest zeroed) | verified |

```
--payload=tls_client_hello --lua-desync=fake:blob=fake_default_tls
--payload=http_req         --lua-desync=fake:blob=fake_default_http
--payload=quic_initial     --lua-desync=fake:blob=fake_default_quic
```

`[evidence: verified]` (standard blobs are initialised in `lua/zapret-lib.lua` at startup).

## `tls_mod` — TLS Client Hello mutation function

`tls_mod` is a **Lua function** (not a desync argument) that rewrites a TLS Client Hello blob. This card owns the *function*; the per-technique *argument* `:tls_mod=...` semantics (which mods run on which technique, the "silently skipped without `reasm_data`" gotcha) live in `zapret2-strategies/reference/fake.md`.

### Signature

```lua
tls_mod(blob, modlist, [payload]) -> modified_blob
```

- `blob` — source TLS Client Hello (binary string).
- `modlist` — comma-separated mod names.
- `payload` (optional) — the real packet payload; required by `dupsid` to copy the Session ID.

`[evidence: verified]` (function defined in `lua/zapret-lib.lua`).

### Mod glossary

| Mod | Effect | Evidence |
|-----|--------|----------|
| `none` | no modification (explicit) | verified |
| `rnd` | randomise the 32-byte `random` field **and** the `session_id` field | verified |
| `rndsni` | replace SNI with a random domain | verified |
| `sni=<domain>` | set a specific SNI (supports `sni=%var`) | verified |
| `dupsid` | copy Session ID from the real `payload` (needs 3rd arg) | verified |
| `padencap` | add padding to TLS extensions | verified |

For mod behaviour **inside a desync technique** (e.g. `fake` only runs `tls_mod` on the first replay chunk and silently skips it without `reasm_data`), see `zapret2-strategies/reference/fake.md`. `[evidence: verified]`

### Two application modes

**(1) Startup mutation via `--lua-init`** — runs once at launch, rebinds the blob variable:

```
--lua-init="fake_default_tls = tls_mod(fake_default_tls,'rnd,rndsni')"
--lua-init="tls_google = tls_mod(fake_default_tls,'sni=www.google.com')"
```

Now `fake_default_tls` (or a new named blob `tls_google`) carries the mutation permanently. `[evidence: verified]` (`--lua-init` executes Lua at startup; reassignment is standard Lua semantics).

**(2) On-the-fly mutation via the `:tls_mod=` desync argument** — runs per send:

```
--lua-desync=fake:blob=fake_default_tls:tls_mod=rnd,dupsid,sni=www.google.com
```

Here `dupsid` can use the real packet payload (available inside the desync call). `[evidence: verified]`

Startup mutation is cheaper (one-time); on-the-fly is needed when the mod depends on the live packet (e.g. `dupsid` copying the real Session ID). `[evidence: community-observed]`

## Custom blobs

```
--blob=myblob:0x1603010000                              # inline hex
--blob=custom_tls:@/opt/zapret2/bin/tls_clienthello.bin # from file
--blob=custom_tls:+100@/opt/zapret2/bin/file.bin        # from file offset
--lua-desync=fake:blob=myblob
```

`[evidence: verified]` (flag syntax).

## Full preset example (router)

```
--lua-init=@lua/zapret-lib.lua --lua-init=@lua/zapret-antidpi.lua
--lua-init="fake_default_tls = tls_mod(fake_default_tls,'rnd,rndsni')"
--blob=quic_google:@/opt/zapret2/bin/quic_initial_www_google_com.bin

--filter-tcp=80 --filter-l7=http
--payload=http_req --lua-desync=fake:blob=fake_default_http:tcp_md5
--new

--filter-tcp=443 --filter-l7=tls
--payload=tls_client_hello --lua-desync=fake:blob=fake_default_tls:tcp_md5:repeats=6
--new

--filter-udp=443 --filter-l7=quic
--payload=quic_initial --lua-desync=fake:blob=quic_google:repeats=11
```

`[evidence: community-observed]` (composition shape from upstream presets); `[evidence: verified]` (flag syntax, `--new` separator).

## Gotchas

- **`blob=` is required for `fake`** (errors if absent without `:optional`). nfqws1 auto-selected a blob by payload type; nfqws2 needs an explicit `blob=` per instance. See `zapret2-strategies/reference/fake.md`. `[evidence: verified]`
- **`dupsid` needs the real payload.** It only works inside a desync call where the live packet is available; as a startup-only `tls_mod` (mode 1) it has nothing to copy. `[evidence: verified]`
- **`tls_mod` startup vs runtime.** Startup rebinds the variable globally (every later reference sees the mutated blob); runtime `:tls_mod=` re-mutates on each send and can use the live payload. Choose by whether the mod depends on the live packet. `[evidence: community-observed]`
- **Standard blobs exist without `--blob`.** Re-declaring `--blob=fake_default_tls:...` overwrites the auto-initialised one. `[evidence: verified]`

## Cross-references

`core-flags.md` (`--blob` as a header global, `--lua-init` for startup mutation); `fooling.md` (fooling flags combined with `blob=` in desync args); `zapret2-strategies/reference/fake.md` (`blob=` argument, `optional`, the `tls_mod` per-technique arg semantics and gotchas); `zapret2-strategies/reference/syndata.md` (another blob consumer).

## Source mapping

Upstream code: `lua/zapret-lib.lua` (`tls_mod` function, standard blob initialisation, `--blob` parsing). Upstream documentation: zapret2 blob model (standard blobs, custom declaration, mutation modes).
