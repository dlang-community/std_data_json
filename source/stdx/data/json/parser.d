/**
 * Provides various means for parsing JSON documents.
 *
 * This module contains two different parser implementations. The first
 * implementation returns a single JSON document in the form of a
 * $(D JSONValue), while the second implementation returns a stream
 * of nodes. The stream based parser is particularly useful for
 * deserializing with few allocations or for processing large documents.
 *
 * Copyright: Copyright 2012 - 2015, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/parser.d)
 */
module stdx.data.json.parser;

///
unittest
{
    import std.algorithm : equal, map;

    // Parse a JSON string to a single value
    JSONValue value = toJSONValue(`{"name": "D", "kind": "language"}`);

    // Parse a JSON string to a node stream
    auto nodes = parseJSONStream(`{"name": "D", "kind": "language"}`);
    with (JSONParserNodeKind) {
        assert(nodes.map!(n => n.kind).equal(
            [objectStart, key, literal, key, literal, objectEnd]));
    }

    // Parse a list of tokens instead of a string
    auto tokens = lexJSON(`{"name": "D", "kind": "language"}`);
    JSONValue value2 = toJSONValue(tokens);
    assert(value == value2);
}

import std.array : appender;
import std.range : ElementType, isInputRange;
import std.traits : isIntegral, isSomeChar;

import stdx.data.json.lexer;
import stdx.data.json.value;

/**
 * Parses a JSON string or token range and returns the result as a
 * `JSONValue`.
 *
 * The input string must be a valid JSON document. In particular, it must not
 * contain any additional text other than whitespace after the end of the
 * JSON document.
 *
 * See_also: `parseJSONValue`
 */
JSONValue toJSONValue(LexOptions options = LexOptions.init, Input)(Input input, string filename = "")
    if (isInputRange!Input && (isSomeChar!(ElementType!Input) || isIntegral!(ElementType!Input)))
{
    auto tokens = lexJSON!options(input, filename);
    return toJSONValue(tokens);
}
/// ditto
JSONValue toJSONValue(Input)(Input tokens)
    if (isJSONTokenInputRange!Input)
{
    import stdx.data.json.foundation;
    auto ret = parseJSONValue(tokens);
    enforceJson(tokens.empty, "Unexpected characters following JSON", tokens.location);
    return ret;
}

///
@safe unittest
{
    // parse a simple number
    JSONValue a = toJSONValue(`1.0`);
    assert(a == 1.0);

    // parse an object
    JSONValue b = toJSONValue(`{"a": true, "b": "test"}`);
    auto bdoc = b.get!(JSONValue[string]);
    assert(bdoc.length == 2);
    assert(bdoc["a"] == true);
    assert(bdoc["b"] == "test");

    // parse an array
    JSONValue c = toJSONValue(`[1, 2, null]`);
    auto cdoc = c.get!(JSONValue[]);
    assert(cdoc.length == 3);
    assert(cdoc[0] == 1.0);
    assert(cdoc[1] == 2.0);
    assert(cdoc[2] == null);
}

unittest { // issue #22
    import std.conv;
    JSONValue jv = toJSONValue(`{ "a": 1234 }`);
    assert(jv["a"].to!int == 1234);
}

/*unittest
{
    import std.bigint;
    auto v = toJSONValue!(LexOptions.useBigInt)(`{"big": 12345678901234567890}`);
    assert(v["big"].value == BigInt("12345678901234567890"));
}*/

@safe unittest
{
    import std.exception;
    assertNotThrown(toJSONValue("{} \t\r\n"));
    assertThrown(toJSONValue(`{} {}`));
}


/**
 * Consumes a single JSON value from the input range and returns the result as a
 * `JSONValue`.
 *
 * The input string must start with a valid JSON document. Any characters
 * occurring after this document will be left in the input range. Use
 * `toJSONValue` instead if you wish to perform a normal string to `JSONValue`
 * conversion.
 *
 * See_also: `toJSONValue`
 */
JSONValue parseJSONValue(LexOptions options = LexOptions.init, Input)(ref Input input, string filename = "")
    if (isInputRange!Input && (isSomeChar!(ElementType!Input) || isIntegral!(ElementType!Input)))
{
    import stdx.data.json.foundation;

    auto tokens = lexJSON!options(input, filename);
    auto ret = parseJSONValue(tokens);
    input = tokens.input;
    return ret;
}

