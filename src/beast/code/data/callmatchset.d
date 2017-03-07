module beast.code.data.callmatchset;

import beast.code.data.toolkit;
import beast.code.data.callable;
import beast.code.data.scope_.local;
import beast.code.ast.expr.expression;

/// Structure that handles overload matching
struct CallMatchSet {

	public:
		this( Overloadset overloadset, DataScope parentScope, AST_Node ast, bool reportErrors = true ) {
			scope_ = new LocalDataScope( parentScope );
			this.reportErrors = reportErrors;

			foreach ( overload; overloadset ) {
				if ( overload.isCallable )
					matches ~= overload.startCallMatch( scope_, ast );

				// If the overload is not callable, we try to overload against overload.#operator( Operator.call, XXX )
				else {
					foreach ( suboverload; overload.resolveIdentifier( Identifier.preobtained!"#operator", scope_ ) ) {
						if ( overload.isCallable )
							matches ~= suboverload.startCallMatch( scope_, ast ).matchNextArgument( coreLibrary.constants.operator_call.dataEntity );
					}
				}
			}

			benforce( !reportErrors || matches.length != 0, E.noMatchingOverload, "No callable overloads in overloadset %s".format( overloadset.identificationString ) );
		}

	public:
		ref CallMatchSet argument( DataEntity entity ) {
			Symbol_Type dataType = entity.dataType;
			argumentTypes ~= dataType;

			foreach ( match; matches ) {
				with ( memoryManager.session )
					match.matchNextArgument( null, entity, dataType );
			}

			return this;
		}

		ref CallMatchSet argument( AST_Expression expr ) {
			const bool reportErrors = reportErrors && matches.length == 1;

			DataEntity entity = expr.buildSemanticTree_single( null, scope_, reportErrors );
			Symbol_Type dataType = entity ? entity.dataType : null;
			argumentTypes ~= dataType;

			foreach ( match; matches ) {
				with ( memoryManager.session )
					match.matchNextArgument( expr, entity, dataType );
			}

			return this;
		}

	public:
		ref CallMatchSet arguments( AST_Expression[ ] expressions ) {
			foreach ( expr; expressions )
				argument( expr );

			return this;
		}

	public:
		/// Can return null when reportErrors is false
		DataEntity finish( ) {
			if ( matches.length == 0 )
				return null;

			scope_.finish( );

			// Now find best match
			CallableMatch bestMatch = matches[ 0 ];
			size_t bestMatchCount = 1;

			matches[ 0 ].finish( );

			foreach ( match; matches[ 1 .. $ ] ) {
				match.finish( );

				if ( match.matchLevel > bestMatch.matchLevel ) {
					bestMatch = match;
					bestMatchCount = 1;
				}
				else if ( match.matchLevel == bestMatch.matchLevel )
					bestMatchCount++;
			}

			if ( bestMatch.matchLevel == CallableMatch.MatchFlags.noMatch ) {
				// TODO: error messages when matchLevel is noMatch
				benforce( !reportErrors, E.noMatchingOverload, //
						"None of the overloads matches arguments %s: %s".format(  //
							argumentListIdentificationString, //
							matches.map!( x => "\n\t%s:\n\t\t%s".format( x.sourceDataEntity.identificationString, x.errorStr ) ).joiner( ", " ) ) //
						 );

				return null;
			}

			if ( bestMatchCount != 1 ) {
				benforce( !reportErrors, E.ambiguousResolution, //
						"Ambiguous overload resolution: %s for %s".format(  //
							matches.filter!( x => x.matchLevel == bestMatch.matchLevel ).map!( x => x.sourceDataEntity ).array.Overloadset.identificationString, //
							argumentListIdentificationString //
							 ) );

				return null;
			}

			return bestMatch.toDataEntity;
		}

	public:
		/// List of types of arguments, null item means item needs inferring
		Symbol_Type[ ] argumentTypes;

		CallableMatch[ ] matches;

		DataScope scope_;

		bool reportErrors;

	public:
		string argumentListIdentificationString( ) {
			return "( %s )".format( argumentTypes.map!( x => x is null ? "(infer)" : x.identificationString ).joiner( ", " ).to!string );
		}

}
