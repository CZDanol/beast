module beast.backend.common.codebuilder;

import beast.backend.toolkit;
import beast.util.identifiable;

/// Root class for building code with any backend
abstract class CodeBuilder : Identifiable {

	public:
		/// When called, StmtFunction should build given part of the statement using provided codebuilder
		alias StmtFunction = void delegate( CodeBuilder cb );

		/// When called, DeclFunction should build relevant declarations using provided codebuilder
		alias DeclFunction = void delegate( CodeBuilder cb );

	public: // Declaration related build commands
		void build_moduleDefinition( Symbol_Module module_, DeclFunction content ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

		void build_localVariableDefinition( DataEntity_LocalVariable var ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

		void build_functionDefinition( Symbol_RuntimeFunction func, StmtFunction body_ ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

		void build_typeDefinition( Symbol_Type type, DeclFunction content ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

	public: // Expression related build commands
		/// Builds access to a memory (passed by a pointer)
		/// The memory doesn't have to be static! You have to check associated memory block flags (it can be local ctime variable or so)
		void build_memoryAccess( MemoryPtr pointer ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

		/// Builds write to a memory
		void build_memoryWrite( MemoryPtr target, DataEntity data ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

		final void build_memoryWrite( MemoryPtr target, Symbol sym ) {
			build_memoryWrite( target, sym.dataEntity );
		}

		void build_functionCall( Symbol_RuntimeFunction function_, DataEntity parentInstance, DataEntity[ ] arguments ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

		void build_primitiveOperation( Symbol_RuntimeFunction wrapperFunction, BackendPrimitiveOperation op, DataEntity parentInstance, DataEntity[ ] arguments ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

	public: // Statement related build commands
		/// Builds the "if" construction
		/// Condition has to be of type bool
		/// elseBranch can be null
		void build_if( DataEntity condition, StmtFunction thenBranch, StmtFunction elseBranch ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

		void build_return( DataEntity returnValue ) {
			assert( 0, "%s not implemented for %s".format( __FUNCTION__, identificationString ) );
		}

	public:
		final void build_copyCtor( DataEntity_LocalVariable var, DataEntity initValue ) {
			var.expectResolveIdentifier( ID!"#ctor" ).resolveCall( var.ast, true, coreLibrary.enum_.xxctor.copy, initValue ).buildCode( this );
		}

	protected:
		/// Creates a new scope (scopes are stored on a stack)
		/// CodeBuilder scopes are used for destructor generating
		void pushScope( ) {
			scopeStack_ ~= topScope_;
			topScope_ = Scope( );
		}

		/// Destroys the last scope
		/// CodeBuilder scopes are used for destructor generating
		void popScope( bool generateDestructors = true ) {
			if ( generateDestructors )
				generateScopeExit( topScope_ );

			assert( scopeStack_.length );

			topScope_ = scopeStack_[ $ - 1 ];
			scopeStack_.length--;
		}

		/// Generates destructors for all the scope
		final void generateScopesExit( ) {
			generateScopeExit( topScope_ );

			foreach_reverse ( scope_; scopeStack_ )
				generateScopeExit( scope_ );
		}

		final void addToScope( DataEntity_LocalVariable var ) {
			topScope_.variables ~= var;
		}

		final DataEntity_LocalVariable[ ] scopeItems( ) {
			return topScope_.variables;
		}

	private:
		final void generateScopeExit( ref Scope scope_ ) {
			foreach_reverse ( var; scope_.variables )
				var.expectResolveIdentifier( ID!"#dtor" ).resolveCall( null, true ).buildCode( this );
		}

	private:
		Scope topScope_;
		Scope[ ] scopeStack_;

	private:
		struct Scope {
			DataEntity_LocalVariable[ ] variables;
		}

}
