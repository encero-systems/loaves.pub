# The signed audit feed

loaves.pub signs its state as RFC 125 ("Registry identity and signing") requires, in the wire Oven verifies: a root key a reader pins, online keys the root delegates, a statement signed for every event of the log, and a checkpoint over a log accumulator that proves the feed complete and an extension of every earlier one. [`src/signing.incn`](../src/signing.incn) implements this page, and [`tests/fixtures/signed-feed`](../tests/fixtures/signed-feed) is a small signed feed to verify against.

The feed is one document, `audit/v1.json` on the `index` branch, served at `<base>/audit/v1.json`. The event files under `events/` are unchanged by signing: the feed is where their signatures live.

## Keys and ids

| term | form |
|---|---|
| key | Ed25519, 32 raw bytes |
| key id | lowercase hex SHA-256 of the 32 raw bytes, with no prefix |
| registry id | the key id of the root |
| pin | `ed25519:` followed by the standard padded base64 of the key's DER SubjectPublicKeyInfo, as RFC 117's `root-keys` spells it; a registry configuration's `id` is `sha256:` followed by the registry id |

`keys/root.json` on the `index` branch names the root:

```json
{
  "registry": "<registry id>",
  "root": "ed25519:<base64 SubjectPublicKeyInfo>",
  "schema": "loaves.pub/root/1"
}
```

A reader pins both through its registry configuration and refuses a feed under any other root.

## Signed preimages

Every signature is PureEd25519 (RFC 8032) over UTF-8 lines, each ending in LF, the last one included, with nothing else. Numbers are canonical decimal; digests are lowercase hex with no prefix.

| signed by | preimage |
|---|---|
| root, delegating a key | `incan-registry-delegation-v1`, `registry=<registry id>`, `key-kind=ed25519`, `key=<raw key hex>` |
| root, revoking a key | `incan-registry-key-revocation-v1`, `registry=<registry id>`, `key=<key id>`, `sequence=<position of the revocation>`, `reason=<one line>` |
| delegated key, a statement | `incan-registry-statement-v1`, `registry=<registry id>`, `key=<key id>`, `kind=<event or checkpoint>`, `sequence=<position>`, `payload-sha256=<SHA-256 of the payload>` |

A statement's payload is the event it signs:

| event | payload |
|---|---|
| `advisory` | the lines `incan-registry-advisory-v1`, `id=<the event id's 64 hex digits>`, `package=crates-io/<name>`, `version=<version>`, `action=publish`, `reason=<the advisory text, one line>` |
| every other kind | the event's canonical JSON without `id` and `signature`, so the payload's SHA-256 is the hex of the event id |

Canonical JSON sorts object keys, writes no whitespace, escapes only `"`, `\` and control characters in strings, and admits no floats ([external-source-record.md](external-source-record.md)).

The checkpoint's payload is `incan-registry-checkpoint-v1`, `head=<accumulator>`, `length=<envelopes covered>`, `timestamp=<Unix seconds>`, signed as a statement of kind `checkpoint` whose sequence is its length.

## The log accumulator

`H0` is 64 ASCII zeroes. For envelope `i`, `S_i` is the lowercase hex SHA-256 of the exact preimage signed for it (a statement's whole envelope, not only its payload), and `H_i` is the lowercase hex SHA-256 of the lines `incan-registry-log-v1`, `sequence=<i>`, `previous=<H_(i-1)>`, `signed-sha256=<S_i>`. A checkpoint's `head` is `H_length`.

## The document

```json
{"schema":"loaves.pub/audit/1","registry":"<registry id>","checkpoint":{"head":"…","key":"<key id>","length":3,"signature":{"r":"","raw":"<hex>","s":""},"timestamp":1764000000},"events":[
{"key":"<raw key hex>","key_kind":"ed25519","kind":"delegate","sequence":1,"signature":{"r":"","raw":"<hex>","s":""}},
{"key":"<key id>","kind":"statement","payload":"<padded base64>","sequence":2,"signature":{"r":"","raw":"<hex>","s":""}},
{"key":"<key id>","kind":"revoke-key","reason":"…","sequence":3,"signature":{"r":"","raw":"<hex>","s":""}}
]}
```

| member | meaning |
|---|---|
| `events` | every envelope from sequence 1, in order, one per line; each has exactly the fields of its kind |
| `delegate` | the root authorizes `key` (raw hex) from this position on |
| `revoke-key` | the root ends `key` (a key id): it signs nothing after this position, and no checkpoint after it |
| `statement` | a delegated key in force signs one event of the log; `payload` is the signed payload's bytes |
| `checkpoint` | `head`, `length` (the number of envelopes), `timestamp` (Unix seconds), `key` (the delegated key id) and `signature` |
| `signature` | `raw` is the 64-byte Ed25519 signature as hex; `r` and `s` are empty |

Statements sign the events of `events/` in log order: the k-th statement of the feed signs the k-th event. Key envelopes live only in the feed, so a feed's sequence numbers count envelopes, not events. Events the feed does not cover yet are not part of the registry's signed state.

## Verifying

1. Refuse `keys/root.json` and the feed unless the registry id and root equal the pinned values.
2. Walk the envelopes in order, refusing one that is omitted, repeated, reordered or of an unknown kind. Verify a `delegate` or `revoke-key` under the root, and a statement under a key the root delegated at an earlier position and has not revoked at or before this one.
3. Fold the accumulator over every envelope, and refuse a checkpoint whose `length` is not the number of envelopes or whose `head` is not `H_length`. Verify its signature under a key still in force at its length.
4. Refuse a checkpoint older than one already observed, one with a smaller length, one with a different head at the same length, and one whose accumulator at an earlier observed length differs from that observation's head. RFC 125's default staleness bound is seven days, and it does not apply offline.

The registry signs a new checkpoint at least daily, and whenever it signs new events.
