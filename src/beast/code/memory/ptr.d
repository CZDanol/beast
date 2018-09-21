module beast.code.memory.ptr;

import beast.code.toolkit;
import beast.code.memory.block;
import beast.code.memory.memorymgr;
import beast.code.semantic.type.type;
import beast.code.hwenv.hwenv;
import core.stdc.string : memcpy;
import std.algorithm.searching : all;
import std.range : repeat;

enum nullMemoryPtr = MemoryPtr(0);

/// Pointer to Beast interpret memory (target machine memory)
struct MemoryPtr {

public:
	size_t val;

public:
	/// Returns memory block corresponding to this pointer
	MemoryBlock block() const {
		return memoryManager.findMemoryBlock(this);
	}

public:
	/// Writes a "primitive" (direct data copy - usually you should use hwenv) into given pointer
	MemoryPtr writePrimitive(T)(const auto ref T data) const {
		return write(&data, data.sizeof);
	}

	MemoryPtr write(const void* data, size_t bytes) const {
		return write(cast(const(ubyte)[]) data[0 .. bytes]);
	}

	MemoryPtr write(const(ubyte)[] data) const {
		memoryManager.write(this, data);
		return this;
	}

	MemoryPtr write(MemoryPtr data, size_t bytes) const {
		memoryManager.write(this, memoryManager.read(data, bytes));
		return this;
	}

	/// Reads a "primitive" (direct data read - usually you should use hwenv) from a given pointer
	T readPrimitive(T)() const {
		return *(cast(T*) memoryManager.read(this, T.sizeof));
	}

	const(ubyte)[] read(size_t bytes) const {
		return memoryManager.read(this, bytes);
	}

public:
	/// Interprets the value as a Type variable
	Symbol_Type readType() const {
		Symbol_Type type = typeUIDKeeper[readPrimitive!(typeUIDKeeper.I)];
		benforce(type !is null, E.invalidPointer, "Variable does not point to a valid type");
		return type;
	}

	void writeMemoryPtr(MemoryPtr ptr) const {
		writeSizeT(ptr.val);
	}

	MemoryPtr readMemoryPtr() const {
		return MemoryPtr(readSizeT);
	}

	/// Writes size_t but maximally up to hardwareEnvironment.pointerSize
	void writeSizeT(size_t val) const {
		auto ptrSize = hardwareEnvironment.effectivePointerSize;
		write(&val, ptrSize);

		if (ptrSize > size_t.sizeof)
			MemoryPtr(val + size_t.sizeof).write(repeat(cast(ubyte) 0, ptrSize - size_t.sizeof).array);
	}

	size_t readSizeT() const {
		size_t result;
		auto ptrSize = hardwareEnvironment.effectivePointerSize;
		memcpy(&result, read(ptrSize).ptr, ptrSize);

		benforce(ptrSize <= size_t.sizeof || MemoryPtr(val + size_t.sizeof).read(ptrSize - size_t.sizeof).all!(x => x == 0), E.invalidPointer, "Pointer value too big for the compiler machine to handle");

		return result;
	}

public:
	void free() {
		memoryManager.free(this);
	}

public:
	bool dataEquals(MemoryPtr other, size_t comparedLength) const {
		import core.stdc.string : memcmp;

		return memcmp(memoryManager.read(this, comparedLength).ptr, memoryManager.read(other, comparedLength).ptr, comparedLength) == 0;
	}

public:
	int opCmp(const MemoryPtr other) const {
		if (val > other.val)
			return 1;
		else if (val < other.val)
			return -1;
		else
			return 0;
	}

	bool isNull() const {
		return val == 0;
	}

public:
	MemoryPtr opBinary(string op)(const MemoryPtr other) const if (op == "+" || op == "-") {
		return mixin("MemoryPtr( val " ~ op ~ " other.val )");
	}

	MemoryPtr opBinary(string op)(size_t other) const if (op == "+" || op == "-") {
		return mixin("MemoryPtr( val " ~ op ~ " other )");
	}

public:
	string toString() const {
		return "0x%x".format(val);
	}

	bool opCast(T : bool)() const {
		return val != 0;
	}

}
