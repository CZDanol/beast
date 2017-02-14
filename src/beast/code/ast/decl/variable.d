module beast.code.ast.decl.variable;

import beast.code.ast.toolkit;
import beast.code.ast.decl.toolkit;
import beast.code.decorationlist;
import beast.code.sym.var.userstatic;

final class AST_VariableDeclaration : AST_Declaration {

public:
	static bool canParse( ) {
		assert( 0 );
	}

	/// Continues parsing after "@deco Type name" part ( "= value;", ":= value;" or ";" can follow )
	static AST_Declaration parse( CodeLocationGuard _gd, AST_DecorationList decorationList, AST_TypeOrAutoExpression type, AST_Identifier identifier ) {
		AST_VariableDeclaration result = new AST_VariableDeclaration;
		result.decorationList = decorationList;
		result.type = type;
		result.identifier = identifier;

		if ( currentToken == Token.Operator.assign ) {
			getNextToken( );
			result.value = AST_Expression.parse( );
		}
		else if ( currentToken == Token.Operator.colonAssign ) {
			getNextToken( );
			result.valueColonAssign = true;
			result.value = AST_Expression.parse( );
		}
		else
			currentToken.expect( Token.Special.semicolon, "default value or ';'" );

		result.codeLocation = _gd.get( );
		return result;
	}

public:
	override void executeDeclarations( DeclarationEnvironment env, void delegate( Symbol ) sink ) {
		VariableDeclarationData declData = new VariableDeclarationData( env );
		DecorationList decorationList = new DecorationList( decorationList );

		// Apply possible decorators in the variableDeclarationModifier context
		decorationList.apply_variableDeclarationModifier( declData );

		if ( declData.isStatic && !declData.isCtime )
			sink( new Symbol_UserStaticVariable( this, decorationList, env ) );
		else
			berror( E.unimplemented, "Not implemented" );
	}

public:
	AST_DecorationList decorationList;
	AST_TypeOrAutoExpression type;
	AST_Identifier identifier;
	AST_Expression value;
	/// True if variable was declarated using "@deco Type name := value"
	bool valueColonAssign;

protected:
	override InputRange!AST_Node _subnodes( ) {
		// Decoration list can be inherited from decoration block or something, in that case we should not consider it a subnodes
		return nodeRange( type, identifier, value, decorationList.codeLocation.isInside( codeLocation ) ? decorationList : null );
	}

}

final class VariableDeclarationData {

public:
	this( DeclarationEnvironment e ) {
		isCtime = e.isCtime;
		isStatic = e.isStatic;
	}

public:
	bool isCtime;
	bool isStatic;

}
