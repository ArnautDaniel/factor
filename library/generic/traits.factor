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

IN: generic
USE: errors
USE: hashtables
USE: kernel
USE: lists
USE: namespaces
USE: parser
USE: strings
USE: words
USE: vectors

! Traits metaclass for user-defined classes based on hashtables

: traits ( object -- symbol ) \ traits swap hash ;

! Hashtable slot holding an optional delegate. Any undefined
! methods are called on the delegate. The object can also
! manually pass any methods on to the delegate.
SYMBOL: delegate

: traits-dispatch ( object selector -- object quot )
    over traits over "methods" word-property hash* dup [
        nip cdr ( method is defined )
    ] [
        drop delegate rot hash [
            swap traits-dispatch ( check delegate )
        ] [
            [ undefined-method ] ( no delegate )
        ] ifte*
    ] ifte ;

: add-traits-dispatch ( word vtable -- )
    >r unit [ car traits-dispatch call ] cons \ vector r>
    set-vtable ;

\ traits [
    ( generic vtable definition class -- )
    2drop add-traits-dispatch
] "add-method" set-word-property

\ traits [
    drop vector "builtin-type" word-property unit
] "builtin-supertypes" set-word-property

\ traits 10 "priority" set-word-property

\ traits [ 2drop t ] "class<" set-word-property

: traits-predicate ( word -- )
    #! foo? where foo is a traits type tests if the top of stack
    #! is of this type.
    dup predicate-word swap
    [ swap traits eq? ] cons
    define-compound ;

: TRAITS:
    #! TRAITS: foo creates a new traits type. Instances can be
    #! created with <foo>, and tested with foo?.
    CREATE
    dup define-symbol
    dup \ traits "metaclass" set-word-property
    traits-predicate ; parsing

: constructor-word ( word -- word )
    word-name "<" swap ">" cat3 "in" get create ;

: define-constructor ( constructor traits definition -- )
    >r
    [ \ traits pick set-hash ] cons \ <namespace> swons
    r> append define-compound ;

: C: ( -- constructor traits [ ] )
    #! C: foo ... begins definition for <foo> where foo is a
    #! traits type.
    scan-word [ constructor-word ] keep
    [ define-constructor ] [ ] ; parsing