# theory — networking concepts for debugging nfqws2 interception

This file distills the 7-part upstream networking tutorial into the conceptual foundation an agent needs to debug "why is nfqws2 not intercepting / not bypassing." It is **conceptual** ("what X is and why it matters"), not enumerative ("which values X takes"). For the enumerative reference — payload-type list, `--out-range` prefix table, `--lua-desync` function list — load the neighbouring skills: `zapret2-engine-reference` for flag syntax/types, `zapret2-strategies` for desync technique semantics.

The sections run as a sequential tutorial (L2-L7 → TCP → NFQUEUE → dissect → payload → Lua pipeline → start/cutoff), but each is self-contained enough to load for a specific debugging question.

## 1. Network stack (L2-L7) and where zapret2 sits

The network is layers:

- **L2 (link)**: Ethernet/Wi-Fi — frame delivery to the next device.
- **L3 (network)**: IP — packet delivery to a remote address (routing). TTL/HL decreases per router.
- **L4 (transport)**: TCP/UDP — application data delivery + (TCP) ordering, reliability, flow control.
- **L7 (application)**: HTTP/TLS/QUIC/... — what the browser and server actually understand.

zapret2 works with **L3/L4 raw packets** (raw IPv4/IPv6 bytes) and knows enough about L7 to recognise payload types (e.g. `tls_client_hello`) for filtering.

### Packet anatomy (TCP)

```
IP header | TCP header | TCP payload (application bytes: HTTP/TLS/...)
```

- **IP header**: src/dst address, TTL/HL, fragmentation flags, checksum (IPv4).
- **TCP header**: ports, `seq/ack`, flags (SYN/ACK/RST/...), window, options (timestamp, SACK, MD5).
- **payload**: application bytes (e.g. `GET / HTTP/1.1...` or TLS ClientHello).

### TTL/HL as a fooling tool

IPv4 TTL / IPv6 Hop Limit decreases at each router; TTL=0 drops the packet. This makes TTL a "header fooling" tool — a packet with a low TTL reaches the DPI on the path but not the destination server. In zapret2 this is the `ip_ttl` / `ip_autottl` fooling family.

### Checksum as a fooling tool

TCP/UDP checksums cover pseudo-header + payload. A bad checksum makes the OS/stack drop the packet — used as `badsum` fooling (DPI may still inspect, server rejects).

### MSS vs IP fragmentation (do not confuse)

- **TCP segmentation (L4)**: TCP splits a large payload into segments that fit the channel MTU. Bound to MSS (Maximum Segment Size).
- **IP fragmentation (L3)**: IP splits one IP packet into fragments (IPv4 or IPv6 fragment header). Lower-level mechanism.

zapret2's `multisplit`/`multidisorder` make **TCP segments** at the payload level; `ipfrag` then makes **IP fragments** out of those segments. Different layers, different mechanisms.

### Mini-glossary

- **raw packet** — IP packet bytes as-is.
- **dissect** — parsed packet structure (`ip/ip6/tcp/udp/payload` tables).
- **reconstruct** — raw packet assembly from a dissect.
- **fooling** — header corruption so the server rejects the packet but DPI accepts it.
- **payload type** — payload classification (`http_req`, `tls_client_hello`, `quic_initial`, etc. — full list in `zapret2-engine-reference/reference/payload.md`).

## 2. TCP — seq/ack, window, MSS, retransmission

TCP presents as a byte stream to applications but transmits as packets. It guarantees order, reliability, and flow control. `[evidence: verified]` (TCP semantics are RFC-standard).

### seq (sequence number)

`seq` is the number of the first payload byte in the overall stream.

- Segment A: `seq=1000`, payload 200 bytes → bytes `[1000..1199]`.
- Segment B: `seq=1200`, payload 100 bytes → bytes `[1200..1299]`.

### ack (acknowledgement)

`ack` means "I have received all bytes up to `ack-1`; send byte `ack` next." A wrong `ack` makes the OS drop the packet — which is why `ack`/`seq` manipulation is a strong fooling lever.

### Window

The TCP window advertises how much data the receiver will accept now. Technique idea: insert a segment "outside the window" — the server ignores it, but DPI may still parse it. In zapret2 this is the `seqovl` family (see `zapret2-strategies/reference/multidisorder.md`).

### Retransmission

If an ACK doesn't arrive, TCP retransmits the segment. To an observer (and DPI) this looks like "another similar packet with the same seq." Many techniques mimic retransmissions to confuse DPI about which packet is the original.

### MSS and "why are there suddenly more packets"

MSS = max TCP payload per segment (~MTU minus headers). If a payload exceeds MSS, TCP splits it. zapret2 auto-segments by MSS on send — even if you "logically" split into 2 parts, each part may be further split by MSS. This explains why packet logs show more segments than the strategy nominally produces.

### Order matters: multisplit vs multidisorder

- `multisplit` sends segments forward-order (head to tail).
- `multidisorder` sends reverse-order (tail to head).

