#!/usr/bin/env sh
# Stage the managed Builder's C owner for aarch64-apple-darwin in OWNER: the Incan-built Clang the C toolchain release
# pins (encero-systems/loaves.pub#4, RFC 159) beside a copy of this host's Xcode SDK. A `link` record names one owner
# directory holding the compiler, its resource directory and the sysroot (src/native.incn), and Apple's SDK cannot be
# redistributed, so the owner is assembled on the Builder that compiles. Prints, for `$GITHUB_ENV`, the directory of
# Clang's executables and the sysroot, which `record-fact --cc --cxx --ar --sysroot` and `INCAN_OVEN_LINK_OWNERS` take.
#
# Usage: scripts/stage-pinned-clang.sh OWNER
set -eu

# The release `toolchain/clang:22.1.8-aarch64-apple-darwin`, pinned by digest so a tag pushed again changes nothing here.
digest=sha256:8cc12635b32726ab2625a4bb8835dd2c5dc100b9cd5be860845f494b64132ac0
owner="$1"

[ ! -e "$owner" ] || { printf 'stage-pinned-clang.sh: %s exists; stage into a fresh directory\n' "$owner" >&2; exit 1; }
mkdir -p "$owner" "$owner.pull"
oras pull "ghcr.io/encero-systems/loaves.pub/toolchain/clang@$digest" --output "$owner.pull" >&2
tar -xzf "$owner.pull"/clang-*-aarch64-apple-darwin.tar.gz -C "$owner"
rm -rf "$owner.pull"
clang_bin="$(cd "$owner"/clang-*-aarch64-apple-darwin/bin && pwd -P)"
for tool in clang clang++ llvm-ar; do
  [ -x "$clang_bin/$tool" ] || { printf 'stage-pinned-clang.sh: the pinned Clang has no %s\n' "$tool" >&2; exit 1; }
done

# The SDK the host selects, copied whole under its versioned name so every path the compiler reads lies in the owner.
sdk="$(cd "$(xcrun --sdk macosx --show-sdk-path)" && pwd -P)"
mkdir -p "$owner/SDKs"
name="MacOSX$(xcrun --sdk macosx --show-sdk-version).sdk"
ditto "$sdk" "$owner/SDKs/$name"

printf 'PINNED_CLANG_OWNER=%s\n' "$(cd "$owner" && pwd -P)"
printf 'PINNED_CLANG_BIN=%s\n' "$clang_bin"
printf 'PINNED_CLANG_SYSROOT=%s\n' "$(cd "$owner/SDKs/$name" && pwd -P)"
