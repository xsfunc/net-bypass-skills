# list-management — ipset list-fetching infrastructure, ip2net, mdig

This card documents the **list-fetching infrastructure** under `/opt/zapret2/ipset/`, the `ip2net` IP-aggregation utility, and the `mdig` multi-threaded DNS resolver. These produce the hostlist/ipset files that `MODE_FILTER=ipset`/`hostlist`/`autohostlist` (`config-file.md` §3) load into the engine and kernel sets. `[evidence: verified]` (script names and behaviour are code-defined in `ipset/*.sh`, `ip2net/`, `mdig/`); `[evidence: community-observed]` (list-source quality).

For the **engine-side** `--hostlist`/`--ipset` flag semantics and the dnsmasq nftset wiring, see `hostlist-ipset-nftset.md` — this card covers the *production* of the lists, not their *consumption*.

## Standard list files

`[evidence: verified]` (file names + types in `ipset/*.sh`).

| Hostlist | Type | Purpose | IP lists |
|----------|------|---------|----------|
| `zapret-hosts-user.txt` | user | inclusion | `zapret-ip-user.txt` / `zapret-ip-user6.txt` |
| `zapret-hosts-user-exclude.txt` | user | exclusion | `zapret-ip-exclude.txt` / `zapret-ip-exclude6.txt` |
| `zapret-hosts-user-ipban.txt` | user | traffic redirect | `zapret-ip-user-ipban.txt` / `zapret-ip-user-ipban6.txt` |
| — | generated | traffic redirect | `zapret-ip-ipban.txt` / `zapret-ip-ipban6.txt` |
| `zapret-hosts.txt` | generated | inclusion | `zapret-ip.txt` / `zapret-ip6.txt` |

- User hostlists may contain hostnames / IPv4 / IPv6 / CIDR; generated hostlists only hostnames. `[evidence: verified]`
- gzip supported (`.gz` appended). `[evidence: verified]`
- IP lists split v4/v6 — the v6 file has `6` before the extension (e.g. `zapret-ip6.txt`). `[evidence: verified]`
- Inclusion IP lists → kernel sets only if `MODE_FILTER=ipset`; the exclusion IP list is always loaded. `[evidence: verified]`
- ipset names: `nozapret`/`nozapret6` (exclude), `zapret`/`zapret6` (include), `ipban`/`ipban6`. ipfw uses sets combining v4+v6. `[evidence: verified]`

## ipset scripts

`[evidence: verified]` (script names + behaviour in `ipset/*.sh`).

| Script | Purpose | Evidence |
|--------|---------|----------|
| `clear_lists.sh` | Remove all generated list files | verified |
| `create_ipset.sh [clear\|no-update]` | Create kernel ipset/nftset (backend auto by `FWTYPE`/OS) | verified |
| `get_config.sh` | Runs `GETLIST` (or `get_ipban.sh`); the cron entry point | verified |
| `get_user.sh` | Fetch/refresh the user list | verified |
| `get_ipban.sh` | Fetch/refresh the ipban list | verified |
| `get_exclude.sh` | Fetch/refresh the exclusion list | verified |
| `get_antifilter_*.sh` | antifilter.network source | verified |
| `get_antizapret_domains.sh` | prostovpn.org source | verified |
| `get_refilter_*.sh` | 1andrevich/Re-filter-lists source | verified |
| `get_reestr_*.sh` | bol-van/rulist source | verified |

`get_reestr_*` variants: `resolvable_domains`, `preresolved`, `preresolved_smart` — the latter ships a problematic-AS list (AS32934/13414/13335/15169/16509/16276/24940 — Facebook/Cloudflare/Google/Amazon/OVH; IPs in these ASes are excluded from the smart list because they host both blocked and unblocked properties) and a white-AS list (AS47541/35237/47764/13238/47764 — RU hosters whose blocks are unlikely to be DPI). `[evidence: verified]` (variant names + AS lists in `ipset/get_reestr_*.sh`); `[evidence: community-observed]` (list-source quality — the problematic-AS heuristic is upstream policy, not a measured invariant).

`GETLIST` in `config` (`config-file.md` §11) selects which fetcher `get_config.sh` runs. Comment out `GETLIST` to disable auto-fetch. `[evidence: verified]`

## ipban system

