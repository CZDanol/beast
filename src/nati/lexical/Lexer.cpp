#include "Lexer.h"

namespace nati {

	__thread Lexer *lexer = nullptr;

	void Lexer::setSource( const std::string &source ) {
		source_ = source + '\0';
		sourceIterator_ = source_.begin();
	}

	const Token &Lexer::token() const {
		return token_;
	}

	bool Lexer::isToken( TokenType type ) const {
		return token_.type == type;
	}

	void Lexer::expectToken( TokenType type ) const {
		// TODO
	}

	void Lexer::nextToken() {
		// Clear the accumulator
		accumulator_.str( std::string() );
		accumulator_.clear();

		token_.type = TokenType::none;

		state_ = LexerState::init;

		while( true ) {
			char ch = *sourceIterator_; ///< Currently processed character
			bool readNextChar = true;

			switch( state_ ) {

				case LexerState::init: {
					if( isalpha( ch ) || ch == '#' || ch == '_' ) {
						state_ = LexerState::identifierOrKeyword;
						accumulator_ << ch;
						break;
					}

					if( isspace( ch ) ) {
						break;
					}

					switch( ch ) {

						case '\0': {
							token_.type = TokenType::eof;
							readNextChar = false;
							break;
						}

						default: {
							// TODO throw error
							break;
						}

					}
					break;
				}

				case LexerState::identifierOrKeyword: {
					if( isalnum( ch ) || ch == '_' ) {
						accumulator_ << ch;
						break;
					}

					Identifier ident( accumulator_.str() );
					if( ident.keyword() == Keyword::notAKeyword ) {
						token_.type = TokenType::identifier;
						token_.identifier = ident;

					} else {
						token_.type = TokenType::keyword;
						token_.keyword = ident.keyword();

					}
					readNextChar = false;
					break;
				}

			}

			if( readNextChar )
				sourceIterator_++;

			if( token_ )
				return;
		}
	}

}
