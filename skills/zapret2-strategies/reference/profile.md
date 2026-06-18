# profile — one block inside a preset

## What a profile is

A **profile** is one block of flags inside a preset, delimited by `--new`. Its formula: **for this traffic (filters) apply this bypass (desync)**. The engine walks profiles top-to-bottom and applies the first whose filters match a given packet. The preset is only the container; the profile is the unit of work. `[evidence: community-observed]` (model from upstream profile documentation).

## Anatomy

| Field | One-line glossary | Detail |
|-------|-------------------|--------|
| `--name=<label>` | GUI/audit label only — no effect on traffic. | — |
| `--filter-tcp=<ports>` / `--filter-udp=<ports>` | Which transport ports this profile reacts to. TCP-only ⇒ UDP ignored here, and vice versa. | pending `zapret2-engine-reference`, issue #4 |
| `--filter-l7=<proto>` | Narrow by application protocol: `http`, `tls`, `quic`, `wireguard`, `discord`, `stun`, `mtproto`… | pending `zapret2-engine-reference`, issue #4 |
| `--hostlist=<file>` / `--hostlist-domains=<dom>` / `--hostlist-exclude=<file>` | Match by SNI/Host domain (include or exclude). | pending `zapret2-router-deploy`, issue #5 |
| `--ipset=<file>` / `--ipset-exclude=<file>` / `--ipset-ip=<ip>` | Match by IP range (QUIC/voice have no SNI → IP-based). | pending `zapret2-router-deploy`, issue #5 |
| `--out-range=-dN` / `-nN` | Act only on the first N packets (`d`=data packets, `n`=all). | pending `zapret2-engine-reference`, issue #4 |
| `--payload=<type>` | Restrict to payload type: `tls_client_hello`, `http_req`, `quic_initial`, `all`… | pending `zapret2-engine-reference`, issue #4 |
| `--lua-desync=<func>:…` | The bypass strategy. May repeat — see "Stacking". | `../reference/*.md`, `circular.md` |

`[evidence: verified]` (flag syntax is code-defined); `[evidence: community-observed]` (anatomy convention).

## Filters combine by AND

All filters in a profile act simultaneously: a packet must match port AND protocol AND hostlist/ipset AND out-range AND payload. Miss any one and the profile is skipped — the engine tries the next. Over-narrow filters are a common cause of "the strategy is there but never fires". `[evidence: community-observed]`

## `--lua-desync=pass` — the exclusion profile

`pass` means "do nothing — let the packet through untouched". It is how exclusions are written: a top profile with `--hostlist=ru-exceptions.txt --lua-desync=pass` protects RU sites from tampering by profiles below. Because it sits first, matched traffic is consumed and never reaches the "tampering" profiles. `[evidence: verified]` (`pass` verdict); `[evidence: community-observed]` (exclusion placement practice).

## Stacking — multiple `--lua-desync` in one profile

Strategies stack: consecutive `--lua-desync` lines are applied in order to the matching packet. A typical combo is `send:repeats=2` → `syndata:blob=…` → `multisplit:…`. Each technique's card lives in `../reference/<name>.md`. An orchestrator (`circular.md`) may also appear here, replacing the linear stack with auto-rotation. `[evidence: verified]` (execution-plan ordering); `[evidence: community-observed]` (combo patterns from upstream presets).

## Ordering — first match wins

- Profiles run **top-to-bottom**; the first whose filters match takes the packet. `[evidence: community-observed]`
- Put `pass` exclusions **first**, or a lower tampering profile will grab that traffic first. `[evidence: community-observed]`
- If two profiles catch overlapping traffic (e.g. both on `:443` with no narrow hostlist), the upper one wins. `[evidence: community-observed]`

## Multi-profile example — YouTube + Discord in one preset

```
--filter-tcp=80,443 --hostlist=/opt/zapret2/lists/youtube.txt
--out-range=-d8 --payload=tls_client_hello
--lua-desync=multisplit:pos=2,midsld-2:seqovl=1:seqovl_pattern=tls7

--new

--filter-tcp=443 --hostlist-domains=updates.discord.com
--out-range=-d10
--lua-desync=multidisorder:pos=1,host+2,sld+2,sld+5,sniext+1,endhost-2:seqovl=1

--new

--filter-tcp=80,443,1080,2053,2083,2087,2096,8443 --hostlist=/opt/zapret2/lists/discord.txt
--out-range=-n10
--lua-desync=fake:blob=tls_google:repeats=6:tcp_ts=1000
--lua-desync=multidisorder_legacy:seqovl=652:seqovl_pattern=tls5
```

YouTube is a single-technique profile; the Discord-media profile stacks `fake` + `multidisorder_legacy`; the `updates.discord.com` profile narrows via `--hostlist-domains` so it wins over the broader Discord profile below it. `[evidence: community-observed]` (composition from upstream presets); `[evidence: verified]` (flag syntax, `--new` separator).

## Gotchas

- Over-narrow AND filters silently no-op a profile — widen one filter at a time when debugging "strategy present but not firing". `[evidence: community-observed]`
- Order matters as much as the strategy itself: a broad upper profile shadows every narrower one below it. `[evidence: community-observed]`
- A "broken" site usually means **one profile** is stale under the current DPI, not that the preset/program "stopped working" — tune that profile's `--lua-desync`, do not swap the whole preset. `[evidence: community-observed]`
- Do not hardcode a profile from this card — run `blockcheck2` and shape the desync from the result. `[evidence: hypothesis]` (effectiveness is ISP-dependent).

## Cross-references

`preset.md` (the container — header, blobs, `--new` layout); `circular.md` (auto-rotation inside a profile); `../reference/<technique>.md` (each desync function); `../migration.md` (flag translation); `../testing-ladder.md` (escalation order per profile).

## Source mapping

Upstream documentation: zapret2 profile model (filter AND-desync, `--new` blocks, stacking, ordering). No single code path — model distilled from upstream profile documentation. Flag-syntax references pending `zapret2-engine-reference` (issue #4) and `zapret2-router-deploy` (issue #5).
