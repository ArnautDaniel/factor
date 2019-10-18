! Copyright (C) 2006, 2007 Slava Pestov
! See http://factorcode.org/license.txt for BSD license.
IN: objc
USING: alien arrays compiler hashtables kernel kernel-internals
libc math namespaces sequences strings words ;

: init-method ( method alien -- )
    >r first3 r>
    [ >r execute r> set-objc-method-imp ] keep
    [ >r malloc-char-string r> set-objc-method-types ] keep
    >r sel_registerName r> set-objc-method-name ;

: <empty-method-list> ( n -- alien )
    "objc-method-list" heap-size
    "objc-method" heap-size pick * + 1 calloc
    [ set-objc-method-list-count ] keep ;

: <method-list> ( methods -- alien )
    dup length dup <empty-method-list> -rot
    [ pick method-list@ objc-method-nth init-method ] 2each ;

: define-objc-methods ( class methods -- )
    <method-list> class_addMethods ;

: <objc-class> ( name info -- class )
    "objc-class" malloc-object
    [ set-objc-class-info ] keep
    [ >r malloc-char-string r> set-objc-class-name ] keep ;

! The Objective C object model is a bit funny.
! Every class has a metaclass.

! The superclass of the metaclass of X is the metaclass of the
! superclass of X.

! The metaclass of the metaclass of X is the metaclass of the
! root class of X.
: meta-meta-class ( class -- class ) root-class objc-class-isa ;

: copy-instance-size ( class -- )
    dup objc-class-super-class objc-class-instance-size
    swap set-objc-class-instance-size ;

: <meta-class> ( superclass name -- class )
    CLS_META <objc-class>
    [ >r dup objc-class-isa r> set-objc-class-super-class ] keep
    [ >r meta-meta-class r> set-objc-class-isa ] keep
    dup copy-instance-size ;

: <new-class> ( metaclass superclass name -- class )
    CLS_CLASS <objc-class>
    [ set-objc-class-super-class ] keep
    [ set-objc-class-isa ] keep
    dup copy-instance-size ;

: (define-objc-class) ( superclass name imeth -- )
    >r
    >r objc-class r>
    [ <meta-class> ] 2keep <new-class> dup objc_addClass
    r> <method-list> class_addMethods ;

: encode-types ( return types -- encoding )
    swap add* [
        alien>objc-types get hash "0" append
    ] map concat ;

: prepare-method ( ret types quot -- type imp )
    >r [ encode-types ] 2keep r> [
        "cdecl" swap 4array % \ alien-callback ,
    ] [ ] make compile-quot ;

: prepare-methods ( methods -- methods )
    [ first4 prepare-method 3array ] map ;

: redefine-objc-methods ( name imeth -- )
    >r objc_getClass r> define-objc-methods ;

: define-objc-class ( superclass name imeth -- )
    prepare-methods
    over class-exists? [ 2dup redefine-objc-methods ] when
    over >r [ 3array % \ (define-objc-class) , ] [ ] make r>
    swap import-objc-class ;
