module beast.code.data.function_.nrtparambuilder;

import beast.code.data.function_.toolkit;
import std.typetuple : TypeTuple;
import std.traits : RepresentationTypeTuple;
import std.meta : aliasSeqOf;
import std.range : iota;

abstract class CallMatchFactory( bool isMemberFunction_, SourceEntity_ ) {

	public:
		enum isMemberFunction = isMemberFunction_;
		alias SourceEntity = SourceEntity_;

	public:
		abstract CallableMatch startCallMatch( SourceEntity sourceEntity, AST_Node ast, bool isOnlyOverloadOption );

		abstract string[ ] argumentsIdentificationStrings( );

}

final class CallMatchFactoryImpl( bool isMemberFunction, SourceEntity, Builder_ ) : CallMatchFactory!( isMemberFunction, SourceEntity ) {

	public:
		alias Builder = Builder_;

	public:
		this( Builder builder, Builder.ObtainFunc obtainFunc ) {
			builder_ = builder;
			obtainFunc_ = obtainFunc;
		}

	public:
		override CallableMatch startCallMatch( SourceEntity sourceEntity, AST_Node ast, bool isOnlyOverloadOption ) {
			return new Match!( typeof( this ) )( this, sourceEntity, ast, isOnlyOverloadOption );
		}

		override string[ ] argumentsIdentificationStrings( ) {
			string[ ] data;
			foreach ( i; aliasSeqOf!( iota( 1, Builder.BuilderCount ) ) )
				data ~= builder_.builder!i.identificationString;

			return data;
		}

	private:
		Builder builder_;
		Builder.ObtainFunc obtainFunc_;

}

final static class Match( Factory ) : SeriousCallableMatch {

	public:
		alias Builder = Factory.Builder;
		alias SourceEntity = Factory.SourceEntity;
		enum isMemberFunction = Factory.isMemberFunction;

	public:
		this( Factory factory, SourceEntity sourceEntity, AST_Node ast, bool isOnlyOverloadOption ) {
			super( sourceEntity, ast, isOnlyOverloadOption, factory.builder_.builder!( 0 ).initialMatchFlags_ );

			factory_ = factory;

			static if ( isMemberFunction )
				parentInstance_ = sourceEntity.parentInstance;
		}

	protected:
		override MatchFlags _matchNextArgument( AST_Expression expression, DataEntity entity, Symbol_Type dataType ) {
			foreach ( i; aliasSeqOf!( iota( 1, Factory.Builder.BuilderCount ) ) ) {
				if ( currentFactoryItem_ == i ) {
					bool nextFactoryItem = true;

					MatchFlags result = factory_.builder_.builder!i.matchArgument( this, expression, entity, dataType, params_[ Builder.Builder!i.ParamsOffset .. Builder.Builder!i.ParamsOffset + Builder.Builder!i.Params.length ], nextFactoryItem );

					if ( nextFactoryItem )
						currentFactoryItem_++;

					return result;
				}
			}

			// If currentFactoryItem_ is outside builder bounds, that means that there are more arguments that parameters
			errorStr = "too many arguments";
			return MatchFlags.noMatch;
		}

		override MatchFlags _finish( ) {
			// Either we must have processed all factory items or the last one must be satisfied (this happens when the parameter is variadic)
			if ( currentFactoryItem_ != Factory.Builder.BuilderCount && !factory_.builder_.isSatisfied( params_[ Builder.ParamsOffset .. $ ] ) ) {
				errorStr = "not enough arguments";
				return MatchFlags.noMatch;
			}

			return MatchFlags.fullMatch;
		}

		override DataEntity _toDataEntity( ) {
			static if ( isMemberFunction )
				return factory_.obtainFunc_( ast, parentInstance_, params_ );
			else
				return factory_.obtainFunc_( ast, params_ );
		}

	private:
		size_t currentFactoryItem_ = 1; // Starting from 1 - first is Builer_Base which does nothing
		Factory factory_;
		Builder.ParamsTuple params_;
		static if ( isMemberFunction )
			DataEntity parentInstance_;

}

