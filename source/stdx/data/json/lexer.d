/**
 * Provides JSON lexing facilities.
*/
module stdx.data.json.lexer;

import std.range;
import std.traits : isSomeChar, isIntegral;
import stdx.data.json.exception;


/**
 * Returns a lazy range of tokens corresponding to the given JSON input string.
 *
 * The input must be a valid JSON string, given as an input range of either
 * character types, or of integral types. In case of integral types, the input
 * ecoding is assumed to be a superset of ASCII that is parsed unit by unit.
 *
 * For inputs of type $(D string), string type tokens not containing any escape
 * sequences will be slices into the original string. JSON documents containing
 * no escape sequences will result in completely allocation-free operation of
 * the lexer.
*/
JSONLexerRange!(Input, track_location) lexJSON(bool track_location = true, Input)(Input input, string filename = null)
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    return JSONLexerRange!(Input, track_location)(input, filename);
}


/**
 * A lazy input range of JSON tokens.
 *
 * This range type takes an input string range and converts it into a range of
 * $(D JSONToken) values.
 *
 * See $(D lexJSON) for more information.
*/
struct JSONLexerRange(Input, bool track_location = true)
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    import std.string : representation;

    private {
        typeof(Input.init.representation) _input;
        JSONToken _front;
        JSONToken.Location _loc;
    }

    this(Input input, string filename = null)
    {
        _input = input.representation;
        _front.location.file = filename;
        skipWhitespace();
    }

    /**
     * The current location of the lexer.
     */
    @property JSONToken.Location location() const { return _loc; }

    @property bool empty() { return _front.kind == JSONToken.Kind.invalid && _input.empty; }

    @property ref const(JSONToken) front()
    {
        assert(!empty, "Calling front on an empty JSONTokenRange.");
        if (_front.kind == JSONToken.Kind.invalid) {
            readToken();
            assert(_front.kind != JSONToken.Kind.invalid);
        }
        return _front;
    }

    void popFront()
    {
        if (_front.kind == JSONToken.Kind.invalid) {
            readToken();
            assert(_front.kind != JSONToken.Kind.invalid);
        }
        _front.kind = JSONToken.Kind.invalid;
    }

    private void readToken()
    {
        import std.algorithm : skipOver;

        assert(!_input.empty, "Reading JSON token from empty input stream.");

        _front.location = _loc;

        switch (_input.front) {
            default:
            import std.conv;
                throw new JSONException(`Malformed token: `~to!string(cast(Input)_input), _loc);
            case 'f':
                enforceJson(_input.skipOver("false"), `Malformed token, expected "false"`, _loc);
                _front.boolean = false;
                break;
            case 't':
                enforceJson(_input.skipOver("true"), `Malformed token, expected "true"`, _loc);
                _front.boolean = true;
                break;
            case 'n':
                enforceJson(_input.skipOver("null"), `Malformed token, expected "null"`, _loc);
                _front.kind = JSONToken.Kind.null_;
                break;
            case '"': _front.string = _input.parseString!track_location(_loc); break;
            case '0': .. case '9': case '-': _front.number = _input.parseNumber!track_location(_loc); break;
            case '[': skipNonWSChar(); _front.kind = JSONToken.Kind.arrayStart; break;
            case ']': skipNonWSChar(); _front.kind = JSONToken.Kind.arrayEnd; break;
            case '{': skipNonWSChar(); _front.kind = JSONToken.Kind.objectStart; break;
            case '}': skipNonWSChar(); _front.kind = JSONToken.Kind.objectEnd; break;
            case ':': skipNonWSChar(); _front.kind = JSONToken.Kind.colon; break;
            case ',': skipNonWSChar(); _front.kind = JSONToken.Kind.comma; break;
        }

        skipWhitespace();
    }

    private void skipNonWSChar()
    {
        _input.popFront();
        static if (track_location) _loc.column++;
    }

    private void skipWhitespace()
    {
        while (!_input.empty) {
            static if (track_location) {
                switch (_input.front) {
                    default: return;
                    case '\r': // Mac and Windows line breaks
                        _loc.line++;
                        _loc.column = 0;
                        _input.popFront();
                        if (!_input.empty && _input.front == '\n')
                            _input.popFront();
                        break;
                    case '\n': // Linux line breaks
                        _loc.line++;
                        _loc.column = 0;
                        _input.popFront();
                        break;
                    case ' ', '\t':
                        _loc.column++;
                        _input.popFront();
                        break;
                }
            } else {
                switch (_input.front) {
                    default: return;
                    case '\r', '\n', ' ', '\t':
                        _input.popFront();
                        break;
                }
            }
        }
    }
}

