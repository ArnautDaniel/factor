! Copyright (C) 2004, 2007 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: math
USING: errors generic kernel math-internals namespaces sequences
strings ;

DEFER: base>

: string>ratio ( str radix -- a/b )
    >r "/" split1 r> tuck base> >r base> r>
    2dup and [ / ] [ 2drop f ] if ;

: digit> ( ch -- n )
    {
        { [ dup digit?  ] [ CHAR: 0 - ] }
        { [ dup letter? ] [ CHAR: a - 10 + ] }
        { [ dup LETTER? ] [ CHAR: A - 10 + ] }
        { [ t ] [ drop f ] }
    } cond ;

: digit+ ( num digit base -- num )
    pick pick and
    [ 2dup < [ rot * + ] [ 3drop f ] if ] [ 3drop f ] if ;

: (string>integer) ( radix str -- num )
    dup empty? [
        2drop f
    ] [
        0 [ digit> pick digit+ ] reduce nip
    ] if ;

: string>integer ( string radix -- n )
    swap "-" ?head >r (string>integer) dup r> and [ neg ] when ;

: base> ( str radix -- n/f )
    {
        { [ CHAR: / pick member? ] [ string>ratio ] }
        { [ CHAR: . pick member? ] [ drop string>float ] }
        { [ t ] [ string>integer ] }
    } cond ;

: string>number ( str -- n ) 10 base> ;
: bin> ( str -- n ) 2 base> ;
: oct> ( str -- n ) 8 base> ;
: hex> ( str -- n ) 16 base> ;

: >digit ( n -- ch )
    dup 10 < [ CHAR: 0 + ] [ 10 - CHAR: a + ] if ;

: integer, ( num radix -- )
    dup 1 <= [ "Invalid radix" throw ] when
    dup >r /mod >digit , dup 0 >
    [ r> integer, ] [ r> 2drop ] if ;

G: >base ( n radix -- str ) 1 standard-combination ;

M: integer >base
    [
        over 0 < [
            swap neg swap integer, CHAR: - ,
        ] [
            integer,
        ] if
    ] "" make reverse ;

M: ratio >base
    [
        over numerator over >base %
        CHAR: / ,
        swap denominator swap >base %
    ] "" make ;

: fix-float
    CHAR: . over member? [ ".0" append ] unless ;

M: float >base
    drop {
        { [ dup 1.0/0.0 = ] [ drop "1.0/0.0" ] }
        { [ dup -1.0/0.0 = ] [ drop "-1.0/0.0" ] }
        { [ dup fp-nan? ] [ drop "0.0/0.0" ] }
        { [ t ] [ float>string fix-float ] }
    } cond ;

: number>string ( n -- str ) 10 >base ;
: >bin ( num -- string ) 2 >base ;
: >oct ( num -- string ) 8 >base ;
: >hex ( num -- string ) 16 >base ;

: # ( n -- ) number>string % ;
