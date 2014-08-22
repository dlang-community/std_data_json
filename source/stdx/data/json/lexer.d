/**
 * Provides JSON lexing facilities.
 *
 * Synopsis:
 * ---
 * // Lex a JSON string into a lazy range of tokens
 * auto tokens = lexJSON(`{"name": "Peter", "age": 42}`);
 *
 * with (JSONToken.Kind) {
 *     assert(tokens.map!(t => t.kind).equal(
 *         [objectStart, string, colon, string, comma,
 *         string, colon, number, objectEnd]));
 * }
 *
 * // Get detailed information
 * tokens.popFront(); // skip the '{'
 * assert(tokens.front.string == "name");
 * tokens.popFront(); // skip "name"
 * tokens.popFront(); // skip the ':'
 * assert(tokens.front.string == "Peter");
 * assert(tokens.front.location.line == 0);
 * assert(tokens.front.location.column == 9);
 * ---
 *
 * Credits:
 *   Support for escaped UTF-16 surrogates was contributed to the original
 *   vibe.d JSON module by Etienne Cimon. The number parsing code is based
 *   on the version contained in Andrei Alexandrescu's "std.jgrandson"
 *   module draft.
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/lexer.d)
 */
module stdx.data.json.lexer;
@safe:

import std.range;
import std.traits : isIntegral, isSomeChar, isSomeString;
import stdx.data.json.foundation;


/**
 * Returns a lazy range of tokens corresponding to the given JSON input string.
 *
 * The input must be a valid JSON string, given as an input range of either
 * characters, or of integral values. In case of integral types, the input
 * ecoding is assumed to be a superset of ASCII that is parsed unit by unit.
 *
 * For inputs of type $(D string), string literals not containing any escape
 * sequences will be returned as slices into the original string. JSON documents
 * containing no escape sequences will result in allocation-free operation o
 * the lexer.
*/
JSONLexerRange!(Input, options) lexJSON
    (LexOptions options = LexOptions.defaults, Input)
    (Input input, string filename = null)
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    return JSONLexerRange!(Input, options)(input, filename);
}

///
unittest
{
    auto rng = lexJSON(`{ "hello": 1.2, "world":[1, true, null]}`);
    with (JSONToken.Kind)
    {
        assert(rng.map!(t => t.kind).equal(
            [objectStart, string, colon, number, comma, string, colon,
            arrayStart, number, comma, boolean, comma, null_, arrayEnd, objectEnd]));
    }
}

///
unittest
{
    auto rng = lexJSON("true\n   false null\r\n  1.0\r \"test\"");
    rng.popFront();
    assert(rng.front.boolean == false);
    assert(rng.front.location.line == 1 && rng.front.location.column == 3);
    rng.popFront();
    assert(rng.front.kind == JSONToken.Kind.null_);
    assert(rng.front.location.line == 1 && rng.front.location.column == 9);
    rng.popFront();
    assert(rng.front.number == 1.0);
    assert(rng.front.location.line == 2 && rng.front.location.column == 2);
    rng.popFront();
    assert(rng.front.string == "test");
    assert(rng.front.location.line == 3 && rng.front.location.column == 1);
    rng.popFront();
    assert(rng.empty);
}

