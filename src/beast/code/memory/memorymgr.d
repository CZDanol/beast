module beast.code.memory.memorymgr;

import beast.code.toolkit;
import beast.code.memory.block;
import beast.code.memory.ptr;
import core.sync.rwmutex : ReadWriteMutex;
import beast.code.hwenv.hwenv;
import beast.util.uidgen;
import std.container.rbtree : RedBlackTree;
import std.algorithm.searching : until;

/// MemoryManager is in charge of all @ctime-allocated memory
__gshared MemoryManager memoryManager;

/// One of the root classes of @ctime
/// Is in charge of all @ctime-allocated memory
final class MemoryManager {

	public:
		this( ) {
			pointerList_ = new RedBlackTree!MemoryPtr;
			pointerListMutex_ = new ReadWriteMutex;
			blockListMutex_ = new ReadWriteMutex;
		}

	public:
		MemoryBlock allocBlock( size_t bytes ) {
			import std.array : insertInPlace;

			debug assert( !finished_ );
			assert( bytes, "Trying to allocate 0 bytes" );

			// We round the bytes to pointerSize so all the data is aligned
			bytes = ( bytes + hardwareEnvironment.pointerSize - 1 ) / hardwareEnvironment.pointerSize * hardwareEnvironment.pointerSize;
			assert( bytes % hardwareEnvironment.pointerSize == 0 );

			MemoryPtr endPtr = MemoryPtr( hardwareEnvironment.pointerSize /* != 0 to prevent allocating on a null pointer, pointerSize so it is aligned */  );
			MemoryBlock result;

			synchronized ( blockListMutex_.writer ) {
				debug synchronized ( this ) {
					debug assert( context.session in activeSessions_, "Invalid session" );
					debug assert( context.jobId == activeSessions_[ context.session ], "Session does not match with the jobId" );
				}

				// First, we try inserting the new block between currently existing memory blocks
				foreach ( i, block; mmap_ ) {
					if ( endPtr + bytes <= block.startPtr ) {
						result = new MemoryBlock( endPtr, bytes );

						mmap_.insertInPlace( i, result );
						//mmap_ = mmap_[ 0 .. i ] ~ result ~ mmap_[ i .. $ ];
						assert( mmap_[ i ] is result );
						assert( mmap_[ i + 1 ] is block );

						break;
					}

					endPtr = block.endPtr;
				}

				if ( !result ) {
					// If it fails, we add a new memory after all existing blocks
					benforce( endPtr <= MemoryPtr( hardwareEnvironment.memorySize ), E.outOfMemory, "Failed to allocate %s bytes".format( bytes ) );

					assert( mmap_.length == 0 || mmap_[ $ - 1 ].endPtr == endPtr );

					result = new MemoryBlock( endPtr, bytes );
					mmap_ ~= result;
				}

				debug {
					MemoryBlock prevBlock = mmap_[ 0 ];
					foreach ( i, block; mmap_[ 1 .. $ ] ) {
						assert( block.startPtr >= prevBlock.endPtr );
						prevBlock = block;
					}
				}
			}

			assert( result.startPtr.val !in context.sessionMemoryBlocks );
			context.sessionMemoryBlocks[ result.startPtr.val ] = result;

			return result;
		}

		MemoryBlock allocBlock( size_t bytes, MemoryBlock.Flags flags ) {
			MemoryBlock result = allocBlock( bytes );
			result.flags |= flags;
			return result;
		}

		MemoryPtr alloc( size_t bytes ) {
			return allocBlock( bytes ).startPtr;
		}

		MemoryPtr alloc( size_t bytes, MemoryBlock.Flags flags, string identifier = null ) {
			MemoryBlock result = allocBlock( bytes );
			result.flags |= flags;
			result.identifier = identifier;
			return result.startPtr;
		}

