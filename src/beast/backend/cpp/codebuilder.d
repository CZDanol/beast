module beast.backend.cpp.codebuilder;

import beast.backend.toolkit;

// TODO: Asynchronous proxy definition handler

class CodeBuilder_Cpp : CodeBuilder {

	public:
		this( CodeBuilder_Cpp parent ) {
			result_ = appender!string;

			if ( parent )
				tabOffset_ = parent.tabOffset_ + 1;
		}

	public:
		/// Last built code
		string result( ) {
			return result_.data;
		}

		/// When building an expression, result of the expression is stored into given variable
		string resultVarName( ) {
			return resultVarName_;
		}

	public: // Declaration related build commands
		override void build_moduleDefinition( Symbol_Module module_, DeclFunction content ) {
			result_ ~= tabs ~ "// module " ~ module_.identificationString ~ "\n\n";
			content( this );
		}

		override void build_localVariableDefinition( DataEntity_LocalVariable var ) {
			// TODO: implicit value
			result_ ~= tabs ~ " " ~ cppIdentifier( var.dataType ) ~ " " ~ cppIdentifier( var ) ~ ";\n";
		}

		override void build_functionDefinition( Symbol_RuntimeFunction func, StmtFunction body_ ) {
			build_functionPrototype( func );
			result_ ~= "{\n";
			tabOffset_++;

			body_( this );

			tabOffset_--;
			result_ ~= tabs ~ "}\n\n";
		}

	public: // Expression related build commands
		override void build_memoryAccess( MemoryPtr pointer ) {
			MemoryBlock block = pointer.block;

			if ( block.isLocal ) {
				assert( block.localVariable );
				resultVarName_ = cppIdentifier( block.localVariable );
			}
			else
				resultVarName_ = "__staticMemory_%s".format( pointer.val );
		}

		override void build_functionCall( DataScope scope_, Symbol_RuntimeFunction function_, DataEntity[ ] arguments ) {
			result_ ~= tabs ~ "{\n";
			tabOffset_++;

			string[ ] argumentNames;
			foreach ( arg; arguments ) {
				arg.buildCode( this, scope_ );
				argumentNames ~= resultVarName_;
			}

			result_ ~= tabs ~ cppIdentifier( function_ ) ~ "( " ~ argumentNames.joiner( ", " ).to!string ~ ");\n";
			resultVarName_ = null; // TODO: return value

			tabOffset_--;
			result_ ~= tabs ~ "}\n";
		}

	public: // Statement related build commands
		override void build_if( DataScope scope_, DataEntity condition, StmtFunction thenBranch, StmtFunction elseBranch ) {
			result_ ~= tabs ~ "{\n";
			tabOffset_++;

			// Build the condition
			{
				condition.buildCode( this, scope_ );
				result_ ~= tabs ~ "if( " ~ resultVarName_ ~ " ) {\n";
			}

			// Build then branch
			{
				tabOffset_++;
				thenBranch( this );
				tabOffset_--;

				result_ ~= tabs ~ "}\n";
			}

			// Build else branch
			if ( elseBranch ) {
				result_ ~= tabs ~ "else {\n";

				tabOffset_++;
				elseBranch( this );
				tabOffset_--;

				result_ ~= tabs ~ "}\n";
			}

			tabOffset_--;
			result_ ~= tabs ~ "}\n";

			resultVarName_ = null;
		}

	protected:
		void build_functionPrototype( Symbol_RuntimeFunction func ) {
			size_t parameterCount = 0;
			result_ ~= tabs ~ "void " ~ cppIdentifier( func ) ~ "( ";

			// Return value is passed as a pointer
			if ( func.returnType !is coreLibrary.types.Void ) {
				result_ ~= cppIdentifier( func.returnType ) ~ " *result";
				parameterCount++;
			}

			foreach ( param; func.parameters ) {
				// Constant-value parameters do not go to the output code
				if ( param.constValue )
					continue;

				if ( parameterCount )
					result_ ~= ", ";

				result_ ~= cppIdentifier( param.type ) ~ " " ~ param.identifier.str;

				parameterCount++;
			}

			result_ ~= " ) ";
		}

	protected:
		string cppIdentifier( DataEntity_LocalVariable var ) {
			return "_%s__%s".format( var.outerHash.str, var.identifier ? var.identifier.str : "tmp" );
		}

		string cppIdentifier( Symbol sym ) {
			return "_%s__%s".format( sym.outerHash.str, sym.identifier ? sym.identifier.str : "tmp" );
		}

	protected:
		string tabs( ) {
			string result;
			foreach ( i; 0 .. tabOffset_ )
				result ~= "\t";

			return result;
		}

	protected:
		Appender!string result_;
		string resultVarName_;
		size_t tabOffset_;

}
