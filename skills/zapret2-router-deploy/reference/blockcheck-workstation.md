# blockcheck2 on a Linux/WSL (host-side)

Doc covers the **host-side variant**: running `blockcheck2.sh` on a Linux/WSL when router is too weak for heavy combinatorial scan (HTTP3/QUIC, many fake variants, longfakedsplit patterns).

**Agent** prepares the environment (download, install, smoke-test) and emits a final runbook command. The user runs the final command in their own tty.

## Why host-side

- **Weak-router** — curl with ngtcp2/quictls + nghttp3 is heavy
- **curl-impersonate / curl-h3 binaries** for ARM/MIPS are rare upstream; x86_64 is universally available.

## Install procedure

> **Agent dialog first.** Before running the recipe, ask the user for the install path via the `question` tool — default `~/zapret2`, allow any custom absolute path. Capture the answer into a `ZAPRET_BASE` shell var and use it in every recipe below (blockcheck2.sh reads `ZAPRET_BASE` from env, so a custom path propagates automatically).

```sh
# 1. Discover the latest release tag.
LATEST=$(curl -fsSL https://api.github.com/repos/bol-van/zapret2/releases/latest \
         | grep -m1 '"tag_name"' | cut -d'"' -f4)

# 2. Fetch tarball (carries binaries/, blockcheck2.sh, blockcheck2.d/, install_* scripts).
cd /tmp
curl -fL -o zapret2.tgz \
  https://github.com/bol-van/zapret2/releases/download/${LATEST}/zapret2-${LATEST}.tar.gz
curl -fL -o sha256sum.txt \
  https://github.com/bol-van/zapret2/releases/download/${LATEST}/sha256sum.txt

# 3. Extract (strip the zapret2-<tag>/ prefix) into the path chosen in the dialog.
mkdir -p "$ZAPRET_BASE"
tar xzf zapret2.tgz --strip-components=1 -C "$ZAPRET_BASE"

# 4. Verify SHA-256 of the x86_64 binaries only (the tarball ships all arches; only x86_64 relevant here).
cd "$ZAPRET_BASE"
grep "linux-x86_64" /tmp/sha256sum.txt \
  | sed "s#zapret2-${LATEST}/#./#" | sha256sum -c --quiet -

# 5. Symlink binaries into the dirs blockcheck2.sh expects (ZAPRET_BASE/nfq2, /mdig, /ip2net).
sh install_bin.sh
# Expected: "linux-x86_64 is OK", three "linking : ..." lines.

# 6. Smoke: confirm binaries execute.
"$ZAPRET_BASE"/nfq2/nfqws2 2>&1 | head -1
"$ZAPRET_BASE"/mdig/mdig --help 2>&1 | head -1
"$ZAPRET_BASE"/ip2net/ip2net -h 2>&1 | head -1
```

## Prerequisites

`install_prereq.sh` auto-detects `FWTYPE` and installs the matching set via the host's package manager. Requires root (uses `apt-get`/`dnf`/`pacman`/etc.).

```sh
sudo sh "$ZAPRET_BASE"/install_prereq.sh
```

On Debian/Ubuntu the script installs: `curl`, `nftables`, `dnsutils`. On nftables-mode, `ipset`/`iptables` are **not** pulled — blockcheck2 uses `nft` directly. `netcat-openbsd` (`/usr/bin/nc`) is used for the IP-block pre-flight and is already present; if missing, install manually (`sudo apt install netcat-openbsd`) before running blockcheck2.

(`wsl2:` the `microsoft virtualization detected` warning blockcheck2 prints at startup is expected on WSL2 — it is informational)

## HTTP3 curl swap: stunnel/static-curl

Usually `curl` **built without HTTP3** (`curl -V` Features line lacks `HTTP3`). blockcheck2's `ENABLE_HTTP3=1` path needs `curl --http3`, which requires ngtcp2/nghttp3/quictls compiled in. The cleanest swap is a third-party static binary. 

**Recipe — `stunnel/static-curl` musl-linux-x86_64:**

```sh
# Discover the latest stunnel/static-curl tag.
CURL_H3_VER=$(curl -fsSL https://api.github.com/repos/stunnel/static-curl/releases/latest \
              | grep -m1 '"tag_name"' | cut -d'"' -f4)

mkdir -p "$ZAPRET_BASE"/curl-h3 && cd "$ZAPRET_BASE"/curl-h3
curl -fL -o curl-h3.tar.xz \
  https://github.com/stunnel/static-curl/releases/download/${CURL_H3_VER}/curl-linux-x86_64-musl-${CURL_H3_VER}.tar.xz
tar xJf curl-h3.tar.xz                               # extracts ./curl ./trurl ./SHA256SUMS
sha256sum -c SHA256SUMS --quiet                      # verify (SHA256SUMS ships inside the tar)
./curl -V | tail -2                                  # Features must include HTTP3
```

> Choose the **musl** variant, not glibc — stunnel's README warns that static glibc curl crashes on systems where `/etc/nsswitch.conf` has `passwd: compat`, due to `libnss_compat.so`/`libnss_nis.so`/`libpthread.so` incompatibilities. musl is statically self-contained.

