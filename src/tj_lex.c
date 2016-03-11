/*
** Lexical analyzer.
** Copyright (C) 2013-2015 Francois Perrad.
**
** Major portions taken verbatim or adapted from the LuaJIT.
** Copyright (C) 2005-2016 Mike Pall.
** Major portions taken verbatim or adapted from the Lua interpreter.
** Copyright (C) 1994-2008 Lua.org, PUC-Rio.
*/

#define tj_lex_c
#define LUA_CORE

#include "lj_obj.h"
#include "lj_gc.h"
#include "lj_err.h"
#include "lj_buf.h"
#include "lj_str.h"
#if LJ_HASFFI
#include "lj_tab.h"
#include "lj_ctype.h"
#include "lj_cdata.h"
#include "lualib.h"
#endif
#include "lj_state.h"
#include "tj_lex.h"
#include "tj_parse.h"
#include "lj_char.h"
#include "lj_strscan.h"
#include "lj_strfmt.h"

/* tVM lexer token names. */
static const char *const tokennames[] = {
#define TKSTR(name, sym)	#sym,
TKDEF(TKSTR)
#undef TKSTR
  NULL
};

/* -- Buffer handling ----------------------------------------------------- */

#define LEX_EOF			(-1)
#define lex_iseol(ls)		(ls->c == '\n' || ls->c == '\r')

/* Get more input from reader. */
static LJ_NOINLINE LexChar lex_more(LexState *ls)
 {
  size_t sz;
  const char *p = ls->rfunc(ls->L, ls->rdata, &sz);
  if (p == NULL || sz == 0) return LEX_EOF;
  ls->pe = p + sz;
  ls->p = p + 1;
  return (LexChar)(uint8_t)p[0];
}

/* Get next character. */
static LJ_AINLINE LexChar lex_next(LexState *ls)
{
  return (ls->c = ls->p < ls->pe ? (LexChar)(uint8_t)*ls->p++ : lex_more(ls));
}

/* Save character. */
static LJ_AINLINE void lex_save(LexState *ls, LexChar c)
{
  lj_buf_putb(&ls->sb, c);
}

/* Save previous character and get next character. */
static LJ_AINLINE LexChar lex_savenext(LexState *ls)
{
  lex_save(ls, ls->c);
  return lex_next(ls);
}

/* Skip line break. Handles "\n", "\r", "\r\n" or "\n\r". */
static void lex_newline(LexState *ls)
{
  LexChar old = ls->c;
  lua_assert(lex_iseol(ls));
  lex_next(ls);  /* Skip "\n" or "\r". */
  if (lex_iseol(ls) && ls->c != old) lex_next(ls);  /* Skip "\n\r" or "\r\n". */
  if (++ls->linenumber >= LJ_MAX_LINE)
    lj_lex_error(ls, ls->tok, LJ_ERR_XLINES);
}

/* -- Scanner for terminals ----------------------------------------------- */

/* Parse a number literal. */
static void lex_number(LexState *ls)
{
  StrScanFmt fmt;
  TValue *tv = &ls->tokval;
  LexChar c, xp = 'e';
  if (ls->c == '+' || ls->c == '-')
    lex_savenext(ls);
  if ((c = ls->c) == '0' && (lex_savenext(ls) | 0x20) == 'x')
    xp = 'p';
  while (lj_char_isident(ls->c) || ls->c == '.' ||
	 ((ls->c == '-' || ls->c == '+') && (c | 0x20) == xp)) {
    c = ls->c;
    lex_savenext(ls);
  }
  lex_save(ls, '\0');
  fmt = lj_strscan_scan((const uint8_t *)sbufB(&ls->sb), tv,
	  (LJ_DUALNUM ? STRSCAN_OPT_TOINT : STRSCAN_OPT_TONUM) |
	  (LJ_HASFFI ? (STRSCAN_OPT_LL|STRSCAN_OPT_IMAG) : 0));
  ls->tok = TK_number;
  if (LJ_DUALNUM && fmt == STRSCAN_INT) {
    setitype(tv, LJ_TISNUM);
  } else if (fmt == STRSCAN_NUM) {
    /* Already in correct format. */
#if LJ_HASFFI
  } else if (fmt != STRSCAN_ERROR) {
    lua_State *L = ls->L;
    GCcdata *cd;
    lua_assert(fmt == STRSCAN_I64 || fmt == STRSCAN_U64 || fmt == STRSCAN_IMAG);
    if (!ctype_ctsG(G(L))) {
      ptrdiff_t oldtop = savestack(L, L->top);
      luaopen_ffi(L);  /* Load FFI library on-demand. */
      L->top = restorestack(L, oldtop);
    }
    if (fmt == STRSCAN_IMAG) {
      cd = lj_cdata_new_(L, CTID_COMPLEX_DOUBLE, 2*sizeof(double));
      ((double *)cdataptr(cd))[0] = 0;
      ((double *)cdataptr(cd))[1] = numV(tv);
    } else {
      cd = lj_cdata_new_(L, fmt==STRSCAN_I64 ? CTID_INT64 : CTID_UINT64, 8);
      *(uint64_t *)cdataptr(cd) = tv->u64;
    }
    lj_parse_keepcdata(ls, tv, cd);
#endif
  } else {
    lua_assert(fmt == STRSCAN_ERROR);
    lj_lex_error(ls, TK_number, LJ_ERR_XNUMBER);
  }
}

