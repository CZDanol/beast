/// RunTime
module beast.code.data.function_.rt;

import beast.code.data.function_.toolkit;

/// Runtime function = function without @ctime arguments (or expanded ones)
abstract class Symbol_RuntimeFunction : Symbol_Function {

	public:
		abstract Symbol_Type returnType( );

		abstract ExpandedFunctionParameter[ ] parameters( );

	protected:
		override void execute_outerHashObtaining( ) {
			super.execute_outerHashObtaining( );

			foreach ( param; parameters )
				outerHash_ += param.dataType.outerHash;
		}

		final string baseIdentifier( ) {
			return identifier ? identifier.str : "(anonymous function)";
		}

	protected:
		abstract class Data : SymbolRelatedDataEntity {

			public:
				this( ) {
					super( this.outer );
				}

			public:
				override Symbol_Type dataType( ) {
					// TODO: Function types
					return coreLibrary.types.Void;
				}

				override bool isCtime( ) {
					// TODO: This might not true for member functions
					return true;
				}

				final override bool isCallable( ) {
					return true;
				}

				override string identification( ) {
					import std.array : appender;
					
					auto result = appender!string;
					result ~= baseIdentifier;
					result ~= "(";

					if ( parameters.length )
						result ~= " ";

					result ~= parameters.map!( x => x.identificationString ).joiner( ", " );

					if ( parameters.length )
						result ~= " ";

					result ~= ")";
					return result.data;
				}

			public:
				override CallableMatch startCallMatch( DataScope scope_, AST_Node ast ) {
					return new Match( scope_, this, ast );
				}

		}

		class Match : SeriousCallableMatch {

			public:
				this( DataScope scope_, DataEntity sourceEntity, AST_Node ast ) {
					super( scope_, sourceEntity, ast );
				}

			protected:
				override MatchFlags _matchNextArgument( AST_Expression expression, DataEntity entity, Symbol_Type dataType ) {
					if ( argumentIndex_ >= parameters.length )
						return MatchFlags.noMatch;

					ExpandedFunctionParameter param = parameters[ argumentIndex_ ];

					/// If the expression needs expectedType to be parsed, parse it with current parameter type as expected
					if ( !entity ) {
						with ( memoryManager.session ) {
							entity = expression.buildSemanticTree_single( param.dataType, scope_ );
							dataType = entity.dataType;
						}
					}
					else // Add the entity to the scope so it is findable
						scope_.addEntity( entity );

					if ( dataType !is param.dataType )
						return MatchFlags.noMatch;

					if ( param.constValue ) {
						// TODO: This will have to be solved better -- or not?
						if ( !entity.isCtime )
							return MatchFlags.noMatch;

						MemoryPtr entityData = entity.ctExec( scope_ );
						if ( !entityData.dataEquals( param.constValue, dataType.instanceSize ) )
							return MatchFlags.noMatch;
					}

					arguments_ ~= entity;
					argumentIndex_++;

					return MatchFlags.fullMatch;
				}

				override MatchFlags _finish( ) {
					if ( argumentIndex_ != parameters.length )
						return MatchFlags.noMatch;

					return MatchFlags.fullMatch;
				}

				override DataEntity _toDataEntity( ) {
					return new MatchData( this );
				}

			private:
				Symbol_RuntimeFunction func_;
				DataEntity[ ] arguments_;
				size_t argumentIndex_;

		}

		class MatchData : DataEntity {

			public:
				this( Match match ) {
					arguments_ = match.arguments_;
					ast_ = match.ast;
				}

			public:
				override Symbol_Type dataType( ) {
					return this.outer.returnType;
				}

				override bool isCtime( ) {
					// TODO: ctime deduction (long-time target)
					return false;
				}

				override string identification( ) {
					return "%s.%s( %s )".format( parent.identificationString, baseIdentifier, arguments_.map!( x => x.identificationString ).joiner( ", " ).to!string );
				}

				override DataEntity parent( ) {
					return dataEntity.parent;
				}

				override AST_Node ast( ) {
					return ast_;
				}

			public:
				override void buildCode( CodeBuilder cb, DataScope scope_ ) {
					cb.build_functionCall( scope_, this.outer, null, arguments_ );
				}

			protected:
				DataEntity[ ] arguments_;
				AST_Node ast_;

		}

}
