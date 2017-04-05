module beast.backend.interpreter.instruction;

import beast.backend.toolkit;
import beast.code.data.function_.rt;
import beast.util.enumassoc;
import beast.core.project.codelocation;
import beast.core.error.error;

struct Instruction {

	public:
		enum I {
			// GENERAL
			noOp, /// Does basically nothing
			noReturnError, /// () Throws an error - function did not exit using return statement
			printError, /// () Throws an error - cannot print to stdout at compile time
			assert_, /// (condition: ptr) If condition is false (evaluated as bool), reports an error

			// STACK
			allocLocal, /// (bpOffset : dd, bytes : dd) Allocates memory for a local variable
			skipAlloc, /// (bpOffset: dd) Do not allocate memory for local variable (but increase stack offset)
			popScope, /// (targetBpOffset: dd) Deallocates all variables on the stack above targetBpOffset
			call, /// (function : func) Function call (arguments are passed on the stack in order [RETURN VALUE] [OP3] [OP2] [OP1] [CONTEXT PTR - always (even if null)])
			ret, /// () returns from a function call

			// COMPARISON
			bitsCmp, /// (op1: ptr, op2: ptr, bytes: dd) Bit compares two operands and stores result into INTERNAL FLAGS (use cmpXX instructions)
			cmpEq, /// (target: ptr) Stores bool into target stating whether previous comparison resulted x == y
			cmpNeq, /// (target: ptr) Stores bool into target stating whether previous comparison resulted x != y
			cmpLt, /// (target: ptr) Stores bool into target stating whether previous comparison resulted as x < y
			cmpLte, /// (target: ptr) Stores bool into target stating whether previous comparison resulted as x <= y
			cmpGt, /// (target: ptr) Stores bool into target stating whether previous comparison resulted as x > y
			cmpGte, /// (target: ptr) Stores bool into target stating whether previous comparison resulted as x >= y

			// MEMORY
			mov, /// (target : ptr, source : ptr, bytes : dd) Copies memory from one place to another
			movConst, /// (target: ptr, source: dd, bytes: dd) Saves given data into memory
			zero, /// (target: ptr, bytes: dd) Zeroes given memory
			stAddr, /// (target: ptr, source: ptr) Stores address of source into the target
			malloc, /// (target: ptr, bytes: ptr) Mallocaes n bytes and stores the pointer to target
			free, /// (target: ptr) Frees the memory referenced by target

			// Pointers
			markPtr, /// (target: ptr) Mark given address as pointer
			unmarkPtr, /// (target: ptr) Unmark given address as pointer

			// BRANCHING
			jmpTrue, /// (target: jt, condition: ptr) Jumps to given instruction (ID/index) when condition (read as 1byte boolean) is true
			jmpFalse, /// (target: jt, condition: ptr) Jumps to given instruction (ID/index) when condition (read as 1byte boolean) is false
			jmp, /// (target: jt) Jumps to given instruction (ID/index)

			// BOOL
			boolNot, /// (target: ptr, source: ptr) Boolean not operation)

			// INT32
			_int32,
			intAdd32, /// (target: ptr, op1: ptr, op2: ptr) target <= op1 + op2
			intAddConst32, /// (target: ptr, op1: ptr, op2: dd) target <= op1 + op2
			intSub32, /// (target: ptr, op1: ptr, op2: ptr) target <= op1 - op2
			intMult32, /// (target: ptr, op1: ptr, op2: ptr) target <= op1 * op2
			intDiv32, /// (target: ptr, op1: ptr, op2: ptr) target <= op1 / op2
			intCmp32, /// (op1: ptr, op2: ptr) Compares two integers and stores the result into INTERNAL FLAGS (use cmpXX instructions)

			// INT32
			_int64,
			intAdd64, /// (target: ptr, op1: ptr, op2: ptr) target <= op1 + op2
			intAddConst64, /// (target: ptr, op1: ptr, op2: dd) target <= op1 + op2
			intSub64, /// (target: ptr, op1: ptr, op2: ptr) target <= op1 - op2
			intMult64, /// (target: ptr, op1: ptr, op2: ptr) target <= op1 * op2
			intDiv64, /// (target: ptr, op1: ptr, op2: ptr) target <= op1 / op2
			intCmp64, /// (op1: ptr, op2: ptr) Compares two integers and stores the result into INTERNAL FLAGS (use cmpXX instructions)
		}

		enum NumI {
			_none,
			add,
			addConst,
			sub,
			mult,
			div,
			cmp
		}