/// Parse an object
@safe unittest
{
    // parse an object
    string str = `{"a": true, "b": "test"}`;
    JSONValue v = parseJSONValue(str);
    assert(!str.length); // the input has been consumed

    auto obj = v.get!(JSONValue[string]);
    assert(obj.length == 2);
    assert(obj["a"] == true);
    assert(obj["b"] == "test");
}

/// Parse multiple consecutive values
@safe unittest
{
    string str = `1.0 2.0`;
    JSONValue v1 = parseJSONValue(str);
    assert(v1 == 1.0);
    assert(str == `2.0`);
    JSONValue v2 = parseJSONValue(str);
    assert(v2 == 2.0);
    assert(str == ``);
}


/**
 * Parses a stream of JSON tokens and returns the result as a $(D JSONValue).
 *
 * All tokens belonging to the document will be consumed from the input range.
 * Any tokens after the end of the first JSON document will be left in the
 * input token range for possible later consumption.
*/
@safe JSONValue parseJSONValue(Input)(ref Input tokens)
    if (isJSONTokenInputRange!Input)
{
    import std.array;
    import stdx.data.json.foundation;

    enforceJson(!tokens.empty, "Missing JSON value before EOF", tokens.location);

    JSONValue ret;

    final switch (tokens.front.kind) with (JSONTokenKind)
    {
        case none: assert(false);
        case error: enforceJson(false, "Invalid token encountered", tokens.front.location); assert(false);
        case null_: ret = JSONValue(null); break;
        case boolean: ret = JSONValue(tokens.front.boolean); break;
        case number:
            final switch (tokens.front.number.type)
            {
                case JSONNumber.Type.double_: ret = tokens.front.number.doubleValue; break;
                case JSONNumber.Type.long_: ret = tokens.front.number.longValue; break;
                case JSONNumber.Type.bigInt: () @trusted { ret = WrappedBigInt(tokens.front.number.bigIntValue); } (); break;
            }
            break;
        case string: ret = JSONValue(tokens.front.string); break;
        case objectStart:
            auto loc = tokens.front.location;
            bool first = true;
            JSONValue[.string] obj;
            tokens.popFront();
            while (true)
            {
                enforceJson(!tokens.empty, "Missing closing '}'", loc);
                if (tokens.front.kind == objectEnd) break;

                if (!first)
                {
                    enforceJson(tokens.front.kind == comma, "Expected ',' or '}'", tokens.front.location);
                    tokens.popFront();
                    enforceJson(!tokens.empty, "Expected field name", tokens.location);
                }
                else first = false;

                enforceJson(tokens.front.kind == string, "Expected field name string", tokens.front.location);
                auto key = tokens.front.string;
                tokens.popFront();
                enforceJson(!tokens.empty && tokens.front.kind == colon, "Expected ':'",
                    tokens.empty ? tokens.location : tokens.front.location);
                tokens.popFront();
                obj[key] = parseJSONValue(tokens);
            }
            ret = JSONValue(obj, loc);
            break;
        case arrayStart:
            auto loc = tokens.front.location;
            bool first = true;
            auto array = appender!(JSONValue[]);
            tokens.popFront();
            while (true)
            {
                enforceJson(!tokens.empty, "Missing closing ']'", loc);
                if (tokens.front.kind == arrayEnd) break;

                if (!first)
                {
                    enforceJson(tokens.front.kind == comma, "Expected ',' or ']'", tokens.front.location);
                    tokens.popFront();
                }
                else first = false;

                () @trusted { array ~= parseJSONValue(tokens); }();
            }
            ret = JSONValue(array.data, loc);
            break;
        case objectEnd, arrayEnd, colon, comma:
            enforceJson(false, "Expected JSON value", tokens.front.location);
            assert(false);
    }

    tokens.popFront();
    return ret;
}

///
@safe unittest
{
    // lex
    auto tokens = lexJSON(`[1, 2, 3]`);

    // parse
    auto doc = parseJSONValue(tokens);

    auto arr = doc.get!(JSONValue[]);
    assert(arr.length == 3);
    assert(arr[0] == 1.0);
    assert(arr[1] == 2.0);
    assert(arr[2] == 3.0);
}

