! Copyright (C) 2005 Slava Pestov.
! See http://factor.sf.net/license.txt for BSD license.
IN: gadgets
USING: generic kernel lists math namespaces sdl ;

: <check> ( w h -- cross )
    2dup >r >r 0 0 r> r> <line> <gadget>
    >r tuck neg >r >r >r 0 r> r> r> <line> <gadget> r>
    2list <stack> ;

TUPLE: checkbox bevel selected? delegate ;

: init-checkbox-bevel ( bevel checkbox -- )
    2dup set-checkbox-bevel add-gadget ;

: update-checkbox ( checkbox -- )
    #! Really, there should only be one child.
    dup checkbox-bevel gadget-children [ unparent ] each
    dup checkbox-selected? [
        7 7 <check>
    ] [
        0 0 7 7 <rectangle> <gadget>
    ] ifte swap checkbox-bevel add-gadget ;

: toggle-checkbox ( checkbox -- )
    dup checkbox-selected? not over set-checkbox-selected?
    update-checkbox ;

: checkbox-update ( checkbox -- )
    dup button-pressed? >r checkbox-bevel r>
    reverse-video set-paint-property ;

: checkbox-actions ( checkbox -- )
    dup [ toggle-checkbox ] [ action ] set-action
    dup [ dup checkbox-update button-clicked ] [ button-up 1 ] set-action
    dup [ checkbox-update ] [ button-down 1 ] set-action
    dup [ checkbox-update ] [ mouse-leave ] set-action
    [ checkbox-bevel button-update ] [ mouse-enter ] set-action ;

C: checkbox ( label -- checkbox )
    <default-shelf> over set-checkbox-delegate
    [ f line-border swap init-checkbox-bevel ] keep
    [ >r <label> r> add-gadget ] keep
    dup checkbox-actions
    dup update-checkbox ;
