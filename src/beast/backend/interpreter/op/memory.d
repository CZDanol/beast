module beast.backend.interpreter.op.memory;

import beast.backend.interpreter.op.toolkit;
import beast.code.hwenv.hwenv;
import std.range : repeat;
import core.checkedint : addu;

//debug = interpreter;

debug ( interpreter ) {
	import std.stdio : writefln;
}

pragma( inline ):

	// ALLOCATION/DEALLOCATION
	void op_allocLocal( Interpreter ir, size_t bpOffset, size_t bytes ) {
		const size_t stackOffset = ir.currentFrame.basePointer + bpOffset;

		assert( stackOffset == ir.stack.length, "AllocLocal offset mismatch %s expected %s got".format( ir.stack.length, stackOffset ) );
		ir.stack ~= memoryManager.alloc( bytes, MemoryBlock.Flag.ctime ); // TODO: separate memory block type to prevent writing to ctime-mirrored data

		debug ( interpreter )
			writefln( "alloc BP+%s (SP+%s) (%#x)", bpOffset, ir.stack.length - 1, ir.stack[ $ - 1 ].val );
	}

	void op_skipAlloc( Interpreter ir, size_t bpOffset ) {
		const size_t stackOffset = ir.currentFrame.basePointer + bpOffset;

		assert( stackOffset == ir.stack.length, "AllocLocal offset mismatch %s expected %s got".format( ir.stack.length, stackOffset ) );
		ir.stack ~= MemoryPtr( );

		debug ( interpreter )
			writefln( "skipalloc BP+%s", ir.stack.length - 1 );
	}

	void op_malloc( Interpreter ir, MemoryPtr op1, MemoryPtr op2 ) {
		op1.writeMemoryPtr( memoryManager.alloc( op2.readSizeT, MemoryBlock.Flag.dynamicallyAllocated | MemoryBlock.Flag.ctime ) );

		debug ( interpreter )
			writefln( "malloc( %s ) (=%s) => %s", op2.readSizeT, op1.readMemoryPtr, op1 );
	}

	void op_free( Interpreter ir, MemoryPtr op1 ) {
		auto ptr = op1.readMemoryPtr;
		benforce( ptr.isNull || ptr.block.isDynamicallyAllocated, E.invalidMemoryOperation, "Can only free memory allocated with new or malloc" );
		memoryManager.free( ptr );

		debug ( interpreter )
			writefln( "free( %s (=%s) )", op1, op1.readMemoryPtr );
	}

	// CT STACK
	void op_allocCt( Interpreter ir, size_t offset, size_t bytes ) {
		// Compile-times stack should never be smaller by more than one item (because of previous ct variables)
		assert( ir.ctStack.length == offset );

		ir.ctStack ~= memoryManager.alloc( bytes, MemoryBlock.Flag.ctime );

		debug ( interpreter )
			writefln( "ctalloc( %s ) (=%s) => CT+%s", bytes, ir.ctStack[ offset ], offset );
	}

	void op_freeCt( Interpreter ir, size_t offset ) {
		assert( offset < ir.ctStack.length );
		assert( !ir.ctStack[ offset ].isNull );

		memoryManager.free( ir.ctStack[ offset ] );
		debug ir.ctStack[ offset ] = MemoryPtr( );

		debug ( interpreter )
			writefln( "freeCt( CT+%s (=%s) )", offset, ir.ctStack[ offset ] );
	}

	// MEMORY OPERATIONS
	void op_mov( Interpreter ir, MemoryPtr op1, MemoryPtr op2, size_t bytes ) {
		op1.write( op2, bytes );

		debug ( interpreter )
			writefln( "%#x => %#x\t%s", op2.val, op1.val, op1.read( bytes ) );
	}

	void op_movConst( Interpreter ir, MemoryPtr op1, size_t data, size_t bytes ) {
		version ( BigEndian ) static assert( 0 );
		op1.write( &data, bytes );

		debug ( interpreter )
			writefln( "=> %#x\t%s", op1.val, cast( const( ubyte )[ ] )( cast( void* )&data )[ 0 .. bytes ] );
	}

	void op_zero( Interpreter ir, MemoryPtr op1, size_t bytes ) {
		op1.write( repeat( cast( ubyte ) 0, bytes ).array );

		debug ( interpreter )
			writefln( "0 => %#x (%s)", op1.val, bytes );
	}

	void op_stAddr( Interpreter ir, MemoryPtr op1, MemoryPtr op2 ) {
		op1.write( &op2, hardwareEnvironment.effectivePointerSize );

		debug ( interpreter )
			writefln( "@%#x => %#x", op2.val, op1.val );
	}

	void op_markPtr( Interpreter ir, MemoryPtr op1 ) {
		memoryManager.markAsPointer( op1 );

		debug ( interpreter )
			writefln( "mark %s", op1 );
	}

	void op_unmarkPtr( Interpreter ir, MemoryPtr op1 ) {
		memoryManager.unmarkAsPointer( op1 );

		debug ( interpreter )
			writefln( "unmark %s", op1 );
	}

	void op_enforceNotNullptr( Interpreter ir, MemoryPtr op1 ) {
		memoryManager.checkNullptr( op1.readMemoryPtr );
	}
