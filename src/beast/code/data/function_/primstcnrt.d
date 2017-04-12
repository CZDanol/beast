module beast.code.data.function_.primstcnrt;

import beast.code.data.function_.toolkit;
import beast.code.data.function_.nonrt;
import beast.code.data.function_.nrtparambuilder;

final class Symbol_PrimitiveStaticNonRuntimeFunction : Symbol_NonRuntimeFunction {

	public:
		static auto paramsBuilder( ) {
			return Builer_Base!( false, Data )( );
		}

	public:
		this( Identifier id, DataEntity parent, CallMatchFactory!( false, Data ) matchFactory ) {
			parent_ = parent;
			id_ = id;
			matchFactory_ = matchFactory;

			staticData_ = new Data( this, null, MatchLevel.fullMatch );
		}

	public:
		override DeclType declarationType( ) {
			return DeclType.memberFunction;
		}

		override Identifier identifier( ) {
			return id_;
		}

	public:
		override DataEntity dataEntity( MatchLevel matchLevel = MatchLevel.fullMatch, DataEntity parentInstance = null ) {
			if ( parentInstance || matchLevel != MatchLevel.fullMatch )
				return new Data( this, parentInstance, matchLevel );
			else
				return staticData_;
		}

	private:
		DataEntity parent_;
		Identifier id_;
		CallMatchFactory!( false, Data ) matchFactory_;
		Data staticData_;

	protected:
		final static class Data : super.Data {

			public:
				this( Symbol_PrimitiveStaticNonRuntimeFunction sym, DataEntity parentInstance, MatchLevel matchLevel ) {
					super( sym, matchLevel );
					sym_ = sym;
					parentInstance_ = parentInstance;
				}

			public:
				override string identification( ) {
					return "%s( %s )".format( sym_.identifier.str, sym_.matchFactory_.argumentsIdentificationStrings.joiner( ", " ) );
				}

				override string identificationString_noPrefix( ) {
					return "%s.%s".format( sym_.parent_.identificationString, identification );
				}

				override Symbol_Type dataType( ) {
					// TODO: better
					return coreType.Void;
				}

				final override DataEntity parent( ) {
					return sym_.parent_;
				}

				final override bool isCtime( ) {
					return true;
				}

				final override bool isCallable( ) {
					return true;
				}

			public:
				DataEntity parentInstance( ) {
					return parentInstance_;
				}

			public:
				override CallableMatch startCallMatch( AST_Node ast, bool canThrowErrors, MatchLevel matchLevel ) {
					return sym_.matchFactory_.startCallMatch( this, ast, canThrowErrors, matchLevel | this.matchLevel );
				}

			protected:
				Symbol_PrimitiveStaticNonRuntimeFunction sym_;
				DataEntity parentInstance_;

		}

}
