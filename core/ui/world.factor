! Copyright (C) 2005, 2006 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: gadgets
USING: arrays errors freetype generic hashtables
kernel math models namespaces opengl sequences ;

TUPLE: world
active?
gadget glass
title status
focus focused?
fonts handle
loc ;

: free-fonts ( world -- )
    dup world-handle select-gl-context
    world-fonts hash-values [ second free-sprites ] each ;

DEFER: request-focus

C: world ( gadget status status-model title-model -- world )
    [ set-world-title ] keep
    [ set-world-status ] keep
    {
        { f f f @bottom }
        { f set-world-gadget f @center }
    } make-frame*
    t over set-gadget-root?
    t over set-world-active?
    H{ } clone over set-world-fonts
    { 0 0 } over set-world-loc
    dup world-gadget request-focus ;

: find-world [ world? ] find-parent ;

: show-status ( object gadget -- )
    find-world [ world-status set-model ] [ drop ] if* ;

: hide-status ( gadget -- ) f swap show-status ;

M: world pref-dim*
    delegate pref-dim* [ >fixnum ] map { 1024 768 } vmin ;

M: world graft*
    dup dup world-title add-connection
    dup dup world-status add-connection
    model-changed ;

M: world ungraft*
    dup
    dup world-title remove-connection
    dup world-status remove-connection ;

M: world model-changed
    dup world-handle [
        dup world-title model-value over set-title
    ] when drop ;

: focused-ancestors ( world -- seq )
    world-focus parents <reversed> ;

M: world layout*
    dup delegate layout*
    dup world-glass [
        >r dup rect-dim r> set-layout-dim
    ] when* drop ;

M: world children-on nip gadget-children ;
