# PRD: router-agent zapret2/DPI-bypass knowledge skills

> Source knowledge base: `../todo` (~180 markdown files, Obsidian wiki). Scope locked to router-agent (OpenWrt, fw4/nftables, nfqws2) per AGENTS.md. Triage label: `ready-for-agent`.

## Problem Statement

The router-agent (an OpenWrt SSH agent governed by AGENTS.md) currently has no dedicated knowledge skills for zapret2 DPI-bypass strategies, the nfqws2 engine flag/syntax reference, router-side deployment, or DPI/TSPU detection theory. When the agent encounters these tasks it lacks structured, evidence-tagged reference material and must either lean on the generic AGENTS.md (which covers operational safety but not the strategy/flag/theory knowledge) or reason ad hoc. A large knowledge base already exists at `../todo`, but it is unstructured for router-agent use and mixes router-relevant content with large out-of-scope areas (Windows GUI launcher, Android/Magisk, MTProto proxy-server on VPS, AmneziaWG client, VLESS/endpoint hardening, TSPU site-remediation, PKI/НУЦ, premium/publish tooling). The operator needs the router-relevant subset distilled into a small set of focused, self-contained, evidence-tagged skills that the agent loads on demand without over-triggering on out-of-scope topics.

## Solution

Create 4 opencode skills scoped to router-agent (OpenWrt, fw4/nftables, nfqws2), distilled from the `../todo` knowledge base:

1. **zapret2-strategies** — desync strategy taxonomy (`--lua-desync` family) + orchestrator/circular auto-rotation + preset/profile model.
2. **zapret2-engine-reference** — `filter` / `wf`+NFQUEUE / `payload` / `out-range` / `blob` / fooling flags / argument ordering / MTProto L7-recognition.
3. **zapret2-router-deploy** — OpenWrt+Keenetic/nftables/NFQUEUE deployment + `manual/` networking theory (L2–L7, TCP seq/ack/MSS, conntrack, Lua pipeline) + hostlist/ipset/nftset management + blockcheck.
4. **dpi-tspu-strategy-theory** — DPI inspection funnel (6 stages) + June-2026 "Siberian scheme" (3 AND-conditions) + JA3/JA4 + TTL/autottl semantics → strategy selection.

Each skill is self-contained (inlines the operational safety procedures: safe-mode snapshot/rollback timer, PM-axis detection, preflight, validation, audit logging), evidence-tagged (`verified` / `community-observed` / `hypothesis`), and uses a pack structure (SKILL.md index + separate reference files) for the two large skills and a single SKILL.md for the two small ones. Out-of-scope content is explicitly excluded and must not trigger these skills.

## User Stories