mixin template BuilderCommon( ) {
	static if ( is( Parent == void ) ) {
		alias ParamsTuple = Params;
		enum BuilderCount = 1;
		enum ParamsOffset = 0;
	}
	else {
		Parent parent;
		alias ParamsTuple = TypeTuple!( Parent.ParamsTuple, Params );
		enum isMemberFunction = Parent.isMemberFunction;
		alias SourceEntity = Parent.SourceEntity;
		enum BuilderCount = Parent.BuilderCount + 1;
		enum ParamsOffset = Parent.ParamsOffset + Parent.Params.length;
	}

	static if ( isMemberFunction )
		alias ObtainFunc = DataEntity delegate( AST_Node, DataEntity, ParamsTuple );
	else
		alias ObtainFunc = DataEntity delegate( AST_Node, ParamsTuple );

	/// Match single runtime parameter of type type (adds DataEntity parameter to obtainFunc)
	auto rtArg( )( Symbol_Type type ) {
		return Builder_RuntimeParameter!( typeof( this ) )( this, type );
	}

	/// Match single ctime parameter of type type (adds MemoryPtr parameter to obtainFunc)
	auto ctArg( )( Symbol_Type type ) {
		return Builder_CtimeParameter!( typeof( this ) )( this, type );
	}

	/// Match single const-value parameter of type type and value value (doesn't add any parameters to obtainFunc)
	auto constArg( )( Symbol_Type type, MemoryPtr value ) {
		return Builder_ConstParameter!( typeof( this ) )( this, type, value );
	}

	/// Match single const-value parameter of value data (doesn't add any parameters to obtainFunc)
	auto constArg( )( DataEntity data ) {
		return Builder_ConstParameter!( typeof( this ) )( this, data.dataType, data.ctExec );
	}

	/// Match single const-value parameter of value data (doesn't add any parameters to obtainFunc)
	auto constArg( )( Symbol sym ) {
		auto data = sym.dataEntity;
		return Builder_ConstParameter!( typeof( this ) )( this, data.dataType, data.ctExec );
	}

	/// Matches anything (adds Expression[] and DataEntity[] parameter to obtainFunc - Expression[] for unparsed parameters, DataEntity[] for parsed ones)
	auto matchesAnything( )( ) {
		return Builder_Anything!( typeof( this ) )( this );
	}

	CallMatchFactory!( isMemberFunction, SourceEntity ) finish( )( ObtainFunc obtainFunc ) {
		return new CallMatchFactoryImpl!( isMemberFunction, SourceEntity, typeof( this ) )( this, obtainFunc );
	}

	template Builder( size_t id ) {
		static if ( id == BuilderCount - 1 )
			alias Builder = typeof( this );
		else
			alias Builder = Parent.Builder!id;
	}

	auto ref builder( size_t id )( ) {
		static if ( id == BuilderCount - 1 )
			return this;
		else
			return parent.builder!id;
	}

	bool isSatisfied( ref Params params ) {
		return false;
	}

}

struct Builer_Base( bool isMemberFunction_, SourceEntity_ ) {
	alias Parent = void;
	enum isMemberFunction = isMemberFunction_;
	alias SourceEntity = SourceEntity_;
	mixin BuilderCommon;
	alias Params = TypeTuple!( );

	auto ref markAsFallback( ) {
		initialMatchFlags_ &= CallableMatch.MatchFlags.fallback;
		return this;
	}

	private:
		CallableMatch.MatchFlags initialMatchFlags_ = CallableMatch.MatchFlags.fullMatch;
}

struct Builder_RuntimeParameter( Parent ) {
	mixin BuilderCommon;

	alias Params = TypeTuple!( DataEntity );

	CallableMatch.MatchFlags matchArgument( SeriousCallableMatch match, AST_Expression expression, DataEntity entity, Symbol_Type dataType, ref Params params, ref bool nextFactoryItem ) {
		auto result = match.matchStandardArgument( expression, entity, dataType, type_ );
		if ( result == CallableMatch.MatchFlags.noMatch )
			return CallableMatch.MatchFlags.noMatch;

		params[ 0 ] = entity;
		return result;
	}

	string identificationString( ) {
		return type_.tryGetIdentificationString;
	}

	private:
		Symbol_Type type_;

}

struct Builder_CtimeParameter( Parent ) {
	mixin BuilderCommon;

	alias Params = TypeTuple!( MemoryPtr );

	CallableMatch.MatchFlags matchArgument( SeriousCallableMatch match, AST_Expression expression, DataEntity entity, Symbol_Type dataType, ref Params params, ref bool nextFactoryItem ) {
		MemoryPtr value;

		auto result = match.matchCtimeArgument( expression, entity, dataType, type_, value );
		if ( result == CallableMatch.MatchFlags.noMatch )
			return CallableMatch.MatchFlags.noMatch;

		params[ 0 ] = value;
		return result;
	}

	string identificationString( ) {
		return "@ctime %s".format( type_.tryGetIdentificationString );
	}

	private:
		Symbol_Type type_;

}

struct Builder_ConstParameter( Parent ) {
	mixin BuilderCommon;

	alias Params = TypeTuple!( );

	CallableMatch.MatchFlags matchArgument( SeriousCallableMatch match, AST_Expression expression, DataEntity entity, Symbol_Type dataType, ref Params params, ref bool nextFactoryItem ) {
		auto result = match.matchConstValue( expression, entity, dataType, type_, value_ );
		if ( result == CallableMatch.MatchFlags.noMatch )
			return CallableMatch.MatchFlags.noMatch;

		return result;
	}

	string identificationString( ) {
		return "@ctime %s = %s".format( type_.tryGetIdentificationString, type_.valueIdentificationString( value_ ) );
	}

	private:
		Symbol_Type type_;
		MemoryPtr value_;

}

struct Builder_Anything( Parent ) {
	mixin BuilderCommon;

	alias Params = TypeTuple!( AST_Expression[ ], DataEntity[ ] );

	CallableMatch.MatchFlags matchArgument( SeriousCallableMatch match, AST_Expression expression, DataEntity entity, Symbol_Type dataType, ref Params params, ref bool nextFactoryItem ) {
		params[ 0 ] ~= expression;
		params[ 1 ] ~= entity;

		nextFactoryItem = false;
		return CallableMatch.MatchFlags.fullMatch;
	}

	string identificationString( ) {
		return "...";
	}

	bool isSatisfied( ref Params params ) {
		return true;
	}

}
