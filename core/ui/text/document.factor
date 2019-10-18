! Copyright (C) 2006, 2007 Slava Pestov
! See http://factorcode.org/license.txt for BSD license.
IN: gadgets-text
USING: arrays generic io kernel math models namespaces sequences
strings test ;

: +col ( loc n -- newloc ) >r first2 r> + 2array ;

: +line ( loc n -- newloc ) >r first2 swap r> + swap 2array ;

: =col ( n loc -- newloc ) first swap 2array ;

: =line ( n loc -- newloc ) second 2array ;

: lines-equal? ( loc1 loc2 -- ? ) [ first ] 2apply number= ;

TUPLE: document locs ;

C: document ( -- document )
    V{ "" } clone <model> over set-delegate
    V{ } clone over set-document-locs ;

: add-loc document-locs push ;

: remove-loc document-locs delete ;

: update-locs ( loc document -- )
    document-locs [ set-model ] each-with ;

: doc-line ( n document -- string ) model-value nth ;

: doc-lines ( from to document -- slice )
    >r 1+ r> model-value <slice> ;

: start-on-line ( document from line# -- n1 )
    >r dup first r> = [ nip second ] [ 2drop 0 ] if ;

: end-on-line ( document to line# -- n2 )
    over first over = [
        drop second nip
    ] [
        nip swap doc-line length
    ] if ;

: each-line ( from to quot -- )
    pick pick = [
        3drop
    ] [
        >r [ first ] 2apply 1+ dup <slice> r> each
    ] if ; inline

: start/end-on-line ( from to line# -- n1 n2 )
    tuck >r >r document get -rot start-on-line r> r>
    document get -rot end-on-line ;

: (doc-range) ( from to line# -- )
    [ start/end-on-line ] keep document get doc-line <slice> , ;

: doc-range ( from to document -- string )
    [
        document set 2dup [
            >r 2dup r> (doc-range)
        ] each-line 2drop
    ] { } make "\n" join ;

: text+loc ( lines loc -- loc )
    over >r over length 1 = [
        nip first2
    ] [
        first swap length 1- + 0
    ] if r> peek length + 2array ;

: prepend-first ( str seq -- )
    0 swap [ append ] change-nth ;

: append-last ( str seq -- )
    [ length 1- ] keep [ swap append ] change-nth ;

: loc-col/str ( loc document -- str col )
    >r first2 swap r> nth swap ;

: prepare-insert ( newinput from to lines -- newinput )
    tuck loc-col/str tail-slice >r loc-col/str head-slice r>
    pick append-last over prepend-first ;

: (set-doc-range) ( newlines from to lines -- )
    [ prepare-insert ] 3keep
    >r [ first ] 2apply 1+ r>
    replace-slice ;

: set-doc-range ( string from to document -- )
    [
        >r >r >r string-lines r> [ text+loc ] 2keep r> r>
        [ [ (set-doc-range) ] keep ] change-model
    ] keep update-locs ;

: remove-doc-range ( from to document -- )
    >r >r >r "" r> r> r> set-doc-range ;

: last-line# ( document -- line )
    model-value length 1- ;

: validate-line ( line document -- line )
    last-line# min 0 max ;

: validate-col ( col line document -- col )
    doc-line length min 0 max ;

: line-end ( line# document -- loc )
    dupd doc-line length 2array ;

: line-end? ( loc document -- ? )
    >r first2 swap r> doc-line length = ;

: doc-end ( document -- loc )
    [ last-line# ] keep line-end ;

: validate-loc ( loc document -- newloc )
    over first over model-value length >= [
        nip doc-end
    ] [
        over first 0 < [
            2drop { 0 0 }
        ] [
            >r first2 swap tuck r> validate-col 2array
        ] if
    ] if ;

: doc-string ( document -- str )
    model-value "\n" join ;

: set-doc-string ( string document -- )
    >r string-lines V{ } like r> [ set-model ] keep
    dup doc-end swap update-locs ;

: clear-doc ( document -- )
    "" swap set-doc-string ;
