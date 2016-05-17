#ifndef NATI_TOKEN_H
#define NATI_TOKEN_H

#include "Identifier.h"

namespace nati {

	enum class TokenType {
		none, ///< Erroreous state
		identifier,
		keyword,
		eof
	};

	class Token {

	public:
		operator bool() const;

	public:
		TokenType type;
		union {
			Identifier identifier;
			Keyword keyword;
		};

	};

}

#endif //NATI_TOKEN_H
