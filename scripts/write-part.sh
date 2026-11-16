#!/bin/sh
# Writes the Part file GFOpenUpTool INSTALL reads (gfopenup src/openuptool.c):
# one "copy" line per file under the part drawer, each to SYS:<its path>.
#   write-part.sh <part drawer> <version>
# Copyright (c) 2026 AmiCradle Team. zlib licence, like TreeSheets.
set -eu
P=$1; V=$2
{
    echo "part TreeSheets $V"
    echo "; TreeSheets: a free-form hierarchical data organiser (notes, outlines, tables, to-do lists)"
    echo "needs 68040"
    (cd "$P" && find Utilities -type f ! -name Part | LC_ALL=C sort) | while read -r f; do
        echo "copy \"$f\" \"SYS:$f\""
    done
} > "$P/Part"
