#!/usr/bin/tvmjit
;
;   TvmJIT : <http://github.com/fperrad/tvmjit/>
;   Copyright (C) 2013-2017 Francois Perrad.
;
;   Major portions taken verbatim or adapted from the lua-TestMore library.
;   Copyright (c) 2009-2015 Francois Perrad
;

(!call (!index tvm "dofile") "TAP.tp")

(!let tostring tostring)
(!let plan plan)
(!let error_contains error_contains)
(!let is is)
(!let contains contains)
(!let type_ok type_ok)

(!call plan 82)

(!call is -1 (!neg 1) "!neg 1")

(!call is -5 (!bnot 4) "!bnot 4")

(!call error_contains (!lambda () (!return (!len 1)))
                      ": attempt to get length of a number value"
                      "!len 1")

(!call is (!not 1) !false "!not 1")

(!call is (!add 10 2) 12 "!add 10 2")

(!call is (!sub 2 10) -8 "!sub 2 10")

(!call is (!mul 3.14 1) 3.14 "!mul 3.14 1")

(!call is (!div -7 0.5) -14 "!div -7 0.5")

(!call type_ok (!div 1 0) "number" "!div 1 0")

(!call is (!mod -25 3) 2 "!mod -25 3")

(!call type_ok (!mod 1 0) "number" "!mod 1 0")

(!call is (!idiv 25 3) 8 "!idiv 25 3")

(!call is (!idiv 25 -3) -9 "!idiv 25 -3")

(!call is (!idiv 1 -1) -1 "!idiv 1 -1")

(!call type_ok (!idiv 1 0) "number" "!idiv 1 0")

(!call is (!band 3 7) 3 "!band 3 7")

(!call is (!bor 4 1) 5 "!bor 4 1")

(!call is (!bxor 7 1) 6 "!bxor 7 1")

(!call is (!shr 100 5) 3 "!shr 100 5")

(!call is (!shl 3 2) 12 "!shl 3 2")

(!call error_contains (!lambda () (!return (!add 10 !true)))
                      ": attempt to perform arithmetic on a boolean value"
                      "!add 10 true")

(!call error_contains (!lambda () (!return (!sub 2 !nil)))
                      ": attempt to perform arithmetic on a nil value"
                      "!sub 2 !nil")

(!call error_contains (!lambda () (!return (!mul 3.14 !false)))
                      ": attempt to perform arithmetic on a boolean value"
                      "!mul 3.14 !false")

(!call error_contains (!lambda () (!return (!div -7 ())))
                      ": attempt to perform arithmetic on a table value"
                      "!div -7 ()")

(!call error_contains (!lambda () (!return (!pow 3 !true)))
                      ": attempt to perform arithmetic on a boolean value"
                      "!pow 3 !true")

(!call error_contains (!lambda () (!return (!mod -25 !false)))
                      ": attempt to perform arithmetic on a boolean value"
                      "!mod -25 !false")

(!call error_contains (!lambda () (!return (!idiv 25 ())))
                      ": attempt to perform arithmetic on a table value"
                      "!idiv 25 ()")

(!call error_contains (!lambda () (!return (!band 3 !true)))
                      ": attempt to perform bitwise operation on a boolean value"
                      "!band 3 !true")

(!call error_contains (!lambda () (!return (!bor 4 !true)))
                      ": attempt to perform bitwise operation on a boolean value"
                      "!bor 4 !true")

(!call error_contains (!lambda () (!return (!bxor 7 !true)))
                      ": attempt to perform bitwise operation on a boolean value"
                      "!bxor 7 !true")

(!call error_contains (!lambda () (!return (!shr 100 !true)))
                      ": attempt to perform bitwise operation on a boolean value"
                      "!shr 100 !true")

(!call error_contains (!lambda () (!return (!shl 3 !true)))
                      ": attempt to perform bitwise operation on a boolean value"
                      "!shl 3 !true")

(!call error_contains (!lambda () (!return (!add 10 "text")))
                      ": attempt to perform arithmetic on a string value"
                      "!add 10 \"text\"")

(!call error_contains (!lambda () (!return (!sub 2 "text")))
                      ": attempt to perform arithmetic on a string value"
                      "!sub 2 \"text\"")

(!call error_contains (!lambda () (!return (!mul 3.14 "text")))
                      ": attempt to perform arithmetic on a string value"
                      "!mul 3.14 \"text\"")

(!call error_contains (!lambda () (!return (!div -7 "text")))
                      ": attempt to perform arithmetic on a string value"
                      "!div -7 \"text\"")

(!call error_contains (!lambda () (!return (!mod 25 "text")))
                      ": attempt to perform arithmetic on a string value"
                      "!mod 25 \"text\"")

