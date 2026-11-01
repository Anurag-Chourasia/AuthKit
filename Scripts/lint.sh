#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
version="$(cat .swiftlint-version)"
binary="${SWIFTLINT_BIN:-swiftlint}"
command -v "$binary" >/dev/null || { echo "Install SwiftLint $version with Scripts/install-swiftlint.sh" >&2; exit 1; }
[[ "$("$binary" version)" == "$version" ]] || { echo "SwiftLint $version is required; refusing a different rules engine" >&2; exit 1; }
xcrun --find swiftc >/dev/null
exec "$binary" lint --strict --no-cache --config .swiftlint.yml "$@"