@safe unittest
{
    import std.exception;

    assertThrown(toJSONValue(`]`));
    assertThrown(toJSONValue(`}`));
    assertThrown(toJSONValue(`,`));
    assertThrown(toJSONValue(`:`));
    assertThrown(toJSONValue(`{`));
    assertThrown(toJSONValue(`[`));
    assertThrown(toJSONValue(`[1,]`));
    assertThrown(toJSONValue(`[1,,]`));
    assertThrown(toJSONValue(`[1,`));
    assertThrown(toJSONValue(`[1 2]`));
    assertThrown(toJSONValue(`{1: 1}`));
    assertThrown(toJSONValue(`{"a": 1,}`));
    assertThrown(toJSONValue(`{"a" 1}`));
    assertThrown(toJSONValue(`{"a": 1 "b": 2}`));
}

/**
 * Parses a JSON document using a lazy parser node range.
 *
 * This mode parsing mode is similar to a streaming XML (StAX) parser. It can
 * be used to parse JSON documents of unlimited size. The memory consumption
 * grows linearly with the nesting level (about 4 bytes per level), but is
 * independent of the number of values in the JSON document.
 *
 * The resulting range of nodes is guaranteed to be ordered according to the
 * following grammar, where uppercase terminals correspond to the node kind
 * (See $(D JSONParserNodeKind)).
 *
 * $(UL
 *   $(LI list → value*)
 *   $(LI value → LITERAL | array | object)
 *   $(LI array → ARRAYSTART (value)* ARRAYEND)
 *   $(LI object → OBJECTSTART (KEY value)* OBJECTEND)
 * )
 */
JSONParserRange!(JSONLexerRange!(Input, options, String))
    parseJSONStream(LexOptions options = LexOptions.init, String = string, Input)
        (Input input, string filename = null)
    if (isInputRange!Input && (isSomeChar!(ElementType!Input) || isIntegral!(ElementType!Input)))
{
    return parseJSONStream(lexJSON!(options, String)(input, filename));
}
/// ditto
JSONParserRange!Input parseJSONStream(Input)(Input tokens)
    if (isJSONTokenInputRange!Input)
{
    return JSONParserRange!Input(tokens);
}

///
@safe unittest
{
    import std.algorithm;

    auto rng1 = parseJSONStream(`{ "a": 1, "b": [null] }`);
    with (JSONParserNodeKind)
    {
        assert(rng1.map!(n => n.kind).equal(
            [objectStart, key, literal, key, arrayStart, literal, arrayEnd,
            objectEnd]));
    }

    auto rng2 = parseJSONStream(`1 {"a": 2} null`);
    with (JSONParserNodeKind)
    {
        assert(rng2.map!(n => n.kind).equal(
            [literal, objectStart, key, literal, objectEnd, literal]));
    }
}

@safe unittest
{
    auto rng = parseJSONStream(`{"a": 1, "b": [null, true], "c": {"d": {}}}`);
    with (JSONParserNodeKind)
    {
        rng.popFront();
        assert(rng.front.kind == key && rng.front.key == "a"); rng.popFront();
        assert(rng.front.kind == literal && rng.front.literal.number == 1.0); rng.popFront();
        assert(rng.front.kind == key && rng.front.key == "b"); rng.popFront();
        assert(rng.front.kind == arrayStart); rng.popFront();
        assert(rng.front.kind == literal && rng.front.literal.kind == JSONTokenKind.null_); rng.popFront();
        assert(rng.front.kind == literal && rng.front.literal.boolean == true); rng.popFront();
        assert(rng.front.kind == arrayEnd); rng.popFront();
        assert(rng.front.kind == key && rng.front.key == "c"); rng.popFront();
        assert(rng.front.kind == objectStart); rng.popFront();
        assert(rng.front.kind == key && rng.front.key == "d"); rng.popFront();
        assert(rng.front.kind == objectStart); rng.popFront();
        assert(rng.front.kind == objectEnd); rng.popFront();
        assert(rng.front.kind == objectEnd); rng.popFront();
        assert(rng.front.kind == objectEnd); rng.popFront();
        assert(rng.empty);
    }
}

