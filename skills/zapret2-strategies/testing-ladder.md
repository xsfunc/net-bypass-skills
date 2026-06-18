# Progressive testing ladder

Start with the **lightest** strategy and escalate only if the previous rung fails — and always verify failure via `blockcheck2` (autodetect, never hardcode). Each rung below shows the technique, a representative `--lua-desync` chain, and the rationale. These are reference shapes, not a fixed prescription: the actual positions, blobs, and fooling must come from a `blockcheck2` result for the operator's ISP.

## Rung 1 — tcpseg, no cut (lightest)

Send the whole payload as one segment with a seqovl prefix that overwrites the stream start for DPI, without splitting. Lowest disruption; tries to fool DPI that reads only the first bytes of a stream.

```
--lua-desync=tcpseg:pos=0,-1:seqovl=1 --lua-desync=drop:payload=known
```

Why first: no segmentation, no fakes, no disorder — minimal chance of breaking the connection. `tcpseg` returns no verdict, so `drop` replaces the original. `[evidence: verified]` (mechanism); `[evidence: hypothesis]` (effectiveness vs a given DPI — confirm with blockcheck2).

## Rung 2 — tcpseg + duplication

Add `repeats=N` to flood the DPI buffer with repeated stream-start bytes, still no cutting.

```
--lua-desync=tcpseg:pos=0,midsld:repeats=3:ip_id=rnd --lua-desync=drop:payload=known
```

Why: if DPI reassembles a single seqovl but chokes on repeated prefix bytes, duplication escalates without splitting. `[evidence: verified]` (mechanism); `[evidence: hypothesis]` (effectiveness).

## Rung 3 — multisplit (cut)

Actually cut the payload into forward-order segments at protocol-meaningful positions.

```
--payload=tls_client_hello --lua-desync=multisplit:pos=1,midsld
```

Why: defeats DPI that does not reassemble. Fooling hits all segments here, so use only safe fooling (`tcp_ts_up`, `ip_id`, IPv6 headers). `[evidence: verified]` (mechanism); `[evidence: hypothesis]` (effectiveness — escalate if DPI reassembles).

## Rung 4 — aggressive: fakedsplit / fakeddisorder (fakes + split + disorder)

Surround the split with same-seq fakes (fakedsplit) and/or reverse the order (fakeddisorder) for triple confusion. The heaviest single-technique rung.

```
--payload=tls_client_hello --lua-desync=fakeddisorder:pos=midsld:tcp_ack=-66000:tcp_ts_up
```

Why: defeats DPI that checks both order and content. **Fooling is mandatory for fakes** here, and `tcp_ts_up` must accompany `tcp_ack` on Linux. seqovl in `fakeddisorder` is a marker and is subject to the Windows-server breakage gotcha. `[evidence: verified]` (mechanism); `[evidence: hypothesis]` (effectiveness).

## DPI-capability selection sidebar `[evidence: hypothesis]`

If `blockcheck2` reports the DPI's behavior, pick directly:

| DPI behavior | Technique |
|--------------|-----------|
| Does not reassemble | `multisplit` (rung 3) |
| Reassembles, no order check | `multidisorder` |
| Checks order, not content | `fakedsplit` |
| Checks both order and content | `fakeddisorder` (rung 4) |

This table is a reasoning heuristic from the source, not code-confirmed — report-and-ask; never auto-apply as fact.

## Beyond rung 4

The next layer is **circular auto-rotation** — a preset that cycles through strategies on RST/retransmission/redirect failures, so the router retries rung 1→4 automatically. That is the orchestrator, not yet documented in this pack. Until it lands, do not improvise rotation logic — report the gap.
