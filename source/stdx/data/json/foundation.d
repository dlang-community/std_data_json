/**
 * Exception definitions specific to the JSON processing functions.
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/foundation.d)
 */
module stdx.data.json.foundation;
@safe:

import stdx.data.json.lexer;

/**
 * Represents a location in an input range/file.
 *
 * The indices are zero based and the column is represented in code units of
 * the input (i.e. in bytes in case of a UTF-8 input string).
 */
struct Location
{
    /// Optional file name.
    string file;
    /// The zero based line of the input file.
    size_t line = 0;
    /// The zero based code unit index of the referenced line.
    size_t column = 0;

    /// Returns a string representation of the location.
    string toString() const
    {
        import std.string;
        return format("%s(%s:%s)", this.file, this.line, this.column);
    }
}


/**
 * JSON specific exception.
 *
 * This exception is thrown during the lexing and parsing stages.
*/
class JSONException : Exception
{
    /// The bare error message
    string message;

    /// The location where the error occured
    Location location;

    /// Constructs a new exception from the given message and location
    this(string message, Location loc, string file = __FILE__, size_t line = __LINE__)
    {
        import std.string;
        this.message = message;
        this.location = loc;
        super(format("%s(%s:%s) %s", loc.file, loc.line, loc.column, message), file, line);
    }
}

package void enforceJson(string file = __FILE__, size_t line = __LINE__)(bool cond, lazy string message, lazy Location loc)
{
    if (!cond) throw new JSONException(message, loc, file, line);
}