		void free( MemoryPtr ptr ) {
			debug assert( !finished_ );

			checkNullptr( ptr );

			synchronized ( blockListMutex_.writer ) {
				debug synchronized ( this ) {
					debug assert( context.session in activeSessions_, "Invalid session" );
					debug assert( context.jobId == activeSessions_[ context.session ], "Session does not match with the jobId" );
				}

				foreach ( i, block; mmap_ ) {
					if ( block.startPtr == ptr ) {
						benforce( block.session == context.session, E.protectedMemory, "Cannot free memory block owned by a different session (%#x)".format( ptr.val ) );

						mmap_ = mmap_[ 0 .. i ] ~ mmap_[ i + 1 .. $ ];

						assert( block.startPtr.val in context.sessionMemoryBlocks );
						context.sessionMemoryBlocks.remove( block.startPtr.val );

						// We also have to unmark pointers in the block
						context.sessionPointers.removeKey( pointersInSessionBlock( block ) );

						return;
					}
					else
						benforce( block.startPtr < ptr || block.endPtr >= ptr, E.invalidMemoryOperation, "You have to call free on memory block start pointer, not any pointer in the memory block (%#x)".format( ptr.val ) );
				}
			}

			berror( E.invalidMemoryOperation, "Cannot free - memory with this pointer is not allocated (%#x)".format( ptr.val ) );
		}

		void free( MemoryBlock block ) {
			free( block.startPtr );
		}

		// Frees the block in the GC cleanup when finishing memoryMgr
		private void sudoFree( MemoryBlock targetBlock ) {
			debug assert( finished_ );

			foreach ( i, block; mmap_ ) {
				if ( block !is targetBlock )
					continue;

				mmap_ = mmap_[ 0 .. i ] ~ mmap_[ i + 1 .. $ ];
				return;
			}

			assert( 0 );
		}

	public:
		/// Tries to write data at a given pointer. Might fail.
		void write( MemoryPtr ptr, const( ubyte )[ ] data ) {
			import core.stdc.string : memcpy;

			debug assert( !finished_ );

			MemoryBlock block = findMemoryBlock( ptr );

			debug benforce( block.session == context.session, E.protectedMemory, "Cannot write to memory block owned by a different session (block %s; current %s)".format( block.session, context.session ) );
			benforce( block.session == context.session, E.protectedMemory, "Cannot write to memory block owned by a different session" );
			benforce( ptr + data.length <= block.endPtr, E.invalidMemoryOperation, "Memory write outside of allocated block bounds" );
			benforce( !( block.flags & MemoryBlock.Flag.runtime ), E.runtimeMemoryManipulation, "Cannnot write to runtime memory (%s)".format( block.identificationString ) );

			debug synchronized ( this ) {
				debug assert( block.session in activeSessions_ );
				assert( context.session == block.session );
				debug assert( context.jobId == activeSessions_[ block.session ] );
			}

			debug assert( !block.wasReadOutsideContext, "Block was read outside context before write (race condition might occur)" );

			// We're writing to a memory that is accessed only from one thread (context), so no mutexes should be needed
			memcpy( block.data + ( ptr - block.startPtr ).val, data.ptr, data.length );
		}

		/// "Reads" given amount of bytes from memory and returns pointer to them (it doesn't actually read, just does some checks)
		const( ubyte )[ ] read( const MemoryPtr ptr, size_t bytes ) {
			MemoryBlock block = findMemoryBlock( ptr );

			// Either the session the block was created in is no longer active (-> the block cannot be changed anymore), or the session belongs to the same task context as current session (meaning it is the same session or a derived one)
			// Other cases should not happen
			debug synchronized ( this ) {
				debug assert( block.session !in activeSessions_ || activeSessions_[ block.session ] == context.jobId );
				assert( !( block.flags & MemoryBlock.Flag.local ) || block.session == context.session, "Local memory block is accessed from a different session" );
			}

			benforce( ptr + bytes <= block.endPtr, E.invalidMemoryOperation, "Memory read outside of allocated block bounds" );
			benforce( !( block.flags & MemoryBlock.Flag.runtime ), E.runtimeMemoryManipulation, "Cannnot read from runtime memory (%s)".format( block.identificationString ) );

			debug if ( context.jobId != block.jobId )
				block.wasReadOutsideContext = true;

			return ( block.data + ( ptr - block.startPtr ).val )[ 0 .. bytes ];
		}