1. As a router-agent operator, I want the agent to have a dedicated skill for zapret2 desync strategies, so that when I ask it to build a DPI-bypass strategy it uses the correct technique (fake/split/disorder/syndata/oob/tcpseg) rather than guessing.
2. As a router-agent operator, I want the strategies skill to explain when to use fake vs multisplit vs multidisorder vs tcpseg, so that I get a strategy matched to my ISP's DPI behavior.
3. As the router-agent, I want each desync technique documented as a reference card with its Lua signature, arguments, position markers, and gotchas, so that I can construct a correct `--lua-desync` chain.
4. As a router-agent operator, I want the strategies skill to include the preset/profile model, so that I can manage multi-profile configs (e.g. a YouTube profile and a Discord profile in one preset).
5. As the router-agent, I want the orchestrator/circular auto-rotation logic documented, so that I can set up a preset that auto-rotates strategies on RST/retransmission/redirect failures.
6. As a router-agent operator, I want a progressive testing ladder (simple tcpseg → dup → split → aggressive) in the strategies skill, so that I can start with the lightest strategy and escalate only if needed.
7. As the router-agent, I want the nfqws1→nfqws2 migration mapping per strategy, so that I can translate legacy presets to the new Lua-based core.
8. As a router-agent operator, I want a dedicated engine-reference skill, so that when I ask about a specific flag (`--out-range`, `--payload`, `--filter`) the agent explains it precisely.
9. As the router-agent, I want filter/wf/payload/out-range/blob documented as separate reference files, so that I load only the relevant reference when needed (context economy).
10. As the router-agent, I want the argument-ordering rules (`--payload`/`--out-range` must precede the `--lua-desync` they scope) documented, so that I don't generate an invalid config.
11. As a router-agent operator, I want the engine-reference skill to bridge winws2 (Windows) specifics to nfqws2 (router) equivalents, so that Windows-only parts (windivert) are clearly marked and not applied on OpenWrt.
12. As the router-agent, I want MTProto L7-recognition (`l7proto` vs `l7payload`, no-hostname → `ipset`/`--filter-l7` required) documented, so that I can correctly filter MTProto traffic on the router.
13. As a router-agent operator, I want a router-deploy skill, so that the agent can install zapret2 on my OpenWrt router (apk on 25.x / opkg on pre-25) following the correct procedure.
14. As the router-agent, I want the deploy skill to inline the operational safety procedures (safe-mode snapshot, rollback timer, PM-axis detect, preflight, validation, audit), so that I apply changes safely without a separate AGENTS.md lookup.
15. As a router-agent operator, I want the deploy skill to cover nftables/NFQUEUE wiring and conntrack specifics, so that nfqws2 actually intercepts traffic on the router.
16. As the router-agent, I want the `manual/` networking theory (L2–L7, TCP seq/ack/MSS, NFQUEUE verdicts, Lua pipeline) included, so that I can debug why a strategy isn't intercepting.
17. As a router-agent operator, I want hostlist/ipset/nftset management in the deploy skill, so that I can scope bypass to specific domains (YouTube/Discord) via dnsmasq nftset.
18. As the router-agent, I want blockcheck troubleshooting included, so that when no strategy works I can run autodetection rather than hardcoding a strategy.
19. As a router-agent operator, I want a DPI/TSPU theory skill, so that the agent understands why a strategy works and can select one based on my ISP's detection model.
20. As the router-agent, I want the DPI inspection funnel (6 stages) documented, so that I can reason about which layer a given DPI rule targets.
21. As a router-agent operator, I want the June-2026 "Siberian scheme" (3 AND-conditions: subnet + TLS fingerprint + connection frequency) documented, so that the agent accounts for it when tuning strategies.
22. As the router-agent, I want JA3/JA4 fingerprint concepts and the TTL/autottl semantics documented, so that I can choose fooling parameters (`ip_autottl`, `ip_ttl`) correctly.
23. As a router-agent operator, I want every claim in the skills tagged with evidence level (verified/community-observed/hypothesis), so that the agent doesn't apply speculation as fact on my live router.
24. As the router-agent, I want hypothesis-tagged content (eternal-h2/h3, statistical morphing) gated behind "report-and-ask", so that I never auto-apply unverified techniques.
25. As a router-agent operator, I want out-of-scope topics (Wi-Fi, Windows GUI, MTProto proxy-server, AmneziaWG client, VLESS endpoint hardening, firmware/sysupgrade) to NOT trigger any of these skills, so that the agent stays in its lane and stops/asks per AGENTS.md.
26. As a router-agent operator, I want the skills to be self-contained (inline ops), so that the agent can operate even when AGENTS.md isn't fully loaded in context.
27. As a router-agent operator, I want the two large skills (strategies, engine-reference) to use a pack structure (index + reference files), so that only the needed reference is loaded and context isn't bloated.
28. As a router-agent operator, I want the two small skills (router-deploy, dpi-theory) as single SKILL.md files, so that they're simple to maintain and load in one shot.
29. As the router-agent, I want inline-ops sections marked with "mirrors AGENTS.md §X as of <date>", so that drift between skills and AGENTS.md is detectable via grep.
30. As a router-agent operator, I want the skills placed under `router-agent/skills/`, so that they're version-controlled alongside AGENTS.md.
31. As a router-agent operator, I want the source-file mapping (which `../todo` file each skill distills) documented, so that I can trace claims back to the original knowledge base.
32. As the router-agent, I want the raw `ipset-discord` CIDR list marked "needs curation" (duplicates, mixed ASNs), so that I don't load it as a ready-made firewall rule.
33. As the router-agent, I want the empty `оркестратор.md` stub ignored and `circular.md` used as the real source, so that I don't reference a non-existent doc.
34. As a router-agent operator, I want a test seam that verifies skill activation routing, so that I can confirm the right skill fires for a given query and out-of-scope queries fire nothing.
35. As a router-agent operator, I want the routing test to include negative cases (Wi-Fi, sysupgrade, Windows GUI, MTProto VPS, AmneziaWG client), so that scope boundaries are enforced and the agent stops/asks instead of over-reaching.

## Implementation Decisions

