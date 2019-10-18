! Copyright (C) 2005, 2007 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: hashtables-internals
USING: arrays hashtables kernel kernel-internals math
math-internals sequences sequences-internals vectors ;

: hash@ ( key array -- i )
    >r hashcode r> array-capacity 2 /i rem 2 * >fixnum ; inline

: probe ( array i -- array i )
    2 fixnum+fast over array-capacity fixnum-mod ; inline

: (key@) ( key keys i -- n )
    #! cond form expanded by hand for better interpreter speed
    3dup swap array-nth dup ((tombstone)) eq? [
        2drop probe (key@)
    ] [
        dup ((empty)) eq? [
            2drop 3drop -1
        ] [
            = [ 2nip ] [ probe (key@) ] if
        ] if
    ] if ; inline

: key@ ( key hash -- i )
    hash-array 2dup hash@ (key@) ; inline

: if-key ( key hash true false -- )
    >r >r [ key@ ] 2keep pick -1 > r> r> if ; inline

: <hash-array> ( n -- array )
    >fixnum 1+ 4 * ((empty)) <array> ; inline

: init-hash ( hash -- )
    0 over set-hash-count 0 swap set-hash-deleted ;

: reset-hash ( n hash -- )
    swap <hash-array> over set-hash-array init-hash ;

: (new-key@) ( key keys i -- n )
    #! cond form expanded by hand for better interpreter speed
    3dup swap array-nth dup ((empty)) eq? [
        2drop 2nip
    ] [
        = [
            2nip
        ] [
            probe (new-key@)
        ] if
    ] if ; inline

: new-key@ ( key hash -- i )
    hash-array 2dup hash@ (new-key@) ; inline

: nth-pair ( n seq -- key value )
    [ array-nth ] 2keep >r 1+ r> array-nth ; inline

: set-nth-pair ( value key n seq -- )
    [ set-array-nth ] 2keep >r 1+ r> set-array-nth ; inline

: hash-count+ ( hash -- )
    dup hash-count 1+ swap set-hash-count ; inline

: hash-deleted+ ( hash -- )
    dup hash-deleted 1+ swap set-hash-deleted ; inline

: change-size ( hash old -- )
    ((empty)) eq? [ hash-count+ ] [ drop ] if ; inline

: (set-hash) ( value key hash -- )
    2dup new-key@ swap
    [ hash-array 2dup array-nth ] keep
    swap change-size set-nth-pair ; inline

: (each-pair) ( quot array i -- )
    over array-capacity over eq? [
        3drop
    ] [
        [
            swap nth-pair over tombstone?
            [ 3drop ] [ rot call ] if
        ] 3keep 2 fixnum+fast (each-pair)
    ] if ; inline

: each-pair ( array quot -- )
    swap 0 (each-pair) ; inline

: (all-pairs?) ( quot array i -- ? )
    over array-capacity over eq? [
        3drop t
    ] [
        3dup >r >r >r swap nth-pair over tombstone? [
            3drop r> r> r> 2 fixnum+fast (all-pairs?)
        ] [
            rot call [
                r> r> r> 2 fixnum+fast (all-pairs?)
            ] [
                r> r> r> 3drop f
            ] if
        ] if
    ] if ; inline

: all-pairs? ( array quot -- ? )
    swap 0 (all-pairs?) ; inline

: (hash-keys/values) ( hash quot -- accum array )
    >r
    hash-array [ length 2 /i <vector> ] keep
    r> each-pair { } like ; inline

: (rehash) ( hash array -- )
    [ swap pick (set-hash) ] each-pair drop ;

IN: hashtables

: <hashtable> ( n -- hash )
    (hashtable) [ reset-hash ] keep ;

: hash* ( key hash -- value ? )
    [
        nip >r 1 fixnum+fast r> hash-array array-nth t
    ] [
        3drop f f
    ] if-key ;

: hash-member? ( key hash -- ? )
    [ 3drop t ] [ 3drop f ] if-key ;

: ?hash* ( key hash/f -- value/f ? )
    dup [ hash* ] [ 2drop f f ] if ;

: hash ( key hash -- value ) hash* drop ; inline

: ?hash ( key hash/f -- value )
    dup [ hash ] [ 2drop f ] if ;

: clear-hash ( hash -- )
    dup init-hash hash-array [ drop ((empty)) ] inject ;

: remove-hash ( key hash -- )
    [
        nip
        dup hash-deleted+
        hash-array >r >r ((tombstone)) dup r> r> set-nth-pair
    ] [
        3drop
    ] if-key ;

: ?remove-hash ( key hash/f -- )
    dup [ remove-hash ] [ 2drop ] if ;

: remove-hash* ( key hash -- old )
    [ hash ] 2keep remove-hash ;

: hash-size ( hash -- n )
    dup hash-count swap hash-deleted - ; inline

: hash-empty? ( hash -- ? ) hash-size zero? ;

: rehash ( hash -- )
    dup hash-array
    dup length ((empty)) <array> pick set-hash-array
    (rehash) ;

