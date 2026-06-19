# ja3-ja4 — TLS client fingerprinting (Stage 2)

When the protocol marker (Stage 1) says "this is TLS", DPI collapses the `ClientHello` into a fingerprint. This is Stage 2 of the funnel — the layer that identifies *which client* (Chrome 13x, bare Go, Firefox, …) opened the connection, and the layer the Siberian scheme's Signal 2 operates on. `[evidence: verified]` (JA3/JA4 are published specifications; the fingerprinting behaviour is standard DPI practice)

## JA3 — order-sensitive MD5

```
JA3 = MD5(SSLVersion, Ciphers, Extensions, EllipticCurves, ECPointFormats)
```

Five fields, GREASE values excluded, **order-sensitive** — the fields are hashed in the order they appear in the packet. `[evidence: verified]` (JA3 specification, Salesforce/FoxIO)

The order-sensitivity is the weakness: Chrome **shuffles extension order** per connection (officially since Chrome 110, Jan 2023; visible in 108–109 builds), so JA3 "floats" for Chrome and is easily evaded. This is why JA4 exists. `[evidence: verified]` (Chrome extension shuffling is documented)

## JA4 — sorted, GREASE-ignored, three-part string

JA4 (FoxIO, 2023) is more robust: it **sorts** ciphers and extensions before hashing and **ignores GREASE**. It is not one hash but a string `a_b_c`:

- **a** (readable): transport (`t` TLS-over-TCP / `q` QUIC / `d` DTLS), TLS version, SNI presence (`d` domain / `i` IP), cipher count, extension count, ALPN. Example: `t13d1516h2` = TCP, TLS 1.3, SNI present, 15 ciphers, 16 extensions, ALPN h2.
- **b**: truncated SHA256 of **sorted** cipher suites.
- **c**: truncated SHA256 of **sorted** extensions (minus SNI and ALPN), followed by **signature algorithms — unsorted** (intentionally left unsorted as an extra distinguishing feature).

`[evidence: verified]` (JA4 specification, FoxIO/ja4)

Because it sorts, JA4 is not fooled by extension shuffling. The version field: `0x0303` in ClientHello is `legacy_version` (formally TLS 1.2, set for compatibility) — JA4 takes the real version from the `supported_versions` extension (`0x0304` = TLS 1.3), not the legacy field. `[evidence: verified]` (RFC 8446; JA4 spec)

## Go-vs-Chrome — how DPI tells a bare client from a browser

A bare Go `crypto/tls` ClientHello is a unique marker (uTLS devs: "Golang's ClientHello has a very unique fingerprint"). Any of the top three differences is enough to passively distinguish Go from Chrome:

| Feature | bare Go | Chrome |
|---|---|---|
| GREASE | absent | 5 places |
| Extension order | fixed | shuffled (since 110) |
| `application_settings`/ALPS | absent | present |
| `compress_certificate`/brotli | absent | present |
| ECH | absent | present (where enabled) |
| Extension count | ~10–12 | ~17–18 |
| PQ `X25519MLKEM768` key_share | since Go 1.24 | since Chrome v131 |

`[evidence: verified]` (RFC 8448 ClientHello anatomy; the Go-vs-Chrome differences are structural)

## uTLS — the countermeasure class, and its weakness

uTLS (refraction-networking/utls) is a fork of `crypto/tls` that swaps the ClientHello by preset — a borrowed browser handwriting. This is the **uTLS-fingerprint** countermeasure class for Stage 2. The transport config (which preset to select) is out-of-scope; the agent reasons about the *class* and its limits here, then defers to the operator/transport-engineering for preset choice. `[evidence: verified]` (uTLS is a real library; the class mapping is the funnel-layer bridge)

Its weakness — why "mass `chrome`" gets caught:

- **Preset list is small and enumerable** (~50 presets in `u_common.go`). A censor can enumerate all uTLS preset JA3/JA4 values. `[evidence: community-observed]`
- **Presets go stale.** A preset without post-quantum `key_share` (`X25519MLKEM768`) is itself anomalous for a "fresh" browser. Keep xray/uTLS current. `[evidence: community-observed]`
- **CVE-2026-27017** (closed in uTLS 1.8.1). `[evidence: community-observed]`
- **Real-preset mimicry vs synthetic generation** — two distinct approaches: picking a *real* browser preset per connection yields valid handwriting; generating a *synthetic* ClientHello with random ciphers/extensions (not a real browser, different each connection) is itself anomalous at Stage 2 — a synthetic print is statistically visible, and has been observed getting blocked (MGTS MSK, April 2026). Not a panacea. `[evidence: community-observed]`

Saving grace: banning a *popular valid* fingerprint is costly for the censor — real users break. `[evidence: community-observed]`

## Field case — Chrome 134 / `…d8a2da3f94cd` block

A documented block (June 2026, `wireflow.space`): the site opens in Firefox/Safari/`curl` but not Chrome/Edge. DPI blocks **one specific JA4** — `t13d1516h2_8daaf6152771_d8a2da3f94cd` (Chrome 134-generation, also Telegram MTPROTO FakeTLS's print) — not "Chrome in general". Fresh Chrome 148 (`t13d1514h2_…`, 14 extensions) passes. F5 (session resumption) adds `pre_shared_key`, shifting 16→17 extensions and the hash, so the print no longer matches the rule. `[evidence: community-observed]` (multi-observer, community-source — telegramdesktop/tdesktop#30733)

The block is "blacklist of specific bypass JA4 values"; old Chrome/Edge builds that happened to share the print were collateral damage. `[evidence: community-observed]`

## Cross-references

`siberian-scheme.md` (Signal 2 = this fingerprint layer), `ttl-detection.md` (Stage 0 — the layer below), `hypothesis-frontier.md` (eternal-h2/h3 mechanism, SNI↔IP mismatch). The countermeasure class for this layer is uTLS-fingerprint — transport config (xray `fingerprint:` field, preset selection) is out-of-scope; the agent reasons about the *class*, then defers to the operator/transport-engineering for config.

## Source mapping

Upstream notes: `DPI/dpi-analysis-pipeline.md` Stage 2 (JA3 formula, JA4/sorting, GREASE nuance), `VLESS/dpi-tls-june-2026.md` (JA3 vs JA4 detail, Go-vs-Chrome table, uTLS mechanics/weakness, `random` vs `randomized`), `DPI/browser-ja4-fingerprint-block.md` (the Chrome 134 / `…d8a2da3f94cd` case, F5/session-resumption shift, Telegram FakeTLS link).
