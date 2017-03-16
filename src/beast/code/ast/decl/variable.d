module beast.code.ast.decl.variable;

import beast.code.ast.decl.toolkit;
import beast.code.ast.identifier;
import beast.code.data.scope_.root;
import beast.code.data.var.userstatic;
import beast.code.data.var.userlocal;

final class AST_VariableDeclaration : AST_Declaration {

	public:
		static bool canParse( ) {
			assert( 0 );
		}

		/// Continues parsing after "@deco Type name" part ( "= value;", ":= value;" or ";" can follow )
		static AST_VariableDeclaration parse( CodeLocationGuard _gd, AST_DecorationList decorationList, AST_Expression dataType, AST_Identifier identifier ) {
			AST_VariableDeclaration result = new AST_VariableDeclaration;
			result.decorationList = decorationList;
			result.dataType = dataType;
			result.identifier = identifier;

			if ( currentToken.matchAndNext( Token.Operator.assign ) ) {
				result.value = AST_Expression.parse( );
			}
			else if ( currentToken.matchAndNext( Token.Operator.colonAssign ) ) {
				result.valueColonAssign = true;
				result.value = AST_Expression.parse( );
			}
			else
				currentToken.expect( Token.Special.semicolon, "default value or ';'" );

			currentToken.expectAndNext( Token.Special.semicolon );

			result.codeLocation = _gd.get( );
			return result;
		}

	public:
		override void executeDeclarations( DeclarationEnvironment env, void delegate( Symbol ) sink ) {
			const auto __gd = ErrorGuard( this );

			VariableDeclarationData declData = new VariableDeclarationData( env );
			DecorationList decorationList = new DecorationList( decorationList, env.staticMembersParent );

			// Apply possible decorators in the variableDeclarationModifier context
			decorationList.apply_variableDeclarationModifier( declData );

			if ( declData.isStatic ) {
				// No buildConstructor - that is handled in the Symbol_UserStaticVariable.memoryAllocation
				sink( new Symbol_UserStaticVariable( this, decorationList, declData ) );
			}
			else
				berror( E.notImplemented, "Not implemented" );
		}

		override void buildStatementCode( DeclarationEnvironment env, CodeBuilder cb ) {
			const auto __gd = ErrorGuard( this );
			assert( currentScope );

			VariableDeclarationData declData = new VariableDeclarationData( env );
			DecorationList decorations = new DecorationList( decorationList, env.staticMembersParent );

			// Apply possible decorators in the variableDeclarationModifier context
			decorations.apply_variableDeclarationModifier( declData );

			if ( declData.isStatic ) {
				// No buildConstructor - that is handled in the Symbol_UserStaticVariable.memoryAllocation

				if ( !env.staticMemberMerger ) {
					Symbol_UserStaticVariable var = new Symbol_UserStaticVariable( this, decorations, declData );
					currentScope.addEntity( var );
				}
				else if ( env.staticMemberMerger.isFinished( ) ) {
					currentScope.addEntity( env.staticMemberMerger.getRecord( this ) );
				}
				else {
					Symbol_UserStaticVariable var = new Symbol_UserStaticVariable( this, decorations, declData );
					currentScope.addEntity( var );

					env.staticMemberMerger.addRecord( this, var );
				}
			}
			else {
				DataEntity_UserLocalVariable var = new DataEntity_UserLocalVariable( this, decorations, declData );
				cb.build_localVariableDefinition( var );
				buildConstructor( var, cb );
				currentScope.addLocalVariable( var );
			}
		}

	public:
		AST_DecorationList decorationList;
		AST_Expression dataType;
		AST_Identifier identifier;
		AST_Expression value;
		/// True if variable was declarated using "@deco Type name := value"
		bool valueColonAssign;

	protected:
		override SubnodesRange _subnodes( ) {
			// Decoration list can be inherited from decoration block or something, in that case we should not consider it a subnodes
			return nodeRange( dataType, identifier, value, decorationList.codeLocation.isInside( codeLocation ) ? decorationList : null );
		}

	public:
		void buildConstructor( DataEntity entity, CodeBuilder cb ) {
			auto match = entity.expectResolveIdentifier( ID!"#ctor" ).CallMatchSet( this, true );

			if ( value ) {
				// colonAssign calls #ctor( #Ctor.opRefAssign, value );
				if ( valueColonAssign )
					match.arg( coreLibrary.enum_.xxctor.opRefAssign );
				else
					match.arg( coreLibrary.enum_.xxctor.opAssign );

				match.arg( value.buildSemanticTree_single( entity.dataType ) );
			}

			match.finish( ).buildCode( cb );
		}

}

final class VariableDeclarationData {

	public:
		this( DeclarationEnvironment env ) {
			this.env = env;

			isCtime = env.isCtime;
			isStatic = env.isStatic;
		}

	public:
		DeclarationEnvironment env;

	public:
		bool isCtime;
		bool isStatic;

}
