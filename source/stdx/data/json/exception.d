/**
 * Exception definitions specific to the JSON processing functions.
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/exception.d)
 */
module stdx.data.json.exception;

import stdx.data.json.lexer;


/**
 * JSON specific exception.
 *
 * This exception is thrown during the lexing and parsing stages.
*/
class JSONException : Exception {
    /// The bare error message
    string message;

    /// The location where the error occured
    JSONToken.Location location;

    /// Constructs a new exception from the given message and location
    this(string message, JSONToken.Location loc, string file = __FILE__, size_t line = __LINE__)
    {
        import std.string;
        this.message = message;
        this.location = loc;
        super(format("%s(%s:%s) %s", loc.file, loc.line, loc.column, message), file, line);
    }
}

package void enforceJson(string file = __FILE__, size_t line = __LINE__)(bool cond, lazy string message, lazy JSONToken.Location loc)
{
    if (!cond) throw new JSONException(message, loc, file, line);
}

