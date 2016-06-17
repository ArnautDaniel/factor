USING: tools.test classes.mixin compiler.units arrays kernel.private
strings sequences vocabs definitions kernel ;
in: compiler.tests.redefine17

COMPILE< "compiler.tests.redefine17" vocab-words forget-all COMPILE>

GENERIC: bong ( a -- b ) ;

M: array bong ;

M: string bong length ;

mixin: mixin

INSTANCE: array mixin ;

: blah ( a -- b ) { mixin } declare bong ;

[ { } ] [ { } blah ] unit-test

[ ] [ [ \ array \ mixin remove-mixin-instance ] with-compilation-unit ] unit-test

[ ] [ [ \ string \ mixin add-mixin-instance ] with-compilation-unit ] unit-test

[ 0 ] [ "" blah ] unit-test

mixin: mixin1

INSTANCE: string mixin1 ;

mixin: mixin2

GENERIC: billy ( a -- b ) ;

M: mixin2 billy ;

M: array billy drop "BILLY" ;

INSTANCE: string mixin2 ;

: bully ( a -- b ) { mixin1 } declare billy ;

[ "" ] [ "" bully ] unit-test

[ ] [ [ \ string \ mixin1 remove-mixin-instance ] with-compilation-unit ] unit-test

[ ] [ [ \ array \ mixin1 add-mixin-instance ] with-compilation-unit ] unit-test

[ "BILLY" ] [ { } bully ] unit-test