(!call error_contains (!lambda () (!return (!pow 3 "text")))
                      ": attempt to perform arithmetic on a string value"
                      "!pow 3 \"text\"")

(!call error_contains (!lambda () (!return (!idiv 25 "text")))
                      ": attempt to perform arithmetic on a string value"
                      "!idiv 25 \"text\"")

(!call error_contains (!lambda () (!return (!band 3 "text")))
                      ": attempt to perform bitwise operation on a string value"
                      "!band 3 \"text\"")

(!call error_contains (!lambda () (!return (!bor 4 "text")))
                      ": attempt to perform bitwise operation on a string value"
                      "!bor 4 \"text\"")

(!call error_contains (!lambda () (!return (!bxor 7 "text")))
                      ": attempt to perform bitwise operation on a string value"
                      "!bxor 7 \"text\"")

(!call error_contains (!lambda () (!return (!shr 100 "text")))
                      ": attempt to perform bitwise operation on a string value"
                      "!shr 100 \"text\"")

(!call error_contains (!lambda () (!return (!shl 3 "text")))
                      ": attempt to perform bitwise operation on a string value"
                      "!shl 3 \"text\"")

(!call is (!add 10 "2") 12 "!add 10 \"2\"")

(!call is (!sub 2 "10") -8 "!sub 2 \"10\"")

(!call is (!mul 3.14 "1") 3.14 "!mul 3.14 \"1\"")

(!call is (!div -7 "0.5") -14 "!div -7 \"0.5\"")

(!call is (!mod -25 "3") 2 "!mod -25 \"3\"")

(!call is (!pow 3 "3") 27 "!pow 3 \"3\"")

(!call is (!idiv 25 "3") 8 "!idiv 25 \"3\"")

(!call is (!band 3 "7") 3 "!band 3 \"7\"")

(!call is (!bor 4 "1") 5 "!bor 4 \"1\"")

(!call is (!bxor 7 "1") 6 "!bxor 7 \"1\"")

(!call is (!shr 100 "5") 3 "!shr 100 \"5\"")

(!call is (!shl 3 "2") 12 "!shl 3 \"2\"")

(!call is (!concat 1 "end") "1end" "!concat 1 \"end\"")

(!call is (!concat 1 2) "12" "!concat 1 2")

(!call error_contains (!lambda () (!return (!concat 1 !true)))
                      ": attempt to concatenate a boolean value"
                      "!concat 1 !true")

(!call is (!eq 1.0 1) !true "!eq 1.0 1")

(!call is (!ne 1 2) !true "!ne 1 2")

(!call is (!eq 1 !true) !false "!eq 1 !true")

(!call is (!ne 1 !nil) !true "!ne 1 !nil")

(!call is (!eq 1 "1") !false "!eq 1 \"1\"")

(!call is (!ne 1 "1") !true "!ne 1 \"1\"")

(!call is (!lt 1 0) !false "!lt 1 0")

(!call is (!le 1 0) !false "!le 1 0")

(!call is (!gt 1 0) !true "!gt 1 0")

(!call is (!ge 1 0) !true "!ge 1 0")

(!call error_contains (!lambda () (!return (!lt 1 !false)))
                      ": attempt to compare number with boolean"
                      "!lt 1 !false")

(!call error_contains (!lambda () (!return (!le 1 !nil)))
                      ": attempt to compare nil with number"
                      "1 <= nil")

(!call error_contains (!lambda () (!return (!gt 1 !true)))
                      ": attempt to compare boolean with number"
                      "!gt 1 !true")

(!call error_contains (!lambda () (!return (!ge 1 ())))
                      ": attempt to compare number with table"
                      "!ge 1 ()")

(!call error_contains (!lambda () (!return (!lt 1 "0")))
                      ": attempt to compare number with string"
                      "!lt 1 \"0\"")

(!call error_contains (!lambda () (!return (!le 1 "0")))
                      ": attempt to compare string with number"
                      "!le 1 \"0\"")

(!call error_contains (!lambda () (!return (!gt 1 "0")))
                      ": attempt to compare string with number"
                      "!gt 1 \"0\"")

(!call error_contains (!lambda () (!return (!ge 1 "0")))
                      ": attempt to compare number with string"
                      "!ge 1 \"0\"")

(!call is (!call tostring 1000000000) "1000000000" "number 1000000000")

(!call is (!call tostring 1e9) "1000000000" "number 1e9")

(!call is (!call tostring 1.0e+9) "1000000000" "number 1.0e+9")

(!call error_contains (!lambda () (!define a 3.14)(!define b (!index a 1)))
                      ": attempt to index"
                      "index")

(!call error_contains (!lambda () (!define a 3.14)(!assign (!index a 1) 1))
                      ": attempt to index"
                      "index")

