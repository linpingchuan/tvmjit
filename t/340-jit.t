#!/usr/bin/tvmjit
;
;   TvmJIT : <http://github.com/fperrad/tvmjit/>
;   Copyright (C) 2013-2015 Francois Perrad.
;

(!call (!index tvm "dofile") "TAP.tp")

(!let plan plan)
(!let is is)
(!let type_ok type_ok)

(!call plan 10)

(!call type_ok (!index jit "on") "function" "function jit.on")
(!call type_ok (!index jit "off") "function" "function jit.off")
(!call type_ok (!index jit "flush") "function" "function jit.flush")
(!call type_ok (!index jit "attach") "function" "function jit.attach")

(!call is (!index jit "version") "LuaJIT 2.1.0-beta2" "jit.version")
(!call is (!index jit "version_num") 20100 "jit.version_num")

(!call type_ok (!index jit "os") "string" "jit.os")
(!call type_ok (!index jit "arch") "string" "jit.arch")

(!call type_ok (!index jit "opt") "table" "jit.opt")
(!call type_ok (!index (!index jit "opt") "start") "function" "function jit.opt.start")

