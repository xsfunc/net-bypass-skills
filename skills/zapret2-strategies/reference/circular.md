# circular — orchestrator auto-rotation of strategies

## Lua signature

`function circular(ctx, desync)` — `lua/zapret-auto.lua:312-386` `[evidence: verified]` CLI: `--lua-desync=circular[:param=val[:...]]`, followed by subordinate instances each tagged `:strategy=N`.

## What it does

A Lua orchestrator that auto-rotates through a chain of desync strategies when failures are detected on a per-host basis. It takes over the normal C execution loop, runs its failure/success detectors against the current connection, and on threshold breach advances to the next strategy number — executing **only** the subordinate instances whose `strategy=N` matches the current number. State (current strategy, failure counter) is stored per-host in the global `autostate` table and survives individual connections. `[evidence: verified]` (algorithm from code).

**Requires redirection of incoming traffic** (`--in-range=-s<N>`) so it can observe incoming RST and HTTP redirect replies — without incoming capture the RST and HTTP-redirect triggers cannot fire. `[evidence: verified]` (upstream code comment: "this orchestrator requires redirection of incoming traffic to cache RST and http replies").

## Parameters (on the `circular` instance)

| Param | Type | Default | Notes | Evidence |
|-------|------|---------|-------|----------|
| `fails=N` | number | `3` | Failure threshold to rotate to the next strategy | verified |
| `time=N` | number (sec) | `60` | Reset the failure counter if the last failure was > N seconds ago | verified |
| `failure_detector=func` | name | `standard_failure_detector` | Custom failure-detector function name | verified |
| `success_detector=func` | name | `standard_success_detector` | Custom success-detector function name | verified |
| `hostkey=func` | name | `standard_hostkey` | Custom host-key generator function name | verified |
| `key=string` | string | auto | `autostate` table name — isolates state between multiple `circular` instances | verified |
| `nld=N` | number | off | Cut hostname to N-level domain (`static.a.google.com` → `google.com` at `nld=2`) | verified |
| `reqhost` | flag | off | Skip work if hostname is unknown (IP-only) | verified |

## Parameters on subordinate instances

| Param | Notes | Evidence |
|-------|-------|----------|
| `strategy=N` | **Required.** Strategy number, starting at 1, incrementing with no gaps (validated; gaps error) | verified |
| `final` | Stops rotation at this strategy — no further rotation past it | verified |

## Failure detector — `standard_failure_detector`

`lua/zapret-auto.lua:146-214`. Params pass straight into `circular` (not the subordinates). `[evidence: verified]`

### TCP

| Param | Default | Notes | Evidence |
|-------|---------|-------|----------|
| `retrans=N` | `3` | Outgoing retransmission count = failure | verified |
| `maxseq=N` | `32768` | Count retransmissions only up to this relative sequence | verified |
| `reset` | off | Send RST to the retransmitter (breaks a hung connection faster) | verified |
| `inseq=N` | `4096` | Incoming RST counts as failure only up to this rseq | verified |
| `no_rst` | off | Disable the incoming-RST trigger | verified |
| `no_http_redirect` | off | Disable the DPI HTTP-redirect (302/307 to a different SLD) trigger | verified |

### UDP

| Param | Default | Notes | Evidence |
|-------|---------|-------|----------|
| `udp_out=N` | `4` | Failure if outgoing packets >= N | verified |
| `udp_in=N` | `1` | Failure if incoming packets <= N | verified |

## Success detector — `standard_success_detector`

`lua/zapret-auto.lua:226-258`. On success the failure counter is reset. `[evidence: verified]`

| Param | Default | Notes | Evidence |
|-------|---------|-------|----------|
| `maxseq=N` | `32768` | TCP: outgoing rseq > N → success | verified |
| `inseq=N` | `4096` | TCP: incoming rseq > N → success | verified |
| `udp_in=N` | `1` | UDP: incoming packets > N → success (only tested when `udp_out` set) | verified |

## How rotation works

1. A packet arrives at `circular` with its `ctx`. `[evidence: verified]`
2. `circular` calls `orchestrate()` and cancels the normal C execution loop. `[evidence: verified]`
3. It reads the per-host record from `autostate`; on first sight it starts at strategy 1. `[evidence: verified]`
4. `automate_failure_check` runs the success detector first (resets the counter on success) then the failure detector; if the counter reaches `fails`, it advances: `nstrategy = (nstrategy % total) + 1`. `[evidence: verified]`
5. If the new strategy equals the recorded `final`, rotation stops here for all future failures. `[evidence: verified]`
6. Only instances with `strategy == current` are executed; the rest of the plan is skipped for this connection. `[evidence: verified]`

A single strategy may span **several instances** sharing the same `strategy=N`; `circular` runs all of them in order (multi-phase strategy). `[evidence: verified]`

## Router config formatting

Inside `NFQWS2_OPT="..."` the param list may be split across lines and indented — the shell tokenises them as ordinary whitespace. `[evidence: verified]`

```
--filter-tcp=443 --filter-l7=tls <HOSTLIST> --payload=tls_client_hello
--out-range=-d1000
--in-range=-s5556
--lua-desync=circular:fails=1:time=300:retrans=3:nld=2
  --lua-desync=fake:blob=fake_default_http:repeats=4:strategy=1
  --lua-desync=multisplit:pos=2:seqovl=211:strategy=1
  --lua-desync=multidisorder:pos=host:strategy=2:final
--new
```

Here `fails=1` rotates after one failure, `time=300` resets the counter if the last failure was > 5 min ago, `retrans=3` defines a failure as 3 retransmissions, `nld=2` keys state on the 2-level domain, and `final` on strategy 2 stops rotation. `[evidence: community-observed]` (parameter composition pattern from upstream presets).

## Gotchas

- **Incoming capture is mandatory** for the RST and HTTP-redirect triggers. On the router this means an `--in-range=-s<N>` (NFQUEUE ingress) entry must be present in the same profile, plus conntrack enabled (`--ctrack-disable=0`); without it only the retransmission/UDP triggers can fire. `[evidence: verified]`
- **`conntrack` is required** — `circular` returns early if `desync.track` is missing. `[evidence: verified]`
- **No gaps in `strategy=N`** — the validator errors on non-contiguous numbering. `[evidence: verified]`
- Rotation is **per-host, not per-connection**: a flaky host can pin itself to `final` and stay there until `time` resets the counter. Reset window is a tuning knob, not a cure. `[evidence: community-observed]`
- `final` is a **stop marker, not a reset**: once reached, subsequent failures do not rotate back to strategy 1. `[evidence: verified]`
- Do not hardcode a `circular` chain from these docs — run `blockcheck2` and let autodetection shape the strategy order. `[evidence: hypothesis]` (effectiveness of any given order is ISP-dependent).

## nfqws1 → nfqws2 migration

New in nfqws2 — **no nfqws1 analog** (nfqws1 had no Lua orchestrator and no auto-rotation). There is nothing to translate; a `circular` chain is authored fresh against the Lua core. `[evidence: verified]`

## Cross-references

`multisplit`, `fake`, `multidisorder` (typical subordinate techniques); `../migration.md` (new nfqws2-only capabilities); `../testing-ladder.md` §"Beyond rung 4" (circular as the layer above the testing ladder); `preset.md` / `profile.md` (where a `circular` chain lives inside a profile).

## Source mapping

Upstream code: `lua/zapret-auto.lua:312-386` (`circular`), `:146-214` (`standard_failure_detector`), `:226-258` (`standard_success_detector`), `:9-24` (`standard_hostkey`), `:260-297` (`automate_failure_check`).