The ipban pipeline produces kernel `ipban`/`ipban6` sets for your own PBR/proxy redirect — **zapret does not use them** for bypass. Use `INIT_FW_*_HOOK` (`config-file.md` §10) for sync with your PBR rules. `[evidence: verified]` (ipban-set names + that the engine doesn't consume them); `[evidence: community-observed]` (PBR-sync pattern widely attested).

## `ip2net` utility

Groups IPs into subnets to shrink the IP lists. stdin → stdout. `[evidence: verified]` (utility in `ip2net/`).

| Flag | Purpose | Evidence |
|------|---------|----------|
| `-4` / `-6` | ipv4 (default) / ipv6 | verified |
| `--prefix-length=min[-max]` | e.g. `22-30` (v4), `56-64` (v6) | verified |
| `--v4-threshold=mul/div` | e.g. `3/4` (integer math, keep ≤32-bit) | verified |
| `--v6-threshold=N` | min IPs to form a v6 subnet | verified |

Records `ip/prefix` and `ip1-ip2` pass through unchanged. Algorithm: in the prefix range, find subnets with max addresses; if tie, pick the smallest (largest prefix). ipset handles `ip1-ip2` optimally for `hash:net`; ipfw only understands `ip/prefix`. `[evidence: verified]` (algorithm in `ip2net/`).

Configured via `IP2NET_OPT4`/`IP2NET_OPT6` (`config-file.md` §14). `[evidence: verified]`

## `mdig` utility

Multi-threaded DNS resolver. stdin domains → stdout IPs, errors to stderr. `[evidence: verified]` (utility in `mdig/`).

| Flag | Purpose | Evidence |
|------|---------|----------|
| `--family=<4\|6\|46>` | IP family | verified |
| `--threads=<N>` | default `1` | verified |
| `--eagain=<retries>` | default `10` | verified |
| `--eagain-delay=<ms>` | default `500` | verified |
| `--verbose` | verbose | verified |
| `--stats=N` | stats every N | verified |
| `--log-resolved=<file>` / `--log-failed=<file>` | log files | verified |
| `--dns-make-query=<domain>` | emit binary DNS query (AAAA if `--family=6` else A) | verified |
| `--dns-parse-query` | parse binary DNS reply, emit IPs | verified |

Configured via `MDIG_THREADS`/`MDIG_EAGAIN`/`MDIG_EAGAIN_DELAY` (`config-file.md` §15). `[evidence: verified]`

### DoH example

`mdig --dns-make-query` + `curl --data-binary` + `mdig --dns-parse-query` is the upstream pattern for DoH resolution: `[evidence: verified]` (binary query mode in `mdig/`)

```sh
mdig --family=6 --dns-make-query=rutracker.org \
  | curl --data-binary @- -H "Content-Type: application/dns-message" https://cloudflare-dns.com/dns-query \
  | mdig --dns-parse-query
```

## Gotchas

- **`get_reestr_preresolved_smart`'s problematic-AS list is a heuristic, not a measured invariant** — AS reassignments change the picture; re-check before relying on the smart list for a new deployment. `[evidence: community-observed]`
- **ipban sets are not consumed by zapret2** — don't expect bypass to work for ipban-redirected traffic; ipban is your PBR/proxy scope. `[evidence: verified]`
- **`ip2net` `--v4-threshold` is integer `mul/div` math** — keep the result ≤32-bit (e.g. `3/4`, not `0.75`). `[evidence: verified]`
- **Gzip lists (`GZIP_LISTS=1`, `config-file.md` §16) require the consumer to handle `.gz`** — the engine and `create_ipset.sh` do; external tools may not. `[evidence: verified]`
- **`LISTS_RELOAD` (`config-file.md` §16) empty = auto backend selection**; `-` = disable; on BSD+PF there is no auto reload — provide your own command. `[evidence: verified]`

## Cross-references

`config-file.md` (`GETLIST` §11, `IPSET_OPT` §13, `IP2NET_OPT4/6` §14, `MDIG_*` §15, `GZIP_LISTS`/`LISTS_RELOAD` §16, `INIT_FW_*_HOOK` §10); `hostlist-ipset-nftset.md` (engine-side `--hostlist`/`--ipset` flags + dnsmasq nftset wiring — the *consumption* side); `init-script.md` (cron job running `get_config.sh`); `deploy.md` (tarball layout — `ipset/`, `ip2net/`, `mdig/` ship under `/opt/zapret2/`); `openwrt-ops` §2 (nftset preferred over kernel ipset for OpenWrt).

## Source mapping

Upstream code: `ipset/*.sh` (list-fetching scripts — `clear_lists.sh`, `create_ipset.sh`, `get_config.sh`, `get_user.sh`, `get_ipban.sh`, `get_exclude.sh`, `get_antifilter_*.sh`, `get_antizapret_domains.sh`, `get_refilter_*.sh`, `get_reestr_*.sh`); `ip2net/` (IP aggregation utility); `mdig/` (multi-threaded DNS resolver + DoH binary-query mode). Upstream documentation: `docs/manual.md` §"ipset scripts", §"ipban system", §"ip2net", §"mdig" (flag reference + list-file catalogue).
