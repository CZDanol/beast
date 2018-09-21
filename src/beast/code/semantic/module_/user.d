module beast.code.semantic.module_.user;

import beast.code.semantic.toolkit;
import beast.code.semantic.module_.module_;
import beast.code.ast.decl.module_;
import beast.core.project.module_;
import beast.code.semantic.codenamespace.namespace;
import beast.code.semantic.codenamespace.user;
import beast.code.ast.decl.env;

/// User (programmer) defined module
final class Symbol_UserModule : Symbol_Module {

public:
	this(Module module_, AST_Module ast) {
		this.module_ = module_;
		ast_ = ast;

		// User modules have corelib module as a parent
		namespace_ = new UserNamespace(this, &execute_membersObtaining);
	}

public:
	/// Corresponing module instance
	Module module_;

public:
	override Identifier identifier() {
		return module_.identifier[$ - 1];
	}

	override AST_Node ast() {
		return ast_;
	}

protected:
	override Namespace namespace() {
		return namespace_;
	}

private:
	Symbol[] execute_membersObtaining() {
		scope env = DeclarationEnvironment.newModule();
		env.staticMembersParent = dataEntity;

		// All identifiers used during members obtaning will be resolved within core module (mostly because of decorators)
		return ast_.declarationScope.executeDeclarations(env).inRootDataScope(coreLibrary.module_.dataEntity);
	}

private:
	UserNamespace namespace_;
	AST_Module ast_;

}
