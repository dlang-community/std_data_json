/**
 * Exception definitions specific to the JSON processing functions.
 */
module stdx.data.json.exception;

import stdx.data.json.lexer;


class JSONException : Exception {

    string message;
    JSONToken.Location location;

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

