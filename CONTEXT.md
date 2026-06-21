## Language

### Detection model

**DPI inspection funnel**:
The 6-stage model of how DPI (ТСПУ) analyses a connection from first SYN to ML classifier — TCP/IP headers → protocol marker → JA3/JA4 → certificate → flow meta-analysis → ML. Cheap checks first, expensive ML last and only for survivors; bypass tools try to be filtered out early.
_Avoid_: DPI-конвейер, воронка ТСПУ

**Siberian scheme**:
A behavioural detection model (June 2026): an AND-chain of three conditions — destination subnet + client TLS-fingerprint + connection frequency to one SNI. All three must match to trigger; breaking any one defeats it. Reverse-engineered (single researcher, multi-source attested), operator-variable, a June-2026 snapshot not a universal law.
_Avoid_: июньская блокировка (the date will rot), сибирская блокировка (blurs the AND-nature)

**freeze**:
The 120-second throttle-block the Siberian scheme applies when all three conditions match — not an RST, but quiet degradation (timeouts/slowdown) that looks like bad connectivity, not censorship. A fidget-triggered escalation extends this to 600 s on all TLS regardless of fingerprint/SNI.
_Avoid_: бан (implies permanence), блок (too generic)

**OS fingerprint (passive)**:
Passive identification of the client OS from TCP/IP headers: the starting TTL (128 Windows / 64 Linux·macOS, decremented per hop) and the set/order of TCP options in the SYN (MSS/Window Scale/SACK/Timestamps — the p0f technique). Stage 0 of the funnel.
_Avoid_: TCP-отпечаток

### Countermeasures

**countermeasure class**:
A category of response that defeats a funnel layer (OS-stack/fake-TTL, TLS-wrapper, uTLS-fingerprint, REALITY, mux/SNI-spread, statistical-morphing) — a conceptual category, not a specific technique or flag. The dpi-theory skill maps funnel layers to these classes only; it does not name desync techniques, flag syntax, or transport config (those belong to `zapret2-strategies` / `zapret2-engine-reference` / VLESS-out-of-scope).
_Avoid_: стратегия (reserved for desync techniques in `zapret2-strategies`), обход (too generic)

**TTL fooling**:
The `ip_ttl` / `ip_autottl` parameters that make a zapret2 fake packet plausible to a DPI that cross-checks TTL against the OS fingerprint. The *flag mechanics* live in `zapret2-engine-reference/reference/fooling.md`; the *detection vector* (DPI catches fakes by TTL mismatch) lives in `dpi-tspu-strategy-theory/reference/ttl-detection.md`.
_Avoid_: TTL-обман

### Skill taxonomy

**theory skill**:
An opencode skill with no router-facing steps — the agent reads it to reason, and acts through other skills. `dpi-tspu-strategy-theory` is the theory skill: it carries no safe-mode trigger and no `$openwrt-ops` load directive; operational safety attaches at the action step via `zapret2-strategies` / `zapret2-engine-reference` / `zapret2-router-deploy`, each of which has its own ops-reminder.
_Avoid_: пассивный скилл
