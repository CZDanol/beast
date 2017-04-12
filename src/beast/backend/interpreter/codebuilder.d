module beast.backend.interpreter.codebuilder;

import beast.backend.toolkit;
import std.array : Appender, appender;
import beast.backend.interpreter.instruction;
import beast.backend.interpreter.codeblock;
import beast.code.data.var.result;
import beast.code.data.scope_.local;

/// "CodeBuilder" that builds code for the internal interpret
final class CodeBuilder_Interpreter : CodeBuilder {
	alias I = Instruction.I;

	public:
		alias InstructionPtr = size_t;

	public:
		final string identificationString( ) {
			return "interpreter";
		}

		final InterpreterCodeBlock result( ) {
			return new InterpreterCodeBlock( result_.data );
		}

	public:
		override void build_localVariableDefinition( DataEntity_LocalVariable var ) {
			var.interpreterBpOffset = currentBPOffset_;
			addToScope( var );

			addInstruction( I.allocLocal, currentBPOffset_.iopLiteral, var.dataType.instanceSize.iopLiteral );
			operandResult_ = currentBPOffset_.iopBpOffset;

			currentBPOffset_++;
		}

		override void build_functionDefinition( Symbol_RuntimeFunction func, StmtFunction body_ ) {
			assert( currentBPOffset_ == 0 );
			assert( !currentFunction_ );

			currentFunction_ = func;

			pushScope( );
			body_( this );

			// Function MUST have a return instruction (for user functions, they're added automatically when return type is void)
			addInstruction( I.noReturnError, func.iopFuncPtr );
			popScope( false );
		}

	public:
		override void build_memoryAccess( MemoryPtr pointer ) {
			MemoryBlock block = pointer.block;
			operandResult_ = block.isLocal ? block.relatedDataEntity.asLocalVariable_interpreterBpOffset.iopBpOffset : pointer.iopPtr;
		}

		override void build_offset( ExprFunction expr, size_t offset ) {
			expr( this );

			if ( offset == 0 )
				return;

			final switch ( operandResult_.type ) {

			case InstructionOperand.Type.directData:
			case InstructionOperand.Type.functionPtr:
			case InstructionOperand.Type.jumpTarget:
			case InstructionOperand.Type.placeholder:
			case InstructionOperand.Type.unused:
				assert( 0, "Cannot offset operand %s".format( operandResult_.identificationString ) );

			case InstructionOperand.Type.heapRef:
				operandResult_.heapLocation.val += offset;
				break;

			case InstructionOperand.Type.stackRef:
			case InstructionOperand.Type.refHeapRef:
			case InstructionOperand.Type.refStackRef: {
					auto varOperand = currentBPOffset_.iopBpOffset;
					auto ptrSize = hardwareEnvironment.pointerSize;

					addInstruction( I.allocLocal, currentBPOffset_.iopLiteral, ptrSize.iopLiteral );
					addInstruction( I.stAddr, varOperand, operandResult_ );
					addInstruction( Instruction.numericI( ptrSize, Instruction.NumI.addConst ), varOperand, varOperand, offset.iopLiteral );

					operandResult_.type = InstructionOperand.Type.refStackRef;
					operandResult_.basePointerOffset = currentBPOffset_;

					currentBPOffset_++;
				}
				break;

			}
		}

		override void build_functionCall( Symbol_RuntimeFunction function_, DataEntity parentInstance, DataEntity[ ] arguments ) {
			/*
				Call convention:
				RETURN ARG3 ARG2 ARG1 CONTEXT
				context is always present
				constnant value args also get their BPoffset (it is unused though, even unallocated)
			*/

			InstructionOperand operandResult;

			if ( function_.returnType !is coreType.Void ) {
				auto returnVar = new DataEntity_TmpLocalVariable( function_.returnType, false );
				build_localVariableDefinition( returnVar );
				operandResult = operandResult_;
			}

			pushScope( );

			DataEntity_TmpLocalVariable[ ] argVars;
			argVars.length = function_.parameters.length;

			// Because of call convention (where the argument order is RET ARG3 ARG2 ARG1 CTX), we need to initialize this rather strangely
			foreach_reverse ( i, ExpandedFunctionParameter param; function_.parameters ) {
				if ( param.isConstValue ) {
					currentBPOffset_++;
					continue;
				}

				auto argVar = new DataEntity_TmpLocalVariable( param.dataType, false );
				build_localVariableDefinition( argVar );

				argVars[ i ] = argVar;
			}

			if ( function_.declarationType == Symbol.DeclType.memberFunction ) {
				assert( parentInstance );

				auto iopOffset = currentBPOffset_.iopLiteral;
				auto contextPtrIOP = currentBPOffset_.iopBpOffset;
				currentBPOffset_++;

				addInstruction( I.allocLocal, iopOffset, hardwareEnvironment.pointerSize.iopLiteral );
				addInstruction( I.markPtr, contextPtrIOP );

				parentInstance.buildCode( this );
				addInstruction( I.stAddr, contextPtrIOP, operandResult_ );
			}
			else {
				addInstruction( I.skipAlloc, currentBPOffset_.iopLiteral );
				currentBPOffset_++;
			}

			foreach ( i, ExpandedFunctionParameter param; function_.parameters ) {
				if ( param.isConstValue )
					continue;

				pushScope( );
				build_copyCtor( argVars[ i ], arguments[ i ] );
				popScope( );
			}

			addInstruction( I.call, function_.iopFuncPtr );

			popScope( );
			operandResult_ = operandResult;
		}

