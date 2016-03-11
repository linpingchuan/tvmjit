/*
** Lexical analyzer.
** Copyright (C) 2013-2015 Francois Perrad.
**
** Major parts taken verbatim from the LuaJIT.
** Copyright (C) 2005-2016 Mike Pall.
** Major portions taken verbatim or adapted from the Lua interpreter.
** Copyright (C) 1994-2008 Lua.org, PUC-Rio.
*/

#ifndef _TJ_LEX_H
#define _TJ_LEX_H

#include <stdarg.h>

#include "lj_obj.h"
#include "lj_err.h"

/* tVM lexer tokens. */
#define TKDEF(_) \
  _(number, <number>) _(name, <name>) _(string, <string>) _(eof, <eof>)

enum {
  TK_OFS = 256,
#define TKENUM(name, sym)	TK_##name,
TKDEF(TKENUM)
#undef TKENUM
};

typedef int LexChar;	/* Lexical character. Unsigned ext. from char. */
typedef int LexToken;	/* Lexical token. */

/* Combined bytecode ins/line. Only used during bytecode generation. */
typedef struct BCInsLine {
  BCIns ins;		/* Bytecode instruction. */
  BCLine line;		/* Line number for this bytecode. */
} BCInsLine;

/* Info for local variables. Only used during bytecode generation. */
typedef struct VarInfo {
  GCRef name;		/* Local variable name or goto/label name. */
  BCPos startpc;	/* First point where the local variable is active. */
  BCPos endpc;		/* First point where the local variable is dead. */
  uint8_t slot;		/* Variable slot. */
  uint8_t info;		/* Variable/goto/label info. */
  uint8_t final;
} VarInfo;

/* Lua lexer state. */
typedef struct LexState {
  struct FuncState *fs;	/* Current FuncState. Defined in tj_parse.c. */
  struct lua_State *L;	/* Lua state. */
  TValue tokval;	/* Current token value. */
  const char *p;	/* Current position in input buffer. */
  const char *pe;	/* End of input buffer. */
  LexChar c;		/* Current character. */
  LexToken tok;		/* Current token. */
  SBuf sb;		/* String buffer for tokens. */
  lua_Reader rfunc;	/* Reader callback. */
  void *rdata;		/* Reader callback data. */
  BCLine linenumber;	/* Input line counter. */
  BCLine lastline;	/* Line of last token. */
  GCstr *chunkname;	/* Current chunk name (interned string). */
  const char *chunkarg;	/* Chunk name argument. */
  const char *mode;	/* Allow loading bytecode (b) and/or source text (t). */
  VarInfo *vstack;	/* Stack for names and extents of local variables. */
  MSize sizevstack;	/* Size of variable stack. */
  MSize vtop;		/* Top of variable stack. */
  BCInsLine *bcstack;	/* Stack for bytecode instructions/line numbers. */
  MSize sizebcstack;	/* Size of bytecode stack. */
  uint32_t level;	/* Syntactical nesting level. */
} LexState;

LJ_FUNC int lj_lex_setup(lua_State *L, LexState *ls);
LJ_FUNC void lj_lex_cleanup(lua_State *L, LexState *ls);
LJ_FUNC void lj_lex_next(LexState *ls);
LJ_FUNC const char *lj_lex_token2str(LexState *ls, LexToken tok);
LJ_FUNC_NORET void lj_lex_error(LexState *ls, LexToken tok, ErrMsg em, ...);

#endif
