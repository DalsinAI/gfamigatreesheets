# Host tests for the Amiga pieces (compat/): make test
CXX ?= c++
CXXFLAGS ?= -std=c++17 -Wall -Wextra -Werror -O1
test: test_compat
	./test_compat
	sh test-part.sh
test_compat: test_compat.cpp ../compat/ts_amiga_pool.h ../compat/ts_amiga_path.h
	$(CXX) $(CXXFLAGS) -I../compat -o $@ test_compat.cpp
clean:
	rm -f test_compat
.PHONY: test clean
