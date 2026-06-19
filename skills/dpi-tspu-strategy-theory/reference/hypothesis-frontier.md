# hypothesis-frontier — the gated speculation tier

**Everything in this card is `[evidence: hypothesis]`.** These are DPI-behaviour reasoning, unverified mechanisms, or research concepts — **report-and-ask**: the agent surfaces these to the operator and never builds a recommendation on them as established fact, never auto-applies them on a live router. This file is loaded only on explicit demand; it is isolated from the verified+community-observed core so that activating the skill for ordinary reasoning does not pull speculation into context. *(See ADR-0003.)*

## eternal-h2/h3 mechanism — effect confirmed, mechanism not

**Observation (confirmed):** XHTTP with HTTP/3 masks better than REALITY+vision on port 443; REALITY+vision on 443 gets blocked. `[evidence: community-observed]` (net4people/bbs #546, XTLS/Xray-core #5332 — the *effect* is multi-source attested)

**Hypothesised mechanism (NOT confirmed):** DPI catches proxies by "eternal HTTP/2" — a real browser migrates to HTTP/3 via `Alt-Svc` at the first opportunity, while a proxy client stays on h2 forever, and that "no h3 transition" is the tell. `[evidence: hypothesis]` (single observer, 11 June 2026; no independent confirmation of the *mechanism*)

**Competing, more economical explanation:** XHTTP+h3 helps not because "h2 is the tell" but because QUIC folds everything into *one* connection and mux multiplexes streams — i.e. it reduces the *count* of recognisable TLS connections (the Siberian Signal 3 / Stage 4), and REALITY+vision on 443 suffers from the single-TLS-stream-on-standard-port pattern, not from "no h3 transition." Two independent sources (net4people/bbs #546, Habr 990236) explain the same effect *without* the h2/h3 mechanism. `[evidence: community-observed]` (the competing explanation is itself multi-source)

**Verdict:** the practical advice (move to XHTTP+h3 / mux, off port 443) is attested; the *reason* "h2 gives away the proxy" is speculation. Report the advice as community-attested, the mechanism as hypothesis. `[evidence: hypothesis]`

## statistical morphing — concept, not a working defence

The concept: mask not the *protocol* but the *behaviour* — make the bypass channel replay the user's own traffic statistics (pauses, volumes, rhythm) so it looks like "this person reading a feed," not "a proxy." It targets Stage 4 (flow meta-analysis) / Stage 5 (ML), where uTLS (Stage 2) cannot reach. `[evidence: hypothesis]` (a concept for discussion, no working implementation — author-positioned as "channel of last resort" for text at 64–128 Kbit/s)

**Why it is hard — the "parrot is dead" limit.** Mimicry systems are fundamentally vulnerable (Houmansadr, Brubaker, Shmatikov, IEEE S&P 2013): imitation must be perfect across *all* side channels at once — error reaction, packet-loss response, retry timing, edge cases. The censor finds the discrepancy the mimicker did not reproduce. The concept's own author names this: "the censor can distinguish traffic by different reaction to packet loss." `[evidence: hypothesis]` (theoretical limit, widely accepted in the traffic-analysis literature)

**Does not close the round-trip vector.** Even perfect size/pause morphing does not remove the *number of round-trips* of a nested TLS handshake — the TLS-in-TLS detection vector below. Morphing raises the *cost* of detection, it does not close it. `[evidence: hypothesis]`

This is the **statistical-morphing** countermeasure class for Stage 5 — a research direction, not an action-skill input. `[evidence: hypothesis]`

## TLS-in-TLS round-trip — a separate detection vector

A nested TLS handshake has a characteristic choreography: a burst of packets from the client → a one-RTT pause → a burst from the server. When that handshake runs *inside* a tunnel, the sequence "shines through" the outer encryption as a recognisable rhythm. USENIX Security 2024 ("Fingerprinting Obfuscated Proxy Traffic with Encapsulated TLS Handshakes"): padding and mux do *not* change the RTT structure — TPR >70%; Vision padding → ~51%. `[evidence: hypothesis]` (a research-paper result; whether ТСПУ specifically deploys it is not confirmed — the technique exists in the literature, its operational use by the censor is hypothesised)

**This is NOT part of the Siberian trio** — the source explicitly: "a separate vector, not the Siberian Signal 3." `[evidence: hypothesis]`

## SNI↔IP mismatch — a hypothesised future check

A consistency check: the SNI in `ClientHello` should match the server's IP/ASN (e.g. `icloud.com` → AS714 Apple). A mismatch (SNI = `icloud.com`, IP = random hosting) could be a detection signal. `[evidence: hypothesis]` ("practitioners' forecast, not a confirmed part of the scheme; the primary source has three signals, no SNI↔IP check… a hypothesis about DPI development, not a recorded rule")

**Why it is only a hypothesis:** in TLS 1.3 the certificate is encrypted, so passive DPI sees only SNI + ASN/IP — and CDN legitimately put brand traffic in foreign ASes (iCloud Private Relay via Akamai/Cloudflare/Fastly, not AS714), so a crude "foreign AS → dirty" check yields false positives. The censor would need a per-brand AS/CDN allowlist, which is non-trivial. `[evidence: verified]` (TLS 1.3 cert encryption is RFC 8446; CDN AS-mixing is factual) + `[evidence: hypothesis]` (that DPI does/does not run this check)

## Cross-references

`siberian-scheme.md` (what is *not* part of the verified trio lives here), `ja3-ja4.md` (uTLS-preset weakness — the Stage 2 analogue of "mimicry has limits"), `SKILL.md` (the funnel spine — these vectors span Stages 4–5). None of these hypotheses name an action-skill input; if the operator wants to act on any of them, the agent reports and asks before proceeding.

## Source mapping

Upstream notes: `DPI/tspu-h2-h3-fingerprint-hypothesis.md` (eternal-h2/h3 — self-tagged "НЕВЕРИФИЦИРОВАННАЯ ГИПОТЕЗА", the verification section is the source for the competing explanation), `DPI/statistical-morphing-concept.md` (statistical morphing concept, "parrot is dead" limit — Habr 1012926, @unxed), `VLESS/dpi-tls-june-2026.md` (TLS-in-TLS round-trip per USENIX 2024, SNI↔IP mismatch as hypothesised check), `DPI/dpi-analysis-pipeline.md` (Stage 5 ML context, the 16KB threshold).
