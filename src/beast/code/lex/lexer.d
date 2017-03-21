module beast.code.lex.lexer;

import beast.code.lex.toolkit;
import beast.core.project.codesource;
import beast.core.project.codelocation;

pragma( inline ) {
	/// Context-local lexer instance
	Lexer lexer( ) {
		return context.lexer;
	}

	/// Current token of the current context lexer
	Token currentToken( ) {
		assert( lexer.currentToken );
		return lexer.currentToken;
	}

	/// Commands current context lexer to scan for next token and returns it
	Token getNextToken( ) {
		return lexer.getNextToken;
	}
}

final class Lexer {

	public:
		this( CodeSource source ) {
			source_ = source;
			line_ = 1;
		}

	public:
		CodeSource source( ) {
			return source_;
		}

		/// Position in source file
		size_t pos( ) {
			return pos_;
		}

		/// The last parsed token
		Token currentToken( ) {
			return currentToken_;
		}

		/// List of all tokens generated by the lexer
		Token[ ] generatedTokens( ) {
			return generatedTokens_;
		}

		/// Parses next token from the source file
		Token getNextToken( ) {
			Token result = _getNextToken( );
			result.previousToken = currentToken_;
			currentToken_ = result;
			generatedTokens_ ~= result;
			return result;
		}

		private Token _getNextToken( ) {
			assert( lexer is this );

			const auto _gd = ErrorGuard( CodeLocation( source_, tokenStartPos_, pos_ - tokenStartPos_ ) );

			State state = State.init;

			while ( true ) {
				currentChar_ = pos_ < source_.content.length ? source_.content[ pos_ ] : EOF;

				/*
			writeln( "char ", currentChar_, " state ", state );*/

				if ( currentChar_ == '\n' )
					line_++;

				final switch ( state ) {

				case State.init: {
						tokenStartPos_ = pos_;

						switch ( currentChar_ ) {

						case 'a': .. case 'z': // Identifier or keyword
						case 'A': .. case 'Z':
						case '#', '_': {
								state = State.identifierOrKeyword;
								stringAccumulator ~= currentChar_;
								pos_++;
							}
							break;

						case ' ', '\t', '\n': { // Whitespace
								pos_++;
							}
							break;

						case '/': {
								state = State.slashPrefix;
								pos_++;
							}
							break;

						case ':': {
								state = State.colonPrefix;
								pos_++;
							}
							break;

						case '&': {
								state = State.andPrefix;
								pos_++;
							}
							break;

						case '|': {
								state = State.orPrefix;
								pos_++;
							}
							break;

						case '=': {
								pos_++;
								return new Token( Token.Operator.assign );
							}

						case '.': {
								pos_++;
								return new Token( Token.Special.dot );
							}

						case ',': {
								pos_++;
								return new Token( Token.Special.comma );
							}

						case ';': {
								pos_++;
								return new Token( Token.Special.semicolon );
							}

						case '@': {
								pos_++;
								return new Token( Token.Special.at );
							}

						case '?': {
								pos_++;
								return new Token( Token.Operator.questionMark );
							}

						case '!': {
								pos_++;
								return new Token( Token.Operator.exclamationMark );
							}

						case '(': {
								pos_++;
								return new Token( Token.Special.lParent );
							}

						case ')': {
								pos_++;
								return new Token( Token.Special.rParent );
							}

						case '{': {
								pos_++;
								return new Token( Token.Special.lBrace );
							}

						case '}': {
								pos_++;
								return new Token( Token.Special.rBrace );
							}

						case EOF: {
								return new Token( Token.Special.eof );
							}

						default:
							error_unexpectedCharacter( );

						}
					}
					break;

				case State.identifierOrKeyword: {
						switch ( currentChar_ ) {

						case 'a': .. case 'z': // Continuation of identifier/keyword
						case 'A': .. case 'Z':
						case '0': .. case '9':
						case '_': {
								stringAccumulator ~= currentChar_;
								pos_++;
							}
							break;

						default: {
								Identifier id = Identifier( stringAccumulator );
								stringAccumulator = null;
								state = State.init;

								return id.keyword == Token.Keyword._noKeyword ? new Token( id ) : new Token( id.keyword );
							}

						}

					}
					break;

				case State.slashPrefix: {
						if ( currentChar_ == '/' ) {
							state = State.singleLineComment;
							pos_++;
						}
						else if ( currentChar_ == '*' ) {
							assert( multiLineCommentNestingLevel_ == 0 );
							state = State.multiLineComment;
							multiLineCommentNestingLevel_ = 1;
							pos_++;
						}
						else
							return new Token( Token.Operator.divide );
					}
					break;

				case State.colonPrefix: {
						if ( currentChar_ == '=' ) {
							pos_++;
							return new Token( Token.Operator.colonAssign );
						}
						else
							return new Token( Token.Special.colon );
					}

				case State.andPrefix: {
						if ( currentChar_ == '&' ) {
							pos_++;
							return new Token( Token.Operator.logAnd );
						}
						else
							return new Token( Token.Operator.bitAnd );
					}

				case State.orPrefix: {
						if ( currentChar_ == '|' ) {
							pos_++;
							return new Token( Token.Operator.logOr );
						}
						else
							return new Token( Token.Operator.bitOr );
					}

				case State.singleLineComment: {
						if ( currentChar_ == '\n' || currentChar_ == EOF )
							state = State.init;
						pos_++;
					}
					break;

				case State.multiLineComment: {
						switch ( currentChar_ ) {

						case '/': {
								state = State.multiLineComment_possibleBegin;
								pos_++;
							}
							break;

						case '*': {
								state = State.multiLineComment_possibleEnd;
								pos_++;
							}
							break;

						case EOF: {
								berror( E.unclosedComment, "Unclosed /* comment (found EOF when scanning for */), nesting level: %s. Please note that Beast block comments support nesting.".format( multiLineCommentNestingLevel_ ) );
							}
							break;

						default: {
								pos_++;
							}
							break;

						}
					}
					break;

				case State.multiLineComment_possibleBegin: {
						if ( currentChar_ == '*' )
							multiLineCommentNestingLevel_++;
						pos_++;
						state = State.multiLineComment;
					}
					break;

				case State.multiLineComment_possibleEnd: {
						if ( currentChar_ == '/' && --multiLineCommentNestingLevel_ == 0 )
							state = State.init;
						pos_++;
					}

				}
			}

			assert( 0 );
		}

