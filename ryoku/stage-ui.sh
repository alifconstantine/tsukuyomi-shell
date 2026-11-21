#!/usr/bin/env bash
# Apply shared Ryoku.Ui patches to a copied QML payload in preview and ISO builds.
set -euo pipefail

ui=${1:?STAGED_RYOKU_UI_DIR is required}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
shopt -s nullglob
for change in "$here"/ui-patches/*.patch; do
    patch --batch --forward --fuzz=0 -d "$ui" -p1 < "$change"
done