	public:
		this( I i, InstructionOperand op1 = InstructionOperand( ), InstructionOperand op2 = InstructionOperand( ), InstructionOperand op3 = InstructionOperand( ) ) {
			this.i = i;
			op[ 0 ] = op1;
			op[ 1 ] = op2;
			op[ 2 ] = op3;

			codeLocation = getCodeLocation( );
		}

	public:
		I i;
		InstructionOperand[ 3 ] op;
		CodeLocation codeLocation;

	public:
		ref InstructionOperand op1( ) {
			return op[ 0 ];
		}

		ref InstructionOperand op2( ) {
			return op[ 1 ];
		}

		ref InstructionOperand op3( ) {
			return op[ 2 ];
		}

	public:
		string identificationString( ) {
			assert( i in enumAssocInvert!I );

			string ops;

			if ( op[ 0 ].type != InstructionOperand.Type.unused ) {
				ops ~= " %s".format( op[ 0 ].identificationString );

				if ( op[ 1 ].type != InstructionOperand.Type.unused ) {
					ops ~= ", %s".format( op[ 1 ].identificationString );

					if ( op[ 2 ].type != InstructionOperand.Type.unused )
						ops ~= ", %s".format( op[ 2 ].identificationString );
				}
				else {
					assert( op[ 2 ].type == InstructionOperand.Type.unused );
				}
			}
			else {
				assert( op[ 1 ].type == InstructionOperand.Type.unused );
				assert( op[ 2 ].type == InstructionOperand.Type.unused );
			}

			return "%s%s".format( enumAssocInvert!I[ i ], ops );
		}

	public:
		static I numericI( size_t numericSize, NumI type ) {
			switch ( numericSize ) {

			case 4:
				return cast( I )( I._int32 + type );

			case 8:
				return cast( I )( I._int64 + type );

			default:
				assert( 0, "No numeric instructions for type of size %s".format( numericSize ) );

			}
		}

}

struct InstructionOperand {

	public:
		enum Type {
			unused,

			heapRef, /// Direct pointer to a memory
			stackRef, /// Offset from base pointer

			refHeapRef, /// Reference in a static memory
			refStackRef, /// Reference on a stack

			directData,
			functionPtr,
			jumpTarget,

			placeholder, /// This should not appear in the resulting code
		}

	public:
		Type type;
		union {
			/// When type == heapRef || refHeapRef
			MemoryPtr heapLocation;

			/// When type == stackRef || refStackRef
			size_t basePointerOffset;

			/// When type == directData
			size_t directData;

			/// When type == functionPtr
			Symbol_RuntimeFunction functionPtr;

			/// When type == jumpTarget
			size_t jumpTarget;
		}

	public:
		string identificationString( ) {
			final switch ( type ) {

			case Type.unused:
				return "(unused)";

			case Type.heapRef:
				return "%#x".format( heapLocation.val );

			case Type.stackRef: {
					int bpo = cast( int ) basePointerOffset;
					return bpo >= 0 ? "BP+%s".format( bpo ) : "BP-%s".format( -bpo );
				}

			case Type.refHeapRef:
				return "#%#x".format( heapLocation.val );

			case Type.refStackRef: {
					int bpo = cast( int ) basePointerOffset;
					return bpo >= 0 ? "#BP+%s".format( bpo ) : "#BP-%s".format( -bpo );
				}

			case Type.directData:
				return "%s".format( directData );

			case Type.functionPtr:
				return "@%s".format( functionPtr.identificationString );

			case Type.jumpTarget:
				return "@%s".format( jumpTarget );

			case Type.placeholder:
				return "(placeholder)";

			}
		}

}

InstructionOperand iopBpOffset( size_t offset ) {
	auto result = InstructionOperand( InstructionOperand.Type.stackRef );
	result.basePointerOffset = offset;
	return result;
}

InstructionOperand iopPtr( MemoryPtr ptr ) {
	auto result = InstructionOperand( InstructionOperand.Type.heapRef );
	result.heapLocation = ptr;
	return result;
}

InstructionOperand iopLiteral( size_t data ) {
	auto result = InstructionOperand( InstructionOperand.Type.directData );
	result.directData = data;
	return result;
}

InstructionOperand iopFuncPtr( Symbol_RuntimeFunction func ) {
	auto result = InstructionOperand( InstructionOperand.Type.functionPtr );
	result.functionPtr = func;
	return result;
}

InstructionOperand iopPlaceholder( ) {
	return InstructionOperand( InstructionOperand.Type.placeholder );
}
