USING: arrays errors math parser test kernel generic words io
listener namespaces ;
IN: temporary

[ 1 CHAR: a ]
[ 0 "abcd" next-char ] unit-test

[ 6 CHAR: \s ]
[ 1 "\\u0020hello" next-escape ] unit-test

[ 2 CHAR: \n ]
[ 1 "\\nhello" next-escape ] unit-test

[ 6 CHAR: \s ]
[ 0 "\\u0020hello" next-char ] unit-test

[ [ 1 [ 2 [ 3 ] 4 ] 5 ] ]
[ "1\n[\n2\n[\n3\n]\n4\n]\n5" parse ]
unit-test

[ [ t t f f ] ]
[ "t t f f" parse ]
unit-test

[ [ "hello world" ] ]
[ "\"hello world\"" parse ]
unit-test

[ [ "\n\r\t\\" ] ]
[ "\"\\n\\r\\t\\\\\"" parse ]
unit-test

[ "hello world" ]
[
    "IN: temporary : hello \"hello world\" ;"
    parse call "USE: scratchpad hello" eval
] unit-test

[ ]
[ "! This is a comment, people." parse call ]
unit-test

! Test escapes

[ [ " " ] ]
[ "\"\\u0020\"" parse ]
unit-test

[ [ "'" ] ]
[ "\"\\u0027\"" parse ]
unit-test

[ "\\u123" parse ] unit-test-fails

! Test EOL comments in multiline strings.
[ [ "Hello" ] ] [ "#! This calls until-eol.\n\"Hello\"" parse ] unit-test 

[ word ] [ \ f class ] unit-test

! Test stack effect parsing

: foo ( a b -- c ) + ;

[ T{ effect f { "a" "b" } { "c" } f } ]
[ \ foo "declared-effect" word-prop ] unit-test

[ t ] [ 1 1 <effect> 2 2 <effect> effect<= ] unit-test
[ f ] [ 1 0 <effect> 2 2 <effect> effect<= ] unit-test
[ t ] [ 2 2 <effect> 2 2 <effect> effect<= ] unit-test
[ f ] [ 3 3 <effect> 2 2 <effect> effect<= ] unit-test
[ f ] [ 2 3 <effect> 2 2 <effect> effect<= ] unit-test

: baz ( a b -- * ) 2array throw ;

[ t ]
[ \ baz "declared-effect" word-prop effect-terminated? ]
unit-test

[ [ ] ] [ "IN: temporary : foo ( a b -- c ) + ;" parse ] unit-test
[ [ ] ] [ "IN: temporary : foo ;" parse ] unit-test
[ f ] [ \ foo "declared-effect" word-prop ] unit-test

! Funny bug
[ 2 ] [ "IN: temporary : \0. 2 ; \0." eval ] unit-test

[ "IN: temporary : missing-- ( a b ) ;" eval ] unit-test-fails

! Test interactive parsing, restarts
[
    file-vocabs
    "errors" use+

    [ [ \ + 1 2 3 4 ] ]
    [
        [
            "cont" set
            [
                "\\ + 1 2 3 4" 
                <string-reader>
                parse-interactive "cont" get continue-with
            ] catch
            "0 :res" eval
        ] callcc1
    ] unit-test
] with-scope

! These should throw errors
[ "HEX: zzz" parse ] unit-test-fails
[ "OCT: 999" parse ] unit-test-fails
[ "BIN: --0" parse ] unit-test-fails

[ f ] [
    "IN: temporary FUNCTION: int foo ; TUPLE: foo ;" parse drop
    "foo" "temporary" lookup symbol?
] unit-test

! Another funny bug
[ t ] [
    [
        "scratchpad" in set
        { "scratchpad" "arrays" } set-use
        [
            ! This shouldn't modify in/use in the outer scope!
            file-vocabs
        ] with-scope
        
        use get { "scratchpad" "arrays" } set-use use get =
    ] with-scope
] unit-test
