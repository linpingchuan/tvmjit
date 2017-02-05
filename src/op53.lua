
--
--  TvmJIT : <http://github.com/fperrad/tvmjit/>
--  Copyright (C) 2016 Francois Perrad.
--

local bit = bit
local band = bit.band
local bnot = bit.bnot
local bor = bit.bor
local bxor = bit.bxor
local error = error
local floor = math.floor
local getmetatable = getmetatable
local shl = bit.lshift
local rawget = rawget
local shr = bit.rshift
local tonumber = tonumber
local tvm = tvm or {}
local type = type

local function operror (a)
    error("attempt to perform bitwise operation on a " .. type(a) .. " value", 3)
end

function tvm.band (a, b)
    local mt = getmetatable(a)
    local meth = mt and rawget(mt, '__band')
    if meth then
        return meth(a, b)
    end
    mt = getmetatable(b)
    meth = mt and rawget(mt, '__band')
    if meth then
        return meth(a, b)
    end
    if not tonumber(a) then
        operror(a)
    end
    if not tonumber(b) then
        operror(b)
    end
    return band(a, b)
end

function tvm.bnot (a)
    local mt = getmetatable(a)
    local meth = mt and rawget(mt, '__bnot')
    if meth then
        return meth(a)
    end
    if not tonumber(a) then
        operror(a)
    end
    return bnot(a)
end

function tvm.bor (a, b)
    local mt = getmetatable(a)
    local meth = mt and rawget(mt, '__bor')
    if meth then
        return meth(a, b)
    end
    mt = getmetatable(b)
    meth = mt and rawget(mt, '__bor')
    if meth then
        return meth(a, b)
    end
    if not tonumber(a) then
        operror(a)
    end
    if not tonumber(b) then
        operror(b)
    end
    return bor(a, b)
end

function tvm.bxor (a, b)
    local mt = getmetatable(a)
    local meth = mt and rawget(mt, '__bxor')
    if meth then
        return meth(a, b)
    end
    mt = getmetatable(b)
    meth = mt and rawget(mt, '__bxor')
    if meth then
        return meth(a, b)
    end
    if not tonumber(a) then
        operror(a)
    end
    if not tonumber(b) then
        operror(b)
    end
    return bxor(a, b)
end

function tvm.idiv (a, b)
    local mt = getmetatable(a)
    local meth = mt and rawget(mt, '__idiv')
    if meth then
        return meth(a, b)
    end
    mt = getmetatable(b)
    meth = mt and rawget(mt, '__idiv')
    if meth then
        return meth(a, b)
    end
    return floor(a / b)
end

function tvm.shl (a, b)
    local mt = getmetatable(a)
    local meth = mt and rawget(mt, '__shl')
    if meth then
        return meth(a, b)
    end
    mt = getmetatable(b)
    meth = mt and rawget(mt, '__shl')
    if meth then
        return meth(a, b)
    end
    if not tonumber(a) then
        operror(a)
    end
    if not tonumber(b) then
        operror(b)
    end
    return shl(a, b)
end

function tvm.shr (a, b)
    local mt = getmetatable(a)
    local meth = mt and rawget(mt, '__shr')
    if meth then
        return meth(a, b)
    end
    mt = getmetatable(b)
    meth = mt and rawget(mt, '__shr')
    if meth then
        return meth(a, b)
    end
    if not tonumber(a) then
        operror(a)
    end
    if not tonumber(b) then
        operror(b)
    end
    return shr(a, b)
end

return tvm