@safe unittest
{
    auto rng = parseJSONStream(`[]`);
    with (JSONParserNodeKind)
    {
        import std.algorithm;
        assert(rng.map!(n => n.kind).equal([arrayStart, arrayEnd]));
    }
}

@safe unittest
{
    import std.array;
    import std.exception;

    assertThrown(parseJSONStream(`]`).array);
    assertThrown(parseJSONStream(`}`).array);
    assertThrown(parseJSONStream(`,`).array);
    assertThrown(parseJSONStream(`:`).array);
    assertThrown(parseJSONStream(`{`).array);
    assertThrown(parseJSONStream(`[`).array);
    assertThrown(parseJSONStream(`[1,]`).array);
    assertThrown(parseJSONStream(`[1,,]`).array);
    assertThrown(parseJSONStream(`[1,`).array);
    assertThrown(parseJSONStream(`[1 2]`).array);
    assertThrown(parseJSONStream(`{1: 1}`).array);
    assertThrown(parseJSONStream(`{"a": 1,}`).array);
    assertThrown(parseJSONStream(`{"a" 1}`).array);
    assertThrown(parseJSONStream(`{"a": 1 "b": 2}`).array);
    assertThrown(parseJSONStream(`{"a": 1, "b": [null, true], "c": {"d": {}}}}`).array);
}

// Not possible to test anymore with the new String customization scheme
/*@safe unittest { // test for @nogc interface
   static struct MyAppender
   {
        @nogc:
        void put(string s) { }
        void put(dchar ch) {}
        void put(char ch) {}
        @property string data() { return null; }
    }
    static MyAppender createAppender() @nogc { return MyAppender.init; }

    static struct EmptyStream
    {
        @nogc:
        @property bool empty() { return true; }
        @property dchar front() { return ' '; }
        void popFront() { assert(false); }
        @property EmptyStream save() { return this; }
    }

    void test(T)()
    {
        T t;
        auto str = parseJSONStream!(LexOptions.noThrow, createAppender)(t);
        while (!str.empty) {
            auto f = str.front;
            str.popFront();
        }
    }
    // just instantiate, don't run
    auto t1 = &test!string;
    auto t2 = &test!wstring;
    auto t3 = &test!dstring;
    auto t4 = &test!EmptyStream;
}*/


/**
 * Lazy input range of JSON parser nodes.
 *
 * See $(D parseJSONStream) for more information.
 */
