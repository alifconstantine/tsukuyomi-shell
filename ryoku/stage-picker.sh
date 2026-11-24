#!/usr/bin/env bash
# Apply the same picker patches to a copied QML payload in preview and ISO builds.
set -euo pipefail

picker=${1:?STAGED_PICKER_DIR is required}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for change in "$here"/wallpaper-patches/*.patch; do
    patch --batch --forward --fuzz=0 --no-backup-if-mismatch -d "$picker" -p1 < "$change"
done
find "$picker" -name '*.orig' -delete
