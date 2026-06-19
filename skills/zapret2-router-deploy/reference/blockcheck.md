# blockcheck — autodetection & the "zapret not working" framework

zapret2 **MUST** use autodetection / `blockcheck2` — never hardcode a strategy (openwrt-ops §11). This file covers the autodetection procedure and the troubleshooting framework for when bypass doesn't work. **Hardcoding a strategy from any source (a community preset, a friend's config, this skill pack) is forbidden** — run `blockcheck2` and let the result shape the config.

## The autodetect-never-hardcode rule

There is **no universal working strategy**. A strategy that works in one region on one ISP on one DPI firmware version may fail in another region on the same ISP. Reasons (the framework below): `[evidence: community-observed]` (the framework is widely attested in upstream documentation; the underlying variability is structural)

1. **TSPU hardware heterogeneity**: one region has old DPI that simple fragmentation defeats; another has modern DPI that reassembles fragments and inspects the TLS handshake deeply.
2. **"Regional lottery"**: what works in Moscow may be blocked in Novosibirsk.
3. **Different backbone providers**: filtering can happen at the regional ISP, the backbone, or both — a strategy that passes one level may fail the other.
4. **Block type determines effectiveness**:
   - **IP block**: zapret2 is powerless — it modifies packet content, not destination address. Needs VPN/proxy (out of scope).
   - **DPI block (content inspection)**: zapret2's target — fragmentation, fake packets, ClientHello splitting.
   - **Throttle (slowdown)**: zapret2 "works" but speed is unusable. Harder to diagnose than a hard block.

`[evidence: community-observed]` (framework from upstream troubleshooting documentation).

> "Not working" is a **symptom, not a cause**. zapret2 is a packet manipulator — it doesn't "break"; the ISP's DPI updates and the previously-effective strategy becomes visible. Fix the profile (run `blockcheck2`), don't reinstall zapret2. `[evidence: community-observed]`

## `blockcheck2` — the autodetection procedure

`blockcheck2` is the engine's autodetection tool (shipped in `/opt/zapret2/bin/` per `deploy.md` layout). It systematically tries combinations of desync techniques, fooling flags, and positions against a target, and logs which combinations get through. `[evidence: community-observed]` (tool behaviour widely attested; specific combinatorial coverage is upstream-defined).

### When to run it

- No stock preset works for a site.
- A previously-working strategy stopped working (DPI update suspected).
- Setting up zapret2 on a new ISP/region for the first time.
- The operator asks "which strategy is best for X".

`[evidence: community-observed]`

### Procedure

1. **Pick the target**: a specific blocked site (e.g. `https://www.youtube.com`) or service (Discord voice). blockcheck tests against one target at a time.
2. **Run `blockcheck2`** on the router (it must be installed per `deploy.md` and NFQUEUE wired per `nfqueue-wiring.md` — though blockcheck can also run in a standalone mode without the full init-script setup, the router-context run uses the live NFQUEUE path):
   ```sh
   # From /opt/zapret2/bin/
   sh /opt/zapret2/bin/blockcheck2.sh <target-domain> 2>&1 | tee /tmp/blockcheck-<target>.log
   ```
   Run under safe-mode (openwrt-ops §6) if it modifies state; a pure test run that doesn't write config is read-only and doesn't need the timer. `[evidence: community-observed]`
3. **Wait** — the run takes **~1 hour or more**. It tests many combinations sequentially. Do **not** close the session (a closed SSH session may kill the foreground process — use `tmux`/`screen` on capable HW, or `nohup` on constrained HW). `[evidence: community-observed]`
4. **Read the log** (`/tmp/blockcheck-<target>.log`): it reports which strategy combinations succeeded. The successful combinations are the candidates for the preset's profile for that target. `[evidence: community-observed]`
5. **Translate the result into a profile** using `zapret2-strategies` (desync technique semantics) + `zapret2-engine-reference` (flag syntax + argument ordering). Don't copy a raw blockcheck line into the config without understanding it — blockcheck output is a starting point, not a drop-in config. `[evidence: hypothesis]` (translation discipline is operator-policy; not upstream-mandated but the safe path).
6. **Apply under safe-mode** (openwrt-ops §6): snapshot → edit `/opt/zapret2/config` → `sh -n` validate → arm timer → restart zapret2 → validate `ps` + `logread` → confirm/disarm/audit (the openwrt-ops Appendix B procedure). `[evidence: verified]`

### Scope

`blockcheck2` is primarily for **YouTube and Discord** (the canonical Russian-block targets). For other sites, it can still produce useful results but the combinatorial coverage may be tuned to the canonical targets. `[evidence: community-observed]`

## "No strategy works" — decision tree

Walk top-down; stop at the first failing layer.

| # | Layer | Check | If fail | Evidence |
|---|-------|-------|---------|----------|
| 1 | zapret2 installed & running? | `ps w \| grep [n]fqws2` | Install per `deploy.md`; start via init script. | verified |
| 2 | NFQUEUE wired? | `nft list ruleset \| grep 'queue num'` | Wire per `nfqueue-wiring.md`. | verified |
| 3 | Flow offload off? | `uci -q get firewall.@defaults[0].flow_offloading` | Disable per `nfqueue-wiring.md` §flow-offload-conflict. | community-observed |
| 4 | Target actually DPI-blocked (not IP-blocked, not GEO-blocked)? | Try a non-DPI method: does a VPN/proxy reach it? If yes but zapret2 doesn't, it's DPI. If VPN also fails on RU IP, it's GEO (site self-blocks RU) — zapret2 can't help, see `hosts` approach (out of scope here). If the target IP itself is blocked (ping fails to the IP from RU), it's IP-block — zapret2 can't help. | community-observed |
| 5 | Throttle not block? | Site loads but slowly? Speedtest during the bypass vs without. If throughput is the issue, it's a throttle — zapret2 may be "working" but ineffective against the throttle pattern. | community-observed |
| 6 | Local conflict? | Antivirus/firewall on the **client** (not router) intercepting? Another VPN running on the client? DoH/DoT bypassing the router's DNS so dnsmasq nftset doesn't see the domain? | community-observed |
| 7 | Multi-CDN site? | Site loads main page but sub-resources (analytics, fonts, API) fail? Those may be on different domains/CDNs — the hostlist scope is too narrow. | community-observed |
| 8 | Strategy actually applies to the flow? | `--lua-desync=posdebug` + `--lua-desync=luaexec:code="DLOG(...)"` (see `theory.md` §7) — did the strategy fire on the right packet? | verified |
| 9 | Run `blockcheck2` | If layers 1-8 pass and bypass still fails → autodetect. | community-observed |

