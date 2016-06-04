! Copyright (C) 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: kernel help.markup help.syntax ;
in: prettyprint.custom

HELP: pprint*
{ $values { "obj" object } }
{ $contract "Adds sections to the current block corresponding to the prettyprinted representation of the object." }
$prettyprinting-note ;