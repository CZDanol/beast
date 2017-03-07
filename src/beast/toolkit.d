module beast.toolkit;

public {
	import beast.core.context : context, project, taskManager;
	import beast.core.error.error : benforce, berror, breport, benforceHint, E, ErrorSeverity;
	import std.algorithm.iteration : map, filter, joiner;
	import std.array : array;
	import std.conv : to;
	import std.format : format;
}

import beast.util.hooks;

alias HookAppInit = Hook!"appInit";