unittest
{
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
 * A lazy input range of JSON tokens.
 *
 * This range type takes an input string range and converts it into a range of
 * $(D JSONToken) values.
 *
 * See $(D lexJSON) for more information.
*/
struct JSONLexerRange(Input, LexOptions options = LexOptions.defaults)
    if (isStringInputRange!Input || isIntegralInputRange!Input)
{
    import std.string : representation;

    static if (isSomeString!Input)
        alias InternalInput = typeof(Input.init.representation);
    else
        alias InternalInput = Input;

    static if (typeof(InternalInput.init.front).sizeof > 1)
        alias CharType = dchar;
    else
        alias CharType = char;

    private
    {
        InternalInput _input;
        JSONToken _front;
        Location _loc;
        string _error;
    }

    /**
     * Constructs a new token stream.
     */
    this(Input input, string filename = null)
    {
        _input = cast(InternalInput)input;
        _front.location.file = filename;
    }

    /**
     * Returns a copy of the underlying input range.
     */
    @property Input input() { return cast(Input)_input; }

    /**
     * The current location of the lexer.
     */
    @property Location location() const { return _loc; }

    /**
     * Determines if the token stream has been exhausted.
     */
    @property bool empty()
    {
        if (_front.kind != JSONToken.Kind.none) return false;
        if (_input.empty) return true;
        skipWhitespace();
        return _input.empty;
    }

    /**
     * Returns the current token in the stream.
     */
    @property ref const(JSONToken) front()
    {
        ensureFrontValid();
        return _front;
    }

    /**
     * Skips to the next token.
     */
    void popFront()
    {
        ensureFrontValid();
        _front.kind = JSONToken.Kind.none;
    }

    private void ensureFrontValid()
    {
        assert(!empty, "Reading from an empty JSONLexerRange.");
        if (_front.kind == JSONToken.Kind.none)
        {
            readToken();
            assert(_front.kind != JSONToken.Kind.none);

            if (_front.kind == JSONToken.Kind.error)
            {
                // consume the remaining input after an invalid token
                while (!_input.empty)
                    _input.popFront();

                static if (!(options & LexOptions.noThrow))
                    throw new JSONException(_error, _loc);
            }
        }
    }

    private void readToken()
    {
        import std.algorithm : skipOver;

        void skipChar()
        {
            _input.popFront();
            static if (options & LexOptions.trackLocation) _loc.column++;
        }


        skipWhitespace();

        assert(!_input.empty, "Reading JSON token from empty input stream.");

        _front.location = _loc;

        string kw;

        switch (_input.front)
        {
            default:
                setError("Malformed token");
                return;
            case 'f': kw = "false"; _front.boolean = false; goto parse_kw;
            case 't': kw = "true"; _front.boolean = true; goto parse_kw;
            case 'n': kw = "null"; _front.kind = JSONToken.Kind.null_; goto parse_kw;
            case '"': parseString(); break;
            case '0': .. case '9': case '-': parseNumber(); break;
            case '[': skipChar(); _front.kind = JSONToken.Kind.arrayStart; break;
            case ']': skipChar(); _front.kind = JSONToken.Kind.arrayEnd; break;
            case '{': skipChar(); _front.kind = JSONToken.Kind.objectStart; break;
            case '}': skipChar(); _front.kind = JSONToken.Kind.objectEnd; break;
            case ':': skipChar(); _front.kind = JSONToken.Kind.colon; break;
            case ',': skipChar(); _front.kind = JSONToken.Kind.comma; break;
        }

        skipWhitespace();
        return;

		parse_kw:
            if (_input.skipOver(kw))
            {
                static if (options & LexOptions.trackLocation) _loc.column += kw.length;
            }
            else setError("Invalid keyord");
    }

    private void skipWhitespace()
    {
        while (!_input.empty)
        {
            static if (options & LexOptions.trackLocation)
            {
                switch (_input.front)
                {
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
            }
            else
            {
                switch (_input.front)
                {
                    default: return;
                    case '\r', '\n', ' ', '\t':
                        _input.popFront();
                        break;
                }
            }
        }
    }

    private void parseString()
    {
        import std.algorithm : skipOver;
        import std.array;

        assert(!_input.empty && _input.front == '"');
        _input.popFront();
        static if (options & LexOptions.trackLocation) _loc.column++;

        Appender!string ret;

        // try the fast slice based route first
        static if (is(Input == string) || is(Input == immutable(ubyte)[]))
        {
            auto orig = input;
            size_t idx = 0;
            while (true)
            {
                if (idx >= _input.length)
                {
                    setError("Unterminated string literal");
                    return;
                }

                // return a slice for simple strings
                if (_input[idx] == '"')
                {
                    _input = _input[idx+1 .. $];
                    static if (options & LexOptions.trackLocation) _loc.column += idx+1;
                    _front.string = cast(string)orig[0 .. idx];
                    return;
                }

                // fall back to full decoding when an escape sequence is encountered
                if (_input[idx] == '\\')
                {
                    ret = appender!string();
                    ret.put(cast(string)_input[0 .. idx]);
                    _input = _input[idx .. $];
                    static if (options & LexOptions.trackLocation) _loc.column += idx;
                    break;
                }

                // Make sure that no illegal characters are present
                if (_input[idx] < 0x20)
                {
                    setError("Control chararacter found in string literal");
                    return;
                }
                idx++;
            }
        }
        else ret = appender!string();

        // perform full decoding
        while (true)
        {
            if (_input.empty)
            {
                setError("Unterminated string literal");
                return;
            }

            auto ch = _input.front;
            _input.popFront();
            static if (options & LexOptions.trackLocation)  _loc.column++;

            switch (ch)
            {
                default: ret.put(cast(CharType)ch); break;
                case '"':
                    _front.string = ret.data;
                    return;
                case '\\':
                    if (_input.empty)
                    {
                        setError("Unterminated string escape sequence.");
                        return;
                    }

                    auto ech = _input.front;
                    _input.popFront();
                    static if (options & LexOptions.trackLocation) _loc.column++;

                    switch (ech)
                    {
                        default:
                            setError("Invalid string escape sequence.");
                            return;
                        case '"': ret.put('\"'); break;
                        case '\\': ret.put('\\'); break;
                        case '/': ret.put('/'); break;
                        case 'b': ret.put('\b'); break;
                        case 'f': ret.put('\f'); break;
                        case 'n': ret.put('\n'); break;
                        case 'r': ret.put('\r'); break;
                        case 't': ret.put('\t'); break;
                        case 'u': // \uXXXX
                            static if (options & LexOptions.trackLocation) _loc.column += 4;
                            dchar decode_unicode_escape()
                            {
                                dchar uch = 0;
                                foreach (i; 0 .. 4)
                                {
                                    if (_input.empty)
                                    {
                                        setError("Premature end of unicode escape sequence");
                                        return dchar.max;
                                    }

                                    uch *= 16;
                                    auto dc = _input.front;
                                    _input.popFront();

                                    if (dc >= '0' && dc <= '9')
                                        uch += dc - '0';
                                    else if ((dc >= 'a' && dc <= 'f') || (dc >= 'A' && dc <= 'F'))
                                        uch += (dc & ~0x20) - 'A' + 10;
                                    else
                                    {
                                        setError("Invalid character in Unicode escape sequence");
                                        return dchar.max;
                                    }
                                }
                                return uch;
                            }

                            dchar uch = decode_unicode_escape();
                            if (uch == dchar.max) return;

                            // detect UTF-16 surrogate pairs
                            if (0xD800 <= uch && uch <= 0xDBFF)
                            {
                                static if (options & LexOptions.trackLocation) _loc.column += 6;

                                if (!_input.skipOver("\\u"))
                                {
                                    setError("Missing second UTF-16 surrogate");
                                    return;
                                }

                                auto uch2 = decode_unicode_escape();
                                if (uch2 == dchar.max) return;

                                if (0xDC00 > uch2 || uch2 > 0xDFFF)
                                {
                                    setError("Invalid UTF-16 surrogate sequence");
                                    return;
                                }

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

    private void parseNumber()
    {
        import std.algorithm : among;
        import std.ascii;
        import std.string;
        import std.traits;

        assert(!_input.empty, "Passed empty range to parseNumber");

        void skipChar()
        {
            _input.popFront();
            static if (options & LexOptions.trackLocation) _loc.column++;
        }

        import std.math;
        double result = 0;
        bool neg = false;

        // negative sign
        if (_input.front == '-')
        {
            skipChar();
            neg = true;
        }

        // integer part of the number
        if (_input.empty || !_input.front.isDigit())
        {
            setError("Invalid number, expected digit");
            return;
        }

        if (_input.front == '0')
        {
            skipChar();
            if (_input.empty) // return 0
            {
                _front.number = neg ? -result : result;
                return;
            }

            if (_input.front.isDigit)
            {
                setError("Invalid number, 0 must not be followed by another digit");
                return;
            }
        }
        else do
        {
            result = result * 10 + (_input.front - '0');
            skipChar();
            if (_input.empty) // return integer
            {
                _front.number = neg ? -result : result;
                return;
            }
        }
        while (isDigit(_input.front));

        // post decimal point part
        assert(!_input.empty);
        if (_input.front == '.')
        {
            skipChar();

            if (_input.empty)
            {
                setError("Missing fractional number part");
                return;
            }

            double mul = 0.1;
            while (true) {
                if (_input.empty)
                {
                    _front.number = neg ? -result : result;
                    return;
                }
                if (!isDigit(_input.front)) break;
                result = result + (_input.front - '0') * mul;
                mul *= 0.1;
                skipChar();
            }
        }

        // exponent
        assert(!_input.empty);
        if (_input.front.among('e', 'E'))
        {
            skipChar();
            if (_input.empty)
            {
                setError("Missing exponent");
                return;
            }

            bool negexp = void;
            if (_input.front == '-')
            {
                negexp = true;
                skipChar();
            }
            else
            {
                negexp = false;
                if (_input.front == '+') skipChar();
            }

            if (_input.empty || !_input.front.isDigit)
            {
                setError("Missing exponent");
                return;
            }

            uint exp = 0;
            while (true)
            {
                exp = exp * 10 + (_input.front - '0');
                skipChar();
                if (_input.empty || !_input.front.isDigit) break;
            }
            result *= pow(negexp ? 0.1 : 10.0, exp);
        }

        _front.number = neg ? -result : result;
    }

    void setError(string err)
    {
        _front.kind = JSONToken.Kind.error;
        _error = err;
    }
}

unittest
{
    import std.conv;
    import std.exception;
    import std.string : format, representation;

    static string parseStringHelper(R)(ref R input, ref Location loc)
    {
        auto rng = JSONLexerRange!R(input);
        rng.parseString();
        input = cast(R)rng._input;
        loc = rng._loc;
        return rng._front.string;
    }

    void testResult(string str, string expected, string remaining, bool slice_expected = false)
    {
        { // test with string (possibly sliced result)
            Location loc;
            string scopy = str;
            auto ret = parseStringHelper(scopy, loc);
            assert(ret == expected, ret);
            assert(scopy == remaining);
            if (slice_expected) assert(&ret[0] is &str[1]);
            assert(loc.line == 0);
            assert(loc.column == str.length - remaining.length, format("%s col %s", str, loc.column));
        }

        { // test with string representation (possibly sliced result)
            Location loc;
            immutable(ubyte)[] scopy = str.representation;
            auto ret = parseStringHelper(scopy, loc);
            assert(ret == expected, ret);
            assert(scopy == remaining);
            if (slice_expected) assert(&ret[0] is &str[1]);
            assert(loc.line == 0);
            assert(loc.column == str.length - remaining.length, format("%s col %s", str, loc.column));
        }

        { // test with dstring (fully duplicated result)
            Location loc;
            dstring scopy = str.to!dstring;
            auto ret = parseStringHelper(scopy, loc);
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
}

unittest
{
    import std.exception;

    void testFail(string str)
    {
        Location loc;
        auto rng1 = JSONLexerRange!(string, LexOptions.defaults)(str);
        assertThrown(rng1.front);

        auto rng2 = JSONLexerRange!(string, LexOptions.noThrow)(str);
        assertNotThrown(rng2.front);
        assert(rng2.front.kind == JSONToken.Kind.error);
    }

    testFail(`"`); // unterminated string
    testFail(`"\`); // unterminated string escape sequence
    testFail(`"test\"`); // unterminated string
    testFail(`"test'`); // unterminated string
    testFail("\"test\n\""); // illegal control character
    testFail(`"\x"`); // invalid escape sequence
    testFail(`"\u123`); // unterminated unicode escape sequence
    testFail(`"\u123"`); // too short unicode escape sequence
    testFail(`"\u123G"`); // invalid unicode escape sequence
    testFail(`"\u123g"`); // invalid unicode escape sequence
    testFail(`"\uD800"`); // missing surrogate
    testFail(`"\uD800\u"`); // too short second surrogate
    testFail(`"\uD800\u1234"`); // invalid surrogate pair
}

unittest
{
    import std.exception;
    import std.math : approxEqual;

    static double parseNumberHelper(R)(ref R input, ref Location loc)
    {
        auto rng = JSONLexerRange!R(input);
        rng.parseNumber();
        input = cast(R)rng._input;
        loc = rng._loc;
        return rng._front.number;
    }

    void test(string str, double expected, string remainder)
    {
        Location loc;
        auto strcopy = str;
        auto res = parseNumberHelper(strcopy, loc);
        assert(approxEqual(res, expected));
        assert(strcopy == remainder);
        assert(loc.line == 0);
        assert(loc.column == str.length - remainder.length);
    }

    test("-0", 0.0, "");
    test("-0 ", 0.0, " ");
    test("-0e+10 ", 0.0, " ");
    test("123", 123.0, "");
    test("123 ", 123.0, " ");
    test("123.0", 123.0, "");
    test("123.0 ", 123.0, " ");
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
}

unittest
{
    import std.exception;

    void testFail(string str)
    {
        Location loc;
        auto rng1 = JSONLexerRange!(string, LexOptions.defaults)(str);
        assertThrown(rng1.front);

        auto rng2 = JSONLexerRange!(string, LexOptions.noThrow)(str);
        assertNotThrown(rng2.front);
        assert(rng2.front.kind == JSONToken.Kind.error);
    }

    testFail("+");
    testFail("-");
    testFail("+1");
    testFail("1.");
    testFail(".1");
    testFail("01");
    testFail("1e");
    testFail("1e+");
    testFail("1e-");
    testFail("1.e");
    testFail("1.e-");
    testFail("1.ee");
    testFail("1.e-e");
    testFail("1.e+e");
}


/**
 * A low-level JSON token as returned by $(D JSONLexer).
*/
struct JSONToken
{
    @safe:
    import std.algorithm : among;

    /**
     * The kind of token represented.
     */
    enum Kind
    {
        none,         /// Used internally, never returned from the lexer
        error,        /// Malformed token
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

    private
    {
        union
        {
            .string _string;
            bool _boolean;
            double _number;
        }
        Kind _kind = Kind.none;
    }

    /// The location of the token in the input.
    Location location;

    /**
     * Gets/sets the kind of the represented token.
     *
     * Setting the token kind is not allowed for any of the kinds that have
     * additional data associated (boolean, number and string).
     */
    @property Kind kind() const nothrow { return _kind; }
    @property Kind kind(Kind value) nothrow
        in { assert(!value.among(Kind.boolean, Kind.number, Kind.string)); }
        body { return _kind = value; }

    /// Gets/sets the boolean value of the token.
    @property bool boolean() const nothrow
    {
        assert(_kind == Kind.boolean, "Token is not a boolean.");
        return _boolean;
    }
    /// ditto
    @property bool boolean(bool value) nothrow
    {
        _kind = Kind.boolean;
        _boolean = value;
        return value;
    }

    /// Gets/sets the numeric value of the token.
    @property double number() const nothrow
    {
        assert(_kind == Kind.number, "Token is not a number.");
        return _number;
    }
    /// ditto
    @property double number(double value) nothrow
    {
        _kind = Kind.number;
        _number = value;
        return value;
    }

    /// Gets/sets the string value of the token.
    @property .string string() const @trusted nothrow
    {
        assert(_kind == Kind.string, "Token is not a string.");
        return _string;
    }
    /// ditto
    @property .string string(.string value) nothrow
    {
        _kind = Kind.string;
        _string = value;
        return value;
    }

    /**
     * Enables equality comparisons.
     *
     * Note that the location is considered token meta data and thus does not
     * affect the comparison.
     */
    bool opEquals(in ref JSONToken other) const nothrow
    {
        if (this.kind != other.kind) return false;

        switch (this.kind)
        {
            default: return true;
            case Kind.boolean: return this.boolean == other.boolean;
            case Kind.number: return this.number == other.number;
            case Kind.string: return this.string == other.string;
        }
    }
    /// ditto
    bool opEquals(JSONToken other) const nothrow { return opEquals(other); }

    /**
     * Enables usage of $(D JSONToken) as an associative array key.
     */
    size_t toHash()
    const nothrow {
        hash_t ret = 3781249591u + cast(uint)_kind * 2721371;

        switch (_kind)
        {
            default: return ret;
            case Kind.boolean: return ret + _boolean;
            case Kind.number: return ret + typeid(double).getHash(&_number);
            case Kind.string: return ret + typeid(.string).getHash(&_string);
        }
    }

    /**
     * Converts the token to a string representation.
     *
     * Note that this representation is NOT the JSON representation, but rather
     * a representation suitable for printing out a token including its
     * location.
     */
    .string toString()
    const @trusted
    {
        import std.string;
        switch (this.kind)
        {
            default: return format("[%s %s]", location, this.kind);
            case Kind.boolean: return format("[%s %s]", location, this.boolean);
            case Kind.number: return format("[%s %s]", location, this.number);
            case Kind.string: return format("[%s \"%s\"]", location, this.string);
        }
    }
}

unittest
{
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

    assert((tok.kind = JSONToken.Kind.none) == JSONToken.Kind.none);
    assert(tok.kind == JSONToken.Kind.none);
    assert((tok.kind = JSONToken.Kind.error) == JSONToken.Kind.error);
    assert(tok.kind == JSONToken.Kind.error);
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


/**
 * Flags for configuring the JSON lexer.
 *
 * These flags can be combined using a bitwise or operation.
 */
enum LexOptions {
    none          = 0,    /// Don't track token location and only use double numbers
    trackLocation = 1<<0, /// Counts lines and columns while lexing the source
    noThrow       = 1<<1, /// Uses JSONToken.Kind.error instead of throwing exceptions
    //useLong     = 1<<2, /// Use long to represent integers
    //useBigInt   = 1<<3, /// Use BigInt to represent integers (if larger than long or useLong is not given)
    //useDecimal  = 1<<4, /// Use Decimal to represent floating point numbers
    defaults      = trackLocation, // Same as trackLocation
}


package enum bool isStringInputRange(R) = isInputRange!R && isSomeChar!(typeof(R.init.front));
package enum bool isIntegralInputRange(R) = isInputRange!R && isIntegral!(typeof(R.init.front));
