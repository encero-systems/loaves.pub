# Authored Loaves

An authored Loaf is a package its publisher writes, packages and signs, published under a scope the registry has opened for authored publication ([RFC 125](https://github.com/encero-systems/incan/blob/main/workspaces/docs-site/docs/RFCs/125_incan_pub_loaf_registry_and_baked_asset_distribution.md), "Publishing a Loaf" and "Source Loaves"). An adoption scope (`c`, `crates-io`; [policy.md](policy.md)) never takes an authored publication, and an authored scope never takes an adoption.

## Names and paths

| item | form |
|---|---|
| package name | `<scope>/<name>`; scope and name each match `[a-z0-9][a-z0-9-]*` and are at most 64 characters |
| version | SemVer, published once and never replaced |
| index file | `index/<scope>/<name>`, one line per version |
| manifests | `<scope>/<name>/<version>/loaf.toml`, the publisher's manifest byte for byte, and `<scope>/<name>/<version>/assets.json` beside it |
| source Loaf archive | `ghcr.io/encero-systems/loaves.pub/<scope>/<name>`, tag `<version>` with `+` written `_` |
| baked units | the same repository, tag `<version>-<12 hex of the binding>`, as for adopted Loaves |
| publication bundle | the publisher's Sigstore bundle, stored at `content/sha256/<hex>` on the `index` branch |

A scope is open for authored publication while a trusted publisher is in force for it. Only reserved scopes ([policy.md](policy.md)) open while the registry has no community accounts.

## Events

| event | subject | meaning | admission |
|---|---|---|---|
| `trusted-publisher` | the scope | adds or removes one identity allowed to publish under the scope | the scope is reserved and is not an adoption scope; an `add` names an identity not already in force, and a `remove` names one that is |
| `publish` | `<scope>/<name>@<version>` | the source Loaf exists, signed by a trusted publisher | see [Admitting a publication](#admitting-a-publication) |
| `asset` | `<scope>/<name>@<version>` | a baked unit for one binding is available | as for an adopted Loaf ([external-source-record.md](external-source-record.md)); a `publisher` asset's attestation identity is a trusted publisher in force for the scope at the event's position |
| `yank`, `unyank`, `advisory` | `<scope>/<name>@<version>` | governance | as for an adopted Loaf |

A `trusted-publisher` event's payload:

```json
{"action":"add","issuer":"https://token.actions.githubusercontent.com","provider":"github-actions","ref":"refs/tags/v*","repository":"encero-systems/<repo>","workflow":".github/workflows/<file>.yml"}
```

`ref` is a full ref name, or a prefix ending in `*`. An identity is in force from its `add` until a `remove` with the same `repository`, `workflow` and `ref`. Every event carries the envelope of [external-source-record.md](external-source-record.md), and the signed audit feed signs it ([signing.md](signing.md)).

An authored `publish` event's payload:

| member | meaning |
|---|---|
| `source` | `archive`, the source Loaf digest (`sha256:` and 64 hex digits); `bytes`, its size; `location`, its GHCR `registry`, `repository` and `tag` |
| `manifest` | the digest of the archive's `loaf.toml`, whose bytes `content/` holds |
| `facets` | the facet kinds the source Loaf carries, sorted: `incan` when it holds Incan sources, `rust` when its manifest declares a Rust facet |
| `publisher` | the verified certificate identity: `identity` (`https://github.com/<repository>/<workflow>@<ref>`), `issuer`, `repository`, `workflow`, `ref` and `commit` |
| `attestation` | `bundle`, the digest of the stored Sigstore bundle, and `url`, GitHub's attestation page for it |

## Admitting a publication

The publisher's workflow packages the source Loaf, attests the archive with GitHub's build-provenance attestation (a Sigstore bundle with a keyless certificate for the workflow identity and a transparency-log entry), and attaches the archive and the bundle to a release of its repository. The `admit-publication` workflow takes that release (its repository, tag, the two asset names and the attestation page) and runs `loaves-pub admit-publication`, which:

1. Verifies the bundle against the archive with `gh attestation verify`, requiring the issuer, repository, workflow and ref of a trusted publisher in force for the scope. This checks the certificate chain, the transparency-log inclusion, and that the attested subject is the archive's digest.
2. Unpacks the archive under the rules adoption extracts with: agreeing tar headers, relative printable paths, no case-fold collisions.
3. Requires `loaf.toml` at the archive's root, with `[project]` `name` equal to `<scope>/<name>` and `version` equal to the subject's, and no `path` dependency.
4. Refuses a `(name, version)` already published.
5. Stores the archive in the blob store and the manifest and bundle under `content/`, and appends the `publish` event, which the log keeps only if it folds.

The workflow then runs `check`, pushes the archive with `loaves-pub push-authored`, pushes `index`, and dispatches `sign`, which signs the event and the new files. A trusted publisher is recorded with `loaves-pub trusted-publisher add SCOPE --repository OWNER/NAME --workflow PATH --ref REF`, and ended with `remove`.

`check` re-verifies a publication offline:
- the stored bundle's digest;
- that the bundle's in-toto subject is the archive digest;
- that the recorded identity matches a trusted publisher in force at the event's position;
- the manifest digest;
- with `--blobs`, the archive's digest.

## The index line

An authored version's index line has the fields of an adopted line that apply to it:

| field | value |
|---|---|
| `name`, `vers` | the subject |
| `cksum` | the source Loaf digest |
| `deps` | the manifest's `[dependencies]`, each with `name`, `loaf` or `crate`, `req`, `features`, `default-features` and `optional` |
| `facets` | the `publish` event's `facets` |
| `features` | the manifest's `[features]` |
| `requires` | the toolchain ranges the manifest declares: `incan` from `[project]` `requires-incan`, when it has one |
| `facts` | empty: an authored Loaf has no build facts |
| `manifest` | `<scope>/<name>/<version>/loaf.toml` |
| `publisher` | the verified identity |
| `yanked`, `advisories`, `assets` | as for an adopted line |

## Statements and serving

`sign` signs `index/<scope>/<name>` as a statement of kind `index`, and each `loaf.toml` and `assets.json` under `<scope>/` as kind `manifest`, with the path-bound preimage of [signing.md](signing.md). The site serves every authored scope's directory beside `crates-io/`.
