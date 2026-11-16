// Host tests for compat/: the in-order task pool and Amiga path joining.
// Copyright (c) 2026 AmiCradle Team. zlib licence, like TreeSheets.
#include <cstdio>
#include <string>
#include <vector>
#include "ts_amiga_pool.h"
#include "ts_amiga_path.h"

static int fails = 0, checks = 0;
#define CHECK(c) do { ++checks; if (!(c)) { ++fails; std::printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); } } while (0)

struct Image { int trefc; int shown; };

int main() {
    // the pool runs each task at once, in order, with its argument (system.h's use)
    std::vector<Image> imgs {{1, 0}, {0, 0}, {2, 0}};
    std::vector<int> order;
    {
        TSAmigaPool pool(1);
        for (size_t i = 0; i < imgs.size(); i++)
            pool.enqueue([&order, i](Image *img) { if (img->trefc) img->shown++; order.push_back(int(i)); }, &imgs[i]);
        CHECK(pool.ran() == 3);
        CHECK(imgs[0].shown == 1 && imgs[1].shown == 0 && imgs[2].shown == 1);  // done before scope ends
    }
    CHECK((order == std::vector<int> {0, 1, 2}));
    { TSAmigaPool pool(0); pool.enqueue([&order] { order.push_back(9); }); CHECK(pool.ran() == 1); }  // 0 workers still runs
    CHECK(order.back() == 9);

    // paths
    CHECK(ts_amiga_join("PROGDIR:", "images/icon32.png") == "PROGDIR:images/icon32.png");
    CHECK(ts_amiga_join("Work:TreeSheets", "docs/tutorial.cts") == "Work:TreeSheets/docs/tutorial.cts");
    CHECK(ts_amiga_join("Work:TreeSheets/", "docs") == "Work:TreeSheets/docs");
    CHECK(ts_amiga_join("", "images") == "images");
    CHECK(ts_amiga_join("PROGDIR:", "") == "PROGDIR:");
    std::printf("%d/%d checks passed\n", checks - fails, checks);
    return fails ? 1 : 0;
}
