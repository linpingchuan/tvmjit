
--
--  TvmJIT : <http://github.com/fperrad/tvmjit/>
--  Copyright (C) 2013-2016 Francois Perrad.
--


local _G = _G
local assert = assert
local band = bit.band
local char = string.char
local error = error
local _find = string.find
local format = string.format
local quote = tvm.quote
local rshift = bit.rshift
local setmetatable= setmetatable
local sub = string.sub
local tconcat = table.concat
local tonumber = tonumber

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

local L = {}

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
    self:_esccheck(self.current == '}', "missing '}'");
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

local P = setmetatable({}, { __index=L })

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

function P:statlist ()
    -- statlist -> { stat [`;'] }
    while not self:block_follow(true) do
        self.out[#self.out+1] = '\n'
        if self.t.token == 'return' then
            self:statement()
            return
        end
        self:statement()
    end
end

function P:fieldsel ()
    -- fieldsel -> ['.' | ':'] NAME
    self:next()
    return quote(self:str_checkname())
end

function P:yindex ()
    -- index -> '[' expr ']'
    self:next()
    self:expr(true)
    self:checknext(']')
end

function P:recfield ()
    -- recfield -> (NAME | `['exp1`]') = exp1
    if self.t.token == '<name>' then
        self.out[#self.out+1] = quote(self:str_checkname())
    else
        self:yindex()
    end
    self:checknext('=')
    self.out[#self.out+1] = ': '
    self:expr(true)
end

function P:field ()
    -- field -> listfield | recfield
    if     self.t.token == '<name>' then
        if self:lookahead() ~= '=' then
            self:expr() -- listfield -> exp
        else
            self:recfield()
        end
    elseif self.t.token == '[' then
        self:recfield()
    else
        self:expr()     -- listfield -> exp
    end
end

function P:constructor ()
    -- constructor -> '{' [ field { sep field } [sep] ] '}'
    local line = self.linenumber
    self:checknext('{')
    self.out[#self.out+1] = '('
    repeat
        if self.t.token == '}' then
            break
        end
        self:field()
        if self.t.token == ',' or self.t.token == ';' then
            self.out[#self.out+1] = ' '
        end
    until not (self:testnext(',') or self:testnext(';'))
    self:check_match('}', '{', line)
    self.out[#self.out+1] = ')'
end

function P:parlist (ismethod)
    -- parlist -> [ param { `,' param } ]
    -- param -> NAME | `...'
    if ismethod then
        self.out[#self.out+1] = 'self'
    end
    if self.t.token ~= ')' then
        if ismethod then
            self.out[#self.out+1] = ' '
        end
        repeat
            if self.t.token == '<name>' then
                self.out[#self.out+1] = self.t.seminfo
                self:next()
            elseif self.t.token == '...' then
                self:next()
                self.out[#self.out+1] = '!vararg'
                break
            else
                self:syntaxerror("<name> or '...' expected")
            end
            if self.t.token == ',' then
                self.out[#self.out+1] = ' '
            end
        until not self:testnext(',')
    end
end

function P:body (ismethod, line)
    -- body ->  `(' parlist `)' block END
    self:checknext('(')
    self.out[#self.out+1] = '(!lambda ('
    self:parlist(ismethod)
    self:checknext(')')
    self.out[#self.out+1] = ')'
    self:statlist()
    self:check_match('end', 'function', line)
    self.out[#self.out+1] = ')'
end

function P:explist ()
    -- explist -> expr { `,' expr }
    self:expr()
    while self:testnext(',') do
        self.out[#self.out+1] = ' '
        self:expr()
    end
end

function P:funcargs (line)
    if     self.t.token == '(' then
        -- funcargs -> `(' [ explist ] `)'
        self:next()
        if self.t.token ~= ')' then
            self:explist()
        end
        self:check_match(')', '(', line)
    elseif self.t.token == '{' then
        -- funcargs -> constructor
        self:constructor()
    elseif self.t.token == '<string>' then
        -- funcargs -> STRING
        self.out[#self.out+1] = quote(self.t.seminfo)
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
        self:expr(true)
        self:check_match(')', '(', line)
    elseif self.t.token == '<name>' then
        self.out[#self.out+1] = self:str_checkname()
    else
        self:syntaxerror("unexpected symbol")
    end
end

function P:suffixedexp (one)
    -- suffixedexp ->
    --    primaryexp { `.' NAME | `[' exp `]' | `:' NAME funcargs | funcargs }
    local line = self.linenumber
    local sav = self.out
    self.out = {}
    self:primaryexpr()
    local out = tconcat(self.out)
    while true do
        self.out = {}
        if     self.t.token == '.' then
            out = '(!index ' .. out .. ' ' .. self:fieldsel() .. ')'
        elseif self.t.token == '[' then
            self.out[#self.out+1] = '(!index '
            self.out[#self.out+1] = out
            self.out[#self.out+1] = ' '
            self:yindex()
            self.out[#self.out+1] = ')'
            out = tconcat(self.out)
        elseif self.t.token == ':' then
            self:next()
            if one then
                self.out[#self.out+1] = '(!callmeth1 '
            else
                self.out[#self.out+1] = '(!callmeth '
            end
            self.out[#self.out+1] = out
            self.out[#self.out+1] = ' '
            self.out[#self.out+1] = self:str_checkname()
            self.out[#self.out+1] = ' '
            self:funcargs(line)
            self.out[#self.out+1] = ')'
            out = tconcat(self.out)
        elseif self.t.token == '('
            or self.t.token == '{'
            or self.t.token == '<string>' then
            if one then
                self.out[#self.out+1] = '(!call1 '
            else
                self.out[#self.out+1] = '(!call '
            end
            self.out[#self.out+1] = out
            self.out[#self.out+1] = ' '
            self:funcargs(line)
            self.out[#self.out+1] = ')'
            out = tconcat(self.out)
        else
            self.out = sav
            self.out[#self.out+1] = out
            return
        end
    end
end

function P:simpleexpr (one)
    -- simpleexp -> NUMBER | STRING | NIL | TRUE | FALSE | ... |
    --             constructor | FUNCTION body | suffixedexp
    if     self.t.token == '<number>' then
        self.out[#self.out+1] = self.t.seminfo
    elseif self.t.token == '<string>' then
        self.out[#self.out+1] = quote(self.t.seminfo)
    elseif self.t.token == 'nil' then
        self.out[#self.out+1] = '!nil'
    elseif self.t.token == 'true' then
        self.out[#self.out+1] = '!true'
    elseif self.t.token == 'false' then
        self.out[#self.out+1] = '!false'
    elseif self.t.token == '...' then
        self.out[#self.out+1] = '!vararg'
    elseif self.t.token == '{' then
        self:constructor()
        return
    elseif self.t.token == 'function' then
        self:next()
        self:body(false, self.linenumber)
        return
    else
        self:suffixedexp(one)
        return
    end
    self:next()
end

local unop = {
    ['not']   = '(!not ',
    ['-']     = '(!neg ',
    ['~']     = '(!call1 (!index tvm "bnot")',
    ['#']     = '(!len ',
}
local binop = {
    ['+']     = '(!add ',
    ['-']     = '(!sub ',
    ['*']     = '(!mul ',
    ['%']     = '(!mod ',
    ['^']     = '(!pow ',
    ['/']     = '(!div ',
    ['//']    = '(!call1 (!index tvm "idiv")',
    ['&']     = '(!call1 (!index tvm "band")',
    ['|']     = '(!call1 (!index tvm "bor")',
    ['~']     = '(!call1 (!index tvm "bxor")',
    ['<<']    = '(!call1 (!index tvm "lshift")',
    ['>>']    = '(!call1 (!index tvm "rshift")',
    ['..']    = '(!concat ',
    ['~=']    = '(!ne ',
    ['==']    = '(!eq ',
    ['<']     = '(!lt ',
    ['<=']    = '(!le ',
    ['>']     = '(!gt ',
    ['>=']    = '(!ge ',
    ['and']   = '(!and ',
    ['or']    = '(!or ',
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
    local sav = self.out
    self.out = {}
    local uop = unop[self.t.token]
    if uop then
        self:next()
        self.out[#self.out+1] = uop
        self:expr(false, 12)    -- UNARY_PRIORITY
        self.out[#self.out+1] = ')'
    else
        self:simpleexpr(one)
    end
    local out = tconcat(self.out)
    local op = binop[self.t.token]
    local prior = priority[self.t.token]
    while op and prior[1] > limit do
        self:next()
        self.out = { op, out, ' ' }
        self:expr(false, prior[2])
        self.out[#self.out+1] = ')'
        out = tconcat(self.out)
        op = binop[self.t.token]
        prior = priority[self.t.token]
    end
    self.out = sav
    self.out[#self.out+1] = out
end

function P:block ()
    -- block -> statlist
    self:statlist()
    self.out[#self.out+1] = ')'
end

function P:assignment ()
    if self:testnext(',') then
        -- assignment -> `,' suffixedexp assignment
        self.out[#self.out+1] = ' '
        self:suffixedexp()
        self:assignment()
    else
        -- assignment -> `=' explist
        self:checknext('=')
        self.out[#self.out+1] = ') ('
        self:explist()
        self.out[#self.out+1] = '))'
    end
end

function P:breakstat (line)
    self:next()
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!break)'
end

function P:gotostat (line)
    self:next()
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!goto '
    self.out[#self.out+1] = self:str_checkname()
    self.out[#self.out+1] = ')'
end

function P:labelstat (name, line)
    -- label -> '::' NAME '::'
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!label '
    self.out[#self.out+1] = name
    self.out[#self.out+1] = ')'
    self:checknext('::')
end

function P:whilestat (line)
    -- whilestat -> WHILE cond DO block END
    self:next()
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!while '
    self:expr(true)
    self.out[#self.out+1] = '\n'
    self:checknext('do')
    self:block()
    self:check_match('end', 'while', line)
end

function P:repeatstat (line)
    -- repeatstat -> REPEAT block UNTIL cond
    self:next()
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!repeat'
    self:statlist()
    self:check_match('until', 'repeat', line)
    self.out[#self.out+1] = '\n'
    self:expr(true)
    self.out[#self.out+1] = ')'
end

function P:forbody (name)
    -- forbody -> DO block
    self.out[#self.out+1] = '\n'
    self:checknext('do')
    if name then
        self.out[#self.out+1] = "(!define "
        self.out[#self.out+1] = name
        self.out[#self.out+1] = " "
        self.out[#self.out+1] = name
        self.out[#self.out+1] = ")"
    end
    self:block()
end

function P:fornum (name, line)
    -- fornum -> NAME = exp1,exp1[,exp1] forbody
    self:checknext('=')
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!loop '
    self.out[#self.out+1] = name
    self.out[#self.out+1] = ' '

    self:expr(true)     -- initial value
    self:checknext(',')
    self.out[#self.out+1] = ' '
    self:expr(true)     -- limit
    if self:testnext(',') then
        self.out[#self.out+1] = ' '
        self:expr(true) -- optional step
    else
        self.out[#self.out+1] = ' 1'    -- default step = 1
    end
    self:forbody(name)
end

function P:forlist (name, line)
    -- forlist -> NAME {,NAME} IN explist forbody
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!for ('
    self.out[#self.out+1] = name
    while self:testnext(',') do
        self.out[#self.out+1] = ' '
        self.out[#self.out+1] = self:str_checkname()
    end
    self.out[#self.out+1] = ') ('
    self:checknext('in')
    self:explist()
    self.out[#self.out+1] = ')'
    self:forbody()
end

function P:forstat (line)
    -- forstat -> FOR (fornum | forlist) END
    self:next()
    local name = self:str_checkname()
    if     self.t.token == '=' then
        self:fornum(name, line)
    elseif self.t.token == ','
        or self.t.token == 'in' then
        self:forlist(name, line)
    else
        self:syntaxerror("'=' or 'in' expected")
    end
    self:check_match('end', 'for', line)
end

function P:test_then_block ()
    -- test_then_block -> [IF | ELSEIF] cond THEN block
    self:next()
    self.out[#self.out+1] = '(!if '
    self:expr(true)
    self.out[#self.out+1] = '\n'
    self:checknext('then')
    self.out[#self.out+1] = '(!do'
    self:block()
end

function P:ifstat (line)
    -- ifstat -> IF cond THEN block {ELSEIF cond THEN block} [ELSE block] END
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')'
    self:test_then_block()
    local n = 1
    while self.t.token == 'elseif' do
        self:test_then_block()
        n = n + 1
    end
    if self:testnext('else') then
        self.out[#self.out+1] = '(!do'
        self:block()
    end
    self:check_match('end', 'if', line)
    for _ = 1, n, 1 do
        self.out[#self.out+1] = ')'
    end
end

function P:localfunc (line)
    local name = self:str_checkname()
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!define '
    self.out[#self.out+1] = name
    self.out[#self.out+1] = ')(!assign '
    self.out[#self.out+1] = name
    self:body(false, line)
    self.out[#self.out+1] = ')\n'
end

function P:localstat (line)
    -- stat -> LOCAL NAME {`,' NAME} [`=' explist]
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!define '
    local multi = false
    repeat
        local name = self:str_checkname()
        self.out[#self.out+1] = name
        if self.t.token == ',' then
            if not multi then
                multi = true
                self.out[#self.out] = '('
                self.out[#self.out+1] = name
            end
            self.out[#self.out+1] = ' '
        end
    until not self:testnext(',')
    if multi then
        self.out[#self.out+1] = ')'
    end
    if self:testnext('=') then
        self.out[#self.out+1] = ' '
        if multi then
            self.out[#self.out+1] = '('
        end
        self:explist()
        if multi then
            self.out[#self.out+1] = ')'
        end
    end
    self.out[#self.out+1] = ')'
end

function P:funcname ()
    -- funcname -> NAME {fieldsel} [`:' NAME]
    local ismethod = false
    local name = self:str_checkname()
    while self.t.token == '.' do
        name = '(!index ' .. name .. ' ' .. self:fieldsel() .. ')'
    end
    if self.t.token == ':' then
        ismethod = true
        name = '(!index ' .. name .. ' ' .. self:fieldsel() .. ')'
    end
    self.out[#self.out+1] = name
    return ismethod
end

function P:funcstat (line)
    -- funcstat -> FUNCTION funcname body
    self:next()
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!assign '
    local ismethod = self:funcname()
    self:body(ismethod, line)
    self.out[#self.out+1] = ')\n'
end

function P:exprstat (line)
    -- stat -> func | assignment
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')'
    local sav = self.out
    self.out = {}
    self:suffixedexp()
    local out = tconcat(self.out)
    self.out = sav
    if self.t.token == '=' or self.t.token == ',' then
        self.out[#self.out+1] = '(!massign ('
        self.out[#self.out+1] = out
        self:assignment()
    else
        self.out[#self.out+1] = out
    end
end

function P:retstat (line)
    -- stat -> RETURN [explist] [';']
    self.out[#self.out+1] = '(!line '
    self.out[#self.out+1] = line
    self.out[#self.out+1] = ')(!return '
    if not self:block_follow(true) and self.t.token ~= ';' then
        self:explist()
    end
    self.out[#self.out+1] = ')'
    self:testnext(';')
end

function P:statement ()
    local line = self.linenumber
    if     self.t.token == ';' then
        -- stat -> ';' (empty statement)
        self:next()
    elseif self.t.token == 'if' then
        -- stat -> ifstat
        self:ifstat(line)
    elseif self.t.token == 'while' then
        -- stat -> whilestat
        self:whilestat(line)
    elseif self.t.token == 'do' then
        -- stat -> DO block END
        self:next()
        self.out[#self.out+1] = '(!line '
        self.out[#self.out+1] = line
        self.out[#self.out+1] = ')(!do'
        self:block()
        self:check_match('end', 'do', line)
    elseif self.t.token == 'for' then
        -- stat -> forstat
        self:forstat(line)
    elseif self.t.token == 'repeat' then
        -- stat -> repeatstat
        self:repeatstat(line)
    elseif self.t.token == 'function' then
        -- stat -> funcstat
        self:funcstat(line)
    elseif self.t.token == 'local' then
        -- stat -> localstat
        self:next()
        if self:testnext('function') then
            self:localfunc(line)
        else
            self:localstat(line)
        end
    elseif self.t.token == '::' then
        -- stat -> label
        self:next()
        self:labelstat(self:str_checkname(), line)
    elseif self.t.token == 'return' then
        -- stat -> retstat
        self:next()
        self:retstat(line)
    elseif self.t.token == 'break' then
        -- stat -> breakstat
        self:breakstat(line)
    elseif self.t.token == 'goto' then
        -- stat -> 'goto' NAME
        self:gotostat(line)
    else
        -- stat -> func | assignment
        self:exprstat(line)
    end
end

function P:mainfunc ()
    self:next()
    self:statlist()
    self:check('<eof>')
end

local function translate (s, fname)
    local p = setmetatable({}, { __index=P })
    p:setinput(s, fname)
    if p.current == '\x1B' then
        return s
    end
    p:shebang()
    p.out = { '(!line ', quote(fname), ' ', p.linenumber, ')' }
    p:mainfunc()
    p.out[#p.out+1] = "\n; end of generation"
    return tconcat(p.out)
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
    local code = translate(s, '@' .. fname)
    print "; bootstrap"
    print(code)
end
