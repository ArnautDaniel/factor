! Copyright (C) 2005, 2006 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: generic hashtables inference kernel math namespaces
sequences vectors words parser ;
IN: gadgets

GENERIC: graft* ( gadget -- )

M: gadget graft* drop ;

: graft ( gadget -- )
    t over set-gadget-grafted?
    dup graft*
    [ graft ] each-child ;

GENERIC: ungraft* ( gadget -- )

M: gadget ungraft* drop ;

: ungraft ( gadget -- )
    dup gadget-grafted? [
        dup [ ungraft ] each-child
        dup ungraft*
        f over set-gadget-grafted?
    ] when drop ;

: (unparent) ( gadget -- )
    dup ungraft
    dup forget-pref-dim
    f swap set-gadget-parent ;

: unparent ( gadget -- )
    [
        dup gadget-parent dup [
            over (unparent)
            [ gadget-children delete ] keep relayout
        ] [
            2drop
        ] if
    ] when* ;

: (clear-gadget) ( gadget -- )
    dup [ (unparent) ] each-child f swap set-gadget-children ;

: clear-gadget ( gadget -- )
    dup (clear-gadget) relayout ;

: ((add-gadget)) ( gadget box -- )
    [ gadget-children ?push ] keep set-gadget-children ;

: (add-gadget) ( gadget box -- )
    over unparent
    dup pick set-gadget-parent
    [ ((add-gadget)) ] 2keep
    gadget-grafted? [ graft ] [ drop ] if ;

: add-gadget ( gadget parent -- )
    [ (add-gadget) ] keep relayout ;

: add-gadgets ( seq parent -- )
    swap [ over (add-gadget) ] each relayout ;

: add-spec ( quot spec -- )
    dup first %
    dup second [ [ dup gadget get ] % , ] when*
    dup third %
    [ gadget get ] %
    fourth ,
    % ;

: (build-spec) ( quot spec -- quot )
    [ [ add-spec ] each-with ] [ ] make ;

: build-spec ( spec quot -- )
    swap (build-spec) call ;

\ build-spec [
    2 ensure-values
    pop-literal pop-literal nip (build-spec) infer-quot-value
] "infer" set-word-prop

: (parents) ( gadget -- )
    [ dup , gadget-parent (parents) ] when* ;

: parents ( gadget -- seq )
    [ (parents) ] { } make ;

: each-parent ( gadget quot -- ? )
    >r parents r> all? ; inline

: find-parent ( gadget quot -- parent )
    >r parents r> find nip ; inline

: screen-loc ( gadget -- loc )
    parents { 0 0 } [ rect-loc v+ ] reduce ;

: child? ( parent child -- ? )
    {
        { [ 2dup eq? ] [ 2drop t ] }
        { [ dup not ] [ 2drop f ] }
        { [ t ] [ gadget-parent child? ] }
    } cond ;

GENERIC: focusable-child* ( gadget -- child/t )

M: gadget focusable-child* drop t ;

: focusable-child ( gadget -- child )
    dup focusable-child*
    dup t eq? [ drop ] [ nip focusable-child ] if ;

: make-pile ( children -- pack ) <pile> [ add-gadgets ] keep ;

: make-filled-pile ( children -- pack )
    make-pile 1 over set-pack-fill ;

: make-shelf ( children -- pack ) <shelf> [ add-gadgets ] keep ;