struct JSONParserRange(Input)
    if (isJSONTokenInputRange!Input)
{
    import stdx.data.json.foundation;

    alias String = typeof(Input.front).String;

    private {
        Input _input;
        JSONTokenKind[] _containerStack;
        size_t _containerStackFill = 0;
        JSONParserNodeKind _prevKind;
        JSONParserNode!String _node;
    }

    /**
     * Constructs a new parser range.
     */
    this(Input input)
    {
        _input = input;
    }

    /**
     * Determines of the range has been exhausted.
     */
    @property bool empty() { return _containerStackFill == 0 && _input.empty && _node.kind == JSONParserNodeKind.none; }

    /**
     * Returns the current node from the stream.
     */
    @property ref const(JSONParserNode!String) front()
    {
        ensureFrontValid();
        return _node;
    }

    /**
     * Skips to the next node in the stream.
     */
    void popFront()
    {
        assert(!empty);
        ensureFrontValid();
        _prevKind = _node.kind;
        _node.kind = JSONParserNodeKind.none;
    }

    private void ensureFrontValid()
    {
        if (_node.kind == JSONParserNodeKind.none)
        {
            readNext();
            assert(_node.kind != JSONParserNodeKind.none);
        }
    }

    private void readNext()
    {
        if (_containerStackFill)
        {
            if (_containerStack[_containerStackFill-1] == JSONTokenKind.objectStart)
                readNextInObject();
            else readNextInArray();
        }
        else readNextValue();
    }

    private void readNextInObject() @trusted
    {
        enforceJson(!_input.empty, "Missing closing '}'", _input.location);
        switch (_prevKind)
        {
            default: assert(false);
            case JSONParserNodeKind.objectStart:
                if (_input.front.kind == JSONTokenKind.objectEnd)
                {
                    _node.kind = JSONParserNodeKind.objectEnd;
                    _containerStackFill--;
                }
                else
                {
                    enforceJson(_input.front.kind == JSONTokenKind.string,
                        "Expected field name", _input.front.location);
                    _node.key = _input.front.string;
                }
                _input.popFront();
                break;
            case JSONParserNodeKind.key:
                enforceJson(_input.front.kind == JSONTokenKind.colon,
                    "Expected ':'", _input.front.location);
                _input.popFront();
                readNextValue();
                break;
            case JSONParserNodeKind.literal, JSONParserNodeKind.objectEnd, JSONParserNodeKind.arrayEnd:
                if (_input.front.kind == JSONTokenKind.objectEnd)
                {
                    _node.kind = JSONParserNodeKind.objectEnd;
                    _containerStackFill--;
                }
                else
                {
                    enforceJson(_input.front.kind == JSONTokenKind.comma,
                        "Expected ',' or '}'", _input.front.location);
                    _input.popFront();
                    enforceJson(!_input.empty && _input.front.kind == JSONTokenKind.string,
                        "Expected field name", _input.front.location);
                    _node.key = _input.front.string;
                }
                _input.popFront();
                break;
        }
    }

    private void readNextInArray()
    {
        enforceJson(!_input.empty, "Missing closing ']'", _input.location);
        switch (_prevKind)
        {
            default: assert(false);
            case JSONParserNodeKind.arrayStart:
                if (_input.front.kind == JSONTokenKind.arrayEnd)
                {
                    _node.kind = JSONParserNodeKind.arrayEnd;
                    _containerStackFill--;
                    _input.popFront();
                }
                else
                {
                    readNextValue();
                }
                break;
            case JSONParserNodeKind.literal, JSONParserNodeKind.objectEnd, JSONParserNodeKind.arrayEnd:
                if (_input.front.kind == JSONTokenKind.arrayEnd)
                {
                    _node.kind = JSONParserNodeKind.arrayEnd;
                    _containerStackFill--;
                    _input.popFront();
                }
                else
                {
                    enforceJson(_input.front.kind == JSONTokenKind.comma,
                        "Expected ',' or ']'", _input.front.location);
                    _input.popFront();
                    enforceJson(!_input.empty, "Missing closing ']'", _input.location);
                    readNextValue();
                }
                break;
        }
    }

    private void readNextValue()
    {
        switch (_input.front.kind)
        {
            default:
                throw new JSONException("Expected JSON value", _input.location);
            case JSONTokenKind.none: assert(false);
            case JSONTokenKind.null_, JSONTokenKind.boolean,
                    JSONTokenKind.number, JSONTokenKind.string:
                _node.literal = _input.front;
                _input.popFront();
                break;
            case JSONTokenKind.objectStart:
                _node.kind = JSONParserNodeKind.objectStart;
                pushContainer(JSONTokenKind.objectStart);
                _input.popFront();
                break;
            case JSONTokenKind.arrayStart:
                _node.kind = JSONParserNodeKind.arrayStart;
                pushContainer(JSONTokenKind.arrayStart);
                _input.popFront();
                break;
        }
    }

    private void pushContainer(JSONTokenKind kind)
    {
        import std.algorithm/*.comparison*/ : max;
        if (_containerStackFill >= _containerStack.length)
            _containerStack.length = max(32, _containerStack.length*3/2);
        _containerStack[_containerStackFill++] = kind;
    }
}


/**
 * Represents a single node of a JSON parse tree.
 *
 * See $(D parseJSONStream) and $(D JSONParserRange) more information.
 */
struct JSONParserNode(String)
{
    @safe:
    import std.algorithm/*.comparison*/ : among;
    import stdx.data.json.foundation : Location;

    private alias Kind = JSONParserNodeKind; // compatibility alias

    private
    {
        Kind _kind = Kind.none;
        union
        {
            String _key;
            JSONToken!String _literal;
        }
    }

    /**
     * The kind of this node.
     */
    @property Kind kind() const nothrow { return _kind; }
    /// ditto
    @property Kind kind(Kind value) nothrow
        in { assert(!value.among(Kind.key, Kind.literal)); }
        body { return _kind = value; }

    /**
     * The key identifier for $(D Kind.key) nodes.
     *
     * Setting the key will automatically switch the node kind.
     */
    @property String key() const @trusted nothrow
    {
        assert(_kind == Kind.key);
        return _key;
    }
    /// ditto
    @property String key(String value) nothrow
    {
        _kind = Kind.key;
        return () @trusted { return _key = value; } ();
    }

