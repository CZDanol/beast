module beast.corelib.type.bool_;

import beast.corelib.type.toolkit;
import beast.code.data.var.tmplocal;

void initialize_Bool( ref CoreLibrary_Types tp ) {
	Symbol[ ] mem;

	mem ~= Symbol_PrimitiveMemberRuntimeFunction.newPrimitiveCtor( tp.Bool ); // Implicit constructor
	mem ~= Symbol_PrimitiveMemberRuntimeFunction.newPrimitiveCopyCtor( tp.Bool ); // Copy constructor
	mem ~= Symbol_PrimitiveMemberRuntimeFunction.newNoopDtor( tp.Bool ); // Destructor

	// Operator overloads
	mem ~= Symbol_PrimitiveMemberRuntimeFunction.newPrimitiveAssignOp( tp.Bool ); // a = b

	// a || b
	mem ~= new Symbol_PrimitiveMemberRuntimeFunction( ID!"#operator", tp.Bool, tp.Bool, //
			ExpandedFunctionParameter.bootstrap( enm.operator.binOr, tp.Bool ), //
			( cb, inst, args ) { //
				// 0th operator is Operator.binOr
				auto var = new DataEntity_TmpLocalVariable( coreLibrary.type.Bool, false );
				cb.build_localVariableDefinition( var );

				// We construct the local variable based on the if result
				cb.build_if( inst, //
					&var.expectResolveIdentifier( ID!"#ctor" ).resolveCall( null, true, coreEnum.xxctor.opAssign, coreConst.true_.dataEntity ).buildCode, //
					&var.expectResolveIdentifier( ID!"#ctor" ).resolveCall( null, true, coreEnum.xxctor.opAssign, args[ 1 ] ).buildCode );

				// Result expression is var
				var.buildCode( cb );
			} );

	// a && b
	mem ~= new Symbol_PrimitiveMemberRuntimeFunction( ID!"#operator", tp.Bool, tp.Bool, //
			ExpandedFunctionParameter.bootstrap( enm.operator.binAnd, tp.Bool ), //
			( cb, inst, args ) { //
				/// args[ 0 ] is Operator.binAnd
				auto var = new DataEntity_TmpLocalVariable( coreLibrary.type.Bool, false );
				cb.build_localVariableDefinition( var );

				// We construct the local variable based on the if result
				cb.build_if( inst, //
					&var.expectResolveIdentifier( ID!"#ctor" ).resolveCall( null, true, coreEnum.xxctor.opAssign, args[ 1 ] ).buildCode, //
					&var.expectResolveIdentifier( ID!"#ctor" ).resolveCall( null, true, coreEnum.xxctor.opAssign, coreConst.false_.dataEntity ).buildCode );

				// Result expression is var
				var.buildCode( cb );
			} );

	// !a
	mem ~= new Symbol_PrimitiveMemberRuntimeFunction( ID!"#operator", tp.Bool, tp.Bool, //
			ExpandedFunctionParameter.bootstrap( enm.operator.preNot ), //
			( cb, inst, args ) { //
				/// args[ 0 ] is Operator.binAnd

				auto var = new DataEntity_TmpLocalVariable( coreLibrary.type.Bool, false );
				cb.build_localVariableDefinition( var );
				cb.build_primitiveOperation( BackendPrimitiveOperation.boolNot, var, inst );

				// Result expression is var
				var.buildCode( cb );
			} );

	tp.Bool.valueIdentificationStringFunc = ( ptr ) { return ptr.readPrimitive!bool ? "true" : "false"; };
	tp.Bool.initialize( mem );
}