	package:
		size_t tokenStartPos( ) {
			return tokenStartPos_;
		}

	private:
		void error_unexpectedCharacter( string file = __FILE__, size_t line = __LINE__ ) {
			import std.ascii : isPrintable;

			berror( E.unexpectedCharacter, "Unexpected character: '%s' (%s)".format( currentChar_.isPrintable ? [ currentChar_ ] : null, ( cast( int ) currentChar_ ).to!string ) );
		}

	private:
		size_t pos_;
		size_t tokenStartPos_;
		size_t line_;
		Token currentToken_;
		char currentChar_;
		CodeSource source_;
		/// Beast supports multiline comment nesting
		size_t multiLineCommentNestingLevel_;
		Token[ ] generatedTokens_;

	private:
		string stringAccumulator;

	private:
		enum char EOF = 0;
		enum State {
			init,
			identifierOrKeyword,
			slashPrefix, /// Token that begins with "/": can be "/", "/* comment */" or "// comment \n"
			colonPrefix, /// Token that begins with ":": can be ":" or ":="
			andPrefix, /// Token that begins with "&": can be "&" or "&&"
			orPrefix, /// Token that begins with "|": can be "|" or "||"
			singleLineComment,
			multiLineComment,
			multiLineComment_possibleEnd, /// When there's * in the multiline comment (beginning of */)
			multiLineComment_possibleBegin, /// When there's / in the multiline comment (beginning of /*)
		}

}
