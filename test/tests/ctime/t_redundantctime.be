module t_redundantctime;

Void main() {
	@ctime Int! i = 4;

	print( i ); //! stdout: 4

	@ctime {
		i = 5;
		// TODO: make this work somehow?
		@ctime i = i + 1; // ! warning: duplicitModification
	}

	print( i ); //! stdout: 6
}