Different stacks handle overlaps and out-of-order segments differently — the source of DPI confusion. For which to use and when, see `zapret2-strategies/reference/multisplit.md` and `multidisorder.md`.

## 3. NFQUEUE verdicts — where nfqws2 sits in the kernel

On Linux (nfqws2), the interception chain is:

1. nftables/iptables rules direct some packets into **NFQUEUE** (a kernel queue).
2. `nfqws2` reads them in userspace.
3. The program decides: **PASS** / **DROP** / **MODIFY**.
4. The kernel applies the verdict and continues processing.

On Windows (winws2) the analogue uses WinDivert driver interception — **out of scope for the router agent** (Windows-only, marked in `zapret2-engine-reference/reference/core-flags.md`).

### The three verdicts

- **PASS** — let the packet through unchanged.
- **DROP** — discard the packet (it "disappeared").
- **MODIFY** — let it through with changed bytes. MODIFY almost always means the packet was **reconstructed from the dissect**, not patched raw.

### Why fakes are not MODIFY

`fake` and similar techniques often **send an additional packet** (rawsend) and leave the intercepted packet alone (PASS) — or another instance drops it. The "extra noise + untouched original" model is normal.

### Verdict priority

When multiple Lua instances run on the same packet, the final verdict is `DROP > MODIFY > PASS`. One `DROP` is enough to block the original; a `fake` that sends an extra packet but doesn't drop the original leaves the original going through.

### Why filtering is mandatory for performance

Intercepting "all port 443" sends every packet to userspace, runs Lua constantly, and can pin the CPU at 100%. zapret2 therefore uses `--filter-*`, `--payload=...`, `--out-range`/`--in-range`, and `cutoff` to limit when Lua fires. `[evidence: verified]` (filter flags are engine-defined in `zapret2-engine-reference`; cutoff is engine-defined). For the wiring that decides *which packets reach NFQUEUE at all*, see `nfqueue-wiring.md`.

## 4. dissect / reconstruct and the `desync` object

Each `--lua-desync=...` invokes a Lua function `(ctx, desync)`. `desync` is the table the function operates on:

- `desync.dis` — the current dissect (parsed IP/TCP/UDP/payload).
- `desync.arg` — the current instance's arguments.
- `desync.l7payload` / `desync.l7proto` — recognised types.
- `desync.track` — conntrack state (may be nil).
- `desync.reasm_data` / `desync.decrypt_data` — assembled payloads if reassembly fired.
- `desync.replay`, `desync.replay_piece`, `desync.replay_piece_count` — replay state.

### The dissect structure

- `desync.dis.ip` / `desync.dis.ip6` — IP header.
- `desync.dis.tcp` / `desync.dis.udp` — transport header.
- `desync.dis.payload` — payload bytes (string).
- For TCP: `desync.dis.tcp.th_seq`, `th_ack`, `th_flags`, `th_win`, `th_urp`, `options[]`.

### Why dissect > raw

Raw packet editing requires manual offset arithmetic, easy mistakes, and checksum recomputation. zapret2 does most modifications as: dissect → edit fields → reconstruct.

### Debug helpers

- `pktdebug` — prints the whole `desync` (verbose).
- `argdebug` — prints `desync.arg` only.
- `posdebug` — prints conntrack counters (`n/d/b/s/p`) and reasm/decrypt/replay status.

### "Standard args" — the shared argument blocks

Most strategies (`fake`, `multisplit`, `multidisorder`) accept the same blocks: `direction`, `payload`, `fooling` (ttl/md5/flags/badsum), `ipid`, `rawsend`, `ipfrag`. This makes techniques composable — the same send/reconstruct machinery applies these blocks uniformly. For the per-technique argument list, see `zapret2-strategies`.

## 5. Payload types, reasm/replay, markers (concept)

### `l7proto` vs `l7payload`

Two classification layers:

- `l7proto` — the flow's protocol (`tls` / `http` / `quic` / ...). Filter: `--filter-l7=tls,http,quic`.
- `l7payload` — the specific payload type within the flow (`http_req`, `tls_client_hello`, `quic_initial`, ...). Filter: `--payload=tls_client_hello`.

For the full payload-type list and CLI syntax, see `zapret2-engine-reference/reference/payload.md`.

### Why payload filtering matters

Many strategies must fire only on the "first important packet" — HTTP request (Host visible), TLS ClientHello (SNI visible), QUIC Initial. Filtering by payload type saves CPU and makes behaviour predictable.

### `reasm_data` — payload across multiple TCP segments

Sometimes a payload (e.g. TLS ClientHello with kyber) doesn't fit in one segment. zapret2 can assemble multiple segments into one logical payload (`desync.reasm_data`). Strategies like `multisplit`/`multidisorder` then cut the **whole reasm**, not just the current segment.

### `replay` — packets held and re-played

To accumulate payload for reasm or to run a series of instances, the engine may hold packets and "replay" them once state is ready. Many strategies do their main work on `replay_first(...)` and drop subsequent pieces (already sent in the desired form).

### Markers — logical positions, not byte offsets

