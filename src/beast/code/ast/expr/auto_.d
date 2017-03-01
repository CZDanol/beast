module beast.code.ast.expr.auto_;

import beast.code.ast.toolkit;

final class AST_AutoExpression : AST_Expression {

public:
	static bool canParse( ) {
		return currentToken == Token.Keyword.auto_;
	}

	static AST_AutoExpression parse( ) {
		auto _gd = codeLocationGuard( );
		AST_TypeOrAutoExpression result = new AST_AutoExpression;

		currentToken.expect( Token.Keyword.auto_ );

		// TODO: auto mut etc.

		result.codeLocation = _gd.get( );
		return result;
	}

public:
	this( ) {

	}

public:
	override AST_AutoExpression isAutoExpression( ) {
		return this;
	}

public:
	override DataEntity buildSemanticTree( Symbol_Type expectedType, DataScope scope_, bool errorOnFailure = true ) {
		berror( E.syntaxError, "'auto' is not allowed here" );
		assert( 0 );
	}

public:
	bool isMut;
	bool isRef;

}
