module beast.util.util;

import beast.util.identifiable;
import beast.core.error.error;

/// Return expression identificationString value or "#error#" if expression executing results in an error
pragma( inline ) string tryGetIdentificationString( T )( lazy T obj ) {
	try {
		auto data = obj();

		if ( data is null )
			return "#error#";

		return data.identificationString;
	}
	catch ( BeastErrorException ) {
		return "#error#";
	}
}

/// Return expression identificationString value or "#error#" if expression executing results in an error
pragma( inline ) string tryGetIdentificationString_noPrefix( T )( lazy T obj ) {
	try {
		auto data = obj();

		if ( data is null )
			return "#error#";

		return data.identificationString_noPrefix;
	}
	catch ( BeastErrorException ) {
		return "#error#";
	}
}

/// Return expression identification value or "#error#" if expression executing results in an error
pragma( inline ) string tryGetIdentification( T )( lazy T obj ) {
	try {
		auto data = obj();

		if ( data is null )
			return "#error#";

		return data.identification;
	}
	catch ( BeastErrorException ) {
		return "#error#";
	}
}
