
--
--  TvmJIT : <http://github.com/fperrad/tvmjit/>
--  Copyright (C) 2013-2017 Francois Perrad.
--

local _G = _G
local string = string
local table = table
local tvm = tvm

local error = error
local format = string.format
local op = tvm.op.new
local ops = tvm.ops.new
local str = tvm.str
local setmetatable= setmetatable
local tostring = tostring

local L = {} do

local assert = assert
local band = bit.band
local char = string.char
local _find = string.find
local rshift = bit.rshift
local sub = string.sub
local tonumber = tonumber
local tconcat = table.concat

local function find (s, patt)
    return _find(s, patt, 1, true)
end

local digit = '0123456789'
local xdigit = 'ABCDEF'
            .. 'abcdef' .. digit
local alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
           .. 'abcdefghijklmnopqrstuvwxyz' .. '_'
local alnum = alpha .. digit
local newline = '\n\r'
local space = ' \f\t\v\n\r'

local tokens = {
    ['and'] = true,
    ['break'] = true,
    ['do'] = true,
    ['else'] = true,
    ['elseif'] = true,
    ['end'] = true,
    ['false']= true,
    ['for'] = true,
    ['function'] = true,
    ['goto'] = true,
    ['if'] = true,
    ['in'] = true,
    ['local'] = true,
    ['nil'] = true,
    ['not'] = true,
    ['or'] = true,
    ['repeat'] = true,
    ['return'] = true,
    ['then'] = true,
    ['true'] = true,
    ['until'] = true,
    ['while'] = true,
}

function L:_resetbuffer ()
    self.buff = {}
end

