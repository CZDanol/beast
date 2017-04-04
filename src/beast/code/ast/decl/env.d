module beast.code.ast.decl.env;

import beast.code.ast.decl.toolkit;
import beast.code.data.type.type;
import beast.code.data.codenamespace.namespace;
import beast.code.data.stcmemmerger.d;
import beast.code.data.function_.rt;

/// Implicit declaration arguments
final class DeclarationEnvironment {

	public:
		static DeclarationEnvironment newModule( ) {
			DeclarationEnvironment result = new DeclarationEnvironment;
			return result;
		}

		static DeclarationEnvironment newFunctionBody( ) {
			DeclarationEnvironment result = new DeclarationEnvironment;
			result.isStatic = false;
			return result;
		}

		static DeclarationEnvironment newClass( ) {
			DeclarationEnvironment result = new DeclarationEnvironment;
			result.isStatic = false;
			return result;
		}

	public:
		bool isStatic = true;
		bool isCtime = false;

	public:
		Symbol_Type parentType;

		/// Delegate that is used when declaring class members
		/// Points to parent class function that enforces that members have correct parent offset (bytes from this) value set
		void delegate() enforceDone_memberOffsetObtaining;

		/// Parent for static members
		DataEntity staticMembersParent;

		StaticMemberMerger staticMemberMerger;

		/// When in function, this varaible is used for inferring expected types for return statements
		/// Can be null (when function return type is auto) -> then the first return in the code sets it
		Symbol_Type functionReturnType;

}