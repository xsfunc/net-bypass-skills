# preset — composition model

## What a preset is

A **preset** is the full zapret2 configuration block — on the router, the contents of `NFQWS2_OPT="..."` in `/opt/zapret2/config` (the one non-UCI config file). It is a container: a global header followed by one or more **profiles** separated by `--new`. The preset itself does not "do" anything; the engine processes traffic profile-by-profile. `[evidence: community-observed]` (model from upstream preset documentation).

On Windows the preset lives in a `.txt` file loaded by `winws2.exe` via `@<config_file>`; that surface is out of scope here. On the router the same flag grammar lives inside `NFQWS2_OPT`. `[evidence: community-observed]`

## Three logical parts

1. **Header / globals** — flags that apply to the whole preset.
2. **Blobs** — named data placeholders referenced by desync techniques.
3. **Profiles** — `--new`-separated blocks, each "for this traffic (filter) apply this bypass (desync)". See `profile.md`.

## Header (globals)

| Flag | One-line glossary | Detail |
|------|------------------|--------|
| `--lua-init=@lua/<file>.lua` | Load a Lua library (strategies, automation, custom funcs). **Required** — without `zapret-antidpi.lua`/`zapret-auto.lua` the `--lua-desync` techniques have nothing to call. | pending `zapret2-engine-reference`, issue #4 |
| `--ctrack-disable=0` | Enable connection tracking (conntrack). Needed by `circular` and most fooling. | pending `zapret2-engine-reference`, issue #4 |
| `--ipcache-lifetime=N` | IP-cache TTL in seconds (e.g. `8400`). | pending `zapret2-engine-reference`, issue #4 |
| `--ipcache-hostname=1` | Cache hostname → IP. | pending `zapret2-engine-reference`, issue #4 |
| `--blob=name:@bin/x.bin` / `--blob=name:0x…` | Named binary/hex placeholder referenced by `blob=` in desync args. | pending `zapret2-engine-reference`, issue #4 |

`[evidence: verified]` (flag syntax is code-defined); `[evidence: community-observed]` (the "header holds globals" convention).

> The full flag reference (syntax, values, gotchas) for `--lua-init`, `--ctrack-disable`, `--ipcache-*`, `--blob` lives in `zapret2-engine-reference` (issue #4, not yet authored). This card lists them only as header tokens.

## Profiles

Each profile is a block of flags from one `--new` to the next. The engine walks profiles **top-to-bottom** and, for each packet, applies the **first** profile whose filters match. `[evidence: community-observed]`

Filtering primitives that appear inside a profile (`--filter-tcp/udp/l7`, `--hostlist`, `--ipset`/`--ipset-exclude`, `--out-range`, `--payload`) are one-line tokens here — their full reference is pending `zapret2-engine-reference` (issue #4) and `zapret2-router-deploy` (issue #5, for hostlist/ipset/nftset management). Anatomy and AND-semantics of a profile: `profile.md`.

## Profile ordering

- **First match wins.** If two profiles' filters overlap, the upper one takes the packet. `[evidence: community-observed]`
- Put **exclusions** (`--lua-desync=pass`, see `profile.md`) at the top so "do not touch" traffic never reaches a tampering profile below. `[evidence: community-observed]`

## Router example — YouTube + Discord in one preset

```
NFQWS2_OPT="
--lua-init=@lua/zapret-lib.lua
--lua-init=@lua/zapret-antidpi.lua
--lua-init=@lua/zapret-auto.lua
--ctrack-disable=0 --ipcache-lifetime=8400 --ipcache-hostname=1
--blob=tls_google:@bin/tls_clienthello_www_google_com.bin
--blob=fake_default_http:0x00

--filter-tcp=80,443 --hostlist=/opt/zapret2/lists/youtube.txt
--out-range=-d8 --payload=tls_client_hello
--lua-desync=multisplit:pos=2,midsld-2:seqovl=1:seqovl_pattern=tls7

--new

--filter-tcp=80,443,1080,2053,2083,2087,2096,8443 --hostlist=/opt/zapret2/lists/discord.txt
--out-range=-n10
--lua-desync=fake:blob=tls_google:repeats=6:tcp_ts=1000
--lua-desync=multidisorder_legacy:seqovl=652:seqovl_pattern=tls5

--new

--filter-tcp=80,443 --hostlist=/opt/zapret2/lists/ru-exceptions.txt
--lua-desync=pass
"
```

Three profiles: YouTube (multisplit), Discord (fake + multidisorder_legacy), and a `pass` exception block for RU sites. Only two `--blob` entries are shown — a real preset declares all blobs its desync args reference; the full blob reference is pending `zapret2-engine-reference` (issue #4). `[evidence: community-observed]` (composition shape from upstream presets); `[evidence: verified]` (`--new` separator, flag syntax).

## Gotchas

- A preset is a **starting point**, not a guarantee: strategies are pinned per profile, so one site may load while another breaks on the same preset. Tune the **profile**, do not blindly swap presets. `[evidence: community-observed]`
- On the router, capture/interception of ports is done by nftables/NFQUEUE wiring (not `--wf-*`, which is Windows WinDivert). That wiring is pending `zapret2-router-deploy` (issue #5). `[evidence: community-observed]`
- Do not hardcode a preset from this card — run `blockcheck2` and let autodetection shape each profile's desync. `[evidence: hypothesis]` (effectiveness is ISP-dependent).

## Cross-references

`profile.md` (anatomy of one profile, AND-semantics, `--lua-desync=pass`, desync stacking); `circular.md` (orchestrator that rotates strategies inside a profile); `../migration.md` (nfqws1→nfqws2 flag translation); `../testing-ladder.md` (progressive escalation per profile).

## Source mapping

Upstream documentation: zapret2 preset model (header + `--new`-separated profiles). No single code path — model distilled from upstream preset/profile documentation. Flag syntax references pending `zapret2-engine-reference` (issue #4).
