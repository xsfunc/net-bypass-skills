# ttl-detection — TTL as a detection vector (Stage 0)

DPI starts sniffing a connection before any TLS — at the TCP/IP headers. Stage 0 of the funnel uses TTL and TCP options as a **passive OS fingerprint** and as a **fake-packet catcher**. This card covers the *detection vector*; the *flag mechanics* that answer it (`ip_ttl`/`ip_autottl` syntax, `delta,min-max` format, conntrack requirement) live in `zapret2-engine-reference/reference/fooling.md` — this card bridges by name, without duplicating syntax. *(See ADR-0001.)*

## TTL — OS fingerprint and fake-catcher

Starting TTL differs by OS: **Windows → 128, Linux/macOS/iOS → 64**. Each intermediate hop decrements TTL by 1 — so `TTL 63` passed one hop, `TTL 62` two. `[evidence: verified]` (IP standard; TTL semantics are RFC-defined)

Two consequences for bypass:

1. **OS fingerprint.** The starting TTL (reverse-computed from observed TTL + hop count) roughly identifies the client OS. `[evidence: verified]`
2. **Fake-packet catcher.** Tools like zapret2 send fake packets with a *low* TTL so they reach the DPI on the path but "die" before the real server. If DPI cross-checks the fake's TTL against the OS fingerprint it implies, it distinguishes the fake from a real packet. This is the direct link between Stage 0 of the funnel and the zapret2 fooling model. `[evidence: community-observed]` (the fake-by-TTL technique and DPI's TTL cross-check are attested across the source notes; whether a given ISP cross-checks is operator-variable)

## The bridge to fooling flags (concept only)

The detection vector maps to the **fake-TTL fooling** countermeasure class. The *concept*: if DPI cross-checks TTL against the OS fingerprint, the fake needs a plausible TTL — that is the `ip_autottl` flag (auto-detect a believable TTL from observed traffic); if DPI does *not* cross-check, a fixed `ip_ttl` suffices. **The flag syntax, the `delta,min-max` format, the conntrack requirement — those are in `zapret2-engine-reference/reference/fooling.md`.** This card does not repeat them. `[evidence: verified]` (the layer→class mapping; flag mechanics are out-of-scope for this card per ADR-0001)

## Neighbouring vector — p0f (TCP options)

Stage 0 has a second OS-fingerprinting vector: the **set and order of TCP options in the SYN** — `MSS`, `Window Scale`, `SACK`, `Timestamps` — varies by OS and version (the p0f technique). By one SYN, DPI can say "looks like Windows 11" or "looks like Linux." `[evidence: verified]` (p0f is a well-established passive fingerprinting technique)

**No fooling response in zapret2.** There are no flags for MSS/Window-Scale/SACK/Timestamps manipulation — p0f is a theoretical marker here, not actionable through zapret2. Mentioned for funnel completeness so the agent does not hunt for a non-existent flag. `[evidence: verified]` (absence of such flags in the engine-reference fooling set)

## Illustrative thresholds (not constants)

Author estimates from the source note, **not confirmed TSPU constants** — read as order of magnitude: "the first ~5 packets of a connection pass without active intervention" (DPI gathers context first); "if the first content packet after the handshake is shorter than ~83 bytes, that is suspicious." `[evidence: community-observed]` (snapshot, author estimate — illustrative of the logic, not a confirmed constant)

## Cross-references

`ja3-ja4.md` (Stage 2 — the next fingerprinting layer), `siberian-scheme.md` (the Siberian trio operates at Stages 2 and 4, not Stage 0), `SKILL.md` (the funnel spine). `zapret2-engine-reference/reference/fooling.md` (the `ip_ttl`/`ip_autottl` flag mechanics this card bridges to — load it when the agent needs to *set* a fooling value, not when reasoning about *why* TTL detection works).

## Source mapping

Upstream note: `DPI/dpi-analysis-pipeline.md` Stage 0 (TTL as OS fingerprint and fake-catcher, p0f TCP-options, the 5-packet/83-byte illustrative thresholds). The TTL-as-fooling-mechanics reference is `zapret2-engine-reference/reference/fooling.md` (sourced from `lua/zapret-lib.lua` `apply_fooling()`/`parse_autottl`).
