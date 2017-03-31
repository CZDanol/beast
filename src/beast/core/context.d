module beast.core.context;

import beast.core.project.project;
import beast.core.task.taskmgr;
import beast.code.lex.lexer;
import beast.code.memory.block;
import beast.core.task.context;
import beast.core.error.guard;
import beast.core.task.worker;
import beast.code.data.scope_.scope_;
import std.container.rbtree;
import beast.code.memory.ptr : MemoryPtr;

/// General project-related data
__gshared Project project;

/// TaskManager is in charge of parallelism and work planning
__gshared TaskManager taskManager;

class ContextData {

	public:
		/// Currently working lexer
		Lexer lexer;

	public:
		/// Id of the current job (task)
		size_t jobId;

		/// Sessions separate code executing into logical units. It is not possible to write to memory of other sessions.
		/// Do not edit yourself, call memoryManager.startSession() and memoryManager.endSession()
		size_t session;

		/// Sessions can be nested (they're absolutely independent though); last session in the stack is saved in the session variable for speed up
		size_t[ ] sessionStack;

		/// List of all memory blocks allocated in the current session (mapped by src ptr)
		MemoryBlock[ size_t ] sessionMemoryBlocks;

		/// Memory blocks allocated by the sessions in the stack
		MemoryBlock[ size_t ][ ] sessionMemoryBlockStack;

		/// Pointers created in the current session
		RedBlackTree!MemoryPtr sessionPointers;

		RedBlackTree!MemoryPtr[] sessionPointersStack;

	public:
		/// This is to prevent passing scopes aroung all the time
		DataScope currentScope;

		DataScope[ ] scopeStack;

	public:
		/// Jobs that are about to be issued as soon as the context finishes its current job (or current taskGuard)
		TaskContext.Job[ ] delayedIssuedJobs;

		TaskContext.Job[ ][ ] delayedIssuedJobsStack;

	public:
		/// This number is increased with every compile-time function call and decreased by every return
		size_t currentRecursionLevel;

	public:
		/// TaskContext of the current running task
		TaskContext taskContext;
		ErrorGuardData errorGuardData;

}

/// Context-local (fiber-local) pointer to working context
ContextData context;
