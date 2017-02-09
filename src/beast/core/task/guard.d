module beast.core.task.guard;

import core.sync.mutex;
import beast.toolkit;
import beast.util.identifiable;
import beast.core.task.context;

alias TaskGuardId = shared ubyte*;

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
	//static assert( is( typeof( this ) : Identifiable ), "TaskGuards can only be mixed into classes that implement Identifiable interface" );
	static assert( __traits( hasMember, typeof( this ), _taskGuard_executeFunctionName ), "You must implement 'void " ~ fullyQualifiedName!( typeof( this ) ) ~ "." ~ _taskGuard_executeFunctionName ~ "()'." );

	import beast.core.task.context : TaskContext;
	import beast.core.task.guard : TaskGuardId;
	import beast.util.identifiable;
	import std.traits : fullyQualifiedName;

private:
	shared ubyte _taskGuard_flags;

	/// Context this task is being processed in
	TaskContext _taskGuard_context;

	enum _taskGuard_executeFunctionName = "execute_" ~ guardName;

public:
	/// All-in-one function. If the task is done, returns its result. If not, either starts working on it or waits till it's done (and eventually throws poisoning error). Checks for circular dependencies
	void _taskGuard_func( ) {
		import beast.util.atomic : atomicFetchThenOr, atomicStore, atomicOp;
		import beast.core.task.guard : Flags = TaskGuardFlags, taskGuardDependentsList, taskGuardResolvingMutex, BeastErrorException;

		const ubyte initialFlags = atomicFetchThenOr( _taskGuard_flags, Flags.workInProgress );

		if ( initialFlags & Flags.error )
			throw new BeastErrorException( "#poison" );

		// Task is already done, no problem
		if ( initialFlags & Flags.done )
			return;

		// If not, we have to check if it is work in progress
		if ( initialFlags & Flags.workInProgress ) {
			taskGuardResolvingMutex.lock( );

			// Mark that there are tasks waiting for it
			const ubyte wipFlags = atomicFetchThenOr( _taskGuard_flags, Flags.dependentTasksWaiting );

			// It is possible that the task finished/failed between initialFlags and wipFlags fetches, we need to check for that
			if ( wipFlags & Flags.error ) {
				taskGuardResolvingMutex.unlock( );
				throw new BeastErrorException( "#poison" );
			}

			if ( wipFlags & Flags.done ) {
				taskGuardResolvingMutex.unlock( );
				return;
			}

			// Check for circular dependencies
			{
				// Wait for the worker context to mark itself to this guard (this is not done atomically)
				while ( !( _taskGuard_flags & Flags.contextSet ) ) {
					// TODO: Benchmark this
				}

				TaskContext ctx = _taskGuard_context;
				const TaskContext thisContext = context.taskContext;
				while ( ctx ) {
					if ( ctx is thisContext ) {
						// Walk the dependencies again, this time record contexts we were walking
						TaskContext ctx2 = _taskGuard_context;
						string[ ] loopList = [ ctx2.blockingTaskGuardIdentificationString_ ];
						while ( ctx2 !is thisContext ) {
							ctx2 = ctx2.blockingContext_;
							loopList ~= ctx2.blockingTaskGuardIdentificationString_;
						}

						taskGuardResolvingMutex.unlock( );
						berror( E.dependencyLoop, "Circular dependency loop: " ~ loopList.joiner( " - " ).to!string );
					}

					ctx = ctx.blockingContext_;
				}
			}

			// Mark current context to be woken when the task is finished
			assert( cast( bool )( _taskGuard_id in taskGuardDependentsList ) == cast( bool )( wipFlags & Flags.dependentTasksWaiting ) );

			if ( wipFlags & Flags.dependentTasksWaiting )
				taskGuardDependentsList[ _taskGuard_id ] ~= context.taskContext;
			else
				taskGuardDependentsList[ _taskGuard_id ] = [ context.taskContext ];

			// Mark current context as waiting on this task	(for circular dependency checks)
			context.taskContext.blockingContext_ = _taskGuard_context;
			context.taskContext.blockingTaskGuardIdentificationString_ = identificationString ~ "." ~ guardName;

			// Yield the current context (we have to unlock dependentsMutex after yielding, before could screw things up -- the context could be woken before yelding)
			context.taskContext.yield( { taskGuardResolvingMutex.unlock( ); } );

			synchronized ( taskGuardResolvingMutex )
				context.taskContext.blockingContext_ = null;

			assert( _taskGuard_flags & Flags.done );

			if ( _taskGuard_flags & Flags.error )
				throw new BeastErrorException( "#posion" );

			// After this context is resumed, the task should be done
			return;
		}

		_taskGuard_context = context.taskContext;
		atomicOp!( "|=" )( _taskGuard_flags, Flags.contextSet );

		try {
			__traits( getMember, this, _taskGuard_executeFunctionName )( );
		}
		catch ( BeastErrorException exc ) {
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

		return;
	}

	// Give the taskGuard function an useful name
	mixin( "alias enforceDone_" ~ guardName ~ " = _taskGuard_func;" );

private:
	pragma( inline ) @property TaskGuardId _taskGuard_id( ) {
		return &_taskGuard_flags;
	}

	/// Issue tasks that were waiting for this task to finish
	void _taskGuard_issueWaitingTasks( ) {
		import beast.util.atomic : atomicFetchThenOr;
		import beast.core.task.guard : taskGuardDependentsList, taskGuardResolvingMutex;

		synchronized ( taskGuardResolvingMutex ) {
			assert( _taskGuard_id in taskGuardDependentsList );

			foreach ( task; taskGuardDependentsList[ _taskGuard_id ] )
				taskManager.issueTask( task );

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