blockcheck2 picks up a custom curl via the `CURL=` / `CURL_OPT=` env vars (table in `blockcheck.md`). For HTTP3 specifically, `--http3` is auto-selected by the script when `ENABLE_HTTP3=1` — the agent only needs to point `CURL=` at the static binary. `CURL_OPT="--noproxy *"` is required if the host has a proxy env.

## Step 1 — SIMULATE smoke-test

Before the ~1-hour real run, must verify the script can detect the system, binaries, curl, nftables, and reach the pre-flight checks without error. Use the `SIMULATE=1` + `SKIP_PKTWS=1` combo to run the script without root, without nft ruleset changes, without nfqws2 launch:

```sh
cd "$ZAPRET_BASE"
SKIP_PKTWS=1 BATCH=1 SIMULATE=1 \
  DOMAINS=iana.org \
  SKIP_DNSCHECK=1 SKIP_IPBLOCK=1 \
  ENABLE_HTTP=1 ENABLE_HTTPS_TLS12=0 ENABLE_HTTPS_TLS13=0 ENABLE_HTTP3=0 \
  REPEATS=1 \
  timeout 30 sh blockcheck2.sh 2>&1 | head -40
```

`SKIP_PKTWS=1` skips the `require_root` check. `SIMULATE=1` replaces real strategy success with the `SIM_SUCCESS_RATE` (default 10%) random outcome. `SKIP_DNSCHECK=1 SKIP_IPBLOCK=1` avoid network pre-flights.

Expected output (verified lines):
```
* checking system
Linux detected
...
firewall type is nftables
CURL=curl
...
* checking prerequisites
* checking virtualization
...
* SUMMARY
```

If the smoke reaches `* SUMMARY` without error → ready. If it dies earlier (missing `nft`, binary not found, curl detects no HTTP3 when `ENABLE_HTTP3=1`) → fix prerequisite before the real run. Do **not** skip this step — the real run is ~1 hour, a startup failure wastes the slot.

## Step 2 — real run

The agent prepares the runbook, the user runs it in their own tty. The agent does not invoke sudo, does not hold the session, does not stream the log.

```sh
# Unset ALL proxy env on the session — blockcheck2's QUIC path dies behind a host proxy
# (curl tries MASQUE CONNECT-UDP, proxy returns HTTP 400).
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

sudo env \
  ZAPRET_BASE="$ZAPRET_BASE" \
  CURL="$ZAPRET_BASE"/curl-h3/curl \
  BATCH=1 \
  DOMAINS=instagram.com \
  SKIP_DNSCHECK=1 \
  ENABLE_HTTP3=1 \
  REPEATS=2 \
  sh "$ZAPRET_BASE"/blockcheck2.sh 2>&1 | tee ~/blockcheck-ig-quic-$(date +%F).log
```

- `BATCH=1` — non-interactive
- `DOMAINS=`- space-separated; URIs (no `https://` prefix) allowed: `DOMAINS="rutracker.org/forum/index.php youtube.com"`.
- `ENABLE_HTTP3=1` only tests QUIC/HTTP3; pair with `ENABLE_HTTPS_TLS12=1 ENABLE_HTTPS_TLS13=1` to scan all protocols.
- `REPEATS=2` reduces per-strategy attempts (default is per-scanlevel) — useful on slow sites; bump to 3-5 for noisy links.
- `SKIP_DNSCHECK=1` DoH/SOCKS-DNS detection rarely relevant when the host is not the resolver. For a first run, drop this and let detect DNS spoofing.
- `tee` to `~/` not `/tmp` — the router pack uses `/tmp` (tmpfs, avoids flash wear).
- **Don't close the session**: ~1 hour. Use `tmux`/`screen`/`nohup` if the SSH/terminal is unstable.

## Agent session-holding caveat

blockcheck2 takes ~1 hour; the agent's tool shell typically has a shorter timeout and no tty for sudo. The agent must **not** attempt to background the run. The agent's job ends at "log file path printed, runbook explained, waiting for the log to be provided".

After the run, the agent can read log, interprets it per `blockcheck.md`, translates successful strategies into a profile and applies on the **router**, under safe-mode (`/openwrt-ops` skill), not on the workstation.


## Result validity decision tree

blockcheck2 systematically tries strategies, **but the strategies are tested against the path that the workstation's traffic takes to the target**. If that path does not coincide with the DPI-blind path your real client (behind the router) takes, the result is a ranking of what would work *if you were on the workstation's network*, not a recipe for the client. Walk top-down, stop at the first matching row:

| # | WAN/egress path of the workstation | Validity for the client's DPI scene | Action |
|---|------------------------------------|--------------------------------------|--------|
| 1 | Workstation's egress = same ISP router uplinks to | Plausible | Use results as preset candidates. Validate on the real client after applying |
| 2 | Workstation behind VPN, different ISP's egress | **Not valid** | Re-run from a workstation on the target ISP, or run on the router itself. |
| 3 | WSL2 NAT via Windows host with direct ISP egress | Plausible with skepticism | Hyper-V's NAT may alter TTL/IP-options enough that DPI's OS-fingerprint stage sees a different signature than the router. Treat result as candidate-ranking only, validate on client. |
| 4 | In a corporate / CI / bridged NAT that exits via a third DPI | **Not plausible** | Results unusable for the target scene. |
