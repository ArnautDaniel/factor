! Copyright (C) 2005 Alex Chapman
! Copyright (C) 2006, 2007 Slava Pestov
! See http://factorcode.org/license.txt for BSD license.
IN: embedded
USING: sequences kernel parser namespaces io html errors ;

! See apps/http-server/test/ or libs/furnace/ for embedded usage
! examples!

: process-html ( parse-tree string -- parse-tree )
    dup empty? [ drop ] [ parsed \ write-html parsed ] if ;

: process-embedded ( parse-tree string -- string parse-tree )
    "<%" split1-slice >r process-html r> "%>" split1-slice 
    >r string-lines [ (parse) ] each r> ;

: (parse-embedded) ( parse-tree string -- parse-tree )
    dup empty?
    [ drop ] [ process-embedded (parse-embedded) ] if ;

: parse-embedded ( string -- quot )
    [ f swap (parse-embedded) >quotation ] with-parser ;

: eval-embedded ( string -- ) parse-embedded call ;

: run-embedded-file ( filename -- )
    [
        [
            file-vocabs
            dup file set ! so that reload works properly
            [ <file-reader> contents eval-embedded ] keep
        ] with-scope
    ] assert-depth drop ;

: embedded-convert ( infile outfile -- )
    <file-writer> [ run-embedded-file ] with-stream ;