///
unittest {
    auto rng = lexJSON(`{ "hello": 1.2, "world":[1, true, null]}`);
    with (JSONToken.Kind) {
        assert(rng.map!(t => t.kind).equal(
            [objectStart, string, colon, number, comma, string, colon,
            arrayStart, number, comma, boolean, comma, null_, arrayEnd, objectEnd]));
    }
}

///
unittest {
    auto rng = lexJSON("true\n   false\r\n  1.0\r \"test\"");
    rng.popFront();
    assert(rng.front.boolean == false);
    assert(rng.front.location.line == 1 && rng.front.location.column == 3);
    rng.popFront();
    assert(rng.front.number == 1.0);
    assert(rng.front.location.line == 2 && rng.front.location.column == 2);
    rng.popFront();
    assert(rng.front.string == "test");
    assert(rng.front.location.line == 3 && rng.front.location.column == 1);
    rng.popFront();
    assert(rng.empty);
}

unittest {
    import std.exception;
    assertThrown(lexJSON(`trui`).array); // invalid token
    assertThrown(lexJSON(`fal`).array); // invalid token
    assertThrown(lexJSON(`falsi`).array); // invalid token
    assertThrown(lexJSON(`nul`).array); // invalid token
    assertThrown(lexJSON(`nulX`).array); // invalid token
    assertThrown(lexJSON(`0.e`).array); // invalid number
    assertThrown(lexJSON(`xyz`).array); // invalid token
 }


/**
 * A low-level JSON token as returned by $(D JSONLexer).
*/
struct JSONToken {
    import std.algorithm : among;

    /**
     * The kind of token represented.
     */
    enum Kind {
        invalid,      /// Used internally
        null_,        /// The "null" token
        boolean,      /// "true" or "false" token
        number,       /// Numeric token
        string,       /// String token, stored in escaped form
        objectStart,  /// The "{" token
        objectEnd,    /// The "}" token
        arrayStart,   /// The "[" token
        arrayEnd,     /// The "]" token
        colon,        /// The ":" token
        comma         /// The "," token
    }

    /**
     * Represents a location in the input range.
     *
     * The indices are zero based and the column is represented in code units of
     * the input (i.e. in bytes in case of a UTF-8 input string).
     */
    struct Location {
        /// Optional file name.
        .string file;
        /// The zero based line of the input file.
        size_t line = 0;
        /// The zero based code unit index of the referenced line.
        size_t column = 0;
    }

    private {
        union {
            .string _string;
            bool _boolean;
            double _number;
        }
        Kind _kind = Kind.invalid;
    }

    /// The location of the token in the input.
    Location location;

    /**
     * Gets/sets the kind of the represented token.
     *
     * Setting the token kind is not allowed for any of the kinds that have
     * additional data associated (boolean, number and string).
     */
    @property Kind kind() const { return _kind; }
    @property Kind kind(Kind value)
        in { assert(!value.among(Kind.boolean, Kind.number, Kind.string)); }
        body { return _kind = value; }

    /// Gets/sets the boolean value of the token.
    @property bool boolean()
    const {
        assert(_kind == Kind.boolean, "Token is not a boolean.");
        return _boolean;
    }
    /// ditto
    @property bool boolean(bool value)
    {
        _kind = Kind.boolean;
        _boolean = value;
        return value;
    }

    /// Gets/sets the numeric value of the token.
    @property double number()
    const {
        assert(_kind == Kind.number, "Token is not a number.");
        return _number;
    }
    /// ditto
    @property double number(double value)
    {
        _kind = Kind.number;
        _number = value;
        return value;
    }

    /// Gets/sets the string value of the token.
    @property .string string()
    const {
        assert(_kind == Kind.string, "Token is not a string.");
        return _string;
    }
    /// ditto
    @property .string string(.string value)
    {
        _kind = Kind.string;
        _string = value;
        return value;
    }
}

