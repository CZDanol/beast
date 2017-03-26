module beast.code.data.decorator.decorator;

import beast.code.data.toolkit;
import beast.code.ast.decl.variable;
import beast.code.ast.decl.function_;

/// Base class for all decorator types
abstract class Symbol_Decorator : Symbol {

	public:
		this( DataEntity parent ) {
			parent_ = parent;
			staticData_ = new Data( this, MatchLevel.fullMatch );
		}

	public:
		final override DeclType declarationType( ) {
			return DeclType.decorator;
		}

	public:
		final override DataEntity dataEntity( MatchLevel matchLevel = MatchLevel.fullMatch, DataEntity parentInstance = null ) {
			if ( matchLevel == MatchLevel.fullMatch )
				return staticData_;
			else
				return new Data( this, matchLevel );
		}

	public:
		/// Tries to apply in the variableDeclarationModifier context. Returns true if successful
		bool apply_variableDeclarationModifier( VariableDeclarationData data ) {
			return false;
		}

		/// Tries to apply in the functionDeclarationModifier context. Returns true if successful
		bool apply_functionDeclarationModifier( FunctionDeclarationData data ) {
			return false;
		}

		/// Attempts to apply the decorator in the typeDecorator context. Returns true if successfull.
		/// Type decorator takes one type and returns another
		bool apply_typeWrapper( ref Symbol_Type type ) {
			return false;
		}

	private:
		DataEntity parent_;
		DataEntity staticData_;

	private:
		final static class Data : SymbolRelatedDataEntity {

			public:
				this( Symbol_Decorator sym, MatchLevel matchLevel ) {
					super( sym, matchLevel );
					sym_ = sym;
				}

			public:
				override Symbol_Type dataType( ) {
					// TODO: decorator reflection
					return coreLibrary.type.Void;
				}

				override bool isCtime( ) {
					return true;
				}

				override DataEntity parent( ) {
					return sym_.parent_;
				}

				override Symbol_Decorator isDecorator( ) {
					return sym_;
				}

			private:
				Symbol_Decorator sym_;

		}

}

enum DecorationContext {
	_noContext,

	// AST level contexts: (are applied before symbol creation)
	variableDeclarationModifier, /// For example @static

	// Symbol level contexts: (are applied on symbols)
}
