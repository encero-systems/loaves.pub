# The registry's published policy

RFC 125 leaves four things to a registry's published policy: which scopes beyond its own it reserves, which of them hold adopted Loaves, how old a release must be before it is adopted, and which toolchains it supports. [`src/policy.incn`](../src/policy.incn) holds them, and `catalog/policy.json` on the `index` branch publishes them, so a reader gets the policy from the same checkpoint as everything else.

## Reserved scopes

A scope is the first part of a package name. A reserved scope can't be claimed by a community publisher, and a publish to one is refused from any identity not authorized for it.

| scope | what it holds |
|---|---|
| `c` | C libraries adopted from an upstream release |
| `crates-io` | packages adopted from crates.io |
| `encero` | reserved for the project |
| `encero-systems` | reserved for the project |
| `incan` | native packages the project provides |
| `oven` | reserved for the toolchain |
| `std` | reserved for the toolchain |

## Adoption scopes

`c` and `crates-io` are adoption scopes: the registry adopts their Loaves from an upstream release rather than taking them from a publisher, so no single publisher stands behind the scope. A consumer refuses a publisher-wide trust entry for an adoption scope (RFC 117, "Compile-time code trust"); trust in an adopted Loaf is per version.

## Release-age floor and selection hazards

A crates.io version enters adoption only once it is 72 hours old (`release-age-floor-hours` in `catalog/policy.json`), by the `pubtime` its index line records; a consumer filling a miss locally applies the same floor. Two signals hold a version back even past the floor: a patch release that depends, normally or to build, on a package its previous patch release did not, and a yank burst, three or more of the crate's five newest versions yanked. Automatic selection passes over a version any rule holds back and names the reason; a version adopted by name is refused for it unless the adoption accepts the hazards ([src/intake.incn](../src/intake.incn)).

## Supported toolchains

An asset is kept while its toolchain is supported, and its record names that toolchain as `incan@<commit>`. Once a toolchain leaves this list, the bytes of its assets may be removed by a signed `retire` event; a removed asset is an ordinary miss, and the consumer bakes from source. Nothing is removed because of age or total size.

The supported set is the release the project's CI builds with: `incan@0cb030e9c6d9817c620e481854e7d6f6440fd9d6`, the 0.6.0-dev.8 bundles.