: grow-hash ( hash -- )
    [ dup hash-array swap hash-size 1+ ] keep
    [ reset-hash ] keep
    swap (rehash) ;

: hash-large? ( hash -- ? )
    dup hash-count 1 fixnum+fast 3 fixnum*
    swap hash-array array-capacity > ;

: hash-stale? ( hash -- ? )
    dup hash-deleted 10 * swap hash-count > ;

: ?grow-hash ( hash -- )
    dup hash-large? [
        grow-hash
    ] [
        dup hash-stale? [
            grow-hash
        ] [
            drop
        ] if
    ] if ; inline

: set-hash ( value key hash -- )
    dup ?grow-hash (set-hash) ;

: associate ( value key -- hash )
    2 <hashtable> [ set-hash ] keep ;

: ?set-hash ( value key hash/f -- hash )
    [ [ set-hash ] keep ] [ associate ] if* ;

: hash-keys ( hash -- seq )
    [ drop over push ] (hash-keys/values) ;

: hash-values ( hash -- seq )
    [ nip over push ] (hash-keys/values) ;

: hash>alist ( hash -- alist )
    dup hash-keys swap hash-values 2array flip ;

: alist>hash ( alist -- hash )
    [ length <hashtable> ] keep
    [ first2 swap pick (set-hash) ] each ;

: hash-each ( hash quot -- )
    >r hash-array r> each-pair ; inline

: hash-each-with ( obj hash quot -- )
    swap [ 2swap [ >r -rot r> call ] 2keep ] hash-each 2drop ;
    inline

: hash-all? ( hash quot -- ? )
    >r hash-array r> all-pairs? ; inline

: hash-all-with? ( obj hash quot -- ? )
    swap
    [ 2swap [ >r -rot r> call ] 2keep rot ] hash-all? 2nip ;
    inline

: subhash? ( hash1 hash2 -- ? )
    swap [
        >r swap hash* [ r> = ] [ r> 2drop f ] if
    ] hash-all-with? ;

: hash-subset ( hash quot -- subhash )
    over hash-size <hashtable> rot [
        2swap [
            >r pick pick >r >r call [
                r> r> swap r> set-hash
            ] [
                r> r> r> 3drop
            ] if
        ] 2keep
    ] hash-each nip ; inline

: hash-subset-with ( obj hash quot -- subhash )
    swap
    [ 2swap [ >r -rot r> call ] 2keep rot ] hash-subset 2nip ;
    inline

: hash-map ( hash quot -- newhash )
    swap hash>alist [
        first2 rot call 2array
    ] map-with alist>hash ; inline

M: hashtable clone
    (clone) dup hash-array clone over set-hash-array ;

: hashtable= ( hash hash -- ? )
    2dup subhash? >r swap subhash? r> and ;

M: hashtable equal?
    {
        { [ over hashtable? not ] [ 2drop f ] }
        { [ 2dup [ hash-size ] 2apply number= not ] [ 2drop f ] }
        { [ t ] [ hashtable= ] }
    } cond ;

: hashtable-hashcode ( hashtable -- n )
    0 swap [
        hashcode >r hashcode -1 shift r> bitxor bitxor
    ] hash-each ;

M: hashtable hashcode
    dup hash-size 1 number=
    [ hashtable-hashcode ] [ hash-size ] if ;

: ?hash ( key hash/f -- value/f )
    dup [ hash ] [ 2drop f ] if ;

: ?hash* ( key hash/f -- value/f ? )
    dup [ hash* ] [ 2drop f f ] if ;

IN: hashtables-internals

: (hash-stack) ( key i seq -- value )
    over 0 < [
        3drop f
    ] [
        3dup nth-unsafe dup [
            hash* [
                >r 3drop r>
            ] [
                drop >r 1- r> (hash-stack)
            ] if
        ] [
            2drop >r 1- r> (hash-stack)
        ] if
    ] if ;

IN: hashtables

: hash-stack ( key seq -- value )
    dup length 1- swap (hash-stack) ;

: hash-intersect ( hash1 hash2 -- intersection )
    [ drop swap hash ] hash-subset-with ;

: hash-update ( hash1 hash2 -- )
    [ swap rot set-hash ] hash-each-with ;

: hash-union ( hash1 hash2 -- union )
    >r clone dup r> hash-update ;

: remove-all ( hash seq -- subseq )
    [ swap hash-member? not ] subset-with ;

: cache ( key hash quot -- value )
    pick pick hash [
        >r 3drop r>
    ] [
        pick rot >r >r call dup r> r> set-hash
    ] if* ; inline

: change-hash ( key hash quot -- )
    [ >r hash r> call ] 3keep drop set-hash ; inline

: hash+ ( n key hash -- )
    [ [ 0 ] unless* + ] change-hash ;

: map>hash ( seq quot -- hash )
    over length <hashtable> rot
    [ -rot [ >r call swap r> set-hash ] 2keep ] each nip ;
    inline
