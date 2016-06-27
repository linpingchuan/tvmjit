
--
--  TvmJIT : <http://github.com/fperrad/tvmjit/>
--  Copyright (C) 2016 Francois Perrad.
--

local bit = bit
local band = bit.band
local bnot = bit.bnot
local bor = bit.bor
local bxor = bit.bxor
local floor = math.floor
local getmetatable = getmetatable
local lshift = bit.lshift
local rawget = rawget
local rshift = bit.rshift
local tvm = tvm or {}

function tvm.band (a, b)
    return (rawget(getmetatable(a) or {}, '__band')
         or rawget(getmetatable(b) or {}, '__band')
         or band)(a, b)
end

function tvm.bnot (a)
    return (rawget(getmetatable(a) or {}, '__bnot')
         or bnot)(a)
end

function tvm.bor (a, b)
    return (rawget(getmetatable(a) or {}, '__bor')
         or rawget(getmetatable(b) or {}, '__bor')
         or bor)(a, b)
end

function tvm.bxor (a, b)
    return (rawget(getmetatable(a) or {}, '__bxor')
         or rawget(getmetatable(b) or {}, '__bxor')
         or bxor)(a, b)
end

function tvm.idiv (a, b)
    local meth = rawget(getmetatable(a) or {}, '__idiv')
              or rawget(getmetatable(b) or {}, '__idiv')
    return meth and meth(a, b) or floor(a / b)
end

function tvm.lshift (a, b)
    return (rawget(getmetatable(a) or {}, '__lshift')
         or rawget(getmetatable(b) or {}, '__lshift')
         or lshift)(a, b)
end

function tvm.rshift (a, b)
    return (rawget(getmetatable(a) or {}, '__rshift')
         or rawget(getmetatable(b) or {}, '__rshift')
         or rshift)(a, b)
end

return tvm
