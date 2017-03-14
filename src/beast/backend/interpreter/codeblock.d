module beast.backend.interpreter.codeblock;

import beast.backend.interpreter.instruction;

/// Code block generated by the interpreter codebuilder (usually a code representing function)
final class InterpreterCodeBlock {

	package:
		this( Instruction[ ] instructions ) {
			instructions_ = instructions;
		}

	private:
		Instruction[ ] instructions_;

}