function L:_buffremove (n)
    for _ = 1, n do
        self.buff[#self.buff] = nil
    end
end

function L:_next ()
    self.pos = self.pos + 1
    local c = sub(self.z, self.pos, self.pos)
    self.current = (c ~= '') and c or '<eof>'
    return self.current
end

function L:_save_and_next ()
    self:_save(self.current)
    self:_next()
end

function L:_save (c)
    self.buff[#self.buff+1] = c
end

function L:_txtToken (token)
    if     token == '<name>'
        or token == '<string>'
        or token == '<number>' then
        return tconcat(self.buff)
    else
        return token
    end
end

local function chunkid (source, max)
    local first = sub(source, 1, 1)
    if     first == '=' then    -- 'literal' source
        return sub(source, 2, 1 + max)
    elseif first == '@' then    -- file name
        if #source <= max then
            return sub(source, 2)
        else
            return '...' .. sub(source, -max)
        end
    else                        -- string; format as [string "source"]
        source = sub(source, 1, (find(source, "\n") or #source) - 1)
        source = (#source < (max - 11)) and source or sub(source, 1, max - 14) .. '...'
        return '[string "' .. source .. '"]'
    end
end

function L:_lexerror (msg, token)
    msg = format("%s:%d: %s", chunkid(self.source, 60), self.linenumber, msg)
    if token then
        msg = format("%s near %s", msg, self:_txtToken(token))
    end
    error(msg)
end

function L:syntaxerror(msg)
    self:_lexerror(msg, self.t.token)
end

function L:_inclinenumber ()
    local old = self.current
    assert(find(newline, self.current))
    self:_next()
    if find(newline, self.current) and self.current ~= old then
        self:_next()
    end
    self.linenumber = self.linenumber + 1
end

function L:setinput(z, source)
    self._lookahead = { token = false, seminfo = false }
    self.z = z
    self.linenumber = 1
    self.lastline = 1
    self.source = source
    self.buff = {}
    self.pos = 0
    self.t = { token = self:_next(), seminfo = false }
end

--[[
    =======================================================
    LEXICAL ANALYZER
    =======================================================
--]]

function L:_check_next1 (c)
    if self.current == c then
        self:_next()
        return true
    end
end

function L:_check_next2 (set)
    if find(set, self.current) then
        self:_save_and_next()
        return true
    end
end

function L:_read_numeral (tok)
    local expo = 'Ee'
    local first = self.current
    assert(find(digit, self.current))
    self:_save_and_next()
    if first == '0' and self:_check_next2('Xx') then
        expo = 'Pp'
    end
    while true do
        if self:_check_next2(expo) then
            self:_check_next2('+-')
        elseif find(xdigit, self.current) or self.current == '.' then
            self:_save_and_next()
        else
            break
        end
    end
    tok.seminfo = tconcat(self.buff)
    if not tonumber(tok.seminfo) then
        self:_lexerror("malformed number", '<number>')
    end
    return '<number>'
end

function L:_skip_sep ()
    local count = 0
    local s = self.current
    assert(s == '[' or s == ']')
    self:_save_and_next()
    while self.current == '=' do
        self:_save_and_next()
        count = count + 1
    end
    return (self.current == s) and count or -count-1
end

function L:_read_long_string (tok, sep)
    local line = self.linenumber
    self:_save_and_next()
    if find(newline, self.current) then
        self:_inclinenumber()
    end
    while true do
        if     self.current == '<eof>' then
            local what = tok and "string" or "comment"
            local msg = format("unfinished long %s (starting at line %d)", what, line)
            self:_lexerror(msg, '<eof>')
        elseif self.current == ']' then
            if self:_skip_sep() == sep then
                self:_save_and_next()
                break
            end
        elseif self.current == '\n' or self.current == '\r' then
            self:_save('\n')
            self:_inclinenumber()
            if not tok then
                self:_resetbuffer()
            end
        else
            if tok then
                self:_save_and_next()
            else
                self:_next()
            end
        end
    end
    if tok then
        tok.seminfo = sub(tconcat(self.buff), 3+sep, -3-sep)
        return '<string>'
    end
end

function L:_esccheck (cond, msg)
    if not cond then
        if self.current ~= '<eof>' then
            self:_save_and_next()
        end
        self:_lexerror(msg, '<string>')
    end
end

function L:_gethexa ()
    self:_save_and_next()
    local c = self.current
    self:_esccheck(find(xdigit, c), "hexadecimal digit expected")
    return tonumber(c, 16)
end

function L:_readhexaesc ()
    local r = self:_gethexa()
    r = (16 * r) + self:_gethexa()
    self:_buffremove(2)
    return char(r)
end

function L:_readutf8esc ()
    local i = 4
    self:_save_and_next()
    self:_esccheck(self.current == '{', "missing '{'")
    local r = self:_gethexa()
    self:_save_and_next()
    while find(xdigit, self.current) do
        i = i + 1
        r = (16 * r) + tonumber(self.current, 16)
        self:_esccheck(r <= 0x10FFFF, "UTF-8 value too large")
        self:_save_and_next()
    end
    self:_esccheck(self.current == '}', "missing '}'")
    self:_next()
    self:_buffremove(i)
    return r
end

function L:_utf8esc ()
    local n = self:_readutf8esc()
    if n < 0x80 then
        self:_save(char(n))
    elseif n < 0x800 then
        self:_save(char(0xC0 + rshift(n, 6)))
        self:_save(char(0x80 + band(n, 0x3F)))
    elseif n < 0x10000 then
        self:_save(char(0xE0 + rshift(n, 12)))
        self:_save(char(0x80 + band(rshift(n, 6), 0x3F)))
        self:_save(char(0x80 + band(n, 0x3F)))
    else
        self:_save(char(0xF0 + rshift(n, 18)))
        self:_save(char(0x80 + band(rshift(n, 12), 0x3F)))
        self:_save(char(0x80 + band(rshift(n, 6), 0x3F)))
        self:_save(char(0x80 + band(n, 0x3F)))
    end
end

function L:_readdecesc ()
    local r = 0
    local i = 0
    while i < 3 and find(digit, self.current) do
        r = (10 * r) + tonumber(self.current)
        self:_save_and_next()
        i = i + 1
    end
    self:_esccheck(r <= 255, "decimal escape too large")
    self:_buffremove(i)
    return char(r)
end

function L:_read_string (del, tok)
    self:_save_and_next()
    while self.current ~= del do
        if     self.current == '<eof>' then
            self:_lexerror("unfinished string", '<eof>')
        elseif self.current == '\n'
            or self.current == '\r' then
            self:_lexerror("unfinished string", '<string>')
        elseif self.current == '\\' then
            local c
            self:_save_and_next()
            if     self.current == 'a' then
                c = '\a'
                goto read_save
            elseif self.current == 'b' then
                c = 'b'
                goto read_save
            elseif self.current == 'f' then
                c = '\f'
                goto read_save
            elseif self.current == 'n' then
                c = '\n'
                goto read_save
            elseif self.current == 'r' then
                c = '\r'
                goto read_save
            elseif self.current == 't' then
                c = '\t'
                goto read_save
            elseif self.current == 'v' then
                c = '\v'
                goto read_save
            elseif self.current == 'x' then
                c = self:_readhexaesc()
                goto read_save
            elseif self.current == 'u' then
                self:_utf8esc()
                goto no_save
            elseif self.current == '\n'
                or self.current == '\r' then
                self:_inclinenumber()
                c = '\n'
                goto only_save
            elseif self.current == '\\' then
                c = '\\'
                goto read_save
            elseif self.current == '"' then
                c = '"'
                goto read_save
            elseif self.current == '\'' then
                c = '\''
                goto read_save
            elseif self.current == '<eof>' then
                goto no_save
                -- will raise an error next loop
            elseif self.current == 'z' then
                self:_buffremove(1)
                self:_next()
                while find(space, self.current) do
                    if find(newline, self.current) then
                        self:_inclinenumber()
                    else
                        self:_next()
                    end
                end
                goto no_save
            else
                self:_esccheck(find(digit, self.current), "invalid escape sequence")
                c = self:_readdecesc()
                goto only_save
            end
::read_save::
            self:_next()
::only_save::
            self:_buffremove(1)
            self:_save(c)
::no_save::
        else
            self:_save_and_next()
        end
    end
    self:_save_and_next()
    tok.seminfo = sub(tconcat(self.buff), 2, -2)
    return '<string>'
end

function L:_llex (tok)
    self:_resetbuffer()
    while true do
        if     self.current == '\n'
            or self.current == '\r' then
            self:_inclinenumber()
        elseif self.current == ' '
            or self.current == '\f'
            or self.current == '\t'
            or self.current == '\v' then
            self:_next()
        elseif self.current == '-' then
            self:_next()
            if self.current ~= '-' then
                return '-'
            end
            self:_next()
            if self.current == '[' then
                local sep = self:_skip_sep()
                self:_resetbuffer()
                if sep >= 0 then
                    self:_read_long_string(nil, sep)
                    self:_resetbuffer()
                end
            else
                while not find(newline, self.current) and self.current ~= '<eof>' do
                    self:_next()
                end
            end
        elseif self.current == '[' then
            local sep = self:_skip_sep()
            if sep >= 0 then
                return self:_read_long_string(tok, sep)
            elseif sep ~= -1 then
                self:_lexerror("invalid long string delimiter", '<string>')
            end
            return '['
        elseif self.current == '=' then
            self:_next()
            if self:_check_next1('=') then
                return '=='
            else
                return '='
            end
        elseif self.current == '<' then
            self:_next()
            if self:_check_next1('=') then
                return '<='
            elseif self:_check_next1('<') then
                return '<<'
            else
                return '<'
            end
        elseif self.current == '>' then
            self:_next()
            if self:_check_next1('=') then
                return '>='
            elseif self:_check_next1('>') then
                return '>>'
            else
                return '>'
            end
        elseif self.current == '/' then
            self:_next()
            if self:_check_next1('/') then
                return '//'
            else
                return '/'
            end
        elseif self.current == '~' then
            self:_next()
            if self:_check_next1('=') then
                return '~='
            else
                return '~'
            end
        elseif self.current == ':' then
            self:_next()
            if self:_check_next1(':') then
                return '::'
            else
                return ':'
            end
        elseif self.current == '"'
            or self.current == '\'' then
            return self:_read_string(self.current, tok)
        elseif self.current == '.' then
            self:_save_and_next()
            if self:_check_next1('.') then
                if self:_check_next1('.') then
                    return '...'
                else
                    return '..'
                end
            end
            if not find(digit, self.current) then
                return '.'
            else
                return self:_read_numeral(tok)
            end
        elseif find(digit, self.current) then
            return self:_read_numeral(tok)
        elseif self.current == '<eof>' then
            return '<eof>'
        else
            if find(alpha, self.current) then
                repeat
                    self:_save_and_next()
                until not find(alnum, self.current)
                tok.seminfo = tconcat(self.buff)
                if tokens[tok.seminfo] then
                    return tok.seminfo
                else
                    return '<name>'
                end
            else
                local c = self.current
                self:_next()
                return c
            end
        end
    end
end

function L:next ()
    self.lastline = self.linenumber
    if self._lookahead.token then
        self.t.token = self._lookahead.token
        self.t.seminfo = self._lookahead.seminfo
        self._lookahead.token = false
    else
        self.t.token = self:_llex(self.t)
    end
end

function L:lookahead ()
    assert(not self._lookahead.token)
    self._lookahead.token = self:_llex(self._lookahead)
    return self._lookahead.token
end

function L:BOM ()
    -- UTF-8 BOM
    if self.current == char(0xEF) then
        self:_next()
        if self.current == char(0xBB) then
            self:_next()
            if self.current == char(0xBF) then
                self:_next()
            end
        end
    end
end

function L:shebang ()
    self:BOM()
    if self.current == '#' then
        while self.current ~= '\n' do
            self:_next()
        end
        self:_inclinenumber()
    end
end

end -- module L

local P = setmetatable({}, { __index=L }) do

function P:error_expected (token)
    self:syntaxerror(token .. " expected")
end

function P:testnext (c)
    if self.t.token == c then
        self:next()
        return true
    else
        return false
    end
end

function P:check (c)
    if self.t.token ~= c then
        self:error_expected(c)
    end
end

function P:checknext (c)
    self:check(c)
    self:next()
end

function P:check_match (what, who, where)
    if not self:testnext(what) then
        if where == self.linenumber then
            self:error_expected(what)
        else
            self:syntaxerror(format("%s expected (to close %s at line %d)", what, who, where))
        end
    end
end

function P:str_checkname ()
    self:check('<name>')
    local name = self.t.seminfo
    self:next()
    return name
end

--[[
    ============================================================
    GRAMMAR RULES
    ============================================================
--]]

function P:block_follow (withuntil)
    if     self.t.token == 'else'
        or self.t.token == 'elseif'
        or self.t.token == 'end'
        or self.t.token == '<eof>' then
        return true
    elseif self.t.token == 'until' then
        return withuntil
    else
        return false
    end
end

function P:statlist (ast)
    -- statlist -> { stat [`;'] }
    while not self:block_follow(true) do
        if self.t.token == 'return' then
            self:statement(ast)
            return
        end
        self:statement(ast)
    end
end

function P:fieldsel ()
    -- fieldsel -> ['.' | ':'] NAME
    self:next()
    return str(self:str_checkname())
end

function P:yindex ()
    -- index -> '[' expr ']'
    self:next()
    local exp = self:expr(true)
    self:checknext(']')
    return exp
end

function P:recfield (ast)
    -- recfield -> (NAME | `['exp1`]') = exp1
    local key = self.t.token == '<name>' and str(self:str_checkname()) or self:yindex()
    self:checknext('=')
    ast:addkv(key, self:expr(true))
end

function P:field (ast)
    -- field -> listfield | recfield
    if     self.t.token == '<name>' then
        if self:lookahead() ~= '=' then
            ast:push(self:expr())       -- listfield -> exp
        else
            self:recfield(ast)
        end
    elseif self.t.token == '[' then
        self:recfield(ast)
    else
        ast:push(self:expr())           -- listfield -> exp
    end
end

function P:constructor ()
    -- constructor -> '{' [ field { sep field } [sep] ] '}'
    local line = self.linenumber
    self:checknext('{')
    local op_ctor = op{}
    repeat
        if self.t.token == '}' then
            break
        end
        self:field(op_ctor)
    until not (self:testnext(',') or self:testnext(';'))
    self:check_match('}', '{', line)
    return op_ctor
end

function P:parlist (ast)
    -- parlist -> [ param { `,' param } ]
    -- param -> NAME | `...'
    if self.t.token ~= ')' then
        repeat
            if self.t.token == '<name>' then
                ast:push(self.t.seminfo)
                self:next()
            elseif self.t.token == '...' then
                self:next()
                ast:push('!vararg')
                break
            else
                self:syntaxerror("<name> or '...' expected")
            end
        until not self:testnext(',')
    end
    return ast
end

function P:body (ismethod, line)
    -- body ->  `(' parlist `)' block END
    self:checknext('(')
    local op_prm = self:parlist(op{ismethod and 'self' or nil})
    self:checknext(')')
    local op_lambda = self:block(op{'!lambda', op_prm})
    self:check_match('end', 'function', line)
    return op_lambda
end

function P:explist (ast)
    -- explist -> expr { `,' expr }
    ast:push(self:expr())
    while self:testnext(',') do
        ast:push(self:expr())
    end
    return ast
end

function P:funcargs (ast, line)
    if     self.t.token == '(' then
        -- funcargs -> `(' [ explist ] `)'
        self:next()
        if self.t.token ~= ')' then
            self:explist(ast)
        end
        self:check_match(')', '(', line)
    elseif self.t.token == '{' then
        -- funcargs -> constructor
        ast:push(self:constructor())
    elseif self.t.token == '<string>' then
        -- funcargs -> STRING
        ast:push(str(self.t.seminfo))
        self:next()
    else
        self:syntaxerror("function arguments expected")
    end
end

function P:primaryexpr ()
    -- primaryexp -> NAME | '(' expr ')'
    if     self.t.token == '(' then
        local line = self.linenumber
        self:next()
        local op_expr = self:expr(true)
        self:check_match(')', '(', line)
        return op_expr
    elseif self.t.token == '<name>' then
        return self:str_checkname()
    else
        self:syntaxerror("unexpected symbol")
    end
end

function P:suffixedexp (one)
    -- suffixedexp ->
    --    primaryexp { `.' NAME | `[' exp `]' | `:' NAME funcargs | funcargs }
    local line = self.linenumber
    local op_expr = self:primaryexpr()
    while true do
        if     self.t.token == '.' then
            op_expr = op{'!index', op_expr, self:fieldsel()}
        elseif self.t.token == '[' then
            op_expr = op{'!index', op_expr, self:yindex()}
        elseif self.t.token == ':' then
            self:next()
            local callmeth = one and '!callmeth1' or '!callmeth'
            op_expr = op{callmeth, op_expr, self:str_checkname()}
            self:funcargs(op_expr, line)
        elseif self.t.token == '('
            or self.t.token == '{'
            or self.t.token == '<string>' then
            local call = one and '!call1' or '!call'
            op_expr = op{call, op_expr}
            self:funcargs(op_expr, line)
        else
            return op_expr
        end
    end
end

function P:simpleexpr (one)
    -- simpleexp -> NUMBER | STRING | NIL | TRUE | FALSE | ... |
    --             constructor | FUNCTION body | suffixedexp
    local exp
    if     self.t.token == '<number>' then
        exp = self.t.seminfo
    elseif self.t.token == '<string>' then
        exp = str(self.t.seminfo)
    elseif self.t.token == 'nil' then
        exp = '!nil'
    elseif self.t.token == 'true' then
        exp = '!true'
    elseif self.t.token == 'false' then
        exp = '!false'
    elseif self.t.token == '...' then
        exp = '!vararg'
    elseif self.t.token == '{' then
        return self:constructor()
    elseif self.t.token == 'function' then
        self:next()
        return self:body(false, self.linenumber)
    else
        return self:suffixedexp(one)
    end
    self:next()
    return exp
end

local unop = {
    ['not']   = '!not',
    ['-']     = '!neg',
    ['~']     = '!call1 (!index tvm "bnot")',
    ['#']     = '!len',
}
local binop = {
    ['+']     = '!add',
    ['-']     = '!sub',
    ['*']     = '!mul',
    ['%']     = '!mod',
    ['^']     = '!pow',
    ['/']     = '!div',
    ['//']    = '!idiv',
    ['&']     = '!band',
    ['|']     = '!bor',
    ['~']     = '!bxor',
    ['<<']    = '!shl',
    ['>>']    = '!shr',
    ['..']    = '!concat',
    ['~=']    = '!ne',
    ['==']    = '!eq',
    ['<']     = '!lt',
    ['<=']    = '!le',
    ['>']     = '!gt',
    ['>=']    = '!ge',
    ['and']   = '!and',
    ['or']    = '!or',
}
local priority = {
    --        { left right }
    ['+']     = { 10, 10 },
    ['-']     = { 10, 10 },
    ['*']     = { 11, 11 },
    ['%']     = { 11, 11 },
    ['^']     = { 14, 13 },     -- right associative
    ['/']     = { 11, 11 },
    ['//']    = { 11, 11 },
    ['&']     = { 6,  6 },
    ['|']     = { 4,  4 },
    ['~']     = { 5,  5 },
    ['<<']    = { 7,  7 },
    ['>>']    = { 7,  7 },
    ['..']    = { 9,  8 },      -- right associative
    ['==']    = { 3,  3 },
    ['<']     = { 3,  3 },
    ['<=']    = { 3,  3 },
    ['~=']    = { 3,  3 },
    ['>']     = { 3,  3 },
    ['>=']    = { 3,  3 },
    ['and']   = { 2,  2 },
    ['or']    = { 1,  1 },
}

function P:expr (one, limit)
    -- expr -> (simpleexp | unop expr) { binop expr }
    limit = limit or 0
    local op_expr
    local uop = unop[self.t.token]
    if uop then
        self:next()
        op_expr = op{uop, self:expr(false, 12)} -- UNARY_PRIORITY
    else
        op_expr = self:simpleexpr(one)
    end
    local bop = binop[self.t.token]
    local prior = priority[self.t.token]
    while bop and prior[1] > limit do
        self:next()
        op_expr = op{bop, op_expr, self:expr(false, prior[2])}
        bop = binop[self.t.token]
        prior = priority[self.t.token]
    end
    return op_expr
end

function P:block (ast)
    -- block -> statlist
    self:statlist(ast)
    return ast
end

function P:assignment (ast)
    if self:testnext(',') then
        -- assignment -> `,' suffixedexp assignment
        ast[2]:push(self:suffixedexp())
        self:assignment(ast)
    else
        -- assignment -> `=' explist
        self:checknext('=')
        self:explist(ast[3])
    end
end

function P:breakstat (ast)
    self:next()
    ast:push(op{'!break'})
end

function P:gotostat (ast)
    self:next()
    ast:push(op{'!goto', self:str_checkname()})
end

function P:labelstat (ast)
    -- label -> '::' NAME '::'
    ast:push(op{'!label', self:str_checkname()})
    self:checknext('::')
end

function P:whilestat (ast, line)
    -- whilestat -> WHILE cond DO block END
    self:next()
    local cond = self:expr(true)
    self:checknext('do')
    local op_while = self:block(op{'!while', cond})
    self:check_match('end', 'while', line)
    ast:push(op_while)
end

function P:repeatstat (ast, line)
    -- repeatstat -> REPEAT block UNTIL cond
    self:next()
    local op_repeat = self:block(op{'!repeat'})
    self:check_match('until', 'repeat', line)
    op_repeat:push(self:expr(true))
    ast:push(op_repeat)
end

function P:forbody (ast)
    -- forbody -> DO block
    self:checknext('do')
    return self:block(ast)
end

function P:fornum (ast, name)
    -- fornum -> NAME = exp1,exp1[,exp1] forbody
    self:checknext('=')
    local init = self:expr(true)
    self:checknext(',')
    local limit = self:expr(true)
    local step = self:testnext(',') and self:expr(true) or 1
    ast:push(self:forbody(op{'!loop', name, init, limit, step, op{'!define', name, name}}))
end

function P:forlist (ast, name)
    -- forlist -> NAME {,NAME} IN explist forbody
    local op_var = op{name}
    while self:testnext(',') do
        op_var:push(self:str_checkname())
    end
    self:checknext('in')
    ast:push(self:forbody(op{'!for', op_var, self:explist(op{})}))
end

function P:forstat (ast, line)
    -- forstat -> FOR (fornum | forlist) END
    self:next()
    local name = self:str_checkname()
    if     self.t.token == '=' then
        self:fornum(ast, name)
    elseif self.t.token == ','
        or self.t.token == 'in' then
        self:forlist(ast, name)
    else
        self:syntaxerror("'=' or 'in' expected")
    end
    self:check_match('end', 'for', line)
end

function P:test_then_block (ast)
    -- test_then_block -> [IF | ELSEIF] cond THEN block
    self:next()
    local op_if = op{'!if', self:expr(true)}
    self:checknext('then')
    op_if:push(self:block(op{'!do'}))
    ast:push(op_if)
    return op_if
end

function P:ifstat (ast, line)
    -- ifstat -> IF cond THEN block {ELSEIF cond THEN block} [ELSE block] END
    local op_if = self:test_then_block(ast)
    while self.t.token == 'elseif' do
        op_if = self:test_then_block(op_if)
    end
    if self:testnext('else') then
        op_if:push(self:block(op{'!do'}))
    end
    self:check_match('end', 'if', line)
end

function P:localfunc (ast, line)
    local name = self:str_checkname()
    ast:push(op{'!define', name})
    ast:push(op{'!assign', name, self:body(false, line)})
end

function P:localstat (ast)
    -- stat -> LOCAL NAME {`,' NAME} [`=' explist]
    local op_var = op{}
    repeat
        op_var:push(self:str_checkname())
    until not self:testnext(',')
    if self:testnext('=') then
        local op_exp = self:explist(op{})
        if #op_var == 1 and #op_exp == 1 then
            ast:push(op{'!define', op_var[1], op_exp[1]})
        else
            ast:push(op{'!mdefine', op_var, op_exp})
        end
    else
        if #op_var == 1 then
            ast:push(op{'!define', op_var[1]})
        else
            ast:push(op{'!mdefine', op_var})
        end
    end
end

function P:funcname ()
    -- funcname -> NAME {fieldsel} [`:' NAME]
    local ismethod = false
    local name = self:str_checkname()
    while self.t.token == '.' do
        name = op{'!index', name, self:fieldsel()}
    end
    if self.t.token == ':' then
        ismethod = true
        name = op{'!index', name, self:fieldsel()}
    end
    return name, ismethod
end

function P:funcstat (ast, line)
    -- funcstat -> FUNCTION funcname body
    self:next()
    local name, ismethod = self:funcname()
    ast:push(op{'!assign', name, self:body(ismethod, line)})
end

function P:exprstat (ast)
    -- stat -> func | assignment
    local op_exp = self:suffixedexp()
    if self.t.token == '=' or self.t.token == ',' then
        local op_asg = op{'!massign', op{op_exp}, op{}}
        self:assignment(op_asg)
        if #op_asg[2] == 1 and #op_asg[3] == 1 then
            op_asg[1] = '!assign'
            op_asg[2] = op_asg[2][1]
            op_asg[3] = op_asg[3][1]
        end
        ast:push(op_asg)
    else
        ast:push(op_exp)
    end
end

function P:retstat (ast)
    -- stat -> RETURN [explist] [';']
    local op_return = op{'!return'}
    if not self:block_follow(true) and self.t.token ~= ';' then
        self:explist(op_return)
    end
    ast:push(op_return)
    self:testnext(';')
end

function P:statement (ast)
    local line = self.linenumber
    ast:push(op{'!line', line})
    if     self.t.token == ';' then
        -- stat -> ';' (empty statement)
        self:next()
    elseif self.t.token == 'if' then
        -- stat -> ifstat
        self:ifstat(ast, line)
    elseif self.t.token == 'while' then
        -- stat -> whilestat
        self:whilestat(ast, line)
    elseif self.t.token == 'do' then
        -- stat -> DO block END
        self:next()
        ast:push(self:block(op{'!do'}))
        self:check_match('end', 'do', line)
    elseif self.t.token == 'for' then
        -- stat -> forstat
        self:forstat(ast, line)
    elseif self.t.token == 'repeat' then
        -- stat -> repeatstat
        self:repeatstat(ast, line)
    elseif self.t.token == 'function' then
        -- stat -> funcstat
        self:funcstat(ast, line)
    elseif self.t.token == 'local' then
        -- stat -> localstat
        self:next()
        if self:testnext('function') then
            self:localfunc(ast, line)
        else
            self:localstat(ast)
        end
    elseif self.t.token == '::' then
        -- stat -> label
        self:next()
        self:labelstat(ast)
    elseif self.t.token == 'return' then
        -- stat -> retstat
        self:next()
        self:retstat(ast)
    elseif self.t.token == 'break' then
        -- stat -> breakstat
        self:breakstat(ast)
    elseif self.t.token == 'goto' then
        -- stat -> 'goto' NAME
        self:gotostat(ast)
    else
        -- stat -> func | assignment
        self:exprstat(ast)
    end
end

function P:mainfunc (ast)
    self:next()
    self:statlist(ast)
    self:check('<eof>')
end

end -- module P

local function parse (s, fname)
    local p = setmetatable({}, { __index=P })
    p:setinput(s, fname)
    if p.current == '\x1B' then
        return s
    end
    p:shebang()
    local ast = ops{op{'!line', str(fname), p.linenumber}}
    p:mainfunc(ast)
    return ast
end

local function translate (s, fname)
    return tostring(parse(s, fname))
end

_G._COMPILER = translate

local arg = arg
local fname = arg and arg[1]
if not debug.getinfo(3) and fname then
    local f, msg = _G.io.open(fname, 'r')
    if not f then
        error(msg)
    end
    local s = f:read'*a'
    f:close()
    local ast = parse(s, '@' .. fname)
    print "; bootstrap"
    print(ast)
    print "\n; end of generation"
end
