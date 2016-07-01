codes = true
std = 'luajit'
read_globals = {
    'tvm',
}

files['parse.lua'].ignore = { '122/tvm' }
files['json/*.lua'].ignore = { '212/s', '411/posn' }
files['lolcode/lolcode.lua'].ignore = { '121/arg' }
files['lolcode/translator.lua'].ignore = { '211/capt', '231/capt', '311/capt', '411/capt', '411/posn' }

files['lua/tvm.lua'].globals = { '_ENV' }
