module beast.toolkit;

public {
	import std.conv : to;

	import beast.context;
	import beast.error;
	import beast.code.lex.identifier;
	import beast.code.lex.token;
	import beast.project.codelocation;
	import beast.task.guard;
	import beast.utility.identifiable;
}

import beast.utility.hooks;

alias HookAppInit = Hook!"appInit";
