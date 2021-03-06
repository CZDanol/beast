module beast.core.error.guard;

import beast.toolkit;
import beast.core.error.errormsg;
import beast.core.project.codelocation;

alias ErrorGuardFunction = void delegate(ErrorMessage msg);

struct ErrorGuardData {
	ErrorGuardFunction[] stack;
}

/// Guard that passes additional informataion to errors occured during its existence
struct ErrorGuard {

public:
	@disable this();

	this(ErrorGuardFunction func) {
		debug this.func = func;
		context.errorGuardData.stack ~= func;
	}

	this(lazy CodeLocation codeLocation) {
		this((err) { err.codeLocation = codeLocation; });
	}

	this(T)(auto ref T t) if (__traits(hasMember, T, "codeLocation")) {
		static if (is(T == class) || is(T == interface))
			this(t ? (err) {
				if (t.codeLocation.source)
					err.codeLocation = t.codeLocation;
			} : (err) {  });
		else
			this((err) {
				if (t.codeLocation.source)
					err.codeLocation = t.codeLocation;
			});
	}

	~this() {
		debug assert(context.errorGuardData.stack[$ - 1] == func);
		context.errorGuardData.stack.length--;
	}

private:
	debug ErrorGuardFunction func;

}
