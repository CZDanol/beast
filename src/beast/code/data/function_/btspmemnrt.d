module beast.code.data.function_.bstpmemnrt;

import beast.code.data.function_.toolkit;
import beast.code.data.function_.nonrt;
import beast.code.data.function_.nrtparambuilder;

final class Symbol_BootstrapMemberNonRuntimeFunction : Symbol_NonRuntimeFunction {

	public:
		static auto paramsBuilder( ) {
			return Builer_Base!( true, Data )( );
		}

	public:
		this( DataEntity parent, Identifier id, CallMatchFactory!( true, Data ) matchFactory ) {
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
		CallMatchFactory!( true, Data ) matchFactory_;
		Data staticData_;

	protected:
		final static class Data : super.Data {

			public:
				this( Symbol_BootstrapMemberNonRuntimeFunction sym, DataEntity parentInstance, MatchLevel matchLevel ) {
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
					return coreLibrary.type.Void;
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
					if ( parentInstance_ )
						return sym_.matchFactory_.startCallMatch( this, ast, canThrowErrors, matchLevel | this.matchLevel );
					else {
						benforce( !canThrowErrors, E.needThis, "Need this for %s".format( this.tryGetIdentificationString ) );
						return new InvalidCallableMatch( this, "need this" );
					}
				}

			protected:
				Symbol_BootstrapMemberNonRuntimeFunction sym_;
				DataEntity parentInstance_;

		}

}
