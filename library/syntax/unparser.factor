! :folding=indent:collapseFolds=1:

! $Id$
!
! Copyright (C) 2004 Slava Pestov.
! 
! Redistribution and use in source and binary forms, with or without
! modification, are permitted provided that the following conditions are met:
! 
! 1. Redistributions of source code must retain the above copyright notice,
!    this list of conditions and the following disclaimer.
! 
! 2. Redistributions in binary form must reproduce the above copyright notice,
!    this list of conditions and the following disclaimer in the documentation
!    and/or other materials provided with the distribution.
! 
! THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
! INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
! FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
! DEVELOPERS AND CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
! SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
! PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
! OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
! WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
! OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
! ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

IN: unparser
USE: generic
USE: kernel
USE: lists
USE: math
USE: namespaces
USE: parser
USE: stdio
USE: strings
USE: words

GENERIC: unparse ( obj -- str )

M: object unparse ( obj -- str )
    [
        "#<" ,
        dup class unparse ,
        " @ " , 
        address unparse ,
        ">" ,
    ] make-string ;

: >digit ( n -- ch )
    dup 10 < [ CHAR: 0 + ] [ 10 - CHAR: a + ] ifte ;

: integer, ( num radix -- )
    dup >r /mod >digit , dup 0 > [
        r> integer,
    ] [
        r> 2drop
    ] ifte ;

: >base ( num radix -- string )
    #! Convert a number to a string in a certain base.
    [
        over 0 < [
            swap neg swap integer, CHAR: - ,
        ] [
            integer,
        ] ifte
    ] make-rstring ;

: >dec ( num -- string ) 10 >base ;
: >bin ( num -- string ) 2 >base ;
: >oct ( num -- string ) 8 >base ;
: >hex ( num -- string ) 16 >base ;

M: fixnum unparse ( obj -- str ) >dec ;
M: bignum unparse ( obj -- str ) >dec ;

M: ratio unparse ( num -- str )
    [
        dup
        numerator unparse ,
        CHAR: / ,
        denominator unparse ,
    ] make-string ;

: fix-float ( str -- str )
    #! This is terrible. Will go away when we do our own float
    #! output.
    "." over str-contains? [ ".0" cat2 ] unless ;

M: float unparse ( float -- str )
    (unparse-float) fix-float ;

M: complex unparse ( num -- str )
    [
        "#{ " ,
        dup
        real unparse ,
        " " ,
        imaginary unparse ,
        " }" ,
    ] make-string ;

: ch>ascii-escape ( ch -- esc )
    [
        [ CHAR: \e | "\\e" ]
        [ CHAR: \n | "\\n" ]
        [ CHAR: \r | "\\r" ]
        [ CHAR: \t | "\\t" ]
        [ CHAR: \0 | "\\0" ]
        [ CHAR: \\ | "\\\\" ]
        [ CHAR: \" | "\\\"" ]
    ] assoc ;

: ch>unicode-escape ( ch -- esc )
    >hex 4 "0" pad "\\u" swap cat2 ;

: unparse-ch ( ch -- ch/str )
    dup quotable? [
        dup ch>ascii-escape dup [
            nip
        ] [
            drop ch>unicode-escape
        ] ifte
    ] unless ;

M: string unparse ( str -- str )
    [
        CHAR: " , [ unparse-ch , ] str-each CHAR: " ,
    ] make-string ;

M: word unparse ( obj -- str )
    word-name dup "#<unnamed>" ? ;

M: t unparse drop "t" ;
M: f unparse drop "f" ;