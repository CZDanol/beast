module beast.code.ast.expr.decorated;

import beast.code.ast.toolkit;
import beast.code.decorationlist;
import beast.code.data.util.ctexec;

final class AST_DecoratedExpression : AST_Expression {

	public:
		alias ValueTransformer = Overloadset delegate( Overloadset );

	public:
		this( AST_DecorationList decorationList, AST_Expression baseExpression ) {
			this.decorationList = decorationList;
			this.baseExpression = baseExpression;
		}

	public:
		override bool isPrefixExpression( ) {
			return baseExpression.isPrefixExpression;
		}

	public:
		override Overloadset buildSemanticTree( Symbol_Type inferredType, bool errorOnInferrationFailure = true ) {

			auto decoData = new ExpressionDecorationData;
			auto decoList = new DecorationList( decorationList );

			decoList.apply_expressionDecorator( decoData );
			decoList.enforceAllResolved( );

			auto result = baseExpression.buildSemanticTree( inferredType, errorOnInferrationFailure );

			if ( decoData.isCtime )
				result = result.map!( x => cast( DataEntity ) new DataEntity_CtExecProxy( x ) ).Overloadset;

			return result;
		}

	public:
		AST_DecorationList decorationList;
		AST_Expression baseExpression;

}

final class ExpressionDecorationData {

	public:
		bool isCtime;

}