- **Four skills**, named `zapret2-strategies`, `zapret2-engine-reference`, `zapret2-router-deploy`, `dpi-tspu-strategy-theory`, placed under `router-agent/skills/`.
- **Scope locked to router-agent** (OpenWrt, fw4/nftables, nfqws2). The OpenWrt 25.x (apk) vs pre-25 (opkg) and constrained-vs-capable HW axes from AGENTS.md are respected inside each skill.
- **Structure:** pack (SKILL.md index + reference files) for `zapret2-strategies` and `zapret2-engine-reference`; single SKILL.md for `zapret2-router-deploy` and `dpi-tspu-strategy-theory`.
- **Self-contained ops:** each skill inlines the operational safety procedures it needs (safe-mode snapshot + rollback timer per AGENTS.md §6, PM-axis detection §1, preflight §1, validation §7, audit logging §10) rather than only linking out. Each inlined ops section is marked `mirrors AGENTS.md §X as of <date>` so drift is grep-detectable (chosen mitigation for the self-sufficiency/drift tradeoff).
- **Evidence tagging:** every strategy/claim carries `verified` / `community-observed` / `hypothesis`. Hypothesis-tier content (eternal-h2/h3 fingerprint hypothesis, statistical morphing R&D) is gated behind the AGENTS.md "report-and-ask" discipline and never auto-applied.
- **Source-file mapping per skill:**
  - `zapret2-strategies`: `Zapret2/Zapret2.md`, `Zapret2/desync.md`, `Zapret2/desync/{fake,syndata,multisplit,multidisorder,multidisorder_legacy,fakedsplit,fakeddisorder,hostfakesplit,tcpseg,oob}.md`, `Zapret2/circular.md`, `Zapret2/preset.md`, `Zapret2/profile.md`.
  - `zapret2-engine-reference`: `Zapret2/{filter,wf,windivert,payload,out-range,blob}.md`, `Zapret2/основные флаги.md`, `Zapret2/последовательность аргументов.md`, `Zapret2/распознавание mtproto.md`, plus the nfqws-relevant subset of `Zapret/Zapret flags.md`.
  - `zapret2-router-deploy`: `Zapret/{router,linux,manual}.md`, `Zapret/manual/zapret2_01..06.md` + `zapret2_start_cutoff.md`, `Zapret/{hostlist,ipset,hosts,Что такое файл hosts,Чёрный хостлист,Создание своей категории,Blockcheck,zapret_not_working}.md`, `ipset-discord.md`, `ipset-ovh.txt.md`.
  - `dpi-tspu-strategy-theory`: `DPI/{dpi-analysis-pipeline,browser-ja4-fingerprint-block,tspu-false-blocks-june-2026,tspu-h2-h3-fingerprint-hypothesis,statistical-morphing-concept}.md` and the detection-model/JA3-JA4/TTL-autottl portion only of `VLESS/dpi-tls-june-2026.md`.
- **winws2 vs nfqws2 bridging:** `wf.md`/`windivert.md` are Windows-only; the engine-reference skill marks them "Windows-only, not applied on router" and bridges to the nfqws2/nftables-NFQUEUE equivalent on OpenWrt.
- **MTProto split:** MTProto proxy-server engineering (`Zapret/mtproto/00-11`, `mtproxy/*`) is discarded as out-of-scope; the router-side `распознавание mtproto.md` (L7 recognition, ipset, no-hostname) is kept inside `zapret2-engine-reference`.
- **`ipset-discord.md`:** raw CIDR list with duplicates and mixed ASNs (Discord CDN + Google/Cloudflare); included only as a "needs curation" example, never as a ready-made rule.
- **`оркестратор.md`:** empty stub (frontmatter only) — ignored; `circular.md` is the real orchestrator source.
- **`VLESS/dpi-tls-june-2026.md`:** large and mostly VLESS-transport; only the detection-model / JA3-JA4 / TTL-autottl semantics are extracted into `dpi-tspu-strategy-theory`, the VLESS/REALITY/XHTTP transport engineering is discarded.
- **Discarded as out-of-scope:** Windows GUI launcher (`home/download/discord/youtube/games/.bat/DiscordFix/YTDisBystro/LordSlon/cactuz/Zapret GUI/Сборки/path/Win7-8/Как пользоваться/Манифест/faq/virus/discord-cdn-fix-fake-repos/changelog`), Android/Magisk (`android.md`), MTProto proxy-server, AmneziaWG (`amnezia-2-0/`), VLESS/endpoint hardening (`Localhost-tracking`, `VLESS-SOCKS5-vulnerability`, `VLESS-localhost-protection-guide`, `tunnel-detection-fix-split-ip`, `vless-sni.md`), TSPU site-remediation (`tspu-http2-tls12-fix`, `tspu-disable-quic-chrome`, `tspu-3xui-scmininterval-trap`, `post-*`, `ru-network-blocklists`, `mincifry-nuc-certs`, `nuc-root-mitm`, `post-cert-danger-kratko`), premium/publish/stubs (`premium/*`, `publish.js`, `Privacy Google.md`, `SMS.md`, `Zapret.cmd`, `ZapretVPN.md`), project-meta (`ZapretTeam`, `Волонтёры`, `Дорожная карта`, `ToDo/`).
- **Trigger descriptions:** each skill's frontmatter `description` is tuned for activation precision (fires on router-relevant zapret2/DPI tasks; does not fire on the discarded out-of-scope topics). The `customize-opencode` skill conventions govern frontmatter/format.

