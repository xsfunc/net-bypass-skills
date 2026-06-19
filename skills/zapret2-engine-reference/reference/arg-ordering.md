# arg-ordering — argument ordering rules

The order of flags inside a profile matters for **one specific pair**: `--payload` / `--out-range` / `--in-range` **must precede** the `--lua-desync` they scope. Other profile-scope filters (`--filter-*`, `--hostlist`, `--ipset`) are order-independent among themselves. Getting the ordering wrong is **not** a parse error — the config validates cleanly, but the desync runs against the wrong (or default) filter and the strategy silently misfires. `[evidence: verified]` (scoped-filter semantics are code-defined); `[evidence: community-observed]` (the ordering rule is attested in upstream documentation).

## The rule

`--payload`, `--out-range`, and `--in-range` are **scoped forward** filters: each one applies to the `--lua-desync` calls that follow it, until the next occurrence of the same flag or the end of the profile. Therefore they **must appear before** the `--lua-desync` they are meant to scope.

### Correct vs invalid

```
# ✅ CORRECT — payload BEFORE lua-desync
--payload=tls_client_hello --lua-desync=fake:blob=fake_default_tls

# ❌ INVALID — payload AFTER lua-desync (does NOT scope this function!)
--lua-desync=fake:blob=fake_default_tls --payload=tls_client_hello
```

In the invalid form, the `fake` runs against the **previous** `--payload` (or the default `known` if none preceded it), and the trailing `--payload` scopes nothing (or a later `--lua-desync` if one follows). `[evidence: verified]`

Same rule for `--out-range`:

```
# ✅ CORRECT
--out-range=-d10 --lua-desync=fake:blob=fake_default_tls

# ❌ INVALID
--lua-desync=fake:blob=fake_default_tls --out-range=-d10
```

`[evidence: verified]`

## Scope table

| Flag | Scope | Order matters? | Evidence |
|------|-------|----------------|----------|
| `--filter-tcp` / `--filter-udp` | whole profile | no (profile-scope) | verified |
| `--filter-l3` | whole profile | no | verified |
| `--filter-l7` | whole profile | no | verified |
| `--hostlist` / `--hostlist-exclude` / `--hostlist-domains` | whole profile | no | verified |
| `--ipset` / `--ipset-exclude` | whole profile | no | verified |
| `--payload` | until next `--payload` (or profile end) | **yes — must precede `--lua-desync`** | verified |
| `--out-range` | until next `--out-range` (or profile end) | **yes — must precede `--lua-desync`** | verified |
| `--in-range` | until next `--in-range` (or profile end) | **yes — must precede `--lua-desync`** | verified |
| `--lua-desync` | the specific call (execution order = list order) | yes (call sequence) | verified |

`[evidence: verified]` (scope semantics are code-defined).

## Profile boundary resets scope

`--new` terminates a profile. All scoped filters (`--payload`, `--out-range`, `--in-range`) reset at the next `--new` — they do **not** carry over between profiles. Each profile starts with the default `--payload=known` and no range filter unless redeclared. `[evidence: verified]` (`--new` separator is code-defined; profile-scope reset); profile model: `zapret2-strategies/reference/preset.md`.

## Multiple scoped filters in one profile

A profile can repeat `--payload` / `--out-range` to scope different `--lua-desync` blocks differently:

```
--filter-tcp=443 --filter-l7=tls
--payload=tls_client_hello
  --lua-desync=fake:blob=fake_default_tls:tcp_md5
  --lua-desync=multisplit:pos=1,midsld
--payload=http_req
  --lua-desync=fake:blob=fake_default_http:ip_ttl=5
--new
```

The two `fake` calls under `tls_client_hello` both run only on TLS Client Hello; the `fake` under `http_req` runs only on HTTP requests. `[evidence: verified]` (scoped filter reset); `[evidence: community-observed]` (composition pattern).

## Recommended style (readability)

For maintainability, group flags in this order inside each profile:

1. **Profile filters** (order-independent): `--filter-tcp/udp`, `--filter-l7`, `--hostlist`, `--ipset`.
2. **Scoped filters + desync blocks**: `--payload` / `--out-range` immediately before the `--lua-desync`(s) they scope, repeated per block.
3. `--new` to end the profile.

```
--filter-tcp=443 --filter-l7=tls --hostlist=/opt/zapret2/lists/mylist.txt
--out-range=-d10 --payload=tls_client_hello
--lua-desync=fake:blob=fake_default_tls:tcp_md5
--lua-desync=multisplit:pos=1,midsld
--new
```

This is not required by the parser, but it makes the scoping obvious and prevents the ordering bug. `[evidence: community-observed]`

## Equivalent orderings (profile filters)

The profile-scope filters are order-independent among themselves, so all three of these are equivalent **as long as the `--payload`/`--lua-desync` pair stays ordered**:

```
# hostlist first
--hostlist=list.txt --payload=tls_client_hello --lua-desync=fake:blob=fake_default_tls

# payload first
--payload=tls_client_hello --hostlist=list.txt --lua-desync=fake:blob=fake_default_tls

# hostlist last (still fine — it's profile-scope, not scoped-to-desync)
--payload=tls_client_hello --lua-desync=fake:blob=fake_default_tls --hostlist=list.txt
```

`[evidence: verified]` (profile-scope filters are not order-sensitive relative to each other or to the `--payload`/`--lua-desync` pair, as long as the `--payload`-before-`--lua-desync` rule holds).

## Gotchas

- **Reversed `--payload`/`--out-range` is a silent misfire, not a parse error.** `sh -n /opt/zapret2/config` will not catch it — the syntax is valid, the scoping is wrong. Review ordering by eye. `[evidence: verified]`
- **A trailing scoped filter scopes nothing.** `--lua-desync=... --payload=tls_client_hello` leaves the desync unscoped (runs against the previous/default filter) and the `--payload` waits for a `--lua-desync` that never comes — or scopes a later one unintentionally. `[evidence: verified]`
- **`--new` resets scoped filters.** Don't rely on a `--payload` from the previous profile carrying into the next — redeclare it. `[evidence: verified]`
- **Multiple `--lua-desync` calls execute in list order.** Stacking order is itself significant (`send` → `syndata` → `multisplit` differs from `multisplit` → `send`). See `zapret2-strategies/reference/profile.md`. `[evidence: verified]`

## Cross-references

`payload.md` (the `--payload` filter and its types); `out-range.md` (the `--out-range`/`--in-range` filter); `filter.md` (profile-scope filters); `zapret2-strategies/reference/profile.md` (where scoping sits in a profile's anatomy, `--lua-desync` stacking order); `zapret2-strategies/reference/preset.md` (`--new` profile separator).

## Source mapping

Upstream documentation: zapret2 argument-ordering rules (`--payload`/`--out-range` precedence, scope table, profile-boundary reset). No single code path cited — the scoped-filter semantics are spread across the engine's profile walker; model distilled from upstream ordering documentation.
