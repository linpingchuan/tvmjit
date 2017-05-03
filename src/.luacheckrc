codes = true
std = 'luajit'
read_globals = {
    'tvm',
}

files['parse.lua'].ignore = { '122/tvm' }
files['host/genlibbc.lua'].ignore = { '213/i' } -- unused loop variable i
files['jit/*.lua'].ignore = { '542' }  -- empty if branch
files['jit/bcsave.lua'].ignore = { '231/is64' }  -- variable is64 is never accessed
files['jit/dis_ppc.lua'].ignore = { '212/t' }  -- unused argument t
files['jit/dis_x86.lua'].ignore = { '212/name', '212/pat' }  -- unused argument
files['jit/dump.lua'].ignore = { '211', '212/tr', '232/callee' }
files['jit/vmdef.lua'].ignore = { '631' } -- line is too long
files['json/*.lua'].ignore = { '212/s', '411/posn' }
files['lolcode/lolcode.lua'].ignore = { '121/arg' }
files['lolcode/translator.lua'].ignore = { '211/capt', '231/capt', '311/capt', '411/capt', '411/posn' }

files['lua/tvm.lua'].globals = { '_ENV' }
