#!/usr/bin/env bash
# Build the patched daemon from the same commit as the pinned desktop packages.
set -euo pipefail

output=$(realpath -m -- "${1:?OUTPUT is required}")
cache=${2:-${XDG_CACHE_HOME:-$HOME/.cache}/tsukuyomi/source}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
revision=08ff3280c9c0b702250c82ac6a7047862c0d72a0
source="$cache/ryoku-shell-$revision"
module=ryoku/shell/ipc

mkdir -p -- "$cache"
exec 9>"$cache/ryoku-shell-$revision.lock"
flock 9
if [[ ! -d $source/.git ]]; then
    git init -q "$source"
    git -C "$source" remote add origin https://github.com/Ryoku-dev/ryoku.git
fi
if [[ $(git -C "$source" rev-parse --verify HEAD 2>/dev/null || true) != "$revision" ]]; then
    git -C "$source" -c remote.origin.promisor=true fetch --depth=1 --filter=blob:none origin "$revision"
    git -C "$source" sparse-checkout set --cone "$module"
    git -C "$source" -c advice.detachedHead=false checkout --detach "$revision"
fi
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cp -a -- "$source/$module/." "$work/"
flock -u 9

for change in "$here"/shell-patches/*.patch; do
    patch --batch --forward --fuzz=0 -d "$work" -p1 < "$change"
done
(cd "$work" && go build -mod=vendor -trimpath -buildvcs=false -o "$output" .)
