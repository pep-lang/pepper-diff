#!/usr/bin/env bash
# Runs the package's tests: the [Test] functions in tests/, with pepper test.
#
# Usage: tests/run.sh [path/to/pepper]   (default: pepper on PATH)
set -euxo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pepper="${1:-pepper}"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

# The package is the module `diff`: a folder of that name on the import path.
mkdir "$build/packages"
ln -s "$root" "$build/packages/diff"
# The fixture tests read tests/fixtures/ relative to the root.
cd "$root"
"$pepper" test -I "$build/packages" tests
