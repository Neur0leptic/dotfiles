#!/bin/bash

clang -std=c23 -Ofast -flto=thin -pipe -march=native -Wl,-O3 -Wl,--as-needed -Wl,--gc-sections -Wl,--icf=all \
	"${1}" -o "${1%.*}" -lpthread -lmimalloc
