---
name: dpi-tspu-strategy-theory
description: >-
  DPI/TSPU detection-theory pack for the OpenWrt router agent (nfqws2). Distills
  the DPI inspection funnel (6 stages: TCP/IP OS fingerprint -> protocol marker
  -> JA3/JA4 TLS fingerprint -> certificate -> flow meta-analysis -> ML), the
  June-2026 "Siberian scheme" behavioural detection model (3 AND-conditions:
  subnet + TLS fingerprint + connection frequency to one SNI -> 120s freeze,
  fidget-trap -> 600s), JA3 vs JA4 mechanics, TTL as a detection vector (OS
  fingerprint + fake-packet catcher), and the hypothesis frontier (eternal-h2/h3
  mechanism, statistical morphing, TLS-in-TLS round-trip, SNI-IP mismatch) gated
  behind report-and-ask. Maps each funnel layer to a countermeasure *class* only
  — it does not name desync techniques, fooling-flag syntax, or transport config.
  Use when: DPI detection model, DPI inspection funnel, how DPI analyses a
  connection, which layer a DPI rule targets, Siberian scheme, June-2026
  behavioural detection, AND-conditions subnet fingerprint frequency, freeze 120s
  600s, fidget trap, JA3 JA4 TLS fingerprint, ClientHello fingerprint, uTLS
  fingerprint theory, OS fingerprint p0f, TTL detection, why fake packets are
  caught by TTL, why a strategy works, strategy selection by ISP detection model,
  countermeasure class, statistical morphing concept, TLS-in-TLS round-trip
  detection, behavioural detection. Do NOT use for: which desync technique to use,
  --lua-desync function semantics, fake syndata multisplit multidisorder position
  markers seqovl, fooling flag syntax ip_autottl ip_ttl values tcp_md5 badsum,
  --filter --payload --out-range --blob --lua-init, router install apk opkg,
  nftables NFQUEUE wiring, hostlist ipset nftset management, blockcheck procedure,
  VLESS REALITY XHTTP mux transport config, SNI donor choice, endpoint hardening,
  wifi wireless, sysupgrade firmware, Windows GUI launcher winws2, MTProto VPS
  proxy-server, AmneziaWG client.
---

# dpi-tspu-strategy-theory — DPI detection model, Siberian scheme, fingerprint & TTL theory pack

Scope: the OpenWrt router agent (nfqws2 engine). This pack covers **DPI/TSPU detection theory** — the conceptual knowledge an agent needs to understand *why* a bypass strategy works and reason about strategy selection by the ISP's detection model. It is a **theory skill**: no router-facing steps, no safe-mode trigger, no `$openwrt-ops` load directive. Operational safety attaches at the *action* step: when the agent acts on this theory it must load `$zapret2-strategies` (technique choice), `$zapret2-engine-reference` (flag syntax), and/or `$zapret2-router-deploy` (install/wiring) — each carries its own ops-reminder and `$openwrt-ops` directive. *(exempt from the inline-ops rule — see ADR-0005)*

## The path: theory explains why, autodetect still rules

zapret2 **MUST** use autodetection / `blockcheck2` — never hardcode a strategy (openwrt-ops §11). This pack explains *why a strategy works* and *which funnel layer it breaks* so the agent can read a `blockcheck2` result, reason about the ISP's detection model, and map a detection vector to a countermeasure class. It does not pick a technique, set a flag value, or prescribe transport config — that is the action-skills' job.

## Evidence tags (ternary + sub-signatures)

Every claim carries one of three tags (assigned during distillation — the source files carry none):

