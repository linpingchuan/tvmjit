#!/usr/bin/tvmjit
;
;   TvmJIT : <http://github.com/fperrad/tvmjit/>
;   Copyright (C) 2013-2017 Francois Perrad.
;
;   Major portions taken verbatim or adapted from the lua-TestMore library.
;   Copyright (c) 2009-2015 Francois Perrad
;

(!call (!index tvm "dofile") "TAP.tp")

(!let plan plan)
(!let error_contains error_contains)
(!let is is)

(!call plan 31)

(!call error_contains (!lambda () (!return (!neg !nil)))
                      ": attempt to perform arithmetic on a nil value"
                      "!neg !nil")

(!call error_contains (!lambda () (!return (!len !nil)))
                      ": attempt to get length of a nil value"
                      "!len !nil")

(!call error_contains (!lambda () (!return (!bnot !nil)))
                      ": attempt to perform bitwise operation on a nil value"
                      "!bnot !nil")

(!call is (!not !nil) !true "!not !nil")

(!call error_contains (!lambda () (!return (!add !nil 10)))
                      ": attempt to perform arithmetic on a nil value"
                      "!add !nil 10")

(!call error_contains (!lambda () (!return (!sub !nil 2)))
                      ": attempt to perform arithmetic on a nil value"
                      "!sub !nil 2")

(!call error_contains (!lambda () (!return (!mul !nil 3.14)))
                      ": attempt to perform arithmetic on a nil value"
                      "!mul !nil 3.14")

(!call error_contains (!lambda () (!return (!div !nil -7)))
                      ": attempt to perform arithmetic on a nil value"
                      "!div !nil -7")

(!call error_contains (!lambda () (!return (!mod !nil 4)))
                      ": attempt to perform arithmetic on a nil value"
                      "!mod !nil 4")

(!call error_contains (!lambda () (!return (!pow !nil 3)))
                      ": attempt to perform arithmetic on a nil value"
                      "!pow !nil 3")

(!call error_contains (!lambda () (!return (!concat !nil "end")))
                      ": attempt to concatenate a nil value"
                      "!concat !nil \"end\"")

(!call error_contains (!lambda () (!return (!idiv !nil 3)))
                      ": attempt to perform arithmetic on a nil value"
                      "!idiv !nil 3")

(!call error_contains (!lambda () (!return (!band !nil 7)))
                      ": attempt to perform bitwise operation on a nil value"
                      "!band !nil 7")

(!call error_contains (!lambda () (!return (!bor !nil 1)))
                      ": attempt to perform bitwise operation on a nil value"
                      "!bor !nil 1")

(!call error_contains (!lambda () (!return (!bxor !nil 4)))
                      ": attempt to perform bitwise operation on a nil value"
                      "!bxor !nil 4")

(!call error_contains (!lambda () (!return (!shr !nil 5)))
                      ": attempt to perform bitwise operation on a nil value"
                      "!shr !nil 5")

(!call error_contains (!lambda () (!return (!shl !nil 2)))
                      ": attempt to perform bitwise operation on a nil value"
                      "!shl !nil 2")

(!call is (!eq !nil !nil) !true "!eq !nil !nil")

(!call is (!ne !nil !nil) !false "!ne !nil !nil")

(!call is (!eq !nil 1) !false "!eq !nil 1")

(!call is (!ne !nil 1) !true "!ne !nil 1")

(!call error_contains (!lambda () (!return (!lt !nil !nil)))
                      ": attempt to compare two nil values"
                      "!lt !nil !nil")

(!call error_contains (!lambda () (!return (!le !nil !nil)))
                      ": attempt to compare two nil values"
                      "!le !nil !nil")

(!call error_contains (!lambda () (!return (!gt !nil !nil)))
                      ": attempt to compare two nil values"
                      "!gt !nil !nil")

(!call error_contains (!lambda () (!return (!ge !nil !nil)))
                      ": attempt to compare two nil values"
                      "!ge !nil !nil")

(!call error_contains (!lambda () (!return (!lt !nil 0)))
                      ": attempt to compare nil with number"
                      "!lt !nil 0")

(!call error_contains (!lambda () (!return (!le !nil 0)))
                      ": attempt to compare number with nil"
                      "!le !nil 0")

(!call error_contains (!lambda () (!return (!gt !nil 0)))
                      ": attempt to compare number with nil"
                      "!gt !nil 0")

(!call error_contains (!lambda () (!return (!ge !nil 0)))
                      ": attempt to compare nil with number"
                      "!ge !nil 0")

(!call error_contains (!lambda () (!define a !nil)(!define b (!index a 1)))
                      ": attempt to index"
                      "index")

(!call error_contains (!lambda () (!define a !nil)(!assign (!index a 1) 1))
                      ": attempt to index"
                      "index")

