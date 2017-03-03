
--
--  TvmJIT : <http://github.com/fperrad/tvmjit/>
--  Copyright (C) 2013-2017 Francois Perrad.
--

--
--  This module emulates some features of TvmJIT in Lua for Lua.
--

local char = string.char
local format = string.format
local gsub = string.gsub
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local type = type
local tconcat = table.concat
local unpack = table.unpack or unpack   -- luacheck: compat
local _G = _G

_ENV = nil

local tvm = {}
_G.tvm = tvm

function tvm.escape (s)
    return (gsub(s, '[():%s]', function (c) return '\\' .. c end))
end

function tvm.quote (s)
    return format('%q', s)
end

function tvm.unpack (t)
    return unpack(t or {})
end

function tvm.wchar (n)
    return char(n)
end


local need_newline = {
    ['!line'] = true,
    ['!do'] = true,
}

local op_mt = {
        __tostring = function (o)
                        local t = {}
                        if o[0] then
                            t[#t+1] = '0: ' .. tostring(o[0])
                        end
                        for i = 1, #o do
                            t[#t+1] = tostring(o[i])
                        end
                        for k, v in pairs(o) do
                            if type(k) ~= 'number' or k < 0 or k > #o then
                                t[#t+1] = tostring(k) .. ': ' .. tostring(v)
                            end
                        end
                        return (need_newline[o[1]] and "\n(" or "(") .. tconcat(t, ' ') .. ')'
        end,
}

local op = {
        push = function (self, v)
                        self[#self+1] = v
                        return self
        end,
        addkv = function (self, k, v)
                        self[k] = v
                        return self
        end,
        new = function (t)
                        return setmetatable(t, op_mt)
        end,
        _NAME = 'op',
}
op_mt.__index = op
tvm.op = op

local ops_mt = {
        __tostring = function (o)
                        local t = {}
                        for i = 1, #o do
                            t[i] = tostring(o[i])
                        end
                        return tconcat(t)
        end,
}

local ops = {
        push = function (self, v)
                        self[#self+1] = v
                        return self
        end,
        new = function (t)
                        return setmetatable(t, ops_mt)
        end,
        _NAME = 'ops',
}
ops_mt.__index = ops
tvm.ops = ops

local str_mt = {
        __tostring = function (o)
                        return tvm.quote(o[1])
        end,
}

function tvm.str (s)
    return setmetatable({s}, str_mt)
end

return tvm