/* Parse a string. */
static void lex_string(LexState *ls)
{
  lex_savenext(ls);
  while (ls->c != '"') {
    switch (ls->c) {
    case LEX_EOF:
      lj_lex_error(ls, TK_eof, LJ_ERR_XSTR);
      continue;
    case '\\': {
      LexChar c = lex_next(ls);  /* Skip the '\\'. */
      switch (c) {
      case 'a': c = '\a'; break;
      case 'b': c = '\b'; break;
      case 'f': c = '\f'; break;
      case 'n': c = '\n'; break;
      case 'r': c = '\r'; break;
      case 't': c = '\t'; break;
      case 'v': c = '\v'; break;
      case 'x':  /* Hexadecimal escape '\xXX'. */
	c = (lex_next(ls) & 15u) << 4;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 4;
	}
	c += (lex_next(ls) & 15u);
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9;
	}
	break;
      case 'u':  /* Unicode escape '\uXXXX'. */
	c = (lex_next(ls) & 15u) << 12;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 12;
	}
	c += (lex_next(ls) & 15u) << 8;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 8;
	}
	c += (lex_next(ls) & 15u) << 4;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 4;
	}
	c += (lex_next(ls) & 15u);
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9;
	}
	if (c >= 0x0800) {
	  lex_save(ls, 0xE0 | (c >> 12));
	  lex_save(ls, 0x80 | ((c >> 6) & 0x3f));
	  c = 0x80 | (c & 0x3f);
	}
	else if (c >= 0x0080) {
	  lex_save(ls, 0xC0 | (c >> 6));
	  c = 0x80 | (c & 0x3f);
	}
	break;
      case 'U':  /* Unicode escape '\UXXXXXXXX'. */
	c = (lex_next(ls) & 15u) << 28;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 28;
	}
	c += (lex_next(ls) & 15u) << 24;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 24;
	}
	c += (lex_next(ls) & 15u) << 20;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 20;
	}
	c += (lex_next(ls) & 15u) << 16;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 16;
	}
	c += (lex_next(ls) & 15u) << 12;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 12;
	}
	c += (lex_next(ls) & 15u) << 8;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 8;
	}
	c += (lex_next(ls) & 15u) << 4;
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9 << 4;
	}
	c += (lex_next(ls) & 15u);
	if (!lj_char_isdigit(ls->c)) {
	  if (!lj_char_isxdigit(ls->c)) goto err_xesc;
	  c += 9;
	}
	if (c >= 0x4000000) {
	  lex_save(ls, 0xFC | (c >> 30));
	  lex_save(ls, 0x80 | ((c >> 24) & 0x3f));
	  lex_save(ls, 0x80 | ((c >> 18) & 0x3f));
	  lex_save(ls, 0x80 | ((c >> 12) & 0x3f));
	  lex_save(ls, 0x80 | ((c >> 6) & 0x3f));
	  c = 0x80 | (c & 0x3f);
	}
	else if (c >= 0x200000) {
	  lex_save(ls, 0xF8 | (c >> 24));
	  lex_save(ls, 0x80 | ((c >> 18) & 0x3f));
	  lex_save(ls, 0x80 | ((c >> 12) & 0x3f));
	  lex_save(ls, 0x80 | ((c >> 6) & 0x3f));
	  c = 0x80 | (c & 0x3f);
	}
	else if (c >= 0x10000) {
	  lex_save(ls, 0xF0 | (c >> 18));
	  lex_save(ls, 0x80 | ((c >> 12) & 0x3f));
	  lex_save(ls, 0x80 | ((c >> 6) & 0x3f));
	  c = 0x80 | (c & 0x3f);
	}
	else if (c >= 0x0800) {
	  lex_save(ls, 0xE0 | (c >> 12));
	  lex_save(ls, 0x80 | ((c >> 6) & 0x3f));
	  c = 0x80 | (c & 0x3f);
	}
	else if (c >= 0x0080) {
	  lex_save(ls, 0xC0 | (c >> 6));
	  c = 0x80 | (c & 0x3f);
	}
	break;
      case '\\': case '\"': case '\'': break;
      case LEX_EOF: continue;
      default:
      err_xesc:
	lj_lex_error(ls, TK_string, LJ_ERR_XESC);
      }
      lex_save(ls, c);
      lex_next(ls);
      continue;
      }
    case '\n':
    case '\r':
      lex_newline(ls);
      lex_save(ls, '\n');
      break;
    default:
      lex_savenext(ls);
      break;
    }
  }
  lex_savenext(ls);  /* Skip trailing delimiter. */
  setstrV(ls->L, &ls->tokval,
	  lj_parse_keepstr(ls, sbufB(&ls->sb)+1, sbuflen(&ls->sb)-2));
  ls->tok = TK_string;
}

