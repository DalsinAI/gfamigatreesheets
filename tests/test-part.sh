#!/bin/sh
# Host test for scripts/write-part.sh: the Part file GFOpenUpTool reads.
# Copyright (c) 2026 AmiCradle Team. zlib licence, like TreeSheets.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/Utilities/TreeSheets/images" "$T/Utilities/TreeSheets/docs"
: > "$T/Utilities/TreeSheets/TreeSheets"; : > "$T/Utilities/TreeSheets/images/icon32.png"; : > "$T/Utilities/TreeSheets/docs/tutorial.cts"
sh "$HERE/../scripts/write-part.sh" "$T" 3048
fail=0
expect() { grep -qxF "$1" "$T/Part" || { echo "FAIL: no line: $1"; fail=1; }; }
expect 'part TreeSheets 3048'
expect 'needs 68040'
expect 'copy "Utilities/TreeSheets/TreeSheets" "SYS:Utilities/TreeSheets/TreeSheets"'
expect 'copy "Utilities/TreeSheets/images/icon32.png" "SYS:Utilities/TreeSheets/images/icon32.png"'
expect 'copy "Utilities/TreeSheets/docs/tutorial.cts" "SYS:Utilities/TreeSheets/docs/tutorial.cts"'
[ "$(head -1 "$T/Part")" = 'part TreeSheets 3048' ] || { echo "FAIL: first line"; fail=1; }
[ "$(grep -c '^copy' "$T/Part")" = 3 ] || { echo "FAIL: copy count (the Part file itself must not be listed)"; fail=1; }
sh "$HERE/../scripts/write-part.sh" "$T" 3048   # a second run: same file
[ "$(grep -c '^copy' "$T/Part")" = 3 ] || { echo "FAIL: second run lists the Part file"; fail=1; }
[ $fail = 0 ] && echo "Part file: all checks passed"
exit $fail
