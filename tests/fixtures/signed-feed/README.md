# A producer-signed audit feed

A small registry log signed by `loaves-pub` exactly as [docs/signing.md](../../../docs/signing.md) specifies, for a consumer to replay. Its keys are fixture keys, published here so a consumer can mint further variants: never trust them for anything else.

| path | what it is |
|---|---|
| `events/` | the four events the feed signs: two publishes, each followed by an advisory |
| `keys/root.json` | the root the feed is verified from |
| `registration.toml` | the same root as an RFC 117 registration's `id` and `root-keys`; the fixture is read as bytes, so it names no endpoint |
| `audit/v1.json` | the feed: 7 envelopes under a checkpoint at 7 |
| `earlier/v1.json` | the same feed as first signed: 3 envelopes under an earlier checkpoint at 3 |
| `variants/*.json` | tampered copies of `audit/v1.json` |
| `index/crates-io/widget` and `.statement` | an index file, as `loaves-pub build` renders it from `events/`, with its `index` statement (path `index/crates-io/widget`) signed by key B at sequence 7 |
| `fixture-keys.json` | the fixture's private keys, each the hex of its PKCS#8 DER |

## The envelopes of `audit/v1.json`

| sequence | envelope | signed by |
|---|---|---|
| 1 | `delegate` of key A | root |
| 2 | statement: `publish` of `crates-io/widget 1.0.0` (canonical JSON) | A |
| 3 | statement: advisory on `crates-io/widget 1.0.0` (`incan-registry-advisory-v1`) | A |
| 4 | `revoke-key` of key A | root |
| 5 | `delegate` of key B | root |
| 6 | statement: `publish` of `crates-io/gadget 2.0.0` | B |
| 7 | statement: advisory on `crates-io/gadget 2.0.0` | B |

The checkpoint at 7 is signed by B. `earlier/v1.json` holds envelopes 1 to 3 under A's checkpoint at 3, and its checkpoint `head` is the accumulator of `audit/v1.json` at 3, so the later feed extends it.

## Verdicts

| feed | verdict |
|---|---|
| `audit/v1.json` | accepted: both advisories in effect |
| `earlier/v1.json`, then `audit/v1.json` | accepted: the newer checkpoint is later, longer, and its accumulator at 3 is the earlier head |
| `audit/v1.json`, then `earlier/v1.json` | refused: older and shorter than the observed checkpoint |
| `variants/payload-changed.json` | refused: envelope 3's payload is a withdrawal its signature does not cover |
| `variants/envelope-omitted.json` | refused: envelope 2 is missing, so the sequence breaks |
| `variants/head-changed.json` | refused: the checkpoint's head is not the accumulator at 7 |
| `variants/revoked-key-signs.json` | refused: envelope 6 is signed by A after its revocation at 4 |

The checkpoint timestamps are the moments the fixture was signed; a consumer replays it offline or with a fixed clock, since the seven-day staleness bound expires it.

## Rebuilding a private key

```bash
jq -r .root fixture-keys.json | xxd -r -p | openssl pkey -inform DER -out root.pem
```