		override void build_contextPtr( ) {
			operandResult_ = ( -1 ).iopRefBpOffset;
		}

		mixin Build_PrimitiveOperationImpl!( "interpreter", "operandResult_" );

	public:
		override void build_scope( StmtFunction body_ ) {
			pushScope( );
			body_( this );
			popScope( );
		}

		override void build_if( ExprFunction condition, StmtFunction thenBranch, StmtFunction elseBranch ) {
			pushScope( );

			auto _s = new LocalDataScope( );
			auto _sgd = _s.scopeGuard; // Build the condition

			InstructionPtr condJmpInstr;
			{
				condition( this );
				condJmpInstr = addInstruction( I.jmpFalse, iopPlaceholder, operandResult_ );
			}

			// Build then branch
			InstructionPtr thenJmpInstr;
			{
				pushScope( );
				thenBranch( this );
				popScope( );

				if ( elseBranch )
					thenJmpInstr = addInstruction( I.jmp, iopPlaceholder );
			}

			setInstructionOperand( condJmpInstr, 0, jumpTarget );

			// Build else branch
			if ( elseBranch ) {
				pushScope( );
				elseBranch( this );
				popScope( );
				setInstructionOperand( thenJmpInstr, 0, jumpTarget );
			}

			popScope( );
			_s.finish( );
		}

		override void build_loop( StmtFunction body_ ) {
			pushScope( ScopeFlags.loop );
			auto jt = jumpTarget( );
			pushScope( );
			body_( this );
			popScope( );
			addInstruction( I.jmp, jt );
			popScope( );
		}

		override void build_break( size_t scopeIndex ) {
			foreach_reverse ( ref s; scopeStack_[ scopeIndex .. $ ] )
				generateScopeExit( s );

			additionalScopeData_[ scopeIndex ].breakJumps ~= addInstruction( I.jmp, iopPlaceholder );
		}

		override void build_return( DataEntity returnValue ) {
			assert( currentFunction_ );

			if ( returnValue )
				build_copyCtor( new DataEntity_Result( currentFunction_, returnValue.dataType ), returnValue );

			generateScopesExit( );
			addInstruction( I.ret );
		}

	public:
		void debugPrintResult( string desc ) {
			if ( !result_.data.length )
				return;

			import std.stdio : writefln, stdout;
			import beast.core.error.error : stderrMutex;

			// uncommenting this causes freezes - dunno why
			//synchronized ( stderrMutex ) {
			writefln( "\n== BEGIN CODE %s\n", desc );

			foreach ( i, instr; result_.data )
				writefln( "@%3s   %s", i, instr.identificationString );

			writefln( "\n== END\n" );
			//stdout.flush();
			//}
		}

	package:
		/// Adds instruction, returns it's ID (index)
		pragma( inline ) InstructionPtr addInstruction( I i, InstructionOperand op1 = InstructionOperand( ), InstructionOperand op2 = InstructionOperand( ), InstructionOperand op3 = InstructionOperand( ) ) {
			result_ ~= Instruction( i, op1, op2, op3 );
			return result_.data.length - 1;
		}

		/// Updates instruction operand via it's ID (index)
		pragma( inline ) void setInstructionOperand( InstructionPtr instruction, size_t operandId, InstructionOperand set ) {
			assert( result_.data[ instruction ].op[ operandId ].type == InstructionOperand.Type.placeholder, "You can only update placeholder operands" );
			result_.data[ instruction ].op[ operandId ] = set;
		}

		/// Returns operand representing a next instruction jump target
		pragma( inline ) InstructionOperand jumpTarget( ) {
			InstructionOperand result = InstructionOperand( InstructionOperand.Type.jumpTarget );
			result.jumpTarget = result_.data.length;
			return result;
		}

	public:
		override void pushScope( ScopeFlags flags = ScopeFlags.none ) {
			super.pushScope( flags );
			additionalScopeData_ ~= AdditionalScopeData( currentBPOffset_ );
		}

		override void popScope( bool generateDestructors = true ) {
			// Result might be f-ked around because of destructors
			auto result = operandResult_;

			super.popScope( generateDestructors );

			// "Link" break jumps that jump after scope exit
			if ( auto jmps = additionalScopeData_[ $ - 1 ].breakJumps ) {
				auto jt = jumpTarget( );
				foreach ( jmp; jmps )
					setInstructionOperand( jmp, 0, jt );
			}

			currentBPOffset_ = additionalScopeData_[ $ - 1 ].bpOffset;
			additionalScopeData_.length--;

			operandResult_ = result;
		}

	protected:
		override void generateScopeExit( ref Scope scope_ ) {
			super.generateScopeExit( scope_ );

			size_t targetBPOffset = additionalScopeData_[ scope_.index ].bpOffset;
			if ( targetBPOffset < currentBPOffset_ )
				addInstruction( I.popScope, targetBPOffset.iopLiteral );
		}

	package:
		Appender!( Instruction[ ] ) result_;
		InstructionOperand operandResult_;
		size_t currentBPOffset_;

	private:
		Symbol_RuntimeFunction currentFunction_;
		AdditionalScopeData[ ] additionalScopeData_ = [ AdditionalScopeData( ) ];

	private:
		struct AdditionalScopeData {
			size_t bpOffset;

			/// List of jmp instruction pointers generated by break statements
			/// Those instructions have placeholder as a target as the jump target was
			/// unknown when the jmp instruction was created
			/// breakJumps are "linked" in the popScope function
			InstructionPtr[ ] breakJumps;
		}

}
