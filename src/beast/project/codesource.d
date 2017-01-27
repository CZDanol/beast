module beast.project.codesource;

import std.path;
import std.file;
import beast.toolkit;
import beast.utility.identifiable;

final class CodeSource {

public:
	this( string fileName ) {
		absoluteFilePath = fileName.absolutePath( context.project.basePath );

		try {
			content = readText( absoluteFilePath );
		}
		catch ( FileException exc ) {
			berror( CodeLocation( this ), BError.fileError, "File error: " ~ exc.msg );
		}

		// Calculate newlines
		{
			size_t[ ] newlinePositions = [ 0 ];
			foreach ( int i, dchar ch; content ) {
				if ( ch == '\n' )
					newlinePositions ~= i;
			}
			newlinePositions_ = newlinePositions;
		}
	}

public:
	const string absoluteFilePath;

	/// File contents
	const string content;

public:
	/// Returns line number (counting from 1) of nth char of the content (counting from 0)
	size_t lineNumberAt( size_t offset ) const {
		// Binary search
		size_t low = 0, high = content.length;

		while ( low <= high ) {
			const size_t mid = ( high + low ) / 2;

			if ( offset > newlinePositions_[ mid ] )
				low = mid;
			else if ( offset < newlinePositions_[ mid ] )
				high = mid - 1;
			else
				return mid + 1;
		}

		return low + 1;
	}

	/// Returns position of the '\n' of the specified line (counting from 1)
	size_t lineNumberStart( size_t lineNumber ) const {
		assert( lineNumber > 0 && lineNumber <= newlinePositions_.length );
		return newlinePositions_[ lineNumber - 1 ];
	}

public:
	/// Index = line number (counting from 0), value = position of the '\n' in the file
	const size_t[ ] newlinePositions_;

}
