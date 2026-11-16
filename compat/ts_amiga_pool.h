/* TreeSheets' ThreadPool for AmigaOS: one CPU and no std::thread in the
 * Amiga C++ library, so every task runs at once, in the order given, on the
 * calling task. Same interface as src/threadpool.h (the callers only wait
 * for the pool to go out of scope).
 * Copyright (c) 2026 AmiCradle Team. zlib licence, like TreeSheets. */
#ifndef TS_AMIGA_POOL_H
#define TS_AMIGA_POOL_H

#include <cstddef>
#include <utility>

class TSAmigaPool {
    public:
    explicit TSAmigaPool(std::size_t) {}
    template<class F, class... Args>
    void enqueue(F &&f, Args &&...args) {
        std::forward<F>(f)(std::forward<Args>(args)...);
        ++ran_;
    }
    std::size_t ran() const { return ran_; }

    private:
    std::size_t ran_ {0};
};

#endif