static void lex_name(LexState *ls)
{
  for (;;) {
    switch (ls->c) {
      case '\n':
      case '\r':  /* line breaks */
      case ' ':
      case '\f':
      case '\t':
      case '\v':  /* spaces */
      case '(':
      case ')':
      case ':':
        goto end;
      case '\\':
        lex_next(ls);
      default:
        lex_savenext(ls);
    }
  }
end:
  setstrV(ls->L, &ls->tokval,
	  lj_parse_keepstr(ls, sbufB(&ls->sb), sbuflen(&ls->sb)));
  ls->tok = TK_name;
}

/* -- Main lexical scanner ------------------------------------------------ */

void lj_lex_next(LexState *ls)
{
  ls->lastline = ls->linenumber;
  lj_buf_reset(&ls->sb);
  for (;;) {
    switch (ls->c) {
    case '\n':
    case '\r':
      lex_newline(ls);
      continue;
    case ' ':
    case '\t':
    case '\v':
    case '\f':
      lex_next(ls);
      continue;
    case ';':
      lex_next(ls);
      while (!lex_iseol(ls) && ls->c != LEX_EOF)
	lex_next(ls);
      continue;
    case '(':
    case ')':
    case ':': {
      ls->tok = ls->c;
      lex_next(ls);
      return;
    }
    case '"':
      lex_string(ls);
      return;
    case '-':
    case '+':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      lex_number(ls);
      return;
    case LEX_EOF:
      ls->tok = TK_eof;
      return;
    default: {
      lex_name(ls);
      return;
    }
    }
  }
}

/* -- Lexer API ----------------------------------------------------------- */

/* Setup lexer state. */
int lj_lex_setup(lua_State *L, LexState *ls)
{
  int header = 0;
  ls->L = L;
  ls->fs = NULL;
  ls->pe = ls->p = NULL;
  ls->vstack = NULL;
  ls->sizevstack = 0;
  ls->vtop = 0;
  ls->bcstack = NULL;
  ls->sizebcstack = 0;
  ls->tok = 0;
  ls->linenumber = 1;
  ls->lastline = 1;
  lex_next(ls);  /* Read-ahead first char. */
  if (ls->c == 0xef && ls->p + 2 <= ls->pe && (uint8_t)ls->p[0] == 0xbb &&
      (uint8_t)ls->p[1] == 0xbf) {  /* Skip UTF-8 BOM (if buffered). */
    ls->p += 2;
    lex_next(ls);
    header = 1;
  }
  if (ls->c == '#') {  /* Skip POSIX #! header line. */
    do {
      lex_next(ls);
      if (ls->c == LEX_EOF) return 0;
    } while (!lex_iseol(ls));
    lex_newline(ls);
    header = 1;
  }
  if (ls->c == LUA_SIGNATURE[0]) {  /* Bytecode dump. */
    if (header) {
      /*
      ** Loading bytecode with an extra header is disabled for security
      ** reasons. This may circumvent the usual check for bytecode vs.
      ** Lua code by looking at the first char. Since this is a potential
      ** security violation no attempt is made to echo the chunkname either.
      */
      setstrV(L, L->top++, lj_err_str(L, LJ_ERR_BCBAD));
      lj_err_throw(L, LUA_ERRSYNTAX);
    }
    return 1;
  }
  return 0;
}

/* Cleanup lexer state. */
void lj_lex_cleanup(lua_State *L, LexState *ls)
{
  global_State *g = G(L);
  lj_mem_freevec(g, ls->bcstack, ls->sizebcstack, BCInsLine);
  lj_mem_freevec(g, ls->vstack, ls->sizevstack, VarInfo);
  lj_buf_free(g, &ls->sb);
}

/* Convert token to string. */
const char *lj_lex_token2str(LexState *ls, LexToken tok)
{
  if (tok > TK_OFS)
    return tokennames[tok-TK_OFS-1];
  else if (!lj_char_iscntrl(tok))
    return lj_strfmt_pushf(ls->L, "%c", tok);
  else
    return lj_strfmt_pushf(ls->L, "char(%d)", tok);
}

/* Lexer error. */
void lj_lex_error(LexState *ls, LexToken tok, ErrMsg em, ...)
{
  const char *tokstr;
  va_list argp;
  if (tok == 0) {
    tokstr = NULL;
  } else if (tok == TK_name || tok == TK_string || tok == TK_number) {
    lex_save(ls, '\0');
    tokstr = sbufB(&ls->sb);
  } else {
    tokstr = lj_lex_token2str(ls, tok);
  }
  va_start(argp, em);
  lj_err_lex(ls->L, ls->chunkname, tokstr, ls->linenumber, em, argp);
  va_end(argp);
}

