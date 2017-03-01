module beast.code.ast.decl.module_;

import beast.code.ast.decl.toolkit;
import beast.code.ast.decl.declarationscope;

final class AST_Module : AST_Node {

public:
	static AST_Module parse( ) {
		auto clg = codeLocationGuard( );
		auto result = new AST_Module;

		// module a.b.c;
		{
			currentToken.expectAndNext( Token.Keyword.module_ );

			result.identifier = ExtendedIdentifier.parse( );

			currentToken.expectAndNext( Token.Special.semicolon );
		}

		result.declarationScope = AST_DeclarationScope.parse( );

		currentToken.expect( Token.Special.eof, "declaration or EOF" );

		result.codeLocation = clg.get( );
		return result;
	}

public:
	ExtendedIdentifier identifier;
	AST_DeclarationScope declarationScope;

protected:
	override InputRange!AST_Node _subnodes( ) {
		return nodeRange( declarationScope );
	}

}