	public:
		/// Finds memory block containing ptr or throws segmentation fault
		MemoryBlock findMemoryBlock( const MemoryPtr ptr ) {
			checkNullptr( ptr );

			synchronized ( blockListMutex_.reader ) {
				foreach ( block; mmap_ ) {
					if ( ptr >= block.startPtr && ptr < block.endPtr )
						return block;
				}
			}

			berror( E.invalidPointer, "There's no memory allocated on a given address" );
			assert( 0 );
		}

	public:
		void markAsPointer( const MemoryPtr ptr ) {
			debug assert( !finished_ );

			// context.sessionPointers is per-context and context can be acessed from one thread only, so we don't need mutexes
			benforce( ptr.val % hardwareEnvironment.pointerSize == 0, E.unalignedMemory, "Pointers must be memory-aligned" );
			benforce( ptr !in context.sessionPointers, E.corruptMemory, "Corrupt memory: dual initialization of a pointer" );
			context.sessionPointers.insert( ptr );
		}

		void unmarkAsPointer( const MemoryPtr ptr ) {
			debug assert( !finished_ );

			benforce( ptr in context.sessionPointers, E.corruptMemory, "Corrupt memory: destroying unexisting pointer" );
			context.sessionPointers.removeKey( ptr );
		}

		/// Returns if given memory has been marked as pointer previously
		bool isPointer( const MemoryPtr ptr ) {
			debug assert( finished_ );
			return ptr in pointerList_;
		}

		/// Returns next nearest memory pointer (where nextPtr > ptr) or NULL if there is no such pointer
		MemoryPtr nextPointer( const MemoryPtr ptr ) {
			debug assert( finished_ );

			auto range = pointerList_.upperBound( ptr );
			return range.empty ? MemoryPtr( 0 ) : range.front;
		}

		auto pointersInBlock( MemoryBlock block ) {
			debug assert( finished_ );
			return pointerList_.upperBound( block.startPtr - 1 ).until!( x => x >= block.endPtr );
		}

	protected:
		/// Returns range of MemoryPtr s - pointer in given block
		/// Works only for blocks allocated by current session
		auto pointersInSessionBlock( MemoryBlock block ) {
			assert( block.session == context.session );
			return context.sessionPointers.upperBound( block.startPtr - 1 ).until!( x => x >= block.endPtr );
		}

	public:
		void startSession( ) {
			debug assert( !finished_ );
			static __gshared UIDGenerator sessionUIDGen;

			size_t session = sessionUIDGen( );

			context.sessionMemoryBlockStack ~= context.sessionMemoryBlocks;
			context.sessionMemoryBlocks = null;

			context.sessionStack ~= context.session;
			context.session = session;

			context.sessionPointersStack ~= context.sessionPointers;
			context.sessionPointers = new RedBlackTree!MemoryPtr;

			debug synchronized ( this )
				activeSessions_[ session ] = context.jobId;
		}

