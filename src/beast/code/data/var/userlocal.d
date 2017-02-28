module beast.code.data.var.userlocal;

import beast.code.data.toolkit;
import beast.code.data.scope_.local;

final class DataEntity_UserLocalVariable : DataEntity_LocalVariable {

public:
	this( AST_VariableDeclaration ast, DecorationList decorationList, VariableDeclarationData data ) {
		Symbol_Type dataType;

		// Deduce data type
		{
			DataScope localScope_ = new LocalDataScope( data.env.scope_ );
			dataType = ast.type.buildSemanticTree( coreLibrary.types.Type, localScope_ ).ctExec_asType( localScope_ );
		}

		super( dataType, data.env.scope_ );
	}

public:
	final override AST_Node ast( ) {
		return ast_;
	}

private:
	AST_Node ast_;

}
