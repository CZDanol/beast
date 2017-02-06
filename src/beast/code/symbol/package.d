module beast.code.symbol;

import beast.code.symbol.toolkit;

/// Base class for all symbols
abstract class Symbol : Identifiable {

public:
	Symbol parent;

public:
	/// Identifier of the symbol, may be null (for template instances, anonymous functions etc.)
	@property Identifier identifier( ) {
		return null;
	}

	/// For template instances, the base name is the template identifier; otherwise it is equal to identifier
	@property Identifier baseName( ) {
		return identifier;
	}

public:
	override @property string identificationString( ) {
		return parent ? parent.identificationString ~ "." ~ baseName.str : baseName.str;
	}

public:
	/// AST node related to the symbol (declaration)
	abstract @property AST_Node ast( ) {
		return null;
	}

	/// Location of where in the code the symbol was declared (or code that +- matches it)
	@property CodeLocation codeLocation( ) {
		return ast ? ast.codeLocation : cast( CodeLocation ) null;
	}

public:
	/// Resolves identifier. This function only looks into current symbol namespace
	Overloadset resolveIdentifier( Identifier id ) {
		return Overloadset( );
	}

	/// Recursively resolves identifier - if it doesn't found any overloads in the current symbol namespace, looks into parent symbol namespace, etc.
	/// This function can be overloaded - this is used for making some symbols accessible only from "inside" of the scope
	Overloadset recursivelyResolveIdentifier( Identifier id ) {
		// First try looking in the current scope
		if ( Overloadset result = resolveIdentifier( id ) )
			return result;

		// If not found, recursively look in parent ones
		if ( parent )
			return parent.recursivelyResolveIdentifier( id );

		return Overloadset( );
	}

}