Markers name a position logically: `method` (HTTP method), `host` / `endhost` / `midsld` (positions inside Host/SNI domain), `sniext`, `extlen` (TLS structures). They accept arithmetic (`midsld+1`, `endhost-2`, `-10`, `100`) and are used in `multisplit:pos=...`, `multidisorder:pos=...:seqovl=...`. `[evidence: verified]` (marker syntax is engine-defined).

Why a marker may "not work": payload not recognised (`l7payload=unknown`), no matching structure in the payload (e.g. no SNI), or the marker is invalid for that payload type.

## 6. Lua pipeline — instances, args, cutoff, debug

### Instance

Each `--lua-desync=...` creates one **instance**: a function name, its arguments (`desync.arg`), and its position in the profile (execution order). Instances run strictly in list order within the active profile.

### Argument syntax

```
--lua-desync=function:arg1[=val1]:arg2[=val2]:flag3:flag4
```

All values are strings. If `=val` is omitted, the value is the empty string `""` (which is "true" in Lua) — so flags are written as `:optional`, `:nodrop`, `:tcp_ts_up`, `:ipfrag`, `:ipfrag_disorder`.

### How standard blocks attach

Most strategies don't send packets manually — they call the shared sender which: deepcopies the dissect if needed → applies `apply_fooling` (TTL/MD5/flags) → MSS-segments the payload → applies `ip_id` policy → optionally IP-fragments → `rawsend`. This is why standard args compose predictably.

### Cutoff — self-disabling for CPU

An instance can disable itself by direction, or disable the whole Lua profile (lua cutoff). After the "critical phase" (first N packets), Lua stops firing — CPU saved.

### The 3 debug tools

- `argdebug` — prints `desync.arg` of the current instance.
- `posdebug` — prints conntrack counters (`n/d/b/s/p`) and `reasm/decrypt/replay` status.
- `pktdebug` — prints the whole `desync` (verbose, sometimes indispensable).

### Debug recipe — "no chaos"

1. Narrow the profile: `--payload=...` + `--out-range=...`.
2. Put `--lua-desync=posdebug` first.
3. Put the strategy under test.
4. Add `argdebug` next to it if needed.

You see: when the strategy fired, on which payload, whether reasm/replay was active.

## 7. start/cutoff — why `n2<n3` "suddenly" hits ClientHello

A common surprise:

```
--filter-tcp=443 --payload=all --out-range="n1<n2" --lua-desync=send:ip_ttl=1
```
→ duplicates the SYN.

```
--filter-tcp=443 --payload=all --out-range="n2<n3" --lua-desync=send:ip_ttl=1
```
→ duplicates the **ClientHello**, even though "by rights" the 2nd outgoing packet should be the ACK.

### The key fact

`n` is the **intercepted** packet counter, not the TCP-flow packet counter. `n` increments only on outgoing packets that were **actually intercepted** (NFQUEUE/WinDivert) **and** reached profile processing (filters didn't drop them earlier). A packet that wasn't intercepted **doesn't exist** for `n`.

### Why the ACK often "vanishes"

- **Windows / winws2** defaults to `--wf-tcp-empty=0` — empty TCP ACKs are not intercepted (CPU saving). So `n1`=SYN, `n2`=ClientHello (first data packet); the handshake ACK exists in the real flow but not in the counter.
- **Linux / nfqws2**: if the NFQUEUE rules intercept only "data packets" or only some phases, the ACK is never delivered to userspace and `n` shifts the same way. See `nfqueue-wiring.md` for how the rule's filter expression decides this.

### Second cause (rarer): ACK glued to ClientHello

A stack may send the SYN-ACK ACK together with the first data segment (ACK+payload). Then the "second outgoing packet" really is ClientHello — verified only by capture (Wireshark).

### Equivalent of nfqws1 `--dup-start=n2 --dup-cutoff=n3`

```
--out-range="n2<n3" --lua-desync=send:ip_ttl=1
```

Works "as expected" only if that 2nd packet is actually intercepted.

### Hitting the ACK specifically (if it's empty)

**Option A (Windows)**: enable empty-ACK interception (`--wf-tcp-empty=1`), then narrow: `--payload=empty --out-range="n2<n3" --lua-desync=send:ip_ttl=1`. If nothing duplicates → ACK not intercepted by filters, or ACK isn't empty.

**Option B**: target "first data packet" with the `d` counter (data-packet counter), robust against empty-ACK skipping:
```
--payload=tls_client_hello --out-range="d1<d2" --lua-desync=send:ip_ttl=1
```

### Fastest diagnosis

Add for debugging:
```
--lua-desync=posdebug
--lua-desync=luaexec:code="DLOG('flags '..tostring(desync.dis.tcp and desync.dis.tcp.th_flags)..' payload '..#desync.dis.payload..' l7payload '..tostring(desync.l7payload))"
```
Inspect: payload length at `n2`, the `l7payload` value (`empty`/`tls_client_hello`/`unknown`), whether `n` increments on empty ACKs. `[evidence: community-observed]` (debug recipe pattern).