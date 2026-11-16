#!/bin/sh
# Builds TreeSheets for GFOS (AmigaOS 3.2.3 with GFOpenUp, on the GFOpenKick
# ROM or a Kickstart) with a stove: 68040, soft float with the FPU taken when
# there is one (fpuauto), on the GFOpenWX Toolkit.
#   STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh
#   (WXT_SRC=... to use a toolkit tree already on disk)
# TreeSheets, the toolkit and fpuauto are fetched at the commits
# treesheets.lock gives; nothing third-party is kept here. The build tree is
# kept, so a run that stops at BUDGET_TOTAL seconds goes on next time.
# OUT gets Parts/TreeSheets: a GFOpenUp part (its Part file and the files it
# puts in SYS:Utilities/TreeSheets), installed with
#   GFOpenUpTool INSTALL Parts/TreeSheets
# Copyright (c) 2026 AmiCradle Team. zlib licence, like TreeSheets.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/treesheets.lock"
STOVE=${STOVE:-"$HOME/AmiCradle/stoves/os32-gcc16-open6"}
# outside the checkout: Cradle cleans it (git clean -ffdx) before every job
WORK="${WORK:-$HOME/.cache/gfamigatreesheets/build}"; OUT="${OUT:-$WORK/out}"; JOBS=${JOBS:-12}
TC="$STOVE/prefix"; PATH="$TC/bin:$PATH"; export PATH
mkdir -p "$WORK/deps" "$OUT"; OUT=$(cd "$OUT" && pwd)
t0=$(date +%s)

# a repository at one commit, fetched once (SPARSE: only those folders)
fetch() {
    d="$WORK/deps/$1"
    if [ "$(git -C "$d" rev-parse HEAD 2>/dev/null)" != "$3" ]; then
        rm -rf "${d:?}"; mkdir -p "$d"
        git -C "$d" init -q
        if [ -n "${4:-}" ]; then
            git -C "$d" config core.sparseCheckout true
            echo "$4" > "$d/.git/info/sparse-checkout"
            git -C "$d" fetch -q --depth 1 --filter=blob:none "$2" "$3"
        else
            git -C "$d" fetch -q --depth 1 "$2" "$3"
        fi
        git -C "$d" checkout -q FETCH_HEAD
        [ "$(git -C "$d" rev-parse HEAD)" = "$3" ] || { echo "$1: commit mismatch"; exit 1; }
    fi
}

# --- the toolkit's SDK, again only when its tree changed ---------------------
if [ -z "${WXT_SRC:-}" ]; then fetch gfopenwxtoolkit "$WXT_REPO" "$WXT_COMMIT"; WXT_SRC="$WORK/deps/gfopenwxtoolkit"; fi
WXB="$WORK/gfopenwx"
WXREV=$( (git -C "$WXT_SRC" rev-parse HEAD 2>/dev/null; git -C "$WXT_SRC" diff HEAD 2>/dev/null) | sha256sum | cut -c1-16)
if [ ! -x "$WXB/out/sdk/bin/wx-config" ] || [ "$(cat "$WXB/out/.rev" 2>/dev/null)" != "$WXREV" ]; then
    # stopped here, before Cradle's own cap, so the log says how far it got
    set +e
    STOVE="$STOVE" WORK="$WXB" OUT="$WXB/out" JOBS=$JOBS timeout "${BUDGET_TOTAL:-840}" sh "$WXT_SRC/build-amiga.sh" > "$WORK.wx.log" 2>&1
    rc=$?
    set -e
    if [ "$rc" = 124 ]; then
        echo "toolkit: out of time after $(( $(date +%s) - t0 )) s, run again to go on"
        echo "  base objects: $(find "$WXB/base" -name '*.o' 2>/dev/null | wc -l), GUI objects: $(find "$WXB/gui/obj" -name '*.o' 2>/dev/null | wc -l)"
        tail -5 "$WORK.wx.log"
        exit 0
    fi
    [ "$rc" = 0 ] || { tail -40 "$WORK.wx.log"; exit 1; }
    [ -x "$WXB/out/sdk/bin/wx-config" ] || { tail -40 "$WORK.wx.log"; echo "no toolkit SDK"; exit 1; }
    echo "$WXREV" > "$WXB/out/.rev"
fi
echo "toolkit: $(( $(date +%s) - t0 )) s"
WXC="$WXB/out/sdk/bin/wx-config"

# --- fpuauto: libfpuauto.a and its link specs ---------------------------------
fetch fpuauto "$FPA_REPO" "$FPA_COMMIT" "/common/fpuauto/"
FA="$WORK/deps/fpuauto/common/fpuauto"; FAL="$WORK/fpuauto"
if [ ! -f "$FAL/libfpuauto.a" ] || [ "$(cat "$FAL/.rev" 2>/dev/null)" != "$FPA_COMMIT" ]; then
    rm -rf "$FAL"; mkdir -p "$FAL/obj"
    m68k-amigaos-gcc -m68040 -DFPUAUTO_COMMON -c "$FA/fpuauto.S" -o "$FAL/obj/fa_common.o"
    for n in $(sed 's/^--wrap=//' "$FA/fpuauto.wraps"); do
        m68k-amigaos-gcc -m68040 -DR_$n -c "$FA/fpuauto.S" -o "$FAL/obj/fa_$n.o"
    done
    m68k-amigaos-ar rcs "$FAL/libfpuauto.a" "$FAL"/obj/fa_*.o
    echo "$FPA_COMMIT" > "$FAL/.rev"
