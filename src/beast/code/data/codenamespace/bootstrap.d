module beast.code.data.codenamespace.bootstrap;

import beast.code.data.toolkit;
import beast.code.data.codenamespace.namespace;
import beast.util.identifiable;

/// Namespace whose symbols are added manually in the compiler code
/// Call initialize with symbol list as an argument
final class BootstrapNamespace : Namespace {

public:
	this(Identifiable parent) {
		super(parent);
	}

public:
	final void initialize(Symbol[] symbolList) {
		initialize_(symbolList);
	}

}
