module beast.core.task.guard;

import core.sync.mutex : Mutex;
import beast.core.task.context;
import beast.toolkit;

//debug = taskGuards;

alias TaskGuardId = shared ubyte*;

// TODO: Check for unfinished task guards
// TODO: Get functionality outside the mixin

/**
	USAGE:
	- mixin this
	- implement void execute_<<guardName>>() which does the task
	- implement function like <<Type>> <<guardName>>() { enforceDone_<<guardName>>(); return <<guardName>>_data; } (enforceDone_<<guardName>>() is generated by this mixin)

	TaskGuard is a core element for Beast's multithread compiler design, which is based on data-processing tasks.
	Getting some information/parsing something/etc is designed to be a single-fire task (which can be dependent on another tasks) which can be run parallely with different tasks.
	This mixin ensures that each task is done exactly once, handles synchronization between threads and loop dependency.
*/
mixin template TaskGuard( string guardName ) {
	import beast.core.task.context : TaskContext;
	import beast.core.task.guard : taskGuardResolvingMutex, TaskGuardId, taskGuardDependentsList;

	public:
		// Give the taskGuard function an useful name
		mixin( "final pragma( inline ) void enforceDone_" ~ guardName ~ "() { _taskGuard_func(); }" );

		// And generate abstract execute function that the programmer has to override
		mixin( "void execute_" ~ guardName ~ "() { assert( 0, \"execute_\" ~ guardName ~ \" not implemented for \" ~ typeof(this).stringof ~ \" \" ~ identificationString ); }" );

	private:
		shared ubyte _taskGuard_flags;

		/// Context this task is being processed in
		TaskContext _taskGuard_context;

		enum _taskGuard_executeFunctionName = "execute_" ~ guardName;

	private:
		/// All-in-one function. If the task is done, returns its result. If not, either starts working on it or waits till it's done (and eventually throws poisoning error). Checks for circular dependencies
		final void _taskGuard_func( ) {
			debug import beast.core.task.worker;
			import core.atomic : atomicOp;
			import beast.util.atomic : atomicFetchThenOr;
			import beast.code.memory.block : MemoryBlock;
			import beast.core.task.guard : Flags = TaskGuardFlags;
			import beast.util.identifiable : Identifiable;
			import beast.core.error.error : BeastErrorException;
			import beast.util.util : tryGetIdentificationString;

			static assert( is( typeof( this ) : Identifiable ), "TaskGuards can only be mixed into classes that implement Identifiable interface (%s)".format( typeof( this ).stringof ) );
			assert( Worker.current, "All task guards must be processed in worker threads" );
			assert( !context.taskContext.blockingContext_ );

			debug ( taskGuards ) {
				import std.stdio : writefln;
			}

			const ubyte initialFlags = atomicFetchThenOr( _taskGuard_flags, Flags.workInProgress );

			if ( initialFlags & Flags.error ) {
				debug ( taskGuards )
					writefln( "%s.%s posioned", typeof( this ).stringof, guardName );

				throw new BeastErrorException( "#poison" );
			}

			// Task is already done, no problem
			if ( initialFlags & Flags.done ) {
				debug ( taskGuards )
					writefln( "%s.%s already done", typeof( this ).stringof, guardName );

				return;
			}

			// If not, we have to check if it is work in progress
			if ( initialFlags & Flags.workInProgress ) {
				TaskContext thisContext = context.taskContext;

				synchronized ( taskGuardResolvingMutex ) {
					assert( !context.taskContext.blockingContext_ );

					// Mark that there are tasks waiting for it
					const ubyte wipFlags = atomicFetchThenOr( _taskGuard_flags, Flags.dependentTasksWaiting );

					// It is possible that the task finished/failed between initialFlags and wipFlags fetches, we need to check for that
					if ( wipFlags & Flags.error ) {
						debug ( taskGuards )
							writefln( "%s.%s poisoned", typeof( this ).stringof, guardName );

						throw new BeastErrorException( "#poison" );
					}

					if ( wipFlags & Flags.done )
						return;

					// Wait for the worker context to mark itself to this guard (this is not done atomically)
					while ( !( _taskGuard_flags & Flags.contextSet ) ) {
						// TODO: Benchmark this
					}

					// Mark current context as waiting on this task	(for circular dependency checks)
					thisContext.blockingContext_ = _taskGuard_context;
					thisContext.blockingTaskGuardIdentificationString_ = ( ) => "%s.(%s)".format( this.tryGetIdentificationString, guardName );

					// Check for circular dependencies
					{
						TaskContext ctx = _taskGuard_context;
						while ( ctx ) {

							if ( ctx is thisContext ) {
								// Mark error to prevent dependency loop while resolving identificationStrings for dependency loop
								_taskGuard_flags.atomicOp!"|="( Flags.error );

								// Unmark this context to be waiting for anything (the context would get reused with blockingContext_ being set which would lead to unfunny behavior)
								thisContext.blockingContext_ = null;

								// Walk the dependencies again, this time record contexts we were walking
								TaskContext ctx2 = _taskGuard_context;
								string[ ] loopList = [ ctx2.blockingTaskGuardIdentificationString_( ) ];
								while ( ctx2 !is thisContext ) {
									assert( ctx2.blockingTaskGuardIdentificationString_ );
									ctx2 = ctx2.blockingContext_;
									loopList ~= ctx2.blockingTaskGuardIdentificationString_( );
								}

								loopList ~= loopList[ 0 ];
								// TODO: Better loop dependency message - gotta wake all looped contexts and get context guard data from them

								// If the circular loop is this context to this context, 
								if ( !( wipFlags & Flags.dependentTasksWaiting ) )
									taskGuardDependentsList[ _taskGuard_id ] = [ ];

								berror( E.dependencyLoop, "Circular dependency loop: %s".format( loopList.joiner( " - " ).to!string ) );
							}

							assert( ctx !is ctx.blockingContext_ );

							ctx = ctx.blockingContext_;
						}
					}

					assert( thisContext.blockingContext_ !is thisContext );

					// Mark current context to be woken when the task is finished, the _taskGuard_issueWaitingTasks is called anyway - we have to ensure it has a record to work with
					assert( cast( bool )( _taskGuard_id in taskGuardDependentsList ) == cast( bool )( wipFlags & Flags.dependentTasksWaiting ) );

					if ( wipFlags & Flags.dependentTasksWaiting )
						taskGuardDependentsList[ _taskGuard_id ] ~= thisContext;
					else
						taskGuardDependentsList[ _taskGuard_id ] = [ thisContext ];
				}

				// Yield the current context
				thisContext.yield( );

				assert( context.taskContext is thisContext );

				synchronized ( taskGuardResolvingMutex )
					thisContext.blockingContext_ = null;

				assert( _taskGuard_flags & Flags.done );

				if ( _taskGuard_flags & Flags.error )
					throw new BeastErrorException( "#posion" );

				// After this context is resumed, the task should be done
				return;
			}

			_taskGuard_context = context.taskContext;
			atomicOp!( "|=" )( _taskGuard_flags, Flags.contextSet );

			try {
				debug ( taskGuards )
					writefln( "%s.%s exec", typeof( this ).stringof, guardName );

				__traits( getMember, this, _taskGuard_executeFunctionName )( );

				debug ( taskGuards )
					writefln( "%s.%s finish", typeof( this ).stringof, guardName );
			}
			catch ( BeastErrorException exc ) {
				debug ( taskGuards )
					writefln( "%s.%s error", typeof( this ).stringof, guardName );

				// Mark this task as erroreous
				const ubyte data = atomicFetchThenOr( _taskGuard_flags, Flags.done | Flags.error );

				// If there were tasks waiting for this guard, issue them (they should be poisoned)
				if ( data & Flags.dependentTasksWaiting )
					_taskGuard_issueWaitingTasks( );

				// Rethrow the exception
				throw exc;
			}

			assert( _taskGuard_flags & Flags.workInProgress && !( _taskGuard_flags & Flags.done ) );

			// Finish
			const ubyte endData = atomicFetchThenOr( _taskGuard_flags, Flags.done );

			// If there were tasks waiting for this guard, issue them
			if ( endData & Flags.dependentTasksWaiting )
				_taskGuard_issueWaitingTasks( );
		}

	private:
		pragma( inline ) final TaskGuardId _taskGuard_id( ) {
			return &_taskGuard_flags;
		}

		/// Issue tasks that were waiting for this task to finish
		final void _taskGuard_issueWaitingTasks( ) {

			synchronized ( taskGuardResolvingMutex ) {
				assert( _taskGuard_id in taskGuardDependentsList );

				foreach ( ctx; taskGuardDependentsList[ _taskGuard_id ] )
					taskManager.issueTask( ctx );

				taskGuardDependentsList.remove( _taskGuard_id );
			}
		}
}

enum TaskGuardFlags : ubyte {
	done = 1 << 0,
	workInProgress = 1 << 1,
	dependentTasksWaiting = 1 << 2,
	contextSet = 1 << 3,
	error = 1 << 4
}

static __gshared Mutex taskGuardResolvingMutex;

/// Map of contexts that are waiting for a given task guard
static __gshared TaskContext[ ][ TaskGuardId ] taskGuardDependentsList;

enum _init = HookAppInit.hook!( { //
		taskGuardResolvingMutex = new Mutex; //
	} );
