! Copyright (C) 2004, 2006 Slava Pestov.
! Copyright (C) 2005 Mackenzie Straight.
! See http://factorcode.org/license.txt for BSD license.
IN: threads
USING: arrays errors hashtables io-internals kernel math
namespaces queues sequences vectors ;

! Co-operative multitasker.

: run-queue ( -- queue ) \ run-queue get-global ;

: schedule-thread ( continuation -- ) run-queue enque ;

: schedule-thread-with ( obj continuation -- )
    2array schedule-thread ;

: sleep-queue ( -- vector ) \ sleep-queue get-global ;

: sleep-queue* ( -- vector )
    sleep-queue dup [ [ first ] compare neg ] nsort ;

: sleep-time ( vector -- ms )
    dup empty? [ drop 1000 ] [ peek first millis [-] ] if ;

: stop ( -- )
    get-walker-hook [
        f swap continue-with
    ] [
        run-queue deque dup array?
        [ first2 continue-with ] [ continue ] if
    ] if* ;

: yield ( -- ) [ schedule-thread stop ] callcc0 ;

: sleep ( ms -- )
    >fixnum millis +
    [ 2array sleep-queue push stop ] callcc0 drop ;

: in-thread ( quot -- )
    [
        schedule-thread
        V{ } set-catchstack
        V{ } set-callstack
        V{ } set-retainstack
        [ print-error ] recover
        stop
    ] callcc0 drop ;

IN: kernel-internals

: (idle-thread) ( slow? -- )
    sleep-queue* dup sleep-time dup zero?
    [ drop pop second schedule-thread drop ]
    [ nip 0 ? io-multiplex ] if ;

: idle-thread ( -- )
    #! This thread is always running.
    #! If run queue is not empty, we don't sleep.
    run-queue queue-empty? (idle-thread) yield idle-thread ;

: init-threads ( -- )
    <queue> \ run-queue set-global
    V{ } clone \ sleep-queue set-global
    [ idle-thread ] in-thread ;
