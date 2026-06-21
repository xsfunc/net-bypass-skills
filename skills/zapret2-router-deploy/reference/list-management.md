# list-management — ipset list-fetching infrastructure, ip2net, mdig

This card documents the **list-fetching infrastructure** under `/opt/zapret2/ipset/`, the `ip2net` IP-aggregation utility, and the `mdig` multi-threaded DNS resolver. These produce the hostlist/ipset files that `MODE_FILTER=ipset`/`hostlist`/`autohostlist` (`config-file.md`) load into the engine and kernel sets.

For the **engine-side** `--hostlist`/`--ipset` flag semantics and the dnsmasq nftset wiring, see `hostlist-ipset-nftset.md`.

## Standard list files

| Hostlist | Type | Purpose | IP lists |
|----------|------|---------|----------|
| `zapret-hosts-user.txt` | user | inclusion | `zapret-ip-user.txt` / `zapret-ip-user6.txt` |
| `zapret-hosts-user-exclude.txt` | user | exclusion | `zapret-ip-exclude.txt` / `zapret-ip-exclude6.txt` |
| `zapret-hosts-user-ipban.txt` | user | traffic redirect | `zapret-ip-user-ipban.txt` / `zapret-ip-user-ipban6.txt` |
| — | generated | traffic redirect | `zapret-ip-ipban.txt` / `zapret-ip-ipban6.txt` |
| `zapret-hosts.txt` | generated | inclusion | `zapret-ip.txt` / `zapret-ip6.txt` |

- User hostlists may contain hostnames / IPv4 / IPv6 / CIDR; generated hostlists only hostnames
- gzip supported (`.gz` appended)
- IP lists split v4/v6 — the v6 file has `6` before the extension (e.g. `zapret-ip6.txt`)
- Inclusion IP lists → kernel sets only if `MODE_FILTER=ipset`; the exclusion IP list is always loaded
- ipset names: `nozapret`/`nozapret6` (exclude), `zapret`/`zapret6` (include), `ipban`/`ipban6`. ipfw uses sets combining v4+v6

## ipset scripts

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

`get_reestr_*` variants: `resolvable_domains`, `preresolved`, `preresolved_smart` — the latter ships a problematic-AS list (AS32934/13414/13335/15169/16509/16276/24940 — Facebook/Cloudflare/Google/Amazon/OVH; IPs in these ASes are excluded from the smart list because they host both blocked and unblocked properties) and a white-AS list (AS47541/35237/47764/13238/47764 — RU hosters whose blocks are unlikely to be DPI).

`GETLIST` in `config` (`config-file.md`) selects which fetcher `get_config.sh` runs. Comment out `GETLIST` to disable auto-fetch.

## ipban system

The ipban pipeline produces kernel `ipban`/`ipban6` sets for your own PBR/proxy redirect — **zapret does not use them** for bypass. Use `INIT_FW_*_HOOK` (`config-file.md`) for sync with your PBR rules.

## `ip2net` utility

Groups IPs into subnets to shrink the IP lists. stdin → stdout.

| Flag | Purpose | Evidence |
|------|---------|----------|
| `-4` / `-6` | ipv4 (default) / ipv6 | verified |
| `--prefix-length=min[-max]` | e.g. `22-30` (v4), `56-64` (v6) | verified |
| `--v4-threshold=mul/div` | e.g. `3/4` (integer math, keep ≤32-bit) | verified |
| `--v6-threshold=N` | min IPs to form a v6 subnet | verified |

Records `ip/prefix` and `ip1-ip2` pass through unchanged. Algorithm: in the prefix range, find subnets with max addresses; if tie, pick the smallest (largest prefix). ipset handles `ip1-ip2` optimally for `hash:net`; ipfw only understands `ip/prefix`

Configured via `IP2NET_OPT4`/`IP2NET_OPT6` (`config-file.md`).

## `mdig` utility

Multi-threaded DNS resolver. stdin domains → stdout IPs, errors to stderr.

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

Configured via `MDIG_THREADS`/`MDIG_EAGAIN`/`MDIG_EAGAIN_DELAY` (`config-file.md`).

### DoH example

`mdig --dns-make-query` + `curl --data-binary` + `mdig --dns-parse-query` is the upstream pattern for DoH resolution:

```sh
mdig --family=6 --dns-make-query=rutracker.org \
  | curl --data-binary @- -H "Content-Type: application/dns-message" https://cloudflare-dns.com/dns-query \
  | mdig --dns-parse-query
```

## Gotchas

- **`get_reestr_preresolved_smart`'s problematic-AS list is a heuristic, not a measured invariant** — AS reassignments change the picture
- **ipban sets are not consumed by zapret2** — don't expect bypass to work for ipban-redirected traffic; ipban is your PBR/proxy scope
- **`ip2net` `--v4-threshold` is integer `mul/div` math** — keep the result ≤32-bit (e.g. `3/4`, not `0.75`)
- **Gzip lists (`GZIP_LISTS=1`, `config-file.md` §16) require the consumer to handle `.gz`** — the engine and `create_ipset.sh` do; external tools may not
- **`LISTS_RELOAD` (`config-file.md` §16) empty = auto backend selection**; `-` = disable; on BSD+PF there is no auto reload — provide your own command