! Copyright (C) 2005, 2006 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: kernel furnace furnace.validator http.server.responders
       help help.topics html splitting sequences words strings 
       quotations ;
IN: webapps.help 

: show-help ( topic -- )
    serving-html
    dup article-title [
        [ help ] with-html-stream
    ] html-document ;

: string>topic ( string -- topic )
    " " split dup length 1 = [ first ] when ;

\ show-help {
    { "topic" "handbook" v-default string>topic }
} define-action

M: link browser-link-href
    link-name [ \ f ] unless* dup word? [
        browser-link-href
    ] [
        dup [ string? ] all? [ " " join ] when
        [ show-help ] curry quot-link
    ] if ;

"help" "show-help" "extra/webapps/help" web-app
