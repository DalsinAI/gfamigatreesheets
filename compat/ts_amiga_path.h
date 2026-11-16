/* Joins a drawer and a relative path the AmigaOS way: "PROGDIR:" +
 * "images/x.png" is "PROGDIR:images/x.png" and "Work:TS" + "docs" is
 * "Work:TS/docs". A '/' after a ':' would mean the parent drawer, so none
 * is added there.
 * Copyright (c) 2026 AmiCradle Team. zlib licence, like TreeSheets. */
#ifndef TS_AMIGA_PATH_H
#define TS_AMIGA_PATH_H

#include <string>

inline std::string ts_amiga_join(const std::string &dir, const std::string &rel) {
    if (dir.empty()) return rel;
    if (rel.empty()) return dir;
    char last = dir[dir.size() - 1];
    if (last == ':' || last == '/') return dir + rel;
    return dir + "/" + rel;
}

#endif