fi

# --- TreeSheets at its pinned commit, with patches/ ---------------------------
SRC="$WORK/treesheets"
PSUM=$(cat "$HERE"/patches/*.patch | sha256sum | cut -c1-16)
if [ "$(cat "$SRC/.patched" 2>/dev/null)" != "$TS_COMMIT-$PSUM" ]; then
    rm -rf "$SRC"; mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" fetch -q --depth 1 "$TS_GIT" "$TS_COMMIT"
    git -C "$SRC" checkout -q FETCH_HEAD
    [ "$(git -C "$SRC" rev-parse HEAD)" = "$TS_COMMIT" ] || { echo "commit mismatch"; exit 1; }
    for p in "$HERE"/patches/*.patch; do
        patch -s -d "$SRC" -p1 < "$p" || { echo "patch failed: $p"; exit 1; }
    done
    echo "$TS_COMMIT-$PSUM" > "$SRC/.patched"
    rm -rf "$WORK/obj"
fi

# objects made against another toolkit commit go: its headers are not in
# the make rules, and stale objects crash at start (gfamigagolly #3)
if [ "$(cat "$WORK/.toolkit-objs" 2>/dev/null)" != "$WXT_COMMIT" ]; then
    rm -rf "$WORK/obj"
    echo "$WXT_COMMIT" > "$WORK/.toolkit-objs"
fi

# --- compile: TreeSheets is one unit (src/main.cpp takes in the rest) ---------
LATE=""
if m68k-amigaos-gcc -fno-late-combine-instructions -S -o /dev/null -x c /dev/null 2>/dev/null; then LATE="-fno-late-combine-instructions"; fi
CF="-noixemul -m68040 -O2 -fno-delete-null-pointer-checks $LATE -DNDEBUG"
O="$WORK/obj"; mkdir -p "$O"
# shellcheck disable=SC2046
CXXF="$CF -std=gnu++20 $("$WXC" --cxxflags) -I$HERE/compat -I$SRC/src -DPACKAGE_VERSION=\"$TS_VERSION\" -Wno-deprecated-declarations"
left=$(( ${BUDGET_TOTAL:-840} - ($(date +%s) - t0) ))
[ "$left" -gt 60 ] || { echo "no time left for TreeSheets this run"; exit 0; }
set +e
if [ ! -f "$O/main.o" ]; then
    # shellcheck disable=SC2086
    timeout "$left" nice -n 19 m68k-amigaos-g++ $CXXF -c "$SRC/src/main.cpp" -o "$O/main.o.tmp" > "$O/compile.log" 2>&1
    rc=$?
    [ "$rc" = 0 ] && mv "$O/main.o.tmp" "$O/main.o"
else rc=0; fi
set -e
grep -E 'error' "$O/compile.log" 2>/dev/null | head -60
[ "$rc" = 0 ] || { [ "$rc" = 124 ] && echo "out of time: run again to go on"; tail -30 "$O/compile.log"; echo "compile: $(( $(date +%s) - t0 )) s"; exit "$rc"; }
m68k-amigaos-gcc $CF -c "$HERE/compat/amiga_stack.c" -o "$O/amiga_stack.o"
echo "compile: $(( $(date +%s) - t0 )) s"

# --- the link: soft-float specs, then fpuauto's ------------------------------
# shellcheck disable=SC2046
m68k-amigaos-g++ -noixemul -m68040 -specs="$HERE/scripts/m68k-soft-m68040.specs" -specs="$FA/fpuauto.specs" -L"$FAL" \
    -o "$O/TreeSheets.debug" "$O/main.o" "$O/amiga_stack.o" \
    $("$WXC" --libs std,aui,xml,net) > "$O/link.log" 2>&1 || { head -60 "$O/link.log"; exit 1; }

# --- the GFOpenUp part: Parts/TreeSheets --------------------------------------
P="$OUT/Parts/TreeSheets"; rm -rf "$P"; mkdir -p "$P/Utilities/TreeSheets"
m68k-amigaos-strip -o "$P/Utilities/TreeSheets/TreeSheets" "$O/TreeSheets.debug"
for d in images docs examples translations; do cp -R "$SRC/TS/$d" "$P/Utilities/TreeSheets/"; done
cp "$SRC/TS/readme.html" "$SRC/ZLIB_LICENSE.txt" "$P/Utilities/TreeSheets/"
# only the compiled catalogues (ts.mo) of translations/, and no Windows or shell helpers
find "$P/Utilities/TreeSheets/translations" -type f ! -name ts.mo -exec rm -f {} +
rm -f "$P/Utilities/TreeSheets/docs/script_reference_update.bat"
sh "$HERE/scripts/write-part.sh" "$P" "$TS_VERSION"
ls -l "$P/Utilities/TreeSheets/TreeSheets"
echo "part: $(grep -c '^copy' "$P/Part") files, $(du -sk "$P" | cut -f1) KB"
echo "fpuauto: $(m68k-amigaos-nm "$O/TreeSheets.debug" | grep -c ' T ___wrap_') wrapped routines"
echo "total: $(( $(date +%s) - t0 )) s"
