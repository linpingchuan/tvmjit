/*
** Configuration header.
** Copyright (C) 2013-2015 Francois Perrad.
*/

#ifndef tvmconf_h
#define tvmconf_h

#include "luaconf.h"

/* Default path for loading Lua and C modules with require(). */
#if defined(_WIN32)
/*
** In Windows, any exclamation mark ('!') in the path is replaced by the
** path of the directory of the executable file of the current process.
*/
#define TVM_LDIR	"!\\tvm\\"
#define TVM_CDIR	"!\\"
#define TVM_PATH_DEFAULT \
  ".\\?.lua;" LUA_LDIR"?.lua;" LUA_LDIR"?\\init.lua;"
#define LUA_CPATH_DEFAULT \
  ".\\?.dll;" LUA_CDIR"?.dll;" LUA_CDIR"loadall.dll"
#else
/*
** Note to distribution maintainers: do NOT patch the following line!
** Please read ../doc/install.html#distro and pass PREFIX=/usr instead.
*/
#ifndef LUA_MULTILIB
#define LUA_MULTILIB	"lib"
#endif
#ifndef LUA_LMULTILIB
#define LUA_LMULTILIB	"lib"
#endif
#define LUA_LROOT	"/usr/local"
#define LUA_LUADIR	"/lua/5.1/"
#define TVM_TJDIR	"/tvmjit-0.1.3/"

#ifdef TVM_ROOT
#define TVM_JROOT	TVM_ROOT
#define TVM_RLDIR	TVM_ROOT "/share" LUA_LUADIR
#define TVM_RCDIR	TVM_ROOT "/" LUA_MULTILIB LUA_LUADIR
#define TVM_RLPATH	";" TVM_RLDIR "?.lua;" TVM_RLDIR "?/init.lua"
#define TVM_RCPATH	";" TVM_RCDIR "?.so"
#else
#define TVM_JROOT	LUA_LROOT
#define TVM_RLPATH
#define TVM_RCPATH
#endif

#define TVM_JPATH	";" TVM_JROOT "/share" TVM_TJDIR "?.lua"
#define TVM_LLDIR	LUA_LROOT "/share" LUA_LUADIR
#define TVM_LCDIR	LUA_LROOT "/" LUA_LMULTILIB LUA_LUADIR
#define TVM_LLPATH	";" TVM_LLDIR "?.lua;" TVM_LLDIR "?/init.lua"
#define TVM_LCPATH1	";" TVM_LCDIR "?.so"
#define TVM_LCPATH2	";" TVM_LCDIR "loadall.so"

#define TVM_PATH_DEFAULT	"./?.lua" TVM_JPATH TVM_LLPATH TVM_RLPATH
#define TVM_CPATH_DEFAULT	"./?.so" TVM_LCPATH1 TVM_RCPATH TVM_LCPATH2
#endif

/* Environment variable names for path overrides and initialization code. */
#define TVM_PATH	"TVM_PATH"
#define TVM_CPATH	"TVM_CPATH"
#define TVM_INIT	"TVM_INIT"

#endif
