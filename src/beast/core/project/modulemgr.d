module beast.core.project.modulemgr;

import beast.toolkit;
import beast.code.module_;
import std.file;
import std.path;
import std.algorithm;
import std.array;

/// Class that handles mapping modules on files in the filesystem (eventually stdin or whatever)
final class ModuleManager {

public:
	/// Initializes the manager for usage (prepares initial module list)
	void initialize( ) {
		initialModuleList_ = getInitialModuleList( );
		foreach ( Module m; initialModuleList_ )
			moduleList_[ m.identifier ] = m;
	}

public:
	/// Returns module based on identifier. The module can be added to the project by demand.
	final Module getModule( ExtendedIdentifier id, CodeLocation codeLocation ) {
		synchronized ( this ) {
			// If the module is already in the project, return it
			auto _in = id in moduleList_;
			if ( _in )
				return *_in;

			// TODO: std library injection

			// Otherwise try adding it to the project
			// TODO: Implement searching in include directories

			berror( E.unimplemented, "" );
			assert( 0 );
		}
	}

	@property final Module[ ] initialModuleList( ) {
		return initialModuleList_;
	}

protected:
	Module[ ] getInitialModuleList( ) {
		Module[ ] result;

		foreach ( string sourceDir; context.project.configuration.sourceDirectories ) {
			foreach ( string file; sourceDir.dirEntries( "*.be", SpanMode.depth ) ) {
				// For each .be file in source directories, create a module
				// Identifier of the module should correspon to the path from source directory
				ExtendedIdentifier extId = ExtendedIdentifier( file.asRelativePath( sourceDir ).array.stripExtension.pathSplitter.map!( x => Identifier.obtain( cast( string ) x ) ).array );

				// Test if the identifier is valid
				foreach ( id; extId )
					benforce( id.str.isValidModuleOrPackageIdentifier, E.invalidModuleIdentifier, "Identifier '" ~ id.str ~ "' of module '" ~ extId.str ~ "' (" ~ file.absolutePath( sourceDir ) ~ ") is not a valid module identifier." );

				Module m = new Module( Module.CTOR_FromFile( ), file.absolutePath( sourceDir ), extId );
				result ~= m;

				context.taskManager.issueJob( {
					// Force taskGuard to obtain symbol for the module
					m.symbol;
				} );
			}
		}

		return result;
	}

private:
	Module[ const ExtendedIdentifier ] moduleList_;
	Module[ ] initialModuleList_;

}