    /**
     * The literal token for $(D Kind.literal) nodes.
     *
     * Setting the literal will automatically switch the node kind.
     */
    @property ref inout(JSONToken!String) literal() inout @trusted nothrow
    {
        assert(_kind == Kind.literal);
        return _literal;
    }
    /// ditto
    @property ref JSONToken!String literal(JSONToken!String literal) nothrow
    {
        _kind = Kind.literal;
        return *() @trusted { return &(_literal = literal); } ();
    }

    @property Location location()
    const @trusted nothrow {
        if (_kind == Kind.literal) return _literal.location;
        return Location.init;
    }

    /**
     * Enables equality comparisons.
     *
     * Note that the location is considered part of the token and thus is
     * included in the comparison.
     */
    bool opEquals(in ref JSONParserNode other)
    const nothrow
    {
        if (this.kind != other.kind) return false;

        switch (this.kind)
        {
            default: return true;
            case Kind.literal: return this.literal == other.literal;
            case Kind.key: return this.key == other.key;
        }
    }
    /// ditto
    bool opEquals(JSONParserNode other) const nothrow { return opEquals(other); }

    unittest
    {
        JSONToken!string t1, t2, t3;
        t1.string = "test";
        t2.string = "test".idup;
        t3.string = "other";

        JSONParserNode!string n1, n2;
        n2.literal = t1; assert(n1 != n2);
        n1.literal = t1; assert(n1 == n2);
        n1.literal = t3; assert(n1 != n2);
        n1.literal = t2; assert(n1 == n2);
        n1.kind = Kind.objectStart; assert(n1 != n2);
        n1.key = "test"; assert(n1 != n2);
        n2.key = "other"; assert(n1 != n2);
        n2.key = "test".idup; assert(n1 == n2);
    }

    /**
     * Enables usage of $(D JSONToken) as an associative array key.
     */
    size_t toHash() const nothrow @trusted
    {
        hash_t ret = 723125331 + cast(int)_kind * 3962627;

        switch (_kind)
        {
            default: return ret;
            case Kind.literal: return ret + _literal.toHash();
            case Kind.key: return ret + typeid(.string).getHash(&_key);
        }
    }

    /**
     * Converts the node to a string representation.
     *
     * Note that this representation is NOT the JSON representation, but rather
     * a representation suitable for printing out a node.
     */
    string toString() const
    {
        import std.string;
        switch (this.kind)
        {
            default: return format("%s", this.kind);
            case Kind.key: return format("[key \"%s\"]", this.key);
            case Kind.literal: return literal.toString();
        }
    }
}


/**
 * Identifies the kind of a parser node.
 */
enum JSONParserNodeKind
{
    none,        /// Used internally, never occurs in a node stream
    key,         /// An object key
    literal,     /// A literal value ($(D null), $(D boolean), $(D number) or $(D string))
    objectStart, /// The start of an object value
    objectEnd,   /// The end of an object value
    arrayStart,  /// The start of an array value
    arrayEnd,    /// The end of an array value
}


/// Tests if a given type is an input range of $(D JSONToken).
enum isJSONTokenInputRange(R) = isInputRange!R && is(typeof(R.init.front) : JSONToken!String, String);

static assert(isJSONTokenInputRange!(JSONLexerRange!string));

/// Tests if a given type is an input range of $(D JSONParserNode).
enum isJSONParserNodeInputRange(R) = isInputRange!R && is(typeof(R.init.front) : JSONParserNode!String, String);

static assert(isJSONParserNodeInputRange!(JSONParserRange!(JSONLexerRange!string)));

// Workaround for https://issues.dlang.org/show_bug.cgi?id=14425
private alias Workaround_14425 = JSONParserRange!(JSONLexerRange!string);


/**
 * Skips a single JSON value in a parser stream.
 *
 * The value pointed to by `nodes.front` will be skipped. All JSON types will
 * be skipped, which means in particular that arrays and objects will be
 * skipped recursively.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 */