## Testing Decisions

- **What makes a good test:** test external behavior only, not implementation details. For knowledge skills the observable external behavior is *skill activation routing* — which skill(s) fire for a given user query — not the prose contents.
- **Single seam (highest point):** a skill-trigger routing suite. A fixture of representative router-agent user queries:
  - in-scope positives, one per skill — e.g. "построй fake+multidisorder стратегию для YouTube на роутере" → `zapret2-strategies`; "что значит `--out-range=-d10`" → `zapret2-engine-reference`; "поставить zapret2 на OpenWrt через apk" → `zapret2-router-deploy`; "почему ТСПУ режет ClientHello по JA4" → `dpi-tspu-strategy-theory`;
  - out-of-scope negatives that must activate none of the four — Wi-Fi setup, Windows GUI launcher, MTProto VPS proxy-server, AmneziaWG client, VLESS/endpoint hardening, firmware `sysupgrade`.
  - Assert: the expected skill activates, the other three do not, and negatives activate nothing (agent falls back to AGENTS.md stop-and-ask).
- **Existing seams:** none — the repo's `skills/` is empty, so a new seam is proposed at the highest point (one seam for all four skills), per the "ideal number is one" principle.
- **Prior art:** the `skill-optimizer` skill's with/without-skill delta benchmark and `skill-creator`'s activation-tuning guidance are the closest analogues in the broader skill ecosystem; the routing suite is the lightweight, deterministic slice of that pattern.

## Out of Scope

- Authoring the actual skill content files (the 4 SKILL.md + reference files). This PRD fixes the category/scope/structure decisions; implementation is the downstream agent task surfaced by the `ready-for-agent` label.
- All discarded knowledge-base areas listed in Implementation Decisions (Windows GUI, Android, MTProto proxy-server, AmneziaWG, VLESS/endpoint hardening, TSPU site-remediation, PKI/НУЦ, premium/publish/stubs, project-meta).
- Modifying AGENTS.md itself (skills mirror it, they do not edit it).
- Any router-device changes — this is a knowledge/skill-authoring effort, not a router engagement.

## Further Notes

- **AGENTS.md drift risk:** self-contained skills duplicate operational procedures; the `mirrors AGENTS.md §X as of <date>` marker + a future grep/CI check is the mitigation. When AGENTS.md §6/§1/§7/§10 change, the mirrored sections need a refresh pass.
- **Evidence-level discipline** matches the source files' own self-tagging (several `DPI/*` files already carry callouts: community-sourced / reverse-engineering / unverified hypothesis / estimates-not-constants). The skills preserve these tags rather than flattening them.
- **Cross-links:** the source files form a graph (`dpi-analysis-pipeline` ↔ `dpi-tls-june-2026` ↔ `statistical-morphing-concept`; `tspu-false-blocks-june-2026` hubs the TSPU notes; the desync cards cross-reference each other). The skills preserve cross-references between their own reference files rather than leaving them isolated.
- **Publish blocker (at PRD creation time):** the local `router-agent` repo was initialized as a standalone git repo (it was previously an untracked subdir of the `../` mega-repo) and committed; `mise.local.toml` (contains `SSHPASS`) is gitignored and was NOT committed. GitHub publish (repo + issue with `ready-for-agent` label) was blocked because the `GITHUB_TOKEN` has no OAuth scopes (`Token scopes: none`) and cannot create repos/issues. The PRD is committed locally under `docs/`; publish is pending token-scope grant.
