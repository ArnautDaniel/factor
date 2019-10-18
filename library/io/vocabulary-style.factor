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

IN: presentation
USE: hashtables
USE: lists
USE: kernel
USE: namespaces
USE: words

: vocab-style ( vocab -- style )
    #! Each vocab has a style object specifying how words are
    #! to be printed.
    "vocabularies" style hash ;

: set-vocab-style ( style vocab -- )
    >r default-style append r> "vocabularies" style set-hash ;

: word-style ( word -- style )
    word-vocabulary [ vocab-style ] [ default-style ] ifte* ;

<namespace> "vocabularies" set-style

[
    [ "ansi-fg" | "1" ]
    [ "fg" | [ 204 0 0 ] ]
] "arithmetic" set-vocab-style
[
    [ "ansi-fg" | "1" ]
    [ "fg" | [ 255 0 0 ] ]
] "errors" set-vocab-style
[
    [ "ansi-fg" | "4" ]
    [ "fg" | [ 153 102 255 ] ]
] "hashtables" set-vocab-style
[
    [ "ansi-fg" | "2" ]
    [ "fg" | [ 0 102 153 ] ]
] "lists" set-vocab-style
[
    [ "ansi-fg" | "1" ]
    [ "fg" | [ 204 0 0 ] ]
] "math" set-vocab-style
[
    [ "ansi-fg" | "6" ]
    [ "fg" | [ 0 153 255 ] ]
] "namespaces" set-vocab-style
[
    [ "ansi-fg" | "2" ]
    [ "fg" | [ 102 204 255 ] ]
] "parser" set-vocab-style
[
    [ "ansi-fg" | "2" ]
    [ "fg" | [ 102 204 255 ] ]
] "prettyprint" set-vocab-style
[
    [ "ansi-fg" | "2" ]
    [ "fg" | [ 0 0 0 ] ]
] "stack" set-vocab-style
[
    [ "ansi-fg" | "4" ]
    [ "fg" | [ 204 0 204 ] ]
] "stdio" set-vocab-style
[
    [ "ansi-fg" | "4" ]
    [ "fg" | [ 102 0 204 ] ]
] "streams" set-vocab-style
[
    [ "ansi-fg" | "6" ]
    [ "fg" | [ 255 0 204 ] ]
] "strings" set-vocab-style
[
    [ "ansi-fg" | "4" ]
    [ "fg" | [ 102 204 255 ] ]
] "unparser" set-vocab-style
[
    [ "ansi-fg" | "3" ]
    [ "fg" | [ 2 185 2 ] ]
] "vectors" set-vocab-style
[
    [ "fg" | [ 128 128 128 ] ]
] "syntax" set-vocab-style