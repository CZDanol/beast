module beast.code.ast.expr.new_;

import beast.code.ast.toolkit;
import beast.code.ast.expr.prefix;
import beast.code.ast.expr.binary;
import beast.code.ast.expr.parentcomma;
import beast.code.data.util.reinterpret;
import beast.code.data.util.btsp;
import beast.code.data.var.tmplocal;
import beast.code.data.matchlevel;
import beast.code.data.util.deref;

final class AST_NewExpression : AST_Expression {
	alias LowerLevelExpression = AST_PrefixExpression;

	public:
		static bool canParse( ) {
			return LowerLevelExpression.canParse || currentToken == Token.Keyword.new_;
		}

		static AST_Expression parse( ) {
			auto _gd = codeLocationGuard( );

			if ( currentToken.matchAndNext( Token.Keyword.new_ ) ) {
				auto result = new AST_NewExpression;

				auto data = LowerLevelExpression.parse( ).asNewRightExpression( );
				result.type = data[ 0 ];
				result.args = data[ 1 ];
				result.codeLocation = _gd.get( );

				return result;
			}

			return LowerLevelExpression.parse( );
		}

	public:
		AST_Expression type;
		AST_ParentCommaExpression args;

	public:
		override Overloadset buildSemanticTree( Symbol_Type inferredType, bool errorOnInferrationFailure = true ) {
			const auto __gd = ErrorGuard( codeLocation );

			Symbol_Type ttype;

			if ( auto autoExpr = type.isAutoExpression ) {
				benforce( inferredType !is null, E.cannotInfer, "Cannot infer type in new auto expression" );

				auto refInferredType = inferredType.isReferenceType;
				benforce( refInferredType !is null, E.referenceTypeRequired, "Inferred type %s is not a reference type".format( inferredType.identificationString ) );

				ttype = refInferredType.baseType;
			}
			else {
				auto ctexec = type.ctExec( coreType.Type );
				ttype = ctexec.value.readType( );
				ctexec.destroy( );
			}

			auto refType = coreType.Reference.referenceTypeOf( ttype );

			return new DataEntity_Bootstrap( null, refType, ttype.dataEntity, false, ( cb ) { //
				// Create a temporary variable
				auto var = new DataEntity_TmpLocalVariable( refType, cb.isCtime );
				cb.build_localVariableDefinition( var );

				// Call malloc, store result into the variable
				DataEntity mallocCall = coreFunc.malloc.dataEntity.resolveCall( this, true, ttype.instanceSizeLiteral );
				coreType.Pointer.copyCtor.dataEntity( MatchLevel.fullMatch, new DataEntity_ReinterpretCast( var, coreType.Pointer ) ).resolveCall( this, true, mallocCall ).buildCode( cb );

				// Call constructor for the referenced value
				new DataEntity_DereferenceProxy( var, ttype ).expectResolveIdentifier( ID!"#ctor" ).resolveCall( args, true, args.items ).buildCode( cb );

				// Return the variable as a result
				var.buildCode( cb );
			} ).Overloadset;
		}

	protected:
		override SubnodesRange _subnodes( ) {
			return nodeRange( type, args );
		}

}
