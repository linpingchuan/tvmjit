#!/usr/bin/tvmjit
;
;   TvmJIT : <http://github.com/fperrad/tvmjit/>
;   Copyright (C) 2013-2017 Francois Perrad.
;
;   Major portions taken verbatim or adapted from the lua-TestMore library.
;   Copyright (c) 2009-2011 Francois Perrad
;

(!call (!index tvm "dofile") "TAP.tp")

(!let coroutine coroutine)
(!let next next)


(!call plan 8)

;   list_iter
(!let list_iter (!lambda (t)
                (!define i 0)
                (!let n (!len t))
                (!return (!lambda ()
                                (!assign i (!add i 1))
                                (!if (!le i n)
                                     (!return (!index t i))
                                     (!return !nil))))))

(!define t (10 20 30))
(!define output ())
(!for (element) ((!call list_iter t))
      (!assign (!index output (!add (!len output) 1)) element))
(!call eq_array output t "list_iter")

;   values
(!let values (!lambda (t)
                (!define i 0)
                (!return (!lambda ()
                                (!assign i (!add i 1))
                                (!return (!index t i))))))

(!define t (10 20 30))
(!define output ())
(!for (element) ((!call values t))
      (!assign (!index output (!add (!len output) 1)) element))
(!call eq_array output t "values")

;   emul ipairs
(!let iter (!lambda (a i)
                (!assign i (!add i 1))
                (!let v (!index a i))
                (!if v
                     (!return i v))))

(!let my_ipairs (!lambda (a)
                (!return iter a 0)))

(!define a ("one" "two" "three"))
(!define output ())
(!for (i v) ((!call my_ipairs a))
      (!assign (!index output (!add (!len output) 1)) i)
      (!assign (!index output (!add (!len output) 1)) v))
(!call eq_array output (1 "one" 2 "two" 3 "three") "emul ipairs")

;   emul pairs
(!let my_pairs (!lambda (t)
                (!return next t !nil)))

(!define a ("one" "two" "three"))
(!define output ())
(!for (k v) ((!call my_pairs a))
      (!assign (!index output (!add (!len output) 1)) k)
      (!assign (!index output (!add (!len output) 1)) v))
(!call eq_array output (1 "one" 2 "two" 3 "three") "emul pairs")

;   with next
(!define t ("one" "two" "three"))
(!define output ())
(!for (k v) (next t)
      (!assign (!index output (!add (!len output) 1)) k)
      (!assign (!index output (!add (!len output) 1)) v))
(!call eq_array output (1 "one" 2 "two" 3 "three") "with next")

;   permutations
(!letrec permgen (!lambda (a n)
                (!assign n (!or n (!len a)))     ; default for 'n' is size of 'a'
                (!if (!le n 1)                   ; nothing to change?
                     (!call (!index coroutine "yield") a)
                     (!loop i 1 n 1
                            ; put i-th element as the last one
                            (!massign ((!index a n)(!index a i)) ((!index a i)(!index a n)))
                            ; generate all permutations of the other elements
                            (!call permgen a (!sub n 1))
                            ; restore i-th element
                            (!massign ((!index a n)(!index a i)) ((!index a i)(!index a n)))))))

(!let permutations (!lambda (a)
                (!let co (!call (!index coroutine "create") (!lambda () (!call permgen a))))
                (!return (!lambda ()    ; iterator
                                (!mlet (code res) ((!call (!index coroutine "resume") co)))
                                (!return res)))))

(!define output ())
(!for (p) ((!call permutations ("a" "b" "c")))
      (!assign (!index output (!add (!len output) 1)) (!mconcat (!index p 1) " " (!index p 2) " " (!index p 3))))
(!call eq_array output ("b c a" "c b a" "c a b" "a c b" "b a c" "a b c") "permutations")


;   permutations with wrap
(!letrec permgen (!lambda (a n)
                (!assign n (!or n (!len a)))     ; default for 'n' is size of 'a'
                (!if (!le n 1)                   ; nothing to change?
                     (!call (!index coroutine "yield") a)
                     (!loop i 1 n 1
                            ; put i-th element as the last one
                            (!massign ((!index a n)(!index a i)) ((!index a i)(!index a n)))
                            ; generate all permutations of the other elements
                            (!call permgen a (!sub n 1))
                            ; restore i-th element
                            (!massign ((!index a n)(!index a i)) ((!index a i)(!index a n)))))))

(!let permutations (!lambda (a)
                (!return (!call (!index coroutine "wrap") (!lambda () (!call permgen a))))))

(!define output ())
(!for (p) ((!call permutations ("a" "b" "c")))
      (!assign (!index output (!add (!len output) 1)) (!mconcat (!index p 1) " " (!index p 2) " " (!index p 3))))
(!call eq_array output ("b c a" "c b a" "c a b" "a c b" "b a c" "a b c") "permutations with wrap")

;   fibo
(!let fibogen (!lambda ()
                (!mdefine (x y) (0 1))
                (!while !true
                        (!call (!index coroutine "yield") x)
                        (!massign (x y) (y (!add x y))))))

(!let fibo (!lambda ()
                (!return (!call (!index coroutine "wrap") (!lambda () (!call fibogen))))))

(!define output ())
(!for (n) ((!call fibo))
      (!assign (!index output (!add (!len output) 1)) n)
      (!if (!gt n 30) (!break)))
(!call eq_array output (0 1 1 2 3 5 8 13 21 34) "fibo")

