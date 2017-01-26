module beast.lex.token;

import beast.lex.toolkit;
import beast.project.codesource;
import beast.project.codelocation;

final class Token {

public:
	enum Type {
		_noToken,
		identifier,
		keyword,
		special
	}

	enum Keyword {
		_noKeyword,
		class_,
		if_,
		else_
	}

	enum Operator {
		plus,
		minus,
		asterisk,
		slash,
		dollar
	}

	enum Special {
		eof,
		lBracket,
		rBracket,
		lBrace,
		rBrace,
		lParent,
		rParent
	}

public:
	this( Special special ) {
		this( );
		type = Type.special;
		data.special = special;
	}

	this( Identifier identifier ) {
		this( );
		type = Type.identifier;
		data.identifier = identifier;
	}

	this( Keyword keyword ) {
		this( );
		type = Type.keyword;
		data.keyword = keyword;
	}

public:
	CodeLocation codeLocation;
	const Type type;

public:
	@property Identifier identifier( ) {
		assert( type == Type.identifier );
		return data.identifier;
	}

	@property Keyword keyword( ) {
		assert( type == Type.keyword );
		return data.keyword;
	}

	@property Special special( ) {
		assert( type == Type.special );
		return data.special;
	}

private:
	this( ) {
		assert( lexer );

		codeLocation.source = lexer.source;
		codeLocation.startPos = lexer.tokenStartPos;
		codeLocation.length = lexer.pos - lexer.tokenStartPos;

		type = Type._noToken;
	}

private:
	union Data {
		Identifier identifier;
		Keyword keyword;
		Special special;
	}

	Data data;

}