		void endSession( ) {
			debug assert( !finished_ );

			// "GC" cleanup blocks at session end
			{
				MemoryBlock[ ] list;

				foreach ( MemoryBlock block; context.sessionMemoryBlocks ) {
					if ( block.isDoNotGCAtSessionEnd )
						list ~= block;
				}

				while ( list.length ) {
					MemoryBlock block = list[ $ - 1 ];
					list.length--;

					auto pointersInBlock = pointersInSessionBlock( block );
					assert( ( !block.isLocal && !block.isRuntime ) || pointersInBlock.empty, "There should be no pointers in local or runtime memory block on session end" );

					foreach ( ptr; pointersInBlock ) {
						MemoryBlock block2 = ptr.block;
						if ( block2.isDoNotGCAtSessionEnd )
							continue;

						block2.markDoNotGCAtSessionEnd;
						list ~= block2;
					}
				}

				// We have to copy blocks to be deleted, because sessionMemoryBlocks shrinks as blocks are freed
				foreach ( MemoryBlock block; context.sessionMemoryBlocks ) {
					if ( !block.isDoNotGCAtSessionEnd )
						list ~= block;
					else
						assert( !block.isLocal );
				}

				foreach ( block; list )
					free( block );
			}

			debug synchronized ( this ) {
				debug assert( context.session in activeSessions_, "Invalid session" );
				debug assert( context.jobId == activeSessions_[ context.session ], "Session does not match with the jobId" );

				activeSessions_.remove( context.session );
			}

			synchronized ( pointerListMutex_.writer )
				pointerList_.insert( context.sessionPointers[ ] );

			if ( context.sessionStack.length ) {
				context.session = context.sessionStack[ $ - 1 ];
				context.sessionStack.length--;

				context.sessionPointers = context.sessionPointersStack[ $ - 1 ];
				context.sessionPointersStack.length--;

				context.sessionMemoryBlocks = context.sessionMemoryBlockStack[ $ - 1 ];
				context.sessionMemoryBlockStack.length--;
			}
			else {
				context.session = 0;
				debug context.sessionMemoryBlocks = null;
			}
		}

		/// Utility function for use with with( memoryManager.session ) { xxx } - calls startSession on beginning and endSession on end
		auto session( ) {
			static struct Result {
				~this( ) {
					memoryManager.endSession( );
				}

				debug size_t prevSession, newSession;

			}

			debug auto prevSession = context.session;
			startSession( );

			debug {
				return Result( prevSession, context.session );
			}
			else
				return Result( );
		}

	public:
		void checkNullptr( MemoryPtr ptr ) {
			benforce( ptr.val != 0, E.nullPointer, "Null pointer" );
		}

	public:
		/// Disables all further memory manipulations
		void finish( ) {
			debug finished_ = true;
			debug assert( activeSessions_.length == 0 );

			// GC all unreferenced blocks
			{
				MemoryBlock[ ] list;

				foreach ( block; mmap_ ) {
					assert( !block.isLocal, "Local blocks should have been freed already" );

					if ( block.isReferenced )
						list ~= block;
				}

				while ( list.length ) {
					MemoryBlock block = list[ $ - 1 ];
					list.length--;

					foreach ( ptr; pointersInBlock( block ) ) {
						MemoryBlock block2 = ptr.readMemoryPtr.block;

						if ( block2.isReferenced )
							continue;

						block2.markReferenced;
						list ~= block2;
					}
				}

				// Now we use the list as free list
				foreach ( block; mmap_ ) {
					if ( !block.isReferenced )
						list ~= block;
				}

				foreach ( block; list )
					sudoFree( block );
			}
		}

	public:
		/// Returns range for iterating memory blocks
		auto memoryBlocks( ) {
			debug assert( finished_, "Cannot iterate blocks when not finished" );

			struct Result {

				public:
					MemoryBlock front( ) {
						return mgr_.mmap_[ i_ ];
					}

					bool empty( ) {
						return i_ >= mgr_.mmap_.length;
					}

					void popFront( ) {
						i_++;
					}

				private:
					MemoryManager mgr_;
					size_t i_;

			}

			return Result( this );
		}

	private:
		debug bool finished_;
		/// Sorted array of memory blocks
		MemoryBlock[ ] mmap_; // TODO: Better implementation
		/// Map of session id -> jobId
		debug static __gshared size_t[ size_t ] activeSessions_;

		ReadWriteMutex blockListMutex_, pointerListMutex_;

		/// List of addresses that contain pointers
		/// Data are first stored in context.sessionPointers, to this list, they're added after session end
		RedBlackTree!MemoryPtr pointerList_;

}
