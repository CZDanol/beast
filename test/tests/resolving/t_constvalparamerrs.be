module t_constvalparamerrs;

Void test( 4 ) {
	print( 14 );
}

Void test( 5 ) {
	print( 15 );
}

Void test2( 5 ) {
	print( 15 );
}

Void err1() {
	test( 6 ); //! error: noMatchingOverload
}

Void err2() {
	Int x = 15;
	Int y = 16;
	test2( x + y ); //! error: noMatchingOverload
}

Void main() {

}