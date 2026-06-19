# siberian-scheme — the June-2026 behavioural detection model

The **Siberian scheme** is a behavioural DPI detection model (June 2026): a trigger fires only when an AND-chain of three conditions matches simultaneously. It is named for the `Siberian` subchecker in `dpi-checkers v0.7.0`; the model was reverse-engineered by Пётр Осетров (@hyperion_cs) and independently attested by eByeBots, 3DNews, hosters (Selectel/Beget/Timeweb), and net4people/bbs #546. It is a June-2026 snapshot, operator-variable — parameters drift over time. `[evidence: community-observed]` (reverse-engineering, multi-source attested).

## The three AND-conditions

DPI inspects every `ClientHello` and aggregates behaviour per SNI. The trigger is **AND, not OR** — all three must match:

1. **Subnet** (Signal 1) — the destination IP/subnet/AS is on a "suspicious" list covering whole datacentre ranges (Selectel, Яндекс.Облако, Cloud.ru, Leaseweb, Beget, foreign hostings Hetzner/DO/OVH). The *whole range* is suspect, not your specific IP — "your IP is not burned, the entire range is under suspicion." Novelty vs older methods (`tcp 16-20` / `l4-25`): those hit only foreign providers; the Siberian scheme *added* Russian DCs. `[evidence: community-observed]` (reverse-engineering, multi-source attested)
2. **TLS fingerprint** (Signal 2) — the ClientHello fingerprint (JA3/JA4 — see `ja3-ja4.md`) matches a "suspicious" client: Chrome, Safari, iOS. The most popular browser is the most "paleny" precisely because bypass tools mass-mimic it. "Loyal": Firefox, Edge, Android OkHttp, 360, QQ. `[evidence: community-observed]` (reverse-engineering, multi-source attested)
3. **Frequency** (Signal 3) — more than ~3 parallel TLS attempts to one SNI, with inter-attempt delay under ~350–400ms (community reports also cite <20–50ms), within a 60s window. This is Stage 4 of the funnel (flow meta-analysis). `[evidence: community-observed]` (snapshot June-2026, operator-variable — read as order of magnitude, not constants)

**SNI is the aggregation key for Signal 3, not a fourth signal.** Frequency is counted *per SNI*; the trigger remains three-signed. `[evidence: community-observed]` (reverse-engineering, multi-source attested)

## The trigger: AND-chain ⇒ break any one

```
subnet in list?  AND  fingerprint suspicious?  AND  >3 conn/SNI <~350-400ms/60s  ->  freeze 120s
break ANY one link  ->  rule does NOT fire
```

The practical corollary: you do not need to defeat all three — breaking *any single one* defeats the trigger. `[evidence: community-observed]` (reverse-engineering, multi-source attested)

## freeze — 120s throttle, not RST

On all-three-match, traffic to the host is **frozen for 120 seconds**. This is not a hard RST — connections quietly degrade (timeouts, slowdown) to look like bad connectivity, not censorship. TCP itself passes; TLS over it is throttled. This is the `throttle` verdict in the funnel's action set (RST / drop / throttle). `[evidence: community-observed]` (snapshot June-2026, operator-variable)

## fidget-trap — 600s escalation

If during a freeze the client *changes its fingerprint* (even to a clean, allowed one), DPI reads this as "someone deliberately evading" and escalates to a **600-second block on all TLS to the host regardless of fingerprint and SNI**. TCP still passes; only TLS is suffocated. This is why "fidgeting" under load (rapidly switching fingerprints) is counterproductive. `[evidence: community-observed]` (snapshot June-2026, operator-variable)

## Why legitimate sites get caught (collateral damage)

A legitimate site on a DC subnet (condition 1) + a Chrome visitor (condition 2) + HTTP/1.1's per-host pool of ~6 parallel connections loading a heavy page (condition 3) — all three match *involuntarily*, and honest traffic is frozen. The rule was written for VPN; it fires on ordinary sites because the three conditions are individually common. `[evidence: community-observed]` (reverse-engineering, multi-source attested — the collateral-damage pattern is documented by hosters and eByeBots)

## What is explicitly NOT part of the verified trio

These are **not** part of the verified Siberian scheme — they live in `hypothesis-frontier.md`:
- **SNI↔IP mismatch** (consistency check) — "practitioners' forecast, not a confirmed part of the scheme; the primary source has three signals, no SNI↔IP check." `[evidence: hypothesis]`
- **TLS-in-TLS shape** (round-trip choreography) — "a separate vector, not the Siberian Signal 3." `[evidence: hypothesis]`
- **eternal-h2/h3 mechanism** — effect observed, mechanism not confirmed. `[evidence: hypothesis]`

## Cross-references

`ja3-ja4.md` (Signal 2's fingerprint mechanics in detail), `ttl-detection.md` (Stage 0 — the layer above Signal 1's subnet), `hypothesis-frontier.md` (the hypothesised additions to the trio), `SKILL.md` (the funnel spine — Signal 2 = Stage 2, Signal 3 = Stage 4). The countermeasure-class map in `SKILL.md` names the *classes* that break each condition (subnet→CDN-fronting/IP-choice, fingerprint→uTLS, frequency→mux/SNI-spread); transport config for those classes is out-of-scope.

## Source mapping

Upstream notes: `DPI/dpi-tls-june-2026.md` (the 3-AND model, fidget-trap, 120/600s, SNI-as-key — Habr 1044396, @hyperion_cs), `DPI/tspu-false-blocks-june-2026.md` (collateral damage, hoster attestations, eByeBots/3DNews/CNews — the same model from the site-owner side).