unittest {
    JSONToken tok;

    assert((tok.boolean = true) == true);
    assert(tok.kind == JSONToken.Kind.boolean);
    assert(tok.boolean == true);

    assert((tok.number = 1.0) == 1.0);
    assert(tok.kind == JSONToken.Kind.number);
    assert(tok.number == 1.0);

    assert((tok.string = "test") == "test");
    assert(tok.kind == JSONToken.Kind.string);
    assert(tok.string == "test");

    assert((tok.kind = JSONToken.Kind.invalid) == JSONToken.Kind.invalid);
    assert(tok.kind == JSONToken.Kind.invalid);
    assert((tok.kind = JSONToken.Kind.null_) == JSONToken.Kind.null_);
    assert(tok.kind == JSONToken.Kind.null_);
    assert((tok.kind = JSONToken.Kind.objectStart) == JSONToken.Kind.objectStart);
    assert(tok.kind == JSONToken.Kind.objectStart);
    assert((tok.kind = JSONToken.Kind.objectEnd) == JSONToken.Kind.objectEnd);
    assert(tok.kind == JSONToken.Kind.objectEnd);
    assert((tok.kind = JSONToken.Kind.arrayStart) == JSONToken.Kind.arrayStart);
    assert(tok.kind == JSONToken.Kind.arrayStart);
    assert((tok.kind = JSONToken.Kind.arrayEnd) == JSONToken.Kind.arrayEnd);
    assert(tok.kind == JSONToken.Kind.arrayEnd);
    assert((tok.kind = JSONToken.Kind.colon) == JSONToken.Kind.colon);
    assert(tok.kind == JSONToken.Kind.colon);
    assert((tok.kind = JSONToken.Kind.comma) == JSONToken.Kind.comma);
    assert(tok.kind == JSONToken.Kind.comma);
}


private string parseString(bool track_location = true, Input)(ref Input input, ref JSONToken.Location loc)
{
    import std.algorithm : skipOver;
    import std.array;

    assert(!input.empty && input.front == '"');
    input.popFront();
    static if (track_location) loc.column++;

    Appender!string ret;

    // try the fast slice based route first
    static if (is(Input == string) || is(Input == immutable(ubyte)[])) {
        auto orig = input;
        size_t idx = 0;
        while (true) {
            enforceJson(idx < input.length, "Unterminated string literal", loc);

            // return a slice for simple strings
            if (input[idx] == '"') {
                input = input[idx+1 .. $];
                static if (track_location) loc.column += idx+1;
                return cast(string)orig[0 .. idx];
            }

            // fall back to full decoding when an escape sequence is encountered
            if (input[idx] == '\\') {
                ret = appender!string();
                ret.put(cast(string)input[0 .. idx]);
                input = input[idx .. $];
                static if (track_location) loc.column += idx;
                break;
            }

            // Make sure that no illegal characters are present
            enforceJson(input[idx] >= 0x20, "Control chararacter found in string literal", loc);
            idx++;
        }
    } else ret = appender!string();

    // perform full decoding
    while (true) {
        enforceJson(!input.empty, "Unterminated string literal", loc);
        auto ch = input.front;
        input.popFront();
       static if (track_location)  loc.column++;

        switch (ch) {
            default: ret.put(ch); break;
            case '"': return ret.data;
            case '\\':
                enforceJson(!input.empty, "Unterminated string escape sequence.", loc);
                auto ech = input.front;
                input.popFront();
                static if (track_location) loc.column++;

                switch (ech) {
                    default: enforceJson(false, "Invalid string escape sequence.", loc); break;
                    case '"': ret.put('\"'); break;
                    case '\\': ret.put('\\'); break;
                    case '/': ret.put('/'); break;
                    case 'b': ret.put('\b'); break;
                    case 'f': ret.put('\f'); break;
                    case 'n': ret.put('\n'); break;
                    case 'r': ret.put('\r'); break;
                    case 't': ret.put('\t'); break;
                    case 'u': // \uXXXX
                        static if (track_location) loc.column += 4;
                        dchar decode_unicode_escape() {
                            dchar uch = 0;
                            foreach (i; 0 .. 4) {
                                enforceJson(!input.empty, "Premature end of unicode escape sequence", loc);
                                uch *= 16;
                                auto dc = input.front;
                                input.popFront();

                                if (dc >= '0' && dc <= '9')
                                    uch += dc - '0';
                                else if (dc >= 'a' && dc <= 'f' || dc >= 'A' && dc <= 'F')
                                    uch += (dc & ~0x20) - 'A' + 10;
                                else enforceJson(false, "Invalid character in Unicode escape sequence", loc);
                            }
                            return uch;
                        }

                        dchar uch = decode_unicode_escape();

                        // detect UTF-16 surrogate pairs
                        if (0xD800 <= uch && uch <= 0xDBFF) {
                            static if (track_location) loc.column += 6;
                            enforceJson(input.skipOver("\\u"), "Missing second UTF-16 surrogate", loc);
                            auto uch2 = decode_unicode_escape();
                            enforceJson(0xDC00 <= uch2 && uch2 <= 0xDFFF, "Invalid UTF-16 surrogate sequence", loc);
                            // combine to a valid UCS-4 character
                            uch = ((uch - 0xD800) << 10) + (uch2 - 0xDC00) + 0x10000;
                        }

                        ret.put(uch);
                        break;
                }
                break;
        }
    }
}

