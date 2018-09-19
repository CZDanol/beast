module beast.backend.interpreter.interpreter;

import beast.backend.toolkit;
import beast.backend.interpreter.instruction;
import std.typecons : Typedef;
import std.meta : aliasSeqOf;
import std.range : iota;
import beast.core.error.guard;
import std.algorithm : startsWith, count;

//debug = interpreter;

final class Interpreter {

public:
	static void executeFunction(Symbol_RuntimeFunction func, MemoryPtr resultPtr, MemoryPtr ctxPtr, MemoryPtr[] args) {
		assert(resultPtr.isNull == (func.returnType is coreType.Void));
		assert(args.length == func.parameters.count!(x => !x.isConstValue));

		auto ir = scoped!Interpreter;
		auto ptrSize = hardwareEnvironment.pointerSize;

		MemoryPtr resultPtrPtr = memoryManager.alloc(ptrSize, MemoryBlock.Flag.ctime);
		resultPtrPtr.writeMemoryPtr(resultPtr);
		ir.stack ~= resultPtrPtr;

		MemoryPtr[] argPtrs;
		argPtrs.length = args.length;
		foreach_reverse (i, arg; args) {
			auto ptr = memoryManager.alloc(ptrSize, MemoryBlock.Flag.ctime);
			ptr.writeMemoryPtr(arg);
			argPtrs[i] = ptr;
			ir.stack ~= ptr;
		}

		MemoryPtr ctxPtrPtr = memoryManager.alloc(ptrSize, MemoryBlock.Flag.ctime);
		ctxPtrPtr.writeMemoryPtr(ctxPtr);
		ir.stack ~= ctxPtrPtr;

		import beast.core.error.error : stderrMutex;

		ir.executeInstruction(Instruction.I.call, func.iopFuncPtr);
		ir.run();

		resultPtrPtr.free();
		ctxPtrPtr.free();

		foreach (argPtr; argPtrs)
			argPtr.free();
	}

public:
	this() {
		currentFrame.instructionPointer = 1;
	}

public:
	void executeInstruction(Instruction.I i, InstructionOperand op1 = InstructionOperand(), InstructionOperand op2 = InstructionOperand(), InstructionOperand op3 = InstructionOperand()) {
		Instruction instr = Instruction(i, op1, op2, op3);
		executeInstruction(instr);
	}

	void executeInstruction(ref Instruction instr) {
		debug (interpreter) {
			import std.stdio : writefln;

			writefln("\n%s; @%s; %s   (#%s)\n---------------------", execId, currentFrame.instructionPointer - 1, instr.identificationString, instr.codeLocation.startLine);
			execId++;
		}

		mixin(() { //
			import std.array : appender;

			auto result = appender!string;
			result ~= "final switch( instr.i ) {\n";

			foreach (instrName; __traits(derivedMembers, Instruction.I)) {
				if (instrName.startsWith("_"))
					result ~= "case Instruction.I.%s: assert( 0, \"Invalid instruction: %s\" );\n".format(instrName, instrName);
				else
					result ~= "case Instruction.I.%s: executeInstruction!\"%s\"( instr ); break;\n".format(instrName, instrName);
			}

			result ~= "}";
			return result.data;
		}());
	}

public:
	/// Starts executing instructions until it hits return to null function
	void run() {
		size_t ip;

		auto _gd = ErrorGuard((err) { err.codeLocation = currentFrame.sourceBytecode[ip].codeLocation; });

		while (currentFrame.sourceBytecode) {
			ip = currentFrame.instructionPointer;
			currentFrame.instructionPointer++;

			executeInstruction(currentFrame.sourceBytecode[ip]);
		}
	}

private:
	pragma(inline) void executeInstruction(string instructionName)(ref Instruction instr) {
		// Calls appropriate function from beast.backend.interpreter.op

		static import beast.backend.interpreter.op;
		import std.traits : Parameters;

		mixin("alias ifunc = beast.backend.interpreter.op.op_%s;".format(instructionName));

		alias Args = Parameters!ifunc[1 .. $];

		Args args;

		foreach (i; aliasSeqOf!(iota(args.length)))
			args[i] = convertOperand!(Args[i])(instr.op[i]);

		ifunc(this, args);
	}

private:
	pragma(inline) auto convertOperand(Target : MemoryPtr)(ref InstructionOperand op) {
		switch (op.type) {

		case InstructionOperand.Type.heapRef:
			return op.heapLocation;

		case InstructionOperand.Type.stackRef:
			assert(currentFrame.basePointer + op.basePointerOffset < stack.length, "Variable not on the stack");
			return stack[currentFrame.basePointer + op.basePointerOffset];

		case InstructionOperand.Type.ctStackRef:
			assert(currentFrame.baseCtPointer + op.basePointerOffset < ctStack.length, "Variable not on the @ctime stack");
			return ctStack[currentFrame.baseCtPointer + op.basePointerOffset];

		case InstructionOperand.Type.refHeapRef:
			return op.heapLocation.readMemoryPtr;

		case InstructionOperand.Type.refStackRef:
			assert(currentFrame.basePointer + op.basePointerOffset < stack.length, "Variable not on the stack");
			return stack[currentFrame.basePointer + op.basePointerOffset].readMemoryPtr;

		case InstructionOperand.Type.refCtStackRef:
			assert(currentFrame.baseCtPointer + op.basePointerOffset < ctStack.length, "Variable not on the @ctime stack");
			return ctStack[currentFrame.baseCtPointer + op.basePointerOffset].readMemoryPtr;

		default:
			assert(0, "Invalid operand type '%s', expected memoryPtr".format(op.type));

		}
	}

	pragma(inline) auto convertOperand(Target : size_t)(ref InstructionOperand op) {
		switch (op.type) {

		case InstructionOperand.Type.directData:
			return op.directData;

		default:
			assert(0, "Invalid operand type '%s', expected directData".format(op.type));

		}
	}

	pragma(inline) auto convertOperand(Target : JumpTarget)(ref InstructionOperand op) {
		switch (op.type) {

		case InstructionOperand.Type.jumpTarget:
			return JumpTarget(op.jumpTarget);

		default:
			assert(0, "Invalid operand type '%s', expected jumpTarget".format(op.type));

		}
	}

	pragma(inline) auto convertOperand(Target : Symbol_RuntimeFunction)(ref InstructionOperand op) {
		switch (op.type) {

		case InstructionOperand.Type.functionPtr:
			return op.functionPtr;

		default:
			assert(0, "Invalid operand type '%s', expected functionPtr".format(op.type));

		}
	}

package:
	/// Stack of function call records
	StackFrame[] callStack;
	StackFrame currentFrame;
	/// Stack of local variables
	MemoryPtr[] stack;
	/// Stack of ctime-mirrored variables
	MemoryPtr[] ctStack;
	debug (interpreter) size_t execId;

	RFlag flagsRegister;

package:
	pragma(inline) void flagsRegister_setFlag(RFlag flag, bool set) {
		if (set)
			flagsRegister |= flag;
		else
			flagsRegister &= ~flag;
	}

package:
	alias JumpTarget = Typedef!(size_t, 0, "beast.interpreter.jumpTarget");
	struct StackFrame {
		debug (identificationLocals) string functionId;

		size_t basePointer;
		size_t baseCtPointer;

		/// Bytecode that is currently interpreted (functions have separate bytecodes)
		Instruction[] sourceBytecode;

		/// Instruction that should be executed after a return from this stack
		size_t instructionPointer;
	}

public:
	enum RFlag {
		equals = 1,
		less = equals << 1
	}

}
