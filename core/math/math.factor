! Copyright (C) 2003, 2006 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: math
USING: errors generic kernel math-internals ;

GENERIC: >fixnum ( x -- y ) foldable
GENERIC: >bignum ( x -- y ) foldable
GENERIC: >float ( x -- y ) foldable

G: number= ( x y -- ? ) math-combination ; foldable
M: object number= 2drop f ;

G: <  ( x y -- ? ) math-combination ; foldable
G: <= ( x y -- ? ) math-combination ; foldable
G: >  ( x y -- ? ) math-combination ; foldable
G: >= ( x y -- ? ) math-combination ; foldable

G: +   ( x y -- z ) math-combination ; foldable
G: -   ( x y -- z ) math-combination ; foldable
G: *   ( x y -- z ) math-combination ; foldable
G: /   ( x y -- z ) math-combination ; foldable
G: /i  ( x y -- z ) math-combination ; foldable
G: mod ( x y -- z ) math-combination ; foldable

G: /mod ( x y -- z w ) math-combination ; foldable

G: bitand ( x y -- z ) math-combination ; foldable
G: bitor  ( x y -- z ) math-combination ; foldable
G: bitxor ( x y -- z ) math-combination ; foldable
G: shift  ( x n -- y ) 1 standard-combination ; foldable

GENERIC: bitnot ( x -- y ) foldable

GENERIC: abs ( x -- y ) foldable
GENERIC: absq ( x -- y ) foldable

GENERIC: zero? ( x -- ? ) foldable
M: object zero? drop f ;

: 1+ ( x -- y ) 1 + ; foldable
: 1- ( x -- y ) 1 - ; foldable
: 2/ ( x -- y ) -1 shift ; foldable
: sq ( x -- y ) dup * ; foldable
: neg ( x -- -x ) 0 swap - ; foldable
: recip ( x -- y ) 1 swap / ; foldable

: most ( x y quot -- z )
    >r 2dup r> call [ drop ] [ nip ] if ; inline

: max ( x y -- z ) [ > ] most ; foldable
: min ( x y -- z ) [ < ] most ; foldable

: between? ( x y z -- ? )
    pick >= [ >= ] [ 2drop f ] if ; foldable

: power-of-2? ( n -- ? )
    dup 0 < [ drop f ] [ dup 1- bitand zero? ] if ; foldable

: rem ( x y -- z ) tuck mod over + swap mod ; foldable
: sgn ( x -- n ) dup 0 < -1 0 ? swap 0 > 1 0 ? bitor ; foldable
: align ( m w -- n ) 1- [ + ] keep bitnot bitand ; inline
: truncate ( x -- y ) dup 1 mod - ; foldable
: round ( x -- y ) dup sgn 2 / + truncate ; foldable

: floor ( x -- y )
    dup 1 mod dup zero?
    [ drop ] [ dup 0 < [ - 1- ] [ - ] if ] if ; foldable

: ceiling ( x -- y ) neg floor neg ; foldable

: [-] ( a b -- c ) - 0 max ; inline

: 2^ ( n -- 2^n ) 1 swap shift ; inline

: (repeat) ( from to quot -- )
    pick pick >= [
        3drop
    ] [
        [ swap >r call 1+ r> ] keep (repeat)
    ] if ; inline

: repeat 0 -rot (repeat) ; inline

: times ( n quot -- )
    swap [ >r dup slip r> ] repeat drop ; inline
