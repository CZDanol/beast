module beast.main;

import beast.core.project.configuration;
import beast.core.project.project;
import beast.core.task.manager;
import beast.toolkit;
import std.concurrency;
import std.algorithm;
import std.getopt;
import std.json;
import std.path;
import std.stdio;
import std.string;
import std.file;
import std.array;

void mainImpl( string[ ] args ) {
	HookAppInit.call( );

	context.taskManager = new TaskManager;
	scope ( exit ) {
		context.taskManager.waitForEverythingDone( );
		context.taskManager.quitWorkers( );
	}
	context.project = new Project;

	/// Absolute file path of project file
	string projectFile;
	/// Root directory of the project as set by --root
	string root;
	/// Number of source files added to the project using --source
	size_t sourceFileCount;
	/// Project configuration options set by arguments
	JSONValue[ string ] optConfigs;
	/// Project file content, if set by stdin
	string stdinProjectData;

	GetoptResult getoptResult;
	try {
		getoptResult = getopt( args, //
				std.getopt.config.bundling, //
				"project|p", "Location of project configuration file.", ( string opt, string val ) { //
					benforce( !projectFile, E.invalidOpts, "Cannot set multiple project files" );
					projectFile = val.absolutePath;
				}, //
				"project-stdin", "Loads the project configuration from stdin (until EOF).", ( ) { //
					stdinProjectData = stdin.byLine.joiner( "\n" ).to!string;
				}, //
				"source|s", "Adds specified source file to the project.", ( string opt, string val ) { //
					sourceFileCount++;
					optConfigs[ "sourceFiles@opt-origin" ~ sourceFileCount.to!string ] = [ val.absolutePath.to!string ];
				}, //
				"root", "Root directory of the project.", &root, //
				"run|r", "Run the target application after a successfull build.", { //
					optConfigs[ "runAfterBuild" ] = true;
				}, //

				"config", "Override project configuration option. See --help-config for possible options. \nUsage: --config <optName>=<jsonValue>, for example --config messageFormat=\"json\"", ( string opt, string val ) { //
					// TODO: Smart config vals
					const auto data = val.findSplit( "=" );
					const string key = data[ 0 ].strip;
					const string value = data[ 2 ].strip;

					try {
						optConfigs[ key ] = value.parseJSON;
					}
					catch ( JSONException exc ) {
						berror( E.invalidOpts, "Config opt '" ~ key ~ "' value '" ~ value ~ "' parsing failed: " ~ exc.msg );
					}
				}, //

				"json-messages", "Print messages in JSON format.", { //
					optConfigs[ "messageFormat" ] = "json";
				}, //

				"help-config", "Shows documentation of project configuration.", { //
					context.project.configuration.printHelp( );
				} //
				 );
	}
	catch ( GetOptException exc ) {
		berror( E.invalidOpts, exc.msg );
	}

	if ( getoptResult.helpWanted ) {
		writeln( "Beast language compiler" );

		writeln;
		writeln( "Options:" );
		foreach ( opt; getoptResult.options )
			writef( "  %s\n    %s\n\n", opt.optShort ~ ( opt.optShort && opt.optLong ? " | " : "" ) ~ opt.optLong, opt.help.replace( "\n", "\n    " ) );
	}

	// Find out project root
	if ( root )
		context.project.basePath = root;
	else if ( projectFile )
		context.project.basePath = projectFile.dirName;

	// If no project is set (and the mode is not fast), load implicit configuration file (if it exists)
	if ( "originSourceFile" !in optConfigs && !projectFile && absolutePath( "beast.json", context.project.basePath ).exists )
		projectFile = "beast.json";

	// Build project configuration
	{
		ProjectConfigurationBuilder configBuilder = new ProjectConfigurationBuilder;

		if ( projectFile )
			configBuilder.applyFile( projectFile );

		if ( stdinProjectData ) {
			try {
				configBuilder.applyJSON( stdinProjectData.parseJSON );
			}
			catch ( JSONException exc ) {
				berror( E.invalidProjectConfiguration, "Stdin project configuration parsing failed: " ~ exc.msg );
			}
		}

		configBuilder.applyJSON( JSONValue( optConfigs ) );
		context.project.configuration.load( configBuilder.build( ) );
	}

	context.project.finishConfiguration( );
	context.taskManager.spawnWorkers( );
}

int main( string[ ] args ) {
	try {
		mainImpl( args );
		return 0;
	}
	catch ( BeastErrorException err ) {
		return -1;
	}
}
