module beast.core.error.msgfmtr.gnu;

import beast.core.error.errormsg;
import beast.core.error.msgfmtr.msgfmtr;
import beast.toolkit;
import std.conv;

final class MessageFormatter_GNU : MessageFormatter {

public:
	override string formatErrorMessage( ErrorMessage msg ) {
		string result;

		auto cl = msg.codeLocation;
		if ( cl.source ) {
			result ~= cl.file ~ ":";

			if ( cl.startLine ) {
				result ~= cl.startLine.to!string ~ "." ~ cl.startColumn.to!string;
				if ( cl.endLine != cl.startLine )
					result ~= "-" ~ cl.endLine.to!string ~ "." ~ cl.endColumn.to!string;
				else
					result ~= "-" ~ cl.endColumn.to!string;

				result ~= ":";
			}

		}
		else
			result = "beast:";

		result ~= " " ~ ErrorSeverityStrings[ msg.severity ] ~ ": " ~ /* enumAssocInvert!( E )[ error ] ~ " | " ~ */ msg.message;

		return result;
	}

}