void skipValue(R)(ref R nodes) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", nodes.front.literal.location);

    auto k = nodes.front.kind;
    nodes.popFront();

    with (JSONParserNodeKind) {
        if (k != arrayStart && k != objectStart) return;

        int depth = 1;
        while (!nodes.empty) {
            k = nodes.front.kind;
            nodes.popFront();
            if (k == arrayStart || k == objectStart) depth++;
            else if (k == arrayEnd || k == objectEnd) {
                if (--depth == 0) break;
            }
        }
    }
}

///
@safe unittest
{
    auto j = parseJSONStream(q{
            [
                [1, 2, 3],
                "foo"
            ]
        });

    assert(j.front.kind == JSONParserNodeKind.arrayStart);
    j.popFront();
    
    // skips the whole [1, 2, 3] array
    j.skipValue();

    string value = j.readString;
    assert(value == "foo");

    assert(j.front.kind == JSONParserNodeKind.arrayEnd);
    j.popFront();

    assert(j.empty);
}


/**
 * Skips all entries in an object until a certain key is reached.
 *
 * The node range must either point to the start of an object
 * (`JSONParserNodeKind.objectStart`), or to a key within an object
 * (`JSONParserNodeKind.key`).
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *   key = Name of the key to find
 *
 * Returns:
 *   `true` is returned if and only if the specified key has been found.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 */
bool skipToKey(R)(ref R nodes, string key) if (isJSONParserNodeInputRange!R)
{
    import std.algorithm/*.comparison*/ : among;
    import stdx.data.json.foundation;

    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind.among!(JSONParserNodeKind.objectStart, JSONParserNodeKind.key) > 0,
        "Expected object or object key", nodes.front.location);

    if (nodes.front.kind == JSONParserNodeKind.objectStart)
        nodes.popFront();

    while (true) {
        auto k = nodes.front.kind;
        if (k == JSONParserNodeKind.objectEnd) {
            nodes.popFront();
            return false;
        }

        assert(k == JSONParserNodeKind.key);
        if (nodes.front.key == key) {
            nodes.popFront();
            return true;
        }

        nodes.popFront();

        nodes.skipValue();
    }
}

///
@safe unittest
{
    auto j = parseJSONStream(q{
            {
                "foo": 2,
                "bar": 3,
                "baz": false,
                "qux": "str"
            }
        });

    j.skipToKey("bar");
    double v1 = j.readDouble;
    assert(v1 == 3);

    j.skipToKey("qux");
    string v2 = j.readString;
    assert(v2 == "str");

    assert(j.front.kind == JSONParserNodeKind.objectEnd);
    j.popFront();

    assert(j.empty);
}


/**
 * Reads an array and issues a callback for each entry.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *   del = The callback to invoke for each array entry
 */
void readArray(R)(ref R nodes, scope void delegate() @safe del) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNodeKind.arrayStart,
        "Expected array", nodes.front.location);
    nodes.popFront();

    while (true) {
        auto k = nodes.front.kind;
        if (k == JSONParserNodeKind.arrayEnd) {
          nodes.popFront();
          return;
        }
        del();
    }
}

///
@safe unittest
{
    auto j = parseJSONStream(q{
            [
                "foo",
                "bar"
            ]
        });

    size_t i = 0;
    j.readArray({
        auto value = j.readString();
        switch (i++) {
            default: assert(false);
            case 0: assert(value == "foo"); break;
            case 1: assert(value == "bar"); break;
        }
    });

    assert(j.empty);
}

/** Reads an array and returns a lazy range of parser node ranges.
  *
  * The given parser node range must point to a node of kind
  * `JSONParserNodeKind.arrayStart`. Each of the returned sub ranges
  * corresponds to the contents of a single array entry.
  *
  * Params:
  *   nodes = An input range of JSON parser nodes
  *
  * Throws:
  *   A `JSONException` is thrown if the input range does not point to the
  *   start of an array.
*/
auto readArray(R)(ref R nodes) @system if (isJSONParserNodeInputRange!R)
{
    static struct VR {
        R* nodes;
        size_t depth = 0;

        @disable this(this);

        @property bool empty() { return !nodes || nodes.empty; }

        @property ref const(typeof(nodes.front)) front() { return nodes.front; }

        void popFront()
        {
            switch (nodes.front.kind) with (JSONParserNodeKind)
            {
                default: break;
                case objectStart, arrayStart: depth++; break;
                case objectEnd, arrayEnd: depth--; break;
            }

            nodes.popFront();

            if (depth == 0) nodes = null;
        }
    }

    static struct ARR {
        R* nodes;
        VR value;

        @property bool empty() { return !nodes || nodes.empty; }

        @property ref inout(VR) front() inout { return value; }

        void popFront()
        {
            while (!value.empty) value.popFront();
            if (nodes.front.kind == JSONParserNodeKind.arrayEnd) {
                nodes.popFront();
                nodes = null;
            } else {
                value = VR(nodes);
            }
        }
    }

    import stdx.data.json.foundation;

    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNodeKind.arrayStart,
        "Expected array", nodes.front.location);
    nodes.popFront();

    ARR ret;

    if (nodes.front.kind != JSONParserNodeKind.arrayEnd) {
        ret.nodes = &nodes;
        ret.value = VR(&nodes);
    } else nodes.popFront();

    return ret;
}