unittest {
    import std.conv;
    import std.exception;
    import std.string : format, representation;

    void testResult(string str, string expected, string remaining, bool slice_expected = false) {
        { // test with string (possibly sliced result)
            JSONToken.Location loc;
            string scopy = str;
            auto ret = parseString(scopy, loc);
            assert(ret == expected, ret);
            assert(scopy == remaining);
            if (slice_expected) assert(ret.ptr is str.ptr+1);
            assert(loc.line == 0);
            assert(loc.column == str.length - remaining.length, format("%s col %s", str, loc.column));
        }

        { // test with string representation (possibly sliced result)
            JSONToken.Location loc;
            immutable(ubyte)[] scopy = str.representation;
            auto ret = parseString(scopy, loc);
            assert(ret == expected, ret);
            assert(scopy == remaining);
            if (slice_expected) assert(ret.ptr is str.ptr+1);
            assert(loc.line == 0);
            assert(loc.column == str.length - remaining.length, format("%s col %s", str, loc.column));
        }

        { // test with dstring (fully duplicated result)
            JSONToken.Location loc;
            dstring scopy = str.to!dstring;
            auto ret = parseString(scopy, loc);
            assert(ret == expected);
            assert(scopy == remaining.to!dstring);
            assert(loc.line == 0);
            assert(loc.column == str.to!dstring.length - remaining.to!dstring.length, format("%s col %s", str, loc.column));
        }
    }

    testResult(`"test"`, "test", "", true);
    testResult(`"test"...`, "test", "...", true);
    testResult(`"test\n"`, "test\n", "");
    testResult(`"test\n"...`, "test\n", "...");
    testResult(`"test\""...`, "test\"", "...");
    testResult(`"ä"`, "ä", "", true);
    testResult(`"\r\n\\\"\b\f\t\/"`, "\r\n\\\"\b\f\t/", "");
    testResult(`"\u1234"`, "\u1234", "");
    testResult(`"\uD800\udc00"`, "\U00010000", "");

    JSONToken.Location loc;
    string s;
    assertThrown(parseString(s = `"`, loc)); // unterminated string
    assertThrown(parseString(s = `"test\"`, loc)); // unterminated string
    assertThrown(parseString(s = `"test'`, loc)); // unterminated string
    assertThrown(parseString(s = "\"test\n\"", loc)); // illegal control character
    assertThrown(parseString(s = `"\x"`, loc)); // invalid escape sequence
    assertThrown(parseString(s = `"\u123"`, loc)); // too short unicode escape sequence
    assertThrown(parseString(s = `"\u123G"`, loc)); // invalid unicode escape sequence
    assertThrown(parseString(s = `"\u123g"`, loc)); // invalid unicode escape sequence
    assertThrown(parseString(s = `"\uD800"`, loc)); // missing surrogate
    assertThrown(parseString(s = `"\uD800\u"`, loc)); // too short second surrogate
    assertThrown(parseString(s = `"\uD800\u1234"`, loc)); // invalid surrogate pair
}

