module beast.core.project.codelocation;

import beast.core.project.codesource;
import beast.context;

/// Structure storing information of where a code segment is located in the source code files
struct CodeLocation {

public:
	this( CodeSource source, size_t startPos, size_t length ) {
		this.source = source;
		this.startPos = startPos;
		this.length = length;
	}

	this( CodeSource source ) {
		this.source = source;
	}

public:
	CodeSource source;
	/// Offset from the start of the sourceFile (the code begins there)
	size_t startPos = -1;
	/// Length of the code segment
	size_t length;

public:
	pragma( inline ) @property const {
		size_t endPos( ) {
			return startPos + length;
		}

		size_t startLine( ) {
			return source && startPos != -1 ? source.lineNumberAt( startPos ) : 0;
		}

		size_t startColumn( ) {
			return source && startPos != -1 ? startPos - source.lineNumberStart( startLine ) : 0;
		}

		size_t endLine( ) {
			return source && startPos != -1 ? source.lineNumberAt( startPos + length ) : 0;
		}

		size_t endColumn( ) {
			return source && startPos != -1 ? endPos - source.lineNumberStart( endLine ) : 0;
		}

		string file( ) {
			return source.absoluteFilePath;
		}
	}

}

/// Struct for watching code location, marks start with construction (call function codeLocationGuard), end with get
struct CodeLocationGuard {

public:
	@disable this( );

public:
	CodeLocation get( ) {
		CodeLocation endLocation = context.lexer.currentToken.codeLocation;
		assert( startLocation.source is endLocation.source );
		assert( startLocation.startPos < endLocation.endPos );

		return CodeLocation( startLocation.source, startLocation.startPos, endLocation.endPos - startLocation.startPos );
	}

private:
	this( CodeLocation loc ) {
		this.startLocation = loc;
	}

private:
	CodeLocation startLocation;

}

pragma( inline ) CodeLocationGuard codeLocationGuard( ) {
	auto lx = context.lexer;
	auto tk = lx.currentToken;
	return CodeLocationGuard( context.lexer.currentToken.codeLocation );
}