///
unittest {
    auto j = parseJSONStream(q{
            [
                "foo",
                "bar"
            ]
        });

    size_t i = 0;
    foreach (ref entry; j.readArray) {
        auto value = entry.readString;
        assert(entry.empty);
        switch (i++) {
            default: assert(false);
            case 0: assert(value == "foo"); break;
            case 1: assert(value == "bar"); break;
        }
    }
    assert(i == 2);
}


/**
 * Reads an object and issues a callback for each field.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *   del = The callback to invoke for each object field
 */
void readObject(R)(ref R nodes, scope void delegate(string key) @safe del) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNodeKind.objectStart,
        "Expected object", nodes.front.literal.location);
    nodes.popFront();

    while (true) {
        auto k = nodes.front.kind;
        if (k == JSONParserNodeKind.objectEnd) {
          nodes.popFront();
          return;
        }
        auto key = nodes.front.key;
        nodes.popFront();
        del(key);
    }
}

///
@safe unittest
{
    auto j = parseJSONStream(q{
            {
                "foo": 1,
                "bar": 2
            }
        });

    j.readObject((key) {
        auto value = j.readDouble;
        switch (key) {
            default: assert(false);
            case "foo": assert(value == 1); break;
            case "bar": assert(value == 2); break;
        }
    });

    assert(j.empty);
}


/**
 * Reads a single double value.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *
 * Throws: Throws a `JSONException` is the node range is empty or `nodes.front` is not a number.
 */
double readDouble(R)(ref R nodes) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNodeKind.literal
        && nodes.front.literal.kind == JSONTokenKind.number,
        "Expected numeric value", nodes.front.literal.location);
    double ret = nodes.front.literal.number;
    nodes.popFront();
    return ret;
}

///
@safe unittest
{
    auto j = parseJSONStream(`1.0`);
    double value = j.readDouble;
    assert(value == 1.0);
    assert(j.empty);
}


/**
 * Reads a single double value.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *
 * Throws: Throws a `JSONException` is the node range is empty or `nodes.front` is not a string.
 */
string readString(R)(ref R nodes) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNodeKind.literal
        && nodes.front.literal.kind == JSONTokenKind.string,
        "Expected string value", nodes.front.literal.location);
    string ret = nodes.front.literal.string;
    nodes.popFront();
    return ret;
}

///
@safe unittest
{
    auto j = parseJSONStream(`"foo"`);
    string value = j.readString;
    assert(value == "foo");
    assert(j.empty);
}


/**
 * Reads a single double value.
 *
 * Params:
 *   nodes = An input range of JSON parser nodes
 *
 * Throws: Throws a `JSONException` is the node range is empty or `nodes.front` is not a boolean.
 */
bool readBool(R)(ref R nodes) if (isJSONParserNodeInputRange!R)
{
    import stdx.data.json.foundation;
    enforceJson(!nodes.empty, "Unexpected end of input", Location.init);
    enforceJson(nodes.front.kind == JSONParserNodeKind.literal
        && nodes.front.literal.kind == JSONTokenKind.boolean,
        "Expected boolean value", nodes.front.literal.location);
    bool ret = nodes.front.literal.boolean;
    nodes.popFront();
    return ret;
}

///
@safe unittest
{
    auto j = parseJSONStream(`true`);
    bool value = j.readBool;
    assert(value == true);
    assert(j.empty);
}