private double parseNumber(bool track_location = true, Input)(ref Input input, ref JSONToken.Location loc)
{
    import std.algorithm : among;
    import std.ascii;
    import std.string;
    import std.traits;

    assert(!input.empty, "Passed empty range to parseNumber");

    static if (isSomeString!Input) {
        auto rep = input.representation;
        auto result = .parseNumber!track_location(rep, loc);
        input = cast(Input) rep;
        return result;
    } else {
        import std.math;
        double result = 0;
        bool neg = false;

        // negative sign
        if (input.front == '-') {
            input.popFront();
            static if (track_location) loc.column++;
            neg = true;
        }

        // integer part of the number
        enforceJson(!input.empty && input.front.isDigit(), "Invalid number, expected digit", loc);
        do {
            result = result * 10 + (input.front - '0');
            input.popFront();
            static if (track_location) loc.column++;
            if (input.empty) return neg ? -result : result;
        } while (isDigit(input.front));

        // post decimal point part
        assert(!input.empty);
        if (input.front == '.') {
            input.popFront();
            static if (track_location) loc.column++;
            double mul = 0.1;
            while (true) {
                if (input.empty) return neg ? -result : result;
                if (!isDigit(input.front)) break;
                result = result + (input.front - '0') * mul;
                mul *= 0.1;
                input.popFront();
                static if (track_location) loc.column++;
            }
        }

        // exponent
        assert(!input.empty);
        if (input.front.among('e', 'E')) {
            input.popFront();
            static if (track_location) loc.column++;
            enforceJson(!input.empty, "Missing exponent", loc);

            bool negexp = void;
            if (input.front == '-') {
                negexp = true;
                input.popFront();
                static if (track_location) loc.column++;
            } else {
                negexp = false;
                if (input.front == '+') {
                    input.popFront();
                    static if (track_location) loc.column++;
                }
            }

            enforceJson(!input.empty && input.front.isDigit, "Missing exponent", loc);
            uint exp = 0;
            while (true) {
                exp = exp * 10 + (input.front - '0');
                input.popFront();
                static if (track_location) loc.column++;
                if (input.empty || !input.front.isDigit) break;
            }
            result *= pow(negexp ? 0.1 : 10.0, exp);
        }

        return neg ? -result : result;
    }
}

unittest {
    import std.exception;
    import std.math : approxEqual;
    import std.string : format;

    void test(string str, double expected, string remainder) {
        JSONToken.Location loc;
        auto strcopy = str;
        auto res = parseNumber(strcopy, loc);
        assert(approxEqual(res, expected), format("%s vs %s %s", res, expected, res-expected));
        assert(strcopy == remainder, format("rem '%s' '%s'", str, strcopy));
        assert(loc.line == 0);
        assert(loc.column == str.length - remainder.length);
    }

    test("-0", 0.0, "");
    test("-0 ", 0.0, " ");
    test("-0e+10 ", 0.0, " ");
    test("123", 123.0, "");
    test("123 ", 123.0, " ");
    test("123.", 123.0, "");
    test("123. ", 123.0, " ");
    test("123.456", 123.456, "");
    test("123.456 ", 123.456, " ");
    test("123.456e1", 1234.56, "");
    test("123.456e1 ", 1234.56, " ");
    test("123.456e+1", 1234.56, "");
    test("123.456e+1 ", 1234.56, " ");
    test("123.456e-1", 12.3456, "");
    test("123.456e-1 ", 12.3456, " ");
    test("123.456e-01", 12.3456, "");
    test("123.456e-01 ", 12.3456, " ");
    test("0.123e-12", 0.123e-12, "");
    test("0.123e-12 ", 0.123e-12, " ");

    JSONToken.Location loc;
    string s;
    assertThrown(parseNumber(s = "+", loc));
    assertThrown(parseNumber(s = "-", loc));
    assertThrown(parseNumber(s = "+1", loc));
    assertThrown(parseNumber(s = "1e", loc));
    assertThrown(parseNumber(s = "1e+", loc));
    assertThrown(parseNumber(s = "1e-", loc));
    assertThrown(parseNumber(s = "1.e", loc));
    assertThrown(parseNumber(s = "1.e-", loc));
    assertThrown(parseNumber(s = "1.ee", loc));
    assertThrown(parseNumber(s = "1.e-e", loc));
    assertThrown(parseNumber(s = "1.e+e", loc));
}


package enum bool isStringInputRange(R) = isInputRange!R && isSomeChar!(typeof(R.init.front));
package enum bool isIntegralInputRange(R) = isInputRange!R && isIntegral!(typeof(R.init.front));
