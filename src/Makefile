# Makefile for compiling required oct files

TARGET := $(shell $(CC) -dumpmachine)
ifeq ($(findstring mingw,$(TARGET)),mingw)
  OS_WINDOWS := 1
endif
ifeq ($(findstring windows,$(TARGET)),windows)
  OS_WINDOWS := 1
endif

ifdef OS_WINDOWS
  OLLAMA_LIBS = -lws2_32
else
  OLLAMA_LIBS =
endif

all:
	$(MKOCTFILE)       -march=native -O2 fig2base64.cc fpng.cpp
	$(MKOCTFILE)       __ollama__.cc $(OLLAMA_LIBS)