`[evidence: verified]` for the tool-command semantics; `[evidence: community-observed]` for the diagnostic framework (attested in upstream troubleshooting documentation).

## The "zapret not working" mental model

zapret2 is one link in a chain: `[evidence: community-observed]` (chain model from upstream documentation)

```
Browser → OS → Antivirus → zapret2 → Router → ISP → Backbone → Target server
```

A failure or conflict at any link breaks the whole chain. The same strategy gives different results for different users even on the same ISP in the same city — because the client-side links (browser, OS, antivirus, local VPN, DoH) differ. `[evidence: community-observed]`

### Common client-side conflicts (out of router-agent scope, but diagnose)

- **Antivirus / third-party firewall on the client**: sees zapret2's packet manipulation as a threat, blocks it. Add exclusions on the client. (Out of scope — agent acts on the router, not the client.) `[evidence: community-observed]`
- **VPN running on the client**: creates its own routing, may bypass the router's NFQUEUE path entirely. `[evidence: community-observed]`
- **Client DoH/DoT**: DNS queries bypass the router's dnsmasq, so the dnsmasq nftset never gets populated — the NFQUEUE rule's `@zapret_v4` match is empty. Fix: force router-level DNS (openwrt-ops §4 dnsmasq-full + https-dns-proxy) or use a `--hostlist` (domain) scope instead of `--ipset`/nftset (IP) scope. `[evidence: community-observed]`
- **Router forcing ISP DNS**: if the router hands out ISP DNS via DHCP, dnsmasq may not be the resolver clients use — nftset stays empty. `[evidence: community-observed]`

### Version freshness

Before a deep debug, confirm zapret2 is the latest release. The built-in update check has been broken in some versions (the update server was DDoS'd/moved) — check the version manually against upstream and update per `deploy.md` §Upgrade. `[evidence: community-observed]`

## Gotchas

- **`blockcheck2` takes ~1 hour.** Don't close the session. Use `tmux`/`screen` on capable HW; `nohup ... &` on constrained HW. `[evidence: community-observed]`
- **The log is the deliverable.** Without the log, the run is useless. `tee` to a file in `/tmp` (tmpfs, no flash wear). `[evidence: community-observed]`
- **A blockcheck result is not a drop-in config.** It's a starting point — translate it through `zapret2-strategies` + `zapret2-engine-reference` before writing to `/opt/zapret2/config`. `[evidence: hypothesis]` (translation discipline is operator-policy).
- **Don't run `blockcheck2` against a target you don't own/aren't authorised to test.** It generates unusual traffic patterns. Stick to your own blocked-site access testing. `[evidence: hypothesis]` (operator-conduct policy).
- **GEO-blocks are not DPI blocks.** A site that self-blocks RU users (e.g. ChatGPT) is not something zapret2 can fix — zapret2 modifies packet content, not your geography. Use a VPN/proxy for GEO-blocks (out of scope). `[evidence: community-observed]`
- **IP blocks are not DPI blocks.** If the target IP is unreachable from RU, zapret2 (a packet manipulator) can't help — use a VPN/proxy. `[evidence: verified]` (zapret2 operates on packet content, not routing).
- **Throttle is the hardest to diagnose.** "Site loads but slowly" may be a throttle, not a block — zapret2 "works" but the throttle pattern targets the bypassed flow's shape. `[evidence: community-observed]`
- **Don't reinstall zapret2 to "fix" a broken strategy.** The binary didn't break; the DPI evolved. Run `blockcheck2` and fix the profile. `[evidence: community-observed]`

## Cross-references

`deploy.md` (install blockcheck2 as part of `/opt/zapret2/bin/`); `nfqueue-wiring.md` (wiring must be correct before blockcheck results are meaningful); `theory.md` §7 (the `posdebug`/`luaexec` debug recipe used in decision-tree step 8); `hostlist-ipset-nftset.md` (domain vs IP scoping — relevant when blockcheck targets a specific site); `zapret2-strategies` (translate blockcheck results into a desync chain — `reference/fake.md`, `multisplit.md`, etc.; `testing-ladder.md` for the progressive escalation order); `zapret2-engine-reference/reference/arg-ordering.md` (correct flag ordering when composing the resulting profile); `openwrt-ops` §6 (safe-mode for the apply step), §11 (no hardcoded strategy), Appendix B (safe-mode zapret2 config edit).

## Source mapping

Upstream code: `blockcheck2` tool shipped in zapret2 tarball (`/opt/zapret2/bin/`). Upstream documentation: openwrt-ops §11 (no hardcoded strategy mandate), §6/Appendix B (safe-mode config edit procedure). Troubleshooting framework: the upstream `zapret_not_working` note (DPI heterogeneity, regional lottery, block-type taxonomy, link-chain model, client-side conflict list, version-freshness caveat).
