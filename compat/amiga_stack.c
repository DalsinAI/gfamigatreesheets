/* A Shell gives 4 KB of stack; libnix's startup sets this much up instead.
 * wxWidgets' event handling and TreeSheets' recursive grid layout nest deeply.
 * Copyright (c) 2026 AmiCradle Team. zlib licence, like TreeSheets. */
unsigned long __stack = 1024 * 1024;
static const char version[] __attribute__((used)) = "$VER: TreeSheets 3048 Amiga (16.11.2026)";
