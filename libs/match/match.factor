! Copyright (C) 2006 Chris Double.
! See http://factorcode.org/license.txt for BSD license.
!
! Based on pattern matching code from Paul Graham's book 'On Lisp'.
IN: match
USING: kernel words sequences namespaces hashtables parser generic ;

SYMBOL: _
USE: prettyprint

: define-match-var ( name -- )
  create-in dup t "match-var" set-word-prop [ dup <wrapper> , \ get , ] [ ] make define-compound ;

: define-match-vars ( seq -- )
  [ define-match-var ] each ;

: MATCH-VARS: ! vars ...
  string-mode on [ string-mode off define-match-vars ] f ; parsing

: match-var? ( symbol -- bool )
  dup word? [
    "match-var" word-prop
  ] [
    drop f
  ] if ;

: && ( obj seq -- ? ) [ call ] all-with? ;

: (match) ( seq1 seq2 -- matched? )
  {
    { [ 2dup = ] [ 2drop t ] }
    { [ over _ = ] [ 2drop t ] } 
    { [ dup _ = ] [ 2drop t ] }
    { [ dup match-var? ] [ set t ] }
    { [ over match-var? ] [ swap set t ] }
    { [ over { [ sequence? ] [ empty? not ] } && over { [ sequence? ] [ empty? not ] } && and [ over first over first (match) ] [ f ] if ] [ >r 1 tail r> 1 tail (match) ] }
    { [ over tuple? over tuple? and ] [ >r tuple>array r> tuple>array (match) ] }
    { [ t ] [ 2drop f ] }
  } cond ;

: match ( seq1 seq2 -- bindings )
  [ (match) ] make-hash swap [ drop f ] unless ;

SYMBOL: result

: match-cond ( seq assoc -- )
  [
    [ first over match dup result set ] find 2nip dup [ result get [ second call ] bind ] [ no-cond ] if 
  ] with-scope ;

: replace-patterns ( object -- result )
  {
    { [ dup match-var? ] [ get ] }
    { [ dup sequence? ] [ [ [ replace-patterns , ] each ] over make ] }
    { [ dup tuple? ] [ tuple>array replace-patterns >tuple ] }
    { [ t ] [ ] }    
  } cond ;

: match-replace ( object pattern1 pattern2 -- result )
  -rot match [ replace-patterns ] bind ;