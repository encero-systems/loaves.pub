# Working on loaves.pub

This repository is the interim registry of [RFC 125](https://github.com/encero-systems/incan/blob/main/workspaces/docs-site/docs/RFCs/125_incan_pub_loaf_registry_and_baked_asset_distribution.md), in the repository-based v0 shape [docs/v0.md](docs/v0.md) defines. `main` holds the tool and the docs; the orphan [`index`](https://github.com/encero-systems/loaves.pub/tree/index) branch holds the data a toolchain reads and pins by commit.

## Rules

1. **The tool is written in Incan.** Not Python, not shell beyond the two CI helpers. The site's formatter and browser scripts are the one exception. A registry whose admission were written in another language would be a claim the language cannot make about itself.
2. **Projections are never edited.** Change the log under `events/`, run `loaves-pub build`, commit both. `loaves-pub check` refuses a checkout whose events, committed generated inputs or projections disagree, and CI runs it on both branches.
3. **The fact vocabulary is closed** and mirrors the compiler's `RustFactRecord`; [docs/external-source-record.md](docs/external-source-record.md) states what a key entering it must satisfy. Adding a key here without the compiler reading it publishes a fact no consumer can apply.
4. **The tool is built with a published Incan release.** `.github/workflows/check.yml` pins the release and each target's bundle by digest. A compiler gap is worked around in place with a comment naming it, and reported to the dev line rather than patched here.
5. **Records keep the name they were written under.** New events are `loaves.pub/event/1`; events written as `incan.pub/event/1` read as the same records and are never rewritten, and the files an adoption added name the registry as it was named when the adoption was recorded, so its archive keeps its digest.
6. **Never create a repository named `encero-systems/incan.pub`.** This repository was renamed from it, and GitHub redirects the old name only while nothing else holds it. Recorded events and the index link through that redirect.

## Building

```sh
./build.sh   # test, build -> target/loaves-pub
```

`build.sh` uses the `incan` on `PATH`, or the one `INCAN` names. `INCAN_HOME` names an installation of the release CI pins (`incan toolchain install` of its bundle, which needs Rust 1.98.0 with `rustc-dev`), and `INCAN_STDLIB` the `loaves/stdlib` of a checkout of encero-systems/incan at that release. Nothing in this runs Cargo.

## Admitting a harvest

A harvest drop is a directory of `<name>-<version>-<profile>/proposal.json` plus the `out/` files each proposal names, produced by the release bake ([docs/harvest-proposal.md](docs/harvest-proposal.md) is the contract). Against a checkout of `index`:

```sh
loaves-pub admit-drop <drop>                      # cross-checks the drop, then admits every proposal in order
loaves-pub check --crates-io-index <snapshot>     # scripts/snapshot-crates-io-index.sh writes the snapshot
git commit && git push
```

Then report the resulting `index` HEAD: that commit is what a toolchain manifest pins and what the next release bake consumes. A proposal admission refuses goes back to whoever harvested it verbatim — the fix belongs on the harvest side, never in the proposal or the log. An identical binding is a no-op; a different one for a binding already on record is a refusal, and that refusal is the point: it is how a record made by hand gets checked against the machine.

Records the harvest declines to propose keep whatever record they have: a script whose emitted environment it cannot prove is unread, or link or tool work whose closure it cannot bind completely. Do not hand-write a fact to fill the gap — an incomplete declaration is worse than none, because a consumer cannot tell that it is incomplete.

`admit-drop` performs the one check that needs the whole drop: a package named in `refusals-<profile>.json` must not also have a proposal for that profile. Admission cannot catch that contradiction one proposal at a time — a fact that omits work the script does says nothing about the work it omits — so the drop is refused whole, and nothing is admitted. `add-fact` remains for a single proposal.

## Adopting crates.io packages

Adoption turns a crates.io package version into a Loaf ([RFC 125](https://github.com/encero-systems/incan/blob/main/workspaces/docs-site/docs/RFCs/125_incan_pub_loaf_registry_and_baked_asset_distribution.md), "Adoption from crates.io"): one `adopt` event per revision, whose manifest follows RFC 119's Rust facet grammar and whose source Loaf archive is stored by digest. Admission refuses an `adopt` event while a dependency active under the version's default features, on any target, is not adopted yet, so `adopt` plans the whole closure first and appends in dependency order. The plan is what a consumer of each named version builds with its default features: it follows the features every dependent enables on a dependency, through versions already adopted as well, so an optional dependency that only a dependent's feature switches on is adopted too, and naming an adopted version again adopts whatever its build still lacks. Against a checkout of `index`:

```sh
loaves-pub adopt --records --cache <cache> --blobs <blob store>   # or: adopt NAME VERSION ...
loaves-pub check --crates-io-index <snapshot> --blobs <blob store>
git commit && git push
```

`--cache` keeps the crates.io index files and `.crate` archives adoption downloads, each checked against its crates.io checksum before it is read; `--blobs` receives every source Loaf archive as `sha256/<hex>.tar`. A requirement no adopted version meets is met by the newest crates.io version satisfying it that intake lets in, preferring one that is not yanked: intake holds back a version younger than the release-age floor, a patch release that adds a dependency, and a crate in a yank burst ([docs/policy.md](docs/policy.md)). A version named explicitly is refused for the same reasons, which the refusal names; pass `--accept-hazards` only after reading them. `--features a,b` asks the named versions for those features as well as their defaults, for a package whose defaults do not compile on their own (moka needs `sync` or `future`); take the features its `[package.metadata.docs.rs]` builds with. Report the resulting `index` HEAD as for a harvest.

## Recording build facts

A version with a build script needs a fact for every binding a consumer selects (RFC 125, "Adoption from crates.io", rule 6). `loaves-pub record-fact NAME VERSION --features a,b --profile P --domain target|host --graph <roots.json> --rustc <pinned rustc> --cache <cache> --blobs <blob store> --work <dir>` compiles the script with that `rustc` and runs it under `sandbox-exec` with the network closed, writes confined to its work directory, and an environment built only from the binding. Its `rustc-cfg` answers and `OUT_DIR` files become the fact, which is admitted like any harvested proposal, with the domain and the graph in its evidence. A version without a build script is reported as needing no fact.

A script that compiles C or C++ needs `--cc`, `--cxx`, `--ar` and `--sysroot`: `CC`, `CXX` and `AR` then name copies of `loaves-pub` that run those exact tools and trace every successful run, and `SDKROOT` names the sysroot. After the script, the traces become `link` records ([src/native.incn](src/native.incn)): each `static=` library one archive, each archived object one plain compile, crate paths declared inputs, files the script generated in `OUT_DIR` declared `out` sources the fact commits under `out`, compiler paths owner paths, and the compiler identified by an inventory of everything its owner paths reach. Non-archived compiles are probes, kept as evidence. `loaves-pub native-convert` prints what a directory of traces converts to. A script with build dependencies needs `--oven` (the `oven` of an installed toolchain bundle) and `--build-lock` (an `oven.lock` resolving its build-dependency roots, written by that toolchain's `oven lock`): `oven compile-closure` compiles them for the host from their adopted archives, and the script links against the units its result lists. A C toolchain release's Clang is staged as one owner with `scripts/stage-pinned-clang.sh OWNER`, which prints the paths `--cc`, `--cxx`, `--ar` and `--sysroot` take.

An include tree lists only the files the compiles read beneath it, taken from each compile's dependency file, and every file a compile reads must be a declared input or lie in the compiler's owner closure; a file it reads without its arguments naming it is a declared source listed in that object's `reads` (RFC 119). `out` is the `OUT_DIR` files the crate's own sources include.

## Publishing to the registry

Source Loaf archives and compiled units are stored on the GitHub Container Registry as packages linked to this repository, `ghcr.io/encero-systems/loaves.pub/crates-io/<name>`; the `index` branch stays the authority and every fetch is verified against it. Credentials reach the tool as `LOAVES_PUB_REGISTRY_USER` and `LOAVES_PUB_REGISTRY_TOKEN` and reach curl only through a config file.

A package must first be created by a workflow of this repository: it then takes the repository's public visibility. A package whose first push comes from anywhere else is private, there is no API to change that, and an owner has to make it public by hand. Pushes from a maintainer's machine are for packages that already exist.

- **Source archives.** `loaves-pub push-source NAME VERSION [--revision N]` pushes one adopted version's source archive under the tag `<version>` (`+` written `_`), or `<version>-r<N>` for a later revision, rebuilding the archive by adoption when the blob store lacks it and refusing a digest other than the index names. The `publish-sources` workflow runs it for the versions it is given.
- **Compiled units.** The `bake` workflow compiles the shards it is given, each a directory under `bake/` holding `oven.lock` files (`*.oven.lock`), on a GitHub-hosted runner of the target's platform (macOS for `aarch64-apple-darwin`). Each lock entry from crates.io carries the `registry`, `revision` and archive digest (`checksum`, the index line's `cksum`) `oven lock` took from the index. `fetch-sources` pulls every lock's source archives anonymously by that digest, and one `oven compile-closure` over all the locks compiles them twice, in two roots, each lock as its own graph and a unit two locks share once. `pack-units` packs each unit's store entry (its `artifact.json`, the library once as `payload`, and the other files under `artifacts/`) as one deterministic archive, and with `--reproduces` refuses the run unless both compiles give every unit the same identity, entry and archive bytes. A closure that refuses a unit (it does not compile, or misses a fact) publishes nothing and lists the refused units in `refused.tsv` in the artifact. Run the same two compiles locally before dispatching a bake, where a refused bake is a wasted run. Compiling runs every proc macro in the closure, so that job holds no credential: a read-only token its checkouts do not keep, no package write and no OIDC token. A second job, which runs only this tool, takes the packed archives as an artifact, `actions/attest-build-provenance` attests them, and `push-units --toolchain incan@<commit>` pushes them, one tag per binding (`<version>-<12 hex of the binding's canonical JSON digest>`), adding layers to those the tag already lists. The run uploads one asset proposal per unit as the `asset-proposals` artifact.
- **Recording facts on a runner.** A build script runs where its target runs, so Linux facts are recorded on Linux. The `record-facts` workflow takes a bindings file under `bake/facts/` (name, version, features, profile, domain, graph per line), runs `loaves-pub record-fact --propose` for each in the platform's sandbox (bubblewrap on Linux, `sandbox-exec` on macOS) and uploads the proposals; `loaves-pub add-fact` admits them on a checkout of `index`.
- **Recording assets.** `loaves-pub admit-assets DIR --work DIR` on a checkout of `index` decides each proposal against the log, pulls its archive anonymously and refuses it unless the bytes arrive with their digest, then appends an `asset` event and rebuilds the projections. An asset needs an adopted record, and one unit identity names one archive. Facts are not checked: a unit's identity carries the facts it compiled under, so a unit compiled without the facts a plan selects never matches that plan. Admitted assets are listed in `crates-io/<name>/<version>/assets.json`.
- **Compilers.** The `bake` workflow compiles with an Incan toolchain bundle (`incan`, `incan-lsp` and `toolchain.tar.zst`) pulled from `ghcr.io/encero-systems/loaves.pub/toolchain/incan` by the digest of its image, and installed into a fresh home per root; `record-facts` installs the same bundle to compile build dependencies. `bake/toolchain.json` pins it once for both: `commit` (the commit it was built from) and one image digest per target triple, so moving to another bundle is one change there. `check.yml` builds the tool with a published release instead, its bundles pinned by digest in the same way. Building the compiler or the tool runs third-party build code, so those jobs hold a read-only token and hand the binary to a job that only pushes it. The `check` workflow publishes the tool the same way, `toolchain/loaves-pub:<tool key>-<target triple>` for every push to `main`, keyed by the git hash of what the binary is built from, and `bake` and `publish-sources` pull the one for their commit's key instead of building it. Releases cannot hold it: this repository's releases are immutable once published.
- **The earlier paths.** Packages were first published under `ghcr.io/encero-systems/incan.pub/*`. The `copy-packages` workflow copies every tagged version to the same name under `ghcr.io/encero-systems/loaves.pub/*` and refuses one whose copy names another digest; a later run only catches up. Artifacts are identified by digest, so a copy changes no identity a lockfile or an attestation records. The earlier paths stay until 0.6 ships, because the 0.6.0-dev.8 release pulls its toolchain from them.

## Signing the registry

`audit/v1.json` on `index` is the signed audit feed ([docs/signing.md](docs/signing.md)): the root's key envelopes, one statement per event in log order, and a checkpoint over all of it. Two keys sign it, and both are Ed25519 private keys that OpenSSL 3 reads.

- **The root** never reaches a runner or this repository. Its holder runs `loaves-pub delegate --root-key ROOT.pem --key ed25519:<online public key>` on a checkout of `index`; the first delegation writes `keys/root.json`, whose registry id is then the root's. `loaves-pub revoke-key --root-key ROOT.pem --key <key id> --reason TEXT` ends a key from its position on; delegate a new one before the next `sign`.
- **The online key** is the `LOAVES_PUB_ONLINE_KEY` secret. The `sign` workflow runs daily and on dispatch: `loaves-pub sign --key` appends a statement for every event the feed does not cover yet and a checkpoint over the whole feed, `check --signed` verifies the result, and the job pushes it to `index`. Dispatch it after an admission, so the new events are signed the same day.

`check` verifies the feed whenever `keys/root.json` names a root, refuses a statement that does not sign its event, and with `--signed` refuses a feed short of the log. An advisory's text is one line, because the feed signs it as one. [tests/fixtures/signed-feed](tests/fixtures/signed-feed) is a small signed feed with its verdicts, for a consumer to replay.

## Correcting a wrong adoption

The log is append-only, so an adoption that is wrong because of a bug is corrected by its next revision (RFC 125, "Adoption from crates.io", rule 8): fix the translation, raise `ADOPTION_VERSION` in `src/adoption.incn` when the bytes adoption writes change, then run `loaves-pub readopt NAME VERSION ... --reason TEXT --cache <cache> --blobs <blob store>` against a checkout of `index`. Each named version takes a new `adopt` event naming the revision it supersedes and why. A version whose translation comes out the same is right and is refused, and a revision may change only `loaf.toml` and the files adoption adds, so a package's sources never change. A lockfile pinned to the old revision keeps resolving to it. The highest revision keeps the version's directory, and each one it superseded moves to `r<N>/` below it. Its source archive goes to the registry under the tag `<version>-r<N>`. Commit, push and report the new `index` HEAD as for any other change.

Adoptions and assets recorded before event 14157 lack what a new event must state, and the log keeps them as they are: such an adoption is revision 1 with its tool version unrecorded, and absent `build-script` means `false`. An asset among them names only its Rust compiler.

## The web surface

The site is generated, and nothing on it is edited or asks a live service for anything. `site/` holds its design: the templates, the styles and scripts, its fonts and art, and the game. Everything a page says about a package comes from the catalog on `index`. Against a checkout of `index`:

```sh
(cd site && npm ci --ignore-scripts)
node site/format-documents.mjs <index> <formatted>      # checks each document against its digest, then formats it
loaves-pub site --root <index> --formatted <formatted> --templates site/templates --checkpoint "$(git -C <index> rev-parse HEAD)" --out <out>
cp -R site/assets site/arcade <out>/
(cd <index> && cp -R catalog index crates-io content graphs events <out>/)
SITE_OUT=<out> npm --prefix site test
```

The `site` workflow does the same, and publishes the result. `check` on `index` dispatches it after each push there, and a change under `site/` runs it too. Rendering keeps three rules. An upstream value is always escaped, and a link out must be `http` or `https`. Author HTML stays inert and a remote image becomes its alternate text, so reading a package page requests nothing from elsewhere. A page states what the registry records and no more: a missing record is shown as missing, never as zero.

Only `format-documents.mjs` and the browser scripts are JavaScript. What a page says, and where, is in `src/site.incn`.

## Where the contract lives

| | |
|---|---|
| [docs/v0.md](docs/v0.md) | the v0 design: two branches, three programs, admission, what is out of scope |
| [docs/model.md](docs/model.md) | the loop from both ends: what a toolchain does to publish, what the registry does to manage |
| [docs/external-source-record.md](docs/external-source-record.md) | the record, its events, the rendered manifest, the closed vocabulary |
| [docs/harvest-proposal.md](docs/harvest-proposal.md) | what a harvest emits and what `add-fact` admits |
| [docs/policy.md](docs/policy.md) | the reserved scopes and supported toolchains the registry publishes |
| [docs/c-toolchain.md](docs/c-toolchain.md) | the C toolchain release of RFC 159: Clang builds, Linux sysroots, pinned platform flags, the reproduction gate |
| [encero-systems/incan#1666](https://github.com/encero-systems/incan/issues/1666) | the tracking issue, including the open questions this registry cannot settle alone |