- `[evidence: verified]` — pipeline-solid fact: confirmed by standard (TTL 128/64, JA3 formula, ASN numbers, RST/drop/throttle) or by cited upstream code.
- `[evidence: community-observed]` — empirical model from reverse-engineering or community observation, not code-confirmed. Carries a **sub-signature** naming the source class, because a reproducible model and a brittle constant are not the same thing:
  - `reverse-engineering, multi-source attested` — the Siberian 3-AND model itself (hyperion_cs + eByeBots + net4people/bbs #546 + the `dpi-checkers` "Siberian" subchecker).
  - `snapshot June-2026, operator-variable` — the model's numeric thresholds (120/600s, >3/60s, <350–400ms). Read as order of magnitude, not constants — parameters vary by operator and drift over time.
- `[evidence: hypothesis]` — DPI-behaviour reasoning, effectiveness rationale, or unverified mechanism. **Report-and-ask**: the agent surfaces these to the operator and never builds a recommendation on them as established fact. All hypothesis-tier content is isolated in `reference/hypothesis-frontier.md` (loaded only on explicit demand).

*(See ADR-0002 for why a 4th tag was rejected in favour of sub-signatures.)*

## The DPI inspection funnel — the spine

DPI does not verdict on one packet. It accumulates and **filters at every stage**: cheap checks first, expensive ML last and only for survivors. Bypass tools fight to be filtered out *early* — to look boring before the expensive layers engage. `[evidence: verified]` (the funnel is an analytical model attested across the source notes; the *stages* are standard networking, the *thresholds* are community-observed).

```
              traffic
                │
  Stage 0   ┌───▼───┐  TCP/IP: TTL (OS fingerprint) + TCP options (p0f) -> fake-packet catch
  (TCP/IP)  └───┬───┘  ──> reference/ttl-detection.md
                │
  Stage 1   ┌───▼───┐  protocol marker: 16 03 01… (TLS) / SSH-2.0- / entropy (SS)
  (marker)  └───┬───┘
                │
  Stage 2   ┌───▼───┐  ClientHello -> JA3 / JA4 (client fingerprint)
  (hello)   └───┬───┘  ──> reference/ja3-ja4.md
                │
  Stage 3   ┌───▼───┐  certificate: CT logs, ASN, CN/SAN <-> SNI (TLS 1.2 passive; TLS 1.3 encrypted)
  (cert)    └───┬───┘
                │
  Stage 4   ┌───▼───┐  flow meta-analysis: in/out ratio, inter-packet timing, duration, frequency
  (flow)    └───┬───┘  ──> reference/siberian-scheme.md (Signal 3 = this stage)
                │
  Stage 5   ┌───▼───┐  ML classifier (~after 16KB): sizes, timing, entropy, burst rhythm
  (ML)      └───┬───┘  ──> reference/hypothesis-frontier.md (statistical morphing, TLS-in-TLS)
                │
          verdict -> PASS / RST / drop / throttle
```

The June-2026 **Siberian scheme** is the lower stages of this funnel in behavioural form: fingerprint = Stage 2, frequency/parallelism = Stage 4. `[evidence: community-observed]` (reverse-engineering, multi-source attested).

## Pack contents

- `reference/siberian-scheme.md` — the 3-AND behavioural detection model (subnet + TLS fingerprint + frequency to one SNI), the 120s freeze, the fidget-trap 600s escalation, SNI as aggregation key (not a 4th signal), and why the AND-chain means breaking any one condition defeats the trigger.
- `reference/ja3-ja4.md` — JA3 (MD5, order-sensitive) vs JA4 (`a_b_c`, sorted, GREASE-ignored), the Go-vs-Chrome ClientHello differentiators, uTLS-preset weakness, and the Chrome 134 / `…d8a2da3f94cd` block case.
- `reference/ttl-detection.md` — Stage 0: TTL as OS fingerprint (128/64, per-hop decrement) and as a fake-packet catcher (the detection vector — flag mechanics live in `zapret2-engine-reference/fooling.md`), plus the neighbouring p0f TCP-options vector.
- `reference/hypothesis-frontier.md` — the gated hypothesis tier: eternal-h2/h3 mechanism, statistical morphing concept, TLS-in-TLS round-trip detection, SNI↔IP mismatch. Report-and-ask — never auto-applied.

## Countermeasure-class map (the bridge to action)

This is the "→ strategy selection" bridge: which *class* of countermeasure breaks which funnel layer. **Classes only** — no desync technique names, no fooling-flag syntax, no transport config (those belong to `zapret2-strategies` / `zapret2-engine-reference` / VLESS-out-of-scope respectively). `[evidence: community-observed]` (the layer→class mapping is attested across the source notes; which class fits a given ISP is the agent's reasoning task, not a fixed recipe).

| Funnel layer | Countermeasure class | Notes |
|---|---|---|
| Stage 0 TCP/IP (TTL, OS opts) | correct OS stack / fake-TTL fooling | fake-TTL flag mechanics: `zapret2-engine-reference/fooling.md` |
| Stage 1 protocol marker | TLS-wrapper (looks like ordinary TLS) | transport engineering = out-of-scope |
| Stage 2 JA3/JA4 | uTLS-fingerprint (client Hello mimicry) | transport engineering = out-of-scope |
| Stage 3 certificate/SNI/ASN | REALITY (borrowed identity) | transport engineering = out-of-scope |
| Stage 4 flow meta-analysis | mux / SNI-spread / flow normalisation | transport engineering = out-of-scope |
| Stage 5 ML | statistical morphing (concept, not working tool) | `[evidence: hypothesis]` — see `hypothesis-frontier.md` |

The layers are **orthogonal**: a perfect JA3 can coexist with a dirty subnet; a hidden certificate can coexist with a leaky flow. Robustness comes from covering the funnel top-to-bottom, not from any single class. `[evidence: community-observed]`

## Cross-references

`zapret2-strategies` (desync technique semantics — the "what to do" layer this theory maps onto), `zapret2-engine-reference` (flag syntax — `fooling.md` for the `ip_ttl`/`ip_autottl` mechanics this theory's TTL card bridges to), `zapret2-router-deploy` (install/nftables/blockcheck — the action layer), `openwrt-ops` §11 (the autodetect-never-hardcode rule this theory defers to). Cross-links between reference cards preserve the source-note graph; each card links its siblings rather than duplicating material.
