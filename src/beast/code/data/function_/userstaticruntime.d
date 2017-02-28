module beast.code.data.function_.userstaticruntime;

import beast.code.data.toolkit;
import beast.code.data.function_.runtime;
import beast.code.data.scope_.root;

final class Symbol_UserStaticRuntimeFunction : Symbol_RuntimeFunction {
	mixin TaskGuard!"returnTypeDeduction";

public:
	this( AST_FunctionDeclaration ast, DecorationList decorationList, FunctionDeclarationData data ) {
		ast_ = ast;
		decorationList_ = decorationList;
		staticData_ = new Data;
		parent_ = data.env.staticMembersParent;
	}

	override Identifier identifier( ) {
		return ast_.identifier;
	}

	override Symbol_Type returnType( ) {
		enforceDone_returnTypeDeduction( );
		return returnType_;
	}

	override AST_Node ast( ) {
		return ast_;
	}

	final override DeclType declarationType( ) {
		return DeclType.staticFunction;
	}

public:
	final override DataEntity dataEntity( DataEntity parentInstance = null ) {
		return staticData_;
	}

	final override void buildDefinitionsCode( CodeBuilder cb ) {
		cb.build_functionDefinition( this, ( cb ) { //
			scope scope_ = new RootDataScope( staticData_ );

			scope env = DeclarationEnvironment.newFunctionBody;
			env.scope_ = scope_;
			env.staticMembersParent = dataEntity;
			
			ast_.body_.buildStatementCode( env, cb, scope_ );
		} );
	}

private:
	AST_FunctionDeclaration ast_;
	DecorationList decorationList_;
	Data staticData_;
	DataEntity parent_;
	Symbol_Type returnType_;

protected:
	final void execute_returnTypeDeduction( ) {
		benforce( !ast_.returnType.isAuto, E.notImplemented, "Auto return type is not implemented yet" );
		returnType_ = ast_.returnType.standaloneCtExec( coreLibrary.types.Type, parent_ ).readType( );
	}

private:
	final class Data : SymbolRelatedDataEntity {

	public:
		this( ) {
			super( this.outer );
		}

	public:
		override Symbol_Type dataType( ) {
			return null;
		}

		override bool isCtime( ) {
			return true;
		}

		override DataEntity parent( ) {
			return this.outer.parent_;
		}

	}

}
